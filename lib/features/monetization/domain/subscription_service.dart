import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../profile/domain/user_profile_service.dart';

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

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  /// Flag to force Test Ads during testing
  static const bool useTestAdsForClosedTesting = true;

  /// Production AdMob Credentials
  static const String prodAppId = 'ca-app-pub-8040358402439788~2110636475';
  static const String prodBannerAdUnitId = 'ca-app-pub-8040358402439788/3028398253';
  static const String prodRewardedAdUnitId = 'ca-app-pub-8040358402439788/3028398253';
  static const String prodInterstitialAdUnitId = 'ca-app-pub-8040358402439788/3028398253';

  /// Google Official Test AdMob Credentials
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testIosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  static const String testIosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  static String get bannerAdUnitId =>
      (useTestAdsForClosedTesting || kDebugMode)
          ? ((!kIsWeb && Platform.isIOS) ? testIosBannerAdUnitId : testBannerAdUnitId)
          : prodBannerAdUnitId;

  static String get rewardedAdUnitId =>
      (useTestAdsForClosedTesting || kDebugMode)
          ? ((!kIsWeb && Platform.isIOS) ? testIosRewardedAdUnitId : testRewardedAdUnitId)
          : prodRewardedAdUnitId;

  static String get interstitialAdUnitId =>
      (useTestAdsForClosedTesting || kDebugMode)
          ? ((!kIsWeb && Platform.isIOS) ? testIosInterstitialAdUnitId : testInterstitialAdUnitId)
          : prodInterstitialAdUnitId;

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

  /// Checks if the user is currently in an active Ad-Free window
  Future<bool> isAdFree() async {
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
    if (clean.contains('TESTER') || clean.contains('KAPALI')) {
      await activateTesterLicense(code: clean);
      return PromoCodeRedeemResult(
        status: PromoCodeStatus.success,
        message: '🧪 Tester Lisansı aktifleştirildi! 1 Yıl Boyunca Reklamsız Kullanım tanımlandı.',
      );
    }
    await addAdFreeHours(72);
    return PromoCodeRedeemResult(
      status: PromoCodeStatus.success,
      message: '🎉 Promosyon kodu kabul edildi: +3 Gün (72 Saat) Reklamsız Kullanım eklendi!',
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
