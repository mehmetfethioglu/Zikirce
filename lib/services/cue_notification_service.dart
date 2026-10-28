import 'package:flutter/services.dart';

import '../models/cue_models.dart';

/// Native OS Notification & Scheduled Alarm Bridge (`com.akarworks.cuedeck/notifications`)
/// delivering real Android heads-up/status-bar notifications via `NotificationManager`
/// and exact background reminders via `AlarmManager` + `CueDeckReminderReceiver`.
class CueNotificationService {
  CueNotificationService();

  static const MethodChannel _channel = MethodChannel(
    'com.akarworks.cuedeck/notifications',
  );

  /// Deterministic positive 31-bit notification ID from a [cueId] and [slot].
  static int computeNotificationId(String cueId, {int slot = 0}) {
    var hash = 2166136261;
    for (final unit in cueId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7FFFFFFF;
    }
    final base = (hash % 900000) + 10000;
    return base * 2 + (slot & 1);
  }

  /// Requests Android 13+ (`API 33+`) `POST_NOTIFICATIONS` permission.
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Immediately posts a real Android OS notification to the system notification shade.
  Future<bool> showReminderNotification(
    WatchCueItem item, {
    bool isLeadReminder = false,
  }) async {
    final notificationId = computeNotificationId(
      item.id,
      slot: isLeadReminder ? 0 : 1,
    );
    final title = isLeadReminder
        ? '⏰ ${item.reminderMinutesBefore} dk sonra: ${item.title}'
        : '🎬 İzleme Vakti (${item.formattedClock}) • ${item.platform.label}';
    final body = '${item.title} — ${item.checkpointSummary}';
    final subText =
        '${item.platform.label} • ${item.recurrenceSummary} • ${item.sessionMinutes}dk/seans';

    try {
      final shown = await _channel.invokeMethod<bool>(
        'showNotificationNow',
        <String, dynamic>{
          'notificationId': notificationId,
          'title': title,
          'body': body,
          'subText': subText,
          'cueId': item.id,
        },
      );
      return shown ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Builds the upcoming alarm payload list for all incomplete [items] after [now].
  static List<Map<String, dynamic>> buildAlarmPayloads(
    List<WatchCueItem> items, {
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final alarms = <Map<String, dynamic>>[];

    for (final item in items) {
      if (item.isCompleted) continue;

      final subText =
          '${item.platform.label} • ${item.recurrenceSummary} • ${item.sessionMinutes}dk/seans';

      // 1. Lead reminder alarm (scheduledTime - reminderMinutesBefore)
      if (item.reminderMinutesBefore > 0) {
        final nextRem = item.nextReminderDateTime(referenceNow);
        if (nextRem != null && nextRem.isAfter(referenceNow)) {
          alarms.add(<String, dynamic>{
            'alarmId': computeNotificationId(item.id, slot: 0),
            'triggerAtMillis': nextRem.millisecondsSinceEpoch,
            'title': '⏰ ${item.reminderMinutesBefore} dk sonra: ${item.title}',
            'body':
                '${item.platform.label} (${item.formattedClock}) • ${item.checkpointSummary}',
            'subText': subText,
            'cueId': item.id,
          });
        }
      }

      // 2. Exact watch start time alarm (scheduledTime)
      final nextWatch = item.nextWatchDateTime(referenceNow);
      if (nextWatch != null && nextWatch.isAfter(referenceNow)) {
        alarms.add(<String, dynamic>{
          'alarmId': computeNotificationId(item.id, slot: 1),
          'triggerAtMillis': nextWatch.millisecondsSinceEpoch,
          'title':
              '🎬 İzleme Vakti (${item.formattedClock}) • ${item.platform.label}',
          'body': '${item.title} — ${item.checkpointSummary}',
          'subText': subText,
          'cueId': item.id,
        });
      }
    }

    return alarms;
  }

  /// Synchronizes all upcoming watch plan reminders and start alarms with Android `AlarmManager`.
  Future<int> syncScheduledReminders(
    List<WatchCueItem> items, {
    DateTime? now,
  }) async {
    final alarms = buildAlarmPayloads(items, now: now);
    try {
      final count = await _channel.invokeMethod<int>(
        'syncScheduledNotifications',
        <String, dynamic>{'alarms': alarms},
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
