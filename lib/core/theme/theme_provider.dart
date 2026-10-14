import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class ReaderThemeState {
  final TahrirThemePreset preset;
  final ThemeMode themeMode;
  final TahrirFontFamily fontFamily;
  final double fontSize;
  final double lineHeight;
  final double sideMargin;
  final bool bionicReadingEnabled;

  const ReaderThemeState({
    required this.preset,
    required this.themeMode,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.sideMargin,
    required this.bionicReadingEnabled,
  });

  ReaderThemeState copyWith({
    TahrirThemePreset? preset,
    ThemeMode? themeMode,
    TahrirFontFamily? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? sideMargin,
    bool? bionicReadingEnabled,
  }) {
    return ReaderThemeState(
      preset: preset ?? this.preset,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      sideMargin: sideMargin ?? this.sideMargin,
      bionicReadingEnabled: bionicReadingEnabled ?? this.bionicReadingEnabled,
    );
  }
}

class ReaderThemeNotifier extends StateNotifier<ReaderThemeState> {
  ReaderThemeNotifier()
      : super(const ReaderThemeState(
          preset: TahrirThemePreset.parchment,
          themeMode: ThemeMode.system,
          fontFamily: TahrirFontFamily.literata,
          fontSize: AppConstants.defaultFontSize,
          lineHeight: AppConstants.defaultLineHeight,
          sideMargin: AppConstants.defaultSideMargin,
          bionicReadingEnabled: false,
        )) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetIndex = prefs.getInt(AppConstants.keyActiveTheme) ?? 0;
      final themeModeIndex = prefs.getInt(AppConstants.keyThemeMode) ?? 0;
      final fontIndex = prefs.getInt(AppConstants.keyActiveFont) ?? 0;
      final fontSize = prefs.getDouble(AppConstants.keyFontSize) ?? AppConstants.defaultFontSize;
      final lineHeight = prefs.getDouble(AppConstants.keyLineHeight) ?? AppConstants.defaultLineHeight;
      final sideMargin = prefs.getDouble(AppConstants.keySidePadding) ?? AppConstants.defaultSideMargin;
      final bionic = prefs.getBool(AppConstants.keyBionicReading) ?? false;

      state = state.copyWith(
        preset: TahrirThemePreset.values.elementAtOrNull(presetIndex) ?? TahrirThemePreset.parchment,
        themeMode: ThemeMode.values.elementAtOrNull(themeModeIndex) ?? ThemeMode.system,
        fontFamily: TahrirFontFamily.values.elementAtOrNull(fontIndex) ?? TahrirFontFamily.literata,
        fontSize: fontSize,
        lineHeight: lineHeight,
        sideMargin: sideMargin,
        bionicReadingEnabled: bionic,
      );
    } catch (_) {}
  }

  Future<void> setPreset(TahrirThemePreset preset) async {
    state = state.copyWith(preset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyActiveTheme, preset.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyThemeMode, mode.index);
  }

  Future<void> setFontFamily(TahrirFontFamily font) async {
    state = state.copyWith(fontFamily: font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyActiveFont, font.index);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(12.0, 32.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyFontSize, state.fontSize);
  }

  Future<void> setLineHeight(double height) async {
    state = state.copyWith(lineHeight: height.clamp(1.2, 2.4));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyLineHeight, state.lineHeight);
  }

  Future<void> setSideMargin(double margin) async {
    state = state.copyWith(sideMargin: margin.clamp(8.0, 48.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keySidePadding, state.sideMargin);
  }

  Future<void> toggleBionicReading() async {
    final next = !state.bionicReadingEnabled;
    state = state.copyWith(bionicReadingEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyBionicReading, next);
  }
}

final readerThemeProvider = StateNotifierProvider<ReaderThemeNotifier, ReaderThemeState>((ref) {
  return ReaderThemeNotifier();
});
