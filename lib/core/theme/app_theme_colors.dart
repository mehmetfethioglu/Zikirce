import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color pageBackground;
  final Color headerBackground;
  final Color headerGradientEnd;
  final Color cardBackground;
  final Color cardBackgroundAlt;
  final Color primaryText;
  final Color secondaryText;
  final Color secondaryTextAlt;
  final Color tertiaryText;
  final Color accent;
  final Color accentLight;
  final Color accentText;
  final Color borderStroke;
  final Color streakBg;
  final Color dailyBg;
  final Color weeklyBg;
  final Color totalBg;
  final Color hadisBg;
  final Color bottomSheetBg;
  final Color zikirArabicColor;
  final Color counterButtonColor;
  final Color counterProgressColor;
  final Color counterValueColor;
  final Color activeNavIconColor;
  final Color inactiveNavIconColor;
  final Color statusBarColor;
  final Brightness statusBrightness;

  const AppThemeColors({
    required this.pageBackground,
    required this.headerBackground,
    required this.headerGradientEnd,
    required this.cardBackground,
    required this.cardBackgroundAlt,
    required this.primaryText,
    required this.secondaryText,
    required this.secondaryTextAlt,
    required this.tertiaryText,
    required this.accent,
    required this.accentLight,
    required this.accentText,
    required this.borderStroke,
    required this.streakBg,
    required this.dailyBg,
    required this.weeklyBg,
    required this.totalBg,
    required this.hadisBg,
    required this.bottomSheetBg,
    required this.zikirArabicColor,
    required this.counterButtonColor,
    required this.counterProgressColor,
    required this.counterValueColor,
    required this.activeNavIconColor,
    required this.inactiveNavIconColor,
    required this.statusBarColor,
    required this.statusBrightness,
  });

  static AppThemeColors of(BuildContext context) {
    return Theme.of(context).extension<AppThemeColors>() ?? greenLight;
  }

  // -------------------------------------------------------------
  // 1. AÇIK YEŞİL (Zümrüt Yeşil - Green Light)
  // -------------------------------------------------------------
  static const greenLight = AppThemeColors(
    pageBackground: Color(0xFFECF3F0),
    headerBackground: Color(0xFFE0EBE7),
    headerGradientEnd: Color(0xFFD0DFDA),
    cardBackground: Color(0xFFFFFFFF),
    cardBackgroundAlt: Color(0xFFF4F8F6),
    primaryText: Color(0xFF1E2B27),
    secondaryText: Color(0xFF3B7E6F),
    secondaryTextAlt: Color(0xFF506861),
    tertiaryText: Color(0xFF809A93),
    accent: Color(0xFF236B56),
    accentLight: Color(0xFFE0EBE7),
    accentText: Color(0xFF236B56),
    borderStroke: Color(0xFFD8E5E1),
    streakBg: Color(0xFFFFF0F0),
    dailyBg: Color(0xFFFFF8E1),
    weeklyBg: Color(0xFFE8F5E9),
    totalBg: Color(0xFFE0F2FE),
    hadisBg: Color(0xFFFFF8E1),
    bottomSheetBg: Color(0xFFFFFFFF),
    zikirArabicColor: Color(0xFF236B56),
    counterButtonColor: Color(0xFFE0EBE7),
    counterProgressColor: Color(0xFF236B56),
    counterValueColor: Color(0xFF1E2B27),
    activeNavIconColor: Color(0xFFFFFFFF),
    inactiveNavIconColor: Color(0xFF555555),
    statusBarColor: Color(0xFFE0EBE7),
    statusBrightness: Brightness.dark,
  );

  // -------------------------------------------------------------
  // 2. AÇIK KREM (Krem & Altın - Cream Light)
  // -------------------------------------------------------------
  static const creamLight = AppThemeColors(
    pageBackground: Color(0xFFFAF4ED),
    headerBackground: Color(0xFFF5E6D3),
    headerGradientEnd: Color(0xFFE8D5C4),
    cardBackground: Color(0xFFFFFFFF),
    cardBackgroundAlt: Color(0xFFFAFAFA),
    primaryText: Color(0xFF4A3728),
    secondaryText: Color(0xFF8B7355),
    secondaryTextAlt: Color(0xFF6B5445),
    tertiaryText: Color(0xFFA89888),
    accent: Color(0xFFD4A574),
    accentLight: Color(0xFFF5E6D3),
    accentText: Color(0xFFB57D15),
    borderStroke: Color(0xFFE8DDD0),
    streakBg: Color(0xFFFFF0F0),
    dailyBg: Color(0xFFFFF8E1),
    weeklyBg: Color(0xFFE8F5E9),
    totalBg: Color(0xFFFFF3E0),
    hadisBg: Color(0xFFFFF8E1),
    bottomSheetBg: Color(0xFFFFFFFF),
    zikirArabicColor: Color(0xFFB57D15),
    counterButtonColor: Color(0xFFF5E6D3),
    counterProgressColor: Color(0xFFD4A574),
    counterValueColor: Color(0xFF4A3728),
    activeNavIconColor: Color(0xFFFFFFFF),
    inactiveNavIconColor: Color(0xFF555555),
    statusBarColor: Color(0xFFF5E6D3),
    statusBrightness: Brightness.dark,
  );

  // -------------------------------------------------------------
  // 3. KOYU (Kahve Gece - Dark)
  // -------------------------------------------------------------
  static const dark = AppThemeColors(
    pageBackground: Color(0xFF1A1512),
    headerBackground: Color(0xFF2A2520),
    headerGradientEnd: Color(0xFF1F1A17),
    cardBackground: Color(0xFF2A2520),
    cardBackgroundAlt: Color(0xFF3A3530),
    primaryText: Color(0xFFE8DDD0),
    secondaryText: Color(0xFFC4A574),
    secondaryTextAlt: Color(0xFFA89888),
    tertiaryText: Color(0xFFA89888),
    accent: Color(0xFFD4A574),
    accentLight: Color(0xFF3A3530),
    accentText: Color(0xFFE8DDD0),
    borderStroke: Color(0xFF4A4540),
    streakBg: Color(0xFF3A2020),
    dailyBg: Color(0xFF3A3010),
    weeklyBg: Color(0xFF1A3020),
    totalBg: Color(0xFF3A3530),
    hadisBg: Color(0xFF2A2520),
    bottomSheetBg: Color(0xFF2A2520),
    zikirArabicColor: Color(0xFFD4A574),
    counterButtonColor: Color(0xFF2A2520),
    counterProgressColor: Color(0xFFD4A574),
    counterValueColor: Color(0xFFE8DDD0),
    activeNavIconColor: Color(0xFFFFFFFF),
    inactiveNavIconColor: Color(0xFF8E8E93),
    statusBarColor: Color(0xFF2A2520),
    statusBrightness: Brightness.light,
  );

  // -------------------------------------------------------------
  // 4. OLED SİYAH (Simsiyah & Altın - Black OLED)
  // -------------------------------------------------------------
  static const oledBlack = AppThemeColors(
    pageBackground: Color(0xFF000000),
    headerBackground: Color(0xFF0D0D0D),
    headerGradientEnd: Color(0xFF050505),
    cardBackground: Color(0xFF121212),
    cardBackgroundAlt: Color(0xFF1C1C1E),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xFFF7D15A),
    secondaryTextAlt: Color(0xFFD4AF37),
    tertiaryText: Color(0xFF888888),
    accent: Color(0xFFFAD26B),
    accentLight: Color(0xFF1F1F1F),
    accentText: Color(0xFFF7D15A),
    borderStroke: Color(0xFF2C2C2E),
    streakBg: Color(0xFF1A0A0A),
    dailyBg: Color(0xFF1A1505),
    weeklyBg: Color(0xFF0A1A10),
    totalBg: Color(0xFF1F1F1F),
    hadisBg: Color(0xFF121212),
    bottomSheetBg: Color(0xFF0D0D0D),
    zikirArabicColor: Color(0xFFF7D15A),
    counterButtonColor: Color(0xFF000000),
    counterProgressColor: Color(0xFFFAD26B),
    counterValueColor: Color(0xFFFFFFFF),
    activeNavIconColor: Color(0xFFFFFFFF),
    inactiveNavIconColor: Color(0xFF8E8E93),
    statusBarColor: Color(0xFF000000),
    statusBrightness: Brightness.light,
  );

  // -------------------------------------------------------------
  // 5. YÜKSEK KONTRAST (Siyah & Saf Sarı - High Contrast)
  // -------------------------------------------------------------
  static const highContrast = AppThemeColors(
    pageBackground: Color(0xFF000000),
    headerBackground: Color(0xFF000000),
    headerGradientEnd: Color(0xFF000000),
    cardBackground: Color(0xFF000000),
    cardBackgroundAlt: Color(0xFF111111),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xFFFFFF00),
    secondaryTextAlt: Color(0xFFFFFF00),
    tertiaryText: Color(0xFFFFFFFF),
    accent: Color(0xFFFFFF00),
    accentLight: Color(0xFF222222),
    accentText: Color(0xFFFFFF00),
    borderStroke: Color(0xFFFFFFFF),
    streakBg: Color(0xFF000000),
    dailyBg: Color(0xFF000000),
    weeklyBg: Color(0xFF000000),
    totalBg: Color(0xFF000000),
    hadisBg: Color(0xFF000000),
    bottomSheetBg: Color(0xFF000000),
    zikirArabicColor: Color(0xFFFFFF00),
    counterButtonColor: Color(0xFF000000),
    counterProgressColor: Color(0xFFFFFF00),
    counterValueColor: Color(0xFFFFFFFF),
    activeNavIconColor: Color(0xFF000000),
    inactiveNavIconColor: Color(0xFFFFFF00),
    statusBarColor: Color(0xFF000000),
    statusBrightness: Brightness.light,
  );

  @override
  AppThemeColors copyWith({
    Color? pageBackground,
    Color? headerBackground,
    Color? headerGradientEnd,
    Color? cardBackground,
    Color? cardBackgroundAlt,
    Color? primaryText,
    Color? secondaryText,
    Color? secondaryTextAlt,
    Color? tertiaryText,
    Color? accent,
    Color? accentLight,
    Color? accentText,
    Color? borderStroke,
    Color? streakBg,
    Color? dailyBg,
    Color? weeklyBg,
    Color? totalBg,
    Color? hadisBg,
    Color? bottomSheetBg,
    Color? zikirArabicColor,
    Color? counterButtonColor,
    Color? counterProgressColor,
    Color? counterValueColor,
    Color? activeNavIconColor,
    Color? inactiveNavIconColor,
    Color? statusBarColor,
    Brightness? statusBrightness,
  }) {
    return AppThemeColors(
      pageBackground: pageBackground ?? this.pageBackground,
      headerBackground: headerBackground ?? this.headerBackground,
      headerGradientEnd: headerGradientEnd ?? this.headerGradientEnd,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBackgroundAlt: cardBackgroundAlt ?? this.cardBackgroundAlt,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      secondaryTextAlt: secondaryTextAlt ?? this.secondaryTextAlt,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentText: accentText ?? this.accentText,
      borderStroke: borderStroke ?? this.borderStroke,
      streakBg: streakBg ?? this.streakBg,
      dailyBg: dailyBg ?? this.dailyBg,
      weeklyBg: weeklyBg ?? this.weeklyBg,
      totalBg: totalBg ?? this.totalBg,
      hadisBg: hadisBg ?? this.hadisBg,
      bottomSheetBg: bottomSheetBg ?? this.bottomSheetBg,
      zikirArabicColor: zikirArabicColor ?? this.zikirArabicColor,
      counterButtonColor: counterButtonColor ?? this.counterButtonColor,
      counterProgressColor: counterProgressColor ?? this.counterProgressColor,
      counterValueColor: counterValueColor ?? this.counterValueColor,
      activeNavIconColor: activeNavIconColor ?? this.activeNavIconColor,
      inactiveNavIconColor: inactiveNavIconColor ?? this.inactiveNavIconColor,
      statusBarColor: statusBarColor ?? this.statusBarColor,
      statusBrightness: statusBrightness ?? this.statusBrightness,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      headerBackground: Color.lerp(headerBackground, other.headerBackground, t)!,
      headerGradientEnd: Color.lerp(headerGradientEnd, other.headerGradientEnd, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBackgroundAlt: Color.lerp(cardBackgroundAlt, other.cardBackgroundAlt, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      secondaryTextAlt: Color.lerp(secondaryTextAlt, other.secondaryTextAlt, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      borderStroke: Color.lerp(borderStroke, other.borderStroke, t)!,
      streakBg: Color.lerp(streakBg, other.streakBg, t)!,
      dailyBg: Color.lerp(dailyBg, other.dailyBg, t)!,
      weeklyBg: Color.lerp(weeklyBg, other.weeklyBg, t)!,
      totalBg: Color.lerp(totalBg, other.totalBg, t)!,
      hadisBg: Color.lerp(hadisBg, other.hadisBg, t)!,
      bottomSheetBg: Color.lerp(bottomSheetBg, other.bottomSheetBg, t)!,
      zikirArabicColor: Color.lerp(zikirArabicColor, other.zikirArabicColor, t)!,
      counterButtonColor: Color.lerp(counterButtonColor, other.counterButtonColor, t)!,
      counterProgressColor: Color.lerp(counterProgressColor, other.counterProgressColor, t)!,
      counterValueColor: Color.lerp(counterValueColor, other.counterValueColor, t)!,
      activeNavIconColor: Color.lerp(activeNavIconColor, other.activeNavIconColor, t)!,
      inactiveNavIconColor: Color.lerp(inactiveNavIconColor, other.inactiveNavIconColor, t)!,
      statusBarColor: Color.lerp(statusBarColor, other.statusBarColor, t)!,
      statusBrightness: t < 0.5 ? statusBrightness : other.statusBrightness,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get colors => AppThemeColors.of(this);
}
