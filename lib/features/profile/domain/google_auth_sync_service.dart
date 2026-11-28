import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/kilerce_backup_service.dart';
import 'user_profile_service.dart';

/// Metadata model for cloud backup file located in Google Drive AppData
class CloudBackupInfo {
  final bool exists;
  final String? fileId;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  const CloudBackupInfo({
    required this.exists,
    this.fileId,
    this.modifiedTime,
    this.sizeBytes,
  });

  static const CloudBackupInfo empty = CloudBackupInfo(exists: false);
}

/// Result container for Google authentication operations
class GoogleAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;
  final CloudBackupInfo? cloudBackup;

  const GoogleAuthResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.errorMessage,
    this.cloudBackup,
  });
}

/// Service managing independent Google Sign-In and Google Drive AppData synchronization
class GoogleAuthSyncService extends ChangeNotifier {
  static final GoogleAuthSyncService instance = GoogleAuthSyncService._internal();
  GoogleAuthSyncService._internal();

  static const String _backupFileName = 'organicscore_backup.json';
  static const String _driveScope = 'https://www.googleapis.com/auth/drive.appdata';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      _driveScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastSyncMessage;
  String? get lastSyncMessage => _lastSyncMessage;

  /// Initializes Google Sign-In state and restores previous session silently if available
  Future<void> init() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _updateUserProfileFromAccount(_currentUser!);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthSyncService.init error: $e');
      }
    }
  }

  /// Triggers interactive Google Sign-In flow
  Future<GoogleAuthResult> signIn() async {
    try {
      _isSyncing = true;
      notifyListeners();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        _isSyncing = false;
        notifyListeners();
        return const GoogleAuthResult(isSuccess: false, isCancelled: true);
      }

      _currentUser = account;
      await _updateUserProfileFromAccount(account);

      // Check if an existing cloud backup exists in Google Drive AppData
      final backupInfo = await checkCloudBackup();

      _isSyncing = false;
      notifyListeners();

      return GoogleAuthResult(
        isSuccess: true,
        cloudBackup: backupInfo,
      );
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      final err = e.toString();
      if (kDebugMode) {
        debugPrint('GoogleAuthSyncService.signIn error: $err');
      }
      return GoogleAuthResult(
        isSuccess: false,
        errorMessage: _humanizeError(err),
      );
    }
  }

  /// Disconnects Google account while preserving all local statistics and badges
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      await UserProfileService.instance.clearGoogleAccount();
      _lastSyncMessage = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthSyncService.signOut error: $e');
      }
    }
  }

  /// Checks if a backup file exists in Google Drive AppData folder
  Future<CloudBackupInfo> checkCloudBackup() async {
    if (_currentUser == null) return CloudBackupInfo.empty;

    try {
      final headers = await _currentUser!.authHeaders;
      final uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        '?spaces=appDataFolder'
        '&q=name%3D\'$_backupFileName\''
        '&fields=files(id,name,modifiedTime,size)',
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? files = data['files'] as List<dynamic>?;

        if (files != null && files.isNotEmpty) {
          final first = files.first as Map<String, dynamic>;
          final fileId = first['id'] as String?;
          final modifiedTimeStr = first['modifiedTime'] as String?;
          final sizeStr = first['size'] as String?;

          final modified = modifiedTimeStr != null ? DateTime.tryParse(modifiedTimeStr) : null;
          final size = sizeStr != null ? int.tryParse(sizeStr) : null;

          return CloudBackupInfo(
            exists: true,
            fileId: fileId,
            modifiedTime: modified,
            sizeBytes: size,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthSyncService.checkCloudBackup error: $e');
      }
    }

    return CloudBackupInfo.empty;
  }

  /// Restores user profile and badges from Google Drive AppData
  Future<bool> restoreFromCloud({String? specificFileId}) async {
    if (_currentUser == null) return false;

    try {
      _isSyncing = true;
      notifyListeners();

      String? fileId = specificFileId;
      if (fileId == null) {
        final info = await checkCloudBackup();
        fileId = info.fileId;
      }

      if (fileId == null) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final headers = await _currentUser!.authHeaders;
      final downloadUri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
      final response = await http
          .get(downloadUri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonStr = utf8.decode(response.bodyBytes);
        final success = await KilerceBackupService.importFullBackupJson(jsonStr);
        if (success) {
          _lastSyncMessage = 'Buluttan başarıyla geri yüklendi';
        }
        _isSyncing = false;
        notifyListeners();
        return success;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthSyncService.restoreFromCloud error: $e');
      }
    }

    _isSyncing = false;
    notifyListeners();
    return false;
  }

  /// Exports local snapshot and uploads/updates it in Google Drive AppData
  Future<bool> uploadToCloud() async {
    _currentUser ??= await _googleSignIn.signInSilently();
    if (_currentUser == null) {
      _lastSyncMessage = 'Google oturumu aktif değil. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }

    try {
      _isSyncing = true;
      notifyListeners();

      final backupJson = await KilerceBackupService.exportFullBackupJson();
      final headers = await _currentUser!.authHeaders;

      // Check if backup file already exists in AppData
      final existing = await checkCloudBackup();

      if (existing.exists && existing.fileId != null) {
        // Update existing file content
        final updateUri = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/${existing.fileId}?uploadType=media',
        );
        final updateHeaders = Map<String, String>.from(headers)
          ..['Content-Type'] = 'application/json; charset=utf-8';

        final response = await http
            .patch(
              updateUri,
              headers: updateHeaders,
              body: utf8.encode(backupJson),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await UserProfileService.instance.updateLastBackupTimestamp(now);
          _lastSyncMessage = 'Drive ile eşitlendi';
          _isSyncing = false;
          notifyListeners();
          return true;
        } else {
          _lastSyncMessage = _parseDriveApiError(response.statusCode, response.body);
          _isSyncing = false;
          notifyListeners();
          return false;
        }
      } else {
        // Create new file metadata inside appDataFolder
        final createUri = Uri.parse('https://www.googleapis.com/drive/v3/files');
        final createHeaders = Map<String, String>.from(headers)
          ..['Content-Type'] = 'application/json; charset=utf-8';

        final metadataBody = jsonEncode({
          'name': _backupFileName,
          'parents': ['appDataFolder'],
        });

        final createResp = await http
            .post(
              createUri,
              headers: createHeaders,
              body: metadataBody,
            )
            .timeout(const Duration(seconds: 12));

        if (createResp.statusCode == 200) {
          final createdData = jsonDecode(createResp.body) as Map<String, dynamic>;
          final newFileId = createdData['id'] as String?;

          if (newFileId != null) {
            // Upload the JSON content into the created file
            final mediaUri = Uri.parse(
              'https://www.googleapis.com/upload/drive/v3/files/$newFileId?uploadType=media',
            );
            final mediaHeaders = Map<String, String>.from(headers)
              ..['Content-Type'] = 'application/json; charset=utf-8';

            final mediaResp = await http
                .patch(
                  mediaUri,
                  headers: mediaHeaders,
                  body: utf8.encode(backupJson),
                )
                .timeout(const Duration(seconds: 15));

            if (mediaResp.statusCode == 200) {
              final now = DateTime.now().millisecondsSinceEpoch;
              await UserProfileService.instance.updateLastBackupTimestamp(now);
              _lastSyncMessage = 'Drive ile eşitlendi';
              _isSyncing = false;
              notifyListeners();
              return true;
            } else {
              _lastSyncMessage = _parseDriveApiError(mediaResp.statusCode, mediaResp.body);
              _isSyncing = false;
              notifyListeners();
              return false;
            }
          }
        } else {
          _lastSyncMessage = _parseDriveApiError(createResp.statusCode, createResp.body);
          _isSyncing = false;
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _lastSyncMessage = 'Bağlantı hatası: $e';
    }

    _isSyncing = false;
    notifyListeners();
    return false;
  }

  String _parseDriveApiError(int statusCode, String body) {
    if (body.contains('it is disabled') || body.contains('has not been used in project')) {
      return 'Google Cloud Console\'da "Google Drive API" etkinleştirilmelidir (Hata 403).';
    }
    if (statusCode == 401) {
      return 'Oturum süresi doldu. Lütfen Çıkış yapıp tekrar Google ile bağlanın.';
    }
    if (statusCode == 403) {
      if (body.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') || body.contains('insufficientPermissions')) {
        return 'Google Drive izin kapsamı yetersiz. Lütfen Çıkış yapıp tekrar giriş yapın.';
      }
      return 'Google Drive erişim izni reddedildi (Hata 403). Google Cloud Console\'dan Drive API\'yi etkinleştirin.';
    }
    return 'Google Drive Hatası ($statusCode)';
  }

  Future<void> _updateUserProfileFromAccount(GoogleSignInAccount account) async {
    await UserProfileService.instance.setGoogleAccountInfo(
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  String _humanizeError(String error) {
    if (error.contains('network_error')) {
      return 'İnternet bağlantısı kurulamadı. Lütfen ağınızı kontrol edin.';
    }
    if (error.contains('sign_in_canceled') || error.contains('canceled')) {
      return 'Giriş işlemi iptal edildi.';
    }
    if (error.contains('ApiException: 10') || error.contains('DEVELOPER_ERROR')) {
      return 'Google Cloud yapılandırması (SHA-1/OAuth) gerekiyor. Lütfen geliştirici ayarlarını kontrol edin.';
    }
    if (error.contains('GIDClientID') ||
        error.contains('No active configuration') ||
        error.contains('missing support for the following URL schemes') ||
        error.contains('keychain')) {
      return 'iOS Google Sign-In yapılandırması (GIDClientID/URL Scheme) eksik veya hatalı.';
    }
    if (error.contains('access_denied') || error.contains('403')) {
      return 'Google hesabı erişim izni reddedildi. OAuth izin veya test kullanıcısı ayarlarını kontrol edin.';
    }
    return 'Google oturumu açılırken bir sorun oluştu. Lütfen tekrar deneyin.';
  }
}
