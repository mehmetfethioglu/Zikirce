import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/pdks/domain/pdks_models.dart';
import '../database/hasibu_database.dart';
import '../security/hasibu_security_service.dart';

enum DriveSyncStage {
  idle,
  syncing,
  synced,
  offlineSaved,
  error,
}

@immutable
class GoogleTokenVerificationResult {
  final bool isValid;
  final String email;
  final String displayName;
  final String errorMessage;

  const GoogleTokenVerificationResult({
    required this.isValid,
    this.email = '',
    this.displayName = '',
    this.errorMessage = '',
  });
}

enum CloudEncryptionKeyMode {
  accountAuto('Otomatik (Aynı Google Hesabı)'),
  customPassphrase('Özel Bulut Şifreleme Parolası');

  final String label;
  const CloudEncryptionKeyMode(this.label);
}

@immutable
class BrowserGoogleSignInResult {
  final bool success;
  final String accessToken;
  final String refreshToken;
  final String email;
  final String displayName;
  final String message;
  final bool requiresUserLogin;
  final String? suggestedUsername;

  const BrowserGoogleSignInResult({
    required this.success,
    this.accessToken = '',
    this.refreshToken = '',
    this.email = '',
    this.displayName = '',
    required this.message,
    this.requiresUserLogin = false,
    this.suggestedUsername,
  });
}

@immutable
class DriveSyncStatus {
  final DriveSyncStage stage;
  final DateTime? lastSyncTime;
  final String lastDeviceName;
  final String? lastHash;
  final String connectedGmail;
  final String message;
  final bool isCloudApiVerified;
  final bool isDriveFolderMirrored;
  final String syncedFilePath;
  final int syncedBytes;
  final String cloudProfileId;
  final String lastOperation;
  final bool isDecryptionKeyMismatch;

  const DriveSyncStatus({
    this.stage = DriveSyncStage.idle,
    this.lastSyncTime,
    this.lastDeviceName = 'İşyeri Laptop (Merkez)',
    this.lastHash,
    this.connectedGmail = '',
    this.message = 'Senkronizasyona hazır',
    this.isCloudApiVerified = false,
    this.isDriveFolderMirrored = false,
    this.syncedFilePath = '',
    this.syncedBytes = 0,
    this.cloudProfileId = 'default',
    this.lastOperation = '',
    this.isDecryptionKeyMismatch = false,
  });

  bool get isTrulySynced =>
      stage == DriveSyncStage.synced &&
      (isCloudApiVerified || isDriveFolderMirrored);

  DriveSyncStatus copyWith({
    DriveSyncStage? stage,
    DateTime? lastSyncTime,
    String? lastDeviceName,
    String? lastHash,
    String? connectedGmail,
    String? message,
    bool? isCloudApiVerified,
    bool? isDriveFolderMirrored,
    String? syncedFilePath,
    int? syncedBytes,
    String? cloudProfileId,
    String? lastOperation,
    bool? isDecryptionKeyMismatch,
  }) {
    return DriveSyncStatus(
      stage: stage ?? this.stage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
      lastHash: lastHash ?? this.lastHash,
      connectedGmail: connectedGmail ?? this.connectedGmail,
      message: message ?? this.message,
      isCloudApiVerified: isCloudApiVerified ?? this.isCloudApiVerified,
      isDriveFolderMirrored:
          isDriveFolderMirrored ?? this.isDriveFolderMirrored,
      syncedFilePath: syncedFilePath ?? this.syncedFilePath,
      syncedBytes: syncedBytes ?? this.syncedBytes,
      cloudProfileId: cloudProfileId ?? this.cloudProfileId,
      lastOperation: lastOperation ?? this.lastOperation,
      isDecryptionKeyMismatch:
          isDecryptionKeyMismatch ?? this.isDecryptionKeyMismatch,
    );
  }
}

/// Aynı Gmail Google Drive hesabı veya yerel klasörde bulunan yedek profili / kasa slotu özeti.
@immutable
class CloudBackupProfileInfo {
  final String profileId;
  final String fileName;
  final String? remoteFileId;
  final DateTime? modifiedTime;
  final int sizeBytes;
  final String source;

  const CloudBackupProfileInfo({
    required this.profileId,
    required this.fileName,
    this.remoteFileId,
    this.modifiedTime,
    this.sizeBytes = 0,
    required this.source,
  });
}

/// Tek bir şube yüz okutma köprüsü cihaz kutusunun (`hasibu_branch_inbox_*.enc`) durumu.
@immutable
class BranchInboxDeviceStatus {
  final String deviceSlug;
  final int branchId;
  final String branchCode;
  final String branchName;
  final String deviceName;
  final String fileName;
  final String? remoteFileId;
  final DateTime? modifiedTime;
  final int logCount;
  final int newlyInsertedCount;
  final int syncedUsersCount;
  final String source;

  const BranchInboxDeviceStatus({
    required this.deviceSlug,
    required this.branchId,
    this.branchCode = '',
    this.branchName = '',
    this.deviceName = '',
    required this.fileName,
    this.remoteFileId,
    this.modifiedTime,
    this.logCount = 0,
    this.newlyInsertedCount = 0,
    this.syncedUsersCount = 0,
    this.source = 'Google Drive Bulut',
  });
}

/// Tüm şube cihaz kutularının Google Drive'dan okunup birleştirilme özeti.
@immutable
class BranchInboxPullResult {
  final List<BranchInboxDeviceStatus> devices;
  final int totalLogsRead;
  final int totalNewLogsInserted;
  final int totalUsersSynced;
  final List<String> warnings;

  const BranchInboxPullResult({
    this.devices = const <BranchInboxDeviceStatus>[],
    this.totalLogsRead = 0,
    this.totalNewLogsInserted = 0,
    this.totalUsersSynced = 0,
    this.warnings = const <String>[],
  });
}

class _MirrorWriteOutcome {
  final bool wroteDriveFolder;
  final String driveFilePath;
  final String localFilePath;
  final int bytesWritten;

  const _MirrorWriteOutcome({
    this.wroteDriveFolder = false,
    this.driveFilePath = '',
    this.localFilePath = '',
    this.bytesWritten = 0,
  });

  String get primaryPath =>
      wroteDriveFolder && driveFilePath.isNotEmpty ? driveFilePath : localFilePath;
}

/// Google Drive Bulut Yedekleme ve Cihazlar Arası Senkronizasyon Motoru.
/// [SYNC-01], [SYNC-02], [SYNC-03]:
/// - Açık JSON yerine `AES-256-GCM` şifreleme katmanı (`hasibu_sync.enc`) kullanılır.
/// - Yönetici (`hasibu_master_vault.enc`) ve Personel (`hasibu_portal_queue.enc`) paketleri izole edilir.
/// - OAuth belirteçleri ve Şirket Çalışma Alanı Anahtarı (Workspace Key) yalnızca `FlutterSecureStorage` içinde tutulur.
class GoogleDriveSyncService {
  static const String backupFileName = 'hasibu_sync.enc';
  static const String masterVaultFileName = 'hasibu_master_vault.enc';
  static const String portalQueueFileName = 'hasibu_portal_queue.enc';
  static const String branchInboxPrefix = 'hasibu_branch_inbox_';
  static const String _legacyBackupFileName = 'Hasibu_CloudSync_v1.json';

  static const Map<String, String> _turkishCharFoldMap = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };

  static String _foldAndSanitizeSlug(
    String? raw, {
    required String fallback,
    int maxLength = 32,
  }) {
    if (raw == null) return fallback;
    final buf = StringBuffer();
    for (final rune in raw.trim().runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_turkishCharFoldMap[ch] ?? ch);
    }
    var slug = buf
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    if (slug.length > maxLength) {
      slug = slug.substring(0, maxLength).replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    }
    return slug.isEmpty ? fallback : slug;
  }

  /// Aynı Gmail hesabı içinde farklı işletme / kullanıcı kasaları oluşturmak için
  /// profil kimliğini güvenli dosya adı ekine (`slug`) dönüştürür.
  static String normalizeCloudProfileId(String? raw) {
    final slug = _foldAndSanitizeSlug(raw, fallback: 'default', maxLength: 32);
    if (slug == 'default' || slug == 'varsayilan' || slug == 'ana') {
      return 'default';
    }
    return slug;
  }

  /// Şube/cihaz adını güvenli tek-alt-çizgili cihaz koduna (`slug`) dönüştürür (`__` ayırıcısını korur).
  static String normalizeDeviceSlug(String? raw) =>
      _foldAndSanitizeSlug(raw, fallback: 'device', maxLength: 40);

  static String branchInboxFileNameForDevice({
    required String deviceSlug,
    String? profileId,
  }) {
    final cleanProfile = normalizeCloudProfileId(profileId);
    final cleanSlug = normalizeDeviceSlug(deviceSlug);
    return cleanProfile == 'default'
        ? '$branchInboxPrefix$cleanSlug.enc'
        : '$branchInboxPrefix${cleanProfile}__$cleanSlug.enc';
  }

  static String? parseBranchInboxDeviceSlug(
    String fileName, {
    String? profileId,
  }) {
    final clean = fileName.trim();
    if (!clean.startsWith(branchInboxPrefix) || !clean.endsWith('.enc')) {
      return null;
    }
    final body = clean.substring(branchInboxPrefix.length, clean.length - 4);
    if (body.isEmpty) return null;
    final expectedProfile = normalizeCloudProfileId(profileId);
    final sepIdx = body.indexOf('__');
    if (sepIdx >= 0) {
      final fileProfile = normalizeCloudProfileId(body.substring(0, sepIdx));
      final rawSlug = body.substring(sepIdx + 2);
      if (fileProfile != expectedProfile || rawSlug.isEmpty) {
        return null;
      }
      return normalizeDeviceSlug(rawSlug);
    }
    if (expectedProfile != 'default') {
      return null;
    }
    return normalizeDeviceSlug(body);
  }

  static String backupFileNameForProfile(String? profileId) {
    final slug = normalizeCloudProfileId(profileId);
    return slug == 'default' ? backupFileName : 'hasibu_sync_$slug.enc';
  }

  static String masterVaultFileNameForProfile(String? profileId) {
    final slug = normalizeCloudProfileId(profileId);
    return slug == 'default'
        ? masterVaultFileName
        : 'hasibu_master_vault_$slug.enc';
  }

  static String portalQueueFileNameForProfile(String? profileId) {
    final slug = normalizeCloudProfileId(profileId);
    return slug == 'default'
        ? portalQueueFileName
        : 'hasibu_portal_queue_$slug.enc';
  }

  static String? parseProfileIdFromFileName(String fileName) {
    final clean = fileName.trim();
    if (clean == backupFileName) return 'default';
    final match = RegExp(r'^hasibu_sync_([a-z0-9_-]+)\.enc$').firstMatch(clean);
    if (match != null) {
      return normalizeCloudProfileId(match.group(1));
    }
    return null;
  }
  static const String _driveFilesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';
  static const String _googleUserInfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';
  static const String _googleDriveAboutEndpoint =
      'https://www.googleapis.com/drive/v3/about?fields=user';
  static const String _googleTokenEndpoint =
      'https://oauth2.googleapis.com/token';

  static const int preferredLoopbackPort = 43821;
  static const String defaultIhasibuClientId = String.fromEnvironment(
    'HASIBU_GOOGLE_CLIENT_ID',
    defaultValue:
        '489201025131-sbm03iptselfqu4peaaoq02b2vieki5p.apps.googleusercontent.com',
  );
  static const String defaultIhasibuWebClientId = String.fromEnvironment(
    'HASIBU_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '489201025131-psj7ukl89v09oeev4dj77lskkktrs1l3.apps.googleusercontent.com',
  );
  static const String defaultIhasibuIosClientId = String.fromEnvironment(
    'HASIBU_GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '489201025131-p0vi3e2bpvdlrgaen2l20ron7ik544de.apps.googleusercontent.com',
  );
  static const String _compileTimeOAuthClientSecret = String.fromEnvironment(
    'HASIBU_GOOGLE_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String _kAccessToken = 'hasibu_gdrive_access_token';
  static const String _kRefreshToken = 'hasibu_gdrive_refresh_token';
  static const String _kWorkspaceKey = 'hasibu_workspace_sync_key_v1';
  static const String _kWorkspaceKeyMode = 'hasibu_workspace_key_mode_v1';
  static const String _kOAuthClientId = 'hasibu_google_oauth_client_id';
  static const String _kOAuthClientSecret = 'hasibu_google_oauth_client_secret';

  static String _generatePkceCodeVerifier() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  static String _generatePkceCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  final HasibuDatabase db;
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  DateTime _lastSyncAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastPayloadHash;
  DriveSyncStatus? _lastCachedStatus;
  String? _lastSyncWarning;
  Future<String?> Function()? _mobileSilentRefreshCallback;
  final Map<String, String> _processedBranchInboxSignatures =
      <String, String>{};
  final Map<String, BranchInboxDeviceStatus> _cachedBranchInboxStatuses =
      <String, BranchInboxDeviceStatus>{};

  /// Yakalanan son senkronizasyon uyarı mesajı
  String? get lastSyncWarning => _lastSyncWarning;

  /// Mobil platformda (`google_sign_in`) sessiz token yenileme geri çağrısını bağlar.
  void setMobileTokenRefresher(Future<String?> Function()? cb) {
    _mobileSilentRefreshCallback = cb;
  }

  GoogleDriveSyncService({
    required this.db,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  /// [SYNC-03] OAuth belirteçlerini ve varsa Şirket Çalışma Alanı Anahtarını güvenli depoda saklar.
  Future<void> saveOAuthTokens({
    required String accessToken,
    String? refreshToken,
    String? workspaceKey,
  }) async {
    await _secureStorage.write(key: _kAccessToken, value: accessToken.trim());
    await HasibuSecurityService.saveGoogleOAuthToken(accessToken.trim());
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await _secureStorage.write(
        key: _kRefreshToken,
        value: refreshToken.trim(),
      );
    }
    if (workspaceKey != null && workspaceKey.trim().isNotEmpty) {
      await saveWorkspaceKey(workspaceKey.trim());
    }
  }

  /// Aktif bulut yedek şifreleme modunu okur (varsayılan: Aynı Google Hesabıyla Otomatik).
  Future<CloudEncryptionKeyMode> getCloudEncryptionKeyMode() async {
    try {
      final mode = (await _secureStorage.read(key: _kWorkspaceKeyMode) ?? '')
          .trim();
      if (mode == 'custom') {
        return CloudEncryptionKeyMode.customPassphrase;
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
    return CloudEncryptionKeyMode.accountAuto;
  }

  /// [SYNC-03] Şirket Çalışma Alanı Anahtarını (`Workspace Key`) yerel veritabanında değil,
  /// `flutter_secure_storage` içinde saklar ve özel anahtar modunu etkinleştirir.
  Future<void> saveWorkspaceKey(String workspaceKey) async {
    final trimmed = workspaceKey.trim();
    if (trimmed.isEmpty) return;
    await HasibuSecurityService.saveWorkspaceSyncKey(trimmed);
    try {
      await _secureStorage.write(key: _kWorkspaceKey, value: trimmed);
      await _secureStorage.write(key: _kWorkspaceKeyMode, value: 'custom');
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: saveWorkspaceKey uyarısı: $e');
    }
  }

  /// Kısa ve akılda kalıcı bulut şifreleme parolasından 256-bit anahtar türetip kaydeder.
  Future<void> saveCloudSyncPassphrase(String passphrase) async {
    final trimmed = passphrase.trim();
    if (trimmed.isEmpty) return;
    final derived = HasibuSecurityService.derivePassphraseWorkspaceKey(trimmed);
    await saveWorkspaceKey(derived);
  }

  /// Aynı Google hesabına bağlı tüm cihazların manuel anahtar kopyalamadan
  /// otomatik anahtar türetme (`account_auto`) kullanmasını sağlar.
  Future<void> useAutomaticAccountEncryption() async {
    try {
      await _secureStorage.write(
        key: _kWorkspaceKeyMode,
        value: 'account_auto',
      );
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint(
        'GoogleDriveSyncService: useAutomaticAccountEncryption uyarısı: $e',
      );
    }
  }

  /// Aktif bulut şifreleme anahtarını ve zarf modunu (`account_auto` / `passphrase` / `workspace_key`) çözer.
  Future<({String key, String envelopeKeyMode})> resolveActiveEncryptionKey({
    String? profileId,
    String? gmailOverride,
  }) async {
    String mode = '';
    String storedRaw = '';
    try {
      mode = (await _secureStorage.read(key: _kWorkspaceKeyMode) ?? '').trim();
      storedRaw = (await _secureStorage.read(key: _kWorkspaceKey) ?? '').trim();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }

    final settings = db.getCompanySettings();
    final effectiveProfile =
        normalizeCloudProfileId(profileId ?? settings.cloudProfileId);
    final effectiveGmail = (gmailOverride ?? settings.syncGmailAccount).trim();

    if (mode == 'custom' && storedRaw.isNotEmpty) {
      return (key: storedRaw, envelopeKeyMode: 'passphrase');
    }
    if (effectiveGmail.isNotEmpty && mode != 'custom') {
      return (
        key: HasibuSecurityService.deriveAccountWorkspaceKey(
          googleEmail: effectiveGmail,
          cloudProfileId: effectiveProfile,
        ),
        envelopeKeyMode: 'account_auto',
      );
    }
    final fallback = storedRaw.isNotEmpty
        ? storedRaw
        : await HasibuSecurityService.getOrCreateWorkspaceSyncKey();
    return (key: fallback, envelopeKeyMode: 'workspace_key');
  }

  Future<String> getWorkspaceKey({String? profileId}) async {
    final resolved = await resolveActiveEncryptionKey(profileId: profileId);
    return resolved.key;
  }

  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _kAccessToken);
      if (token != null && token.trim().isNotEmpty) {
        return token.trim();
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: getAccessToken uyarısı: $e');
    }
    final fallback = await HasibuSecurityService.readGoogleOAuthToken();
    return fallback.isEmpty ? null : fallback;
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _kAccessToken);
      await _secureStorage.delete(key: _kRefreshToken);
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: clearTokens uyarısı: $e');
    }
    await HasibuSecurityService.saveGoogleOAuthToken('');
    _lastCachedStatus = null;
  }

  static ({String clientId, String clientSecret})? _parseGoogleClientJsonString(
    String raw,
  ) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final section = decoded['installed'] ?? decoded['web'] ?? decoded;
        if (section is Map<String, dynamic>) {
          final cid = (section['client_id'] ?? '').toString().trim();
          final csec = (section['client_secret'] ?? '').toString().trim();
          if (cid.isNotEmpty || csec.isNotEmpty) {
            return (clientId: cid, clientSecret: csec);
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveSyncService: _parseGoogleClientJsonString ayrıştırma uyarısı: $e');
      return null;
    }
    return null;
  }

  /// Belirtilen dizinlerdeki `client_secret*.json` dosyalarından `expectedClientId` ile
  /// eşleşen (veya filtresiz) ilk geçerli Google OAuth 2.0 istemci bilgisini okur.
  static ({String clientId, String clientSecret})?
      discoverGoogleClientCredentialsInDirectories(
    List<Directory> directories, {
    String? expectedClientId,
  }) {
    final targetId = (expectedClientId ?? '').trim();
    final candidates = <File>[];
    for (final dir in directories) {
      try {
        if (!dir.existsSync()) continue;
        candidates.addAll(
          dir.listSync().whereType<File>().where((f) {
            final name = p.basename(f.path).toLowerCase();
            return name.startsWith('client_secret') && name.endsWith('.json');
          }),
        );
      } catch (e) {
        debugPrint(
          'GoogleDriveSyncService: client_secret tarama uyarısı (${dir.path}): $e',
        );
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    for (final file in candidates) {
      try {
        final parsed = _parseGoogleClientJsonString(file.readAsStringSync());
        if (parsed == null || parsed.clientId.isEmpty) continue;
        if (targetId.isNotEmpty && parsed.clientId != targetId) continue;
        return parsed;
      } catch (e) {
        debugPrint(
          'GoogleDriveSyncService: client_secret okuma uyarısı (${file.path}): $e',
        );
      }
    }
    return null;
  }

  static Future<List<Directory>> _localCredentialSearchDirectories() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationSupportDirectory());
    } catch (e) {
      debugPrint(
        'GoogleDriveSyncService: uygulama destek dizini alınamadı: $e',
      );
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isNotEmpty) {
        dirs.add(Directory(p.join(userProfile, 'Downloads')));
      }
    }
    return dirs;
  }

  static Future<({String clientId, String clientSecret})?>
      _tryDiscoverLocalGoogleClientJson({String? expectedClientId}) async {
    final dirs = await _localCredentialSearchDirectories();
    final targetId = (expectedClientId ?? defaultIhasibuClientId).trim();
    return discoverGoogleClientCredentialsInDirectories(
      dirs,
      expectedClientId: targetId,
    );
  }

  /// Google Cloud Console üzerinden alınan OAuth 2.0 Client ID ve varsa Client Secret bilgisini
  /// `FlutterSecureStorage` içinde saklar.
  Future<void> saveOAuthClientCredentials({
    required String clientId,
    String? clientSecret,
  }) async {
    try {
      var cleanId = clientId.trim();
      var cleanSec = (clientSecret ?? '').trim();
      final parsedFromId = _parseGoogleClientJsonString(cleanId);
      if (parsedFromId != null) {
        if (parsedFromId.clientId.isNotEmpty) cleanId = parsedFromId.clientId;
        if (parsedFromId.clientSecret.isNotEmpty) {
          cleanSec = parsedFromId.clientSecret;
        }
      }
      final parsedFromSec = _parseGoogleClientJsonString(cleanSec);
      if (parsedFromSec != null) {
        if (parsedFromSec.clientId.isNotEmpty && cleanId.isEmpty) {
          cleanId = parsedFromSec.clientId;
        }
        if (parsedFromSec.clientSecret.isNotEmpty) {
          cleanSec = parsedFromSec.clientSecret;
        }
      }
      if (cleanId.isNotEmpty) {
        await _secureStorage.write(key: _kOAuthClientId, value: cleanId);
      }
      if (cleanSec.isNotEmpty && !cleanSec.contains('****')) {
        await _secureStorage.write(key: _kOAuthClientSecret, value: cleanSec);
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: saveOAuthClientCredentials yazma uyarısı: $e');
    }
  }

  static String _extractGoogleProjectNumber(String clientId) {
    final trimmed = clientId.trim();
    final dash = trimmed.indexOf('-');
    if (dash <= 0) return '';
    final prefix = trimmed.substring(0, dash);
    return RegExp(r'^\d+$').hasMatch(prefix) ? prefix : '';
  }

  /// Kayıtlı/girilen Client ID'nin `ihasibu` Google Cloud projesine ait olup olmadığını doğrular.
  static bool isCompatibleIhasibuClientId(String clientId) {
    final trimmed = clientId.trim();
    if (trimmed.isEmpty) return false;
    final expectedProject = _extractGoogleProjectNumber(defaultIhasibuClientId);
    if (expectedProject.isEmpty) return true;
    final candidateProject = _extractGoogleProjectNumber(trimmed);
    return candidateProject.isNotEmpty && candidateProject == expectedProject;
  }

  Future<void> _purgeForeignOAuthCredentials() async {
    await _secureStorage.delete(key: _kOAuthClientId);
    await _secureStorage.delete(key: _kOAuthClientSecret);
  }

  Future<String> getSavedOAuthClientId() async {
    try {
      final stored = (await _secureStorage.read(key: _kOAuthClientId) ?? '')
          .trim();
      if (stored.isNotEmpty) {
        if (isCompatibleIhasibuClientId(stored)) {
          return stored;
        }
        debugPrint(
          'GoogleDriveSyncService: Farklı Google Cloud projesine ait eski OAuth Client ID ($stored) temizlendi.',
        );
        await _purgeForeignOAuthCredentials();
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: getSavedOAuthClientId okuma uyarısı: $e');
    }
    final defaultId = defaultIhasibuClientId.trim();
    final discovered = await _tryDiscoverLocalGoogleClientJson(
      expectedClientId: defaultId,
    );
    if (discovered != null && discovered.clientId.isNotEmpty) {
      return discovered.clientId;
    }
    return defaultId;
  }

  Future<String> getSavedOAuthClientSecret() async {
    try {
      final storedId = (await _secureStorage.read(key: _kOAuthClientId) ?? '')
          .trim();
      if (storedId.isNotEmpty && !isCompatibleIhasibuClientId(storedId)) {
        debugPrint(
          'GoogleDriveSyncService: Uyumsuz OAuth Client ID ($storedId) nedeniyle önbellekteki gizli anahtar atlandı.',
        );
        await _purgeForeignOAuthCredentials();
      } else {
        final stored =
            (await _secureStorage.read(key: _kOAuthClientSecret) ?? '').trim();
        if (stored.isNotEmpty && !stored.contains('****')) return stored;
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: getSavedOAuthClientSecret okuma uyarısı: $e');
    }
    final compileTimeSecret = _compileTimeOAuthClientSecret.trim();
    if (compileTimeSecret.isNotEmpty && !compileTimeSecret.contains('****')) {
      return compileTimeSecret;
    }
    final expectedClientId = await getSavedOAuthClientId();
    final discovered = await _tryDiscoverLocalGoogleClientJson(
      expectedClientId: expectedClientId,
    );
    if (discovered != null &&
        discovered.clientSecret.isNotEmpty &&
        !discovered.clientSecret.contains('****')) {
      return discovered.clientSecret;
    }
    return '';
  }

  /// OAuth 2.0 PKCE Authorization Code (`code`) değerini `https://oauth2.googleapis.com/token`
  /// uç noktasında gerçek `access_token` ve `refresh_token` ile takas eder.
  Future<({String accessToken, String refreshToken, String error})>
      exchangeAuthorizationCodeForToken({
    required String code,
    required String clientId,
    String? clientSecret,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    try {
      final payload = <String, dynamic>{
        'code': code.trim(),
        'client_id': clientId.trim(),
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      };
      if (clientSecret != null && clientSecret.trim().isNotEmpty) {
        payload['client_secret'] = clientSecret.trim();
      }
      final resp = await _dio.post<Map<String, dynamic>>(
        _googleTokenEndpoint,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (resp.statusCode == 200 && data != null) {
        final access = (data['access_token'] as String?)?.trim() ?? '';
        final refresh = (data['refresh_token'] as String?)?.trim() ?? '';
        if (access.isNotEmpty) {
          await saveOAuthTokens(
            accessToken: access,
            refreshToken: refresh.isEmpty ? null : refresh,
          );
          return (accessToken: access, refreshToken: refresh, error: '');
        }
      }
      return (
        accessToken: '',
        refreshToken: '',
        error: 'Google Token sunucusu beklenen yanıtı döndürmedi.',
      );
    } on DioException catch (e) {
      final errData = e.response?.data;
      final detail = errData is Map
          ? '${errData['error'] ?? ''}: ${errData['error_description'] ?? ''}'
          : (e.message ?? 'Bilinmeyen hata');
      return (
        accessToken: '',
        refreshToken: '',
        error: 'OAuth 2.0 kod takası başarısız ($detail). '
            'Masaüstü (Desktop) istemcisi için Client Secret gerekiyorsa girdiğinizden emin olun.',
      );
    } catch (e) {
      return (
        accessToken: '',
        refreshToken: '',
        error: 'OAuth 2.0 kod takası hatası: $e',
      );
    }
  }

  /// Kayıtlı `refresh_token` (veya mobilde sessiz oturum) ile süresi dolmuş OAuth 2.0 `access_token` değerini yeniler.
  Future<String?> refreshAccessToken() async {
    try {
      final refreshToken =
          (await _secureStorage.read(key: _kRefreshToken) ?? '').trim();
      if (refreshToken.isEmpty) {
        if (_mobileSilentRefreshCallback != null) {
          final silentToken = (await _mobileSilentRefreshCallback!() ?? '').trim();
          if (silentToken.isNotEmpty) {
            await saveOAuthTokens(accessToken: silentToken);
            return silentToken;
          }
        }
        return null;
      }

      final clientId = await getSavedOAuthClientId();
      if (clientId.isEmpty) return null;
      final clientSecret = await getSavedOAuthClientSecret();

      final payload = <String, dynamic>{
        'client_id': clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      };

      final resp = await _dio.post<Map<String, dynamic>>(
        _googleTokenEndpoint,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (resp.statusCode == 200 && data != null) {
        final newAccess = (data['access_token'] as String?)?.trim() ?? '';
        final newRefresh = (data['refresh_token'] as String?)?.trim() ?? '';
        if (newAccess.isNotEmpty) {
          await saveOAuthTokens(
            accessToken: newAccess,
            refreshToken: newRefresh.isEmpty ? null : newRefresh,
          );
          return newAccess;
        }
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: refreshAccessToken uyarısı: $e');
    }
    return null;
  }

  /// Verilen OAuth 2.0 Bearer erişim anahtarını doğrudan Google sunucularında doğrular.
  Future<GoogleTokenVerificationResult> verifyGoogleAccessToken(
    String rawToken,
  ) async {
    final token = rawToken.trim();
    if (token.isEmpty) {
      return const GoogleTokenVerificationResult(
        isValid: false,
        errorMessage: 'OAuth 2.0 erişim anahtarı (Access Token) boş.',
      );
    }

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        _googleUserInfoEndpoint,
        options: Options(
          headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        ),
      );
      final data = resp.data;
      if (resp.statusCode == 200 && data != null) {
        final email = (data['email'] as String?)?.trim() ?? '';
        final name = (data['name'] as String?)?.trim() ?? '';
        return GoogleTokenVerificationResult(
          isValid: true,
          email: email,
          displayName: name,
        );
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: userinfo atlandı, drive/v3/about denenecek: $e');
    }

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        _googleDriveAboutEndpoint,
        options: Options(
          headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        ),
      );
      final data = resp.data;
      if (resp.statusCode == 200 && data != null) {
        final userMap = data['user'] as Map<String, dynamic>?;
        final email = (userMap?['emailAddress'] as String?)?.trim() ?? '';
        final name = (userMap?['displayName'] as String?)?.trim() ?? '';
        return GoogleTokenVerificationResult(
          isValid: true,
          email: email,
          displayName: name,
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return GoogleTokenVerificationResult(
          isValid: false,
          errorMessage:
              'Google API anahtarı reddetti (HTTP $code). Anahtar geçersiz veya süresi dolmuş.',
        );
      }
      return GoogleTokenVerificationResult(
        isValid: false,
        errorMessage: 'Google sunucusuna ulaşılamadı: ${e.message}',
      );
    } catch (e) {
      return GoogleTokenVerificationResult(
        isValid: false,
        errorMessage: 'Google doğrulama hatası: $e',
      );
    }

    return const GoogleTokenVerificationResult(
      isValid: false,
      errorMessage: 'Google OAuth 2.0 erişim anahtarı doğrulanamadı.',
    );
  }

  /// Yerel loopback (`http://127.0.0.1:43821/login` veya dinamik port) üzerinden
  /// Microsoft Edge / varsayılan tarayıcıyı açarak Google OAuth 2.0 (PKCE Code + Token) girişini başlatır.
  Future<BrowserGoogleSignInResult> startInteractiveBrowserGoogleSignIn({
    String? loginHintEmail,
    String? customClientId,
    String? customClientSecret,
    Duration timeout = const Duration(seconds: 120),
    List<String> extraScopes = const <String>[],
  }) async {
    HttpServer? server;
    try {
      String activeClientId = (customClientId ?? '').trim();
      String activeClientSecret = (customClientSecret ?? '').trim();
      if (activeClientId.isNotEmpty || activeClientSecret.isNotEmpty) {
        await saveOAuthClientCredentials(
          clientId: activeClientId,
          clientSecret: activeClientSecret,
        );
      }
      if (activeClientId.isEmpty) {
        activeClientId = await getSavedOAuthClientId();
      }
      if (activeClientSecret.isEmpty) {
        activeClientSecret = await getSavedOAuthClientSecret();
      }

      try {
        server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          preferredLoopbackPort,
        );
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }

      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/oauth2callback';
      final pkceVerifier = _generatePkceCodeVerifier();
      final pkceChallenge = _generatePkceCodeChallenge(pkceVerifier);
      final oauthState = _generatePkceCodeVerifier();
      final hasDirectPkceConfig =
          activeClientId.isNotEmpty && activeClientSecret.isNotEmpty;
      final initialUri = hasDirectPkceConfig
          ? Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: port,
              path: '/start_pkce',
              queryParameters: <String, String>{
                if ((loginHintEmail ?? '').trim().isNotEmpty)
                  'email': loginHintEmail!.trim(),
              },
            )
          : Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: port,
              path: '/login',
            );
      final loginUrl = initialUri.toString();
      final completer = Completer<BrowserGoogleSignInResult>();

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(
            const BrowserGoogleSignInResult(
              success: false,
              message:
                  'Tarayıcıda Google OAuth 2.0 girişi zaman aşımına uğradı (120 sn).',
            ),
          );
        }
      });

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/login' || path == '/') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType =
              ContentType('text', 'html', charset: 'utf-8');
          request.response.write(
            _buildLoopbackLoginHtml(
              port: port,
              loginHintEmail: loginHintEmail ?? '',
              customClientId: activeClientId,
              customClientSecret: activeClientSecret,
              pkceCodeChallenge: pkceChallenge,
            ),
          );
          await request.response.close();
          return;
        }

        if (path == '/start_pkce') {
          final cid =
              (request.uri.queryParameters['client_id'] ?? activeClientId)
                  .trim();
          final csec = (request.uri.queryParameters['client_secret'] ??
                  activeClientSecret)
              .trim();
          final hint =
              (request.uri.queryParameters['email'] ?? loginHintEmail ?? '')
                  .trim();
          if (cid.isNotEmpty &&
              (cid != activeClientId ||
                  (csec.isNotEmpty && csec != activeClientSecret))) {
            activeClientId = cid;
            if (csec.isNotEmpty) activeClientSecret = csec;
            await saveOAuthClientCredentials(
              clientId: activeClientId,
              clientSecret: activeClientSecret,
            );
          }
          if (activeClientId.isEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            request.response.write(
              _buildResultHtml(
                success: false,
                title: 'Google Cloud OAuth 2.0 Client ID Eksik',
                detail:
                    'Lütfen Google Cloud Console üzerinden oluşturduğunuz Masaüstü/Web OAuth 2.0 Client ID değerini girin veya Yöntem 2\'yi kullanın.',
              ),
            );
            await request.response.close();
            return;
          }

          final requestedScopes = <String>{
            'openid',
            'email',
            'profile',
            'https://www.googleapis.com/auth/drive.file',
            ...extraScopes.map((s) => s.trim()).where((s) => s.isNotEmpty),
          }.join(' ');

          final authUri =
              Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(
            queryParameters: <String, String>{
              'client_id': activeClientId,
              'redirect_uri': redirectUri,
              'response_type': 'code',
              'scope': requestedScopes,
              'code_challenge': pkceChallenge,
              'code_challenge_method': 'S256',
              'state': oauthState,
              'access_type': 'offline',
              'prompt': 'select_account consent',
              if (extraScopes.isNotEmpty) 'include_granted_scopes': 'true',
              if (hint.isNotEmpty) 'login_hint': hint,
            },
          );
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            authUri.toString(),
          );
          await request.response.close();
          return;
        }

        if (path == '/oauth2callback') {
          final authCode = (request.uri.queryParameters['code'] ?? '').trim();
          final returnedState =
              (request.uri.queryParameters['state'] ?? '').trim();
          final oauthErr = (request.uri.queryParameters['error'] ?? '').trim();

          if (oauthErr.isNotEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            request.response.write(
              _buildResultHtml(
                success: false,
                title: 'Google OAuth Yetkilendirme Hatası ($oauthErr)',
                detail:
                    'Google OAuth 2.0 yetkilendirmesi tamamlanamadı: $oauthErr. Lütfen Google Cloud Console Test Kullanıcıları (Test Users) listesine e-postanızı eklediğinizden emin olun.',
              ),
            );
            await request.response.close();
            return;
          }

          // PKCE Authorization Code (Masaüstü / Web Uygulaması) geldiyse CSRF state doğrulayıp token ile takas et!
          if (authCode.isNotEmpty && activeClientId.isNotEmpty) {
            if (returnedState != oauthState) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType =
                  ContentType('text', 'html', charset: 'utf-8');
              request.response.write(
                _buildResultHtml(
                  success: false,
                  title: 'Google OAuth 2.0 Güvenlik Doğrulaması Başarısız',
                  detail:
                      'OAuth 2.0 CSRF state parametresi eşleşmedi. Güvenliğiniz için oturum açma isteği reddedildi.',
                ),
              );
              await request.response.close();
              return;
            }
            final exchange = await exchangeAuthorizationCodeForToken(
              code: authCode,
              clientId: activeClientId,
              clientSecret:
                  activeClientSecret.isEmpty ? null : activeClientSecret,
              codeVerifier: pkceVerifier,
              redirectUri: redirectUri,
            );
            if (exchange.accessToken.isEmpty) {
              request.response.statusCode = HttpStatus.unauthorized;
              request.response.headers.contentType =
                  ContentType('text', 'html', charset: 'utf-8');
              request.response.write(
                _buildResultHtml(
                  success: false,
                  title: 'Google OAuth 2.0 Kod Takası Başarısız',
                  detail: exchange.error,
                ),
              );
              await request.response.close();
              return;
            }

            final verification =
                await verifyGoogleAccessToken(exchange.accessToken);
            final resolvedEmail = verification.email.isNotEmpty
                ? verification.email
                : (loginHintEmail ?? '').trim();

            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            request.response.write(
              _buildResultHtml(
                success: true,
                title: 'Google Hesabı Doğrulandı ve Hasibu\'da Oturum Açıldı',
                detail:
                    'Hesap: ${resolvedEmail.isEmpty ? verification.displayName : resolvedEmail}. Bu Edge sekmesini kapatıp Hasibu uygulamasına dönebilirsiniz.',
              ),
            );
            await request.response.close();

            if (!completer.isCompleted) {
              timer.cancel();
              completer.complete(
                BrowserGoogleSignInResult(
                  success: true,
                  accessToken: exchange.accessToken,
                  refreshToken: exchange.refreshToken,
                  email: resolvedEmail,
                  displayName: verification.displayName,
                  message:
                      'Google OAuth 2.0 PKCE oturumu açıldı (${resolvedEmail.isEmpty ? "Google" : resolvedEmail}).',
                ),
              );
            }
            return;
          }

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType =
              ContentType('text', 'html', charset: 'utf-8');
          request.response.write(_buildFragmentExtractorHtml(port));
          await request.response.close();
          return;
        }

        if (path == '/callback') {
          final rawToken =
              (request.uri.queryParameters['access_token'] ?? '').trim();
          final hintEmail =
              (request.uri.queryParameters['email'] ?? loginHintEmail ?? '')
                  .trim();

          if (rawToken.isEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            request.response.write(
              _buildResultHtml(
                success: false,
                title: 'Google OAuth Anahtarı Alınamadı',
                detail:
                    'Lütfen Google OAuth 2.0 erişim anahtarını (ya29...) girerek tekrar deneyin.',
              ),
            );
            await request.response.close();
            return;
          }

          final verification = await verifyGoogleAccessToken(rawToken);
          if (!verification.isValid) {
            request.response.statusCode = HttpStatus.unauthorized;
            request.response.headers.contentType =
                ContentType('text', 'html', charset: 'utf-8');
            request.response.write(
              _buildResultHtml(
                success: false,
                title: 'Google API Doğrulaması Başarısız',
                detail: verification.errorMessage,
              ),
            );
            await request.response.close();
            return;
          }

          final resolvedEmail =
              verification.email.isNotEmpty ? verification.email : hintEmail;

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType =
              ContentType('text', 'html', charset: 'utf-8');
          request.response.write(
            _buildResultHtml(
              success: true,
              title: 'Google Hesabı Doğrulandı ve Hasibu\'ya Bağlandı',
              detail:
                  'Hesap: ${resolvedEmail.isEmpty ? verification.displayName : resolvedEmail}. Bu tarayıcı sekmesini kapatıp Hasibu uygulamasına dönebilirsiniz.',
            ),
          );
          await request.response.close();

          if (!completer.isCompleted) {
            timer.cancel();
            completer.complete(
              BrowserGoogleSignInResult(
                success: true,
                accessToken: rawToken,
                email: resolvedEmail,
                displayName: verification.displayName,
                message:
                    'Google OAuth 2.0 doğrulaması başarılı (${resolvedEmail.isEmpty ? "Google Drive" : resolvedEmail}).',
              ),
            );
          }
          return;
        }

        if (path == '/cancel') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType =
              ContentType('text', 'html', charset: 'utf-8');
          request.response.write(
            _buildResultHtml(
              success: false,
              title: 'İşlem İptal Edildi',
              detail: 'Google girişi kullanıcı tarafından iptal edildi.',
            ),
          );
          await request.response.close();
          if (!completer.isCompleted) {
            timer.cancel();
            completer.complete(
              const BrowserGoogleSignInResult(
                success: false,
                message: 'Tarayıcıdaki Google girişi iptal edildi.',
              ),
            );
          }
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final browserOpened = await _openSystemBrowser(loginUrl);
      if (!browserOpened) {
        timer.cancel();
        return BrowserGoogleSignInResult(
          success: false,
          message:
              'Sistem tarayıcısı otomatik açılamadı. Lütfen tarayıcıda $loginUrl adresini açın veya doğrudan OAuth anahtarı girin.',
        );
      }

      return await completer.future;
    } catch (e) {
      return BrowserGoogleSignInResult(
        success: false,
        message: 'Yerel OAuth 2.0 sunucusu başlatılamadı: $e',
      );
    } finally {
      try {
        await server?.close(force: true);
      } catch (e) {
        _lastSyncWarning = e.toString();
        debugPrint('GoogleDriveSyncService: Loopback server kapatma uyarısı: $e');
      }
    }
  }

  static Future<bool> _openSystemBrowser(String url) async {
    try {
      final parsed = Uri.tryParse(url);
      if (parsed == null || (parsed.scheme != 'https' && parsed.scheme != 'http')) {
        return false;
      }
      if (Platform.isWindows) {
        // Öncelikle Microsoft Edge (msedge.exe) kuruluysa doğrudan açık olan Edge oturumunda sekme aç
        for (final edgePath in const <String>[
          r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
          r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        ]) {
          if (File(edgePath).existsSync()) {
            await Process.start(edgePath, <String>[parsed.toString()]);
            return true;
          }
        }
        final res = await Process.run(
          'rundll32',
          <String>['url.dll,FileProtocolHandler', parsed.toString()],
        );
        return res.exitCode == 0;
      } else if (Platform.isMacOS) {
        final res = await Process.run('open', <String>[parsed.toString()]);
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final res = await Process.run('xdg-open', <String>[parsed.toString()]);
        return res.exitCode == 0;
      }
    } catch (e) {
      debugPrint('GoogleDriveSyncService: _openSystemBrowser hatası: $e');
      return false;
    }
    return false;
  }

  /// Aktif senkronizasyon veya yerel yedek klasörünü Windows Gezgini'nde (Explorer) açar.
  Future<String> openSyncFolderInExplorer([String? customFolder]) async {
    final settings = db.getCompanySettings();
    final effective = await _resolveEffectiveSyncFolder(
      customFolder ?? settings.syncFolderPath,
    );
    String targetDirPath = effective;
    if (targetDirPath.isEmpty) {
      try {
        final appDir = await getApplicationSupportDirectory();
        targetDirPath = appDir.path;
      } catch (_) {
        targetDirPath = Directory.current.path;
      }
    }
    final dir = Directory(targetDirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dir.path]);
    }
    return dir.path;
  }

  /// Yerel SQLite veritabanını arka plan izolatında serileştirir,
  /// [SYNC-01] & [SYNC-02] uyarınca `AES-256-GCM` ile şifreler:
  /// - `hasibu_master_vault.enc` (& `hasibu_sync.enc` veya profil dosyası): İK/Yönetici tam veritabanı yedeği
  /// - `hasibu_portal_queue.enc`: Personel Portalı kısıtlı paketi (`hr_requests` + maskelenmiş vardiya)
  Future<DriveSyncStatus> pushToCloud({
    String deviceName = 'İşyeri Laptop (Merkez)',
    bool force = false,
    bool isEmployeePortalOnly = false,
    String? employeeCardNo,
    String? profileId,
    String operationLabel = 'backup',
  }) async {
    final now = DateTime.now();
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount.trim();
    final effectiveProfileId =
        normalizeCloudProfileId(profileId ?? settings.cloudProfileId);
    final primaryFileName = backupFileNameForProfile(effectiveProfileId);
    final masterFileName = masterVaultFileNameForProfile(effectiveProfileId);
    final portalFileName = portalQueueFileNameForProfile(effectiveProfileId);

    if (!force &&
        _lastCachedStatus != null &&
        _lastCachedStatus!.cloudProfileId == effectiveProfileId &&
        now.difference(_lastSyncAttempt) < const Duration(seconds: 10)) {
      return _lastCachedStatus!;
    }

    final keySpec = await resolveActiveEncryptionKey(
      profileId: effectiveProfileId,
    );

    // [SYNC-02] Yönetici (master_vault) ve Personel (portal_queue) paketlerini oluştur
    final masterSnapshot = db.exportCloudSnapshot(deviceName: deviceName);
    final portalSnapshot = db.exportPortalQueueSnapshot(
      deviceName: deviceName,
      employeeCardNo: employeeCardNo,
    );

    final encryptedMasterPayload =
        await HasibuSecurityService.encryptSyncJsonPayload(
      masterSnapshot,
      workspaceKey: keySpec.key,
      vaultRole: 'master_vault',
      keyMode: keySpec.envelopeKeyMode,
    );
    final encryptedPortalPayload =
        await HasibuSecurityService.encryptSyncJsonPayload(
      portalSnapshot,
      workspaceKey: keySpec.key,
      vaultRole: 'portal_queue',
      keyMode: keySpec.envelopeKeyMode,
    );

    final primaryEncryptedPayload = isEmployeePortalOnly
        ? encryptedPortalPayload
        : encryptedMasterPayload;
    final payloadBytes = utf8.encode(primaryEncryptedPayload);
    final hash = sha256.convert(payloadBytes).toString().substring(0, 12);
    final cacheKey = '${effectiveProfileId}_$hash';

    if (!force && cacheKey == _lastPayloadHash && _lastCachedStatus != null) {
      return _lastCachedStatus!.copyWith(
        lastSyncTime: now,
        lastHash: hash,
        cloudProfileId: effectiveProfileId,
        lastOperation: operationLabel,
      );
    }

    // 1. Yerel disk ve varsa gerçek Google Drive Masaüstü klasör yedeğini AES-256-GCM (.enc) olarak kaydet
    final effectiveFolder = await _resolveEffectiveSyncFolder(
      settings.syncFolderPath,
    );
    final mirrorOutcome = await _writeLocalMirror(
      primaryEncryptedPayload,
      effectiveFolder,
      primaryFileName: primaryFileName,
      masterFileName: masterFileName,
      portalFileName: portalFileName,
      masterVaultEncrypted: isEmployeePortalOnly ? null : encryptedMasterPayload,
      portalQueueEncrypted: encryptedPortalPayload,
    );
    _lastSyncAttempt = now;
    _lastPayloadHash = cacheKey;

    // 2. Google Drive OAuth token mevcutsa buluta yükle
    String? token;
    try {
      token = await getAccessToken();
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: getAccessToken hatası: $e');
    }

    final cleanToken = (token ?? '').trim();
    final bool hasOAuthBearerToken =
        cleanToken.isNotEmpty && cleanToken.startsWith('ya29.');

    if (hasOAuthBearerToken) {
      try {
        final targetRemoteName =
            isEmployeePortalOnly ? portalFileName : primaryFileName;
        await _runWithTokenRefresh<void>(
          cleanToken,
          (activeToken) => _uploadEncryptedPayload(
            activeToken,
            targetRemoteName: targetRemoteName,
            primaryEncryptedPayload: primaryEncryptedPayload,
            payloadBytes: payloadBytes,
            now: now,
          ),
        );

        final status = DriveSyncStatus(
          stage: DriveSyncStage.synced,
          lastSyncTime: now,
          lastDeviceName: deviceName,
          lastHash: hash,
          connectedGmail: gmail,
          isCloudApiVerified: true,
          isDriveFolderMirrored: mirrorOutcome.wroteDriveFolder,
          syncedFilePath: mirrorOutcome.primaryPath,
          syncedBytes: payloadBytes.length,
          cloudProfileId: effectiveProfileId,
          lastOperation: operationLabel,
          message:
              'Google Drive AES-256-GCM (${gmail.isEmpty ? "OAuth 2.0" : gmail} • Profil: $effectiveProfileId) buluta şifreli yüklendi (#$hash • ${(payloadBytes.length / 1024).toStringAsFixed(1)} KB)',
        );
        _lastCachedStatus = status;
        return status;
      } catch (e) {
        if (mirrorOutcome.wroteDriveFolder) {
          final status = DriveSyncStatus(
            stage: DriveSyncStage.synced,
            lastSyncTime: now,
            lastDeviceName: deviceName,
            lastHash: hash,
            connectedGmail: gmail,
            isCloudApiVerified: false,
            isDriveFolderMirrored: true,
            syncedFilePath: mirrorOutcome.driveFilePath,
            syncedBytes: mirrorOutcome.bytesWritten,
            cloudProfileId: effectiveProfileId,
            lastOperation: operationLabel,
            message:
                'Google API anahtarı süresi doldu ancak Google Drive klasörüne AES-256-GCM şifreli eşitlendi (${mirrorOutcome.driveFilePath} • #$hash)',
          );
          _lastCachedStatus = status;
          return status;
        }
        final status = DriveSyncStatus(
          stage: DriveSyncStage.offlineSaved,
          lastSyncTime: now,
          lastDeviceName: deviceName,
          lastHash: hash,
          connectedGmail: gmail,
          isCloudApiVerified: false,
          isDriveFolderMirrored: false,
          syncedFilePath: mirrorOutcome.localFilePath,
          syncedBytes: mirrorOutcome.bytesWritten,
          cloudProfileId: effectiveProfileId,
          lastOperation: operationLabel,
          message:
              'Google Drive API yüklemesi başarısız. Yalnızca yerel AES-256-GCM şifreli yedek alındı (#$hash).',
        );
        _lastCachedStatus = status;
        return status;
      }
    }

    // OAuth token yoksa: Yalnızca gerçek bir Google Drive klasörüne yazıldıysa synced döndür!
    if (mirrorOutcome.wroteDriveFolder) {
      final status = DriveSyncStatus(
        stage: DriveSyncStage.synced,
        lastSyncTime: now,
        lastDeviceName: deviceName,
        lastHash: hash,
        connectedGmail: gmail,
        isCloudApiVerified: false,
        isDriveFolderMirrored: true,
        syncedFilePath: mirrorOutcome.driveFilePath,
        syncedBytes: mirrorOutcome.bytesWritten,
        cloudProfileId: effectiveProfileId,
        lastOperation: operationLabel,
        message:
            'Google Drive Klasörüne AES-256-GCM şifreli eşitlendi (${mirrorOutcome.driveFilePath} • #$hash • ${(mirrorOutcome.bytesWritten / 1024).toStringAsFixed(1)} KB)',
      );
      _lastCachedStatus = status;
      return status;
    }

    // Ne OAuth2 token var ne de Google Drive klasörü: Dürüstçe offlineSaved döndür!
    final status = DriveSyncStatus(
      stage: DriveSyncStage.offlineSaved,
      lastSyncTime: now,
      lastDeviceName: deviceName,
      lastHash: hash,
      connectedGmail: gmail,
      isCloudApiVerified: false,
      isDriveFolderMirrored: false,
      syncedFilePath: mirrorOutcome.localFilePath,
      syncedBytes: mirrorOutcome.bytesWritten,
      cloudProfileId: effectiveProfileId,
      lastOperation: operationLabel,
      message: gmail.isNotEmpty
          ? 'Google OAuth 2.0 girişi doğrulanmadı ($gmail). Yerel AES-256-GCM yedek alındı ($primaryFileName • #$hash).'
          : 'Yerel AES-256-GCM şifreli yedek alındı ($primaryFileName • #$hash). Google OAuth 2.0 veya Drive klasörü bağlandığında buluta eşitlenir.',
    );
    _lastCachedStatus = status;
    return status;
  }

  /// Google Drive'dan (veya yerel paylaşılan `.enc` yedek dosyasından) seçili profilin
  /// şifreli paketini indirip `AES-256-GCM` şifresini çözer ve yerel SQLite ile birleştirir
  /// (`CloudRestoreMode.merge`) veya birebir geri yükler (`CloudRestoreMode.replace`).
  Future<({DriveSyncStatus status, CloudRestoreSummary? summary})>
      restoreFromCloud({
    String? profileId,
    CloudRestoreMode mode = CloudRestoreMode.merge,
    bool isEmployeePortalOnly = false,
    bool cloudOnly = false,
    String? overrideWorkspaceKey,
  }) async {
    final now = DateTime.now();
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount.trim();
    final effectiveProfileId =
        normalizeCloudProfileId(profileId ?? settings.cloudProfileId);
    final primaryFileName = backupFileNameForProfile(effectiveProfileId);
    final masterFileName = masterVaultFileNameForProfile(effectiveProfileId);
    final portalFileName = portalQueueFileNameForProfile(effectiveProfileId);

    try {
      String? token;
      try {
        token = await getAccessToken();
      } catch (e) {
        _lastSyncWarning = e.toString();
        debugPrint('GoogleDriveSyncService: getAccessToken indirme uyarısı: $e');
      }
      String? rawPayload;
      bool fromCloudApi = false;
      bool fromDriveFolder = false;
      String sourcePath = '';

      final cleanToken = (token ?? '').trim();
      final bool isDirectGoogleApiToken =
          cleanToken.isNotEmpty && cleanToken.startsWith('ya29.');

      final preferredFile =
          isEmployeePortalOnly ? portalFileName : primaryFileName;

      if (isDirectGoogleApiToken) {
        try {
          final cloudPayload = await _runWithTokenRefresh<
              ({String rawPayload, String fileId})?>(
            cleanToken,
            (activeToken) => _downloadEncryptedPayload(
              activeToken,
              preferredFile: preferredFile,
              fallbackMasterFile: masterFileName,
              includeLegacyDefault: effectiveProfileId == 'default',
            ),
          );
          if (cloudPayload != null) {
            rawPayload = cloudPayload.rawPayload;
            fromCloudApi = true;
            sourcePath = 'Google Drive Cloud (${cloudPayload.fileId})';
          }
        } catch (e) {
          _lastSyncWarning = e.toString();
          debugPrint(
            'GoogleDriveSyncService: Bulut indirme başarısız, yerel yedeğe geçiliyor: $e',
          );
        }
      }

      final candidateNames = <String>[
        preferredFile,
        if (masterFileName != preferredFile) masterFileName,
        if (primaryFileName != preferredFile) primaryFileName,
        if (effectiveProfileId == 'default') _legacyBackupFileName,
      ];

      final effectiveFolder = await _resolveEffectiveSyncFolder(
        settings.syncFolderPath,
      );
      if (rawPayload == null || rawPayload.isEmpty) {
        if (effectiveFolder.isNotEmpty) {
          for (final candidateName in candidateNames) {
            final driveFile = File(p.join(effectiveFolder, candidateName));
            if (await driveFile.exists()) {
              rawPayload = await driveFile.readAsString();
              fromDriveFolder = true;
              sourcePath = driveFile.path;
              break;
            }
          }
        }
      }

      if (!cloudOnly && (rawPayload == null || rawPayload.isEmpty)) {
        rawPayload = await _readLocalMirror(
          '',
          candidateNames: candidateNames,
        );
        if (rawPayload != null && rawPayload.isNotEmpty) {
          try {
            final dir = await getApplicationSupportDirectory();
            sourcePath = p.join(dir.path, primaryFileName);
          } catch (_) {
            sourcePath = primaryFileName;
          }
        }
      }

      if (rawPayload == null || rawPayload.isEmpty) {
        if (mode == CloudRestoreMode.merge && !isEmployeePortalOnly) {
          try {
            final inboxRes = await pullAndMergeBranchInboxes(
              profileId: effectiveProfileId,
            );
            if (inboxRes.devices.isNotEmpty) {
              final status = DriveSyncStatus(
                stage: DriveSyncStage.synced,
                lastSyncTime: now,
                lastDeviceName: inboxRes.devices.first.deviceName,
                connectedGmail: gmail,
                isCloudApiVerified:
                    inboxRes.devices.any((d) => d.remoteFileId != null),
                cloudProfileId: effectiveProfileId,
                lastOperation: 'restore',
                message:
                    '${inboxRes.devices.length} şube cihaz kutusu birleştirildi (${inboxRes.totalNewLogsInserted} yeni hareket).',
              );
              _lastCachedStatus = status;
              return (status: status, summary: null);
            }
          } catch (e) {
            _lastSyncWarning = e.toString();
          }
        }
        final status = DriveSyncStatus(
          stage: cloudOnly ? DriveSyncStage.error : DriveSyncStage.idle,
          lastSyncTime: now,
          connectedGmail: gmail,
          isCloudApiVerified: false,
          isDriveFolderMirrored: false,
          cloudProfileId: effectiveProfileId,
          lastOperation: 'restore',
          message: cloudOnly
              ? 'Google Drive bulutunda "$effectiveProfileId" profiline ait şifreli yedek ($primaryFileName) bulunamadı.'
              : 'Henüz bulut veya yerel şifreli yedek dosyası bulunamadı.',
        );
        return (status: status, summary: null);
      }

      final candidateKeys = <({String key, bool saveAsCustom})>[];
      void addCandidateKey(String key, bool saveAsCustom) {
        final k = key.trim();
        if (k.isEmpty || candidateKeys.any((c) => c.key == k)) return;
        candidateKeys.add((key: k, saveAsCustom: saveAsCustom));
      }

      final cleanOverride = (overrideWorkspaceKey ?? '').trim();
      if (cleanOverride.isNotEmpty) {
        addCandidateKey(cleanOverride, true);
        addCandidateKey(
          HasibuSecurityService.derivePassphraseWorkspaceKey(cleanOverride),
          true,
        );
      } else {
        final activeSpec = await resolveActiveEncryptionKey(
          profileId: effectiveProfileId,
        );
        addCandidateKey(activeSpec.key, false);

        final envelopeKeyMode =
            HasibuSecurityService.readEnvelopeKeyMode(rawPayload);
        if (envelopeKeyMode == 'account_auto' && gmail.isNotEmpty) {
          addCandidateKey(
            HasibuSecurityService.deriveAccountWorkspaceKey(
              googleEmail: gmail,
              cloudProfileId: effectiveProfileId,
            ),
            false,
          );
        }

        final currentMode = await getCloudEncryptionKeyMode();
        if (currentMode != CloudEncryptionKeyMode.customPassphrase) {
          try {
            final legacyStored =
                (await _secureStorage.read(key: _kWorkspaceKey) ?? '').trim();
            addCandidateKey(legacyStored, false);
          } catch (e) {
            _lastSyncWarning = e.toString();
          }
        }
      }

      Map<String, dynamic>? decoded;
      for (final candidate in candidateKeys) {
        try {
          decoded = await HasibuSecurityService.decryptSyncJsonPayload(
            rawPayload,
            workspaceKey: candidate.key,
          );
          if (candidate.saveAsCustom) {
            await saveWorkspaceKey(candidate.key);
          }
          break;
        } on SecretBoxAuthenticationError {
          continue;
        }
      }

      if (decoded == null) {
        final status = DriveSyncStatus(
          stage: DriveSyncStage.error,
          lastSyncTime: now,
          connectedGmail: gmail,
          isCloudApiVerified: fromCloudApi,
          isDriveFolderMirrored: fromDriveFolder,
          cloudProfileId: effectiveProfileId,
          lastOperation: 'restore',
          isDecryptionKeyMismatch: true,
          message:
              'Bulut yedeği çözülemedi: Bu yedek farklı bir Bulut Şifreleme Parolası veya Çalışma Alanı Anahtarı (Workspace Key) ile şifrelenmiş. Ortak parolanızı veya diğer cihazdan aldığınız anahtarı girip tekrar deneyin.',
        );
        return (status: status, summary: null);
      }

      final summary = db.restoreCloudSnapshot(decoded, mode: mode);
      int extraBranchNewLogs = 0;
      if (mode == CloudRestoreMode.merge && !isEmployeePortalOnly) {
        try {
          final inboxRes = await pullAndMergeBranchInboxes(
            profileId: effectiveProfileId,
          );
          extraBranchNewLogs = inboxRes.totalNewLogsInserted;
        } catch (e) {
          _lastSyncWarning = e.toString();
        }
      }
      final remoteDevice = summary.sourceDeviceName;
      final bytesLen = utf8.encode(rawPayload).length;

      final bool trulySynced = fromCloudApi || fromDriveFolder;
      final branchSuffix = extraBranchNewLogs > 0
          ? ' + $extraBranchNewLogs şube kutusu kaydı'
          : '';
      final status = DriveSyncStatus(
        stage: trulySynced ? DriveSyncStage.synced : DriveSyncStage.offlineSaved,
        lastSyncTime: now,
        lastDeviceName: remoteDevice,
        connectedGmail: gmail,
        isCloudApiVerified: fromCloudApi,
        isDriveFolderMirrored: fromDriveFolder,
        syncedFilePath: sourcePath,
        syncedBytes: bytesLen,
        cloudProfileId: effectiveProfileId,
        lastOperation: 'restore',
        message: trulySynced
            ? 'Buluttan yüklendi (${mode.label} • $remoteDevice • Profil: $effectiveProfileId): ${summary.toTurkishSummary()}$branchSuffix'
            : 'Yerel yedekten yüklendi (${mode.label} • $remoteDevice): ${summary.toTurkishSummary()}$branchSuffix',
      );
      _lastCachedStatus = status;
      return (status: status, summary: summary);
    } catch (e) {
      final status = DriveSyncStatus(
        stage: DriveSyncStage.error,
        lastSyncTime: now,
        connectedGmail: gmail,
        cloudProfileId: effectiveProfileId,
        lastOperation: 'restore',
        message: 'Buluttan yükleme hatası: $e',
      );
      return (status: status, summary: null);
    }
  }

  /// Uygulama yeniden açıldığında kayıtlı Gmail, OAuth2 token / refresh token
  /// veya Google Drive masaüstü klasörü bilgisinden bulut oturumunu geri yükler.
  Future<DriveSyncStatus?> restorePersistedGoogleSession() async {
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount.trim();
    if (gmail.isEmpty) return null;

    String? accessToken;
    String refreshToken = '';
    try {
      accessToken = await getAccessToken();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
    try {
      refreshToken =
          (await _secureStorage.read(key: _kRefreshToken) ?? '').trim();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }

    bool folderExists = false;
    try {
      final effectiveFolder = await _resolveEffectiveSyncFolder(
        settings.syncFolderPath,
      );
      if (effectiveFolder.isNotEmpty) {
        folderExists = Directory(effectiveFolder).existsSync();
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
    }

    final hasAccessToken =
        accessToken != null && accessToken.trim().startsWith('ya29.');
    if (hasAccessToken || refreshToken.isNotEmpty) {
      final status = DriveSyncStatus(
        stage: DriveSyncStage.synced,
        connectedGmail: gmail,
        isCloudApiVerified: true,
        isDriveFolderMirrored: folderExists,
        cloudProfileId: settings.cloudProfileId,
        lastOperation: 'session_restored',
        message: 'Google Bulut oturumu açık ($gmail)',
      );
      _lastCachedStatus = status;
      return status;
    }

    if (folderExists) {
      final status = DriveSyncStatus(
        stage: DriveSyncStage.synced,
        connectedGmail: gmail,
        isCloudApiVerified: false,
        isDriveFolderMirrored: true,
        cloudProfileId: settings.cloudProfileId,
        lastOperation: 'session_restored',
        message: 'Google Drive klasörü aktif ($gmail)',
      );
      _lastCachedStatus = status;
      return status;
    }

    return null;
  }

  /// Google Drive'dan (veya yerel paylaşılan `.enc` yedek dosyasından) en güncel paketi
  /// indirip `AES-256-GCM` şifresini çözer ve yerel SQLite ile birleştirir.
  Future<DriveSyncStatus> pullAndReconcile({
    bool isEmployeePortalOnly = false,
  }) async {
    final result = await restoreFromCloud(
      mode: CloudRestoreMode.merge,
      isEmployeePortalOnly: isEmployeePortalOnly,
    );
    return result.status;
  }

  /// Tek bir şube cihazının yüz okutma kayıtlarını izole şube gelen kutusuna
  /// (`hasibu_branch_inbox_<slug>.enc`, `vaultRole: 'branch_inbox'`) yükler.
  Future<DriveSyncStatus> pushBranchInboxSnapshot({
    required String deviceSlug,
    required int branchId,
    required String branchCode,
    required String branchName,
    required String deviceName,
    required List<AttendanceLog> logs,
    List<Map<String, dynamic>> deviceUsers = const <Map<String, dynamic>>[],
    String? profileId,
  }) async {
    final now = DateTime.now();
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount.trim();
    final effectiveProfileId =
        normalizeCloudProfileId(profileId ?? settings.cloudProfileId);
    final cleanSlug = normalizeDeviceSlug(deviceSlug);
    final fileName = branchInboxFileNameForDevice(
      deviceSlug: cleanSlug,
      profileId: effectiveProfileId,
    );
    final keySpec = await resolveActiveEncryptionKey(
      profileId: effectiveProfileId,
    );

    final sanitizedLogs = logs
        .map((l) => l.copyWith(integrityHash: '').toJson()..['integrityHash'] = '')
        .toList(growable: false);
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'vaultRole': 'branch_inbox',
      'cloudProfileId': effectiveProfileId,
      'deviceSlug': cleanSlug,
      'branchId': branchId,
      'branchCode': branchCode,
      'branchName': branchName,
      'deviceName': deviceName,
      'exportedAt': now.toUtc().toIso8601String(),
      'attendanceLogs': sanitizedLogs,
      'deviceUsers': deviceUsers,
    };

    final encryptedPayload = await HasibuSecurityService.encryptSyncJsonPayload(
      payload,
      workspaceKey: keySpec.key,
      vaultRole: 'branch_inbox',
      keyMode: keySpec.envelopeKeyMode,
    );
    final payloadBytes = utf8.encode(encryptedPayload);
    final hash = sha256.convert(payloadBytes).toString().substring(0, 12);

    final effectiveFolder =
        await _resolveEffectiveSyncFolder(settings.syncFolderPath);
    final mirrorOutcome = await _writeLocalMirror(
      encryptedPayload,
      effectiveFolder,
      primaryFileName: fileName,
    );

    String? token;
    try {
      token = await getAccessToken();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
    final cleanToken = (token ?? '').trim();
    if (cleanToken.isNotEmpty && cleanToken.startsWith('ya29.')) {
      try {
        await _runWithTokenRefresh<void>(
          cleanToken,
          (activeToken) => _uploadEncryptedPayload(
            activeToken,
            targetRemoteName: fileName,
            primaryEncryptedPayload: encryptedPayload,
            payloadBytes: payloadBytes,
            now: now,
          ),
        );
        return DriveSyncStatus(
          stage: DriveSyncStage.synced,
          lastSyncTime: now,
          lastDeviceName: deviceName,
          lastHash: hash,
          connectedGmail: gmail,
          isCloudApiVerified: true,
          isDriveFolderMirrored: mirrorOutcome.wroteDriveFolder,
          syncedFilePath: mirrorOutcome.primaryPath,
          syncedBytes: payloadBytes.length,
          cloudProfileId: effectiveProfileId,
          lastOperation: 'branch_inbox_push',
          message:
              'Şube kutusu ($fileName) Google Drive\'a yüklendi (${sanitizedLogs.length} kayıt).',
        );
      } catch (e) {
        _lastSyncWarning = e.toString();
      }
    }

    return DriveSyncStatus(
      stage: mirrorOutcome.wroteDriveFolder
          ? DriveSyncStage.synced
          : DriveSyncStage.offlineSaved,
      lastSyncTime: now,
      lastDeviceName: deviceName,
      lastHash: hash,
      connectedGmail: gmail,
      isCloudApiVerified: false,
      isDriveFolderMirrored: mirrorOutcome.wroteDriveFolder,
      syncedFilePath: mirrorOutcome.primaryPath,
      syncedBytes: payloadBytes.length,
      cloudProfileId: effectiveProfileId,
      lastOperation: 'branch_inbox_push',
      message: mirrorOutcome.wroteDriveFolder
          ? 'Şube kutusu Drive klasörüne yazıldı ($fileName).'
          : 'Şube kutusu yerel önbelleğe kaydedildi ($fileName).',
    );
  }

  /// Google Drive hesabındaki ve yerel senkronizasyon klasöründeki tüm
  /// şube gelen kutusu (`hasibu_branch_inbox_*.enc`) dosyalarını tarar,
  /// yeni/güncel olanları indirip `AES-256-GCM` çözerek yerel SQLite ile birleştirir.
  Future<BranchInboxPullResult> pullAndMergeBranchInboxes({
    String? profileId,
    bool force = false,
  }) async {
    final settings = db.getCompanySettings();
    final effectiveProfileId =
        normalizeCloudProfileId(profileId ?? settings.cloudProfileId);
    final workspaceKey = await getWorkspaceKey();
    final warnings = <String>[];
    final candidates = <String, ({
      String slug,
      String? fileId,
      DateTime? modifiedTime,
      String signature,
      File? localFile,
      String source,
    })>{};

    String? token;
    try {
      token = await getAccessToken();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
    final cleanToken = (token ?? '').trim();
    final bool hasOAuth =
        cleanToken.isNotEmpty && cleanToken.startsWith('ya29.');

    if (hasOAuth) {
      try {
        final files = await _runWithTokenRefresh<List<dynamic>>(
          cleanToken,
          (activeToken) async {
            final resp = await _dio.get<Map<String, dynamic>>(
              _driveFilesEndpoint,
              queryParameters: {
                'q': "name contains '$branchInboxPrefix' and trashed = false",
                'spaces': 'drive',
                'fields': 'files(id, name, modifiedTime, size)',
                'orderBy': 'modifiedTime desc',
                'pageSize': 100,
              },
              options: Options(
                headers: {
                  HttpHeaders.authorizationHeader: 'Bearer $activeToken',
                },
              ),
            );
            return resp.data?['files'] as List<dynamic>? ?? const <dynamic>[];
          },
        );
        for (final raw in files) {
          if (raw is! Map) continue;
          final f = Map<String, dynamic>.from(raw);
          final name = (f['name'] as String? ?? '').trim();
          final slug = parseBranchInboxDeviceSlug(
            name,
            profileId: effectiveProfileId,
          );
          if (slug == null || candidates.containsKey(name)) continue;
          final modIso = (f['modifiedTime'] as String? ?? '').trim();
          final sizeStr = (f['size'] ?? '0').toString();
          candidates[name] = (
            slug: slug,
            fileId: f['id'] as String?,
            modifiedTime: DateTime.tryParse(modIso),
            signature: '$modIso|$sizeStr',
            localFile: null,
            source: 'Google Drive Bulut',
          );
        }
      } catch (e) {
        _lastSyncWarning = e.toString();
        warnings.add('Drive şube kutuları listelenemedi: $e');
      }
    }

    final effectiveFolder =
        await _resolveEffectiveSyncFolder(settings.syncFolderPath);
    if (effectiveFolder.isNotEmpty) {
      try {
        final dir = Directory(effectiveFolder);
        if (await dir.exists()) {
          await for (final entity in dir.list(followLinks: false)) {
            if (entity is! File) continue;
            final name = p.basename(entity.path);
            final slug = parseBranchInboxDeviceSlug(
              name,
              profileId: effectiveProfileId,
            );
            if (slug == null || candidates.containsKey(name)) continue;
            final stat = await entity.stat();
            candidates[name] = (
              slug: slug,
              fileId: null,
              modifiedTime: stat.modified,
              signature:
                  '${stat.modified.toUtc().toIso8601String()}|${stat.size}',
              localFile: entity,
              source: 'Google Drive Klasörü',
            );
          }
        }
      } catch (e) {
        _lastSyncWarning = e.toString();
      }
    }

    final statuses = <BranchInboxDeviceStatus>[];
    int totalLogsRead = 0;
    int totalNewLogsInserted = 0;
    int totalUsersSynced = 0;

    for (final entry in candidates.entries) {
      final fileName = entry.key;
      final item = entry.value;
      final cached = _cachedBranchInboxStatuses[fileName];
      if (!force &&
          item.signature.isNotEmpty &&
          _processedBranchInboxSignatures[fileName] == item.signature &&
          cached != null) {
        statuses.add(
          BranchInboxDeviceStatus(
            deviceSlug: cached.deviceSlug,
            branchId: cached.branchId,
            branchCode: cached.branchCode,
            branchName: cached.branchName,
            deviceName: cached.deviceName,
            fileName: cached.fileName,
            remoteFileId: cached.remoteFileId,
            modifiedTime: cached.modifiedTime,
            logCount: cached.logCount,
            newlyInsertedCount: 0,
            syncedUsersCount: 0,
            source: cached.source,
          ),
        );
        continue;
      }

      try {
        String? rawPayload;
        if (item.fileId != null && hasOAuth) {
          rawPayload = await _runWithTokenRefresh<String?>(
            cleanToken,
            (activeToken) async {
              final resp = await _dio.get<String>(
                '$_driveFilesEndpoint/${item.fileId}?alt=media',
                options: Options(
                  headers: {
                    HttpHeaders.authorizationHeader: 'Bearer $activeToken',
                  },
                  responseType: ResponseType.plain,
                ),
              );
              return resp.data;
            },
          );
        } else if (item.localFile != null) {
          rawPayload = await item.localFile!.readAsString();
        }

        if (rawPayload == null || rawPayload.trim().isEmpty) continue;

        final decoded = await HasibuSecurityService.decryptSyncJsonPayload(
          rawPayload,
          workspaceKey: workspaceKey,
          expectedVaultRole: 'branch_inbox',
        );
        final merged = db.mergeBranchInboxSnapshot(decoded);

        final branchId = (decoded['branchId'] as num?)?.toInt() ?? 1;
        final branchCode = (decoded['branchCode'] as String? ?? '').trim();
        final branchName = (decoded['branchName'] as String? ?? '').trim();
        final deviceName = (decoded['deviceName'] as String? ?? '').trim();
        final exportedAt = DateTime.tryParse(
          (decoded['exportedAt'] as String? ?? '').trim(),
        );

        final status = BranchInboxDeviceStatus(
          deviceSlug: (decoded['deviceSlug'] as String? ?? item.slug).trim(),
          branchId: branchId,
          branchCode: branchCode,
          branchName: branchName,
          deviceName: deviceName,
          fileName: fileName,
          remoteFileId: item.fileId,
          modifiedTime: item.modifiedTime ?? exportedAt,
          logCount: merged.totalLogs,
          newlyInsertedCount: merged.newLogs,
          syncedUsersCount: merged.syncedUsers,
          source: item.source,
        );
        statuses.add(status);
        _processedBranchInboxSignatures[fileName] = item.signature;
        _cachedBranchInboxStatuses[fileName] = status;

        totalLogsRead += merged.totalLogs;
        totalNewLogsInserted += merged.newLogs;
        totalUsersSynced += merged.syncedUsers;
      } on SecretBoxAuthenticationError {
        warnings.add(
          '$fileName çözülemedi: Çalışma Alanı Anahtarı (Workspace Key) uyumsuz.',
        );
      } catch (e) {
        warnings.add('$fileName okuma/birleştirme hatası: $e');
      }
    }

    return BranchInboxPullResult(
      devices: statuses,
      totalLogsRead: totalLogsRead,
      totalNewLogsInserted: totalNewLogsInserted,
      totalUsersSynced: totalUsersSynced,
      warnings: warnings,
    );
  }

  /// Bağlı Google Drive hesabında ve yerel/Drive klasörlerinde bulunan yedek profillerini listeler.
  Future<List<CloudBackupProfileInfo>> listAvailableCloudBackups() async {
    final byProfile = <String, CloudBackupProfileInfo>{};
    final settings = db.getCompanySettings();

    String? token;
    try {
      token = await getAccessToken();
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
    final cleanToken = (token ?? '').trim();
    if (cleanToken.isNotEmpty && cleanToken.startsWith('ya29.')) {
      try {
        final files = await _runWithTokenRefresh<List<dynamic>>(
          cleanToken,
          (activeToken) async {
            final resp = await _dio.get<Map<String, dynamic>>(
              _driveFilesEndpoint,
              queryParameters: {
                'q': "name contains 'hasibu_sync' and trashed = false",
                'spaces': 'drive',
                'fields': 'files(id, name, modifiedTime, size)',
                'orderBy': 'modifiedTime desc',
                'pageSize': 50,
              },
              options: Options(
                headers: {HttpHeaders.authorizationHeader: 'Bearer $activeToken'},
              ),
            );
            return resp.data?['files'] as List<dynamic>? ?? const <dynamic>[];
          },
        );
        for (final raw in files) {
          if (raw is! Map) continue;
          final f = Map<String, dynamic>.from(raw);
          final name = (f['name'] as String? ?? '').trim();
          final profileId = parseProfileIdFromFileName(name);
          if (profileId == null) continue;
          if (byProfile.containsKey(profileId)) continue;
          final size = int.tryParse((f['size'] ?? '0').toString()) ?? 0;
          final modified = DateTime.tryParse(
            (f['modifiedTime'] as String? ?? '').trim(),
          );
          byProfile[profileId] = CloudBackupProfileInfo(
            profileId: profileId,
            fileName: name,
            remoteFileId: f['id'] as String?,
            modifiedTime: modified,
            sizeBytes: size,
            source: 'Google Drive Bulut',
          );
        }
      } catch (e) {
        _lastSyncWarning = e.toString();
        debugPrint(
          'GoogleDriveSyncService: listAvailableCloudBackups API uyarısı: $e',
        );
      }
    }

    final effectiveFolder =
        await _resolveEffectiveSyncFolder(settings.syncFolderPath);
    if (effectiveFolder.isNotEmpty) {
      await _collectDirectoryBackupProfiles(
        Directory(effectiveFolder),
        source: 'Google Drive Klasörü',
        byProfile: byProfile,
      );
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      await _collectDirectoryBackupProfiles(
        supportDir,
        source: 'Yerel Yedek',
        byProfile: byProfile,
      );
    } catch (e) {
      _lastSyncWarning = e.toString();
    }

    final sorted = byProfile.values.toList()
      ..sort((a, b) {
        final am = a.modifiedTime;
        final bm = b.modifiedTime;
        if (am == null && bm == null) {
          return a.profileId.compareTo(b.profileId);
        }
        if (am == null) return 1;
        if (bm == null) return -1;
        return bm.compareTo(am);
      });
    return List<CloudBackupProfileInfo>.unmodifiable(sorted);
  }

  Future<void> _collectDirectoryBackupProfiles(
    Directory dir, {
    required String source,
    required Map<String, CloudBackupProfileInfo> byProfile,
  }) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final profileId = parseProfileIdFromFileName(name);
        if (profileId == null || byProfile.containsKey(profileId)) continue;
        final stat = await entity.stat();
        byProfile[profileId] = CloudBackupProfileInfo(
          profileId: profileId,
          fileName: name,
          modifiedTime: stat.modified,
          sizeBytes: stat.size,
          source: source,
        );
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
    }
  }

  Future<T> _runWithTokenRefresh<T>(
    String initialToken,
    Future<T> Function(String token) action,
  ) async {
    try {
      return await action(initialToken);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed != null && refreshed.isNotEmpty) {
          return await action(refreshed);
        }
      }
      rethrow;
    }
  }

  Future<void> _uploadEncryptedPayload(
    String token, {
    required String targetRemoteName,
    required String primaryEncryptedPayload,
    required List<int> payloadBytes,
    required DateTime now,
  }) async {
    final existingFileId = await _findRemoteFileId(
      token,
      fileName: targetRemoteName,
    );
    if (existingFileId != null) {
      await _dio.patch<void>(
        '$_driveUploadEndpoint/$existingFileId?uploadType=media',
        data: Stream.fromIterable([payloadBytes]),
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/octet-stream',
            HttpHeaders.contentLengthHeader: payloadBytes.length,
          },
        ),
      );
      return;
    }

    final boundary = 'hasibu_sync_${now.millisecondsSinceEpoch}';
    final metaJson = jsonEncode({
      'name': targetRemoteName,
      'mimeType': 'application/octet-stream',
    });
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metaJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n\r\n'
        '$primaryEncryptedPayload\r\n'
        '--$boundary--';

    await _dio.post<void>(
      '$_driveUploadEndpoint?uploadType=multipart',
      data: body,
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader:
              'multipart/related; boundary=$boundary',
        },
      ),
    );
  }

  Future<({String rawPayload, String fileId})?> _downloadEncryptedPayload(
    String token, {
    required String preferredFile,
    String fallbackMasterFile = masterVaultFileName,
    bool includeLegacyDefault = true,
  }) async {
    String? fileId = await _findRemoteFileId(
      token,
      fileName: preferredFile,
    );
    if (fileId == null && fallbackMasterFile != preferredFile) {
      fileId = await _findRemoteFileId(
        token,
        fileName: fallbackMasterFile,
      );
    }
    if (fileId == null && includeLegacyDefault) {
      fileId = await _findRemoteFileId(
        token,
        fileName: _legacyBackupFileName,
      );
    }
    if (fileId == null) return null;

    final resp = await _dio.get<String>(
      '$_driveFilesEndpoint/$fileId?alt=media',
      options: Options(
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        responseType: ResponseType.plain,
      ),
    );
    final data = resp.data;
    if (data != null && data.isNotEmpty) {
      return (rawPayload: data, fileId: fileId);
    }
    return null;
  }

  Future<String?> _findRemoteFileId(
    String token, {
    String fileName = backupFileName,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      _driveFilesEndpoint,
      queryParameters: {
        'q': "name = '$fileName' and trashed = false",
        'spaces': 'drive',
        'fields': 'files(id, name, modifiedTime)',
        'pageSize': 1,
      },
      options: Options(
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      ),
    );
    final files = resp.data?['files'] as List<dynamic>?;
    if (files == null || files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  static String detectDefaultGoogleDrivePath() {
    try {
      if (Platform.isWindows) {
        final candidates = <String>[
          r"G:\Drive'ım",
          r'G:\My Drive',
          if (Platform.environment['USERPROFILE'] != null) ...[
            p.join(Platform.environment['USERPROFILE']!, 'Google Drive'),
            p.join(Platform.environment['USERPROFILE']!, 'GoogleDrive'),
            p.join(Platform.environment['USERPROFILE']!, "Drive'ım"),
          ],
        ];
        for (final root in candidates) {
          if (Directory(root).existsSync()) {
            return p.join(root, 'Hasibu', 'CloudSync');
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveSyncService: detectDefaultGoogleDrivePath uyarısı: $e');
      return '';
    }
    return '';
  }

  Future<String> _resolveEffectiveSyncFolder(String customFolderPath) async {
    final trimmed = customFolderPath.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return detectDefaultGoogleDrivePath();
  }

  Future<_MirrorWriteOutcome> _writeLocalMirror(
    String jsonPayload,
    String customFolderPath, {
    String primaryFileName = backupFileName,
    String masterFileName = masterVaultFileName,
    String portalFileName = portalQueueFileName,
    String? masterVaultEncrypted,
    String? portalQueueEncrypted,
  }) async {
    bool wroteDriveFolder = false;
    String driveFilePath = '';
    String localFilePath = '';
    int bytesWritten = utf8.encode(jsonPayload).length;

    try {
      final cleanFolder = customFolderPath.trim();
      if (cleanFolder.isNotEmpty) {
        final customDir = Directory(cleanFolder);
        // Sürücü kökü (örn. G:\ veya C:\) gerçekten sistemde mevcutsa klasörü oluşturup yaz
        final rootPrefix = p.rootPrefix(cleanFolder);
        if (rootPrefix.isEmpty || Directory(rootPrefix).existsSync()) {
          await customDir.create(recursive: true);
          final customFile = File(p.join(customDir.path, primaryFileName));
          await customFile.writeAsString(jsonPayload, flush: true);
          if (masterVaultEncrypted != null) {
            await File(p.join(customDir.path, masterFileName))
                .writeAsString(masterVaultEncrypted, flush: true);
          }
          if (portalQueueEncrypted != null) {
            await File(p.join(customDir.path, portalFileName))
                .writeAsString(portalQueueEncrypted, flush: true);
          }
          if (customFile.existsSync() && customFile.lengthSync() > 0) {
            wroteDriveFolder = true;
            driveFilePath = customFile.path;
            bytesWritten = customFile.lengthSync();
          }
        }
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: _writeLocalMirror drive klasörü yazma uyarısı: $e');
    }

    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, primaryFileName));
      await file.writeAsString(jsonPayload, flush: true);
      if (masterVaultEncrypted != null) {
        await File(p.join(dir.path, masterFileName))
            .writeAsString(masterVaultEncrypted, flush: true);
      }
      if (portalQueueEncrypted != null) {
        await File(p.join(dir.path, portalFileName))
            .writeAsString(portalQueueEncrypted, flush: true);
      }
      if (file.existsSync()) {
        localFilePath = file.path;
        bytesWritten = file.lengthSync();
      }
    } catch (e) {
      // Test ortamında path_provider yoksa sessizce geç
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: _writeLocalMirror yerel dizin uyarısı: $e');
    }

    return _MirrorWriteOutcome(
      wroteDriveFolder: wroteDriveFolder,
      driveFilePath: driveFilePath,
      localFilePath: localFilePath,
      bytesWritten: bytesWritten,
    );
  }

  Future<String?> _readLocalMirror(
    String customFolderPath, {
    List<String> candidateNames = const <String>[
      backupFileName,
      masterVaultFileName,
      portalQueueFileName,
      _legacyBackupFileName,
    ],
  }) async {
    try {
      if (customFolderPath.trim().isNotEmpty) {
        for (final name in candidateNames) {
          final customFile = File(p.join(customFolderPath.trim(), name));
          if (await customFile.exists()) {
            return await customFile.readAsString();
          }
        }
      }
      final dir = await getApplicationSupportDirectory();
      for (final name in candidateNames) {
        final file = File(p.join(dir.path, name));
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
    } catch (e) {
      _lastSyncWarning = e.toString();
      debugPrint('GoogleDriveSyncService: _readLocalMirror okuma uyarısı: $e');
    }
    return null;
  }

  static String _buildLoopbackLoginHtml({
    required int port,
    required String loginHintEmail,
    required String customClientId,
    String customClientSecret = '',
    String pkceCodeChallenge = '',
  }) {
    final escapedEmail = const HtmlEscape().convert(loginHintEmail);
    final escapedClientId = const HtmlEscape().convert(customClientId);
    final escapedClientSecret = const HtmlEscape().convert(customClientSecret);
    const playgroundUrl =
        'https://developers.google.com/oauthplayground/#step1&apisSelect=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive.file%2Chttps%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email';

    return '''
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <title>Hasibu (ihasibu) • Google OAuth 2.0 & E-Posta Oturum Açma</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0f172a;
      color: #f8fafc;
      margin: 0;
      padding: 32px 16px;
      display: flex;
      justify-content: center;
    }
    .card {
      max-width: 700px;
      width: 100%;
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 16px;
      padding: 28px;
      box-shadow: 0 20px 40px rgba(0,0,0,0.45);
    }
    h1 { margin: 0 0 8px 0; font-size: 22px; color: #38bdf8; }
    p { color: #cbd5e1; font-size: 14px; line-height: 1.55; }
    .step-box {
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 12px;
      padding: 18px;
      margin-top: 18px;
    }
    .step-title {
      font-weight: 700;
      font-size: 15px;
      color: #f8fafc;
      margin-bottom: 8px;
    }
    label {
      display: block;
      font-size: 12px;
      color: #94a3b8;
      margin-top: 12px;
      margin-bottom: 4px;
    }
    input[type="text"], input[type="email"], input[type="password"] {
      width: 100%;
      box-sizing: border-box;
      padding: 10px 12px;
      border-radius: 8px;
      border: 1px solid #475569;
      background: #1e293b;
      color: #f8fafc;
      font-size: 14px;
    }
    .btn {
      display: inline-block;
      margin-top: 12px;
      padding: 11px 18px;
      border-radius: 8px;
      font-weight: 600;
      font-size: 14px;
      text-decoration: none;
      cursor: pointer;
      border: none;
    }
    .btn-primary { background: #2563eb; color: #fff; }
    .btn-emerald { background: #10b981; color: #052e16; }
    .btn-outline { background: transparent; border: 1px solid #64748b; color: #cbd5e1; }
    .code-pill {
      background: #334155;
      padding: 2px 6px;
      border-radius: 4px;
      font-family: monospace;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>Hasibu (ihasibu) • Google E-Posta ile Oturum Açma & Drive Köprüsü</h1>
    <p>
      Edge tarayıcınızda açık olan Google hesabınızla doğrudan oturum açabilir ve Hasibu
      veritabanınızı <b>AES-256-GCM</b> şifreli olarak Google Drive ile eşitleyebilirsiniz.
    </p>

    <div class="step-box">
      <div class="step-title">Yöntem 1 (ihasibu Google Cloud Console OAuth 2.0 PKCE ile Doğrudan Oturum Açma)</div>
      <p style="margin: 4px 0 8px 0;">
        Google Cloud Console'da <b>ihasibu</b> projesi için oluşturduğunuz <b>Masaüstü Uygulaması (Desktop App)</b> veya
        <b>Web Uygulaması</b> (Yönlendirme URI: <span class="code-pill">http://127.0.0.1:$port/oauth2callback</span>) bilgilerini girip doğrudan Google hesabınızla giriş yapın:
      </p>
      <form action="/start_pkce" method="GET">
        <label>Google E-Posta Adresiniz (Oturum Açılacak Hesap):</label>
        <input type="email" name="email" value="$escapedEmail" placeholder="ornek@gmail.com" />
        <label>Google Cloud OAuth 2.0 Client ID (.apps.googleusercontent.com):</label>
        <input type="text" name="client_id" id="clientIdInput" value="$escapedClientId" placeholder="123456789-abcdef.apps.googleusercontent.com" required />
        <label>Google Cloud OAuth 2.0 Client Secret (Masaüstü/Web İstemcisi için Gerekliyse):</label>
        <input type="password" name="client_secret" value="$escapedClientSecret" placeholder="GOCSPX-..." />
        <button type="submit" class="btn btn-emerald">
          Google Hesabım ile Doğrudan Oturum Aç (PKCE OAuth 2.0) ↗
        </button>
      </form>
    </div>

    <div class="step-box">
      <div class="step-title">Yöntem 2 (Hızlı Giriş - Hazır Google OAuth 2.0 Playground Köprüsü)</div>
      <p style="margin: 4px 0 10px 0;">
        1. Aşağıdaki mavi butona tıklayarak Google'ın resmi OAuth 2.0 yetkilendirme sayfasını açın ve Google hesabınızla giriş yapın.<br/>
        2. Açılan sayfada mavi <b>"Authorize APIs"</b> ve ardından <b>"Exchange authorization code for tokens"</b> butonuna basın.<br/>
        3. Üretilen <span class="code-pill">ya29....</span> ile başlayan <b>Access token</b> değerini aşağıdaki kutuya yapıştırıp <b>"Google API ile Doğrula ve Hasibu'da Oturum Aç"</b> butonuna tıklayın.
      </p>
      <a class="btn btn-primary" href="$playgroundUrl" target="_blank" rel="noopener">
        1. Google OAuth 2.0 Giriş Sayfasını Aç (developers.google.com) ↗
      </a>

      <form action="/callback" method="GET" style="margin-top: 14px;">
        <label>Google E-Posta Adresiniz:</label>
        <input type="email" name="email" value="$escapedEmail" placeholder="ornek@gmail.com" />
        <label>Google OAuth 2.0 Erişim Anahtarı (Access Token - ya29...):</label>
        <input type="text" name="access_token" required placeholder="ya29.a0AeDClZ..." />
        <button type="submit" class="btn btn-emerald">
          2. Google API ile Doğrula ve Hasibu'da Oturum Aç ✓
        </button>
      </form>
    </div>

    <div style="margin-top: 18px; text-align: right;">
      <a class="btn btn-outline" href="/cancel">İptal Et</a>
    </div>
  </div>
</body>
</html>
''';
  }

  static String _buildFragmentExtractorHtml(int port) {
    return '''
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="utf-8" /><title>Google OAuth 2.0 Yönlendiriliyor...</title></head>
<body style="background:#0f172a;color:#f8fafc;font-family:sans-serif;padding:40px;text-align:center;">
  <h2>Google OAuth 2.0 Anahtarı Doğrulanıyor...</h2>
  <script>
    (function() {
      var hash = window.location.hash.substring(1);
      var params = new URLSearchParams(hash);
      var token = params.get('access_token');
      if (token) {
        window.location.replace('http://127.0.0.1:$port/callback?access_token=' + encodeURIComponent(token));
      } else {
        document.body.innerHTML = '<h3>Google OAuth yanıtında access_token bulunamadı.</h3><a href="/login" style="color:#38bdf8;">Geri Dön</a>';
      }
    })();
  </script>
</body>
</html>
''';
  }

  static String _buildResultHtml({
    required bool success,
    required String title,
    required String detail,
  }) {
    final color = success ? '#10b981' : '#ef4444';
    final escapedTitle = const HtmlEscape().convert(title);
    final escapedDetail = const HtmlEscape().convert(detail);
    return '''
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="utf-8" /><title>$escapedTitle</title></head>
<body style="background:#0f172a;color:#f8fafc;font-family:sans-serif;padding:48px;text-align:center;">
  <div style="max-width:520px;margin:0 auto;background:#1e293b;border:2px solid $color;border-radius:16px;padding:28px;">
    <h2 style="color:$color;margin-top:0;">$escapedTitle</h2>
    <p style="color:#cbd5e1;line-height:1.5;">$escapedDetail</p>
    ${success ? '' : '<p style="margin-top:20px;"><a href="/login" style="color:#38bdf8;font-weight:bold;">← Giriş Ekranına Geri Dön</a></p>'}
  </div>
</body>
</html>
''';
  }
}
