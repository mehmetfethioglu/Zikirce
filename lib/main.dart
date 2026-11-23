import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/bio_rpg/domain/bio_rpg_service.dart';
import 'features/kiler/domain/kiler_service.dart';
import 'features/kiler/presentation/kilerce_hub_screen.dart';
import 'features/profile/domain/user_profile_service.dart';
import 'features/profile/domain/google_auth_sync_service.dart';

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
  await KilerService.instance.loadAll();
  await UserProfileService.instance.loadProfile();
  await BioRpgService.instance.loadState();
  GoogleAuthSyncService.instance.init();

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
          title: 'Kilerce: Barkod, Dolap & Tarif',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.amoledDarkTheme,
          themeMode: currentMode,
          home: const KilerceHubScreen(),
        );
      },
    );
  }
}
