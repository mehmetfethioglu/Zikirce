import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TahrirPlanTier {
  free,
  monthlyPro,
  yearlyPro,
  lifetimeMuderris,
}

class SubscriptionState {
  final TahrirPlanTier activeTier;
  final TahrirPlanTier selectedOfferTier;
  final bool isProcessing;

  const SubscriptionState({
    this.activeTier = TahrirPlanTier.free,
    this.selectedOfferTier = TahrirPlanTier.lifetimeMuderris,
    this.isProcessing = false,
  });

  bool get isPro => activeTier != TahrirPlanTier.free;

  String get activeBadgeLabel {
    switch (activeTier) {
      case TahrirPlanTier.free:
        return '✨ Tahrir Pro';
      case TahrirPlanTier.monthlyPro:
        return '✨ Pro Aylık';
      case TahrirPlanTier.yearlyPro:
        return '✨ Pro Yıllık';
      case TahrirPlanTier.lifetimeMuderris:
        return '👑 Pro Ömür Boyu';
    }
  }

  SubscriptionState copyWith({
    TahrirPlanTier? activeTier,
    TahrirPlanTier? selectedOfferTier,
    bool? isProcessing,
  }) {
    return SubscriptionState(
      activeTier: activeTier ?? this.activeTier,
      selectedOfferTier: selectedOfferTier ?? this.selectedOfferTier,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  static const String _tierKey = 'tahrir_subscription_tier_v1';

  SubscriptionNotifier() : super(const SubscriptionState()) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTierName = prefs.getString(_tierKey);

    TahrirPlanTier resolved = TahrirPlanTier.free;
    if (savedTierName != null) {
      for (final tier in TahrirPlanTier.values) {
        if (tier.name == savedTierName) {
          resolved = tier;
          break;
        }
      }
    }

    state = state.copyWith(
      activeTier: resolved,
    );
  }

  void selectOfferTier(TahrirPlanTier tier) {
    state = state.copyWith(selectedOfferTier: tier);
  }

  Future<void> activateSelectedPlan() async {
    state = state.copyWith(isProcessing: true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final chosen = state.selectedOfferTier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, chosen.name);
    state = state.copyWith(
      activeTier: chosen,
      isProcessing: false,
    );
  }

  Future<bool> restorePurchases() async {
    state = state.copyWith(isProcessing: true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    final savedTierName = prefs.getString(_tierKey);

    TahrirPlanTier resolved = TahrirPlanTier.free;
    if (savedTierName != null) {
      for (final tier in TahrirPlanTier.values) {
        if (tier.name == savedTierName) {
          resolved = tier;
          break;
        }
      }
    }

    state = state.copyWith(
      activeTier: resolved,
      isProcessing: false,
    );
    return resolved != TahrirPlanTier.free;
  }

  Future<void> resetToFreeTier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, TahrirPlanTier.free.name);
    state = state.copyWith(activeTier: TahrirPlanTier.free);
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
