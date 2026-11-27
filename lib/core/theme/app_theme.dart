import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  // OLED / AMOLED True Black Dark Colors
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF101412);
  static const Color amoledSurfaceGlass = Color(0xD9101412);
  static const Color amoledCardBorder = Color(0xFF232B27);
  static const Color darkTextPrimary = Color(0xFFF3F6F4);
  static const Color darkTextSecondary = Color(0xFF94A39B);

  // Soft Pastel Mint Light Colors
  static const Color lightBackground = Color(0xFFF2F8F5);
  static const Color lightSurface = Color(0xFFFAFDFA);
  static const Color lightSurfaceGlass = Color(0xD9FAFDFA);
  static const Color lightCardBorder = Color(0xFFD7E7DF);
  static const Color lightTextPrimary = Color(0xFF1D2C26);
  static const Color lightTextSecondary = Color(0xFF5D736A);

  // Softened Brand Accent Colors
  static const Color primaryEmerald = Color(0xFF3FA080);
  static const Color primaryMint = Color(0xFF58B09C);
  static const Color cautionGold = Color(0xFFD89758);
  static const Color dangerRed = Color(0xFFD86C6C);
  static const Color toxicPurple = Color(0xFF9680CF);

  // Soft Pastel Container Tints — Light
  static const Color pastelSageLight = Color(0xFFDDF0E7);
  static const Color pastelPeachLight = Color(0xFFFCF0E3);
  static const Color pastelBlushLight = Color(0xFFFBE7E7);
  static const Color pastelLavenderLight = Color(0xFFEEEAF9);
  static const Color pastelSkyLight = Color(0xFFE2F1F7);

  // Soft Pastel Container Tints — Dark (Tuned for #000000 OLED)
  static const Color pastelSageDark = Color(0xFF11221B);
  static const Color pastelPeachDark = Color(0xFF241B12);
  static const Color pastelBlushDark = Color(0xFF261518);
  static const Color pastelLavenderDark = Color(0xFF1B1829);
  static const Color pastelSkyDark = Color(0xFF121F26);

  // Adaptive Pastel Ink Accents — Light & Dark
  static const Color accentSageLight = Color(0xFF2E8B6E);
  static const Color accentSageDark = Color(0xFF7CE0B6);
  static const Color accentMintLight = Color(0xFF3E9484);
  static const Color accentMintDark = Color(0xFF88D4C5);
  static const Color accentWarmLight = Color(0xFFC27B3A);
  static const Color accentWarmDark = Color(0xFFF0B982);
  static const Color accentDangerLight = Color(0xFFC75B5B);
  static const Color accentDangerDark = Color(0xFFF09292);
  static const Color accentLavenderLight = Color(0xFF7560B3);
  static const Color accentLavenderDark = Color(0xFFC0B0EC);
  static const Color accentSkyLight = Color(0xFF43829C);
  static const Color accentSkyDark = Color(0xFF8ECAE0);

  // Legacy Compatibility Fallbacks
  static const Color background = amoledBackground;
  static const Color backgroundDark = amoledBackground;
  static const Color surface = amoledSurface;
  static const Color surfaceDark = amoledSurface;
  static const Color surfaceGlass = amoledSurfaceGlass;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextSecondary;
  static const Color cardBorder = amoledCardBorder;
}

class AppTheme {
  /// Deep Botanical Slate Dark Theme (Soft Pastel Nocturnal)
  static ThemeData get amoledDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.amoledBackground,
      primaryColor: AppColors.accentSageDark,
      cardColor: AppColors.amoledSurface,
      dividerColor: AppColors.amoledCardBorder,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentSageDark,
        onPrimary: Color(0xFF071A13),
        secondary: AppColors.accentMintDark,
        onSecondary: Color(0xFF071A13),
        surface: AppColors.amoledSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerLow: Color(0xFF0A0D0B),
        surfaceContainerHighest: Color(0xFF19201D),
        outlineVariant: AppColors.amoledCardBorder,
        error: AppColors.accentDangerDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.amoledBackground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.amoledCardBorder,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.amoledSurface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 14,
        ),
      ),
      useMaterial3: true,
    );
  }

  /// Warm Oat & Botanical Pastel Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.accentSageLight,
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightCardBorder,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentSageLight,
        onPrimary: Colors.white,
        secondary: AppColors.accentMintLight,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerLow: Color(0xFFEBF4F0),
        surfaceContainerHighest: Color(0xFFE6F1EC),
        outlineVariant: AppColors.lightCardBorder,
        error: AppColors.accentDangerLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightCardBorder,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 14,
        ),
      ),
      useMaterial3: true,
    );
  }
}

extension ThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get surfaceColor => Theme.of(this).cardColor;
  Color get glassSurfaceColor =>
      isDarkMode ? AppColors.amoledSurfaceGlass : AppColors.lightSurfaceGlass;
  Color get subtleSurfaceColor =>
      isDarkMode ? const Color(0xFF19201D) : const Color(0xFFE6F1EC);
  Color get cardBorderColor =>
      isDarkMode ? AppColors.amoledCardBorder : AppColors.lightCardBorder;
  Color get borderColor => cardBorderColor;
  Color get textPrimaryColor =>
      isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondaryColor =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  // Soft Pastel Tints
  Color get pastelSageTint =>
      isDarkMode ? AppColors.pastelSageDark : AppColors.pastelSageLight;
  Color get pastelPeachTint =>
      isDarkMode ? AppColors.pastelPeachDark : AppColors.pastelPeachLight;
  Color get pastelBlushTint =>
      isDarkMode ? AppColors.pastelBlushDark : AppColors.pastelBlushLight;
  Color get pastelLavenderTint =>
      isDarkMode ? AppColors.pastelLavenderDark : AppColors.pastelLavenderLight;
  Color get pastelSkyTint =>
      isDarkMode ? AppColors.pastelSkyDark : AppColors.pastelSkyLight;

  // Adaptive Pastel Accents
  Color get accentPrimary =>
      isDarkMode ? AppColors.accentSageDark : AppColors.accentSageLight;
  Color get accentSecondary =>
      isDarkMode ? AppColors.accentMintDark : AppColors.accentMintLight;
  Color get accentWarm =>
      isDarkMode ? AppColors.accentWarmDark : AppColors.accentWarmLight;
  Color get accentDanger =>
      isDarkMode ? AppColors.accentDangerDark : AppColors.accentDangerLight;
  Color get accentLavender =>
      isDarkMode ? AppColors.accentLavenderDark : AppColors.accentLavenderLight;
  Color get accentSky =>
      isDarkMode ? AppColors.accentSkyDark : AppColors.accentSkyLight;
  Color get onAccentPrimary =>
      isDarkMode ? const Color(0xFF071A13) : Colors.white;
}

/// Unified "Bio-Zen Minimalist" Design System Widgets
class BioMinimalUi {
  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? fillColor,
    Color? accentBorder,
    double radius = 20,
  }) {
    return BoxDecoration(
      color: fillColor ?? context.surfaceColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentBorder ?? context.cardBorderColor,
        width: 1.0,
      ),
    );
  }

  static Widget sectionHeader(
    BuildContext context, {
    required String overline,
    required String title,
    Color? overlineColor,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline.toUpperCase(),
                style: TextStyle(
                  color: overlineColor ?? context.accentPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class ThemeController extends ValueNotifier<ThemeMode> {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal() : super(ThemeMode.system);

  static const String _prefKey = 'app_theme_mode_enum';

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModeStr = prefs.getString(_prefKey) ?? 'system';
    switch (savedModeStr) {
      case 'light':
        value = ThemeMode.light;
        break;
      case 'dark':
        value = ThemeMode.dark;
        break;
      case 'system':
      default:
        value = ThemeMode.system;
        break;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }
}
