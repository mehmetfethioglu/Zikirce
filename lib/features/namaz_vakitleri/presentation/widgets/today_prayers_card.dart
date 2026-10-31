import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../dashboard/providers/share_reminder_provider.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/golden_day_service.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../providers/prayer_providers.dart';

class TodayPrayersCard extends ConsumerWidget {
  final bool showCountdownHeader;

  const TodayPrayersCard({
    super.key,
    this.showCountdownHeader = false,
  });

  String _getPrayerTime(PrayerTimings? timings, String prayerName) {
    if (timings == null) return '';
    switch (prayerName) {
      case 'Sabah':
        return timings.fajr;
      case 'Öğle':
        return timings.dhuhr;
      case 'İkindi':
        return timings.asr;
      case 'Akşam':
        return timings.maghrib;
      case 'Yatsı':
        return timings.isha;
      default:
        return '';
    }
  }

  bool _isUpcoming(String prayerName, String? nextName) {
    if (nextName == null) return false;
    if (prayerName == 'Sabah' && (nextName == 'İmsak' || nextName == 'Güneş')) return true;
    return prayerName == nextName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayPrayersAsync = ref.watch(todayPrayersProvider);
    final timingsAsync = ref.watch(prayerTimingsProvider);
    final selectedCity = ref.watch(selectedCityProvider);
    final nextPrayerName = ref.watch(nextPrayerInfoProvider.select((i) => i?.name));
    // Vakit değişiminde kartın anında yeniden değerlendirilmesi için aktif vakit indeksini izle
    ref.watch(nextPrayerInfoProvider.select((i) => i?.activePrayerIndex));
    final nextPrayerTime = showCountdownHeader
        ? ref.watch(nextPrayerInfoProvider.select((i) => i?.time))
        : null;

    final timings = timingsAsync.valueOrNull ??
        PrayerTimesService.calculateOfflinePrayerTimes(selectedCity, DateTime.now());
    final rawPrayers = todayPrayersAsync.valueOrNull ?? [];
    
    // Asla boş kart kalmaması için 5 vakit garantisi
    const fallbackPrayers = [
      TodayPrayerStatusItem(prayerName: 'Sabah', isCompleted: false, kazaCount: 0, icon: '🌅', badgeColorHex: '#4A90E2'),
      TodayPrayerStatusItem(prayerName: 'Öğle', isCompleted: false, kazaCount: 0, icon: '☀️', badgeColorHex: '#F5A623'),
      TodayPrayerStatusItem(prayerName: 'İkindi', isCompleted: false, kazaCount: 0, icon: '🌤️', badgeColorHex: '#F8E71C'),
      TodayPrayerStatusItem(prayerName: 'Akşam', isCompleted: false, kazaCount: 0, icon: '🌇', badgeColorHex: '#BD10E0'),
      TodayPrayerStatusItem(prayerName: 'Yatsı', isCompleted: false, kazaCount: 0, icon: '🌙', badgeColorHex: '#9013FE'),
    ];
    final prayers = rawPrayers.isNotEmpty ? rawPrayers : fallbackPrayers;

    final completedCount = prayers.where((p) => p.isCompleted).length;
    final isAllCompleted = completedCount == 5;

    final String titleText;
    final String subtitleText;

    if (showCountdownHeader && nextPrayerName != null && nextPrayerTime != null) {
      titleText = l10n.isTurkish
          ? '$nextPrayerName Vaktine Kalan'
          : 'Until $nextPrayerName';
      subtitleText = l10n.isTurkish
          ? 'Sonraki Vakit: $nextPrayerTime'
          : 'Next: $nextPrayerTime';
    } else {
      titleText = l10n.isTurkish ? 'Günün 5 Vakit Namazı' : '5 Daily Prayers';
      subtitleText = l10n.isTurkish
          ? '$completedCount / 5 Vakit Tamamlandı'
          : '$completedCount / 5 Completed';
    }


    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAllCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : colors.borderStroke,
          width: isAllCompleted ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (isAllCompleted ? const Color(0xFF10B981) : colors.accent)
                      .withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  isAllCompleted ? '🎉' : '🕌',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.secondaryTextAlt,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showCountdownHeader) ...[
                const SizedBox(width: 12),
                const _PrayerCountdownTickerText(),
              ],
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  HapticService.selectionClick();
                  ZikirSharePreviewModal.show(
                    context: context,
                    zikirName: l10n.isTurkish ? '5 Vakit Namaz & Secde Huzuru' : '5 Daily Prayers & Prostration',
                    category: 'Namaz',
                    currentCount: completedCount,
                    targetCount: 5,
                    totalCount: completedCount,
                    initialTheme: ZikirShareCardTheme.turquoiseDome,
                    initialShowCounterStats: false,
                  );
                },
                borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 14),

          // 5 Prayers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayers.map((item) {
              final timeStr = _getPrayerTime(timings, item.prayerName);
              final isUpcoming = _isUpcoming(item.prayerName, nextPrayerName);
              final isTimeEntered = PrayerTrackingService.isPrayerTimeEntered(
                item.prayerName,
                timings,
              );
              return _buildPrayerItem(
                context,
                ref,
                item,
                timeStr,
                isUpcoming,
                isTimeEntered,
                completedCount,
                colors,
                isDark,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerItem(
    BuildContext context,
    WidgetRef ref,
    TodayPrayerStatusItem item,
    String timeStr,
    bool isUpcoming,
    bool isTimeEntered,
    int completedCount,
    AppThemeColors colors,
    bool isDark,
  ) {
    final isDone = isTimeEntered && item.isCompleted;
    final l10n = context.l10n;

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          HapticService.selectionClick();
          if (!isTimeEntered) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  content: Row(
                    children: [
                      const Text('⏳', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.isTurkish
                              ? '${item.prayerName} namazının vakti henüz girmedi${timeStr.isNotEmpty ? ' ($timeStr)' : ''}. Vakti girmeden kılındı olarak işaretlenemez.'
                              : '${item.prayerName} prayer time has not entered yet${timeStr.isNotEmpty ? ' ($timeStr)' : ''}. It cannot be marked as completed before its time.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return;
          }

          final db = ref.read(databaseProvider);
          final earnedDiamond = await PrayerTrackingService.toggleTodayPrayer(db, item.prayerName);

          final todayStr = GoldenDayService.getTodayStr();
          final transferredGold = await GoldenDayService.claimPendingRewardsIfAny(todayStr);

          ref.invalidate(todayPrayersProvider);
          ref.invalidate(kazaPrayersStreamProvider);
          ref.invalidate(kazaSummaryProvider);
          ref.invalidate(namazStreakProvider);
          ref.invalidate(dailyGoalsStatusProvider);
          ref.read(badgeRefreshTriggerProvider.notifier).state++;

          if (!isDone) {
            try {
              ref.read(shareReminderProvider.notifier).setReminder(
                title: '${item.prayerName} Namazı & Secde Huzuru',
                subtitle: '${completedCount + 1} / 5 vakit kılındı 🕌',
                type: ShareReminderType.prayers,
                metadata: {
                  'name': '5 Vakit Namaz & Secde Huzuru',
                  'category': 'Namaz',
                  'count': completedCount + 1,
                  'target': 5,
                },
              );
            } catch (_) {}
          }

          if (transferredGold > 0 && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF854D0E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tebrikler! Yatsı namazını kılarak Altın Gün\'ü tamamladınız. Sandıktan kazandığınız +$transferredGold Altın hesabınıza aktarıldı!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (earnedDiamond && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF065F46),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: const Row(
                  children: [
                    Text('💎', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tebrikler! Günün 5 vakit namazını tamamlayarak 1 Elmas kazandınız!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          decoration: BoxDecoration(
            color: isDone
                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5)).withValues(alpha: 0.6)
                : (isUpcoming
                    ? colors.accent.withValues(alpha: isDark ? 0.12 : 0.08)
                    : colors.pageBackground),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
                  : (isUpcoming
                      ? colors.accent.withValues(alpha: 0.6)
                      : colors.borderStroke),
              width: isDone || isUpcoming ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            children: [
              // Icon
              Opacity(
                opacity: isTimeEntered ? 1.0 : 0.48,
                child: Text(
                  item.icon,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 4),

              // Prayer Name
              Text(
                item.prayerName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDone
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                      : (isTimeEntered
                          ? colors.primaryText
                          : colors.secondaryTextAlt.withValues(alpha: 0.7)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isUpcoming ? FontWeight.bold : FontWeight.w500,
                    color: isUpcoming ? colors.accent : colors.secondaryTextAlt,
                  ),
                ),
              ],
              const SizedBox(height: 6),

              // Checkbox Indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                      : (!isTimeEntered
                          ? colors.secondaryTextAlt.withValues(alpha: 0.08)
                          : Colors.transparent),
                  border: Border.all(
                    color: isDone
                        ? Colors.transparent
                        : (isUpcoming
                            ? colors.accent.withValues(alpha: 0.7)
                            : colors.secondaryTextAlt.withValues(alpha: isTimeEntered ? 0.4 : 0.25)),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : (!isTimeEntered
                        ? Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: isUpcoming
                                ? colors.accent.withValues(alpha: 0.85)
                                : colors.secondaryTextAlt.withValues(alpha: 0.55),
                          )
                        : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerCountdownTickerText extends ConsumerWidget {
  const _PrayerCountdownTickerText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final remainingText = ref.watch(nextPrayerInfoProvider.select((i) => i?.formattedRemaining ?? ''));

    return Text(
      remainingText,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: colors.primaryText,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
