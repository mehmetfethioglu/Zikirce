import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/subscription_provider.dart';

class TahrirProSheet extends ConsumerWidget {
  const TahrirProSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const TahrirProSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subState = ref.watch(subscriptionProvider.select((s) => s));
    final notifier = ref.read(subscriptionProvider.notifier);

    const monthlyPrice = '₺49,99';
    const yearlyPrice = '₺249,99';
    const lifetimePrice = '₺499,99';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Üst Başlık & Tahrir Pro Rozeti
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.terracotta.withValues(alpha: 0.14),
                      AppColors.amberGold.withValues(alpha: 0.16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.amberGold.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amberGold.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '%100 CİHAZ İÇİ (OFFLINE) • SIFIR REKLAM',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tahrir Pro',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.literata(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Taranmış ağır PDF’leri, çift sütunlu makaleleri ve akademik kitapları sınır olmadan sıcak parşömen akışına dönüştürün.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Gerçek Süper Güç
              const _ProFeatureRow(
                emoji: '✨',
                title: 'Sınırsız Taranmış PDF OCR & Smart Reflow',
                subtitle:
                    '15 sayfa sınırını kaldırın; çift sütunlu ve taranmış PDF kitapları Word tarzı otomatik tashih ile akıcı metne dönüştürün.',
              ),
              const _ProFeatureRow(
                emoji: '⚡',
                title: 'Sınırsız Akıcı Fasıl, Kademeli Göz Koçu & Göz Atölyesi',
                subtitle:
                    'Günlük 1 ücretsiz fasıl sınırını kaldırın; 12–30 dk derin odak, Kademeli Bırakma (Scaffolding), yoğunluk adaptasyonu ve Göz Atölyesi kilidini açın.',
              ),
              const _ProFeatureRow(
                emoji: '🧭',
                title: 'Tam Kitap Kavram Radarı & 10 Stüdyo Ambiyansı',
                subtitle:
                    'Kitap boyunca kavram ağını indeksleyin ve 10 gerçek zamanlı DSP ambiyans sesiyle odaklanın.',
              ),
              const _ProFeatureRow(
                emoji: '🖼️',
                title: 'Filigransız 3x Alıntı Stüdyosu & Markdown İhracı',
                subtitle:
                    'Alıntı kartlarını filigransız paylaşın ve tüm notlarınızı Obsidian/Markdown olarak dışa aktarın.',
              ),
              const SizedBox(height: 12),

              // 3 Paket Kartı
              _PlanOptionCard(
                tier: TahrirPlanTier.lifetimeMuderris,
                selectedTier: subState.selectedOfferTier,
                badge: '👑 EN ÇOK TERCİH EDİLEN • ÖMÜR BOYU LİSANS',
                title: 'Ömür Boyu Pro (Tek Seferlik)',
                price: lifetimePrice,
                periodLabel: 'ömür boyu • abonelik yok',
                subtitle: 'Bir kez edinin, tüm Tahrir Pro motorlarına süresiz sahip olun.',
                onTap: () => notifier.selectOfferTier(TahrirPlanTier.lifetimeMuderris),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PlanOptionCard(
                      tier: TahrirPlanTier.yearlyPro,
                      selectedTier: subState.selectedOfferTier,
                      badge: '%58 TASARRUF',
                      title: 'Yıllık Pro',
                      price: yearlyPrice,
                      periodLabel: '/ yıl',
                      subtitle: '12 ay tam erişim',
                      compact: true,
                      onTap: () => notifier.selectOfferTier(TahrirPlanTier.yearlyPro),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PlanOptionCard(
                      tier: TahrirPlanTier.monthlyPro,
                      selectedTier: subState.selectedOfferTier,
                      badge: 'ESNEK',
                      title: 'Aylık Pro',
                      price: monthlyPrice,
                      periodLabel: '/ ay',
                      subtitle: 'İstediğin an iptal',
                      compact: true,
                      onTap: () => notifier.selectOfferTier(TahrirPlanTier.monthlyPro),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Onay / Aktivasyon Butonu
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: subState.isProcessing
                    ? null
                    : () async {
                        await notifier.activateSelectedPlan();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '👑 ${ref.read(subscriptionProvider).activeBadgeLabel} kütüphanenize tanımlandı!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.verified_outlined, size: 20),
                label: Text(
                  subState.selectedOfferTier == TahrirPlanTier.lifetimeMuderris
                      ? 'Ömür Boyu Pro Lisansı Aç ($lifetimePrice)'
                      : subState.selectedOfferTier == TahrirPlanTier.yearlyPro
                          ? 'Yıllık Pro Paketi Başlat ($yearlyPrice)'
                          : 'Aylık Pro Paketi Başlat ($monthlyPrice)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: subState.isProcessing
                        ? null
                        : () async {
                            final restored = await notifier.restorePurchases();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    restored
                                        ? '✅ Satın alımlarınız başarıyla geri yüklendi!'
                                        : 'Kayıtlı aktif bir Tahrir Pro satın alımı bulunamadı.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              if (restored) {
                                Navigator.pop(context);
                              }
                            }
                          },
                    child: Text(
                      'Satın Alımları Geri Yükle',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (subState.isPro) ...[
                TextButton(
                  onPressed: () async {
                    await notifier.resetToFreeTier();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'Mevcut Aktif Paket: ${subState.activeBadgeLabel} (Ücretsiz Moda Dön)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _ProFeatureRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  final TahrirPlanTier tier;
  final TahrirPlanTier selectedTier;
  final String badge;
  final String title;
  final String price;
  final String periodLabel;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.tier,
    required this.selectedTier,
    required this.badge,
    required this.title,
    required this.price,
    required this.periodLabel,
    required this.subtitle,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = tier == selectedTier;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.10)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.amberGold
                : theme.colorScheme.outline.withValues(alpha: 0.6),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.amberGold.withValues(alpha: 0.25)
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.literata(
                fontSize: compact ? 13.5 : 15,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    periodLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
