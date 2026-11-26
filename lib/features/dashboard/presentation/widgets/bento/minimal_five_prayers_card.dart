import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/providers/database_provider.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/services/prayer_times_service.dart';
import '../../../../../core/services/prayer_tracking_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../gamification/providers/gamification_providers.dart';
import '../../../../gamification/services/golden_day_service.dart';
import '../../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../providers/share_reminder_provider.dart';

class MinimalFivePrayersCard extends ConsumerWidget {
  const MinimalFivePrayersCard({super.key});

  static const List<TodayPrayerStatusItem> _fallbackPrayers = [
    TodayPrayerStatusItem(
      prayerName: 'Sabah',
      isCompleted: false,
      kazaCount: 0,
      icon: '🌅',
      badgeColorHex: '#4A90E2',
    ),
    TodayPrayerStatusItem(
      prayerName: 'Öğle',
      isCompleted: false,
      kazaCount: 0,
      icon: '☀️',
      badgeColorHex: '#F5A623',
    ),
    TodayPrayerStatusItem(
      prayerName: 'İkindi',
      isCompleted: false,
      kazaCount: 0,
      icon: '🌤️',
      badgeColorHex: '#F8E71C',
    ),
    TodayPrayerStatusItem(
      prayerName: 'Akşam',
      isCompleted: false,
      kazaCount: 0,
      icon: '🌇',
      badgeColorHex: '#BD10E0',
    ),
    TodayPrayerStatusItem(
      prayerName: 'Yatsı',
      isCompleted: false,
      kazaCount: 0,
      icon: '🌙',
      badgeColorHex: '#9013FE',
    ),
  ];

  String _getPrayerTime(PrayerTimings timings, String prayerName) {
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

  String _localizedPrayerLabel(String prayerName, bool isTurkish) {
    if (isTurkish) return prayerName;
    switch (prayerName) {
      case 'Sabah':
        return 'Fajr';
      case 'Öğle':
        return 'Dhuhr';
      case 'İkindi':
        return 'Asr';
      case 'Akşam':
        return 'Maghrib';
      case 'Yatsı':
        return 'Isha';
      default:
        return prayerName;
    }
  }

  bool _isUpcoming(String prayerName, String? nextName) {
    if (nextName == null) return false;
    if (prayerName == 'Sabah' && (nextName == 'İmsak' || nextName == 'Güneş')) {
      return true;
    }
    return prayerName == nextName;
  }

  Future<void> _onTapPrayer(
    BuildContext context,
    WidgetRef ref, {
    required TodayPrayerStatusItem item,
    required String timeStr,
    required bool isTimeEntered,
    required bool isDone,
    required int completedCount,
    required bool isDark,
  }) async {
    HapticService.selectionClick();
    final l10n = context.l10n;

    if (!isTimeEntered) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                const Text('⏳', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.isTurkish
                        ? '${item.prayerName} namazının vakti henüz girmedi${timeStr.isNotEmpty ? ' ($timeStr)' : ''}. Vakti girmeden kılındı olarak işaretlenemez.'
                        : '${_localizedPrayerLabel(item.prayerName, false)} prayer time has not entered yet${timeStr.isNotEmpty ? ' ($timeStr)' : ''}.',
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

    try {
      final db = ref.read(databaseProvider);
      final earnedDiamond =
          await PrayerTrackingService.toggleTodayPrayer(db, item.prayerName);

      final todayStr = GoldenDayService.getTodayStr();
      final transferredGold =
          await GoldenDayService.claimPendingRewardsIfAny(todayStr);

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
        } catch (e) {
          debugPrint('[MinimalFivePrayersCard] shareReminder error: $e');
        }
      }

      if (transferredGold > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF854D0E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tebrikler! Altın Gün\'ü tamamladınız. +$transferredGold Altın hesabınıza aktarıldı!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Row(
              children: [
                Text('💎', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tebrikler! Günün 5 vakit namazını tamamlayarak 1 Elmas kazandınız!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MinimalFivePrayersCard] toggleTodayPrayer error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rawPrayers =
        ref.watch(todayPrayersProvider.select((a) => a.valueOrNull)) ??
            const <TodayPrayerStatusItem>[];
    final timingsVal =
        ref.watch(prayerTimingsProvider.select((a) => a.valueOrNull));
    final selectedCity = ref.watch(selectedCityProvider);
    final nextPrayerName =
        ref.watch(nextPrayerInfoProvider.select((i) => i?.name));
    ref.watch(nextPrayerInfoProvider.select((i) => i?.activePrayerIndex));

    final timings = timingsVal ??
        PrayerTimesService.calculateOfflinePrayerTimes(
          selectedCity,
          DateTime.now(),
        );
    final prayers = rawPrayers.isNotEmpty ? rawPrayers : _fallbackPrayers;
    final completedCount = prayers.where((p) => p.isCompleted).length;
    final isAllCompleted = completedCount == 5;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAllCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : colors.borderStroke,
          width: isAllCompleted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.hasBoundedHeight;
          final isCompact = hasBoundedHeight && constraints.maxHeight < 86;
          final prayersRow = Row(
            crossAxisAlignment: hasBoundedHeight
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: prayers.map((item) {
              final timeStr = _getPrayerTime(timings, item.prayerName);
              final isUpcoming = _isUpcoming(item.prayerName, nextPrayerName);
              final isTimeEntered = PrayerTrackingService.isPrayerTimeEntered(
                item.prayerName,
                timings,
              );
              final isDone = isTimeEntered && item.isCompleted;
              final label =
                  _localizedPrayerLabel(item.prayerName, l10n.isTurkish);

              return Expanded(
                child: _MinimalPrayerPill(
                  key: Key('minimal_prayer_${item.prayerName}'),
                  label: label,
                  timeStr: timeStr,
                  isDone: isDone,
                  isUpcoming: isUpcoming,
                  isTimeEntered: isTimeEntered,
                  isCompact: isCompact,
                  colors: colors,
                  isDark: isDark,
                  onTap: () => _onTapPrayer(
                    context,
                    ref,
                    item: item,
                    timeStr: timeStr,
                    isTimeEntered: isTimeEntered,
                    isDone: isDone,
                    completedCount: completedCount,
                    isDark: isDark,
                  ),
                  onLongPress: () {
                    HapticService.selectionClick();
                    GoRouter.maybeOf(context)?.go('/namaz');
                  },
                ),
              );
            }).toList(),
          );

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 7,
              vertical: isCompact ? 4 : 6,
            ),
            child: Column(
              mainAxisSize:
                  hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MinimalNextPrayerHeader(isCompact: isCompact),
                SizedBox(height: isCompact ? 3 : 4),
                if (hasBoundedHeight) Expanded(child: prayersRow) else prayersRow,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MinimalNextPrayerHeader extends ConsumerWidget {
  final bool isCompact;

  const _MinimalNextPrayerHeader({required this.isCompact});

  String _localizedPrayerName(String name, bool isTurkish) {
    if (isTurkish) return name;
    switch (name) {
      case 'İmsak':
      case 'Sabah':
        return 'Fajr';
      case 'Güneş':
        return 'Sunrise';
      case 'Öğle':
        return 'Dhuhr';
      case 'İkindi':
        return 'Asr';
      case 'Akşam':
        return 'Maghrib';
      case 'Yatsı':
        return 'Isha';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final info = ref.watch(
      nextPrayerInfoProvider.select(
        (i) => (
          name: i?.name ?? '',
          remaining: i?.formattedRemaining ?? '--:--:--',
        ),
      ),
    );

    final displayName = _localizedPrayerName(info.name, l10n.isTurkish);
    final title = displayName.isNotEmpty
        ? (l10n.isTurkish
            ? '$displayName Vaktine Kalan'
            : 'Until $displayName')
        : (l10n.isTurkish ? 'Sonraki Vakit' : 'Next Prayer');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: isCompact ? 11.0 : 12.0,
            color: colors.accent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isCompact ? 9.5 : 10.5,
                fontWeight: FontWeight.w600,
                color: colors.secondaryTextAlt,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            info.remaining,
            key: const Key('minimal_prayer_countdown_text'),
            style: TextStyle(
              fontSize: isCompact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: colors.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalPrayerPill extends StatelessWidget {
  final String label;
  final String timeStr;
  final bool isDone;
  final bool isUpcoming;
  final bool isTimeEntered;
  final bool isCompact;
  final AppThemeColors colors;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MinimalPrayerPill({
    super.key,
    required this.label,
    required this.timeStr,
    required this.isDone,
    required this.isUpcoming,
    required this.isTimeEntered,
    required this.isCompact,
    required this.colors,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final doneGreen =
        isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
    final bgColor = isDone
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
            .withValues(alpha: 0.55)
        : (isUpcoming
            ? colors.accent.withValues(alpha: isDark ? 0.14 : 0.08)
            : colors.pageBackground);
    final borderColor = isDone
        ? doneGreen
        : (isUpcoming
            ? colors.accent.withValues(alpha: 0.6)
            : colors.borderStroke);
    final statusSize = isCompact ? 13.0 : 14.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 2.5,
              vertical: isCompact ? 2.0 : 3.0,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: borderColor,
                width: isDone || isUpcoming ? 1.15 : 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: isCompact ? 9.5 : 10.0,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? (isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF065F46))
                          : (isTimeEntered
                              ? colors.primaryText
                              : colors.secondaryTextAlt.withValues(alpha: 0.72)),
                      height: 1.08,
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  SizedBox(height: isCompact ? 1.0 : 1.5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeStr,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: isCompact ? 8.5 : 9.0,
                        fontWeight:
                            isUpcoming ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isUpcoming ? colors.accent : colors.secondaryTextAlt,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.08,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: isCompact ? 2.0 : 3.0),
                Container(
                  width: statusSize,
                  height: statusSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? (isDark
                            ? const Color(0xFF10B981)
                            : const Color(0xFF059669))
                        : (!isTimeEntered
                            ? colors.secondaryTextAlt.withValues(alpha: 0.08)
                            : Colors.transparent),
                    border: Border.all(
                      color: isDone
                          ? Colors.transparent
                          : (isUpcoming
                              ? colors.accent.withValues(alpha: 0.7)
                              : colors.secondaryTextAlt.withValues(
                                  alpha: isTimeEntered ? 0.4 : 0.25,
                                )),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: Colors.white,
                        )
                      : (!isTimeEntered
                          ? Icon(
                              Icons.schedule_rounded,
                              size: 8.5,
                              color: isUpcoming
                                  ? colors.accent.withValues(alpha: 0.85)
                                  : colors.secondaryTextAlt
                                      .withValues(alpha: 0.55),
                            )
                          : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
