import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_colors.dart';
import '../providers/database_provider.dart';

class AppThemeKeys {
  static const String system = 'system';
  static const String greenLight = 'greenLight';
  static const String creamLight = 'creamLight';
  static const String dark = 'dark';
  static const String oledBlack = 'oledBlack';
  static const String highContrast = 'highContrast';

  static const List<String> all = [
    system,
    greenLight,
    creamLight,
    dark,
    oledBlack,
    highContrast,
  ];

  /// Safely normalizes any theme value (int, string int, legacy MAUI names, Turkish names, or null)
  /// into a deterministic AppThemeKeys constant.
  static String normalize(dynamic value) {
    if (value == null) return system;

    if (value is int) {
      switch (value) {
        case 0:
          return system;
        case 1:
          return greenLight;
        case 2:
          return creamLight;
        case 3:
          return dark;
        case 4:
          return oledBlack;
        case 5:
          return highContrast;
        default:
          return system;
      }
    }

    final str = value.toString().trim();
    if (str.isEmpty) return system;

    if (all.contains(str)) return str;

    switch (str) {
      case '0':
        return system;
      case '1':
        return greenLight;
      case '2':
        return creamLight;
      case '3':
        return dark;
      case '4':
        return oledBlack;
      case '5':
        return highContrast;
    }

    final lower = str.toLowerCase();
    switch (lower) {
      case 'system':
      case 'sistem':
        return system;
      case 'greenlight':
      case 'acikyesil':
      case 'açık yeşil':
      case 'light':
      case 'parchmentlight':
        return greenLight;
      case 'creamlight':
      case 'acikkrem':
      case 'açık krem':
      case 'açık':
      case 'acik':
        return creamLight;
      case 'dark':
      case 'koyu':
      case 'midnightgold':
      case 'emeralddark':
        return dark;
      case 'oledblack':
      case 'oled / siyah':
      case 'oled siyah':
      case 'oled':
      case 'siyah':
        return oledBlack;
      case 'highcontrast':
      case 'yüksek kontrast':
      case 'yuksekkontrast':
        return highContrast;
      default:
        return system;
    }
  }

  /// Safely normalizes light subtheme values.
  static String normalizeSubTheme(dynamic value) {
    if (value == null) return greenLight;
    if (value is int) {
      return (value == 1) ? creamLight : greenLight;
    }
    final str = value.toString().trim();
    if (str == '1' || str == creamLight || str.toLowerCase() == 'açık krem' || str.toLowerCase() == 'acikkrem') {
      return creamLight;
    }
    return greenLight;
  }

  /// Converts key to integer index for legacy / backup serialization
  static int toInt(String key) {
    switch (normalize(key)) {
      case system:
        return 0;
      case greenLight:
        return 1;
      case creamLight:
        return 2;
      case dark:
        return 3;
      case oledBlack:
        return 4;
      case highContrast:
        return 5;
      default:
        return 0;
    }
  }

  static int subThemeToInt(String key) {
    return normalizeSubTheme(key) == creamLight ? 1 : 0;
  }

  static String getDisplayName(String key) {
    switch (normalize(key)) {
      case system:
        return 'Sistem';
      case greenLight:
        return 'Açık Yeşil';
      case creamLight:
        return 'Açık Krem';
      case dark:
        return 'Koyu';
      case oledBlack:
        return 'OLED Siyah';
      case highContrast:
        return 'Yüksek Kontrast';
      default:
        return 'Sistem';
    }
  }

  static String getKeyFromDisplayName(String displayName) {
    return normalize(displayName);
  }
}

final initialThemeKeyProvider = Provider<String>((ref) => AppThemeKeys.system);
final initialLightSubThemeProvider = Provider<String>((ref) => AppThemeKeys.greenLight);

final lightSubThemeProvider = StateProvider<String>((ref) {
  final initial = ref.watch(initialLightSubThemeProvider);
  return initial;
});

class ThemeNotifier extends StateNotifier<String> with WidgetsBindingObserver {
  final Ref ref;
  static const String _prefKey = 'AppThemeOption';
  static const String _lightSubThemeKey = 'LightSubThemeOption';

  ThemeNotifier(this.ref, [String? initialTheme]) : super(initialTheme ?? AppThemeKeys.system) {
    WidgetsBinding.instance.addObserver(this);
    _loadSavedTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get lightSubTheme => ref.read(lightSubThemeProvider);

  static Future<String> loadSavedThemeKey([String? customSessionId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = customSessionId;
      final isDefault = sid == null || sid.isEmpty;
      final sfx = isDefault ? '' : '_$sid';

      final rawValue = (sfx.isNotEmpty ? prefs.get('theme_mode$sfx') : null) ??
          (sfx.isNotEmpty ? prefs.get('AppThemeOption_str$sfx') : null) ??
          (sfx.isNotEmpty ? prefs.get('AppThemeOption$sfx') : null) ??
          prefs.get('theme_mode') ??
          prefs.get('AppThemeOption_str') ??
          prefs.get('AppThemeOption') ??
          prefs.get('AppTheme');

      return AppThemeKeys.normalize(rawValue);
    } catch (_) {
      return AppThemeKeys.system;
    }
  }

  static Future<String> loadSavedLightSubTheme([String? customSessionId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = customSessionId;
      final isDefault = sid == null || sid.isEmpty;
      final sfx = isDefault ? '' : '_$sid';

      final rawValue = (sfx.isNotEmpty ? prefs.get('light_sub_theme$sfx') : null) ??
          (sfx.isNotEmpty ? prefs.get('LightSubThemeOption_str$sfx') : null) ??
          (sfx.isNotEmpty ? prefs.get('LightSubThemeOption$sfx') : null) ??
          prefs.get('light_sub_theme') ??
          prefs.get('LightSubThemeOption_str') ??
          prefs.get('LightSubThemeOption');

      return AppThemeKeys.normalizeSubTheme(rawValue);
    } catch (_) {
      return AppThemeKeys.greenLight;
    }
  }

  Future<void> _loadSavedTheme([String? customSessionId]) async {
    try {
      final savedTheme = await loadSavedThemeKey(customSessionId);
      final savedSub = await loadSavedLightSubTheme(customSessionId);

      ref.read(lightSubThemeProvider.notifier).state = savedSub;
      state = savedTheme;
    } catch (_) {}
  }

  Future<void> reloadForSession(String sessionId) async {
    await _loadSavedTheme(sessionId);
  }

  Future<void> setTheme(String themeKey) async {
    final normalized = AppThemeKeys.normalize(themeKey);
    final themeInt = AppThemeKeys.toInt(normalized);
    state = normalized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', normalized);
      await prefs.setString('${_prefKey}_str', normalized);
      await prefs.setInt(_prefKey, themeInt);

      // Sync with Drift DB if user profile exists
      final db = ref.read(databaseProvider);
      final profile = await db.select(db.userProfiles).getSingleOrNull();
      if (profile != null) {
        await (db.update(db.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          profile.copyWith(themeMode: normalized),
        );
      }
    } catch (_) {}
  }

  Future<void> setLightSubTheme(String subThemeKey) async {
    final normalizedSub = AppThemeKeys.normalizeSubTheme(subThemeKey);
    final subInt = AppThemeKeys.subThemeToInt(normalizedSub);
    ref.read(lightSubThemeProvider.notifier).state = normalizedSub;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('light_sub_theme', normalizedSub);
      await prefs.setString('${_lightSubThemeKey}_str', normalizedSub);
      await prefs.setInt(_lightSubThemeKey, subInt);

      if (state == AppThemeKeys.greenLight || state == AppThemeKeys.creamLight) {
        await setTheme(normalizedSub);
      }
    } catch (_) {}
  }

  static AppThemeColors getColorsForKey(String key) {
    switch (key) {
      case AppThemeKeys.greenLight:
        return AppThemeColors.greenLight;
      case AppThemeKeys.creamLight:
        return AppThemeColors.creamLight;
      case AppThemeKeys.dark:
        return AppThemeColors.dark;
      case AppThemeKeys.oledBlack:
        return AppThemeColors.oledBlack;
      case AppThemeKeys.highContrast:
        return AppThemeColors.highContrast;
      default:
        return AppThemeColors.greenLight;
    }
  }

  ThemeMode getThemeMode(String key) {
    switch (key) {
      case AppThemeKeys.system:
        return ThemeMode.system;
      case AppThemeKeys.greenLight:
      case AppThemeKeys.creamLight:
        return ThemeMode.light;
      case AppThemeKeys.dark:
      case AppThemeKeys.oledBlack:
      case AppThemeKeys.highContrast:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeData getLightThemeData([String? lightKey]) {
    final key = lightKey ?? lightSubTheme;
    final colors = (key == AppThemeKeys.creamLight)
        ? AppThemeColors.creamLight
        : AppThemeColors.greenLight;
    return buildThemeData(colors);
  }

  ThemeData getDarkThemeData([String? darkKey]) {
    final key = darkKey ?? state;
    final colors = (key == AppThemeKeys.system || key == AppThemeKeys.greenLight || key == AppThemeKeys.creamLight)
        ? AppThemeColors.dark
        : getColorsForKey(key);
    return buildThemeData(colors);
  }

  AppThemeColors get currentColors {
    if (state == AppThemeKeys.system) {
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness == Brightness.dark) {
        return AppThemeColors.dark;
      } else {
        return lightSubTheme == AppThemeKeys.creamLight
            ? AppThemeColors.creamLight
            : AppThemeColors.greenLight;
      }
    }

    return getColorsForKey(state);
  }

  static ThemeData buildThemeData(AppThemeColors colors) {
    final isDark = colors.statusBrightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.pageBackground,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: colors.accent,
              onPrimary: Colors.black,
              surface: colors.cardBackground,
              onSurface: colors.primaryText,
              outline: colors.borderStroke,
            )
          : ColorScheme.light(
              primary: colors.accent,
              onPrimary: Colors.white,
              surface: colors.cardBackground,
              onSurface: colors.primaryText,
              outline: colors.borderStroke,
            ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.borderStroke, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.primaryText),
        titleTextStyle: TextStyle(
          color: colors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
      ),
      extensions: [colors],
      textTheme: isDark
          ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          : GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    );
  }

  ThemeData get currentThemeData {
    return buildThemeData(currentColors);
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, String>((ref) {
  final initialTheme = ref.watch(initialThemeKeyProvider);
  return ThemeNotifier(ref, initialTheme);
});
