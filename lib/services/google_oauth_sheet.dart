import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'google_drive_backup_service.dart';

class GoogleOAuthConstants {
  static const String clientId =
      '803381919405-3j7rne8pv0j5b9u87faeesagnvrqd5gd.apps.googleusercontent.com';
  static const String reversedClientId =
      'com.googleusercontent.apps.803381919405-3j7rne8pv0j5b9u87faeesagnvrqd5gd';
  static const String redirectUri = 'com.akarworks.cuedeck://';
  static const String altRedirectUri =
      'com.googleusercontent.apps.803381919405-3j7rne8pv0j5b9u87faeesagnvrqd5gd:/oauthredirect';
  static const String authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';
  static const String driveScope =
      'https://www.googleapis.com/auth/drive.appdata '
      'https://www.googleapis.com/auth/drive.file '
      'https://www.googleapis.com/auth/userinfo.email '
      'https://www.googleapis.com/auth/userinfo.profile';
}

/// PKCE (`S256`), CSRF `state` generation, and OAuth2 code exchange helper.
class GoogleOAuthHelper {
  static const Duration _timeout = Duration(seconds: 15);

  static String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(values)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  static String generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  static String generateState() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static bool isAllowedGoogleOAuthHost(String host) {
    final lower = host.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == 'accounts.google.com' ||
        lower == 'oauth2.googleapis.com' ||
        lower == 'accounts.youtube.com' ||
        lower == 'google.com' ||
        lower == 'google.com.tr' ||
        lower == 'gstatic.com' ||
        lower == 'googleapis.com' ||
        lower == 'googleusercontent.com' ||
        lower == 'gvt1.com') {
      return true;
    }
    return lower.endsWith('.google.com') ||
        lower.endsWith('.google.com.tr') ||
        lower.contains('.google.') ||
        lower.endsWith('.gstatic.com') ||
        lower.endsWith('.googleapis.com') ||
        lower.endsWith('.googleusercontent.com') ||
        lower.endsWith('.youtube.com') ||
        lower.endsWith('.gvt1.com');
  }

  static Future<bool> exchangeAndSaveTokens({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _timeout;
    try {
      final formBody = <String, String>{
        'code': code,
        'client_id': GoogleOAuthConstants.clientId,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      }.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');

      final tokenReq = await client
          .postUrl(Uri.parse(GoogleOAuthConstants.tokenEndpoint))
          .timeout(_timeout);
      tokenReq.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      final bodyBytes = utf8.encode(formBody);
      tokenReq.contentLength = bodyBytes.length;
      tokenReq.add(bodyBytes);

      final tokenRes = await tokenReq.close().timeout(_timeout);
      final tokenResBody =
          await tokenRes.transform(utf8.decoder).join().timeout(_timeout);

      if (tokenRes.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(tokenResBody) as Map<String, dynamic>;
      final accessToken = (data['access_token'] as String?) ?? '';
      final refreshToken = (data['refresh_token'] as String?) ?? '';
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

      if (accessToken.isEmpty) return false;

      var email = '';
      var name = '';

      // Fetch Google UserInfo profile (email & display name)
      try {
        final userReq = await client
            .getUrl(Uri.parse(GoogleOAuthConstants.userInfoEndpoint))
            .timeout(_timeout);
        userReq.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
        final userRes = await userReq.close().timeout(_timeout);
        final userBody =
            await userRes.transform(utf8.decoder).join().timeout(_timeout);
        if (userRes.statusCode == 200) {
          final userData = jsonDecode(userBody) as Map<String, dynamic>;
          email = (userData['email'] as String?)?.trim() ?? '';
          name = (userData['name'] as String?)?.trim() ?? '';
        }
      } catch (_) {}

      await GoogleDriveBackupService.saveTokensSecurely(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresInSeconds: expiresIn,
        email: email.isNotEmpty ? email : 'Google Drive Kullanıcısı',
        name: name.isNotEmpty ? name : 'CueDeck Kullanıcısı',
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: false);
    }
  }
}

/// Obsidian & Gold themed OAuth2 PKCE (`S256`) modal bottom sheet for Google Drive sign-in.
class GoogleOAuthSheet extends StatefulWidget {
  const GoogleOAuthSheet({super.key});

  static Future<bool> startOAuth(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => const GoogleOAuthSheet(),
    );
    return result ?? false;
  }

  @override
  State<GoogleOAuthSheet> createState() => _GoogleOAuthSheetState();
}

class _GoogleOAuthSheetState extends State<GoogleOAuthSheet> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _handledRedirect = false;
  String _errorMessage = '';
  String _codeVerifier = '';
  String _expectedState = '';
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
      _handledRedirect = false;
      _errorMessage = '';
    });

    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage =
            'Google OAuth WebView penceresi Android ve iOS cihazlarda desteklenmektedir.';
      });
      return;
    }

    try {
      _codeVerifier = GoogleOAuthHelper.generateCodeVerifier();
      final codeChallenge =
          GoogleOAuthHelper.generateCodeChallenge(_codeVerifier);
      _expectedState = GoogleOAuthHelper.generateState();

      _authUrl = Uri.parse(GoogleOAuthConstants.authEndpoint).replace(
        queryParameters: <String, String>{
          'client_id': GoogleOAuthConstants.clientId,
          'redirect_uri': GoogleOAuthConstants.redirectUri,
          'response_type': 'code',
          'scope': GoogleOAuthConstants.driveScope,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'state': _expectedState,
          'access_type': 'offline',
          'prompt': 'select_account consent',
        },
      ).toString();

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.values.last)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        )
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
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false) return;
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
                  (uri.scheme == 'com.akarworks.cuedeck' ||
                      uri.scheme == GoogleOAuthConstants.reversedClientId ||
                      request.url.startsWith('com.akarworks.cuedeck:') ||
                      request.url.startsWith(
                        '${GoogleOAuthConstants.reversedClientId}:',
                      ) ||
                      request.url.startsWith(
                        GoogleOAuthConstants.redirectUri,
                      ) ||
                      request.url.startsWith(
                        GoogleOAuthConstants.altRedirectUri,
                      ));
              if (isRedirect) {
                _handleRedirect(request.url);
                return NavigationDecision.prevent;
              }
              if (request.url == 'about:blank' || !request.isMainFrame) {
                return NavigationDecision.navigate;
              }
              if (uri != null &&
                  uri.scheme == 'https' &&
                  GoogleOAuthHelper.isAllowedGoogleOAuthHost(uri.host)) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
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
    if (_handledRedirect || !mounted) return;
    _handledRedirect = true;

    setState(() => _isLoading = true);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    // Strict OAuth2 CSRF state parameter verification
    final returnedState = uri.queryParameters['state'];
    if (_expectedState.isEmpty || returnedState != _expectedState) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _handledRedirect = false;
          _errorMessage =
              'Güvenlik doğrulaması (OAuth2 CSRF state) eşleşmedi. Lütfen tekrar deneyin.';
        });
      }
      return;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final success = await GoogleOAuthHelper.exchangeAndSaveTokens(
      code: code,
      codeVerifier: _codeVerifier,
      redirectUri: GoogleOAuthConstants.redirectUri,
    );

    if (mounted) {
      Navigator.of(context).pop(success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E111A) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF141824);
    final secondaryTextColor =
        isDark ? const Color(0xFFA0A8B8) : const Color(0xFF5A6275);
    const accentGold = Color(0xFFE2A84B);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: accentGold.withValues(alpha: 0.25)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.16),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.cloud_done_rounded,
                        color: accentGold,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Google ile Giriş Yap',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: primaryTextColor,
                        ),
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
                        icon: Icon(
                          Icons.close_rounded,
                          color: primaryTextColor,
                        ),
                        tooltip: 'Kapat',
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
                color: accentGold,
                minHeight: 2.5,
              ),
            Expanded(
              child: _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 54,
                              color: Color(0xFFFF5252),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bağlantı Kurulamadı',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage.isNotEmpty
                                  ? _errorMessage
                                  : 'Google hesabınıza bağlanmak için lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: const Color(0xFF090A0F),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _initOAuth,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Yeniden Dene',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _controller == null
                      ? const Center(
                          child: CircularProgressIndicator(color: accentGold),
                        )
                      : ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: WebViewWidget(controller: _controller!),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
