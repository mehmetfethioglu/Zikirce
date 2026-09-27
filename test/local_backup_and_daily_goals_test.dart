import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/backup_service.dart';
import 'package:zikirce/core/services/google_drive_backup_service.dart';
import 'package:zikirce/core/utils/pref_utils.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('BackupService collects 1:1 .NET MAUI BackupData schema', () async {
    // Seed some data
    await db.into(db.zikirs).insert(
      ZikirsCompanion.insert(
        name: 'Elhamdülillah',
        target: const Value(33),
        currentCount: const Value(33),
        totalCount: const Value(330),
      ),
    );

    await db.delete(db.userStreaks).go();
    await db.into(db.userStreaks).insert(
      UserStreaksCompanion.insert(
        currentStreak: const Value(7),
        bestStreak: const Value(15),
        totalDays: const Value(25),
        freezeCount: const Value(4),
        xp: const Value(150),
      ),
    );

    final backupData = await BackupService.collectBackupData(db);

    expect(backupData['AppVersion'], '2.0');
    expect(backupData.containsKey('Zikirler'), isTrue);
    expect(backupData.containsKey('ZikirLogs'), isTrue);
    expect(backupData.containsKey('UserProfile'), isTrue);
    expect(backupData.containsKey('Hatimler'), isTrue);
    expect(backupData.containsKey('HatimCuzProgressList'), isTrue);
    expect(backupData.containsKey('AppSettings'), isTrue);
    expect(backupData.containsKey('UserStreak'), isTrue);
    expect(backupData.containsKey('KazaPrayers'), isTrue);
    expect(backupData.containsKey('PrayerAnswerLogs'), isTrue);
    expect(backupData.containsKey('KazaMeltLogs'), isTrue);
    expect(backupData.containsKey('StreakGapDays'), isTrue);
    expect(backupData.containsKey('UserStreakHistories'), isTrue);
    expect(backupData.containsKey('JuzBookmarks'), isTrue);
    expect(backupData.containsKey('MemorizationPlans'), isTrue);

    final zikirler = backupData['Zikirler'] as List<dynamic>;
    expect(zikirler.length, greaterThanOrEqualTo(1));
    expect(zikirler.any((z) => z['ZikirAdi'] == 'Elhamdülillah'), isTrue);

    final streak = backupData['UserStreak'] as Map<String, dynamic>;
    expect(streak['CurrentStreak'], 7);
    expect(streak['ShieldCount'], 4);
    expect(streak['OverflowBadgeCount'], 150);
  });

  test('GoldenDayService achieves Golden Day when all active enabled goals are met', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();

    // User has Zikir (100) and Quran (5 pages) enabled (default settings)
    await prefs.setBool('IsDailyZikirGoalEnabled', true);
    await prefs.setInt('DailyZikirGoal', 100);

    await prefs.setBool('IsDailyQuranGoalEnabled', true);
    await prefs.setInt('DailyQuranGoal', 5);
    await prefs.setInt('TodayReadPages_$todayStr', 5);

    // Kaza & Ezber & Prayers disabled
    await prefs.setBool('IsDailyKazaGoalEnabled', false);
    await prefs.setBool('IsHafizlikRepeatGoalEnabled', false);
    await prefs.setBool('IsDailyPrayersGoalEnabled', false);

    // Seed 100 zikirs today
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: 1,
        count: 100,
        dateStr: todayStr,
      ),
    );

    // Seed 5 mandatory prayers
    for (final p in ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      await db.into(db.prayerAnswerLogs).insert(
        PrayerAnswerLogsCompanion.insert(
          prayerType: p,
          dateStr: todayStr,
          isPerformed: true,
        ),
      );
    }

    final status = await GoldenDayService.checkGoldenDayStatus(db);

    expect(status.isPrayersMet, isTrue);
    expect(status.isZikirMet, isTrue);
    expect(status.isKuranMet, isTrue);
    expect(status.isGoldCompleted, isTrue);
    expect(status.totalActiveGoals, 3);
    expect(status.completedGoalsCount, 3);

    // Verify 5 ordered goals for profile hearts
    expect(status.orderedGoals.length, 5);
    expect(status.orderedGoals[0].id, 'prayers');
    expect(status.orderedGoals[1].id, 'zikir');
    expect(status.orderedGoals[2].id, 'kuran');
    expect(status.orderedGoals[3].id, 'ezber');
    expect(status.orderedGoals[4].id, 'kaza');

    final chestAvail = prefs.getBool('SurpriseChestAvailable_$todayStr');
    expect(chestAvail, isTrue);
  });

  test('GoldenDayService Excused Mode (Zaruri Hal) waives Prayers and Quran goals', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();

    await prefs.setBool('IsExcusedModeEnabled', true);
    await prefs.setBool('IsDailyZikirGoalEnabled', true);
    await prefs.setInt('DailyZikirGoal', 50);
    await prefs.setBool('IsDailyKazaGoalEnabled', false);
    await prefs.setBool('IsEzberGoalEnabled', false);

    // Seed 50 zikirs (completed)
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: 1,
        count: 50,
        dateStr: todayStr,
      ),
    );

    // Prayers and Quran have 0 progress, but Excused Mode is on -> Should be met!
    final status = await GoldenDayService.checkGoldenDayStatus(db);
    expect(status.isExcusedMode, isTrue);
    expect(status.isPrayersMet, isTrue);
    expect(status.isKuranMet, isTrue);
    expect(status.isZikirMet, isTrue);
    expect(status.isGoldCompleted, isTrue);
    expect(status.orderedGoals[0].isExcused, isTrue);
    expect(status.orderedGoals[2].isExcused, isTrue);
  });

  test('GoldenDayService accurately tracks partial goals progress', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();

    // User has 3 active goals: Zikir (100), Quran (10), Kaza (2) + mandatory prayers
    await prefs.setBool('IsDailyZikirGoalEnabled', true);
    await prefs.setInt('DailyZikirGoal', 100);

    await prefs.setBool('IsDailyQuranGoalEnabled', true);
    await prefs.setInt('DailyQuranGoal', 10);
    await prefs.setInt('TodayReadPages_$todayStr', 4); // not completed (4/10)

    await prefs.setBool('IsDailyKazaGoalEnabled', true);
    await prefs.setInt('DailyKazaGoal', 2);
    await prefs.setInt('TodayKazaCount_$todayStr', 2); // completed (2/2)

    // Seed 100 zikirs today (completed 100/100)
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: 1,
        count: 100,
        dateStr: todayStr,
      ),
    );

    // Seed 5 prayers
    for (final p in ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      await db.into(db.prayerAnswerLogs).insert(
        PrayerAnswerLogsCompanion.insert(
          prayerType: p,
          dateStr: todayStr,
          isPerformed: true,
        ),
      );
    }

    final status = await GoldenDayService.checkGoldenDayStatus(db);

    expect(status.isPrayersMet, isTrue);
    expect(status.isZikirMet, isTrue);
    expect(status.isKuranMet, isFalse);
    expect(status.isKazaMet, isTrue);
    expect(status.isGoldCompleted, isFalse);
    expect(status.totalActiveGoals, 4); // Prayers + Zikir + Quran + Kaza
    expect(status.completedGoalsCount, 3); // Prayers, Zikir, Kaza
  });

  test('PrefUtils safely parses all types and edge cases without casting errors', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('test_str_int', '42');
    await prefs.setString('test_str_double', '3.14');
    await prefs.setString('test_str_bool_true', 'true');
    await prefs.setString('test_str_bool_1', '1');
    await prefs.setString('test_str_bool_false', 'false');
    await prefs.setString('test_invalid_num', 'abc');
    await prefs.setInt('test_native_int', 99);
    await prefs.setBool('test_native_bool', true);
    await prefs.setDouble('test_native_double', 12.34);

    expect(PrefUtils.getInt(prefs, 'test_str_int'), 42);
    expect(PrefUtils.getInt(prefs, 'test_native_int'), 99);
    expect(PrefUtils.getInt(prefs, 'test_invalid_num', 7), 7);
    expect(PrefUtils.getInt(prefs, 'non_existing', 10), 10);

    expect(PrefUtils.getDouble(prefs, 'test_str_double'), 3.14);
    expect(PrefUtils.getDouble(prefs, 'test_native_double'), 12.34);
    expect(PrefUtils.getDouble(prefs, 'test_native_int'), 99.0);

    expect(PrefUtils.getBool(prefs, 'test_str_bool_true'), isTrue);
    expect(PrefUtils.getBool(prefs, 'test_str_bool_1'), isTrue);
    expect(PrefUtils.getBool(prefs, 'test_str_bool_false'), isFalse);
    expect(PrefUtils.getBool(prefs, 'test_native_bool'), isTrue);
    expect(PrefUtils.getBool(prefs, 'non_existing', true), isTrue);

    expect(PrefUtils.getIntFromKeys(prefs, ['missing_key', 'test_str_int']), 42);
    expect(PrefUtils.getStringFromKeys(prefs, ['missing_key', 'test_str_int']), '42');
  });

  test('BackupService and GoogleDriveBackupService handle String preference values without throwing type cast exceptions', () async {
    // Simulate SharedPreferences polluted with String values (e.g. from .NET MAUI migration / XML)
    SharedPreferences.setMockInitialValues({
      'ZikirDailyGoal': '150',
      'DailyZikirGoal': '150',
      'zikir_daily_goal': '150',
      'KuranDailyGoal': '30',
      'kuran_daily_goal': '30',
      'KazaDailyGoal': '5',
      'kaza_daily_goal': '5',
      'EzberDailyGoal': '2',
      'ezber_daily_goal': '2',
      'TotalReadPages': '45',
      'total_read_pages': '45',
      'TodayReadPages': '10',
      'today_read_pages': '10',
      'ReadingStreak': '12',
      'reading_streak': '12',
      'BestReadingStreak': '20',
      'best_reading_streak': '20',
      'AverageDailyPages': '8',
      'average_daily_pages': '8',
      'TotalReadingDays': '15',
      'total_reading_days': '15',
      'Quran_ArabicFontSize': '40.0',
      'quran_arabic_font_size': '40.0',
      'Quran_TurkishFontSize': '18.0',
      'quran_turkish_font_size': '18.0',
      'Quran_ReadingMode': '1',
      'quran_reading_mode': '1',
      'AppThemeOption': '2',
      'LightSubThemeOption': '1',
      'kaza_weekly_target': '45',
      'kaza_monthly_target': '450',
      'DiamondCount': '5',
      'GoldCount': '200',
      'Streak_Waqiah': '3',
      'BestStreak_Waqiah': '5',
      'sound_enabled': 'true',
      'vibration_enabled': 'true',
      'IsAutoBackupEnabled': 'true',
      'IsGoogleDriveAutoBackupEnabled': 'true',
      'IsDailyZikirGoalEnabled': 'true',
      'IsDailyQuranGoalEnabled': 'true',
      'current_streak': '7',
      'LastGoogleDriveBackupTicks': '1700000000000',
    });

    // 1. Verify collectBackupData does not throw
    final backupData = await BackupService.collectBackupData(db);
    expect(backupData, isNotNull);
    final appSettings = backupData['AppSettings'] as Map<String, dynamic>;
    expect(appSettings['ZikirDailyGoal'], 150);
    expect(appSettings['KuranDailyGoal'], 30);
    expect(appSettings['KazaDailyGoal'], 5);
    expect(appSettings['ReadingStreak'], 12);
    expect(appSettings['ZikirSoundEnabled'], isTrue);

    // 2. Verify GoogleDriveBackupService.createBackupJson does not throw
    final driveService = GoogleDriveBackupService(db: db);
    final jsonStr = await driveService.createBackupJson();
    expect(jsonStr, isNotEmpty);
    expect(jsonStr.contains('150'), isTrue);

    // 3. Verify restoreFromJson works
    final restoredCount = await driveService.restoreFromJson(jsonStr);
    expect(restoredCount, greaterThanOrEqualTo(0));

    // 4. Verify local auto-backup can be created without type cast errors
    final autoPath = await BackupService.createAutoBackup(db, force: true);
    expect(autoPath, isNotNull);
  });

  test('Custom profile photo is embedded as Base64 in JSON and ProfileImage.jpg in .zikirback ZIP, and restored properly', () async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Create a dummy image file
    final testImageFile = File('test_avatar_sample.jpg');
    final dummyBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]; // JPEG header bytes
    await testImageFile.writeAsBytes(dummyBytes);

    try {
      await db.delete(db.userProfiles).go();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          userName: const Value('Hz. Zâkir'),
          avatar: Value(testImageFile.path),
        ),
      );
      await prefs.setString('UserProfileImage', testImageFile.path);
      await prefs.setString('UserDisplayName', 'Hz. Zâkir');
      await prefs.setString('user_display_name', 'Hz. Zâkir');

      // 2. Test JSON collection (Base64 embedding)
      final backupData = await BackupService.collectBackupData(db);
      final userProfile = backupData['UserProfile'] as Map<String, dynamic>;
      expect(userProfile['AvatarBase64'], isNotEmpty);
      expect(userProfile['DisplayName'], 'Hz. Zâkir');

      // 3. Test Google Drive JSON backup creation & restore
      final driveService = GoogleDriveBackupService(db: db);
      final jsonStr = await driveService.createBackupJson();
      expect(jsonStr.contains('AvatarBase64'), isTrue);

      // Clear prefs & database profile
      await prefs.remove('UserProfileImage');
      await prefs.remove('avatar');
      await db.delete(db.userProfiles).go();

      // Restore from JSON
      await driveService.restoreFromJson(jsonStr);

      final restoredPath = prefs.getString('UserProfileImage');
      expect(restoredPath, isNotNull);
      expect(restoredPath!.isNotEmpty, isTrue);

      final profileFromDb = await db.select(db.userProfiles).getSingleOrNull();
      expect(profileFromDb, isNotNull);
      expect(profileFromDb!.userName, 'Hz. Zâkir');

      // 4. Test Local .zikirback ZIP backup & restore
      final autoBackupPath = await BackupService.createAutoBackup(db, force: true);
      expect(autoBackupPath, isNotNull);

      // Clear again
      await prefs.remove('UserProfileImage');
      await db.delete(db.userProfiles).go();

      // Restore from .zikirback
      final restoreRes = await BackupService.restoreBackupFile(autoBackupPath!, db);
      expect(restoreRes.success, isTrue);

      final restoredPathFromZip = prefs.getString('UserProfileImage');
      expect(restoredPathFromZip, isNotNull);
      expect(restoredPathFromZip!.isNotEmpty, isTrue);
    } finally {
      if (testImageFile.existsSync()) {
        testImageFile.deleteSync();
      }
    }
  });

  test('All Daily Goals (Zikir, Quran, Kaza, Ezber, Namaz counts and switches) are saved and restored with dual keys', () async {
    final prefs = await SharedPreferences.getInstance();

    // Set custom values for all daily goals
    await prefs.setInt('DailyZikirGoal', 500);
    await prefs.setBool('IsDailyZikirGoalEnabled', true);

    await prefs.setInt('DailyQuranGoal', 15);
    await prefs.setBool('IsDailyQuranGoalEnabled', true);

    await prefs.setInt('DailyKazaGoal', 3);
    await prefs.setBool('IsDailyKazaGoalEnabled', true);

    await prefs.setInt('DailyEzberGoal', 2);
    await prefs.setBool('IsHafizlikRepeatGoalEnabled', true);

    await prefs.setBool('IsDailyPrayersGoalEnabled', true);
    await prefs.setInt('kaza_weekly_target', 60);
    await prefs.setInt('kaza_monthly_target', 600);

    // 1. Collect and verify in AppSettings Map
    final backupData = await BackupService.collectBackupData(db);
    final appSettings = backupData['AppSettings'] as Map<String, dynamic>;

    expect(appSettings['ZikirDailyGoal'], 500);
    expect(appSettings['KuranDailyGoal'], 15);
    expect(appSettings['KazaDailyGoal'], 3);
    expect(appSettings['EzberDailyGoal'], 2);
    expect(appSettings['IsZikirGoalEnabled'], isTrue);
    expect(appSettings['IsKuranGoalEnabled'], isTrue);
    expect(appSettings['IsKazaGoalEnabled'], isTrue);
    expect(appSettings['IsEzberGoalEnabled'], isTrue);
    expect(appSettings['IsDailyPrayersGoalEnabled'], isTrue);
    expect(appSettings['KazaWeeklyTarget'], 60);
    expect(appSettings['KazaMonthlyTarget'], 600);

    // 2. Wipe prefs
    await prefs.clear();

    // 3. Restore using BackupService
    final driveService = GoogleDriveBackupService(db: db);
    final jsonStr = JsonEncoder.withIndent('  ').convert(backupData);
    await driveService.restoreFromJson(jsonStr);

    // Verify dual keys are synchronized
    expect(prefs.getInt('DailyZikirGoal'), 500);
    expect(prefs.getInt('ZikirDailyGoal'), 500);
    expect(prefs.getInt('zikir_daily_goal'), 500);

    expect(prefs.getInt('DailyQuranGoal'), 15);
    expect(prefs.getInt('KuranDailyGoal'), 15);
    expect(prefs.getInt('kuran_daily_goal'), 15);

    expect(prefs.getInt('DailyKazaGoal'), 3);
    expect(prefs.getInt('KazaDailyGoal'), 3);
    expect(prefs.getInt('kaza_daily_goal'), 3);

    expect(prefs.getInt('DailyEzberGoal'), 2);
    expect(prefs.getInt('EzberDailyGoal'), 2);
    expect(prefs.getInt('ezber_daily_goal'), 2);

    expect(prefs.getBool('IsDailyZikirGoalEnabled'), isTrue);
    expect(prefs.getBool('IsZikirGoalEnabled'), isTrue);

    expect(prefs.getBool('IsDailyQuranGoalEnabled'), isTrue);
    expect(prefs.getBool('IsKuranGoalEnabled'), isTrue);

    expect(prefs.getBool('IsDailyKazaGoalEnabled'), isTrue);
    expect(prefs.getBool('IsKazaGoalEnabled'), isTrue);

    expect(prefs.getBool('IsHafizlikRepeatGoalEnabled'), isTrue);
    expect(prefs.getBool('IsEzberGoalEnabled'), isTrue);

    expect(prefs.getBool('IsDailyPrayersGoalEnabled'), isTrue);
    expect(prefs.getInt('KazaWeeklyTarget'), 60);
    expect(prefs.getInt('kaza_weekly_target'), 60);
  });
}
