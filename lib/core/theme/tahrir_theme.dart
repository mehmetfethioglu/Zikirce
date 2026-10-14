import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class TahrirTheme {
  const TahrirTheme._();

  static ThemeData getThemeForPreset(TahrirThemePreset preset, {bool isDark = false}) {
    final (bg, surface, text, secondary, accent, border) = switch (preset) {
      TahrirThemePreset.parchment => (
          AppColors.parchmentBg,
          AppColors.parchmentSurface,
          AppColors.parchmentText,
          AppColors.parchmentSecondary,
          AppColors.parchmentAccent,
          AppColors.parchmentBorder,
        ),
      TahrirThemePreset.amoled => (
          AppColors.amoledBg,
          AppColors.amoledSurface,
          AppColors.amoledText,
          AppColors.amoledSecondary,
          AppColors.amoledAccent,
          AppColors.amoledBorder,
        ),
      TahrirThemePreset.sapphire => (
          AppColors.sapphireBg,
          AppColors.sapphireSurface,
          AppColors.sapphireText,
          AppColors.sapphireSecondary,
          AppColors.sapphireAccent,
          AppColors.sapphireBorder,
        ),
      TahrirThemePreset.paperWhite => (
          AppColors.paperBg,
          AppColors.paperSurface,
          AppColors.paperText,
          AppColors.paperSecondary,
          AppColors.paperAccent,
          AppColors.paperBorder,
        ),
      TahrirThemePreset.forest => (
          AppColors.forestBg,
          AppColors.forestSurface,
          AppColors.forestText,
          AppColors.forestSecondary,
          AppColors.forestAccent,
          AppColors.forestBorder,
        ),
    };

    final brightness = (preset == TahrirThemePreset.amoled ||
            preset == TahrirThemePreset.sapphire ||
            preset == TahrirThemePreset.forest ||
            isDark)
        ? Brightness.dark
        : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.literata(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: secondary,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.literata(color: text, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.literata(color: text, fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: GoogleFonts.literata(color: text, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.inter(color: text, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.literata(color: text, fontSize: 17, height: 1.6),
        bodyMedium: GoogleFonts.inter(color: text, fontSize: 14, height: 1.5),
        bodySmall: GoogleFonts.inter(color: secondary, fontSize: 12),
      ),
    );
  }
}
