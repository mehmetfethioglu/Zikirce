import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../zikir/providers/zikir_providers.dart';
import '../../gamification/providers/gamification_providers.dart';

/// Modern ve dengeli zikir dağılımı renk paleti
const List<Color> kDistributionPalette = [
  Color(0xFF3B82F6), // Royal Blue
  Color(0xFF10B981), // Emerald
  Color(0xFFF59E0B), // Amber / Gold
  Color(0xFF8B5CF6), // Purple / Violet
  Color(0xFFEC4899), // Pink / Rose
  Color(0xFF06B6D4), // Cyan
  Color(0xFFEF4444), // Coral Red
  Color(0xFF14B8A6), // Teal
  Color(0xFF6366F1), // Indigo
  Color(0xFF84CC16), // Lime
  Color(0xFFF97316), // Orange
  Color(0xFFD946EF), // Fuchsia
  Color(0xFF0EA5E9), // Sky Blue
  Color(0xFFA855F7), // Amethyst
  Color(0xFF22C55E), // Light Green
  Color(0xFFE11D48), // Rose
];

/// Sayıları Türkçe standartlarına uygun kompakt formatlama (1000 -> 1,0K, 1500000 -> 1,5M)
String formatCompactNumber(num number) {
  if (number >= 1000000) {
    final val = number / 1000000.0;
    return '${val.toStringAsFixed(1).replaceAll('.', ',')}M';
  } else if (number >= 1000) {
    final val = number / 1000.0;
    return '${val.toStringAsFixed(1).replaceAll('.', ',')}K';
  }
  return number.toInt().toString();
}

/// Zikir dağılımı grafiği ve listesi için veri modeli
class ZikirDistributionItem {
  final int id;
  final String name;
  final String? arabic;
  final int totalCount;
  final double ratio; // 0.0 - 1.0
  final double percentage; // 0.0 - 100.0
  final Color color;

  const ZikirDistributionItem({
    required this.id,
    required this.name,
    this.arabic,
    required this.totalCount,
    required this.ratio,
    required this.percentage,
    required this.color,
  });

  String get formattedTotal {
    final str = totalCount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// Çekilen zikirlerin dağılım oranlarını hesaplayan reaktif provider
final zikirDistributionProvider = Provider<List<ZikirDistributionItem>>((ref) {
  final zikirsAsync = ref.watch(zikirListStreamProvider);
  return zikirsAsync.when(
    data: (zikirs) {
      final activeZikirs = zikirs.where((z) => z.totalCount > 0).toList()
        ..sort((a, b) => b.totalCount.compareTo(a.totalCount));

      if (activeZikirs.isEmpty) return const [];

      final totalSum = activeZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
      if (totalSum == 0) return const [];

      return List.generate(activeZikirs.length, (index) {
        final z = activeZikirs[index];
        final ratio = z.totalCount / totalSum;
        final percentage = double.parse((ratio * 100).toStringAsFixed(1));
        final color = kDistributionPalette[index % kDistributionPalette.length];

        return ZikirDistributionItem(
          id: z.id,
          name: z.name,
          arabic: z.arabic,
          totalCount: z.totalCount,
          ratio: ratio,
          percentage: percentage,
          color: color,
        );
      });
    },
    loading: () => const [],
    error: (_, __) => const [],
  );
});

/// Yıllık aktivite ısı haritası ve istatistik grafikleri için günlük zikir toplamları stream provider'ı
final dailyZikirContributionProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.zikirLogs).watch().map((logs) {
    final map = <String, int>{};
    for (final log in logs) {
      final dateStr = log.dateStr;
      map[dateStr] = (map[dateStr] ?? 0) + log.count;
    }
    return map;
  }).handleError((error, stackTrace) {
    debugPrint('[dailyZikirContributionProvider] Error loading zikir logs: $error');
    return <String, int>{};
  });
});

// ===========================================================================
// HIZLI İSTATİSTİKLER (QUICK STATS DATA & PROVIDER)
// ===========================================================================

class QuickStatsData {
  final int todayCount;
  final int thisWeekCount;
  final int dailyAverage;
  final int totalCount;
  final int quranTodayCount;
  final int quranTotalCount;

  final String formattedToday;
  final String formattedThisWeek;
  final String formattedDailyAverage;
  final String formattedTotal;
  final String formattedQuranToday;
  final String formattedQuranTotal;

  const QuickStatsData({
    required this.todayCount,
    required this.thisWeekCount,
    required this.dailyAverage,
    required this.totalCount,
    this.quranTodayCount = 0,
    this.quranTotalCount = 0,
    required this.formattedToday,
    required this.formattedThisWeek,
    required this.formattedDailyAverage,
    required this.formattedTotal,
    this.formattedQuranToday = '0',
    this.formattedQuranTotal = '0',
  });
}

final quickStatsProvider = StreamProvider<QuickStatsData>((ref) {
  ref.watch(badgeRefreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final activeSession = ref.watch(activeSessionProvider);
  final streakAsync = ref.watch(userStreakStreamProvider);
  final streak = streakAsync.valueOrNull;
  final zikirsAsync = ref.watch(zikirListStreamProvider);
  final zikirs = zikirsAsync.valueOrNull ?? const [];

  final totalFromZikirs = zikirs.fold<int>(0, (sum, z) => sum + z.totalCount);

  return db.select(db.zikirLogs).watch().asyncMap((logs) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);

    int todaySum = 0;
    int thisWeekSum = 0;
    int totalLogsSum = 0;

    for (final log in logs) {
      totalLogsSum += log.count;
      if (log.dateStr == todayStr) {
        todaySum += log.count;
      }
      if (log.timestamp.isAfter(startOfWeek) || log.timestamp.isAtSameMomentAs(startOfWeek)) {
        thisWeekSum += log.count;
      }
    }

    final effectiveTotal = max(totalFromZikirs, totalLogsSum);
    final totalDays = max(1, streak?.totalDays ?? 1);
    final dailyAvg = effectiveTotal > 0 ? (effectiveTotal / totalDays).round() : 0;

    final isDefault = activeSession.id == UserSession.defaultSessionId;
    final todayKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_${activeSession.id}';
    final totalKey = isDefault ? 'TotalReadQuranPages' : 'TotalReadQuranPages_${activeSession.id}';

    // Calculate today's pages from all hatims
    int todayHatimPages = 0;
    try {
      final hatims = await db.select(db.hatims).get();
      for (final h in hatims) {
        todayHatimPages += prefs.getInt('HatimTodayPages_${h.id}_$todayStr') ?? 0;
      }
    } catch (_) {}

    int rawToday = prefs.getInt(todayKey) ?? prefs.getInt('TodayReadPages_$todayStr') ?? 0;

    // Self-healing: Eski hayalet +5 bug'ı ile şişirilmiş veriyi düzelt ve kaydet
    if (rawToday == todayHatimPages + 5 || (todayHatimPages == 0 && rawToday == 5)) {
      rawToday = todayHatimPages;
      await prefs.setInt(todayKey, todayHatimPages);
      if (!isDefault) {
        await prefs.setInt('TodayReadPages_$todayStr', todayHatimPages);
      }
    } else if (todayHatimPages > rawToday) {
      rawToday = todayHatimPages;
    }

    final quranToday = rawToday;
    final quranTotal = prefs.getInt(totalKey) ??
        prefs.getInt('TotalReadQuranPages') ??
        prefs.getInt('TotalReadPages_All') ??
        prefs.getInt('total_read_pages') ??
        prefs.getInt('TotalReadPages') ??
        0;

    return QuickStatsData(
      todayCount: todaySum,
      thisWeekCount: thisWeekSum,
      dailyAverage: dailyAvg,
      totalCount: effectiveTotal,
      quranTodayCount: quranToday,
      quranTotalCount: quranTotal,
      formattedToday: formatCompactNumber(todaySum),
      formattedThisWeek: formatCompactNumber(thisWeekSum),
      formattedDailyAverage: formatCompactNumber(dailyAvg),
      formattedTotal: formatCompactNumber(effectiveTotal),
      formattedQuranToday: formatCompactNumber(quranToday),
      formattedQuranTotal: formatCompactNumber(quranTotal),
    );
  });
});

// ===========================================================================
// AKTİVİTE TRENDLERİ (ACTIVITY TREND CHART DATA & PROVIDER)
// ===========================================================================

class WeeklyTrendDay {
  final String day;
  final int count;
  final Color color;

  const WeeklyTrendDay({
    required this.day,
    required this.count,
    required this.color,
  });
}

class ActivityTrendData {
  final List<WeeklyTrendDay> weekDays;
  final int monthlyDailyAverage;
  final int yearlyTotal;

  const ActivityTrendData({
    required this.weekDays,
    required this.monthlyDailyAverage,
    required this.yearlyTotal,
  });
}

final activityTrendDataProvider = StreamProvider<ActivityTrendData>((ref) {
  final db = ref.watch(databaseProvider);

  return db.select(db.zikirLogs).watch().map((logs) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    // Day names and colors
    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final dayColors = [
      const Color(0xFF29B6F6),
      const Color(0xFF4CAF50),
      const Color(0xFFFFA726),
      const Color(0xFFAB47BC),
      const Color(0xFFEF5350),
      const Color(0xFF00BCD4),
      const Color(0xFFEC407A),
    ];

    final weekCounts = List<int>.filled(7, 0);
    int monthTotal = 0;
    int yearTotal = 0;

    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    for (final log in logs) {
      if (log.timestamp.isAfter(startOfYear) || log.timestamp.isAtSameMomentAs(startOfYear)) {
        yearTotal += log.count;
      }
      if (log.timestamp.isAfter(startOfMonth) || log.timestamp.isAtSameMomentAs(startOfMonth)) {
        monthTotal += log.count;
      }

      for (int i = 0; i < 7; i++) {
        final targetDate = monday.add(Duration(days: i));
        final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        if (log.dateStr == dateStr) {
          weekCounts[i] += log.count;
        }
      }
    }

    final daysInMonthSoFar = max(1, now.day);
    final monthlyDailyAvg = (monthTotal / daysInMonthSoFar).round();

    final weekDays = List.generate(7, (i) {
      return WeeklyTrendDay(
        day: dayNames[i],
        count: weekCounts[i],
        color: dayColors[i],
      );
    });

    return ActivityTrendData(
      weekDays: weekDays,
      monthlyDailyAverage: monthlyDailyAvg,
      yearlyTotal: yearTotal,
    );
  });
});

// ===========================================================================
// ZİKİR GEÇMİŞİ (DYNAMIC ZIKIR HISTORY ITEM & PROVIDER)
// ===========================================================================

class DynamicZikirHistoryItem {
  final int zikirId;
  final String title;
  final String date;
  final String count;
  final int rawCount;
  final int distinctDays;
  final List<Map<String, dynamic>> dailyDetails;

  const DynamicZikirHistoryItem({
    required this.zikirId,
    required this.title,
    required this.date,
    required this.count,
    required this.rawCount,
    required this.distinctDays,
    required this.dailyDetails,
  });
}

final zikirHistoryListProvider = StreamProvider<List<DynamicZikirHistoryItem>>((ref) {
  final db = ref.watch(databaseProvider);

  return db.select(db.zikirs).watch().asyncMap((allZikirs) async {
    final allLogs = await db.select(db.zikirLogs).get();
    if (allZikirs.isEmpty) return const [];

    final zikirMap = {for (final z in allZikirs) z.id: z};
    final groupedLogs = <int, List<ZikirLog>>{};

    for (final log in allLogs) {
      groupedLogs.putIfAbsent(log.zikirId, () => []).add(log);
    }

    final List<DynamicZikirHistoryItem> historyList = [];
    final now = DateTime.now();

    for (final entry in groupedLogs.entries) {
      final zikir = zikirMap[entry.key];
      if (zikir == null) continue;

      final logs = entry.value;
      final totalAmount = max(zikir.totalCount, logs.fold<int>(0, (s, l) => s + l.count));
      if (totalAmount == 0) continue;

      final distinctDates = logs.map((l) => l.dateStr).toSet();
      final latestLog = logs.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
      
      // Calculate display date string
      String dateText;
      final diffDays = now.difference(latestLog.timestamp).inDays;
      final turkishMonths = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

      if (diffDays == 0) {
        dateText = 'Bugün • ${distinctDates.length} günde';
      } else if (diffDays == 1) {
        dateText = 'Dün • ${distinctDates.length} günde';
      } else {
        final m = turkishMonths[latestLog.timestamp.month];
        final d = latestLog.timestamp.day.toString().padLeft(2, '0');
        dateText = '$d $m • ${distinctDates.length} günde';
      }

      final buffer = StringBuffer();
      final countStr = totalAmount.toString();
      for (int i = 0; i < countStr.length; i++) {
        if (i > 0 && (countStr.length - i) % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(countStr[i]);
      }

      historyList.add(DynamicZikirHistoryItem(
        zikirId: zikir.id,
        title: zikir.name,
        date: dateText,
        count: buffer.toString(),
        rawCount: totalAmount,
        distinctDays: distinctDates.length,
        dailyDetails: [],
      ));
    }

    // Sort by largest rawCount / most active
    historyList.sort((a, b) => b.rawCount.compareTo(a.rawCount));

    return historyList;
  });
});
