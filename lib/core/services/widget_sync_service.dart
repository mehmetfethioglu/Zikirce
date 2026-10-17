import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../utils/pref_utils.dart';
import '../utils/hijri_calendar.dart';
import 'backup_service.dart';
import 'prayer_times_service.dart';

class WidgetSyncService {
  static const String appGroupId = 'group.com.akarworks.zikirce';
  static bool _isAppGroupInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isAppGroupInitialized && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HomeWidget.setAppGroupId(appGroupId);
        _isAppGroupInitialized = true;
      } catch (e) {
        if (kDebugMode) {
          print('[WidgetSyncService] setAppGroupId error: $e');
        }
      }
    }
  }

  static const List<String> widgetProviderNames = [
    'PrayerTimesWidgetProvider',
    'PrayerTimesMiniWidgetProvider',
    'PrayerCountdownWidgetProvider',
    'PrayerDigitalClockWidgetProvider',
    'PrayerAnalogClockWidgetProvider',
    'DailyVerseWidgetProvider',
    'PrayerKazaWidgetProvider',
    'KalpSagligiWidgetProvider',
    'ZikirCounterWidgetProvider',
    'PrayerNextWidgetProvider',
    'StreakWidgetProvider',
    'KazaQuickWidgetProvider',
    'PrayerMiniWidgetProvider',
  ];

  static const List<String> iosWidgetKinds = [
    'PrayerTimesWidget',
    'PrayerTimesMiniWidget',
    'PrayerCountdownWidget',
    'PrayerDigitalClockWidget',
    'PrayerAnalogClockWidget',
    'PrayerNextWidget',
    'PrayerMiniWidget',
    'HijriCalendarWidget',
    'PrayerKazaWidget',
    'KazaQuickWidget',
    'KalpSagligiWidget',
    'ZikirCounterWidget',
    'StreakWidget',
  ];

  /// Synchronize prayer times for a city and push to all widgets
  static Future<void> syncPrayerTimes({
    required String city,
    required PrayerTimings timings,
    String? language,
    String? sessionId,
  }) async {
    try {
      await _ensureInitialized();
      final now = DateTime.now();
      final hijri = HijriDate.fromGregorian(now);

      final hDay = (timings.hijriDay != null && timings.hijriDay!.isNotEmpty)
          ? timings.hijriDay!
          : hijri.day.toString();
      final hMonth = (timings.hijriMonth != null && timings.hijriMonth!.isNotEmpty)
          ? HijriDate.translateMonth(timings.hijriMonth!)
          : hijri.monthName;
      final hYear = (timings.hijriYear != null && timings.hijriYear!.isNotEmpty)
          ? timings.hijriYear!
          : hijri.year.toString();

      final jsonMap = {
        'Imsak': timings.fajr,
        'Gunes': timings.sunrise,
        'Ogle': timings.dhuhr,
        'Ikindi': timings.asr,
        'Aksam': timings.maghrib,
        'Yatsi': timings.isha,
        'HijriDay': hDay,
        'HijriMonth': hMonth,
        'HijriYear': hYear,
        'Date': timings.date,
      };

      final jsonStr = jsonEncode(jsonMap);

      // Persist to standard SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final isDefault = sessionId == null || sessionId == 'default_user';
      final sfx = isDefault ? '' : '_$sessionId';

      await prefs.setString('SelectedCity$sfx', city);
      if (isDefault) {
        await prefs.setString('SelectedCity', city);
      }
      await prefs.setString('CachedPrayerTimes_$city', jsonStr);

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await HomeWidget.saveWidgetData<String>('SelectedCity', city);
          await HomeWidget.saveWidgetData<String>('CachedPrayerTimes_$city', jsonStr);
          await HomeWidget.saveWidgetData<String>('PrayerTimesJson', jsonStr);
          if (language != null) {
            await HomeWidget.saveWidgetData<String>('AppLanguage', language);
          }
          await triggerWidgetUpdate();
        } catch (e) {
          if (kDebugMode) {
            print('[WidgetSyncService] HomeWidget channel error: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncPrayerTimes error: $e');
      }
    }
  }

  /// Synchronize dhikr statistics and streak state
  static Future<void> syncDhikrAndStreak({
    int todayDhikr = 0,
    int currentStreak = 0,
    bool isGoldCompleted = false,
    int zikirDailyGoal = 100,
    List<int>? weeklyCounts,
    List<String>? activeDatesInWeek,
  }) async {
    try {
      await _ensureInitialized();
      await HomeWidget.saveWidgetData<int>('TodayZikirCount', todayDhikr);
      await HomeWidget.saveWidgetData<int>('CurrentStreak', currentStreak);
      await HomeWidget.saveWidgetData<bool>('IsTodayGoldCompleted', isGoldCompleted);
      await HomeWidget.saveWidgetData<int>('ZikirDailyGoal', zikirDailyGoal);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('TodayZikirCount', todayDhikr);
      await prefs.setInt('CurrentStreak', currentStreak);
      await prefs.setBool('IsTodayGoldCompleted', isGoldCompleted);
      await prefs.setInt('ZikirDailyGoal', zikirDailyGoal);

      if (weeklyCounts != null && weeklyCounts.isNotEmpty) {
        final weeklyStr = weeklyCounts.join(',');
        await HomeWidget.saveWidgetData<String>('WeeklyDhikrCounts', weeklyStr);
        await prefs.setString('WeeklyDhikrCounts', weeklyStr);
      }

      if (activeDatesInWeek != null) {
        final activeDatesStr = activeDatesInWeek.join(',');
        await HomeWidget.saveWidgetData<String>('ActiveDatesInWeek', activeDatesStr);
        await prefs.setString('ActiveDatesInWeek', activeDatesStr);
      }

      await triggerWidgetUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncDhikrAndStreak error: $e');
      }
    }
  }

  /// Synchronize kaza prayer debts
  static Future<void> syncKazaCounts(
    Map<String, int> kazaCounts, {
    String? lastCompletedDate,
  }) async {
    try {
      await _ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      for (final entry in kazaCounts.entries) {
        final key = 'KazaCount_${entry.key}';
        await HomeWidget.saveWidgetData<int>(key, entry.value);
        await prefs.setInt(key, entry.value);
      }
      if (lastCompletedDate != null && lastCompletedDate.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('KazaLastCompletedDate', lastCompletedDate);
        await prefs.setString('KazaLastCompletedDate', lastCompletedDate);
      }

      await triggerWidgetUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncKazaCounts error: $e');
      }
    }
  }

  /// Synchronize today's fard prayer completion checkmarks
  static Future<void> syncFardTicks(Map<String, bool> fardTicks) async {
    try {
      await _ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      for (final entry in fardTicks.entries) {
        final key = 'TodayFard_${entry.key}';
        await HomeWidget.saveWidgetData<bool>(key, entry.value);
        await prefs.setBool(key, entry.value);
      }

      await triggerWidgetUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncFardTicks error: $e');
      }
    }
  }

  /// Synchronizes full app state from SQLite database and current settings
  static Future<void> syncAll(AppDatabase db, {String? sessionId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDefault = sessionId == null || sessionId == 'default_user';
      final sfx = isDefault ? '' : '_$sessionId';

      final city = PrefUtils.getStringFromKeys(
        prefs,
        ['SelectedCity$sfx', 'AppCity$sfx', 'selected_city$sfx', 'SelectedCity', 'AppCity', 'selected_city'],
        'İstanbul',
      );
      final lang = PrefUtils.getStringFromKeys(
        prefs,
        ['app_language$sfx', 'SelectedLanguage$sfx', 'AppLanguage$sfx', 'app_language', 'SelectedLanguage', 'AppLanguage'],
        'tr',
      );

      // 1. Prayer times
      final timings = await PrayerTimesService.getPrayerTimes(city: city);
      await syncPrayerTimes(city: city, timings: timings, language: lang, sessionId: sessionId);

      // 2. Dhikr & Streak
      final streak = await (db.select(db.userStreaks)..limit(1)).getSingleOrNull();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final todayLogs = await (db.select(db.zikirLogs)..where((t) => t.dateStr.equals(todayStr))).get();
      final todayDhikr = todayLogs.fold<int>(0, (sum, item) => sum + item.count);

      // Calculate last 7 days for the Heart Health curve and active dates
      final weeklyCounts = <int>[];
      final activeDates = <String>[];
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final dStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        final dayLogs = await (db.select(db.zikirLogs)..where((t) => t.dateStr.equals(dStr))).get();
        final daySum = dayLogs.fold<int>(0, (s, l) => s + l.count);
        weeklyCounts.add(daySum);
        if (daySum > 0) {
          activeDates.add(dStr);
        }
      }

      final isGold = PrefUtils.getBool(prefs, 'IsTodayGoldCompleted$sfx', false) || (isDefault && PrefUtils.getBool(prefs, 'IsTodayGoldCompleted', false));
      final dailyGoal = PrefUtils.getIntFromKeys(prefs, ['ZikirDailyGoal$sfx', 'DailyZikirGoal$sfx', 'zikir_daily_goal$sfx', 'ZikirDailyGoal'], 100);

      await syncDhikrAndStreak(
        todayDhikr: todayDhikr,
        currentStreak: streak?.currentStreak ?? 0,
        isGoldCompleted: isGold,
        zikirDailyGoal: dailyGoal,
        weeklyCounts: weeklyCounts,
        activeDatesInWeek: activeDates,
      );

      // 3. Kaza
      final kazas = await db.select(db.kazaPrayers).get();
      final kazaMap = <String, int>{
        'Sabah': 0, 'Öğle': 0, 'İkindi': 0, 'Akşam': 0, 'Yatsı': 0, 'Vitir': 0,
      };
      for (final k in kazas) {
        final remaining = k.totalCount.clamp(0, 999999);
        kazaMap[k.prayerType] = remaining;
      }
      final kazaLastDate = prefs.getString('KazaLastCompletedDate');
      await syncKazaCounts(kazaMap, lastCompletedDate: kazaLastDate);

      // 4. Background auto backup (debounced)
      BackupService.triggerAutoBackupBackground(db, sessionId: sessionId);
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncAll error: $e');
      }
    }
  }

  /// Triggers update broadcast to all registered native widgets
  static Future<void> triggerWidgetUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _ensureInitialized();
      if (Platform.isAndroid) {
        for (final name in widgetProviderNames) {
          await HomeWidget.updateWidget(
            name: name,
            androidName: name,
          );
        }
      } else if (Platform.isIOS) {
        for (final kind in iosWidgetKinds) {
          await HomeWidget.updateWidget(
            name: kind,
            iOSName: kind,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] triggerWidgetUpdate error: $e');
      }
    }
  }
}

