import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeColors & ThemeNotifier Tests', () {
    late AppDatabase inMemoryDb;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      inMemoryDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('All 5 themes are defined with valid non-null colors matching MAUI palettes', () {
      final greenLight = AppThemeColors.greenLight;
      expect(greenLight.pageBackground, const Color(0xFFECF3F0));
      expect(greenLight.accent, const Color(0xFF236B56));
      expect(greenLight.primaryText, const Color(0xFF1E2B27));

      final creamLight = AppThemeColors.creamLight;
      expect(creamLight.pageBackground, const Color(0xFFFAF4ED));
      expect(creamLight.accent, const Color(0xFFD4A574));
      expect(creamLight.primaryText, const Color(0xFF4A3728));

      final dark = AppThemeColors.dark;
      expect(dark.pageBackground, const Color(0xFF1A1512));
      expect(dark.cardBackground, const Color(0xFF2A2520));
      expect(dark.primaryText, const Color(0xFFE8DDD0));

      final oled = AppThemeColors.oledBlack;
      expect(oled.pageBackground, const Color(0xFF000000));
      expect(oled.secondaryText, const Color(0xFFF7D15A));

      final highContrast = AppThemeColors.highContrast;
      expect(highContrast.pageBackground, const Color(0xFF000000));
      expect(highContrast.accent, const Color(0xFFFFFF00));
      expect(highContrast.borderStroke, const Color(0xFFFFFFFF));
    });

    test('ThemeNotifier handles system mode and reacts to subthemes', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
      );
      final notifier = container.read(themeNotifierProvider.notifier);

      expect(container.read(themeNotifierProvider), AppThemeKeys.system);

      // In System mode with light brightness:
      expect(notifier.currentColors.pageBackground, const Color(0xFFECF3F0));

      // Switch sub-theme to cream:
      await notifier.setLightSubTheme(AppThemeKeys.creamLight);
      expect(notifier.currentColors.pageBackground, const Color(0xFFFAF4ED));

      // Change to OLED Black
      await notifier.setTheme(AppThemeKeys.oledBlack);
      expect(container.read(themeNotifierProvider), AppThemeKeys.oledBlack);
      expect(notifier.currentColors.pageBackground, const Color(0xFF000000));

      // Change to High Contrast
      await notifier.setTheme(AppThemeKeys.highContrast);
      expect(container.read(themeNotifierProvider), AppThemeKeys.highContrast);
      expect(notifier.currentColors.accent, const Color(0xFFFFFF00));

      // Change to Dark
      await notifier.setTheme(AppThemeKeys.dark);
      expect(container.read(themeNotifierProvider), AppThemeKeys.dark);
      expect(notifier.currentColors.pageBackground, const Color(0xFF1A1512));

      // Check theme modes
      expect(notifier.getThemeMode(AppThemeKeys.system), ThemeMode.system);
      expect(notifier.getThemeMode(AppThemeKeys.greenLight), ThemeMode.light);
      expect(notifier.getThemeMode(AppThemeKeys.creamLight), ThemeMode.light);
      expect(notifier.getThemeMode(AppThemeKeys.dark), ThemeMode.dark);
      expect(notifier.getThemeMode(AppThemeKeys.oledBlack), ThemeMode.dark);
      expect(notifier.getThemeMode(AppThemeKeys.highContrast), ThemeMode.dark);

      container.dispose();
    });

    testWidgets('System theme dynamically adapts when platform brightness changes without app restart', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
      );
      final notifier = container.read(themeNotifierProvider.notifier);

      late BuildContext testContext;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final activeThemeKey = ref.watch(themeNotifierProvider);
              final lightSubTheme = ref.watch(lightSubThemeProvider);
              final tNotifier = ref.read(themeNotifierProvider.notifier);

              return MaterialApp(
                theme: tNotifier.getLightThemeData(lightSubTheme),
                darkTheme: tNotifier.getDarkThemeData(activeThemeKey),
                themeMode: tNotifier.getThemeMode(activeThemeKey),
                home: Builder(
                  builder: (ctx) {
                    testContext = ctx;
                    final colors = AppThemeColors.of(ctx);
                    return Scaffold(
                      body: Text(
                        colors.primaryText.toHexString(),
                        key: const Key('theme_color_text'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      // Initially in Light Mode:
      expect(Theme.of(testContext).brightness, Brightness.light);
      expect(AppThemeColors.of(testContext).pageBackground, const Color(0xFFECF3F0));

      // Simulate device switching to Dark Mode while app is open:
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      // Should automatically adapt to Dark Mode without restart:
      expect(Theme.of(testContext).brightness, Brightness.dark);
      expect(AppThemeColors.of(testContext).pageBackground, const Color(0xFF1A1512));

      // Simulate device switching back to Light Mode while app is open:
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();

      // Should automatically adapt to Light Mode:
      expect(Theme.of(testContext).brightness, Brightness.light);
      expect(AppThemeColors.of(testContext).pageBackground, const Color(0xFFECF3F0));

      // Switch light style to cream:
      await notifier.setLightSubTheme(AppThemeKeys.creamLight);
      await tester.pumpAndSettle();
      expect(AppThemeColors.of(testContext).pageBackground, const Color(0xFFFAF4ED));

      container.dispose();
    });

    test('AppThemeKeys.normalize accurately maps all formats (int, string, legacy, turkish)', () {
      expect(AppThemeKeys.normalize(null), AppThemeKeys.system);
      expect(AppThemeKeys.normalize(0), AppThemeKeys.system);
      expect(AppThemeKeys.normalize(1), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize(2), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalize(3), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize(4), AppThemeKeys.oledBlack);
      expect(AppThemeKeys.normalize(5), AppThemeKeys.highContrast);

      expect(AppThemeKeys.normalize('0'), AppThemeKeys.system);
      expect(AppThemeKeys.normalize('1'), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize('2'), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalize('3'), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize('4'), AppThemeKeys.oledBlack);
      expect(AppThemeKeys.normalize('5'), AppThemeKeys.highContrast);

      expect(AppThemeKeys.normalize('system'), AppThemeKeys.system);
      expect(AppThemeKeys.normalize('Sistem'), AppThemeKeys.system);
      expect(AppThemeKeys.normalize('greenLight'), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize('Açık Yeşil'), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize('parchmentLight'), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize('light'), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalize('creamLight'), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalize('Açık Krem'), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalize('Açık'), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalize('dark'), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize('Koyu'), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize('midnightGold'), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize('emeraldDark'), AppThemeKeys.dark);
      expect(AppThemeKeys.normalize('oledBlack'), AppThemeKeys.oledBlack);
      expect(AppThemeKeys.normalize('OLED Siyah'), AppThemeKeys.oledBlack);
      expect(AppThemeKeys.normalize('highContrast'), AppThemeKeys.highContrast);
      expect(AppThemeKeys.normalize('Yüksek Kontrast'), AppThemeKeys.highContrast);

      expect(AppThemeKeys.normalizeSubTheme(null), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalizeSubTheme(0), AppThemeKeys.greenLight);
      expect(AppThemeKeys.normalizeSubTheme(1), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalizeSubTheme('creamLight'), AppThemeKeys.creamLight);
      expect(AppThemeKeys.normalizeSubTheme('Açık Krem'), AppThemeKeys.creamLight);
    });

    test('Theme selection persists accurately across app restarts', () async {
      final container1 = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
      );

      // User sets theme to Light (greenLight)
      await container1.read(themeNotifierProvider.notifier).setTheme(AppThemeKeys.greenLight);
      expect(container1.read(themeNotifierProvider), AppThemeKeys.greenLight);
      container1.dispose();

      // Simulate App Restart: read saved theme
      final savedTheme = await ThemeNotifier.loadSavedThemeKey();
      final savedSub = await ThemeNotifier.loadSavedLightSubTheme();
      expect(savedTheme, AppThemeKeys.greenLight);

      final container2 = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
          initialThemeKeyProvider.overrideWithValue(savedTheme),
          initialLightSubThemeProvider.overrideWithValue(savedSub),
        ],
      );

      // Verify that new container immediately opens in greenLight, NOT system
      expect(container2.read(themeNotifierProvider), AppThemeKeys.greenLight);
      expect(container2.read(themeNotifierProvider.notifier).currentColors.pageBackground, const Color(0xFFECF3F0));

      container2.dispose();
    });

    test('ThemeNotifier gracefully handles integer values in SharedPreferences (e.g. from MAUI/backup)', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate integer stored in SharedPreferences
      await prefs.setInt('AppThemeOption', 1); // 1 -> greenLight
      await prefs.setInt('LightSubThemeOption', 0); // 0 -> greenLight

      final savedTheme = await ThemeNotifier.loadSavedThemeKey();
      expect(savedTheme, AppThemeKeys.greenLight);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
          initialThemeKeyProvider.overrideWithValue(savedTheme),
        ],
      );

      expect(container.read(themeNotifierProvider), AppThemeKeys.greenLight);
      container.dispose();
    });
  });
}

extension on Color {
  String toHexString() => '#${toARGB32().toRadixString(16).padLeft(8, '0')}';
}
