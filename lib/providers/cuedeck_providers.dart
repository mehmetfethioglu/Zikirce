import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cue_models.dart';
import '../services/adb_tv_service.dart';
import '../services/cue_monetization_service.dart';
import '../services/cue_notification_service.dart';
import '../services/google_drive_backup_service.dart';

const String _kPrefsCueItemsKey = 'cuedeck_watch_items_v1';
const String _kPrefsTvIpKey = 'cuedeck_tv_ip_v1';
const String _kPrefsDarkModeKey = 'cuedeck_dark_mode_v1';
const String _kPrefsRemoteShortcutsKey = 'cuedeck_remote_shortcuts_v1';

/// Immutable state for the CueDeck Remote & Watch Planner application.
@immutable
class CueDeckState {
  const CueDeckState({
    required this.activeTab,
    required this.selectedDevice,
    required this.discoveredDevices,
    required this.isScanning,
    required this.isTouchpadMode,
    required this.lastPressedDirection,
    required this.lastCommandStatus,
    required this.cueItems,
    this.remoteShortcuts = StreamingPlatform.defaultRemoteShortcuts,
    this.isDarkMode = true,
    this.isListeningVoice = false,
    this.lastVoiceTranscript = '',
    this.isGoogleSignedIn = false,
    this.googleUserEmail = '',
    this.googleUserName = '',
    this.lastBackupTimeFormatted = 'Henüz yedekleme yapılmadı',
    this.isAutoCloudBackupEnabled = false,
    this.isProcessingBackup = false,
    this.activePlayingCueId,
    this.activeReminderItem,
    this.entitlement = const CueEntitlementState(),
  });

  final int activeTab;
  final TvDevice selectedDevice;
  final List<TvDevice> discoveredDevices;
  final bool isScanning;
  final bool isTouchpadMode;
  final TvKeyCommand? lastPressedDirection;
  final String lastCommandStatus;
  final List<WatchCueItem> cueItems;
  final List<StreamingPlatform> remoteShortcuts;
  final bool isDarkMode;
  final bool isListeningVoice;
  final String lastVoiceTranscript;
  final bool isGoogleSignedIn;
  final String googleUserEmail;
  final String googleUserName;
  final String lastBackupTimeFormatted;
  final bool isAutoCloudBackupEnabled;
  final bool isProcessingBackup;
  final String? activePlayingCueId;
  final WatchCueItem? activeReminderItem;
  final CueEntitlementState entitlement;

  /// True when the user owns the one-time Lifetime Pro upgrade.
  bool get isProLifetime => entitlement.isProLifetime;

  /// True when the 24-hour Rewarded Pro Pass is currently active.
  bool get isProPassActive => entitlement.isProPassActive();

  /// True when the user has full Pro features unlocked (Lifetime Pro OR active 24h Pro Pass).
  bool get hasProAccess => entitlement.hasProAccess();

  /// Number of distinct days the user unlocked a 24h Pro Pass via Rewarded Ad.
  int get rewardedDaysCount => entitlement.rewardedDaysCount;

  /// True when the user has unlocked the 40% Loyalty Discount (`89,99 ₺` / `$3.49`).
  bool get isLoyaltyDiscountUnlocked => entitlement.isLoyaltyDiscountUnlocked;

  /// Weighted overall completion percentage across all planned watch items (0..100).
  int get overallCompletionPercent {
    if (cueItems.isEmpty) return 0;
    var totalMins = 0;
    var watchedMins = 0;
    for (final item in cueItems) {
      totalMins += item.totalMinutes;
      watchedMins += item.watchedMinutes.clamp(0, item.totalMinutes);
    }
    if (totalMins <= 0) return 0;
    return ((watchedMins / totalMins) * 100).round().clamp(0, 100);
  }

  /// Total watched minutes across all planned items.
  int get totalWatchedMinutes {
    var sum = 0;
    for (final item in cueItems) {
      sum += item.watchedMinutes.clamp(0, item.totalMinutes);
    }
    return sum;
  }

  /// Total planned minutes across all planned items.
  int get totalPlannedMinutes {
    var sum = 0;
    for (final item in cueItems) {
      sum += item.totalMinutes;
    }
    return sum;
  }

  /// Number of completed watch plan items.
  int get completedCount => cueItems.where((e) => e.isCompleted).length;

  /// Returns the currently active or next upcoming incomplete WatchCueItem.
  WatchCueItem? get primaryCueItem {
    if (cueItems.isEmpty) return null;
    if (activePlayingCueId != null) {
      for (final item in cueItems) {
        if (item.id == activePlayingCueId) return item;
      }
    }
    for (final item in cueItems) {
      if (!item.isCompleted) return item;
    }
    return cueItems.first;
  }

  CueDeckState copyWith({
    int? activeTab,
    TvDevice? selectedDevice,
    List<TvDevice>? discoveredDevices,
    bool? isScanning,
    bool? isTouchpadMode,
    TvKeyCommand? lastPressedDirection,
    bool clearPressedDirection = false,
    String? lastCommandStatus,
    List<WatchCueItem>? cueItems,
    List<StreamingPlatform>? remoteShortcuts,
    bool? isDarkMode,
    bool? isListeningVoice,
    String? lastVoiceTranscript,
    bool? isGoogleSignedIn,
    String? googleUserEmail,
    String? googleUserName,
    String? lastBackupTimeFormatted,
    bool? isAutoCloudBackupEnabled,
    bool? isProcessingBackup,
    String? activePlayingCueId,
    bool clearActivePlayingCue = false,
    WatchCueItem? activeReminderItem,
    bool clearReminder = false,
    CueEntitlementState? entitlement,
  }) {
    return CueDeckState(
      activeTab: activeTab ?? this.activeTab,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
      isTouchpadMode: isTouchpadMode ?? this.isTouchpadMode,
      lastPressedDirection: clearPressedDirection
          ? null
          : (lastPressedDirection ?? this.lastPressedDirection),
      lastCommandStatus: lastCommandStatus ?? this.lastCommandStatus,
      cueItems: cueItems ?? this.cueItems,
      remoteShortcuts: remoteShortcuts ?? this.remoteShortcuts,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isListeningVoice: isListeningVoice ?? this.isListeningVoice,
      lastVoiceTranscript: lastVoiceTranscript ?? this.lastVoiceTranscript,
      isGoogleSignedIn: isGoogleSignedIn ?? this.isGoogleSignedIn,
      googleUserEmail: googleUserEmail ?? this.googleUserEmail,
      googleUserName: googleUserName ?? this.googleUserName,
      lastBackupTimeFormatted:
          lastBackupTimeFormatted ?? this.lastBackupTimeFormatted,
      isAutoCloudBackupEnabled:
          isAutoCloudBackupEnabled ?? this.isAutoCloudBackupEnabled,
      isProcessingBackup: isProcessingBackup ?? this.isProcessingBackup,
      activePlayingCueId: clearActivePlayingCue
          ? null
          : (activePlayingCueId ?? this.activePlayingCueId),
      activeReminderItem: clearReminder
          ? null
          : (activeReminderItem ?? this.activeReminderItem),
      entitlement: entitlement ?? this.entitlement,
    );
  }
}

final adbTvServiceProvider = Provider<AdbTvService>((ref) {
  final service = AdbTvService();
  ref.onDispose(service.dispose);
  return service;
});

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>((
  ref,
) {
  return GoogleDriveBackupService();
});

final cueNotificationServiceProvider = Provider<CueNotificationService>((ref) {
  return CueNotificationService();
});

final cueMonetizationServiceProvider = Provider<CueMonetizationService>((ref) {
  return CueMonetizationService();
});

final cueDeckProvider = NotifierProvider<CueDeckNotifier, CueDeckState>(
  CueDeckNotifier.new,
);

class CueDeckNotifier extends Notifier<CueDeckState> {
  Timer? _schedulerTimer;
  Timer? _highlightResetTimer;
  Timer? _autoBackupDebounceTimer;
  Timer? _initialRetryTimer;

  @override
  CueDeckState build() {
    ref.onDispose(() {
      _schedulerTimer?.cancel();
      _highlightResetTimer?.cancel();
      _autoBackupDebounceTimer?.cancel();
      _initialRetryTimer?.cancel();
    });

    final now = DateTime.now();
    final initialDevices = <TvDevice>[
      const TvDevice(
        name: 'Redline Android TV (Salon)',
        ip: '192.168.1.125',
        port: 5555,
        boardInfo: 'Realtek RTD2851P • CleanYourTV OS',
        isOnline: true,
      ),
    ];

    final defaultCues = <WatchCueItem>[
      WatchCueItem(
        id: 'cue_yt_playlist_1',
        title: 'Mimari & Teknoloji 4K Oynatma Listesi',
        subtitle: 'YouTube Playlist • 8 Video Serisi',
        platform: StreamingPlatform.youtube,
        scheduledTime: now.add(const Duration(minutes: 15)),
        totalMinutes: 160,
        watchedMinutes: 65,
        sessionMinutes: 40,
        currentEpisode: 3,
        totalEpisodes: 8,
        deepLinkUrl:
            'https://www.youtube.com/playlist?list=PLjxrf2q8roU23XGwz3Km7sQZFTdB996iG',
        recurrence: WatchRecurrence.daily,
        activeWeekdays: const <int>[1, 2, 3, 4, 5, 6, 7],
        reminderMinutesBefore: 10,
      ),
      WatchCueItem(
        id: 'cue_bein_2',
        title: 'Süper Lig: Haftanın Derbi Özel Yayını',
        subtitle: 'Canlı Stüdyo & Maç Özeti • Kanal 77',
        platform: StreamingPlatform.beinConnect,
        scheduledTime: now.add(const Duration(minutes: 45)),
        totalMinutes: 120,
        watchedMinutes: 48,
        sessionMinutes: 60,
        currentEpisode: 1,
        totalEpisodes: 1,
        recurrence: WatchRecurrence.weekends,
        activeWeekdays: const <int>[6, 7],
        reminderMinutesBefore: 15,
      ),
      WatchCueItem(
        id: 'cue_tabii_3',
        title: 'Gassal • Özel Kurgu Seçkisi',
        subtitle: '2. Sezon • Dizi Maratonu',
        platform: StreamingPlatform.tabii,
        scheduledTime: now.add(const Duration(hours: 1, minutes: 30)),
        totalMinutes: 150,
        watchedMinutes: 50,
        sessionMinutes: 50,
        currentEpisode: 4,
        totalEpisodes: 10,
        recurrence: WatchRecurrence.weekdays,
        activeWeekdays: const <int>[1, 2, 3, 4, 5],
        reminderMinutesBefore: 15,
      ),
      WatchCueItem(
        id: 'cue_netflix_4',
        title: 'Bilim Kurgu Gece Kuşağı',
        subtitle: '1. Sezon • Akşam Kuşağı',
        platform: StreamingPlatform.netflix,
        scheduledTime: now.add(const Duration(hours: 3)),
        totalMinutes: 180,
        watchedMinutes: 45,
        sessionMinutes: 45,
        currentEpisode: 2,
        totalEpisodes: 8,
        recurrence: WatchRecurrence.customDays,
        activeWeekdays: const <int>[1, 3, 5, 7],
        reminderMinutesBefore: 15,
      ),
    ];

    Future<void>.microtask(_initializeAsync);

    return CueDeckState(
      activeTab: 0,
      selectedDevice: initialDevices.first,
      discoveredDevices: initialDevices,
      isScanning: false,
      isTouchpadMode: false,
      lastPressedDirection: null,
      lastCommandStatus: 'Redline Android TV (192.168.1.123:5555) hazır',
      cueItems: defaultCues,
      activePlayingCueId: 'cue_yt_playlist_1',
    );
  }

  Future<void> _initializeAsync() async {
    await _loadPersistedState();
    final loadedEntitlement =
        await ref.read(cueMonetizationServiceProvider).loadEntitlement();
    state = state.copyWith(entitlement: loadedEntitlement);
    await ref.read(cueNotificationServiceProvider).requestPermission();
    await _syncNativeNotifications();
    await refreshGoogleDriveStatus();
    _startScheduleMonitor();
    await scanNetworkForTvs();
    if (!state.selectedDevice.isOnline) {
      _initialRetryTimer?.cancel();
      _initialRetryTimer = Timer(const Duration(seconds: 4), () {
        if (!state.selectedDevice.isOnline && !state.isScanning) {
          scanNetworkForTvs();
        }
      });
    }
  }

  Future<void> _syncNativeNotifications() async {
    await ref
        .read(cueNotificationServiceProvider)
        .syncScheduledReminders(state.cueItems);
  }

  void _startScheduleMonitor() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _checkScheduledRemindersAndActivePlayback();
    });
  }

  void _checkScheduledRemindersAndActivePlayback() {
    final now = DateTime.now();
    WatchCueItem? dueReminder;
    final updatedList = <WatchCueItem>[];
    var changed = false;

    for (final item in state.cueItems) {
      var current = item;
      if (current.isReminderDue(now) && dueReminder == null) {
        current = current.copyWith(reminderFired: true);
        dueReminder = current;
        changed = true;
      }
      updatedList.add(current);
    }

    if (changed) {
      state = state.copyWith(
        cueItems: updatedList,
        activeReminderItem: dueReminder ?? state.activeReminderItem,
        lastCommandStatus: dueReminder != null
            ? '⏰ Hatırlatıcı: "${dueReminder.title}" saati yaklaştı!'
            : state.lastCommandStatus,
      );
      if (dueReminder != null) {
        unawaited(
          ref
              .read(cueNotificationServiceProvider)
              .showReminderNotification(dueReminder, isLeadReminder: true),
        );
      }
      _persistState(triggerAutoBackup: false);
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString(_kPrefsTvIpKey);
      final savedDark = prefs.getBool(_kPrefsDarkModeKey);
      final rawJson = prefs.getString(_kPrefsCueItemsKey);
      final savedShortcuts = prefs.getStringList(_kPrefsRemoteShortcutsKey);

      List<WatchCueItem>? loadedItems;
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        loadedItems = decoded
            .whereType<Map<String, dynamic>>()
            .map(WatchCueItem.fromJson)
            .toList();
      }

      List<StreamingPlatform>? loadedShortcuts;
      if (savedShortcuts != null && savedShortcuts.length == 6) {
        loadedShortcuts = savedShortcuts
            .map((name) => StreamingPlatform.fromName(name))
            .toList(growable: false);
      }

      state = state.copyWith(
        isDarkMode: savedDark ?? state.isDarkMode,
        selectedDevice: savedIp != null && AdbTvService.isValidIp(savedIp)
            ? state.selectedDevice.copyWith(ip: savedIp)
            : state.selectedDevice,
        cueItems: (loadedItems != null && loadedItems.isNotEmpty)
            ? loadedItems
            : state.cueItems,
        remoteShortcuts: loadedShortcuts ?? state.remoteShortcuts,
      );
    } catch (_) {
      // Ignore storage read issues in headless test environments
    }
  }

  Future<void> _persistState({bool triggerAutoBackup = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsTvIpKey, state.selectedDevice.ip);
      await prefs.setBool(_kPrefsDarkModeKey, state.isDarkMode);
      await prefs.setStringList(
        _kPrefsRemoteShortcutsKey,
        state.remoteShortcuts.map((e) => e.name).toList(growable: false),
      );
      final encoded = jsonEncode(
        state.cueItems.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_kPrefsCueItemsKey, encoded);
    } catch (_) {
      // Ignore persistence errors during tests
    }
    unawaited(_syncNativeNotifications());
    if (triggerAutoBackup) {
      _scheduleDebouncedAutoCloudBackup();
    }
  }

  void _scheduleDebouncedAutoCloudBackup() {
    if (!state.isAutoCloudBackupEnabled || !state.isGoogleSignedIn) return;
    _autoBackupDebounceTimer?.cancel();
    _autoBackupDebounceTimer = Timer(const Duration(seconds: 30), () {
      if (state.isAutoCloudBackupEnabled &&
          state.isGoogleSignedIn &&
          !state.isProcessingBackup) {
        unawaited(backupNowToCloud(silent: true));
      }
    });
  }

  // ===========================================================================
  // GOOGLE DRIVE & LOCAL BACKUP / RESTORE / MULTI-DEVICE SYNC ACTIONS
  // ===========================================================================

  /// Refreshes Google Drive OAuth2 sign-in state, profile info, and last backup timestamp.
  Future<void> refreshGoogleDriveStatus() async {
    try {
      final backupService = ref.read(googleDriveBackupServiceProvider);
      final signedIn = await backupService.isSignedIn();
      final email = (await backupService.getUserEmail()) ?? '';
      final name = (await backupService.getUserName()) ?? '';
      final lastTime = await backupService.getLastBackupTimeFormatted();
      final autoEnabled = await backupService.isAutoBackupEnabled();

      state = state.copyWith(
        isGoogleSignedIn: signedIn,
        googleUserEmail: signedIn ? email : '',
        googleUserName: signedIn ? name : '',
        lastBackupTimeFormatted: lastTime,
        isAutoCloudBackupEnabled: autoEnabled,
      );
    } catch (_) {}
  }

  /// Signs out from Google Drive and clears encrypted tokens.
  Future<BackupOperationResult> signOutGoogleDrive() async {
    _autoBackupDebounceTimer?.cancel();
    final backupService = ref.read(googleDriveBackupServiceProvider);
    await backupService.signOut();
    state = state.copyWith(
      isGoogleSignedIn: false,
      googleUserEmail: '',
      googleUserName: '',
      lastCommandStatus: 'Google Drive oturumu kapatıldı',
    );
    return const BackupOperationResult(
      success: true,
      message: 'Google Drive bağlantısı kesildi.',
    );
  }

  /// Toggles automatic background cloud backup; triggers an immediate backup when enabled.
  Future<void> toggleAutoCloudBackup(bool enabled) async {
    final backupService = ref.read(googleDriveBackupServiceProvider);
    await backupService.setAutoBackupEnabled(enabled);
    state = state.copyWith(
      isAutoCloudBackupEnabled: enabled,
      lastCommandStatus: enabled
          ? '☁️ Otomatik Google Drive yedekleme açıldı'
          : 'Otomatik Google Drive yedekleme kapatıldı',
    );
    if (enabled && state.isGoogleSignedIn) {
      unawaited(backupNowToCloud());
    }
  }

  /// Immediately backs up all watch plans and settings to Google Drive (`appDataFolder`).
  Future<BackupOperationResult> backupNowToCloud({bool silent = false}) async {
    if (state.isProcessingBackup) {
      return const BackupOperationResult(
        success: false,
        message: 'Yedekleme işlemi devam ediyor, lütfen bekleyin.',
      );
    }

    state = state.copyWith(
      isProcessingBackup: true,
      lastCommandStatus: silent
          ? state.lastCommandStatus
          : '☁️ Google Drive\'a yedekleniyor...',
    );

    final backupService = ref.read(googleDriveBackupServiceProvider);
    final result = await backupService.backupToCloud(
      items: state.cueItems,
      isDarkMode: state.isDarkMode,
      tvIp: state.selectedDevice.ip,
      selectedDevice: state.selectedDevice,
    );

    final lastTime = await backupService.getLastBackupTimeFormatted();
    state = state.copyWith(
      isProcessingBackup: false,
      lastBackupTimeFormatted: lastTime,
      lastCommandStatus: result.message,
    );
    return result;
  }

  /// Returns the list of available cloud and local backup snapshots.
  Future<List<CloudBackupInfo>> fetchAvailableBackups() async {
    final backupService = ref.read(googleDriveBackupServiceProvider);
    return backupService.listCloudBackups();
  }

  /// Downloads and restores watch plans & settings from a specific cloud/local backup.
  Future<BackupOperationResult> restoreFromBackup({String? fileId}) async {
    if (state.isProcessingBackup) {
      return const BackupOperationResult(
        success: false,
        message: 'İşlem devam ediyor, lütfen bekleyin.',
      );
    }

    state = state.copyWith(
      isProcessingBackup: true,
      lastCommandStatus: '☁️ Yedek indiriliyor ve doğrulanıyor...',
    );

    final backupService = ref.read(googleDriveBackupServiceProvider);
    try {
      final rawJson =
          await backupService.downloadCloudBackupJson(fileId: fileId);
      final parsed = backupService.parseAndValidateBackupJson(rawJson);

      final restoredDark = parsed.settings['isDarkMode'] as bool?;
      final restoredIp = parsed.settings['tvIp'] as String?;

      state = state.copyWith(
        isProcessingBackup: false,
        cueItems: parsed.items,
        activePlayingCueId:
            parsed.items.isNotEmpty ? parsed.items.first.id : null,
        isDarkMode: restoredDark ?? state.isDarkMode,
        selectedDevice: (restoredIp != null && AdbTvService.isValidIp(restoredIp))
            ? state.selectedDevice.copyWith(ip: restoredIp)
            : state.selectedDevice,
        lastCommandStatus:
            '✓ ${parsed.items.length} izleme planı başarıyla geri yüklendi',
      );
      await _persistState(triggerAutoBackup: false);

      return BackupOperationResult(
        success: true,
        message:
            '✓ ${parsed.items.length} izleme planı başarıyla geri yüklendi',
        restoredCount: parsed.items.length,
        backupDate: parsed.backupDate,
        restoredItems: parsed.items,
        restoredSettings: parsed.settings,
      );
    } catch (e) {
      final msg = 'Geri yükleme başarısız: $e';
      state = state.copyWith(
        isProcessingBackup: false,
        lastCommandStatus: msg,
      );
      return BackupOperationResult(success: false, message: msg);
    }
  }

  /// Synchronizes and merges local watch plans with the latest Google Drive backup.
  Future<BackupOperationResult> syncDevicesWithCloud() async {
    if (state.isProcessingBackup) {
      return const BackupOperationResult(
        success: false,
        message: 'Eşitleme işlemi zaten devam ediyor.',
      );
    }

    state = state.copyWith(
      isProcessingBackup: true,
      lastCommandStatus: '🔄 Cihazlar arası planlar eşitleniyor...',
    );

    final backupService = ref.read(googleDriveBackupServiceProvider);
    final res = await backupService.syncAndMergeWithCloud(
      localItems: state.cueItems,
      isDarkMode: state.isDarkMode,
      tvIp: state.selectedDevice.ip,
      selectedDevice: state.selectedDevice,
    );

    final lastTime = await backupService.getLastBackupTimeFormatted();
    if (res.success && res.restoredItems != null) {
      state = state.copyWith(
        isProcessingBackup: false,
        cueItems: res.restoredItems,
        lastBackupTimeFormatted: lastTime,
        lastCommandStatus: res.message,
      );
      await _persistState(triggerAutoBackup: false);
    } else {
      state = state.copyWith(
        isProcessingBackup: false,
        lastBackupTimeFormatted: lastTime,
        lastCommandStatus: res.message,
      );
    }
    return res;
  }

  /// Exports a `.json` backup file to device storage via Android SAF.
  Future<BackupOperationResult> exportLocalBackupFile() async {
    state = state.copyWith(
      isProcessingBackup: true,
      lastCommandStatus: '💾 Yedek dosyası hazırlanıyor...',
    );
    final backupService = ref.read(googleDriveBackupServiceProvider);
    final res = await backupService.exportBackupToFile(
      items: state.cueItems,
      isDarkMode: state.isDarkMode,
      tvIp: state.selectedDevice.ip,
      selectedDevice: state.selectedDevice,
    );
    state = state.copyWith(
      isProcessingBackup: false,
      lastCommandStatus: res.message,
    );
    return res;
  }

  /// Imports and restores a `.json` backup file selected via Android SAF.
  Future<BackupOperationResult> importLocalBackupFile() async {
    state = state.copyWith(
      isProcessingBackup: true,
      lastCommandStatus: '📂 Yedek dosyası okunuyor...',
    );
    final backupService = ref.read(googleDriveBackupServiceProvider);
    final res = await backupService.importBackupFromFile();
    if (res.success && res.restoredItems != null) {
      final restoredDark = res.restoredSettings?['isDarkMode'] as bool?;
      final restoredIp = res.restoredSettings?['tvIp'] as String?;
      state = state.copyWith(
        isProcessingBackup: false,
        cueItems: res.restoredItems,
        activePlayingCueId: res.restoredItems!.isNotEmpty
            ? res.restoredItems!.first.id
            : null,
        isDarkMode: restoredDark ?? state.isDarkMode,
        selectedDevice: (restoredIp != null && AdbTvService.isValidIp(restoredIp))
            ? state.selectedDevice.copyWith(ip: restoredIp)
            : state.selectedDevice,
        lastCommandStatus: res.message,
      );
      await _persistState();
    } else {
      state = state.copyWith(
        isProcessingBackup: false,
        lastCommandStatus: res.message,
      );
    }
    return res;
  }

  // ===========================================================================
  // THEME, NAVIGATION & REMOTE CONTROL ACTIONS
  // ===========================================================================

  void toggleThemeMode() {
    final nextDark = !state.isDarkMode;
    state = state.copyWith(
      isDarkMode: nextDark,
      lastCommandStatus: nextDark
          ? 'Gerçek Siyah (AMOLED) Koyu Tema aktif'
          : 'Açık Tema (G10 Beyaz Kumanda) aktif',
    );
    _persistState();
  }

  void setDarkMode(bool isDark) {
    if (state.isDarkMode == isDark) return;
    state = state.copyWith(
      isDarkMode: isDark,
      lastCommandStatus: isDark
          ? 'Gerçek Siyah (AMOLED) Koyu Tema aktif'
          : 'Açık Tema (G10 Beyaz Kumanda) aktif',
    );
    _persistState();
  }

  /// Replaces the streaming app assigned to slot [slotIndex] (0..5) on the G10 remote.
  void updateRemoteShortcutSlot(int slotIndex, StreamingPlatform platform) {
    if (slotIndex < 0 || slotIndex >= 6) return;
    final current = List<StreamingPlatform>.from(
      state.remoteShortcuts.length == 6
          ? state.remoteShortcuts
          : StreamingPlatform.defaultRemoteShortcuts,
    );
    current[slotIndex] = platform;
    state = state.copyWith(
      remoteShortcuts: List<StreamingPlatform>.unmodifiable(current),
      lastCommandStatus:
          '🎮 ${slotIndex + 1}. kısayol tuşu "${platform.label}" olarak güncellendi',
    );
    _persistState(triggerAutoBackup: false);
  }

  /// Restores the G10 remote's 6 app shortcut slots to the default lineup.
  void resetRemoteShortcutsToDefault() {
    state = state.copyWith(
      remoteShortcuts: StreamingPlatform.defaultRemoteShortcuts,
      lastCommandStatus: '🎮 Kumanda kısayol tuşları varsayılana sıfırlandı',
    );
    _persistState(triggerAutoBackup: false);
  }

  void setActiveTab(int index) {
    if (state.activeTab == index) return;
    state = state.copyWith(activeTab: index);
  }

  void toggleTouchpadMode() {
    state = state.copyWith(
      isTouchpadMode: !state.isTouchpadMode,
      lastCommandStatus: !state.isTouchpadMode
          ? 'Dokunmatik Kaydırma (Touchpad) modu aktif'
          : 'Klasik D-Pad Kadran modu aktif',
    );
  }

  Future<void> scanNetworkForTvs({String? customIp}) async {
    final targetIp = (customIp != null && AdbTvService.isValidIp(customIp))
        ? customIp.trim()
        : state.selectedDevice.ip;

    state = state.copyWith(
      isScanning: true,
      lastCommandStatus: '$targetIp:5555 taranıyor...',
    );

    final service = ref.read(adbTvServiceProvider);
    final devices = await service.discoverDevices(preferredIp: targetIp);
    final selected = devices.firstWhere(
      (d) => d.ip == targetIp && d.isOnline,
      orElse: () => devices.firstWhere(
        (d) => d.isOnline,
        orElse: () => devices.first,
      ),
    );

    state = state.copyWith(
      isScanning: false,
      discoveredDevices: devices,
      selectedDevice: selected,
      lastCommandStatus: selected.isOnline
          ? 'Bağlandı: ${selected.name} (${selected.ip})'
          : (service.lastConnectRequiredPairingPrompt
                ? '🔐 TV ekranındaki "Hata ayıklamaya izin ver" onayını kabul edin (${selected.ip})'
                : 'Çevrimdışı / ADB Bekleniyor (${selected.ip})'),
    );
    await _persistState(triggerAutoBackup: false);
  }

  /// Initiates an interactive 18-second ADB RSA-2048 pairing handshake with the
  /// selected (or [customIp]) Android TV so the user can accept the on-screen
  /// debugging prompt on Sony, TCL, Xiaomi, Philips, Google TV, or Redline sets.
  Future<bool> pairWithSelectedTv({String? customIp}) async {
    final targetIp = (customIp != null && AdbTvService.isValidIp(customIp))
        ? customIp.trim()
        : state.selectedDevice.ip;

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Android TV ($targetIp)',
            ip: targetIp,
            port: 5555,
            boardInfo: 'Android TV • Eşleştiriliyor...',
            isOnline: false,
          );

    state = state.copyWith(
      isScanning: true,
      selectedDevice: candidate,
      lastCommandStatus:
          '🔐 TV ekranındaki "Hata ayıklamaya izin ver" onayını kabul edin...',
    );

    final service = ref.read(adbTvServiceProvider);
    final pairedDevice = await service.pairWithTv(candidate);

    final updatedList = <TvDevice>[
      pairedDevice,
      ...state.discoveredDevices.where((d) => d.ip != pairedDevice.ip),
    ];

    state = state.copyWith(
      isScanning: false,
      selectedDevice: pairedDevice,
      discoveredDevices: updatedList,
      lastCommandStatus: pairedDevice.isOnline
          ? '✓ Eşleşti ve Bağlandı: ${pairedDevice.name} (${pairedDevice.ip})'
          : '⚠️ Eşleştirme tamamlanamadı: ${pairedDevice.boardInfo}',
    );
    await _persistState(triggerAutoBackup: false);
    return pairedDevice.isOnline;
  }

  /// Pairs with a standard retail Android TV / Google TV over Port 6466/6467
  /// using the 6-digit PIN displayed on the TV screen (Zero-Config mode).
  Future<bool> pairWithSelectedTvPin6466(
    String sixDigitPin, {
    String? customIp,
  }) async {
    final targetIp = (customIp != null && AdbTvService.isValidIp(customIp))
        ? customIp.trim()
        : state.selectedDevice.ip;

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Google TV ($targetIp)',
            ip: targetIp,
            port: 6466,
            protocol: TvConnectionProtocol.remotePort6466,
            boardInfo: 'Google TV • PIN Eşleştiriliyor...',
            isOnline: false,
          );

    state = state.copyWith(
      isScanning: true,
      selectedDevice: candidate,
      lastCommandStatus:
          '🔢 Port 6466 üzerinden 6 haneli PIN doğrulanıyor ($targetIp)...',
    );

    final service = ref.read(adbTvServiceProvider);
    final pairedDevice = await service.pairWithPin6466(candidate, sixDigitPin);

    final updatedList = <TvDevice>[
      pairedDevice,
      ...state.discoveredDevices.where((d) => d.ip != pairedDevice.ip),
    ];

    state = state.copyWith(
      isScanning: false,
      selectedDevice: pairedDevice,
      discoveredDevices: updatedList,
      lastCommandStatus: pairedDevice.isPaired
          ? '✓ PIN Eşleşti (Port 6466): ${pairedDevice.name} (${pairedDevice.ip})'
          : '⚠️ PIN Eşleştirme hatası: ${pairedDevice.boardInfo}',
    );
    await _persistState(triggerAutoBackup: false);
    return pairedDevice.isPaired;
  }

  // ===========================================================================
  // MONETIZATION: LIFETIME PRO IAP, 24H REWARDED PRO PASS & 40% LOYALTY DISCOUNT
  // ===========================================================================

  /// Unlocks a 24-hour "CueDeck Pro Pass" via a real Google AdMob Rewarded Video Ad
  /// (`RewardedAd.show` -> `onUserEarnedReward`) and increments the user's distinct-day
  /// loyalty counter toward the 40% discount.
  Future<MonetizationActionResult> unlockProPassWithRewardedAd({
    DateTime? now,
  }) async {
    final service = ref.read(cueMonetizationServiceProvider);
    final res = await service.watchRewardedAdAndUnlockProPass(
      current: state.entitlement,
      now: now,
    );
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  /// Resets the current 24h Pro Pass / Pro state back to the Free Ad-Supported state
  /// so the user can test Banner & Rewarded Video Ads anytime without waiting 24 hours.
  Future<MonetizationActionResult> resetProPassToFree() async {
    final service = ref.read(cueMonetizationServiceProvider);
    final res = await service.resetEntitlementToFree(
      current: state.entitlement,
    );
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  /// Completes the one-time Lifetime Pro purchase (`cuedeck_pro_lifetime` or `cuedeck_pro_loyalty_40`).
  Future<MonetizationActionResult> purchaseLifetimePro({DateTime? now}) async {
    final service = ref.read(cueMonetizationServiceProvider);
    final res = await service.purchaseLifetimePro(
      current: state.entitlement,
      now: now,
    );
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  /// Restores any previously purchased Lifetime Pro entitlement.
  Future<MonetizationActionResult> restoreProPurchases() async {
    final service = ref.read(cueMonetizationServiceProvider);
    final res = await service.restorePurchases(current: state.entitlement);
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  void selectDevice(TvDevice device) {
    state = state.copyWith(
      selectedDevice: device,
      lastCommandStatus: 'Aktif TV: ${device.name} (${device.ip})',
    );
    _persistState();
  }

  Future<void> sendRemoteKey(TvKeyCommand command) async {
    _highlightResetTimer?.cancel();
    state = state.copyWith(
      lastPressedDirection: command,
      lastCommandStatus: 'Komut gönderildi: ${command.label}',
    );
    _highlightResetTimer = Timer(const Duration(milliseconds: 220), () {
      state = state.copyWith(clearPressedDirection: true);
    });

    final service = ref.read(adbTvServiceProvider);
    final ok = await service.sendKeyCommand(state.selectedDevice, command);
    state = state.copyWith(
      selectedDevice: state.selectedDevice.copyWith(isOnline: ok),
      lastCommandStatus: ok
          ? '✓ TV: ${command.label} (${state.selectedDevice.ip})'
          : '⚡ Komut kuyruğa alındı: ${command.label}',
    );
  }

  /// Listens to the phone's microphone via native speech recognizer and executes
  /// the spoken command or YouTube search directly on the TV.
  Future<void> startVoiceCommandSession() async {
    if (state.isListeningVoice) return;
    state = state.copyWith(
      isListeningVoice: true,
      lastCommandStatus: '🎙️ Telefon mikrofonu dinleniyor... Lütfen konuşun',
    );

    final service = ref.read(adbTvServiceProvider);
    final transcript = await service.listenPhoneMicrophone();

    if (transcript == null || transcript.trim().isEmpty) {
      state = state.copyWith(
        isListeningVoice: false,
        lastCommandStatus:
            '🎙️ Sesli komut iptal edildi veya ses algılanamadı',
      );
      return;
    }

    state = state.copyWith(
      isListeningVoice: false,
      lastVoiceTranscript: transcript,
    );
    await runVoiceTranscript(transcript);
  }

  /// Executes a spoken or preset voice transcript on the TV.
  Future<void> runVoiceTranscript(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty) return;

    state = state.copyWith(
      lastVoiceTranscript: cleaned,
      lastCommandStatus: '🎙️ İşleniyor: "$cleaned"...',
    );

    final service = ref.read(adbTvServiceProvider);
    final statusMsg = await service.executeVoiceCommand(
      state.selectedDevice,
      cleaned,
    );

    state = state.copyWith(
      selectedDevice: state.selectedDevice.copyWith(
        isOnline: statusMsg.startsWith('🎙️'),
      ),
      lastCommandStatus: statusMsg,
    );
  }

  /// Triggers the TV's native Google Assistant / Voice Search overlay (`KEYCODE_VOICE_ASSIST`).
  Future<void> triggerTvNativeVoiceAssistant() async {
    await sendRemoteKey(TvKeyCommand.voiceAssist);
  }

  Future<void> launchPlatformApp(StreamingPlatform platform) async {
    state = state.copyWith(
      lastCommandStatus: '${platform.label} TV ekranında açılıyor...',
    );
    final service = ref.read(adbTvServiceProvider);
    final ok = await service.launchPlatformOrDeepLink(
      state.selectedDevice,
      platform: platform,
    );
    state = state.copyWith(
      selectedDevice: state.selectedDevice.copyWith(isOnline: ok),
      lastCommandStatus: ok
          ? '✓ TV\'de Açıldı: ${platform.label}'
          : '⚡ ${platform.label} başlatma sinyali gönderildi',
    );
  }

  /// Launches a planned watch item directly on the TV (with deep-link URL if set)
  /// and activates its live checkpoint tracker.
  Future<void> beamCueToTv(WatchCueItem item) async {
    state = state.copyWith(
      activePlayingCueId: item.id,
      clearReminder: state.activeReminderItem?.id == item.id,
      lastCommandStatus:
          '🎬 TV\'de Başlatılıyor: ${item.title} (${item.watchedMinutes}. dk)',
    );

    final service = ref.read(adbTvServiceProvider);
    final ok = await service.launchPlatformOrDeepLink(
      state.selectedDevice,
      platform: item.platform,
      deepLinkUrl: item.deepLinkUrl,
      fallbackSearchQuery: item.title,
    );

    state = state.copyWith(
      selectedDevice: state.selectedDevice.copyWith(isOnline: ok),
      lastCommandStatus: ok
          ? '✓ TV\'de Oynatılıyor: ${item.title} • %${item.progressPercent}'
          : '🎬 İzleme Takibi Aktif: ${item.title} (${item.watchedMinutes}. dk)',
    );
  }

  Future<void> sendKeyboardText(String text) async {
    if (text.trim().isEmpty) return;
    final service = ref.read(adbTvServiceProvider);
    final ok = await service.sendSearchText(state.selectedDevice, text);
    state = state.copyWith(
      lastCommandStatus: ok
          ? '✓ TV\'ye metin yazıldı: "${text.trim()}"'
          : 'Metin gönderildi: "${text.trim()}"',
    );
  }

  void stepProgress(String id, int deltaMinutes) {
    final updated = state.cueItems.map((item) {
      if (item.id != id) return item;
      final nextMins =
          (item.watchedMinutes + deltaMinutes).clamp(0, item.totalMinutes);
      return item.copyWith(watchedMinutes: nextMins);
    }).toList();

    state = state.copyWith(
      cueItems: updated,
      lastCommandStatus:
          'İlerleme güncellendi (${deltaMinutes > 0 ? "+$deltaMinutes" : "$deltaMinutes"} dk)',
    );
    _persistState();
  }

  void updateWatchedProgress(String id, int deltaMinutes) {
    stepProgress(id, deltaMinutes);
  }

  void incrementEpisode(String id, {int delta = 1}) {
    final updated = state.cueItems.map((item) {
      if (item.id != id) return item;
      final nextEp = (item.currentEpisode + delta).clamp(1, item.totalEpisodes);
      return item.copyWith(currentEpisode: nextEp);
    }).toList();
    state = state.copyWith(cueItems: updated);
    _persistState();
  }

  void toggleReminder(String id) {
    final updated = state.cueItems.map((item) {
      if (item.id != id) return item;
      return item.copyWith(reminderFired: !item.reminderFired);
    }).toList();
    state = state.copyWith(cueItems: updated);
    _persistState();
  }

  /// Advances a planned watch item by one planned session (`item.sessionMinutes`)
  /// and increments the episode/video counter when applicable.
  void completeSessionStep(String id) {
    final updated = state.cueItems.map((item) {
      if (item.id != id) return item;
      final nextMins = (item.watchedMinutes + item.sessionMinutes).clamp(
        0,
        item.totalMinutes,
      );
      final nextEp = item.totalEpisodes > 1
          ? (item.currentEpisode + 1).clamp(1, item.totalEpisodes)
          : item.currentEpisode;
      return item.copyWith(
        watchedMinutes: nextMins,
        currentEpisode: nextEp,
      );
    }).toList();

    state = state.copyWith(
      cueItems: updated,
      lastCommandStatus: '✓ Günlük seans tamamlandı, ilerleme kaydedildi',
    );
    _persistState();
  }

  void updateProgress(
    String id, {
    int? watchedMinutes,
    int? currentEpisode,
  }) {
    final updated = state.cueItems.map((item) {
      if (item.id != id) return item;
      final nextMins = watchedMinutes != null
          ? watchedMinutes.clamp(0, item.totalMinutes)
          : item.watchedMinutes;
      final nextEp = currentEpisode != null
          ? currentEpisode.clamp(1, item.totalEpisodes)
          : item.currentEpisode;
      return item.copyWith(
        watchedMinutes: nextMins,
        currentEpisode: nextEp,
      );
    }).toList();

    state = state.copyWith(cueItems: updated);
    _persistState();
  }

  void addWatchCue(WatchCueItem item) {
    final updated = <WatchCueItem>[item, ...state.cueItems];
    state = state.copyWith(
      cueItems: updated,
      activePlayingCueId: item.id,
      lastCommandStatus:
          '✓ Plan eklendi: ${item.title} (${item.formattedClock} • ${item.recurrenceSummary})',
    );
    unawaited(ref.read(cueNotificationServiceProvider).requestPermission());
    _persistState();
  }

  void updateWatchCue(WatchCueItem updatedItem) {
    final updated = state.cueItems.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
    state = state.copyWith(
      cueItems: updated,
      lastCommandStatus:
          '✓ Plan güncellendi: ${updatedItem.title} (${updatedItem.formattedClock} • ${updatedItem.recurrenceSummary})',
    );
    unawaited(ref.read(cueNotificationServiceProvider).requestPermission());
    _persistState();
  }

  void deleteWatchCue(String id) {
    final updated = state.cueItems.where((e) => e.id != id).toList();
    state = state.copyWith(
      cueItems: updated,
      clearActivePlayingCue: state.activePlayingCueId == id,
      lastCommandStatus: 'İzleme planı silindi',
    );
    _persistState();
  }

  Future<void> triggerTestReminder(WatchCueItem item) async {
    state = state.copyWith(
      activeReminderItem: item,
      lastCommandStatus:
          '🔔 Bildirim gönderildi: "${item.title}" (${item.platform.label}) başlama zamanı! (%${item.progressPercent} tamamlandı)',
    );
    await ref
        .read(cueNotificationServiceProvider)
        .showReminderNotification(item, isLeadReminder: false);
  }

  void dismissReminder() {
    state = state.copyWith(clearReminder: true);
  }
}
