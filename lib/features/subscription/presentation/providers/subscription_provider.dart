import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tahrir_entitlement_models.dart';
import '../../services/tahrir_monetization_service.dart';

export '../../domain/tahrir_entitlement_models.dart';

/// Dependency Injection provider for [TahrirMonetizationGateway].
final tahrirMonetizationGatewayProvider =
    Provider<TahrirMonetizationGateway>((ref) {
  final service = TahrirMonetizationService();
  ref.onDispose(service.dispose);
  return service;
});

@immutable
class SubscriptionState {
  final TahrirEntitlementState entitlement;
  final TahrirPlanTier selectedOfferTier;
  final bool isLoaded;
  final bool isProcessing;
  final bool isWatchingRewardedAd;
  final Map<String, String> storePricesBySku;
  final String? lastStatusMessage;
  final int clockTickEpochMs;

  const SubscriptionState({
    this.entitlement = const TahrirEntitlementState(),
    this.selectedOfferTier = TahrirPlanTier.yearlyPro,
    this.isLoaded = false,
    this.isProcessing = false,
    this.isWatchingRewardedAd = false,
    this.storePricesBySku = const <String, String>{},
    this.lastStatusMessage,
    this.clockTickEpochMs = 0,
  });

  DateTime? get _effectiveNow => clockTickEpochMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(clockTickEpochMs)
      : null;

  /// Active paid tier (or [TahrirPlanTier.free] when on trial, rewarded pass, or free).
  TahrirPlanTier get activeTier => entitlement.effectivePaidTier(_effectiveNow);

  /// True whenever user holds a paid plan, active 24h rewarded pass, or initial 24h free trial.
  bool get isPro => entitlement.hasProAccess(_effectiveNow);

  /// True while the initial 24-hour post-install trial is active without a paid plan.
  bool get isInFirst24hTrial =>
      !entitlement.isSubscriptionActive(_effectiveNow) &&
      !entitlement.isProPassActive(_effectiveNow) &&
      entitlement.isFirst24hTrialActive(_effectiveNow);

  /// True while a 24-hour full-screen rewarded ad Pro Pass is active without a paid plan.
  bool get isRewardedProPassActive =>
      !entitlement.isSubscriptionActive(_effectiveNow) &&
      entitlement.isProPassActive(_effectiveNow);

  /// Current watch step (`0..2`) toward the 3-ad 24-hour Pro unlock.
  int get rewardedAdProgress => entitlement.rewardedAdWatchProgress;

  /// Remaining rewarded ads needed to unlock 24-hour Pro access.
  int get remainingRewardedAds => entitlement.remainingRewardedAdsForPass;

  /// True once entitlement is loaded AND the 24h free window / pass / subscription has expired.
  bool get shouldShowEntryPaywall =>
      isLoaded && entitlement.shouldShowEntryPaywall(_effectiveNow);

  /// Compatibility alias for [shouldShowEntryPaywall].
  bool get requiresEntryPaywall => shouldShowEntryPaywall;

  /// Display badge for Settings and confirmations.
  String get activeBadgeLabel => entitlement.activeBadgeLabel(_effectiveNow);

  /// Returns localized store price for [tier] if available, otherwise Turkish catalog price.
  String priceForTier(TahrirPlanTier tier) {
    final meta = TahrirProProductCatalog.metadataFor(tier);
    if (meta == null) return '';
    return storePricesBySku[meta.sku] ?? meta.fallbackPriceTr;
  }

  SubscriptionState copyWith({
    TahrirEntitlementState? entitlement,
    TahrirPlanTier? selectedOfferTier,
    bool? isLoaded,
    bool? isProcessing,
    bool? isWatchingRewardedAd,
    Map<String, String>? storePricesBySku,
    String? lastStatusMessage,
    bool clearStatusMessage = false,
    int? clockTickEpochMs,
  }) {
    return SubscriptionState(
      entitlement: entitlement ?? this.entitlement,
      selectedOfferTier: selectedOfferTier ?? this.selectedOfferTier,
      isLoaded: isLoaded ?? this.isLoaded,
      isProcessing: isProcessing ?? this.isProcessing,
      isWatchingRewardedAd:
          isWatchingRewardedAd ?? this.isWatchingRewardedAd,
      storePricesBySku: storePricesBySku ?? this.storePricesBySku,
      lastStatusMessage: clearStatusMessage
          ? null
          : (lastStatusMessage ?? this.lastStatusMessage),
      clockTickEpochMs: clockTickEpochMs ?? this.clockTickEpochMs,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final TahrirMonetizationGateway _gateway;
  final Completer<void> _loadCompleter = Completer<void>();

  SubscriptionNotifier(this._gateway) : super(const SubscriptionState()) {
    unawaited(_initialize());
  }

  /// Resolves once the sealed local entitlement vault has been loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _initialize() async {
    try {
      final loaded = await _gateway.loadEntitlement();
      if (!mounted) return;
      state = state.copyWith(
        entitlement: loaded,
        isLoaded: true,
        clockTickEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      await _gateway.initializeStore(
        onStoreEntitlementUpdate: (updated, message) {
          if (!mounted) return;
          state = state.copyWith(
            entitlement: updated,
            isProcessing: false,
            lastStatusMessage: message,
            clockTickEpochMs: DateTime.now().millisecondsSinceEpoch,
          );
        },
        onStoreError: (message) {
          if (!mounted) return;
          state = state.copyWith(
            isProcessing: false,
            lastStatusMessage: message,
          );
        },
      );

      if (!mounted) return;
      state = state.copyWith(
        storePricesBySku: _gateway.localizedPricesBySku,
      );

      if (!loaded.isSubscriptionActive()) {
        await _gateway.ensureAdsInitialized();
        unawaited(_gateway.preloadRewardedAd());
      }
    } catch (e) {
      debugPrint('SubscriptionNotifier _initialize error: $e');
      if (mounted) {
        state = state.copyWith(isLoaded: true);
      }
    } finally {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    }
  }

  /// Selects one of the 4 paid offer cards inside [TahrirProSheet].
  void selectOfferTier(TahrirPlanTier tier) {
    if (tier == TahrirPlanTier.free) return;
    state = state.copyWith(selectedOfferTier: tier, clearStatusMessage: true);
  }

  /// Triggers a clock tick so expired 24-hour trials/passes immediately enforce the gate.
  void refreshEntitlementClock({DateTime? now}) {
    final tick = (now ?? DateTime.now()).millisecondsSinceEpoch;
    state = state.copyWith(clockTickEpochMs: tick);
  }

  /// Launches Google Play / App Store billing for [state.selectedOfferTier].
  Future<TahrirMonetizationResult> purchaseSelectedPlan({DateTime? now}) async {
    state = state.copyWith(isProcessing: true, clearStatusMessage: true);
    try {
      final result = await _gateway.purchaseTier(
        tier: state.selectedOfferTier,
        current: state.entitlement,
        now: now,
      );
      if (mounted) {
        state = state.copyWith(
          entitlement: result.entitlement,
          isProcessing: false,
          lastStatusMessage: result.message,
          clockTickEpochMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
        );
      }
      return result;
    } catch (e) {
      debugPrint('SubscriptionNotifier purchaseSelectedPlan error: $e');
      final fallback = TahrirMonetizationResult(
        success: false,
        message: '⚠️ Satın alma başlatılamadı: $e',
        entitlement: state.entitlement,
      );
      if (mounted) {
        state = state.copyWith(
          isProcessing: false,
          lastStatusMessage: fallback.message,
        );
      }
      return fallback;
    }
  }

  /// Shows a full-screen Rewarded Ad (no banners) and grants 24-hour Pro access on completion.
  Future<TahrirMonetizationResult> watchRewardedAdFor24hPro({
    DateTime? now,
  }) async {
    state = state.copyWith(isWatchingRewardedAd: true, clearStatusMessage: true);
    try {
      final result = await _gateway.watchRewardedAdAndUnlockProPass(
        current: state.entitlement,
        now: now,
      );
      if (mounted) {
        state = state.copyWith(
          entitlement: result.entitlement,
          isWatchingRewardedAd: false,
          lastStatusMessage: result.message,
          clockTickEpochMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
        );
      }
      return result;
    } catch (e) {
      debugPrint('SubscriptionNotifier watchRewardedAdFor24hPro error: $e');
      final fallback = TahrirMonetizationResult(
        success: false,
        message: '⚠️ Ödüllü reklam başlatılamadı: $e',
        entitlement: state.entitlement,
      );
      if (mounted) {
        state = state.copyWith(
          isWatchingRewardedAd: false,
          lastStatusMessage: fallback.message,
        );
      }
      return fallback;
    }
  }

  /// Restores store purchases / local sealed entitlements.
  Future<TahrirMonetizationResult> restorePurchases({DateTime? now}) async {
    state = state.copyWith(isProcessing: true, clearStatusMessage: true);
    try {
      final result = await _gateway.restorePurchases(
        current: state.entitlement,
        now: now,
      );
      if (mounted) {
        state = state.copyWith(
          entitlement: result.entitlement,
          isProcessing: false,
          lastStatusMessage: result.message,
          clockTickEpochMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
        );
      }
      return result;
    } catch (e) {
      debugPrint('SubscriptionNotifier restorePurchases error: $e');
      final fallback = TahrirMonetizationResult(
        success: false,
        message: '⚠️ Geri yükleme başarısız: $e',
        entitlement: state.entitlement,
      );
      if (mounted) {
        state = state.copyWith(
          isProcessing: false,
          lastStatusMessage: fallback.message,
        );
      }
      return fallback;
    }
  }

  /// Debug-only helper to simulate the post-24h hard paywall state during QA.
  Future<void> debugSimulate24hExpired({DateTime? now}) async {
    if (!kDebugMode) return;
    final currentTime = now ?? DateTime.now();
    final expiredInstallMs = currentTime
        .subtract(const Duration(hours: 25))
        .millisecondsSinceEpoch;
    final expired = TahrirEntitlementState(
      firstInstallEpochMs: expiredInstallMs,
    );
    await _gateway.saveEntitlement(expired);
    if (mounted) {
      state = state.copyWith(
        entitlement: expired,
        isLoaded: true,
        lastStatusMessage: '🧪 24 saatlik deneme süresi sona erdi (Simülasyon).',
        clockTickEpochMs: currentTime.millisecondsSinceEpoch,
      );
    }
  }

  @override
  void dispose() {
    _gateway.dispose();
    super.dispose();
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final gateway = ref.watch(tahrirMonetizationGatewayProvider);
  return SubscriptionNotifier(gateway);
});
