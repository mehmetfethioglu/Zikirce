import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScreenAwakeService {
  static const MethodChannel _channel = MethodChannel('com.akarworks.zikirce/battery_optimization');

  /// Toggles Android FLAG_KEEP_SCREEN_ON to keep screen awake during Quran reading & Dhikr.
  static Future<void> setKeepAwake(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setKeepScreenAwake', {'enabled': enabled});
      debugPrint('[ScreenAwakeService] setKeepAwake set to: $enabled');
    } catch (e) {
      debugPrint('[ScreenAwakeService] Error setting screen awake: $e');
    }
  }
}
