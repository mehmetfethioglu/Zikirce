import 'package:flutter/material.dart';

class AppColors {
  // Emerald Heritage (Primary)
  static const Color emerald900 = Color(0xFF07271E);
  static const Color emerald800 = Color(0xFF0F3B2E);
  static const Color emerald700 = Color(0xFF165241);
  static const Color emerald600 = Color(0xFF1E6B56);
  static const Color emerald500 = Color(0xFF2A876E);
  static const Color emerald400 = Color(0xFF3EA388);
  static const Color emerald100 = Color(0xFFD4EBE4);
  static const Color emerald50 = Color(0xFFEDF7F4);

  // Sovereign Gold (Accent)
  static const Color gold900 = Color(0xFF5A3C08);
  static const Color gold800 = Color(0xFF83590E);
  static const Color gold700 = Color(0xFFB57D15);
  static const Color gold600 = Color(0xFFD99B1D);
  static const Color gold500 = Color(0xFFF3B728);
  static const Color gold400 = Color(0xFFFFCC4D);
  static const Color gold300 = Color(0xFFFFDE82);
  static const Color gold100 = Color(0xFFFFF4D4);

  // Midnight Obsidian (Dark Backgrounds)
  static const Color darkBackground = Color(0xFF090D10);
  static const Color darkSurface = Color(0xFF11171D);
  static const Color darkCard = Color(0xFF18212A);
  static const Color darkBorder = Color(0xFF24313E);

  // Parchment & Light Mode
  static const Color lightBackground = Color(0xFFF7F6F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0EFEA);
  static const Color lightBorder = Color(0xFFE2DFD6);
  static const Color mushafPaper = Color(0xFFFFFDF8);

  // Functional & Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Glows & Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFDF7A), Color(0xFFD49B27), Color(0xFF9E6E12)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF1E6B56), Color(0xFF0F3B2E), Color(0xFF07271E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardDarkGradient = LinearGradient(
    colors: [Color(0xFF1A242E), Color(0xFF121920)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFFF4500), Color(0xFFFF8C00), Color(0xFFFFD700)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
}
