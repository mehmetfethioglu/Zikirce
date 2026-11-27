import 'package:flutter/material.dart';

import '../../domain/pdks_models.dart';

/// Minimalist Tema Paleti (Açık / Koyu / Sistem uyumlu — Katman 4 Atomik UI).
class HasibuPalette {
  final bool isDark;

  const HasibuPalette._(this.isDark);

  factory HasibuPalette.of(BuildContext context) {
    return HasibuPalette._(Theme.of(context).brightness == Brightness.dark);
  }

  // Koyu temada OLED ekranlar için %100 gerçek simsiyah (#000000) zemin
  Color get bg => isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
  Color get card => isDark ? const Color(0xFF09090B) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF121216) : const Color(0xFFF8FAFC);
  Color get chip => isDark ? const Color(0xFF18181D) : const Color(0xFFF1F5F9);
  Color get border =>
      isDark ? const Color(0xFF232329) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
  Color get activeBg =>
      isDark ? const Color(0xFF10B981) : const Color(0xFF0F172A);
  Color get activeFg => Colors.white;
}

Color attendanceStateColor(DailyAttendanceState state) {
  switch (state) {
    case DailyAttendanceState.present:
      return const Color(0xFF059669);
    case DailyAttendanceState.late:
      return const Color(0xFFD97706);
    case DailyAttendanceState.onLeave:
      return const Color(0xFF0284C7);
    case DailyAttendanceState.sickReport:
      return const Color(0xFF7C3AED);
    case DailyAttendanceState.publicHoliday:
      return const Color(0xFF0EA5E9);
    case DailyAttendanceState.weeklyOff:
      return const Color(0xFF6366F1);
    case DailyAttendanceState.absent:
      return const Color(0xFFDC2626);
    case DailyAttendanceState.terminated:
      return const Color(0xFF64748B);
    case DailyAttendanceState.notYetHired:
      return const Color(0xFF94A3B8);
  }
}
