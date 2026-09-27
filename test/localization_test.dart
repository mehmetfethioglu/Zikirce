import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/localization/translations/app_strings_tr.dart';
import 'package:zikirce/core/localization/translations/app_strings_en.dart';

void main() {
  group('AppLocalizations & Translations Tests', () {
    test('Verify translation dictionary count and parity', () {
      expect(appStringsTr.length, equals(appStringsEn.length));
      expect(appStringsTr.keys.toSet(), equals(appStringsEn.keys.toSet()));
    });

    test('Turkish AppLocalizations returns Turkish strings', () {
      final l10n = AppLocalizations(const Locale('tr'));
      expect(l10n.isTurkish, isTrue);
      expect(l10n.isEnglish, isFalse);
      expect(l10n.settingsTitle, equals('Uygulama Ayarları'));
      expect(l10n.settingsLanguageTitle, equals('Dil Seçimi / Language'));
      expect(l10n.settingsGoogleCloudAccount, equals('Google Bulut Hesabı'));
      expect(l10n['Common_Ok'], equals('Tamam'));
      expect(l10n['Common_Cancel'], equals('İptal'));
    });

    test('English AppLocalizations returns English strings', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.isTurkish, isFalse);
      expect(l10n.isEnglish, isTrue);
      expect(l10n.settingsTitle, equals('App Settings'));
      expect(l10n.settingsLanguageTitle, equals('Language Selection'));
      expect(l10n.settingsGoogleCloudAccount, equals('Google Cloud Account'));
      expect(l10n['Common_Ok'], equals('OK'));
      expect(l10n['Common_Cancel'], equals('Cancel'));
    });

    test('Fallback to Turkish when key missing in English', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.translate('NON_EXISTENT_KEY'), equals('NON_EXISTENT_KEY'));
    });
  });
}
