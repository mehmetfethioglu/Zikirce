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

import 'package:flutter/foundation.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/utils/pref_utils.dart';

final initialCityProvider = Provider<String>((ref) => 'İstanbul');

class CityNotifier extends StateNotifier<String> {
  final Ref _ref;
  int _latestOperationId = 0;

  CityNotifier(this._ref, String initialCity) : super(initialCity);

  static Future<String> loadSavedCity(String? sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final isDefault = sessionId == null || sessionId == 'default_user';
    final sfx = isDefault ? '' : '_$sessionId';

    if (!isDefault) {
      final sessionCity = PrefUtils.getStringOrNull(prefs, 'SelectedCity$sfx') ??
          PrefUtils.getStringOrNull(prefs, 'AppCity$sfx') ??
          PrefUtils.getStringOrNull(prefs, 'selected_city$sfx');
      if (sessionCity != null && sessionCity.isNotEmpty) {
        return sessionCity;
      }
    }

    return PrefUtils.getStringFromKeys(
      prefs,
      [
        'SelectedCity',
        'AppCity',
        'selected_city',
      ],
      'İstanbul',
    );
  }

  Future<void> reloadForSession(String sessionId) async {
    final opId = ++_latestOperationId;
    final saved = await loadSavedCity(sessionId);
    if (opId == _latestOperationId && saved.isNotEmpty && saved != state) {
      state = saved;
    }
  }

  Future<void> setCity(String city) async {
    if (city.isEmpty) return;
    _latestOperationId++;
    state = city;
    final prefs = await SharedPreferences.getInstance();
    final activeSession = _ref.read(activeSessionProvider);
    final sessionId = activeSession.id;
    final isDefault = sessionId == 'default_user';
    final sfx = isDefault ? '' : '_$sessionId';

    await prefs.setString('SelectedCity$sfx', city);
    await prefs.setString('AppCity$sfx', city);
    await prefs.setString('selected_city$sfx', city);

    if (isDefault) {
      await prefs.setString('SelectedCity', city);
      await prefs.setString('AppCity', city);
      await prefs.setString('selected_city', city);
    }

    // Sync widgets and local notifications for the newly selected city
    try {
      final timings = await PrayerTimesService.getPrayerTimes(city: city);
      await WidgetSyncService.syncPrayerTimes(city: city, timings: timings, sessionId: sessionId);
      await LocalNotificationService.scheduleAllPrayerNotifications(timings);
    } catch (e) {
      debugPrint('[CityNotifier] Sync notice: $e');
    }
  }
}

final selectedCityProvider = StateNotifierProvider<CityNotifier, String>((ref) {
  final initialCity = ref.watch(initialCityProvider);
  return CityNotifier(ref, initialCity);
});

final currentDateProvider = Provider<String>((ref) {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
  final timer = Timer(nextMidnight.difference(now), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

final prayerTimingsProvider = FutureProvider<PrayerTimings>((ref) async {
  final city = ref.watch(selectedCityProvider);
  ref.watch(currentDateProvider); // Automatically re-fetch timings when date crosses midnight
  final timings = await PrayerTimesService.getPrayerTimes(city: city);

  // Sync updated timings to native widgets and schedule local notifications
  try {
    final activeSession = ref.read(activeSessionProvider);
    await WidgetSyncService.syncPrayerTimes(
      city: city,
      timings: timings,
      sessionId: activeSession.id,
    );
    await LocalNotificationService.scheduleAllPrayerNotifications(timings);
  } catch (_) {}

  return timings;
});

// Periodic timer emitting every second ONLY while watched by an active UI widget
final timeTickerStreamProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final nextPrayerInfoProvider = Provider.autoDispose<NextPrayerInfo?>((ref) {
  final timingsAsync = ref.watch(prayerTimingsProvider);
  final city = ref.watch(selectedCityProvider);
  ref.watch(timeTickerStreamProvider); // trigger recompute every second only when watched

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
      final prayerList = list.where((k) => k.prayerType != 'Oruç');
      final remaining = prayerList.fold<int>(0, (sum, k) => sum + k.totalCount);
      final completed = prayerList.fold<int>(0, (sum, k) => sum + k.completedCount);
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

  Future<void> _syncKazaWidgets(AppDatabase db, {String? lastCompletedDate}) async {
    try {
      final kazas = await db.select(db.kazaPrayers).get();
      final kazaMap = <String, int>{
        'Sabah': 0, 'Öğle': 0, 'İkindi': 0, 'Akşam': 0, 'Yatsı': 0, 'Vitir': 0,
      };
      for (final k in kazas) {
        kazaMap[k.prayerType] = k.totalCount.clamp(0, 999999);
      }
      await WidgetSyncService.syncKazaCounts(kazaMap, lastCompletedDate: lastCompletedDate);
    } catch (_) {}
  }

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

    await _syncKazaWidgets(db);
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

    await _syncKazaWidgets(db);
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

      final todayStr = GoldenDayService.getTodayStr();
      if (prayerType != 'Oruç') {
        final prefs = await SharedPreferences.getInstance();
        final curCount = prefs.getInt('TodayKazaCount_$todayStr') ?? 0;
        await prefs.setInt('TodayKazaCount_$todayStr', curCount + 1);
      }

      await _syncKazaWidgets(db, lastCompletedDate: todayStr);
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
