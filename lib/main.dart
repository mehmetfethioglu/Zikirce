import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/cuedeck_providers.dart';
import 'screens/cuedeck_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CueDeckApp(),
    ),
  );
}

class CueDeckApp extends ConsumerWidget {
  const CueDeckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));

    return MaterialApp(
      title: 'CueDeck: Akıllı TV Kumandası & İzleme Planlayıcı',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFECEEF2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1C2026),
          brightness: Brightness.light,
          primary: const Color(0xFF1C2026),
          secondary: const Color(0xFFE2A84B),
          surface: const Color(0xFFF7F8FA),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2A84B),
          brightness: Brightness.dark,
          primary: const Color(0xFFE2A84B),
          secondary: const Color(0xFF7C4DFF),
          surface: const Color(0xFF000000),
        ),
      ),
      home: const CueDeckHomeScreen(),
    );
  }
}
