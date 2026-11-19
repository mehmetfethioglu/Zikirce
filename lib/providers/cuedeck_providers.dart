import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tv_network_validators.dart';
import '../models/cue_models.dart';
import '../services/adb_tv_service.dart';
import '../services/cue_monetization_service.dart';
import '../services/cue_notification_service.dart';
import '../services/cue_release_notes_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/share/cue_share_intent_service.dart';
import 'cue_deck_state.dart';

export '../domain/tv_driver_contract.dart' show TvCapability;
export '../domain/tv_network_validators.dart' show TvNetworkValidators;
export '../services/cue_monetization_service.dart'
    show
        CueAdMobConfig,
        CueProProductCatalog,
        CueEntitlementState,
        MonetizationActionResult;
export '../services/cue_release_notes_service.dart'
    show
        CueReleaseNotesCatalog,
        CueReleaseVersionEntry,
        CueReleaseNoteItem,
        CueReleaseNotesService;
export '../services/drivers/ir_blaster_driver.dart'
    show IrBlasterDriver, IrBrandProfile;
export '../services/drivers/tv_quirks_registry.dart'
    show TvQuirkProfile, TvQuirksRegistry;
export '../services/google_drive_backup_service.dart'
    show CloudBackupInfo, BackupOperationResult;
export '../services/google_oauth_sheet.dart'
    show GoogleOAuthConstants, GoogleOAuthHelper;
export 'cue_deck_state.dart';

const String _kPrefsCueItemsKey = 'cuedeck_watch_items_v1';
const String _kPrefsTvDeviceV2Key = 'cuedeck_tv_device_v2';
const String _kPrefsDarkModeKey = 'cuedeck_dark_mode_v1';
const String _kPrefsRemoteShortcutsKey = 'cuedeck_remote_shortcuts_v1';

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

final cueShareIntentServiceProvider = Provider<CueShareIntentService>((ref) {
  return CueShareIntentService();
});

final cueReleaseNotesServiceProvider = Provider<CueReleaseNotesService>((ref) {
  return const CueReleaseNotesService();
});

final cueDeckProvider = NotifierProvider<CueDeckNotifier, CueDeckState>(
  CueDeckNotifier.new,
);

class CueDeckNotifier extends Notifier<CueDeckState> {
  Timer? _schedulerTimer;
  Timer? _highlightResetTimer;
  Timer? _autoBackupDebounceTimer;
  Timer? _initialRetryTimer;
  Timer? _mouseMoveBatchTimer;
  Timer? _mouseWheelBatchTimer;
  double _pendingMouseDx = 0;
  double _pendingMouseDy = 0;
  double _pendingWheelDeltaY = 0;
  bool _isSendingMouseMove = false;
  bool _isSendingWheelScroll = false;
  bool _healingConnection = false;

  @override
  CueDeckState build() {
    ref.onDispose(() {
      _schedulerTimer?.cancel();
      _highlightResetTimer?.cancel();
      _autoBackupDebounceTimer?.cancel();
      _initialRetryTimer?.cancel();
      _mouseMoveBatchTimer?.cancel();
      _mouseWheelBatchTimer?.cancel();
    });

    final now = DateTime.now();
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
      selectedDevice: TvDevice.unconfigured,
      discoveredDevices: const <TvDevice>[],
      isScanning: false,
      isTouchpadMode: false,
      lastPressedDirection: null,
      lastCommandStatus: 'Ağdaki TV cihazları aranıyor...',
      cueItems: defaultCues,
      activePlayingCueId: 'cue_yt_playlist_1',
    );
  }

  Future<void> _initializeAsync() async {
    await _loadPersistedState();
    if (!ref.mounted) return;
    unawaited(ref.read(adbTvServiceProvider).quirksRegistry.loadCachedOverrides());
    await ref.read(cueNotificationServiceProvider).requestPermission();
    if (!ref.mounted) return;
    await _syncNativeNotifications();
    if (!ref.mounted) return;

    final loadedEntitlement =
        await ref.read(cueMonetizationServiceProvider).loadEntitlement();
    if (!ref.mounted) return;
    final hasIr =
        await ref.read(adbTvServiceProvider).hasIrBlasterHardware();
    if (!ref.mounted) return;
    state = state.copyWith(
      entitlement: loadedEntitlement,
      hasIrEmitter: hasIr,
    );

    final shareSvc = ref.read(cueShareIntentServiceProvider);
    shareSvc.listenForIncomingShares((SharedCuePayload payload) {
      if (!ref.mounted) return;
      state = state.copyWith(
        pendingSharedPayload: payload,
        lastCommandStatus: '📲 Paylaşılan içerik hazır: ${payload.title}',
      );
    });
    final initialShare = await shareSvc.consumeInitialSharedPayload();
    if (!ref.mounted) return;
    if (initialShare != null) {
      state = state.copyWith(
        pendingSharedPayload: initialShare,
        lastCommandStatus: '📲 Paylaşılan içerik hazır: ${initialShare.title}',
      );
    }

    await refreshGoogleDriveStatus();
    if (!ref.mounted) return;
    _startScheduleMonitor();
    await scanNetworkForTvs();
    if (!ref.mounted) return;
    if (!state.selectedDevice.isOnline && !state.selectedDevice.isIrBlaster) {
      _initialRetryTimer?.cancel();
      _initialRetryTimer = Timer(const Duration(seconds: 4), () {
        if (!ref.mounted) return;
        if (!state.selectedDevice.isOnline &&
            !state.selectedDevice.isIrBlaster &&
            !state.isScanning) {
          scanNetworkForTvs();
        }
      });
    }
  }

  Future<void> _syncNativeNotifications() async {
    if (!ref.mounted) return;
    final items = state.cueItems;
    await ref
        .read(cueNotificationServiceProvider)
        .syncScheduledReminders(items);
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
      _persistState(triggerAutoBackup: false);
    }

    if (!Platform.environment.containsKey('FLUTTER_TEST') &&
        state.selectedDevice.hasValidIp &&
        !state.selectedDevice.isIrBlaster &&
        !state.selectedDevice.isOnline &&
        !state.isScanning) {
      unawaited(healSelectedTvConnection(allowSubnetRescan: true));
    }
  }

  List<TvDevice> _mergeDeviceIntoDiscovered(TvDevice updated) {
    final others = state.discoveredDevices.where((d) => d.ip != updated.ip);
    return <TvDevice>[updated, ...others];
  }

  /// Silently verifies the selected TV socket/port, restores dropped connections,
  /// upgrades DIAL/UPnP endpoints if a native protocol responds, and optionally
  /// rescans the local subnet if the TV changed IP.
  Future<bool> healSelectedTvConnection({bool allowSubnetRescan = false}) async {
    if (_healingConnection || state.isScanning) {
      return state.selectedDevice.isOnline;
    }
    final current = state.selectedDevice;
    if (!current.hasValidIp || current.isIrBlaster) return current.isOnline;

    _healingConnection = true;
    try {
      final service = ref.read(adbTvServiceProvider);
      final refreshed = await service.verifyOrReconnectDevice(current);
      if (!ref.mounted) return false;
      if (refreshed.isOnline) {
        final protocolUpgraded = refreshed.port != current.port ||
            refreshed.protocol != current.protocol;
        state = state.copyWith(
          selectedDevice: refreshed,
          discoveredDevices: _mergeDeviceIntoDiscovered(refreshed),
          lastCommandStatus: protocolUpgraded
              ? '✓ Bağlantı iyileştirildi: ${refreshed.name} (${refreshed.displayEndpoint})'
              : state.lastCommandStatus,
        );
        if (protocolUpgraded) {
          unawaited(_persistState(triggerAutoBackup: false));
        }
        return true;
      }

      if (allowSubnetRescan &&
          !Platform.environment.containsKey('FLUTTER_TEST')) {
        final discovered = await service.discoverDevices(preferredIp: current.ip);
        if (!ref.mounted) return false;
        if (discovered.isNotEmpty) {
          TvDevice? rebound;
          if (current.macAddress.trim().isNotEmpty) {
            final cleanMac = current.macAddress.trim().toLowerCase();
            for (final d in discovered) {
              if (d.macAddress.trim().toLowerCase() == cleanMac && d.isOnline) {
                rebound = d;
                break;
              }
            }
          }
          if (rebound == null && current.name.trim().isNotEmpty) {
            final cleanName = current.name.trim().toLowerCase();
            for (final d in discovered) {
              if (d.name.trim().toLowerCase() == cleanName && d.isOnline) {
                rebound = d;
                break;
              }
            }
          }
          if (rebound == null) {
            final onlineOnes = discovered.where((d) => d.isOnline).toList();
            if (onlineOnes.length == 1) {
              rebound = onlineOnes.first;
            }
          }
          if (rebound != null) {
            state = state.copyWith(
              selectedDevice: rebound,
              discoveredDevices: discovered,
              lastCommandStatus:
                  '✓ TV bağlantısı yenilendi: ${rebound.name} (${rebound.displayEndpoint})',
            );
            await _persistState(triggerAutoBackup: false);
            return true;
          }
        }
      }

      if (!ref.mounted) return false;
      if (state.selectedDevice.isOnline) {
        state = state.copyWith(
          selectedDevice: state.selectedDevice.copyWith(isOnline: false),
        );
      }
      return false;
    } finally {
      _healingConnection = false;
    }
  }

  /// Warms up / restores active TV connection when the phone resumes from sleep.
  Future<void> onAppResumed() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    await healSelectedTvConnection(allowSubnetRescan: true);
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceRaw = prefs.getString(_kPrefsTvDeviceV2Key);
      final savedDark = prefs.getBool(_kPrefsDarkModeKey);
      final rawJson = prefs.getString(_kPrefsCueItemsKey);
      final savedShortcuts = prefs.getStringList(_kPrefsRemoteShortcutsKey);

      TvDevice? loadedDevice;
      if (savedDeviceRaw != null && savedDeviceRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedDeviceRaw);
          if (decoded is Map<String, dynamic>) {
            final parsed = TvDevice.fromJson(decoded);
            if (parsed.hasControlTarget) {
              if (parsed.isPaired &&
                  parsed.protocol == TvConnectionProtocol.remotePort6466) {
                ref.read(adbTvServiceProvider).markPinPairedIp(parsed.ip);
              }
              loadedDevice = parsed.isIrBlaster
                  ? parsed.copyWith(isOnline: true, isPaired: true)
                  : parsed.copyWith(isOnline: false);
            }
          }
        } catch (e) {
          debugPrint('CueDeckNotifier parse saved device err: $e');
        }
      }

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
        selectedDevice: loadedDevice ?? state.selectedDevice,
        cueItems: (loadedItems != null && loadedItems.isNotEmpty)
            ? loadedItems
            : state.cueItems,
        remoteShortcuts: loadedShortcuts ?? state.remoteShortcuts,
      );
    } catch (e) {
      debugPrint('CueDeckNotifier loadPersistedState skipped: $e');
    }
  }

  Future<void> _persistState({bool triggerAutoBackup = true}) async {
    if (!ref.mounted) return;
    final currentDevice = state.selectedDevice;
    final currentDark = state.isDarkMode;
    final currentShortcuts = state.remoteShortcuts;
    final currentItems = state.cueItems;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (currentDevice.hasControlTarget) {
        await prefs.setString(
          _kPrefsTvDeviceV2Key,
          jsonEncode(currentDevice.toJson()),
        );
      } else {
        await prefs.remove(_kPrefsTvDeviceV2Key);
      }
      await prefs.setBool(_kPrefsDarkModeKey, currentDark);
      await prefs.setStringList(
        _kPrefsRemoteShortcutsKey,
        currentShortcuts.map((e) => e.name).toList(growable: false),
      );
      final encoded = jsonEncode(
        currentItems.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_kPrefsCueItemsKey, encoded);
    } catch (e) {
      debugPrint('CueDeckNotifier persistState skipped: $e');
    }
    if (!ref.mounted) return;
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
    } catch (e) {
      debugPrint('CueDeckNotifier refreshGoogleDriveStatus skipped: $e');
    }
  }

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

  Future<List<CloudBackupInfo>> fetchAvailableBackups() async {
    final backupService = ref.read(googleDriveBackupServiceProvider);
    return backupService.listCloudBackups();
  }

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
        selectedDevice:
            (restoredIp != null && TvNetworkValidators.isValidIp(restoredIp))
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
        selectedDevice:
            (restoredIp != null && TvNetworkValidators.isValidIp(restoredIp))
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
    final nextMode = !state.isTouchpadMode;
    state = state.copyWith(
      isTouchpadMode: nextMode,
      lastCommandStatus: nextMode
          ? '🖱️ TV Mouse Oku & Touchpad modu aktif'
          : 'Klasik D-Pad Kadran modu aktif',
    );
    final device = state.selectedDevice;
    if (device.hasValidIp) {
      final service = ref.read(adbTvServiceProvider);
      if (nextMode) {
        unawaited(service.enableTvMouseCursor(device));
      } else {
        unawaited(service.disableTvMouseCursor(device));
      }
    }
  }

  void moveTouchpadCursor(double dx, double dy) {
    _pendingMouseDx += dx;
    _pendingMouseDy += dy;
    if (_mouseMoveBatchTimer?.isActive ?? false) return;
    _mouseMoveBatchTimer = Timer(
      const Duration(milliseconds: 42),
      _flushPendingMouseMove,
    );
  }

  Future<void> _flushPendingMouseMove() async {
    if (_isSendingMouseMove) return;
    final dx = _pendingMouseDx;
    final dy = _pendingMouseDy;
    if (dx.abs() < 0.8 && dy.abs() < 0.8) return;
    _pendingMouseDx = 0;
    _pendingMouseDy = 0;

    final device = state.selectedDevice;
    if (!device.hasControlTarget) return;
    _isSendingMouseMove = true;
    try {
      await ref.read(adbTvServiceProvider).moveTvMouseCursor(device, dx, dy);
    } finally {
      _isSendingMouseMove = false;
      if (_pendingMouseDx.abs() >= 1.5 || _pendingMouseDy.abs() >= 1.5) {
        unawaited(_flushPendingMouseMove());
      }
    }
  }

  Future<void> clickTouchpadCursor({bool rightClick = false}) async {
    final device = state.selectedDevice;
    final ok = await ref
        .read(adbTvServiceProvider)
        .clickTvMouseCursor(device, rightClick: rightClick);
    state = state.copyWith(
      selectedDevice: device.copyWith(isOnline: ok),
      lastCommandStatus: rightClick
          ? '🖱️ TV Sağ Tık (Geri) gönderildi'
          : '🖱️ TV Mouse Sol Tık (Seç) gönderildi',
    );
  }

  void scrollTouchpadWheelByDelta(double deltaY) {
    _pendingWheelDeltaY += deltaY;
    if (_mouseWheelBatchTimer?.isActive ?? false) return;
    _mouseWheelBatchTimer = Timer(
      const Duration(milliseconds: 48),
      _flushPendingWheelScroll,
    );
  }

  Future<void> _flushPendingWheelScroll() async {
    if (_isSendingWheelScroll) return;
    const double pixelsPerNotch = 16.0;
    if (_pendingWheelDeltaY.abs() < pixelsPerNotch) return;

    final int notches = (_pendingWheelDeltaY / pixelsPerNotch).truncate();
    if (notches == 0) return;
    _pendingWheelDeltaY -= notches * pixelsPerNotch;

    final int wheelClicks = (-notches).clamp(-6, 6);
    final device = state.selectedDevice;
    if (!device.hasControlTarget) return;

    _isSendingWheelScroll = true;
    try {
      await ref
          .read(adbTvServiceProvider)
          .scrollTvMouseWheel(device, wheelClicks);
    } finally {
      _isSendingWheelScroll = false;
      if (_pendingWheelDeltaY.abs() >= pixelsPerNotch) {
        unawaited(_flushPendingWheelScroll());
      }
    }
  }

  Future<void> scrollTouchpadWheelSteps(int wheelClicks) async {
    if (wheelClicks == 0) return;
    final device = state.selectedDevice;
    final ok = await ref
        .read(adbTvServiceProvider)
        .scrollTvMouseWheel(device, wheelClicks);
    state = state.copyWith(
      selectedDevice: device.copyWith(isOnline: ok),
      lastCommandStatus: wheelClicks > 0
          ? '🖱️ Mouse Tekerlek Yukarı kaydırıldı'
          : '🖱️ Mouse Tekerlek Aşağı kaydırıldı',
    );
  }

  Future<void> scanNetworkForTvs({String? customIp}) async {
    final cleanCustom = customIp?.trim() ?? '';
    final hasCustomIp = TvNetworkValidators.isValidIp(cleanCustom);
    final targetIp = hasCustomIp
        ? cleanCustom
        : (state.selectedDevice.hasValidIp ? state.selectedDevice.ip : '');

    state = state.copyWith(
      isScanning: true,
      lastCommandStatus: targetIp.isNotEmpty
          ? '$targetIp ve yerel Wi-Fi ağı taranıyor...'
          : 'Yerel Wi-Fi ağındaki akıllı TV\'ler taranıyor...',
    );

    final service = ref.read(adbTvServiceProvider);
    final devices = await service.discoverDevices(preferredIp: targetIp);
    if (!ref.mounted) return;

    TvDevice selected;
    if (devices.isNotEmpty) {
      selected = devices.firstWhere(
        (d) => targetIp.isNotEmpty && d.ip == targetIp && d.isOnline,
        orElse: () => devices.firstWhere(
          (d) => d.isOnline,
          orElse: () => devices.firstWhere(
            (d) => targetIp.isNotEmpty && d.ip == targetIp,
            orElse: () => devices.first,
          ),
        ),
      );
    } else if (hasCustomIp) {
      selected = TvDevice(
        name: 'Akıllı TV ($cleanCustom)',
        ip: cleanCustom,
        port: 5555,
        boardInfo: 'Ağda yanıt alınamadı • TV\'nin açık olduğundan emin olun',
        isOnline: false,
      );
    } else if (state.selectedDevice.hasControlTarget) {
      selected = state.selectedDevice.isIrBlaster
          ? state.selectedDevice
          : state.selectedDevice.copyWith(isOnline: false);
    } else {
      selected = TvDevice.unconfigured;
    }

    final statusMessage = selected.isIrBlaster
        ? '📡 Kızılötesi (IR) Aktif: ${selected.name}'
        : (selected.isOnline
              ? 'Bağlandı: ${selected.name} (${selected.ip}:${selected.port})'
              : (service.localNetworkPermissionDenied
                    ? '⚠️ iPhone "Yerel Ağ" izni kapalı! Ayarlar > CueDeck > Yerel Ağ iznini açın.'
                    : (service.lastConnectRequiredPairingPrompt &&
                              selected.hasValidIp
                          ? '🔐 TV ekranındaki "Hata ayıklamaya izin ver" onayını kabul edin (${selected.ip})'
                          : (devices.isEmpty
                                ? 'Ağda açık TV bulunamadı — TV\'nin aynı Wi-Fi ağında olduğundan emin olun'
                                : '${devices.length} TV bulundu — bağlanmak için listeden seçin'))));

    state = state.copyWith(
      isScanning: false,
      discoveredDevices: devices,
      selectedDevice: selected,
      localWifiIp: service.detectedWifiIp,
      localNetworkPermissionDenied: service.localNetworkPermissionDenied,
      lastCommandStatus: statusMessage,
    );
    await _persistState(triggerAutoBackup: false);

    if (!Platform.environment.containsKey('FLUTTER_TEST') &&
        selected.isOnline &&
        !selected.isPaired &&
        (selected.protocol == TvConnectionProtocol.samsungTizen8001 ||
            selected.protocol == TvConnectionProtocol.lgWebOs3000)) {
      unawaited(() async {
        final warmed = await service.pairWithTv(selected);
        if (!ref.mounted) return;
        if (warmed.isOnline && warmed.isPaired) {
          state = state.copyWith(
            selectedDevice: warmed,
            discoveredDevices: _mergeDeviceIntoDiscovered(warmed),
          );
          await _persistState(triggerAutoBackup: false);
        }
      }());
    }
  }

  void disconnectCurrentTv() {
    state = state.copyWith(
      selectedDevice: TvDevice.unconfigured,
      lastCommandStatus:
          'TV bağlantısı sıfırlandı — ağdaki cihazları arayın veya listeden TV seçin',
    );
    unawaited(_persistState(triggerAutoBackup: false));
  }

  /// Activates a zero-Wi-Fi Infrared Blaster profile for [brandCode].
  Future<void> activateIrBlasterBrand(String brandCode) async {
    final service = ref.read(adbTvServiceProvider);
    final irDevice = await service.pairIrBlasterDevice(brandCode);
    state = state.copyWith(
      selectedDevice: irDevice,
      lastCommandStatus: '📡 Kızılötesi Modu Aktif: ${irDevice.name}',
    );
    await _persistState(triggerAutoBackup: false);
  }

  /// Sends a Wake-on-LAN UDP magic packet to the selected TV's MAC address.
  Future<bool> wakeUpSelectedTv() async {
    final device = state.selectedDevice;
    final ok = await ref.read(adbTvServiceProvider).wakeUpTv(device);
    state = state.copyWith(
      lastCommandStatus: ok
          ? '⚡ TV uyandırma (Wake-on-LAN) paketi gönderildi'
          : '⚠️ TV uyandırma için geçerli MAC adresi bulunamadı',
    );
    return ok;
  }

  /// Generates a full diagnostic report for the currently selected TV.
  Future<String> generateConnectionDiagnosticReport() {
    return ref.read(adbTvServiceProvider).buildConnectionDiagnosticReport(
          state.selectedDevice,
          appVersion: CueReleaseNotesCatalog.currentVersion,
        );
  }

  /// Generates a Zero-PII compatibility report (strips LAN IP, MAC, and personal names).
  Future<String> generateAnonymizedCompatibilityReport() {
    return ref.read(adbTvServiceProvider).buildAnonymizedCompatibilityReport(
          state.selectedDevice,
          appVersion: CueReleaseNotesCatalog.currentVersion,
        );
  }

  /// Returns ranked alternative protocol/port profiles for troubleshooting OEM chassis quirks.
  List<TvQuirkProfile> getSuggestedAlternativeProfiles() {
    return ref
        .read(adbTvServiceProvider)
        .quirksRegistry
        .suggestedAlternativeProfiles(state.selectedDevice);
  }

  /// Manually switches the active TV's control protocol/port profile without losing TV identity.
  Future<bool> switchTvProtocolProfile(TvQuirkProfile profile) async {
    final current = state.selectedDevice;
    if (!current.hasValidIp) {
      state = state.copyWith(
        lastCommandStatus: '⚠️ Profil değiştirmek için önce bir TV seçin veya IP girin',
      );
      return false;
    }

    final needsExplicitAuth =
        profile.protocol == TvConnectionProtocol.adbPort5555 ||
        profile.protocol == TvConnectionProtocol.remotePort6466 ||
        profile.protocol == TvConnectionProtocol.samsungTizen8001 ||
        profile.protocol == TvConnectionProtocol.lgWebOs3000 ||
        profile.protocol == TvConnectionProtocol.philipsJointSpace1925 ||
        profile.protocol == TvConnectionProtocol.vidaaSmart36669 ||
        profile.protocol == TvConnectionProtocol.sonyBraviaIrcc;

    final updated = current.copyWith(
      protocol: profile.protocol,
      port: profile.port,
      isPaired: profile.protocol == current.protocol
          ? current.isPaired
          : !needsExplicitAuth,
      isOnline: true,
      boardInfo: '${profile.label} • ${profile.subtitle}',
    );

    state = state.copyWith(
      selectedDevice: updated,
      discoveredDevices: _mergeDeviceIntoDiscovered(updated),
      lastCommandStatus:
          '✓ Alternatif profil seçildi: ${profile.label} (Port ${profile.port})',
    );
    await _persistState(triggerAutoBackup: false);
    return true;
  }

  Future<bool> connectAndPairDevice(TvDevice device) async {
    if (device.isIrBlaster) {
      await activateIrBlasterBrand(device.irBrandCode);
      return true;
    }
    if (!device.hasValidIp) return false;
    state = state.copyWith(
      isScanning: true,
      selectedDevice: device,
      lastCommandStatus:
          '🔌 Bağlanılıyor: ${device.name} (${device.ip}:${device.port})...',
    );

    final service = ref.read(adbTvServiceProvider);

    // Interactive handshake for Samsung Tizen (8002 token), LG webOS (client-key), Philips v6, VIDAA, Sony IRCC
    if (device.protocol == TvConnectionProtocol.samsungTizen8001 ||
        device.protocol == TvConnectionProtocol.lgWebOs3000 ||
        device.protocol == TvConnectionProtocol.philipsJointSpace1925 ||
        device.protocol == TvConnectionProtocol.vidaaSmart36669 ||
        device.protocol == TvConnectionProtocol.sonyBraviaIrcc) {
      final pairedSmart = await service.pairWithTv(device);
      final updatedList = <TvDevice>[
        pairedSmart,
        ...state.discoveredDevices.where((d) => d.ip != pairedSmart.ip),
      ];
      state = state.copyWith(
        isScanning: false,
        selectedDevice: pairedSmart,
        discoveredDevices: updatedList,
        lastCommandStatus: pairedSmart.isOnline
            ? '✓ Eşleşti ve Bağlandı: ${pairedSmart.name} (${pairedSmart.ip}:${pairedSmart.port})'
            : '⚠️ ${pairedSmart.boardInfo}',
      );
      await _persistState(triggerAutoBackup: false);
      return pairedSmart.isOnline;
    }

    if (device.protocol.isNonAndroidSmartTv) {
      final smartConnected = device.copyWith(isOnline: true, isPaired: true);
      final updatedList = <TvDevice>[
        smartConnected,
        ...state.discoveredDevices.where((d) => d.ip != smartConnected.ip),
      ];
      state = state.copyWith(
        isScanning: false,
        selectedDevice: smartConnected,
        discoveredDevices: updatedList,
        lastCommandStatus:
            '✓ Bağlandı: ${smartConnected.name} (${smartConnected.ip}:${smartConnected.port})',
      );
      await _persistState(triggerAutoBackup: false);
      return true;
    }

    if (device.protocol == TvConnectionProtocol.remotePort6466 &&
        device.port == 6466) {
      if (device.isPaired) {
        final updatedDevice = device.copyWith(
          isOnline: true,
          isPaired: true,
          boardInfo: 'Google TV • Port 6466 PIN Eşleşti ✓',
        );
        final updatedList = <TvDevice>[
          updatedDevice,
          ...state.discoveredDevices.where((d) => d.ip != updatedDevice.ip),
        ];
        state = state.copyWith(
          isScanning: false,
          selectedDevice: updatedDevice,
          discoveredDevices: updatedList,
          lastCommandStatus:
              '✓ Bağlandı: ${updatedDevice.name} (${updatedDevice.ip}:6466)',
        );
        await _persistState(triggerAutoBackup: false);
        return true;
      }

      final session = await service.startPin6467PairingSession(device);
      final adbOpen = session['adb5555Open'] == true;
      if (adbOpen) {
        final paired = await service.pairWithTv(
          device.copyWith(
            port: 5555,
            protocol: TvConnectionProtocol.adbPort5555,
          ),
        );
        final updatedList = <TvDevice>[
          paired,
          ...state.discoveredDevices.where((d) => d.ip != paired.ip),
        ];
        state = state.copyWith(
          isScanning: false,
          selectedDevice: paired,
          discoveredDevices: updatedList,
          lastCommandStatus: paired.isOnline
              ? '✓ Bağlandı: ${paired.name} (${paired.ip})'
              : '🔐 TV ekranındaki onayı kabul edin veya PIN ile eşleştirin',
        );
        await _persistState(triggerAutoBackup: false);
        return paired.isOnline;
      }

      final pinShown =
          session['pinDisplayed'] == true || session['pinTriggered'] == true;
      final updatedDevice = device.copyWith(
        isOnline: device.isPaired,
        boardInfo: pinShown
            ? 'TV ekranında 6 haneli PIN gösteriliyor • PIN girin'
            : device.boardInfo,
      );
      final updatedList = <TvDevice>[
        updatedDevice,
        ...state.discoveredDevices.where((d) => d.ip != updatedDevice.ip),
      ];
      state = state.copyWith(
        isScanning: false,
        selectedDevice: updatedDevice,
        discoveredDevices: updatedList,
        lastCommandStatus: pinShown
            ? '🔢 TV ekranındaki 6 haneli PIN kodunu girerek eşleştirmeyi tamamlayın'
            : 'Aktif TV: ${updatedDevice.name} (${updatedDevice.ip}:6466)',
      );
      await _persistState(triggerAutoBackup: false);
      return updatedDevice.isOnline;
    }

    final pairedDevice = await service.pairWithTv(device);
    final updatedList = <TvDevice>[
      pairedDevice,
      ...state.discoveredDevices.where((d) => d.ip != pairedDevice.ip),
    ];

    state = state.copyWith(
      isScanning: false,
      selectedDevice: pairedDevice,
      discoveredDevices: updatedList,
      lastCommandStatus: pairedDevice.isOnline
          ? '✓ Bağlandı: ${pairedDevice.name} (${pairedDevice.ip})'
          : '⚠️ Bağlantı bekleniyor: ${pairedDevice.boardInfo}',
    );
    await _persistState(triggerAutoBackup: false);
    return pairedDevice.isOnline;
  }

  Future<void> openIosLocalNetworkSettings() async {
    await ref.read(adbTvServiceProvider).openIosLocalNetworkSettings();
  }

  String _resolveTargetTvIp(String? customIp) {
    final cleanCustom = customIp?.trim() ?? '';
    if (TvNetworkValidators.isValidIp(cleanCustom)) return cleanCustom;
    if (state.selectedDevice.hasValidIp) return state.selectedDevice.ip;
    for (final d in state.discoveredDevices) {
      if (d.hasValidIp) return d.ip;
    }
    return '';
  }

  Future<bool> pairWithSelectedTv({String? customIp}) async {
    final targetIp = _resolveTargetTvIp(customIp);
    if (targetIp.isEmpty) {
      state = state.copyWith(
        lastCommandStatus:
            '⚠️ Önce "Ağdaki Cihazları Ara" ile TV seçin veya TV IP adresini girin',
      );
      return false;
    }

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Akıllı TV ($targetIp)',
            ip: targetIp,
            port: 5555,
            boardInfo: 'Android TV • Eşleştiriliyor...',
            isOnline: false,
          );

    state = state.copyWith(
      isScanning: true,
      selectedDevice: candidate,
      lastCommandStatus:
          '🔐 TV ekranındaki "Hata ayıklamaya izin ver" onayını kabul edin ($targetIp)...',
    );

    final pairedDevice = await ref.read(adbTvServiceProvider).pairWithTv(candidate);
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

  Future<Map<String, dynamic>> startPin6467Pairing({
    String? customIp,
    bool forceRestart = false,
  }) async {
    final targetIp = _resolveTargetTvIp(customIp);
    if (targetIp.isEmpty) {
      return const <String, dynamic>{
        'pinDisplayed': false,
        'adb5555Open': false,
        'message':
            'Önce "Ağdaki Cihazları Ara" ile TV seçin veya TV IP adresini girin.',
      };
    }

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Google TV ($targetIp)',
            ip: targetIp,
            port: 6466,
            protocol: TvConnectionProtocol.remotePort6466,
            boardInfo: 'Google TV • PIN İsteniyor...',
            isOnline: false,
          );

    final res = await ref.read(adbTvServiceProvider).startPin6467PairingSession(
          candidate,
          forceRestart: forceRestart,
        );
    final msg = (res['message'] as String?) ?? '';
    if (msg.isNotEmpty) {
      state = state.copyWith(lastCommandStatus: msg);
    }
    return res;
  }

  Future<bool> pairWithSelectedTvPin6466(
    String sixDigitPin, {
    String? customIp,
  }) async {
    final targetIp = _resolveTargetTvIp(customIp);
    if (targetIp.isEmpty) {
      state = state.copyWith(
        lastCommandStatus:
            '⚠️ Önce "Ağdaki Cihazları Ara" ile TV seçin veya TV IP adresini girin',
      );
      return false;
    }

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
      lastCommandStatus: '🔢 TV PIN kodu doğrulanıyor ($targetIp)...',
    );

    final pairedDevice = await ref
        .read(adbTvServiceProvider)
        .pairWithPin6466(candidate, sixDigitPin);
    final updatedList = <TvDevice>[
      pairedDevice,
      ...state.discoveredDevices.where((d) => d.ip != pairedDevice.ip),
    ];

    final ok = pairedDevice.isPaired || pairedDevice.isOnline;
    state = state.copyWith(
      isScanning: false,
      selectedDevice: pairedDevice,
      discoveredDevices: updatedList,
      lastCommandStatus: ok
          ? '✓ Eşleşti ve Bağlandı: ${pairedDevice.name} (${pairedDevice.ip})'
          : '⚠️ PIN Eşleştirme hatası: ${pairedDevice.boardInfo}',
    );
    await _persistState(triggerAutoBackup: false);
    return ok;
  }

  /// Protocol-aware PIN request (supports 6-char Google TV 6466, 4-digit Philips 1926, and 4-digit VIDAA 36669).
  Future<Map<String, dynamic>> startSmartPinPairing({
    String? customIp,
    bool forceRestart = false,
  }) async {
    final targetIp = _resolveTargetTvIp(customIp);
    if (targetIp.isEmpty) {
      return const <String, dynamic>{
        'pinDisplayed': false,
        'adb5555Open': false,
        'pinLength': 6,
        'message':
            'Önce "Ağdaki Cihazları Ara" ile TV seçin veya TV IP adresini girin.',
      };
    }

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Google TV ($targetIp)',
            ip: targetIp,
            port: 6466,
            protocol: TvConnectionProtocol.remotePort6466,
            boardInfo: 'Smart TV • PIN İsteniyor...',
            isOnline: false,
          );

    final res = await ref.read(adbTvServiceProvider).startSmartTvPinPairing(
          candidate,
          forceRestart: forceRestart,
        );
    final msg = (res['message'] as String?) ?? '';
    if (msg.isNotEmpty) {
      state = state.copyWith(lastCommandStatus: msg);
    }
    return res;
  }

  /// Protocol-aware PIN submission (supports 6-char Google TV 6466, 4-digit Philips 1926, and 4-digit VIDAA 36669).
  Future<bool> submitSmartPinPairing(
    String pin, {
    String? customIp,
  }) async {
    final targetIp = _resolveTargetTvIp(customIp);
    if (targetIp.isEmpty) {
      state = state.copyWith(
        lastCommandStatus:
            '⚠️ Önce "Ağdaki Cihazları Ara" ile TV seçin veya TV IP adresini girin',
      );
      return false;
    }

    final candidate = state.selectedDevice.ip == targetIp
        ? state.selectedDevice
        : TvDevice(
            name: 'Google TV ($targetIp)',
            ip: targetIp,
            port: 6466,
            protocol: TvConnectionProtocol.remotePort6466,
            boardInfo: 'Smart TV • PIN Eşleştiriliyor...',
            isOnline: false,
          );

    state = state.copyWith(
      isScanning: true,
      selectedDevice: candidate,
      lastCommandStatus: '🔢 TV PIN kodu doğrulanıyor ($targetIp)...',
    );

    final pairedDevice = await ref
        .read(adbTvServiceProvider)
        .completeSmartTvPinPairing(candidate, pin);
    final updatedList = <TvDevice>[
      pairedDevice,
      ...state.discoveredDevices.where((d) => d.ip != pairedDevice.ip),
    ];

    final ok = pairedDevice.isPaired || pairedDevice.isOnline;
    state = state.copyWith(
      isScanning: false,
      selectedDevice: pairedDevice,
      discoveredDevices: updatedList,
      lastCommandStatus: ok
          ? '✓ Eşleşti ve Bağlandı: ${pairedDevice.name} (${pairedDevice.ip})'
          : '⚠️ PIN Eşleştirme hatası: ${pairedDevice.boardInfo}',
    );
    await _persistState(triggerAutoBackup: false);
    return ok;
  }

  // ===========================================================================
  // SHARE-TO-TV BEAM & SCHEDULE (PHASE 2)
  // ===========================================================================

  void clearPendingSharedPayload() {
    state = state.copyWith(clearPendingSharedPayload: true);
  }

  Future<bool> importClipboardAsSharedPayload() async {
    final payload = await ref
        .read(cueShareIntentServiceProvider)
        .readClipboardAsSharePayload();
    if (payload == null) {
      state = state.copyWith(
        lastCommandStatus:
            '📋 Panoda geçerli YouTube veya video bağlantısı bulunamadı',
      );
      return false;
    }
    state = state.copyWith(
      pendingSharedPayload: payload,
      lastCommandStatus: '📲 Panodaki bağlantı hazır: ${payload.title}',
    );
    return true;
  }

  Future<({bool beamed, bool needsPaywall})> beamSharedPayloadNow(
    SharedCuePayload payload,
  ) async {
    final quotaRes = await ref
        .read(cueMonetizationServiceProvider)
        .consumeDailyBeamQuota(current: state.entitlement);
    if (!quotaRes.success) {
      state = state.copyWith(
        entitlement: quotaRes.entitlement,
        shouldPromptPaywall: true,
        lastCommandStatus: quotaRes.message,
      );
      return (beamed: false, needsPaywall: true);
    }

    final ok = await ref.read(adbTvServiceProvider).launchPlatformOrDeepLink(
          state.selectedDevice,
          platform: payload.platform,
          deepLinkUrl: payload.url,
          fallbackSearchQuery: payload.title,
        );
    state = state.copyWith(
      entitlement: quotaRes.entitlement,
      clearPendingSharedPayload: true,
      selectedDevice: state.selectedDevice.copyWith(isOnline: ok),
      lastCommandStatus: ok
          ? '🔥 TV\'ye Işınlandı: ${payload.title}'
          : '⚡ TV başlatma komutu gönderildi: ${payload.title}',
    );
    return (beamed: true, needsPaywall: false);
  }

  bool scheduleSharedPayload(
    SharedCuePayload payload, {
    required int hour,
    required int minute,
  }) {
    if (!canAddMoreWatchPlans) {
      state = state.copyWith(
        shouldPromptPaywall: true,
        lastCommandStatus:
            '⚡ Ücretsiz sürümde en fazla ${CueProProductCatalog.maxFreeWatchPlans} izleme planı eklenebilir.',
      );
      return false;
    }
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    final item = WatchCueItem(
      id: 'cue_share_${now.millisecondsSinceEpoch}',
      title: payload.title,
      subtitle: '${payload.platform.label} • Paylaşımdan Planlandı',
      platform: payload.platform,
      scheduledTime: scheduled,
      totalMinutes: 45,
      sessionMinutes: 45,
      deepLinkUrl: payload.url,
      recurrence: WatchRecurrence.once,
    );
    addWatchCue(item);
    clearPendingSharedPayload();
    return true;
  }

  // ===========================================================================
  // MONETIZATION: 3-TIER PAYWALL, 24H REWARDED PRO PASS & LOYALTY DISCOUNT
  // ===========================================================================

  static const Set<String> _seededDemoCueIds = <String>{
    'cue_yt_playlist_1',
    'cue_bein_2',
    'cue_tabii_3',
    'cue_netflix_4',
  };

  int get customWatchPlanCount => state.cueItems
      .where((item) => !_seededDemoCueIds.contains(item.id))
      .length;

  bool get canAddMoreWatchPlans =>
      state.hasProAccess ||
      customWatchPlanCount < CueProProductCatalog.maxFreeWatchPlans;

  void triggerPaywallPrompt() {
    state = state.copyWith(shouldPromptPaywall: true);
  }

  void dismissPaywallPrompt() {
    if (state.shouldPromptPaywall) {
      state = state.copyWith(shouldPromptPaywall: false);
    }
  }

  Future<MonetizationActionResult> unlockProPassWithRewardedAd({
    DateTime? now,
  }) async {
    final res = await ref
        .read(cueMonetizationServiceProvider)
        .watchRewardedAdAndUnlockProPass(current: state.entitlement, now: now);
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  Future<MonetizationActionResult> resetProPassToFree() async {
    final res = await ref
        .read(cueMonetizationServiceProvider)
        .resetEntitlementToFree(current: state.entitlement);
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  Future<MonetizationActionResult> purchaseLifetimePro({DateTime? now}) async {
    final res = await ref
        .read(cueMonetizationServiceProvider)
        .purchaseLifetimePro(current: state.entitlement, now: now);
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  Future<MonetizationActionResult> purchasePlan(
    CuePlanTier tier, {
    DateTime? now,
  }) async {
    final res = await ref
        .read(cueMonetizationServiceProvider)
        .purchasePlanTier(tier, current: state.entitlement, now: now);
    state = state.copyWith(
      entitlement: res.entitlement,
      shouldPromptPaywall: false,
      lastCommandStatus: res.message,
    );
    return res;
  }

  Future<MonetizationActionResult> restoreProPurchases() async {
    final res = await ref
        .read(cueMonetizationServiceProvider)
        .restorePurchases(current: state.entitlement);
    state = state.copyWith(
      entitlement: res.entitlement,
      lastCommandStatus: res.message,
    );
    return res;
  }

  void selectDevice(TvDevice device) {
    state = state.copyWith(
      selectedDevice: device,
      isMuted: false,
      lastCommandStatus: 'Aktif TV: ${device.name} (${device.displayEndpoint})',
    );
    _persistState();
    if (!device.isOnline && !device.isIrBlaster && !state.isScanning) {
      unawaited(scanNetworkForTvs(customIp: device.ip));
    }
  }

  bool _nextMuteState(TvKeyCommand command) {
    if (command == TvKeyCommand.mute) return !state.isMuted;
    if (command == TvKeyCommand.volUp || command == TvKeyCommand.volDown) {
      return false;
    }
    return state.isMuted;
  }

  Future<void> sendRemoteKey(TvKeyCommand command) async {
    if (!ref.mounted) return;
    _highlightResetTimer?.cancel();
    final initialDevice = state.selectedDevice;
    state = state.copyWith(
      lastPressedDirection: command,
      lastCommandStatus: 'Komut gönderildi: ${command.label}',
    );
    _highlightResetTimer = Timer(const Duration(milliseconds: 220), () {
      if (!ref.mounted) return;
      state = state.copyWith(clearPressedDirection: true);
    });

    final service = ref.read(adbTvServiceProvider);
    var ok = await service.sendKeyCommand(initialDevice, command);
    if (!ref.mounted) return;

    if (initialDevice.isIrBlaster) {
      state = state.copyWith(
        isMuted: _nextMuteState(command),
        lastCommandStatus: ok
            ? '✓ IR: ${command.label} (${initialDevice.displayEndpoint})'
            : '⚡ IR sinyali gönderildi: ${command.label}',
      );
      return;
    }

    if (ok) {
      state = state.copyWith(
        selectedDevice: initialDevice.isOnline
            ? initialDevice
            : initialDevice.copyWith(isOnline: true),
        isMuted: _nextMuteState(command),
        lastCommandStatus:
            '✓ TV: ${command.label} (${initialDevice.displayEndpoint})',
      );
      return;
    }

    final refreshed = await service.verifyOrReconnectDevice(initialDevice);
    if (!ref.mounted) return;
    if (refreshed.isOnline) {
      final upgraded = refreshed.port != initialDevice.port ||
          refreshed.protocol != initialDevice.protocol;
      if (upgraded) {
        ok = await service.sendKeyCommand(refreshed, command);
        if (!ref.mounted) return;
      }
      state = state.copyWith(
        selectedDevice: refreshed,
        discoveredDevices: _mergeDeviceIntoDiscovered(refreshed),
        isMuted: ok ? _nextMuteState(command) : state.isMuted,
        lastCommandStatus: ok
            ? '✓ TV: ${command.label} (${refreshed.displayEndpoint})'
            : 'ℹ️ "${command.label}" bu TV kaynağında yanıt vermedi (Canlı TV / uydu modunu kontrol edin)',
      );
      if (upgraded) {
        unawaited(_persistState(triggerAutoBackup: false));
      }
      return;
    }

    state = state.copyWith(
      selectedDevice: refreshed,
      discoveredDevices: _mergeDeviceIntoDiscovered(refreshed),
      lastCommandStatus: '⚠️ TV bağlantısı koptu — yeniden bağlanılıyor...',
    );
    unawaited(healSelectedTvConnection(allowSubnetRescan: true));
  }

  Future<bool> startVoiceCommandSession() async {
    if (state.isListeningVoice) return false;
    state = state.copyWith(
      isListeningVoice: true,
      voicePermissionDenied: false,
      lastCommandStatus: '🎙️ Telefon mikrofonu dinleniyor... Lütfen konuşun',
    );

    final service = ref.read(adbTvServiceProvider);
    final transcript = await service.listenPhoneMicrophone();

    if (transcript == null || transcript.trim().isEmpty) {
      final permDenied = service.voicePermissionDenied;
      state = state.copyWith(
        isListeningVoice: false,
        voicePermissionDenied: permDenied,
        lastCommandStatus: permDenied
            ? '⚠️ Mikrofon / Ses Tanıma izni kapalı! Ayarlar > CueDeck üzerinden izin verin.'
            : '🎙️ Sesli komut hazır — konuşmak için dokunun veya hızlı komut seçin',
      );
      return false;
    }

    state = state.copyWith(
      isListeningVoice: false,
      voicePermissionDenied: false,
      lastVoiceTranscript: transcript,
    );
    await runVoiceTranscript(transcript);
    return true;
  }

  Future<void> stopVoiceCommandSession() async {
    if (!state.isListeningVoice) return;
    await ref.read(adbTvServiceProvider).stopPhoneMicrophone();
  }

  Future<void> cancelVoiceCommandSession() async {
    if (!state.isListeningVoice) return;
    await ref.read(adbTvServiceProvider).cancelPhoneMicrophone();
    if (state.isListeningVoice) {
      state = state.copyWith(
        isListeningVoice: false,
        lastCommandStatus: '🎙️ Sesli dinleme durduruldu',
      );
    }
  }

  Future<void> runVoiceTranscript(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty || !ref.mounted) return;

    state = state.copyWith(
      lastVoiceTranscript: cleaned,
      lastCommandStatus: '🎙️ İşleniyor: "$cleaned"...',
    );

    final service = ref.read(adbTvServiceProvider);
    final device = state.selectedDevice;
    final statusMsg = await service.executeVoiceCommand(device, cleaned);
    if (!ref.mounted) return;

    if (device.isIrBlaster) {
      state = state.copyWith(lastCommandStatus: statusMsg);
      return;
    }

    var nextOnline = device.isOnline;
    if (statusMsg.startsWith('🎙️')) {
      nextOnline = true;
    } else if (device.hasValidIp) {
      final refreshed = await service.verifyOrReconnectDevice(device);
      if (!ref.mounted) return;
      nextOnline = refreshed.isOnline;
    }

    state = state.copyWith(
      selectedDevice: device.copyWith(isOnline: nextOnline),
      lastCommandStatus: statusMsg,
    );
  }

  Future<void> triggerTvNativeVoiceAssistant() =>
      sendRemoteKey(TvKeyCommand.voiceAssist);

  Future<void> launchPlatformApp(
    StreamingPlatform platform, {
    String? deepLinkUrl,
  }) async {
    if (!ref.mounted) return;
    state = state.copyWith(
      lastCommandStatus: '${platform.label} TV ekranında açılıyor...',
    );
    final service = ref.read(adbTvServiceProvider);
    final device = state.selectedDevice;
    final ok = await service.launchPlatformOrDeepLink(
      device,
      platform: platform,
      deepLinkUrl: deepLinkUrl ?? '',
    );
    if (!ref.mounted) return;

    if (ok || device.isIrBlaster) {
      state = state.copyWith(
        selectedDevice: device.isIrBlaster
            ? device
            : device.copyWith(isOnline: true),
        lastCommandStatus: ok
            ? '✓ TV\'de Açıldı: ${platform.label}'
            : '⚡ ${platform.label} başlatma sinyali gönderildi',
      );
      return;
    }

    final refreshed = await service.verifyOrReconnectDevice(device);
    if (!ref.mounted) return;
    state = state.copyWith(
      selectedDevice: refreshed,
      discoveredDevices: _mergeDeviceIntoDiscovered(refreshed),
      lastCommandStatus: '⚡ ${platform.label} başlatma sinyali gönderildi',
    );
  }

  Future<void> beamCueToTv(WatchCueItem item) async {
    state = state.copyWith(
      activePlayingCueId: item.id,
      clearReminder: state.activeReminderItem?.id == item.id,
      lastCommandStatus:
          '🎬 TV\'de Başlatılıyor: ${item.title} (${item.watchedMinutes}. dk)',
    );

    final ok = await ref.read(adbTvServiceProvider).launchPlatformOrDeepLink(
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

  Future<void> sendKeyboardText(
    String text, {
    bool submitEnter = false,
  }) async {
    if (text.isEmpty) return;
    if (text != ' ' && text.trim().isEmpty) return;
    final ok = await ref.read(adbTvServiceProvider).sendSearchText(
          state.selectedDevice,
          text,
          submitEnter: submitEnter,
        );
    final display = text == ' ' ? 'Boşluk' : text.trim();
    state = state.copyWith(
      lastCommandStatus: ok
          ? '✓ TV\'ye yazıldı: "$display"'
          : 'Metin gönderildi: "$display"',
    );
  }

  Future<void> sendKeyboardBackspace({int count = 1}) async {
    final ok = await ref
        .read(adbTvServiceProvider)
        .sendBackspace(state.selectedDevice, count: count);
    state = state.copyWith(
      lastCommandStatus: ok
          ? '⌫ TV klavyede silindi ($count karakter)'
          : '⌫ Silme komutu gönderildi',
    );
  }

  Future<void> sendKeyboardEnter() async {
    final ok = await ref.read(adbTvServiceProvider).sendEnterKey(state.selectedDevice);
    state = state.copyWith(
      lastCommandStatus: ok
          ? '↵ TV\'de Arama / Enter onaylandı'
          : '↵ Enter komutu gönderildi',
    );
  }

  Future<void> searchTranscriptOnYoutube(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final ok = await ref.read(adbTvServiceProvider).launchPlatformOrDeepLink(
          state.selectedDevice,
          platform: StreamingPlatform.youtube,
          fallbackSearchQuery: clean,
        );
    state = state.copyWith(
      selectedDevice: state.selectedDevice.copyWith(isOnline: ok),
      lastCommandStatus: ok
          ? '🎬 YouTube\'da aratıldı: "$clean"'
          : '⚡ YouTube arama sinyali gönderildi: "$clean"',
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

  void updateWatchedProgress(String id, int deltaMinutes) =>
      stepProgress(id, deltaMinutes);

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
      return item.copyWith(watchedMinutes: nextMins, currentEpisode: nextEp);
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
      return item.copyWith(watchedMinutes: nextMins, currentEpisode: nextEp);
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
