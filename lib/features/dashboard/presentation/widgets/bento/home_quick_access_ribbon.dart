import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../ezber/presentation/screens/memorization_screen.dart';
import '../../../../gamification/providers/gamification_providers.dart';
import '../../../../hatim/presentation/widgets/hatim_duasi_modal.dart';
import '../../../../kuran/presentation/widgets/tilavet_secdesi_guide_sheet.dart';
import '../../../../kuran/providers/tilavet_secdesi_provider.dart';
import '../../../../namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import '../../../../namaz_vakitleri/presentation/screens/qibla_compass_screen.dart';
import '../../../../namaz_vakitleri/presentation/widgets/kaza_manager_sheet.dart';
import '../../../../namaz_vakitleri/presentation/widgets/prayer_notification_settings_sheet.dart';
import '../../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../daily_goals_sheet.dart';
import '../kaza_tasks_horizontal_list.dart';

class HomeQuickAccessRibbon extends ConsumerWidget {
  final bool compact;

  const HomeQuickAccessRibbon({
    super.key,
    this.compact = false,
  });

  void _pushRoute(
    BuildContext context, {
    required String route,
    required WidgetBuilder fallbackBuilder,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(route);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: fallbackBuilder),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = l10n.isTurkish;

    final totalKaza = ref.watch(
      kazaPrayersStreamProvider.select(
        (a) => (a.valueOrNull ?? const <KazaPrayer>[])
            .fold<int>(0, (sum, k) => sum + k.totalCount),
      ),
    );
    final goalsSlice = ref.watch(
      dailyGoalsStatusProvider.select(
        (a) => (
          completed: a.valueOrNull?.completedGoalsCount ?? 0,
          total: a.valueOrNull?.totalActiveGoals ?? 0,
          isGold: a.valueOrNull?.isGoldCompleted ?? false,
        ),
      ),
    );
    final tilavetDebt = ref.watch(tilavetSecdesiDebtProvider);

    final amberColor =
        isDark ? const Color(0xFFFFB300) : const Color(0xFFD97706);
    final tileSize = compact ? 46.0 : 50.0;
    final ribbonHeight = compact ? 54.0 : 58.0;

    final items = <Widget>[
      _QuickAccessIconTile(
        key: const Key('home_quick_access_kaza'),
        size: tileSize,
        tooltip: isTr
            ? 'Telafi Görevleri (Kaza Namazı & Oruç)'
            : 'Make-up Tasks (Qada Prayer & Fasting)',
        iconWidget: Icon(
          Icons.fact_check_rounded,
          size: compact ? 20 : 22,
          color: totalKaza > 0 ? amberColor : colors.accent,
        ),
        badgeText: totalKaza > 0
            ? formatCompactNumber(totalKaza)
            : (isTr ? 'Kaza' : 'Qada'),
        badgeColor: totalKaza > 0 ? amberColor : colors.accent,
        isHighlighted: totalKaza > 0,
        cardBg: totalKaza > 0
            ? (isDark ? const Color(0xFF2D2012) : const Color(0xFFFFF9ED))
            : colors.cardBackground,
        borderColor: totalKaza > 0
            ? amberColor.withValues(alpha: 0.6)
            : colors.borderStroke,
        shadowColor: totalKaza > 0 ? amberColor.withValues(alpha: 0.2) : null,
        onTap: () => _HomeKazaTasksSheet.show(context),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_qibla'),
        size: tileSize,
        tooltip: isTr ? 'Kıble Bulucu' : 'Qibla Finder',
        iconWidget: Icon(
          Icons.explore_rounded,
          size: compact ? 20 : 22,
          color: colors.accent,
        ),
        badgeText: isTr ? 'Kıble' : 'Qibla',
        badgeColor: colors.accent,
        cardBg: colors.cardBackground,
        borderColor: colors.borderStroke,
        onTap: () => _pushRoute(
          context,
          route: '/qibla',
          fallbackBuilder: (_) => const QiblaCompassScreen(),
        ),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_goals'),
        size: tileSize,
        tooltip: isTr
            ? 'Günlük Hedefler & Altın Gün'
            : 'Daily Goals & Golden Day',
        iconWidget: Icon(
          Icons.workspace_premium_rounded,
          size: compact ? 20 : 22,
          color: goalsSlice.isGold ? amberColor : colors.accent,
        ),
        badgeText: goalsSlice.total > 0
            ? '${goalsSlice.completed}/${goalsSlice.total}'
            : (isTr ? 'Hedef' : 'Goals'),
        badgeColor: goalsSlice.isGold ? amberColor : colors.accent,
        isHighlighted: goalsSlice.isGold,
        cardBg: goalsSlice.isGold
            ? (isDark ? const Color(0xFF2D2012) : const Color(0xFFFFF9ED))
            : colors.cardBackground,
        borderColor: goalsSlice.isGold
            ? amberColor.withValues(alpha: 0.6)
            : colors.borderStroke,
        shadowColor:
            goalsSlice.isGold ? amberColor.withValues(alpha: 0.2) : null,
        onTap: () => DailyGoalsSheet.show(context),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_tilavet'),
        size: tileSize,
        tooltip: tilavetDebt > 0
            ? (isTr
                ? '$tilavetDebt Tilâvet Secdesi Borcu'
                : '$tilavetDebt Sajdah Tilawah Pending')
            : (isTr ? 'Tilâvet Secdesi Rehberi' : 'Sajdah Tilawah Guide'),
        iconWidget: SvgPicture.asset(
          'assets/images/ic_tilavet_secde.svg',
          width: compact ? 20 : 22,
          height: compact ? 20 : 22,
          colorFilter: ColorFilter.mode(
            tilavetDebt > 0 ? amberColor : colors.accent,
            BlendMode.srcIn,
          ),
          placeholderBuilder: (_) => Icon(
            Icons.mosque_rounded,
            size: compact ? 18 : 20,
            color: tilavetDebt > 0 ? amberColor : colors.accent,
          ),
        ),
        badgeText:
            tilavetDebt > 0 ? '$tilavetDebt' : (isTr ? 'Secde' : 'Sajdah'),
        badgeColor: tilavetDebt > 0 ? amberColor : colors.accent,
        isHighlighted: tilavetDebt > 0,
        cardBg: tilavetDebt > 0
            ? (isDark ? const Color(0xFF2D2012) : const Color(0xFFFFF9ED))
            : colors.cardBackground,
        borderColor: tilavetDebt > 0
            ? amberColor.withValues(alpha: 0.6)
            : colors.borderStroke,
        shadowColor:
            tilavetDebt > 0 ? amberColor.withValues(alpha: 0.2) : null,
        onTap: () {
          TilavetSecdesiGuideSheet.show(
            context,
            onNavigateToPage: (page) {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.push('/mushaf?page=$page');
              }
            },
          );
        },
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_prayer_alerts'),
        size: tileSize,
        tooltip: isTr
            ? 'Ezan & Namaz Bildirim Ayarları'
            : 'Adhan & Prayer Notification Settings',
        iconWidget: Icon(
          Icons.notifications_active_outlined,
          size: compact ? 20 : 22,
          color: colors.accent,
        ),
        badgeText: isTr ? 'Ezan' : 'Adhan',
        badgeColor: colors.accent,
        cardBg: colors.cardBackground,
        borderColor: colors.borderStroke,
        onTap: () => PrayerNotificationSettingsSheet.show(context),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_hatim_duasi'),
        size: tileSize,
        tooltip: isTr ? 'Hatim Duası Oku' : 'Read Khatam Dua',
        iconWidget: Text(
          '🤲',
          style: TextStyle(fontSize: compact ? 18 : 20),
        ),
        badgeText: 'Dua',
        badgeColor: const Color(0xFFB57D15),
        cardBg: isDark ? const Color(0xFF282218) : const Color(0xFFFDF8EB),
        borderColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
        onTap: () => HatimDuasiModal.show(context),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_fiqh'),
        size: tileSize,
        tooltip: isTr ? 'Fıkıh & İlmihal Rehberi' : 'Fiqh & Ilmihal Guide',
        iconWidget: Icon(
          Icons.menu_book_rounded,
          size: compact ? 20 : 22,
          color: colors.accent,
        ),
        badgeText: isTr ? 'Fıkıh' : 'Fiqh',
        badgeColor: colors.accent,
        cardBg: colors.cardBackground,
        borderColor: colors.borderStroke,
        onTap: () => _pushRoute(
          context,
          route: '/fiqh',
          fallbackBuilder: (_) => const FiqhLibraryScreen(),
        ),
      ),
      _QuickAccessIconTile(
        key: const Key('home_quick_access_ezber'),
        size: tileSize,
        tooltip: isTr ? 'Ezber & Hafızlık' : 'Memorization & Hifz',
        iconWidget: Icon(
          Icons.school_rounded,
          size: compact ? 20 : 22,
          color: colors.accent,
        ),
        badgeText: isTr ? 'Ezber' : 'Hifz',
        badgeColor: colors.accent,
        cardBg: colors.cardBackground,
        borderColor: colors.borderStroke,
        onTap: () => _pushRoute(
          context,
          route: '/ezber',
          fallbackBuilder: (_) => const MemorizationScreen(),
        ),
      ),
    ];

    return SizedBox(
      height: ribbonHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}

class _QuickAccessIconTile extends StatelessWidget {
  final double size;
  final String tooltip;
  final Widget iconWidget;
  final String? badgeText;
  final Color? badgeColor;
  final bool isHighlighted;
  final Color cardBg;
  final Color borderColor;
  final Color? shadowColor;
  final VoidCallback onTap;

  const _QuickAccessIconTile({
    super.key,
    required this.size,
    required this.tooltip,
    required this.iconWidget,
    this.badgeText,
    this.badgeColor,
    this.isHighlighted = false,
    required this.cardBg,
    required this.borderColor,
    this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        button: true,
        label: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  HapticService.lightImpact();
                  onTap();
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: isHighlighted ? 1.5 : 1.0,
                    ),
                    boxShadow: shadowColor != null
                        ? [
                            BoxShadow(
                              color: shadowColor!,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: iconWidget),
                ),
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: -3,
                right: -3,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeKazaTasksSheet extends ConsumerWidget {
  const _HomeKazaTasksSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HomeKazaTasksSheet(),
    );
  }

  void _showKazaMeltModal(
    BuildContext context,
    WidgetRef ref,
    String prayerName,
    int count,
  ) {
    final colors = context.colors;
    showModalBottomSheet<void>(
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
                        onPressed: () async {
                          try {
                            await ref
                                .read(kazaNotifierProvider)
                                .adjustKaza(prayerName, 1);
                          } catch (e) {
                            debugPrint('[HomeKazaSheet] adjustKaza error: $e');
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(
                          prayerName == 'Oruç'
                              ? (l10n.isTurkish ? '+1 Gün Ekle' : '+1 Add Day')
                              : (l10n.isTurkish
                                  ? '+1 Kaza Ekle'
                                  : '+1 Add Missed'),
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
                        onPressed: () async {
                          try {
                            await ref
                                .read(kazaNotifierProvider)
                                .performKaza(prayerName);
                          } catch (e) {
                            debugPrint('[HomeKazaSheet] performKaza error: $e');
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) {
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
                          }
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.isTurkish ? 'Telafi Görevleri' : 'Make-up Tasks',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const KazaManagerSheet(),
                    );
                  },
                  icon: Icon(Icons.tune_rounded, size: 16, color: colors.accent),
                  label: Text(
                    l10n.isTurkish ? 'Yönet' : 'Manage',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            KazaTasksHorizontalList(
              onTaskTap: (prayerName, count) =>
                  _showKazaMeltModal(context, ref, prayerName, count),
            ),
          ],
        ),
      ),
    );
  }
}
