import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-specific Google AdMob App IDs & Ad Unit IDs.
/// - Android uses Google's official Test Ad Unit IDs during Closed Testing to
///   strictly comply with AdMob Invalid Traffic (IVT) policies.
/// - iOS uses the official production CueDeck AdMob App ID and Ad Unit IDs.
class CueAdMobConfig {
  CueAdMobConfig._();

  // Android Closed Testing Official Google Test IDs
  static const String androidTestAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String androidTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String androidTestRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // iOS Production CueDeck AdMob IDs
  static const String iosProdAppId =
      'ca-app-pub-8040358402439788~5365691448';
  static const String iosProdBannerUnitId =
      'ca-app-pub-8040358402439788/7325640375';
  static const String iosProdRewardedUnitId =
      'ca-app-pub-8040358402439788/1390787414';

  /// True when running on a real Android or iOS device/emulator (outside `flutter test`).
  static bool get isNativeMobileAdsSupported {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Active Banner Ad Unit ID for the current platform.
  static String get activeBannerUnitId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return iosProdBannerUnitId;
    }
    return androidTestBannerUnitId;
  }

  /// Active Rewarded Video Ad Unit ID for the current platform.
  static String get activeRewardedUnitId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return iosProdRewardedUnitId;
    }
    return androidTestRewardedUnitId;
  }
}

/// Product SKU identifiers and regional pricing tiers for CueDeck Pro (Lifetime IAP).
class CueProProductCatalog {
  CueProProductCatalog._();

  /// Standard one-time lifetime Pro unlock SKU.
  static const String skuProLifetime = 'cuedeck_pro_lifetime';

  /// 40% Loyalty discount SKU unlocked after 10 distinct days of Rewarded Pro Pass usage.
  static const String skuProLoyalty40 = 'cuedeck_pro_loyalty_40';

  /// Maximum number of active custom watch plans in the Free tier (when Pro Pass is inactive).
  static const int maxFreeWatchPlans = 2;

  /// Maximum number of saved TV profiles in the Free tier.
  static const int maxFreeTvProfiles = 1;

  /// Number of distinct rewarded ad days required to unlock the 40% loyalty discount SKU.
  static const int loyaltyDiscountTargetDays = 10;

  /// Duration granted by watching 1 optional rewarded video ad ("24 Saatlik Pro Pass").
  static const Duration rewardedProPassDuration = Duration(hours: 24);

  /// Minimum cooldown between rewarded ad extensions to prevent AdMob Invalid Traffic (IVT).
  static const Duration rewardedAdCooldown = Duration(hours: 4);

  /// Standard price display in Turkish Lira (`149,99 ₺` standard, `89,99 ₺` with 40% Loyalty Discount).
  static const String priceStandardTr = '149,99 ₺';
  static const String priceLaunchTr = '149,99 ₺';
  static const String priceLoyalty40Tr = '89,99 ₺';

  /// Global Tier-1 USD price display.
  static const String priceStandardUsd = '\$5.99';
  static const String priceLaunchUsd = '\$5.99';
  static const String priceLoyalty40Usd = '\$3.49';
}

/// Immutable snapshot of the user's monetization and Pro entitlement state.
@immutable
class CueEntitlementState {
  const CueEntitlementState({
    this.isProLifetime = false,
    this.purchasedSku = '',
    this.purchaseEpochMs = 0,
    this.proPassExpiresEpochMs = 0,
    this.lastRewardedAdEpochMs = 0,
    this.rewardedDays = const <String>[],
  });

  final bool isProLifetime;
  final String purchasedSku;
  final int purchaseEpochMs;
  final int proPassExpiresEpochMs;
  final int lastRewardedAdEpochMs;
  final List<String> rewardedDays;

  /// True if the 24-hour Rewarded Pro Pass is currently active at [now].
  bool isProPassActive([DateTime? now]) {
    if (proPassExpiresEpochMs <= 0) return false;
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return proPassExpiresEpochMs > currentMs;
  }

  /// True if the user has full Pro access (either Lifetime Pro OR active 24h Pro Pass).
  bool hasProAccess([DateTime? now]) =>
      isProLifetime || isProPassActive(now);

  /// Remaining duration on the 24-hour Pro Pass, or [Duration.zero] if expired.
  Duration remainingProPassDuration([DateTime? now]) {
    if (proPassExpiresEpochMs <= 0) return Duration.zero;
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final diffMs = proPassExpiresEpochMs - currentMs;
    if (diffMs <= 0) return Duration.zero;
    return Duration(milliseconds: diffMs);
  }

  /// Formatted remaining time for the 24-hour Pro Pass (e.g., "23s 45dk").
  String formattedRemainingProPass([DateTime? now]) {
    final rem = remainingProPassDuration(now);
    if (rem <= Duration.zero) return 'Süresi doldu';
    final hours = rem.inHours;
    final mins = rem.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}s ${mins}dk kaldı';
    }
    return '${mins}dk kaldı';
  }

  /// Number of distinct days the user has unlocked a 24h Pro Pass via Rewarded Ad.
  int get rewardedDaysCount => rewardedDays.length;

  /// True when the user has unlocked the 40% Loyalty Discount (`89,99 ₺` / `$3.49`).
  bool get isLoyaltyDiscountUnlocked =>
      rewardedDays.length >= CueProProductCatalog.loyaltyDiscountTargetDays;

  /// Progress ratio (0.0 .. 1.0) toward the 10-day Loyalty Discount.
  double get loyaltyProgressRatio =>
      (rewardedDays.length / CueProProductCatalog.loyaltyDiscountTargetDays)
          .clamp(0.0, 1.0);

  /// Active one-time Pro price label based on loyalty status.
  String get activePriceLabelTr => isLoyaltyDiscountUnlocked
      ? '${CueProProductCatalog.priceLoyalty40Tr} (%40 Sadakat İndirimi)'
      : '${CueProProductCatalog.priceStandardTr} (Tek Seferlik Ömür Boyu)';

  /// Active SKU identifier for one-time purchase.
  String get activeProductSku => isLoyaltyDiscountUnlocked
      ? CueProProductCatalog.skuProLoyalty40
      : CueProProductCatalog.skuProLifetime;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'isProLifetime': isProLifetime,
        'purchasedSku': purchasedSku,
        'purchaseEpochMs': purchaseEpochMs,
        'proPassExpiresEpochMs': proPassExpiresEpochMs,
        'lastRewardedAdEpochMs': lastRewardedAdEpochMs,
        'rewardedDays': rewardedDays,
      };

  factory CueEntitlementState.fromJson(Map<String, dynamic> json) {
    final rawDays = json['rewardedDays'];
    final parsedDays = rawDays is List
        ? rawDays
            .whereType<String>()
            .where((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d))
            .toSet()
            .toList()
        : const <String>[];

    return CueEntitlementState(
      isProLifetime: (json['isProLifetime'] as bool?) ?? false,
      purchasedSku: (json['purchasedSku'] as String?) ?? '',
      purchaseEpochMs: (json['purchaseEpochMs'] as int?) ?? 0,
      proPassExpiresEpochMs: (json['proPassExpiresEpochMs'] as int?) ?? 0,
      lastRewardedAdEpochMs: (json['lastRewardedAdEpochMs'] as int?) ?? 0,
      rewardedDays: parsedDays,
    );
  }
}

/// Result of a Pro purchase, restore, or Rewarded 24h Pro Pass operation.
@immutable
class MonetizationActionResult {
  const MonetizationActionResult({
    required this.success,
    required this.message,
    required this.entitlement,
  });

  final bool success;
  final String message;
  final CueEntitlementState entitlement;
}

/// Manages Free vs. Pro entitlements, `AndroidKeyStore` AES-256-GCM encrypted
/// entitlement persistence, SHA-256 tamper protection, real Google AdMob
/// `RewardedAd` / `BannerAd` lifecycle, and official Google Play Billing /
/// Apple StoreKit 2 (`in_app_purchase`) Lifetime Pro unlocks.
class CueMonetizationService {
  static const MethodChannel _storageChannel = MethodChannel(
    'com.akarworks.cuedeck/storage',
  );

  // Bumped to v3 so any simulated/accidental Pro state from earlier test builds is cleared.
  static const String _kVaultPrefsKey = 'cuedeck_entitlement_vault_v3';
  static const String _kIntegritySalt =
      'CueDeck_Akarworks_v1.9_Entitlement_Seal_2026';

  static bool _adsInitialized = false;
  RewardedAd? _preloadedRewardedAd;
  bool _isPreloadingRewardedAd = false;

  /// Initializes the Google Mobile Ads SDK once on Android/iOS.
  Future<void> ensureAdsInitialized() async {
    if (_adsInitialized || !CueAdMobConfig.isNativeMobileAdsSupported) return;
    try {
      await MobileAds.instance.initialize();
      _adsInitialized = true;
      unawaited(preloadRewardedAd());
    } catch (_) {}
  }

  /// Preloads a `RewardedAd` in the background so tapping "24 Saat Ücretsiz Aç"
  /// launches the video ad with zero delay.
  Future<void> preloadRewardedAd() async {
    if (!CueAdMobConfig.isNativeMobileAdsSupported) return;
    if (_preloadedRewardedAd != null || _isPreloadingRewardedAd) return;
    _isPreloadingRewardedAd = true;
    try {
      await ensureAdsInitialized();
      await RewardedAd.load(
        adUnitId: CueAdMobConfig.activeRewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _preloadedRewardedAd = ad;
            _isPreloadingRewardedAd = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _preloadedRewardedAd = null;
            _isPreloadingRewardedAd = false;
          },
        ),
      );
    } catch (_) {
      _isPreloadingRewardedAd = false;
    }
  }

  /// Disposes any preloaded rewarded ad instance.
  void dispose() {
    _preloadedRewardedAd?.dispose();
    _preloadedRewardedAd = null;
  }

  /// Computes a canonical SHA-256 integrity seal over the entitlement fields
  /// so plain-text tampering is rejected even if KeyStore is unavailable in tests.
  static String computeIntegrityHash(CueEntitlementState state) {
    final sortedDays = List<String>.from(state.rewardedDays)..sort();
    final canonical =
        '$_kIntegritySalt|pro:${state.isProLifetime}|sku:${state.purchasedSku}|'
        'ts:${state.purchaseEpochMs}|pass:${state.proPassExpiresEpochMs}|'
        'lastAd:${state.lastRewardedAdEpochMs}|days:${sortedDays.join(",")}';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Formats a [DateTime] as `YYYY-MM-DD` for distinct-day loyalty tracking.
  static String formatDayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Loads and verifies the user's entitlement state from encrypted storage.
  Future<CueEntitlementState> loadEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kVaultPrefsKey);
      if (stored == null || stored.isEmpty) {
        return const CueEntitlementState();
      }

      String? jsonStr;
      if (stored.startsWith('{')) {
        jsonStr = stored;
      } else {
        try {
          jsonStr = await _storageChannel.invokeMethod<String>(
            'decryptSecret',
            <String, dynamic>{'cipherText': stored},
          );
        } catch (_) {
          jsonStr = null;
        }
      }

      if (jsonStr == null || jsonStr.isEmpty) {
        return const CueEntitlementState();
      }

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final savedSeal = (decoded['seal'] as String?) ?? '';
      final parsed = CueEntitlementState.fromJson(decoded);
      final expectedSeal = computeIntegrityHash(parsed);
      if (savedSeal != expectedSeal) {
        // Tampered entitlement payload detected; reset to safe Free state
        return const CueEntitlementState();
      }
      return parsed;
    } catch (_) {
      return const CueEntitlementState();
    }
  }

  /// Persists the entitlement state with SHA-256 seal and `AndroidKeyStore` encryption.
  Future<void> saveEntitlement(CueEntitlementState entitlement) async {
    try {
      final payloadMap = <String, dynamic>{
        ...entitlement.toJson(),
        'seal': computeIntegrityHash(entitlement),
      };
      final rawJson = jsonEncode(payloadMap);

      String toStore = rawJson;
      try {
        final encrypted = await _storageChannel.invokeMethod<String>(
          'encryptSecret',
          <String, dynamic>{'plainText': rawJson},
        );
        if (encrypted != null && encrypted.isNotEmpty) {
          toStore = encrypted;
        }
      } catch (_) {
        // Fallback to SHA-256 sealed JSON in headless test environments
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kVaultPrefsKey, toStore);
    } catch (_) {}
  }

  /// Loads and presents a real full-screen Google AdMob `RewardedAd` on Android/iOS,
  /// and ONLY grants the 24-hour Pro Pass after `onUserEarnedReward` fires.
  Future<MonetizationActionResult> watchRewardedAdAndUnlockProPass({
    required CueEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (current.isProLifetime) {
      return MonetizationActionResult(
        success: true,
        message: '💎 Ömür Boyu CueDeck Pro zaten aktif!',
        entitlement: current,
      );
    }

    // Frequency cap guard: prevent ad-farming loops (AdMob IVT protection)
    if (current.lastRewardedAdEpochMs > 0) {
      final elapsedMs =
          currentTime.millisecondsSinceEpoch - current.lastRewardedAdEpochMs;
      if (elapsedMs >= 0 &&
          elapsedMs < CueProProductCatalog.rewardedAdCooldown.inMilliseconds &&
          current.isProPassActive(currentTime)) {
        return MonetizationActionResult(
          success: false,
          message:
              '⏳ 24 Saatlik Pro Pass zaten aktif (${current.formattedRemainingProPass(currentTime)}).',
          entitlement: current,
        );
      }
    }

    // In headless unit/widget tests, delegate directly to deterministic state logic
    if (!CueAdMobConfig.isNativeMobileAdsSupported) {
      return grantRewardedProPass(current: current, now: currentTime);
    }

    await ensureAdsInitialized();

    RewardedAd? adToShow = _preloadedRewardedAd;
    _preloadedRewardedAd = null;

    if (adToShow == null) {
      final loadCompleter = Completer<RewardedAd?>();
      String? loadErrorMsg;

      await RewardedAd.load(
        adUnitId: CueAdMobConfig.activeRewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (!loadCompleter.isCompleted) loadCompleter.complete(ad);
          },
          onAdFailedToLoad: (LoadAdError error) {
            loadErrorMsg = error.message;
            if (!loadCompleter.isCompleted) loadCompleter.complete(null);
          },
        ),
      );

      adToShow = await loadCompleter.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );

      if (adToShow == null) {
        return MonetizationActionResult(
          success: false,
          message:
              '⚠️ Reklam videosu yüklenemedi (${loadErrorMsg ?? "Zaman aşımı"}). Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
          entitlement: current,
        );
      }
    }

    bool userEarnedReward = false;
    final showCompleter = Completer<void>();

    adToShow.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        if (!showCompleter.isCompleted) showCompleter.complete();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        if (!showCompleter.isCompleted) showCompleter.complete();
      },
    );

    await adToShow.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        userEarnedReward = true;
      },
    );

    await showCompleter.future;
    unawaited(preloadRewardedAd());

    if (!userEarnedReward) {
      return MonetizationActionResult(
        success: false,
        message:
            '⚠️ 24 Saatlik Pro Pass kazanmak için reklam videosunu sonuna kadar izlemelisiniz.',
        entitlement: current,
      );
    }

    return grantRewardedProPass(current: current, now: DateTime.now());
  }

  /// Grants a 24-hour "CueDeck Pro Pass" after watching a Rewarded Video Ad,
  /// enforcing AdMob Invalid Traffic (IVT) frequency capping and recording the
  /// distinct calendar day toward the 10-day 40% Loyalty Discount.
  Future<MonetizationActionResult> grantRewardedProPass({
    required CueEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (current.isProLifetime) {
      return MonetizationActionResult(
        success: true,
        message: '💎 Ömür Boyu CueDeck Pro zaten aktif!',
        entitlement: current,
      );
    }

    // Frequency cap guard: prevent ad-farming loops (AdMob IVT protection)
    if (current.lastRewardedAdEpochMs > 0) {
      final elapsedMs =
          currentTime.millisecondsSinceEpoch - current.lastRewardedAdEpochMs;
      if (elapsedMs >= 0 &&
          elapsedMs < CueProProductCatalog.rewardedAdCooldown.inMilliseconds &&
          current.isProPassActive(currentTime)) {
        return MonetizationActionResult(
          success: false,
          message:
              '⏳ 24 Saatlik Pro Pass zaten aktif (${current.formattedRemainingProPass(currentTime)}).',
          entitlement: current,
        );
      }
    }

    final dayKey = formatDayKey(currentTime);
    final updatedDays = <String>{...current.rewardedDays, dayKey}.toList()
      ..sort();
    final expiresAt = currentTime.add(
      CueProProductCatalog.rewardedProPassDuration,
    );

    final updated = CueEntitlementState(
      isProLifetime: false,
      purchasedSku: current.purchasedSku,
      purchaseEpochMs: current.purchaseEpochMs,
      proPassExpiresEpochMs: expiresAt.millisecondsSinceEpoch,
      lastRewardedAdEpochMs: currentTime.millisecondsSinceEpoch,
      rewardedDays: updatedDays,
    );

    await saveEntitlement(updated);

    final loyaltyMsg = updated.isLoyaltyDiscountUnlocked
        ? '🎉 %40 Sadakat İndirimi (${CueProProductCatalog.priceLoyalty40Tr}) kilidi açıldı!'
        : 'Sadakat İlerlemesi: ${updated.rewardedDaysCount}/${CueProProductCatalog.loyaltyDiscountTargetDays} gün';

    return MonetizationActionResult(
      success: true,
      message:
          '🎬 24 Saatlik CueDeck Pro Pass aktif edildi! ($loyaltyMsg)',
      entitlement: updated,
    );
  }

  /// Resets the current Pro Pass / Pro state back to the Free Ad-Supported state
  /// (while preserving accumulated `rewardedDays` loyalty progress) so the user
  /// can test Banner & Rewarded Video Ads anytime without waiting 24 hours.
  Future<MonetizationActionResult> resetEntitlementToFree({
    required CueEntitlementState current,
  }) async {
    final resetState = CueEntitlementState(
      isProLifetime: false,
      purchasedSku: '',
      purchaseEpochMs: 0,
      proPassExpiresEpochMs: 0,
      lastRewardedAdEpochMs: 0,
      rewardedDays: current.rewardedDays,
    );
    await saveEntitlement(resetState);
    unawaited(preloadRewardedAd());
    return MonetizationActionResult(
      success: true,
      message:
          '🔄 Ücretsiz (Reklamlı) sürüme dönüldü. Alt bar reklamı ve ödüllü video reklam tekrar aktif.',
      entitlement: resetState,
    );
  }

  /// Initiates a real Google Play Billing / Apple StoreKit 2 (`InAppPurchase`)
  /// non-consumable purchase for `cuedeck_pro_lifetime` (`149,99 ₺`) or
  /// `cuedeck_pro_loyalty_40` (`89,99 ₺`).
  Future<MonetizationActionResult> purchaseLifetimePro({
    required CueEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final sku = current.activeProductSku;

    // On real Android/iOS devices, require real Google Play / App Store billing confirmation
    if (CueAdMobConfig.isNativeMobileAdsSupported) {
      try {
        final iap = InAppPurchase.instance;
        final available = await iap.isAvailable();
        if (!available) {
          return MonetizationActionResult(
            success: false,
            message:
                '⚠️ Google Play / App Store ödeme servisine şu anda ulaşılamıyor.',
            entitlement: current,
          );
        }

        final response = await iap.queryProductDetails(<String>{
          sku,
          CueProProductCatalog.skuProLifetime,
        });

        if (response.productDetails.isEmpty) {
          return MonetizationActionResult(
            success: false,
            message:
                'ℹ️ "$sku" (${CueProProductCatalog.priceStandardTr}) ürünü mağaza konsolunda yayınlandığında ödeme ekranı açılacaktır.',
            entitlement: current,
          );
        }

        final product = response.productDetails.firstWhere(
          (p) => p.id == sku,
          orElse: () => response.productDetails.first,
        );

        final purchaseCompleter = Completer<PurchaseDetails?>();
        StreamSubscription<List<PurchaseDetails>>? sub;
        sub = iap.purchaseStream.listen(
          (List<PurchaseDetails> purchases) async {
            for (final p in purchases) {
              if (p.pendingCompletePurchase) {
                await iap.completePurchase(p);
              }
              if (p.status == PurchaseStatus.purchased ||
                  p.status == PurchaseStatus.restored) {
                if (!purchaseCompleter.isCompleted) {
                  purchaseCompleter.complete(p);
                }
              } else if (p.status == PurchaseStatus.error ||
                  p.status == PurchaseStatus.canceled) {
                if (!purchaseCompleter.isCompleted) {
                  purchaseCompleter.complete(null);
                }
              }
            }
          },
          onError: (_) {
            if (!purchaseCompleter.isCompleted) {
              purchaseCompleter.complete(null);
            }
          },
        );

        final param = PurchaseParam(productDetails: product);
        final launched = await iap.buyNonConsumable(purchaseParam: param);
        if (!launched) {
          await sub.cancel();
          return MonetizationActionResult(
            success: false,
            message: '⚠️ Mağaza satın alma penceresi başlatılamadı.',
            entitlement: current,
          );
        }

        final verifiedPurchase = await purchaseCompleter.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () => null,
        );
        await sub.cancel();

        if (verifiedPurchase == null) {
          return MonetizationActionResult(
            success: false,
            message: 'ℹ️ Satın alma işlemi iptal edildi veya tamamlanmadı.',
            entitlement: current,
          );
        }
      } catch (e) {
        return MonetizationActionResult(
          success: false,
          message: '⚠️ Mağaza ödeme hatası: $e',
          entitlement: current,
        );
      }
    }

    final updated = CueEntitlementState(
      isProLifetime: true,
      purchasedSku: sku,
      purchaseEpochMs: currentTime.millisecondsSinceEpoch,
      proPassExpiresEpochMs: current.proPassExpiresEpochMs,
      lastRewardedAdEpochMs: current.lastRewardedAdEpochMs,
      rewardedDays: current.rewardedDays,
    );

    await saveEntitlement(updated);

    return MonetizationActionResult(
      success: true,
      message:
          '💎 CueDeck Pro (Ömür Boyu) aktif edildi! Tüm reklamlar kaldırıldı ve bulut senkronizasyonu açıldı.',
      entitlement: updated,
    );
  }

  /// Restores a previously purchased Lifetime Pro entitlement.
  Future<MonetizationActionResult> restorePurchases({
    required CueEntitlementState current,
  }) async {
    final loaded = await loadEntitlement();
    if (loaded.isProLifetime) {
      return MonetizationActionResult(
        success: true,
        message: '✓ Ömür Boyu CueDeck Pro lisansınız geri yüklendi.',
        entitlement: loaded,
      );
    }
    return MonetizationActionResult(
      success: false,
      message: 'Bu cihazda veya kasada kayıtlı Pro satın alımı bulunamadı.',
      entitlement: current,
    );
  }
}
