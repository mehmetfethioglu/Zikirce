import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_sync_engine.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../core/services/screen_awake_service.dart';
import '../core/theme/theme_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/namaz_vakitleri/providers/prayer_providers.dart';
import '../features/gamification/providers/gamification_providers.dart';
import '../core/widgets/celebration/spiritual_celebration_overlay.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Warm up cloudSyncProvider early so CloudSyncEngine has application-level Ref
      ref.read(cloudSyncProvider.notifier);
      CloudSyncEngine.instance.syncOnAppResume(ref);
      CloudSyncEngine.instance.startPeriodicSync(ref);
    });
  }

  @override
  void dispose() {
    CloudSyncEngine.instance.stopPeriodicSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Invalidate database streams when resuming so external widget modifications reflect immediately
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(dailyGoalsStatusProvider);
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
        ScreenAwakeService.setKeepAwake(next);
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return SpiritualCelebrationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
