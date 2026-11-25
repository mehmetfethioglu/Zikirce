import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/subscription_provider.dart';

/// Tahrir Pro paywall & 3-ad rewarded unlock modal.
/// Always dismissible (App Store compliant): users may close the popup at any time
/// to continue in Basic mode (PDF reading + Daily Reading Streak), watch 3 rewarded ads
/// for 24h full Pro access, or choose Weekly/Monthly/Yearly/Lifetime Pro.
class TahrirProSheet extends ConsumerStatefulWidget {
  final bool isEntryPrompt;

  const TahrirProSheet({
    super.key,
    this.isEntryPrompt = false,
  });

  static Future<void> show(
    BuildContext context, {
    bool isEntryPrompt = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TahrirProSheet(isEntryPrompt: isEntryPrompt),
    );
  }

  @override
  ConsumerState<TahrirProSheet> createState() => _TahrirProSheetState();
}

class _TahrirProSheetState extends ConsumerState<TahrirProSheet> {
  bool _didAutoDismiss = false;

  String _purchaseButtonLabel(TahrirPlanTier tier, String price) {
    switch (tier) {
      case TahrirPlanTier.weeklyPro:
        return 'Haftalık Pro Başlat ($price)';
      case TahrirPlanTier.monthlyPro:
        return 'Aylık Pro Başlat ($price)';
      case TahrirPlanTier.yearlyPro:
        return 'Yıllık Pro Başlat ($price)';
      case TahrirPlanTier.lifetimeMuderris:
        return 'Ömür Boyu Pro Lisansı Aç ($price)';
      case TahrirPlanTier.free:
        return 'Tahrir Pro Başlat';
    }
  }

  Future<void> _onRewardedAdPressed() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final result = await notifier.watchRewardedAdFor24hPro();
    if (!mounted) return;
    if (result.success && result.entitlement.hasProAccess()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _onPurchasePressed() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final result = await notifier.purchaseSelectedPlan();
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      if (!widget.isEntryPrompt && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _onRestorePressed() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final result = await notifier.restorePurchases();
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      if (!widget.isEntryPrompt && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      subscriptionProvider.select((s) => s.isPro),
      (previous, next) {
        if (widget.isEntryPrompt &&
            previous == false &&
            next == true &&
            !_didAutoDismiss &&
            mounted) {
          _didAutoDismiss = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
      },
    );

    final theme = Theme.of(context);
    final subState = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);

    final weeklyMeta =
        TahrirProProductCatalog.metadataFor(TahrirPlanTier.weeklyPro)!;
    final monthlyMeta =
        TahrirProProductCatalog.metadataFor(TahrirPlanTier.monthlyPro)!;
    final yearlyMeta =
        TahrirProProductCatalog.metadataFor(TahrirPlanTier.yearlyPro)!;
    final lifetimeMeta =
        TahrirProProductCatalog.metadataFor(TahrirPlanTier.lifetimeMuderris)!;

    final weeklyPrice = subState.priceForTier(TahrirPlanTier.weeklyPro);
    final monthlyPrice = subState.priceForTier(TahrirPlanTier.monthlyPro);
    final yearlyPrice = subState.priceForTier(TahrirPlanTier.yearlyPro);
    final lifetimePrice =
        subState.priceForTier(TahrirPlanTier.lifetimeMuderris);
    final selectedPrice = subState.priceForTier(subState.selectedOfferTier);
    final isBusy = subState.isProcessing || subState.isWatchingRewardedAd;

    return PopScope(
      canPop: true,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                const SizedBox(height: 12),
                _ProHeroHeader(
                  isEntryPrompt: widget.isEntryPrompt,
                  subState: subState,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 14),
                _RewardedPassCard(
                  isBusy: isBusy,
                  isWatching: subState.isWatchingRewardedAd,
                  isPassActive: subState.isRewardedProPassActive,
                  watchProgress: subState.rewardedAdProgress,
                  requiredAds:
                      TahrirProProductCatalog.rewardedAdsRequiredFor24hPro,
                  activeBadgeLabel: subState.activeBadgeLabel,
                  onWatchAd: _onRewardedAdPressed,
                ),
                if (subState.lastStatusMessage != null &&
                    subState.lastStatusMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InlineStatusBanner(message: subState.lastStatusMessage!),
                ],
                const SizedBox(height: 16),
                Text(
                  'Abonelik & Ömür Boyu Seçenekler',
                  style: GoogleFonts.literata(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _PlanOptionCard(
                  tier: TahrirPlanTier.lifetimeMuderris,
                  selectedTier: subState.selectedOfferTier,
                  badge: lifetimeMeta.badge,
                  title: lifetimeMeta.title,
                  price: lifetimePrice,
                  periodLabel: lifetimeMeta.periodLabel,
                  subtitle: lifetimeMeta.subtitle,
                  onTap: () => notifier.selectOfferTier(
                    TahrirPlanTier.lifetimeMuderris,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PlanOptionCard(
                        tier: TahrirPlanTier.yearlyPro,
                        selectedTier: subState.selectedOfferTier,
                        badge: yearlyMeta.badge,
                        title: yearlyMeta.title,
                        price: yearlyPrice,
                        periodLabel: yearlyMeta.periodLabel,
                        subtitle: yearlyMeta.subtitle,
                        compact: true,
                        onTap: () => notifier.selectOfferTier(
                          TahrirPlanTier.yearlyPro,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PlanOptionCard(
                        tier: TahrirPlanTier.monthlyPro,
                        selectedTier: subState.selectedOfferTier,
                        badge: monthlyMeta.badge,
                        title: monthlyMeta.title,
                        price: monthlyPrice,
                        periodLabel: monthlyMeta.periodLabel,
                        subtitle: monthlyMeta.subtitle,
                        compact: true,
                        onTap: () => notifier.selectOfferTier(
                          TahrirPlanTier.monthlyPro,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PlanOptionCard(
                  tier: TahrirPlanTier.weeklyPro,
                  selectedTier: subState.selectedOfferTier,
                  badge: weeklyMeta.badge,
                  title: weeklyMeta.title,
                  price: weeklyPrice,
                  periodLabel: weeklyMeta.periodLabel,
                  subtitle: weeklyMeta.subtitle,
                  compact: true,
                  onTap: () =>
                      notifier.selectOfferTier(TahrirPlanTier.weeklyPro),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isBusy ? null : _onPurchasePressed,
                  icon: subState.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.verified_outlined, size: 20),
                  label: Text(
                    _purchaseButtonLabel(
                      subState.selectedOfferTier,
                      selectedPrice,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Temel Modda Devam Et (Sadece PDF & Günlük Seri)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: isBusy ? null : _onRestorePressed,
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
                Text(
                  'Temel modda sadece Orijinal PDF okuma ve Günlük Seri ücretsizdir. Abonelikler dönem bitiminden en az 24 saat önce iptal edilmedikçe Google Play / App Store hesabınız üzerinden yenilenir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 16),
                const _ProFeatureRow(
                  emoji: '✨',
                  title: 'Akıllı Reflow, EPUB/TXT/MD, 300 DPI OCR & Zemberek',
                  subtitle:
                      'Çift sütunlu ve taranmış PDF kitapları, EPUB/Markdown dosyalarını temiz parşömen akışında okuyun.',
                ),
                const _ProFeatureRow(
                  emoji: '⚡',
                  title: 'Hızlı Okuma, Akıcı Fasıl, Göz Atölyesi & Bionic Odak',
                  subtitle:
                      '60 sn kavram ısınması, 2–4 kelimelik fasıl koçu, Piramit, Takistoskop, Schulte matrisi ve WPM ölçümü.',
                ),
                const _ProFeatureRow(
                  emoji: '📝',
                  title: 'Notlar, Haşiye, Popup Lügat, Obsidian & QR Paylaşım',
                  subtitle:
                      'Derkenar notları, Klasik Lügat, 3x Alıntı Stüdyosu, JSON Yedekleme, Kavram Radarı ve AI Özet.',
                ),
                const _ProFeatureRow(
                  emoji: '🎧',
                  title: 'Sesli Okuma (TTS), Ambiyans, Tema, Isı Haritası & Widget',
                  subtitle:
                      'Kelime takibiyle TTS, 10 stüdyo ambiyansı, özel temalar/fontlar, Isı Haritası ve ana ekran widget’ı.',
                ),
                if (kDebugMode) ...[
                  const Divider(height: 20),
                  TextButton(
                    onPressed: () async {
                      await notifier.debugSimulate24hExpired();
                    },
                    child: Text(
                      '🧪 [Debug QA] 24 Saati Dolmuş Simüle Et',
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
      ),
    );
  }
}

class _ProHeroHeader extends StatelessWidget {
  final bool isEntryPrompt;
  final SubscriptionState subState;
  final VoidCallback onClose;

  const _ProHeroHeader({
    required this.isEntryPrompt,
    required this.subState,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amberGold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BANNER REKLAMSIZ • İLK 24 SAAT ÜCRETSİZ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                tooltip: 'Kapat ve Temel Modda Devam Et',
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEntryPrompt
                ? '24 Saatlik Ücretsiz Pro Süreniz Doldu'
                : 'Tahrir Pro',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEntryPrompt
                ? 'Temel kullanımda Orijinal PDF okuma ve Günlük Seri ücretsiz devam eder. Tüm Pro araçlar için 3 ödüllü reklam izleyerek 24 saat Pro açabilir veya paket seçebilirsiniz.'
                : 'Temel modda sadece Orijinal PDF okuma ve Günlük Seri ücretsizdir; Reflow, OCR, Hızlı Okuma, Notlar, Lügat, Ses ve Yedekleme Pro ile açılır.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.2,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          if (subState.isPro) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Aktif Durum: ${subState.activeBadgeLabel}',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardedPassCard extends StatelessWidget {
  final bool isBusy;
  final bool isWatching;
  final bool isPassActive;
  final int watchProgress;
  final int requiredAds;
  final String activeBadgeLabel;
  final VoidCallback onWatchAd;

  const _RewardedPassCard({
    required this.isBusy,
    required this.isWatching,
    required this.isPassActive,
    required this.watchProgress,
    required this.requiredAds,
    required this.activeBadgeLabel,
    required this.onWatchAd,
  });

  String _buttonText() {
    if (isWatching) return 'Tam Ekran Reklam Yükleniyor...';
    if (watchProgress <= 0) {
      return '1. Reklamı İzle (0/$requiredAds) → 24 Saat Pro';
    }
    if (watchProgress == 1) {
      return '2. Reklamı İzle (1/$requiredAds) → 2 Reklam Kaldı';
    }
    return 'Son Reklamı İzle ($watchProgress/$requiredAds) → 24 Saat Pro Aç';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.amberGold.withValues(alpha: 0.65),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amberGold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ondemand_video_rounded,
                  size: 22,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24 Saat Ücretsiz Pro ($requiredAds Ödüllü Reklam)',
                      style: GoogleFonts.literata(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPassActive
                          ? 'Aktif: $activeBadgeLabel'
                          : 'Banner reklam yok! $requiredAds tam ekran ödüllü reklam izleyerek 24 saat boyunca tüm Pro özelliklerini ücretsiz kullanın.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.35,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPassActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < requiredAds; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < watchProgress
                            ? AppColors.terracotta
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i < requiredAds - 1) const SizedBox(width: 6),
                ],
                const SizedBox(width: 10),
                Text(
                  '$watchProgress / $requiredAds Reklam',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.terracotta,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.terracotta,
              side: BorderSide(
                color: AppColors.terracotta.withValues(alpha: 0.8),
                width: 1.3,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isBusy ? null : onWatchAd,
            icon: isWatching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_filled_rounded, size: 20),
            label: Text(
              _buttonText(),
              style: GoogleFonts.inter(
                fontSize: 12.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatusBanner extends StatelessWidget {
  final String message;

  const _InlineStatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
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
