import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has completed the first-launch Kilerce user guide.
class UserGuideService {
  static final UserGuideService instance = UserGuideService._internal();
  UserGuideService._internal();

  static const String prefCompletedKey = 'kilerce_user_guide_completed_v1';

  Future<bool> hasCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefCompletedKey) ?? false;
    } catch (e) {
      debugPrint('UserGuideService.hasCompleted error: $e');
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefCompletedKey, true);
    } catch (e) {
      debugPrint('UserGuideService.markCompleted error: $e');
    }
  }

  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefCompletedKey);
    } catch (e) {
      debugPrint('UserGuideService.reset error: $e');
    }
  }
}
