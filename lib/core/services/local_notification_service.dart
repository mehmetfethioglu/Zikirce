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
            UILocalNotificationDateInterpretation.wallClockTime,
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
              UILocalNotificationDateInterpretation.wallClockTime,
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
    final details =
        _buildNotificationDetails(config: channelConfig, title: title);
    await _notificationsPlugin.show(id, title, body, details,
        payload: payload);
  }

  /// Cancels all prayer and question notifications across 7-day range
  static Future<void> cancelAllPrayerNotifications() async {
    try {
      for (int i = 0; i < 70; i++) {
        await _notificationsPlugin.cancel(basePrayerNotificationId + i);
      }
      for (int i = 0; i < 70; i++) {
        await _notificationsPlugin.cancel(baseQuestionNotificationId + i);
      }
      await _notificationsPlugin.cancel(dailyKazaReminderNotificationId);
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] cancelAllPrayerNotifications error: $e');
    }
  }

  /// Cancels today's 45-minute question notification for a specific prayer when prayed
  static Future<void> cancelTodayQuestionNotification(String prayerName) async {
    final questionIndexMap = {
      'Sabah': 0,
      'İmsak': 0,
      'Öğle': 1,
      'İkindi': 2,
      'Akşam': 3,
      'Yatsı': 4,
    };
    final idx = questionIndexMap[prayerName];
    if (idx != null) {
      final id = baseQuestionNotificationId + idx; // Day 0 ID
      await _notificationsPlugin.cancel(id);
      debugPrint('[LocalNotificationService] Smart cancellation: Cancelled question notification for $prayerName (id: $id)');
    }
  }

  static String? _lastScheduledSignature;
  static DateTime? _lastScheduledTime;

  /// Schedules 7-day rolling window for all 6 prayer entries and 5 "Namazınızı Kıldınız mı?" interactive questions
  static Future<void> scheduleAllPrayerNotifications(
      PrayerTimings timings, {bool force = false}) async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final signature = '${timings.date}_${timings.fajr}_${timings.isha}_$todayStr';

      if (!force &&
          _lastScheduledSignature == signature &&
          _lastScheduledTime != null &&
          now.difference(_lastScheduledTime!) < const Duration(minutes: 30)) {
        debugPrint(
            '[LocalNotificationService] scheduleAllPrayerNotifications skipped (already scheduled for $todayStr)');
        return;
      }
      _lastScheduledSignature = signature;
      _lastScheduledTime = now;

      await cancelAllPrayerNotifications();

      final prefs = await SharedPreferences.getInstance();
      final isNamazMasterEnabled = prefs.getBool('IsNamazReminderEnabled') ?? true;
      if (!isNamazMasterEnabled) {
        debugPrint(
            '[LocalNotificationService] scheduleAllPrayerNotifications skipped: IsNamazReminderEnabled is false');
        return;
      }

      final city = prefs.getString('SelectedCity') ?? 'İstanbul';

      final soundSetting = prefs.getString('SelectedPrayerSound') ??
          prefs.getString('SelectedReminderSound') ??
          'Bülbül Sesi';
      final channelConfig = _resolveChannelConfig(soundSetting);

      final isQuestionMasterEnabled =
          prefs.getBool('KazaQuestionNotificationEnabled') ?? true;

      // 32 Farz progression tracker
      final lastScheduledDay = prefs.getString('FarzNotificationLastScheduledDay');
      int baseFarzIdx = prefs.getInt('FarzNotificationCurrentIndex') ?? 0;
      if (lastScheduledDay != null && lastScheduledDay != todayStr) {
        final lastDayCount = prefs.getInt('FarzNotificationDaySlotsCount') ?? 5;
        baseFarzIdx = (baseFarzIdx + lastDayCount) % kFarz32List.length;
        await prefs.setInt('FarzNotificationCurrentIndex', baseFarzIdx);
      }
      await prefs.setString('FarzNotificationLastScheduledDay', todayStr);

      int globalFarzStep = 0;

      // On iOS, limit rolling window to 5 days so total scheduled notifications (5 * 11 = 55)
      // do not exceed Apple's strict 64 pending notification cap (which drops notifications silently).
      // On Android / Desktop, keep full 7-day rolling window.
      final daysLimit = Platform.isIOS ? 5 : 7;
      final currentTZNow = tz.TZDateTime.now(tz.local);

      // Iterate rolling forward (Day 0 to Day daysLimit - 1)
      for (int dayOffset = 0; dayOffset < daysLimit; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final dayStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

        final dayTimings = (dayOffset == 0)
            ? timings
            : PrayerTimesService.calculateOfflinePrayerTimes(city, targetDate);

        tz.TZDateTime parseTZTime(String hhmm, {Duration offset = Duration.zero}) {
          final clean = hhmm.trim();
          final parts = clean.split(':');
          if (parts.length < 2) return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, 0);
          final h = int.tryParse(parts[0].trim()) ?? 0;
          final m = int.tryParse(parts[1].trim()) ?? 0;
          final base = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, h, m);
          return offset == Duration.zero ? base : base.add(offset);
        }

        // 1. Prayer Entry Items (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı)
        final prayerItems = [
          (name: 'İmsak', time: parseTZTime(dayTimings.fajr), prefKey: 'ImsakNotificationEnabled'),
          (name: 'Güneş', time: parseTZTime(dayTimings.sunrise), prefKey: 'GunesNotificationEnabled'),
          (name: 'Öğle', time: parseTZTime(dayTimings.dhuhr), prefKey: 'OgleNotificationEnabled'),
          (name: 'İkindi', time: parseTZTime(dayTimings.asr), prefKey: 'IkindiNotificationEnabled'),
          (name: 'Akşam', time: parseTZTime(dayTimings.maghrib), prefKey: 'AksamNotificationEnabled'),
          (name: 'Yatsı', time: parseTZTime(dayTimings.isha), prefKey: 'YatsiNotificationEnabled'),
        ];

        for (int pIdx = 0; pIdx < prayerItems.length; pIdx++) {
          final item = prayerItems[pIdx];
          final isEnabled = prefs.getBool(item.prefKey) ??
              prefs.getBool('${item.name}NotificationEnabled') ??
              true;
          if (!isEnabled) continue;

          final targetTime = item.time;
          if (targetTime.isBefore(currentTZNow)) continue; // Already in the past

          final farzIdx = (baseFarzIdx + globalFarzStep) % kFarz32List.length;
          globalFarzStep++;
          final farzItem = kFarz32List[farzIdx];

          final title = '${item.name} Vakti Girdi 🕌 • 32 Farz (#${farzItem.id})';
          final body = '${farzItem.title}: ${farzItem.notificationSummary}';
          final details = _buildNotificationDetails(config: channelConfig, title: title);

          final notifId = basePrayerNotificationId + (dayOffset * 10) + pIdx;
          await _scheduleZonedWithFallback(
            id: notifId,
            title: title,
            body: body,
            scheduledDate: targetTime,
            notificationDetails: details,
            payload: 'farz_article|${farzItem.id}',
          );
        }

        // 2. Question Notifications ("Namazınızı Kıldınız mı? 🕌")
        if (isQuestionMasterEnabled) {
          final questionItems = [
            (
              name: 'Sabah',
              targetTime: parseTZTime(dayTimings.sunrise, offset: const Duration(minutes: -45)),
              prefKey: 'ImsakNotificationEnabled',
              fallbackKey: 'SabahNotificationEnabled',
            ),
            (
              name: 'Öğle',
              targetTime: parseTZTime(dayTimings.asr, offset: const Duration(minutes: -45)),
              prefKey: 'OgleNotificationEnabled',
              fallbackKey: 'OgleNotificationEnabled',
            ),
            (
              name: 'İkindi',
              targetTime: parseTZTime(dayTimings.maghrib, offset: const Duration(minutes: -45)),
              prefKey: 'IkindiNotificationEnabled',
              fallbackKey: 'IkindiNotificationEnabled',
            ),
            (
              name: 'Akşam',
              targetTime: parseTZTime(dayTimings.isha, offset: const Duration(minutes: -45)),
              prefKey: 'AksamNotificationEnabled',
              fallbackKey: 'AksamNotificationEnabled',
            ),
            (
              name: 'Yatsı',
              targetTime: parseTZTime(dayTimings.isha, offset: const Duration(hours: 1)),
              prefKey: 'YatsiNotificationEnabled',
              fallbackKey: 'YatsiNotificationEnabled',
            ),
          ];

          for (int qIdx = 0; qIdx < questionItems.length; qIdx++) {
            final q = questionItems[qIdx];
            final isEnabled = prefs.getBool(q.prefKey) ?? prefs.getBool(q.fallbackKey) ?? true;
            if (!isEnabled) continue;

            final questionTime = q.targetTime;
            if (questionTime.isBefore(currentTZNow)) continue; // In the past

            const title = 'Namazınızı Kıldınız mı? 🕌';
            final body = '${q.name} namazınızı kıldınız mı?';
            final payload = 'prayer_question|${q.name}|$dayStr';

            final details = _buildNotificationDetails(config: channelConfig, title: title);

            final notifId = baseQuestionNotificationId + (dayOffset * 10) + qIdx;
            await _scheduleZonedWithFallback(
              id: notifId,
              title: title,
              body: body,
              scheduledDate: questionTime,
              notificationDetails: details,
              payload: payload,
            );
          }
        }
      }

      await prefs.setInt('FarzNotificationDaySlotsCount', globalFarzStep.clamp(1, 42));
      debugPrint('[LocalNotificationService] Successfully scheduled $daysLimit-day rolling prayer & question notifications');
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

      final now = tz.TZDateTime.now(tz.local);
      var scheduledTZ = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
      if (scheduledTZ.isBefore(now)) {
        scheduledTZ = scheduledTZ.add(const Duration(days: 1));
      }

      final prefs = await SharedPreferences.getInstance();
      final soundSetting =
          prefs.getString('SelectedReminderSound') ?? 'Bülbül Sesi';
      final channelConfig = _resolveChannelConfig(soundSetting);
      const title = '📖 Günlük Kur\'an Hatırlatması';
      final details =
          _buildNotificationDetails(config: channelConfig, title: title);

      await _scheduleZonedWithFallback(
        id: dailyQuranReminderNotificationId,
        title: title,
        body:
            'Günün Kur\'an tilavetini tamamlayıp manevi hedefine bir adım daha yaklaş.',
        scheduledDate: scheduledTZ,
        notificationDetails: details,
        payload: 'quran_reminder',
      );
      debugPrint(
          '[LocalNotificationService] Scheduled Quran reminder at $scheduledTZ');
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
    final iosImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
    }

    String effectiveSound = sound ?? '';
    if (effectiveSound.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveSound =
          prefs.getString('SelectedReminderSound') ?? 'Bülbül Sesi';
    }

    final channelConfig = _resolveChannelConfig(effectiveSound);
    final sampleFarz = kFarz32List.first;
    final title = '🕌 Öğle Vakti Girdi • 32 Farz (#${sampleFarz.id})';
    final details =
        _buildNotificationDetails(config: channelConfig, title: title);

    await _notificationsPlugin.show(
      999,
      title,
      '${sampleFarz.title}: ${sampleFarz.notificationSummary}',
      details,
      payload: 'farz_article|${sampleFarz.id}',
    );
  }

  static NotificationDetails _buildNotificationDetails({
    required _NotificationChannelConfig config,
    required String title,
  }) {
    final androidDetails = AndroidNotificationDetails(
      config.channelId,
      config.channelName,
      channelDescription: config.description,
      importance: config.importance,
      priority: Priority.max,
      sound: config.sound,
      playSound: config.playSound,
      enableVibration: config.enableVibration,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      category: AndroidNotificationCategory.reminder,
      ticker: title,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: config.playSound,
      sound: config.playSound ? config.darwinSound : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
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
        darwinSound: 'kumru.wav',
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
        darwinSound: null,
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
        darwinSound: null,
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
        darwinSound: 'bulbul.wav',
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
  final String? darwinSound;
  final bool playSound;
  final bool enableVibration;
  final Importance importance;

  const _NotificationChannelConfig({
    required this.channelId,
    required this.channelName,
    required this.description,
    this.sound,
    this.darwinSound,
    required this.playSound,
    required this.enableVibration,
    required this.importance,
  });
}
