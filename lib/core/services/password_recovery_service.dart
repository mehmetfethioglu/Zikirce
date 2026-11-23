import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/pdks/domain/pdks_models.dart';

/// Gmail REST API gönderim sonucu hata kodları.
enum PasswordResetEmailErrorCode {
  none,
  unauthorized,
  insufficientScope,
  apiDisabled,
  networkOrOther,
}

@immutable
class PasswordResetEmailResult {
  final bool success;
  final PasswordResetEmailErrorCode errorCode;
  final String message;

  const PasswordResetEmailResult({
    required this.success,
    this.errorCode = PasswordResetEmailErrorCode.none,
    required this.message,
  });
}

enum RecoverableAccountKind {
  rootAdmin,
  appUser,
  employee,
}

@immutable
class PasswordRecoveryAccountLookup {
  final bool found;
  final bool hasCompanyGmail;
  final String normalizedUsername;
  final String displayName;
  final RecoverableAccountKind? kind;
  final UserRole? resolvedRole;
  final String companyGmail;
  final String maskedCompanyGmail;
  final String? errorMessage;

  const PasswordRecoveryAccountLookup({
    required this.found,
    this.hasCompanyGmail = false,
    this.normalizedUsername = '',
    this.displayName = '',
    this.kind,
    this.resolvedRole,
    this.companyGmail = '',
    this.maskedCompanyGmail = '',
    this.errorMessage,
  });
}

@immutable
class PasswordRecoverySendOutcome {
  final bool success;
  final bool canUseGoogleIdentityFallback;
  final String maskedEmail;
  final int expiresInMinutes;
  final String message;

  const PasswordRecoverySendOutcome({
    required this.success,
    this.canUseGoogleIdentityFallback = false,
    this.maskedEmail = '',
    this.expiresInMinutes = 10,
    required this.message,
  });
}

@immutable
class PasswordRecoveryVerifyOutcome {
  final bool success;
  final String maskedEmail;
  final String message;

  const PasswordRecoveryVerifyOutcome({
    required this.success,
    this.maskedEmail = '',
    required this.message,
  });
}

/// Şifre kurtarma doğrulama e-postası gönderim sözleşmesi (DIP).
abstract interface class PasswordRecoveryEmailGateway {
  Future<PasswordResetEmailResult> sendVerificationCodeEmail({
    required String accessToken,
    required String recipientEmail,
    required String companyName,
    required String targetUsername,
    required String verificationCode,
    required int expiresInMinutes,
  });
}

/// Gmail REST API (`users.messages.send`) üzerinden RFC 2822 UTF-8 MIME doğrulama e-postası gönderir.
class GmailApiPasswordRecoveryGateway implements PasswordRecoveryEmailGateway {
  static const String _gmailSendEndpoint =
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send';

  final Dio _dio;

  GmailApiPasswordRecoveryGateway({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  @override
  Future<PasswordResetEmailResult> sendVerificationCodeEmail({
    required String accessToken,
    required String recipientEmail,
    required String companyName,
    required String targetUsername,
    required String verificationCode,
    required int expiresInMinutes,
  }) async {
    final token = accessToken.trim();
    final recipient = recipientEmail.trim();
    if (token.isEmpty) {
      return const PasswordResetEmailResult(
        success: false,
        errorCode: PasswordResetEmailErrorCode.unauthorized,
        message: 'Google OAuth erişim anahtarı bulunamadı.',
      );
    }
    if (recipient.isEmpty || !recipient.contains('@')) {
      return const PasswordResetEmailResult(
        success: false,
        errorCode: PasswordResetEmailErrorCode.networkOrOther,
        message: 'Geçerli bir şirket Gmail adresi bulunamadı.',
      );
    }

    final safeCompany =
        companyName.trim().isEmpty ? 'Hasibu' : companyName.trim();
    final subjectText = '[$safeCompany] Hasibu Parola Sıfırlama Doğrulama Kodu';
    final encodedSubject = '=?UTF-8?B?${base64Encode(utf8.encode(subjectText))}?=';

    final bodyText = [
      'Merhaba,',
      '',
      '$safeCompany Hasibu hesabınız için parola sıfırlama talebi oluşturuldu.',
      '',
      'Kullanıcı Adı / Kart No: $targetUsername',
      'Doğrulama Kodu: $verificationCode',
      'Geçerlilik Süresi: $expiresInMinutes dakika',
      '',
      'Güvenliğiniz için bu kodu yalnızca Hasibu parola sıfırlama penceresine girin.',
      'Bu işlemi siz başlatmadıysanız bu e-postayı dikkate almayın.',
    ].join('\r\n');

    final bodyBase64 = base64Encode(utf8.encode(bodyText));
    final mime = [
      'To: $recipient',
      'Subject: $encodedSubject',
      'MIME-Version: 1.0',
      'Content-Type: text/plain; charset="UTF-8"',
      'Content-Transfer-Encoding: base64',
      '',
      bodyBase64,
    ].join('\r\n');

    final rawBase64Url = base64UrlEncode(utf8.encode(mime));

    try {
      final response = await _dio.post<dynamic>(
        _gmailSendEndpoint,
        data: <String, dynamic>{'raw': rawBase64Url},
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return PasswordResetEmailResult(
          success: true,
          message: 'Doğrulama kodu şirket Gmail hesabına ($recipient) gönderildi.',
        );
      }
      return PasswordResetEmailResult(
        success: false,
        errorCode: PasswordResetEmailErrorCode.networkOrOther,
        message: 'Gmail API beklenmeyen yanıt kodu döndü ($status).',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final bodyStr = e.response?.data?.toString() ?? e.message ?? '';
      final lower = bodyStr.toLowerCase();

      if (status == 401) {
        return const PasswordResetEmailResult(
          success: false,
          errorCode: PasswordResetEmailErrorCode.unauthorized,
          message: 'Google OAuth oturum süresi dolmuş veya geçersiz.',
        );
      }
      if (status == 403 &&
          (lower.contains('service_disabled') ||
              lower.contains('accessnotconfigured') ||
              lower.contains('gmail api has not been used'))) {
        return const PasswordResetEmailResult(
          success: false,
          errorCode: PasswordResetEmailErrorCode.apiDisabled,
          message:
              'Google Cloud projesinde Gmail API etkin değil. Google hesabıyla doğrudan sahiplik doğrulaması kullanabilirsiniz.',
        );
      }
      if (status == 403 &&
          (lower.contains('insufficientpermissions') ||
              lower.contains('access_token_scope_insufficient') ||
              lower.contains('insufficient'))) {
        return const PasswordResetEmailResult(
          success: false,
          errorCode: PasswordResetEmailErrorCode.insufficientScope,
          message:
              'Gmail gönderim izni (gmail.send) verilmedi. Yetki vererek tekrar deneyebilir veya Google hesabıyla doğrudan doğrulayabilirsiniz.',
        );
      }
      debugPrint('GmailApiPasswordRecoveryGateway: Dio hatası ($status): $e');
      return PasswordResetEmailResult(
        success: false,
        errorCode: PasswordResetEmailErrorCode.networkOrOther,
        message: 'E-posta gönderilemedi: ${e.message ?? 'Ağ veya sunucu hatası'}',
      );
    } catch (e) {
      debugPrint('GmailApiPasswordRecoveryGateway: genel hata: $e');
      return PasswordResetEmailResult(
        success: false,
        errorCode: PasswordResetEmailErrorCode.networkOrOther,
        message: 'E-posta gönderilemedi: $e',
      );
    }
  }
}

class _ActiveRecoveryChallenge {
  final String username;
  final UserRole role;
  final String targetEmail;
  final String salt;
  final String codeHash;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool googleOAuthVerified;
  int remainingAttempts;

  _ActiveRecoveryChallenge({
    required this.username,
    required this.role,
    required this.targetEmail,
    required this.salt,
    required this.codeHash,
    required this.issuedAt,
    required this.expiresAt,
    this.googleOAuthVerified = false,
    this.remainingAttempts = 5,
  });
}

@immutable
class RecoveryChallengeCreation {
  final bool ok;
  final String code;
  final int waitSeconds;
  final String message;

  const RecoveryChallengeCreation({
    required this.ok,
    this.code = '',
    this.waitSeconds = 0,
    this.message = '',
  });
}

@immutable
class RecoveryVerificationCheck {
  final bool verified;
  final String message;

  const RecoveryVerificationCheck({
    required this.verified,
    required this.message,
  });
}

/// 6 haneli tek kullanımlık OTP doğrulama ve Google OAuth canlı sahiplik doğrulama servisi.
class PasswordRecoveryService {
  static const String gmailSendScope =
      'https://www.googleapis.com/auth/gmail.send';
  static const Duration codeValidity = Duration(minutes: 10);
  static const Duration resendCooldown = Duration(seconds: 30);
  static const int maxVerifyAttempts = 5;

  final PasswordRecoveryEmailGateway _emailGateway;
  final DateTime Function() _clock;
  final String Function() _codeGenerator;
  _ActiveRecoveryChallenge? _activeChallenge;

  PasswordRecoveryService({
    required PasswordRecoveryEmailGateway emailGateway,
    DateTime Function()? clock,
    String Function()? codeGenerator,
  })  : _emailGateway = emailGateway,
        _clock = clock ?? DateTime.now,
        _codeGenerator = codeGenerator ?? _defaultGenerateSixDigitCode;

  static String _defaultGenerateSixDigitCode() {
    final rng = Random.secure();
    final value = rng.nextInt(900000) + 100000;
    return value.toString();
  }

  /// E-posta adresini kullanıcı arayüzünde gizlilik dostu şekilde maskeler.
  static String maskEmail(String email) {
    final clean = email.trim();
    final atIdx = clean.indexOf('@');
    if (atIdx <= 0 || atIdx == clean.length - 1) return clean;
    final local = clean.substring(0, atIdx);
    final domain = clean.substring(atIdx + 1);
    if (local.length == 1) {
      return '*@$domain';
    }
    if (local.length == 2) {
      return '${local[0]}*@$domain';
    }
    if (local.length == 3) {
      return '${local[0]}**@$domain';
    }
    return '${local.substring(0, 2)}***${local[local.length - 1]}@$domain';
  }

  static String _hashCode(String salt, String code) {
    final digest = crypto.sha256.convert(utf8.encode('$salt|${code.trim()}'));
    return digest.toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    final ab = utf8.encode(a);
    final bb = utf8.encode(b);
    if (ab.length != bb.length) return false;
    var diff = 0;
    for (var i = 0; i < ab.length; i++) {
      diff |= ab[i] ^ bb[i];
    }
    return diff == 0;
  }

  RecoveryChallengeCreation createChallenge({
    required String username,
    required UserRole role,
    required String targetEmail,
    bool ignoreCooldown = false,
  }) {
    final now = _clock();
    final cleanUser = username.trim().toLowerCase();
    final current = _activeChallenge;
    if (!ignoreCooldown &&
        current != null &&
        !current.googleOAuthVerified &&
        current.username == cleanUser &&
        current.role == role) {
      final elapsed = now.difference(current.issuedAt);
      if (elapsed < resendCooldown) {
        final waitSec = (resendCooldown - elapsed).inSeconds.clamp(1, 30);
        return RecoveryChallengeCreation(
          ok: false,
          waitSeconds: waitSec,
          message:
              'Yeni doğrulama kodu göndermek için lütfen $waitSec saniye bekleyin.',
        );
      }
    }

    final code = _codeGenerator().trim();
    final rng = Random.secure();
    final saltBytes = List<int>.generate(12, (_) => rng.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    _activeChallenge = _ActiveRecoveryChallenge(
      username: cleanUser,
      role: role,
      targetEmail: targetEmail.trim().toLowerCase(),
      salt: salt,
      codeHash: _hashCode(salt, code),
      issuedAt: now,
      expiresAt: now.add(codeValidity),
      remainingAttempts: maxVerifyAttempts,
    );
    return RecoveryChallengeCreation(ok: true, code: code);
  }

  Future<PasswordResetEmailResult> sendChallengeEmail({
    required String accessToken,
    required String recipientEmail,
    required String companyName,
    required String targetUsername,
    required String verificationCode,
  }) {
    return _emailGateway.sendVerificationCodeEmail(
      accessToken: accessToken,
      recipientEmail: recipientEmail,
      companyName: companyName,
      targetUsername: targetUsername,
      verificationCode: verificationCode,
      expiresInMinutes: codeValidity.inMinutes,
    );
  }

  void markVerifiedByGoogleOAuth({
    required String username,
    required UserRole role,
    required String verifiedEmail,
  }) {
    final now = _clock();
    _activeChallenge = _ActiveRecoveryChallenge(
      username: username.trim().toLowerCase(),
      role: role,
      targetEmail: verifiedEmail.trim().toLowerCase(),
      salt: '',
      codeHash: '',
      issuedAt: now,
      expiresAt: now.add(codeValidity),
      googleOAuthVerified: true,
    );
  }

  RecoveryVerificationCheck verifyChallenge({
    required String username,
    required UserRole role,
    String? code,
  }) {
    final current = _activeChallenge;
    final cleanUser = username.trim().toLowerCase();
    if (current == null ||
        current.username != cleanUser ||
        current.role != role) {
      return const RecoveryVerificationCheck(
        verified: false,
        message:
            'Aktif bir doğrulama talebi bulunamadı. Lütfen önce doğrulama kodu gönderin veya Google ile doğrulayın.',
      );
    }

    final now = _clock();
    if (now.isAfter(current.expiresAt)) {
      _activeChallenge = null;
      return const RecoveryVerificationCheck(
        verified: false,
        message:
            'Doğrulama süreniz doldu (10 dakika). Lütfen yeni doğrulama kodu isteyin.',
      );
    }

    if (current.googleOAuthVerified) {
      return const RecoveryVerificationCheck(
        verified: true,
        message: 'Google hesap sahipliği doğrulandı.',
      );
    }

    final inputCode = (code ?? '').trim();
    if (inputCode.isEmpty) {
      return const RecoveryVerificationCheck(
        verified: false,
        message: 'Lütfen şirketin Gmail hesabına gönderilen 6 haneli kodu girin.',
      );
    }

    final inputHash = _hashCode(current.salt, inputCode);
    if (!_constantTimeEquals(inputHash, current.codeHash)) {
      current.remainingAttempts -= 1;
      if (current.remainingAttempts <= 0) {
        _activeChallenge = null;
        return const RecoveryVerificationCheck(
          verified: false,
          message:
              'Çok fazla hatalı doğrulama kodu girildi. Güvenlik nedeniyle talep iptal edildi; lütfen yeni kod gönderin.',
        );
      }
      return RecoveryVerificationCheck(
        verified: false,
        message:
            'Doğrulama kodu hatalı (Kalan deneme: ${current.remainingAttempts}).',
      );
    }

    return const RecoveryVerificationCheck(
      verified: true,
      message: 'Doğrulama kodu onaylandı.',
    );
  }

  void clearChallenge() {
    _activeChallenge = null;
  }
}
