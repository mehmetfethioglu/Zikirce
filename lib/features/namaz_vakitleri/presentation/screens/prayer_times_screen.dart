import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/foldable_layout_info.dart';
import '../../../../core/layout/foldable_two_pane.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../../irfan/presentation/widgets/irfan_seljuk_star_painter.dart';
import '../../providers/prayer_providers.dart';
import '../widgets/city_selection_sheet.dart';
import '../widgets/kaza_manager_sheet.dart';
import '../widgets/prayer_circular_ring.dart';
import '../widgets/today_prayers_card.dart';
import '../widgets/prayer_notification_settings_sheet.dart';
import '../widgets/qibla_finder_card.dart';
import 'qibla_compass_screen.dart';

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  void _openCitySelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CitySelectionSheet(),
    );
  }

  void _openKazaManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KazaManagerSheet(),
    );
  }

  void _openQiblaFinder(BuildContext context) {
    HapticService.selectionClick();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/qibla');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const QiblaCompassScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currentCity = ref.watch(selectedCityProvider);
    final kazaSummary = ref.watch(kazaSummaryProvider);
    final layout = FoldableLayoutInfo.of(context);
    final bottomPad = layout.useNavigationRail ? 28.0 : 110.0;

    final cityHeader = _buildCityNotificationHeader(
      context,
      currentCity: currentCity,
      l10n: l10n,
      colors: colors,
    );

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: layout.supportsTwoPaneHorizontal
            ? FoldableTwoPane(
                key: const Key('prayer_times_two_pane'),
                axis: FoldableSplitAxis.horizontal,
                paneProportion: 0.5,
                paneSpacing: 16.0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                startPane: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(4, 16, 4, bottomPad),
                  children: [
                    cityHeader,
                    const SizedBox(height: 18),
                    const TodayPrayersCard(showCountdownHeader: true),
                  ],
                ),
                endPane: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(4, 16, 4, bottomPad),
                  children: [
                    const QiblaFinderCard(),
                    const SizedBox(height: 16),
                    _buildKazaCardsRow(context, kazaSummary, colors),
                    const SizedBox(height: 16),
                    _buildFeraciyeAndSelaBanner(
                      context,
                      colors,
                      l10n.isTurkish,
                    ),
                    const SizedBox(height: 20),
                    const _IrfanLibraryShortcutCard(),
                  ],
                ),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  layout.isNarrowCoverScreen ? 14 : 20,
                  16,
                  layout.isNarrowCoverScreen ? 14 : 20,
                  bottomPad,
                ),
                children: [
                  cityHeader,
                  const SizedBox(height: 18),
                  const TodayPrayersCard(showCountdownHeader: true),
                  const SizedBox(height: 16),
                  const QiblaFinderCard(),
                  const SizedBox(height: 16),
                  _buildKazaCardsRow(context, kazaSummary, colors),
                  const SizedBox(height: 16),
                  _buildFeraciyeAndSelaBanner(context, colors, l10n.isTurkish),
                  const SizedBox(height: 20),
                  const _IrfanLibraryShortcutCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildCityNotificationHeader(
    BuildContext context, {
    required String currentCity,
    required AppLocalizations l10n,
    required AppThemeColors colors,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openCitySelection(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          currentCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.accent,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.namazTapToChangeCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.secondaryTextAlt.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TvFocusable(
          key: const Key('prayer_header_qibla_btn'),
          borderRadius: 16,
          onPressed: () => _openQiblaFinder(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderStroke, width: 0.8),
            ),
            child: Icon(
              Icons.explore_rounded,
              color: colors.accent,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TvFocusable(
          borderRadius: 16,
          onPressed: () => PrayerNotificationSettingsSheet.show(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderStroke, width: 0.8),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: colors.accent,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Perşembe Feraciye Duası & Cuma Salâsı Hızlı Erişim ve Fazilet Kartı
  // =========================================================================
  Widget _buildFeraciyeAndSelaBanner(BuildContext context, AppThemeColors colors, bool isTr) {
    final virtuePill = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => PrayerNotificationSettingsSheet.showVirtueSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          isTr ? 'Fazileti' : 'Virtue',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.accent,
          ),
        ),
      ),
    );
    final settingsPill = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => PrayerNotificationSettingsSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: colors.pageBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.borderStroke),
        ),
        child: Text(
          isTr ? 'Vakit Ayarı' : 'Settings',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 330;
          return Row(
            crossAxisAlignment:
                isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('🤲', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Feraciye Duası & Cuma Salâsı' : 'Feraciye Prayer & Friday Sala',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTr
                          ? 'Perşembe akşamı Feraciye, yatsı ve Cuma öncesi Salâ vakitleri'
                          : 'Thursday Feraciye & Thursday/Friday Sala recitations',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                    if (isNarrow) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [virtuePill, settingsPill],
                      ),
                    ],
                  ],
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 6),
                virtuePill,
                const SizedBox(width: 6),
                settingsPill,
              ],
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3'lü Kaza Takip Kartları Row
  // =========================================================================
  Widget _buildKazaCardsRow(BuildContext context, KazaSummary summary, AppThemeColors colors) {
    final l10n = context.l10n;
    return Row(
      children: [
        // CARD 1: KILINAN KAZA
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${summary.totalCompleted}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.namazCompleted,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.secondaryTextAlt,
                  ),
                ),
                const SizedBox(height: 10),
                PrayerCircularRing(
                  progress: summary.weeklyMeltedPercent,
                  size: 46,
                  strokeWidth: 3.5,
                  progressColor: const Color(0xFF2E7D32),
                  trackColor: colors.borderStroke.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // CARD 2: KALAN KAZA
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${summary.totalRemaining}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.namazRemaining,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.secondaryTextAlt,
                  ),
                ),
                const SizedBox(height: 10),
                PrayerCircularRing(
                  progress: summary.generalMeltedPercent,
                  size: 46,
                  strokeWidth: 3.5,
                  progressColor: const Color(0xFF1A237E),
                  trackColor: colors.borderStroke.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // CARD 3: KAZA AYARI
        Expanded(
          child: InkWell(
            onTap: () => _openKazaManager(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.settings_rounded,
                    size: 22,
                    color: colors.primaryText,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.namazManageMissed,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrayerCircularRing(
                    progress: 1.0,
                    size: 46,
                    strokeWidth: 3.5,
                    progressColor: const Color(0xFFD4A574),
                    trackColor: colors.borderStroke.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IrfanLibraryShortcutCard extends StatelessWidget {
  const _IrfanLibraryShortcutCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          context.go('/irfan?tab=library');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.cardBackground,
                colors.accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: IrfanSeljukStarBadge(
                  size: 30,
                  color: colors.accent,
                  accentColor: const Color(0xFFD4A574),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isTr
                                ? '32 Farz İlmihal & İrfan Meydanı'
                                : '32 Farz Catechism & Wisdom Plaza',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.irfanShortcutSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTr ? 'Aç' : 'Open',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
