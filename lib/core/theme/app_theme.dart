import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  // OLED / AMOLED True Black Dark Colors
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF121212);
  static const Color amoledSurfaceGlass = Color(0xCC121212);
  static const Color amoledCardBorder = Color(0xFF27272A);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);

  // Modern Light Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xCCFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Shared Brand Accent Colors
  static const Color primaryEmerald = Color(0xFF10B981);
  static const Color primaryMint = Color(0xFF059669);
  static const Color cautionGold = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color toxicPurple = Color(0xFF7C3AED);

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
  /// OLED / AMOLED True Black Dark Theme
  static ThemeData get amoledDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.amoledBackground,
      primaryColor: AppColors.primaryEmerald,
      cardColor: AppColors.amoledSurface,
      dividerColor: AppColors.amoledCardBorder,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryEmerald,
        secondary: AppColors.primaryMint,
        surface: AppColors.amoledSurface,
        error: AppColors.dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.amoledBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
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

  /// Modern High-Aesthetic Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.primaryEmerald,
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightCardBorder,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryEmerald,
        secondary: AppColors.primaryMint,
        surface: AppColors.lightSurface,
        error: AppColors.dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
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
  Color get glassSurfaceColor => isDarkMode ? AppColors.amoledSurfaceGlass : AppColors.lightSurfaceGlass;
  Color get cardBorderColor => isDarkMode ? AppColors.amoledCardBorder : AppColors.lightCardBorder;
  Color get borderColor => cardBorderColor;
  Color get textPrimaryColor => isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondaryColor => isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
