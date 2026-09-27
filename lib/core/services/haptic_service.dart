import 'package:flutter/services.dart';

class HapticService {
  static bool isHapticEnabled = true;

  /// Subtle tactile click for each dhikr tap
  static void countTap() {
    if (!isHapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Subtle tactile click for each dhikr tap
  static void tapClick() {
    if (!isHapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Medium impact on reaching round boundaries (33, 99)
  static void roundCompleted() {
    if (!isHapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Celebratory double pulse on reaching total target
  static void targetReached() {
    if (!isHapticEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// UI interaction click
  static void selectionClick() {
    if (!isHapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Light tactile feedback
  static void lightImpact() {
    if (!isHapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Error vibration
  static void error() {
    if (!isHapticEnabled) return;
    HapticFeedback.vibrate();
  }
}
