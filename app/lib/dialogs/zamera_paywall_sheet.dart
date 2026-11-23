import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/camera_colors.dart';
import '../models/app_version_info.dart';
import '../models/zamera_monetization_models.dart';
import '../services/zamera_monetization_service.dart';

/// Zero-telemetry paywall bottom sheet presenting Zamera Pro plans
/// (1-Month Free Trial Annual, Launch-Discount Lifetime, and Monthly Anchor).
class ZameraPaywallSheet extends StatefulWidget {
  final MonetizationService monetization;
  final ZameraProFeature? triggeredFeature;

  const ZameraPaywallSheet({
    super.key,
    required this.monetization,
    this.triggeredFeature,
  });

  static Future<bool?> show(
    BuildContext context, {
    required MonetizationService monetization,
    ZameraProFeature? triggeredFeature,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ZameraPaywallSheet(
        monetization: monetization,
        triggeredFeature: triggeredFeature,
      ),
    );
  }

  @override
  State<ZameraPaywallSheet> createState() => _ZameraPaywallSheetState();
}

class _ZameraPaywallSheetState extends State<ZameraPaywallSheet> {
  ZameraPlanId _selectedPlan = ZameraPlanId.annualPro;
  late bool _wasEntitledOnOpen;
  bool _poppedOnUnlock = false;

  @override
  void initState() {
    super.initState();
    _wasEntitledOnOpen = widget.monetization.hasProAccess;
    widget.monetization.addListener(_onMonetizationChanged);
    if (!widget.monetization.state.storeAvailable) {
      widget.monetization.refreshStoreOffers();
    }
  }

  @override
  void dispose() {
    widget.monetization.removeListener(_onMonetizationChanged);
    super.dispose();
  }

  void _onMonetizationChanged() {
    if (!mounted) return;
    if (!_wasEntitledOnOpen &&
        widget.monetization.hasProAccess &&
        !_poppedOnUnlock) {
      _poppedOnUnlock = true;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  bool _isTurkishLocale(BuildContext context) {
    final lang =
        Localizations.maybeLocaleOf(context)?.languageCode ??
        PlatformDispatcher.instance.locale.languageCode;
    return lang.toLowerCase().startsWith('tr');
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final uri = Uri.parse(AppVersionInfo.privacyPolicyUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gizlilik sayfası açılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.monetization.state;
    final isTr = _isTurkishLocale(context);
    final selectedOffer = state.offerFor(_selectedPlan);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PaywallHeader(onClose: () => Navigator.of(context).pop(false)),
              if (widget.triggeredFeature != null) ...<Widget>[
                const SizedBox(height: 10),
                _AhaReasonCallout(feature: widget.triggeredFeature!),
              ],
              const SizedBox(height: 12),
              const _ProFeatureChecklist(),
              const SizedBox(height: 14),
              for (final plan in ZameraPlanId.values) ...<Widget>[
                _PlanSelectorCard(
                  key: ValueKey<String>('paywall_plan_${plan.name}'),
                  plan: plan,
                  offer: state.offerFor(plan),
                  isSelected: _selectedPlan == plan,
                  isTurkish: isTr,
                  onTap: state.isBusy
                      ? null
                      : () => setState(() => _selectedPlan = plan),
                ),
                const SizedBox(height: 8),
              ],
              if (state.statusMessageTr != null &&
                  state.statusMessageTr!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  state.statusMessageTr!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: kZameraCyan,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _PaywallFooterActions(
                selectedPlan: _selectedPlan,
                selectedPriceLabel: selectedOffer.priceForLocale(
                  isTurkish: isTr,
                ),
                isBusy: state.isBusy,
                onPurchase: () =>
                    widget.monetization.purchasePlan(_selectedPlan),
                onRestore: widget.monetization.restorePurchases,
                onOpenPrivacy: _openPrivacyPolicy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PaywallHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[kIosYellow, kZameraCyan],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Zamera Pro · Gerçek Renk & Sinema',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '1 Ay Ücretsiz Dene · %100 Cihaz İçi · Sıfır Veri Takibi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kZameraCyan,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('paywall_close_btn'),
              tooltip: 'Kapat',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }
}

class _AhaReasonCallout extends StatelessWidget {
  final ZameraProFeature feature;

  const _AhaReasonCallout({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kZameraCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kZameraCyan.withValues(alpha: 0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.auto_awesome_rounded, color: kZameraCyan, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feature.titleTr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.ahaReasonTr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.3,
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

class _ProFeatureChecklist extends StatelessWidget {
  static const List<(IconData, String)> _items = <(IconData, String)>[
    (
      Icons.palette_outlined,
      'Sınırsız TrueColor ΔE₀₀ ≤ 1.0 Sanat Modu & 24-Yama Kalibrasyon',
    ),
    (
      Icons.raw_on_rounded,
      'Sınırsız 14-bit DNG RAW, 48MP ProRAW & Kayıpsız 1:1 PNG Arşivi',
    ),
    (
      Icons.content_cut_rounded,
      'Sınırsız Şeffaf / Beyaz Konturlu PNG Sticker Kesimi ve Rafı',
    ),
    (
      Icons.videocam_outlined,
      '10-Bit Apple Log / HLG10 / ProRes 422 HQ & Özel .cube 3D LUT',
    ),
  ];

  const _ProFeatureChecklist();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderDark),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < _items.length; i++) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(_items[i].$1, size: 16, color: kIosYellow),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _items[i].$2,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (i < _items.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _PlanSelectorCard extends StatelessWidget {
  final ZameraPlanId plan;
  final ZameraStoreOffer offer;
  final bool isSelected;
  final bool isTurkish;
  final VoidCallback? onTap;

  const _PlanSelectorCard({
    super.key,
    required this.plan,
    required this.offer,
    required this.isSelected,
    required this.isTurkish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = offer.priceForLocale(isTurkish: isTurkish);
    final originalText = offer.originalPriceForLocale(isTurkish: isTurkish);
    final borderColor = isSelected
        ? kIosYellow
        : (plan.isRecommended
              ? kZameraCyan.withValues(alpha: 0.45)
              : kBorderDark);

    return Material(
      color: isSelected ? kIosYellow.withValues(alpha: 0.12) : kCardDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? kIosYellow : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          plan.titleTr,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: plan.hasFreeTrial
                                ? kIosYellow
                                : kZameraCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badgeTr,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: plan.hasFreeTrial
                                  ? Colors.black
                                  : kZameraCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.subtitleTr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (originalText != null)
                    Text(
                      originalText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? kIosYellow : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallFooterActions extends StatelessWidget {
  final ZameraPlanId selectedPlan;
  final String selectedPriceLabel;
  final bool isBusy;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onOpenPrivacy;

  const _PaywallFooterActions({
    required this.selectedPlan,
    required this.selectedPriceLabel,
    required this.isBusy,
    required this.onPurchase,
    required this.onRestore,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final renewalNote = selectedPlan.hasFreeTrial
        ? 'İlk 30 gün boyunca ücret yansımaz. Memnun kalmazsanız mağaza ayarlarından tek dokunuşla iptal edebilirsiniz ($selectedPriceLabel).'
        : (selectedPlan.isLifetime
              ? 'Tek seferlik $selectedPriceLabel ödeme ile abonelik olmadan ömür boyu Zamera Pro erişimi.'
              : '$selectedPriceLabel aylık plan; dilediğiniz an mağaza ayarlarından iptal edilebilir.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          key: const ValueKey<String>('paywall_primary_cta_btn'),
          style: FilledButton.styleFrom(
            backgroundColor: kIosYellow,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isBusy ? null : onPurchase,
          child: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  selectedPlan.ctaLabelTr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          renewalNote,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.white54,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: <Widget>[
            TextButton(
              key: const ValueKey<String>('paywall_restore_btn'),
              onPressed: isBusy ? null : onRestore,
              child: const Text(
                'Satın Alımları Geri Yükle',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kZameraCyan,
                ),
              ),
            ),
            const Text('·', style: TextStyle(color: Colors.white24)),
            TextButton(
              onPressed: onOpenPrivacy,
              child: const Text(
                'Gizlilik (Sıfır Takip)',
                style: TextStyle(fontSize: 11.5, color: Colors.white60),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
