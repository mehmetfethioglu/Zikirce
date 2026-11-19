import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../kuran/presentation/widgets/add_custom_quran_badge_sheet.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/activity_trend_chart.dart';
import '../widgets/annual_heatmap_widget.dart';
import '../widgets/badge_gallery_cards.dart';
import '../widgets/kaza_tasks_horizontal_list.dart';
import '../widgets/quick_stats_share_preview_modal.dart';
import '../widgets/stats_treasury_summary_card.dart';
import '../widgets/zikir_distribution_donut.dart';
import '../widgets/zikir_distribution_sheet.dart';
import '../widgets/zikir_history_section.dart';

class DetailedStatsScreen extends ConsumerWidget {
  const DetailedStatsScreen({super.key});

  void _showKazaMeltModal(
    BuildContext context,
    WidgetRef ref,
    String prayerName,
    int count,
  ) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderStroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  prayerName == 'Oruç'
                      ? (l10n.isTurkish
                          ? 'Oruç Kazası Telafisi'
                          : 'Missed Fasting Make-up')
                      : (l10n.isTurkish
                          ? '$prayerName Namazı Kaza Telafisi'
                          : '$prayerName Missed Prayer Make-up'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prayerName == 'Oruç'
                      ? (l10n.isTurkish
                          ? 'Mevcut Kaza Borcu: $count Gün'
                          : 'Current Missed Debt: $count Days')
                      : (l10n.isTurkish
                          ? 'Mevcut Kaza Borcu: $count Vakit'
                          : 'Current Missed Debt: $count Times'),
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.secondaryTextAlt,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primaryText,
                          side: BorderSide(color: colors.borderStroke),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(kazaNotifierProvider).adjustKaza(prayerName, 1);
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          prayerName == 'Oruç'
                              ? (l10n.isTurkish ? '+1 Gün Ekle' : '+1 Add Day')
                              : (l10n.isTurkish ? '+1 Kaza Ekle' : '+1 Add Missed'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(kazaNotifierProvider).performKaza(prayerName);
                          Navigator.of(ctx).pop();
                          final message = prayerName == 'Oruç'
                              ? (l10n.isTurkish
                                  ? 'Allah kabul etsin, oruç kazası kaydedildi.'
                                  : 'May Allah accept it, missed fast recorded.')
                              : (l10n.isTurkish
                                  ? '$prayerName kaza namazı kaydedildi.'
                                  : '$prayerName missed prayer recorded.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        child: Text(
                          prayerName == 'Oruç'
                              ? (l10n.isTurkish ? 'Tutuldu (-1)' : 'Fasted (-1)')
                              : (l10n.isTurkish ? 'Kılındı (-1)' : 'Prayed (-1)'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final quickStats = ref.watch(
      quickStatsProvider.select((a) => a.valueOrNull),
    );
    final totalZikirVal = ref.watch(
      totalZikirCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final userRank = ref.watch(currentUserRankProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.primaryText,
        title: Text(
          l10n.isTurkish ? 'Detaylı İstatistikler' : 'Detailed Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.isTurkish ? 'Karneni Paylaş' : 'Share Summary',
            onPressed: () {
              HapticService.selectionClick();
              QuickStatsSharePreviewModal.show(
                context: context,
                todayZikir: quickStats?.formattedToday ?? '0',
                thisWeekZikir: quickStats?.formattedThisWeek ?? '0',
                dailyAvgZikir: quickStats?.formattedDailyAverage ?? '0',
                totalZikir: quickStats?.formattedTotal ??
                    formatCompactNumber(totalZikirVal),
                quranPages: quickStats?.formattedQuranToday ?? '0',
                rankName: userRank.name,
                rankBadge: userRank.badge,
                initialTheme: ZikirShareThemeData.themeForGoalOrTask(
                  category: 'İbadet Karnesi',
                ),
              );
            },
            icon: Icon(Icons.share_rounded, color: colors.accent),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            const StatsTreasurySummaryCard(),
            const SizedBox(height: 16),
            const ActivityTrendChart(),
            const SizedBox(height: 16),
            ZikirDistributionDonut(
              onTap: () => ZikirDistributionSheet.show(context),
            ),
            const SizedBox(height: 16),
            KazaTasksHorizontalList(
              onTaskTap: (prayer, count) =>
                  _showKazaMeltModal(context, ref, prayer, count),
            ),
            const SizedBox(height: 16),
            const AnnualHeatmapWidget(),
            const SizedBox(height: 16),
            BadgeGalleryCards(
              onAddQuranBadge: () => AddCustomQuranBadgeSheet.show(context),
            ),
            const SizedBox(height: 20),
            const ZikirHistorySection(),
          ],
        ),
      ),
    );
  }
}
