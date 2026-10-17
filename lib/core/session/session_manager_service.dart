import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pref_utils.dart';
import '../utils/secure_storage_helper.dart';
import 'user_session.dart';

class SessionManagerService {
  static const String _sessionsListKey = 'App_UserSessionsList_V1';
  static const String _activeSessionIdKey = 'App_ActiveSessionId_V1';
  static const String _pinSalt = 'Zikirce_Secure_Session_Salt_2026';

  /// PIN Hash Hesaplayıcı (SHA-256 + Salt)
  static String hashPin(String pin) {
    final bytes = utf8.encode('$pin:$_pinSalt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Tüm kayıtlı oturumları yükler ve gerekirse eski tekil oturumu migrate eder
  static Future<List<UserSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionsListKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
        final sessions = list
            .map((item) => UserSession.fromMap(item as Map<String, dynamic>))
            .toList();

        if (sessions.isNotEmpty) {
          return sessions;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[SessionManagerService] JSON parse error: $e');
        }
      }
    }

    // İlk kurulum veya eski versiyondan geçiş (Migration)
    final defaultSession = await _createInitialMigratedSession(prefs);
    final initialList = [defaultSession];
    await saveSessions(initialList);
    await setActiveSessionId(defaultSession.id);
    return initialList;
  }

  /// Eski tekil verileri "Ana Profil" olarak bağlar (Sıfır veri kaybı)
  static Future<UserSession> _createInitialMigratedSession(SharedPreferences prefs) async {
    final name = PrefUtils.getStringFromKeys(prefs, ['UserDisplayName', 'user_display_name'], 'Ana Profil');
    final avatar = PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar', 'ProfileImagePath'], 'assets/images/avatar_male_1.png');
    final email = PrefUtils.getStringOrNull(prefs, 'GoogleDrive_UserEmail');
    final isCloud = email != null && email.isNotEmpty;

    return UserSession.defaultSession(
      displayName: name.isNotEmpty ? name : 'Ana Profil',
      avatar: avatar.isNotEmpty ? avatar : 'assets/images/avatar_male_1.png',
      email: email,
      isCloud: isCloud,
    );
  }

  /// Oturum listesini SharedPreferences'e kaydeder
  static Future<void> saveSessions(List<UserSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sessions.map((s) => s.toMap()).toList();
    await prefs.setString(_sessionsListKey, jsonEncode(list));
  }

  /// Aktif oturum kimliğini getirir
  static Future<String> getActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeSessionIdKey);
    if (activeId != null && activeId.isNotEmpty) {
      return activeId;
    }
    return UserSession.defaultSessionId;
  }

  /// Aktif oturum kimliğini günceller
  static Future<void> setActiveSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSessionIdKey, id);
  }

  static int _idCounter = 0;

  /// Yeni Yerel Oturum Oluşturur
  static Future<UserSession> createLocalSession({
    String? id,
    required String name,
    required String avatar,
    String? pin,
  }) async {
    final sessions = await loadSessions();
    final newId = (id != null && id.isNotEmpty)
        ? id
        : 'usr_${DateTime.now().microsecondsSinceEpoch}_${++_idCounter}';
    final dbName = 'zikirce_user_$newId.sqlite';

    final hasPin = pin != null && pin.trim().length == 4;
    final pinHash = hasPin ? hashPin(pin.trim()) : null;
    final now = DateTime.now();

    final newSession = UserSession(
      id: newId,
      displayName: name.trim(),
      avatar: avatar,
      isCloud: false,
      email: null,
      hasPin: hasPin,
      pinHash: pinHash,
      dbFileName: dbName,
      createdAt: now,
      lastActiveAt: now,
    );

    sessions.add(newSession);
    await saveSessions(sessions);
    return newSession;
  }

  /// Yeni Google Bulut Oturumu Oluşturur
  static Future<UserSession> createCloudSession({
    String? id,
    required String name,
    required String avatar,
    required String email,
    String? pin,
  }) async {
    final sessions = await loadSessions();
    final newId = (id != null && id.isNotEmpty)
        ? id
        : 'usr_${DateTime.now().microsecondsSinceEpoch}_${++_idCounter}';
    final dbName = 'zikirce_user_$newId.sqlite';

    final hasPin = pin != null && pin.trim().length == 4;
    final pinHash = hasPin ? hashPin(pin.trim()) : null;
    final now = DateTime.now();

    final newSession = UserSession(
      id: newId,
      displayName: name.trim(),
      avatar: avatar,
      isCloud: true,
      email: email.trim(),
      hasPin: hasPin,
      pinHash: pinHash,
      dbFileName: dbName,
      createdAt: now,
      lastActiveAt: now,
    );

    sessions.add(newSession);
    await saveSessions(sessions);
    return newSession;
  }

  /// Var olan oturumu günceller (isim, avatar, bulut bağlantısı vb.)
  static Future<void> updateSession(UserSession updated) async {
    final sessions = await loadSessions();
    final index = sessions.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      sessions[index] = updated.copyWith(lastActiveAt: DateTime.now());
      await saveSessions(sessions);
    }
  }

  /// Oturumu siler (Varsayılan ana oturum silinemez, kalan son oturum silinemez)
  static Future<bool> deleteSession(String sessionId) async {
    final sessions = await loadSessions();
    if (sessions.length <= 1) {
      return false; // Son oturum silinemez
    }

    final target = sessions.firstWhere((s) => s.id == sessionId, orElse: () => sessions.first);
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);

    // İlgili SQLite veritabanı dosyasını sil (varsayılan ana dosya haricinde)
    if (target.dbFileName != UserSession.defaultDbName) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final dbFile = File(p.join(docs.path, target.dbFileName));
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          print('[SessionManagerService] DB file deletion error: $e');
        }
      }
    }

    // Google Token'larını temizle
    await SecureStorageHelper.delete('GoogleDrive_AccessToken_$sessionId');
    await SecureStorageHelper.delete('GoogleDrive_RefreshToken_$sessionId');
    await SecureStorageHelper.delete('GoogleDrive_TokenExpiry_$sessionId');

    // Profille ilişkili SharedPreferences anahtarlarını temizle
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final targetSuffix = '_$sessionId';
      for (final key in keys) {
        if (key.endsWith(targetSuffix)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}

    return true;
  }

  /// PIN Doğrulama
  static bool verifyPin(UserSession session, String pinInput) {
    if (!session.hasPin || session.pinHash == null) {
      return true; // Kilitli değil
    }
    final inputHash = hashPin(pinInput.trim());
    return inputHash == session.pinHash;
  }

  /// Oturuma PIN Tanımlama / Değiştirme
  static Future<UserSession> setSessionPin(UserSession session, String newPin) async {
    final hash = hashPin(newPin.trim());
    final updated = session.copyWith(
      hasPin: true,
      pinHash: hash,
    );
    await updateSession(updated);
    return updated;
  }

  /// Oturumun PIN Korumasını Kaldırma
  static Future<UserSession> removeSessionPin(UserSession session) async {
    final updated = session.copyWith(
      hasPin: false,
      clearPinHash: true,
    );
    await updateSession(updated);
    return updated;
  }
}
