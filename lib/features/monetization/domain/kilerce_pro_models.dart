/// Paid & rewarded Pro tiers offered in Kilerce.
enum KilercePlanTier {
  weekly(
    productId: 'kilerce_pro_weekly',
    title: 'Haftalık Pro',
    subtitle: '7 gün reklamsız + 23.933 tarif tam erişim',
    fallbackPrice: '₺39,99 / hafta',
  ),
  monthly(
    productId: 'kilerce_pro_monthly',
    title: 'Aylık Pro',
    subtitle: 'En esnek aylık mutfak asistanı',
    fallbackPrice: '₺99,99 / ay',
  ),
  yearly(
    productId: 'kilerce_pro_yearly',
    title: 'Yıllık Pro',
    subtitle: '%55 tasarruf • En popüler',
    fallbackPrice: '₺549,99 / yıl',
    isPopular: true,
  ),
  lifetime(
    productId: 'kilerce_pro_lifetime',
    title: 'Ömür Boyu Pro',
    subtitle: 'Ömür boyu 23.933+ tarif & reklamsız + aylık 100 AI analiz',
    fallbackPrice: '₺1.499,99 tek sefer',
  );

  final String productId;
  final String title;
  final String subtitle;
  final String fallbackPrice;
  final bool isPopular;

  const KilercePlanTier({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.fallbackPrice,
    this.isPopular = false,
  });

  static KilercePlanTier? fromProductId(String id) {
    final lower = id.trim().toLowerCase();
    for (final tier in KilercePlanTier.values) {
      if (lower == tier.productId || lower.contains(tier.name)) {
        return tier;
      }
    }
    return null;
  }
}

/// Canonical Pro entitlement & daily quota snapshot returned by Cloudflare Worker.
class KilerceEntitlementSnapshot {
  final String appUserId;
  final bool isPro;
  final String tier;
  final String source;
  final bool isLifetime;
  final int proUntilMs;
  final int adProgress;
  final int adsRequired;
  final int dailyRewardPassesUsed;
  final int dailyRewardPassesLimit;
  final int dailyDetailUsed;
  final int dailyDetailLimit;
  final int dailyDetailRemaining;

  const KilerceEntitlementSnapshot({
    this.appUserId = '',
    this.isPro = false,
    this.tier = 'free',
    this.source = 'none',
    this.isLifetime = false,
    this.proUntilMs = 0,
    this.adProgress = 0,
    this.adsRequired = 3,
    this.dailyRewardPassesUsed = 0,
    this.dailyRewardPassesLimit = 2,
    this.dailyDetailUsed = 0,
    this.dailyDetailLimit = 5,
    this.dailyDetailRemaining = 5,
  });

  Duration remainingProDuration({DateTime? now}) {
    if (isLifetime) return const Duration(days: 3650);
    if (!isPro || proUntilMs <= 0) return Duration.zero;
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final diff = proUntilMs - currentMs;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  factory KilerceEntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    return KilerceEntitlementSnapshot(
      appUserId: (json['app_user_id'] as String?) ?? '',
      isPro: json['is_pro'] == true,
      tier: (json['tier'] as String?) ?? 'free',
      source: (json['source'] as String?) ?? 'none',
      isLifetime: json['is_lifetime'] == true,
      proUntilMs: (json['pro_until_ms'] as num?)?.toInt() ?? 0,
      adProgress: (json['ad_progress'] as num?)?.toInt() ?? 0,
      adsRequired: (json['ads_required'] as num?)?.toInt() ?? 3,
      dailyRewardPassesUsed:
          (json['daily_reward_passes_used'] as num?)?.toInt() ?? 0,
      dailyRewardPassesLimit:
          (json['daily_reward_passes_limit'] as num?)?.toInt() ?? 2,
      dailyDetailUsed: (json['daily_detail_used'] as num?)?.toInt() ?? 0,
      dailyDetailLimit: (json['daily_detail_limit'] as num?)?.toInt() ?? 5,
      dailyDetailRemaining:
          (json['daily_detail_remaining'] as num?)?.toInt() ?? 5,
    );
  }
}
