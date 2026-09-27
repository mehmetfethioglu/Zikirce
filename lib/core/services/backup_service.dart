import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/gamification/services/badge_service.dart';
import '../database/app_database.dart';
import '../services/data_reconciliation_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/widget_sync_service.dart';
import '../theme/theme_provider.dart';
import '../utils/pref_utils.dart';

/// Sonuç modeli
class BackupOperationResult {
  final bool success;
  final String message;
  final String? filePath;
  final DateTime? backupDate;

  BackupOperationResult({
    required this.success,
    required this.message,
    this.filePath,
    this.backupDate,
  });
}

/// .NET MAUI 1:1 Uyumlu Yerel Yedekleme ve Geri Yükleme Servisi
class BackupService {
  static const String backupFileNamePrefix = 'Zikirce_Yedek_';
  static const String autoBackupFileName = 'Zikirce_OtomatikYedek.zikirback';
  static const String autoBackupJsonFileName = 'Zikirce_OtomatikYedek.json';
  
  // Debounce süresi - 30 saniye
  static DateTime _lastAutoBackupTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minBackupInterval = Duration(seconds: 30);

  // ===========================================================================
  // 1. DATA COLLECTION (1:1 .NET MAUI BackupData JSON MAP)
  // ===========================================================================

  static Future<Map<String, dynamic>> collectBackupData(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Zikirler (ZikirBackup)
    final zikirs = await db.select(db.zikirs).get();
    final zikirlerList = zikirs.map((z) => {
      'ZikirId': z.id,
      'ZikirAdi': z.name,
      'ZikirMiktar': z.target,
      'ZikirAciklama': '',
      'ZikirToplam': z.totalCount,
      'TarihUnix': z.createdAt.millisecondsSinceEpoch ~/ 1000,
      'KullaniciKartindaMi': true,
      'CicekGorsel': '',
      'CicekHarf': '',
      'MaxSeyir': z.lap,
      'Sayac': z.currentCount,
      'ArapceMetin': z.arabic ?? '',
      'IsFavorite': z.isFavorite,
      'Kategori': z.category,
    }).toList();

    // 2. ZikirLogs (ZikirLogBackup)
    final zikirLogs = await db.select(db.zikirLogs).get();
    final zikirLogsList = zikirLogs.map((l) => {
      'LogId': l.id,
      'ZikirId': l.zikirId,
      'ZikirAdi': '',
      'CekilenMiktar': l.count,
      'TarihUnix': l.timestamp.millisecondsSinceEpoch ~/ 1000,
    }).toList();

    // 3. UserProfile (UserProfileBackup)
    final profile = (await (db.select(db.userProfiles)..limit(1)).get()).firstOrNull;
    final firstStreak = (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
    final userDisplayName = (profile != null && profile.userName.isNotEmpty && profile.userName != 'Zâkir')
        ? profile.userName
        : PrefUtils.getStringFromKeys(prefs, ['user_display_name', 'UserDisplayName'], profile?.userName ?? 'Zâkir');
    final avatarPath = PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar', 'ProfileImagePath'], profile?.avatar ?? '');
    
    String avatarBase64 = '';
    if (avatarPath.isNotEmpty && !avatarPath.startsWith('assets/')) {
      try {
        final avatarFile = File(avatarPath);
        if (avatarFile.existsSync()) {
          final bytes = await avatarFile.readAsBytes();
          avatarBase64 = base64Encode(bytes);
        }
      } catch (_) {}
    }

    final userProfileMap = {
      'DisplayName': userDisplayName,
      'AvatarPath': avatarPath,
      'TotalZikir': zikirs.fold<int>(0, (sum, z) => sum + z.totalCount),
      'CurrentStreak': firstStreak?.currentStreak ?? 0,
      'LastZikirDateUnix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'AvatarBase64': avatarBase64,
    };

    // 4. Hatimler (HatimBackup)
    final hatims = await db.select(db.hatims).get();
    final hatimlerList = hatims.map((h) => {
      'HatimId': int.tryParse(h.id.replaceAll(RegExp(r'\D'), '')) ?? 1,
      'HatimAdi': h.title,
      'BaslangicTarihiUnix': h.createdAt.millisecondsSinceEpoch ~/ 1000,
      'BitisTarihiUnix': h.targetDate != null ? (h.targetDate!.millisecondsSinceEpoch ~/ 1000) : null,
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
      'LastReadDate': DateTime.now().toIso8601String().split('T').first,
      'TodayReadPages': 0,
      'UsedStreakProtections': 0,
    }).toList();

    // 5. HatimCuzProgressList
    final hatimProgress = await db.select(db.hatimCuzProgresses).get();
    final cuzProgressList = hatimProgress.map((cp) => {
      'Id': cp.id,
      'HatimId': int.tryParse(cp.hatimId.replaceAll(RegExp(r'\D'), '')) ?? 1,
      'CuzNumber': cp.juzNo,
      'OwnerType': 0,
      'OwnerName': cp.readerName ?? userDisplayName,
      'Status': cp.isCompleted ? 2 : 0,
      'CompletedAtUnix': cp.completedAt != null ? (cp.completedAt!.millisecondsSinceEpoch ~/ 1000) : null,
      'LastPage': cp.juzNo * 20,
    }).toList();

    // 6. Badges
    final badges = await db.select(db.unlockedBadges).get();
    List<String> exportedBadgeIds = badges.map((b) => b.badgeId).toList();
    if (exportedBadgeIds.isEmpty) {
      try {
        final evaluated = await BadgeService(db).getBadges();
        exportedBadgeIds = evaluated.where((b) => b.isUnlocked).map((b) => b.id).toList();
      } catch (_) {}
    }

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayReadPagesVal = PrefUtils.getIntFromKeys(prefs, [
      'TodayReadPages_$todayStr',
      'TodayReadPages',
      'today_read_pages',
    ], 0);
    final lastReadDateVal = PrefUtils.getStringFromKeys(prefs, [
      'LastReadDate',
      'last_read_date',
    ], todayReadPagesVal > 0 ? todayStr : '');

    // 7. AppSettings (AppSettingsBackup)
    final appSettingsMap = {
      'ZikirSoundEnabled': PrefUtils.getBool(prefs, 'sound_enabled', true),
      'ZikirVibrationEnabled': PrefUtils.getBool(prefs, 'vibration_enabled', true),
      'IsAutoBackupEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsAutoLocalBackupEnabled', 'IsAutoBackupEnabled'], false),
      'LastZikirId': PrefUtils.getInt(prefs, 'last_zikir_id', -1),
      'IsStreakReminderEnabled': PrefUtils.getBool(prefs, 'IsStreakReminderEnabled', false),
      'StreakReminderTimeTicks': PrefUtils.getInt(prefs, 'StreakReminderTimeTicks', 0),
      'KuranDailyGoal': PrefUtils.getIntFromKeys(prefs, ['KuranDailyGoal', 'DailyQuranGoal', 'kuran_daily_goal'], 20),
      'DailyQuranGoal': PrefUtils.getIntFromKeys(prefs, ['DailyQuranGoal', 'KuranDailyGoal', 'kuran_daily_goal'], 20),
      'IsReadingReminderEnabled': PrefUtils.getBool(prefs, 'IsReadingReminderEnabled', false),
      'ReadingReminderTimeTicks': PrefUtils.getInt(prefs, 'ReadingReminderTimeTicks', 0),
      'TotalReadPages': PrefUtils.getIntFromKeys(prefs, ['TotalReadPages', 'total_read_pages'], 0),
      'TodayReadPages': todayReadPagesVal,
      'LastReadDate': lastReadDateVal,
      'ReadingStreak': PrefUtils.getIntFromKeys(prefs, ['ReadingStreak', 'reading_streak'], 0),
      'BestReadingStreak': PrefUtils.getIntFromKeys(prefs, ['BestReadingStreak', 'best_reading_streak'], 0),
      'AverageDailyPages': PrefUtils.getIntFromKeys(prefs, ['AverageDailyPages', 'average_daily_pages'], 0),
      'TotalReadingDays': PrefUtils.getIntFromKeys(prefs, ['TotalReadingDays', 'total_reading_days'], 0),
      'SelectedCity': PrefUtils.getString(prefs, 'selected_city', 'İstanbul'),
      'UserDisplayName': userDisplayName,
      'SelectedBird': PrefUtils.getStringFromKeys(prefs, ['SelectedBird', 'selected_bird'], 'yeni_bird.json'),
      'QuranArabicFontSize': PrefUtils.getDouble(prefs, 'Quran_ArabicFontSize', 38.0),
      'QuranTurkishFontSize': PrefUtils.getDouble(prefs, 'Quran_TurkishFontSize', 16.0),
      'QuranIsBold': PrefUtils.getBool(prefs, 'Quran_IsBold', false),
      'QuranSelectedFontName': PrefUtils.getString(prefs, 'Quran_SelectedFontName', 'mushaf'),
      'QuranReadingMode': PrefUtils.getInt(prefs, 'Quran_ReadingMode', 0),
      'QuranIsMaskingEnabled': PrefUtils.getBool(prefs, 'Quran_IsMaskingEnabled', false),
      'QuranIsBlurringEnabled': PrefUtils.getBool(prefs, 'Quran_IsBlurringEnabled', false),
      'SelectedDownloadLanguageId': PrefUtils.getInt(prefs, 'SelectedDownloadLanguageId', 5),
      'AppThemeOption': PrefUtils.getStringFromKeys(prefs, ['AppThemeOption', 'theme_mode'], 'system'),
      'AppThemeOptionInt': AppThemeKeys.toInt(PrefUtils.getStringFromKeys(prefs, ['AppThemeOption', 'theme_mode'], 'system')),
      'LightSubThemeOption': PrefUtils.getStringFromKeys(prefs, ['LightSubThemeOption', 'light_sub_theme'], 'greenLight'),
      'IsOnboardingCompleted': true,
      'KazaWeeklyTarget': PrefUtils.getInt(prefs, 'kaza_weekly_target', 45),
      'KazaMonthlyTarget': PrefUtils.getInt(prefs, 'kaza_monthly_target', 450),
      'IsGoogleDriveAutoBackupEnabled': PrefUtils.getBool(prefs, 'IsGoogleDriveAutoBackupEnabled', false),
      'ZikirDailyGoal': PrefUtils.getIntFromKeys(prefs, ['ZikirDailyGoal', 'DailyZikirGoal', 'zikir_daily_goal'], 100),
      'DailyZikirGoal': PrefUtils.getIntFromKeys(prefs, ['DailyZikirGoal', 'ZikirDailyGoal', 'zikir_daily_goal'], 100),
      'KazaDailyGoal': PrefUtils.getIntFromKeys(prefs, ['KazaDailyGoal', 'DailyKazaGoal', 'kaza_daily_goal'], 5),
      'DailyKazaGoal': PrefUtils.getIntFromKeys(prefs, ['DailyKazaGoal', 'KazaDailyGoal', 'kaza_daily_goal'], 5),
      'SelectedSurahGoals': PrefUtils.getString(prefs, 'SelectedSurahGoals', ''),
      'IsZikirGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsZikirGoalEnabled', 'IsDailyZikirGoalEnabled'], true),
      'IsDailyZikirGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyZikirGoalEnabled', 'IsZikirGoalEnabled'], true),
      'IsKuranGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsKuranGoalEnabled', 'IsDailyQuranGoalEnabled'], true),
      'IsDailyQuranGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyQuranGoalEnabled', 'IsKuranGoalEnabled'], true),
      'IsEzberGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsEzberGoalEnabled', 'IsHafizlikRepeatGoalEnabled'], false),
      'IsHafizlikRepeatGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsHafizlikRepeatGoalEnabled', 'IsEzberGoalEnabled'], false),
      'IsKazaGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsKazaGoalEnabled', 'IsDailyKazaGoalEnabled'], false),
      'IsDailyKazaGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyKazaGoalEnabled', 'IsKazaGoalEnabled'], false),
      'IsDailyPrayersGoalEnabled': PrefUtils.getBoolFromKeys(prefs, ['IsDailyPrayersGoalEnabled', 'IsPrayersGoalEnabled'], false),
      'EzberDailyGoal': PrefUtils.getIntFromKeys(prefs, ['EzberDailyGoal', 'DailyEzberGoal', 'ezber_daily_goal'], 1),
      'DailyEzberGoal': PrefUtils.getIntFromKeys(prefs, ['DailyEzberGoal', 'EzberDailyGoal', 'ezber_daily_goal'], 1),
      'SurahStreaks': <String, int>{
        'Streak_Waqiah': PrefUtils.getInt(prefs, 'Streak_Waqiah', 0),
        'Streak_Mulk': PrefUtils.getInt(prefs, 'Streak_Mulk', 0),
        'Streak_Naba': PrefUtils.getInt(prefs, 'Streak_Naba', 0),
        'Streak_Sleep': PrefUtils.getInt(prefs, 'Streak_Sleep', 0),
      },
      'BestSurahStreaks': <String, int>{
        'BestStreak_Waqiah': PrefUtils.getInt(prefs, 'BestStreak_Waqiah', 0),
        'BestStreak_Mulk': PrefUtils.getInt(prefs, 'BestStreak_Mulk', 0),
        'BestStreak_Naba': PrefUtils.getInt(prefs, 'BestStreak_Naba', 0),
        'BestStreak_Sleep': PrefUtils.getInt(prefs, 'BestStreak_Sleep', 0),
      },
      'LastReadDates': <String, String>{
        'LastReadDate_Waqiah': PrefUtils.getString(prefs, 'LastReadDate_Waqiah', ''),
        'LastReadDate_Mulk': PrefUtils.getString(prefs, 'LastReadDate_Mulk', ''),
        'LastReadDate_Naba': PrefUtils.getString(prefs, 'LastReadDate_Naba', ''),
        'LastReadDate_Sleep': PrefUtils.getString(prefs, 'LastReadDate_Sleep', ''),
      },
      'UnlockedBadgeIds': exportedBadgeIds,
      'CustomQuranBadgesJson': PrefUtils.getString(prefs, 'CustomQuranBadges_List_v1', ''),
      'DiamondCount': PrefUtils.getInt(prefs, 'DiamondCount', 0),
      'GoldCount': PrefUtils.getInt(prefs, 'GoldCount', firstStreak?.xp ?? 0),
    };

    // 8. UserStreak (UserStreakBackup)
    final curDiamondsVal = PrefUtils.getInt(prefs, 'DiamondCount', 0);
    final curGoldVal = PrefUtils.getInt(prefs, 'GoldCount', firstStreak?.xp ?? 0);

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
      'UnlockedBirds': PrefUtils.getString(prefs, 'UnlockedBirds', 'yeni_bird.json'),
      'ZikirProtectionCount': firstStreak?.freezeCount ?? 3,
      'KuranProtectionCount': 0,
      'ZikirUsedProtectionCount': 0,
      'KuranUsedProtectionCount': 0,
    };

    // 9. KazaPrayers
    final kazaPrayers = await db.select(db.kazaPrayers).get();
    final kazaPrayersList = kazaPrayers.map((kp) => {
      'PrayerType': kp.prayerType,
      'prayerType': kp.prayerType,
      'CompletedCount': kp.completedCount,
      'completedCount': kp.completedCount,
      'TargetCount': kp.totalCount,
      'TotalCount': kp.totalCount,
      'totalCount': kp.totalCount,
    }).toList();

    // 10. PrayerAnswerLogs
    final prayerLogs = await db.select(db.prayerAnswerLogs).get();
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

    // 11. KazaMeltLogs
    final kazaMelts = await db.select(db.kazaMeltLogs).get();
    final kazaMeltLogsList = kazaMelts.map((km) => {
      'Id': km.id,
      'Date': km.timestamp.toIso8601String(),
      'Amount': km.meltAmount,
      'Type': km.prayerType,
    }).toList();

    // 12. MemorizationPlans
    final plans = await db.select(db.memorizationPlans).get();
    final memorizationPlansList = plans.map((p) => {
      'PageId': p.pageId,
      'SurahId': p.surahId ?? 0,
      'ScheduledReviewDateUnix': p.scheduledReviewDate.millisecondsSinceEpoch ~/ 1000,
      'State': p.state,
      'TimesReviewed': p.timesReviewed,
    }).toList();

    // 13. JuzBookmarks
    final bookmarks = await db.select(db.juzBookmarks).get();
    final juzBookmarksList = bookmarks.map((b) => {
      'JuzNumber': b.juzNo,
      'Page': b.lastPage,
      'CreatedAtUnix': b.updatedAt.millisecondsSinceEpoch ~/ 1000,
    }).toList();

    // 14. StreakGapDays
    final gapDays = await db.select(db.streakGapDays).get();
    final streakGapDaysList = gapDays.map((g) => {
      'MissedDateUnix': DateTime.tryParse(g.dateStr)?.millisecondsSinceEpoch != null
          ? (DateTime.parse(g.dateStr).millisecondsSinceEpoch ~/ 1000)
          : 0,
      'StreakType': 0,
      'RepairStatus': g.isRepaired ? 1 : 0,
      'RepairedAtUnix': null,
      'UsedShieldType': null,
      'CompletedTaskId': null,
    }).toList();

    // 15. UserStreakHistories
    final streakHistories = await db.select(db.userStreakHistories).get();
    final streakHistoriesList = streakHistories.map((sh) => {
      'ActivityDateUnix': DateTime.tryParse(sh.dateStr)?.millisecondsSinceEpoch != null
          ? (DateTime.parse(sh.dateStr).millisecondsSinceEpoch ~/ 1000)
          : 0,
      'StreakType': 0,
      'IsCompleted': true,
    }).toList();

    return {
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
      'StreakGapDays': streakGapDaysList,
      'UserStreakHistories': streakHistoriesList,
      'JuzBookmarks': juzBookmarksList,
      'MemorizationPlans': memorizationPlansList,
    };
  }

  // ===========================================================================
  // 2. CREATE BACKUP FILE & SHARE (.zikirback ZIP / JSON)
  // ===========================================================================

  static Future<String?> createBackupFile(AppDatabase db) async {
    try {
      final backupDataMap = await collectBackupData(db);
      final jsonContent = const JsonEncoder.withIndent('  ').convert(backupDataMap);
      final prefs = await SharedPreferences.getInstance();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      
      // Standard .zikirback hybrid zip package (metadata.json + backup.json + optional ProfileImage.jpg)
      final archive = Archive();
      final jsonBytes = utf8.encode(jsonContent);
      archive.addFile(ArchiveFile('metadata.json', jsonBytes.length, jsonBytes));
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

      // Pack custom profile image into ZIP if exists
      final avatarPath = PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar', 'ProfileImagePath'], '');
      if (avatarPath.isNotEmpty && !avatarPath.startsWith('assets/')) {
        try {
          final avatarFile = File(avatarPath);
          if (avatarFile.existsSync()) {
            final avatarBytes = await avatarFile.readAsBytes();
            if (avatarBytes.isNotEmpty) {
              archive.addFile(ArchiveFile('ProfileImage.jpg', avatarBytes.length, avatarBytes));
            }
          }
        } catch (_) {}
      }

      final zipBytes = ZipEncoder().encode(archive);
      final fileName = 'Zikirce_Yedek_$dateStr.zikirback';
      final file = File('${tempDir.path}/$fileName');

      if (zipBytes != null) {
        await file.writeAsBytes(zipBytes);
      } else {
        // Fallback to plain JSON file
        await file.writeAsString(jsonContent);
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Zikirce Yedek Dosyası ($dateStr)',
        subject: 'Zikirce Yedek Dosyası',
      );

      return file.path;
    } catch (e) {
      debugPrint('[BackupService] createBackupFile Hatası: $e');
      return null;
    }
  }

  // ===========================================================================
  // 3. AUTOMATIC LOCAL BACKUP (DEBOUNCED)
  // ===========================================================================

  static Future<String?> createAutoBackup(AppDatabase db, {bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force && now.difference(_lastAutoBackupTime) < _minBackupInterval) {
        debugPrint('[BackupService] Auto backup debounced.');
        return null;
      }
      _lastAutoBackupTime = now;

      final backupDataMap = await collectBackupData(db);
      final jsonContent = const JsonEncoder.withIndent('  ').convert(backupDataMap);
      final prefs = await SharedPreferences.getInstance();

      String? targetDir;
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (downloadsDir.existsSync()) {
            targetDir = downloadsDir.path;
          } else {
            targetDir = extDir.path;
          }
        }
      }

      targetDir ??= (await getApplicationDocumentsDirectory()).path;

      final autoBackupPath = p.join(targetDir, autoBackupFileName);
      final autoBackupJsonPath = p.join(targetDir, autoBackupJsonFileName);

      // Create ZIP .zikirback with ProfileImage.jpg if custom avatar exists
      final archive = Archive();
      final jsonBytes = utf8.encode(jsonContent);
      archive.addFile(ArchiveFile('metadata.json', jsonBytes.length, jsonBytes));
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

      final avatarPath = PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar', 'ProfileImagePath'], '');
      if (avatarPath.isNotEmpty && !avatarPath.startsWith('assets/')) {
        try {
          final avatarFile = File(avatarPath);
          if (avatarFile.existsSync()) {
            final avatarBytes = await avatarFile.readAsBytes();
            if (avatarBytes.isNotEmpty) {
              archive.addFile(ArchiveFile('ProfileImage.jpg', avatarBytes.length, avatarBytes));
            }
          }
        } catch (_) {}
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes != null) {
        await File(autoBackupPath).writeAsBytes(zipBytes);
      }

      // Also save JSON for absolute redundancy
      await File(autoBackupJsonPath).writeAsString(jsonContent);

      await prefs.setInt('LastLocalBackupTicks', now.millisecondsSinceEpoch);

      debugPrint('[BackupService] ✅ Yerel otomatik yedekleme başarılı: $autoBackupPath');
      return autoBackupPath;
    } catch (e) {
      debugPrint('[BackupService] createAutoBackup Hatası: $e');
      return null;
    }
  }

  static void triggerAutoBackupBackground(AppDatabase db, {bool force = false, String? sessionId}) {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isAutoLocalBackup = PrefUtils.getBoolFromKeys(prefs, ['IsAutoLocalBackupEnabled', 'IsAutoBackupEnabled'], false);
        if (isAutoLocalBackup || force) {
          await createAutoBackup(db, force: force);
        }

        // Also trigger Google Drive auto cloud backup if enabled and signed in
        GoogleDriveBackupService.triggerAutoBackupBackground(db, force: force, sessionId: sessionId);
      } catch (e) {
        debugPrint('[BackupService] triggerAutoBackupBackground Hatası: $e');
      }
    });
  }

  // ===========================================================================
  // 4. RESTORE FROM FILE (.zikirback ZIP, JSON, LEGACY)
  // ===========================================================================

  static Future<BackupOperationResult> pickAndRestoreBackup(AppDatabase db) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zikirback', 'json', 'zikirce', 'zip'],
      );

      if (result == null || result.files.single.path == null) {
        return BackupOperationResult(success: false, message: 'Dosya seçilmedi.');
      }

      return await restoreBackupFile(result.files.single.path!, db);
    } catch (e) {
      return BackupOperationResult(success: false, message: 'Dosya seçilirken hata oluştu: $e');
    }
  }

  static Future<BackupOperationResult> restoreBackupFile(String filePath, AppDatabase db) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return BackupOperationResult(success: false, message: 'Yedek dosyası bulunamadı: $filePath');
      }

      final ext = p.extension(filePath).toLowerCase();
      String jsonString = '';

      if (ext == '.zikirback' || ext == '.zip') {
        // Try unzip
        final bytes = await file.readAsBytes();
        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          ArchiveFile? dataFile;
          ArchiveFile? imageFile;
          for (final f in archive) {
            final lowerName = f.name.toLowerCase();
            if (lowerName == 'profileimage.jpg' || lowerName == 'profileimage.png' || lowerName == 'avatar.jpg' || lowerName == 'avatar.png') {
              imageFile = f;
            } else if (dataFile == null && (lowerName == 'backup.json' || lowerName == 'metadata.json' || lowerName.endsWith('.json'))) {
              dataFile = f;
            }
          }

          if (imageFile != null) {
            try {
              final docDir = await getApplicationDocumentsDirectory();
              final targetExt = p.extension(imageFile.name).isNotEmpty ? p.extension(imageFile.name) : '.jpg';
              final extractedImageFile = File(p.join(docDir.path, 'profile_restored_${DateTime.now().millisecondsSinceEpoch}$targetExt'));
              await extractedImageFile.writeAsBytes(imageFile.content as List<int>);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('UserProfileImage', extractedImageFile.path);
              await prefs.setString('avatar', extractedImageFile.path);
            } catch (e) {
              debugPrint('[BackupService] ProfileImage archive extract warning: $e');
            }
          }

          if (dataFile != null) {
            jsonString = utf8.decode(dataFile.content as List<int>);
          } else {
            // Might be plain JSON with .zikirback extension
            jsonString = utf8.decode(bytes);
          }
        } catch (_) {
          // Direct read if not a zip
          jsonString = await file.readAsString();
        }
      } else {
        jsonString = await file.readAsString();
      }

      jsonString = jsonString.trim();
      if (jsonString.startsWith('\uFEFF')) {
        jsonString = jsonString.substring(1);
      }

      final parsed = jsonDecode(jsonString);
      if (parsed is! Map<String, dynamic>) {
        return BackupOperationResult(success: false, message: 'Geçersiz yedek dosya formatı.');
      }

      // Check legacy format with checksum
      if (parsed.containsKey('checksum') && parsed.containsKey('data')) {
        final rawData = parsed['data'] as String;
        final expectedHash = parsed['checksum'] as String;
        final actualHash = sha256.convert(utf8.encode(rawData)).toString();
        if (actualHash != expectedHash) {
          return BackupOperationResult(success: false, message: 'Doğrulama (checksum) hatası.');
        }
        final innerMap = jsonDecode(rawData) as Map<String, dynamic>;
        final count = await _restoreFromDataMap(innerMap, db);
        return BackupOperationResult(
          success: true,
          message: 'Eski format yedek başarıyla aktarıldı ($count kayıt).',
          backupDate: DateTime.now(),
        );
      }

      // Standard .NET MAUI / Flutter BackupData Map
      final count = await _restoreFromDataMap(parsed, db);
      final backupDateStr = parsed['BackupDate']?.toString();
      final backupDate = backupDateStr != null ? DateTime.tryParse(backupDateStr) : DateTime.now();

      return BackupOperationResult(
        success: true,
        message: 'Yedekleme başarıyla geri yüklendi ($count kayıt aktarıldı).',
        backupDate: backupDate,
      );
    } catch (e) {
      debugPrint('[BackupService] Restore hatası: $e');
      return BackupOperationResult(success: false, message: 'Geri yükleme hatası: $e');
    }
  }

  // ===========================================================================
  // 5. DATABASE & PREFERENCES RESTORATION ENGINE
  // ===========================================================================

  static Future<int> _restoreFromDataMap(Map<String, dynamic> data, AppDatabase db) async {
    int totalRestored = 0;
    final prefs = await SharedPreferences.getInstance();

    await db.transaction(() async {
      // 1. ZIKIRLER
      final zikirlerList = (data['Zikirler'] ?? data['zikirs']) as List<dynamic>?;
      if (zikirlerList != null && zikirlerList.isNotEmpty) {
        await db.delete(db.zikirs).go();
        for (final item in zikirlerList) {
          if (item is Map<String, dynamic>) {
            final name = (item['ZikirAdi'] ?? item['name'] ?? 'Zikir').toString();
            final target = _parseInt(item['ZikirMiktar'] ?? item['target'], 33);
            final currentCount = _parseInt(item['Sayac'] ?? item['currentCount'], 0);
            final totalCount = _parseInt(item['ZikirToplam'] ?? item['totalCount'], 0);
            final lap = _parseInt(item['MaxSeyir'] ?? item['lap'], 0);
            final arabic = (item['ArapceMetin'] ?? item['arabic'])?.toString();
            final isFav = _parseBool(item['IsFavorite'] ?? item['isFavorite'], false);
            final category = (item['Kategori'] ?? item['category'] ?? 'Genel').toString();

            await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                name: name,
                arabic: Value(arabic),
                target: Value(target),
                currentCount: Value(currentCount),
                totalCount: Value(totalCount),
                lap: Value(lap),
                isFavorite: Value(isFav),
                category: Value(category),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 2. ZIKIR LOGS
      final logsList = (data['ZikirLogs'] ?? data['zikir_logs']) as List<dynamic>?;
      if (logsList != null && logsList.isNotEmpty) {
        await db.delete(db.zikirLogs).go();
        for (final item in logsList) {
          if (item is Map<String, dynamic>) {
            final zikirId = _parseInt(item['ZikirId'] ?? item['zikirId'], 1);
            final count = _parseInt(item['CekilenMiktar'] ?? item['count'], 1);
            final unix = _tryParseInt(item['TarihUnix'] ?? item['timestamp']);
            final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix > 100000000000 ? unix : unix * 1000) : DateTime.now();
            final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

            await db.into(db.zikirLogs).insert(
              ZikirLogsCompanion.insert(
                zikirId: zikirId,
                count: count,
                dateStr: dateStr,
                timestamp: Value(dt),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 3. USER PROFILE & AVATAR
      final userProfile = (data['UserProfile'] ?? data['user_profile']) as Map<String, dynamic>?;
      if (userProfile != null) {
        final displayName = (userProfile['DisplayName'] ?? userProfile['userName'] ?? 'Zâkir').toString();
        var avatarPath = (userProfile['AvatarPath'] ?? userProfile['avatar'] ?? '').toString();
        final avatarBase64 = userProfile['AvatarBase64']?.toString() ?? '';

        if (avatarBase64.isNotEmpty) {
          try {
            final appDocDir = await getApplicationDocumentsDirectory();
            final newAvatarFile = File('${appDocDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await newAvatarFile.writeAsBytes(base64Decode(avatarBase64));
            avatarPath = newAvatarFile.path;
          } catch (_) {}
        }

        final totalZikirVal = _parseInt(userProfile['TotalZikir'] ?? userProfile['totalZikir'], 0);
        if (totalZikirVal > 0) {
          await prefs.setInt('TotalZikir', totalZikirVal);
        }

        await prefs.setString('user_display_name', displayName);
        await prefs.setString('UserDisplayName', displayName);
        if (avatarPath.isNotEmpty) {
          await prefs.setString('UserProfileImage', avatarPath);
        }

        await db.delete(db.userProfiles).go();
        await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            userName: Value(displayName),
            avatar: Value(avatarPath),
          ),
        );
        totalRestored++;
      }

      // 4. USER STREAK & CURRENCIES
      final streakMap = (data['UserStreak'] ?? data['streak'] ?? data['user_streak']) as Map<String, dynamic>?;
      if (streakMap != null) {
        final currentStreak = _parseInt(streakMap['CurrentStreak'] ?? streakMap['currentStreak'], 0);
        final longestStreak = _parseInt(streakMap['LongestStreak'] ?? streakMap['bestStreak'], 0);
        final totalDays = _parseInt(streakMap['TotalActiveDays'] ?? streakMap['totalDays'], 0);
        final shields = _parseInt(streakMap['ShieldCount'] ?? streakMap['freezeCount'] ?? streakMap['ZikirProtectionCount'], 2);
        final overflowCoins = _parseInt(streakMap['OverflowBadgeCount'] ?? streakMap['xp'], 0);
        final unlockedBirds = streakMap['UnlockedBirds']?.toString() ?? '';

        // Safe Diamond and Gold Restore
        final remoteDiamonds = int.tryParse(
          streakMap['DiamondCount']?.toString() ??
          (data['AppSettings'] is Map ? data['AppSettings']['DiamondCount']?.toString() : null) ??
          (data['Gamification'] is Map ? data['Gamification']['DiamondCount']?.toString() : null) ??
          ''
        );
        final remoteGold = int.tryParse(
          streakMap['GoldCount']?.toString() ??
          streakMap['OverflowBadgeCount']?.toString() ??
          (data['AppSettings'] is Map ? data['AppSettings']['GoldCount']?.toString() : null) ??
          (data['Gamification'] is Map ? data['Gamification']['GoldCount']?.toString() : null) ??
          ''
        );

        final curDiamonds = PrefUtils.getInt(prefs, 'DiamondCount', 0);
        final curGold = PrefUtils.getInt(prefs, 'GoldCount', 0);

        final finalDiamonds = max(curDiamonds, remoteDiamonds ?? 0);
        final finalGold = max(curGold, remoteGold ?? overflowCoins);

        await db.delete(db.userStreaks).go();
        await db.into(db.userStreaks).insert(
          UserStreaksCompanion.insert(
            currentStreak: Value(currentStreak),
            bestStreak: Value(longestStreak),
            totalDays: Value(totalDays),
            freezeCount: Value(shields),
            xp: Value(finalGold),
          ),
        );

        if (finalDiamonds > 0) {
          await prefs.setInt('DiamondCount', finalDiamonds);
        }
        if (finalGold > 0) {
          await prefs.setInt('GoldCount', finalGold);
        }
        if (unlockedBirds.isNotEmpty) {
          await prefs.setString('UnlockedBirds', unlockedBirds);
        }
        totalRestored++;
      }

      // 5. HATIMLER & CUZ PROGRESS
      final hatimlerList = (data['Hatimler'] ?? data['hatims']) as List<dynamic>?;
      if (hatimlerList != null && hatimlerList.isNotEmpty) {
        await db.delete(db.hatims).go();
        for (final item in hatimlerList) {
          if (item is Map<String, dynamic>) {
            final id = (item['HatimId'] ?? item['id'] ?? '1').toString();
            final title = (item['HatimAdi'] ?? item['title'] ?? 'Hatim').toString();
            final pages = _parseInt(item['CurrentPage'] ?? item['completedPages'], 0);
            final isCompleted = _parseBool(item['IsCompleted'] ?? item['isCompleted'], false);
            final isGroup = _parseInt(item['Type'] ?? (item['isGroup'] == true ? 1 : 0), 0) == 1;

            await db.into(db.hatims).insert(
              HatimsCompanion.insert(
                id: id,
                title: title,
                completedPages: Value(pages),
                isCompleted: Value(isCompleted),
                isGroup: Value(isGroup),
              ),
            );
            totalRestored++;
          }
        }
      }

      final cuzProgressList = (data['HatimCuzProgressList'] ?? data['cuz_progress']) as List<dynamic>?;
      if (cuzProgressList != null && cuzProgressList.isNotEmpty) {
        await db.delete(db.hatimCuzProgresses).go();
        for (final item in cuzProgressList) {
          if (item is Map<String, dynamic>) {
            final hatimId = (item['HatimId'] ?? '1').toString();
            final cuzNumber = _parseInt(item['CuzNumber'] ?? item['juzNo'], 1);
            final status = _parseInt(item['Status'], 0);
            final isCompleted = status == 2 || _parseBool(item['isCompleted'], false);
            final readerName = item['OwnerName']?.toString();

            await db.into(db.hatimCuzProgresses).insert(
              HatimCuzProgressesCompanion.insert(
                hatimId: hatimId,
                juzNo: cuzNumber,
                isCompleted: Value(isCompleted),
                readerName: Value(readerName),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 6. KAZA PRAYERS
      final kazaList = (data['KazaPrayers'] ?? data['kaza']) as List<dynamic>?;
      if (kazaList != null && kazaList.isNotEmpty) {
        await db.delete(db.kazaPrayers).go();
        for (final item in kazaList) {
          if (item is Map<String, dynamic>) {
            final prayerType = (item['PrayerName'] ?? item['PrayerType'] ?? item['prayerType'] ?? 'Sabah').toString();
            final targetCount = _parseInt(item['Count'] ?? item['TargetCount'] ?? item['targetCount'] ?? item['TotalCount'] ?? item['totalCount'], 0);
            final completedCount = _parseInt(item['CompletedCount'] ?? item['completedCount'], 0);

            await db.into(db.kazaPrayers).insert(
              KazaPrayersCompanion.insert(
                prayerType: prayerType,
                totalCount: Value(targetCount),
                completedCount: Value(completedCount),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 7. PRAYER ANSWER LOGS
      final prayerLogsList = (data['PrayerAnswerLogs'] ?? data['prayer_logs']) as List<dynamic>?;
      if (prayerLogsList != null && prayerLogsList.isNotEmpty) {
        await db.delete(db.prayerAnswerLogs).go();
        for (final item in prayerLogsList) {
          if (item is Map<String, dynamic>) {
            final dateStr = (item['Date'] ?? item['dateStr'] ?? '').toString();
            final prayerName = (item['PrayerName'] ?? item['prayerType'] ?? '').toString();
            final answer = item['Answer']?.toString() ?? '';
            final isPerformed = answer == 'Evet' || answer == 'Kıldım' || _parseBool(item['isPerformed'], false);

            if (dateStr.isNotEmpty && prayerName.isNotEmpty) {
              await db.into(db.prayerAnswerLogs).insert(
                PrayerAnswerLogsCompanion.insert(
                  prayerType: prayerName,
                  dateStr: dateStr,
                  isPerformed: isPerformed,
                ),
              );
              totalRestored++;
            }
          }
        }
      }

      // 8. MEMORIZATION PLANS
      final plansList = (data['MemorizationPlans'] ?? data['memorization_plans']) as List<dynamic>?;
      if (plansList != null && plansList.isNotEmpty) {
        await db.delete(db.memorizationPlans).go();
        for (final item in plansList) {
          if (item is Map<String, dynamic>) {
            final pageId = _parseInt(item['PageId'] ?? item['pageId'], 1);
            final surahId = _tryParseInt(item['SurahId'] ?? item['surahId']);
            final unix = _tryParseInt(item['ScheduledReviewDateUnix'] ?? item['scheduledReviewDate']);
            final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix > 100000000000 ? unix : unix * 1000) : DateTime.now();
            final state = _parseInt(item['State'] ?? item['state'], 0);
            final timesReviewed = _parseInt(item['TimesReviewed'] ?? item['timesReviewed'], 0);

            await db.into(db.memorizationPlans).insertOnConflictUpdate(
              MemorizationPlansCompanion.insert(
                pageId: Value(pageId),
                surahId: Value(surahId),
                scheduledReviewDate: dt,
                state: Value(state),
                timesReviewed: Value(timesReviewed),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 9. JUZ BOOKMARKS
      final bookmarksList = data['JuzBookmarks'] as List<dynamic>?;
      if (bookmarksList != null && bookmarksList.isNotEmpty) {
        await db.delete(db.juzBookmarks).go();
        for (final item in bookmarksList) {
          if (item is Map<String, dynamic>) {
            final juzNo = _parseInt(item['JuzNumber'], 1);
            final page = _parseInt(item['Page'], 1);

            await db.into(db.juzBookmarks).insertOnConflictUpdate(
              JuzBookmarksCompanion.insert(
                juzNo: Value(juzNo),
                lastPage: Value(page),
              ),
            );
            totalRestored++;
          }
        }
      }

      // 10. APP SETTINGS RESTORE
      final settings = (data['AppSettings'] ?? data['settings']) as Map<String, dynamic>?;
      if (settings != null) {
        if (settings.containsKey('ZikirDailyGoal') || settings.containsKey('DailyZikirGoal') || settings.containsKey('zikir_daily_goal')) {
          final val = _parseInt(settings['ZikirDailyGoal'] ?? settings['DailyZikirGoal'] ?? settings['zikir_daily_goal'], 100);
          await prefs.setInt('ZikirDailyGoal', val);
          await prefs.setInt('DailyZikirGoal', val);
          await prefs.setInt('zikir_daily_goal', val);
        }
        if (settings.containsKey('KuranDailyGoal') || settings.containsKey('DailyQuranGoal') || settings.containsKey('kuran_daily_goal')) {
          final val = _parseInt(settings['KuranDailyGoal'] ?? settings['DailyQuranGoal'] ?? settings['kuran_daily_goal'], 20);
          await prefs.setInt('KuranDailyGoal', val);
          await prefs.setInt('DailyQuranGoal', val);
          await prefs.setInt('kuran_daily_goal', val);
        }
        if (settings.containsKey('EzberDailyGoal') || settings.containsKey('DailyEzberGoal') || settings.containsKey('ezber_daily_goal')) {
          final val = _parseInt(settings['EzberDailyGoal'] ?? settings['DailyEzberGoal'] ?? settings['ezber_daily_goal'], 1);
          await prefs.setInt('EzberDailyGoal', val);
          await prefs.setInt('DailyEzberGoal', val);
          await prefs.setInt('ezber_daily_goal', val);
        }
        if (settings.containsKey('KazaDailyGoal') || settings.containsKey('DailyKazaGoal') || settings.containsKey('kaza_daily_goal')) {
          final val = _parseInt(settings['KazaDailyGoal'] ?? settings['DailyKazaGoal'] ?? settings['kaza_daily_goal'], 5);
          await prefs.setInt('KazaDailyGoal', val);
          await prefs.setInt('DailyKazaGoal', val);
          await prefs.setInt('kaza_daily_goal', val);
        }
        if (settings.containsKey('IsZikirGoalEnabled') || settings.containsKey('IsDailyZikirGoalEnabled')) {
          final val = _parseBool(settings['IsZikirGoalEnabled'] ?? settings['IsDailyZikirGoalEnabled'], true);
          await prefs.setBool('IsZikirGoalEnabled', val);
          await prefs.setBool('IsDailyZikirGoalEnabled', val);
        }
        if (settings.containsKey('IsKuranGoalEnabled') || settings.containsKey('IsDailyQuranGoalEnabled')) {
          final val = _parseBool(settings['IsKuranGoalEnabled'] ?? settings['IsDailyQuranGoalEnabled'], true);
          await prefs.setBool('IsKuranGoalEnabled', val);
          await prefs.setBool('IsDailyQuranGoalEnabled', val);
        }
        if (settings.containsKey('IsEzberGoalEnabled') || settings.containsKey('IsHafizlikRepeatGoalEnabled')) {
          final val = _parseBool(settings['IsEzberGoalEnabled'] ?? settings['IsHafizlikRepeatGoalEnabled'], false);
          await prefs.setBool('IsEzberGoalEnabled', val);
          await prefs.setBool('IsHafizlikRepeatGoalEnabled', val);
        }
        if (settings.containsKey('IsKazaGoalEnabled') || settings.containsKey('IsDailyKazaGoalEnabled')) {
          final val = _parseBool(settings['IsKazaGoalEnabled'] ?? settings['IsDailyKazaGoalEnabled'], false);
          await prefs.setBool('IsKazaGoalEnabled', val);
          await prefs.setBool('IsDailyKazaGoalEnabled', val);
        }
        if (settings.containsKey('IsDailyPrayersGoalEnabled') || settings.containsKey('IsPrayersGoalEnabled')) {
          final val = _parseBool(settings['IsDailyPrayersGoalEnabled'] ?? settings['IsPrayersGoalEnabled'], false);
          await prefs.setBool('IsDailyPrayersGoalEnabled', val);
          await prefs.setBool('IsPrayersGoalEnabled', val);
        }
        if (settings.containsKey('KazaWeeklyTarget') || settings.containsKey('kaza_weekly_target')) {
          final val = _parseInt(settings['KazaWeeklyTarget'] ?? settings['kaza_weekly_target'], 45);
          await prefs.setInt('KazaWeeklyTarget', val);
          await prefs.setInt('kaza_weekly_target', val);
        }
        if (settings.containsKey('KazaMonthlyTarget') || settings.containsKey('kaza_monthly_target')) {
          final val = _parseInt(settings['KazaMonthlyTarget'] ?? settings['kaza_monthly_target'], 450);
          await prefs.setInt('KazaMonthlyTarget', val);
          await prefs.setInt('kaza_monthly_target', val);
        }
        if (settings.containsKey('SelectedSurahGoals')) {
          await prefs.setString('SelectedSurahGoals', settings['SelectedSurahGoals'].toString());
        }
        if (settings.containsKey('SurahStreaks') && settings['SurahStreaks'] is Map) {
          final map = settings['SurahStreaks'] as Map;
          for (final entry in map.entries) {
            await prefs.setInt(entry.key.toString(), _parseInt(entry.value, 0));
          }
        }
        if (settings.containsKey('BestSurahStreaks') && settings['BestSurahStreaks'] is Map) {
          final map = settings['BestSurahStreaks'] as Map;
          for (final entry in map.entries) {
            await prefs.setInt(entry.key.toString(), _parseInt(entry.value, 0));
          }
        }
        if (settings.containsKey('LastReadDates') && settings['LastReadDates'] is Map) {
          final map = settings['LastReadDates'] as Map;
          for (final entry in map.entries) {
            await prefs.setString(entry.key.toString(), entry.value.toString());
          }
        }
        if (settings.containsKey('Quran_ArabicFontSize')) await prefs.setDouble('Quran_ArabicFontSize', _parseDouble(settings['Quran_ArabicFontSize'], 38.0));
        if (settings.containsKey('Quran_TurkishFontSize')) await prefs.setDouble('Quran_TurkishFontSize', _parseDouble(settings['Quran_TurkishFontSize'], 16.0));
        if (settings.containsKey('Quran_SelectedFontName')) await prefs.setString('Quran_SelectedFontName', settings['Quran_SelectedFontName'].toString());
        if (settings.containsKey('AppThemeOption') || settings.containsKey('theme_mode')) {
          final themeVal = AppThemeKeys.normalize(settings['AppThemeOption'] ?? settings['theme_mode']);
          await prefs.setString('AppThemeOption', themeVal);
          await prefs.setString('theme_mode', themeVal);
        }
        if (settings.containsKey('LightSubThemeOption') || settings.containsKey('light_sub_theme')) {
          final subVal = AppThemeKeys.normalizeSubTheme(settings['LightSubThemeOption'] ?? settings['light_sub_theme']);
          await prefs.setString('LightSubThemeOption', subVal);
          await prefs.setString('light_sub_theme', subVal);
        }
        if (settings.containsKey('TodayReadPages') || settings.containsKey('today_read_pages')) {
          final val = _parseInt(settings['TodayReadPages'] ?? settings['today_read_pages'], 0);
          final lastRead = settings['LastReadDate']?.toString() ?? settings['last_read_date']?.toString() ?? '';
          final now = DateTime.now();
          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (val > 0 && (lastRead.isEmpty || lastRead.startsWith(todayStr))) {
            await prefs.setInt('TodayReadPages_$todayStr', val);
            await prefs.setInt('TodayReadPages', val);
            await prefs.setInt('today_read_pages', val);
          }
        }
        if (settings.containsKey('UnlockedBadgeIds') && settings['UnlockedBadgeIds'] is List) {
          final List<String> badgeIds = [];
          for (final bId in (settings['UnlockedBadgeIds'] as List)) {
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
          await prefs.setStringList('UnlockedBadgeIds', badgeIds);
        }
        if (settings.containsKey('CustomQuranBadgesJson')) {
          await prefs.setString('CustomQuranBadges_List_v1', settings['CustomQuranBadgesJson'].toString());
        }
      }
    });

    final allZikirs = await db.select(db.zikirs).get();
    final allLogs = await db.select(db.zikirLogs).get();
    final zikirsTotal = allZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
    final logsTotal = allLogs.fold<int>(0, (sum, l) => sum + l.count);
    final curTotal = PrefUtils.getInt(prefs, 'TotalZikir', 0);
    await prefs.setInt('TotalZikir', max(max(zikirsTotal, logsTotal), curTotal));

    await DataReconciliationService.reconcileAll(db);
    await WidgetSyncService.syncAll(db);
    return totalRestored;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
      final dParsed = double.tryParse(value.trim());
      if (dParsed != null) return dParsed.toInt();
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
      final dParsed = double.tryParse(trimmed);
      if (dParsed != null) return dParsed.toInt();
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
}
