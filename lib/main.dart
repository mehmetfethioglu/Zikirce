import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/scanner/presentation/scanner_screen.dart';
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

  // Load saved theme preference, initialize SQLite database & user profile
  await ThemeController.instance.loadSavedTheme();
  await DatabaseHelper().database;
  await UserProfileService.instance.loadProfile();
  GoogleAuthSyncService.instance.init();

  runApp(const OrganicScoreApp());
}

class OrganicScoreApp extends StatelessWidget {
  const OrganicScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'OrganicScore',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.amoledDarkTheme,
          themeMode: currentMode,
          home: const ScannerScreen(),
        );
      },
    );
  }
}
