import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tahrir_entitlement_models.dart';
import 'tahrir_admob_config.dart';

/// Dependency Inversion contract for Tahrir monetization & entitlement operations.
abstract class TahrirMonetizationGateway {
  /// Returns localized store prices indexed by SKU when loaded from Play/App Store.
  Map<String, String> get localizedPricesBySku;

  /// Loads and verifies the SHA-256 sealed entitlement from local storage,
  /// initializing the 24-hour first-install trial on initial launch.
  Future<TahrirEntitlementState> loadEntitlement({DateTime? now});

  /// Persists the SHA-256 sealed entitlement snapshot.
  Future<void> saveEntitlement(TahrirEntitlementState entitlement);

  /// Initializes store billing stream and fetches live product metadata.
  Future<void> initializeStore({
    required void Function(TahrirEntitlementState updated, String message)
        onStoreEntitlementUpdate,
    required void Function(String message) onStoreError,
  });

  /// Initializes Google Mobile Ads SDK once on supported mobile targets.
  Future<void> ensureAdsInitialized();

  /// Preloads a single full-screen Rewarded Ad without recursive error loops.
  Future<void> preloadRewardedAd();

  /// Presents a full-screen Rewarded Ad and grants a 24-hour Pro Pass ONLY
  /// after `onUserEarnedReward` fires.
  Future<TahrirMonetizationResult> watchRewardedAdAndUnlockProPass({
    required TahrirEntitlementState current,
    DateTime? now,
  });

  /// Grants a deterministic 24-hour Rewarded Pro Pass with IVT 4-hour cooldown.
  Future<TahrirMonetizationResult> grantRewardedProPass({
    required TahrirEntitlementState current,
    DateTime? now,
  });

  /// Starts a real Google Play Billing / Apple StoreKit 2 purchase flow.
  Future<TahrirMonetizationResult> purchaseTier({
    required TahrirPlanTier tier,
    required TahrirEntitlementState current,
    DateTime? now,
  });

  /// Restores prior active store purchases or sealed local entitlements.
  Future<TahrirMonetizationResult> restorePurchases({
    required TahrirEntitlementState current,
    DateTime? now,
  });

  /// Releases native ad handles and cancels active purchase stream subscriptions.
  void dispose();
}

/// Concrete AdMob (Rewarded Only, Zero Banners) + Store IAP + SHA-256 Vault service.
class TahrirMonetizationService implements TahrirMonetizationGateway {
  static const String vaultPrefsKey = 'tahrir_entitlement_vault_v2';
  static const String _integritySalt =
      'Tahrir_Akarworks_v1.15_Entitlement_Seal_2026';

  static bool _adsInitialized = false;

  RewardedAd? _preloadedRewardedAd;
  bool _isPreloadingRewardedAd = false;
  bool _storeInitialized = false;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, ProductDetails> _productsBySku = <String, ProductDetails>{};
  final Map<String, String> _localizedPricesBySku = <String, String>{};

  void Function(TahrirEntitlementState updated, String message)?
      _onStoreEntitlementUpdate;
  void Function(String message)? _onStoreError;
  Completer<TahrirEntitlementState?>? _pendingPurchaseCompleter;
  Completer<TahrirEntitlementState?>? _pendingRestoreCompleter;
  TahrirEntitlementState _latestKnownEntitlement =
      const TahrirEntitlementState();

  @override
  Map<String, String> get localizedPricesBySku =>
      Map<String, String>.unmodifiable(_localizedPricesBySku);

  /// Computes a canonical SHA-256 signature over all entitlement fields.
  static String computeIntegritySignature(String payloadJson) {
    return sha256.convert(utf8.encode('$_integritySalt|$payloadJson')).toString();
  }

  /// State returned when tampered storage is detected so hard paywall cannot be bypassed.
  static const TahrirEntitlementState _tamperedFallbackState =
      TahrirEntitlementState(firstInstallEpochMs: 1);

  @override
  Future<TahrirEntitlementState> loadEntitlement({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(vaultPrefsKey);

      if (stored == null || stored.isEmpty) {
        final initial = TahrirEntitlementState(
          firstInstallEpochMs: currentTime.millisecondsSinceEpoch,
        );
        await saveEntitlement(initial);
        _latestKnownEntitlement = initial;
        return initial;
      }

      final envelope = jsonDecode(stored);
      if (envelope is! Map<String, dynamic>) {
        _latestKnownEntitlement = _tamperedFallbackState;
        return _tamperedFallbackState;
      }

      final payloadStr = envelope['payload'];
      final savedSig = envelope['sig'];
      if (payloadStr is! String || savedSig is! String) {
        _latestKnownEntitlement = _tamperedFallbackState;
        return _tamperedFallbackState;
      }

      final expectedSig = computeIntegritySignature(payloadStr);
      if (savedSig != expectedSig) {
        debugPrint('TahrirMonetizationService: entitlement signature mismatch');
        _latestKnownEntitlement = _tamperedFallbackState;
        return _tamperedFallbackState;
      }

      final decodedPayload = jsonDecode(payloadStr);
      if (decodedPayload is! Map<String, dynamic>) {
        _latestKnownEntitlement = _tamperedFallbackState;
        return _tamperedFallbackState;
      }

      final parsed = TahrirEntitlementState.fromJson(decodedPayload);
      if (parsed.firstInstallEpochMs <= 0) {
        final normalized = parsed.copyWith(
          firstInstallEpochMs: currentTime.millisecondsSinceEpoch,
        );
        await saveEntitlement(normalized);
        _latestKnownEntitlement = normalized;
        return normalized;
      }

      _latestKnownEntitlement = parsed;
      return parsed;
    } catch (e) {
      debugPrint('TahrirMonetizationService loadEntitlement error: $e');
      _latestKnownEntitlement = _tamperedFallbackState;
      return _tamperedFallbackState;
    }
  }

  @override
  Future<void> saveEntitlement(TahrirEntitlementState entitlement) async {
    try {
      final payloadJson = jsonEncode(entitlement.toJson());
      final envelope = <String, dynamic>{
        'payload': payloadJson,
        'sig': computeIntegritySignature(payloadJson),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(vaultPrefsKey, jsonEncode(envelope));
      _latestKnownEntitlement = entitlement;
    } catch (e) {
      debugPrint('TahrirMonetizationService saveEntitlement error: $e');
    }
  }

  @override
  Future<void> initializeStore({
    required void Function(TahrirEntitlementState updated, String message)
        onStoreEntitlementUpdate,
    required void Function(String message) onStoreError,
  }) async {
    _onStoreEntitlementUpdate = onStoreEntitlementUpdate;
    _onStoreError = onStoreError;

    if (!TahrirAdMobConfig.isNativeMobileAdsSupported || _storeInitialized) {
      return;
    }

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        debugPrint('TahrirMonetizationService: Store billing unavailable.');
        return;
      }

      await _purchaseSubscription?.cancel();
      _purchaseSubscription = iap.purchaseStream.listen(
        (purchases) => unawaited(_handlePurchaseUpdates(purchases)),
        onError: (Object error) {
          debugPrint('TahrirMonetizationService purchaseStream error: $error');
          _onStoreError?.call('Mağaza akışı hatası: $error');
          if (_pendingPurchaseCompleter != null &&
              !_pendingPurchaseCompleter!.isCompleted) {
            _pendingPurchaseCompleter!.complete(null);
          }
          if (_pendingRestoreCompleter != null &&
              !_pendingRestoreCompleter!.isCompleted) {
            _pendingRestoreCompleter!.complete(null);
          }
        },
      );

      final response = await iap.queryProductDetails(
        TahrirProProductCatalog.allSkus,
      );
      _productsBySku.clear();
      _localizedPricesBySku.clear();
      for (final product in response.productDetails) {
        _productsBySku[product.id] = product;
        _localizedPricesBySku[product.id] = product.price;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'TahrirMonetizationService missing store SKUs: ${response.notFoundIDs.join(', ')}',
        );
      }
      _storeInitialized = true;
    } catch (e) {
      debugPrint('TahrirMonetizationService initializeStore error: $e');
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final iap = InAppPurchase.instance;
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final updated = _applyStoreSkuEntitlement(
            current: _latestKnownEntitlement,
            sku: purchase.productID,
            now: DateTime.now(),
          );
          if (updated != null) {
            await saveEntitlement(updated);
            final metadata = TahrirProProductCatalog.metadataFor(
              TahrirProProductCatalog.tierForSku(purchase.productID),
            );
            final label = metadata?.title ?? 'Tahrir Pro';
            final msg = purchase.status == PurchaseStatus.restored
                ? '✅ $label satın alımınız geri yüklendi!'
                : '👑 $label kütüphanenize tanımlandı!';
            _onStoreEntitlementUpdate?.call(updated, msg);

            if (purchase.status == PurchaseStatus.purchased &&
                _pendingPurchaseCompleter != null &&
                !_pendingPurchaseCompleter!.isCompleted) {
              _pendingPurchaseCompleter!.complete(updated);
            }
            if (_pendingRestoreCompleter != null &&
                !_pendingRestoreCompleter!.isCompleted) {
              _pendingRestoreCompleter!.complete(updated);
            }
          }
        } else if (purchase.status == PurchaseStatus.error) {
          final errMsg =
              purchase.error?.message ?? 'Satın alma işlemi tamamlanamadı.';
          _onStoreError?.call('⚠️ Ödeme hatası: $errMsg');
          if (_pendingPurchaseCompleter != null &&
              !_pendingPurchaseCompleter!.isCompleted) {
            _pendingPurchaseCompleter!.complete(null);
          }
        } else if (purchase.status == PurchaseStatus.canceled) {
          _onStoreError?.call('ℹ️ Satın alma işlemi iptal edildi.');
          if (_pendingPurchaseCompleter != null &&
              !_pendingPurchaseCompleter!.isCompleted) {
            _pendingPurchaseCompleter!.complete(null);
          }
        }

        if (purchase.pendingCompletePurchase) {
          await iap.completePurchase(purchase);
        }
      } catch (e) {
        debugPrint('TahrirMonetizationService _handlePurchaseUpdates error: $e');
      }
    }
  }

  TahrirEntitlementState? _applyStoreSkuEntitlement({
    required TahrirEntitlementState current,
    required String sku,
    required DateTime now,
  }) {
    final tier = TahrirProProductCatalog.tierForSku(sku);
    if (tier == TahrirPlanTier.free) {
      return null;
    }
    final metadata = TahrirProProductCatalog.metadataFor(tier);
    if (metadata == null) {
      return null;
    }

    final nowMs = now.millisecondsSinceEpoch;
    final expiresMs = metadata.isLifetime
        ? 0
        : now
            .add(metadata.subscriptionDuration ?? const Duration(days: 31))
            .millisecondsSinceEpoch;

    return current.copyWith(
      isProLifetime: metadata.isLifetime || current.isProLifetime,
      activePaidTier:
          current.isProLifetime ? TahrirPlanTier.lifetimeMuderris : tier,
      purchasedSku: sku,
      purchaseEpochMs: nowMs,
      subscriptionExpiresEpochMs: expiresMs,
    );
  }

  @override
  Future<void> ensureAdsInitialized() async {
    if (_adsInitialized || !TahrirAdMobConfig.isNativeMobileAdsSupported) return;
    try {
      await MobileAds.instance.initialize();
      _adsInitialized = true;
    } catch (e) {
      debugPrint('TahrirMonetizationService AdMob init error: $e');
    }
  }

  @override
  Future<void> preloadRewardedAd() async {
    if (!TahrirAdMobConfig.isNativeMobileAdsSupported) return;
    if (_preloadedRewardedAd != null || _isPreloadingRewardedAd) return;

    _isPreloadingRewardedAd = true;
    try {
      await ensureAdsInitialized();
      await RewardedAd.load(
        adUnitId: TahrirAdMobConfig.activeRewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _preloadedRewardedAd = ad;
            _isPreloadingRewardedAd = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint(
              'TahrirMonetizationService RewardedAd preload failed: ${error.message}',
            );
            _preloadedRewardedAd = null;
            _isPreloadingRewardedAd = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('TahrirMonetizationService preloadRewardedAd error: $e');
      _isPreloadingRewardedAd = false;
    }
  }

  @override
  Future<TahrirMonetizationResult> watchRewardedAdAndUnlockProPass({
    required TahrirEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (current.isSubscriptionActive(currentTime)) {
      return TahrirMonetizationResult(
        success: true,
        message: '👑 Aktif Tahrir Pro aboneliğiniz zaten mevcut!',
        entitlement: current,
      );
    }

    final cooldownResult = _checkRewardedCooldown(current, currentTime);
    if (cooldownResult != null) {
      return cooldownResult;
    }

    if (!TahrirAdMobConfig.isNativeMobileAdsSupported) {
      return grantRewardedProPass(current: current, now: currentTime);
    }

    await ensureAdsInitialized();

    RewardedAd? adToShow = _preloadedRewardedAd;
    _preloadedRewardedAd = null;

    if (adToShow == null) {
      final loadCompleter = Completer<RewardedAd?>();
      String? loadErrorMsg;

      try {
        await RewardedAd.load(
          adUnitId: TahrirAdMobConfig.activeRewardedUnitId,
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
      } catch (e) {
        loadErrorMsg = e.toString();
        if (!loadCompleter.isCompleted) loadCompleter.complete(null);
      }

      adToShow = await loadCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );

      if (adToShow == null) {
        return TahrirMonetizationResult(
          success: false,
          message:
              '⚠️ Ödüllü reklam yüklenemedi (${loadErrorMsg ?? "Zaman aşımı"}). İnternet bağlantınızı kontrol edip tekrar deneyin.',
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
        debugPrint('RewardedAd show error: ${error.message}');
        ad.dispose();
        if (!showCompleter.isCompleted) showCompleter.complete();
      },
    );

    try {
      await adToShow.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          userEarnedReward = true;
        },
      );
      await showCompleter.future;
    } catch (e) {
      debugPrint('TahrirMonetizationService RewardedAd show exception: $e');
      return TahrirMonetizationResult(
        success: false,
        message: '⚠️ Ödüllü reklam gösterilirken hata oluştu: $e',
        entitlement: current,
      );
    }

    unawaited(preloadRewardedAd());

    if (!userEarnedReward) {
      return TahrirMonetizationResult(
        success: false,
        message:
            '⚠️ Bu adımı tamamlamak için reklam videosunu sonuna kadar izlemelisiniz (${current.rewardedAdWatchProgress}/${TahrirProProductCatalog.rewardedAdsRequiredFor24hPro}).',
        entitlement: current,
      );
    }

    return grantRewardedProPass(current: current, now: DateTime.now());
  }

  TahrirMonetizationResult? _checkRewardedCooldown(
    TahrirEntitlementState current,
    DateTime currentTime,
  ) {
    if (current.lastRewardedAdEpochMs <= 0) return null;
    final elapsedMs =
        currentTime.millisecondsSinceEpoch - current.lastRewardedAdEpochMs;
    if (elapsedMs >= 0 &&
        elapsedMs < TahrirProProductCatalog.rewardedAdCooldown.inMilliseconds &&
        current.isProPassActive(currentTime)) {
      final rem = TahrirEntitlementState.formatRemaining(
        current.remainingProPass(currentTime),
      );
      return TahrirMonetizationResult(
        success: false,
        message: '⏳ 24 Saatlik Pro Pass zaten aktif ($rem kaldı).',
        entitlement: current,
      );
    }
    return null;
  }

  @override
  Future<TahrirMonetizationResult> grantRewardedProPass({
    required TahrirEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (current.isSubscriptionActive(currentTime)) {
      return TahrirMonetizationResult(
        success: true,
        message: '👑 Aktif Tahrir Pro aboneliğiniz zaten mevcut!',
        entitlement: current,
      );
    }

    final cooldownResult = _checkRewardedCooldown(current, currentTime);
    if (cooldownResult != null) {
      return cooldownResult;
    }

    const requiredAds = TahrirProProductCatalog.rewardedAdsRequiredFor24hPro;
    final nextProgress = current.rewardedAdWatchProgress + 1;

    if (nextProgress < requiredAds) {
      final remaining = requiredAds - nextProgress;
      final updated = current.copyWith(
        rewardedAdWatchProgress: nextProgress,
        lastRewardedAdEpochMs: currentTime.millisecondsSinceEpoch,
      );
      await saveEntitlement(updated);

      return TahrirMonetizationResult(
        success: true,
        message:
            '🎬 $nextProgress/$requiredAds reklam tamamlandı! 24 saatlik Pro için $remaining reklam daha izleyin.',
        entitlement: updated,
      );
    }

    final expiresAt = currentTime.add(
      TahrirProProductCatalog.rewardedProPassDuration,
    );
    final updated = current.copyWith(
      rewardedAdWatchProgress: 0,
      proPassExpiresEpochMs: expiresAt.millisecondsSinceEpoch,
      lastRewardedAdEpochMs: currentTime.millisecondsSinceEpoch,
    );
    await saveEntitlement(updated);

    return TahrirMonetizationResult(
      success: true,
      message: '🎉 $requiredAds/$requiredAds reklam tamamlandı! 24 Saatlik Tahrir Pro erişimi açıldı!',
      entitlement: updated,
    );
  }

  @override
  Future<TahrirMonetizationResult> purchaseTier({
    required TahrirPlanTier tier,
    required TahrirEntitlementState current,
    DateTime? now,
  }) async {
    if (tier == TahrirPlanTier.free) {
      return TahrirMonetizationResult(
        success: false,
        message: 'Lütfen geçerli bir Pro paketi seçin.',
        entitlement: current,
      );
    }

    final metadata = TahrirProProductCatalog.metadataFor(tier);
    if (metadata == null) {
      return TahrirMonetizationResult(
        success: false,
        message: 'Seçilen paket katalogda bulunamadı.',
        entitlement: current,
      );
    }

    final currentTime = now ?? DateTime.now();

    if (!TahrirAdMobConfig.isNativeMobileAdsSupported) {
      final updated = _applyStoreSkuEntitlement(
        current: current,
        sku: metadata.sku,
        now: currentTime,
      );
      if (updated == null) {
        return TahrirMonetizationResult(
          success: false,
          message: 'Paket etkinleştirilemedi.',
          entitlement: current,
        );
      }
      await saveEntitlement(updated);
      return TahrirMonetizationResult(
        success: true,
        message: '👑 ${metadata.title} etkinleştirildi!',
        entitlement: updated,
      );
    }

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        return TahrirMonetizationResult(
          success: false,
          message:
              '⚠️ Google Play / App Store ödeme servisine şu anda ulaşılamıyor.',
          entitlement: current,
        );
      }

      ProductDetails? product = _productsBySku[metadata.sku];
      if (product == null) {
        final response = await iap.queryProductDetails(<String>{metadata.sku});
        if (response.productDetails.isNotEmpty) {
          product = response.productDetails.first;
          _productsBySku[product.id] = product;
          _localizedPricesBySku[product.id] = product.price;
        }
      }

      if (product == null) {
        return TahrirMonetizationResult(
          success: false,
          message:
              'ℹ️ "${metadata.sku}" (${metadata.fallbackPriceTr}) ürünü mağaza konsolunda henüz aktif değil. Dilerseniz 24 saatlik ödüllü reklam ile Pro\'yu ücretsiz açabilirsiniz.',
          entitlement: current,
        );
      }

      _pendingPurchaseCompleter = Completer<TahrirEntitlementState?>();
      final launched = await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) {
        _pendingPurchaseCompleter = null;
        return TahrirMonetizationResult(
          success: false,
          message: '⚠️ Mağaza satın alma penceresi başlatılamadı.',
          entitlement: current,
        );
      }

      final verified = await _pendingPurchaseCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
      _pendingPurchaseCompleter = null;

      if (verified == null) {
        return TahrirMonetizationResult(
          success: false,
          message: 'ℹ️ Satın alma işlemi tamamlanmadı veya iptal edildi.',
          entitlement: current,
        );
      }

      return TahrirMonetizationResult(
        success: true,
        message: '👑 ${metadata.title} kütüphanenize tanımlandı!',
        entitlement: verified,
      );
    } catch (e) {
      _pendingPurchaseCompleter = null;
      debugPrint('TahrirMonetizationService purchaseTier error: $e');
      return TahrirMonetizationResult(
        success: false,
        message: '⚠️ Mağaza ödeme hatası: $e',
        entitlement: current,
      );
    }
  }

  @override
  Future<TahrirMonetizationResult> restorePurchases({
    required TahrirEntitlementState current,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();

    if (TahrirAdMobConfig.isNativeMobileAdsSupported) {
      try {
        final iap = InAppPurchase.instance;
        final available = await iap.isAvailable();
        if (available) {
          _pendingRestoreCompleter = Completer<TahrirEntitlementState?>();
          await iap.restorePurchases();
          final restored = await _pendingRestoreCompleter!.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
          _pendingRestoreCompleter = null;
          if (restored != null && restored.isSubscriptionActive(currentTime)) {
            return TahrirMonetizationResult(
              success: true,
              message: '✅ Satın alımlarınız başarıyla geri yüklendi!',
              entitlement: restored,
            );
          }
        }
      } catch (e) {
        _pendingRestoreCompleter = null;
        debugPrint('TahrirMonetizationService restorePurchases error: $e');
      }
    }

    final loaded = await loadEntitlement(now: currentTime);
    if (loaded.isSubscriptionActive(currentTime)) {
      return TahrirMonetizationResult(
        success: true,
        message: '✅ Kayıtlı Tahrir Pro erişiminiz geri yüklendi!',
        entitlement: loaded,
      );
    }

    return TahrirMonetizationResult(
      success: false,
      message: 'Kayıtlı aktif bir Tahrir Pro satın alımı bulunamadı.',
      entitlement: current,
    );
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel() ?? Future<void>.value());
    _purchaseSubscription = null;
    _preloadedRewardedAd?.dispose();
    _preloadedRewardedAd = null;
  }
}
