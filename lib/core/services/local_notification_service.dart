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
  static const String channelEzan = 'zikirce_channel_ezan_v2';
  static const String channelSela = 'zikirce_channel_sela_v2';
  static const String channelFeraciye = 'zikirce_channel_feraciye_v2';
  static const String channelDefault = 'zikirce_channel_default_v3';
  static const String channelSilent = 'zikirce_channel_silent_v3';
  static const String channelQuran = 'zikirce_channel_quran_v3';
  static const String channelDownload = 'zikirce_channel_download_v1';

  static const int basePrayerNotificationId = 1000;
  static const int baseQuestionNotificationId = 6000;
  static const int baseSpecialWeeklyNotificationId = 6500;
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

  /// Stream emitting when user taps a special spiritual notification (feraciye, thursday_sela, friday_sela)
  static final StreamController<String> pendingSpiritualNotificationTapped =
      StreamController<String>.broadcast();

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
        } else if (payload != null && payload.startsWith('special_spiritual|')) {
          final parts = payload.split('|');
          if (parts.length >= 2) {
            pendingSpiritualNotificationTapped.add(parts[1]);
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

      // Clean up legacy v1 sound channels so updated raw audio files take effect
      try {
        await androidImpl.deleteNotificationChannel('zikirce_channel_ezan_v1');
        await androidImpl.deleteNotificationChannel('zikirce_channel_sela_v1');
        await androidImpl.deleteNotificationChannel('zikirce_channel_feraciye_v1');
      } catch (_) {}

      // 2b. Ezan Sound Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelEzan,
          'Zikirce (Ezan Sesi)',
          description: 'Ezan-ı Muhammedi sesi ile vakit bildirimleri',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('ezan'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 2c. Salâ (Sela) Sound Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelSela,
          'Zikirce (Salâ Sesi)',
          description: 'Cuma ve Perşembe gecesi Salâ bildirimleri',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('sela'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: ledColor,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );

      // 2d. Feraciye Duası Sound Channel
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          channelFeraciye,
          'Zikirce (Feraciye Duası)',
          description: 'Perşembe akşamı Feraciye Duası bildirimleri',
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('feraciye'),
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
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      if (pending.isNotEmpty) {
        final toCancel = pending
            .map((p) => p.id)
            .where((id) =>
                id != dailyQuranReminderNotificationId &&
                id != audioDownloadNotificationId)
            .toList();
        await Future.wait(toCancel.map((id) => _notificationsPlugin.cancel(id)));
        return;
      }
    } catch (_) {}

    try {
      final futures = <Future<void>>[
        for (int i = 0; i < 70; i++)
          _notificationsPlugin.cancel(basePrayerNotificationId + i),
        for (int i = 0; i < 70; i++)
          _notificationsPlugin.cancel(baseQuestionNotificationId + i),
        for (int i = 0; i < 50; i++)
          _notificationsPlugin.cancel(baseSpecialWeeklyNotificationId + i),
        _notificationsPlugin.cancel(dailyKazaReminderNotificationId),
      ];
      await Future.wait(futures);
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
  static bool _isScheduling = false;
  static const String _scheduleSchemaVersion = 'v8_feraciye_sela_default_off';

  static Future<void> _ensureTimezoneInitialized() async {
    try {
      if (tz.local.name != 'UTC' && tz.local.name != 'Etc/UTC') {
        return;
      }
    } catch (_) {}
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}
    }
  }

  static String _resolveActiveCityFromPrefs(SharedPreferences prefs) {
    final activeSessionId = prefs.getString('ActiveSessionId');
    if (activeSessionId != null &&
        activeSessionId.isNotEmpty &&
        activeSessionId != 'default_user') {
      final sessionCity = prefs.getString('SelectedCity_$activeSessionId') ??
          prefs.getString('AppCity_$activeSessionId') ??
          prefs.getString('selected_city_$activeSessionId');
      if (sessionCity != null && sessionCity.isNotEmpty) {
        return sessionCity;
      }
    }
    return prefs.getString('SelectedCity') ??
        prefs.getString('AppCity') ??
        prefs.getString('selected_city') ??
        'İstanbul';
  }

  /// Schedules 7-day rolling window for all 6 prayer entries and 5 "Namazınızı Kıldınız mı?" interactive questions
  static Future<void> scheduleAllPrayerNotifications(
      PrayerTimings timings, {bool force = false, String? cityOverride}) async {
    if (_isScheduling) return;
    _isScheduling = true;
    try {
      await _ensureTimezoneInitialized();

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final prefs = await SharedPreferences.getInstance();
      final city = (cityOverride != null && cityOverride.isNotEmpty)
          ? cityOverride
          : _resolveActiveCityFromPrefs(prefs);

      // Ensure global SelectedCity key stays synced with active session city
      if (prefs.getString('SelectedCity') != city) {
        await prefs.setString('SelectedCity', city);
      }

      // Guard against stale timings (e.g. if app resumed after midnight with yesterday's cached object)
      PrayerTimings effectiveTodayTimings = timings;
      if (timings.date.isNotEmpty && timings.date != todayStr) {
        try {
          effectiveTodayTimings = await PrayerTimesService.getPrayerTimes(city: city);
        } catch (_) {
          effectiveTodayTimings = PrayerTimesService.calculateOfflinePrayerTimes(city, now);
        }
      }

      final isFeraciyeEnabled = prefs.getBool('IsFeraciyeEnabled_v2') ?? false;
      final feraciyeMinutesBefore = prefs.getInt('FeraciyeMinutesBeforeMaghrib') ?? 15;
      final feraciyeCustomTime = prefs.getString('FeraciyeCustomTime') ?? '';
      final feraciyeSound = prefs.getString('FeraciyeSound') ?? 'Feraciye Duası';

      final isThursdaySelaEnabled = prefs.getBool('IsThursdaySelaEnabled_v2') ?? false;
      final thursdaySelaMinutesBefore = prefs.getInt('ThursdaySelaMinutesBeforeIsha') ?? 30;
      final thursdaySelaCustomTime = prefs.getString('ThursdaySelaCustomTime') ?? '';
      final thursdaySelaSound = prefs.getString('ThursdaySelaSound') ?? 'Salâ Sesi';

      final isFridaySelaEnabled = prefs.getBool('IsFridaySelaEnabled_v2') ?? false;
      final fridaySelaMinutesBefore = prefs.getInt('FridaySelaMinutesBeforeDhuhr') ?? 45;
      final fridaySelaCustomTime = prefs.getString('FridaySelaCustomTime') ?? '';
      final fridaySelaSound = prefs.getString('FridaySelaSound') ?? 'Salâ Sesi';

      final savedSchema = prefs.getString('LastPrayerScheduleSchemaVersion');
      final schemaUpgradeNeeded = savedSchema != _scheduleSchemaVersion;
      final signature =
          '${_scheduleSchemaVersion}_${city}_${effectiveTodayTimings.date}_${effectiveTodayTimings.fajr}_${effectiveTodayTimings.dhuhr}_${effectiveTodayTimings.asr}_${effectiveTodayTimings.isha}_${todayStr}_${isFeraciyeEnabled}_${feraciyeMinutesBefore}_${feraciyeCustomTime}_${isThursdaySelaEnabled}_${thursdaySelaMinutesBefore}_${thursdaySelaCustomTime}_${isFridaySelaEnabled}_${fridaySelaMinutesBefore}_$fridaySelaCustomTime';

      if (!force &&
          !schemaUpgradeNeeded &&
          _lastScheduledSignature == signature &&
          _lastScheduledTime != null &&
          now.difference(_lastScheduledTime!) < const Duration(minutes: 30)) {
        debugPrint(
            '[LocalNotificationService] scheduleAllPrayerNotifications skipped (already scheduled for $todayStr)');
        return;
      }
      _lastScheduledSignature = signature;
      _lastScheduledTime = now;
      if (schemaUpgradeNeeded) {
        await prefs.setString('LastPrayerScheduleSchemaVersion', _scheduleSchemaVersion);
      }

      await cancelAllPrayerNotifications();

      final isNamazMasterEnabled = prefs.getBool('IsNamazReminderEnabled') ?? true;
      if (!isNamazMasterEnabled) {
        debugPrint(
            '[LocalNotificationService] scheduleAllPrayerNotifications skipped: IsNamazReminderEnabled is false');
        return;
      }

      final soundSetting = prefs.getString('SelectedPrayerSound') ??
          prefs.getString('SelectedReminderSound') ??
          'Bülbül Sesi';
      final channelConfig = _resolveChannelConfig(soundSetting);

      final isQuestionMasterEnabled =
          prefs.getBool('KazaQuestionNotificationEnabled') ?? true;
      final questionMinutesBeforeEnd =
          prefs.getInt('KazaQuestionMinutesBeforeEnd') ?? 45;
      final questionCustomTime =
          prefs.getString('KazaQuestionCustomTime') ?? '';

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

      // Schedule a 5-day rolling window (max 5 * 11 = 55 notifications, safely under Apple's 64 pending cap)
      // directly from the cached Monthly Diyanet API Calendar, refreshed silently on every app open/resume.
      const int daysLimit = 5;
      final currentTZNow = tz.TZDateTime.now(tz.local);
      final todayFardDate = prefs.getString('TodayFardDate');

      final rangeTimings = await PrayerTimesService.getPrayerTimesRange(
        city: city,
        startDate: now,
        days: daysLimit,
        referenceTodayTimings: effectiveTodayTimings,
      );

      // Iterate rolling forward (Day 0 to Day daysLimit - 1)
      for (int dayOffset = 0; dayOffset < daysLimit; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final dayStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

        final dayTimings = (dayOffset < rangeTimings.length)
            ? rangeTimings[dayOffset]
            : PrayerTimesService.calculateCalibratedPrayerTimesForDate(
                city: city,
                targetDate: targetDate,
                referenceTodayTimings: effectiveTodayTimings,
                referenceDate: now,
              );

        tz.TZDateTime parseTZTime(String hhmm, {Duration offset = Duration.zero}) {
          final clean = hhmm.trim().split(' ').first;
          final parts = clean.split(':');
          if (parts.length < 2) return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, 0);
          final h = int.tryParse(parts[0].trim()) ?? 0;
          final m = int.tryParse(parts[1].trim()) ?? 0;
          final base = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, h, m);
          return offset == Duration.zero ? base : base.add(offset);
        }

        final tFajr = parseTZTime(dayTimings.fajr);
        final tSunrise = parseTZTime(dayTimings.sunrise);
        final tDhuhr = parseTZTime(dayTimings.dhuhr);
        var tAsr = parseTZTime(dayTimings.asr);
        var tMaghrib = parseTZTime(dayTimings.maghrib);
        var tIsha = parseTZTime(dayTimings.isha);

        // Poka-Yoke astronomical sanity guard: Asr is ALWAYS >= 90 minutes after Dhuhr in Turkey
        if (tAsr.difference(tDhuhr).inMinutes < 90) {
          final safeOffline = PrayerTimesService.calculateOfflinePrayerTimes(city, targetDate);
          tAsr = parseTZTime(safeOffline.asr);
          tMaghrib = parseTZTime(safeOffline.maghrib);
          tIsha = parseTZTime(safeOffline.isha);
        }

        // 1. Prayer Entry Items (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı)
        final prayerItems = [
          (name: 'İmsak', time: tFajr, prefKey: 'ImsakNotificationEnabled'),
          (name: 'Güneş', time: tSunrise, prefKey: 'GunesNotificationEnabled'),
          (name: 'Öğle', time: tDhuhr, prefKey: 'OgleNotificationEnabled'),
          (name: 'İkindi', time: tAsr, prefKey: 'IkindiNotificationEnabled'),
          (name: 'Akşam', time: tMaghrib, prefKey: 'AksamNotificationEnabled'),
          (name: 'Yatsı', time: tIsha, prefKey: 'YatsiNotificationEnabled'),
        ];

        for (int pIdx = 0; pIdx < prayerItems.length; pIdx++) {
          final item = prayerItems[pIdx];
          final isEnabled = prefs.getBool(item.prefKey) ??
              prefs.getBool('${item.name}NotificationEnabled') ??
              true;
          if (!isEnabled) continue;

          final customTimeStr =
              prefs.getString('PrayerCustomTime_${item.name}') ?? '';
          final offsetMins =
              prefs.getInt('PrayerOffset_${item.name}') ?? 0;

          final tz.TZDateTime targetTime = customTimeStr.trim().contains(':')
              ? parseTZTime(customTimeStr)
              : (offsetMins > 0
                  ? item.time.subtract(Duration(minutes: offsetMins))
                  : item.time);
          if (targetTime.isBefore(currentTZNow)) continue; // Already in the past

          final farzIdx = (baseFarzIdx + globalFarzStep) % kFarz32List.length;
          globalFarzStep++;
          final farzItem = kFarz32List[farzIdx];

          final title = (customTimeStr.trim().isEmpty && offsetMins > 0)
              ? '${item.name} Vaktine $offsetMins Dk Kaldı 🕌 • 32 Farz (#${farzItem.id})'
              : '${item.name} Vakti Girdi 🕌 • 32 Farz (#${farzItem.id})';
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
          final qOffset = questionMinutesBeforeEnd.clamp(5, 180);
          final yatsiTarget = questionCustomTime.trim().contains(':')
              ? parseTZTime(questionCustomTime)
              : tIsha.add(Duration(minutes: qOffset));
          final questionItems = [
            (
              name: 'Sabah',
              entryTime: tFajr,
              nextEntryTime: tSunrise,
              targetTime: tSunrise.subtract(Duration(minutes: qOffset)),
              minOffsetMinutes: 20,
              prefKey: 'ImsakNotificationEnabled',
              fallbackKey: 'SabahNotificationEnabled',
            ),
            (
              name: 'Öğle',
              entryTime: tDhuhr,
              nextEntryTime: tAsr,
              targetTime: tAsr.subtract(Duration(minutes: qOffset)),
              minOffsetMinutes: 60,
              prefKey: 'OgleNotificationEnabled',
              fallbackKey: 'OgleNotificationEnabled',
            ),
            (
              name: 'İkindi',
              entryTime: tAsr,
              nextEntryTime: tMaghrib,
              targetTime: tMaghrib.subtract(Duration(minutes: qOffset)),
              minOffsetMinutes: 45,
              prefKey: 'IkindiNotificationEnabled',
              fallbackKey: 'IkindiNotificationEnabled',
            ),
            (
              name: 'Akşam',
              entryTime: tMaghrib,
              nextEntryTime: tIsha,
              targetTime: tIsha.subtract(Duration(minutes: qOffset)),
              minOffsetMinutes: 20,
              prefKey: 'AksamNotificationEnabled',
              fallbackKey: 'AksamNotificationEnabled',
            ),
            (
              name: 'Yatsı',
              entryTime: tIsha,
              nextEntryTime: tIsha.add(const Duration(hours: 4)),
              targetTime: yatsiTarget,
              minOffsetMinutes: 15,
              prefKey: 'YatsiNotificationEnabled',
              fallbackKey: 'YatsiNotificationEnabled',
            ),
          ];

          for (int qIdx = 0; qIdx < questionItems.length; qIdx++) {
            final q = questionItems[qIdx];
            final isEnabled = prefs.getBool(q.prefKey) ?? prefs.getBool(q.fallbackKey) ?? true;
            if (!isEnabled) continue;

            // Skip today's question notification if the user has already answered or completed this prayer today
            if (dayOffset == 0) {
              final alreadyDoneToday = (todayFardDate == todayStr &&
                      (prefs.getBool('TodayFard_${q.name}') ?? false)) ||
                  (prefs.getBool('TodayPrayerAnswered_${todayStr}_${q.name}') ?? false);
              if (alreadyDoneToday) continue;
            }

            // Poka-Yoke Guard: Question notification MUST NEVER fire before [entryTime + minOffsetMinutes]
            final minQuestionTime = q.entryTime.add(Duration(minutes: q.minOffsetMinutes));
            var questionTime = q.targetTime;
            if (questionTime.isBefore(minQuestionTime)) {
              final windowMinutes = q.nextEntryTime.difference(q.entryTime).inMinutes;
              if (windowMinutes > q.minOffsetMinutes + 10) {
                final safeOffset = (windowMinutes * 0.65).round().clamp(q.minOffsetMinutes, windowMinutes - 10);
                questionTime = q.entryTime.add(Duration(minutes: safeOffset));
              } else {
                continue;
              }
            }
            if (!questionTime.isAfter(q.entryTime)) continue;
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

        // 3. Weekly Special Spiritual Recitations (Feraciye Duası & Perşembe/Cuma Salâsı)
        if (targetDate.weekday == DateTime.thursday) {
          // 3a. Perşembe Feraciye Duası (Varsayılan: Akşam namazından 15 dk önce)
          if (isFeraciyeEnabled) {
            final feraciyeTarget = feraciyeCustomTime.trim().contains(':')
                ? parseTZTime(feraciyeCustomTime)
                : tMaghrib.subtract(Duration(minutes: feraciyeMinutesBefore));
            if (feraciyeTarget.isAfter(currentTZNow)) {
              final feraciyeConfig = _resolveChannelConfig(feraciyeSound);
              const fTitle = '🤲 Perşembe Feraciye Duası Vakti';
              final fBody = feraciyeCustomTime.trim().contains(':')
                  ? 'Cuma gecesine girerken okunan mübarek Feraciye Duası vakti girdi. Faziletini okumak ve dinlemek için dokunun.'
                  : 'Akşam ezanına $feraciyeMinutesBefore dk kaldı. Mübarek Cuma gecesi Feraciye Duası vakti girdi.';
              final fDetails = _buildNotificationDetails(
                config: feraciyeConfig,
                title: fTitle,
              );
              await _scheduleZonedWithFallback(
                id: baseSpecialWeeklyNotificationId + (dayOffset * 10) + 0,
                title: fTitle,
                body: fBody,
                scheduledDate: feraciyeTarget,
                notificationDetails: fDetails,
                payload: 'special_spiritual|feraciye',
              );
            }
          }

          // 3b. Perşembe Yatsı Öncesi Salâ (Varsayılan: Yatsıdan 30 dk önce)
          if (isThursdaySelaEnabled) {
            final thursdaySelaTarget = thursdaySelaCustomTime.trim().contains(':')
                ? parseTZTime(thursdaySelaCustomTime)
                : tIsha.subtract(Duration(minutes: thursdaySelaMinutesBefore));
            if (thursdaySelaTarget.isAfter(currentTZNow)) {
              final selaConfig = _resolveChannelConfig(thursdaySelaSound);
              const sTitle = '🕌 Cuma Gecesi Salâ Vakti';
              final sBody = thursdaySelaCustomTime.trim().contains(':')
                  ? 'Mübarek Cuma gecesi salâ vakti girdi. Efendimiz\'e (s.a.v.) salât ü selâm getirmeyi unutmayın.'
                  : 'Yatsı ezanına $thursdaySelaMinutesBefore dk kaldı. Mübarek Cuma gecesi salâ vakti girdi.';
              final sDetails = _buildNotificationDetails(
                config: selaConfig,
                title: sTitle,
              );
              await _scheduleZonedWithFallback(
                id: baseSpecialWeeklyNotificationId + (dayOffset * 10) + 1,
                title: sTitle,
                body: sBody,
                scheduledDate: thursdaySelaTarget,
                notificationDetails: sDetails,
                payload: 'special_spiritual|thursday_sela',
              );
            }
          }
        } else if (targetDate.weekday == DateTime.friday) {
          // 3c. Cuma Namazı Öncesi Salâ (Varsayılan: Cuma/Öğle vaktinden 45 dk önce)
          if (isFridaySelaEnabled) {
            final fridaySelaTarget = fridaySelaCustomTime.trim().contains(':')
                ? parseTZTime(fridaySelaCustomTime)
                : tDhuhr.subtract(Duration(minutes: fridaySelaMinutesBefore));
            if (fridaySelaTarget.isAfter(currentTZNow)) {
              final selaConfig = _resolveChannelConfig(fridaySelaSound);
              const cTitle = '🕌 Cuma Vakti Salâsı';
              final cBody = fridaySelaCustomTime.trim().contains(':')
                  ? 'Mübarek Cuma salâsı vakti girdi. Cum\'anız mübarek olsun, salât ü selâm getirmeyi unutmayın.'
                  : 'Cuma ezanına $fridaySelaMinutesBefore dk kaldı. Cuma salâsı vakti girdi, Cum\'anız mübarek olsun.';
              final cDetails = _buildNotificationDetails(
                config: selaConfig,
                title: cTitle,
              );
              await _scheduleZonedWithFallback(
                id: baseSpecialWeeklyNotificationId + (dayOffset * 10) + 2,
                title: cTitle,
                body: cBody,
                scheduledDate: fridaySelaTarget,
                notificationDetails: cDetails,
                payload: 'special_spiritual|friday_sela',
              );
            }
          }
        }
      }

      await prefs.setInt('FarzNotificationDaySlotsCount', globalFarzStep.clamp(1, 42));
      debugPrint('[LocalNotificationService] Successfully scheduled $daysLimit-day rolling prayer & question notifications');
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] scheduleAllPrayerNotifications error: $e');
    } finally {
      _isScheduling = false;
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
    if (lower.contains('ezan')) {
      return const _NotificationChannelConfig(
        channelId: channelEzan,
        channelName: 'Zikirce (Ezan Sesi)',
        description: 'Ezan-ı Muhammedi sesi ile bildirim',
        sound: RawResourceAndroidNotificationSound('ezan'),
        darwinSound: 'ezan.wav',
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    } else if (lower.contains('sela') ||
        lower.contains('salâ') ||
        lower.contains('sala')) {
      return const _NotificationChannelConfig(
        channelId: channelSela,
        channelName: 'Zikirce (Salâ Sesi)',
        description: 'Cuma ve Perşembe gecesi Salâ sesi ile bildirim',
        sound: RawResourceAndroidNotificationSound('sela'),
        darwinSound: 'sela.wav',
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    } else if (lower.contains('feraciye')) {
      return const _NotificationChannelConfig(
        channelId: channelFeraciye,
        channelName: 'Zikirce (Feraciye Duası)',
        description: 'Perşembe akşamı Feraciye Duası ile bildirim',
        sound: RawResourceAndroidNotificationSound('feraciye'),
        darwinSound: 'feraciye.wav',
        playSound: true,
        enableVibration: true,
        importance: Importance.max,
      );
    } else if (lower.contains('kumru')) {
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
