import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/prayer_tracking_service.dart';

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

  test('PrayerTrackingService: Answer "Evet" and "Hayır" updates kaza debt and logs correctly', () async {
    const dateStr = '2026-08-24';
    const prayerName = 'Öğle';

    // 1. Initial answer: Hayır -> Kaza should increment
    await PrayerTrackingService.answerPrayerQuestion(db, dateStr, prayerName, false);
    
    var isDone = await PrayerTrackingService.getPrayerAnswer(db, dateStr, prayerName);
    expect(isDone, isFalse);

    var kaza = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerName))).getSingleOrNull();
    expect(kaza, isNotNull);
    expect(kaza!.totalCount, 1);

    // 2. Changed answer from Hayır to Evet -> Kaza should decrement back to 0
    await PrayerTrackingService.answerPrayerQuestion(db, dateStr, prayerName, true);
    isDone = await PrayerTrackingService.getPrayerAnswer(db, dateStr, prayerName);
    expect(isDone, isTrue);

    kaza = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerName))).getSingleOrNull();
    expect(kaza, isNotNull);
    expect(kaza!.totalCount, 0);
  });

  test('PrayerTrackingService: getPastUnansweredDays and savePastDayPrayerAnswers work correctly', () async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    final twoDaysAgo = now.subtract(const Duration(days: 2));
    final twoDaysAgoStr = '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
    await prefs.setString('LastProcessedKazaDate', twoDaysAgoStr);

    // 1. Unanswered past day should be detected
    final result = await PrayerTrackingService.getPastUnansweredDays(db);
    expect(result.recentDays.isNotEmpty, isTrue);
    expect(result.recentDays.any((d) => d.dateStr == yesterdayStr), isTrue);

    // 2. User confirms: Sabah and Öğle performed (true), others missed (false)
    await PrayerTrackingService.savePastDayPrayerAnswers(db, yesterdayStr, {
      'Sabah': true,
      'Öğle': true,
      'İkindi': false,
      'Akşam': false,
      'Yatsı': false,
    });

    final sabahDone = await PrayerTrackingService.getPrayerAnswer(db, yesterdayStr, 'Sabah');
    final ikindiDone = await PrayerTrackingService.getPrayerAnswer(db, yesterdayStr, 'İkindi');
    expect(sabahDone, isTrue);
    expect(ikindiDone, isFalse);

    // Kaza count for missed prayers should have incremented
    final ikindiKaza = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals('İkindi'))).getSingleOrNull();
    expect(ikindiKaza?.totalCount, 1);
  });

  test('PrayerTrackingService: calculateNamazStreak accurately calculates consecutive 5-prayer days', () async {
    final now = DateTime.now();

    for (int dayOffset = 3; dayOffset >= 1; dayOffset--) {
      final targetDate = now.subtract(Duration(days: dayOffset));
      final dStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      for (final prayer in ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
        await PrayerTrackingService.logPrayerAnswer(db, dStr, prayer, true);
      }
    }

    final streak = await PrayerTrackingService.calculateNamazStreak(db);
    expect(streak.currentStreak, 3);
    expect(streak.longestStreak, greaterThanOrEqualTo(3));
  });

  test('PrayerTrackingService: toggleTodayPrayer awards 1 Diamond on 5/5 completion', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('DiamondCount', 0);

    for (final prayer in ['Sabah', 'Öğle', 'İkindi', 'Akşam']) {
      final earned = await PrayerTrackingService.toggleTodayPrayer(db, prayer);
      expect(earned, isFalse);
    }

    // 5th prayer completed -> should award Diamond
    final earnedOnFifth = await PrayerTrackingService.toggleTodayPrayer(db, 'Yatsı');
    expect(earnedOnFifth, isTrue);

    final diamonds = prefs.getInt('DiamondCount') ?? 0;
    expect(diamonds, 1);
  });
}
