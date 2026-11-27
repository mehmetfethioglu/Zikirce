import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';
import '../domain/kilerce_pro_models.dart';
import '../domain/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onScanGranted;
  final KilerceEntitlementSnapshot? initialEntitlement;
  final String? reasonMessage;

  const PaywallScreen({
    super.key,
    this.onScanGranted,
    this.initialEntitlement,
    this.reasonMessage,
  });

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onScanGranted,
    KilerceEntitlementSnapshot? initialEntitlement,
    String? reasonMessage,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PaywallScreen(
          onScanGranted: onScanGranted,
          initialEntitlement: initialEntitlement,
          reasonMessage: reasonMessage,
        ),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  bool _proUnlocked = false;
  Duration _remainingAdFree = Duration.zero;
  int _adProgress = 0;
  int _dailyPassesUsed = 0;
  int _dailyPassesLimit = 2;
  KilercePlanTier _selectedTier = KilercePlanTier.yearly;
  Map<KilercePlanTier, String> _planPrices = {
    for (final t in KilercePlanTier.values) t: t.fallbackPrice,
  };
  VolunteerBadgeInfo _badgeInfo = const VolunteerBadgeInfo(
    rank: VolunteerDetectiveRank.novice,
    title: 'Gıda Gönüllüsü',
    emoji: '🌱',
    totalContributions: 0,
  );
  Timer? _countdownTimer;
  final TextEditingController _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adProgress = widget.initialEntitlement?.adProgress ?? 0;
    _dailyPassesUsed = widget.initialEntitlement?.dailyRewardPassesUsed ?? 0;
    _dailyPassesLimit = widget.initialEntitlement?.dailyRewardPassesLimit ?? 2;
    _loadStatus();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadStatus(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final results = await Future.wait<dynamic>([
      SubscriptionService.instance.getRemainingAdFreeDuration(),
      SubscriptionService.instance.getVolunteerBadge(),
      SubscriptionService.instance.getRewardAdProgress(),
      SubscriptionService.instance.getLocalizedPlanPrices(),
      SubscriptionService.instance.isAdFree(),
      SubscriptionService.instance.getDailyRewardPassesUsed(),
    ]);
    if (!mounted) return;
    setState(() {
      _remainingAdFree = results[0] as Duration;
      _badgeInfo = results[1] as VolunteerBadgeInfo;
      _adProgress = results[2] as int;
      _planPrices = results[3] as Map<KilercePlanTier, String>;
      _proUnlocked = results[4] as bool;
      _dailyPassesUsed = results[5] as int;
    });
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 300) return 'Ömür Boyu / Pro Aktif';
    if (d.inDays > 0) return '${d.inDays} Gün ${d.inHours % 24} Saat';
    if (d.inHours > 0) return '${d.inHours} Saat ${d.inMinutes % 60} Dakika';
    if (d.inMinutes > 0) return '${d.inMinutes} Dakika';
    return 'Ücretsiz Plan (Günde 5 Tarif)';
  }

  Future<void> _watchRewardedAd() async {
    if (_dailyPassesUsed >= _dailyPassesLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bugünkü $_dailyPassesLimit/$_dailyPassesLimit reklamlı Pro hakkınızı kullandınız. Yarın yenilenir veya Pro pakete geçebilirsiniz.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final bool isAvailable = SubscriptionService.instance.isRewardedAdAvailable;

    if (!isAvailable) {
      SubscriptionService.instance.loadRewardedAd();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ödüllü reklam hazırlanıyor, lütfen 3-5 saniye sonra tekrar dokunun.',
            ),
          ),
        );
      }
      return;
    }

    final bool shown = await SubscriptionService.instance.showRewardedAd(
      onRewardGranted: () async {
        if (mounted) setState(() => _isLoading = true);
        final step = await SubscriptionService.instance.recordRewardedAdStep();
        await _loadStatus();
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (step.dailyLimitReached) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bugünkü ${step.dailyPassesLimit}/${step.dailyPassesLimit} reklamlı Pro hakkınız doldu.',
              ),
            ),
          );
        } else if (step.unlockedPro3h) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 3/3 Reklam tamamlandı! +3 Saat Kilerce Pro aktif (Bugün ${step.dailyPassesUsed}/${step.dailyPassesLimit}).',
              ),
              backgroundColor: AppColors.primaryEmerald,
            ),
          );
          if (widget.reasonMessage != null && mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${step.progress}/${step.required} reklam tamamlandı! 3 saat Pro için ${step.required - step.progress} reklam kaldı.',
              ),
              backgroundColor: AppColors.primaryMint,
            ),
          );
        }
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!shown) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam gösterilemedi, tekrar deneyin.')),
        );
      }
    }
  }

  Future<void> _purchaseSelectedTier() async {
    setState(() => _isLoading = true);
    final result = await SubscriptionService.instance.purchaseProTier(_selectedTier);
    await _loadStatus();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.userCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? AppColors.primaryEmerald : AppColors.dangerRed,
        ),
      );
    }
    if (result.success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final result = await SubscriptionService.instance.restoreProPurchases();
    await _loadStatus();
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppColors.primaryEmerald : AppColors.cautionGold,
      ),
    );
    if (result.success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _openContributionModal() {
    Navigator.pop(context, _proUnlocked);
    CrowdsourceDialog.showProductContributionModal(context);
  }

  void _showPromoCodeModal() {
    _promoController.clear();
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.vpn_key_rounded, color: AppColors.primaryEmerald),
            const SizedBox(width: 8),
            Text(
              'Promosyon / Tester Kodu',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gönüllü tester veya kampanya kodunuzu girerek Pro erişimi açabilirsiniz:',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promoController,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Örn: TESTER2026',
                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor:
                    isDark ? AppColors.amoledBackground : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide:
                      BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = _promoController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              if (mounted) setState(() => _isLoading = true);
              final res = await SubscriptionService.instance.redeemPromoCode(code);
              await _loadStatus();
              if (!mounted) return;
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.status == PromoCodeStatus.success
                      ? AppColors.primaryEmerald
                      : AppColors.dangerRed,
                ),
              );
              if (res.status == PromoCodeStatus.success && mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text(
              'Aktifleştir',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentlyAdFree = _remainingAdFree > Duration.zero || _proUnlocked;
    final isDark = context.isDarkMode;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Kilerce Pro & Ödül Merkezi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context, _proUnlocked);
            widget.onScanGranted?.call();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald
                      .withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryEmerald
                        .withValues(alpha: isDark ? 0.45 : 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: AppColors.primaryEmerald, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'KİLERCE PRO & ÖDÜL MERKEZİ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primaryEmerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '23.933+ Tarifin Tamamını Açın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reasonMessage?.trim().isNotEmpty == true
                    ? widget.reasonMessage!
                    : 'Sınırsız adım adım tarifler, kiler eşleştirme ve reklamsız deneyim için 3 kısa reklam izleyin veya Pro plan seçin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Active Pro Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrentlyAdFree
                      ? AppColors.primaryEmerald.withValues(alpha: 0.12)
                      : (isDark
                          ? AppColors.amoledSurface
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrentlyAdFree
                        ? AppColors.primaryEmerald.withValues(alpha: 0.45)
                        : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCurrentlyAdFree
                          ? Icons.verified_rounded
                          : Icons.shield_outlined,
                      color: isCurrentlyAdFree
                          ? AppColors.primaryEmerald
                          : AppColors.cautionGold,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCurrentlyAdFree
                                ? 'Pro Erişimi Aktif'
                                : 'Mevcut Plan',
                            style:
                                TextStyle(color: textSecondary, fontSize: 11.5),
                          ),
                          Text(
                            _formatDuration(_remainingAdFree),
                            style: TextStyle(
                              color: isCurrentlyAdFree
                                  ? AppColors.primaryEmerald
                                  : textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_badgeInfo.emoji} ${_badgeInfo.totalContributions}',
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3 Rewarded Ads = 3 Hours Pro (Max 2x/day)
              InkWell(
                onTap: _isLoading ? null : _watchRewardedAd,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cautionGold.withValues(alpha: 0.16),
                        AppColors.primaryEmerald.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.cautionGold.withValues(alpha: 0.5),
                      width: 1.3,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_circle_filled_rounded,
                              color: AppColors.cautionGold, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ücretsiz: 3 Reklam İzle → 3 Saat Pro',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dailyPassesUsed >= _dailyPassesLimit
                                      ? 'Bugünkü $_dailyPassesLimit/$_dailyPassesLimit reklamlı Pro hakkınızı doldurdunuz.'
                                      : 'Günde 2 kez 3 kısa reklamla 23.933+ tarif ve reklamsız erişim açılır (Bugün: $_dailyPassesUsed/$_dailyPassesLimit).',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (int i = 0; i < 3; i++)
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i < _adProgress
                                      ? AppColors.primaryEmerald
                                      : textSecondary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Text(
                            '$_adProgress / 3',
                            style: const TextStyle(
                              color: AppColors.primaryEmerald,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subscription Tiers (RevenueCat)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kilerce Pro Paketleri',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...KilercePlanTier.values.map((tier) {
                final selected = _selectedTier == tier;
                final price = _planPrices[tier] ?? tier.fallbackPrice;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedTier = tier),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryEmerald.withValues(alpha: 0.12)
                            : (isDark ? AppColors.amoledSurface : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryEmerald
                              : borderColor,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppColors.primaryEmerald
                                : textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      tier.title,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    if (tier.isPopular)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryEmerald,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'EN AVANTAJLI',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  tier.subtitle,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            price,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primaryEmerald
                                  : textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _purchaseSelectedTier,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '${_selectedTier.title} Başlat (${_planPrices[_selectedTier] ?? _selectedTier.fallbackPrice})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Volunteer Crowdsource Contribution
              InkWell(
                onTap: _openContributionModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner_rounded,
                          color: AppColors.primaryEmerald, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Eksik Ürün Etiketi Çek (5 üründe +24 Saat Pro • ${_badgeInfo.totalContributions % 5}/5)',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading ? null : _restorePurchases,
                    icon: Icon(Icons.restore_rounded,
                        size: 16, color: textSecondary),
                    label: Text(
                      'Satın Alımları Geri Yükle',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showPromoCodeModal,
                    icon: Icon(Icons.vpn_key_outlined,
                        size: 16, color: textSecondary),
                    label: Text(
                      'Promosyon / Tester Kodu',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context, _proUnlocked);
                    widget.onScanGranted?.call();
                  },
                  child: Text(
                    'Şimdilik Kapat',
                    style: TextStyle(
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
