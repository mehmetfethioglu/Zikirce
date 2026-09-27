import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Quranic & Arabic
  static TextStyle quranArabic({
    String fontFamily = 'AmasyaAbay',
    double fontSize = 24,
    Color color = AppColors.gold400,
    FontWeight fontWeight = FontWeight.normal,
    double height = 2.25,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle mushafText({
    double fontSize = 22,
    Color color = AppColors.gold300,
    FontWeight fontWeight = FontWeight.normal,
    double height = 2.0,
  }) {
    return TextStyle(
      fontFamily: 'mushaf',
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
    );
  }

  // Modern Headings
  static TextStyle headingLarge({
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.outfit(
      fontSize: 28,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
    );
  }

  static TextStyle headingMedium({
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextStyle headingSmall({
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.outfit(
      fontSize: 18,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Body & Captions
  static TextStyle bodyLarge({
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium({
    Color color = const Color(0xFFC5D1DE),
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: fontWeight,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle bodySmall({
    Color color = const Color(0xFF8A9BAE),
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle counterNumber({
    double fontSize = 56,
    Color color = AppColors.gold400,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -1.0,
    );
  }
}
