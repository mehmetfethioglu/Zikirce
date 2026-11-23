import 'package:flutter/foundation.dart';

/// OCP-compliant subscription and lifetime product catalog for Zamera Pro.
enum ZameraPlanId {
  annualPro(
    productId: 'com.akarworks.zamera.pro.annual',
    titleTr: 'Yıllık Pro',
    badgeTr: '1 AY ÜCRETSİZ DENE',
    subtitleTr: 'İlk 30 gün ücretsiz, ardından yıllık · İstediğin zaman iptal',
    ctaLabelTr: '1 Ay Ücretsiz Başlat',
    fallbackPriceUsd: r'$19.99 / yıl',
    fallbackPriceTry: '₺449,99 / yıl',
    originalFallbackPriceUsd: null,
    originalFallbackPriceTry: null,
    hasFreeTrial: true,
    trialDays: 30,
    isLifetime: false,
    isRecommended: true,
  ),
  lifetimePro(
    productId: 'com.akarworks.zamera.pro.lifetime',
    titleTr: 'Ömür Boyu Pro',
    badgeTr: 'LANSMAN İNDİRİMİ',
    subtitleTr: 'Tek seferlik ödeme · Abonelik yok, ömür boyu sahip ol',
    ctaLabelTr: 'Ömür Boyu Pro Satın Al',
    fallbackPriceUsd: r'$34.99',
    fallbackPriceTry: '₺799,99',
    originalFallbackPriceUsd: r'$49.99',
    originalFallbackPriceTry: '₺1.199,99',
    hasFreeTrial: false,
    trialDays: 0,
    isLifetime: true,
    isRecommended: false,
  ),
  monthlyPro(
    productId: 'com.akarworks.zamera.pro.monthly',
    titleTr: 'Aylık Pro',
    badgeTr: 'ESNEK PLAN',
    subtitleTr: 'Kısa dönem projeler için aylık abonelik',
    ctaLabelTr: 'Aylık Pro Başlat',
    fallbackPriceUsd: r'$3.99 / ay',
    fallbackPriceTry: '₺99,99 / ay',
    originalFallbackPriceUsd: null,
    originalFallbackPriceTry: null,
    hasFreeTrial: false,
    trialDays: 0,
    isLifetime: false,
    isRecommended: false,
  );

  const ZameraPlanId({
    required this.productId,
    required this.titleTr,
    required this.badgeTr,
    required this.subtitleTr,
    required this.ctaLabelTr,
    required this.fallbackPriceUsd,
    required this.fallbackPriceTry,
    required this.originalFallbackPriceUsd,
    required this.originalFallbackPriceTry,
    required this.hasFreeTrial,
    required this.trialDays,
    required this.isLifetime,
    required this.isRecommended,
  });

  final String productId;
  final String titleTr;
  final String badgeTr;
  final String subtitleTr;
  final String ctaLabelTr;
  final String fallbackPriceUsd;
  final String fallbackPriceTry;
  final String? originalFallbackPriceUsd;
  final String? originalFallbackPriceTry;
  final bool hasFreeTrial;
  final int trialDays;
  final bool isLifetime;
  final bool isRecommended;

  static const Map<String, ZameraPlanId> _productRegistry =
      <String, ZameraPlanId>{
        'com.akarworks.zamera.pro.annual': ZameraPlanId.annualPro,
        'com.akarworks.zamera.pro.lifetime': ZameraPlanId.lifetimePro,
        'com.akarworks.zamera.pro.monthly': ZameraPlanId.monthlyPro,
      };

  static ZameraPlanId? fromProductId(String id) => _productRegistry[id];

  static Set<String> get allProductIds => _productRegistry.keys.toSet();

  static ZameraPlanId fromName(
    Object? raw, {
    ZameraPlanId fallback = ZameraPlanId.annualPro,
  }) {
    if (raw is! String || raw.isEmpty) return fallback;
    return values.asNameMap()[raw] ?? fallback;
  }
}

/// Active entitlement tier persisted locally (zero external server tracking).
enum ZameraEntitlementStatus {
  free,
  trialActive,
  proActive,
  proLifetime;

  static ZameraEntitlementStatus fromName(
    Object? raw, {
    ZameraEntitlementStatus fallback = ZameraEntitlementStatus.free,
  }) {
    if (raw is! String || raw.isEmpty) return fallback;
    return values.asNameMap()[raw] ?? fallback;
  }
}

/// OCP-compliant Pro feature gates and daily "Aha-Moment" free allowances.
enum ZameraProFeature {
  colorCheckerCalibration(
    dailyFreeAllowance: 0,
    titleTr: '24-Yama ColorChecker Kalibrasyonu',
    ahaReasonTr:
        'Özel 24-yama sensör matris kalibrasyonu Zamera Pro özelliğidir. 1 ay ücretsiz denemeyle hemen ölçüm yapın.',
  ),
  unlimitedTrueColorCapture(
    dailyFreeAllowance: 1,
    titleTr: 'Sınırsız TrueColor 1:1 Sanat Çekimi',
    ahaReasonTr:
        'Bugünkü 1 ücretsiz TrueColor 1:1 sanat çekiminizi tamamladınız. Sınırsız çekim için 1 ay ücretsiz deneyin.',
  ),
  stickerCutoutExport(
    dailyFreeAllowance: 3,
    titleTr: 'Sınırsız Şeffaf PNG Sticker Kesimi',
    ahaReasonTr:
        'Bugünkü 3 ücretsiz şeffaf sticker dışa aktarım hakkınız doldu. Sınırsız kesim için 1 ay ücretsiz deneyin.',
  ),
  rawDngCaptureAndExport(
    dailyFreeAllowance: 1,
    titleTr: 'Sınırsız 14-Bit DNG RAW & ProRAW',
    ahaReasonTr:
        'Bugünkü 1 ücretsiz RAW DNG çekim/paylaşım hakkınızı kullandınız. JPEG/HEIF her zaman ücretsizdir.',
  ),
  cinemaTenBitLogProRes(
    dailyFreeAllowance: 0,
    titleTr: '10-Bit Sinema (Log/HLG10/ProRes) & Özel LUT',
    ahaReasonTr:
        '10-bit Log/HLG10/ProRes profilleri ve özel .cube 3D LUT yükleme Zamera Pro ile açılır. 4K Rec.709 video ücretsizdir.',
  ),
  losslessPngArchive(
    dailyFreeAllowance: 0,
    titleTr: 'Kayıpsız 1:1 PNG Arşiv Çıktısı',
    ahaReasonTr:
        'Sıkıştırmasız 1:1 kayıpsız PNG arşiv kaydı Zamera Pro (1 ay ücretsiz deneme) ile açılır.',
  );

  const ZameraProFeature({
    required this.dailyFreeAllowance,
    required this.titleTr,
    required this.ahaReasonTr,
  });

  final int dailyFreeAllowance;
  final String titleTr;
  final String ahaReasonTr;
}

/// Immutable storefront price descriptor for a [ZameraPlanId].
@immutable
class ZameraStoreOffer {
  final ZameraPlanId plan;
  final String? localizedPrice;
  final bool isLiveFromStore;

  const ZameraStoreOffer({
    required this.plan,
    this.localizedPrice,
    this.isLiveFromStore = false,
  });

  String priceForLocale({required bool isTurkish}) {
    final live = localizedPrice?.trim();
    if (live != null && live.isNotEmpty) return live;
    return isTurkish ? plan.fallbackPriceTry : plan.fallbackPriceUsd;
  }

  String? originalPriceForLocale({required bool isTurkish}) {
    if (isLiveFromStore) return null;
    return isTurkish
        ? plan.originalFallbackPriceTry
        : plan.originalFallbackPriceUsd;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZameraStoreOffer &&
        other.plan == plan &&
        other.localizedPrice == localizedPrice &&
        other.isLiveFromStore == isLiveFromStore;
  }

  @override
  int get hashCode => Object.hash(plan, localizedPrice, isLiveFromStore);
}

/// Immutable monetization, trial window, and daily quota snapshot.
@immutable
class ZameraMonetizationState {
  final ZameraEntitlementStatus status;
  final ZameraPlanId? activePlan;
  final DateTime? activatedAtUtc;
  final DateTime? trialEndsAtUtc;
  final String usageDayKey;
  final Map<String, int> dailyFeatureCounts;
  final bool isBusy;
  final bool storeAvailable;
  final String? statusMessageTr;
  final Map<ZameraPlanId, ZameraStoreOffer> offers;

  const ZameraMonetizationState({
    required this.status,
    this.activePlan,
    this.activatedAtUtc,
    this.trialEndsAtUtc,
    required this.usageDayKey,
    this.dailyFeatureCounts = const <String, int>{},
    this.isBusy = false,
    this.storeAvailable = false,
    this.statusMessageTr,
    this.offers = const <ZameraPlanId, ZameraStoreOffer>{},
  });

  static Map<ZameraPlanId, ZameraStoreOffer> defaultOffers() {
    return <ZameraPlanId, ZameraStoreOffer>{
      for (final plan in ZameraPlanId.values)
        plan: ZameraStoreOffer(plan: plan),
    };
  }

  static String formatUtcDayKey(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  factory ZameraMonetizationState.initial(String todayKey) {
    return ZameraMonetizationState(
      status: ZameraEntitlementStatus.free,
      usageDayKey: todayKey,
      offers: defaultOffers(),
    );
  }

  bool isEntitledAt(DateTime nowUtc) {
    switch (status) {
      case ZameraEntitlementStatus.proLifetime:
      case ZameraEntitlementStatus.proActive:
        return true;
      case ZameraEntitlementStatus.trialActive:
        final end = trialEndsAtUtc;
        return end == null || nowUtc.toUtc().isBefore(end);
      case ZameraEntitlementStatus.free:
        return false;
    }
  }

  int usedToday(ZameraProFeature feature, String todayKey) {
    if (usageDayKey != todayKey) return 0;
    return dailyFeatureCounts[feature.name] ?? 0;
  }

  int remainingFreeToday(ZameraProFeature feature, String todayKey) {
    if (feature.dailyFreeAllowance <= 0) return 0;
    return (feature.dailyFreeAllowance - usedToday(feature, todayKey)).clamp(
      0,
      feature.dailyFreeAllowance,
    );
  }

  ZameraStoreOffer offerFor(ZameraPlanId plan) {
    return offers[plan] ?? ZameraStoreOffer(plan: plan);
  }

  ZameraMonetizationState copyWith({
    ZameraEntitlementStatus? status,
    ZameraPlanId? activePlan,
    bool clearActivePlan = false,
    DateTime? activatedAtUtc,
    DateTime? trialEndsAtUtc,
    bool clearTrialEndsAt = false,
    String? usageDayKey,
    Map<String, int>? dailyFeatureCounts,
    bool? isBusy,
    bool? storeAvailable,
    String? statusMessageTr,
    bool clearStatusMessage = false,
    Map<ZameraPlanId, ZameraStoreOffer>? offers,
  }) {
    return ZameraMonetizationState(
      status: status ?? this.status,
      activePlan: clearActivePlan ? null : (activePlan ?? this.activePlan),
      activatedAtUtc: activatedAtUtc ?? this.activatedAtUtc,
      trialEndsAtUtc: clearTrialEndsAt
          ? null
          : (trialEndsAtUtc ?? this.trialEndsAtUtc),
      usageDayKey: usageDayKey ?? this.usageDayKey,
      dailyFeatureCounts: dailyFeatureCounts ?? this.dailyFeatureCounts,
      isBusy: isBusy ?? this.isBusy,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      statusMessageTr: clearStatusMessage
          ? null
          : (statusMessageTr ?? this.statusMessageTr),
      offers: offers ?? this.offers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status.name,
      if (activePlan != null) 'activePlan': activePlan!.name,
      if (activatedAtUtc != null)
        'activatedAtUtc': activatedAtUtc!.toUtc().toIso8601String(),
      if (trialEndsAtUtc != null)
        'trialEndsAtUtc': trialEndsAtUtc!.toUtc().toIso8601String(),
      'usageDayKey': usageDayKey,
      'dailyFeatureCounts': dailyFeatureCounts,
    };
  }

  factory ZameraMonetizationState.fromJson(
    Map<Object?, Object?> json, {
    required String fallbackTodayKey,
  }) {
    final rawCounts = json['dailyFeatureCounts'];
    final parsedCounts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final key = entry.key?.toString();
        final val = entry.value;
        if (key != null && key.isNotEmpty && val is num && val.isFinite) {
          parsedCounts[key] = val.toInt().clamp(0, 100000);
        }
      }
    }

    final rawDayKey = json['usageDayKey']?.toString().trim();
    final effectiveDayKey = (rawDayKey != null && rawDayKey.isNotEmpty)
        ? rawDayKey
        : fallbackTodayKey;

    final rawActivePlan = json['activePlan'];
    final activePlan = rawActivePlan is String && rawActivePlan.isNotEmpty
        ? ZameraPlanId.fromName(rawActivePlan)
        : null;

    return ZameraMonetizationState(
      status: ZameraEntitlementStatus.fromName(json['status']),
      activePlan: activePlan,
      activatedAtUtc: _parseUtcIso(json['activatedAtUtc']),
      trialEndsAtUtc: _parseUtcIso(json['trialEndsAtUtc']),
      usageDayKey: effectiveDayKey,
      dailyFeatureCounts: effectiveDayKey == fallbackTodayKey
          ? Map<String, int>.unmodifiable(parsedCounts)
          : const <String, int>{},
      offers: defaultOffers(),
    );
  }

  static DateTime? _parseUtcIso(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
