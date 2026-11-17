import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';

/// Opens the CueDeck Pro 3-tier Paywall + 24h Rewarded Pro Pass modal sheet.
Future<void> showCueProPaywallSheet(
  BuildContext context, {
  String? reasonMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CueProPaywallSheet(reasonMessage: reasonMessage),
  );
}

/// 3-tier Pro subscription & lifetime unlock sheet plus optional 24-hour Rewarded Pro Pass.
class CueProPaywallSheet extends ConsumerStatefulWidget {
  const CueProPaywallSheet({super.key, this.reasonMessage});

  final String? reasonMessage;

  @override
  ConsumerState<CueProPaywallSheet> createState() => _CueProPaywallSheetState();
}

class _CueProPaywallSheetState extends ConsumerState<CueProPaywallSheet> {
  CuePlanTier _selectedTier = CuePlanTier.annualTrial;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final entitlement = ref.watch(cueDeckProvider.select((s) => s.entitlement));

    final sheetBg =
        isDarkMode ? const Color(0xFF0E1017) : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF151824) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFDCE2EC);

    final lifetimeTier = entitlement.isLoyaltyDiscountUnlocked
        ? CuePlanTier.loyalty40
        : CuePlanTier.lifetime;
    final lifetimePrice = entitlement.isLoyaltyDiscountUnlocked
        ? CueProProductCatalog.priceLoyalty40Tr
        : CueProProductCatalog.priceLaunchTr;

    return Container(
      key: const Key('cue_pro_paywall_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.workspace_premium_rounded, color: goldText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CueDeck Pro — Evrensel TV Gücü',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref
                            .read(cueDeckProvider.notifier)
                            .dismissPaywallPrompt();
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.close_rounded, color: secondaryText),
                    ),
                  ],
                ),
                if (widget.reasonMessage != null &&
                    widget.reasonMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: goldText.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: goldText.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      widget.reasonMessage!,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '• Reklamsız kumanda • Sınırsız YouTube/Share-to-TV ışınlama\n'
                  '• Sınırsız izleme planı ve çoklu TV profili • Dokunmatik Touchpad',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Tier 1: Annual 3-Day Free Trial (Recommended Default)
                _PaywallTierTile(
                  key: const Key('paywall_tier_annual'),
                  selected: _selectedTier == CuePlanTier.annualTrial,
                  title: 'Yıllık Pro • 3 Gün Ücretsiz Dene',
                  subtitle: 'İstediğin an iptal et • En yüksek değer',
                  price: '${CueProProductCatalog.priceAnnualTr} / yıl',
                  badgeText: 'ÖNERİLEN • %88 TASARRUF',
                  badgeColor: mintText,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  goldText: goldText,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  onTap: () => setState(
                    () => _selectedTier = CuePlanTier.annualTrial,
                  ),
                ),
                const SizedBox(height: 8),

                // Tier 2: Lifetime One-Time Purchase
                _PaywallTierTile(
                  key: const Key('paywall_tier_lifetime'),
                  selected: _selectedTier == CuePlanTier.lifetime ||
                      _selectedTier == CuePlanTier.loyalty40,
                  title: entitlement.isLoyaltyDiscountUnlocked
                      ? 'Ömür Boyu Tek Ödeme (%40 Sadakat)'
                      : 'Ömür Boyu Tek Ödeme',
                  subtitle: 'Abonelik yok • Gelecek sürümler dahil',
                  price: lifetimePrice,
                  strikePrice: CueProProductCatalog.priceLifetimeAnchorTr,
                  badgeText: entitlement.isLoyaltyDiscountUnlocked
                      ? 'SADAKAT İNDİRİMİ'
                      : 'LANSMAN FIRSATI',
                  badgeColor: goldText,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  goldText: goldText,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  onTap: () => setState(() => _selectedTier = lifetimeTier),
                ),
                const SizedBox(height: 8),

                // Tier 3: Weekly Impulse Pack
                _PaywallTierTile(
                  key: const Key('paywall_tier_weekly'),
                  selected: _selectedTier == CuePlanTier.weekly,
                  title: 'Haftalık Acil Paket',
                  subtitle: 'Hafta sonu maç & dizi keyfi için hızlı açılım',
                  price: '${CueProProductCatalog.priceWeeklyTr} / hafta',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  goldText: goldText,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  onTap: () => setState(
                    () => _selectedTier = CuePlanTier.weekly,
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('paywall_primary_purchase_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE2A84B),
                      foregroundColor: const Color(0xFF090A0F),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _busy ? null : _handlePurchase,
                    icon: Icon(
                      _busy
                          ? Icons.hourglass_top_rounded
                          : Icons.lock_open_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _selectedTier == CuePlanTier.annualTrial
                          ? '3 Gün Ücretsiz Dene'
                          : 'Seçili Planı Başlat',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('paywall_rewarded_ad_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mintText,
                      side: BorderSide(color: mintText.withValues(alpha: 0.55)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: _busy ? null : _handleRewardedPass,
                    icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
                    label: const Text(
                      '🎬 1 Reklam İzle = 24 Saat Ücretsiz Pro Pass',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _handleRestore,
                    child: Text(
                      'Satın Alımları Geri Yükle',
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final res = await ref
        .read(cueDeckProvider.notifier)
        .purchasePlan(_selectedTier);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(res.message)));
    if (res.success) {
      ref.read(cueDeckProvider.notifier).dismissPaywallPrompt();
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRewardedPass() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final res = await ref
        .read(cueDeckProvider.notifier)
        .unlockProPassWithRewardedAd();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(res.message)));
    if (res.success) {
      ref.read(cueDeckProvider.notifier).dismissPaywallPrompt();
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRestore() async {
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final res =
        await ref.read(cueDeckProvider.notifier).restoreProPurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(res.message)));
    if (res.success) {
      ref.read(cueDeckProvider.notifier).dismissPaywallPrompt();
      Navigator.of(context).pop();
    }
  }
}

class _PaywallTierTile extends StatelessWidget {
  const _PaywallTierTile({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.cardBg,
    required this.borderColor,
    required this.goldText,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
    this.strikePrice,
    this.badgeText,
    this.badgeColor,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String price;
  final String? strikePrice;
  final String? badgeText;
  final Color? badgeColor;
  final Color cardBg;
  final Color borderColor;
  final Color goldText;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBorder = selected ? goldText : borderColor;
    final activeFill =
        selected ? goldText.withValues(alpha: 0.10) : cardBg;
    final tagColor = badgeColor ?? goldText;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activeFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activeBorder,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? goldText : secondaryText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (badgeText != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badgeText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (strikePrice != null)
                  Text(
                    strikePrice!,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 10.5,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  price,
                  style: TextStyle(
                    color: selected ? goldText : primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
