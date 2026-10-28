import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cue_models.dart';

/// Metadata for a Google Drive or local JSON backup snapshot.
class CloudBackupInfo {
  const CloudBackupInfo({
    required this.fileId,
    required this.fileName,
    required this.modifiedTime,
    required this.deviceName,
    required this.displayName,
    this.planCount,
    this.sizeBytes,
    this.isLocal = false,
    this.localFilePath,
  });

  final String fileId;
  final String fileName;
  final DateTime modifiedTime;
  final String deviceName;
  final String displayName;
  final int? planCount;
  final int? sizeBytes;
  final bool isLocal;
  final String? localFilePath;

  String get formattedDate {
    final dt = modifiedTime.toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}

/// Validated payload extracted from a CueDeck backup JSON file.
class ParsedBackupPayload {
  const ParsedBackupPayload({
    required this.items,
    required this.settings,
    required this.deviceName,
    this.backupDate,
  });

  final List<WatchCueItem> items;
  final Map<String, dynamic> settings;
  final String deviceName;
  final DateTime? backupDate;

  List<WatchCueItem> get watchCueItems => items;
  Map<String, dynamic> get appSettings => settings;
}

/// Result summary for backup, restore, sync, or local file export/import operations.
class BackupOperationResult {
  const BackupOperationResult({
    required this.success,
    required this.message,
    this.restoredCount = 0,
    this.backupDate,
    this.restoredItems,
    this.restoredSettings,
  });

  final bool success;
  final String message;
  final int restoredCount;
  final DateTime? backupDate;
  final List<WatchCueItem>? restoredItems;
  final Map<String, dynamic>? restoredSettings;
}

/// Google Drive (`appDataFolder` + `drive`) and local SAF JSON backup/restore/sync service
/// with hardware-backed AndroidKeyStore AES-256-GCM encryption and SHA-256 integrity verification.
class GoogleDriveBackupService {
  GoogleDriveBackupService();

  static const String clientId =
      '803381919405-3j7rne8pv0j5b9u87faeesagnvrqd5gd.apps.googleusercontent.com';
  static const String oauthExchangeEndpoint =
      'https://oauth2.googleapis.com/token';
  static const String driveFilesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String driveUploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';

  static const String backupFileName = 'CueDeck_CloudBackup.json';
  static const String autoBackupFileName = 'CueDeck_OtomatikYedek.json';

  static const String _kVaultAccessEntry = 'GoogleDrive_VaultAccess';
  static const String _kVaultRefreshEntry = 'GoogleDrive_VaultRefresh';
  static const String oauthExpiryEpochMsKey = 'GoogleDrive_OAuthExpiryMs';
  static const String userEmailKey = 'GoogleDrive_UserEmail';
  static const String userNameKey = 'GoogleDrive_UserName';
  static const String lastBackupTicksKey = 'LastGoogleDriveBackupTicks';
  static const String autoBackupEnabledKey = 'IsGoogleDriveAutoBackupEnabled';

  static const int maxBackupJsonBytes = 2 * 1024 * 1024; // 2 MB DoS guard
  static const Duration _httpTimeout = Duration(seconds: 15);
  static final RegExp _safeFileIdRegex = RegExp(r'^[a-zA-Z0-9_-]{5,128}$');
  static final RegExp _safeLocalFilenameRegex = RegExp(
    r'^CueDeck_[a-zA-Z0-9._-]+\.json$',
  );

  static const MethodChannel _storageChannel = MethodChannel(
    'com.akarworks.cuedeck/storage',
  );

  /// Ephemeral in-memory fallback vault used only when AndroidKeyStore channel is unavailable.
  static final Map<String, String> _ephemeralVault = <String, String>{};

  // ===========================================================================
  // HARDWARE-BACKED ANDROID KEYSTORE AES-256-GCM CREDENTIAL VAULT
  // ===========================================================================

  static Future<void> _writeVaultEntry(String entryKey, String value) async {
    final store = await _openMetadataStore();
    if (value.isEmpty) {
      _ephemeralVault.remove(entryKey);
      await store.remove(entryKey);
      return;
    }
    try {
      final cipherPayload = await _storageChannel.invokeMethod<String>(
        'encryptSecret',
        <String, dynamic>{'plainText': value},
      );
      if (cipherPayload != null && cipherPayload.isNotEmpty) {
        _ephemeralVault.remove(entryKey);
        await store.setString(entryKey, 'ak_gcm:$cipherPayload');
        return;
      }
    } catch (_) {
      // Keep only in ephemeral memory when hardware KeyStore channel is unavailable
    }
    _ephemeralVault[entryKey] = value;
  }

  static Future<String?> _readVaultEntry(String entryKey) async {
    if (_ephemeralVault.containsKey(entryKey)) {
      return _ephemeralVault[entryKey];
    }
    final store = await _openMetadataStore();
    final raw = store.getString(entryKey);
    if (raw == null || raw.isEmpty) return null;

    if (raw.startsWith('ak_gcm:')) {
      final cipherText = raw.substring(7);
      try {
        final opened = await _storageChannel.invokeMethod<String>(
          'decryptSecret',
          <String, dynamic>{'cipherText': cipherText},
        );
        return (opened != null && opened.isNotEmpty) ? opened : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> _deleteVaultEntry(String entryKey) async {
    _ephemeralVault.remove(entryKey);
    final store = await _openMetadataStore();
    await store.remove(entryKey);
  }

  /// Encrypts and persists OAuth2 session credentials using AndroidKeyStore AES-256-GCM.
  static Future<void> saveTokensSecurely({
    required String accessToken,
    String? refreshToken,
    required int expiresInSeconds,
    String? email,
    String? name,
  }) async {
    await _writeVaultEntry(_kVaultAccessEntry, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _writeVaultEntry(_kVaultRefreshEntry, refreshToken);
    }

    final store = await _openMetadataStore();
    final expiryMs =
        DateTime.now().millisecondsSinceEpoch + (expiresInSeconds * 1000);
    await store.setInt(oauthExpiryEpochMsKey, expiryMs);

    if (email != null && email.isNotEmpty) {
      await store.setString(userEmailKey, email);
    }
    if (name != null && name.isNotEmpty) {
      await store.setString(userNameKey, name);
    }
  }

  // ===========================================================================
  // AUTH STATUS & SESSION REFRESH
  // ===========================================================================

  Future<bool> isSignedIn() async {
    try {
      final bearer = await getValidAccessToken();
      if (bearer == null || bearer.isEmpty) return false;
      final email = await getUserEmail();
      return email != null && email.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getUserEmail() async {
    final store = await _openMetadataStore();
    final email = store.getString(userEmailKey);
    return (email != null && email.trim().isNotEmpty) ? email.trim() : null;
  }

  Future<String?> getUserName() async {
    final store = await _openMetadataStore();
    final name = store.getString(userNameKey);
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  Future<String> getLastBackupTimeFormatted() async {
    final store = await _openMetadataStore();
    final millis = store.getInt(lastBackupTicksKey) ?? 0;
    if (millis <= 0) return 'Henüz yedekleme yapılmadı';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  Future<bool> isAutoBackupEnabled() async {
    final store = await _openMetadataStore();
    return store.getBool(autoBackupEnabledKey) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final store = await _openMetadataStore();
    await store.setBool(autoBackupEnabledKey, enabled);
  }

  Future<void> signOut() async {
    await _deleteVaultEntry(_kVaultAccessEntry);
    await _deleteVaultEntry(_kVaultRefreshEntry);
    final store = await _openMetadataStore();
    await store.remove(oauthExpiryEpochMsKey);
    await store.remove(userEmailKey);
    await store.remove(userNameKey);
  }

  /// Returns a valid OAuth2 bearer credential, refreshing proactively 5 minutes before expiry.
  Future<String?> getValidAccessToken() async {
    try {
      final currentBearer = await _readVaultEntry(_kVaultAccessEntry);
      if (currentBearer == null || currentBearer.isEmpty) return null;

      final store = await _openMetadataStore();
      final expiryMs = store.getInt(oauthExpiryEpochMsKey) ?? 0;

      // 5-minute (300,000 ms) proactive refresh margin
      if (DateTime.now().millisecondsSinceEpoch < (expiryMs - 300000)) {
        return currentBearer;
      }

      final refreshGrant = await _readVaultEntry(_kVaultRefreshEntry);
      if (refreshGrant == null || refreshGrant.isEmpty) {
        return null;
      }

      final formBody = <String, String>{
        'client_id': clientId,
        'refresh_token': refreshGrant,
        'grant_type': 'refresh_token',
      }.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');

      final res = await _httpRequest(
        method: 'POST',
        uri: Uri.parse(oauthExchangeEndpoint),
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        bodyBytes: utf8.encode(formBody),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final nextBearer = (data['access_token'] as String?) ?? '';
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        final nextRefresh = data['refresh_token'] as String?;

        if (nextBearer.isNotEmpty) {
          await saveTokensSecurely(
            accessToken: nextBearer,
            refreshToken: nextRefresh,
            expiresInSeconds: expiresIn,
          );
          return nextBearer;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // JSON SERIALIZATION & MANDATORY SHA-256 INTEGRITY VERIFICATION
  // ===========================================================================

  String _computeCanonicalChecksum(
    List<dynamic> rawItems,
    Map<String, dynamic> rawSettings,
  ) {
    final canonical = jsonEncode(<String, dynamic>{
      'WatchCueItems': rawItems,
      'AppSettings': <String, dynamic>{
        'isDarkMode': rawSettings['isDarkMode'] ?? true,
        'tvIp': rawSettings['tvIp'] ?? '192.168.1.123',
      },
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Creates a canonical CueDeck backup JSON string with SHA-256 `Checksum`.
  Future<String> createBackupJson(
    List<WatchCueItem> items, {
    required bool isDarkMode,
    required String tvIp,
    TvDevice? selectedDevice,
  }) async {
    final autoEnabled = await isAutoBackupEnabled();
    final serializedItems = items.map((e) => e.toJson()).toList();
    final appSettings = <String, dynamic>{
      'isDarkMode': isDarkMode,
      'tvIp': tvIp,
      'selectedDevice': selectedDevice?.toJson(),
      'isAutoBackupEnabled': autoEnabled,
    };

    final checksum = _computeCanonicalChecksum(serializedItems, appSettings);
    final payload = <String, dynamic>{
      'SchemaVersion': 1,
      'AppVersion': '1.5.0',
      'BackupDate': DateTime.now().toUtc().toIso8601String(),
      'DeviceName': Platform.operatingSystem.toUpperCase(),
      'PlanCount': items.length,
      'WatchCueItems': serializedItems,
      'AppSettings': appSettings,
      'Checksum': checksum,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates backup JSON size, schema, and mandatory SHA-256 checksum, returning parsed items & settings.
  ParsedBackupPayload parseAndValidateBackupJson(String jsonString) {
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Yedek dosyası boş.');
    }
    final byteLen = utf8.encode(trimmed).length;
    if (byteLen > maxBackupJsonBytes) {
      throw const FormatException('Yedek dosyası 2 MB güvenlik sınırını aşıyor.');
    }

    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz yedek dosyası formatı.');
    }

    final rawItems = decoded['WatchCueItems'] ?? decoded['cueItems'];
    if (rawItems is! List) {
      throw const FormatException(
        'Yedek dosyasında izleme planı listesi (WatchCueItems) bulunamadı.',
      );
    }

    final rawSettings = decoded['AppSettings'] is Map<String, dynamic>
        ? decoded['AppSettings'] as Map<String, dynamic>
        : <String, dynamic>{};

    final providedChecksum = (decoded['Checksum'] as String?)?.trim();
    if (providedChecksum == null || providedChecksum.isEmpty) {
      throw const FormatException(
        'Yedek dosyasında SHA-256 Checksum eksik veya geçersiz.',
      );
    }

    final expectedChecksum = _computeCanonicalChecksum(rawItems, rawSettings);
    if (providedChecksum != expectedChecksum) {
      throw const FormatException(
        'Yedek dosyası bütünlük doğrulaması (SHA-256 Checksum) başarısız.',
      );
    }

    final parsedItems = <WatchCueItem>[];
    for (final entry in rawItems) {
      if (entry is Map<String, dynamic>) {
        parsedItems.add(WatchCueItem.fromJson(entry));
      } else if (entry is Map) {
        parsedItems.add(
          WatchCueItem.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }

    final backupDate = DateTime.tryParse(
      (decoded['BackupDate'] as String?) ?? '',
    );
    final deviceName = (decoded['DeviceName'] as String?) ?? 'Bulut Cihazı';

    return ParsedBackupPayload(
      items: parsedItems,
      settings: rawSettings,
      deviceName: deviceName,
      backupDate: backupDate,
    );
  }

  // ===========================================================================
  // CLOUD BACKUP, LISTING, DOWNLOAD & MULTI-DEVICE SYNC
  // ===========================================================================

  /// Saves backup locally and uploads both `CueDeck_CloudBackup.json` and a
  /// timestamped snapshot (`CueDeck_Backup_YYYYMMDD_HHMMSS_P<count>_<os>.json`)
  /// to Google Drive `appDataFolder`.
  Future<BackupOperationResult> backupToCloud({
    required List<WatchCueItem> items,
    required bool isDarkMode,
    required String tvIp,
    TvDevice? selectedDevice,
  }) async {
    try {
      final jsonContent = await createBackupJson(
        items,
        isDarkMode: isDarkMode,
        tvIp: tvIp,
        selectedDevice: selectedDevice,
      );

      // 1. Always save local copies in app documents directory
      await _saveLocalAppBackup(backupFileName, jsonContent);
      await _saveLocalAppBackup(autoBackupFileName, jsonContent);

      final bearer = await getValidAccessToken();
      if (bearer == null || bearer.isEmpty) {
        return BackupOperationResult(
          success: false,
          message:
              'Google Drive oturumu açık değil. Yedek cihaz hafızasına kaydedildi.',
          restoredCount: items.length,
        );
      }

      // 2. Find existing CueDeck_CloudBackup.json in appDataFolder
      final existingId = await _findCloudFileIdByName(bearer, backupFileName);
      if (existingId != null && existingId.isNotEmpty) {
        await _updateDriveFileMedia(bearer, existingId, jsonContent);
      } else {
        await _uploadMultipartFileToDrive(bearer, backupFileName, jsonContent);
      }

      // 3. Upload timestamped snapshot for revision history
      final now = DateTime.now();
      final nowStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final timestampedName =
          'CueDeck_Backup_${nowStr}_P${items.length}_${Platform.operatingSystem}.json';
      await _uploadMultipartFileToDrive(bearer, timestampedName, jsonContent);

      final store = await _openMetadataStore();
      await store.setInt(lastBackupTicksKey, now.millisecondsSinceEpoch);

      return BackupOperationResult(
        success: true,
        message:
            '✓ ${items.length} izleme planı Google Drive bulutuna yedeklendi',
        restoredCount: items.length,
        backupDate: now,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'Bulut yedekleme hatası: $e',
      );
    }
  }

  /// Lists all available CueDeck backups from Google Drive (`appDataFolder` & `drive`)
  /// and local storage, sorted newest first.
  Future<List<CloudBackupInfo>> listCloudBackups() async {
    final list = <CloudBackupInfo>[];
    final bearer = await getValidAccessToken();

    if (bearer != null && bearer.isNotEmpty) {
      // 1. Query appDataFolder
      try {
        final uri = Uri.parse(driveFilesEndpoint).replace(
          queryParameters: <String, String>{
            'spaces': 'appDataFolder',
            'fields': 'files(id,name,modifiedTime,size)',
            'pageSize': '50',
          },
        );
        final res = await _httpRequest(
          method: 'GET',
          uri: uri,
          headers: <String, String>{'Authorization': 'Bearer $bearer'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final files = data['files'] as List<dynamic>? ?? const <dynamic>[];
          for (final raw in files) {
            if (raw is! Map<String, dynamic>) continue;
            final id = (raw['id'] as String?) ?? '';
            final name = (raw['name'] as String?) ?? '';
            if (id.isEmpty || name.isEmpty) continue;
            final modTime = DateTime.tryParse(
                  (raw['modifiedTime'] as String?) ?? '',
                )?.toLocal() ??
                DateTime.now();
            final size = int.tryParse(raw['size']?.toString() ?? '');

            if (name == backupFileName) {
              list.add(
                CloudBackupInfo(
                  fileId: id,
                  fileName: name,
                  modifiedTime: modTime,
                  deviceName: 'Google Drive (Ana Bulut)',
                  displayName: 'Otomatik Bulut Yedeği (En Son)',
                  sizeBytes: size,
                ),
              );
              continue;
            }

            final parsedMeta = _parseBackupFilenameMeta(name);
            list.add(
              CloudBackupInfo(
                fileId: id,
                fileName: name,
                modifiedTime: modTime,
                deviceName: parsedMeta.deviceName,
                displayName: parsedMeta.displayName,
                planCount: parsedMeta.planCount,
                sizeBytes: size,
              ),
            );
          }
        }
      } catch (_) {}

      // 2. Query main Drive space for any user-uploaded CueDeck JSON files
      try {
        final uri = Uri.parse(driveFilesEndpoint).replace(
          queryParameters: <String, String>{
            'spaces': 'drive',
            'q': "name contains 'CueDeck' and trashed = false",
            'fields': 'files(id,name,modifiedTime,size)',
            'orderBy': 'modifiedTime desc',
            'pageSize': '25',
          },
        );
        final res = await _httpRequest(
          method: 'GET',
          uri: uri,
          headers: <String, String>{'Authorization': 'Bearer $bearer'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final files = data['files'] as List<dynamic>? ?? const <dynamic>[];
          for (final raw in files) {
            if (raw is! Map<String, dynamic>) continue;
            final id = (raw['id'] as String?) ?? '';
            final name = (raw['name'] as String?) ?? '';
            if (id.isEmpty || list.any((item) => item.fileId == id)) continue;
            final modTime = DateTime.tryParse(
                  (raw['modifiedTime'] as String?) ?? '',
                )?.toLocal() ??
                DateTime.now();
            final size = int.tryParse(raw['size']?.toString() ?? '');
            final parsedMeta = _parseBackupFilenameMeta(name);

            list.add(
              CloudBackupInfo(
                fileId: id,
                fileName: name,
                modifiedTime: modTime,
                deviceName: 'Google Drive Klasörü',
                displayName: parsedMeta.planCount != null
                    ? 'Drive Yedeği (${parsedMeta.planCount} Plan)'
                    : 'Drive Yedeği ($name)',
                planCount: parsedMeta.planCount,
                sizeBytes: size,
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 3. Scan local app documents directory for CueDeck_*.json backups
    final localBackups = await _findLocalBackupFiles();
    for (final local in localBackups) {
      if (!list.any((item) => item.fileName == local.fileName && item.isLocal)) {
        list.add(local);
      }
    }

    list.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return list;
  }

  ({int? planCount, String deviceName, String displayName})
      _parseBackupFilenameMeta(String fileName) {
    // Format: CueDeck_Backup_YYYYMMDD_HHMMSS_P<count>_<os>.json
    int? planCount;
    var deviceName = 'Bulut Cihazı';
    var displayName = 'Geçmiş Bulut Yedeği';

    if (fileName.startsWith('CueDeck_Backup_') && fileName.endsWith('.json')) {
      final clean = fileName.substring(0, fileName.length - 5);
      final parts = clean.split('_');
      if (parts.length >= 6) {
        final pPart = parts[4];
        if (pPart.startsWith('P')) {
          planCount = int.tryParse(pPart.substring(1));
        }
        deviceName = parts.sublist(5).join(' ').toUpperCase();
        displayName = planCount != null
            ? 'Geçmiş Yedek ($planCount Plan • $deviceName)'
            : 'Geçmiş Yedek ($deviceName)';
      }
    }
    return (
      planCount: planCount,
      deviceName: deviceName,
      displayName: displayName,
    );
  }

  /// Downloads a backup JSON string from Google Drive (or local storage if `local:` prefix).
  Future<String> downloadCloudBackupJson({String? fileId}) async {
    if (fileId != null && fileId.startsWith('local:')) {
      final localPath = fileId.substring(6);
      return _readSafeLocalFile(localPath);
    }

    final bearer = await getValidAccessToken();
    if (bearer != null && bearer.isNotEmpty) {
      var targetId = fileId?.trim() ?? '';
      if (targetId.isEmpty) {
        targetId =
            (await _findCloudFileIdByName(bearer, backupFileName)) ?? '';
      }
      if (targetId.isEmpty) {
        final all = await listCloudBackups();
        final cloudFirst =
            all.where((b) => !b.isLocal && !b.fileId.startsWith('local:'));
        if (cloudFirst.isNotEmpty) {
          targetId = cloudFirst.first.fileId;
        }
      }

      if (targetId.isNotEmpty && !targetId.startsWith('local:')) {
        if (!_safeFileIdRegex.hasMatch(targetId)) {
          throw const FormatException('Geçersiz bulut dosya kimliği (fileId).');
        }
        final uri = Uri.parse('$driveFilesEndpoint/$targetId?alt=media');
        final res = await _httpRequest(
          method: 'GET',
          uri: uri,
          headers: <String, String>{'Authorization': 'Bearer $bearer'},
        );
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return res.body;
        }
        throw HttpException(
          'Google Drive yedeği indirilemedi (HTTP ${res.statusCode}).',
        );
      }
    }

    // Fallback to local app backup if offline or no cloud file found
    final docsPath = await _getAppDocsDirectoryPath();
    if (docsPath != null) {
      final fallbackFile = File('$docsPath/$backupFileName');
      if (fallbackFile.existsSync()) {
        return _readSafeLocalFile(fallbackFile.path);
      }
    }

    throw const FileSystemException(
      'Google Drive hesabınızda veya cihaz hafızasında kayıtlı yedek bulunamadı.',
    );
  }

  /// Multi-device reconciliation: merges local watch plans with the latest cloud
  /// backup by `id` (preserving the highest watched progress/episode and all new plans),
  /// then uploads the unified state back to Google Drive.
  Future<BackupOperationResult> syncAndMergeWithCloud({
    required List<WatchCueItem> localItems,
    required bool isDarkMode,
    required String tvIp,
    TvDevice? selectedDevice,
  }) async {
    try {
      final bearer = await getValidAccessToken();
      if (bearer == null || bearer.isEmpty) {
        return const BackupOperationResult(
          success: false,
          message:
              'Çoklu cihaz eşitlemesi için önce Google Drive hesabınızla giriş yapın.',
        );
      }

      List<WatchCueItem> cloudItems = const <WatchCueItem>[];
      Map<String, dynamic> cloudSettings = const <String, dynamic>{};

      final cloudFileId = await _findCloudFileIdByName(bearer, backupFileName);
      if (cloudFileId != null && cloudFileId.isNotEmpty) {
        try {
          final cloudJson = await downloadCloudBackupJson(fileId: cloudFileId);
          final parsed = parseAndValidateBackupJson(cloudJson);
          cloudItems = parsed.items;
          cloudSettings = parsed.settings;
        } catch (_) {
          // If cloud file doesn't exist or is unreadable, proceed with local items
        }
      }

      final mergedMap = <String, WatchCueItem>{};
      for (final item in cloudItems) {
        mergedMap[item.id] = item;
      }

      for (final local in localItems) {
        final existing = mergedMap[local.id];
        if (existing == null) {
          mergedMap[local.id] = local;
        } else {
          // Keep whichever item has further watch progress (episode & watchedMinutes)
          final localScore =
              (local.currentEpisode * 10000) + local.watchedMinutes;
          final cloudScore =
              (existing.currentEpisode * 10000) + existing.watchedMinutes;
          if (localScore >= cloudScore) {
            mergedMap[local.id] = local;
          } else {
            mergedMap[local.id] = local.copyWith(
              watchedMinutes: existing.watchedMinutes,
              currentEpisode: existing.currentEpisode,
              totalMinutes: existing.totalMinutes > local.totalMinutes
                  ? existing.totalMinutes
                  : local.totalMinutes,
              totalEpisodes: existing.totalEpisodes > local.totalEpisodes
                  ? existing.totalEpisodes
                  : local.totalEpisodes,
            );
          }
        }
      }

      final mergedList = mergedMap.values.toList();
      final uploadRes = await backupToCloud(
        items: mergedList,
        isDarkMode: isDarkMode,
        tvIp: tvIp,
        selectedDevice: selectedDevice,
      );

      return BackupOperationResult(
        success: uploadRes.success,
        message: uploadRes.success
            ? '✓ Cihazlar eşitlendi (${mergedList.length} izleme planı birleştirildi)'
            : uploadRes.message,
        restoredCount: mergedList.length,
        backupDate: DateTime.now(),
        restoredItems: mergedList,
        restoredSettings: cloudSettings,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'Cihaz eşitleme hatası: $e',
      );
    }
  }

  // ===========================================================================
  // LOCAL SAF FILE EXPORT & IMPORT
  // ===========================================================================

  /// Exports a `.json` backup file to a user-selected location via Android SAF
  /// (with app directory fallback).
  Future<BackupOperationResult> exportBackupToFile({
    required List<WatchCueItem> items,
    required bool isDarkMode,
    required String tvIp,
    TvDevice? selectedDevice,
  }) async {
    try {
      final jsonContent = await createBackupJson(
        items,
        isDarkMode: isDarkMode,
        tvIp: tvIp,
        selectedDevice: selectedDevice,
      );

      final now = DateTime.now();
      final dateTag =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'CueDeck_Yedek_$dateTag.json';

      await _saveLocalAppBackup(fileName, jsonContent);

      try {
        final savedUri = await _storageChannel.invokeMethod<String>(
          'saveBackupFile',
          <String, dynamic>{
            'fileName': fileName,
            'content': jsonContent,
          },
        );
        if (savedUri != null && savedUri.isNotEmpty) {
          return BackupOperationResult(
            success: true,
            message: '✓ Yedek dosyası kaydedildi: $fileName',
            restoredCount: items.length,
            backupDate: now,
          );
        }
      } catch (_) {
        // Fallback when SAF dialog is unavailable (e.g. desktop/test)
      }

      return BackupOperationResult(
        success: true,
        message: '✓ Yedek dosyası uygulama dizinine kaydedildi: $fileName',
        restoredCount: items.length,
        backupDate: now,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'Dosyaya yedekleme başarısız: $e',
      );
    }
  }

  /// Opens the native Android SAF file picker to import and validate a `.json` backup file.
  Future<BackupOperationResult> importBackupFromFile() async {
    try {
      String? rawJson;
      try {
        rawJson = await _storageChannel.invokeMethod<String>('pickBackupFile');
      } catch (_) {}

      if (rawJson == null || rawJson.trim().isEmpty) {
        // Fallback to local app backup if user canceled or running in test environment
        final docsPath = await _getAppDocsDirectoryPath();
        if (docsPath != null) {
          final fallback = File('$docsPath/$backupFileName');
          if (fallback.existsSync()) {
            rawJson = await _readSafeLocalFile(fallback.path);
          }
        }
      }

      if (rawJson == null || rawJson.trim().isEmpty) {
        return const BackupOperationResult(
          success: false,
          message: 'Dosya seçimi iptal edildi veya yedek dosyası bulunamadı.',
        );
      }

      final parsed = parseAndValidateBackupJson(rawJson);
      return BackupOperationResult(
        success: true,
        message:
            '✓ Yedek dosyasından ${parsed.items.length} izleme planı geri yüklendi',
        restoredCount: parsed.items.length,
        backupDate: parsed.backupDate ?? DateTime.now(),
        restoredItems: parsed.items,
        restoredSettings: parsed.settings,
      );
    } catch (e) {
      return BackupOperationResult(
        success: false,
        message: 'Yedek dosyası okunamadı: $e',
      );
    }
  }

  // ===========================================================================
  // INTERNAL DRIVE REST & FILE SYSTEM HELPERS
  // ===========================================================================

  Future<String?> _findCloudFileIdByName(String bearer, String name) async {
    final uri = Uri.parse(driveFilesEndpoint).replace(
      queryParameters: <String, String>{
        'spaces': 'appDataFolder',
        'q': "name = '$name' and 'appDataFolder' in parents and trashed = false",
        'fields': 'files(id,name,modifiedTime)',
      },
    );
    final res = await _httpRequest(
      method: 'GET',
      uri: uri,
      headers: <String, String>{'Authorization': 'Bearer $bearer'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? const <dynamic>[];
      if (files.isNotEmpty && files.first is Map<String, dynamic>) {
        return (files.first as Map<String, dynamic>)['id'] as String?;
      }
    }
    return null;
  }

  Future<void> _updateDriveFileMedia(
    String bearer,
    String fileId,
    String jsonContent,
  ) async {
    if (!_safeFileIdRegex.hasMatch(fileId)) {
      throw const FormatException('Geçersiz Drive dosya kimliği.');
    }
    final uri = Uri.parse('$driveUploadEndpoint/$fileId?uploadType=media');
    final res = await _httpRequest(
      method: 'PATCH',
      uri: uri,
      headers: <String, String>{
        'Authorization': 'Bearer $bearer',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      bodyBytes: utf8.encode(jsonContent),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Drive güncelleme hatası (HTTP ${res.statusCode}).');
    }
  }

  Future<void> _uploadMultipartFileToDrive(
    String bearer,
    String fileName,
    String jsonContent,
  ) async {
    final boundary =
        '----CueDeckBoundary${DateTime.now().millisecondsSinceEpoch}';
    final metadataJson = jsonEncode(<String, dynamic>{
      'name': fileName,
      'parents': <String>['appDataFolder'],
    });

    final multipartBody = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$jsonContent\r\n'
        '--$boundary--\r\n';

    final uri = Uri.parse('$driveUploadEndpoint?uploadType=multipart');
    final res = await _httpRequest(
      method: 'POST',
      uri: uri,
      headers: <String, String>{
        'Authorization': 'Bearer $bearer',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      bodyBytes: utf8.encode(multipartBody),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Drive yükleme hatası (HTTP ${res.statusCode}).');
    }
  }

  Future<String?> _getAppDocsDirectoryPath() async {
    try {
      final path = await _storageChannel.invokeMethod<String>('getAppDocsPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    try {
      return Directory.systemTemp.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalAppBackup(String fileName, String content) async {
    try {
      final docsPath = await _getAppDocsDirectoryPath();
      if (docsPath == null) return;
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      if (!_safeLocalFilenameRegex.hasMatch(safeName)) return;
      final file = File('$docsPath/$safeName');
      await file.writeAsString(content, encoding: utf8);
    } catch (_) {}
  }

  Future<List<CloudBackupInfo>> _findLocalBackupFiles() async {
    final found = <CloudBackupInfo>[];
    final docsPath = await _getAppDocsDirectoryPath();
    if (docsPath == null) return found;

    final dir = Directory(docsPath);
    if (!dir.existsSync()) return found;

    try {
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (!_safeLocalFilenameRegex.hasMatch(name)) continue;
        final stat = entity.statSync();
        if (stat.size > maxBackupJsonBytes) continue;
        final meta = _parseBackupFilenameMeta(name);
        found.add(
          CloudBackupInfo(
            fileId: 'local:${entity.path}',
            fileName: name,
            modifiedTime: stat.modified,
            deviceName: 'Bu Cihaz (Yerel Hafıza)',
            displayName: name == backupFileName
                ? 'Cihaz İçi Son Yedek'
                : 'Yerel Yedek ($name)',
            planCount: meta.planCount,
            sizeBytes: stat.size,
            isLocal: true,
            localFilePath: entity.path,
          ),
        );
      }
    } catch (_) {}
    return found;
  }

  Future<String> _readSafeLocalFile(String path) async {
    final docsPath = await _getAppDocsDirectoryPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw const FileSystemException('Uygulama yedek dizinine erişilemiyor.');
    }

    final normalizedDocs = docsPath.replaceAll('\\', '/');
    final normalizedPath = path.replaceAll('\\', '/');
    if (normalizedPath.contains('..') ||
        !normalizedPath.startsWith('$normalizedDocs/')) {
      throw const FileSystemException(
        'Güvenlik ihlali: Yalnızca uygulama yedek dizinindeki dosyalar okunabilir.',
      );
    }

    final fileName = normalizedPath.split('/').last;
    if (!_safeLocalFilenameRegex.hasMatch(fileName)) {
      throw const FileSystemException('Geçersiz yerel yedek dosya adı.');
    }

    final file = File('$docsPath/$fileName');
    if (!file.existsSync()) {
      throw const FileSystemException('Yerel yedek dosyası bulunamadı.');
    }
    final stat = file.statSync();
    if (stat.size > maxBackupJsonBytes) {
      throw const FormatException('Yerel yedek dosyası 2 MB sınırını aşıyor.');
    }
    return file.readAsString(encoding: utf8);
  }

  Future<({int statusCode, String body})> _httpRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _httpTimeout;
    try {
      final request = await client.openUrl(method, uri).timeout(_httpTimeout);
      headers.forEach(request.headers.set);
      if (bodyBytes != null && bodyBytes.isNotEmpty) {
        request.contentLength = bodyBytes.length;
        request.add(bodyBytes);
      }
      final response = await request.close().timeout(_httpTimeout);
      final collected = <int>[];
      var totalBytes = 0;
      await for (final List<int> chunk in response.timeout(_httpTimeout)) {
        totalBytes += chunk.length;
        if (totalBytes > maxBackupJsonBytes) {
          throw const FormatException(
            'Bulut yanıtı 2 MB güvenlik sınırını aşıyor.',
          );
        }
        collected.addAll(chunk);
      }
      final responseBody = utf8.decode(collected, allowMalformed: true);
      return (statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close(force: false);
    }
  }
}

Future<SharedPreferences> _openMetadataStore() =>
    SharedPreferences.getInstance();
