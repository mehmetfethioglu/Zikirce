import 'dart:io';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
import 'features/namaz_vakitleri/providers/prayer_providers.dart';
import 'features/gamification/services/daily_streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/cloud_sync_engine.dart';
import 'app/app.dart';

void main(List<String> args) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  // Set preferred orientations & system overlay on mobile
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    final shortestSide = view != null
        ? view.physicalSize.shortestSide / view.devicePixelRatio
        : 0.0;
    final isTablet = shortestSide >= 600;

    if (!isTablet) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

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

  // Pre-load theme settings and prayer city before runApp to prevent flickering / race conditions
  final savedThemeKey = await ThemeNotifier.loadSavedThemeKey(activeSessionId);
  final savedLightSubTheme = await ThemeNotifier.loadSavedLightSubTheme(activeSessionId);
  final savedCity = await CityNotifier.loadSavedCity(activeSessionId);

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
      // Remove native splash seamlessly right as the first frame of ZikirceSplashOverlay renders
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        FlutterNativeSplash.remove();
        AudioSyncService.initialize();
        TafseerService.initialize();
        if (Platform.isAndroid || Platform.isIOS) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final timings = await PrayerTimesService.getPrayerTimes(city: savedCity);
            await LocalNotificationService.scheduleAllPrayerNotifications(timings);

            final isQuranReminder = prefs.getBool('IsQuranReminderEnabled') ?? true;
            final quranTime = prefs.getString('QuranReminderTime') ?? '21:00';
            await LocalNotificationService.scheduleQuranDailyReminder(
              timeHhmm: quranTime,
              isEnabled: isQuranReminder,
            );
          } catch (e) {
            debugPrint('[Main] Deferred background tasks notice: $e');
          }
        }
      });

      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState(
              sessions: sessions,
              activeSessionId: activeSessionId,
              isLoading: false,
            ),
          ),
          initialCityProvider.overrideWithValue(savedCity),
          initialThemeKeyProvider.overrideWithValue(savedThemeKey),
          initialLightSubThemeProvider.overrideWithValue(savedLightSubTheme),
        ],
      );
      CloudSyncEngine.instance.setContainer(container);

      ErrorWidget.builder = (FlutterErrorDetails details) {
        debugPrint('[FlutterError] Caught by ErrorWidget.builder: ${details.exception}');
        return Material(
          color: const Color(0xFFECF3F0),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF236B56), size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Bileşen Yüklenirken Bir Sorun Oluştu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E2B27)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF506861)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      };

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const ZikirceApp(),
        ),
      );
    },
  );
}
