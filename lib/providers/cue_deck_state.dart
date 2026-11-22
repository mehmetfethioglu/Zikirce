import 'package:flutter/foundation.dart';

import '../models/cue_models.dart';
import '../services/cue_monetization_service.dart';

/// Immutable state for the CueDeck Remote & Watch Planner application (Layer 3).
@immutable
class CueDeckState {
  const CueDeckState({
    required this.activeTab,
    required this.selectedDevice,
    required this.discoveredDevices,
    required this.isScanning,
    required this.lastPressedDirection,
    required this.lastCommandStatus,
    required this.cueItems,
    this.bottomDeckMode = RemoteBottomDeckMode.plan,
    this.touchpadSensitivity = 1.25,
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
    this.localWifiIp = '',
    this.localNetworkPermissionDenied = false,
    this.voicePermissionDenied = false,
    this.hasIrEmitter = false,
    this.pendingSharedPayload,
    this.shouldPromptPaywall = false,
    this.isMuted = false,
  });

  final int activeTab;
  final TvDevice selectedDevice;
  final List<TvDevice> discoveredDevices;
  final bool isScanning;
  final RemoteBottomDeckMode bottomDeckMode;
  final double touchpadSensitivity;
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
  final String localWifiIp;
  final bool localNetworkPermissionDenied;
  final bool voicePermissionDenied;
  final bool hasIrEmitter;
  final SharedCuePayload? pendingSharedPayload;
  final bool shouldPromptPaywall;
  final bool isMuted;

  bool get isTouchpadMode => bottomDeckMode == RemoteBottomDeckMode.touchpad;
  bool get isPlanDeckActive => bottomDeckMode == RemoteBottomDeckMode.plan;

  List<WatchCueItem> sortedUpcomingCueItems([DateTime? now]) =>
      WatchCueItem.sortNearestFirst(cueItems, now: now);

  bool get isProLifetime => entitlement.isProLifetime;
  bool get isProPassActive => entitlement.isProPassActive();
  bool get hasProAccess => entitlement.hasProAccess();
  int get rewardedDaysCount => entitlement.rewardedDaysCount;
  bool get isLoyaltyDiscountUnlocked => entitlement.isLoyaltyDiscountUnlocked;

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

  int get totalWatchedMinutes {
    var sum = 0;
    for (final item in cueItems) {
      sum += item.watchedMinutes.clamp(0, item.totalMinutes);
    }
    return sum;
  }

  int get totalPlannedMinutes {
    var sum = 0;
    for (final item in cueItems) {
      sum += item.totalMinutes;
    }
    return sum;
  }

  int get completedCount => cueItems.where((e) => e.isCompleted).length;

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
    RemoteBottomDeckMode? bottomDeckMode,
    double? touchpadSensitivity,
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
    String? localWifiIp,
    bool? localNetworkPermissionDenied,
    bool? voicePermissionDenied,
    bool? hasIrEmitter,
    SharedCuePayload? pendingSharedPayload,
    bool clearPendingSharedPayload = false,
    bool? shouldPromptPaywall,
    bool? isMuted,
  }) {
    final resolvedDeckMode = bottomDeckMode ??
        (isTouchpadMode == null
            ? this.bottomDeckMode
            : (isTouchpadMode
                  ? RemoteBottomDeckMode.touchpad
                  : RemoteBottomDeckMode.plan));
    return CueDeckState(
      activeTab: activeTab ?? this.activeTab,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
      bottomDeckMode: resolvedDeckMode,
      touchpadSensitivity: touchpadSensitivity ?? this.touchpadSensitivity,
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
      localWifiIp: localWifiIp ?? this.localWifiIp,
      localNetworkPermissionDenied:
          localNetworkPermissionDenied ?? this.localNetworkPermissionDenied,
      voicePermissionDenied:
          voicePermissionDenied ?? this.voicePermissionDenied,
      hasIrEmitter: hasIrEmitter ?? this.hasIrEmitter,
      pendingSharedPayload: clearPendingSharedPayload
          ? null
          : (pendingSharedPayload ?? this.pendingSharedPayload),
      shouldPromptPaywall: shouldPromptPaywall ?? this.shouldPromptPaywall,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
