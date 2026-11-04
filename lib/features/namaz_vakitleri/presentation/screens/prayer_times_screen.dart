import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../providers/prayer_providers.dart';
import '../widgets/city_selection_sheet.dart';
import '../widgets/kaza_manager_sheet.dart';
import '../widgets/prayer_circular_ring.dart';
import '../widgets/today_prayers_card.dart';
import '../widgets/prayer_notification_settings_sheet.dart';
import 'fiqh_library_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currentCity = ref.watch(selectedCityProvider);
    final kazaSummary = ref.watch(kazaSummaryProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            // ==========================================
            // 1. DOKUNULABİLİR ŞEHİR BAŞLIĞI & BİLDİRİM AYARI
            // ==========================================
            Row(
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
                              Text(
                                currentCity,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                  letterSpacing: -0.5,
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
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 2. GÜNÜN 5 VAKİT NAMAZI TAKİP KARTI
            // ==========================================
            const TodayPrayersCard(showCountdownHeader: true),
            const SizedBox(height: 16),

            // ==========================================
            // 3. 3'LÜ KAZA TAKİP KARTLARI
            // ==========================================
            _buildKazaCardsRow(context, kazaSummary, colors),
            const SizedBox(height: 16),

            // ==========================================
            // 3.5. PERŞEMBE FERACİYE DUASI & CUMA SALÂSI KARTI
            // ==========================================
            _buildFeraciyeAndSelaBanner(context, colors, l10n.isTurkish),
            const SizedBox(height: 20),

            // ==========================================
            // 4. 32 FARZ İLMİHAL KÜTÜPHANESİ
            // ==========================================
            const FiqhLibraryView(isEmbedded: true),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Perşembe Feraciye Duası & Cuma Salâsı Hızlı Erişim ve Fazilet Kartı
  // =========================================================================
  Widget _buildFeraciyeAndSelaBanner(BuildContext context, AppThemeColors colors, bool isTr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: Row(
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
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
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
          ),
          const SizedBox(width: 6),
          InkWell(
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
          ),
        ],
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
