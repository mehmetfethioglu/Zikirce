import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/screen_awake_service.dart';
import '../../../../core/session/session_manager_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/utils/pref_utils.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../namaz_vakitleri/providers/prayer_providers.dart';

class SettingsState {
  final String userDisplayName;
  final String userProfileImage;
  final bool isDailyZikirGoalEnabled;
  final int dailyZikirGoal;
  final bool isDailyQuranGoalEnabled;
  final int dailyQuranGoal;
  final bool isHafizlikRepeatGoalEnabled;
  final bool isDailyKazaGoalEnabled;
  final int dailyKazaGoal;
  final bool isExcusedModeEnabled;
  final bool isAutoLocalBackupEnabled;
  final bool isKeepScreenAwakeEnabled;
  final bool isShareCardsEnabled;
  final String selectedLanguage;
  final String selectedBirdAvatar;
  final bool isZikirReminderEnabled;
  final String zikirReminderTime;
  final bool isQuranReminderEnabled;
  final String quranReminderTime;
  final bool isNamazReminderEnabled;
  final bool isKazaQuestionEnabled;
  final int kazaQuestionMinutesBefore;
  final String kazaQuestionCustomTime;
  final Map<String, bool> prayerNotifications;
  final Map<String, int> prayerOffsets;
  final Map<String, String> prayerCustomTimes;
  final String selectedDhikrSound;
  final String selectedPrayerSound;
  final String selectedReminderSound;
  final String selectedCongratulationSound;
  final bool isFeraciyeEnabled;
  final int feraciyeMinutesBefore;
  final String feraciyeCustomTime;
  final String feraciyeSound;
  final bool isThursdaySelaEnabled;
  final int thursdaySelaMinutesBefore;
  final String thursdaySelaCustomTime;
  final String thursdaySelaSound;
  final bool isFridaySelaEnabled;
  final int fridaySelaMinutesBefore;
  final String fridaySelaCustomTime;
  final String fridaySelaSound;
  final String selectedQuranTheme;
  final String selectedEzberTheme;
  final bool isBoldArabic;
  final bool isMaskingMode;
  final bool isBlurMode;
  final bool isPlayBesmeleOnStartEnabled;
  final String wordTrackingMode; // 'highlight' | 'arrow'
  final bool isAudioDownloading;
  final bool isAudioDownloadPaused;
  final double audioDownloadProgress;
  final String audioDownloadStatus;
  final int downloadedAudioCount;
  final int totalAudioCount;
  final double audioStorageSizeMb;
  final bool desktopMouseWheelEnabled;
  final bool desktopFullScreenClickEnabled;
  final bool desktopSpaceKeyEnabled;
  final bool desktopEnterKeyEnabled;
  final bool desktopArrowKeysEnabled;

  const SettingsState({
    this.userDisplayName = 'Zâkir',
    this.userProfileImage = 'assets/images/avatar_male_1.png',
    this.isDailyZikirGoalEnabled = true,
    this.dailyZikirGoal = 100,
    this.isDailyQuranGoalEnabled = true,
    this.dailyQuranGoal = 5,
    this.isHafizlikRepeatGoalEnabled = false,
    this.isDailyKazaGoalEnabled = false,
    this.dailyKazaGoal = 1,
    this.isExcusedModeEnabled = false,
    this.isAutoLocalBackupEnabled = true,
    this.isKeepScreenAwakeEnabled = false,
    this.isShareCardsEnabled = true,
    this.selectedLanguage = 'tr',
    this.selectedBirdAvatar = 'Kuş 1 (Varsayılan)',
    this.isZikirReminderEnabled = true,
    this.zikirReminderTime = '09:00',
    this.isQuranReminderEnabled = true,
    this.quranReminderTime = '21:00',
    this.isNamazReminderEnabled = true,
    this.isKazaQuestionEnabled = true,
    this.kazaQuestionMinutesBefore = 45,
    this.kazaQuestionCustomTime = '',
    this.prayerNotifications = const {
      'İmsak': true,
      'Güneş': true,
      'Öğle': true,
      'İkindi': true,
      'Akşam': true,
      'Yatsı': true,
    },
    this.prayerOffsets = const {
      'İmsak': 0,
      'Güneş': 0,
      'Öğle': 0,
      'İkindi': 0,
      'Akşam': 0,
      'Yatsı': 0,
    },
    this.prayerCustomTimes = const {
      'İmsak': '',
      'Güneş': '',
      'Öğle': '',
      'İkindi': '',
      'Akşam': '',
      'Yatsı': '',
    },
    this.selectedDhikrSound = 'Bülbül Sesi',
    this.selectedPrayerSound = 'Kumru Sesi',
    this.selectedReminderSound = 'Bülbül Sesi',
    this.selectedCongratulationSound = 'Bülbül Sesi',
    this.isFeraciyeEnabled = false,
    this.feraciyeMinutesBefore = 15,
    this.feraciyeCustomTime = '',
    this.feraciyeSound = 'Feraciye Duası',
    this.isThursdaySelaEnabled = false,
    this.thursdaySelaMinutesBefore = 30,
    this.thursdaySelaCustomTime = '',
    this.thursdaySelaSound = 'Salâ Sesi',
    this.isFridaySelaEnabled = false,
    this.fridaySelaMinutesBefore = 45,
    this.fridaySelaCustomTime = '',
    this.fridaySelaSound = 'Salâ Sesi',
    this.selectedQuranTheme = 'Klasik Sarı / Amasya',
    this.selectedEzberTheme = 'Açık / Beyaz',
    this.isBoldArabic = false,
    this.isMaskingMode = false,
    this.isBlurMode = false,
    this.isPlayBesmeleOnStartEnabled = true,
    this.wordTrackingMode = 'highlight',
    this.isAudioDownloading = false,
    this.isAudioDownloadPaused = false,
    this.audioDownloadProgress = 0.0,
    this.audioDownloadStatus = '',
    this.downloadedAudioCount = 0,
    this.totalAudioCount = 6236,
    this.audioStorageSizeMb = 0.0,
    this.desktopMouseWheelEnabled = true,
    this.desktopFullScreenClickEnabled = true,
    this.desktopSpaceKeyEnabled = true,
    this.desktopEnterKeyEnabled = true,
    this.desktopArrowKeysEnabled = true,
  });

  SettingsState copyWith({
    String? userDisplayName,
    String? userProfileImage,
    bool? isDailyZikirGoalEnabled,
    int? dailyZikirGoal,
    bool? isDailyQuranGoalEnabled,
    int? dailyQuranGoal,
    bool? isHafizlikRepeatGoalEnabled,
    bool? isDailyKazaGoalEnabled,
    int? dailyKazaGoal,
    bool? isExcusedModeEnabled,
    bool? isAutoLocalBackupEnabled,
    bool? isKeepScreenAwakeEnabled,
    bool? isShareCardsEnabled,
    String? selectedLanguage,
    String? selectedBirdAvatar,
    bool? isZikirReminderEnabled,
    String? zikirReminderTime,
    bool? isQuranReminderEnabled,
    String? quranReminderTime,
    bool? isNamazReminderEnabled,
    bool? isKazaQuestionEnabled,
    int? kazaQuestionMinutesBefore,
    String? kazaQuestionCustomTime,
    Map<String, bool>? prayerNotifications,
    Map<String, int>? prayerOffsets,
    Map<String, String>? prayerCustomTimes,
    String? selectedDhikrSound,
    String? selectedPrayerSound,
    String? selectedReminderSound,
    String? selectedCongratulationSound,
    bool? isFeraciyeEnabled,
    int? feraciyeMinutesBefore,
    String? feraciyeCustomTime,
    String? feraciyeSound,
    bool? isThursdaySelaEnabled,
    int? thursdaySelaMinutesBefore,
    String? thursdaySelaCustomTime,
    String? thursdaySelaSound,
    bool? isFridaySelaEnabled,
    int? fridaySelaMinutesBefore,
    String? fridaySelaCustomTime,
    String? fridaySelaSound,
    String? selectedQuranTheme,
    String? selectedEzberTheme,
    bool? isBoldArabic,
    bool? isMaskingMode,
    bool? isBlurMode,
    bool? isPlayBesmeleOnStartEnabled,
    String? wordTrackingMode,
    bool? isAudioDownloading,
    bool? isAudioDownloadPaused,
    double? audioDownloadProgress,
    String? audioDownloadStatus,
    int? downloadedAudioCount,
    int? totalAudioCount,
    double? audioStorageSizeMb,
    bool? desktopMouseWheelEnabled,
    bool? desktopFullScreenClickEnabled,
    bool? desktopSpaceKeyEnabled,
    bool? desktopEnterKeyEnabled,
    bool? desktopArrowKeysEnabled,
  }) {
    return SettingsState(
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      isDailyZikirGoalEnabled: isDailyZikirGoalEnabled ?? this.isDailyZikirGoalEnabled,
      dailyZikirGoal: dailyZikirGoal ?? this.dailyZikirGoal,
      isDailyQuranGoalEnabled: isDailyQuranGoalEnabled ?? this.isDailyQuranGoalEnabled,
      dailyQuranGoal: dailyQuranGoal ?? this.dailyQuranGoal,
      isHafizlikRepeatGoalEnabled: isHafizlikRepeatGoalEnabled ?? this.isHafizlikRepeatGoalEnabled,
      isDailyKazaGoalEnabled: isDailyKazaGoalEnabled ?? this.isDailyKazaGoalEnabled,
      dailyKazaGoal: dailyKazaGoal ?? this.dailyKazaGoal,
      isExcusedModeEnabled: isExcusedModeEnabled ?? this.isExcusedModeEnabled,
      isAutoLocalBackupEnabled: isAutoLocalBackupEnabled ?? this.isAutoLocalBackupEnabled,
      isKeepScreenAwakeEnabled: isKeepScreenAwakeEnabled ?? this.isKeepScreenAwakeEnabled,
      isShareCardsEnabled: isShareCardsEnabled ?? this.isShareCardsEnabled,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedBirdAvatar: selectedBirdAvatar ?? this.selectedBirdAvatar,
      isZikirReminderEnabled: isZikirReminderEnabled ?? this.isZikirReminderEnabled,
      zikirReminderTime: zikirReminderTime ?? this.zikirReminderTime,
      isQuranReminderEnabled: isQuranReminderEnabled ?? this.isQuranReminderEnabled,
      quranReminderTime: quranReminderTime ?? this.quranReminderTime,
      isNamazReminderEnabled: isNamazReminderEnabled ?? this.isNamazReminderEnabled,
      isKazaQuestionEnabled: isKazaQuestionEnabled ?? this.isKazaQuestionEnabled,
      kazaQuestionMinutesBefore: kazaQuestionMinutesBefore ?? this.kazaQuestionMinutesBefore,
      kazaQuestionCustomTime: kazaQuestionCustomTime ?? this.kazaQuestionCustomTime,
      prayerNotifications: prayerNotifications ?? this.prayerNotifications,
      prayerOffsets: prayerOffsets ?? this.prayerOffsets,
      prayerCustomTimes: prayerCustomTimes ?? this.prayerCustomTimes,
      selectedDhikrSound: selectedDhikrSound ?? this.selectedDhikrSound,
      selectedPrayerSound: selectedPrayerSound ?? this.selectedPrayerSound,
      selectedReminderSound: selectedReminderSound ?? this.selectedReminderSound,
      selectedCongratulationSound: selectedCongratulationSound ?? this.selectedCongratulationSound,
      isFeraciyeEnabled: isFeraciyeEnabled ?? this.isFeraciyeEnabled,
      feraciyeMinutesBefore: feraciyeMinutesBefore ?? this.feraciyeMinutesBefore,
      feraciyeCustomTime: feraciyeCustomTime ?? this.feraciyeCustomTime,
      feraciyeSound: feraciyeSound ?? this.feraciyeSound,
      isThursdaySelaEnabled: isThursdaySelaEnabled ?? this.isThursdaySelaEnabled,
      thursdaySelaMinutesBefore: thursdaySelaMinutesBefore ?? this.thursdaySelaMinutesBefore,
      thursdaySelaCustomTime: thursdaySelaCustomTime ?? this.thursdaySelaCustomTime,
      thursdaySelaSound: thursdaySelaSound ?? this.thursdaySelaSound,
      isFridaySelaEnabled: isFridaySelaEnabled ?? this.isFridaySelaEnabled,
      fridaySelaMinutesBefore: fridaySelaMinutesBefore ?? this.fridaySelaMinutesBefore,
      fridaySelaCustomTime: fridaySelaCustomTime ?? this.fridaySelaCustomTime,
      fridaySelaSound: fridaySelaSound ?? this.fridaySelaSound,
      selectedQuranTheme: selectedQuranTheme ?? this.selectedQuranTheme,
      selectedEzberTheme: selectedEzberTheme ?? this.selectedEzberTheme,
      isBoldArabic: isBoldArabic ?? this.isBoldArabic,
      isMaskingMode: isMaskingMode ?? this.isMaskingMode,
      isBlurMode: isBlurMode ?? this.isBlurMode,
      isPlayBesmeleOnStartEnabled: isPlayBesmeleOnStartEnabled ?? this.isPlayBesmeleOnStartEnabled,
      wordTrackingMode: wordTrackingMode ?? this.wordTrackingMode,
      isAudioDownloading: isAudioDownloading ?? this.isAudioDownloading,
      isAudioDownloadPaused: isAudioDownloadPaused ?? this.isAudioDownloadPaused,
      audioDownloadProgress: audioDownloadProgress ?? this.audioDownloadProgress,
      audioDownloadStatus: audioDownloadStatus ?? this.audioDownloadStatus,
      downloadedAudioCount: downloadedAudioCount ?? this.downloadedAudioCount,
      totalAudioCount: totalAudioCount ?? this.totalAudioCount,
      audioStorageSizeMb: audioStorageSizeMb ?? this.audioStorageSizeMb,
      desktopMouseWheelEnabled: desktopMouseWheelEnabled ?? this.desktopMouseWheelEnabled,
      desktopFullScreenClickEnabled: desktopFullScreenClickEnabled ?? this.desktopFullScreenClickEnabled,
      desktopSpaceKeyEnabled: desktopSpaceKeyEnabled ?? this.desktopSpaceKeyEnabled,
      desktopEnterKeyEnabled: desktopEnterKeyEnabled ?? this.desktopEnterKeyEnabled,
      desktopArrowKeysEnabled: desktopArrowKeysEnabled ?? this.desktopArrowKeysEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref ref;

  SettingsNotifier(this.ref) : super(const SettingsState()) {
    _loadSettings();
  }

  String _sKey(String baseKey, [String? customSessionId]) {
    final sid = customSessionId ?? ref.read(activeSessionProvider).id;
    if (sid != UserSession.defaultSessionId && sid.isNotEmpty) {
      return '${baseKey}_$sid';
    }
    return baseKey;
  }

  Future<void> _setSessionPrefString(SharedPreferences prefs, String key, String value, [String? customSessionId]) async {
    final sid = customSessionId ?? ref.read(activeSessionProvider).id;
    await prefs.setString(_sKey(key, sid), value);
    if (sid == UserSession.defaultSessionId) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _setSessionPrefInt(SharedPreferences prefs, String key, int value, [String? customSessionId]) async {
    final sid = customSessionId ?? ref.read(activeSessionProvider).id;
    await prefs.setInt(_sKey(key, sid), value);
    if (sid == UserSession.defaultSessionId) {
      await prefs.setInt(key, value);
    }
  }

  Future<void> _setSessionPrefBool(SharedPreferences prefs, String key, bool value, [String? customSessionId]) async {
    final sid = customSessionId ?? ref.read(activeSessionProvider).id;
    await prefs.setBool(_sKey(key, sid), value);
    if (sid == UserSession.defaultSessionId) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> _loadSettings([String? targetSessionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final sid = targetSessionId ?? ref.read(activeSessionProvider).id;
    final isDefault = sid == UserSession.defaultSessionId;
    final sfx = isDefault ? '' : '_$sid';

    final sessions = await SessionManagerService.loadSessions();
    final matchingSession = sessions.firstWhere(
      (s) => s.id == sid,
      orElse: () => UserSession.defaultSession(),
    );

    final name = isDefault
        ? PrefUtils.getStringFromKeys(prefs, ['UserDisplayName', 'user_display_name'], matchingSession.displayName)
        : (prefs.getString('UserDisplayName_$sid') ?? prefs.getString('user_display_name_$sid') ?? matchingSession.displayName);

    final avatar = isDefault
        ? PrefUtils.getStringFromKeys(prefs, ['UserProfileImage', 'avatar', 'ProfileImagePath'], matchingSession.avatar)
        : (prefs.getString('UserProfileImage_$sid') ?? prefs.getString('avatar_$sid') ?? matchingSession.avatar);

    final dailyZikir = PrefUtils.getIntFromKeys(prefs, ['DailyZikirGoal$sfx', 'zikir_daily_goal$sfx', 'ZikirDailyGoal$sfx', 'DailyZikirGoal'], 100);
    final isDailyZikirEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyZikirGoalEnabled$sfx', 'IsZikirGoalEnabled$sfx', 'IsDailyZikirGoalEnabled'], true);
    final dailyQuran = PrefUtils.getIntFromKeys(prefs, ['DailyQuranGoal$sfx', 'kuran_daily_goal$sfx', 'KuranDailyGoal$sfx', 'DailyQuranGoal'], 5);
    final isDailyQuranEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyQuranGoalEnabled$sfx', 'IsKuranGoalEnabled$sfx', 'IsDailyQuranGoalEnabled'], true);
    final isHafizlikRepeat = PrefUtils.getBoolFromKeys(prefs, ['IsHafizlikRepeatGoalEnabled$sfx', 'IsEzberGoalEnabled$sfx', 'IsHafizlikRepeatGoalEnabled'], false);
    final dailyKaza = PrefUtils.getIntFromKeys(prefs, ['DailyKazaGoal$sfx', 'kaza_daily_goal$sfx', 'KazaDailyGoal$sfx', 'DailyKazaGoal'], 1);
    final isDailyKazaEnabled = PrefUtils.getBoolFromKeys(prefs, ['IsDailyKazaGoalEnabled$sfx', 'IsKazaGoalEnabled$sfx', 'IsDailyKazaGoalEnabled'], true);
    final isExcused = PrefUtils.getBoolFromKeys(prefs, ['IsExcusedModeEnabled$sfx', 'IsSpecialDaysModeEnabled$sfx', 'IsZaruriHalEnabled$sfx', 'IsExcusedModeEnabled'], false);
    final isAutoLocalBackup = PrefUtils.getBoolFromKeys(prefs, ['IsAutoLocalBackupEnabled$sfx', 'IsAutoBackupEnabled$sfx', 'IsAutoLocalBackupEnabled'], true);
    final isKeepScreenAwake = PrefUtils.getBool(prefs, _sKey('IsKeepScreenAwakeEnabled', sid), false);
    final isShareCards = PrefUtils.getBoolFromKeys(prefs, ['IsShareCardsEnabled$sfx', 'IsShareCardsEnabled'], true);
    final lang = PrefUtils.getStringFromKeys(prefs, ['SelectedLanguage$sfx', 'AppLanguage$sfx', 'app_language$sfx', 'SelectedLanguage', 'AppLanguage', 'app_language'], 'tr');
    final bird = PrefUtils.getString(prefs, _sKey('SelectedBirdAvatar', sid), 'Kuş 1 (Varsayılan)');
    final isZikirReminder = PrefUtils.getBool(prefs, _sKey('IsZikirReminderEnabled', sid), true);
    final zikirTime = PrefUtils.getString(prefs, _sKey('ZikirReminderTime', sid), '09:00');
    final isQuranReminder = PrefUtils.getBool(prefs, _sKey('IsQuranReminderEnabled', sid), true);
    final quranTime = PrefUtils.getString(prefs, _sKey('QuranReminderTime', sid), '21:00');
    final isNamazReminder = PrefUtils.getBool(prefs, _sKey('IsNamazReminderEnabled', sid), prefs.getBool('IsNamazReminderEnabled') ?? true);
    final isKazaQuestion = PrefUtils.getBool(prefs, _sKey('KazaQuestionNotificationEnabled', sid), prefs.getBool('KazaQuestionNotificationEnabled') ?? true);
    final kazaQuestionMins = prefs.getInt('KazaQuestionMinutesBeforeEnd') ?? 45;
    final kazaQuestionCustom = prefs.getString('KazaQuestionCustomTime') ?? '';

    final prayerMap = <String, bool>{
      'İmsak': PrefUtils.getBool(prefs, _sKey('PrayerNotif_İmsak', sid), prefs.getBool('ImsakNotificationEnabled') ?? true),
      'Güneş': PrefUtils.getBool(prefs, _sKey('PrayerNotif_Güneş', sid), prefs.getBool('GunesNotificationEnabled') ?? true),
      'Öğle': PrefUtils.getBool(prefs, _sKey('PrayerNotif_Öğle', sid), prefs.getBool('OgleNotificationEnabled') ?? true),
      'İkindi': PrefUtils.getBool(prefs, _sKey('PrayerNotif_İkindi', sid), prefs.getBool('IkindiNotificationEnabled') ?? true),
      'Akşam': PrefUtils.getBool(prefs, _sKey('PrayerNotif_Akşam', sid), prefs.getBool('AksamNotificationEnabled') ?? true),
      'Yatsı': PrefUtils.getBool(prefs, _sKey('PrayerNotif_Yatsı', sid), prefs.getBool('YatsiNotificationEnabled') ?? true),
    };

    final offsetsMap = <String, int>{
      for (final k in const ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'])
        k: prefs.getInt('PrayerOffset_$k') ?? 0,
    };
    final customTimesMap = <String, String>{
      for (final k in const ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'])
        k: prefs.getString('PrayerCustomTime_$k') ?? '',
    };

    final dhikrSound = PrefUtils.getString(prefs, _sKey('SelectedDhikrSound', sid), 'Bülbül Sesi');
    final prayerSound = PrefUtils.getString(prefs, _sKey('SelectedPrayerSound', sid), prefs.getString('SelectedPrayerSound') ?? 'Kumru Sesi');
    final reminderSound = PrefUtils.getString(prefs, _sKey('SelectedReminderSound', sid), 'Bülbül Sesi');
    final congratSound = PrefUtils.getString(prefs, _sKey('SelectedCongratulationSound', sid), 'Bülbül Sesi');

    final isFeraciye = PrefUtils.getBool(
      prefs,
      _sKey('IsFeraciyeEnabled_v2', sid),
      prefs.getBool('IsFeraciyeEnabled_v2') ?? false,
    );
    final feraciyeMins = PrefUtils.getInt(
      prefs,
      _sKey('FeraciyeMinutesBeforeMaghrib', sid),
      prefs.getInt('FeraciyeMinutesBeforeMaghrib') ?? 15,
    );
    final feraciyeCustom = PrefUtils.getString(
      prefs,
      _sKey('FeraciyeCustomTime', sid),
      prefs.getString('FeraciyeCustomTime') ?? '',
    );
    final feraciyeSnd = PrefUtils.getString(
      prefs,
      _sKey('FeraciyeSound', sid),
      prefs.getString('FeraciyeSound') ?? 'Feraciye Duası',
    );

    final isThuSela = PrefUtils.getBool(
      prefs,
      _sKey('IsThursdaySelaEnabled_v2', sid),
      prefs.getBool('IsThursdaySelaEnabled_v2') ?? false,
    );
    final thuSelaMins = PrefUtils.getInt(
      prefs,
      _sKey('ThursdaySelaMinutesBeforeIsha', sid),
      prefs.getInt('ThursdaySelaMinutesBeforeIsha') ?? 30,
    );
    final thuSelaCustom = PrefUtils.getString(
      prefs,
      _sKey('ThursdaySelaCustomTime', sid),
      prefs.getString('ThursdaySelaCustomTime') ?? '',
    );
    final thuSelaSnd = PrefUtils.getString(
      prefs,
      _sKey('ThursdaySelaSound', sid),
      prefs.getString('ThursdaySelaSound') ?? 'Salâ Sesi',
    );

    final isFriSela = PrefUtils.getBool(
      prefs,
      _sKey('IsFridaySelaEnabled_v2', sid),
      prefs.getBool('IsFridaySelaEnabled_v2') ?? false,
    );
    final friSelaMins = PrefUtils.getInt(
      prefs,
      _sKey('FridaySelaMinutesBeforeDhuhr', sid),
      prefs.getInt('FridaySelaMinutesBeforeDhuhr') ?? 45,
    );
    final friSelaCustom = PrefUtils.getString(
      prefs,
      _sKey('FridaySelaCustomTime', sid),
      prefs.getString('FridaySelaCustomTime') ?? '',
    );
    final friSelaSnd = PrefUtils.getString(
      prefs,
      _sKey('FridaySelaSound', sid),
      prefs.getString('FridaySelaSound') ?? 'Salâ Sesi',
    );

    final quranTheme = PrefUtils.getString(prefs, _sKey('SelectedQuranTheme', sid), 'Klasik Sarı / Amasya');
    final ezberTheme = PrefUtils.getString(prefs, _sKey('SelectedEzberTheme', sid), 'Açık / Beyaz');
    final isBold = PrefUtils.getBool(prefs, _sKey('IsBoldArabic', sid), false);
    final isMask = PrefUtils.getBool(prefs, _sKey('IsMaskingMode', sid), false);
    final isBlur = PrefUtils.getBool(prefs, _sKey('IsBlurMode', sid), false);
    final isPlayBesmele = PrefUtils.getBool(prefs, _sKey('IsPlayBesmeleOnStartEnabled', sid), true);
    final trackingMode = PrefUtils.getString(prefs, _sKey('WordTrackingMode', sid), 'highlight');

    if (!mounted) return;

    state = state.copyWith(
      userDisplayName: name,
      userProfileImage: avatar,
      dailyZikirGoal: dailyZikir,
      isDailyZikirGoalEnabled: isDailyZikirEnabled,
      dailyQuranGoal: dailyQuran,
      isDailyQuranGoalEnabled: isDailyQuranEnabled,
      isHafizlikRepeatGoalEnabled: isHafizlikRepeat,
      dailyKazaGoal: dailyKaza,
      isDailyKazaGoalEnabled: isDailyKazaEnabled,
      isExcusedModeEnabled: isExcused,
      isAutoLocalBackupEnabled: isAutoLocalBackup,
      isKeepScreenAwakeEnabled: isKeepScreenAwake,
      isShareCardsEnabled: isShareCards,
      selectedLanguage: lang,
      selectedBirdAvatar: bird,
      isZikirReminderEnabled: isZikirReminder,
      zikirReminderTime: zikirTime,
      isQuranReminderEnabled: isQuranReminder,
      quranReminderTime: quranTime,
      isNamazReminderEnabled: isNamazReminder,
      isKazaQuestionEnabled: isKazaQuestion,
      kazaQuestionMinutesBefore: kazaQuestionMins,
      kazaQuestionCustomTime: kazaQuestionCustom,
      prayerNotifications: prayerMap,
      prayerOffsets: offsetsMap,
      prayerCustomTimes: customTimesMap,
      selectedDhikrSound: dhikrSound,
      selectedPrayerSound: prayerSound,
      selectedReminderSound: reminderSound,
      selectedCongratulationSound: congratSound,
      isFeraciyeEnabled: isFeraciye,
      feraciyeMinutesBefore: feraciyeMins,
      feraciyeCustomTime: feraciyeCustom,
      feraciyeSound: feraciyeSnd,
      isThursdaySelaEnabled: isThuSela,
      thursdaySelaMinutesBefore: thuSelaMins,
      thursdaySelaCustomTime: thuSelaCustom,
      thursdaySelaSound: thuSelaSnd,
      isFridaySelaEnabled: isFriSela,
      fridaySelaMinutesBefore: friSelaMins,
      fridaySelaCustomTime: friSelaCustom,
      fridaySelaSound: friSelaSnd,
      selectedQuranTheme: quranTheme,
      selectedEzberTheme: ezberTheme,
      isBoldArabic: isBold,
      isMaskingMode: isMask,
      isBlurMode: isBlur,
      isPlayBesmeleOnStartEnabled: isPlayBesmele,
      wordTrackingMode: trackingMode,
      desktopMouseWheelEnabled: prefs.getBool('DesktopMouseWheelEnabled') ?? true,
      desktopFullScreenClickEnabled: prefs.getBool('DesktopFullScreenClickEnabled') ?? true,
      desktopSpaceKeyEnabled: prefs.getBool('DesktopSpaceKeyEnabled') ?? true,
      desktopEnterKeyEnabled: prefs.getBool('DesktopEnterKeyEnabled') ?? true,
      desktopArrowKeysEnabled: prefs.getBool('DesktopArrowKeysEnabled') ?? true,
    );

    await ScreenAwakeService.setKeepAwake(isKeepScreenAwake);
    await refreshAudioStorageInfo();
  }

  void syncFromSession(String name, String avatar) {
    state = state.copyWith(
      userDisplayName: name,
      userProfileImage: avatar,
    );
  }

  Future<void> reloadSettings() async {
    await _loadSettings();
  }

  Future<void> reloadForSession(String sessionId) async {
    await _loadSettings(sessionId);
  }

  Future<void> setUserDisplayName(String name) async {
    state = state.copyWith(userDisplayName: name);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'UserDisplayName', name);
    await _setSessionPrefString(prefs, 'user_display_name', name);

    // Sync active session model in SessionManagerService and sessionProvider
    final activeSession = ref.read(activeSessionProvider);
    if (activeSession.displayName != name) {
      final updated = activeSession.copyWith(displayName: name);
      await ref.read(sessionProvider.notifier).updateSession(updated);
    }

    try {
      final db = ref.read(databaseProvider);
      final profile = await db.select(db.userProfiles).getSingleOrNull();
      if (profile != null) {
        await (db.update(db.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          profile.copyWith(userName: name),
        );
      }
    } catch (_) {}
  }

  Future<void> setUserProfileImage(String path) async {
    state = state.copyWith(userProfileImage: path);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'UserProfileImage', path);
    await _setSessionPrefString(prefs, 'avatar', path);

    // Sync active session model in SessionManagerService and sessionProvider
    final activeSession = ref.read(activeSessionProvider);
    if (activeSession.avatar != path) {
      final updated = activeSession.copyWith(avatar: path);
      await ref.read(sessionProvider.notifier).updateSession(updated);
    }

    try {
      final db = ref.read(databaseProvider);
      final profile = await db.select(db.userProfiles).getSingleOrNull();
      if (profile != null) {
        await (db.update(db.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          profile.copyWith(avatar: path),
        );
      }
    } catch (_) {}
  }

  Future<void> setDailyZikirGoal(int count) async {
    state = state.copyWith(dailyZikirGoal: count);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefInt(prefs, 'DailyZikirGoal', count);
    await _setSessionPrefInt(prefs, 'ZikirDailyGoal', count);
    await _setSessionPrefInt(prefs, 'zikir_daily_goal', count);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleDailyZikirGoal(bool enabled) async {
    state = state.copyWith(isDailyZikirGoalEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsDailyZikirGoalEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsZikirGoalEnabled', enabled);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> setDailyQuranGoal(int count) async {
    state = state.copyWith(dailyQuranGoal: count);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefInt(prefs, 'DailyQuranGoal', count);
    await _setSessionPrefInt(prefs, 'KuranDailyGoal', count);
    await _setSessionPrefInt(prefs, 'kuran_daily_goal', count);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleDailyQuranGoal(bool enabled) async {
    state = state.copyWith(isDailyQuranGoalEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsDailyQuranGoalEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsKuranGoalEnabled', enabled);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleHafizlikRepeatGoal(bool enabled) async {
    state = state.copyWith(isHafizlikRepeatGoalEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsHafizlikRepeatGoalEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsEzberGoalEnabled', enabled);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> setDailyKazaGoal(int count) async {
    state = state.copyWith(dailyKazaGoal: count);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefInt(prefs, 'DailyKazaGoal', count);
    await _setSessionPrefInt(prefs, 'KazaDailyGoal', count);
    await _setSessionPrefInt(prefs, 'kaza_daily_goal', count);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleDailyKazaGoal(bool enabled) async {
    state = state.copyWith(isDailyKazaGoalEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsDailyKazaGoalEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsKazaGoalEnabled', enabled);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleExcusedMode(bool enabled) async {
    state = state.copyWith(isExcusedModeEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsExcusedModeEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsSpecialDaysModeEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsZaruriHalEnabled', enabled);
    ref.invalidate(dailyGoalsStatusProvider);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleAutoLocalBackup(bool enabled) async {
    state = state.copyWith(isAutoLocalBackupEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsAutoLocalBackupEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsAutoBackupEnabled', enabled);
    if (enabled) {
      final db = ref.read(databaseProvider);
      final activeSession = ref.read(activeSessionProvider);
      BackupService.triggerAutoBackupBackground(db, force: true, sessionId: activeSession.id);
    }
  }

  Future<void> toggleKeepScreenAwake(bool enabled) async {
    state = state.copyWith(isKeepScreenAwakeEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsKeepScreenAwakeEnabled', enabled);
    await ScreenAwakeService.setKeepAwake(enabled);
  }

  Future<void> toggleShareCards(bool enabled) async {
    state = state.copyWith(isShareCardsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsShareCardsEnabled', enabled);
  }

  Future<void> setSelectedLanguage(String lang) async {
    state = state.copyWith(selectedLanguage: lang);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedLanguage', lang);
    await _setSessionPrefString(prefs, 'AppLanguage', lang);
    ref.read(localeProvider.notifier).setLanguageCode(lang);
  }

  Future<void> setSelectedBirdAvatar(String bird) async {
    state = state.copyWith(selectedBirdAvatar: bird);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedBirdAvatar', bird);
  }

  Future<void> toggleZikirReminder(bool enabled) async {
    state = state.copyWith(isZikirReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsZikirReminderEnabled', enabled);
  }

  Future<void> setZikirReminderTime(String time) async {
    state = state.copyWith(zikirReminderTime: time);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'ZikirReminderTime', time);
  }

  Future<void> toggleQuranReminder(bool enabled) async {
    state = state.copyWith(isQuranReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsQuranReminderEnabled', enabled);
    await LocalNotificationService.scheduleQuranDailyReminder(
      timeHhmm: state.quranReminderTime,
      isEnabled: enabled,
    );
  }

  Future<void> setQuranReminderTime(String time) async {
    state = state.copyWith(quranReminderTime: time);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'QuranReminderTime', time);
    if (state.isQuranReminderEnabled) {
      await LocalNotificationService.scheduleQuranDailyReminder(
        timeHhmm: time,
        isEnabled: true,
      );
    }
  }

  Future<void> toggleNamazReminder(bool enabled) async {
    state = state.copyWith(isNamazReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsNamazReminderEnabled', enabled);
    await prefs.setBool('IsNamazReminderEnabled', enabled);

    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null) {
      if (enabled) {
        await LocalNotificationService.scheduleAllPrayerNotifications(timings, force: true);
      } else {
        await LocalNotificationService.cancelAllPrayerNotifications();
      }
    }
  }

  Future<void> togglePrayerNotification(String prayerKey, [bool? directVal]) async {
    final currentMap = Map<String, bool>.from(state.prayerNotifications);
    final currentVal = currentMap[prayerKey] ?? true;
    final newVal = directVal ?? !currentVal;
    currentMap[prayerKey] = newVal;

    state = state.copyWith(prayerNotifications: currentMap);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'PrayerNotif_$prayerKey', newVal);
    await _setSessionPrefBool(prefs, '${prayerKey}NotificationEnabled', newVal);
    await prefs.setBool('${prayerKey}NotificationEnabled', newVal);

    // Also map Turkish prayer names to keys used in local_notification_service
    final mapKeys = {
      'İmsak': 'ImsakNotificationEnabled',
      'Güneş': 'GunesNotificationEnabled',
      'Öğle': 'OgleNotificationEnabled',
      'İkindi': 'IkindiNotificationEnabled',
      'Akşam': 'AksamNotificationEnabled',
      'Yatsı': 'YatsiNotificationEnabled',
      'Sabah': 'SabahNotificationEnabled',
    };
    if (mapKeys.containsKey(prayerKey)) {
      await _setSessionPrefBool(prefs, mapKeys[prayerKey]!, newVal);
      await prefs.setBool(mapKeys[prayerKey]!, newVal);
    }

    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null && state.isNamazReminderEnabled) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings, force: true);
    }
  }

  Future<void> toggleKazaQuestion(bool enabled) async {
    state = state.copyWith(isKazaQuestionEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('KazaQuestionNotificationEnabled', enabled);
    await _setSessionPrefBool(prefs, 'KazaQuestionNotificationEnabled', enabled);

    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null && state.isNamazReminderEnabled) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings, force: true);
    }
  }

  Future<void> setKazaQuestionTiming({int? minutesBefore, String? customTime}) async {
    final nextMins = minutesBefore ?? state.kazaQuestionMinutesBefore;
    final nextCustom = customTime ?? state.kazaQuestionCustomTime;
    state = state.copyWith(
      kazaQuestionMinutesBefore: nextMins,
      kazaQuestionCustomTime: nextCustom,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('KazaQuestionMinutesBeforeEnd', nextMins);
    await prefs.setString('KazaQuestionCustomTime', nextCustom);
    await _reschedulePrayersIfActive();
  }

  Future<void> setPrayerTiming(String prayerKey, {int? offsetMinutes, String? customTime}) async {
    final nextOffsets = Map<String, int>.from(state.prayerOffsets);
    final nextCustoms = Map<String, String>.from(state.prayerCustomTimes);
    if (offsetMinutes != null) {
      nextOffsets[prayerKey] = offsetMinutes;
    }
    if (customTime != null) {
      nextCustoms[prayerKey] = customTime;
    }
    state = state.copyWith(
      prayerOffsets: nextOffsets,
      prayerCustomTimes: nextCustoms,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('PrayerOffset_$prayerKey', nextOffsets[prayerKey] ?? 0);
    await prefs.setString('PrayerCustomTime_$prayerKey', nextCustoms[prayerKey] ?? '');
    await _reschedulePrayersIfActive();
  }

  Future<void> setSelectedDhikrSound(String sound) async {
    state = state.copyWith(selectedDhikrSound: sound);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedDhikrSound', sound);
  }

  Future<void> setSelectedPrayerSound(String sound) async {
    state = state.copyWith(selectedPrayerSound: sound);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedPrayerSound', sound);
    await prefs.setString('SelectedPrayerSound', sound);
    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null && state.isNamazReminderEnabled) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings, force: true);
    }
  }

  Future<void> setSelectedReminderSound(String sound) async {
    state = state.copyWith(selectedReminderSound: sound);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedReminderSound', sound);
    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null && state.isNamazReminderEnabled) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings);
    }
  }

  Future<void> setSelectedCongratulationSound(String sound) async {
    state = state.copyWith(selectedCongratulationSound: sound);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedCongratulationSound', sound);
  }

  Future<void> _reschedulePrayersIfActive() async {
    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null && state.isNamazReminderEnabled) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings, force: true);
    }
  }

  Future<void> toggleFeraciyeNotification(bool enabled) async {
    state = state.copyWith(isFeraciyeEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsFeraciyeEnabled_v2', enabled);
    await _setSessionPrefBool(prefs, 'IsFeraciyeEnabled_v2', enabled);
    await prefs.setBool('IsFeraciyeNotificationEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsFeraciyeNotificationEnabled', enabled);
    await _reschedulePrayersIfActive();
  }

  Future<void> setFeraciyeTiming({int? minutesBefore, String? customTime, String? sound}) async {
    final nextMins = minutesBefore ?? state.feraciyeMinutesBefore;
    final nextCustom = customTime ?? state.feraciyeCustomTime;
    final nextSound = sound ?? state.feraciyeSound;
    state = state.copyWith(
      feraciyeMinutesBefore: nextMins,
      feraciyeCustomTime: nextCustom,
      feraciyeSound: nextSound,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('FeraciyeMinutesBeforeMaghrib', nextMins);
    await _setSessionPrefInt(prefs, 'FeraciyeMinutesBeforeMaghrib', nextMins);
    await prefs.setString('FeraciyeCustomTime', nextCustom);
    await _setSessionPrefString(prefs, 'FeraciyeCustomTime', nextCustom);
    await prefs.setString('FeraciyeSound', nextSound);
    await _setSessionPrefString(prefs, 'FeraciyeSound', nextSound);
    await _reschedulePrayersIfActive();
  }

  Future<void> toggleThursdaySelaNotification(bool enabled) async {
    state = state.copyWith(isThursdaySelaEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsThursdaySelaEnabled_v2', enabled);
    await _setSessionPrefBool(prefs, 'IsThursdaySelaEnabled_v2', enabled);
    await prefs.setBool('IsThursdaySelaNotificationEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsThursdaySelaNotificationEnabled', enabled);
    await _reschedulePrayersIfActive();
  }

  Future<void> setThursdaySelaTiming({int? minutesBefore, String? customTime, String? sound}) async {
    final nextMins = minutesBefore ?? state.thursdaySelaMinutesBefore;
    final nextCustom = customTime ?? state.thursdaySelaCustomTime;
    final nextSound = sound ?? state.thursdaySelaSound;
    state = state.copyWith(
      thursdaySelaMinutesBefore: nextMins,
      thursdaySelaCustomTime: nextCustom,
      thursdaySelaSound: nextSound,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ThursdaySelaMinutesBeforeIsha', nextMins);
    await _setSessionPrefInt(prefs, 'ThursdaySelaMinutesBeforeIsha', nextMins);
    await prefs.setString('ThursdaySelaCustomTime', nextCustom);
    await _setSessionPrefString(prefs, 'ThursdaySelaCustomTime', nextCustom);
    await prefs.setString('ThursdaySelaSound', nextSound);
    await _setSessionPrefString(prefs, 'ThursdaySelaSound', nextSound);
    await _reschedulePrayersIfActive();
  }

  Future<void> toggleFridaySelaNotification(bool enabled) async {
    state = state.copyWith(isFridaySelaEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsFridaySelaEnabled_v2', enabled);
    await _setSessionPrefBool(prefs, 'IsFridaySelaEnabled_v2', enabled);
    await prefs.setBool('IsFridaySelaNotificationEnabled', enabled);
    await _setSessionPrefBool(prefs, 'IsFridaySelaNotificationEnabled', enabled);
    await _reschedulePrayersIfActive();
  }

  Future<void> setFridaySelaTiming({int? minutesBefore, String? customTime, String? sound}) async {
    final nextMins = minutesBefore ?? state.fridaySelaMinutesBefore;
    final nextCustom = customTime ?? state.fridaySelaCustomTime;
    final nextSound = sound ?? state.fridaySelaSound;
    state = state.copyWith(
      fridaySelaMinutesBefore: nextMins,
      fridaySelaCustomTime: nextCustom,
      fridaySelaSound: nextSound,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('FridaySelaMinutesBeforeDhuhr', nextMins);
    await _setSessionPrefInt(prefs, 'FridaySelaMinutesBeforeDhuhr', nextMins);
    await prefs.setString('FridaySelaCustomTime', nextCustom);
    await _setSessionPrefString(prefs, 'FridaySelaCustomTime', nextCustom);
    await prefs.setString('FridaySelaSound', nextSound);
    await _setSessionPrefString(prefs, 'FridaySelaSound', nextSound);
    await _reschedulePrayersIfActive();
  }

  Future<void> setSelectedQuranTheme(String theme) async {
    state = state.copyWith(selectedQuranTheme: theme);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedQuranTheme', theme);
  }

  Future<void> setSelectedEzberTheme(String theme) async {
    state = state.copyWith(selectedEzberTheme: theme);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'SelectedEzberTheme', theme);
  }

  Future<void> toggleBoldArabic(bool val) async {
    state = state.copyWith(isBoldArabic: val);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsBoldArabic', val);
  }

  Future<void> toggleMaskingMode(bool val) async {
    state = state.copyWith(isMaskingMode: val);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsMaskingMode', val);
  }

  Future<void> toggleBlurMode(bool val) async {
    state = state.copyWith(isBlurMode: val);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsBlurMode', val);
  }

  Future<void> togglePlayBesmeleOnStart(bool val) async {
    state = state.copyWith(isPlayBesmeleOnStartEnabled: val);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefBool(prefs, 'IsPlayBesmeleOnStartEnabled', val);
  }

  Future<void> setWordTrackingMode(String mode) async {
    state = state.copyWith(wordTrackingMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await _setSessionPrefString(prefs, 'WordTrackingMode', mode);
  }

  Future<void> refreshAudioStorageInfo() async {
    final count = await AudioDownloadService.getDownloadedAudioCount();
    final sizeMb = await AudioDownloadService.getTotalStorageSizeMb();
    state = state.copyWith(
      downloadedAudioCount: count,
      audioStorageSizeMb: sizeMb,
    );
  }

  Future<void> startAudioDownload() async {
    final service = AudioDownloadService();
    state = state.copyWith(
      isAudioDownloading: true,
      isAudioDownloadPaused: false,
      audioDownloadProgress: 0.0,
      audioDownloadStatus: 'Ses dosyaları hazırlanıyor...',
    );

    await service.downloadAllQuran(
      onProgress: (p) {
        state = state.copyWith(
          isAudioDownloading: p.isDownloading,
          isAudioDownloadPaused: p.isPaused,
          audioDownloadProgress: p.progress,
          audioDownloadStatus: p.statusText,
          downloadedAudioCount: p.completed,
        );
      },
    );

    await refreshAudioStorageInfo();
    final actualCount = state.downloadedAudioCount;
    state = state.copyWith(
      isAudioDownloading: false,
      isAudioDownloadPaused: false,
      audioDownloadProgress: actualCount >= 6236 ? 1.0 : (actualCount / 6236),
      audioDownloadStatus: actualCount >= 6236
          ? 'Tüm ses dosyaları başarıyla indirildi.'
          : '$actualCount / 6236 ayet indirildi.',
    );
  }

  void cancelAudioDownload() {
    AudioDownloadService().cancelDownload();
    state = state.copyWith(
      isAudioDownloading: false,
      isAudioDownloadPaused: false,
      audioDownloadStatus: 'İndirme iptal edildi.',
    );
    refreshAudioStorageInfo();
  }

  void toggleAudioDownloadPause() {
    AudioDownloadService().togglePause();
    state = state.copyWith(
      isAudioDownloadPaused: AudioDownloadService().isPaused,
    );
  }

  Future<void> downloadJuz(int juzNumber) async {
    final service = AudioDownloadService();
    state = state.copyWith(
      isAudioDownloading: true,
      isAudioDownloadPaused: false,
      audioDownloadProgress: 0.0,
      audioDownloadStatus: '$juzNumber. Cüz hazırlanıyor...',
    );

    await service.downloadJuz(
      juzNumber,
      onProgress: (p) {
        state = state.copyWith(
          isAudioDownloading: p.isDownloading,
          isAudioDownloadPaused: p.isPaused,
          audioDownloadProgress: p.progress,
          audioDownloadStatus: '$juzNumber. Cüz: ${p.statusText}',
        );
      },
    );

    await refreshAudioStorageInfo();
    state = state.copyWith(
      isAudioDownloading: false,
      isAudioDownloadPaused: false,
      audioDownloadProgress: 1.0,
      audioDownloadStatus: '$juzNumber. Cüz başarıyla indirildi.',
    );
  }

  Future<void> deleteJuzAudios(int juzNumber) async {
    await AudioDownloadService.deleteJuzAudios(juzNumber);
    await refreshAudioStorageInfo();
  }

  Future<void> deleteAllAudios() async {
    await AudioDownloadService.deleteAllAudios();
    await refreshAudioStorageInfo();
    state = state.copyWith(
      audioDownloadProgress: 0.0,
      audioDownloadStatus: 'Tüm ses dosyaları silindi.',
    );
  }

  Future<void> toggleDesktopMouseWheel() async {
    final next = !state.desktopMouseWheelEnabled;
    state = state.copyWith(desktopMouseWheelEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('DesktopMouseWheelEnabled', next);
  }

  Future<void> toggleDesktopFullScreenClick() async {
    final next = !state.desktopFullScreenClickEnabled;
    state = state.copyWith(desktopFullScreenClickEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('DesktopFullScreenClickEnabled', next);
  }

  Future<void> toggleDesktopSpaceKey() async {
    final next = !state.desktopSpaceKeyEnabled;
    state = state.copyWith(desktopSpaceKeyEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('DesktopSpaceKeyEnabled', next);
  }

  Future<void> toggleDesktopEnterKey() async {
    final next = !state.desktopEnterKeyEnabled;
    state = state.copyWith(desktopEnterKeyEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('DesktopEnterKeyEnabled', next);
  }

  Future<void> toggleDesktopArrowKeys() async {
    final next = !state.desktopArrowKeysEnabled;
    state = state.copyWith(desktopArrowKeysEnabled: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('DesktopArrowKeysEnabled', next);
  }
}

final userSettingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

final settingsProvider = userSettingsProvider;

final isBoldArabicProvider = Provider<bool>((ref) {
  return ref.watch(userSettingsProvider.select((s) => s.isBoldArabic));
});
