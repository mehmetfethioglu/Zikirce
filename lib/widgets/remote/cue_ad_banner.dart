import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../providers/cuedeck_providers.dart';

/// Non-intrusive bottom ad banner displayed only when the user has not unlocked
/// CueDeck Pro Lifetime or the 24-hour Rewarded Pro Pass.
class CueNonIntrusiveAdBanner extends ConsumerStatefulWidget {
  const CueNonIntrusiveAdBanner({
    super.key,
    this.showQuickRemoveAction = false,
  });

  final bool showQuickRemoveAction;

  @override
  ConsumerState<CueNonIntrusiveAdBanner> createState() =>
      _CueNonIntrusiveAdBannerState();
}

class _CueNonIntrusiveAdBannerState
    extends ConsumerState<CueNonIntrusiveAdBanner> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAndLoadBanner();
  }

  Future<void> _initAndLoadBanner() async {
    if (!CueAdMobConfig.isNativeMobileAdsSupported) return;
    final monetization = ref.read(cueMonetizationServiceProvider);
    await monetization.ensureAdsInitialized();
    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: CueAdMobConfig.activeBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isBannerLoaded = false;
          });
        },
      ),
    );
    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPro = ref.watch(cueDeckProvider.select((s) => s.hasProAccess));
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    if (hasPro) return const SizedBox.shrink();

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: goldText.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'REKLAM',
                    style: TextStyle(
                      color: goldText,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CueDeck Ücretsiz • Reklamsız deneyim için Pro\'ya geçin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                if (widget.showQuickRemoveAction) ...<Widget>[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .unlockProPassWithRewardedAd();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF0A0C12),
                            content: Text(
                              res.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: goldText.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🎬 24s Kaldır',
                        style: TextStyle(
                          color: goldText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_isBannerLoaded && _bannerAd != null) ...<Widget>[
              const SizedBox(height: 5),
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
