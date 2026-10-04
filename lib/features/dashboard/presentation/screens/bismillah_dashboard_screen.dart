import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/golden_day_service.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../namaz_vakitleri/presentation/widgets/pending_prayer_dialog.dart';
import '../../../namaz_vakitleri/presentation/widgets/past_days_prayer_dialog.dart';
import '../../../namaz_vakitleri/presentation/widgets/bulk_kaza_prompt_dialog.dart';
import '../../../namaz_vakitleri/presentation/widgets/today_prayers_card.dart';
import '../../../namaz_vakitleri/presentation/widgets/exact_alarm_prompt_sheet.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/kaza_tasks_horizontal_list.dart';
import '../widgets/pending_past_prayers_banner.dart';
import '../widgets/zikir_distribution_donut.dart';
import '../widgets/zikir_distribution_sheet.dart';
import '../widgets/activity_trend_chart.dart';
import '../widgets/annual_heatmap_widget.dart';
import '../widgets/badge_gallery_cards.dart';
import '../widgets/rank_info_bottom_sheet.dart';
import '../widgets/daily_goals_sheet.dart';
import '../widgets/surprise_chest_dialog.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../kuran/presentation/widgets/add_custom_quran_badge_sheet.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../gamification/presentation/screens/streak_details_screen.dart';
import '../widgets/streak_share_preview_modal.dart';
import '../widgets/quick_stats_share_preview_modal.dart';
import '../widgets/account_switcher_sheet.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/services/changelog_service.dart';
import '../../../../core/widgets/cloud_sync_app_bar_badge.dart';
import '../widgets/whats_new_bottom_sheet.dart';

class BismillahDashboardScreen extends ConsumerStatefulWidget {
  const BismillahDashboardScreen({super.key});

  @override
  ConsumerState<BismillahDashboardScreen> createState() => _BismillahDashboardScreenState();
}

class _BismillahDashboardScreenState extends ConsumerState<BismillahDashboardScreen> {
  StreamSubscription? _notifSub;
  StreamSubscription<int>? _farzNotifSub;
  bool _hasCheckedPendingPrayers = false;

  @override
  void initState() {
    super.initState();
    _initPrayerTrackingAndNotifications();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _farzNotifSub?.cancel();
    super.dispose();
  }

  void _initPrayerTrackingAndNotifications() {
    _notifSub = LocalNotificationService.pendingPrayerNotificationTapped.stream.listen((event) {
      if (mounted) {
        PendingPrayerDialog.show(
          context,
          prayerName: event.prayerName,
          dateStr: event.dateStr,
        );
      }
    });

    _farzNotifSub = LocalNotificationService.pendingFarzNotificationTapped.stream.listen((farzId) {
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

      // Güncelleme sonrası yenilikler kontrolü (Sadece güncelleyen kullanıcılara ilk açılışta çıkar)
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

      // 1. Process recent past days (up to 3 days) one by one in chronological order
      if (checkResult.recentDays.isNotEmpty) {
        for (final pastDay in checkResult.recentDays) {
          if (!mounted) break;
          final saved = await PastDaysPrayerDialog.show(context, day: pastDay);
          if (saved == false) {
            // User chose "Daha Sonra" - stop sequence and leave remaining pending
            break;
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 2. Process older days (>3 days) if any exist and haven't been resolved yet
      if (mounted) {
        final recheck = await PrayerTrackingService.getPastUnansweredDays(db);
        if (recheck.olderDates.isNotEmpty && mounted) {
          await BulkKazaPromptDialog.show(context, olderDates: recheck.olderDates);
        }
      }

      // 3. Recheck today's pending prayers
      if (mounted) {
        final timings = await ref.read(prayerTimingsProvider.future);
        if (mounted) {
          final unansweredToday = await PrayerTrackingService.checkUnansweredPrayerForToday(db, timings);
          if (unansweredToday != null && mounted) {
            PendingPrayerDialog.show(
              context,
              prayerName: unansweredToday.prayerName,
              dateStr: unansweredToday.dateStr,
            );
          }
        }
      }

      // Refresh state
      ref.invalidate(pendingPastDaysProvider);
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(namazStreakProvider);
    } catch (e) {
      debugPrint('[BismillahDashboard] Error in past days confirmation flow: $e');
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
      debugPrint('[BismillahDashboard] Error checking exact alarm permission: $e');
    }
  }
  Widget _buildAvatarImage(String imagePath) {
    if (imagePath.startsWith('/') || imagePath.contains(':\\') || (!imagePath.startsWith('assets/') && File(imagePath).existsSync())) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('👤', style: TextStyle(fontSize: 32)),
        ),
      );
    } else {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('👤', style: TextStyle(fontSize: 32)),
        ),
      );
    }
  }

  void _showHistoryDetailModal(BuildContext context, DynamicZikirHistoryItem item) {
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: colors.primaryText),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.totalBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.count,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.date,
                  style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.isTurkish
                      ? 'Bu zikir kaydı yerel veritabanında ve bulut yedeklemesinde güvenle saklanmaktadır.'
                      : 'This dhikr record is safely stored in local database and cloud backup.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: colors.primaryText),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddBadgeModal(BuildContext context) {
    AddCustomQuranBadgeSheet.show(context);
  }

  void _showKazaMeltModal(BuildContext context, String prayerName, int count) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                      ? (context.l10n.isTurkish ? 'Oruç Kazası Telafisi' : 'Missed Fasting Make-up')
                      : (context.l10n.isTurkish ? '$prayerName Namazı Kaza Telafisi' : '$prayerName Missed Prayer Make-up'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  prayerName == 'Oruç'
                      ? (context.l10n.isTurkish ? 'Mevcut Kaza Borcu: $count Gün' : 'Current Missed Debt: $count Days')
                      : (context.l10n.isTurkish ? 'Mevcut Kaza Borcu: $count Vakit' : 'Current Missed Debt: $count Times'),
                  style: TextStyle(fontSize: 14, color: colors.secondaryTextAlt),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ref.read(kazaNotifierProvider).adjustKaza(prayerName, 1);
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          prayerName == 'Oruç'
                              ? (context.l10n.isTurkish ? '+1 Gün Ekle' : '+1 Add Day')
                              : (context.l10n.isTurkish ? '+1 Kaza Ekle' : '+1 Add Missed'),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ref.read(kazaNotifierProvider).performKaza(prayerName);
                          Navigator.of(ctx).pop();
                          final message = prayerName == 'Oruç'
                              ? (context.l10n.isTurkish ? 'Allah kabul etsin, oruç kazası kaydedildi.' : 'May Allah accept it, missed fast recorded.')
                              : (context.l10n.isTurkish ? '$prayerName kaza namazı kaydedildi.' : '$prayerName missed prayer recorded.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        child: Text(
                          prayerName == 'Oruç'
                              ? (context.l10n.isTurkish ? 'Tutuldu (-1)' : 'Fasted (-1)')
                              : (context.l10n.isTurkish ? 'Kılındı (-1)' : 'Prayed (-1)'),
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final streakAsync = ref.watch(userStreakStreamProvider);
    final profileAsync = ref.watch(userProfileStreamProvider);
    final userRank = ref.watch(currentUserRankProvider);

    final streak = streakAsync.valueOrNull;
    final streakDays = streak?.currentStreak ?? 0;
    
    final activeSession = ref.watch(activeSessionProvider);
    final userProfile = profileAsync.valueOrNull;
    final userName = activeSession.displayName.isNotEmpty
        ? activeSession.displayName
        : ((userProfile?.userName != null && userProfile!.userName.isNotEmpty)
            ? userProfile.userName
            : (l10n.isTurkish ? 'Zâkir' : 'User'));
    final userAvatar = activeSession.avatar.isNotEmpty
        ? activeSession.avatar
        : ref.watch(userSettingsProvider).userProfileImage;

    final diamondsAsync = ref.watch(diamondCountProvider);
    final diamondsCount = diamondsAsync.valueOrNull ?? streak?.freezeCount ?? 2;

    final goldAsync = ref.watch(goldCountProvider);
    final goldCount = goldAsync.valueOrNull ?? streak?.xp ?? 0;

    final dailyGoalsAsync = ref.watch(dailyGoalsStatusProvider);
    final goalsStatus = dailyGoalsAsync.valueOrNull;

    final totalZikirAsync = ref.watch(totalZikirCountProvider);
    final totalZikirVal = totalZikirAsync.valueOrNull ?? 0;

    final quickStatsAsync = ref.watch(quickStatsProvider);
    final quickStats = quickStatsAsync.valueOrNull;

    final pendingPastAsync = ref.watch(pendingPastDaysProvider);
    final pendingPastResult = pendingPastAsync.valueOrNull;

    final historyListAsync = ref.watch(zikirHistoryListProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ==========================================
            // 1. TOP PROFILE HEADER SECTION (MATCHING SCREENSHOT)
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: colors.headerBackground,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Avatar with theme accent border - Tap to switch account
                  GestureDetector(
                    onTap: () => AccountSwitcherSheet.show(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.cardBackground,
                            border: Border.all(color: colors.accent, width: 2.5),
                          ),
                          child: ClipOval(
                            child: _buildAvatarImage(userAvatar),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Icon(
                              activeSession.isCloud ? Icons.cloud_done_rounded : Icons.swap_horiz_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Column: Username, Rank Badge, Daily Hearts, Diamonds, Coins & Total
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Username & Settings Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => AccountSwitcherSheet.show(context),
                              child: Row(
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: colors.accent,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CloudSyncAppBarBadge(),
                                InkWell(
                                  onTap: () {
                                    context.push('/settings');
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.primaryText.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.settings_outlined, size: 18, color: colors.primaryText),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Row 2: Rank Pill + Daily Hearts
                        Row(
                          children: [
                            // Green Rank Pill (Tappable to show Manevi Mertebeler modal)
                            InkWell(
                              onTap: () => RankInfoBottomSheet.show(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.accent.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(userRank.badge, style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                    Text(
                                      userRank.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.info_outline_rounded, size: 10, color: Colors.white70),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Daily Hearts (5 Hearts - 3 States: Passive/Trace, Active/Light, Completed/Vivid)
                            InkWell(
                              onTap: () => DailyGoalsSheet.show(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: (goalsStatus?.orderedGoals ?? List.generate(
                                    5,
                                    (i) => const DailyGoalItemState(
                                      id: 'default',
                                      title: '',
                                      icon: '',
                                      isEnabled: false,
                                      isCompleted: false,
                                      progressText: '',
                                    ),
                                  )).map((goal) {
                                    Color heartColor;
                                    if (!goal.isEnabled) {
                                      // 1. Pasif (İz görünümü - Düşük opaklık)
                                      heartColor = colors.accent.withValues(alpha: isDark ? 0.18 : 0.15);
                                    } else if (goal.isCompleted) {
                                      // 3. Tamamlanan (Canlı / Koyu tema rengi)
                                      heartColor = colors.accent;
                                    } else {
                                      // 2. Aktif Bekleyen (Açık tema tonu)
                                      heartColor = colors.accent.withValues(alpha: isDark ? 0.45 : 0.38);
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                      child: Icon(
                                        Icons.favorite_rounded,
                                        size: 14.5,
                                        color: heartColor,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Row 3: Diamonds, Coins & Total Zikir Text
                        Row(
                          children: [
                            // Diamonds Pill (Clickable -> Opens Treasury / Exchange)
                            GestureDetector(
                              onTap: () {
                                HapticService.selectionClick();
                                GoldDiamondExchangeSheet.show(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('💎', style: TextStyle(fontSize: 10.5)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$diamondsCount',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.add_circle_outline_rounded, size: 10, color: Color(0xFF0284C7)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Coins Pill (Clickable -> Opens Treasury / Exchange)
                            GestureDetector(
                              onTap: () {
                                HapticService.selectionClick();
                                GoldDiamondExchangeSheet.show(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 10.5)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$goldCount',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Total Zikir Counter Summary
                            Text(
                              '${l10n.bismillahTotal} ${formatCompactNumber(totalZikirVal)} ${l10n.bismillahZikirs}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.secondaryTextAlt,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. MAIN SCROLLABLE DASHBOARD BODY
            // ==========================================
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  // --- SECTION -1: Pending Past Prayers Banner (if any) ---
                  if (pendingPastResult?.hasRecent == true) ...[
                    PendingPastPrayersBanner(
                      count: pendingPastResult!.recentDays.length,
                      onTap: _triggerPastDaysConfirmationFlow,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // --- SECTION 0: Günün 5 Vakit Namazı ---
                  const TodayPrayersCard(),
                  const SizedBox(height: 16),

                  // --- SECTION 1: Günün İbadet ve Telafi Görevleri ---
                  KazaTasksHorizontalList(
                    onTaskTap: (prayer, count) => _showKazaMeltModal(context, prayer, count),
                  ),
                  const SizedBox(height: 18),

                  // --- SECTION 2: 2-COLUMN STATS GRID (BALANCED BOTTOM ALIGNMENT) ---
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column: Gün Serisi & Zikir Dağılımı Donut
                        Expanded(
                          child: Column(
                            children: [
                              // Gün Serisi Card (Enhanced with Golden Day State & Chest Button)
                              Builder(
                                builder: (context) {
                                  final isGold = goalsStatus?.isGoldCompleted ?? false;
                                  final isClaimed = goalsStatus?.isChestClaimed ?? false;

                                  return Material(
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
                                          currentStreak: streakDays,
                                          bestStreak: streak?.bestStreak ?? 0,
                                          totalDays: streak?.totalDays ?? 0,
                                          rankName: userRank.name,
                                          rankBadge: userRank.badge,
                                          isGoldCompleted: isGold,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: isGold
                                              ? (isDark ? const Color(0xFF2A2510) : const Color(0xFFFFFDE7))
                                              : colors.cardBackground,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isGold ? const Color(0xFFEAB308) : colors.borderStroke,
                                            width: isGold ? 1.5 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isGold
                                                  ? const Color(0xFFCA8A04).withValues(alpha: 0.2)
                                                  : Colors.black.withValues(alpha: 0.04),
                                              blurRadius: isGold ? 12 : 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: isGold ? const Color(0xFFFEF08A) : const Color(0xFFFFF3E0),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(isGold ? '🌟' : '🔥', style: const TextStyle(fontSize: 20)),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        isGold
                                                            ? (l10n.isTurkish ? '🌟 Altın Gün!' : '🌟 Golden Day!')
                                                            : l10n.bismillahStreakTitle,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          color: isGold
                                                              ? (isDark ? const Color(0xFFFACC15) : const Color(0xFFB45309))
                                                              : colors.secondaryTextAlt,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '$streakDays ${l10n.bismillahDays}',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: isGold
                                                              ? (isDark ? const Color(0xFFFDE047) : const Color(0xFF78350F))
                                                              : colors.primaryText,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isGold) ...[
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 34,
                                                child: ElevatedButton(
                                                  onPressed: isClaimed
                                                      ? null
                                                      : () async {
                                                          HapticService.selectionClick();
                                                          final reward = await ref
                                                              .read(gamificationNotifierProvider)
                                                              .openSurpriseChest(isTurkish: l10n.isTurkish);
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
                                                        },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFEAB308),
                                                    foregroundColor: Colors.white,
                                                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                                                    elevation: 2,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  child: Text(
                                                    isClaimed
                                                        ? (l10n.isTurkish ? 'Sandık Açıldı ✅' : 'Chest Opened ✅')
                                                        : (l10n.isTurkish ? '🎁 Sürpriz Sandığı Aç' : '🎁 Open Surprise Chest'),
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // Zikir Dağılımı Donut Card
                              Expanded(
                                child: ZikirDistributionDonut(
                                  onTap: () => ZikirDistributionSheet.show(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Column: Hızlı İstatistikler Tall Card
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onLongPress: () {
                                HapticService.selectionClick();
                                QuickStatsSharePreviewModal.show(
                                  context: context,
                                  todayZikir: quickStats?.formattedToday ?? '0',
                                  thisWeekZikir: quickStats?.formattedThisWeek ?? '0',
                                  dailyAvgZikir: quickStats?.formattedDailyAverage ?? '0',
                                  totalZikir: quickStats?.formattedTotal ?? formatCompactNumber(totalZikirVal),
                                  quranPages: quickStats?.formattedQuranToday ?? '0',
                                  rankName: userRank.name,
                                  rankBadge: userRank.badge,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.bismillahQuickStats,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // 1. Bugün
                                    _buildQuickStatRow(
                                      icon: Icons.calendar_today_rounded,
                                      iconColor: const Color(0xFF4CAF50),
                                      iconBg: const Color(0xFFE8F5E9),
                                      title: l10n.bismillahToday,
                                      value: quickStats?.formattedToday ?? '0',
                                      primaryTextColor: colors.primaryText,
                                      secondaryTextColor: colors.secondaryTextAlt,
                                    ),
                                    const SizedBox(height: 8),

                                    // 2. Bu Hafta
                                    _buildQuickStatRow(
                                      icon: Icons.date_range_rounded,
                                      iconColor: const Color(0xFF0284C7),
                                      iconBg: const Color(0xFFE0F2FE),
                                      title: l10n.bismillahThisWeek,
                                      value: quickStats?.formattedThisWeek ?? '0',
                                      primaryTextColor: colors.primaryText,
                                      secondaryTextColor: colors.secondaryTextAlt,
                                    ),
                                    const SizedBox(height: 8),

                                    // 3. Günlük Ortalama
                                    _buildQuickStatRow(
                                      icon: Icons.bar_chart_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                      iconBg: const Color(0xFFFEF3C7),
                                      title: l10n.bismillahDailyAverage,
                                      value: quickStats?.formattedDailyAverage ?? '0',
                                      primaryTextColor: colors.primaryText,
                                      secondaryTextColor: colors.secondaryTextAlt,
                                    ),
                                    const SizedBox(height: 8),

                                    // 4. Toplam
                                    _buildQuickStatRow(
                                      icon: Icons.all_inclusive_rounded,
                                      iconColor: const Color(0xFF9333EA),
                                      iconBg: const Color(0xFFF3E8FF),
                                      title: l10n.bismillahTotal,
                                      value: quickStats?.formattedTotal ?? formatCompactNumber(totalZikirVal),
                                      primaryTextColor: colors.primaryText,
                                      secondaryTextColor: colors.secondaryTextAlt,
                                    ),
                                    const SizedBox(height: 8),

                                    // 5. Kur'an Okuma
                                    _buildQuickStatRow(
                                      icon: Icons.menu_book_rounded,
                                      iconColor: const Color(0xFF0D9488),
                                      iconBg: const Color(0xFFCCFBF1),
                                      title: l10n.bismillahQuranReading,
                                      value: '${quickStats?.formattedQuranToday ?? "0"} ${l10n.bismillahPages}',
                                      primaryTextColor: colors.primaryText,
                                      secondaryTextColor: colors.secondaryTextAlt,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- SECTION 3: Aktivite Trendleri Bar Chart ---
                  const ActivityTrendChart(),
                  const SizedBox(height: 18),

                  // --- SECTION 4: Yıllık Aktivite Isı Haritası ---
                  const AnnualHeatmapWidget(),
                  const SizedBox(height: 20),

                  // --- SECTION 5 & 6: Zikir Başarı Rozetleri & Kuran Okuma Rozetleri ---
                  BadgeGalleryCards(
                    onAddQuranBadge: () => _showAddBadgeModal(context),
                  ),
                  const SizedBox(height: 24),

                  // --- SECTION 7: Zikir Geçmişi Header & List ---
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.bismillahHistoryTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dynamic History Cards List
                  historyListAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.borderStroke),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.history_toggle_off_rounded, size: 32, color: colors.secondaryTextAlt),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.isTurkish
                                      ? 'Henüz zikir geçmişi bulunmuyor.\nZikir çektikçe burada otomatik listelenecektir.'
                                      : 'No dhikr history yet.\nYour dhikrs will be automatically listed here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.secondaryTextAlt,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: items.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => _showHistoryDetailModal(context, item),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colors.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.borderStroke),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colors.primaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.date,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.secondaryTextAlt,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            l10n.isTurkish ? 'Detaylar için dokunun ->' : 'Tap for details ->',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: colors.secondaryTextAlt.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Right Count Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: colors.totalBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.count,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: colors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
