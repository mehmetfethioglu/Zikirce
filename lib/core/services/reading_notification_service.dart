import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationNecessityReason {
  notNeededGoalMet,
  notNeededAlreadyNotifiedToday,
  notNeededDisabled,
  streakAtRiskEvening,
  gentleDailyReminder,
  milestoneCelebration,
}

class SmartNotificationDecision {
  final bool shouldNotify;
  final NotificationNecessityReason reason;
  final String title;
  final String body;

  const SmartNotificationDecision({
    required this.shouldNotify,
    required this.reason,
    required this.title,
    required this.body,
  });
}

class NotificationPreferencesState {
  final bool isEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool onlyWhenGoalIncomplete;
  final bool streakRiskAlertEnabled;
  final int streakShieldCount;
  final bool isShieldArmedForToday;
  final String? lastNotificationPreview;

  const NotificationPreferencesState({
    this.isEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 30,
    this.onlyWhenGoalIncomplete = true,
    this.streakRiskAlertEnabled = true,
    this.streakShieldCount = 2,
    this.isShieldArmedForToday = false,
    this.lastNotificationPreview,
  });

  String get formattedReminderTime {
    final h = reminderHour.toString().padLeft(2, '0');
    final m = reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  NotificationPreferencesState copyWith({
    bool? isEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? onlyWhenGoalIncomplete,
    bool? streakRiskAlertEnabled,
    int? streakShieldCount,
    bool? isShieldArmedForToday,
    String? lastNotificationPreview,
  }) {
    return NotificationPreferencesState(
      isEnabled: isEnabled ?? this.isEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      onlyWhenGoalIncomplete:
          onlyWhenGoalIncomplete ?? this.onlyWhenGoalIncomplete,
      streakRiskAlertEnabled:
          streakRiskAlertEnabled ?? this.streakRiskAlertEnabled,
      streakShieldCount: streakShieldCount ?? this.streakShieldCount,
      isShieldArmedForToday:
          isShieldArmedForToday ?? this.isShieldArmedForToday,
      lastNotificationPreview:
          lastNotificationPreview ?? this.lastNotificationPreview,
    );
  }
}

class ReadingNotificationService extends StateNotifier<NotificationPreferencesState> {
  static const MethodChannel _nativeChannel =
      MethodChannel('com.tahrir.app/native_bridge');

  static const String _enabledKey = 'tahrir_notif_enabled_v1';
  static const String _hourKey = 'tahrir_notif_hour_v1';
  static const String _minuteKey = 'tahrir_notif_minute_v1';
  static const String _onlyIncompleteKey = 'tahrir_notif_only_incomplete_v1';
  static const String _streakAlertKey = 'tahrir_notif_streak_alert_v1';
  static const String _shieldCountKey = 'tahrir_streak_shield_count_v1';
  static const String _shieldArmedDateKey = 'tahrir_streak_shield_date_v1';
  static const String _lastNotifiedDateKey = 'tahrir_last_notified_date_v1';

  ReadingNotificationService() : super(const NotificationPreferencesState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final todayIso = _todayKey(DateTime.now());
    final armedDate = prefs.getString(_shieldArmedDateKey);

    state = state.copyWith(
      isEnabled: prefs.getBool(_enabledKey) ?? true,
      reminderHour: prefs.getInt(_hourKey) ?? 20,
      reminderMinute: prefs.getInt(_minuteKey) ?? 30,
      onlyWhenGoalIncomplete: prefs.getBool(_onlyIncompleteKey) ?? true,
      streakRiskAlertEnabled: prefs.getBool(_streakAlertKey) ?? true,
      streakShieldCount: prefs.getInt(_shieldCountKey) ?? 2,
      isShieldArmedForToday: armedDate == todayIso,
    );
  }

  static String _todayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Bildirim gerekliliğini (Necessity-Driven Notification Logic) hesaplar.
  /// Kullanıcı günlük hedefini tamamladıysa asla gereksiz bildirim (Muda) üretmez.
  static SmartNotificationDecision evaluateNecessity({
    required bool isEnabled,
    required bool onlyWhenGoalIncomplete,
    required bool streakRiskAlertEnabled,
    required int streakDays,
    required int todayMinutesRead,
    required int dailyGoalMinutes,
    required String currentBookTitle,
    required int currentHour,
    bool alreadyNotifiedToday = false,
  }) {
    if (!isEnabled) {
      return const SmartNotificationDecision(
        shouldNotify: false,
        reason: NotificationNecessityReason.notNeededDisabled,
        title: '',
        body: '',
      );
    }

    if (onlyWhenGoalIncomplete && todayMinutesRead >= dailyGoalMinutes) {
      return const SmartNotificationDecision(
        shouldNotify: false,
        reason: NotificationNecessityReason.notNeededGoalMet,
        title: 'Günlük Hedef Tamamlandı',
        body: 'Bugünkü mütalaa hedefiniz mühürlendiği için bildirim gönderilmedi.',
      );
    }

    if (alreadyNotifiedToday) {
      return const SmartNotificationDecision(
        shouldNotify: false,
        reason: NotificationNecessityReason.notNeededAlreadyNotifiedToday,
        title: '',
        body: '',
      );
    }

    final remaining = (dailyGoalMinutes - todayMinutesRead).clamp(1, 120);
    final bookLabel =
        currentBookTitle.trim().isNotEmpty ? '“$currentBookTitle”' : 'kitabınız';

    // Akşam 19:00 sonrası ve aktif seri tehlikedeyse (henüz hiç okunmamışsa)
    if (streakRiskAlertEnabled &&
        streakDays > 0 &&
        todayMinutesRead == 0 &&
        currentHour >= 19) {
      return SmartNotificationDecision(
        shouldNotify: true,
        reason: NotificationNecessityReason.streakAtRiskEvening,
        title: '🔥 $streakDays Günlük Tahrir Seriniz Sönmesin!',
        body:
            '$bookLabel sizi bekliyor. Zinciri korumak için 3 dakikalık tek bir fasıl okumanız veya Kıraat Kalkanını açmanız yeterli.',
      );
    }

    // Kısmi okuma yapılmış ama hedefe az kalmışsa
    if (todayMinutesRead > 0 && todayMinutesRead < dailyGoalMinutes) {
      return SmartNotificationDecision(
        shouldNotify: true,
        reason: NotificationNecessityReason.gentleDailyReminder,
        title: '🕯️ Günlük Mühre Sadece $remaining Dakika Kaldı',
        body:
            'Bugün $todayMinutesRead dk okudunuz. $bookLabel eserinde bir fasıl daha okuyarak günlük hedefinizi tamamlayın.',
      );
    }

    return SmartNotificationDecision(
      shouldNotify: true,
      reason: NotificationNecessityReason.gentleDailyReminder,
      title: '📜 Akşam Mütalaa Vakti Geldi',
      body:
          '$bookLabel eserinde kaldığınız satırdan devam etmek ve zihninizi dinlendirmek için 15 dk Mütalaa Ritüeli hazır.',
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await requestNotificationPermission();
    }
  }

  /// Android 13+ (TIRAMISU) cihazlarda bildirim izni ister
  Future<void> requestNotificationPermission() async {
    try {
      await _nativeChannel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('requestNotificationPermission skipped: $e');
    }
  }

  /// "Tahrir ile Aç" (ACTION_VIEW) ile dışarıdan gelen dosya yolunu tüketir
  Future<String?> consumeIncomingFile() async {
    try {
      final path = await _nativeChannel.invokeMethod<String>('consumeIncomingFile');
      if (path != null && path.trim().isNotEmpty) {
        return path.trim();
      }
      return null;
    } catch (e) {
      debugPrint('consumeIncomingFile skipped: $e');
      return null;
    }
  }

  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  Future<void> setOnlyWhenGoalIncomplete(bool value) async {
    state = state.copyWith(onlyWhenGoalIncomplete: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlyIncompleteKey, value);
  }

  Future<void> setStreakRiskAlertEnabled(bool value) async {
    state = state.copyWith(streakRiskAlertEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_streakAlertKey, value);
  }

  /// Seri Kalkanını (Streak Freeze) bugün için devreye alır
  Future<bool> armStreakShieldForToday() async {
    if (state.isShieldArmedForToday) return true;
    if (state.streakShieldCount <= 0) return false;

    final nextCount = state.streakShieldCount - 1;
    final todayIso = _todayKey(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shieldCountKey, nextCount);
    await prefs.setString(_shieldArmedDateKey, todayIso);

    state = state.copyWith(
      streakShieldCount: nextCount,
      isShieldArmedForToday: true,
    );
    return true;
  }

  /// Bildirim gerekliliğini denetler ve gerekliyse yerel OS bildirimini tetikler
  Future<SmartNotificationDecision> checkAndDispatchSmartNotification({
    required int streakDays,
    required int todayMinutesRead,
    required int dailyGoalMinutes,
    required String currentBookTitle,
    bool forceTest = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayIso = _todayKey(now);
    final alreadyNotified =
        !forceTest && (prefs.getString(_lastNotifiedDateKey) == todayIso);

    final decision = evaluateNecessity(
      isEnabled: forceTest ? true : state.isEnabled,
      onlyWhenGoalIncomplete: forceTest ? false : state.onlyWhenGoalIncomplete,
      streakRiskAlertEnabled: state.streakRiskAlertEnabled,
      streakDays: streakDays,
      todayMinutesRead: todayMinutesRead,
      dailyGoalMinutes: dailyGoalMinutes,
      currentBookTitle: currentBookTitle,
      currentHour: forceTest ? 20 : now.hour,
      alreadyNotifiedToday: alreadyNotified,
    );

    if (decision.shouldNotify) {
      if (!forceTest) {
        await prefs.setString(_lastNotifiedDateKey, todayIso);
      }
      state = state.copyWith(
        lastNotificationPreview: '${decision.title} — ${decision.body}',
      );
      try {
        await _nativeChannel.invokeMethod('showSmartNotification', {
          'title': decision.title,
          'body': decision.body,
        });
      } catch (e) {
        debugPrint('Native notification dispatch fallback: $e');
      }
    }

    return decision;
  }

  /// Cihaz Ana Ekran Widget'ını (Android AppWidget) güncel okuma verileriyle senkronize eder
  Future<void> syncHomeScreenWidget({
    required int streakDays,
    required int todayMinutesRead,
    required int dailyGoalMinutes,
    required String currentBookTitle,
    required String currentBookAuthor,
    required int progressPercent,
    required String dailyQuote,
  }) async {
    try {
      await _nativeChannel.invokeMethod('updateHomeWidget', {
        'streakDays': streakDays,
        'todayMinutesRead': todayMinutesRead,
        'dailyGoalMinutes': dailyGoalMinutes,
        'bookTitle': currentBookTitle,
        'bookAuthor': currentBookAuthor,
        'progressPercent': progressPercent,
        'dailyQuote': dailyQuote,
      });
    } catch (e) {
      debugPrint('HomeWidget sync skipped on current platform: $e');
    }
  }

  /// Kullanıcının tek dokunuşla Tahrir Widget'ını telefon ana ekranına sabitlemesini ister
  Future<bool> requestPinHomeScreenWidget() async {
    try {
      final res = await _nativeChannel.invokeMethod<bool>('requestPinHomeWidget');
      return res ?? false;
    } catch (e) {
      debugPrint('requestPinHomeWidget fallback: $e');
      return false;
    }
  }
}

final readingNotificationProvider = StateNotifierProvider<
    ReadingNotificationService, NotificationPreferencesState>((ref) {
  return ReadingNotificationService();
});
