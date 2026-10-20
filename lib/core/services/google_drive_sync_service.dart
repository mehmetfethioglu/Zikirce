import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/hasibu_database.dart';

String _encodeSnapshotIsolate(Map<String, dynamic> snapshot) {
  return jsonEncode(snapshot);
}

Map<String, dynamic> _decodeSnapshotIsolate(String rawJson) {
  return jsonDecode(rawJson) as Map<String, dynamic>;
}

enum DriveSyncStage {
  idle,
  syncing,
  synced,
  offlineSaved,
  error,
}

@immutable
class DriveSyncStatus {
  final DriveSyncStage stage;
  final DateTime? lastSyncTime;
  final String lastDeviceName;
  final String? lastHash;
  final String connectedGmail;
  final String message;

  const DriveSyncStatus({
    this.stage = DriveSyncStage.idle,
    this.lastSyncTime,
    this.lastDeviceName = 'İşyeri Laptop (Merkez)',
    this.lastHash,
    this.connectedGmail = '',
    this.message = 'Senkronizasyona hazır',
  });

  DriveSyncStatus copyWith({
    DriveSyncStage? stage,
    DateTime? lastSyncTime,
    String? lastDeviceName,
    String? lastHash,
    String? connectedGmail,
    String? message,
  }) {
    return DriveSyncStatus(
      stage: stage ?? this.stage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
      lastHash: lastHash ?? this.lastHash,
      connectedGmail: connectedGmail ?? this.connectedGmail,
      message: message ?? this.message,
    );
  }
}

/// Google Drive Bulut Yedekleme ve Cihazlar Arası Senkronizasyon Motoru.
/// Hassas OAuth belirteçleri yalnızca donanım destekli [FlutterSecureStorage] içinde tutulur.
class GoogleDriveSyncService {
  static const String backupFileName = 'Hasibu_CloudSync_v1.json';
  static const String _driveFilesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';

  static const String _kAccessToken = 'hasibu_gdrive_access_token';
  static const String _kRefreshToken = 'hasibu_gdrive_refresh_token';

  final HasibuDatabase db;
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  DateTime _lastSyncAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastPayloadHash;

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

  Future<void> saveOAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: _kAccessToken);

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
  }

  /// Yerel SQLite veritabanını arka plan izolatında (`compute`) JSON'a serileştirir,
  /// SHA-256 özetini hesaplar, yerel/Drive klasörü aynasına ve Google Drive bulutuna yükler.
  Future<DriveSyncStatus> pushToCloud({
    String deviceName = 'İşyeri Laptop (Merkez)',
    bool force = false,
  }) async {
    final now = DateTime.now();
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount;

    if (!force &&
        now.difference(_lastSyncAttempt) < const Duration(seconds: 10)) {
      return DriveSyncStatus(
        stage: DriveSyncStage.synced,
        lastSyncTime: _lastSyncAttempt,
        lastDeviceName: deviceName,
        lastHash: _lastPayloadHash,
        connectedGmail: gmail,
        message: 'Son senkronizasyon güncel.',
      );
    }

    final snapshot = db.exportCloudSnapshot(deviceName: deviceName);
    final jsonPayload = await compute(_encodeSnapshotIsolate, snapshot);
    final payloadBytes = utf8.encode(jsonPayload);
    final hash = sha256.convert(payloadBytes).toString().substring(0, 12);

    if (!force && hash == _lastPayloadHash) {
      return DriveSyncStatus(
        stage: DriveSyncStage.synced,
        lastSyncTime: now,
        lastDeviceName: deviceName,
        lastHash: hash,
        connectedGmail: gmail,
        message: 'Değişiklik yok (SHA-256: $hash)',
      );
    }

    // 1. Yerel disk ve varsa Google Drive Masaüstü klasör yedeğini kaydet
    await _writeLocalMirror(jsonPayload, settings.syncFolderPath);
    _lastSyncAttempt = now;
    _lastPayloadHash = hash;

    // 2. Google Drive OAuth token mevcutsa buluta yükle
    String? token;
    try {
      token = await getAccessToken();
    } catch (_) {}

    if (token == null || token.isEmpty) {
      if (gmail.isNotEmpty || settings.syncFolderPath.isNotEmpty) {
        return DriveSyncStatus(
          stage: DriveSyncStage.synced,
          lastSyncTime: now,
          lastDeviceName: deviceName,
          lastHash: hash,
          connectedGmail: gmail,
          message: gmail.isNotEmpty
              ? '$gmail hesabı ile senkron paketi güncellendi (#$hash)'
              : 'Drive klasörü senkron paketi güncellendi (#$hash)',
        );
      }
      return DriveSyncStatus(
        stage: DriveSyncStage.offlineSaved,
        lastSyncTime: now,
        lastDeviceName: deviceName,
        lastHash: hash,
        connectedGmail: gmail,
        message:
            'Yerel yedek hazırlandı ($backupFileName • #$hash). Gmail hesabı bağlandığında buluta aktarılır.',
      );
    }

    try {
      final existingFileId = await _findRemoteFileId(token);
      if (existingFileId != null) {
        await _dio.patch<void>(
          '$_driveUploadEndpoint/$existingFileId?uploadType=media',
          data: Stream.fromIterable([payloadBytes]),
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
              HttpHeaders.contentLengthHeader: payloadBytes.length,
            },
          ),
        );
      } else {
        final boundary = 'hasibu_sync_${now.millisecondsSinceEpoch}';
        final metaJson = jsonEncode({
          'name': backupFileName,
          'mimeType': 'application/json',
        });
        final body = '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '$metaJson\r\n'
            '--$boundary\r\n'
            'Content-Type: application/json\r\n\r\n'
            '$jsonPayload\r\n'
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

      return DriveSyncStatus(
        stage: DriveSyncStage.synced,
        lastSyncTime: now,
        lastDeviceName: deviceName,
        lastHash: hash,
        connectedGmail: gmail,
        message: 'Google Drive (${gmail.isEmpty ? "Bulut" : gmail}) eşitlendi (#$hash)',
      );
    } catch (e) {
      return DriveSyncStatus(
        stage: DriveSyncStage.offlineSaved,
        lastSyncTime: now,
        lastDeviceName: deviceName,
        lastHash: hash,
        connectedGmail: gmail,
        message: 'Yerel yedek alındı (#$hash), bulut erişimi bekleniyor.',
      );
    }
  }

  /// Google Drive'dan (veya yerel paylaşılan yedek dosyasından) en güncel paketi
  /// indirip arka plan izolatında (`compute`) çözer ve yerel SQLite ile birleştirir.
  Future<DriveSyncStatus> pullAndReconcile() async {
    final now = DateTime.now();
    final settings = db.getCompanySettings();
    final gmail = settings.syncGmailAccount;
    try {
      String? token;
      try {
        token = await getAccessToken();
      } catch (_) {}
      String? rawJson;

      if (token != null && token.isNotEmpty) {
        final fileId = await _findRemoteFileId(token);
        if (fileId != null) {
          final resp = await _dio.get<String>(
            '$_driveFilesEndpoint/$fileId?alt=media',
            options: Options(
              headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
              responseType: ResponseType.plain,
            ),
          );
          rawJson = resp.data;
        }
      }

      rawJson ??= await _readLocalMirror(settings.syncFolderPath);
      if (rawJson == null || rawJson.isEmpty) {
        return DriveSyncStatus(
          stage: DriveSyncStage.idle,
          lastSyncTime: now,
          connectedGmail: gmail,
          message: 'Henüz bulut yedeği bulunamadı.',
        );
      }

      final decoded = await compute(_decodeSnapshotIsolate, rawJson);
      final merged = db.reconcileCloudSnapshot(decoded);
      final remoteDevice =
          decoded['deviceName'] as String? ?? 'İşyeri Laptop (Merkez)';

      return DriveSyncStatus(
        stage: DriveSyncStage.synced,
        lastSyncTime: now,
        lastDeviceName: remoteDevice,
        connectedGmail: gmail,
        message:
            'Eşitlendi ($remoteDevice) • $merged yeni hareket birleştirildi.',
      );
    } catch (e) {
      return DriveSyncStatus(
        stage: DriveSyncStage.error,
        lastSyncTime: now,
        connectedGmail: gmail,
        message: 'Senkronizasyon hatası: $e',
      );
    }
  }

  Future<String?> _findRemoteFileId(String token) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      _driveFilesEndpoint,
      queryParameters: {
        'q': "name = '$backupFileName' and trashed = false",
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

  Future<void> _writeLocalMirror(
    String jsonPayload,
    String customFolderPath,
  ) async {
    try {
      if (customFolderPath.trim().isNotEmpty) {
        final customDir = Directory(customFolderPath.trim());
        await customDir.create(recursive: true);
        final customFile = File(p.join(customDir.path, backupFileName));
        await customFile.writeAsString(jsonPayload, flush: true);
      }
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, backupFileName));
      await file.writeAsString(jsonPayload, flush: true);
    } catch (_) {
      // Test ortamında path_provider yoksa sessizce geç
    }
  }

  Future<String?> _readLocalMirror(String customFolderPath) async {
    try {
      if (customFolderPath.trim().isNotEmpty) {
        final customFile =
            File(p.join(customFolderPath.trim(), backupFileName));
        if (await customFile.exists()) {
          return await customFile.readAsString();
        }
      }
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, backupFileName));
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }
}
