import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../hatim/providers/hatim_providers.dart';
import '../../../hatim/presentation/widgets/hatim_duasi_modal.dart';
import '../../providers/tilavet_secdesi_provider.dart';
import 'tilavet_secdesi_guide_sheet.dart';

/// Top horizontal icon ribbon for Quran achievements, streaks, and Tilavet Secdesi tracking.
/// Designed with luxury 52x52px icon-only cards, badge counters, and tooltips.
class QuranTopIconRibbon extends ConsumerWidget {
  final void Function(int page)? onNavigateToPage;
  final void Function(Hatim hatim)? onOpenCompletedHatim;
  final void Function({
    required String title,
    required String icon,
    required String description,
    required String category,
  })? onOpenBadgeDetail;
  final void Function(
    String surahTitle,
    int currentStreak,
    int targetDays,
    String blessing,
  )? onOpenStreakDetail;
  final VoidCallback? onOpenMukabeleScreen;

  const QuranTopIconRibbon({
    super.key,
    this.onNavigateToPage,
    this.onOpenCompletedHatim,
    this.onOpenBadgeDetail,
    this.onOpenStreakDetail,
    this.onOpenMukabeleScreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final secondaryTextColor =
        isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final accentGreen =
        isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E);
    final amberColor =
        isDark ? const Color(0xFFFFB300) : const Color(0xFFD97706);
    final cardBg = isDark ? const Color(0xFF23262F) : const Color(0xFFFFFFFF);
    final borderStroke =
        isDark ? const Color(0xFF33343A) : const Color(0xFFD8E5E1);

    // Watch providers
    final tilavetDebt = ref.watch(tilavetSecdesiDebtProvider);
    final hatimsAsync = ref.watch(hatimListStreamProvider);
    final unlockedBadgesAsync = ref.watch(unlockedBadgesStreamProvider);
    final customBadgesAsync = ref.watch(customBadgesProvider);
    final streaksAsync = ref.watch(surahStreaksProvider);

    final allHatims = hatimsAsync.valueOrNull ?? [];
    final completedHatims = allHatims
        .where((h) => h.isCompleted || h.completedPages >= 604)
        .toList();
    final unlockedBadges = unlockedBadgesAsync.valueOrNull ?? [];
    final customBadges = customBadgesAsync.valueOrNull ?? [];
    final streaks = streaksAsync.valueOrNull ?? const SurahStreaksData();

    final List<Widget> items = [];

    // ==========================================
    // 1. PINNED #1: TİLÂVET SECDESİ KARTI
    // ==========================================
    final hasDebt = tilavetDebt > 0;
    items.add(
      _buildIconBadgeCard(
        tooltip: hasDebt
            ? '$tilavetDebt Tilâvet Secdesi Borcu (Dokun ve İncele)'
            : 'Tilâvet Secdesi Rehberi & Takibi (Borç Yok)',
        iconWidget: SvgPicture.asset(
          'assets/images/ic_tilavet_secde.svg',
          width: 25,
          height: 25,
          colorFilter: ColorFilter.mode(
            hasDebt ? amberColor : accentGreen,
            BlendMode.srcIn,
          ),
        ),
        badgeText: hasDebt ? '$tilavetDebt' : null,
        badgeColor: hasDebt ? amberColor : null,
        isHighlighted: hasDebt,
        cardBg: hasDebt
            ? (isDark ? const Color(0xFF2D2012) : const Color(0xFFFFF9ED))
            : cardBg,
        borderColor: hasDebt
            ? amberColor.withValues(alpha: 0.65)
            : accentGreen.withValues(alpha: 0.35),
        shadowColor: hasDebt ? amberColor.withValues(alpha: 0.25) : null,
        onTap: () {
          TilavetSecdesiGuideSheet.show(
            context,
            onNavigateToPage: onNavigateToPage,
          );
        },
      ),
    );

    // ==========================================
    // 1.5 PINNED #2: MATBÛ KUR'ÂN HATİM DUASI KARTI (Sadece Hatim Duası Okuma)
    // ==========================================
    items.add(
      _buildIconBadgeCard(
        tooltip: 'Matbû Kur’ân Hatim Duası (Sadece Hatim Duası Oku)',
        iconWidget: const Text(
          '🤲',
          style: TextStyle(fontSize: 22),
        ),
        badgeText: 'Dua',
        badgeColor: const Color(0xFFB57D15),
        cardBg: isDark ? const Color(0xFF282218) : const Color(0xFFFDF8EB),
        borderColor: const Color(0xFFD4AF37).withValues(alpha: 0.55),
        onTap: () => HatimDuasiModal.show(context),
      ),
    );

    // ==========================================
    // 2. TAMAMLANAN HATİMLER
    // ==========================================
    for (final h in completedHatims) {
      final isMukabele = h.id.startsWith('mukabele_') ||
          h.title.toLowerCase().contains('mukabele');
      items.add(
        _buildIconBadgeCard(
          tooltip: '${h.title} (Tamamlandı)',
          iconWidget: SvgPicture.asset(
            isMukabele
                ? 'assets/images/ic_kuran_crown.svg'
                : 'assets/images/ic_hatim_books.svg',
            width: 25,
            height: 25,
            colorFilter: const ColorFilter.mode(
              Color(0xFFD97706),
              BlendMode.srcIn,
            ),
          ),
          badgeText: isMukabele ? '👑' : '✓',
          badgeColor: const Color(0xFFD97706),
          isHighlighted: true,
          cardBg: isDark ? const Color(0xFF2E2414) : const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFD97706).withValues(alpha: 0.6),
          shadowColor: const Color(0xFFD97706).withValues(alpha: 0.2),
          onTap: () => onOpenCompletedHatim?.call(h),
        ),
      );
    }

    // ==========================================
    // 3. ÇEKİRDEK KUR'AN ROZETLERİ
    // ==========================================
    final unlockedSet = unlockedBadges.map((b) => b.badgeId).toSet();

    if (unlockedSet.contains('quran_first_step')) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Nurlu Başlangıç (İlk Sayfa)',
          iconWidget: SvgPicture.asset(
            'assets/images/ic_kuran_book.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(accentGreen, BlendMode.srcIn),
          ),
          badgeText: '1',
          badgeColor: accentGreen,
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenBadgeDetail?.call(
            title: 'Nurlu Başlangıç',
            icon: '📖',
            description: 'Kuran\'dan ilk sayfanızı başarıyla okudunuz.',
            category: 'Kuran Başarısı',
          ),
        ),
      );
    }

    if (unlockedSet.contains('quran_10_pages')) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Kuran Dostu (10 Sayfa)',
          iconWidget: SvgPicture.asset(
            'assets/images/ic_kuran_scroll.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Color(0xFF0284C7),
              BlendMode.srcIn,
            ),
          ),
          badgeText: '10',
          badgeColor: const Color(0xFF0284C7),
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenBadgeDetail?.call(
            title: 'Kuran Dostu',
            icon: '📜',
            description:
                'Toplamda 10 sayfa Kuran okuyarak bu mertebeye ulaştınız.',
            category: 'Kuran Başarısı',
          ),
        ),
      );
    }

    if (unlockedSet.contains('quran_100_pages')) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Kuran Okuyucusu (100 Sayfa)',
          iconWidget: SvgPicture.asset(
            'assets/images/ic_kuran_sun.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Color(0xFFEAB308),
              BlendMode.srcIn,
            ),
          ),
          badgeText: '100',
          badgeColor: const Color(0xFFEAB308),
          isHighlighted: true,
          cardBg: cardBg,
          borderColor: const Color(0xFFEAB308).withValues(alpha: 0.6),
          onTap: () => onOpenBadgeDetail?.call(
            title: 'Kuran Okuyucusu',
            icon: '🌟',
            description:
                'Toplamda 100 sayfa Kuran okuyarak nurunuzu artırdınız.',
            category: 'Kuran Başarısı',
          ),
        ),
      );
    }

    // ==========================================
    // 4. SURE VİRDLERİ (STREAKS)
    // ==========================================
    if (streaks.waqiahStreak >= 1) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Vâkıa Virdi: ${streaks.waqiahStreak}/40 Gün',
          iconWidget: const Icon(
            Icons.spa_rounded,
            size: 24,
            color: Color(0xFF10B981),
          ),
          badgeText: '${streaks.waqiahStreak}',
          badgeColor: const Color(0xFF10B981),
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenStreakDetail?.call(
            'Vâkıa Sûresi',
            streaks.waqiahStreak,
            40,
            'Rızık ve Bereket Virdi',
          ),
        ),
      );
    }

    if (streaks.mulkStreak >= 1) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Mülk Virdi: ${streaks.mulkStreak}/40 Gün',
          iconWidget: const Icon(
            Icons.nightlight_round,
            size: 23,
            color: Color(0xFF818CF8),
          ),
          badgeText: '${streaks.mulkStreak}',
          badgeColor: const Color(0xFF818CF8),
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenStreakDetail?.call(
            'Mülk Sûresi',
            streaks.mulkStreak,
            40,
            'Kabir Nuru Virdi',
          ),
        ),
      );
    }

    if (streaks.nabaStreak >= 1) {
      items.add(
        _buildIconBadgeCard(
          tooltip: 'Nebe Virdi: ${streaks.nabaStreak}/40 Gün',
          iconWidget: const Icon(
            Icons.wb_sunny_rounded,
            size: 23,
            color: Color(0xFFF59E0B),
          ),
          badgeText: '${streaks.nabaStreak}',
          badgeColor: const Color(0xFFF59E0B),
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenStreakDetail?.call(
            'Nebe Sûresi',
            streaks.nabaStreak,
            40,
            'Müjde ve Bereket Virdi',
          ),
        ),
      );
    }

    // ==========================================
    // 5. ÖZEL HEDEF ROZETLERİ
    // ==========================================
    for (final cb in customBadges) {
      items.add(
        _buildIconBadgeCard(
          tooltip: '${cb.title}: ${cb.currentStreak}/${cb.targetDays} Gün',
          iconWidget: Text(
            cb.iconEmoji,
            style: const TextStyle(fontSize: 22),
          ),
          badgeText: '${cb.currentStreak}',
          badgeColor: accentGreen,
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onOpenBadgeDetail?.call(
            title: cb.title,
            icon: cb.iconEmoji,
            description:
                '${cb.scopeDisplayName} için ${cb.targetDays} günlük Kuran virdi. (İlerleme: ${cb.currentStreak}/${cb.targetDays} Gün)',
            category: 'Özel Kuran Hedefi',
          ),
        ),
      );
    }

    // ==========================================
    // 6. BOŞ / BAŞLANGIÇ HEDEF KARTLARI
    // ==========================================
    if (completedHatims.isEmpty &&
        unlockedBadges.isEmpty &&
        streaks.waqiahStreak == 0 &&
        streaks.mulkStreak == 0 &&
        streaks.nabaStreak == 0 &&
        customBadges.isEmpty) {
      items.addAll([
        _buildIconBadgeCard(
          tooltip: 'İlk Hatminizi Başlatın (Mukabele & Hatim)',
          iconWidget: SvgPicture.asset(
            'assets/images/ic_hatim_books.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              secondaryTextColor.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
          badgeText: '+',
          badgeColor: accentGreen,
          cardBg: cardBg,
          borderColor: borderStroke,
          isDashedBorder: true,
          onTap: onOpenMukabeleScreen,
        ),
        _buildIconBadgeCard(
          tooltip: 'İlk Sayfanızı Okuyun (1. Sayfa)',
          iconWidget: SvgPicture.asset(
            'assets/images/ic_kuran_book.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              secondaryTextColor.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
          badgeText: '1',
          badgeColor: accentGreen,
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onNavigateToPage?.call(1),
        ),
        _buildIconBadgeCard(
          tooltip: 'Vâkıa 40 Gün Virdi Başlat (534. Sayfa)',
          iconWidget: Icon(
            Icons.spa_rounded,
            size: 22,
            color: secondaryTextColor.withValues(alpha: 0.7),
          ),
          badgeText: '40g',
          badgeColor: accentGreen,
          cardBg: cardBg,
          borderColor: borderStroke,
          onTap: () => onNavigateToPage?.call(534),
        ),
      ]);
    }

    return SizedBox(
      height: 60,
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

  Widget _buildIconBadgeCard({
    required String tooltip,
    required Widget iconWidget,
    String? badgeText,
    Color? badgeColor,
    bool isHighlighted = false,
    bool isDashedBorder = false,
    required Color cardBg,
    required Color borderColor,
    Color? shadowColor,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap != null
                  ? () {
                      HapticService.lightImpact();
                      onTap();
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: isHighlighted ? 1.6 : 1.1,
                  ),
                  boxShadow: shadowColor != null
                      ? [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: iconWidget),
              ),
            ),
          ),

          // Micro badge indicator on top right
          if (badgeText != null)
            Positioned(
              top: -3,
              right: -3,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 9.5,
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
    );
  }
}
