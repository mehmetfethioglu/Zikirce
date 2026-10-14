import 'package:flutter/material.dart';

/// Enum representing the custom aesthetic reading themes in Tahrir
enum TahrirThemePreset {
  parchment,   // Tahrir Parşömeni (Sıcak kemik / el yazması)
  amoled,      // İs Mürekkebi (AMOLED Saf Siyah)
  sapphire,    // Gece Safiri (Derin Lacivert)
  paperWhite,  // Hakiki Kağıt Beyazı (Gündüz)
  forest,      // Zeytin & Orman (Doğal Yeşil)
}

/// Rich curated color palette for Tahrir
class AppColors {
  const AppColors._();

  // Primary brand accents
  static const Color terracotta = Color(0xFFC85A32); // Tahrir kiremiti
  static const Color amberGold = Color(0xFFD99B26);  // Hat sanatı altın varak
  static const Color inkBlack = Color(0xFF141416);   // İs mürekkebi
  static const Color warmBone = Color(0xFFF6EFE2);   // Parşömen kemik

  // 1. Tahrir Parşömeni (Parchment) Palette
  static const Color parchmentBg = Color(0xFFF7EEDB);
  static const Color parchmentSurface = Color(0xFFEFE4CF);
  static const Color parchmentText = Color(0xFF382A1E);
  static const Color parchmentSecondary = Color(0xFF6B5848);
  static const Color parchmentAccent = Color(0xFFA64B2A);
  static const Color parchmentBorder = Color(0xFFDFD1B8);

  // 2. İs Mürekkebi (AMOLED) Palette
  static const Color amoledBg = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF121214);
  static const Color amoledText = Color(0xFFE2E8F0);
  static const Color amoledSecondary = Color(0xFF94A3B8);
  static const Color amoledAccent = Color(0xFFFBBF24);
  static const Color amoledBorder = Color(0xFF27272A);

  // 3. Gece Safiri (Sapphire) Palette
  static const Color sapphireBg = Color(0xFF0F172A);
  static const Color sapphireSurface = Color(0xFF1E293B);
  static const Color sapphireText = Color(0xFFE2E8F0);
  static const Color sapphireSecondary = Color(0xFF94A3B8);
  static const Color sapphireAccent = Color(0xFF38BDF8);
  static const Color sapphireBorder = Color(0xFF334155);

  // 4. Hakiki Kağıt Beyazı (Paper White) Palette
  static const Color paperBg = Color(0xFFFAF9F6);
  static const Color paperSurface = Color(0xFFF1EFEA);
  static const Color paperText = Color(0xFF1E293B);
  static const Color paperSecondary = Color(0xFF64748B);
  static const Color paperAccent = Color(0xFF0D9488);
  static const Color paperBorder = Color(0xFFE2E8F0);

  // 5. Zeytin & Orman (Forest) Palette
  static const Color forestBg = Color(0xFF13201C);
  static const Color forestSurface = Color(0xFF1C2E29);
  static const Color forestText = Color(0xFFD8E2DC);
  static const Color forestSecondary = Color(0xFF8DA399);
  static const Color forestAccent = Color(0xFFA3B18A);
  static const Color forestBorder = Color(0xFF2B443D);

  // Highlight colors
  static const Color highlightYellow = Color(0xFFFFE58F);
  static const Color highlightGreen = Color(0xFFB7EB8F);
  static const Color highlightBlue = Color(0xFF91CAFF);
  static const Color highlightRose = Color(0xFFFFADD2);
  static const Color highlightPurple = Color(0xFFD3ADF7);
}
