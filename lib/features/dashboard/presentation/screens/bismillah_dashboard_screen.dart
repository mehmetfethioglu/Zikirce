import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/layout/foldable_layout_info.dart';
import '../../../../core/layout/foldable_two_pane.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/changelog_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/golden_day_service.dart';
import '../../../namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import '../../../namaz_vakitleri/presentation/widgets/bulk_kaza_prompt_dialog.dart';
import '../../../namaz_vakitleri/presentation/widgets/exact_alarm_prompt_sheet.dart';
import '../../../namaz_vakitleri/presentation/widgets/past_days_prayer_dialog.dart';
import '../../../namaz_vakitleri/presentation/widgets/pending_prayer_dialog.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/share_reminder_provider.dart';
import '../widgets/bento/bento_daily_zikir_card.dart';
import '../widgets/bento/bento_home_action_cards.dart';
import '../widgets/bento/bento_streak_rhythm_card.dart';
import '../widgets/bento/last_7_days_activity_trend_card.dart';
import '../widgets/bento/minimal_home_header.dart';
import '../widgets/pending_past_prayers_banner.dart';
import '../widgets/quick_stats_share_preview_modal.dart';
import '../widgets/streak_share_preview_modal.dart';
import '../widgets/whats_new_bottom_sheet.dart';

class BismillahDashboardScreen extends ConsumerStatefulWidget {
  const BismillahDashboardScreen({super.key});

  @override
  ConsumerState<BismillahDashboardScreen> createState() =>
      _BismillahDashboardScreenState();
}

class _BismillahDashboardScreenState
    extends ConsumerState<BismillahDashboardScreen> {
  StreamSubscription<int>? _farzNotifSub;
  bool _hasCheckedPendingPrayers = false;

  @override
  void initState() {
    super.initState();
    _initPrayerTrackingAndNotifications();
  }

  @override
  void dispose() {
    _farzNotifSub?.cancel();
    super.dispose();
  }

  void _initPrayerTrackingAndNotifications() {
    _farzNotifSub = LocalNotificationService
        .pendingFarzNotificationTapped.stream
        .listen((farzId) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FiqhLibraryScreen(initialFarzId: farzId),
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _hasCheckedPendingPrayers) return;
      _hasCheckedPendingPrayers = true;

      try {
        final shouldShowChangelog = await ChangelogService.shouldShowWhatsNew();
        if (shouldShowChangelog && mounted) {
          await WhatsNewBottomSheet.show(context);
        }
      } catch (e) {
        debugPrint('[BismillahDashboard] Error checking changelog: $e');
      }

      if (mounted) {
        await _triggerPastDaysConfirmationFlow();
        if (mounted) {
          await _checkExactAlarmPermissionIfNeeded();
        }
      }
    });
  }

  Future<void> _triggerPastDaysConfirmationFlow() async {
    try {
      final db = ref.read(databaseProvider);
      final checkResult = await PrayerTrackingService.getPastUnansweredDays(db);

      if (!mounted) return;

      if (checkResult.recentDays.isNotEmpty) {
        for (final pastDay in checkResult.recentDays) {
          if (!mounted) break;
          final saved = await PastDaysPrayerDialog.show(context, day: pastDay);
          if (saved == false) {
            break;
          }
        }
      }

      if (mounted) {
        final recheck = await PrayerTrackingService.getPastUnansweredDays(db);
        if (recheck.olderDates.isNotEmpty && mounted) {
          await BulkKazaPromptDialog.show(
            context,
            olderDates: recheck.olderDates,
          );
        }
      }

      if (mounted) {
        final timings = await ref.read(prayerTimingsProvider.future);
        if (mounted) {
          final unansweredToday =
              await PrayerTrackingService.checkUnansweredPrayerForToday(
            db,
            timings,
          );
          if (unansweredToday != null && mounted) {
            PendingPrayerDialog.show(
              context,
              prayerName: unansweredToday.prayerName,
              dateStr: unansweredToday.dateStr,
            );
          }
        }
      }

      ref.invalidate(pendingPastDaysProvider);
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(namazStreakProvider);
    } catch (e) {
      debugPrint(
        '[BismillahDashboard] Error in past days confirmation flow: $e',
      );
    }
  }

  Future<void> _checkExactAlarmPermissionIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool('ExactAlarmPromptShown') ?? false;
      if (alreadyPrompted) return;

      final canExact = await BatteryOptimizationService.canScheduleExactAlarms();
      if (!canExact) {
        await prefs.setBool('ExactAlarmPromptShown', true);
        if (mounted) {
          await ExactAlarmPromptSheet.show(context);
        }
      }
    } catch (e) {
      debugPrint(
        '[BismillahDashboard] Error checking exact alarm permission: $e',
      );
    }
  }

  void _openShareReminder(BuildContext context, ShareReminderState reminder) {
    HapticService.selectionClick();
    if (reminder.hasPendingReminder) {
      ref.read(shareReminderProvider.notifier).clearReminder();
    }

    final streak = ref.read(userStreakStreamProvider).valueOrNull;
    final streakDays = streak?.currentStreak ?? 0;
    final userRank = ref.read(currentUserRankProvider);
    final goalsStatus = ref.read(dailyGoalsStatusProvider).valueOrNull;
    final totalZikirVal = ref.read(totalZikirCountProvider).valueOrNull ?? 0;
    final quickStats = ref.read(quickStatsProvider).valueOrNull;
    final l10n = context.l10n;

    if (reminder.hasPendingReminder &&
        reminder.type == ShareReminderType.streak) {
      StreakSharePreviewModal.show(
        context,
        currentStreak: streakDays,
        bestStreak: streak?.bestStreak ?? 0,
        totalDays: streak?.totalDays ?? 0,
        rankName: userRank.name,
        rankBadge: userRank.badge,
        isGoldCompleted: goalsStatus?.isGoldCompleted ?? false,
        initialTheme: reminder.theme,
      );
      return;
    }

    if (reminder.hasPendingReminder &&
        reminder.type == ShareReminderType.quickStats) {
      QuickStatsSharePreviewModal.show(
        context: context,
        todayZikir: quickStats?.formattedToday ?? '0',
        thisWeekZikir: quickStats?.formattedThisWeek ?? '0',
        dailyAvgZikir: quickStats?.formattedDailyAverage ?? '0',
        totalZikir:
            quickStats?.formattedTotal ?? formatCompactNumber(totalZikirVal),
        quranPages: quickStats?.formattedQuranToday ?? '0',
        rankName: userRank.name,
        rankBadge: userRank.badge,
        initialTheme: reminder.theme,
      );
      return;
    }

    String goalName = l10n.isTurkish
        ? 'Günlük Zikir & Kalbin Huzuru'
        : 'Daily Dhikr & Peace of Heart';
    String category = 'Zikir';
    String? arabic;
    int count = 33;
    int target = 33;
    bool showCounter = false;
    ZikirShareCardTheme theme = ZikirShareCardTheme.emeraldSufi;

    if (reminder.hasPendingReminder) {
      goalName = reminder.metadata['name'] as String? ??
          (reminder.title.isNotEmpty ? reminder.title : goalName);
      category = reminder.metadata['category'] as String? ??
          _categoryForReminderType(reminder.type);
      arabic = reminder.metadata['arabic'] as String?;
      target = reminder.metadata['target'] as int? ?? 33;
      count = reminder.metadata['count'] as int? ?? target;
      showCounter = reminder.type == ShareReminderType.zikir;
      theme = reminder.theme;
    } else if (goalsStatus != null) {
      if (goalsStatus.isGoldCompleted) {
        goalName = 'Altın Gün & İbadette İstikamet';
        category = 'Altın Gün';
        count = goalsStatus.completedGoalsCount;
        target = goalsStatus.totalActiveGoals;
        theme = ZikirShareCardTheme.midnightGold;
      } else if (goalsStatus.isZikirGoalEnabled &&
          goalsStatus.isZikirMet &&
          goalsStatus.todayZikirCount > 0) {
        goalName = 'Günlük Zikir & Kalbin Huzuru';
        category = 'Zikir';
        count = goalsStatus.todayZikirCount;
        target = goalsStatus.zikirGoal;
        showCounter = true;
        theme = ZikirShareCardTheme.emeraldSufi;
      } else if (goalsStatus.isKuranGoalEnabled &&
          goalsStatus.isKuranMet &&
          goalsStatus.todayKuranPages > 0) {
        goalName = 'Kur’an-ı Kerim Tilaveti';
        category = 'Kur’an';
        count = goalsStatus.todayKuranPages;
        target = goalsStatus.kuranGoal;
        theme = ZikirShareCardTheme.fajrDawn;
      } else if (goalsStatus.isPrayersMet) {
        goalName = '5 Vakit Namaz & Secde Huzuru';
        category = 'Namaz';
        count = goalsStatus.completedPrayersCount;
        target = 5;
        theme = ZikirShareCardTheme.turquoiseDome;
      } else if (goalsStatus.isEzberGoalEnabled &&
          goalsStatus.isEzberMet &&
          goalsStatus.todayEzberCount > 0) {
        goalName = 'Ezber & Hafızlık Gayreti';
        category = 'Ezber';
        count = goalsStatus.todayEzberCount;
        target = goalsStatus.ezberGoal;
        theme = ZikirShareCardTheme.royalAmethyst;
      } else if (goalsStatus.isKazaGoalEnabled &&
          goalsStatus.isKazaMet &&
          goalsStatus.todayKazaCount > 0) {
        goalName = 'Kaza Telafisi & İstiğfar';
        category = 'Kaza & Tövbe';
        count = goalsStatus.todayKazaCount;
        target = goalsStatus.kazaGoal;
        theme = ZikirShareCardTheme.roseAmber;
      }
    }

    ZikirSharePreviewModal.show(
      context: context,
      zikirName: goalName,
      arabicText: arabic,
      category: category,
      currentCount: count,
      targetCount: target,
      totalCount: count,
      initialTheme: theme,
      initialShowCounterStats: showCounter,
    );
  }

  String _categoryForReminderType(ShareReminderType type) {
    switch (type) {
      case ShareReminderType.prayers:
        return 'Namaz';
      case ShareReminderType.zikir:
        return 'Zikir';
      case ShareReminderType.kuran:
        return 'Kur’an';
      case ShareReminderType.ezber:
        return 'Ezber';
      case ShareReminderType.kaza:
        return 'Kaza & Tövbe';
      case ShareReminderType.goldenDay:
      case ShareReminderType.streak:
        return 'Altın Gün';
      case ShareReminderType.quickStats:
      case ShareReminderType.general:
        return 'Zikir';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final goalsStatus = ref.watch(
      dailyGoalsStatusProvider.select((a) => a.valueOrNull),
    );
    final pendingPastResult = ref.watch(
      pendingPastDaysProvider.select((a) => a.valueOrNull),
    );

    ref.listen<AsyncValue<DailyGoalsStatus>>(
      dailyGoalsStatusProvider,
      (prev, next) {
        final status = next.valueOrNull;
        if (status != null) {
          ref.read(shareReminderProvider.notifier).syncWithDailyGoals(status);
        }
      },
    );

    final shareReminder = ref.watch(shareReminderProvider);
    final isShareCardsEnabled = ref.watch(
      userSettingsProvider.select((s) => s.isShareCardsEnabled),
    );
    final hasCompletedAnyGoal = (goalsStatus?.completedGoalsCount ?? 0) > 0;
    final hasShareBadge =
        (shareReminder.hasPendingReminder || hasCompletedAnyGoal) &&
            isShareCardsEnabled;
    final isGoldGoalState = (goalsStatus?.isGoldCompleted ?? false) ||
        (shareReminder.hasPendingReminder &&
            shareReminder.type == ShareReminderType.goldenDay);
    final badgePrimaryColor =
        isGoldGoalState ? const Color(0xFFF59E0B) : colors.accent;
    final badgeSecondaryColor =
        isGoldGoalState ? const Color(0xFFD97706) : const Color(0xFF0D9488);

    final layout = FoldableLayoutInfo.of(context);
    final rawBottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomClearance = layout.useNavigationRail
        ? (rawBottomInset + 16.0)
        : (rawBottomInset > 0 ? (rawBottomInset + 10.0) : 12.0);
    const topPad = 8.0;
    final hasPendingBanner = pendingPastResult?.hasRecent == true;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    final minCanvasHeight = (hasPendingBanner ? 576.0 : 516.0) * textScale;
    final maxCanvasHeight = math.max(minCanvasHeight, 840.0);
    final compactHorizontalPad = layout.isNarrowCoverScreen ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight =
                constraints.maxHeight - topPad - bottomClearance;

            if (layout.supportsTwoPaneHorizontal) {
              final minTwoPaneHeight =
                  (hasPendingBanner ? 510.0 : 460.0) * textScale;
              final maxTwoPaneHeight = math.max(minTwoPaneHeight, 900.0);
              final fitsTwoPane = availableHeight >= minTwoPaneHeight;
              final twoPaneCanvasHeight = fitsTwoPane
                  ? availableHeight.clamp(minTwoPaneHeight, maxTwoPaneHeight)
                  : minTwoPaneHeight;
              final gap = (twoPaneCanvasHeight * 0.018).clamp(8.0, 14.0);

              return SingleChildScrollView(
                physics: fitsTwoPane
                    ? const ClampingScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: SizedBox(
                  height: twoPaneCanvasHeight + topPad + bottomClearance,
                  child: FoldableTwoPane(
                    key: const Key('dashboard_two_pane'),
                    axis: FoldableSplitAxis.horizontal,
                    paneProportion: 0.48,
                    paneSpacing: 16.0,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topPad,
                      16,
                      bottomClearance,
                    ),
                    startPane: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasPendingBanner) ...[
                          PendingPastPrayersBanner(
                            count: pendingPastResult!.recentDays.length,
                            onTap: _triggerPastDaysConfirmationFlow,
                          ),
                          SizedBox(height: gap),
                        ],
                        Expanded(
                          flex: 52,
                          child: MinimalHomeHeader(
                            hasShareBadge: hasShareBadge,
                            badgePrimaryColor: badgePrimaryColor,
                            badgeSecondaryColor: badgeSecondaryColor,
                            onOpenShareReminder: () =>
                                _openShareReminder(context, shareReminder),
                          ),
                        ),
                        SizedBox(height: gap),
                        const Expanded(
                          flex: 48,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: BentoDailyZikirCard()),
                              SizedBox(width: 12),
                              Expanded(child: BentoStreakRhythmCard()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    endPane: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(
                          flex: 54,
                          child: FavoriteZikirsCarouselCard(),
                        ),
                        SizedBox(height: gap),
                        const Expanded(
                          flex: 46,
                          child: Last7DaysActivityTrendCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final fitsViewport = availableHeight >= minCanvasHeight;
            final canvasHeight = fitsViewport
                ? availableHeight.clamp(minCanvasHeight, maxCanvasHeight)
                : minCanvasHeight;
            final gap = (canvasHeight * 0.016).clamp(8.0, 12.0);

            return SingleChildScrollView(
              physics: fitsViewport
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                compactHorizontalPad,
                topPad,
                compactHorizontalPad,
                bottomClearance,
              ),
              child: SizedBox(
                height: canvasHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasPendingBanner) ...[
                      PendingPastPrayersBanner(
                        count: pendingPastResult!.recentDays.length,
                        onTap: _triggerPastDaysConfirmationFlow,
                      ),
                      SizedBox(height: gap),
                    ],
                    Expanded(
                      flex: 22,
                      child: MinimalHomeHeader(
                        hasShareBadge: hasShareBadge,
                        badgePrimaryColor: badgePrimaryColor,
                        badgeSecondaryColor: badgeSecondaryColor,
                        onOpenShareReminder: () =>
                            _openShareReminder(context, shareReminder),
                      ),
                    ),
                    SizedBox(height: gap),
                    const Expanded(
                      flex: 19,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: BentoDailyZikirCard()),
                          SizedBox(width: 12),
                          Expanded(child: BentoStreakRhythmCard()),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    const Expanded(
                      flex: 33,
                      child: FavoriteZikirsCarouselCard(),
                    ),
                    SizedBox(height: gap),
                    const Expanded(
                      flex: 26,
                      child: Last7DaysActivityTrendCard(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
