import 'dart:io';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/app_database.dart';
import 'core/database/migration/maui_migration_service.dart';
import 'core/database/zikir_seed_data.dart';
import 'core/services/audio_sync_service.dart';
import 'core/services/tafseer_service.dart';
import 'core/services/notification_db_service.dart';
import 'core/services/sound_pool_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/widget_sync_service.dart';
import 'core/services/prayer_times_service.dart';
import 'core/session/session_manager_service.dart';
import 'core/session/session_providers.dart';
import 'core/session/user_session.dart';
import 'core/theme/theme_provider.dart';
import 'features/gamification/services/daily_streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/cloud_sync_engine.dart';
import 'app/app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  // Set preferred orientations & system overlay on mobile
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
    );
  }

  // Get active session and initialize database
  final activeSessionId = await SessionManagerService.getActiveSessionId();
  final sessions = await SessionManagerService.loadSessions();
  final currentSession = sessions.firstWhere(
    (s) => s.id == activeSessionId,
    orElse: () => sessions.isNotEmpty ? sessions.first : UserSession.defaultSession(),
  );
  final db = AppDatabase(null, currentSession.dbFileName);

  await Future.wait([
    AudioSyncService.initialize(),
    TafseerService.initialize(),
    NotificationDbService.initialize(),
    SoundPoolService.initialize(),
    LocalNotificationService.initialize(),
  ]);

  // Execute seamless MAUI data migration if upgrading from .NET MAUI
  try {
    await MauiMigrationService.checkAndMigrate(db);
  } catch (e) {
    debugPrint('[Main] Migration check notice: $e');
  }

  // Populate 1:1 MAUI Zikir Database (Hadislerden Zikirler, Esmaül-Hüsna, Dualar)
  try {
    await ZikirSeedData.ensureAllDefaultZikirsExist(db);
  } catch (e) {
    debugPrint('[Main] ZikirSeedData notice: $e');
  }

  // Check and advance daily streak on app launch
  try {
    await DailyStreakService.checkDailyStreakOnStartup(db);
  } catch (e) {
    debugPrint('[Main] DailyStreakService notice: $e');
  }

  // Initialize and synchronize all 9 Home Screen AppWidgets
  try {
    await WidgetSyncService.syncAll(db, sessionId: currentSession.id);
  } catch (e) {
    debugPrint('[Main] WidgetSync notice: $e');
  }

  // Pre-schedule 6 prayer entries, 5 questions, and Quran reminder for next 24-48 hours (Mobile only)
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString('SelectedCity') ?? prefs.getString('AppCity') ?? 'Şanlıurfa';
      final timings = await PrayerTimesService.getPrayerTimes(city: city);
      await LocalNotificationService.scheduleAllPrayerNotifications(timings);

      final isQuranReminder = prefs.getBool('IsQuranReminderEnabled') ?? true;
      final quranTime = prefs.getString('QuranReminderTime') ?? '21:00';
      await LocalNotificationService.scheduleQuranDailyReminder(
        timeHhmm: quranTime,
        isEnabled: isQuranReminder,
      );
    } catch (e) {
      debugPrint('[Main] Pre-scheduling notifications notice: $e');
    }
  }

  // Pre-load theme settings before runApp to prevent theme flickering on startup
  final savedThemeKey = await ThemeNotifier.loadSavedThemeKey(activeSessionId);
  final savedLightSubTheme = await ThemeNotifier.loadSavedLightSubTheme(activeSessionId);

  // Close the initial startup DB instance so Riverpod's databaseProvider manages the single active connection
  try {
    await db.close();
  } catch (_) {}

  // Initialize Sentry with Crash Monitoring & ANR Watchdog
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryConfig.dsn;
      options.release = SentryConfig.release;
      options.tracesSampleRate = 0.2;
      options.anrEnabled = true;
      options.enableAutoPerformanceTracing = true;
      options.beforeSend = SentryConfig.beforeSend;
    },
    appRunner: () {
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState(
              sessions: sessions,
              activeSessionId: activeSessionId,
              isLoading: false,
            ),
          ),
          initialThemeKeyProvider.overrideWithValue(savedThemeKey),
          initialLightSubThemeProvider.overrideWithValue(savedLightSubTheme),
        ],
      );
      CloudSyncEngine.instance.setContainer(container);

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const ZikirceApp(),
        ),
      );
    },
  );
}
