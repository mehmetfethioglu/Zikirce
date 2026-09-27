import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/secure_storage_helper.dart';

class GoogleOAuthConstants {
  static const String clientId = '497197680323-k954rqrvtjfk5qv83heimbs8k1fe8t5m.apps.googleusercontent.com';
  static const String redirectUri = 'com.akarworks.zikirce://';
  static const String authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String userInfoEndpoint = 'https://www.googleapis.com/oauth2/v3/userinfo';
  static const String driveScope = 'https://www.googleapis.com/auth/drive.appdata https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile';

  static const String accessTokenKey = 'GoogleDrive_AccessToken';
  static const String refreshTokenKey = 'GoogleDrive_RefreshToken';
  static const String tokenExpiryKey = 'GoogleDrive_TokenExpiry';
  static const String userEmailKey = 'GoogleDrive_UserEmail';
  static const String userNameKey = 'GoogleDrive_UserName';
}

/// Token alışverişi ve kayıt işlemlerini gerçekleştiren ortak yardımcı sınıf
class GoogleOAuthHelper {
  static String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  static String generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  static String generateState() {
    final random = Random.secure();
    return List<int>.generate(16, (i) => random.nextInt(256))
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<bool> exchangeAndSaveTokens({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String? sessionId,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        GoogleOAuthConstants.tokenEndpoint,
        data: {
          'code': code,
          'client_id': GoogleOAuthConstants.clientId,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token']?.toString() ?? '';
        final refreshToken = data['refresh_token']?.toString() ?? '';
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

        final sid = sessionId;
        final isDefault = sid == null || sid.isEmpty || sid == 'default_user';

        if (isDefault) {
          await SecureStorageHelper.write(GoogleOAuthConstants.accessTokenKey, accessToken);
          await SecureStorageHelper.write('${GoogleOAuthConstants.accessTokenKey}_default_user', accessToken);
          if (refreshToken.isNotEmpty) {
            await SecureStorageHelper.write(GoogleOAuthConstants.refreshTokenKey, refreshToken);
            await SecureStorageHelper.write('${GoogleOAuthConstants.refreshTokenKey}_default_user', refreshToken);
          }
        } else {
          await SecureStorageHelper.write('${GoogleOAuthConstants.accessTokenKey}_$sid', accessToken);
          if (refreshToken.isNotEmpty) {
            await SecureStorageHelper.write('${GoogleOAuthConstants.refreshTokenKey}_$sid', refreshToken);
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final expiryMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
        if (isDefault) {
          await prefs.setInt(GoogleOAuthConstants.tokenExpiryKey, expiryMs);
          await prefs.setInt('${GoogleOAuthConstants.tokenExpiryKey}_default_user', expiryMs);
        } else {
          await prefs.setInt('${GoogleOAuthConstants.tokenExpiryKey}_$sid', expiryMs);
        }

        // Fetch User Info
        try {
          final userResponse = await dio.get(
            GoogleOAuthConstants.userInfoEndpoint,
            options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
          );

          if (userResponse.statusCode == 200) {
            final userData = userResponse.data as Map<String, dynamic>;
            final email = userData['email']?.toString() ?? '';
            final name = userData['name']?.toString() ?? '';
            if (isDefault) {
              await prefs.setString(GoogleOAuthConstants.userEmailKey, email);
              await prefs.setString(GoogleOAuthConstants.userNameKey, name);
              await prefs.setString('${GoogleOAuthConstants.userEmailKey}_default_user', email);
              await prefs.setString('${GoogleOAuthConstants.userNameKey}_default_user', name);
            } else {
              await prefs.setString('${GoogleOAuthConstants.userEmailKey}_$sid', email);
              await prefs.setString('${GoogleOAuthConstants.userNameKey}_$sid', name);
            }
          }
        } catch (userInfoError) {
          debugPrint('[GoogleOAuth] UserInfo fetch warning: $userInfoError');
        }

        return true;
      } else {
        debugPrint('[GoogleOAuth] Token endpoint response error: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('[GoogleOAuth] Token exchange DioException: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        debugPrint('[GoogleOAuth] Token exchange error: $e');
      }
    }
    return false;
  }
}

/// ----------------------------------------------------------------------------
/// GOOGLE OAUTH SHEET (MOBILE & DESKTOP ENTEGRASYONU)
/// ----------------------------------------------------------------------------
class GoogleOAuthSheet extends StatefulWidget {
  final String? sessionId;
  const GoogleOAuthSheet({super.key, this.sessionId});

  static Future<bool> startOAuth(BuildContext context, {String? sessionId}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await _startDesktopOAuth(context, sessionId: sessionId);
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => GoogleOAuthSheet(sessionId: sessionId),
    );
    return result ?? false;
  }

  static Future<bool> _startDesktopOAuth(BuildContext context, {String? sessionId}) async {
    try {
      final isAvailable = await WebviewWindow.isWebviewAvailable();
      if (!isAvailable) {
        debugPrint('[GoogleOAuth] Desktop webview not available');
        return false;
      }

      final codeVerifier = GoogleOAuthHelper.generateCodeVerifier();
      final codeChallenge = GoogleOAuthHelper.generateCodeChallenge(codeVerifier);
      final state = GoogleOAuthHelper.generateState();

      final authUrl = Uri.parse(GoogleOAuthConstants.authEndpoint).replace(queryParameters: {
        'client_id': GoogleOAuthConstants.clientId,
        'redirect_uri': GoogleOAuthConstants.redirectUri,
        'response_type': 'code',
        'scope': GoogleOAuthConstants.driveScope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        'prompt': 'select_account consent',
      }).toString();

      final webview = await WebviewWindow.create(
        configuration: const CreateConfiguration(
          windowWidth: 520,
          windowHeight: 720,
          title: 'Google ile Giriş Yap - Zikirce',
          titleBarHeight: 38,
          titleBarTopPadding: 0,
        ),
      );

      final completer = Completer<bool>();
      bool handled = false;

      webview.setOnUrlRequestCallback((url) {
        final uri = Uri.tryParse(url);
        final isRedirect = uri != null &&
            (uri.scheme == 'com.akarworks.zikirce' ||
             url.startsWith('com.akarworks.zikirce:') ||
             url.startsWith(GoogleOAuthConstants.redirectUri));

        if (isRedirect) {
          if (!handled) {
            handled = true;
            final error = uri.queryParameters['error'];
            if (error != null) {
              debugPrint('[GoogleOAuthDesktop] OAuth returned error: $error');
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              try {
                webview.close();
              } catch (_) {}
              return false;
            }

            final code = uri.queryParameters['code'];
            if (code != null && code.isNotEmpty) {
              GoogleOAuthHelper.exchangeAndSaveTokens(
                code: code,
                codeVerifier: codeVerifier,
                redirectUri: GoogleOAuthConstants.redirectUri,
                sessionId: sessionId,
              ).then((success) {
                if (!completer.isCompleted) {
                  completer.complete(success);
                }
                try {
                  webview.close();
                } catch (_) {}
              }).catchError((err) {
                debugPrint('[GoogleOAuthDesktop] Token exchange failed: $err');
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
                try {
                  webview.close();
                } catch (_) {}
              });
            } else {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              try {
                webview.close();
              } catch (_) {}
            }
          }
          return false; // Prevent navigating to custom scheme since we intercepted it
        }
        return true; // Allow navigation to Google login pages
      });

      webview.onClose.then((_) {
        // Only mark failed if the window closed before redirect was captured
        if (!handled && !completer.isCompleted) {
          completer.complete(false);
        }
      });

      webview.launch(authUrl);

      return await completer.future;
    } catch (e) {
      debugPrint('[GoogleOAuthDesktop] Error: $e');
      return false;
    }
  }

  @override
  State<GoogleOAuthSheet> createState() => _GoogleOAuthSheetState();
}

/// ----------------------------------------------------------------------------
/// MOBİL İÇİN WEBVIEW BOTTOM SHEET
/// ----------------------------------------------------------------------------
class _GoogleOAuthSheetState extends State<GoogleOAuthSheet> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _codeVerifier = '';
  String _authUrl = '';

  @override
  void initState() {
    super.initState();
    _initOAuth();
  }

  Future<void> _initOAuth() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _codeVerifier = GoogleOAuthHelper.generateCodeVerifier();
      final codeChallenge = GoogleOAuthHelper.generateCodeChallenge(_codeVerifier);
      final state = GoogleOAuthHelper.generateState();

      _authUrl = Uri.parse(GoogleOAuthConstants.authEndpoint).replace(queryParameters: {
        'client_id': GoogleOAuthConstants.clientId,
        'redirect_uri': GoogleOAuthConstants.redirectUri,
        'response_type': 'code',
        'scope': GoogleOAuthConstants.driveScope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        'prompt': 'select_account consent',
      }).toString();

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                  _errorMessage = error.description;
                });
              }
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              final isRedirect = uri != null &&
                  (uri.scheme == 'com.akarworks.zikirce' ||
                   request.url.startsWith('com.akarworks.zikirce:') ||
                   request.url.startsWith(GoogleOAuthConstants.redirectUri));
              if (isRedirect) {
                _handleRedirect(request.url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      try {
        final cookieManager = WebViewCookieManager();
        await cookieManager.clearCookies();
      } catch (_) {}

      try {
        await controller.clearCache();
      } catch (_) {}

      await controller.loadRequest(Uri.parse(_authUrl));

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Web görünümü başlatılamadı: $e';
        });
      }
    }
  }

  Future<void> _handleRedirect(String url) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];

    if (code == null || code.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final success = await GoogleOAuthHelper.exchangeAndSaveTokens(
      code: code,
      codeVerifier: _codeVerifier,
      redirectUri: GoogleOAuthConstants.redirectUri,
      sessionId: widget.sessionId,
    );

    if (mounted) Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1F1A17) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    const accentColor = Color(0xFF2D7D76);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('☁️ ', style: TextStyle(fontSize: 20)),
                      Text(
                        'Google ile Giriş Yap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Yenile',
                        onPressed: () {
                          if (_controller == null) {
                            _initOAuth();
                            return;
                          }
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                          });
                          _controller!.loadRequest(Uri.parse(_authUrl));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: accentColor,
              ),
            Expanded(
              child: _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFD1495B)),
                            const SizedBox(height: 16),
                            Text(
                              'İnternet Bağlantısı Yok',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage.isNotEmpty
                                  ? _errorMessage
                                  : 'Google hesabınıza bağlanmak için lütfen internet bağlantınızı (Wi-Fi veya Mobil Veri) açın ve tekrar deneyin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Yeniden Dene', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (_controller == null) {
                                  _initOAuth();
                                  return;
                                }
                                setState(() {
                                  _isLoading = true;
                                  _hasError = false;
                                });
                                _controller!.loadRequest(Uri.parse(_authUrl));
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : _controller == null
                      ? const Center(
                          child: CircularProgressIndicator(color: accentColor),
                        )
                      : ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: WebViewWidget(controller: _controller!),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
