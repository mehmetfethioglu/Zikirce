import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../core/services/cloud_sync_engine.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/widget_sync_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../core/providers/tv_mode_provider.dart';
import '../core/services/screen_awake_service.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/notification_detail_bottom_sheet.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/tv/providers/tv_cast_provider.dart';
import '../features/namaz_vakitleri/providers/prayer_providers.dart';
import '../features/gamification/providers/gamification_providers.dart';
import '../core/widgets/celebration/spiritual_celebration_overlay.dart';
import '../core/widgets/splash/zikirce_splash_overlay.dart';
import 'router/app_deep_link_router.dart';
import 'router/app_router.dart';

/// Masaüstü ve tüm platformlarda fare ile sürüklemeyi (mouse drag) aktif kılan ScrollBehavior
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

class ZikirceApp extends ConsumerStatefulWidget {
  const ZikirceApp({super.key});

  @override
  ConsumerState<ZikirceApp> createState() => _ZikirceAppState();
}

class _ZikirceAppState extends ConsumerState<ZikirceApp> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSub;
  StreamSubscription<String>? _notificationPayloadSub;
  bool _isNotificationSheetOpen = false;
  int _activeSheetRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationPayloadSub = LocalNotificationService
        .notificationPayloadTapped.stream
        .listen(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Warm up cloudSyncProvider early so CloudSyncEngine has application-level Ref
      ref.read(cloudSyncProvider.notifier);
      CloudSyncEngine.instance.syncOnAppResume(ref);
      CloudSyncEngine.instance.startPeriodicSync(ref);
      _initWidgetDeepLinkListener();
      final initialPayload =
          LocalNotificationService.consumeInitialNotificationPayload();
      LocalNotificationService.consumeInitialPrayerNotificationTap();
      if (initialPayload != null) {
        _handleNotificationPayload(initialPayload);
      }
    });
  }

  Future<void> _initWidgetDeepLinkListener() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(WidgetSyncService.appGroupId);
      }
      _widgetClickSub ??= HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) {
          _handleWidgetUri(uri);
        }
      });
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _handleWidgetUri(initialUri);
      }
    } catch (e) {
      debugPrint('[ZikirceApp] Widget deep-link listener error: $e');
    }
  }

  void _handleNotificationPayload(String payload) {
    final intent = AppDeepLinkRouter.resolveNotificationPayload(payload);
    if (intent != null) {
      _applyNavigationIntent(intent);
    }
  }

  void _handleWidgetUri(Uri uri) {
    final intent = AppDeepLinkRouter.resolveWidgetUri(uri);
    if (intent != null) {
      _applyNavigationIntent(intent);
    }
  }

  Future<bool> _waitForRouteArrival(String expectedPath) async {
    final currentPath =
        appRouter.routerDelegate.currentConfiguration.uri.path;
    if (currentPath == expectedPath) return true;
    if (currentPath == '/onboarding') return false;

    final completer = Completer<bool>();
    late VoidCallback listener;
    Timer? timeoutTimer;

    void finish(bool arrived) {
      if (!completer.isCompleted) {
        completer.complete(arrived);
      }
    }

    listener = () {
      final path = appRouter.routerDelegate.currentConfiguration.uri.path;
      if (path == expectedPath) {
        finish(true);
      } else if (path == '/onboarding') {
        finish(false);
      }
    };

    appRouter.routerDelegate.addListener(listener);
    timeoutTimer = Timer(const Duration(seconds: 2), () => finish(false));

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      appRouter.routerDelegate.removeListener(listener);
    }
  }

  Future<void> _presentNotificationDetailAfterArrival({
    required NotificationDetailSpec spec,
    required String expectedPath,
    required int requestId,
  }) async {
    final arrived = await _waitForRouteArrival(expectedPath);
    if (!arrived || !mounted || requestId != _activeSheetRequestId) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        requestId != _activeSheetRequestId ||
        _isNotificationSheetOpen) {
      return;
    }

    final currentPath =
        appRouter.routerDelegate.currentConfiguration.uri.path;
    if (currentPath != expectedPath) return;

    final rootCtx = appRootNavigatorKey.currentContext;
    if (rootCtx == null || !rootCtx.mounted) return;

    _isNotificationSheetOpen = true;
    try {
      await NotificationDetailBottomSheet.show(rootCtx, spec: spec);
    } catch (e) {
      debugPrint('[ZikirceApp] Notification detail sheet error: $e');
    } finally {
      _isNotificationSheetOpen = false;
    }
  }

  void _applyNavigationIntent(AppNavigationIntent intent) {
    if (!mounted || TvModeService.isHardwareTv || ref.read(isTvModeProvider)) {
      return;
    }

    final pushRoute = intent.pushRoute;
    final expectedPath = (pushRoute != null && pushRoute.isNotEmpty)
        ? Uri.parse(pushRoute).path
        : Uri.parse(intent.baseRoute).path;

    appRouter.go(intent.baseRoute);
    if (pushRoute != null && pushRoute.isNotEmpty) {
      Future.microtask(() {
        if (mounted) {
          appRouter.push(pushRoute);
        }
      });
    }

    final detailSpec = intent.notificationDetail;
    if (detailSpec != null) {
      final requestId = ++_activeSheetRequestId;
      unawaited(
        _presentNotificationDetailAfterArrival(
          spec: detailSpec,
          expectedPath: expectedPath,
          requestId: requestId,
        ),
      );
    }
  }

  @override
  void dispose() {
    _activeSheetRequestId++;
    _notificationPayloadSub?.cancel();
    _widgetClickSub?.cancel();
    CloudSyncEngine.instance.stopPeriodicSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    unawaited(
      TvModeService.syncOrientationForCurrentDisplay(
        isTvMode: ref.read(isTvModeProvider),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!ref.read(isTvModeProvider)) {
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        if (ref.read(currentDateProvider) != todayStr) {
          ref.invalidate(currentDateProvider);
          ref.invalidate(prayerTimingsProvider);
        } else {
          final timings = ref.read(prayerTimingsProvider).valueOrNull;
          if (timings != null) {
            final city = ref.read(selectedCityProvider);
            LocalNotificationService.scheduleAllPrayerNotifications(
              timings,
              cityOverride: city,
            );
          }
        }
        // Invalidate database streams when resuming so external widget modifications reflect immediately
        ref.invalidate(kazaPrayersStreamProvider);
        ref.invalidate(kazaSummaryProvider);
        ref.invalidate(todayPrayersProvider);
        ref.invalidate(dailyGoalsStatusProvider);
      }
      if (!TvModeService.isHardwareTv && ref.read(tvCastProvider).isSupported) {
        unawaited(ref.read(tvCastProvider.notifier).refreshStatus());
      }
      // Trigger silent cloud check & reconciliation
      CloudSyncEngine.instance.syncOnAppResume(ref);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Push any pending changes before sleeping
      CloudSyncEngine.instance.syncOnAppPause(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep screen awake reactive sync
    ref.listen<bool>(
      settingsProvider.select((s) => s.isKeepScreenAwakeEnabled),
      (prev, next) {
        ScreenAwakeService.setKeepAwake(next || ref.read(isTvModeProvider));
      },
    );

    // Watch active theme state & light sub-theme to trigger rebuild on theme configuration change
    final activeThemeKey = ref.watch(themeNotifierProvider);
    final lightSubTheme = ref.watch(lightSubThemeProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);

    // Watch active locale to trigger rebuild on language change
    final activeLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Zikirce',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: themeNotifier.getLightThemeData(lightSubTheme),
      darkTheme: themeNotifier.getDarkThemeData(activeThemeKey),
      themeMode: themeNotifier.getThemeMode(activeThemeKey),
      locale: activeLocale,
      routerConfig: appRouter,
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return ZikirceSplashOverlay(
          child: SpiritualCelebrationOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
