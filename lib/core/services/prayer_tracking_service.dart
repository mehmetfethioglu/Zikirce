import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'local_notification_service.dart';
import 'prayer_times_service.dart';
import 'widget_sync_service.dart';

class TodayPrayerStatusItem {
  final String prayerName;
  final bool isCompleted;
  final int kazaCount;
  final String icon;
  final String badgeColorHex;

  const TodayPrayerStatusItem({
    required this.prayerName,
    required this.isCompleted,
    required this.kazaCount,
    required this.icon,
    required this.badgeColorHex,
  });
}

class PastUnansweredDay {
  final String dateStr;
  final DateTime date;
  final String formattedDate;
  final List<String> unansweredPrayers;

  const PastUnansweredDay({
    required this.dateStr,
    required this.date,
    required this.formattedDate,
    required this.unansweredPrayers,
  });
}

class PastDaysCheckResult {
  final List<PastUnansweredDay> recentDays;
  final List<String> olderDates;

  const PastDaysCheckResult({
    required this.recentDays,
    required this.olderDates,
  });

  bool get hasAny => recentDays.isNotEmpty || olderDates.isNotEmpty;
  bool get hasRecent => recentDays.isNotEmpty;
  bool get hasOlder => olderDates.isNotEmpty;
}

class PrayerTrackingService {
  static const List<String> fardPrayers = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  static const Map<String, (String icon, String color)> prayerMeta = {
    'Sabah': ('🌙', '#C1D9F9'),
    'Öğle': ('☀️', '#F7D6A7'),
    'İkindi': ('🌤️', '#F3B29B'),
    'Akşam': ('🌆', '#D0C4DF'),
    'Yatsı': ('🌃', '#E1C5ED'),
  };

  static Future<String> _getSavedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('SelectedCity') ??
          prefs.getString('AppCity') ??
          prefs.getString('selected_city') ??
          'İstanbul';
    } catch (_) {
      return 'İstanbul';
    }
  }

  /// Checks whether the prescribed time for [prayerName] has entered today as of [date/now].
  static bool isPrayerTimeEntered(
    String prayerName,
    PrayerTimings? timings, [
    DateTime? date,
  ]) {
    final now = date ?? DateTime.now();
    final effectiveTimings =
        timings ?? PrayerTimesService.calculateOfflinePrayerTimes('İstanbul', now);

    String hhmm;
    switch (prayerName) {
      case 'Sabah':
        hhmm = effectiveTimings.fajr;
        break;
      case 'Öğle':
        hhmm = effectiveTimings.dhuhr;
        break;
      case 'İkindi':
        hhmm = effectiveTimings.asr;
        break;
      case 'Akşam':
        hhmm = effectiveTimings.maghrib;
        break;
      case 'Yatsı':
        hhmm = effectiveTimings.isha;
        break;
      default:
        return true;
    }

    final clean = hhmm.trim().split(' ').first;
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        final prayerDateTime = DateTime(now.year, now.month, now.day, h, m);
        return !now.isBefore(prayerDateTime);
      }
    }

    switch (prayerName) {
      case 'Sabah':
        return now.hour >= 5;
      case 'Öğle':
        return now.hour >= 13;
      case 'İkindi':
        return now.hour >= 16;
      case 'Akşam':
        return now.hour >= 19;
      case 'Yatsı':
        return now.hour >= 21;
      default:
        return true;
    }
  }

  /// Returns the list of fard prayers whose time has entered (arrived) today up to [date/now]
  static Future<List<String>> getDuePrayersForToday([DateTime? date]) async {
    final now = date ?? DateTime.now();
    try {
      final city = await _getSavedCity();
      final timings = await PrayerTimesService.getPrayerTimes(city: city);
      return fardPrayers
          .where((p) => isPrayerTimeEntered(p, timings, now))
          .toList();
    } catch (_) {
      return fardPrayers
          .where((p) => isPrayerTimeEntered(p, null, now))
          .toList();
    }
  }

  /// Gets the current prayer answer for a given date and prayer name (true = Evet, false = Hayır, null = Unanswered)
  static Future<bool?> getPrayerAnswer(
    AppDatabase db,
    String dateStr,
    String prayerName,
  ) async {
    try {
      final row = await (db.select(db.prayerAnswerLogs)
            ..where((t) => t.dateStr.equals(dateStr) & t.prayerType.equals(prayerName)))
          .getSingleOrNull();
      return row?.isPerformed;
    } catch (e) {
      debugPrint('[PrayerTrackingService] getPrayerAnswer error: $e');
      return null;
    }
  }

  /// Logs prayer answer into PrayerAnswerLogs table
  static Future<void> logPrayerAnswer(
    AppDatabase db,
    String dateStr,
    String prayerName,
    bool isPerformed,
  ) async {
    try {
      final existing = await (db.select(db.prayerAnswerLogs)
            ..where((t) => t.dateStr.equals(dateStr) & t.prayerType.equals(prayerName)))
          .getSingleOrNull();

      if (existing != null) {
        await (db.update(db.prayerAnswerLogs)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          PrayerAnswerLogsCompanion(
            isPerformed: Value(isPerformed),
          ),
        );
      } else {
        await db.into(db.prayerAnswerLogs).insert(
              PrayerAnswerLogsCompanion.insert(
                prayerType: prayerName,
                dateStr: dateStr,
                isPerformed: isPerformed,
              ),
            );
      }
    } catch (e) {
      debugPrint('[PrayerTrackingService] logPrayerAnswer error: $e');
    }
  }

  /// Increments or decrements Kaza count in KazaPrayers table
  static Future<void> adjustKazaCount(
    AppDatabase db,
    String prayerName,
    int delta,
  ) async {
    try {
      final row = await (db.select(db.kazaPrayers)
            ..where((t) => t.prayerType.equals(prayerName)))
          .getSingleOrNull();

      if (row != null) {
        final newTotal = (row.totalCount + delta).clamp(0, 999999);
        await (db.update(db.kazaPrayers)
              ..where((t) => t.prayerType.equals(prayerName)))
            .write(
          KazaPrayersCompanion(
            totalCount: Value(newTotal),
          ),
        );
      } else {
        await db.into(db.kazaPrayers).insert(
              KazaPrayersCompanion.insert(
                prayerType: prayerName,
                totalCount: Value(delta.clamp(0, 999999)),
              ),
            );
      }
    } catch (e) {
      debugPrint('[PrayerTrackingService] adjustKazaCount error: $e');
    }
  }

  /// Handles user answer to a pending prayer question (from popup or notification)
  static Future<void> answerPrayerQuestion(
    AppDatabase db,
    String dateStr,
    String prayerName,
    bool answeredYes,
  ) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (dateStr == todayStr && answeredYes) {
        final city = await _getSavedCity();
        final timings = await PrayerTimesService.getPrayerTimes(city: city);
        if (!isPrayerTimeEntered(prayerName, timings, now)) {
          return;
        }
      }

      final previousAnswer = await getPrayerAnswer(db, dateStr, prayerName);

      if (answeredYes) {
        await logPrayerAnswer(db, dateStr, prayerName, true);
        if (previousAnswer == false) {
          // If previously marked as missed (Hayır), decrement kaza debt
          await adjustKazaCount(db, prayerName, -1);
        }
        try { await LocalNotificationService.cancelTodayQuestionNotification(prayerName); } catch (_) {}
      } else {
        if (previousAnswer != false) {
          await logPrayerAnswer(db, dateStr, prayerName, false);
          // Increment kaza debt
          await adjustKazaCount(db, prayerName, 1);
        }
      }

      await _syncHomeWidgets(db);
    } catch (e) {
      debugPrint('[PrayerTrackingService] answerPrayerQuestion error: $e');
    }
  }

  /// Toggles today's prayer completion state (from Today's Prayers Card)
  /// Returns whether a celebration reward was triggered (e.g. 5/5 complete)
  static Future<bool> toggleTodayPrayer(
    AppDatabase db,
    String prayerName,
  ) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final city = await _getSavedCity();
      final timings = await PrayerTimesService.getPrayerTimes(city: city);
      final timeEntered = isPrayerTimeEntered(prayerName, timings, now);
      final previousAnswer = await getPrayerAnswer(db, todayStr, prayerName);

      // Vakti henüz girmeyen namaz kılındı olarak işaretlenemez
      if (!timeEntered) {
        if (previousAnswer == true) {
          await (db.delete(db.prayerAnswerLogs)
                ..where((t) =>
                    t.dateStr.equals(todayStr) & t.prayerType.equals(prayerName)))
              .go();
          await _syncHomeWidgets(db);
        }
        return false;
      }

      if (previousAnswer == true) {
        // Unmarking today's completed prayer -> Mark as Hayır and increment debt
        await logPrayerAnswer(db, todayStr, prayerName, false);
        await adjustKazaCount(db, prayerName, 1);
      } else {
        // Marking as completed -> Mark as Evet
        await logPrayerAnswer(db, todayStr, prayerName, true);
        if (previousAnswer == false) {
          await adjustKazaCount(db, prayerName, -1);
        }
        try { await LocalNotificationService.cancelTodayQuestionNotification(prayerName); } catch (_) {}
      }

      await _syncHomeWidgets(db);

      // Check if 5/5 completed
      final statuses = await getTodayPrayerStatuses(db, todayStr);
      final completedCount = statuses.where((s) => s.isCompleted).length;

      if (completedCount == 5) {
        final prefs = await SharedPreferences.getInstance();
        final bonusKey = 'FardStreakBonusClaimed_$todayStr';
        if (!(prefs.getBool(bonusKey) ?? false)) {
          await prefs.setBool(bonusKey, true);
          final currentDiamonds = prefs.getInt('DiamondCount') ?? 0;
          await prefs.setInt('DiamondCount', currentDiamonds + 1);
          return true; // 1 Diamond awarded!
        }
      }

      return false;
    } catch (e) {
      debugPrint('[PrayerTrackingService] toggleTodayPrayer error: $e');
      return false;
    }
  }

  /// Returns list of TodayPrayerStatusItem for the 5 fard prayers
  static Future<List<TodayPrayerStatusItem>> getTodayPrayerStatuses(
    AppDatabase db, [
    String? dateStr,
  ]) async {
    try {
      final now = DateTime.now();
      final actualTodayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final today = dateStr ?? actualTodayStr;
      final isCheckingToday = today == actualTodayStr;

      PrayerTimings? timings;
      if (isCheckingToday) {
        try {
          final city = await _getSavedCity();
          timings = await PrayerTimesService.getPrayerTimes(city: city);
        } catch (_) {}
      }

      final logs = await (db.select(db.prayerAnswerLogs)..where((t) => t.dateStr.equals(today))).get();
      final answerMap = {for (final l in logs) l.prayerType: l.isPerformed};

      final kazaList = await db.select(db.kazaPrayers).get();
      final kazaMap = {for (final k in kazaList) k.prayerType: k.totalCount};

      final result = <TodayPrayerStatusItem>[];
      for (final prayer in fardPrayers) {
        final meta = prayerMeta[prayer] ?? ('🕌', '#D4A574');
        final timeEntered = !isCheckingToday || isPrayerTimeEntered(prayer, timings, now);

        // Vakti henüz girmemiş bir namaz daha önce yanlışlıkla kılındı işaretlendiyse temizle
        if (!timeEntered && answerMap[prayer] == true) {
          try {
            await (db.delete(db.prayerAnswerLogs)
                  ..where((t) =>
                      t.dateStr.equals(today) & t.prayerType.equals(prayer)))
                .go();
          } catch (_) {}
        }

        result.add(
          TodayPrayerStatusItem(
            prayerName: prayer,
            isCompleted: timeEntered && (answerMap[prayer] == true),
            kazaCount: kazaMap[prayer] ?? 0,
            icon: meta.$1,
            badgeColorHex: meta.$2,
          ),
        );
      }
      return result;
    } catch (e) {
      debugPrint('[PrayerTrackingService] getTodayPrayerStatuses error: $e');
      return [];
    }
  }

  static String _turkishMonth(int month) {
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }

  /// Retrieves past days that have unanswered fard prayers.
  /// Splits into `recentDays` (within last 3 days) and `olderDates` (> 3 days ago).
  static Future<PastDaysCheckResult> getPastUnansweredDays(AppDatabase db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastProcessedStr = prefs.getString('LastProcessedKazaDate');

      DateTime startDate;
      if (lastProcessedStr != null && lastProcessedStr.isNotEmpty) {
        final parsed = DateTime.tryParse(lastProcessedStr);
        if (parsed != null) {
          startDate = DateTime(parsed.year, parsed.month, parsed.day).add(const Duration(days: 1));
        } else {
          startDate = today.subtract(const Duration(days: 7));
        }
      } else {
        startDate = today.subtract(const Duration(days: 7));
      }

      // If startDate is not before today, nothing past to check
      if (!startDate.isBefore(today)) {
        return const PastDaysCheckResult(recentDays: [], olderDates: []);
      }

      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final recentDays = <PastUnansweredDay>[];
      final olderDates = <String>[];

      var checkDate = startDate;
      while (checkDate.isBefore(today)) {
        final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

        // Find which fard prayers are unanswered for this date
        final unansweredList = <String>[];
        for (final prayer in fardPrayers) {
          final answer = await getPrayerAnswer(db, dateStr, prayer);
          if (answer == null) {
            unansweredList.add(prayer);
          }
        }

        if (unansweredList.isNotEmpty) {
          if (checkDate.isBefore(threeDaysAgo)) {
            olderDates.add(dateStr);
          } else {
            final diffDays = today.difference(checkDate).inDays;
            String formatted;
            final mName = _turkishMonth(checkDate.month);
            if (diffDays == 1) {
              formatted = 'Dün (${checkDate.day} $mName)';
            } else if (diffDays == 2) {
              formatted = '2 Gün Önce (${checkDate.day} $mName)';
            } else if (diffDays == 3) {
              formatted = '3 Gün Önce (${checkDate.day} $mName)';
            } else {
              formatted = '${checkDate.day} $mName ${checkDate.year}';
            }

            recentDays.add(
              PastUnansweredDay(
                dateStr: dateStr,
                date: checkDate,
                formattedDate: formatted,
                unansweredPrayers: unansweredList,
              ),
            );
          }
        }

        checkDate = checkDate.add(const Duration(days: 1));
      }

      return PastDaysCheckResult(
        recentDays: recentDays,
        olderDates: olderDates,
      );
    } catch (e) {
      debugPrint('[PrayerTrackingService] getPastUnansweredDays error: $e');
      return const PastDaysCheckResult(recentDays: [], olderDates: []);
    }
  }

  /// Saves user confirmation for a past day's unanswered prayers.
  /// Performed prayers (true) are marked without debt.
  /// Missed prayers (false) are marked as missed and increment kaza debt (+1).
  static Future<void> savePastDayPrayerAnswers(
    AppDatabase db,
    String dateStr,
    Map<String, bool> answers,
  ) async {
    try {
      for (final entry in answers.entries) {
        final prayer = entry.key;
        final performed = entry.value;
        await logPrayerAnswer(db, dateStr, prayer, performed);
        if (!performed) {
          await adjustKazaCount(db, prayer, 1);
        }
      }

      await _updateLastProcessedDateIfApplicable(db);
      await _syncHomeWidgets(db);
    } catch (e) {
      debugPrint('[PrayerTrackingService] savePastDayPrayerAnswers error: $e');
    }
  }

  /// Resolves older days (>3 days ago) as completed with 0 kaza debt (when user rejects bulk kaza prompt).
  static Future<void> resolveOlderDaysAsCompleted(
    AppDatabase db,
    List<String> olderDates,
  ) async {
    try {
      for (final dateStr in olderDates) {
        for (final prayer in fardPrayers) {
          final ans = await getPrayerAnswer(db, dateStr, prayer);
          if (ans == null) {
            await logPrayerAnswer(db, dateStr, prayer, true);
          }
        }
      }

      await _updateLastProcessedDateIfApplicable(db);
      await _syncHomeWidgets(db);
    } catch (e) {
      debugPrint('[PrayerTrackingService] resolveOlderDaysAsCompleted error: $e');
    }
  }

  /// Applies bulk kaza debt increments for older days (>3 days ago) and marks logs as performed.
  static Future<void> applyBulkKazaForOlderDays(
    AppDatabase db,
    List<String> olderDates,
    Map<String, int> kazaDeltas,
  ) async {
    try {
      for (final entry in kazaDeltas.entries) {
        if (entry.value > 0) {
          await adjustKazaCount(db, entry.key, entry.value);
        }
      }

      for (final dateStr in olderDates) {
        for (final prayer in fardPrayers) {
          final ans = await getPrayerAnswer(db, dateStr, prayer);
          if (ans == null) {
            await logPrayerAnswer(db, dateStr, prayer, true);
          }
        }
      }

      await _updateLastProcessedDateIfApplicable(db);
      await _syncHomeWidgets(db);
    } catch (e) {
      debugPrint('[PrayerTrackingService] applyBulkKazaForOlderDays error: $e');
    }
  }

  /// Updates LastProcessedKazaDate if earlier days are now processed
  static Future<void> _updateLastProcessedDateIfApplicable(AppDatabase db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkResult = await getPastUnansweredDays(db);

      if (!checkResult.hasAny) {
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        await prefs.setString('LastProcessedKazaDate', yesterdayStr);
      } else {
        // If there are still unanswered days, set LastProcessedKazaDate to day before the earliest unanswered
        DateTime earliestDate = today;
        if (checkResult.olderDates.isNotEmpty) {
          final parsed = DateTime.tryParse(checkResult.olderDates.first);
          if (parsed != null && parsed.isBefore(earliestDate)) {
            earliestDate = parsed;
          }
        }
        if (checkResult.recentDays.isNotEmpty) {
          final parsed = checkResult.recentDays.first.date;
          if (parsed.isBefore(earliestDate)) {
            earliestDate = parsed;
          }
        }

        final priorDay = earliestDate.subtract(const Duration(days: 1));
        final priorStr = '${priorDay.year}-${priorDay.month.toString().padLeft(2, '0')}-${priorDay.day.toString().padLeft(2, '0')}';
        await prefs.setString('LastProcessedKazaDate', priorStr);
      }
    } catch (e) {
      debugPrint('[PrayerTrackingService] _updateLastProcessedDateIfApplicable error: $e');
    }
  }

  /// Checks if there is an unanswered fard prayer whose notification threshold has passed today.
  /// Exactly mirrors .NET MAUI `CheckAndPromptUnansweredPrayersAsync`
  /// Thresholds:
  /// - Sabah: Güneş - 45 dk
  /// - Öğle: İkindi - 45 dk
  /// - İkindi: Akşam - 45 dk
  /// - Akşam: Yatsı - 45 dk
  /// - Yatsı: Yatsı + 1 saat
  static Future<({String prayerName, String dateStr})?> checkUnansweredPrayerForToday(
    AppDatabase db,
    PrayerTimings timings,
  ) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      DateTime parseTime(String hhmm) {
        final parts = hhmm.split(':');
        if (parts.length < 2) return DateTime.fromMillisecondsSinceEpoch(0);
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return DateTime(now.year, now.month, now.day, h, m);
      }

      final tSunrise = parseTime(timings.sunrise);
      final tAsr = parseTime(timings.asr);
      final tMaghrib = parseTime(timings.maghrib);
      final tIsha = parseTime(timings.isha);

      final prayerChecks = [
        (prayerName: 'Sabah', checkTime: tSunrise.subtract(const Duration(minutes: 45))),
        (prayerName: 'Öğle', checkTime: tAsr.subtract(const Duration(minutes: 45))),
        (prayerName: 'İkindi', checkTime: tMaghrib.subtract(const Duration(minutes: 45))),
        (prayerName: 'Akşam', checkTime: tIsha.subtract(const Duration(minutes: 45))),
        (prayerName: 'Yatsı', checkTime: tIsha.add(const Duration(hours: 1))),
      ];

      final prefs = await SharedPreferences.getInstance();

      for (final pc in prayerChecks) {
        // Skip if threshold has not passed yet
        if (now.isBefore(pc.checkTime)) continue;

        // Check if notification is enabled for this prayer
        final isEnabled = prefs.getBool('${pc.prayerName}NotificationEnabled') ?? true;
        if (!isEnabled) continue;

        final answer = await getPrayerAnswer(db, todayStr, pc.prayerName);
        if (answer == null) {
          // Found first unanswered prayer!
          return (prayerName: pc.prayerName, dateStr: todayStr);
        }
      }

      return null;
    } catch (e) {
      debugPrint('[PrayerTrackingService] checkUnansweredPrayerForToday error: $e');
      return null;
    }
  }

  /// Calculates current streak and longest streak of days where all 5 fard prayers were completed.
  static Future<({int currentStreak, int longestStreak})> calculateNamazStreak(
    AppDatabase db,
  ) async {
    try {
      final logs = await db.select(db.prayerAnswerLogs).get();
      final completedDates = <DateTime>{};

      final dateGrouped = <String, int>{};
      for (final l in logs) {
        if (l.isPerformed && fardPrayers.contains(l.prayerType)) {
          dateGrouped[l.dateStr] = (dateGrouped[l.dateStr] ?? 0) + 1;
        }
      }

      for (final entry in dateGrouped.entries) {
        if (entry.value >= 5) {
          final parsed = DateTime.tryParse(entry.key);
          if (parsed != null) {
            completedDates.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }

      if (completedDates.isEmpty) {
        return (currentStreak: 0, longestStreak: 0);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int currentStreak = 0;
      DateTime? checkDate;

      if (completedDates.contains(today)) {
        checkDate = today;
      } else if (completedDates.contains(today.subtract(const Duration(days: 1)))) {
        checkDate = today.subtract(const Duration(days: 1));
      }

      if (checkDate != null) {
        while (completedDates.contains(checkDate!)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }

      final sortedDates = completedDates.toList()..sort();
      int longestStreak = 1;
      int tempStreak = 1;

      for (int i = 1; i < sortedDates.length; i++) {
        if (sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) {
          tempStreak++;
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
        } else {
          tempStreak = 1;
        }
      }

      return (currentStreak: currentStreak, longestStreak: longestStreak);
    } catch (e) {
      debugPrint('[PrayerTrackingService] calculateNamazStreak error: $e');
      return (currentStreak: 0, longestStreak: 0);
    }
  }

  static Future<void> _syncHomeWidgets(AppDatabase db) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final statuses = await getTodayPrayerStatuses(db, todayStr);
      final fardTicks = {for (final s in statuses) s.prayerName: s.isCompleted};
      final kazaCounts = {for (final s in statuses) s.prayerName: s.kazaCount};

      await WidgetSyncService.syncKazaCounts(kazaCounts);
      await WidgetSyncService.syncFardTicks(fardTicks);
    } catch (e) {
      debugPrint('[PrayerTrackingService] _syncHomeWidgets error: $e');
    }
  }
}
