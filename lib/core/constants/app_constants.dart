/// Core constants for Tahrir App
class AppConstants {
  const AppConstants._();

  static const String appName = 'Tahrir';
  static const String appTagline = 'Zarif, Akıcı ve Bilişsel Okuma Ekosistemi';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String keyActiveTheme = 'tahrir_active_theme';
  static const String keyThemeMode = 'tahrir_theme_mode';
  static const String keyActiveFont = 'tahrir_active_font';
  static const String keyFontSize = 'tahrir_font_size';
  static const String keyLineHeight = 'tahrir_line_height';
  static const String keySidePadding = 'tahrir_side_padding';
  static const String keyDailyGoalMinutes = 'tahrir_daily_goal_minutes';
  static const String keyBionicReading = 'tahrir_bionic_reading';
  static const String keyAmbientSound = 'tahrir_ambient_sound';
  static const String keyAmbientVolume = 'tahrir_ambient_volume';

  // Default values
  static const double defaultFontSize = 17.0;
  static const double defaultLineHeight = 1.65;
  static const double defaultSideMargin = 20.0;
  static const int defaultDailyGoalMinutes = 20;
}
