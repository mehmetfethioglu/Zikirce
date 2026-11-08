import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_version_info.dart';

/// Service managing persistent version tracking and launch state detection.
class VersionTrackingService {
  static const String _kKeyLastSeenVersion = 'zamera_last_seen_version';
  static const String _kKeyLastSeenBuild = 'zamera_last_seen_build';
  static const String _kKeyHasCompletedOnboarding = 'zamera_has_completed_onboarding';

  final SharedPreferences _prefs;

  const VersionTrackingService(this._prefs);

  /// Initializes the service with SharedPreferences.
  static Future<VersionTrackingService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return VersionTrackingService(prefs);
  }

  /// Whether this is the very first time Zamera is ever opened on this device.
  bool get isFirstLaunch {
    final hasOnboarded = _prefs.getBool(_kKeyHasCompletedOnboarding) ?? false;
    final lastVersion = _prefs.getString(_kKeyLastSeenVersion);
    return !hasOnboarded && (lastVersion == null || lastVersion.isEmpty);
  }

  /// Whether the app was updated since the user last ran it.
  bool get isVersionUpdate {
    if (isFirstLaunch) return false;
    final lastBuild = _prefs.getInt(_kKeyLastSeenBuild) ?? 0;
    return lastBuild > 0 && lastBuild < AppVersionInfo.currentBuildNumber;
  }

  /// The version string recorded from the previous run.
  String? get previousVersion => _prefs.getString(_kKeyLastSeenVersion);

  /// Marks the current version as seen so automated prompts only trigger once per release.
  Future<bool> markCurrentVersionSeen() async {
    try {
      final s1 = await _prefs.setString(
        _kKeyLastSeenVersion,
        AppVersionInfo.currentVersion,
      );
      final s2 = await _prefs.setInt(
        _kKeyLastSeenBuild,
        AppVersionInfo.currentBuildNumber,
      );
      final s3 = await _prefs.setBool(_kKeyHasCompletedOnboarding, true);
      return s1 && s2 && s3;
    } catch (e, stackTrace) {
      debugPrint('Error writing version tracking prefs: $e\n$stackTrace');
      return false;
    }
  }
}
