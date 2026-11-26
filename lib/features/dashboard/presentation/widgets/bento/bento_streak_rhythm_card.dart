import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../gamification/presentation/screens/streak_details_screen.dart';
import '../../../../gamification/providers/gamification_providers.dart';
import '../../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../providers/dashboard_providers.dart';
import '../streak_share_preview_modal.dart';

class BentoStreakRhythmCard extends ConsumerWidget {
  const BentoStreakRhythmCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighContrast = colors.borderStroke == const Color(0xFFFFFFFF);

    final streak = ref.watch(
      userStreakStreamProvider.select(
        (a) => (
          current: a.valueOrNull?.currentStreak ?? 0,
          best: a.valueOrNull?.bestStreak ?? 0,
          totalDays: a.valueOrNull?.totalDays ?? 0,
        ),
      ),
    );
    final isGoldCompleted = ref.watch(
      dailyGoalsStatusProvider.select((a) => a.valueOrNull?.isGoldCompleted ?? false),
    );
    final weekDays = ref.watch(
      activityTrendDataProvider.select((a) => a.valueOrNull?.weekDays),
    );
    final userRank = ref.watch(currentUserRankProvider);

    final warmAccent = isHighContrast
        ? colors.accent
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final surfaceColor = colors.dailyBg;
    final borderColor = isHighContrast
        ? colors.borderStroke
        : Color.lerp(surfaceColor, warmAccent, isDark ? 0.35 : 0.22)!;

    final cardTitle = l10n.isTurkish ? 'Gün Serisi' : 'Day Streak';

    return Semantics(
      label: cardTitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticService.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StreakDetailsScreen()),
            );
          },
          onLongPress: () {
            HapticService.selectionClick();
            StreakSharePreviewModal.show(
              context,
              currentStreak: streak.current,
              bestStreak: streak.best,
              totalDays: streak.totalDays,
              rankName: userRank.name,
              rankBadge: userRank.badge,
              isGoldCompleted: isGoldCompleted,
              initialTheme: ZikirShareThemeData.themeForGoalOrTask(
                goalType: 'streak',
                isGold: isGoldCompleted,
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasBoundedHeight = constraints.hasBoundedHeight;
              final h = constraints.maxHeight;
              final padV = hasBoundedHeight ? (h * 0.12).clamp(6.0, 10.0) : 10.0;
              final numFontSize =
                  hasBoundedHeight ? (h * 0.30).clamp(18.0, 23.0) : 22.0;
              final miniBarHeight =
                  hasBoundedHeight ? (h * 0.50).clamp(26.0, 36.0) : 34.0;
              final isCompact = hasBoundedHeight && h < 76;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: padV,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                                '${streak.current}',
                                style: TextStyle(
                                  fontSize: numFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primaryText,
                                  height: 1.05,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 1 : 3),
                            Text(
                              l10n.bismillahDays,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 10.5 : 11.0,
                                fontWeight: FontWeight.w600,
                                color: colors.secondaryTextAlt,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _WeeklyMiniBars(
                        height: miniBarHeight,
                        weekDays: weekDays,
                        accentColor: warmAccent,
                        mutedColor: colors.primaryText.withValues(alpha: 0.14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WeeklyMiniBars extends StatelessWidget {
  final double height;
  final List<WeeklyTrendDay>? weekDays;
  final Color accentColor;
  final Color mutedColor;

  const _WeeklyMiniBars({
    required this.height,
    required this.weekDays,
    required this.accentColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final counts = (weekDays != null && weekDays!.length == 7)
        ? weekDays!.map((d) => d.count).toList()
        : const [0, 0, 0, 0, 0, 0, 0];
    final maxCount = max(1, counts.fold<int>(0, max));
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final minBarHeight = (height * 0.24).clamp(6.0, 10.0);
    final availableSpan = max(4.0, height - minBarHeight - 2.0);

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final count = counts[index];
          final ratio = count > 0 ? (count / maxCount).clamp(0.25, 1.0) : 0.22;
          final barHeight = minBarHeight + (availableSpan * ratio);
          final isToday = index == todayIndex;

          final Color barColor;
          if (isToday) {
            barColor = count > 0 ? accentColor : accentColor.withValues(alpha: 0.45);
          } else if (count > 0) {
            barColor = accentColor.withValues(alpha: 0.55);
          } else {
            barColor = mutedColor;
          }

          return Container(
            width: 5.5,
            height: barHeight,
            margin: EdgeInsets.only(right: index == 6 ? 0 : 3),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
