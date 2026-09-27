import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/session/user_session.dart';
import 'package:zikirce/features/dashboard/providers/dashboard_providers.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';
import 'package:zikirce/features/gamification/services/daily_streak_service.dart';
import 'package:zikirce/features/hatim/providers/hatim_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Quran Daily Tracking & Golden Day Isolation Tests', () {
    test('Waking up in the morning: Yesterday\'s read pages do NOT count towards today', () async {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr(); // e.g. 2026-08-31
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = GoldenDayService.getTodayStr(yesterday);

      // Simulate yesterday: User read 10 pages yesterday
      await prefs.setInt('TodayReadPages_$yesterdayStr', 10);
      await prefs.setInt('TotalReadQuranPages', 50);
      await prefs.setInt('TodayReadPages', 10); // Legacy undated key
      await prefs.setInt('today_read_pages', 10); // Legacy MAUI key

      // Today (morning): User has not read any pages today (TodayReadPages_$todayStr is null)
      // Enable Quran goal (5 pages) and Zikir goal (100)
      await prefs.setBool('IsDailyQuranGoalEnabled', true);
      await prefs.setInt('DailyQuranGoal', 5);
      await prefs.setBool('IsDailyZikirGoalEnabled', false);
      await prefs.setBool('IsDailyKazaGoalEnabled', false);
      await prefs.setBool('IsDailyPrayersGoalEnabled', false);

      // 1. Check GoldenDayService status
      final status = await GoldenDayService.checkGoldenDayStatus(db);
      expect(status.todayKuranPages, 0, reason: 'Morning Quran pages must be 0 for today');
      expect(status.isKuranMet, isFalse, reason: 'Quran goal must NOT be met before reading today');
      expect(status.isGoldCompleted, isFalse, reason: 'Golden Day must NOT be awarded before reading today');

      // 2. Check Hatim stats provider
      final hatimStats = await container.read(hatimStatsProvider.future);
      expect(hatimStats.overallTodayPages, 0, reason: 'Hatim overall today pages must be 0');

      // 3. Listen and verify QuickStats Provider
      container.listen(quickStatsProvider, (_, __) {});
      await pumpEventQueue();
      final quickStats = container.read(quickStatsProvider).valueOrNull;
      expect(quickStats?.quranTodayCount, 0, reason: 'QuickStats today count must be 0');
      expect(quickStats?.formattedQuranToday, '0', reason: 'QuickStats formatted string must be 0');
      expect(quickStats?.quranTotalCount, 50, reason: 'QuickStats total count remains 50');
    });

    test('Reading Quran pages today accurately updates QuickStats and meets Golden Day goal', () async {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr();

      await prefs.setBool('IsDailyQuranGoalEnabled', true);
      await prefs.setInt('DailyQuranGoal', 5);
      await prefs.setBool('IsDailyZikirGoalEnabled', false);
      await prefs.setBool('IsDailyKazaGoalEnabled', false);

      // Initially 0 pages
      var status = await GoldenDayService.checkGoldenDayStatus(db);
      expect(status.todayKuranPages, 0);
      expect(status.isKuranMet, isFalse);

      // User reads 3 pages today
      await prefs.setInt('TodayReadPages_$todayStr', 3);
      status = await GoldenDayService.checkGoldenDayStatus(db);
      expect(status.todayKuranPages, 3);
      expect(status.isKuranMet, isFalse, reason: '3 < 5 pages goal');

      // User reads 2 more pages (total 5 pages today)
      await prefs.setInt('TodayReadPages_$todayStr', 5);
      await prefs.setInt('TotalReadQuranPages', 55);

      status = await GoldenDayService.checkGoldenDayStatus(db);
      expect(status.todayKuranPages, 5);
      expect(status.isKuranMet, isTrue, reason: '5 >= 5 pages goal');

      container.listen(quickStatsProvider, (_, __) {});
      await pumpEventQueue();
      final quickStats = container.read(quickStatsProvider).valueOrNull;
      expect(quickStats?.quranTodayCount, 5);
      expect(quickStats?.formattedQuranToday, '5');
    });

    test('Multi-session isolation: Reading pages in child account does not contaminate default session', () async {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr();
      const childSessionId = 'session_child_123';

      // Default session reads 2 pages today
      await prefs.setInt('TodayReadPages_$todayStr', 2);
      await prefs.setInt('TotalReadQuranPages', 20);

      // Child session reads 10 pages today
      await prefs.setInt('TodayReadPages_${todayStr}_$childSessionId', 10);
      await prefs.setInt('TotalReadQuranPages_$childSessionId', 100);

      // Check Default Session Golden Day
      final defaultStatus = await GoldenDayService.checkGoldenDayStatus(db, null, UserSession.defaultSessionId);
      expect(defaultStatus.todayKuranPages, 2);

      // Check Child Session Golden Day
      final childStatus = await GoldenDayService.checkGoldenDayStatus(db, null, childSessionId);
      expect(childStatus.todayKuranPages, 10);
    });

    test('DailyStreakService startup check does NOT record Quran activity from stale undated keys', () async {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr();
      final yesterdayStr = GoldenDayService.getTodayStr(DateTime.now().subtract(const Duration(days: 1)));

      // Initialize streak record
      await db.delete(db.userStreaks).go();
      await db.into(db.userStreaks).insert(
        UserStreaksCompanion.insert(
          currentStreak: const Value(5),
          lastDate: Value<String?>(yesterdayStr),
        ),
      );

      // Stale undated key present from yesterday
      await prefs.setInt('TodayReadPages', 10);

      // Run startup check
      await DailyStreakService.checkDailyStreakOnStartup(db);

      final streak = await (db.select(db.userStreaks)..limit(1)).getSingle();
      expect(streak.lastDate, yesterdayStr, reason: 'Streak should NOT advance on startup when 0 pages were read today');
      expect(streak.currentStreak, 5);

      // Now user reads pages today
      await prefs.setInt('TodayReadPages_$todayStr', 5);
      await DailyStreakService.checkDailyStreakOnStartup(db);

      final updatedStreak = await (db.select(db.userStreaks)..limit(1)).getSingle();
      expect(updatedStreak.lastDate, todayStr, reason: 'Streak SHOULD advance after reading today');
      expect(updatedStreak.currentStreak, 6);
    });
  });
}
