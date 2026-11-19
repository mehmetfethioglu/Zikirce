import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../providers/dashboard_providers.dart';
import 'quick_stats_share_preview_modal.dart';

class StatsTreasurySummaryCard extends ConsumerWidget {
  const StatsTreasurySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final streakFallback = ref.watch(
      userStreakStreamProvider.select(
        (a) => (
          freezeCount: a.valueOrNull?.freezeCount ?? 2,
          xp: a.valueOrNull?.xp ?? 0,
        ),
      ),
    );
    final diamondsCount = ref.watch(
      diamondCountProvider.select((a) => a.valueOrNull ?? streakFallback.freezeCount),
    );
    final goldCount = ref.watch(
      goldCountProvider.select((a) => a.valueOrNull ?? streakFallback.xp),
    );
    final totalZikirVal = ref.watch(
      totalZikirCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final quickStats = ref.watch(
      quickStatsProvider.select((a) => a.valueOrNull),
    );
    final userRank = ref.watch(currentUserRankProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TreasuryPill(
                emoji: '💎',
                value: '$diamondsCount',
                bgColor: const Color(0xFFE0F2FE),
                borderColor: const Color(0xFFBAE6FD),
                textColor: const Color(0xFF0284C7),
                showAddIcon: true,
                onTap: () {
                  HapticService.selectionClick();
                  GoldDiamondExchangeSheet.show(context);
                },
              ),
              const SizedBox(width: 8),
              _TreasuryPill(
                emoji: '🪙',
                value: '$goldCount',
                bgColor: const Color(0xFFFEF3C7),
                borderColor: const Color(0xFFFDE68A),
                textColor: const Color(0xFFD97706),
                showAddIcon: false,
                onTap: () {
                  HapticService.selectionClick();
                  GoldDiamondExchangeSheet.show(context);
                },
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${l10n.bismillahTotal} ${formatCompactNumber(totalZikirVal)} ${l10n.bismillahZikirs}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.borderStroke),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.bismillahQuickStats,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
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
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    size: 16,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickStatTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  iconBg: const Color(0xFFE8F5E9),
                  title: l10n.bismillahToday,
                  value: quickStats?.formattedToday ?? '0',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickStatTile(
                  icon: Icons.date_range_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  title: l10n.bismillahThisWeek,
                  value: quickStats?.formattedThisWeek ?? '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickStatTile(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFEF3C7),
                  title: l10n.bismillahDailyAverage,
                  value: quickStats?.formattedDailyAverage ?? '0',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickStatTile(
                  icon: Icons.all_inclusive_rounded,
                  iconColor: const Color(0xFF9333EA),
                  iconBg: const Color(0xFFF3E8FF),
                  title: l10n.bismillahTotal,
                  value: quickStats?.formattedTotal ??
                      formatCompactNumber(totalZikirVal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _QuickStatTile(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBg: const Color(0xFFCCFBF1),
            title: l10n.bismillahQuranReading,
            value:
                '${quickStats?.formattedQuranToday ?? "0"} ${l10n.bismillahPages}',
          ),
        ],
      ),
    );
  }
}

class _TreasuryPill extends StatelessWidget {
  final String emoji;
  final String value;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final bool showAddIcon;
  final VoidCallback onTap;

  const _TreasuryPill({
    required this.emoji,
    required this.value,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.showAddIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (showAddIcon) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.add_circle_outline_rounded,
                size: 12,
                color: textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;

  const _QuickStatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderStroke.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.secondaryTextAlt,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
