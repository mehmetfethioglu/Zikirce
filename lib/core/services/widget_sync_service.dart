import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/kuran/data/islamic_bookshelf_models.dart';
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
    'KulliyatWidgetProvider',
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
    'KulliyatWidget',
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

  /// Synchronizes Külliyat bookshelf state, active book reading progress, and annotations to Home Screen Widgets
  static Future<void> syncKulliyatFromPrefs([List<IslamicShelfBook>? currentBooks]) async {
    try {
      await _ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      final defaults = IslamicBookshelfCatalog.defaultBooks();
      final lastMushafPage = prefs.getInt('LastReadPage') ?? 1;
      final lastReadBookId = prefs.getString('zikirce_kulliyat_last_book_id') ?? '';

      List<IslamicShelfBook> books;
      if (currentBooks != null && currentBooks.isNotEmpty) {
        books = currentBooks;
      } else {
        final raw = prefs.getString('zikirce_tahrir_bookshelf_v2') ??
            prefs.getString('zikirce_tahrir_bookshelf_v1');
        if (raw == null || raw.isEmpty) {
          books = defaults.map((b) {
            if (b.id == 'book_mushaf' && lastMushafPage > 1) {
              return b.copyWith(
                currentPage: lastMushafPage.clamp(1, 604),
                hasStartedReading: true,
              );
            }
            return b;
          }).toList();
        } else {
          final decoded = jsonDecode(raw) as List<dynamic>;
          final savedMap = <String, Map<String, dynamic>>{};
          for (final item in decoded) {
            if (item is Map<String, dynamic> && item['id'] is String) {
              savedMap[item['id'] as String] = item;
            }
          }
          books = defaults.map((def) {
            final s = savedMap[def.id];
            if (s == null) return def;
            int curPage = (s['currentPage'] as num?)?.toInt() ?? def.currentPage;
            bool started = (s['hasStartedReading'] as bool?) ?? def.hasStartedReading;
            if (def.id == 'book_mushaf' && lastMushafPage > curPage) {
              curPage = lastMushafPage.clamp(1, 604);
              started = true;
            }
            return def.copyWith(
              sortOrder: (s['sortOrder'] as num?)?.toInt() ?? def.sortOrder,
              isVisible: (s['isVisible'] as bool?) ?? def.isVisible,
              currentPage: curPage.clamp(1, def.totalPages),
              totalPages: def.totalPages,
              hasStartedReading: started,
              paletteIndex: (s['paletteIndex'] as num?)?.toInt() ?? def.paletteIndex,
              coverStyle: (s['coverStyle'] as num?)?.toInt() ?? def.coverStyle,
            );
          }).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
      }

      final visibleBooks = books.where((b) => b.isVisible).toList();
      final effectiveList = visibleBooks.isNotEmpty ? visibleBooks : books;

      // Determine active / last read book
      IslamicShelfBook activeBook = effectiveList.first;
      if (lastReadBookId.isNotEmpty) {
        final match = effectiveList.where((b) => b.id == lastReadBookId);
        if (match.isNotEmpty) {
          activeBook = match.first;
        }
      } else {
        final startedBooks = effectiveList.where((b) => b.hasStartedReading).toList();
        if (startedBooks.isNotEmpty) {
          activeBook = startedBooks.first;
        }
      }

      final startedCount = books.where((b) => b.hasStartedReading).length;
      final totalVisible = effectiveList.length;

      int bookmarksCount = 0;
      int highlightsCount = 0;
      try {
        final rawB = prefs.getString('zikirce_book_bookmarks_v1');
        if (rawB != null && rawB.isNotEmpty) {
          bookmarksCount = (jsonDecode(rawB) as List<dynamic>).length;
        }
        final rawH = prefs.getString('zikirce_book_highlights_v1');
        if (rawH != null && rawH.isNotEmpty) {
          highlightsCount = (jsonDecode(rawH) as List<dynamic>).length;
        }
      } catch (_) {}

      final unitLabel = activeBook.category == IslamicBookCategory.tafseer ? 'Âyet' : 'Sayfa';
      final referenceStr = '$unitLabel ${activeBook.currentPage} / ${activeBook.totalPages}';

      // Build top 6 shelf books JSON for native miniature bookshelf rendering
      final shelfBooksPayload = effectiveList.take(6).map((b) => {
        'id': b.id,
        't': b.shortTitle,
        'a': b.author,
        'c': b.category.label,
        'p': b.currentPage,
        'tp': b.totalPages,
        'pct': b.progressPercent,
        'pal': b.paletteIndex,
        'st': b.hasStartedReading,
      }).toList();
      final shelfJsonStr = jsonEncode(shelfBooksPayload);

      // Persist to SharedPreferences for Android FlutterSharedPreferences direct fallback
      await prefs.setString('KulliyatLastBookId', activeBook.id);
      await prefs.setString('KulliyatLastBookTitle', activeBook.shortTitle);
      await prefs.setString('KulliyatLastBookFullTitle', activeBook.title);
      await prefs.setString('KulliyatLastBookAuthor', activeBook.author);
      await prefs.setString('KulliyatLastBookCategory', activeBook.category.label);
      await prefs.setInt('KulliyatLastBookPage', activeBook.currentPage);
      await prefs.setInt('KulliyatLastBookTotalPages', activeBook.totalPages);
      await prefs.setInt('KulliyatLastBookPercent', activeBook.progressPercent);
      await prefs.setInt('KulliyatLastBookPaletteIndex', activeBook.paletteIndex);
      await prefs.setString('KulliyatLastBookReference', referenceStr);
      await prefs.setInt('KulliyatStartedCount', startedCount);
      await prefs.setInt('KulliyatTotalBooksCount', totalVisible);
      await prefs.setInt('KulliyatBookmarksCount', bookmarksCount);
      await prefs.setInt('KulliyatHighlightsCount', highlightsCount);
      await prefs.setString('KulliyatShelfBooksJson', shelfJsonStr);

      if (Platform.isAndroid || Platform.isIOS) {
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookId', activeBook.id);
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookTitle', activeBook.shortTitle);
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookFullTitle', activeBook.title);
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookAuthor', activeBook.author);
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookCategory', activeBook.category.label);
        await HomeWidget.saveWidgetData<int>('KulliyatLastBookPage', activeBook.currentPage);
        await HomeWidget.saveWidgetData<int>('KulliyatLastBookTotalPages', activeBook.totalPages);
        await HomeWidget.saveWidgetData<int>('KulliyatLastBookPercent', activeBook.progressPercent);
        await HomeWidget.saveWidgetData<int>('KulliyatLastBookPaletteIndex', activeBook.paletteIndex);
        await HomeWidget.saveWidgetData<String>('KulliyatLastBookReference', referenceStr);
        await HomeWidget.saveWidgetData<int>('KulliyatStartedCount', startedCount);
        await HomeWidget.saveWidgetData<int>('KulliyatTotalBooksCount', totalVisible);
        await HomeWidget.saveWidgetData<int>('KulliyatBookmarksCount', bookmarksCount);
        await HomeWidget.saveWidgetData<int>('KulliyatHighlightsCount', highlightsCount);
        await HomeWidget.saveWidgetData<String>('KulliyatShelfBooksJson', shelfJsonStr);
        await triggerWidgetUpdate();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WidgetSyncService] syncKulliyatFromPrefs error: $e');
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

      // 4. Külliyat Bookshelf & Reading Progress
      await syncKulliyatFromPrefs();

      // 5. Background auto backup (debounced)
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

