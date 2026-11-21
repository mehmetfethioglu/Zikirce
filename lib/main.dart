import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/hasibu_database.dart';
import 'features/pdks/domain/pdks_models.dart';
import 'features/pdks/presentation/providers/pdks_providers.dart';
import 'features/pdks/presentation/screens/hasibu_shell_screen.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HasibuDatabase db;
  try {
    db = await HasibuDatabase.openDefault().timeout(
      const Duration(milliseconds: 3500),
    );
  } catch (_) {
    db = HasibuDatabase.inMemory();
  }

  runApp(
    ProviderScope(
      overrides: [
        hasibuDatabaseProvider.overrideWithValue(db),
      ],
      child: const HasibuApp(),
    ),
  );
}

class HasibuApp extends ConsumerWidget {
  const HasibuApp({super.key});

  ThemeMode _toFlutterThemeMode(HasibuThemeMode mode) {
    switch (mode) {
      case HasibuThemeMode.light:
        return ThemeMode.light;
      case HasibuThemeMode.dark:
        return ThemeMode.dark;
      case HasibuThemeMode.system:
        return ThemeMode.system;
    }
  }

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F172A),
        primary: const Color(0xFF0F172A),
        secondary: const Color(0xFF0284C7),
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE0F2FE),
        height: 64,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF09090B),
      dividerColor: const Color(0xFF1F1F23),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF10B981),
        primary: const Color(0xFF38BDF8),
        secondary: const Color(0xFF10B981),
        surface: const Color(0xFF09090B),
        brightness: Brightness.dark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF09090B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF000000),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF18181B),
        height: 60,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF111114),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF242429)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF242429)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(
      pdksDashboardProvider.select((s) => s.activeThemeMode),
    );

    return MaterialApp(
      title: 'Hasibu • Personel & PDKS Yönetimi',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      themeMode: _toFlutterThemeMode(activeTheme),
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const HasibuShellScreen(),
      onGenerateRoute: HasibuRouter.generateRoute,
    );
  }
}
