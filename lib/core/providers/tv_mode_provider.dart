import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_sync_engine.dart';

/// Android TV / Google TV Donanım ve Mod Algılama Servisi
class TvModeService {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zikirce/battery_optimization');
  static const String prefsKey = 'Zikirce_TvMode_Enabled';

  static bool _isHardwareTv = false;
  static bool get isHardwareTv => _isHardwareTv;

  static bool _isTvModeActive = false;
  static bool get isTvModeActive => _isTvModeActive;

  /// Uygulama açılışında (main.dart) donanımsal TV olup olmadığını tespit eder
  static Future<bool> detectTvModeAtStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (Platform.isAndroid) {
        final hwTv = await _channel.invokeMethod<bool>('isTelevision') ?? false;
        _isHardwareTv = hwTv;
      }
      final savedOverride = prefs.getBool(prefsKey);
      if (savedOverride != null) {
        _isTvModeActive = savedOverride;
        return savedOverride;
      }
      _isTvModeActive = _isHardwareTv;
      return _isHardwareTv;
    } catch (_) {
      _isTvModeActive = _isHardwareTv;
      return _isHardwareTv;
    }
  }

  /// TV veya yatay geniş ekranlar için ekran yönelimini ayarlar
  static Future<void> applyOrientationForMode({
    required bool isTvMode,
    required bool isTablet,
  }) async {
    _isTvModeActive = isTvMode;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    if (isTvMode) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (isTablet) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }
}

final initialIsTvModeProvider = Provider<bool>((ref) => false);

class TvModeNotifier extends StateNotifier<bool> {
  TvModeNotifier(super.initialState);

  Future<void> setTvMode(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    TvModeService._isTvModeActive = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(TvModeService.prefsKey, enabled);
      await TvModeService.applyOrientationForMode(
        isTvMode: enabled,
        isTablet: true,
      );
    } catch (_) {}
  }

  Future<void> toggleTvMode() => setTvMode(!state);
}

final isTvModeProvider = StateNotifierProvider<TvModeNotifier, bool>((ref) {
  final initial = ref.watch(initialIsTvModeProvider);
  return TvModeNotifier(initial);
});

/// Cihazlar Arası Senkronize Mukabele İlerleme Durumu
class MukabeleSyncState {
  final int lastPage;
  final int lastJuz;
  final int lastUpdatedMs;

  const MukabeleSyncState({
    this.lastPage = 1,
    this.lastJuz = 1,
    this.lastUpdatedMs = 0,
  });

  MukabeleSyncState copyWith({
    int? lastPage,
    int? lastJuz,
    int? lastUpdatedMs,
  }) {
    return MukabeleSyncState(
      lastPage: lastPage ?? this.lastPage,
      lastJuz: lastJuz ?? this.lastJuz,
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
    );
  }
}

class MukabeleSyncNotifier extends StateNotifier<MukabeleSyncState> {
  MukabeleSyncNotifier() : super(const MukabeleSyncState()) {
    reloadFromPrefs();
  }

  Future<void> reloadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mukPage = prefs.getInt('MukabeleLastPage') ??
          prefs.getInt('LastReadPage') ??
          1;
      final clampedPage = mukPage.clamp(1, 605);
      final juz = prefs.getInt('MukabeleLastJuz') ??
          (((clampedPage - 1) ~/ 20) + 1).clamp(1, 30);
      final updatedMs = prefs.getInt('MukabeleLastUpdatedMs') ?? 0;

      if (mounted) {
        state = MukabeleSyncState(
          lastPage: clampedPage,
          lastJuz: juz,
          lastUpdatedMs: updatedMs,
        );
      }
    } catch (_) {}
  }

  Future<void> saveProgress(int pageNumber, {bool triggerCloudSync = true}) async {
    final clamped = pageNumber.clamp(1, 605);
    final juz = (((clamped - 1) ~/ 20) + 1).clamp(1, 30);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (mounted) {
      state = MukabeleSyncState(
        lastPage: clamped,
        lastJuz: juz,
        lastUpdatedMs: nowMs,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('MukabeleLastPage', clamped);
      await prefs.setInt('MukabeleLastJuz', juz);
      await prefs.setInt('MukabeleLastUpdatedMs', nowMs);
      await prefs.setInt('LastReadPage', clamped);
      await prefs.setInt('LastReadPage_UpdatedMs', nowMs);
      if (triggerCloudSync) {
        CloudSyncEngine.instance.triggerDebouncedSync(
          null,
          delay: const Duration(seconds: 2),
        );
      }
    } catch (_) {}
  }
}

final mukabeleSyncProvider =
    StateNotifierProvider<MukabeleSyncNotifier, MukabeleSyncState>((ref) {
  return MukabeleSyncNotifier();
});
