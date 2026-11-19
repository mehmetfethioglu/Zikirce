import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../gamification/providers/gamification_providers.dart';
import '../../../../gamification/services/golden_day_service.dart';
import '../../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../providers/dashboard_providers.dart';
import '../daily_goals_sheet.dart';
import '../quick_stats_share_preview_modal.dart';
import '../surprise_chest_dialog.dart';

class BentoDailyZikirCard extends ConsumerWidget {
  const BentoDailyZikirCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighContrast = colors.borderStroke == const Color(0xFFFFFFFF);

    final stats = ref.watch(
      quickStatsProvider.select(
        (a) => (
          todayCount: a.valueOrNull?.todayCount ?? 0,
          formattedToday: a.valueOrNull?.formattedToday ?? '0',
          formattedThisWeek: a.valueOrNull?.formattedThisWeek ?? '0',
          formattedDailyAverage: a.valueOrNull?.formattedDailyAverage ?? '0',
          formattedTotal: a.valueOrNull?.formattedTotal ?? '0',
          formattedQuranToday: a.valueOrNull?.formattedQuranToday ?? '0',
        ),
      ),
    );
    final goalsStatus = ref.watch(
      dailyGoalsStatusProvider.select((a) => a.valueOrNull),
    );
    final totalZikirVal = ref.watch(
      totalZikirCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final userRank = ref.watch(currentUserRankProvider);

    final zikirGoal = max(1, goalsStatus?.zikirGoal ?? 100);
    final progress = (stats.todayCount / zikirGoal).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final isGold = goalsStatus?.isGoldCompleted ?? false;
    final isClaimed = goalsStatus?.isChestClaimed ?? false;

    final surfaceColor = colors.weeklyBg;
    final borderColor = isHighContrast
        ? colors.borderStroke
        : Color.lerp(surfaceColor, colors.accent, isDark ? 0.35 : 0.20)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticService.selectionClick();
          DailyGoalsSheet.show(context);
        },
        onLongPress: () {
          HapticService.selectionClick();
          QuickStatsSharePreviewModal.show(
            context: context,
            todayZikir: stats.formattedToday,
            thisWeekZikir: stats.formattedThisWeek,
            dailyAvgZikir: stats.formattedDailyAverage,
            totalZikir: stats.formattedTotal == '0' && totalZikirVal > 0
                ? formatCompactNumber(totalZikirVal)
                : stats.formattedTotal,
            quranPages: stats.formattedQuranToday,
            rankName: userRank.name,
            rankBadge: userRank.badge,
            initialTheme: ZikirShareThemeData.themeForGoalOrTask(
              category: 'İbadet Karnesi',
            ),
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.hasBoundedHeight;
            final h = constraints.maxHeight;
            final pad = hasBoundedHeight ? (h * 0.12).clamp(10.0, 14.0) : 14.0;
            final numFontSize =
                hasBoundedHeight ? (h * 0.21).clamp(20.0, 24.5) : 24.0;
            final ringSize =
                hasBoundedHeight ? (h * 0.38).clamp(36.0, 44.0) : 44.0;
            final isCompact = hasBoundedHeight && h < 105;

            return Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: hasBoundedHeight
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: isCompact ? 24 : 28,
                        height: isCompact ? 24 : 28,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(
                            alpha: isDark ? 0.24 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: isCompact ? 14 : 16,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.isTurkish ? 'Bugünkü Zikir' : "Today's Dhikr",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                      if (isGold && !isClaimed)
                        _SurpriseChestMiniChip(isTurkish: l10n.isTurkish),
                    ],
                  ),
                  if (!hasBoundedHeight) const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                stats.formattedToday,
                                style: TextStyle(
                                  fontSize: numFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primaryText,
                                  height: 1.05,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 4 : 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: (goalsStatus?.orderedGoals ??
                                      const <DailyGoalItemState?>[
                                        null,
                                        null,
                                        null,
                                        null,
                                        null,
                                      ])
                                  .map((goal) {
                                final Color heartColor;
                                if (goal == null || !goal.isEnabled) {
                                  heartColor =
                                      colors.accent.withValues(alpha: 0.16);
                                } else if (goal.isCompleted) {
                                  heartColor = colors.accent;
                                } else {
                                  heartColor =
                                      colors.accent.withValues(alpha: 0.42);
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2.5),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: isCompact ? 10.5 : 11.5,
                                    color: heartColor,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: isCompact ? 4.5 : 5,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                    colors.accent.withValues(alpha: 0.16),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(colors.accent),
                              ),
                            ),
                            Text(
                              progress >= 1.0 ? '✓' : '%$pct',
                              style: TextStyle(
                                fontSize: isCompact ? 9.5 : 10.5,
                                fontWeight: FontWeight.w800,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SurpriseChestMiniChip extends ConsumerWidget {
  final bool isTurkish;

  const _SurpriseChestMiniChip({required this.isTurkish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticService.selectionClick();
        try {
          final reward = await ref
              .read(gamificationNotifierProvider)
              .openSurpriseChest(isTurkish: isTurkish);
          ref.invalidate(dailyGoalsStatusProvider);
          ref.invalidate(userProfileStreamProvider);
          ref.invalidate(diamondCountProvider);
          ref.invalidate(goldCountProvider);
          ref.invalidate(userStreakStreamProvider);
          if (reward != null && context.mounted) {
            await SurpriseChestDialog.show(context, reward: reward);
            ref.invalidate(dailyGoalsStatusProvider);
            ref.invalidate(userProfileStreamProvider);
            ref.invalidate(diamondCountProvider);
            ref.invalidate(goldCountProvider);
            ref.invalidate(userStreakStreamProvider);
          }
        } catch (e) {
          debugPrint('[BentoDailyZikirCard] openSurpriseChest error: $e');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEAB308).withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEAB308), width: 1),
        ),
        child: const Text('🎁', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
