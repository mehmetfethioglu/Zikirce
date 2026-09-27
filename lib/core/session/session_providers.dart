import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/gamification/providers/gamification_providers.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../database/app_database.dart';
import '../database/zikir_seed_data.dart';
import '../services/google_drive_backup_service.dart';
import '../theme/theme_provider.dart';
import '../utils/pref_utils.dart';
import 'session_manager_service.dart';
import 'user_session.dart';

class SessionState {
  final List<UserSession> sessions;
  final String activeSessionId;
  final bool isLoading;

  const SessionState({
    this.sessions = const [],
    this.activeSessionId = UserSession.defaultSessionId,
    this.isLoading = true,
  });

  UserSession get activeSession {
    return sessions.firstWhere(
      (s) => s.id == activeSessionId,
      orElse: () => sessions.isNotEmpty
          ? sessions.first
          : UserSession.defaultSession(),
    );
  }

  SessionState copyWith({
    List<UserSession>? sessions,
    String? activeSessionId,
    bool? isLoading,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref ref;

  SessionNotifier(this.ref, [SessionState initial = const SessionState()]) : super(initial) {
    if (initial.sessions.isEmpty) {
      _init();
    }
  }

  Future<void> _init() async {
    try {
      final list = await SessionManagerService.loadSessions();
      final activeId = await SessionManagerService.getActiveSessionId();
      if (mounted) {
        state = state.copyWith(
          sessions: list,
          activeSessionId: activeId,
          isLoading: false,
        );
      }
      // Arka planda oturum profil verilerini reconcile ve bulut senkronizasyonu yap
      unawaited(syncCloudProfiles());
    } catch (e) {
      if (kDebugMode) {
        print('[SessionNotifier] Init error: $e');
      }
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Oturum Değiştirme
  Future<bool> switchSession(
    String targetSessionId, {
    String? pin,
    bool bypassPinCheck = false,
  }) async {
    final target = state.sessions.firstWhere(
      (s) => s.id == targetSessionId,
      orElse: () => state.activeSession,
    );

    // PIN Kontrolü (Diyalogda önceden doğrulanmamışsa)
    if (!bypassPinCheck && target.hasPin && target.pinHash != null) {
      if (pin == null || !SessionManagerService.verifyPin(target, pin)) {
        return false; // PIN geçersiz
      }
    }

    // 1. Aktif ID'yi kalıcı olarak güncelle
    await SessionManagerService.setActiveSessionId(targetSessionId);

    // 2. Durumu güncelle (activeSessionProvider ve databaseProvider otomatik reaktif yenilenir)
    state = state.copyWith(activeSessionId: targetSessionId);

    // 3. Oturum değişim tetikleyicisini artır
    ref.read(sessionSwitchTriggerProvider.notifier).state++;

    // 4. Temayı ve ayarları yeni oturum için senkronize et
    try {
      ref.read(themeNotifierProvider.notifier).reloadForSession(targetSessionId);
    } catch (_) {}
    try {
      ref.read(userSettingsProvider.notifier).reloadForSession(targetSessionId);
    } catch (_) {}
    try {
      ref.invalidate(userProfileStreamProvider);
    } catch (_) {}

    return true;
  }

  /// Yeni Yerel Oturum Ekle
  Future<UserSession> createLocalSession({
    String? id,
    required String name,
    required String avatar,
    String? pin,
  }) async {
    final newSession = await SessionManagerService.createLocalSession(
      id: id,
      name: name,
      avatar: avatar,
      pin: pin,
    );

    // Yeni oturum SharedPreferences değerlerini kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('UserDisplayName_${newSession.id}', newSession.displayName);
      await prefs.setString('user_display_name_${newSession.id}', newSession.displayName);
      await prefs.setString('UserProfileImage_${newSession.id}', newSession.avatar);
      await prefs.setString('avatar_${newSession.id}', newSession.avatar);

      // Yeni SQLite dosyasını seed et ve profil bilgilerini yaz
      final newSessionDb = AppDatabase(null, newSession.dbFileName);
      await ZikirSeedData.ensureAllDefaultZikirsExist(newSessionDb);
      final profile = await newSessionDb.select(newSessionDb.userProfiles).getSingleOrNull();
      if (profile != null) {
        await (newSessionDb.update(newSessionDb.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          profile.copyWith(
            userName: newSession.displayName,
            avatar: newSession.avatar,
          ),
        );
      }
      await newSessionDb.close();
    } catch (e) {
      if (kDebugMode) {
        print('[SessionNotifier] createLocalSession seed error: $e');
      }
    }

    final updatedList = await SessionManagerService.loadSessions();
    state = state.copyWith(sessions: updatedList);

    // Yeni oturuma geçiş yap
    await switchSession(newSession.id, bypassPinCheck: true);
    return newSession;
  }

  /// Yeni Bulut Oturumu Ekle
  Future<UserSession> createCloudSession({
    String? id,
    required String name,
    required String avatar,
    required String email,
    String? pin,
  }) async {
    final newSession = await SessionManagerService.createCloudSession(
      id: id,
      name: name,
      avatar: avatar,
      email: email,
      pin: pin,
    );

    // Yeni oturum SharedPreferences değerlerini kaydet
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('UserDisplayName_${newSession.id}', newSession.displayName);
      await prefs.setString('user_display_name_${newSession.id}', newSession.displayName);
      await prefs.setString('UserProfileImage_${newSession.id}', newSession.avatar);
      await prefs.setString('avatar_${newSession.id}', newSession.avatar);

      final newSessionDb = AppDatabase(null, newSession.dbFileName);
      await ZikirSeedData.ensureAllDefaultZikirsExist(newSessionDb);
      final profile = await newSessionDb.select(newSessionDb.userProfiles).getSingleOrNull();
      if (profile != null) {
        await (newSessionDb.update(newSessionDb.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          profile.copyWith(
            userName: newSession.displayName,
            avatar: newSession.avatar,
          ),
        );
      }

      // Bulut yedeği varsa otomatik çek
      final driveService = GoogleDriveBackupService(db: newSessionDb, sessionId: newSession.id);
      await driveService.restoreLatestBackupIfExists();
      await newSessionDb.close();
    } catch (e) {
      if (kDebugMode) {
        print('[SessionNotifier] createCloudSession auto-restore error: $e');
      }
    }

    final updatedList = await SessionManagerService.loadSessions();
    state = state.copyWith(sessions: updatedList);

    // Yeni oturuma geçiş yap
    await switchSession(newSession.id, bypassPinCheck: true);
    return state.sessions.firstWhere((s) => s.id == newSession.id, orElse: () => newSession);
  }

  /// Oturum Bilgilerini Güncelle
  Future<void> updateSession(UserSession updated) async {
    await SessionManagerService.updateSession(updated);
    final updatedList = await SessionManagerService.loadSessions();
    state = state.copyWith(sessions: updatedList);

    // SharedPreferences anahtarlarını senkronize et
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDefault = updated.id == UserSession.defaultSessionId;
      final sid = updated.id;

      await prefs.setString('UserDisplayName_$sid', updated.displayName);
      await prefs.setString('user_display_name_$sid', updated.displayName);
      await prefs.setString('UserProfileImage_$sid', updated.avatar);
      await prefs.setString('avatar_$sid', updated.avatar);

      if (isDefault) {
        await prefs.setString('UserDisplayName', updated.displayName);
        await prefs.setString('user_display_name', updated.displayName);
        await prefs.setString('UserProfileImage', updated.avatar);
        await prefs.setString('avatar', updated.avatar);
      }

      // Hedef oturumun SQLite UserProfiles tablosunu güncelle
      try {
        final db = AppDatabase(null, updated.dbFileName);
        final profile = await db.select(db.userProfiles).getSingleOrNull();
        if (profile != null) {
          await (db.update(db.userProfiles)..where((t) => t.id.equals(profile.id))).write(
            profile.copyWith(
              userName: updated.displayName,
              avatar: updated.avatar,
            ),
          );
        }
        await db.close();
      } catch (e) {
        if (kDebugMode) {
          print('[SessionNotifier] SQLite user profile sync warning: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SessionNotifier] updateSession pref sync error: $e');
      }
    }
  }

  /// Oturum Sil
  Future<bool> deleteSession(String sessionId) async {
    if (sessionId == state.activeSessionId) {
      // Silinen oturum aktifse başka bir oturuma geç
      final fallback = state.sessions.firstWhere(
        (s) => s.id != sessionId,
        orElse: () => state.sessions.first,
      );
      await switchSession(fallback.id, bypassPinCheck: true);
    }

    final success = await SessionManagerService.deleteSession(sessionId);
    if (success) {
      final updatedList = await SessionManagerService.loadSessions();
      state = state.copyWith(sessions: updatedList);
    }
    return success;
  }

  /// PIN Belirle
  Future<void> setPin(String sessionId, String pin) async {
    final target = state.sessions.firstWhere((s) => s.id == sessionId);
    final updated = await SessionManagerService.setSessionPin(target, pin);
    await updateSession(updated);
  }

  /// PIN Kaldır
  Future<void> removePin(String sessionId) async {
    final target = state.sessions.firstWhere((s) => s.id == sessionId);
    final updated = await SessionManagerService.removeSessionPin(target);
    await updateSession(updated);
  }

  /// Bulut oturumlarının profil bilgilerini (isim ve avatar) senkronize eder
  Future<void> syncCloudProfiles({bool forceNetwork = false}) async {
    bool hasChanges = false;
    final prefs = await SharedPreferences.getInstance();

    for (final s in state.sessions) {
      var current = s;
      final sid = s.id;
      final isDefault = sid == UserSession.defaultSessionId;

      // 1. Önce yerel SharedPreferences profil verilerini kontrol et
      final savedName = isDefault
          ? PrefUtils.getStringFromKeys(prefs, ['user_display_name', 'UserDisplayName'], '')
          : (prefs.getString('UserDisplayName_$sid') ?? prefs.getString('user_display_name_$sid') ?? '');
      final savedAvatar = isDefault
          ? PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar'], '')
          : (prefs.getString('UserProfileImage_$sid') ?? prefs.getString('avatar_$sid') ?? '');

      if (savedName.isNotEmpty && savedName != current.displayName && savedName != 'Zâkir') {
        current = current.copyWith(displayName: savedName);
        hasChanges = true;
      }
      if (savedAvatar.isNotEmpty && savedAvatar != current.avatar) {
        current = current.copyWith(avatar: savedAvatar);
        hasChanges = true;
      }

      // 2. Eğer oturum bulut hesabı ise ve (forceNetwork veya varsayılan yer tutucular aktifse)
      if (current.isCloud &&
          (forceNetwork ||
              current.displayName == 'Google Kullanıcısı' ||
              current.displayName.isEmpty ||
              current.avatar == 'assets/images/avatar_male_1.png')) {
        try {
          final sessionDb = AppDatabase(null, current.dbFileName);
          final driveService = GoogleDriveBackupService(db: sessionDb, sessionId: current.id);
          final cloudData = await driveService.syncCloudProfileToSession();
          await sessionDb.close();

          if (cloudData != null) {
            final cloudName = cloudData['displayName'];
            final cloudAvatar = cloudData['avatar'];
            if (cloudName != null && cloudName.isNotEmpty && cloudName != current.displayName) {
              current = current.copyWith(displayName: cloudName);
              hasChanges = true;
            }
            if (cloudAvatar != null && cloudAvatar.isNotEmpty && cloudAvatar != current.avatar) {
              current = current.copyWith(avatar: cloudAvatar);
              hasChanges = true;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('[SessionNotifier] syncCloudProfiles network error for ${current.id}: $e');
          }
        }
      }

      if (hasChanges) {
        await SessionManagerService.updateSession(current);
      }
    }

    if (hasChanges) {
      final reloaded = await SessionManagerService.loadSessions();
      if (mounted) {
        state = state.copyWith(sessions: reloaded);
      }
    }
  }

  /// Tek bir oturum için bulut profilini senkronize et
  Future<void> syncCloudProfileForSession(String sessionId) async {
    final session = state.sessions.firstWhere((s) => s.id == sessionId, orElse: () => state.activeSession);
    if (!session.isCloud) return;

    try {
      final sessionDb = AppDatabase(null, session.dbFileName);
      final driveService = GoogleDriveBackupService(db: sessionDb, sessionId: session.id);
      final cloudData = await driveService.syncCloudProfileToSession();
      await sessionDb.close();

      if (cloudData != null) {
        final reloaded = await SessionManagerService.loadSessions();
        if (mounted) {
          state = state.copyWith(sessions: reloaded);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SessionNotifier] syncCloudProfileForSession error: $e');
      }
    }
  }
}

final sessionSwitchTriggerProvider = StateProvider<int>((ref) => 0);

final initialSessionStateProvider = Provider<SessionState>((ref) => const SessionState());

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final initial = ref.watch(initialSessionStateProvider);
  return SessionNotifier(ref, initial);
});

final activeSessionProvider = Provider<UserSession>((ref) {
  final sessionState = ref.watch(sessionProvider);
  return sessionState.activeSession;
});

final sessionListProvider = Provider<List<UserSession>>((ref) {
  final sessionState = ref.watch(sessionProvider);
  return sessionState.sessions;
});
