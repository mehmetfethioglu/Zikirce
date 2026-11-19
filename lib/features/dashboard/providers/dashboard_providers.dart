import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../core/database/zikir_seed_data.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import 'package:drift/drift.dart';
import '../../zikir/providers/zikir_providers.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../gamification/services/golden_day_service.dart';
import '../../namaz_vakitleri/providers/prayer_providers.dart';

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
  return db.customSelect(
    'SELECT date_str, COALESCE(SUM(count), 0) as total FROM zikir_logs GROUP BY date_str',
    readsFrom: {db.zikirLogs},
  ).watch().map((rows) {
    final map = <String, int>{};
    for (final row in rows) {
      map[row.read<String>('date_str')] = row.read<int>('total');
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

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(monday.year, monday.month, monday.day);

  return db.customSelect(
    'SELECT '
    'COALESCE(SUM(count), 0) as total_sum, '
    'COALESCE(SUM(CASE WHEN date_str = ? THEN count ELSE 0 END), 0) as today_sum, '
    'COALESCE(SUM(CASE WHEN timestamp >= ? THEN count ELSE 0 END), 0) as week_sum '
    'FROM zikir_logs',
    variables: [
      Variable.withString(todayStr),
      Variable.withDateTime(startOfWeek),
    ],
    readsFrom: {db.zikirLogs},
  ).watchSingle().asyncMap((row) async {
    final prefs = await SharedPreferences.getInstance();

    final totalLogsSum = row.read<int>('total_sum');
    final todaySum = row.read<int>('today_sum');
    final thisWeekSum = row.read<int>('week_sum');

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
    if (todayHatimPages > 0 && rawToday == todayHatimPages + 5) {
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

  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(monday.year, monday.month, monday.day);
  final sunday = startOfWeek.add(const Duration(days: 6));
  final mondayStr = '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
  final sundayStr = '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfYear = DateTime(now.year, 1, 1);

  // Day names and colors
  const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  const dayColors = [
    Color(0xFF29B6F6),
    Color(0xFF4CAF50),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFF00BCD4),
    Color(0xFFEC407A),
  ];

  return db.customSelect(
    'SELECT '
    'COALESCE(SUM(CASE WHEN timestamp >= ? THEN count ELSE 0 END), 0) as year_total, '
    'COALESCE(SUM(CASE WHEN timestamp >= ? THEN count ELSE 0 END), 0) as month_total '
    'FROM zikir_logs',
    variables: [
      Variable.withDateTime(startOfYear),
      Variable.withDateTime(startOfMonth),
    ],
    readsFrom: {db.zikirLogs},
  ).watchSingle().asyncMap((sumsRow) async {
    final yearTotal = sumsRow.read<int>('year_total');
    final monthTotal = sumsRow.read<int>('month_total');

    final weekRows = await db.customSelect(
      'SELECT date_str, COALESCE(SUM(count), 0) as day_sum FROM zikir_logs WHERE date_str >= ? AND date_str <= ? GROUP BY date_str',
      variables: [
        Variable.withString(mondayStr),
        Variable.withString(sundayStr),
      ],
      readsFrom: {db.zikirLogs},
    ).get();

    final weekMap = <String, int>{};
    for (final r in weekRows) {
      weekMap[r.read<String>('date_str')] = r.read<int>('day_sum');
    }

    final weekCounts = List<int>.filled(7, 0);
    for (int i = 0; i < 7; i++) {
      final targetDate = monday.add(Duration(days: i));
      final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      weekCounts[i] = weekMap[dateStr] ?? 0;
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
    if (allZikirs.isEmpty) return const [];

    final summaryRows = await db.customSelect(
      'SELECT zikir_id, '
      'COALESCE(SUM(count), 0) as total_count, '
      'COUNT(DISTINCT date_str) as distinct_days, '
      'MAX(timestamp) as latest_ts '
      'FROM zikir_logs '
      'GROUP BY zikir_id',
      readsFrom: {db.zikirLogs},
    ).get();

    final zikirMap = {for (final z in allZikirs) z.id: z};
    final List<DynamicZikirHistoryItem> historyList = [];
    final now = DateTime.now();
    const turkishMonths = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

    for (final row in summaryRows) {
      final zId = row.read<int>('zikir_id');
      final zikir = zikirMap[zId];
      if (zikir == null) continue;

      final totalLogs = row.read<int>('total_count');
      final distinctDays = row.read<int>('distinct_days');
      final latestTs = row.readNullable<DateTime>('latest_ts') ?? DateTime.now();

      final totalAmount = max(zikir.totalCount, totalLogs);
      if (totalAmount == 0) continue;

      final diffDays = now.difference(latestTs).inDays;
      String dateText;
      if (diffDays == 0) {
        dateText = 'Bugün • $distinctDays günde';
      } else if (diffDays == 1) {
        dateText = 'Dün • $distinctDays günde';
      } else {
        final m = turkishMonths[latestTs.month];
        final d = latestTs.day.toString().padLeft(2, '0');
        dateText = '$d $m • $distinctDays günde';
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
        distinctDays: distinctDays,
        dailyDetails: const [],
      ));
    }

    historyList.sort((a, b) => b.rawCount.compareTo(a.rawCount));
    return historyList;
  });
});

// ===========================================================================
// PROFİL ÖZETİ (DASHBOARD PROFILE SUMMARY)
// ===========================================================================

/// Ana sayfa profil kartında kullanıcı verilerine göre dinamik özet sunar.
class DashboardProfileSummary {
  final String summaryTr;
  final String summaryEn;
  final String formattedToday;
  final String formattedThisWeek;
  final String formattedDailyAverage;
  final String formattedTotal;
  final String formattedQuranToday;
  final String formattedQuranTotal;
  final int currentStreak;
  final bool isGoldCompleted;

  const DashboardProfileSummary({
    required this.summaryTr,
    required this.summaryEn,
    required this.formattedToday,
    required this.formattedThisWeek,
    required this.formattedDailyAverage,
    required this.formattedTotal,
    required this.formattedQuranToday,
    required this.formattedQuranTotal,
    required this.currentStreak,
    required this.isGoldCompleted,
  });
}

/// Kullanıcı istatistiklerinden profil kartı için dinamik özet metni üretir.
DashboardProfileSummary buildDashboardProfileSummary({
  required QuickStatsData quickStats,
  required int currentStreak,
  required int totalZikirFallback,
  DailyGoalsStatus? goalsStatus,
}) {
  final effectiveTotal = max(quickStats.totalCount, totalZikirFallback);
  final formattedTotal = formatCompactNumber(effectiveTotal);
  final isGoldCompleted = goalsStatus?.isGoldCompleted ?? false;
  final todayZikir = max(quickStats.todayCount, goalsStatus?.todayZikirCount ?? 0);
  final todayQuran = max(quickStats.quranTodayCount, goalsStatus?.todayKuranPages ?? 0);
  final completedGoals = goalsStatus?.completedGoalsCount ?? 0;
  final totalActiveGoals = goalsStatus?.totalActiveGoals ?? 0;

  final String summaryTr;
  final String summaryEn;

  if (isGoldCompleted) {
    summaryTr =
        'Altın Gün tamamlandı! $currentStreak günlük serinle bu hafta ${quickStats.formattedThisWeek}, toplamda $formattedTotal zikir birikimine ulaştın.';
    summaryEn =
        'Golden Day completed! With a $currentStreak-day streak, you reached ${quickStats.formattedThisWeek} this week and $formattedTotal total dhikrs.';
  } else if (todayZikir > 0 || todayQuran > 0) {
    final String activityTr;
    final String activityEn;
    if (todayZikir > 0 && todayQuran > 0) {
      activityTr =
          'Bugün ${formatCompactNumber(todayZikir)} zikir ve $todayQuran sayfa Kur’an okudun';
      activityEn =
          'Today you logged ${formatCompactNumber(todayZikir)} dhikrs and $todayQuran Quran pages';
    } else if (todayZikir > 0) {
      activityTr = 'Bugün ${formatCompactNumber(todayZikir)} zikir çektin';
      activityEn = 'Today you completed ${formatCompactNumber(todayZikir)} dhikrs';
    } else {
      activityTr = 'Bugün $todayQuran sayfa Kur’an okudun';
      activityEn = 'Today you read $todayQuran Quran pages';
    }

    if (totalActiveGoals > 0 && completedGoals > 0) {
      summaryTr =
          '$activityTr ve $completedGoals/$totalActiveGoals günlük hedefini tamamladın; bu hafta ${quickStats.formattedThisWeek}, toplamda $formattedTotal zikirdesin.';
      summaryEn =
          '$activityEn and met $completedGoals/$totalActiveGoals daily goals, reaching ${quickStats.formattedThisWeek} this week and $formattedTotal total.';
    } else {
      summaryTr =
          '$activityTr; günlük ${quickStats.formattedDailyAverage} ortalamayla bu hafta ${quickStats.formattedThisWeek}, toplamda $formattedTotal zikre ulaştın.';
      summaryEn =
          '$activityEn; averaging ${quickStats.formattedDailyAverage}/day with ${quickStats.formattedThisWeek} this week and $formattedTotal total dhikrs.';
    }
  } else if (effectiveTotal > 0 || quickStats.quranTotalCount > 0 || currentStreak > 0) {
    if (currentStreak > 0) {
      summaryTr =
          '$currentStreak günlük serin devam ediyor; günlük ${quickStats.formattedDailyAverage} ortalamayla toplam $formattedTotal zikir birikimin bulunuyor.';
      summaryEn =
          'Your $currentStreak-day streak is active with $formattedTotal total dhikrs at a ${quickStats.formattedDailyAverage} daily average.';
    } else {
      summaryTr =
          'Toplamda $formattedTotal zikir birikimin hazır; bugünkü ilk virdinle yeni serini başlatabilirsin.';
      summaryEn =
          'You have $formattedTotal total dhikrs recorded; start a fresh streak with today’s first session.';
    }
  } else {
    summaryTr =
        'Manevi yolculuğun başlıyor; ilk zikrin veya Kur’an okumanla özetin burada canlanacak.';
    summaryEn =
        'Your spiritual journey starts here; log your first dhikr or reading to see live insights.';
  }

  return DashboardProfileSummary(
    summaryTr: summaryTr,
    summaryEn: summaryEn,
    formattedToday: formatCompactNumber(todayZikir),
    formattedThisWeek: quickStats.formattedThisWeek,
    formattedDailyAverage: quickStats.formattedDailyAverage,
    formattedTotal: formattedTotal,
    formattedQuranToday: formatCompactNumber(todayQuran),
    formattedQuranTotal: quickStats.formattedQuranTotal,
    currentStreak: currentStreak,
    isGoldCompleted: isGoldCompleted,
  );
}

final dashboardProfileSummaryProvider = Provider<DashboardProfileSummary>((ref) {
  final quickStats = ref.watch(
        quickStatsProvider.select((a) => a.valueOrNull),
      ) ??
      const QuickStatsData(
        todayCount: 0,
        thisWeekCount: 0,
        dailyAverage: 0,
        totalCount: 0,
        formattedToday: '0',
        formattedThisWeek: '0',
        formattedDailyAverage: '0',
        formattedTotal: '0',
      );
  final currentStreak = ref.watch(
    userStreakStreamProvider.select((a) => a.valueOrNull?.currentStreak ?? 0),
  );
  final goalsStatus = ref.watch(
    dailyGoalsStatusProvider.select((a) => a.valueOrNull),
  );
  final totalZikirFallback = ref.watch(
    totalZikirCountProvider.select((a) => a.valueOrNull ?? 0),
  );

  return buildDashboardProfileSummary(
    quickStats: quickStats,
    currentStreak: currentStreak,
    totalZikirFallback: totalZikirFallback,
    goalsStatus: goalsStatus,
  );
});

// ===========================================================================
// FAVORİ ZİKİRLER KARUSELİ (ÇOKTAN AZA SIRALI)
// ===========================================================================

/// Favori zikirler yatay kaydırılabilir kartı için öğe modeli.
class FavoriteZikirCardItem {
  final int id;
  final String name;
  final String arabic;
  final String category;
  final String virtueSummary;
  final int currentCount;
  final int target;
  final int effectiveTotal;
  final bool isFavorite;
  final bool isActive;
  final bool isPracticed;

  const FavoriteZikirCardItem({
    required this.id,
    required this.name,
    required this.arabic,
    this.category = 'Genel',
    this.virtueSummary = '',
    required this.currentCount,
    required this.target,
    required this.effectiveTotal,
    required this.isFavorite,
    required this.isActive,
    required this.isPracticed,
  });
}

String _extractConciseVirtueSummary(String name, String? arabic) {
  final raw = ZikirSeedData.getVirtueForZikir(name, arabic: arabic);
  if (raw == null) return '';
  var text = raw.split(' — ').first.trim();
  if (text.startsWith('Anlamı:')) {
    text = text.substring('Anlamı:'.length).trim();
  }
  if (text.startsWith('"') && text.endsWith('"') && text.length > 2) {
    text = text.substring(1, text.length - 1).trim();
  }
  return text;
}

/// Çekilen zikirleri çoktan aza sıralar; hiç çekim yoksa seçili ve favori başlangıç zikirlerini döndürür.
List<FavoriteZikirCardItem> buildFavoriteZikirCardItems({
  required List<Zikir> zikirs,
  required Map<int, int> logTotalsByZikirId,
  int? activeZikirId,
}) {
  if (zikirs.isEmpty) return const [];

  final items = zikirs.map((z) {
    final effectiveTotal = max(z.totalCount, logTotalsByZikirId[z.id] ?? 0);
    final isPracticed = effectiveTotal > 0 || z.currentCount > 0;
    return FavoriteZikirCardItem(
      id: z.id,
      name: z.name,
      arabic: z.arabic ?? '',
      category: z.category,
      virtueSummary: _extractConciseVirtueSummary(z.name, z.arabic),
      currentCount: z.currentCount,
      target: max(1, z.target),
      effectiveTotal: effectiveTotal,
      isFavorite: z.isFavorite,
      isActive: activeZikirId != null && z.id == activeZikirId,
      isPracticed: isPracticed,
    );
  }).toList();

  final practiced = items.where((i) => i.isPracticed).toList();
  if (practiced.isNotEmpty) {
    practiced.sort((a, b) {
      final byTotal = b.effectiveTotal.compareTo(a.effectiveTotal);
      if (byTotal != 0) return byTotal;
      final byCurrent = b.currentCount.compareTo(a.currentCount);
      if (byCurrent != 0) return byCurrent;
      return a.id.compareTo(b.id);
    });
    return practiced.take(7).toList();
  }

  items.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    return a.id.compareTo(b.id);
  });
  return items.take(6).toList();
}

final _zikirLogTotalsStreamProvider = StreamProvider<Map<int, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.customSelect(
    'SELECT zikir_id, COALESCE(SUM(count), 0) as log_sum FROM zikir_logs GROUP BY zikir_id',
    readsFrom: {db.zikirLogs},
  ).watch().map((rows) {
    final map = <int, int>{};
    for (final row in rows) {
      map[row.read<int>('zikir_id')] = row.read<int>('log_sum');
    }
    return map;
  }).handleError((Object error, StackTrace stackTrace) {
    debugPrint('[_zikirLogTotalsStreamProvider] Error loading zikir log totals: $error');
    return <int, int>{};
  });
});

final dashboardFavoriteZikirsProvider = Provider<List<FavoriteZikirCardItem>>((ref) {
  final zikirs = ref.watch(
    zikirListStreamProvider.select((a) => a.valueOrNull ?? const <Zikir>[]),
  );
  final logTotals = ref.watch(
    _zikirLogTotalsStreamProvider.select((a) => a.valueOrNull ?? const <int, int>{}),
  );
  final activeId = ref.watch(selectedZikirIdProvider);

  return buildFavoriteZikirCardItems(
    zikirs: zikirs,
    logTotalsByZikirId: logTotals,
    activeZikirId: activeId,
  );
});

// ===========================================================================
// SON 7 GÜN AKTİVİTE TRENDLERİ (ROLLING LAST 7 DAYS)
// ===========================================================================

String _formatDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Son 7 günlük aktivite trend grafiğindeki tek gün noktası.
class Last7DaysPoint {
  final String dateStr;
  final String dayShortTr;
  final String dayShortEn;
  final String dateLabelTr;
  final String dateLabelEn;
  final int count;
  final bool isToday;

  const Last7DaysPoint({
    required this.dateStr,
    required this.dayShortTr,
    required this.dayShortEn,
    required this.dateLabelTr,
    required this.dateLabelEn,
    required this.count,
    required this.isToday,
  });
}

/// Her zaman [bugün - 6 gün .. bugün] aralığını tutan son 7 gün trend özeti.
class Last7DaysTrendData {
  final List<Last7DaysPoint> days;
  final int sevenDayTotal;
  final int dailyAverage;
  final int peakCount;
  final int? trendDeltaPercent;

  const Last7DaysTrendData({
    required this.days,
    required this.sevenDayTotal,
    required this.dailyAverage,
    required this.peakCount,
    required this.trendDeltaPercent,
  });
}

/// Verilen referans tarihinden geriye dönük tam 7 günlük aktivite trendini hesaplar.
Last7DaysTrendData buildLast7DaysTrendData({
  required DateTime anchorDate,
  required Map<String, int> countsByDate,
  Map<String, int> previousWeekCountsByDate = const {},
}) {
  const trDays = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  const enDays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const trMonths = [
    '',
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  const enMonths = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final anchorDay = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
  final days = <Last7DaysPoint>[];
  int sevenDayTotal = 0;
  int peakCount = 0;

  for (int i = 0; i < 7; i++) {
    final target = anchorDay.subtract(Duration(days: 6 - i));
    final key = _formatDateKey(target);
    final count = countsByDate[key] ?? 0;
    sevenDayTotal += count;
    if (count > peakCount) peakCount = count;

    days.add(
      Last7DaysPoint(
        dateStr: key,
        dayShortTr: trDays[target.weekday],
        dayShortEn: enDays[target.weekday],
        dateLabelTr: '${target.day} ${trMonths[target.month]}',
        dateLabelEn: '${enMonths[target.month]} ${target.day}',
        count: count,
        isToday: i == 6,
      ),
    );
  }

  int prevTotal = 0;
  for (int i = 7; i < 14; i++) {
    final prevTarget = anchorDay.subtract(Duration(days: i));
    final prevKey = _formatDateKey(prevTarget);
    prevTotal += previousWeekCountsByDate[prevKey] ?? countsByDate[prevKey] ?? 0;
  }

  final int? deltaPercent = prevTotal > 0
      ? (((sevenDayTotal - prevTotal) / prevTotal) * 100).round()
      : null;

  return Last7DaysTrendData(
    days: days,
    sevenDayTotal: sevenDayTotal,
    dailyAverage: (sevenDayTotal / 7).round(),
    peakCount: max(1, peakCount),
    trendDeltaPercent: deltaPercent,
  );
}

final last7DaysTrendProvider = StreamProvider<Last7DaysTrendData>((ref) {
  final db = ref.watch(databaseProvider);
  ref.watch(currentDateProvider);

  final now = DateTime.now();
  final anchorDay = DateTime(now.year, now.month, now.day);
  final windowStart = anchorDay.subtract(const Duration(days: 13));
  final startKey = _formatDateKey(windowStart);
  final todayKey = _formatDateKey(anchorDay);

  return db.customSelect(
    'SELECT date_str, COALESCE(SUM(count), 0) as day_sum '
    'FROM zikir_logs WHERE date_str >= ? AND date_str <= ? GROUP BY date_str',
    variables: [
      Variable.withString(startKey),
      Variable.withString(todayKey),
    ],
    readsFrom: {db.zikirLogs},
  ).watch().map((rows) {
    final countsByDate = <String, int>{};
    for (final row in rows) {
      countsByDate[row.read<String>('date_str')] = row.read<int>('day_sum');
    }
    return buildLast7DaysTrendData(
      anchorDate: anchorDay,
      countsByDate: countsByDate,
    );
  }).handleError((Object error, StackTrace stackTrace) {
    debugPrint('[last7DaysTrendProvider] Error loading 7-day trend: $error');
    return buildLast7DaysTrendData(
      anchorDate: anchorDay,
      countsByDate: const {},
    );
  });
});
