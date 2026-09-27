import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  static const String _prefKeySelected = 'SelectedLanguage';
  static const String _prefKeyAppLang = 'AppLanguage';

  LocaleNotifier() : super(const Locale('tr')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKeySelected) ?? prefs.getString(_prefKeyAppLang);

      if (savedCode != null && (savedCode == 'tr' || savedCode == 'en')) {
        state = Locale(savedCode);
      } else {
        // Check system locale
        final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (platformLocale.languageCode == 'en') {
          state = const Locale('en');
        } else {
          state = const Locale('tr');
        }
      }
    } catch (_) {
      state = const Locale('tr');
    }
  }

  Future<void> setLanguageCode(String languageCode) async {
    if (languageCode != 'tr' && languageCode != 'en') return;
    state = Locale(languageCode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySelected, languageCode);
      await prefs.setString(_prefKeyAppLang, languageCode);
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    await setLanguageCode(locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
