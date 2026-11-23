import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_sync_service.dart';

/// Platformlar arası Google OAuth 2.0 kimlik doğrulama ve çıkış sözleşmesi (DIP).
abstract interface class GoogleAuthAdapter {
  /// Mevcut platformun yerel mobil SDK (`google_sign_in`) akışını kullanıp kullanmadığı.
  bool get isNativePlatform;

  /// Platforma uygun Google OAuth 2.0 oturum açma ve Drive `drive.file` yetkilendirmesini başlatır.
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
  });

  /// Kullanıcı etkileşimi olmadan kayıtlı Google erişim belirtecini sessizce yeniler.
  Future<String?> refreshAccessTokenSilently();

  /// Mevcut Google oturumunu yerel SDK önbelleğinden kapatır.
  Future<void> signOut();
}

/// Masaüstü (Windows/macOS/Linux) için tarayıcı + yerel loopback PKCE adaptörü.
class DesktopLoopbackGoogleAuthAdapter implements GoogleAuthAdapter {
  final GoogleDriveSyncService _syncService;

  const DesktopLoopbackGoogleAuthAdapter(this._syncService);

  @override
  bool get isNativePlatform => false;

  @override
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
  }) {
    return _syncService.startInteractiveBrowserGoogleSignIn(
      loginHintEmail: loginHintEmail,
      customClientId: customClientId,
      customClientSecret: customClientSecret,
      timeout: timeout,
    );
  }

  @override
  Future<String?> refreshAccessTokenSilently() =>
      _syncService.refreshAccessToken();

  @override
  Future<void> signOut() async {}
}

/// Android ve iOS için `google_sign_in` v7 (`Credential Manager` + `authorizationClient`) adaptörü.
class NativeMobileGoogleAuthAdapter implements GoogleAuthAdapter {
  static const List<String> _driveScopes = <String>[
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
  ];

  final String? _serverClientIdOverride;
  final String? _iosClientIdOverride;
  bool _initialized = false;

  NativeMobileGoogleAuthAdapter({
    String? serverClientId,
    String? iosClientId,
  })  : _serverClientIdOverride = serverClientId,
        _iosClientIdOverride = iosClientId;

  @override
  bool get isNativePlatform => true;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final effectiveServerClientId = (_serverClientIdOverride ??
            GoogleDriveSyncService.defaultIhasibuWebClientId)
        .trim();
    final effectiveIosClientId = (_iosClientIdOverride ??
            GoogleDriveSyncService.defaultIhasibuIosClientId)
        .trim();
    final String? clientIdForPlatform =
        (!kIsWeb && Platform.isIOS && effectiveIosClientId.isNotEmpty)
            ? effectiveIosClientId
            : null;
    await GoogleSignIn.instance.initialize(
      clientId: clientIdForPlatform,
      serverClientId:
          effectiveServerClientId.isEmpty ? null : effectiveServerClientId,
    );
    _initialized = true;
  }

  @override
  Future<BrowserGoogleSignInResult> signIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      await _ensureInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const BrowserGoogleSignInResult(
          success: false,
          message: 'Bu cihazda yerel Google ile Giriş desteklenmiyor.',
        );
      }

      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _driveScopes,
      );
      final authClient = account.authorizationClient;
      var authorization = await authClient.authorizationForScopes(_driveScopes);
      authorization ??= await authClient.authorizeScopes(_driveScopes);

      final accessToken = authorization.accessToken.trim();
      if (accessToken.isEmpty) {
        return const BrowserGoogleSignInResult(
          success: false,
          message:
              'Google hesabı doğrulandı ancak Drive OAuth 2.0 erişim anahtarı alınamadı.',
        );
      }

      final email = account.email.trim();
      final displayName = (account.displayName ?? '').trim();
      return BrowserGoogleSignInResult(
        success: true,
        accessToken: accessToken,
        email: email,
        displayName: displayName,
        message:
            'Google OAuth 2.0 oturumu açıldı (${email.isEmpty ? "Google" : email}).',
      );
    } on GoogleSignInException catch (e) {
      return BrowserGoogleSignInResult(
        success: false,
        message: _formatExceptionMessage(e),
      );
    } catch (e) {
      debugPrint('NativeMobileGoogleAuthAdapter: signIn hatası: $e');
      return BrowserGoogleSignInResult(
        success: false,
        message: 'Google ile giriş tamamlanamadı: $e',
      );
    }
  }

  @override
  Future<String?> refreshAccessTokenSilently() async {
    try {
      await _ensureInitialized();
      final pending = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = pending == null ? null : await pending;
      if (account == null) return null;
      final auth =
          await account.authorizationClient.authorizationForScopes(_driveScopes);
      final token = auth?.accessToken.trim() ?? '';
      return token.isEmpty ? null : token;
    } catch (e) {
      debugPrint(
        'NativeMobileGoogleAuthAdapter: refreshAccessTokenSilently uyarısı: $e',
      );
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('NativeMobileGoogleAuthAdapter: signOut uyarısı: $e');
    }
  }

  static String _formatExceptionMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google girişi kullanıcı tarafından iptal edildi.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google ile Giriş yapılandırması (Android/Web/iOS Client ID veya SHA-1 parmak izi) doğrulanamadı (${e.description ?? e.code.name}).';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Cihazda Google Play Hizmetleri / Credential Manager hazır değil (${e.description ?? e.code.name}).';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google oturum açma işlemi kesintiye uğradı, lütfen tekrar deneyin.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google oturum açma ekranı şu anda açılamıyor.';
      default:
        return 'Google girişi başarısız (${e.code.name}): ${e.description ?? 'Bilinmeyen hata'}';
    }
  }
}

/// Çalışılan platforma uygun `GoogleAuthAdapter` örneğini oluşturur.
GoogleAuthAdapter createPlatformGoogleAuthAdapter(
  GoogleDriveSyncService syncService,
) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return NativeMobileGoogleAuthAdapter();
  }
  return DesktopLoopbackGoogleAuthAdapter(syncService);
}
