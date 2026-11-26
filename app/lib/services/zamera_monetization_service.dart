import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/zamera_monetization_models.dart';
import 'zamera_monetization_gateway.dart';

/// Dependency-inverted state and quota contract for Zamera Pro monetization.
abstract interface class MonetizationService implements Listenable {
  ZameraMonetizationState get state;

  bool get hasProAccess;

  int remainingFreeToday(ZameraProFeature feature);

  bool canUseFeature(ZameraProFeature feature);

  Future<bool> consumeFeatureOrCheckPro(ZameraProFeature feature);

  Future<void> refreshStoreOffers();

  Future<bool> purchasePlan(ZameraPlanId plan);

  Future<void> restorePurchases();

  void clearMessage();

  void dispose();
}

/// Production on-device controller managing 30-day free trial, Lifetime Pro,
/// and daily "Aha-Moment" free feature quotas with zero external analytics.
class ZameraMonetizationController extends ChangeNotifier
    implements MonetizationService {
  final MonetizationRepository _repository;
  final BillingGateway _billing;
  final DateTime Function() _nowUtc;
  final Duration restoreGraceTimeout;

  ZameraMonetizationState _state;
  StreamSubscription<BillingPurchaseUpdate>? _purchaseSub;
  Completer<void>? _restoreCompleter;
  bool _isRevalidating = false;
  bool _disposed = false;

  ZameraMonetizationController({
    MonetizationRepository? repository,
    BillingGateway? billingGateway,
    DateTime Function()? nowUtcProvider,
    ZameraMonetizationState? initialState,
    this.restoreGraceTimeout = const Duration(milliseconds: 600),
  }) : _repository = repository ?? const SharedPrefsMonetizationRepository(),
       _billing = billingGateway ?? StoreKitPlayBillingGateway(),
       _nowUtc = nowUtcProvider ?? (() => DateTime.now().toUtc()),
       _state =
           initialState ??
           ZameraMonetizationState.initial(
             ZameraMonetizationState.formatUtcDayKey(
               (nowUtcProvider ?? (() => DateTime.now().toUtc()))(),
             ),
           ) {
    _purchaseSub = _billing.purchaseUpdates.listen(_handleBillingUpdate);
  }

  /// Hydrates persisted entitlements immediately and refreshes store prices asynchronously.
  static Future<ZameraMonetizationController> initialize({
    MonetizationRepository? repository,
    BillingGateway? billingGateway,
    DateTime Function()? nowUtcProvider,
    bool refreshOffersInBackground = true,
  }) async {
    final repo = repository ?? const SharedPrefsMonetizationRepository();
    final nowFn = nowUtcProvider ?? (() => DateTime.now().toUtc());
    final todayKey = ZameraMonetizationState.formatUtcDayKey(nowFn());
    final loaded = await repo.load(todayKey: todayKey);

    final controller = ZameraMonetizationController(
      repository: repo,
      billingGateway: billingGateway,
      nowUtcProvider: nowFn,
      initialState: loaded,
    );
    if (refreshOffersInBackground) {
      unawaited(controller.refreshStoreOffers());
    }
    return controller;
  }

  String get _todayKey => ZameraMonetizationState.formatUtcDayKey(_nowUtc());

  @override
  ZameraMonetizationState get state => _state;

  @override
  bool get hasProAccess => _state.isEntitledAt(_nowUtc());

  @override
  int remainingFreeToday(ZameraProFeature feature) {
    if (hasProAccess) return feature.dailyFreeAllowance;
    return _state.remainingFreeToday(feature, _todayKey);
  }

  @override
  bool canUseFeature(ZameraProFeature feature) {
    return hasProAccess || remainingFreeToday(feature) > 0;
  }

  @override
  Future<bool> consumeFeatureOrCheckPro(ZameraProFeature feature) async {
    if (hasProAccess) return true;

    final today = _todayKey;
    if (_state.remainingFreeToday(feature, today) <= 0) {
      return false;
    }

    final baseCounts = _state.usageDayKey == today
        ? Map<String, int>.from(_state.dailyFeatureCounts)
        : <String, int>{};
    baseCounts[feature.name] = (baseCounts[feature.name] ?? 0) + 1;

    _state = _state.copyWith(
      usageDayKey: today,
      dailyFeatureCounts: Map<String, int>.unmodifiable(baseCounts),
      clearStatusMessage: true,
    );
    await _repository.save(_state);
    if (!_disposed) {
      notifyListeners();
    }
    return true;
  }

  @override
  Future<void> refreshStoreOffers() async {
    try {
      final available = await _billing.isAvailable();
      final offers = available
          ? await _billing.queryPrices()
          : ZameraMonetizationState.defaultOffers();
      if (_disposed) return;
      _state = _state.copyWith(storeAvailable: available, offers: offers);
      notifyListeners();

      if (available &&
          _state.needsStoreRevalidation(_nowUtc()) &&
          !_isRevalidating) {
        _isRevalidating = true;
        try {
          await _billing.restore();
        } finally {
          _isRevalidating = false;
        }
      }
    } catch (e, st) {
      debugPrint('ZameraMonetizationController.refreshStoreOffers error: $e\n$st');
    }
  }

  @override
  Future<bool> purchasePlan(ZameraPlanId plan) async {
    if (_disposed || _state.isBusy) return false;
    _state = _state.copyWith(isBusy: true, clearStatusMessage: true);
    notifyListeners();

    try {
      final launched = await _billing.buy(plan);
      if (!launched && !_disposed && _state.isBusy) {
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr:
              _state.statusMessageTr ??
              'Mağaza ödeme penceresi açılamadı.',
        );
        notifyListeners();
      }
      return launched;
    } catch (e, st) {
      debugPrint('ZameraMonetizationController.purchasePlan error: $e\n$st');
      if (!_disposed) {
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr: 'Satın alma hatası: $e',
        );
        notifyListeners();
      }
      return false;
    }
  }

  @override
  Future<void> restorePurchases() async {
    if (_disposed || _state.isBusy) return;
    _state = _state.copyWith(
      isBusy: true,
      statusMessageTr: 'Önceki satın alımlar mağazadan sorgulanıyor...',
    );
    notifyListeners();

    final completer = Completer<void>();
    _restoreCompleter = completer;

    try {
      await _billing.restore();
      await completer.future.timeout(restoreGraceTimeout, onTimeout: () {});
      if (!_disposed && _state.isBusy) {
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr: hasProAccess
              ? 'Zamera Pro erişiminiz geri yüklendi!'
              : 'Bu hesapta aktif bir Zamera Pro aboneliği bulunamadı.',
        );
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('ZameraMonetizationController.restorePurchases error: $e\n$st');
      if (!_disposed) {
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr: 'Geri yükleme hatası: $e',
        );
        notifyListeners();
      }
    } finally {
      if (identical(_restoreCompleter, completer)) {
        _restoreCompleter = null;
      }
    }
  }

  @override
  void clearMessage() {
    if (_disposed || _state.statusMessageTr == null) return;
    _state = _state.copyWith(clearStatusMessage: true);
    notifyListeners();
  }

  Future<void> _handleBillingUpdate(BillingPurchaseUpdate update) async {
    if (_disposed) return;

    switch (update.eventType) {
      case BillingEventType.pending:
        _state = _state.copyWith(
          isBusy: true,
          statusMessageTr: 'Mağaza onayı bekleniyor...',
        );
        notifyListeners();
        return;

      case BillingEventType.purchased:
      case BillingEventType.restored:
        final plan = ZameraPlanId.fromProductId(update.productId);
        if (plan == null) {
          _state = _state.copyWith(isBusy: false);
          if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
            _restoreCompleter!.complete();
          }
          notifyListeners();
          return;
        }
        final now = _nowUtc().toUtc();
        final (
          ZameraEntitlementStatus nextStatus,
          DateTime? trialEnd,
          DateTime? subExpiry,
        ) = _resolveEntitlementForPlan(
          plan: plan,
          isRestore: update.eventType == BillingEventType.restored,
          nowUtc: now,
        );

        _state = _state.copyWith(
          status: nextStatus,
          activePlan: plan,
          activatedAtUtc: now,
          trialEndsAtUtc: trialEnd,
          clearTrialEndsAt: trialEnd == null,
          lastVerifiedAtUtc: now,
          subscriptionExpiresAtUtc: subExpiry,
          clearSubscriptionExpiresAt: subExpiry == null,
          isBusy: false,
          statusMessageTr: nextStatus == ZameraEntitlementStatus.trialActive
              ? '1 Aylık ücretsiz Zamera Pro denemeniz başlatıldı!'
              : 'Zamera Pro etkinleştirildi!',
        );
        await _repository.save(_state);
        await _billing.acknowledgePurchase(
          update.productId,
          update.transactionId,
        );
        if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
          _restoreCompleter!.complete();
        }
        if (!_disposed) {
          notifyListeners();
        }
        return;

      case BillingEventType.canceled:
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr: 'Satın alma işlemi iptal edildi.',
        );
        if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
          _restoreCompleter!.complete();
        }
        notifyListeners();
        return;

      case BillingEventType.error:
        _state = _state.copyWith(
          isBusy: false,
          statusMessageTr:
              update.errorMessage ?? 'Mağaza işlemi tamamlanamadı.',
        );
        if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
          _restoreCompleter!.complete();
        }
        notifyListeners();
        return;
    }
  }

  (ZameraEntitlementStatus, DateTime?, DateTime?) _resolveEntitlementForPlan({
    required ZameraPlanId plan,
    required bool isRestore,
    required DateTime nowUtc,
  }) {
    if (plan.isLifetime) {
      return (ZameraEntitlementStatus.proLifetime, null, null);
    }
    if (plan.hasFreeTrial && !isRestore) {
      return (
        ZameraEntitlementStatus.trialActive,
        nowUtc.add(Duration(days: plan.trialDays)),
        null,
      );
    }
    final expiryWindowDays = plan == ZameraPlanId.annualPro ? 370 : 35;
    return (
      ZameraEntitlementStatus.proActive,
      null,
      nowUtc.add(Duration(days: expiryWindowDays)),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_purchaseSub?.cancel());
    _purchaseSub = null;
    unawaited(_billing.dispose());
    super.dispose();
  }
}
