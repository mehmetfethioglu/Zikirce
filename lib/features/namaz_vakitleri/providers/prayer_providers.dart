import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../gamification/services/daily_streak_service.dart';
import '../../gamification/services/golden_day_service.dart';

class CityNotifier extends StateNotifier<String> {
  CityNotifier() : super('Şanlıurfa') {
    _loadCity();
  }

  static const String _prefKey = 'SelectedCity';

  Future<void> _loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? prefs.getString('AppCity');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setCity(String city) async {
    state = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, city);
    await prefs.setString('AppCity', city);
  }
}

final selectedCityProvider = StateNotifierProvider<CityNotifier, String>((ref) {
  return CityNotifier();
});

final currentDateProvider = Provider<String>((ref) {
  final now = ref.watch(timeTickerStreamProvider).valueOrNull ?? DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

final prayerTimingsProvider = FutureProvider<PrayerTimings>((ref) async {
  final city = ref.watch(selectedCityProvider);
  ref.watch(currentDateProvider); // Automatically re-fetch timings when date crosses midnight
  final timings = await PrayerTimesService.getPrayerTimes(city: city);

  // Automatically schedule/update local notifications for prayer times and 'Did you pray?' questions
  try {
    await LocalNotificationService.scheduleAllPrayerNotifications(timings);
  } catch (_) {}

  return timings;
});

// Periodic timer emitting every second for real-time clock and countdown ticking
final timeTickerStreamProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final nextPrayerInfoProvider = Provider<NextPrayerInfo?>((ref) {
  final timingsAsync = ref.watch(prayerTimingsProvider);
  final city = ref.watch(selectedCityProvider);
  ref.watch(timeTickerStreamProvider); // trigger recompute every second

  return timingsAsync.when(
    data: (timings) => PrayerTimesService.getNextPrayerInfo(timings),
    loading: () {
      final offline = PrayerTimesService.calculateOfflinePrayerTimes(city, DateTime.now());
      return PrayerTimesService.getNextPrayerInfo(offline);
    },
    error: (_, __) {
      final offline = PrayerTimesService.calculateOfflinePrayerTimes(city, DateTime.now());
      return PrayerTimesService.getNextPrayerInfo(offline);
    },
  );
});

// Today's 5 Fard Prayers Provider
final todayPrayersProvider = FutureProvider<List<TodayPrayerStatusItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  return PrayerTrackingService.getTodayPrayerStatuses(db);
});

// Past Unanswered Days Provider (e.g. for Confirmation Popup and Banner)
final pendingPastDaysProvider = FutureProvider<PastDaysCheckResult>((ref) async {
  final db = ref.watch(databaseProvider);
  return PrayerTrackingService.getPastUnansweredDays(db);
});

// 5 Daily Prayers Streak Provider
final namazStreakProvider = FutureProvider<({int currentStreak, int longestStreak})>((ref) async {
  final db = ref.watch(databaseProvider);
  return PrayerTrackingService.calculateNamazStreak(db);
});

// Kaza Prayers Stream
final kazaPrayersStreamProvider = StreamProvider<List<KazaPrayer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.kazaPrayers).watch();
});

class KazaSummary {
  final int totalRemaining;
  final int totalCompleted;
  final double weeklyMeltedPercent;
  final double generalMeltedPercent;

  const KazaSummary({
    required this.totalRemaining,
    required this.totalCompleted,
    required this.weeklyMeltedPercent,
    required this.generalMeltedPercent,
  });
}

final kazaSummaryProvider = Provider<KazaSummary>((ref) {
  final listAsync = ref.watch(kazaPrayersStreamProvider);

  return listAsync.when(
    data: (list) {
      if (list.isEmpty) {
        return const KazaSummary(
          totalRemaining: 0,
          totalCompleted: 0,
          weeklyMeltedPercent: 0.0,
          generalMeltedPercent: 0.0,
        );
      }
      final remaining = list.fold<int>(0, (sum, k) => sum + k.totalCount);
      final completed = list.fold<int>(0, (sum, k) => sum + k.completedCount);
      final total = remaining + completed;
      final generalPct = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
      final weeklyPct = (completed / 45.0).clamp(0.0, 1.0);

      return KazaSummary(
        totalRemaining: remaining,
        totalCompleted: completed,
        weeklyMeltedPercent: weeklyPct,
        generalMeltedPercent: generalPct,
      );
    },
    loading: () => const KazaSummary(
      totalRemaining: 0,
      totalCompleted: 0,
      weeklyMeltedPercent: 0.0,
      generalMeltedPercent: 0.0,
    ),
    error: (_, __) => const KazaSummary(
      totalRemaining: 0,
      totalCompleted: 0,
      weeklyMeltedPercent: 0.0,
      generalMeltedPercent: 0.0,
    ),
  );
});

class KazaNotifier extends StateNotifier<void> {
  final Ref ref;

  KazaNotifier(this.ref) : super(null);

  Future<void> adjustKaza(String prayerType, int delta) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).getSingleOrNull();

    if (row != null) {
      final newTotal = (row.totalCount + delta).clamp(0, 999999);
      await (db.update(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).write(
        KazaPrayersCompanion(
          totalCount: Value(newTotal),
        ),
      );
    } else {
      await db.into(db.kazaPrayers).insert(
        KazaPrayersCompanion.insert(
          prayerType: prayerType,
          totalCount: Value(delta.clamp(0, 999999)),
        ),
      );
    }

    ref.invalidate(todayPrayersProvider);
    ref.invalidate(kazaSummaryProvider);
    ref.invalidate(dailyGoalsStatusProvider);
  }

  Future<void> setKazaCount(String prayerType, int count) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).getSingleOrNull();

    if (row != null) {
      await (db.update(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).write(
        KazaPrayersCompanion(
          totalCount: Value(count.clamp(0, 999999)),
        ),
      );
    } else {
      await db.into(db.kazaPrayers).insert(
        KazaPrayersCompanion.insert(
          prayerType: prayerType,
          totalCount: Value(count.clamp(0, 999999)),
        ),
      );
    }

    ref.invalidate(todayPrayersProvider);
    ref.invalidate(kazaSummaryProvider);
    ref.invalidate(dailyGoalsStatusProvider);
  }

  Future<void> performKaza(String prayerType) async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).getSingleOrNull();

    if (row != null && row.totalCount > 0) {
      await (db.update(db.kazaPrayers)..where((t) => t.prayerType.equals(prayerType))).write(
        KazaPrayersCompanion(
          totalCount: Value(row.totalCount - 1),
          completedCount: Value(row.completedCount + 1),
        ),
      );

      // Log melt
      await db.into(db.kazaMeltLogs).insert(
        KazaMeltLogsCompanion.insert(
          prayerType: prayerType,
          meltAmount: 1,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr();
      final curCount = prefs.getInt('TodayKazaCount_$todayStr') ?? 0;
      await prefs.setInt('TodayKazaCount_$todayStr', curCount + 1);

      await DailyStreakService.recordDailyActivity(db);
      ref.read(badgeRefreshTriggerProvider.notifier).state++;
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(dailyGoalsStatusProvider);
    }
  }
}

final kazaNotifierProvider = Provider<KazaNotifier>((ref) {
  return KazaNotifier(ref);
});
