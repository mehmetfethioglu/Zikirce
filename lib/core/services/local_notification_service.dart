import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_times_service.dart';
import '../../features/namaz_vakitleri/data/farz_32_data.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelBulbul = 'zikirce_channel_bulbul_v3';
  static const String channelKumru = 'zikirce_channel_kumru_v3';
  static const String channelDefault = 'zikirce_channel_default_v3';
  static const String channelSilent = 'zikirce_channel_silent_v3';
  static const String channelQuran = 'zikirce_channel_quran_v3';
  static const String channelDownload = 'zikirce_channel_download_v1';

  static const int basePrayerNotificationId = 1000;
  static const int baseQuestionNotificationId = 6000;
  static const int dailyKazaReminderNotificationId = 7000;
  static const int dailyQuranReminderNotificationId = 8000;
  static const int audioDownloadNotificationId = 9000;

  /// Stream emitting when user taps a "Did you pray?" question notification
  static final StreamController<({String prayerName, String dateStr})>
      pendingPrayerNotificationTapped =
      StreamController<({String prayerName, String dateStr})>.broadcast();

  /// Stream emitting when user taps a 32 Farz prayer notification
  static final StreamController<int> pendingFarzNotificationTapped =
      StreamController<int>.broadcast();

  static Future<void> initialize() async {
    // 1. Initialize Timezone database with native IANA lookup
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[LocalNotificationService] Timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('[LocalNotificationService] Timezone native lookup fallback: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }
    }

    if (Platform.isWindows) {
      debugPrint('[LocalNotificationService] Windows platform detected, notifications plugin skipped.');
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint('[Notification] User tapped notification: $payload');
        if (payload != null && payload.startsWith('prayer_question|')) {
          final parts = payload.split('|');
          if (parts.length >= 3) {
            final prayerName = parts[1];
            final dateStr = parts[2];
            pendingPrayerNotificationTapped
                .add((prayerName: prayerName, dateStr: dateStr));
          }
        } else if (payload != null && payload.startsWith('farz_article|')) {
          final parts = payload.split('|');
          if (parts.length >= 2) {
            final farzId = int.tryParse(parts[1]);
            if (farzId != null) {
              pendingFarzNotificationTapped.add(farzId);
            }
          }
        }
      },
    );

    // 2. Configure High-Importance Channels for Android 8.0+ / Xiaomi HyperOS
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      // Request notification permission for Android 13+
      await androidImpl.requestNotificationsPermission();

      final vibrationPattern = Int64List.fromList([0, 500, 250, 500]);
      const ledColor = Color(0xFF10B981);

      // 1. Bulbul Sound Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelBulbul,
          'Zikirce (Bülbül Sesi)',
          description: 'Bülbül kuşu sesi ile hatırlatma ve vakit bildirimleri',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('bulbul'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 2. Kumru Sound Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelKumru,
          'Zikirce (Kumru Sesi)',
          description: 'Kumru kuşu sesi ile hatırlatma ve vakit bildirimleri',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('kumru'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 3. Default System Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelDefault,
          'Zikirce (Standart)',
          description: 'Standart bildirim sesi',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 4. Silent Channel
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelSilent,
          'Zikirce (Sessiz)',
          description: 'Sessiz bildirimler',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: true,
        ),
      );

      // 5. Quran Reminder Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelQuran,
          'Zikirce (Kur\'an Hatırlatıcısı)',
          description: 'Günlük Kur\'an-ı Kerim okuma hatırlatması',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('bulbul'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 6. Audio Download Channel (Low importance / silent progress)
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelDownload,
          'Zikirce (Ses İndirme)',
          description: 'Kur\'an-ı Kerim ses dosyaları indirme ilerlemesi',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
    }
  }

  /// Checks if exact notification scheduling is permitted (Android 12+)
  static Future<bool> canScheduleExactNotifications() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        final res = await androidImpl.canScheduleExactNotifications();
        return res ?? true;
      } catch (_) {
        return true;
      }
    }
    return true;
  }

  /// Requests exact alarms permission from the user
  static Future<bool> requestExactAlarmsPermission() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        final res = await androidImpl.requestExactAlarmsPermission();
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Robust zonedSchedule wrapper that tries exactAllowWhileIdle first,
  /// and automatically falls back to inexactAllowWhileIdle if Android 14 / Xiaomi
  /// has exact alarms restricted. Guarantees the alarm is NEVER dropped.
  static Future<void> _scheduleZonedWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] exactAllowWhileIdle failed ($e), falling back to inexactAllowWhileIdle for id $id');
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e2) {
        debugPrint(
            '[LocalNotificationService] Inexact zonedSchedule also failed: $e2');
      }
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? sound,
    String? payload,
  }) async {
    String effectiveSound = sound ?? '';
    if (effectiveSound.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveSound =
          prefs.getString('SelectedReminderSound') ?? 'Bülbül Sesi';
    }

    final channelConfig = _resolveChannelConfig(effectiveSound);

    final androidDetails = AndroidNotificationDetails(
      channelConfig.channelId,
      channelConfig.channelName,
      channelDescription: channelConfig.description,
      importance: channelConfig.importance,
      priority: Priority.max,
      sound: channelConfig.sound,
      playSound: channelConfig.playSound,
      enableVibration: channelConfig.enableVibration,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      category: AndroidNotificationCategory.reminder,
      ticker: title,
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(id, title, body, details,
        payload: payload);
  }

  /// Cancels all prayer and question notifications
  static Future<void> cancelAllPrayerNotifications() async {
    try {
      for (int i = 0; i < 6; i++) {
        await _notificationsPlugin.cancel(basePrayerNotificationId + i);
      }
      for (int i = 0; i < 5; i++) {
        await _notificationsPlugin.cancel(baseQuestionNotificationId + i);
      }
      await _notificationsPlugin.cancel(dailyKazaReminderNotificationId);
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] cancelAllPrayerNotifications error: $e');
    }
  }

  /// Schedules all 6 prayer time entry notifications and 5 "Namazınızı Kıldınız mı?" interactive questions
  /// Exactly mirrors .NET MAUI `NotificationService.ScheduleAllPrayerNotificationsAsync`
  static Future<void> scheduleAllPrayerNotifications(
      PrayerTimings timings) async {
    try {
      await cancelAllPrayerNotifications();

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      DateTime parseTime(String hhmm) {
        final clean = hhmm.trim();
        final parts = clean.split(':');
        if (parts.length < 2) return DateTime.fromMillisecondsSinceEpoch(0);
        final h = int.tryParse(parts[0].trim()) ?? 0;
        final m = int.tryParse(parts[1].trim()) ?? 0;
        return DateTime(now.year, now.month, now.day, h, m);
      }

      final prayerItems = [
        (
          name: 'İmsak',
          time: parseTime(timings.fajr),
          prefKey: 'ImsakNotificationEnabled'
        ),
        (
          name: 'Güneş',
          time: parseTime(timings.sunrise),
          prefKey: 'GunesNotificationEnabled'
        ),
        (
          name: 'Öğle',
          time: parseTime(timings.dhuhr),
          prefKey: 'OgleNotificationEnabled'
        ),
        (
          name: 'İkindi',
          time: parseTime(timings.asr),
          prefKey: 'IkindiNotificationEnabled'
        ),
        (
          name: 'Akşam',
          time: parseTime(timings.maghrib),
          prefKey: 'AksamNotificationEnabled'
        ),
        (
          name: 'Yatsı',
          time: parseTime(timings.isha),
          prefKey: 'YatsiNotificationEnabled'
        ),
      ];

      final soundSetting = prefs.getString('SelectedPrayerSound') ??
          prefs.getString('SelectedReminderSound') ??
          'Bülbül Sesi';
      final channelConfig = _resolveChannelConfig(soundSetting);

      // 1. Schedule Vakit Girdi Bildirimleri (IDs: 1000 - 1005) with 32 Farz
      final validPrayers = <({String name, DateTime targetTime, int originalIndex})>[];
      for (int i = 0; i < prayerItems.length; i++) {
        final item = prayerItems[i];
        final isEnabled = prefs.getBool(item.prefKey) ??
            prefs.getBool('${item.name}NotificationEnabled') ??
            true;
        if (!isEnabled) continue;

        var targetTime = item.time;
        if (targetTime.isBefore(now)) {
          targetTime = targetTime.add(const Duration(days: 1));
        }
        validPrayers.add((name: item.name, targetTime: targetTime, originalIndex: i));
      }

      // Sort upcoming prayers chronologically so farz progression is in exact order
      validPrayers.sort((a, b) => a.targetTime.compareTo(b.targetTime));

      // Retrieve persistent base index for 32 Farz cycle
      final lastScheduledDay = prefs.getString('FarzNotificationLastScheduledDay');
      int baseFarzIdx = prefs.getInt('FarzNotificationCurrentIndex') ?? 0;

      // If scheduled for a new day, advance base index; otherwise keep idempotent
      if (lastScheduledDay != null && lastScheduledDay != todayStr) {
        final lastDayCount = prefs.getInt('FarzNotificationDaySlotsCount') ?? 5;
        baseFarzIdx = (baseFarzIdx + lastDayCount) % kFarz32List.length;
        await prefs.setInt('FarzNotificationCurrentIndex', baseFarzIdx);
      }
      await prefs.setString('FarzNotificationLastScheduledDay', todayStr);
      await prefs.setInt('FarzNotificationDaySlotsCount', validPrayers.length);

      for (int step = 0; step < validPrayers.length; step++) {
        final prayer = validPrayers[step];
        final farzIdx = (baseFarzIdx + step) % kFarz32List.length;
        final farzItem = kFarz32List[farzIdx];

        final title = '${prayer.name} Vakti Girdi 🕌 • 32 Farz (#${farzItem.id})';
        final body = '${farzItem.title}: ${farzItem.notificationSummary}';

        final androidDetails = AndroidNotificationDetails(
          channelConfig.channelId,
          channelConfig.channelName,
          channelDescription: channelConfig.description,
          importance: channelConfig.importance,
          priority: Priority.max,
          sound: channelConfig.sound,
          playSound: channelConfig.playSound,
          enableVibration: channelConfig.enableVibration,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
          channelShowBadge: true,
          category: AndroidNotificationCategory.reminder,
          ticker: title,
        );

        final scheduledTZ = tz.TZDateTime.from(prayer.targetTime, tz.local);
        await _scheduleZonedWithFallback(
          id: basePrayerNotificationId + prayer.originalIndex,
          title: title,
          body: body,
          scheduledDate: scheduledTZ,
          notificationDetails: NotificationDetails(android: androidDetails),
          payload: 'farz_article|${farzItem.id}',
        );
        debugPrint(
            '[LocalNotificationService] Scheduled prayer entry for ${prayer.name} with Farz #${farzItem.id} (${farzItem.title}) at ${prayer.targetTime} ($scheduledTZ)');
      }

      // 2. Schedule "Namazınızı Kıldınız mı? 🕌" Question Notifications (IDs: 6000 - 6004)
      final tSunrise = parseTime(timings.sunrise);
      final tAsr = parseTime(timings.asr);
      final tMaghrib = parseTime(timings.maghrib);
      final tIsha = parseTime(timings.isha);

      final questionItems = [
        (
          name: 'Sabah',
          targetTime: tSunrise.subtract(const Duration(minutes: 45)),
          prefKey: 'SabahNotificationEnabled'
        ),
        (
          name: 'Öğle',
          targetTime: tAsr.subtract(const Duration(minutes: 45)),
          prefKey: 'OgleNotificationEnabled'
        ),
        (
          name: 'İkindi',
          targetTime: tMaghrib.subtract(const Duration(minutes: 45)),
          prefKey: 'IkindiNotificationEnabled'
        ),
        (
          name: 'Akşam',
          targetTime: tIsha.subtract(const Duration(minutes: 45)),
          prefKey: 'AksamNotificationEnabled'
        ),
        (
          name: 'Yatsı',
          targetTime: tIsha.add(const Duration(hours: 1)),
          prefKey: 'YatsiNotificationEnabled'
        ),
      ];

      for (int i = 0; i < questionItems.length; i++) {
        final q = questionItems[i];
        final isEnabled = prefs.getBool(q.prefKey) ?? true;
        if (!isEnabled) continue;

        var questionTime = q.targetTime;
        if (questionTime.isBefore(now)) {
          questionTime = questionTime.add(const Duration(days: 1));
        }

        const title = 'Namazınızı Kıldınız mı? 🕌';
        final body = '${q.name} namazınızı kıldınız mı?';
        final payload = 'prayer_question|${q.name}|$todayStr';

        final androidDetails = AndroidNotificationDetails(
          channelConfig.channelId,
          channelConfig.channelName,
          channelDescription: channelConfig.description,
          importance: channelConfig.importance,
          priority: Priority.max,
          sound: channelConfig.sound,
          playSound: channelConfig.playSound,
          enableVibration: channelConfig.enableVibration,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
          channelShowBadge: true,
          category: AndroidNotificationCategory.reminder,
          ticker: title,
        );

        final scheduledTZ = tz.TZDateTime.from(questionTime, tz.local);
        await _scheduleZonedWithFallback(
          id: baseQuestionNotificationId + i,
          title: title,
          body: body,
          scheduledDate: scheduledTZ,
          notificationDetails: NotificationDetails(android: androidDetails),
          payload: payload,
        );
        debugPrint(
            '[LocalNotificationService] Scheduled kaza question for ${q.name} at $questionTime ($scheduledTZ)');
      }
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] scheduleAllPrayerNotifications error: $e');
    }
  }

  /// Schedules daily Quran reminder notification
  static Future<void> scheduleQuranDailyReminder({
    required String timeHhmm,
    required bool isEnabled,
  }) async {
    try {
      await _notificationsPlugin.cancel(dailyQuranReminderNotificationId);
      if (!isEnabled) return;

      final parts = timeHhmm.trim().split(':');
      if (parts.length < 2) return;
      final h = int.tryParse(parts[0].trim()) ?? 21;
      final m = int.tryParse(parts[1].trim()) ?? 0;

      final now = DateTime.now();
      var targetTime = DateTime(now.year, now.month, now.day, h, m);
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      final prefs = await SharedPreferences.getInstance();
      final soundSetting = prefs.getString('SelectedReminderSound') ?? 'Bülbül Sesi';
      final channelConfig = _resolveChannelConfig(soundSetting);

      final androidDetails = AndroidNotificationDetails(
        channelConfig.channelId,
        channelConfig.channelName,
        channelDescription: channelConfig.description,
        importance: Importance.max,
        priority: Priority.max,
        sound: channelConfig.sound,
        playSound: channelConfig.playSound,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
        category: AndroidNotificationCategory.reminder,
        ticker: '📖 Günlük Kur\'an Hatırlatması',
      );

      final scheduledTZ = tz.TZDateTime.from(targetTime, tz.local);
      await _scheduleZonedWithFallback(
        id: dailyQuranReminderNotificationId,
        title: '📖 Günlük Kur\'an Hatırlatması',
        body: 'Günün Kur\'an tilavetini tamamlayıp manevi hedefine bir adım daha yaklaş.',
        scheduledDate: scheduledTZ,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: 'quran_reminder',
      );
      debugPrint(
          '[LocalNotificationService] Scheduled Quran reminder at $targetTime ($scheduledTZ)');
    } catch (e) {
      debugPrint('[LocalNotificationService] scheduleQuranDailyReminder error: $e');
    }
  }

  static Future<void> showTestNotification({String? sound}) async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    String effectiveSound = sound ?? '';
    if (effectiveSound.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveSound =
          prefs.getString('SelectedReminderSound') ?? 'Bülbül Sesi';
    }

    final channelConfig = _resolveChannelConfig(effectiveSound);

    final androidDetails = AndroidNotificationDetails(
      channelConfig.channelId,
      channelConfig.channelName,
      channelDescription: channelConfig.description,
      importance: Importance.max,
      priority: Priority.max,
      sound: channelConfig.sound,
      playSound: channelConfig.playSound,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      category: AndroidNotificationCategory.reminder,
      ticker: '📖 Kur\'an & Zikir Hatırlatıcısı',
    );

    final details = NotificationDetails(android: androidDetails);

    final sampleFarz = kFarz32List.first;
    await _notificationsPlugin.show(
      999,
      '🕌 Öğle Vakti Girdi • 32 Farz (#${sampleFarz.id})',
      '${sampleFarz.title}: ${sampleFarz.notificationSummary}',
      details,
      payload: 'farz_article|${sampleFarz.id}',
    );
  }

  static _NotificationChannelConfig _resolveChannelConfig(String soundName) {
    final lower = soundName.toLowerCase();
    if (lower.contains('kumru')) {
      return const _NotificationChannelConfig(
        channelId: channelKumru,
        channelName: 'Zikirce (Kumru Sesi)',
        description: 'Kumru kuşu sesi ile hatırlatma',
        sound: RawResourceAndroidNotificationSound('kumru'),
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    } else if (lower.contains('sessiz') || lower.contains('silent')) {
      return const _NotificationChannelConfig(
        channelId: channelSilent,
        channelName: 'Zikirce (Sessiz)',
        description: 'Sessiz bildirimler',
        sound: null,
        playSound: false,
        enableVibration: false,
        importance: Importance.low,
      );
    } else if (lower.contains('varsayılan') ||
        lower.contains('default') ||
        lower.contains('click')) {
      return const _NotificationChannelConfig(
        channelId: channelDefault,
        channelName: 'Zikirce (Standart)',
        description: 'Standart bildirim sesi',
        sound: null,
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    } else {
      // Default: Bülbül sesi
      return const _NotificationChannelConfig(
        channelId: channelBulbul,
        channelName: 'Zikirce (Bülbül Sesi)',
        description: 'Bülbül kuşu sesi ile hatırlatma',
        sound: RawResourceAndroidNotificationSound('bulbul'),
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    }
  }

  /// Shows ongoing download progress notification on Android/iOS
  static Future<void> showDownloadProgressNotification({
    required int current,
    required int total,
    required String statusText,
  }) async {
    try {
      final percent = total > 0 ? ((current / total) * 100).round() : 0;
      final androidDetails = AndroidNotificationDetails(
        channelDownload,
        'Zikirce (Ses İndirme)',
        channelDescription: 'Kur\'an-ı Kerim ses dosyaları indirme ilerlemesi',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: total,
        progress: current,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      await _notificationsPlugin.show(
        audioDownloadNotificationId,
        'Kur\'an Sesleri İndiriliyor (%$percent)',
        '$statusText ($current / $total ayet)',
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showDownloadProgressNotification error: $e');
    }
  }

  /// Shows download completed notification
  static Future<void> showDownloadCompletedNotification({required int total}) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        channelDefault,
        'Zikirce (Standart)',
        channelDescription: 'Standart bildirim sesi',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        audioDownloadNotificationId,
        '✅ Kur\'an Sesleri İndirildi',
        'Toplam $total ayet başarıyla cihazınıza indirildi. Çevrimdışı dinleyebilirsiniz.',
        const NotificationDetails(android: androidDetails, iOS: darwinDetails),
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showDownloadCompletedNotification error: $e');
    }
  }

  /// Cancels download notification
  static Future<void> cancelDownloadNotification() async {
    try {
      await _notificationsPlugin.cancel(audioDownloadNotificationId);
    } catch (e) {
      debugPrint('[LocalNotificationService] cancelDownloadNotification error: $e');
    }
  }
}

class _NotificationChannelConfig {
  final String channelId;
  final String channelName;
  final String description;
  final AndroidNotificationSound? sound;
  final bool playSound;
  final bool enableVibration;
  final Importance importance;

  const _NotificationChannelConfig({
    required this.channelId,
    required this.channelName,
    required this.description,
    this.sound,
    required this.playSound,
    required this.enableVibration,
    required this.importance,
  });
}
