import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/database_helper.dart';
import 'core/services/kilerce_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/kiler/domain/expiry_reminder_service.dart';
import 'features/kiler/domain/kiler_service.dart';
import 'features/kiler/presentation/kilerce_hub_screen.dart';
import 'features/monetization/domain/subscription_service.dart';
import 'features/profile/domain/google_auth_sync_service.dart';
import 'features/profile/domain/user_profile_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system bar transparent styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Load saved theme preference, initialize SQLite database, Kilerce engine & user profile
  await ThemeController.instance.loadSavedTheme();
  await DatabaseHelper().database;
  await Future.wait([
    KilerService.instance.loadAll(),
    UserProfileService.instance.loadProfile(),
  ]);
  unawaited(GoogleAuthSyncService.instance.init());
  unawaited(ExpiryReminderService.instance.checkAndNotifyIfNeeded());
  unawaited(
    KilerceNotificationService.instance.syncAllReminders(
      allowImmediateTodayAlert: true,
    ),
  );
  unawaited(SubscriptionService.instance.initAdMob());
  unawaited(SubscriptionService.instance.initRevenueCat());

  runApp(const ProviderScope(child: OrganicScoreApp()));
}

class OrganicScoreApp extends StatelessWidget {
  const OrganicScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, currentMode, child) {
        return MaterialApp(
          onGenerateTitle: (ctx) =>
              AppLocalizations.of(ctx)?.appTitle ??
              'Kilerce: Barkod, Dolap & Tarif',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.amoledDarkTheme,
          themeMode: currentMode,
          home: const KilerceHubScreen(),
        );
      },
    );
  }
}
