import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('com.akarworks.zikirce/battery_optimization');

  static Future<String> getManufacturer() async {
    try {
      final res = await _channel.invokeMethod<String>('getManufacturer');
      return res ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> openAutoStart() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAutoStart');
      return res ?? false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] openAutoStart error: $e');
      return false;
    }
  }

  static Future<bool> openBatterySaverNoRestrictions() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBatterySaverNoRestrictions');
      return res ?? false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] openBatterySaverNoRestrictions error: $e');
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] openNotificationSettings error: $e');
      return false;
    }
  }

  static Future<bool> openExactAlarmSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openExactAlarmSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] openExactAlarmSettings error: $e');
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      final res = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return res ?? true;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] canScheduleExactAlarms error: $e');
      return true;
    }
  }

  static Future<bool> openAppPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppPermissions');
      return res ?? false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] openAppPermissions error: $e');
      return false;
    }
  }
}
