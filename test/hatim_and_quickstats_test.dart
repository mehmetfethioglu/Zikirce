import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/features/dashboard/providers/dashboard_providers.dart';
import 'package:zikirce/features/gamification/providers/gamification_providers.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';
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

  test('HatimNotifier updates today read pages and overall Quran total', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();

    // Create a Hatim
    final hatimNotifier = container.read(hatimNotifierProvider);
    await hatimNotifier.createHatim(title: 'Ramazan Hatmi', isGroup: false);

    final hatims = await db.select(db.hatims).get();
    expect(hatims.length, 1);
    final hatimId = hatims.first.id;

    // Read to page 25 (25 pages delta from 0)
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 25);

    // Verify SharedPreferences keys
    final hatimToday = prefs.getInt('HatimTodayPages_${hatimId}_$todayStr');
    final overallToday = prefs.getInt('TodayReadPages_$todayStr');
    final totalQuran = prefs.getInt('TotalReadQuranPages');
    final lastReadDate = prefs.getString('HatimLastReadDate_$hatimId');

    expect(hatimToday, 25);
    expect(overallToday, 25);
    expect(totalQuran, 25);
    expect(lastReadDate, isNotNull);

    // Read to page 30 (+5 pages delta)
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 30);

    expect(prefs.getInt('HatimTodayPages_${hatimId}_$todayStr'), 30);
    expect(prefs.getInt('TodayReadPages_$todayStr'), 30);
    expect(prefs.getInt('TotalReadQuranPages'), 30);

    // Reopen and save on SAME page (page 30) -> should NOT increment pages
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 30);

    expect(prefs.getInt('HatimTodayPages_${hatimId}_$todayStr'), 30);
    expect(prefs.getInt('TodayReadPages_$todayStr'), 30);
    expect(prefs.getInt('TotalReadQuranPages'), 30);

    // Turn backward (page 28) -> should NOT increment pages
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 28);

    expect(prefs.getInt('HatimTodayPages_${hatimId}_$todayStr'), 30);
    expect(prefs.getInt('TodayReadPages_$todayStr'), 30);
    expect(prefs.getInt('TotalReadQuranPages'), 30);
  });

  test('QuickStatsData accurately reflects Quran reading stats', () {
    const stats = QuickStatsData(
      todayCount: 1500,
      thisWeekCount: 4500,
      dailyAverage: 500,
      totalCount: 50000,
      quranTodayCount: 15,
      quranTotalCount: 120,
      formattedToday: '1,5K',
      formattedThisWeek: '4,5K',
      formattedDailyAverage: '500',
      formattedTotal: '50,0K',
      formattedQuranToday: '15',
      formattedQuranTotal: '120',
    );

    expect(stats.quranTodayCount, 15);
    expect(stats.formattedQuranToday, '15');
    expect(stats.formattedToday, '1,5K');
  });

  test('GoldenDayService activates Golden Day for custom goal settings', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();

    // User only enabled Zikir (50) and Kaza (1)
    await prefs.setBool('IsDailyZikirGoalEnabled', true);
    await prefs.setInt('DailyZikirGoal', 50);

    await prefs.setBool('IsDailyQuranGoalEnabled', false);
    await prefs.setBool('IsDailyKazaGoalEnabled', true);
    await prefs.setInt('DailyKazaGoal', 1);

    await prefs.setBool('IsHafizlikRepeatGoalEnabled', false);
    await prefs.setBool('IsDailyPrayersGoalEnabled', false);

    // Fulfill Zikir (60 >= 50)
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: 1,
        count: 60,
        dateStr: todayStr,
      ),
    );

    // Fulfill Kaza (1 >= 1)
    await db.into(db.kazaMeltLogs).insert(
      KazaMeltLogsCompanion.insert(
        prayerType: 'Sabah',
        meltAmount: 1,
      ),
    );

    // Fulfill Mandatory 5 Prayers
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
    expect(status.isKazaMet, isTrue);
    expect(status.totalActiveGoals, 3);
    expect(status.completedGoalsCount, 3);
    expect(status.isGoldCompleted, isTrue);
    expect(prefs.getBool('IsTodayGoldCompleted'), isTrue);
    expect(prefs.getBool('SurpriseChestAvailable_$todayStr'), isTrue);
  });
}
