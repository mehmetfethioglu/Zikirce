// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Kilerce: Barkod, Dolap & Tarif';

  @override
  String get brandTagline => 'BARKOD • DOLAP • TARİF';

  @override
  String get tabPantry => 'Kilerim';

  @override
  String get tabRecipes => 'Yemek & Tarif';

  @override
  String get tabScanner => 'Barkod & Analiz';

  @override
  String get tabShoppingProfile => 'Alışveriş & Profil';

  @override
  String pantrySummaryBadge(int count, int score) {
    return '$count Ürün • Skor $score';
  }

  @override
  String get taklitTagsisTooltip => 'Bakanlık Taklit & Tağşiş Listesi';

  @override
  String get expiryAlertTitle => 'SKT Bildirimleri';

  @override
  String get expiryAlertSubtitle =>
      'Son kullanma tarihi yaklaşan ürünler için günlük hatırlatma';

  @override
  String get backupSuccessMessage =>
      'Kiler, tarif ve profil verileri yedeklendi';

  @override
  String get restoreSuccessMessage => 'Tüm Kilerce verileri geri yüklendi';
}
