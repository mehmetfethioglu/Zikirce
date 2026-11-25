import 'package:flutter/foundation.dart';

/// Subscription & licensing tiers supported by Tahrir Pro.
enum TahrirPlanTier {
  free,
  weeklyPro,
  monthlyPro,
  yearlyPro,
  lifetimeMuderris,
}

/// Immutable display & store catalog metadata for a paid Tahrir Pro plan.
@immutable
class TahrirPlanMetadata {
  final TahrirPlanTier tier;
  final String sku;
  final String title;
  final String badge;
  final String fallbackPriceTr;
  final String periodLabel;
  final String subtitle;
  final bool isLifetime;
  final Duration? subscriptionDuration;

  const TahrirPlanMetadata({
    required this.tier,
    required this.sku,
    required this.title,
    required this.badge,
    required this.fallbackPriceTr,
    required this.periodLabel,
    required this.subtitle,
    this.isLifetime = false,
    this.subscriptionDuration,
  });
}

/// Central catalog of SKUs, regional fallback prices, trial windows, and
/// rewarded-ad timings for Tahrir Pro (OCP table-driven mapping).
class TahrirProProductCatalog {
  TahrirProProductCatalog._();

  static const String skuProWeekly = 'tahrir_pro_weekly';
  static const String skuProMonthly = 'tahrir_pro_monthly';
  static const String skuProYearly = 'tahrir_pro_yearly';
  static const String skuProLifetime = 'tahrir_pro_lifetime';

  static const Set<String> allSkus = {
    skuProWeekly,
    skuProMonthly,
    skuProYearly,
    skuProLifetime,
  };

  /// Automatic full Pro access granted for the first 24 hours after install.
  static const Duration firstInstallFreeTrialDuration = Duration(hours: 24);

  /// Number of full-screen rewarded ads required to unlock 24h Pro Pass.
  static const int rewardedAdsRequiredFor24hPro = 3;

  /// Full Pro access granted after completing [rewardedAdsRequiredFor24hPro] Rewarded Ads.
  static const Duration rewardedProPassDuration = Duration(hours: 24);

  /// Minimum cooldown while an active Rewarded Pro Pass is running (IVT guard).
  static const Duration rewardedAdCooldown = Duration(hours: 4);

  static const Map<TahrirPlanTier, TahrirPlanMetadata> plansByTier = {
    TahrirPlanTier.weeklyPro: TahrirPlanMetadata(
      tier: TahrirPlanTier.weeklyPro,
      sku: skuProWeekly,
      title: 'Haftalık Pro',
      badge: 'ESNEK DENEME',
      fallbackPriceTr: '₺29,99',
      periodLabel: '/ hafta',
      subtitle: '7 gün tam erişim • İstediğin an iptal',
      subscriptionDuration: Duration(days: 7),
    ),
    TahrirPlanTier.monthlyPro: TahrirPlanMetadata(
      tier: TahrirPlanTier.monthlyPro,
      sku: skuProMonthly,
      title: 'Aylık Pro',
      badge: 'POPÜLER',
      fallbackPriceTr: '₺59,99',
      periodLabel: '/ ay',
      subtitle: '30 gün sınırsız OCR, akıcı fasıl ve not ihracı',
      subscriptionDuration: Duration(days: 31),
    ),
    TahrirPlanTier.yearlyPro: TahrirPlanMetadata(
      tier: TahrirPlanTier.yearlyPro,
      sku: skuProYearly,
      title: 'Yıllık Pro',
      badge: '%58 TASARRUF',
      fallbackPriceTr: '₺299,99',
      periodLabel: '/ yıl',
      subtitle: '12 ay tam erişim • En ekonomik abonelik',
      subscriptionDuration: Duration(days: 366),
    ),
    TahrirPlanTier.lifetimeMuderris: TahrirPlanMetadata(
      tier: TahrirPlanTier.lifetimeMuderris,
      sku: skuProLifetime,
      title: 'Ömür Boyu Pro (Tek Seferlik)',
      badge: '👑 EN ÇOK TERCİH EDİLEN • ÖMÜR BOYU',
      fallbackPriceTr: '₺599,99',
      periodLabel: 'ömür boyu • tek seferlik',
      subtitle: 'Bir kez edinin, tüm Tahrir Pro motorlarına süresiz sahip olun.',
      isLifetime: true,
    ),
  };

  static final Map<String, TahrirPlanTier> tierBySku = {
    for (final entry in plansByTier.entries) entry.value.sku: entry.key,
  };

  /// Returns catalog metadata for a paid [tier], or `null` for [TahrirPlanTier.free].
  static TahrirPlanMetadata? metadataFor(TahrirPlanTier tier) =>
      plansByTier[tier];

  /// Maps a store SKU string to its corresponding [TahrirPlanTier].
  static TahrirPlanTier tierForSku(String sku) =>
      tierBySku[sku] ?? TahrirPlanTier.free;

  /// Returns the store SKU identifier for a paid [tier], or empty string for free.
  static String skuForTier(TahrirPlanTier tier) =>
      plansByTier[tier]?.sku ?? '';
}

/// Immutable snapshot of the user's install trial, rewarded ad pass, and IAP entitlement.
@immutable
class TahrirEntitlementState {
  final int firstInstallEpochMs;
  final bool isProLifetime;
  final TahrirPlanTier activePaidTier;
  final String purchasedSku;
  final int purchaseEpochMs;
  final int subscriptionExpiresEpochMs;
  final int proPassExpiresEpochMs;
  final int lastRewardedAdEpochMs;
  final int rewardedAdWatchProgress;

  const TahrirEntitlementState({
    this.firstInstallEpochMs = 0,
    this.isProLifetime = false,
    this.activePaidTier = TahrirPlanTier.free,
    this.purchasedSku = '',
    this.purchaseEpochMs = 0,
    this.subscriptionExpiresEpochMs = 0,
    this.proPassExpiresEpochMs = 0,
    this.lastRewardedAdEpochMs = 0,
    this.rewardedAdWatchProgress = 0,
  });

  /// Number of remaining rewarded ads required to unlock the 24-hour Pro Pass.
  int get remainingRewardedAdsForPass =>
      (TahrirProProductCatalog.rewardedAdsRequiredFor24hPro -
              rewardedAdWatchProgress)
          .clamp(1, TahrirProProductCatalog.rewardedAdsRequiredFor24hPro);

  /// Returns true during the first 24 hours immediately following initial install.
  bool isFirst24hTrialActive([DateTime? now]) {
    if (firstInstallEpochMs <= 0) return false;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final expiresAtMs =
        firstInstallEpochMs +
        TahrirProProductCatalog.firstInstallFreeTrialDuration.inMilliseconds;
    return nowMs >= firstInstallEpochMs && nowMs < expiresAtMs;
  }

  /// Remaining duration of the initial 24-hour install trial.
  Duration remainingFirst24hTrial([DateTime? now]) {
    if (!isFirst24hTrialActive(now)) return Duration.zero;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final expiresAtMs =
        firstInstallEpochMs +
        TahrirProProductCatalog.firstInstallFreeTrialDuration.inMilliseconds;
    return Duration(milliseconds: expiresAtMs - nowMs);
  }

  /// Returns true if the user holds an active paid subscription or lifetime license.
  bool isSubscriptionActive([DateTime? now]) {
    if (isProLifetime || activePaidTier == TahrirPlanTier.lifetimeMuderris) {
      return true;
    }
    if (activePaidTier == TahrirPlanTier.free) {
      return false;
    }
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return subscriptionExpiresEpochMs > nowMs;
  }

  /// Returns true while a 24-hour Rewarded Ad Pro Pass is active.
  bool isProPassActive([DateTime? now]) {
    if (proPassExpiresEpochMs <= 0) return false;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return proPassExpiresEpochMs > nowMs;
  }

  /// Remaining duration of the active 24-hour Rewarded Ad Pro Pass.
  Duration remainingProPass([DateTime? now]) {
    if (!isProPassActive(now)) return Duration.zero;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return Duration(milliseconds: proPassExpiresEpochMs - nowMs);
  }

  /// True whenever the user has Pro access via paid tier, rewarded pass, or 24h trial.
  bool hasProAccess([DateTime? now]) =>
      isSubscriptionActive(now) ||
      isProPassActive(now) ||
      isFirst24hTrialActive(now);

  /// True once the initial 24h free window has ended and no Pro pass/subscription is active.
  bool shouldShowEntryPaywall([DateTime? now]) => !hasProAccess(now);

  /// Compatibility alias for [shouldShowEntryPaywall].
  bool requiresHardPaywall([DateTime? now]) => shouldShowEntryPaywall(now);

  /// Effective active tier resolved against current timestamps.
  TahrirPlanTier effectivePaidTier([DateTime? now]) {
    if (isProLifetime || activePaidTier == TahrirPlanTier.lifetimeMuderris) {
      return TahrirPlanTier.lifetimeMuderris;
    }
    if (isSubscriptionActive(now)) {
      return activePaidTier;
    }
    return TahrirPlanTier.free;
  }

  /// Human-readable remaining duration string in Turkish.
  static String formatRemaining(Duration d) {
    if (d <= Duration.zero) return '0 dk';
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 1) return '< 1 dk';
    final hours = d.inHours;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '$hours sa $minutes dk';
    }
    return '$minutes dk';
  }

  /// Status badge shown in Settings and purchase confirmations.
  String activeBadgeLabel([DateTime? now]) {
    final paid = effectivePaidTier(now);
    switch (paid) {
      case TahrirPlanTier.lifetimeMuderris:
        return '👑 Pro Ömür Boyu';
      case TahrirPlanTier.yearlyPro:
        return '✨ Pro Yıllık';
      case TahrirPlanTier.monthlyPro:
        return '✨ Pro Aylık';
      case TahrirPlanTier.weeklyPro:
        return '✨ Pro Haftalık';
      case TahrirPlanTier.free:
        if (isProPassActive(now)) {
          return '🎬 24s Pro (${formatRemaining(remainingProPass(now))})';
        }
        if (isFirst24hTrialActive(now)) {
          return '🎁 24s Ücretsiz (${formatRemaining(remainingFirst24hTrial(now))})';
        }
        return '🔒 Tahrir Pro';
    }
  }

  TahrirEntitlementState copyWith({
    int? firstInstallEpochMs,
    bool? isProLifetime,
    TahrirPlanTier? activePaidTier,
    String? purchasedSku,
    int? purchaseEpochMs,
    int? subscriptionExpiresEpochMs,
    int? proPassExpiresEpochMs,
    int? lastRewardedAdEpochMs,
    int? rewardedAdWatchProgress,
  }) {
    return TahrirEntitlementState(
      firstInstallEpochMs: firstInstallEpochMs ?? this.firstInstallEpochMs,
      isProLifetime: isProLifetime ?? this.isProLifetime,
      activePaidTier: activePaidTier ?? this.activePaidTier,
      purchasedSku: purchasedSku ?? this.purchasedSku,
      purchaseEpochMs: purchaseEpochMs ?? this.purchaseEpochMs,
      subscriptionExpiresEpochMs:
          subscriptionExpiresEpochMs ?? this.subscriptionExpiresEpochMs,
      proPassExpiresEpochMs:
          proPassExpiresEpochMs ?? this.proPassExpiresEpochMs,
      lastRewardedAdEpochMs:
          lastRewardedAdEpochMs ?? this.lastRewardedAdEpochMs,
      rewardedAdWatchProgress:
          rewardedAdWatchProgress ?? this.rewardedAdWatchProgress,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstInstallEpochMs': firstInstallEpochMs,
        'isProLifetime': isProLifetime,
        'activePaidTier': activePaidTier.name,
        'purchasedSku': purchasedSku,
        'purchaseEpochMs': purchaseEpochMs,
        'subscriptionExpiresEpochMs': subscriptionExpiresEpochMs,
        'proPassExpiresEpochMs': proPassExpiresEpochMs,
        'lastRewardedAdEpochMs': lastRewardedAdEpochMs,
        'rewardedAdWatchProgress': rewardedAdWatchProgress,
      };

  factory TahrirEntitlementState.fromJson(Map<String, dynamic> json) {
    final tierName = json['activePaidTier'] as String?;
    TahrirPlanTier parsedTier = TahrirPlanTier.free;
    if (tierName != null) {
      for (final tier in TahrirPlanTier.values) {
        if (tier.name == tierName) {
          parsedTier = tier;
          break;
        }
      }
    }

    return TahrirEntitlementState(
      firstInstallEpochMs: (json['firstInstallEpochMs'] as num?)?.toInt() ?? 0,
      isProLifetime: (json['isProLifetime'] as bool?) ?? false,
      activePaidTier: parsedTier,
      purchasedSku: (json['purchasedSku'] as String?) ?? '',
      purchaseEpochMs: (json['purchaseEpochMs'] as num?)?.toInt() ?? 0,
      subscriptionExpiresEpochMs:
          (json['subscriptionExpiresEpochMs'] as num?)?.toInt() ?? 0,
      proPassExpiresEpochMs:
          (json['proPassExpiresEpochMs'] as num?)?.toInt() ?? 0,
      lastRewardedAdEpochMs:
          (json['lastRewardedAdEpochMs'] as num?)?.toInt() ?? 0,
      rewardedAdWatchProgress:
          ((json['rewardedAdWatchProgress'] as num?)?.toInt() ?? 0)
              .clamp(0, TahrirProProductCatalog.rewardedAdsRequiredFor24hPro),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TahrirEntitlementState &&
          runtimeType == other.runtimeType &&
          firstInstallEpochMs == other.firstInstallEpochMs &&
          isProLifetime == other.isProLifetime &&
          activePaidTier == other.activePaidTier &&
          purchasedSku == other.purchasedSku &&
          purchaseEpochMs == other.purchaseEpochMs &&
          subscriptionExpiresEpochMs == other.subscriptionExpiresEpochMs &&
          proPassExpiresEpochMs == other.proPassExpiresEpochMs &&
          lastRewardedAdEpochMs == other.lastRewardedAdEpochMs &&
          rewardedAdWatchProgress == other.rewardedAdWatchProgress;

  @override
  int get hashCode => Object.hash(
        firstInstallEpochMs,
        isProLifetime,
        activePaidTier,
        purchasedSku,
        purchaseEpochMs,
        subscriptionExpiresEpochMs,
        proPassExpiresEpochMs,
        lastRewardedAdEpochMs,
        rewardedAdWatchProgress,
      );
}

/// Outcome returned by purchase, restore, or rewarded-ad operations.
@immutable
class TahrirMonetizationResult {
  final bool success;
  final String message;
  final TahrirEntitlementState entitlement;

  const TahrirMonetizationResult({
    required this.success,
    required this.message,
    required this.entitlement,
  });
}
