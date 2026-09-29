import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/gamification/models/user_rank.dart';
import '../../features/gamification/services/badge_service.dart';
import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../theme/theme_provider.dart';
import '../utils/pref_utils.dart';
import '../utils/secure_storage_helper.dart';
import 'data_reconciliation_service.dart';
import 'widget_sync_service.dart';

import '../session/session_manager_service.dart';
import '../session/session_providers.dart';
import '../session/user_session.dart';

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final activeSession = ref.watch(activeSessionProvider);
  return GoogleDriveBackupService(db: db, sessionId: activeSession.id);
});

/// Google Drive bulut yedek bilgisi modeli
class CloudBackupInfo {
  final String fileId;
  final String fileName;
  final String? revisionId;
  final DateTime modifiedTime;
  final String deviceName;
  final String displayName;
  final int? streakCount;
  final int? zikirCount;
  final int? sizeBytes;
  final bool isLocal;
  final String? localFilePath;

  CloudBackupInfo({
    required this.fileId,
    required this.fileName,
    this.revisionId,
    required this.modifiedTime,
    required this.deviceName,
    required this.displayName,
    this.streakCount,
    this.zikirCount,
    this.sizeBytes,
    this.isLocal = false,
    this.localFilePath,
  });
}

class GoogleDriveBackupService {
  AppDatabase db;
  final String? sessionId;
  final Dio _dio = Dio();

  static const String clientId = '497197680323-k954rqrvtjfk5qv83heimbs8k1fe8t5m.apps.googleusercontent.com';
  static const String tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String driveFilesEndpoint = 'https://www.googleapis.com/drive/v3/files';
  static const String driveUploadEndpoint = 'https://www.googleapis.com/upload/drive/v3/files';

  static const String accessTokenKey = 'GoogleDrive_AccessToken';
  static const String refreshTokenKey = 'GoogleDrive_RefreshToken';
  static const String tokenExpiryKey = 'GoogleDrive_TokenExpiry';
  static const String userEmailKey = 'GoogleDrive_UserEmail';
  static const String userNameKey = 'GoogleDrive_UserName';
  static const String lastBackupTicksKey = 'LastGoogleDriveBackupTicks';
  static const String autoBackupEnabledKey = 'IsGoogleDriveAutoBackupEnabled';

  static const String backupFileName = 'Zikirce_CloudBackup.json';

  // Debounce süresi - 30 saniye
  static DateTime _lastAutoCloudBackupTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minAutoBackupInterval = Duration(seconds: 30);
  static bool _isAutoBackingUp = false;

  GoogleDriveBackupService({required this.db, this.sessionId});

  bool get _isDefaultSession => sessionId == null || sessionId == 'default_user';

  String _sKey(String baseKey) {
    if (!_isDefaultSession) {
      return '${baseKey}_$sessionId';
    }
    return baseKey;
  }

  // ===========================================================================
  // AUTH STATUS & TOKENS
  // ===========================================================================

  Future<bool> isSignedIn() async {
    try {
      final token = await getValidAccessToken();
      final prefs = await SharedPreferences.getInstance();
      var email = PrefUtils.getString(prefs, _sKey(userEmailKey));
      if (_isDefaultSession && email.isEmpty) {
        email = PrefUtils.getString(prefs, userEmailKey);
      }
      return token != null && token.isNotEmpty && email.isNotEmpty;
    } catch (e) {
      debugPrint('[GoogleDriveBackupService] isSignedIn error: $e');
      return false;
    }
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    var email = PrefUtils.getStringOrNull(prefs, _sKey(userEmailKey));
    if (_isDefaultSession && (email == null || email.isEmpty)) {
      email = PrefUtils.getStringOrNull(prefs, userEmailKey);
    }
    return email;
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    var name = PrefUtils.getStringOrNull(prefs, _sKey(userNameKey));
    if (_isDefaultSession && (name == null || name.isEmpty)) {
      name = PrefUtils.getStringOrNull(prefs, userNameKey);
    }
    return name;
  }

  Future<String> getLastBackupTimeFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = PrefUtils.getInt(prefs, _sKey(lastBackupTicksKey), 0);
    if (millis == 0) return 'Henüz yedekleme yapılmadı';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefUtils.getBool(prefs, _sKey(autoBackupEnabledKey), false);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sKey(autoBackupEnabledKey), enabled);
    if (_isDefaultSession) {
      await prefs.setBool(autoBackupEnabledKey, enabled);
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isDefaultSession) {
        await SecureStorageHelper.delete(accessTokenKey);
        await SecureStorageHelper.delete(refreshTokenKey);
        await SecureStorageHelper.delete('${accessTokenKey}_default_user');
        await SecureStorageHelper.delete('${refreshTokenKey}_default_user');
        await prefs.remove(tokenExpiryKey);
        await prefs.remove(userEmailKey);
        await prefs.remove(userNameKey);
        await prefs.remove('${tokenExpiryKey}_default_user');
        await prefs.remove('${userEmailKey}_default_user');
        await prefs.remove('${userNameKey}_default_user');
      } else {
        await SecureStorageHelper.delete(_sKey(accessTokenKey));
        await SecureStorageHelper.delete(_sKey(refreshTokenKey));
        await prefs.remove(_sKey(tokenExpiryKey));
        await prefs.remove(_sKey(userEmailKey));
        await prefs.remove(_sKey(userNameKey));
      }
    } catch (e) {
      debugPrint('[GoogleDriveBackupService] signOut error: $e');
    }
  }

  Future<String?> getValidAccessToken() async {
    try {
      var token = await SecureStorageHelper.read(_sKey(accessTokenKey));
      if (_isDefaultSession && (token == null || token.isEmpty)) {
        token = await SecureStorageHelper.read(accessTokenKey);
      }
      if (token == null || token.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      var expiryMs = PrefUtils.getInt(prefs, _sKey(tokenExpiryKey), 0);
      if (_isDefaultSession && expiryMs == 0) {
        expiryMs = PrefUtils.getInt(prefs, tokenExpiryKey, 0);
      }

      // 5 dakika (300.000 ms) güvenlik marjı ile proaktif yenileme
      if (DateTime.now().millisecondsSinceEpoch < (expiryMs - 300000)) {
        return token;
      }

      var refreshToken = await SecureStorageHelper.read(_sKey(refreshTokenKey));
      if (_isDefaultSession && (refreshToken == null || refreshToken.isEmpty)) {
        refreshToken = await SecureStorageHelper.read(refreshTokenKey);
      }
      if (refreshToken == null || refreshToken.isEmpty) return null;

      try {
        final response = await _dio.post(
          tokenEndpoint,
          data: {
            'client_id': clientId,
            'refresh_token': refreshToken,
            'grant_type': 'refresh_token',
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final newAccessToken = data['access_token']?.toString() ?? '';
          final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
          final newRefreshToken = data['refresh_token']?.toString();

          if (_isDefaultSession) {
            await SecureStorageHelper.write(accessTokenKey, newAccessToken);
            await SecureStorageHelper.write('${accessTokenKey}_default_user', newAccessToken);
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await SecureStorageHelper.write(refreshTokenKey, newRefreshToken);
              await SecureStorageHelper.write('${refreshTokenKey}_default_user', newRefreshToken);
            }
          } else {
            await SecureStorageHelper.write(_sKey(accessTokenKey), newAccessToken);
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await SecureStorageHelper.write(_sKey(refreshTokenKey), newRefreshToken);
            }
          }

          final newExpiryMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
          if (_isDefaultSession) {
            await prefs.setInt(tokenExpiryKey, newExpiryMs);
            await prefs.setInt('${tokenExpiryKey}_default_user', newExpiryMs);
          } else {
            await prefs.setInt(_sKey(tokenExpiryKey), newExpiryMs);
          }

          return newAccessToken;
        }
      } catch (e) {
        debugPrint('[GoogleDrive] Token refresh error: $e');
      }

      return null;
    } catch (e) {
      debugPrint('[GoogleDriveBackupService] getValidAccessToken error: $e');
      return null;
    }
  }

  // ===========================================================================
  // EXPORT DATABASE TO 1:1 .NET MAUI BACKUPDATA JSON
  // ===========================================================================

  Future<String> createBackupJson() async {
    final prefs = await SharedPreferences.getInstance();

    final zikirs = await db.select(db.zikirs).get();
    final zikirLogs = await db.select(db.zikirLogs).get();
    final streaks = await db.select(db.userStreaks).get();
    final badges = await db.select(db.unlockedBadges).get();
    final plans = await db.select(db.memorizationPlans).get();
    final hatims = await db.select(db.hatims).get();
    final hatimProgress = await db.select(db.hatimCuzProgresses).get();
    final kazaPrayers = await db.select(db.kazaPrayers).get();
    final prayerLogs = await db.select(db.prayerAnswerLogs).get();
    final kazaMelts = await db.select(db.kazaMeltLogs).get();

    final firstStreak = streaks.isNotEmpty ? streaks.first : null;

    // 1. Zikirler (MAUI ZikirBackup format)
    final zikirlerList = zikirs.map((z) => {
      'ZikirId': z.id,
      'ZikirAdi': z.name,
      'ArapceMetin': z.arabic ?? '',
      'ZikirMiktar': z.target,
      'Sayac': z.currentCount,
      'ZikirToplam': z.totalCount,
      'MaxSeyir': z.lap,
      'IsFavorite': z.isFavorite,
      'Kategori': z.category,
      'ZikirAciklama': z.soundEffect,
      'TarihUnix': z.createdAt.millisecondsSinceEpoch ~/ 1000,
      'SonPratikUnix': z.lastPracticed != null ? z.lastPracticed!.millisecondsSinceEpoch ~/ 1000 : null,
      'KullaniciKartindaMi': true,
      'CicekGorsel': '',
      'CicekHarf': '',
    }).toList();

    // 2. ZikirLogs (MAUI ZikirLogBackup format)
    final zikirLogsList = zikirLogs.map((l) => {
      'LogId': l.id,
      'ZikirId': l.zikirId,
      'ZikirAdi': '',
      'CekilenMiktar': l.count,
      'TarihUnix': l.timestamp.millisecondsSinceEpoch ~/ 1000,
    }).toList();

    // 3. UserProfile (Dual check: DB -> SharedPreferences -> UserSession)
    final profile = (await (db.select(db.userProfiles)..limit(1)).get()).firstOrNull;
    final sfx = _isDefaultSession ? '' : '_$sessionId';

    final allSessions = await SessionManagerService.loadSessions();
    final matchingSession = allSessions.firstWhere(
      (s) => s.id == (sessionId ?? UserSession.defaultSessionId),
      orElse: () => UserSession.defaultSession(),
    );

    String userDisplayName = '';
    if (profile != null && profile.userName.isNotEmpty && profile.userName != 'Zâkir') {
      userDisplayName = profile.userName;
    } else {
      userDisplayName = PrefUtils.getStringFromKeys(prefs, [
        'user_display_name$sfx',
        'UserDisplayName$sfx',
        if (_isDefaultSession) ...['user_display_name', 'UserDisplayName'],
      ], matchingSession.displayName.isNotEmpty ? matchingSession.displayName : 'Zâkir');
    }
    if (userDisplayName.isEmpty || userDisplayName == 'Zâkir') {
      if (matchingSession.displayName.isNotEmpty &&
          matchingSession.displayName != 'Ana Profil' &&
          matchingSession.displayName != 'Google Kullanıcısı') {
        userDisplayName = matchingSession.displayName;
      }
    }

    String avatarPath = '';
    if (profile != null && profile.avatar.isNotEmpty) {
      avatarPath = profile.avatar;
    } else {
      avatarPath = PrefUtils.getStringFromKeys(prefs, [
        'UserProfileImage$sfx',
        'avatar$sfx',
        if (_isDefaultSession) ...['UserProfileImage', 'avatar', 'ProfileImagePath'],
      ], matchingSession.avatar);
    }
    if (avatarPath.isEmpty) {
      avatarPath = matchingSession.avatar;
    }

    String avatarBase64 = '';
    if (avatarPath.isNotEmpty && !avatarPath.startsWith('assets/') && !avatarPath.startsWith('http')) {
      try {
        File avatarFile = File(avatarPath);
        if (!avatarFile.existsSync()) {
          final docDir = await getApplicationDocumentsDirectory();
          final candidate = File(p.join(docDir.path, p.basename(avatarPath)));
          if (candidate.existsSync()) {
            avatarFile = candidate;
          }
        }
        if (avatarFile.existsSync()) {
          final bytes = await avatarFile.readAsBytes();
          avatarBase64 = base64Encode(bytes);
        }
      } catch (e) {
        debugPrint('[GoogleDrive] AvatarBase64 encode error: $e');
      }
    }
    final userProfileMap = {
      'DisplayName': userDisplayName,
      'AvatarPath': avatarPath,
      'TotalZikir': zikirs.fold<int>(0, (sum, z) => sum + z.totalCount),
      'CurrentStreak': firstStreak?.currentStreak ?? 0,
      'LastZikirDateUnix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'AvatarBase64': avatarBase64,
    };

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 4. Hatimler (MAUI HatimBackup format)
    final hatimlerList = hatims.map((h) {
      final hToday = prefs.getInt('HatimTodayPages_${h.id}_$todayStr') ?? 0;
      final hLastRead = prefs.getString('HatimLastReadDate_${h.id}') ?? (h.createdAt.toIso8601String().split('T').first);
      return {
        'HatimId': int.tryParse(h.id.replaceAll(RegExp(r'\D'), '')) ?? 1,
        'RealHatimId': h.id,
        'id': h.id,
        'HatimAdi': h.title,
        'BaslangicTarihiUnix': h.createdAt.millisecondsSinceEpoch ~/ 1000,
        'BitisTarihiUnix': h.targetDate?.millisecondsSinceEpoch != null ? (h.targetDate!.millisecondsSinceEpoch ~/ 1000) : null,
        'TamamlanmaTarihiUnix': h.isCompleted ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) : null,
        'CurrentPage': h.completedPages,
        'CurrentCuz': (h.completedPages ~/ 20) + 1,
        'CompletedCuzCount': h.completedPages ~/ 20,
        'IsCompleted': h.isCompleted,
        'IsActive': !h.isCompleted,
        'Type': h.isGroup ? 1 : 0,
        'TrackingType': 0,
        'Status': h.isCompleted ? 2 : 1,
        'ParticipantCount': 1,
        'MyCuzCompletedCount': h.completedPages ~/ 20,
        'OthersCuzCompletedCount': 0,
        'DailyGoal': 20,
        'ReminderEnabled': false,
        'ReminderTimeTicks': null,
        'LastReadDate': hLastRead,
        'TodayReadPages': hToday,
        'UsedStreakProtections': 0,
      };
    }).toList();

    // 5. HatimCuzProgressList
    final cuzProgressList = hatimProgress.map((cp) => {
      'Id': cp.id,
      'HatimId': int.tryParse(cp.hatimId.replaceAll(RegExp(r'\D'), '')) ?? 1,
      'RealHatimId': cp.hatimId,
      'hatimId': cp.hatimId,
      'CuzNumber': cp.juzNo,
      'OwnerType': 0,
      'OwnerName': cp.readerName ?? userDisplayName,
      'Status': cp.isCompleted ? 2 : 0,
      'CompletedAtUnix': cp.completedAt?.millisecondsSinceEpoch != null ? (cp.completedAt!.millisecondsSinceEpoch ~/ 1000) : null,
      'LastPage': cp.juzNo * 20,
    }).toList();

    // 6. AppSettings (MAUI AppSettingsBackup format)
    final todayReadPagesVal = PrefUtils.getIntFromKeys(prefs, [
      'TodayReadPages_$todayStr',
      'TodayReadPages_$todayStr$sfx',
      'TodayReadPages',
      'today_read_pages$sfx',
      'today_read_pages',
    ], 0);
    final lastReadDateVal = PrefUtils.getStringFromKeys(prefs, [
      'last_read_date$sfx',
      'LastReadDate$sfx',
      'last_read_date',
      'LastReadDate',
    ], todayReadPagesVal > 0 ? todayStr : '');

    final hatimTodayPagesMap = <String, int>{};
    final hatimLastReadDatesMap = <String, String>{};
    for (final h in hatims) {
      final hToday = prefs.getInt('HatimTodayPages_${h.id}_$todayStr') ?? 0;
      if (hToday > 0) {
        hatimTodayPagesMap[h.id] = hToday;
      }
      final lastRead = prefs.getString('HatimLastReadDate_${h.id}');
      if (lastRead != null && lastRead.isNotEmpty) {
        hatimLastReadDatesMap[h.id] = lastRead;
      }
    }

    List<String> exportedBadgeIds = badges.map((b) => b.badgeId).toList();
    if (exportedBadgeIds.isEmpty) {
      try {
        final evaluated = await BadgeService(db).getBadges();
        exportedBadgeIds = evaluated.where((b) => b.isUnlocked).map((b) => b.id).toList();
      } catch (_) {}
    }

    final appSettingsMap = {
      'ZikirSoundEnabled': PrefUtils.getBool(prefs, _sKey('sound_enabled'), true),
      'ZikirVibrationEnabled': PrefUtils.getBool(prefs, _sKey('vibration_enabled'), true),
      'IsAutoBackupEnabled': PrefUtils.getBool(prefs, _sKey(autoBackupEnabledKey), false),
      'LastZikirId': PrefUtils.getInt(prefs, _sKey('last_zikir_id'), -1),
      'IsStreakReminderEnabled': false,
      'StreakReminderTimeTicks': 0,
      'KuranDailyGoal': PrefUtils.getIntFromKeys(prefs, ['kuran_daily_goal$sfx', 'DailyQuranGoal$sfx', 'KuranDailyGoal$sfx', 'kuran_daily_goal'], 20),
      'DailyQuranGoal': PrefUtils.getIntFromKeys(prefs, ['DailyQuranGoal$sfx', 'KuranDailyGoal$sfx', 'kuran_daily_goal$sfx', 'DailyQuranGoal'], 20),
      'IsReadingReminderEnabled': false,
      'ReadingReminderTimeTicks': 0,
      'TotalReadPages': PrefUtils.getIntFromKeys(prefs, ['total_read_pages$sfx', 'TotalReadPages$sfx', 'total_read_pages'], 0),
      'TodayReadPages': todayReadPagesVal,
      'TodayReadPages_$todayStr': todayReadPagesVal,
      'HatimTodayPages': hatimTodayPagesMap,
      'HatimTodayPages_$todayStr': hatimTodayPagesMap,
      'HatimLastReadDates': hatimLastReadDatesMap,
      'LastReadDate': lastReadDateVal,
      'ReadingStreak': PrefUtils.getIntFromKeys(prefs, ['reading_streak$sfx', 'ReadingStreak$sfx', 'reading_streak'], 0),
      'BestReadingStreak': PrefUtils.getIntFromKeys(prefs, ['best_reading_streak$sfx', 'BestReadingStreak$sfx', 'best_reading_streak'], 0),
      'AverageDailyPages': PrefUtils.getIntFromKeys(prefs, ['average_daily_pages$sfx', 'AverageDailyPages$sfx', 'average_daily_pages'], 0),
      'TotalReadingDays': PrefUtils.getIntFromKeys(prefs, ['total_reading_days$sfx', 'TotalReadingDays$sfx', 'total_reading_days'], 0),
      'SelectedCity': PrefUtils.getStringFromKeys(prefs, [_sKey('SelectedCity'), _sKey('selected_city'), 'SelectedCity', 'AppCity', 'selected_city'], 'İstanbul'),
      'UserDisplayName': userDisplayName,
      'SelectedBird': PrefUtils.getStringFromKeys(prefs, ['selected_bird$sfx', 'SelectedBird$sfx', 'selected_bird'], 'yeni_bird.json'),
      'QuranArabicFontSize': PrefUtils.getDouble(prefs, _sKey('quran_arabic_font_size'), 38.0),
      'QuranTurkishFontSize': PrefUtils.getDouble(prefs, _sKey('quran_turkish_font_size'), 16.0),
      'QuranIsBold': PrefUtils.getBool(prefs, _sKey('quran_is_bold'), false),
      'QuranSelectedFontName': PrefUtils.getString(prefs, _sKey('quran_selected_font_name'), 'mushaf'),
      'QuranReadingMode': PrefUtils.getInt(prefs, _sKey('quran_reading_mode'), 0),
      'QuranIsMaskingEnabled': false,
      'QuranIsBlurringEnabled': false,
      'SelectedDownloadLanguageId': 5,
      'AppThemeOption': PrefUtils.getString(prefs, _sKey('AppThemeOption'), 'system'),
      'AppThemeOptionInt': AppThemeKeys.toInt(PrefUtils.getString(prefs, _sKey('AppThemeOption'), 'system')),
      'LightSubThemeOption': PrefUtils.getString(prefs, _sKey('LightSubThemeOption'), 'greenLight'),
      'IsOnboardingCompleted': true,
      'KazaWeeklyTarget': PrefUtils.getInt(prefs, _sKey('kaza_weekly_target'), 45),
      'KazaMonthlyTarget': PrefUtils.getInt(prefs, _sKey('kaza_monthly_target'), 450),
      'IsGoogleDriveAutoBackupEnabled': PrefUtils.getBool(prefs, _sKey(autoBackupEnabledKey), false),
      'ZikirDailyGoal': PrefUtils.getIntFromKeys(prefs, ['zikir_daily_goal$sfx', 'DailyZikirGoal$sfx', 'ZikirDailyGoal$sfx', 'zikir_daily_goal'], 100),
      'DailyZikirGoal': PrefUtils.getIntFromKeys(prefs, ['DailyZikirGoal$sfx', 'ZikirDailyGoal$sfx', 'zikir_daily_goal$sfx', 'DailyZikirGoal'], 100),
      'KazaDailyGoal': PrefUtils.getIntFromKeys(prefs, ['kaza_daily_goal$sfx', 'DailyKazaGoal$sfx', 'KazaDailyGoal$sfx', 'kaza_daily_goal'], 5),
      'DailyKazaGoal': PrefUtils.getIntFromKeys(prefs, ['DailyKazaGoal$sfx', 'KazaDailyGoal$sfx', 'kaza_daily_goal$sfx', 'DailyKazaGoal'], 5),
      'SelectedSurahGoals': PrefUtils.getString(prefs, _sKey('SelectedSurahGoals'), ''),
      'IsZikirGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyZikirGoalEnabled$sfx', 'IsZikirGoalEnabled$sfx', 'IsDailyZikirGoalEnabled'], true),
      'IsDailyZikirGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyZikirGoalEnabled$sfx', 'IsZikirGoalEnabled$sfx', 'IsDailyZikirGoalEnabled'], true),
      'IsKuranGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyQuranGoalEnabled$sfx', 'IsKuranGoalEnabled$sfx', 'IsDailyQuranGoalEnabled'], true),
      'IsDailyQuranGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyQuranGoalEnabled$sfx', 'IsKuranGoalEnabled$sfx', 'IsDailyQuranGoalEnabled'], true),
      'IsEzberGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsHafizlikRepeatGoalEnabled$sfx', 'IsEzberGoalEnabled$sfx', 'IsHafizlikRepeatGoalEnabled'], false),
      'IsHafizlikRepeatGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsHafizlikRepeatGoalEnabled$sfx', 'IsEzberGoalEnabled$sfx', 'IsHafizlikRepeatGoalEnabled'], false),
      'IsKazaGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyKazaGoalEnabled$sfx', 'IsKazaGoalEnabled$sfx', 'IsDailyKazaGoalEnabled'], false),
      'IsDailyKazaGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyKazaGoalEnabled$sfx', 'IsKazaGoalEnabled$sfx', 'IsDailyKazaGoalEnabled'], false),
      'IsDailyPrayersGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyPrayersGoalEnabled$sfx', 'IsPrayersGoalEnabled$sfx', 'IsDailyPrayersGoalEnabled'], false),
      'EzberDailyGoal': PrefUtils.getIntFromKeys(prefs, ['ezber_daily_goal$sfx', 'DailyEzberGoal$sfx', 'EzberDailyGoal$sfx', 'ezber_daily_goal'], 1),
      'DailyEzberGoal': PrefUtils.getIntFromKeys(prefs, ['DailyEzberGoal$sfx', 'EzberDailyGoal$sfx', 'ezber_daily_goal$sfx', 'DailyEzberGoal'], 1),
      'SurahStreaks': <String, int>{
        'Streak_Waqiah': PrefUtils.getInt(prefs, _sKey('Streak_Waqiah'), 0),
        'Streak_Mulk': PrefUtils.getInt(prefs, _sKey('Streak_Mulk'), 0),
        'Streak_Naba': PrefUtils.getInt(prefs, _sKey('Streak_Naba'), 0),
        'Streak_Sleep': PrefUtils.getInt(prefs, _sKey('Streak_Sleep'), 0),
      },
      'BestSurahStreaks': <String, int>{
        'BestStreak_Waqiah': PrefUtils.getInt(prefs, _sKey('BestStreak_Waqiah'), 0),
        'BestStreak_Mulk': PrefUtils.getInt(prefs, _sKey('BestStreak_Mulk'), 0),
        'BestStreak_Naba': PrefUtils.getInt(prefs, _sKey('BestStreak_Naba'), 0),
        'BestStreak_Sleep': PrefUtils.getInt(prefs, _sKey('BestStreak_Sleep'), 0),
      },
      'LastReadDates': <String, String>{
        'LastReadDate_Waqiah': PrefUtils.getString(prefs, _sKey('LastReadDate_Waqiah'), ''),
        'LastReadDate_Mulk': PrefUtils.getString(prefs, _sKey('LastReadDate_Mulk'), ''),
        'LastReadDate_Naba': PrefUtils.getString(prefs, _sKey('LastReadDate_Naba'), ''),
        'LastReadDate_Sleep': PrefUtils.getString(prefs, _sKey('LastReadDate_Sleep'), ''),
      },
      'UnlockedBadgeIds': exportedBadgeIds,
      'CustomQuranBadgesJson': PrefUtils.getString(prefs, _sKey('CustomQuranBadges_List_v1'), ''),
      'DiamondCount': PrefUtils.getIntFromKeys(prefs, ['DiamondCount$sfx', 'DiamondCount'], 0),
      'GoldCount': PrefUtils.getIntFromKeys(prefs, ['GoldCount$sfx', 'GoldCount'], firstStreak?.xp ?? 0),
    };

    // Direct key exports for nested HatimTodayPages
    for (final entry in hatimTodayPagesMap.entries) {
      appSettingsMap['HatimTodayPages_${entry.key}_$todayStr'] = entry.value;
    }
    for (final entry in hatimLastReadDatesMap.entries) {
      appSettingsMap['HatimLastReadDate_${entry.key}'] = entry.value;
    }

    // 7. UserStreak (MAUI UserStreakBackup format)
    final curDiamondsVal = PrefUtils.getIntFromKeys(prefs, ['DiamondCount$sfx', 'DiamondCount'], 0);
    final curGoldVal = PrefUtils.getIntFromKeys(prefs, ['GoldCount$sfx', 'GoldCount'], firstStreak?.xp ?? 0);

    final userStreakMap = {
      'CurrentStreak': firstStreak?.currentStreak ?? 0,
      'LongestStreak': firstStreak?.bestStreak ?? 0,
      'LastActiveDateUnix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'TotalActiveDays': firstStreak?.totalDays ?? 0,
      'ShieldCount': firstStreak?.freezeCount ?? 3,
      'UsedShieldCount': 0,
      'KuranPagesReadCounter': 0,
      'OverflowBadgeCount': curGoldVal,
      'DiamondCount': curDiamondsVal,
      'GoldCount': curGoldVal,
      'UnlockedBirds': PrefUtils.getString(prefs, _sKey('UnlockedBirds'), 'yeni_bird.json'),
      'ZikirProtectionCount': firstStreak?.freezeCount ?? 3,
      'KuranProtectionCount': 0,
      'ZikirUsedProtectionCount': 0,
      'KuranUsedProtectionCount': 0,
    };

    // 8. KazaPrayers (Dual keys for 100% backward & forward compatibility)
    final kazaPrayersList = kazaPrayers.map((kp) => {
      'PrayerType': kp.prayerType,
      'prayerType': kp.prayerType,
      'CompletedCount': kp.completedCount,
      'completedCount': kp.completedCount,
      'TargetCount': kp.totalCount,
      'TotalCount': kp.totalCount,
      'totalCount': kp.totalCount,
    }).toList();

    // 9. PrayerAnswerLogs (Dual keys for 100% backward & forward compatibility)
    final prayerAnswerLogsList = prayerLogs.map((pl) => {
      'Date': pl.dateStr,
      'DateStr': pl.dateStr,
      'dateStr': pl.dateStr,
      'PrayerName': pl.prayerType,
      'PrayerType': pl.prayerType,
      'prayerType': pl.prayerType,
      'Answer': pl.isPerformed ? 'Evet' : 'Hayır',
      'IsPerformed': pl.isPerformed,
      'isPerformed': pl.isPerformed,
      'Timestamp': DateTime.now().millisecondsSinceEpoch,
    }).toList();

    // 10. KazaMeltLogs
    final kazaMeltLogsList = kazaMelts.map((km) => {
      'Id': km.id,
      'Date': km.timestamp.toIso8601String(),
      'Amount': km.meltAmount,
      'Type': km.prayerType,
    }).toList();

    // 11. MemorizationPlans
    final memorizationPlansList = plans.map((p) => {
      'PageId': p.pageId,
      'SurahId': p.surahId ?? 0,
      'ScheduledReviewDateUnix': p.scheduledReviewDate.millisecondsSinceEpoch ~/ 1000,
      'State': p.state,
      'TimesReviewed': p.timesReviewed,
    }).toList();

    final fullBackup = {
      'AppVersion': '2.0',
      'BackupDate': DateTime.now().toIso8601String(),
      'DeviceName': Platform.operatingSystem,
      'Zikirler': zikirlerList,
      'ZikirLogs': zikirLogsList,
      'UserProfile': userProfileMap,
      'Hatimler': hatimlerList,
      'HatimCuzProgressList': cuzProgressList,
      'AppSettings': appSettingsMap,
      'UserStreak': userStreakMap,
      'Gamification': {
        'DiamondCount': curDiamondsVal,
        'GoldCount': curGoldVal,
        'ShieldCount': firstStreak?.freezeCount ?? 3,
      },
      'KazaPrayers': kazaPrayersList,
      'PrayerAnswerLogs': prayerAnswerLogsList,
      'KazaMeltLogs': kazaMeltLogsList,
      'CompletedTasks': <Map<String, dynamic>>[],
      'StreakGapDays': <Map<String, dynamic>>[],
      'UserStreakHistories': <Map<String, dynamic>>[],
      'JuzBookmarks': <Map<String, dynamic>>[],
      'MemorizationPlans': memorizationPlansList,
    };

    return const JsonEncoder.withIndent('  ').convert(fullBackup);
  }

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(value.trim());
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return defaultValue;
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(trimmed);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return null;
  }

  static double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  static bool _parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
  }

  Future<void> _setSessionPrefString(SharedPreferences prefs, String key, String value) async {
    await prefs.setString(_sKey(key), value);
    if (_isDefaultSession) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _setSessionPrefInt(SharedPreferences prefs, String key, int value) async {
    await prefs.setInt(_sKey(key), value);
    if (_isDefaultSession) {
      await prefs.setInt(key, value);
    }
  }

  Future<void> _setSessionPrefDouble(SharedPreferences prefs, String key, double value) async {
    await prefs.setDouble(_sKey(key), value);
    if (_isDefaultSession) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _setSessionPrefBool(SharedPreferences prefs, String key, bool value) async {
    await prefs.setBool(_sKey(key), value);
    if (_isDefaultSession) {
      await prefs.setBool(key, value);
    }
  }

  // ===========================================================================
  // RESTORE DATABASE FROM .NET MAUI / FLUTTER 1:1 BACKUPDATA JSON
  // ===========================================================================

  Future<int> restoreFromJson(String jsonString) async {
    String cleanedJson = jsonString.trim();
    if (cleanedJson.startsWith('\uFEFF')) {
      cleanedJson = cleanedJson.substring(1).trim();
    }
    dynamic parsed;
    try {
      parsed = jsonDecode(cleanedJson);
      if (parsed is String) {
        parsed = jsonDecode(parsed);
      }
    } catch (e) {
      throw Exception('JSON ayrıştırma hatası: $e');
    }

    if (parsed is! Map<String, dynamic>) {
      throw Exception('Yedek dosyası geçerli bir JSON haritası içermiyor.');
    }

    final Map<String, dynamic> data = parsed;
    final prefs = await SharedPreferences.getInstance();
    int totalRestored = 0;

    // 1. RESTORE APP SETTINGS (Görünüm, Temalar, Sayaçlar, Hedefler, Rozetler)
    try {
      final appSettings = data['AppSettings'] ?? data['appSettings'];
      if (appSettings is Map<String, dynamic>) {
        // Theme
        if (appSettings.containsKey('AppThemeOption') || appSettings.containsKey('theme_mode')) {
          final raw = appSettings['AppThemeOption'] ?? appSettings['theme_mode'];
          final themeVal = AppThemeKeys.normalize(raw);
          final themeInt = AppThemeKeys.toInt(themeVal);
          await _setSessionPrefInt(prefs, 'AppThemeOption', themeInt);
          await _setSessionPrefString(prefs, 'theme_mode', themeVal);
          await _setSessionPrefString(prefs, 'AppThemeOption_str', themeVal);
        }
        if (appSettings.containsKey('LightSubThemeOption') || appSettings.containsKey('light_sub_theme')) {
          final raw = appSettings['LightSubThemeOption'] ?? appSettings['light_sub_theme'];
          final subVal = AppThemeKeys.normalizeSubTheme(raw);
          final subInt = AppThemeKeys.subThemeToInt(subVal);
          await _setSessionPrefInt(prefs, 'LightSubThemeOption', subInt);
          await _setSessionPrefString(prefs, 'light_sub_theme', subVal);
          await _setSessionPrefString(prefs, 'LightSubThemeOption_str', subVal);
        }

        // Font & Quran View Settings
        if (appSettings.containsKey('QuranArabicFontSize')) {
          await _setSessionPrefDouble(prefs, 'quran_arabic_font_size', _parseDouble(appSettings['QuranArabicFontSize'], 38.0));
        }
        if (appSettings.containsKey('QuranTurkishFontSize')) {
          await _setSessionPrefDouble(prefs, 'quran_turkish_font_size', _parseDouble(appSettings['QuranTurkishFontSize'], 16.0));
        }
        if (appSettings.containsKey('QuranSelectedFontName') && appSettings['QuranSelectedFontName'] != null) {
          await _setSessionPrefString(prefs, 'quran_selected_font_name', appSettings['QuranSelectedFontName'].toString());
        }
        if (appSettings.containsKey('QuranIsBold')) {
          await _setSessionPrefBool(prefs, 'quran_is_bold', _parseBool(appSettings['QuranIsBold'], false));
        }
        if (appSettings.containsKey('QuranReadingMode')) {
          await _setSessionPrefInt(prefs, 'quran_reading_mode', _parseInt(appSettings['QuranReadingMode'], 0));
        }

        // User & Location & Bird
        if (appSettings.containsKey('UserDisplayName') && appSettings['UserDisplayName'] != null) {
          final name = appSettings['UserDisplayName'].toString();
          if (name.isNotEmpty) {
            await _setSessionPrefString(prefs, 'user_display_name', name);
            await _setSessionPrefString(prefs, 'UserDisplayName', name);
          }
        }
        if (appSettings.containsKey('SelectedCity') && appSettings['SelectedCity'] != null) {
          final city = appSettings['SelectedCity'].toString();
          await _setSessionPrefString(prefs, 'selected_city', city);
          await _setSessionPrefString(prefs, 'SelectedCity', city);
          await _setSessionPrefString(prefs, 'AppCity', city);
        }
        if (appSettings.containsKey('SelectedBird') && appSettings['SelectedBird'] != null) {
          final bird = appSettings['SelectedBird'].toString();
          if (bird.isNotEmpty) {
            await _setSessionPrefString(prefs, 'selected_bird', bird);
            await _setSessionPrefString(prefs, 'SelectedBird', bird);
          }
        }

        // Sound & Vibration
        if (appSettings.containsKey('ZikirSoundEnabled')) {
          await _setSessionPrefBool(prefs, 'sound_enabled', _parseBool(appSettings['ZikirSoundEnabled'], true));
        }
        if (appSettings.containsKey('ZikirVibrationEnabled')) {
          await _setSessionPrefBool(prefs, 'vibration_enabled', _parseBool(appSettings['ZikirVibrationEnabled'], true));
        }

        // Goals & Stats
        if (appSettings.containsKey('ZikirDailyGoal')) {
          final val = _parseInt(appSettings['ZikirDailyGoal'], 100);
          await _setSessionPrefInt(prefs, 'zikir_daily_goal', val);
          await _setSessionPrefInt(prefs, 'DailyZikirGoal', val);
          await _setSessionPrefInt(prefs, 'ZikirDailyGoal', val);
        }
        if (appSettings.containsKey('KuranDailyGoal')) {
          final val = _parseInt(appSettings['KuranDailyGoal'], 20);
          await _setSessionPrefInt(prefs, 'kuran_daily_goal', val);
          await _setSessionPrefInt(prefs, 'DailyQuranGoal', val);
          await _setSessionPrefInt(prefs, 'KuranDailyGoal', val);
        }
        if (appSettings.containsKey('KazaDailyGoal')) {
          final val = _parseInt(appSettings['KazaDailyGoal'], 5);
          await _setSessionPrefInt(prefs, 'kaza_daily_goal', val);
          await _setSessionPrefInt(prefs, 'DailyKazaGoal', val);
          await _setSessionPrefInt(prefs, 'KazaDailyGoal', val);
        }
        if (appSettings.containsKey('EzberDailyGoal')) {
          final val = _parseInt(appSettings['EzberDailyGoal'], 1);
          await _setSessionPrefInt(prefs, 'ezber_daily_goal', val);
          await _setSessionPrefInt(prefs, 'DailyEzberGoal', val);
          await _setSessionPrefInt(prefs, 'EzberDailyGoal', val);
        }
        if (appSettings.containsKey('TotalReadPages')) {
          final val = _parseInt(appSettings['TotalReadPages'], 0);
          await _setSessionPrefInt(prefs, 'total_read_pages', val);
          await _setSessionPrefInt(prefs, 'TotalReadPages', val);
          await _setSessionPrefInt(prefs, 'TotalReadQuranPages', val);
        }
        if (appSettings.containsKey('TodayReadPages') || appSettings.containsKey('today_read_pages')) {
          final val = _parseInt(appSettings['TodayReadPages'] ?? appSettings['today_read_pages'], 0);
          final lastRead = appSettings['LastReadDate']?.toString() ?? appSettings['last_read_date']?.toString() ?? '';
          final now = DateTime.now();
          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (val > 0 && (lastRead.isEmpty || lastRead.startsWith(todayStr))) {
            await _setSessionPrefInt(prefs, 'TodayReadPages_$todayStr', val);
            await _setSessionPrefInt(prefs, 'TodayReadPages', val);
            await _setSessionPrefInt(prefs, 'today_read_pages', val);
          }
        }
        if (appSettings.containsKey('LastReadDate') && appSettings['LastReadDate'] != null) {
          await _setSessionPrefString(prefs, 'last_read_date', appSettings['LastReadDate'].toString());
          await _setSessionPrefString(prefs, 'LastReadDate', appSettings['LastReadDate'].toString());
        }
        if (appSettings.containsKey('ReadingStreak')) {
          await _setSessionPrefInt(prefs, 'reading_streak', _parseInt(appSettings['ReadingStreak'], 0));
        }
        if (appSettings.containsKey('BestReadingStreak')) {
          await _setSessionPrefInt(prefs, 'best_reading_streak', _parseInt(appSettings['BestReadingStreak'], 0));
        }
        if (appSettings.containsKey('TotalReadingDays')) {
          await _setSessionPrefInt(prefs, 'total_reading_days', _parseInt(appSettings['TotalReadingDays'], 0));
        }

        // Surah Streaks & Badges Dictionaries
        if (appSettings.containsKey('SurahStreaks') && appSettings['SurahStreaks'] is Map) {
          final map = appSettings['SurahStreaks'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefInt(prefs, entry.key.toString(), _parseInt(entry.value, 0));
          }
          await _setSessionPrefString(prefs, 'SurahStreaks', jsonEncode(appSettings['SurahStreaks']));
        }
        if (appSettings.containsKey('BestSurahStreaks') && appSettings['BestSurahStreaks'] is Map) {
          final map = appSettings['BestSurahStreaks'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefInt(prefs, entry.key.toString(), _parseInt(entry.value, 0));
          }
          await _setSessionPrefString(prefs, 'BestSurahStreaks', jsonEncode(appSettings['BestSurahStreaks']));
        }
        if (appSettings.containsKey('LastReadDates') && appSettings['LastReadDates'] is Map) {
          final map = appSettings['LastReadDates'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefString(prefs, entry.key.toString(), entry.value.toString());
          }
          await _setSessionPrefString(prefs, 'LastReadDates', jsonEncode(appSettings['LastReadDates']));
        }

        // Unlocked Badges from AppSettings
        if (appSettings.containsKey('UnlockedBadgeIds') && appSettings['UnlockedBadgeIds'] is List) {
          final List<String> badgeIds = [];
          for (final bId in (appSettings['UnlockedBadgeIds'] as List)) {
            if (bId != null && bId.toString().isNotEmpty) {
              badgeIds.add(bId.toString());
              await db.into(db.unlockedBadges).insert(
                UnlockedBadgesCompanion(
                  badgeId: Value(bId.toString()),
                  category: const Value('General'),
                  unlockedAt: Value(DateTime.now()),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
          await prefs.setStringList(_sKey('UnlockedBadgeIds'), badgeIds);
          if (_isDefaultSession) {
            await prefs.setStringList('UnlockedBadgeIds', badgeIds);
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] AppSettings restore warning: $e');
    }

    // 2. RESTORE USER PROFILE (Base64 avatar & DisplayName)
    try {
      final userProfile = data['UserProfile'] ?? data['userProfile'];
      if (userProfile is Map<String, dynamic>) {
        final displayName = userProfile['DisplayName'] ?? userProfile['displayName'] ?? userProfile['userName'];
        final finalName = (displayName != null && displayName.toString().trim().isNotEmpty)
            ? displayName.toString().trim()
            : null;

        if (finalName != null) {
          await _setSessionPrefString(prefs, 'user_display_name', finalName);
          await _setSessionPrefString(prefs, 'UserDisplayName', finalName);
        }

        final avatarBase64 = userProfile['AvatarBase64'] ?? userProfile['avatarBase64'];
        final avatarPath = userProfile['AvatarPath'] ?? userProfile['avatarPath'];

        String resolvedAvatarPath = '';
        if (avatarBase64 != null && avatarBase64.toString().isNotEmpty) {
          try {
            final bytes = base64Decode(avatarBase64.toString().trim());
            final docDir = await getApplicationDocumentsDirectory();
            final targetSid = sessionId ?? UserSession.defaultSessionId;
            final newFileName = 'profile_${targetSid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final newFile = File(p.join(docDir.path, newFileName));
            await newFile.writeAsBytes(bytes);
            resolvedAvatarPath = newFile.path;
          } catch (e) {
            debugPrint('[GoogleDrive] AvatarBase64 decode error: $e');
          }
        }

        if (resolvedAvatarPath.isEmpty && avatarPath != null && avatarPath.toString().isNotEmpty) {
          final pStr = avatarPath.toString().trim();
          if (pStr.startsWith('assets/') || pStr.startsWith('http://') || pStr.startsWith('https://')) {
            resolvedAvatarPath = pStr;
          } else {
            final directFile = File(pStr);
            if (directFile.existsSync()) {
              resolvedAvatarPath = directFile.path;
            } else {
              try {
                final docDir = await getApplicationDocumentsDirectory();
                final candidate = File(p.join(docDir.path, p.basename(pStr)));
                if (candidate.existsSync()) {
                  resolvedAvatarPath = candidate.path;
                }
              } catch (_) {}
            }
          }
        }

        if (resolvedAvatarPath.isNotEmpty) {
          await _setSessionPrefString(prefs, 'UserProfileImage', resolvedAvatarPath);
          await _setSessionPrefString(prefs, 'avatar', resolvedAvatarPath);
        }

        try {
          final existingProfile = await db.select(db.userProfiles).getSingleOrNull();
          if (existingProfile != null) {
            await (db.update(db.userProfiles)..where((t) => t.id.equals(existingProfile.id))).write(
              existingProfile.copyWith(
                userName: finalName ?? existingProfile.userName,
                avatar: resolvedAvatarPath.isNotEmpty ? resolvedAvatarPath : existingProfile.avatar,
              ),
            );
          } else {
            await db.into(db.userProfiles).insert(
              UserProfilesCompanion(
                userName: Value(finalName ?? 'Zâkir'),
                avatar: Value(resolvedAvatarPath.isNotEmpty ? resolvedAvatarPath : 'assets/images/avatar_male_1.png'),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        } catch (_) {}

        // Multi-Hesap Oturum Bilgilerini (UserSession) kalıcı güncelle
        try {
          final currentSid = sessionId ?? UserSession.defaultSessionId;
          final sessions = await SessionManagerService.loadSessions();
          final sIndex = sessions.indexWhere((s) => s.id == currentSid);
          if (sIndex != -1) {
            final s = sessions[sIndex];
            final updated = s.copyWith(
              displayName: finalName ?? s.displayName,
              avatar: resolvedAvatarPath.isNotEmpty ? resolvedAvatarPath : s.avatar,
            );
            await SessionManagerService.updateSession(updated);
          }
        } catch (e) {
          debugPrint('[GoogleDrive] SessionManagerService profile sync error: $e');
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] UserProfile restore warning: $e');
    }

    // 3. RESTORE USER STREAKS & SHIELDS (Seri, Kalkan ve Puanlar)
    try {
      final userStreak = data['UserStreak'] ?? data['userStreak'] ?? (data['UserStreaks'] is List ? (data['UserStreaks'] as List).firstOrNull : null);
      if (userStreak is Map<String, dynamic>) {
        final currentStreak = _parseInt(userStreak['CurrentStreak'] ?? userStreak['currentStreak'], 0);
        final longestStreak = _parseInt(userStreak['LongestStreak'] ?? userStreak['bestStreak'] ?? userStreak['BestStreak'], 0);
        final totalActiveDays = _parseInt(userStreak['TotalActiveDays'] ?? userStreak['totalDays'], 0);
        final shieldCount = _parseInt(userStreak['ShieldCount'] ?? userStreak['freezeCount'] ?? userStreak['ZikirProtectionCount'], 2);
        final lastActiveUnix = _parseInt(userStreak['LastActiveDateUnix'], 0);
        final lastDateStr = lastActiveUnix > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastActiveUnix * 1000).toIso8601String().split('T').first
            : DateTime.now().toIso8601String().split('T').first;

        final unlockedBirds = userStreak['UnlockedBirds']?.toString();
        if (unlockedBirds != null && unlockedBirds.isNotEmpty) {
          await _setSessionPrefString(prefs, 'UnlockedBirds', unlockedBirds);
        }

        // Safe Diamond and Gold Restore (Never downgrade balances)
        final sfx = _isDefaultSession ? '' : '_$sessionId';
        final remoteDiamonds = _tryParseInt(
          userStreak['DiamondCount'] ??
          (data['AppSettings'] is Map ? data['AppSettings']['DiamondCount'] : null) ??
          (data['Gamification'] is Map ? data['Gamification']['DiamondCount'] : null)
        );
        final remoteGold = _tryParseInt(
          userStreak['GoldCount'] ??
          userStreak['OverflowBadgeCount'] ??
          (data['AppSettings'] is Map ? data['AppSettings']['GoldCount'] : null) ??
          (data['Gamification'] is Map ? data['Gamification']['GoldCount'] : null)
        );

        final curDiamonds = PrefUtils.getIntFromKeys(prefs, ['DiamondCount$sfx', 'DiamondCount'], 0);
        final curGold = PrefUtils.getIntFromKeys(prefs, ['GoldCount$sfx', 'GoldCount'], 0);

        final finalDiamonds = max(curDiamonds, remoteDiamonds ?? 0);
        final finalGold = max(curGold, remoteGold ?? (currentStreak * 50));

        if (finalDiamonds > 0) {
          await _setSessionPrefInt(prefs, 'DiamondCount', finalDiamonds);
        }
        if (finalGold > 0) {
          await _setSessionPrefInt(prefs, 'GoldCount', finalGold);
        }

        final rankObj = UserRank.calculateRank(currentStreak * 100);

        await db.into(db.userStreaks).insert(
          UserStreaksCompanion(
            id: const Value(1),
            currentStreak: Value(currentStreak),
            bestStreak: Value(longestStreak),
            totalDays: Value(totalActiveDays),
            lastDate: Value(lastDateStr),
            freezeCount: Value(shieldCount),
            multiplier: const Value(1.0),
            xp: Value(finalGold > 0 ? finalGold : (currentStreak * 50)),
            rank: Value(rankObj.name),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    } catch (e) {
      debugPrint('[GoogleDrive] UserStreak restore warning: $e');
    }

    // 4. RESTORE DATABASE TABLES IN TRANSACTION WITH EMERGENCY CORRUPTION RECOVERY
    Future<int> executeTableRestore() async {
      int restored = 0;
      await db.transaction(() async {
        // 4.1 Zikirs (Zikirler)
        final zikirsList = data['Zikirler'] ?? data['zikirler'];
        if (zikirsList is List) {
          for (final item in zikirsList) {
            if (item is! Map<String, dynamic>) continue;
            final zId = _tryParseInt(item['ZikirId'] ?? item['id']);
            final zName = item['ZikirAdi'] ?? item['name'] ?? 'Zikir';
            final zArabic = item['ArapceMetin'] ?? item['arabic'];
            final zTarget = _parseInt(item['ZikirMiktar'] ?? item['target'], 33);
            final zCount = _parseInt(item['Sayac'] ?? item['currentCount'], 0);
            final zTotal = _parseInt(item['ZikirToplam'] ?? item['totalCount'], 0);
            final zLap = _parseInt(item['MaxSeyir'] ?? item['lap'], 0);
            final zFav = _parseBool(item['IsFavorite'] ?? item['isFavorite'], false);
            final zCat = item['Kategori'] ?? item['category'] ?? 'Genel';
            final zSound = item['ZikirAciklama'] ?? item['soundEffect'] ?? 'bulbul';
            final unix = _tryParseInt(item['TarihUnix']);
            final createdAt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();

            await db.into(db.zikirs).insert(
              ZikirsCompanion(
                id: zId != null ? Value(zId) : const Value.absent(),
                name: Value(zName.toString()),
                arabic: Value(zArabic?.toString()),
                target: Value(zTarget),
                currentCount: Value(zCount),
                totalCount: Value(zTotal),
                lap: Value(zLap),
                isFavorite: Value(zFav),
                category: Value(zCat.toString()),
                soundEffect: Value(zSound.toString()),
                vibrationEnabled: const Value(true),
                createdAt: Value(createdAt),
              ),
              mode: InsertMode.insertOrReplace,
            );
            restored++;
          }
        }

        // 4.2 Zikir Logs (ZikirLogs)
        final logsList = data['ZikirLogs'] ?? data['zikirLogs'];
        if (logsList is List) {
          for (final item in logsList) {
            if (item is! Map<String, dynamic>) continue;
            final lId = _tryParseInt(item['LogId'] ?? item['id']);
            final zId = _parseInt(item['ZikirId'] ?? item['zikirId'], 1);
            final count = _parseInt(item['CekilenMiktar'] ?? item['count'], 0);
            final unix = _tryParseInt(item['TarihUnix']);
            final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();
            final dateStr = item['dateStr']?.toString() ?? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

            await db.into(db.zikirLogs).insert(
              ZikirLogsCompanion(
                id: lId != null ? Value(lId) : const Value.absent(),
                zikirId: Value(zId),
                count: Value(count),
                dateStr: Value(dateStr),
                timestamp: Value(dt),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // 4.3 Hatimler (Hatimler)
        final hatimlerList = data['Hatimler'] ?? data['hatimler'];
        if (hatimlerList is List) {
          for (final item in hatimlerList) {
            if (item is! Map<String, dynamic>) continue;
            final hId = item['HatimId']?.toString() ?? item['id']?.toString() ?? '1';
            final hTitle = item['HatimAdi'] ?? item['title'] ?? 'Hatim';
            final completedPages = _parseInt(item['CurrentPage'] ?? item['CompletedPages'] ?? item['completedPages'], 0);
            final isComp = _parseBool(item['IsCompleted'] ?? item['isCompleted'], false);
            final isGroup = _parseBool(item['Type'] == 1 || item['Type'] == '1' || item['isGroup'] == true, false);

            await db.into(db.hatims).insert(
              HatimsCompanion(
                id: Value(hId),
                title: Value(hTitle.toString()),
                completedPages: Value(completedPages),
                isCompleted: Value(isComp),
                isGroup: Value(isGroup),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // 4.4 Hatim Cüz İlerlemeleri (HatimCuzProgressList)
        final cuzList = data['HatimCuzProgressList'] ?? data['hatimCuzProgresses'];
        if (cuzList is List) {
          for (final item in cuzList) {
            if (item is! Map<String, dynamic>) continue;
            final cpId = _tryParseInt(item['Id'] ?? item['id']);
            final hatimId = item['HatimId']?.toString() ?? item['hatimId']?.toString() ?? '1';
            final juzNo = _parseInt(item['CuzNumber'] ?? item['juzNo'], 1);
            final isDone = _parseBool(item['Status'] == 2 || item['Status'] == '2' || item['isCompleted'] == true, false);
            final reader = item['OwnerName'] ?? item['readerName'];

            await db.into(db.hatimCuzProgresses).insert(
              HatimCuzProgressesCompanion(
                id: cpId != null ? Value(cpId) : const Value.absent(),
                hatimId: Value(hatimId),
                juzNo: Value(juzNo),
                isCompleted: Value(isDone),
                readerName: Value(reader?.toString()),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // 4.5 Ezber Planları (MemorizationPlans)
        final plansList = data['MemorizationPlans'] ?? data['memorizationPlans'];
        if (plansList is List) {
          for (final item in plansList) {
            if (item is! Map<String, dynamic>) continue;
            final pageId = _tryParseInt(item['PageId'] ?? item['pageId']);
            if (pageId == null) continue;

            final surahId = _tryParseInt(item['SurahId'] ?? item['surahId']);
            final state = _parseInt(item['State'] ?? item['state'], 0);
            final timesReviewed = _parseInt(item['TimesReviewed'] ?? item['timesReviewed'], 0);
            final unix = _tryParseInt(item['ScheduledReviewDateUnix']);
            final reviewDate = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();

            final existing = await (db.select(db.memorizationPlans)..where((tbl) => tbl.pageId.equals(pageId))).getSingleOrNull();
            if (existing != null) {
              await (db.update(db.memorizationPlans)..where((tbl) => tbl.pageId.equals(pageId))).write(
                MemorizationPlansCompanion(
                  surahId: Value(surahId),
                  scheduledReviewDate: Value(reviewDate),
                  state: Value(state),
                  timesReviewed: Value(timesReviewed),
                ),
              );
            } else {
              await db.into(db.memorizationPlans).insert(
                MemorizationPlansCompanion(
                  pageId: Value(pageId),
                  surahId: Value(surahId),
                  scheduledReviewDate: Value(reviewDate),
                  state: Value(state),
                  timesReviewed: Value(timesReviewed),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
        }

        // 4.6 Hafızlık Günlük Kayıtları (HafizlikDailyLogs)
        final hafizlikList = data['HafizlikDailyLogs'] ?? data['hafizlikDailyLogs'];
        if (hafizlikList is List) {
          for (final item in hafizlikList) {
            if (item is! Map<String, dynamic>) continue;
            final dStr = item['DateStr']?.toString() ?? item['dateStr']?.toString();
            final isHam = _parseBool(item['IsHamDone'] ?? item['isHamDone'], false);
            final isPismis = _parseBool(item['IsPismisDone'] ?? item['isPismisDone'], false);
            final isHas = _parseBool(item['IsHasDone'] ?? item['isHasDone'], false);
            final isAsgari = _parseBool(item['IsAsgariVirdDone'] ?? item['isAsgariVirdDone'], false);
            final virdRepeats = _parseInt(item['AsgariVirdRepeats'] ?? item['asgariVirdRepeats'], 0);

            if (dStr != null && dStr.isNotEmpty) {
              final existing = await (db.select(db.hafizlikDailyLogs)..where((tbl) => tbl.dateStr.equals(dStr))).getSingleOrNull();
              if (existing != null) {
                await (db.update(db.hafizlikDailyLogs)..where((tbl) => tbl.dateStr.equals(dStr))).write(
                  HafizlikDailyLogsCompanion(
                    isHamDone: Value(isHam),
                    isPismisDone: Value(isPismis),
                    isHasDone: Value(isHas),
                    isAsgariVirdDone: Value(isAsgari),
                    asgariVirdRepeats: Value(virdRepeats),
                  ),
                );
              } else {
                await db.into(db.hafizlikDailyLogs).insert(
                  HafizlikDailyLogsCompanion(
                    dateStr: Value(dStr),
                    isHamDone: Value(isHam),
                    isPismisDone: Value(isPismis),
                    isHasDone: Value(isHas),
                    isAsgariVirdDone: Value(isAsgari),
                    asgariVirdRepeats: Value(virdRepeats),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // 4.7 Kaza Namazları (KazaPrayers)
        final kazaList = data['KazaPrayers'] ?? data['kazaPrayers'];
        if (kazaList is List) {
          for (final item in kazaList) {
            if (item is! Map<String, dynamic>) continue;
            final pType = item['PrayerName']?.toString() ?? item['PrayerType']?.toString() ?? item['prayerType']?.toString();
            final total = _parseInt(item['Count'] ?? item['TargetCount'] ?? item['targetCount'] ?? item['TotalCount'] ?? item['totalCount'], 0);
            final comp = _parseInt(item['CompletedCount'] ?? item['completedCount'], 0);

            if (pType != null && pType.isNotEmpty) {
              final existing = await (db.select(db.kazaPrayers)..where((tbl) => tbl.prayerType.equals(pType))).getSingleOrNull();
              if (existing != null) {
                await (db.update(db.kazaPrayers)..where((tbl) => tbl.id.equals(existing.id))).write(
                  KazaPrayersCompanion(
                    totalCount: Value(total),
                    completedCount: Value(comp),
                  ),
                );
              } else {
                await db.into(db.kazaPrayers).insert(
                  KazaPrayersCompanion(
                    prayerType: Value(pType),
                    totalCount: Value(total),
                    completedCount: Value(comp),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // 4.8 Kaza Melt Logs (KazaMeltLogs)
        final meltList = data['KazaMeltLogs'] ?? data['kazaMeltLogs'];
        if (meltList is List) {
          for (final item in meltList) {
            if (item is! Map<String, dynamic>) continue;
            final mId = _tryParseInt(item['Id'] ?? item['id']);
            final pType = item['PrayerName']?.toString() ?? item['PrayerType']?.toString() ?? item['prayerType']?.toString() ?? 'Sabah';
            final amount = _parseInt(item['Count'] ?? item['MeltAmount'] ?? item['meltAmount'], 1);
            final unix = _tryParseInt(item['Timestamp']);
            final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix) : DateTime.now();

            await db.into(db.kazaMeltLogs).insert(
              KazaMeltLogsCompanion(
                id: mId != null ? Value(mId) : const Value.absent(),
                prayerType: Value(pType),
                meltAmount: Value(amount),
                timestamp: Value(dt),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // 4.9 Prayer Answer Logs (PrayerAnswerLogs)
        final answerList = data['PrayerAnswerLogs'] ?? data['prayerAnswerLogs'];
        if (answerList is List) {
          for (final item in answerList) {
            if (item is! Map<String, dynamic>) continue;
            final dStr = item['DateStr'] ?? item['dateStr'] ?? item['Date'] ?? item['date'] ?? '';
            final pName = item['PrayerType'] ?? item['prayerType'] ?? item['PrayerName'] ?? item['prayerName'] ?? '';
            final answer = item['Answer']?.toString() ?? item['answer']?.toString() ?? '';
            final performed = answer == 'Evet' || answer == 'Kıldım' || _parseBool(item['IsPerformed'] ?? item['isPerformed'], false);

            if (dStr.toString().isNotEmpty && pName.toString().isNotEmpty) {
              final existing = await (db.select(db.prayerAnswerLogs)
                ..where((tbl) => tbl.dateStr.equals(dStr.toString()) & tbl.prayerType.equals(pName.toString()))
              ).getSingleOrNull();

              if (existing != null) {
                await (db.update(db.prayerAnswerLogs)..where((tbl) => tbl.id.equals(existing.id))).write(
                  PrayerAnswerLogsCompanion(
                    isPerformed: Value(performed),
                  ),
                );
              } else {
                await db.into(db.prayerAnswerLogs).insert(
                  PrayerAnswerLogsCompanion(
                    dateStr: Value(dStr.toString()),
                    prayerType: Value(pName.toString()),
                    isPerformed: Value(performed),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }
      });
      return restored;
    }

    try {
      totalRestored = await executeTableRestore();
    } catch (e) {
      final errLower = e.toString().toLowerCase();
      final isMalformed = errLower.contains('malformed') ||
          errLower.contains('code 11') ||
          errLower.contains('sqliteexception(11)');

      if (isMalformed) {
        debugPrint('[GoogleDrive] Emergency: Database disk image is malformed ($e). Purging corrupted files and rebuilding clean database...');
        final activeDbFileName = db.dbFileName ?? 'zikirce_app.sqlite';
        try {
          await db.close();
        } catch (_) {}

        await AppDatabase.deleteDatabaseFiles(activeDbFileName);

        // Recreate pristine new AppDatabase
        db = AppDatabase(null, activeDbFileName);

        // Re-attempt profile insert on fresh db
        try {
          final userProfile = data['UserProfile'] ?? data['userProfile'];
          if (userProfile is Map<String, dynamic>) {
            final displayName = userProfile['DisplayName'] ?? userProfile['displayName'] ?? userProfile['userName'];
            await db.into(db.userProfiles).insert(
              UserProfilesCompanion(
                userName: Value(displayName != null && displayName.toString().isNotEmpty ? displayName.toString() : 'Zâkir'),
                avatar: const Value('assets/images/avatar_male_1.png'),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        } catch (_) {}

        // Retry table restore on the clean new database
        totalRestored = await executeTableRestore();
        debugPrint('[GoogleDrive] Database successfully rebuilt and all data restored from cloud!');
      } else {
        rethrow;
      }
    }

    // 5. RESTORE COMPLETED TASKS
    // 6. RESTORE APP SETTINGS & DAILY GOALS
    try {
      final settings = (data['AppSettings'] ?? data['settings']) as Map<String, dynamic>?;
      if (settings != null) {
        if (settings.containsKey('ZikirDailyGoal') || settings.containsKey('DailyZikirGoal') || settings.containsKey('zikir_daily_goal')) {
          final val = _parseInt(settings['ZikirDailyGoal'] ?? settings['DailyZikirGoal'] ?? settings['zikir_daily_goal'], 100);
          await _setSessionPrefInt(prefs, 'ZikirDailyGoal', val);
          await _setSessionPrefInt(prefs, 'DailyZikirGoal', val);
          await _setSessionPrefInt(prefs, 'zikir_daily_goal', val);
        }
        if (settings.containsKey('KuranDailyGoal') || settings.containsKey('DailyQuranGoal') || settings.containsKey('kuran_daily_goal')) {
          final val = _parseInt(settings['KuranDailyGoal'] ?? settings['DailyQuranGoal'] ?? settings['kuran_daily_goal'], 20);
          await _setSessionPrefInt(prefs, 'KuranDailyGoal', val);
          await _setSessionPrefInt(prefs, 'DailyQuranGoal', val);
          await _setSessionPrefInt(prefs, 'kuran_daily_goal', val);
        }
        if (settings.containsKey('EzberDailyGoal') || settings.containsKey('DailyEzberGoal') || settings.containsKey('ezber_daily_goal')) {
          final val = _parseInt(settings['EzberDailyGoal'] ?? settings['DailyEzberGoal'] ?? settings['ezber_daily_goal'], 1);
          await _setSessionPrefInt(prefs, 'EzberDailyGoal', val);
          await _setSessionPrefInt(prefs, 'DailyEzberGoal', val);
          await _setSessionPrefInt(prefs, 'ezber_daily_goal', val);
        }
        if (settings.containsKey('KazaDailyGoal') || settings.containsKey('DailyKazaGoal') || settings.containsKey('kaza_daily_goal')) {
          final val = _parseInt(settings['KazaDailyGoal'] ?? settings['DailyKazaGoal'] ?? settings['kaza_daily_goal'], 5);
          await _setSessionPrefInt(prefs, 'KazaDailyGoal', val);
          await _setSessionPrefInt(prefs, 'DailyKazaGoal', val);
          await _setSessionPrefInt(prefs, 'kaza_daily_goal', val);
        }
        if (settings.containsKey('IsZikirGoalEnabled') || settings.containsKey('IsDailyZikirGoalEnabled')) {
          final val = _parseBool(settings['IsZikirGoalEnabled'] ?? settings['IsDailyZikirGoalEnabled'], true);
          await _setSessionPrefBool(prefs, 'IsZikirGoalEnabled', val);
          await _setSessionPrefBool(prefs, 'IsDailyZikirGoalEnabled', val);
        }
        if (settings.containsKey('IsKuranGoalEnabled') || settings.containsKey('IsDailyQuranGoalEnabled')) {
          final val = _parseBool(settings['IsKuranGoalEnabled'] ?? settings['IsDailyQuranGoalEnabled'], true);
          await _setSessionPrefBool(prefs, 'IsKuranGoalEnabled', val);
          await _setSessionPrefBool(prefs, 'IsDailyQuranGoalEnabled', val);
        }
        if (settings.containsKey('IsEzberGoalEnabled') || settings.containsKey('IsHafizlikRepeatGoalEnabled')) {
          final val = _parseBool(settings['IsEzberGoalEnabled'] ?? settings['IsHafizlikRepeatGoalEnabled'], false);
          await _setSessionPrefBool(prefs, 'IsEzberGoalEnabled', val);
          await _setSessionPrefBool(prefs, 'IsHafizlikRepeatGoalEnabled', val);
        }
        if (settings.containsKey('IsKazaGoalEnabled') || settings.containsKey('IsDailyKazaGoalEnabled')) {
          final val = _parseBool(settings['IsKazaGoalEnabled'] ?? settings['IsDailyKazaGoalEnabled'], false);
          await _setSessionPrefBool(prefs, 'IsKazaGoalEnabled', val);
          await _setSessionPrefBool(prefs, 'IsDailyKazaGoalEnabled', val);
        }
        if (settings.containsKey('IsDailyPrayersGoalEnabled') || settings.containsKey('IsPrayersGoalEnabled')) {
          final val = _parseBool(settings['IsDailyPrayersGoalEnabled'] ?? settings['IsPrayersGoalEnabled'], false);
          await _setSessionPrefBool(prefs, 'IsDailyPrayersGoalEnabled', val);
          await _setSessionPrefBool(prefs, 'IsPrayersGoalEnabled', val);
        }
        if (settings.containsKey('KazaWeeklyTarget') || settings.containsKey('kaza_weekly_target')) {
          final val = _parseInt(settings['KazaWeeklyTarget'] ?? settings['kaza_weekly_target'], 45);
          await _setSessionPrefInt(prefs, 'KazaWeeklyTarget', val);
          await _setSessionPrefInt(prefs, 'kaza_weekly_target', val);
        }
        if (settings.containsKey('KazaMonthlyTarget') || settings.containsKey('kaza_monthly_target')) {
          final val = _parseInt(settings['KazaMonthlyTarget'] ?? settings['kaza_monthly_target'], 450);
          await _setSessionPrefInt(prefs, 'KazaMonthlyTarget', val);
          await _setSessionPrefInt(prefs, 'kaza_monthly_target', val);
        }
        if (settings.containsKey('SelectedSurahGoals')) {
          await _setSessionPrefString(prefs, 'SelectedSurahGoals', settings['SelectedSurahGoals'].toString());
        }
        if (settings.containsKey('SurahStreaks') && settings['SurahStreaks'] is Map) {
          final map = settings['SurahStreaks'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefInt(prefs, entry.key.toString(), _parseInt(entry.value, 0));
          }
        }
        if (settings.containsKey('BestSurahStreaks') && settings['BestSurahStreaks'] is Map) {
          final map = settings['BestSurahStreaks'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefInt(prefs, entry.key.toString(), _parseInt(entry.value, 0));
          }
        }
        if (settings.containsKey('LastReadDates') && settings['LastReadDates'] is Map) {
          final map = settings['LastReadDates'] as Map;
          for (final entry in map.entries) {
            await _setSessionPrefString(prefs, entry.key.toString(), entry.value.toString());
          }
        }
        if (settings.containsKey('Quran_ArabicFontSize')) await _setSessionPrefDouble(prefs, 'Quran_ArabicFontSize', _parseDouble(settings['Quran_ArabicFontSize'], 38.0));
        if (settings.containsKey('Quran_TurkishFontSize')) await _setSessionPrefDouble(prefs, 'Quran_TurkishFontSize', _parseDouble(settings['Quran_TurkishFontSize'], 16.0));
        if (settings.containsKey('Quran_SelectedFontName')) await _setSessionPrefString(prefs, 'Quran_SelectedFontName', settings['Quran_SelectedFontName'].toString());
        if (settings.containsKey('CustomQuranBadgesJson')) {
          await _setSessionPrefString(prefs, 'CustomQuranBadges_List_v1', settings['CustomQuranBadgesJson'].toString());
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] AppSettings restore warning: $e');
    }

    final allZikirs = await db.select(db.zikirs).get();
    final allLogs = await db.select(db.zikirLogs).get();
    final zikirsTotal = allZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
    final logsTotal = allLogs.fold<int>(0, (sum, l) => sum + l.count);
    final curTotal = PrefUtils.getInt(prefs, _sKey('TotalZikir'), 0);
    final effectiveTotal = max(max(zikirsTotal, logsTotal), curTotal);
    await _setSessionPrefInt(prefs, 'TotalZikir', effectiveTotal);

    await DataReconciliationService.reconcileAll(db, sessionId);
    await WidgetSyncService.syncAll(db, sessionId: sessionId);
    return totalRestored;
  }

  /// Yeni bulut oturumu açıldığında Drive'da mevcut yedeği bulup otomatik olarak yükler
  Future<bool> restoreLatestBackupIfExists() async {
    try {
      final token = await getValidAccessToken();
      if (token == null || token.isEmpty) return false;

      // 1. Önce varsayılan Zikirce_CloudBackup.json dosyasını ara
      final searchRes = await _dio.get(
        driveFilesEndpoint,
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false",
          'fields': 'files(id, name, modifiedTime)',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      String? targetFileId;
      if (searchRes.statusCode == 200 && searchRes.data != null) {
        final files = searchRes.data['files'] as List?;
        if (files != null && files.isNotEmpty) {
          targetFileId = files.first['id']?.toString();
        }
      }

      // 2. Bulunamadıysa appDataFolder veya root içindeki en son Zikirce yedeğini bul
      if (targetFileId == null || targetFileId.isEmpty) {
        final allBackups = await listCloudBackups();
        final cloudOnly = allBackups.where((b) => !b.isLocal && !b.fileId.startsWith('local:')).toList();
        if (cloudOnly.isNotEmpty) {
          targetFileId = cloudOnly.first.fileId;
        }
      }

      if (targetFileId != null && targetFileId.isNotEmpty) {
        debugPrint('[GoogleDrive] Found existing cloud backup for session $sessionId: $targetFileId. Restoring...');
        final downloadRes = await _dio.get(
          '$driveFilesEndpoint/$targetFileId?alt=media',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            responseType: ResponseType.plain,
            followRedirects: true,
          ),
        );

        if (downloadRes.statusCode == 200 && downloadRes.data != null) {
          final content = downloadRes.data.toString();
          if (content.isNotEmpty) {
            await restoreFromJson(content);
            debugPrint('[GoogleDrive] ✅ Cloud backup successfully auto-imported for session $sessionId.');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] restoreLatestBackupIfExists warning: $e');
    }
    return false;
  }

  /// Bulut yedeğindeki kullanıcı adı ve profil resmini çekip oturumla senkronize eder
  Future<Map<String, String>?> syncCloudProfileToSession() async {
    try {
      final token = await getValidAccessToken();
      if (token == null || token.isEmpty) return null;

      // 1. Zikirce_CloudBackup.json veya en son bulut yedeğini bul
      final searchRes = await _dio.get(
        driveFilesEndpoint,
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false",
          'fields': 'files(id, name, modifiedTime)',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      String? targetFileId;
      if (searchRes.statusCode == 200 && searchRes.data != null) {
        final files = searchRes.data['files'] as List?;
        if (files != null && files.isNotEmpty) {
          targetFileId = files.first['id']?.toString();
        }
      }

      if (targetFileId == null || targetFileId.isEmpty) {
        final allBackups = await listCloudBackups();
        final cloudOnly = allBackups.where((b) => !b.isLocal && !b.fileId.startsWith('local:')).toList();
        if (cloudOnly.isNotEmpty) {
          targetFileId = cloudOnly.first.fileId;
        }
      }

      if (targetFileId != null && targetFileId.isNotEmpty) {
        final downloadRes = await _dio.get(
          '$driveFilesEndpoint/$targetFileId?alt=media',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            responseType: ResponseType.plain,
            followRedirects: true,
          ),
        );

        if (downloadRes.statusCode == 200 && downloadRes.data != null) {
          final content = downloadRes.data.toString();
          if (content.isNotEmpty) {
            await restoreFromJson(content);

            final sid = sessionId ?? UserSession.defaultSessionId;
            final sessions = await SessionManagerService.loadSessions();
            final matching = sessions.firstWhere((s) => s.id == sid, orElse: () => sessions.first);
            return {
              'displayName': matching.displayName,
              'avatar': matching.avatar,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] syncCloudProfileToSession error: $e');
    }
    return null;
  }

  // ===========================================================================
  // GOOGLE DRIVE CLOUD OPERATIONS & BACKUP LISTING
  // ===========================================================================

  /// Google Drive (appDataFolder & drive) ve cihaz yerel hafızasındaki tüm yedekleri listeler
  Future<List<CloudBackupInfo>> listCloudBackups() async {
    final list = <CloudBackupInfo>[];
    final token = await getValidAccessToken();

    if (token != null && token.isNotEmpty) {
      try {
        // 1. appDataFolder içindeki TÜM dosyaları çek
        try {
          final allAppDataRes = await _dio.get(
            driveFilesEndpoint,
            queryParameters: {
              'spaces': 'appDataFolder',
              'fields': 'files(id, name, modifiedTime, size)',
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );

          if (allAppDataRes.statusCode == 200 && allAppDataRes.data != null) {
            final files = allAppDataRes.data['files'] as List?;
            if (files != null && files.isNotEmpty) {
              for (final f in files) {
                final id = f['id']?.toString() ?? '';
                final name = f['name']?.toString() ?? '';
                final modTimeStr = f['modifiedTime']?.toString() ?? '';
                final size = _tryParseInt(f['size']);
                final modTime = DateTime.tryParse(modTimeStr)?.toLocal() ?? DateTime.now();

                // Eğer ana yedek dosyası ise doğrudan listeye ekle
                if (name == backupFileName) {
                  list.add(CloudBackupInfo(
                    fileId: id,
                    fileName: backupFileName,
                    modifiedTime: modTime,
                    deviceName: 'Ana Sürüm (.NET MAUI / Flutter)',
                    displayName: 'Otomatik Bulut Yedeği (En Son)',
                    sizeBytes: size,
                  ));
                  continue;
                }

                // Diğer tarih damgalı dosyalar
                int? streak;
                int? zikirCount;
                String devName = 'Bulut Cihazı';
                String dispName = 'Geçmiş Yedek';

                if (name.startsWith('Zikirce_Backup_') && name.endsWith('.json')) {
                  final clean = name.substring(0, name.length - 5);
                  final parts = clean.split('_');
                  if (parts.length >= 7) {
                    if (parts[4].startsWith('S')) {
                      streak = int.tryParse(parts[4].substring(1));
                    }
                    if (parts[5].startsWith('Z')) {
                      zikirCount = int.tryParse(parts[5].substring(1));
                    }
                    devName = parts.sublist(6).join(' ').replaceAll('_', ' ');
                    dispName = 'Geçmiş Yedek (Seri: ${streak ?? 0}, Zikir: ${zikirCount ?? 0})';
                  }
                }

                list.add(CloudBackupInfo(
                  fileId: id,
                  fileName: name,
                  modifiedTime: modTime,
                  deviceName: devName,
                  displayName: dispName,
                  streakCount: streak,
                  zikirCount: zikirCount,
                  sizeBytes: size,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[GoogleDrive] All appData search error: $e');
        }

        // 2. Drive ana dizininde (spaces=drive) Zikirce dosyası var mı ara
        try {
          final driveRes = await _dio.get(
            driveFilesEndpoint,
            queryParameters: {
              'spaces': 'drive',
              'q': "(name contains 'Zikirce' or name contains 'zikir') and trashed = false",
              'fields': 'files(id, name, modifiedTime, size)',
              'orderBy': 'modifiedTime desc',
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );

          if (driveRes.statusCode == 200 && driveRes.data != null) {
            final files = driveRes.data['files'] as List?;
            if (files != null) {
              for (final f in files) {
                final id = f['id']?.toString() ?? '';
                final name = f['name']?.toString() ?? '';
                if (list.any((item) => item.fileId == id)) continue;

                final modTimeStr = f['modifiedTime']?.toString() ?? '';
                final size = _tryParseInt(f['size']);
                final modTime = DateTime.tryParse(modTimeStr)?.toLocal() ?? DateTime.now();

                list.add(CloudBackupInfo(
                  fileId: id,
                  fileName: name,
                  modifiedTime: modTime,
                  deviceName: 'Google Drive',
                  displayName: 'Drive Yedeği ($name)',
                  sizeBytes: size,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[GoogleDrive] Drive root search error: $e');
        }
      } catch (e) {
        debugPrint('[GoogleDrive] listCloudBackups general error: $e');
      }
    }

    // 3. Yerel hafıza (Android İndirilenler & Belgeler) dosyalarını tara
    try {
      final localFiles = await _findLocalBackupFiles();
      for (final lf in localFiles) {
        if (!list.any((item) => item.fileName == lf.fileName)) {
          list.add(lf);
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] Local backup files scan error: $e');
    }

    list.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return list;
  }

  Future<List<CloudBackupInfo>> _findLocalBackupFiles() async {
    final localList = <CloudBackupInfo>[];
    final candidateDirs = <Directory>[];

    // Documents dir
    try {
      final docDir = await getApplicationDocumentsDirectory();
      candidateDirs.add(docDir);
    } catch (_) {}

    // Android Downloads dir
    if (Platform.isAndroid) {
      candidateDirs.add(Directory('/storage/emulated/0/Download'));
      candidateDirs.add(Directory('/sdcard/Download'));
    }

    for (final dir in candidateDirs) {
      if (!dir.existsSync()) continue;
      try {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last;
            if (name.startsWith('Zikirce_') && (name.endsWith('.json') || name.endsWith('.zikirback'))) {
              final stat = entity.statSync();
              localList.add(CloudBackupInfo(
                fileId: 'local:${entity.path}',
                fileName: name,
                modifiedTime: stat.modified,
                deviceName: 'Cihaz Hafızası (İndirilenler)',
                displayName: 'Yerel Yedek ($name)',
                sizeBytes: stat.size,
                isLocal: true,
                localFilePath: entity.path,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('[GoogleDrive] Directory scan error for ${dir.path}: $e');
      }
    }

    return localList;
  }

  /// Tüm verileri Google Drive'a yükler (Hem varsayılan hem tarih damgalı)
  Future<bool> backupToCloud() async {
    final token = await getValidAccessToken();
    final jsonContent = await createBackupJson();

    // Yerel kopyayı yaz
    final docDir = await getApplicationDocumentsDirectory();
    final backupFile = File('${docDir.path}/$backupFileName');
    await backupFile.writeAsString(jsonContent, encoding: utf8);

    if (token != null && token.isNotEmpty) {
      try {
        // 1. Varsayılan dosyayı bul ve güncelle/oluştur
        final searchRes = await _dio.get(
          driveFilesEndpoint,
          queryParameters: {
            'spaces': 'appDataFolder',
            'q': "name = '$backupFileName' and 'appDataFolder' in parents and trashed = false",
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        String? existingFileId;
        if (searchRes.statusCode == 200 && searchRes.data != null) {
          final files = searchRes.data['files'] as List?;
          if (files != null && files.isNotEmpty) {
            existingFileId = files.first['id']?.toString();
          }
        }

        if (existingFileId != null && existingFileId.isNotEmpty) {
          await _dio.patch(
            '$driveUploadEndpoint/$existingFileId?uploadType=media',
            data: jsonContent,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json; charset=UTF-8',
              },
            ),
          );
          debugPrint('[GoogleDrive] Backup updated on Drive: $existingFileId');
        } else {
          await _uploadFileToDrive(token, backupFileName, jsonContent);
        }

        // 2. Tarih damgalı geçmiş yedeği oluştur
        final now = DateTime.now();
        final nowStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        final prefs = await SharedPreferences.getInstance();
        final streak = PrefUtils.getIntFromKeys(prefs, ['current_streak', 'CurrentStreak'], 0);
        final timestampedName = 'Zikirce_Backup_${nowStr}_S${streak}_Z0_${Platform.operatingSystem}.json';
        await _uploadFileToDrive(token, timestampedName, jsonContent);
      } catch (e) {
        debugPrint('[GoogleDrive] Upload to Drive error: $e');
        rethrow;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sKey(lastBackupTicksKey), DateTime.now().millisecondsSinceEpoch);
    if (_isDefaultSession) {
      await prefs.setInt(lastBackupTicksKey, DateTime.now().millisecondsSinceEpoch);
    }

    return true;
  }

  /// Arka planda debounced otomatik bulut yedekleme tetikler
  static void triggerAutoBackupBackground(AppDatabase db, {bool force = false, String? sessionId}) {
    Future.microtask(() async {
      try {
        if (_isAutoBackingUp) return;
        final now = DateTime.now();
        if (!force && now.difference(_lastAutoCloudBackupTime) < _minAutoBackupInterval) {
          debugPrint('[GoogleDrive] Auto cloud backup debounced.');
          return;
        }

        final service = GoogleDriveBackupService(db: db, sessionId: sessionId);
        final isAutoEnabled = await service.isAutoBackupEnabled();
        if (!isAutoEnabled && !force) return;

        final signedIn = await service.isSignedIn();
        if (!signedIn) return;

        _isAutoBackingUp = true;
        _lastAutoCloudBackupTime = now;
        debugPrint('[GoogleDrive] Starting background auto cloud backup for session: $sessionId...');
        await service.backupToCloud();
        debugPrint('[GoogleDrive] ✅ Background auto cloud backup completed successfully.');
      } catch (e) {
        debugPrint('[GoogleDrive] Background auto cloud backup warning: $e');
      } finally {
        _isAutoBackingUp = false;
      }
    });
  }

  Future<void> _uploadFileToDrive(String token, String filename, String content) async {
    final boundary = '----WebKitFormBoundary${DateTime.now().millisecondsSinceEpoch}';
    final metadataJson = jsonEncode({
      'name': filename,
      'parents': ['appDataFolder'],
    });

    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--\r\n';

    await _dio.post(
      '$driveUploadEndpoint?uploadType=multipart',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
      ),
    );
  }

  /// Belirli bir bulut dosyasını (veya en sonuncuyu) indirip geri yükler
  Future<int> restoreFromCloud({String? fileId, String? revisionId}) async {
    // 1. Yerel dosya seçilmişse doğrudan oku
    if (fileId != null && fileId.startsWith('local:')) {
      final path = fileId.substring(6);
      return await restoreFromLocalFilePath(path);
    }

    final token = await getValidAccessToken();

    // 2. Google Drive buluttan indir
    if (token != null && token.isNotEmpty) {
      String targetFileId = fileId ?? '';

      if (targetFileId.isEmpty) {
        final backups = await listCloudBackups();
        if (backups.isNotEmpty) {
          final first = backups.first;
          targetFileId = first.fileId;
        }
      }

      if (targetFileId.isNotEmpty && !targetFileId.startsWith('local:')) {
        try {
          final downloadUrl = '$driveFilesEndpoint/$targetFileId?alt=media';
          final downloadRes = await _dio.get(
            downloadUrl,
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              responseType: ResponseType.plain,
              followRedirects: true,
            ),
          );

          if (downloadRes.statusCode == 200 && downloadRes.data != null) {
            final jsonContent = downloadRes.data.toString();
            return await restoreFromJson(jsonContent);
          } else {
            throw Exception('Drive indirme başarısız: HTTP ${downloadRes.statusCode}');
          }
        } catch (e) {
          debugPrint('[GoogleDrive] Download error for $targetFileId: $e');
          rethrow;
        }
      }
    }

    // 3. Bulut boşsa veya bulunamadıysa cihazdaki yerel yedekleri dene
    final localFiles = await _findLocalBackupFiles();
    if (localFiles.isNotEmpty) {
      final best = localFiles.first;
      if (best.localFilePath != null) {
        return await restoreFromLocalFilePath(best.localFilePath!);
      }
    }

    final docDir = await getApplicationDocumentsDirectory();
    final backupFile = File('${docDir.path}/$backupFileName');
    if (backupFile.existsSync()) {
      final jsonContent = await backupFile.readAsString(encoding: utf8);
      return await restoreFromJson(jsonContent);
    }

    throw Exception('Google Drive hesabınızda veya yerel hafızada kayıtlı yedek dosyası bulunamadı.');
  }

  // ===========================================================================
  // LOCAL FILE BACKUP & RESTORE (JSON & .ZIKIRBACK / ZIP)
  // ===========================================================================

  Future<int> restoreFromLocalFilePath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Yedek dosyası bulunamadı: $filePath');
    }

    final isZip = filePath.endsWith('.zikirback') || filePath.endsWith('.zip');
    if (isZip) {
      final bytes = await file.readAsBytes();
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final entry in archive) {
          if (entry.isFile && (entry.name == 'backup.json' || entry.name == 'metadata.json' || entry.name.endsWith('.json'))) {
            final content = utf8.decode(entry.content as List<int>);
            return await restoreFromJson(content);
          }
        }
      } catch (zipErr) {
        debugPrint('[GoogleDrive] Not a valid ZIP, attempting direct JSON parse: $zipErr');
        try {
          final content = utf8.decode(bytes);
          return await restoreFromJson(content);
        } catch (_) {}
      }
      throw Exception('Yedek paketi içinde geçerli JSON verisi bulunamadı.');
    } else {
      final content = await file.readAsString(encoding: utf8);
      return await restoreFromJson(content);
    }
  }

  Future<void> shareLocalBackupFile() async {
    final jsonContent = await createBackupJson();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$backupFileName');
    await file.writeAsString(jsonContent, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Zikirce Yedek Dosyası',
      text: 'Zikirce uygulamanızın tam veri yedeği (.NET MAUI & Flutter tam uyumlu).',
    );
  }
}
