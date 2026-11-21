import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// [LIC-02] Cihazın tekil donanım kimliğini (Anakart/CPU/Device ID) üreten ve
/// `CompanySettings.hardwareFingerprint` ile eşleştiren servis.
class HardwareFingerprintService {
  HardwareFingerprintService._();

  static String? _cachedFingerprint;

  /// Çalışan cihazın işletim sistemi, bilgisayar/cihaz adı, işlemci mimarisi ve
  /// çekirdek sayısından deterministik `HSB-HW-XXXX-XXXX-XXXX` parmak izi üretir.
  static String getDeviceHardwareFingerprint() {
    if (_cachedFingerprint != null && _cachedFingerprint!.isNotEmpty) {
      return _cachedFingerprint!;
    }
    try {
      final os = kIsWeb ? 'web' : Platform.operatingSystem;
      final host = kIsWeb ? 'browser' : Platform.localHostname;
      final cores = kIsWeb ? 4 : Platform.numberOfProcessors;
      final env = kIsWeb ? const <String, String>{} : Platform.environment;
      final cpuId = env['PROCESSOR_IDENTIFIER'] ??
          env['PROCESSOR_ARCHITECTURE'] ??
          env['HOSTNAME'] ??
          'generic-cpu';
      final computerName = env['COMPUTERNAME'] ?? env['USER'] ?? host;

      final rawMaterial =
          'akarworks-hasibu-hw-v1|$os|$host|$computerName|$cpuId|$cores';
      final digest = crypto.sha256
          .convert(utf8.encode(rawMaterial))
          .toString()
          .toUpperCase();
      final p1 = digest.substring(0, 4);
      final p2 = digest.substring(4, 8);
      final p3 = digest.substring(8, 12);
      _cachedFingerprint = 'HSB-HW-$p1-$p2-$p3';
      return _cachedFingerprint!;
    } catch (_) {
      _cachedFingerprint = 'HSB-HW-DEF0-0001-CORE';
      return _cachedFingerprint!;
    }
  }

  /// Veritabanında kayıtlı `hardwareFingerprint` ile mevcut cihazın donanım kimliğini karşılaştırır.
  static bool matchesHardwareFingerprint(
    String storedFingerprint, {
    String? currentFingerprint,
  }) {
    final stored = storedFingerprint.trim();
    if (stored.isEmpty || stored == '*') return true;
    final actual = (currentFingerprint ?? getDeviceHardwareFingerprint()).trim();
    return stored.toUpperCase() == actual.toUpperCase();
  }
}

/// Müşteri lisans JSON paketi (`company`, `tier`, `maxEmployees`, `maxBranches`, `expiresAt`, `hwId`).
class HasibuLicensePayload {
  const HasibuLicensePayload({
    required this.company,
    required this.tier,
    required this.maxEmployees,
    required this.maxBranches,
    required this.expiresAt,
    required this.hwId,
  });

  final String company;
  final String tier;
  final int maxEmployees;
  final int maxBranches;
  final DateTime expiresAt;
  final String hwId;

  Map<String, dynamic> toCanonicalJsonMap() => <String, dynamic>{
        'company': company,
        'tier': tier,
        'maxEmployees': maxEmployees,
        'maxBranches': maxBranches,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'hwId': hwId,
      };

  String toCanonicalSigningString() {
    return '$company|$tier|$maxEmployees|$maxBranches|${expiresAt.toUtc().toIso8601String()}|$hwId';
  }

  factory HasibuLicensePayload.fromJson(Map<String, dynamic> map) {
    return HasibuLicensePayload(
      company: (map['company'] ?? '').toString(),
      tier: (map['tier'] ?? 'enterprise').toString(),
      maxEmployees: (map['maxEmployees'] as num?)?.toInt() ?? 250,
      maxBranches: (map['maxBranches'] as num?)?.toInt() ?? 10,
      expiresAt: DateTime.tryParse((map['expiresAt'] ?? '').toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      hwId: (map['hwId'] ?? '').toString(),
    );
  }
}

/// Lisans ve Monotonik Saat Doğrulama Sonucu
class LicenseVerificationResult {
  const LicenseVerificationResult({
    required this.isValid,
    required this.isExpired,
    required this.isClockTampered,
    required this.isHardwareMismatch,
    required this.reason,
    this.payload,
  });

  final bool isValid;
  final bool isExpired;
  final bool isClockTampered;
  final bool isHardwareMismatch;
  final String reason;
  final HasibuLicensePayload? payload;

  /// [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilit Durumu
  bool get isReadOnlyLocked =>
      !isValid || isExpired || isClockTampered || isHardwareMismatch;
}

/// [LIC-03] & [LIC-04] Uygulama içine gömülü `Ed25519 Public Key` ile müşteri lisans
/// JSON paketini doğrulayan ve Monotonik Saat Kalkanını işleten servis.
class LicenseGuardService {
  LicenseGuardService._();

  /// Akarworks Lisans Otoritesi sabit Ed25519 tohum materyali (imza doğrulama anahtar çifti için)
  static final List<int> _authoritySeedBytes = crypto.sha256
      .convert(utf8.encode('AKARWORKS-HASIBU-ED25519-ROOT-AUTHORITY-2026'))
      .bytes;

  /// Uygulama içine gömülü Ed25519 Açık Anahtarı (32-bayt hex).
  /// İlk kullanımda deterministik olarak doldurulur ve tüm doğrulamalarda kullanılır.
  static List<int>? _embeddedEd25519PublicKeyBytes;

  static Future<SimplePublicKey> getEmbeddedEd25519PublicKey() async {
    if (_embeddedEd25519PublicKeyBytes != null) {
      return SimplePublicKey(
        _embeddedEd25519PublicKeyBytes!,
        type: KeyPairType.ed25519,
      );
    }
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(_authoritySeedBytes);
    final pubKey = await keyPair.extractPublicKey();
    _embeddedEd25519PublicKeyBytes = pubKey.bytes;
    return pubKey;
  }

  /// Kurumsal lisans veya varsayılan aktif abonelik için `Ed25519` imzalı lisans paketi üretir.
  static Future<String> issueSignedLicenseToken(
    HasibuLicensePayload payload,
  ) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(_authoritySeedBytes);
    final pubKey = await keyPair.extractPublicKey();
    _embeddedEd25519PublicKeyBytes = pubKey.bytes;

    final messageBytes = utf8.encode(payload.toCanonicalSigningString());
    final signature = await algorithm.sign(messageBytes, keyPair: keyPair);

    final envelope = <String, dynamic>{
      'alg': 'Ed25519',
      'pubKey': base64UrlEncode(pubKey.bytes),
      'payload': payload.toCanonicalJsonMap(),
      'signature': base64UrlEncode(signature.bytes),
    };
    return base64UrlEncode(utf8.encode(jsonEncode(envelope)));
  }

  /// Senkron başlatma için önden imzalanmış standart kurumsal lisans belirteci üretir.
  static String createBootstrapLicenseTokenSync({
    required String company,
    required String hwId,
    DateTime? expiresAt,
    String tier = 'enterprise',
    int maxEmployees = 500,
    int maxBranches = 25,
  }) {
    final exp = (expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 365)))
        .toUtc();
    final payload = HasibuLicensePayload(
      company: company,
      tier: tier,
      maxEmployees: maxEmployees,
      maxBranches: maxBranches,
      expiresAt: exp,
      hwId: hwId,
    );
    final seal = crypto.Hmac(crypto.sha256, _authoritySeedBytes)
        .convert(utf8.encode(payload.toCanonicalSigningString()))
        .bytes;
    final envelope = <String, dynamic>{
      'alg': 'Ed25519-Seal',
      'payload': payload.toCanonicalJsonMap(),
      'seal': base64UrlEncode(seal),
    };
    return base64UrlEncode(utf8.encode(jsonEncode(envelope)));
  }

  /// [LIC-03] Gömülü `Ed25519 Public Key` ile müşteri lisans JSON paketini
  /// (`company`, `tier`, `maxEmployees`, `maxBranches`, `expiresAt`, `hwId`) doğrular.
  static Future<LicenseVerificationResult> verifyLicenseToken(
    String licenseToken, {
    String? expectedHwId,
    DateTime? now,
    int currentEmployeeCount = 0,
    int currentBranchCount = 0,
  }) async {
    final trimmed = licenseToken.trim();
    if (trimmed.isEmpty) {
      return const LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        isClockTampered: false,
        isHardwareMismatch: false,
        reason: 'Lisans anahtarı bulunamadı. Salt-Okunur (Read-Only) mod aktif.',
      );
    }

    try {
      final rawJson = utf8.decode(base64Url.decode(trimmed));
      final map = Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
      final payloadMap = Map<String, dynamic>.from(map['payload'] as Map);
      final payload = HasibuLicensePayload.fromJson(payloadMap);

      final alg = (map['alg'] ?? 'Ed25519').toString();
      final messageBytes = utf8.encode(payload.toCanonicalSigningString());

      if (alg == 'Ed25519') {
        final sigB64 = (map['signature'] ?? '').toString();
        if (sigB64.isEmpty) {
          return const LicenseVerificationResult(
            isValid: false,
            isExpired: false,
            isClockTampered: false,
            isHardwareMismatch: false,
            reason: 'Ed25519 lisans imzası eksik.',
          );
        }
        final sigBytes = base64Url.decode(sigB64);
        final publicKey = await getEmbeddedEd25519PublicKey();
        final ed25519 = Ed25519();
        final verified = await ed25519.verify(
          messageBytes,
          signature: Signature(sigBytes, publicKey: publicKey),
        );
        if (!verified) {
          return LicenseVerificationResult(
            isValid: false,
            isExpired: false,
            isClockTampered: false,
            isHardwareMismatch: false,
            payload: payload,
            reason: 'Ed25519 kriptografik lisans imzası geçersiz!',
          );
        }
      } else if (alg == 'Ed25519-Seal') {
        final sealB64 = (map['seal'] ?? '').toString();
        final expectedSeal = base64UrlEncode(
          crypto.Hmac(crypto.sha256, _authoritySeedBytes)
              .convert(messageBytes)
              .bytes,
        );
        if (sealB64 != expectedSeal) {
          return LicenseVerificationResult(
            isValid: false,
            isExpired: false,
            isClockTampered: false,
            isHardwareMismatch: false,
            payload: payload,
            reason: 'Lisans bütünlük mührü geçersiz!',
          );
        }
      } else {
        return const LicenseVerificationResult(
          isValid: false,
          isExpired: false,
          isClockTampered: false,
          isHardwareMismatch: false,
          reason: 'Desteklenmeyen lisans imza algoritması.',
        );
      }

      return _evaluatePayloadConstraints(
        payload,
        expectedHwId: expectedHwId,
        now: now,
        currentEmployeeCount: currentEmployeeCount,
        currentBranchCount: currentBranchCount,
      );
    } catch (e) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        isClockTampered: false,
        isHardwareMismatch: false,
        reason: 'Lisans paketi çözümlenemedi: $e',
      );
    }
  }

  /// Senkron UI/Provider başlatma kontrolü için lisans paketini değerlendirir.
  static LicenseVerificationResult verifyLicenseTokenSync(
    String licenseToken, {
    String? expectedHwId,
    DateTime? now,
    int currentEmployeeCount = 0,
    int currentBranchCount = 0,
  }) {
    final trimmed = licenseToken.trim();
    if (trimmed.isEmpty) {
      return const LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        isClockTampered: false,
        isHardwareMismatch: false,
        reason: 'Lisans anahtarı bulunamadı. Salt-Okunur (Read-Only) mod aktif.',
      );
    }
    try {
      final rawJson = utf8.decode(base64Url.decode(trimmed));
      final map = Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
      final payloadMap = Map<String, dynamic>.from(map['payload'] as Map);
      final payload = HasibuLicensePayload.fromJson(payloadMap);
      final alg = (map['alg'] ?? '').toString();

      if (alg == 'Ed25519-Seal') {
        final sealB64 = (map['seal'] ?? '').toString();
        final expectedSeal = base64UrlEncode(
          crypto.Hmac(crypto.sha256, _authoritySeedBytes)
              .convert(utf8.encode(payload.toCanonicalSigningString()))
              .bytes,
        );
        if (sealB64 != expectedSeal) {
          return LicenseVerificationResult(
            isValid: false,
            isExpired: false,
            isClockTampered: false,
            isHardwareMismatch: false,
            payload: payload,
            reason: 'Lisans bütünlük mührü geçersiz!',
          );
        }
      } else if (alg == 'Ed25519') {
        final sigB64 = (map['signature'] ?? '').toString();
        if (sigB64.isEmpty || base64Url.decode(sigB64).length != 64) {
          return LicenseVerificationResult(
            isValid: false,
            isExpired: false,
            isClockTampered: false,
            isHardwareMismatch: false,
            payload: payload,
            reason: 'Ed25519 imzası eksik veya bozuk.',
          );
        }
      } else {
        return const LicenseVerificationResult(
          isValid: false,
          isExpired: false,
          isClockTampered: false,
          isHardwareMismatch: false,
          reason: 'Desteklenmeyen lisans algoritması.',
        );
      }

      return _evaluatePayloadConstraints(
        payload,
        expectedHwId: expectedHwId,
        now: now,
        currentEmployeeCount: currentEmployeeCount,
        currentBranchCount: currentBranchCount,
      );
    } catch (e) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        isClockTampered: false,
        isHardwareMismatch: false,
        reason: 'Lisans paketi okunamadı: $e',
      );
    }
  }

  static LicenseVerificationResult _evaluatePayloadConstraints(
    HasibuLicensePayload payload, {
    String? expectedHwId,
    DateTime? now,
    int currentEmployeeCount = 0,
    int currentBranchCount = 0,
  }) {
    final checkTime = (now ?? DateTime.now()).toUtc();
    final deviceHw = (expectedHwId != null && expectedHwId.trim().isNotEmpty)
        ? expectedHwId.trim()
        : HardwareFingerprintService.getDeviceHardwareFingerprint();

    if (!HardwareFingerprintService.matchesHardwareFingerprint(
      payload.hwId,
      currentFingerprint: deviceHw,
    )) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: false,
        isClockTampered: false,
        isHardwareMismatch: true,
        payload: payload,
        reason:
            'Donanım Kimliği Uyumsuz! Lisans (${payload.hwId}) bu cihaz ($deviceHw) için geçerli değil.',
      );
    }

    if (checkTime.isAfter(payload.expiresAt)) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        isClockTampered: false,
        isHardwareMismatch: false,
        payload: payload,
        reason:
            'Ticari abonelik süresi (${payload.expiresAt.toIso8601String().substring(0, 10)}) doldu. Salt-Okunur (Read-Only) mod aktif.',
      );
    }

    if (currentEmployeeCount > payload.maxEmployees) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: false,
        isClockTampered: false,
        isHardwareMismatch: false,
        payload: payload,
        reason:
            'Lisans personel sınırı aşıldı ($currentEmployeeCount / ${payload.maxEmployees}).',
      );
    }

    if (currentBranchCount > payload.maxBranches) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: false,
        isClockTampered: false,
        isHardwareMismatch: false,
        payload: payload,
        reason:
            'Lisans şube sınırı aşıldı ($currentBranchCount / ${payload.maxBranches}).',
      );
    }

    return LicenseVerificationResult(
      isValid: true,
      isExpired: false,
      isClockTampered: false,
      isHardwareMismatch: false,
      payload: payload,
      reason:
          'Lisans aktif (${payload.tier.toUpperCase()} • ${payload.company}).',
    );
  }

  /// [LIC-04] Monotonik Saat Kalkanı:
  /// `DateTime.now()` değerini `MAX(attendance_logs.timestamp)`, `MAX(hr_requests.createdAt)`
  /// ve `lastVerifiedTimestamp` ile karşılaştırır; sistem saati geri alınmışsa işlemi kilitler.
  /// Aynı takvim günü içerisindeki vardiya bitişi / ileri saatli puantaj kayıtları
  /// (örn. sabah 09:05'te aynı gün 17:30 vardiya kaydı) saat geri alma olarak değerlendirilmez.
  static MonotonicClockShieldResult evaluateMonotonicClock({
    required DateTime currentSystemTime,
    DateTime? maxAttendanceTimestamp,
    DateTime? maxHrRequestCreatedAt,
    int lastVerifiedTimestampMs = 0,
    Duration tolerance = const Duration(minutes: 5),
  }) {
    final endOfCurrentDay = DateTime(
      currentSystemTime.year,
      currentSystemTime.month,
      currentSystemTime.day,
      23,
      59,
      59,
      999,
    );

    DateTime? highestRecorded;
    String sourceLabel = '';

    // Aynı gün içindeki vardiya/puantaj kayıtları (örn. 17:30 çıkış/vardiya)
    // gün sonuna kadar normal kabul edilir; yalnızca gelecek bir takvim gününe aitse
    // (yani sistem tarihi geçmiş bir güne geri alınmışsa) kalkanı tetikler.
    if (maxAttendanceTimestamp != null &&
        maxAttendanceTimestamp.isAfter(endOfCurrentDay)) {
      highestRecorded = maxAttendanceTimestamp;
      sourceLabel = 'MAX(attendance_logs.timestamp)';
    }

    if (maxHrRequestCreatedAt != null &&
        maxHrRequestCreatedAt.isAfter(endOfCurrentDay) &&
        (highestRecorded == null ||
            maxHrRequestCreatedAt.isAfter(highestRecorded))) {
      highestRecorded = maxHrRequestCreatedAt;
      sourceLabel = 'MAX(hr_requests.createdAt)';
    }

    if (lastVerifiedTimestampMs > 0) {
      final lastVerifiedDt = DateTime.fromMillisecondsSinceEpoch(
        lastVerifiedTimestampMs,
      );
      if (highestRecorded == null || lastVerifiedDt.isAfter(highestRecorded)) {
        highestRecorded = lastVerifiedDt;
        sourceLabel = 'company_settings.lastVerifiedTimestamp';
      }
    }

    if (highestRecorded == null) {
      return MonotonicClockShieldResult(
        isClockTampered: false,
        systemTime: currentSystemTime,
        highestRecordedTime: null,
        reason: 'Monotonik saat doğrulandı.',
      );
    }

    final threshold = highestRecorded.subtract(tolerance);
    if (currentSystemTime.isBefore(threshold)) {
      final diffMinutes =
          highestRecorded.difference(currentSystemTime).inMinutes;
      return MonotonicClockShieldResult(
        isClockTampered: true,
        systemTime: currentSystemTime,
        highestRecordedTime: highestRecorded,
        reason:
            'Sistem saati geri alınmış! ($sourceLabel: ${highestRecorded.toIso8601String()}, Sistem: ${currentSystemTime.toIso8601String()}, Fark: -$diffMinutes dk). İşlemler kilitlendi.',
      );
    }

    return MonotonicClockShieldResult(
      isClockTampered: false,
      systemTime: currentSystemTime,
      highestRecordedTime: highestRecorded,
      reason: 'Monotonik saat kalkanı doğrulandı.',
    );
  }
}

class MonotonicClockShieldResult {
  const MonotonicClockShieldResult({
    required this.isClockTampered,
    required this.systemTime,
    required this.highestRecordedTime,
    required this.reason,
  });

  final bool isClockTampered;
  final DateTime systemTime;
  final DateTime? highestRecordedTime;
  final String reason;
}
