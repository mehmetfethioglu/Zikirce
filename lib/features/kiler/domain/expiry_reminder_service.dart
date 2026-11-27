import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/kilerce_notification_service.dart';
import 'kiler_models.dart';
import 'kiler_service.dart';

/// Daily local expiry reminder service backed by Android NotificationChannel
/// via MethodChannel and user preference persistence.
class ExpiryReminderService {
  static final ExpiryReminderService instance = ExpiryReminderService._internal();
  ExpiryReminderService._internal();

  static const MethodChannel _channel = MethodChannel('com.akarworks.kilerce/notifications');
  static const String _prefEnabled = 'skt_reminders_enabled';
  static const String _prefLastNotifiedDay = 'skt_last_notified_day';

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefEnabled) ?? true;
    } catch (e) {
      debugPrint('ExpiryReminderService.isEnabled error: $e');
      return true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, enabled);
      if (enabled) {
        unawaited(KilerceNotificationService.instance.syncExpiryReminder());
      } else {
        unawaited(KilerceNotificationService.instance.cancelExpirySchedule());
      }
    } catch (e) {
      debugPrint('ExpiryReminderService.setEnabled error: $e');
    }
  }

  /// Checks pantry items expiring soon and dispatches at most one notification per day.
  Future<bool> checkAndNotifyIfNeeded() async {
    try {
      if (!await isEnabled()) return false;
      final List<PantryItem> expiring = KilerService.instance.value.expiringSoonItems;
      if (expiring.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      final String todayKey = DateTime.now().toIso8601String().substring(0, 10);
      if (prefs.getString(_prefLastNotifiedDay) == todayKey) {
        return false;
      }

      final bool sent = await triggerNow();
      if (sent) {
        await prefs.setString(_prefLastNotifiedDay, todayKey);
      }
      return sent;
    } catch (e) {
      debugPrint('ExpiryReminderService.checkAndNotifyIfNeeded error: $e');
      return false;
    }
  }

  /// Dispatches a local expiry notification immediately if expiring items exist.
  Future<bool> triggerNow() async {
    final List<PantryItem> expiring = KilerService.instance.value.expiringSoonItems;
    if (expiring.isEmpty) return false;

    final String previewNames = expiring.take(3).map((e) => e.name).join(', ');
    final String title = '${expiring.length} ürünün SKT\'si yaklaşıyor';
    final String body = '$previewNames için Kilerce kurtarma tariflerine göz atın.';

    try {
      final bool? shown = await _channel.invokeMethod<bool>(
        'showExpiryNotification',
        {'title': title, 'body': body},
      );
      return shown ?? false;
    } catch (e) {
      debugPrint('ExpiryReminderService.triggerNow platform note: $e');
      return false;
    }
  }
}
