import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/cuedeck_providers.dart';

/// Obsidian & Gold themed OAuth2 PKCE (`S256`) modal bottom sheet for Google Drive sign-in (Layer 4 UI).
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
      } catch (e) {
        debugPrint('WebView clearCookies skipped: $e');
      }

      try {
        await controller.clearCache();
      } catch (e) {
        debugPrint('WebView clearCache skipped: $e');
      }

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
