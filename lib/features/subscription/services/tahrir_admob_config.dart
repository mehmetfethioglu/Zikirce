import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Platform-specific Google AdMob Rewarded Ad configuration for Tahrir.
/// Banner ads are intentionally omitted across the entire application.
/// Uses Google's official Test Rewarded Ad Unit IDs during Closed Testing,
/// and supports `--dart-define` overrides for production release builds.
class TahrirAdMobConfig {
  TahrirAdMobConfig._();

  static const String androidRewardedUnitId = String.fromEnvironment(
    'TAHRIR_ADMOB_ANDROID_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const String iosRewardedUnitId = String.fromEnvironment(
    'TAHRIR_ADMOB_IOS_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// True when running natively on Android or iOS outside headless `flutter test`.
  static bool get isNativeMobileAdsSupported {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      debugPrint('TahrirAdMobConfig platform check failed: $e');
      return false;
    }
  }

  /// Active full-screen Rewarded Ad Unit ID for the current mobile platform.
  static String get activeRewardedUnitId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return iosRewardedUnitId;
    }
    return androidRewardedUnitId;
  }
}
