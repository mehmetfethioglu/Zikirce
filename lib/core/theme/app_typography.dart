import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TahrirFontFamily {
  literata,
  lora,
  merriweather,
  inter,
  jetbrainsMono,
  amiri,
}

extension TahrirFontFamilyX on TahrirFontFamily {
  String get displayName => switch (this) {
        TahrirFontFamily.literata => 'Literata (Edebi)',
        TahrirFontFamily.lora => 'Lora (Zarif)',
        TahrirFontFamily.merriweather => 'Merriweather (Klasik)',
        TahrirFontFamily.inter => 'Inter (Modern)',
        TahrirFontFamily.jetbrainsMono => 'JetBrains (Teknik)',
        TahrirFontFamily.amiri => 'Amiri (Arapça & Hat)',
      };

  TextStyle getTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return switch (this) {
      TahrirFontFamily.literata => GoogleFonts.literata(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
      TahrirFontFamily.lora => GoogleFonts.lora(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
      TahrirFontFamily.merriweather => GoogleFonts.merriweather(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
      TahrirFontFamily.inter => GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
      TahrirFontFamily.jetbrainsMono => GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        ),
      TahrirFontFamily.amiri => GoogleFonts.amiri(
          fontSize: fontSize != null ? fontSize + 2 : null,
          fontWeight: fontWeight,
          color: color,
          height: height != null ? height * 1.25 : 1.9,
          letterSpacing: letterSpacing,
        ),
    };
  }
}
