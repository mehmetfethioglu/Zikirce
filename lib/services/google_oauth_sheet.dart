import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

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

/// PKCE (`S256`), CSRF `state` generation, and OAuth2 code exchange helper (Layer 2 service).
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

      if (tokenRes.statusCode != 200) return false;

      final data = jsonDecode(tokenResBody) as Map<String, dynamic>;
      final accessToken = (data['access_token'] as String?) ?? '';
      final refreshToken = (data['refresh_token'] as String?) ?? '';
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

      if (accessToken.isEmpty) return false;

      var email = '';
      var name = '';
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
      } catch (e) {
        debugPrint('GoogleOAuthHelper userinfo skipped: $e');
      }

      await GoogleDriveBackupService.saveTokensSecurely(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresInSeconds: expiresIn,
        email: email.isNotEmpty ? email : 'Google Drive Kullanıcısı',
        name: name.isNotEmpty ? name : 'CueDeck Kullanıcısı',
      );
      return true;
    } catch (e) {
      debugPrint('GoogleOAuthHelper token exchange error: $e');
      return false;
    } finally {
      client.close(force: false);
    }
  }
}
