import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/features/gamification/services/daily_streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('MAUI migration with streak=243 and null lastDate advances to 244 on activity', () async {
    // 1. Setup existing streak migrated from MAUI
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(
        currentStreak: Value(243),
        bestStreak: Value(243),
        totalDays: Value(243),
        lastDate: Value.absent(), // null
      ),
    );

    // 2. Perform activity today
    final updated = await DailyStreakService.recordDailyActivity(db);

    expect(updated, isNotNull);
    expect(updated!.currentStreak, 244);
    expect(updated.bestStreak, 244);
    expect(updated.totalDays, 244);
    expect(updated.lastDate, DailyStreakService.getTodayStr());

    // 3. Repeated activity on the same day should maintain streak at 244
    final sameDayAgain = await DailyStreakService.recordDailyActivity(db);
    expect(sameDayAgain!.currentStreak, 244);
  });

  test('Consecutive daily activity advances streak by +1', () async {
    final yesterdayStr = DailyStreakService.getYesterdayStr();

    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      UserStreaksCompanion(
        currentStreak: const Value(5),
        bestStreak: const Value(10),
        totalDays: const Value(20),
        lastDate: Value(yesterdayStr),
      ),
    );

    final updated = await DailyStreakService.recordDailyActivity(db);
    expect(updated, isNotNull);
    expect(updated!.currentStreak, 6);
    expect(updated.bestStreak, 10);
    expect(updated.totalDays, 21);
    expect(updated.lastDate, DailyStreakService.getTodayStr());
  });

  test('Missed single day with shield available consumes shield and keeps streak', () async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final twoDaysAgoStr = '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      UserStreaksCompanion(
        currentStreak: const Value(10),
        bestStreak: const Value(15),
        totalDays: const Value(30),
        freezeCount: const Value(2),
        lastDate: Value(twoDaysAgoStr),
      ),
    );

    final updated = await DailyStreakService.recordDailyActivity(db);
    expect(updated, isNotNull);
    expect(updated!.currentStreak, 11);
    expect(updated.freezeCount, 1);
    expect(updated.lastFreezeDate, DailyStreakService.getYesterdayStr());
  });

  test('Missed two days with enough shields (2) consumes 2 shields and keeps streak', () async {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    final threeDaysAgoStr = '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      UserStreaksCompanion(
        currentStreak: const Value(10),
        bestStreak: const Value(15),
        totalDays: const Value(30),
        freezeCount: const Value(3),
        lastDate: Value(threeDaysAgoStr),
      ),
    );

    final updated = await DailyStreakService.recordDailyActivity(db);
    expect(updated, isNotNull);
    expect(updated!.currentStreak, 11);
    expect(updated.freezeCount, 1); // 3 - 2 = 1 shield left
    expect(updated.lastFreezeDate, DailyStreakService.getYesterdayStr());

    // Verify history records for both missed days
    final histories = await db.select(db.userStreakHistories).get();
    final shieldHistories = histories.where((h) => h.actionType.contains('Kalkan Kullanıldı')).toList();
    expect(shieldHistories.length, 2);
  });

  test('Missed two days with 1 shield: consumes 1 shield partially, logs gap day, and repair restores streak', () async {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    final threeDaysAgoStr = '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      UserStreaksCompanion(
        currentStreak: const Value(10),
        bestStreak: const Value(15),
        totalDays: const Value(30),
        freezeCount: const Value(1), // 1 shield available for 2 missed days
        lastDate: Value(threeDaysAgoStr),
      ),
    );

    final updated = await DailyStreakService.recordDailyActivity(db);
    expect(updated, isNotNull);
    expect(updated!.currentStreak, 1); // Reset to 1 for today
    expect(updated.freezeCount, 0); // Consumed for partial recovery

    // Verify StreakGapDays table has 1 unrepaired day
    final gaps = await DailyStreakService.getUnrepairedGapDays(db);
    expect(gaps.length, 1);

    final hasRepairable = await DailyStreakService.hasRepairableHistoricalStreak(db);
    expect(hasRepairable, isTrue);

    // Now give 1 shield to user and repair the remaining gap
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(
        freezeCount: Value(1),
      ),
    );

    final repairResult = await DailyStreakService.repairNextGapDay(db);
    expect(repairResult.success, isTrue);
    expect(repairResult.remainingGaps, 0);

    // Verify streak is restored and reconnected! (10 pre-gap + 1 current = 11)
    final restoredStreak = await (db.select(db.userStreaks)..limit(1)).getSingle();
    expect(restoredStreak.currentStreak, 11);
    expect(restoredStreak.freezeCount, 0); // 1 shield consumed for repair
  });

  test('Historical streak break repair restores currentStreak to bestStreak using 1 shield', () async {
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(
        currentStreak: Value(1),
        bestStreak: Value(25),
        totalDays: Value(50),
        freezeCount: Value(1),
        lastDate: Value('2026-09-14'),
      ),
    );

    final hasRepairable = await DailyStreakService.hasRepairableHistoricalStreak(db);
    expect(hasRepairable, isTrue);

    final repairResult = await DailyStreakService.repairNextGapDay(db);
    expect(repairResult.success, isTrue);

    final restoredStreak = await (db.select(db.userStreaks)..limit(1)).getSingle();
    expect(restoredStreak.currentStreak, 25);
    expect(restoredStreak.freezeCount, 0);
  });

  test('checkDailyStreakOnStartup detects today zikir logs and activates streak', () async {
    final todayStr = DailyStreakService.getTodayStr();

    // User has 243 streak in DB without lastDate set
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(
        currentStreak: Value(243),
        bestStreak: Value(243),
        totalDays: Value(243),
        lastDate: Value.absent(),
      ),
    );

    // Insert 2000 zikrs logged today
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: 1,
        count: 2000,
        dateStr: todayStr,
      ),
    );

    // App launches and runs startup check
    await DailyStreakService.checkDailyStreakOnStartup(db);

    final current = await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
    expect(current, isNotNull);
    expect(current!.currentStreak, 244);
    expect(current.lastDate, todayStr);
  });

  test('Multi-day gap with partial recovery leaves remaining gaps for later and preserves streak bridge', () async {
    // 1. Setup user with 20 day streak, then missed 3 days
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(
        currentStreak: Value(1),
        bestStreak: Value(20),
        totalDays: Value(25),
        freezeCount: Value(2), // Only 2 shields, but 3 days are missing
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('BrokenStreakPreGapValue', 20);

    // Insert 3 unrepaired gap days
    await db.into(db.streakGapDays).insert(
      const StreakGapDaysCompanion(dateStr: Value('2026-09-10'), isRepaired: Value(false)),
    );
    await db.into(db.streakGapDays).insert(
      const StreakGapDaysCompanion(dateStr: Value('2026-09-11'), isRepaired: Value(false)),
    );
    await db.into(db.streakGapDays).insert(
      const StreakGapDaysCompanion(dateStr: Value('2026-09-12'), isRepaired: Value(false)),
    );

    // 2. Perform partial recovery of 2 days using available 2 shields
    final partialResult = await DailyStreakService.repairGapDaysBatch(db, countToRepair: 2);
    expect(partialResult.success, isTrue);
    expect(partialResult.isFullyRestored, isFalse);
    expect(partialResult.remainingGaps, 1);
    expect(partialResult.repairedCount, 2);

    // Verify 2 days repaired, 1 still unrepaired
    final unrepairedAfterPartial = await DailyStreakService.getUnrepairedGapDays(db);
    expect(unrepairedAfterPartial.length, 1);
    expect(unrepairedAfterPartial.first.dateStr, '2026-09-12');

    // Shielded dates should now include the 2 repaired days
    final shieldedDates = await DailyStreakService.getShieldedDates(db);
    expect(shieldedDates.contains('2026-09-10'), isTrue);
    expect(shieldedDates.contains('2026-09-11'), isTrue);
    expect(shieldedDates.contains('2026-09-12'), isFalse);

    // Has repairable should still be TRUE for the user to rescue the last day later!
    final hasRepairable = await DailyStreakService.hasRepairableHistoricalStreak(db);
    expect(hasRepairable, isTrue);

    // 3. User later acquires 1 more shield and repairs the final day
    await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
      const UserStreaksCompanion(freezeCount: Value(1)),
    );

    final finalResult = await DailyStreakService.repairGapDaysBatch(db, countToRepair: 1);
    expect(finalResult.success, isTrue);
    expect(finalResult.isFullyRestored, isTrue);
    expect(finalResult.remainingGaps, 0);

    // Streak is now reconnected to 20 + 1 = 21!
    final finalStreak = await (db.select(db.userStreaks)..limit(1)).getSingle();
    expect(finalStreak.currentStreak, 21);

    // All 3 days are in shielded dates
    final allShielded = await DailyStreakService.getShieldedDates(db);
    expect(allShielded.contains('2026-09-10'), isTrue);
    expect(allShielded.contains('2026-09-11'), isTrue);
    expect(allShielded.contains('2026-09-12'), isTrue);
  });
}
