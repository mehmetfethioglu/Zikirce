import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/prayer_tracking_service.dart';
import 'package:zikirce/features/gamification/models/surprise_chest_reward.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Golden Day & Due Prayers Tests', () {
    test('Before Fajr (no due prayers), isPrayersMet should be true if no missed prayers', () async {
      final nightTime = DateTime(2026, 8, 25, 3, 0); // 03:00 AM
      final due = await PrayerTrackingService.getDuePrayersForToday(nightTime);
      expect(due, isEmpty);

      final status = await GoldenDayService.checkGoldenDayStatus(db, nightTime);
      expect(status.isPrayersMet, isTrue);
    });

    test('After Sabah (due prayers = Sabah), isPrayersMet is true only after Sabah is performed', () async {
      final morningTime = DateTime(2026, 8, 25, 7, 0); // 07:00 AM (after Fajr, before Dhuhr)
      final due = await PrayerTrackingService.getDuePrayersForToday(morningTime);
      expect(due, contains('Sabah'));
      expect(due, isNot(contains('Öğle')));

      // Before performing Sabah
      var status = await GoldenDayService.checkGoldenDayStatus(db, morningTime);
      expect(status.isPrayersMet, isFalse);

      // Perform Sabah
      final todayStr = GoldenDayService.getTodayStr(morningTime);
      await PrayerTrackingService.logPrayerAnswer(db, todayStr, 'Sabah', true);

      status = await GoldenDayService.checkGoldenDayStatus(db, morningTime);
      expect(status.isPrayersMet, isTrue);
    });

    test('If Sabah was marked as missed (Hayır), isPrayersMet is false', () async {
      final morningTime = DateTime(2026, 8, 25, 7, 0);
      final todayStr = GoldenDayService.getTodayStr(morningTime);
      await PrayerTrackingService.logPrayerAnswer(db, todayStr, 'Sabah', false);

      final status = await GoldenDayService.checkGoldenDayStatus(db, morningTime);
      expect(status.isPrayersMet, isFalse);
    });
  });

  group('Kaza Goal and Heart Status Tests', () {
    test('Kaza goal should be met when melt log is recorded for today', () async {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('IsDailyKazaGoalEnabled', true);
      await prefs.setInt('DailyKazaGoal', 1);

      // Initially 0 kaza
      var status = await GoldenDayService.checkGoldenDayStatus(db, now);
      expect(status.isKazaGoalEnabled, isTrue);
      expect(status.isKazaMet, isFalse);
      expect(status.todayKazaCount, equals(0));

      // Record a kaza melt
      await db.into(db.kazaMeltLogs).insert(
        KazaMeltLogsCompanion.insert(
          prayerType: 'Sabah',
          meltAmount: 1,
          timestamp: Value(now),
        ),
      );

      status = await GoldenDayService.checkGoldenDayStatus(db, now);
      expect(status.todayKazaCount, greaterThanOrEqualTo(1));
      expect(status.isKazaMet, isTrue);
    });
  });

  group('Surprise Chest Pending Gold Reward Tests', () {
    test('Chest opened before Yatsi marks gold as pending and claims upon Yatsi prayer', () async {
      final now = DateTime.now();
      final todayStr = GoldenDayService.getTodayStr(now);
      final prefs = await SharedPreferences.getInstance();

      // Open chest before Yatsi is performed
      final reward = await GoldenDayService.openDailySurpriseChest(db: db, isTurkish: true);
      expect(reward, isNotNull);

      if (reward!.type == ChestRewardType.gold || reward.type == ChestRewardType.legendaryBonus) {
        expect(reward.isPendingYatsi, isTrue);
        final pendingGold = prefs.getInt('PendingGoldReward_$todayStr') ?? 0;
        expect(pendingGold, equals(reward.goldAmount));

        // Now user prays Yatsı
        final claimed = await GoldenDayService.claimPendingRewardsIfAny(todayStr);
        expect(claimed, equals(reward.goldAmount));

        // Verify pending is cleared
        expect(prefs.getInt('PendingGoldReward_$todayStr') ?? 0, equals(0));
      }
    });
  });
}
