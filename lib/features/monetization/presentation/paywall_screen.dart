import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/subscription_service.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onScanGranted;

  const PaywallScreen({super.key, this.onScanGranted});

  static Future<void> show(BuildContext context, {VoidCallback? onScanGranted}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallScreen(onScanGranted: onScanGranted),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  Duration _remainingAdFree = Duration.zero;
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
    _loadStatus();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final remaining = await SubscriptionService.instance.getRemainingAdFreeDuration();
    final badge = await SubscriptionService.instance.getVolunteerBadge();
    if (mounted) {
      setState(() {
        _remainingAdFree = remaining;
        _badgeInfo = badge;
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      return '${d.inDays} Gün ${d.inHours % 24} Saat';
    } else if (d.inHours > 0) {
      return '${d.inHours} Saat ${d.inMinutes % 60} Dakika';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes} Dakika';
    } else {
      return 'Reklamlı Mod Aktif';
    }
  }

  Future<void> _watchRewardedAd() async {
    setState(() => _isLoading = true);
    final bool isAvailable = SubscriptionService.instance.isRewardedAdAvailable;

    if (!isAvailable) {
      SubscriptionService.instance.loadRewardedAd();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam hazırlanıyor, lütfen 3-5 saniye sonra tekrar deneyin.')),
        );
      }
      return;
    }

    final bool shown = await SubscriptionService.instance.showRewardedAd(
      onRewardGranted: () async {
        await SubscriptionService.instance.addAdFreeHours(6);
        await _loadStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 Harika! +6 Saat Reklamsız Kullanım Tanımlandı!'),
              backgroundColor: AppColors.primaryEmerald,
            ),
          );
        }
      },
    );

    setState(() => _isLoading = false);
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reklam gösterilemedi, lütfen tekrar deneyin.')),
      );
    }
  }

  void _openContributionModal() {
    Navigator.pop(context);
    CrowdsourceDialog.showProductContributionModal(context);
  }

  void _showPromoCodeModal() {
    _promoController.clear();
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    showDialog(
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
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gönüllü tester veya kampanya kodunuzu girerek ek reklamsız süre kazanabilirsiniz:',
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
                fillColor: isDark ? AppColors.amoledBackground : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.primaryEmerald, width: 1.5),
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
              final res = await SubscriptionService.instance.redeemPromoCode(code);
              await _loadStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.status == PromoCodeStatus.success
                        ? AppColors.primaryEmerald
                        : AppColors.dangerRed,
                  ),
                );
              }
            },
            child: const Text('Aktifleştir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentlyAdFree = _remainingAdFree > Duration.zero;
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          left: BorderSide(color: borderColor, width: 1),
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Title Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.4 : 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded, color: AppColors.primaryEmerald, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '100% ÜCRETSİZ & TOPLULUK DESTEKLİ',
                          style: TextStyle(
                            color: AppColors.primaryEmerald,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                'Gönüllü & Reklamsız Merkez',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'OrganicScore\'da tüm barkod ve OCR taramaları sınırsızdır. Abonelik veya gizli ücret yoktur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Status Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCurrentlyAdFree
                        ? [
                            AppColors.primaryEmerald.withValues(alpha: isDark ? 0.20 : 0.12),
                            AppColors.primaryEmerald.withValues(alpha: isDark ? 0.05 : 0.04),
                          ]
                        : [
                            isDark ? AppColors.amoledSurface : const Color(0xFFF8FAFC),
                            isDark ? AppColors.amoledSurface.withValues(alpha: 0.7) : const Color(0xFFF1F5F9),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrentlyAdFree
                        ? AppColors.primaryEmerald.withValues(alpha: isDark ? 0.4 : 0.3)
                        : borderColor,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCurrentlyAdFree
                                ? AppColors.primaryEmerald.withValues(alpha: isDark ? 0.2 : 0.15)
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.15)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              isCurrentlyAdFree ? Icons.shield_rounded : Icons.info_outline_rounded,
                              color: isCurrentlyAdFree
                                  ? AppColors.primaryEmerald
                                  : (isDark ? Colors.orangeAccent : const Color(0xFFD97706)),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentlyAdFree ? 'Kalan Reklamsız Süreniz' : 'Mevcut Durum',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDuration(_remainingAdFree),
                                style: TextStyle(
                                  color: isCurrentlyAdFree ? AppColors.primaryEmerald : textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(color: borderColor, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(_badgeInfo.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gönüllü Rozeti', style: TextStyle(color: textSecondary, fontSize: 11)),
                                Text(
                                  _badgeInfo.title,
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            '${_badgeInfo.totalContributions} Katkı',
                            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Cards Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reklamsız Süre Kazanın',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),

              // Action 1: Crowdsource / Photograph Incomplete Label
              InkWell(
                onTap: _openContributionModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.amoledSurface : surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.3 : 0.4),
                      width: 1.2,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.15 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryEmerald, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Eksik Ürün Etiketi Çek',
                                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryEmerald,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '5 ÜRÜNDE +24 SAAT',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Markette eksik bir ürünün arkasını fotoğraflayın. Her 5 ürün katkınızda +24 saat reklamsız kullanım kazanın.',
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: textSecondary),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_badgeInfo.totalContributions % 5) / 5.0,
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_badgeInfo.totalContributions % 5} / 5 Ürün',
                            style: const TextStyle(
                              color: AppColors.primaryEmerald,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 2: Rewarded Video Ad (+6 Hours Ad-Free)
              InkWell(
                onTap: _isLoading ? null : _watchRewardedAd,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.amoledSurface : surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.play_circle_filled_rounded,
                          color: isDark ? Colors.orangeAccent : const Color(0xFFD97706),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Kısa Reklam İzle',
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.orangeAccent : const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+6 SAAT',
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ürün çekme imkanınız yoksa 1 kısa video izleyerek reklamsız sürenizi uzatın.',
                              style: TextStyle(color: textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.chevron_right_rounded, color: textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Promo Code & Return
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _showPromoCodeModal,
                    icon: Icon(Icons.vpn_key_outlined, size: 16, color: textSecondary),
                    label: Text('Tester / Promosyon Kodu Gir', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.amoledSurface : const Color(0xFFF1F5F9),
                    foregroundColor: textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: borderColor),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScanGranted?.call();
                  },
                  child: Text(
                    'Taramaya Devam Et',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
