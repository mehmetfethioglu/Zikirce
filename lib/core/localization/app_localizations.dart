import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'translations/app_strings_en.dart';
import 'translations/app_strings_tr.dart';

/// AppLocalizations provides access to 1:1 .NET MAUI translated resources for Flutter.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('tr'));
  }

  bool get isTurkish => locale.languageCode == 'tr';
  bool get isEnglish => locale.languageCode == 'en';

  /// Primary translation method with fallback to Turkish and key name.
  String translate(String key) {
    if (locale.languageCode == 'en') {
      return appStringsEn[key] ?? appStringsTr[key] ?? key;
    }
    return appStringsTr[key] ?? appStringsEn[key] ?? key;
  }

  /// Translation with placeholder arguments {0}, {1}, etc.
  String translateArgs(String key, List<String> args) {
    String text = translate(key);
    for (int i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', args[i]);
    }
    return text;
  }

  /// Shorthand indexer
  String operator [](String key) => translate(key);

  // =========================================================================
  // TYPED CONVENIENCE GETTERS (1:1 with MAUI AppResources keys)
  // =========================================================================

  // Common
  String get commonOk => translate('Common_Ok');
  String get commonCancel => translate('Common_Cancel');
  String get commonSave => translate('Common_Save');
  String get commonDelete => translate('Common_Delete');
  String get commonEdit => translate('Common_Edit');
  String get commonError => translate('Common_Error');
  String get commonSuccess => translate('Common_Success');
  String get commonClose => translate('Common_Close');
  String get commonLoading => translate('Common_Loading');

  // Settings Screen
  String get settingsTitle => translate('Settings_Title');
  String get settingsSubtitle => translate('Settings_Subtitle');
  String get settingsLanguageTitle => translate('Settings_LanguageTitle');
  String get settingsThemeTitle => translate('Settings_ThemeTitle');
  String get settingsProfileSection => translate('Settings_ProfileSection');
  String get settingsProfileName => translate('Settings_ProfileName');
  String get settingsProfileNamePlaceholder => translate('Settings_ProfileNamePlaceholder');
  String get settingsGoogleCloudAccount => translate('Settings_GoogleCloudAccount');
  String get settingsGoogleCloudDesc => translate('Settings_GoogleCloudDesc');
  String get settingsLinkGoogleAccount => translate('Settings_LinkGoogleAccount');
  String get settingsLastCloudBackup => translate('Settings_LastCloudBackup');
  String get settingsAutoCloudBackup => translate('Settings_AutoCloudBackup');
  String get settingsAutoCloudBackupDesc => translate('Settings_AutoCloudBackupDesc');
  String get settingsBackupToCloud => translate('Settings_BackupToCloud');
  String get settingsRestoreFromCloud => translate('Settings_RestoreFromCloud');
  String get settingsLocalDataSection => translate('Settings_LocalDataSection');
  String get settingsAutoLocalBackup => translate('Settings_AutoLocalBackup');
  String get settingsAutoLocalBackupDesc => translate('Settings_AutoLocalBackupDesc');
  String get settingsBackupToFile => translate('Settings_BackupToFile');
  String get settingsRestoreFromFile => translate('Settings_RestoreFromFile');
  String get settingsAppearanceSection => translate('Settings_AppearanceSection');
  String get settingsThemeSelection => translate('Settings_ThemeSelection');
  String get settingsThemeDesc => translate('Settings_ThemeDesc');
  String get settingsThemeSystem => translate('Settings_ThemeSystem');
  String get settingsThemeLight => translate('Settings_ThemeLight');
  String get settingsThemeDark => translate('Settings_ThemeDark');
  String get settingsThemeBlack => translate('Settings_ThemeBlack');
  String get settingsThemeHighContrast => translate('Settings_ThemeHighContrast');
  String get settingsLightThemeStyle => translate('Settings_LightThemeStyle');
  String get settingsLightThemeStyleDesc => translate('Settings_LightThemeStyleDesc');
  String get settingsStyleClassicCream => translate('Settings_StyleClassicCream');
  String get settingsStyleGreenMint => translate('Settings_StyleGreenMint');
  String get settingsBirdSelection => translate('Settings_BirdSelection');
  String get settingsBirdSelectionDesc => translate('Settings_BirdSelectionDesc');
  String get settingsNotificationsSection => translate('Settings_NotificationsSection');
  String get settingsDhikrReminder => translate('Settings_DhikrReminder');
  String get settingsDhikrReminderDesc => translate('Settings_DhikrReminderDesc');
  String get settingsReminderTime => translate('Settings_ReminderTime');
  String get settingsQuranReminder => translate('Settings_QuranReminder');
  String get settingsQuranReminderDesc => translate('Settings_QuranReminderDesc');
  String get settingsSendTestNotification => translate('Settings_SendTestNotification');
  String get settingsPrayerNotifications => translate('Settings_PrayerNotifications');
  String get settingsPrayerNotificationsDesc => translate('Settings_PrayerNotificationsDesc');
  String get settingsImsak => translate('Settings_Imsak');
  String get settingsGunes => translate('Settings_Gunes');
  String get settingsOgle => translate('Settings_Ogle');
  String get settingsIkindi => translate('Settings_Ikindi');
  String get settingsAksam => translate('Settings_Aksam');
  String get settingsYatsi => translate('Settings_Yatsi');
  String get settingsKuranSection => translate('Settings_KuranSection');
  String get settingsDailyReadingGoal => translate('Settings_DailyReadingGoal');
  String get settingsSoundSettingsSection => translate('Settings_SoundSettingsSection');
  String get settingsDhikrSound => translate('Settings_DhikrSound');
  String get settingsPrayerSound => translate('Settings_PrayerSound');
  String get settingsReminderSound => translate('Settings_ReminderSound');
  String get settingsCongratulationSound => translate('Settings_CongratulationSound');
  String get settingsSoundNightingale => translate('Settings_SoundNightingale');
  String get settingsSoundDove => translate('Settings_SoundDove');
  String get settingsSoundDefaultClick => translate('Settings_SoundDefaultClick');
  String get settingsDailyGoalsSection => translate('Settings_DailyGoalsSection');
  String get settingsZikirGoal => translate('Settings_ZikirGoal');
  String get settingsQuranGoal => translate('Settings_QuranGoal');
  String get settingsHafizlikGoal => translate('Settings_HafizlikGoal');
  String get settingsKazaGoal => translate('Settings_KazaGoal');
  String get settingsFeedbackSection => translate('Settings_FeedbackSection');
  String get settingsFeedbackTitle => translate('Settings_FeedbackTitle');
  String get settingsFeedbackDesc => translate('Settings_FeedbackDesc');
  String get settingsFeedbackEmail => translate('Settings_FeedbackEmail');
  String get settingsFeedbackEmailPlaceholder => translate('Settings_FeedbackEmailPlaceholder');
  String get settingsFeedbackType => translate('Settings_FeedbackType');
  String get settingsFeedbackMessage => translate('Settings_FeedbackMessage');
  String get settingsFeedbackMessagePlaceholder => translate('Settings_FeedbackMessagePlaceholder');
  String get settingsSendFeedback => translate('Settings_SendFeedback');
  String get settingsSendFeedbackBtn => translate('Settings_SendFeedbackBtn');
  String get settingsAboutSection => translate('Settings_AboutSection');
  String get settingsAboutApp => translate('Settings_AboutApp');
  String get settingsPrivacyPolicy => translate('Settings_PrivacyPolicy');
  String get settingsFiqhLibrary => translate('Settings_FiqhLibrary');
  String get settingsShareApp => translate('Settings_ShareApp');
  String get settingsBatteryOptimization => translate('Settings_BatteryOptimization');
  String get settingsScreenSection => translate('Settings_ScreenSection');
  String get settingsKeepScreenAwake => translate('Settings_KeepScreenAwake');
  String get settingsKeepScreenAwakeDesc => translate('Settings_KeepScreenAwakeDesc');
  String get settingsBatteryOptimizationDesc => translate('Settings_BatteryOptimizationDesc');
  String get settingsQuranTheme => translate('Settings_QuranTheme');
  String get settingsQuranThemeDesc => translate('Settings_QuranThemeDesc');
  String get settingsEzberTheme => translate('Settings_EzberTheme');
  String get settingsEzberThemeDesc => translate('Settings_EzberThemeDesc');
  String get settingsFontFamily => translate('Settings_FontFamily');
  String get settingsFontSize => translate('Settings_FontSize');
  String get settingsBoldArabic => translate('Settings_BoldArabic');
  String get settingsMaskingMode => translate('Settings_MaskingMode');
  String get settingsBlurMode => translate('Settings_BlurMode');
  String get settingsLineSpacing => translate('Settings_LineSpacing');
  String get settingsDivineWords => translate('Settings_DivineWords');
  String get settingsDivineWordsDesc => translate('Settings_DivineWordsDesc');
  String get settingsAudioDownload => translate('Settings_AudioDownload');
  String get settingsDownloadAllAudio => translate('Settings_DownloadAllAudio');
  String get settingsFeedbackThanks => translate('Settings_FeedbackThanks');
  String get settingsExportJson => translate('Settings_ExportJson');
  String get settingsImportJson => translate('Settings_ImportJson');
  String get settingsSelectBackupFile => translate('Settings_SelectBackupFile');

  // Bismillah Dashboard
  String get bismillahTotal => translate('Bismillah_Total');
  String get bismillahZikirs => translate('Bismillah_Zikirs');
  String get bismillahTasksTitle => translate('Bismillah_TasksTitle');
  String get bismillahStreakTitle => translate('Bismillah_StreakTitle');
  String get bismillahGoldStreakTitle => translate('Bismillah_GoldStreakTitle');
  String get bismillahDays => translate('Bismillah_Days');
  String get bismillahDistributionTitle => translate('Bismillah_DistributionTitle');
  String get bismillahQuickStats => translate('Bismillah_QuickStats');
  String get bismillahToday => translate('Bismillah_Today');
  String get bismillahThisWeek => translate('Bismillah_ThisWeek');
  String get bismillahDailyAverage => translate('Bismillah_DailyAverage');
  String get bismillahQuranReading => translate('Bismillah_QuranReading');
  String get bismillahPages => translate('Bismillah_Pages');
  String get bismillahActivityTrends => translate('Bismillah_ActivityTrends');
  String get bismillahTabWeek => translate('Bismillah_TabWeek');
  String get bismillahTabMonth => translate('Bismillah_TabMonth');
  String get bismillahTabYear => translate('Bismillah_TabYear');
  String get bismillahHeatmapTitle => translate('Bismillah_HeatmapTitle');
  String get bismillahHistoryTitle => translate('Bismillah_HistoryTitle');
  String get bismillahNoHistory => translate('Bismillah_NoHistory');
  String get bismillahNoHistoryDesc => translate('Bismillah_NoHistoryDesc');
  String get bismillahClose => translate('Bismillah_Close');

  // Quran Page
  String get quranPageQuickAccessAndHatims => translate('QuranPage_QuickAccessAndHatims');
  String get quranPageHatimTracking => translate('QuranPage_HatimTracking');
  String get quranPageContinue => translate('QuranPage_Continue');
  String get quranPageNoActiveHatim => translate('QuranPage_NoActiveHatim');
  String get quranPageStartNew => translate('QuranPage_StartNew');
  String get quranPageStart => translate('QuranPage_Start');
  String get quranPageSurahs => translate('QuranPage_Surahs');
  String get quranPageJuzs => translate('QuranPage_Juzs');
  String get quranPageSearchSurah => translate('QuranPage_SearchSurah');
  String get quranPageLastRead => translate('QuranPage_LastRead');

  // Namaz / Prayer
  String get namazPrayerTimes => translate('Namaz_PrayerTimes');
  String get namazQiblaCompass => translate('Namaz_QiblaCompass');
  String get namazKazaTracker => translate('Namaz_KazaTracker');
  String get namazNextPrayer => translate('Namaz_NextPrayer');
  String get namazTimeRemaining => translate('Namaz_TimeRemaining');
  String get namazTapToChangeCity => translate('Namaz_TapToChangeCity');
  String get namazMissedPrayersDebt => translate('Namaz_MissedPrayersDebt');
  String get namazRemaining => translate('Namaz_Remaining');
  String get namazCompleted => translate('Namaz_Completed');
  String get namazManageMissed => translate('Namaz_ManageMissed');
  String get namazViewAllFiqh => translate('Namaz_ViewAllFiqh');

  // Zikir Page & List
  String get zikirPageCounter => translate('ZikirPage_Counter');
  String get zikirPageTarget => translate('ZikirPage_Target');
  String get zikirPageTotal => translate('ZikirPage_Total');
  String get zikirPageReset => translate('ZikirPage_Reset');
  String get zikirPageVibration => translate('ZikirPage_Vibration');
  String get zikirPageSound => translate('ZikirPage_Sound');
  String get zikirListTitle => translate('ZikirList_Title');
  String get zikirListSearchHint => translate('ZikirList_SearchHint');
  String get zikirListAddTooltip => translate('ZikirList_AddTooltip');
  String get addZikirNewTitle => translate('AddZikir_NewTitle');
  String get addZikirImportTitle => translate('AddZikir_ImportTitle');
  String get addZikirNamePlaceholder => translate('AddZikir_NamePlaceholder');
  String get addZikirTargetPlaceholder => translate('AddZikir_TargetPlaceholder');
  String get addZikirCategoryTitle => translate('AddZikir_CategoryTitle');
  String get addZikirArabicPlaceholder => translate('AddZikir_ArabicPlaceholder');
  String get addZikirDescPlaceholder => translate('AddZikir_DescPlaceholder');
  String get addZikirFilterTip => translate('AddZikir_FilterTip');
  String get addZikirSelectDhikr => translate('AddZikir_SelectDhikr');
  String get addZikirListSelectPrompt => translate('AddZikir_ListSelectPrompt');
  String get addZikirRecitedAmount => translate('AddZikir_RecitedAmount');
  String get addZikirAmountPlaceholder => translate('AddZikir_AmountPlaceholder');
  String get addZikirImportTip => translate('AddZikir_ImportTip');
  String get commonAdd => translate('Common_Add');
  String get commonImport => translate('Common_Import');

  // Gamification / Badges / Streaks
  String get badgeGallery => translate('Badge_Gallery');
  String get rankInfo => translate('Rank_Info');
  String get streakDetails => translate('Streak_Details');
  String get streakHistory => translate('Streak_History');

  // Mukabele Hatim
  String get mukabeleTitle => translate('Mukabele_Title');
  String get mukabeleStartCardTitle => translate('Mukabele_StartCardTitle');
  String get mukabeleStartCardSubtitle => translate('Mukabele_StartCardSubtitle');
  String get mukabeleActiveTitle => translate('Mukabele_ActiveTitle');
  String get mukabeleContinue => translate('Mukabele_Continue');
  String get mukabeleViewModeMushaf => translate('Mukabele_ViewModeMushaf');
  String get mukabeleViewModeList => translate('Mukabele_ViewModeList');
  String get mukabeleSpeed => translate('Mukabele_Speed');
  String get mukabeleSelectJuzPage => translate('Mukabele_SelectJuzPage');
  String get mukabeleStartNewPrompt => translate('Mukabele_StartNewPrompt');
  String get mukabeleTypeRamadan30Days => translate('Mukabele_TypeRamadan30Days');
  String get mukabeleTypePersonalFull => translate('Mukabele_TypePersonalFull');
  String get mukabeleTypeCustomJuz => translate('Mukabele_TypeCustomJuz');
  String get mukabeleDescRamadan => translate('Mukabele_DescRamadan');
  String get mukabeleDescPersonal => translate('Mukabele_DescPersonal');
  String get mukabeleDescCustom => translate('Mukabele_DescCustom');
  String get mukabelePlayingAudio => translate('Mukabele_PlayingAudio');
  String get mukabelePausedAudio => translate('Mukabele_PausedAudio');
  String get mukabeleNextAyah => translate('Mukabele_NextAyah');
  String get mukabelePrevAyah => translate('Mukabele_PrevAyah');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
