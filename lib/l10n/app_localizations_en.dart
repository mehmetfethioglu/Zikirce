// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kilerce: Pantry, Barcode & Recipes';

  @override
  String get brandTagline => 'BARCODE • PANTRY • RECIPES';

  @override
  String get tabPantry => 'My Pantry';

  @override
  String get tabRecipes => 'Meals & Recipes';

  @override
  String get tabScanner => 'Barcode & Scan';

  @override
  String get tabShoppingProfile => 'Shopping & Profile';

  @override
  String pantrySummaryBadge(int count, int score) {
    return '$count Items • Score $score';
  }

  @override
  String get taklitTagsisTooltip => 'Ministry Food Fraud Blacklist';

  @override
  String get expiryAlertTitle => 'Expiry Reminders';

  @override
  String get expiryAlertSubtitle =>
      'Daily reminder for pantry items nearing expiration';

  @override
  String get backupSuccessMessage =>
      'Pantry, recipe, and profile data backed up';

  @override
  String get restoreSuccessMessage => 'All Kilerce data restored';
}
