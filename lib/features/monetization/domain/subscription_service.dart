import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import '../../profile/domain/user_profile_service.dart';
import '../../recipes/data/kilerce_cloud_recipe_client.dart';
import '../../recipes/data/kilerce_edge_config.dart';
import 'kilerce_pro_models.dart';

enum VolunteerDetectiveRank {
  novice,
  bronze,
  silver,
  gold,
}

class VolunteerBadgeInfo {
  final VolunteerDetectiveRank rank;
  final String title;
  final String emoji;
  final int totalContributions;

  const VolunteerBadgeInfo({
    required this.rank,
    required this.title,
    required this.emoji,
    required this.totalContributions,
  });
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  static const String _keyAdFreeUntil = 'ad_free_until_timestamp_ms';
  static const String _keyTotalContributions = 'total_volunteer_contributions';
  static const String _keyScanCounter = 'total_scans_since_ad';
  static const String _keyIsTester = 'is_tester_user';
  static const String _keyIsPremium = 'is_premium_user';
  static const String _keyRedeemedPromoCodes = 'redeemed_promo_codes';
  static const String _keyRewardAdProgress = 'kilerce_reward_ad_progress_v1';
  static const String _keyRewardAdResetMs = 'kilerce_reward_ad_reset_ms_v1';
  static const String _keyRewardPassesDate = 'kilerce_reward_passes_date_v1';
  static const String _keyRewardPassesToday = 'kilerce_reward_passes_today_v1';
  static const int rewardAdsRequired = 3;
  static const int rewardProHours = 3;
  static const int maxDailyRewardPasses = 2;
  static const String revenueCatEntitlementId = 'pro';

  bool _revenueCatConfigured = false;
  bool _revenueCatProActive = false;
  KilerceEntitlementSnapshot? _latestCloudEntitlement;

  static const Set<String> _validTesterCodes = {
    'TESTER2026',
    'KAPALI2026',
    'KILERCE_TESTER',
  };
  static const Set<String> _validCampaignCodes = {
    'KILERCE2026',
    'KILERCE3GUN',
    'TEMIZMUTFAK',
  };

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  /// Flag to force Test Ads during closed testing; override via --dart-define=USE_TEST_ADS=false
  static const bool useTestAdsForClosedTesting = bool.fromEnvironment(
    'USE_TEST_ADS',
    defaultValue: true,
  );

  /// Production AdMob Credentials (distinct per platform & ad format)
  static const String prodAppId = 'ca-app-pub-8040358402439788~2110636475';
  static const String prodAndroidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-8040358402439788/3028398253',
  );
  static const String prodAndroidRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
    defaultValue: '',
  );
  static const String prodAndroidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: '',
  );
  static const String prodIosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: '',
  );
  static const String prodIosRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
    defaultValue: '',
  );
  static const String prodIosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
    defaultValue: '',
  );

  /// Google Official Test AdMob Credentials
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testIosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  static const String testIosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  static String _resolveUnitId({
    required String prodAndroid,
    required String prodIos,
    required String testAndroid,
    required String testIos,
  }) {
    final bool isIos = !kIsWeb && Platform.isIOS;
    final String fallbackTest = isIos ? testIos : testAndroid;
    if (useTestAdsForClosedTesting || kDebugMode) {
      return fallbackTest;
    }
    final String prod = (isIos ? prodIos : prodAndroid).trim();
    return prod.isNotEmpty ? prod : fallbackTest;
  }

  static String get bannerAdUnitId => _resolveUnitId(
        prodAndroid: prodAndroidBannerAdUnitId,
        prodIos: prodIosBannerAdUnitId,
        testAndroid: testBannerAdUnitId,
        testIos: testIosBannerAdUnitId,
      );

  static String get rewardedAdUnitId => _resolveUnitId(
        prodAndroid: prodAndroidRewardedAdUnitId,
        prodIos: prodIosRewardedAdUnitId,
        testAndroid: testRewardedAdUnitId,
        testIos: testIosRewardedAdUnitId,
      );

  static String get interstitialAdUnitId => _resolveUnitId(
        prodAndroid: prodAndroidInterstitialAdUnitId,
        prodIos: prodIosInterstitialAdUnitId,
        testAndroid: testInterstitialAdUnitId,
        testIos: testIosInterstitialAdUnitId,
      );

  Future<void> initAdMob() async {
    try {
      await MobileAds.instance.initialize();
      loadRewardedAd();
      loadInterstitialAd();
    } catch (e) {
      debugPrint('AdMob Init Error: $e');
    }
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  bool get isRewardedAdAvailable => _isRewardedAdLoaded && _rewardedAd != null;

  Future<bool> showRewardedAd({required VoidCallback onRewardGranted}) async {
    if (_rewardedAd != null && _isRewardedAdLoaded) {
      final String appUserId =
          await KilerceCloudRecipeClient.instance.getOrCreateAppUserId();
      try {
        await _rewardedAd!.setServerSideOptions(
          ServerSideVerificationOptions(userId: appUserId),
        );
      } catch (e) {
        debugPrint('SSV options attach skipped: $e');
      }

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadRewardedAd();
        },
      );

      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onRewardGranted();
        },
      );
      return true;
    }
    return false;
  }

  /// Configures RevenueCat SDK on mobile targets when a build-time API key is present.
  Future<void> initRevenueCat() async {
    if (_revenueCatConfigured || kIsWeb) return;
    final String apiKey = Platform.isIOS
        ? KilerceEdgeConfig.revenueCatIosKey.trim()
        : KilerceEdgeConfig.revenueCatAndroidKey.trim();
    if (apiKey.isEmpty) return;

    try {
      final appUserId =
          await KilerceCloudRecipeClient.instance.getOrCreateAppUserId();
      final cfg = rc.PurchasesConfiguration(apiKey)..appUserID = appUserId;
      await rc.Purchases.configure(cfg);
      _revenueCatConfigured = true;
      await syncRevenueCatCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  Future<bool> syncRevenueCatCustomerInfo() async {
    if (!_revenueCatConfigured || kIsWeb) return _revenueCatProActive;
    try {
      final info = await rc.Purchases.getCustomerInfo();
      _revenueCatProActive =
          info.entitlements.active.containsKey(revenueCatEntitlementId) ||
          info.entitlements.active.isNotEmpty;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, _revenueCatProActive);
      return _revenueCatProActive;
    } catch (e) {
      debugPrint('RevenueCat sync error: $e');
      return _revenueCatProActive;
    }
  }

  /// Fetches live store prices per plan tier from RevenueCat when configured.
  Future<Map<KilercePlanTier, String>> getLocalizedPlanPrices() async {
    final Map<KilercePlanTier, String> prices = {
      for (final tier in KilercePlanTier.values) tier: tier.fallbackPrice,
    };
    if (!_revenueCatConfigured || kIsWeb) return prices;
    try {
      final offerings = await rc.Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const [];
      for (final pkg in packages) {
        final matchedTier =
            KilercePlanTier.fromProductId(pkg.storeProduct.identifier);
        if (matchedTier != null &&
            pkg.storeProduct.priceString.trim().isNotEmpty) {
          prices[matchedTier] = pkg.storeProduct.priceString;
        }
      }
    } catch (e) {
      debugPrint('RevenueCat getLocalizedPlanPrices error: $e');
    }
    return prices;
  }

  static String _utcDateKey() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  Future<int> getDailyRewardPassesUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _utcDateKey();
    if (prefs.getString(_keyRewardPassesDate) != today) return 0;
    return (prefs.getInt(_keyRewardPassesToday) ?? 0)
        .clamp(0, maxDailyRewardPasses);
  }

  /// Records 1 completed Rewarded Ad; unlocks +3h Pro Pass on 3/3 ads (max 2x/day).
  Future<({
    int progress,
    int required,
    bool unlockedPro3h,
    bool dailyLimitReached,
    int dailyPassesUsed,
    int dailyPassesLimit,
  })> recordRewardedAdStep() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = _utcDateKey();
    final int passesUsed = prefs.getString(_keyRewardPassesDate) == today
        ? (prefs.getInt(_keyRewardPassesToday) ?? 0)
        : 0;
    if (passesUsed >= maxDailyRewardPasses) {
      return (
        progress: 0,
        required: rewardAdsRequired,
        unlockedPro3h: false,
        dailyLimitReached: true,
        dailyPassesUsed: passesUsed,
        dailyPassesLimit: maxDailyRewardPasses,
      );
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int resetMs = prefs.getInt(_keyRewardAdResetMs) ?? 0;
    final int current =
        (resetMs > 0 && resetMs <= nowMs)
            ? 0
            : (prefs.getInt(_keyRewardAdProgress) ?? 0);

    final cloudSnap =
        await KilerceCloudRecipeClient.instance.recordRewardedAdStepOnCloud();
    if (cloudSnap != null) {
      _latestCloudEntitlement = cloudSnap;
      await prefs.setString(_keyRewardPassesDate, today);
      await prefs.setInt(_keyRewardPassesToday, cloudSnap.dailyRewardPassesUsed);
      await prefs.setInt(_keyRewardAdProgress, cloudSnap.adProgress);
      await prefs.setInt(
        _keyRewardAdResetMs,
        cloudSnap.adProgress > 0 ? nowMs + (24 * 3600 * 1000) : 0,
      );
      if (cloudSnap.isPro && cloudSnap.proUntilMs > 0) {
        final currentUntil = prefs.getInt(_keyAdFreeUntil) ?? 0;
        if (cloudSnap.proUntilMs > currentUntil) {
          await prefs.setInt(_keyAdFreeUntil, cloudSnap.proUntilMs);
        }
      }
      final bool unlockedFromCloud = cloudSnap.isPro &&
          cloudSnap.adProgress == 0 &&
          (cloudSnap.dailyRewardPassesUsed > passesUsed ||
              current + 1 >= rewardAdsRequired);
      final bool limitHitFromCloud = !unlockedFromCloud &&
          cloudSnap.dailyRewardPassesUsed >= cloudSnap.dailyRewardPassesLimit &&
          cloudSnap.adProgress == 0;
      return (
        progress: cloudSnap.adProgress,
        required: cloudSnap.adsRequired,
        unlockedPro3h: unlockedFromCloud,
        dailyLimitReached: limitHitFromCloud,
        dailyPassesUsed: cloudSnap.dailyRewardPassesUsed,
        dailyPassesLimit: cloudSnap.dailyRewardPassesLimit,
      );
    }

    final int next = current + 1;

    if (next >= rewardAdsRequired) {
      final int nextPasses = passesUsed + 1;
      await addAdFreeHours(rewardProHours);
      await prefs.setInt(_keyRewardAdProgress, 0);
      await prefs.setInt(_keyRewardAdResetMs, 0);
      await prefs.setString(_keyRewardPassesDate, today);
      await prefs.setInt(_keyRewardPassesToday, nextPasses);
      return (
        progress: 0,
        required: rewardAdsRequired,
        unlockedPro3h: true,
        dailyLimitReached: false,
        dailyPassesUsed: nextPasses,
        dailyPassesLimit: maxDailyRewardPasses,
      );
    }

    await prefs.setInt(_keyRewardAdProgress, next);
    await prefs.setInt(_keyRewardAdResetMs, nowMs + (24 * 3600 * 1000));
    return (
      progress: next,
      required: rewardAdsRequired,
      unlockedPro3h: false,
      dailyLimitReached: false,
      dailyPassesUsed: passesUsed,
      dailyPassesLimit: maxDailyRewardPasses,
    );
  }

  Future<int> getRewardAdProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int resetMs = prefs.getInt(_keyRewardAdResetMs) ?? 0;
    if (resetMs > 0 && resetMs <= nowMs) return 0;
    return (prefs.getInt(_keyRewardAdProgress) ?? 0).clamp(0, rewardAdsRequired);
  }

  Future<KilerceEntitlementSnapshot> syncCloudEntitlement() async {
    var snap = await KilerceCloudRecipeClient.instance.fetchEntitlement();
    final prefs = await SharedPreferences.getInstance();
    if (snap != null && !snap.isPro && prefs.getBool(_keyIsTester) == true) {
      final upgraded =
          await KilerceCloudRecipeClient.instance.redeemPromoCodeOnCloud('TESTER2026');
      if (upgraded != null) {
        snap = upgraded;
      }
    }
    if (snap != null) {
      _latestCloudEntitlement = snap;
      await prefs.setString(_keyRewardPassesDate, _utcDateKey());
      await prefs.setInt(_keyRewardPassesToday, snap.dailyRewardPassesUsed);
      await prefs.setInt(_keyRewardAdProgress, snap.adProgress);
      if (snap.isPro && !snap.isLifetime && snap.proUntilMs > 0) {
        final currentUntil = prefs.getInt(_keyAdFreeUntil) ?? 0;
        if (snap.proUntilMs > currentUntil) {
          await prefs.setInt(_keyAdFreeUntil, snap.proUntilMs);
        }
      } else if (snap.isLifetime) {
        await prefs.setBool(_keyIsPremium, true);
      }
      return snap;
    }

    final bool localPro = await isAdFree();
    final int progress = await getRewardAdProgress();
    final int passesUsed = await getDailyRewardPassesUsed();
    return KilerceEntitlementSnapshot(
      isPro: localPro,
      tier: localPro ? 'pro' : 'free',
      proUntilMs: prefs.getInt(_keyAdFreeUntil) ?? 0,
      adProgress: progress,
      adsRequired: rewardAdsRequired,
      dailyRewardPassesUsed: passesUsed,
      dailyRewardPassesLimit: maxDailyRewardPasses,
    );
  }

  Future<PurchaseResult> purchaseProTier(KilercePlanTier tier) async {
    if (!_revenueCatConfigured || kIsWeb) {
      return PurchaseResult(
        success: false,
        message:
            'Mağaza bağlantısı henüz aktif değil. Günde 2 kez 3 kısa reklam izleyerek 3 saat ücretsiz Pro kullanabilirsiniz.',
      );
    }
    try {
      final offerings = await rc.Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? const [];
      rc.Package? targetPkg;
      for (final pkg in packages) {
        if (KilercePlanTier.fromProductId(pkg.storeProduct.identifier) ==
            tier) {
          targetPkg = pkg;
          break;
        }
      }
      if (targetPkg == null) {
        return PurchaseResult(
          success: false,
          message: '${tier.title} paketi mağazada bulunamadı.',
        );
      }

      await rc.Purchases.purchase(rc.PurchaseParams.package(targetPkg));
      final bool isActive = await syncRevenueCatCustomerInfo();
      unawaited(syncCloudEntitlement());
      if (isActive) {
        return PurchaseResult(
          success: true,
          message: '🎉 ${tier.title} aktif edildi! Keyfini çıkarın.',
        );
      }
      return PurchaseResult(
        success: false,
        message: 'Satın alma doğrulaması bekleniyor.',
      );
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(
          success: false,
          userCancelled: true,
          message: 'Satın alma iptal edildi.',
        );
      }
      return PurchaseResult(
        success: false,
        message: 'Satın alma tamamlanamadı: ${e.message ?? code.name}',
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        message: 'Satın alma hatası: $e',
      );
    }
  }

  Future<PurchaseResult> restoreProPurchases() async {
    if (!_revenueCatConfigured || kIsWeb) {
      await syncCloudEntitlement();
      return PurchaseResult(
        success: false,
        message: 'Mağaza oturumu şu an aktif değil.',
      );
    }
    try {
      final info = await rc.Purchases.restorePurchases();
      _revenueCatProActive =
          info.entitlements.active.containsKey(revenueCatEntitlementId) ||
          info.entitlements.active.isNotEmpty;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, _revenueCatProActive);
      unawaited(syncCloudEntitlement());
      if (_revenueCatProActive) {
        return PurchaseResult(
          success: true,
          message: '✅ Pro üyeliğiniz başarıyla geri yüklendi.',
        );
      }
      return PurchaseResult(
        success: false,
        message: 'Bu hesaba bağlı aktif bir Pro aboneliği bulunamadı.',
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        message: 'Geri yükleme hatası: $e',
      );
    }
  }

  /// Increments scan counter and triggers an interstitial ad every 5 scans if not ad-free.
  Future<void> triggerScanInterstitialIfDue() async {
    final bool adFree = await isAdFree();
    if (adFree) return;

    final prefs = await SharedPreferences.getInstance();
    int scans = prefs.getInt(_keyScanCounter) ?? 0;
    scans += 1;
    await prefs.setInt(_keyScanCounter, scans);

    if (scans % 5 == 0 && _isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitialAd();
        },
      );
      await _interstitialAd!.show();
    }
  }

  // --- Sınırsız Tarama & Reklamsız Süre Yönetimi ---

  /// Scans are 100% free and unlimited.
  Future<bool> canScan() async => true;

  Future<void> consumeScan() async {
    await triggerScanInterstitialIfDue();
  }

  /// Checks if the user is currently in an active Pro / Ad-Free window.
  Future<bool> isAdFree() async {
    if (_revenueCatProActive || (_latestCloudEntitlement?.isPro ?? false)) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyIsTester) == true) return true;
    if (prefs.getBool(_keyIsPremium) == true) return true;

    final int expireAt = prefs.getInt(_keyAdFreeUntil) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expireAt;
  }

  /// Compatibility with legacy isPremium check:
  /// Active ad-free users or testers enjoy ad-free experience.
  Future<bool> isPremium() async => await isAdFree();

  /// Gets remaining ad-free duration
  Future<Duration> getRemainingAdFreeDuration() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyIsTester) == true || prefs.getBool(_keyIsPremium) == true) {
      return const Duration(days: 365);
    }
    final int expireAt = prefs.getInt(_keyAdFreeUntil) ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int diff = expireAt - now;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  /// Adds ad-free hours (stacks with existing active time)
  Future<void> addAdFreeHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int currentExpire = prefs.getInt(_keyAdFreeUntil) ?? 0;

    final int baseTime = currentExpire > now ? currentExpire : now;
    final int newExpire = baseTime + (hours * 3600 * 1000);
    await prefs.setInt(_keyAdFreeUntil, newExpire);
  }

  /// Target contribution threshold to unlock 24-hours ad-free
  static const int contributionRewardThreshold = 5;

  /// Rewards a volunteer user for photographing an incomplete product's label.
  /// Activates +24 Hours Ad-Free on every 5th completed contribution.
  Future<ContributionRewardResult> rewardContribution() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_keyTotalContributions) ?? 0;
    count += 1;
    await prefs.setInt(_keyTotalContributions, count);

    // Sync with UserProfileService for XP (+50 XP) and badge progress
    await UserProfileService.instance.recordContribution();

    final badge = await getVolunteerBadge();
    final int cycleProgress = count % contributionRewardThreshold;
    final bool reachedMilestone = (count > 0 && cycleProgress == 0);

    if (reachedMilestone) {
      await addAdFreeHours(24);
      return ContributionRewardResult(
        success: true,
        message: '🎉 Tebrikler! 5 ürün katkısına ulaştınız ve +24 Saat Reklamsız Kullanım aktifleşti! (${badge.title})',
        tier: UserSubscriptionTier.free,
        earnedScans: 999,
        currentPoints: count,
        reachedMilestone: true,
      );
    } else {
      final int remaining = contributionRewardThreshold - cycleProgress;
      return ContributionRewardResult(
        success: true,
        message: '📸 Katkınız kaydedildi ($cycleProgress/$contributionRewardThreshold Ürün). +24 Saat Reklamsız Kullanım için $remaining ürün daha kaldı! (${badge.title})',
        tier: UserSubscriptionTier.free,
        earnedScans: 0,
        currentPoints: count,
        reachedMilestone: false,
      );
    }
  }

  /// Current progress within the 5-item reward cycle (0 to 4)
  Future<int> getContributionCycleProgress() async {
    final count = await getTotalContributions();
    return count % contributionRewardThreshold;
  }

  /// Total count of product contributions made by user
  Future<int> getTotalContributions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalContributions) ?? 0;
  }

  /// Computes Volunteer Detective Badge based on contribution count
  Future<VolunteerBadgeInfo> getVolunteerBadge() async {
    final int total = await getTotalContributions();
    if (total >= 15) {
      return VolunteerBadgeInfo(
        rank: VolunteerDetectiveRank.gold,
        title: 'Altın Gıda Dedektifi',
        emoji: '🥇',
        totalContributions: total,
      );
    } else if (total >= 5) {
      return VolunteerBadgeInfo(
        rank: VolunteerDetectiveRank.silver,
        title: 'Gümüş Gıda Dedektifi',
        emoji: '🥈',
        totalContributions: total,
      );
    } else if (total >= 1) {
      return VolunteerBadgeInfo(
        rank: VolunteerDetectiveRank.bronze,
        title: 'Bronz Gıda Dedektifi',
        emoji: '🥉',
        totalContributions: total,
      );
    } else {
      return VolunteerBadgeInfo(
        rank: VolunteerDetectiveRank.novice,
        title: 'Gıda Gönüllüsü',
        emoji: '🌱',
        totalContributions: total,
      );
    }
  }

  // --- Legacy Compatibility Stubs (Preventing breaks in any older screens) ---
  Future<int> getRemainingScans() async => 99999;
  Future<bool> isTester() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsTester) ?? false;
  }
  Future<void> activateTesterLicense({String? code}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsTester, true);
    await addAdFreeHours(365 * 24);
  }
  Future<void> deactivateTesterLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsTester, false);
    await prefs.remove(_keyAdFreeUntil);
  }
  Future<UserSubscriptionTier> getSubscriptionTier() async => UserSubscriptionTier.free;
  Future<void> setSubscriptionTier(UserSubscriptionTier tier) async {}
  Future<void> addRewardScans(int count) async {
    await addAdFreeHours(6 * count);
  }
  Future<int> getContributionPoints() async => await getTotalContributions();
  Future<List<String>> getGeneratedGiftCodes() async => [];
  Future<PurchaseResult> restorePurchases() async =>
      PurchaseResult(success: true, message: 'Abonelik modeli kaldırıldı. Tüm özellikler ücretsizdir!');
  Future<PurchaseResult> purchaseSubscriptionTier(UserSubscriptionTier tier, {dynamic package}) async =>
      PurchaseResult(success: true, message: 'Abonelik modeli kaldırıldı. Tüm özellikler ücretsizdir!');
  Future<PromoCodeRedeemResult> redeemPromoCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return PromoCodeRedeemResult(
        status: PromoCodeStatus.invalid,
        message: 'Lütfen geçerli bir promosyon kodu girin.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> redeemed =
        prefs.getStringList(_keyRedeemedPromoCodes) ?? <String>[];
    final bool isTesterCode = _validTesterCodes.contains(clean);
    final bool isCampaignCode = _validCampaignCodes.contains(clean);

    if (redeemed.contains(clean)) {
      if ((isTesterCode || isCampaignCode) &&
          _latestCloudEntitlement?.isPro != true) {
        final cloudSnap =
            await KilerceCloudRecipeClient.instance.redeemPromoCodeOnCloud(clean);
        if (cloudSnap != null && cloudSnap.isPro) {
          _latestCloudEntitlement = cloudSnap;
          if (cloudSnap.proUntilMs > (prefs.getInt(_keyAdFreeUntil) ?? 0)) {
            await prefs.setInt(_keyAdFreeUntil, cloudSnap.proUntilMs);
          }
          return PromoCodeRedeemResult(
            status: PromoCodeStatus.success,
            message: '✅ Pro lisansınız bulut hesabınızla eşitlendi!',
          );
        }
      }
      return PromoCodeRedeemResult(
        status: PromoCodeStatus.alreadyRedeemed,
        message: 'Bu promosyon kodu bu cihazda daha önce kullanılmış.',
      );
    }

    if (isTesterCode) {
      await activateTesterLicense(code: clean);
      await prefs.setStringList(_keyRedeemedPromoCodes, [...redeemed, clean]);
      final cloudSnap =
          await KilerceCloudRecipeClient.instance.redeemPromoCodeOnCloud(clean);
      if (cloudSnap != null) {
        _latestCloudEntitlement = cloudSnap;
      }
      return PromoCodeRedeemResult(
        status: PromoCodeStatus.success,
        message: '🧪 Tester Lisansı aktifleştirildi! 1 Yıl Boyunca Reklamsız Kullanım tanımlandı.',
      );
    }

    if (isCampaignCode) {
      await addAdFreeHours(72);
      await prefs.setStringList(_keyRedeemedPromoCodes, [...redeemed, clean]);
      final cloudSnap =
          await KilerceCloudRecipeClient.instance.redeemPromoCodeOnCloud(clean);
      if (cloudSnap != null) {
        _latestCloudEntitlement = cloudSnap;
      }
      return PromoCodeRedeemResult(
        status: PromoCodeStatus.success,
        message: '🎉 Promosyon kodu kabul edildi: +3 Gün (72 Saat) Reklamsız Kullanım eklendi!',
      );
    }

    return PromoCodeRedeemResult(
      status: PromoCodeStatus.invalid,
      message: 'Geçersiz veya süresi dolmuş promosyon kodu.',
    );
  }
}

enum UserSubscriptionTier { free, pro, lifetimePro, tester }

class ContributionRewardResult {
  final bool success;
  final String message;
  final UserSubscriptionTier tier;
  final int earnedScans;
  final int currentPoints;
  final bool reachedMilestone;
  final String? generatedGiftCode;

  ContributionRewardResult({
    required this.success,
    required this.message,
    required this.tier,
    this.earnedScans = 0,
    this.currentPoints = 0,
    this.reachedMilestone = false,
    this.generatedGiftCode,
  });
}

enum PromoCodeStatus { success, invalid, alreadyRedeemed }

class PromoCodeRedeemResult {
  final PromoCodeStatus status;
  final String message;

  PromoCodeRedeemResult({required this.status, required this.message});
}

class PurchaseResult {
  final bool success;
  final bool userCancelled;
  final String message;

  PurchaseResult({required this.success, this.userCancelled = false, required this.message});
}
