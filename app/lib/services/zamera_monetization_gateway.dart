import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/zamera_monetization_models.dart';

/// Dependency-inverted persistence contract for [ZameraMonetizationState].
abstract interface class MonetizationRepository {
  Future<ZameraMonetizationState> load({required String todayKey});

  Future<bool> save(ZameraMonetizationState state);

  Future<bool> reset();
}

/// Production [SharedPreferences]-backed persistence with timeouts and fault recovery.
class SharedPrefsMonetizationRepository implements MonetizationRepository {
  static const String defaultStorageKey = 'zamera_monetization_v1';
  static const Duration _ioTimeout = Duration(seconds: 3);

  final String storageKey;

  const SharedPrefsMonetizationRepository({
    this.storageKey = defaultStorageKey,
  });

  @override
  Future<ZameraMonetizationState> load({required String todayKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final rawJson = prefs.getString(storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return ZameraMonetizationState.initial(todayKey);
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<Object?, Object?>) {
        return ZameraMonetizationState.initial(todayKey);
      }
      return ZameraMonetizationState.fromJson(
        decoded,
        fallbackTodayKey: todayKey,
      );
    } catch (e, st) {
      debugPrint('SharedPrefsMonetizationRepository.load error: $e\n$st');
      return ZameraMonetizationState.initial(todayKey);
    }
  }

  @override
  Future<bool> save(ZameraMonetizationState state) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final encoded = jsonEncode(state.toJson());
      return await prefs.setString(storageKey, encoded).timeout(_ioTimeout);
    } catch (e, st) {
      debugPrint('SharedPrefsMonetizationRepository.save error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      return await prefs.remove(storageKey).timeout(_ioTimeout);
    } catch (e, st) {
      debugPrint('SharedPrefsMonetizationRepository.reset error: $e\n$st');
      return false;
    }
  }
}

/// Deterministic in-memory [MonetizationRepository] for unit and widget tests.
class InMemoryMonetizationRepository implements MonetizationRepository {
  ZameraMonetizationState? _stored;

  InMemoryMonetizationRepository([this._stored]);

  ZameraMonetizationState? get stored => _stored;

  @override
  Future<ZameraMonetizationState> load({required String todayKey}) async {
    return _stored ?? ZameraMonetizationState.initial(todayKey);
  }

  @override
  Future<bool> save(ZameraMonetizationState state) async {
    _stored = state;
    return true;
  }

  @override
  Future<bool> reset() async {
    _stored = null;
    return true;
  }
}

/// Normalized storefront purchase lifecycle event types.
enum BillingEventType { pending, purchased, restored, canceled, error }

/// Normalized on-device StoreKit 2 / Google Play Billing purchase update.
@immutable
class BillingPurchaseUpdate {
  final BillingEventType eventType;
  final String productId;
  final String? transactionId;
  final String? errorMessage;
  final DateTime? transactionDateUtc;

  const BillingPurchaseUpdate({
    required this.eventType,
    required this.productId,
    this.transactionId,
    this.errorMessage,
    this.transactionDateUtc,
  });
}

/// Narrow DIP billing gateway interface (StoreKit 2 & Google Play Billing).
abstract interface class BillingGateway {
  Future<bool> isAvailable();

  Future<Map<ZameraPlanId, ZameraStoreOffer>> queryPrices();

  Stream<BillingPurchaseUpdate> get purchaseUpdates;

  Future<bool> buy(ZameraPlanId plan);

  Future<void> restore();

  Future<void> dispose();
}

/// Zero-telemetry production gateway backed exclusively by StoreKit 2 & Google Play Billing.
class StoreKitPlayBillingGateway implements BillingGateway {
  static const Map<PurchaseStatus, BillingEventType> _statusMap =
      <PurchaseStatus, BillingEventType>{
        PurchaseStatus.pending: BillingEventType.pending,
        PurchaseStatus.purchased: BillingEventType.purchased,
        PurchaseStatus.restored: BillingEventType.restored,
        PurchaseStatus.canceled: BillingEventType.canceled,
        PurchaseStatus.error: BillingEventType.error,
      };

  final InAppPurchase? _iapOverride;
  final Map<String, ProductDetails> _productCache = <String, ProductDetails>{};
  final StreamController<BillingPurchaseUpdate> _updatesController =
      StreamController<BillingPurchaseUpdate>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _disposed = false;

  StoreKitPlayBillingGateway({InAppPurchase? iapInstance})
    : _iapOverride = iapInstance;

  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  void _ensureStreamSubscribed() {
    if (_disposed || _purchaseSub != null) return;
    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _onStorePurchases,
        onError: (Object error, StackTrace st) {
          debugPrint('StoreKitPlayBillingGateway stream error: $error\n$st');
          if (!_updatesController.isClosed) {
            _updatesController.add(
              BillingPurchaseUpdate(
                eventType: BillingEventType.error,
                productId: '',
                errorMessage: 'Mağaza bağlantı hatası: $error',
              ),
            );
          }
        },
      );
    } catch (e, st) {
      debugPrint('StoreKitPlayBillingGateway listen error: $e\n$st');
    }
  }

  Future<void> _onStorePurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails details in purchases) {
      final eventType =
          _statusMap[details.status] ?? BillingEventType.error;
      final txEpoch = int.tryParse(details.transactionDate ?? '');
      final txDate = txEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(txEpoch, isUtc: true)
          : null;

      if (details.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(details);
        } catch (e, st) {
          debugPrint('StoreKitPlayBillingGateway complete error: $e\n$st');
        }
      }

      if (!_updatesController.isClosed) {
        _updatesController.add(
          BillingPurchaseUpdate(
            eventType: eventType,
            productId: details.productID,
            transactionId: details.purchaseID,
            errorMessage: details.error?.message,
            transactionDateUtc: txDate,
          ),
        );
      }
    }
  }

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates {
    _ensureStreamSubscribed();
    return _updatesController.stream;
  }

  @override
  Future<bool> isAvailable() async {
    _ensureStreamSubscribed();
    try {
      return await _iap.isAvailable();
    } catch (e, st) {
      debugPrint('StoreKitPlayBillingGateway.isAvailable error: $e\n$st');
      return false;
    }
  }

  @override
  Future<Map<ZameraPlanId, ZameraStoreOffer>> queryPrices() async {
    _ensureStreamSubscribed();
    final offers = ZameraMonetizationState.defaultOffers();
    try {
      final available = await isAvailable();
      if (!available) return offers;
      final response = await _iap.queryProductDetails(
        ZameraPlanId.allProductIds,
      );
      for (final ProductDetails details in response.productDetails) {
        _productCache[details.id] = details;
        final plan = ZameraPlanId.fromProductId(details.id);
        if (plan != null) {
          offers[plan] = ZameraStoreOffer(
            plan: plan,
            localizedPrice: details.price,
            isLiveFromStore: true,
          );
        }
      }
      return offers;
    } catch (e, st) {
      debugPrint('StoreKitPlayBillingGateway.queryPrices error: $e\n$st');
      return offers;
    }
  }

  @override
  Future<bool> buy(ZameraPlanId plan) async {
    _ensureStreamSubscribed();
    try {
      var details = _productCache[plan.productId];
      if (details == null) {
        await queryPrices();
        details = _productCache[plan.productId];
      }
      if (details == null) {
        if (!_updatesController.isClosed) {
          _updatesController.add(
            BillingPurchaseUpdate(
              eventType: BillingEventType.error,
              productId: plan.productId,
              errorMessage:
                  'Mağaza ürünü henüz hazır değil (${plan.productId}). Lütfen daha sonra tekrar deneyin.',
            ),
          );
        }
        return false;
      }
      final param = PurchaseParam(productDetails: details);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e, st) {
      debugPrint('StoreKitPlayBillingGateway.buy error: $e\n$st');
      if (!_updatesController.isClosed) {
        _updatesController.add(
          BillingPurchaseUpdate(
            eventType: BillingEventType.error,
            productId: plan.productId,
            errorMessage: 'Satın alma başlatılamadı: $e',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> restore() async {
    _ensureStreamSubscribed();
    try {
      await _iap.restorePurchases();
    } catch (e, st) {
      debugPrint('StoreKitPlayBillingGateway.restore error: $e\n$st');
      if (!_updatesController.isClosed) {
        _updatesController.add(
          BillingPurchaseUpdate(
            eventType: BillingEventType.error,
            productId: '',
            errorMessage: 'Satın alımlar geri yüklenemedi: $e',
          ),
        );
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    if (!_updatesController.isClosed) {
      await _updatesController.close();
    }
  }
}
