import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_sync_engine.dart';
import '../services/screen_awake_service.dart';

/// Android TV / Google TV Donanım ve Mod Algılama Servisi
class TvModeService {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zikirce/battery_optimization');
  static const String prefsKey = 'Zikirce_TvMode_Enabled';

  static bool _isHardwareTv = false;
  static bool get isHardwareTv => _isHardwareTv;

  static bool _isTvModeActive = false;
  static bool get isTvModeActive => _isTvModeActive;

  static String? _lastAppliedOrientationMode;

  @visibleForTesting
  static void setHardwareTvForTest(bool value) {
    _isHardwareTv = value;
  }

  @visibleForTesting
  static void setTvModeActiveForTest(bool value) {
    _isTvModeActive = value;
  }

  @visibleForTesting
  static void resetOrientationCacheForTest() {
    _lastAppliedOrientationMode = null;
  }

  @visibleForTesting
  static bool? testIsIosOverride;

  /// Mevcut cihaz ekranının tablet (>= 600dp shortestSide) olup olmadığını tespit eder
  static bool isCurrentDeviceTablet() {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view == null || view.devicePixelRatio <= 0) {
        return false;
      }
      final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
      return shortestSide >= 600;
    } catch (e) {
      debugPrint('[TvModeService] isCurrentDeviceTablet error: $e');
      return false;
    }
  }

  /// Mevcut ekranda katlanabilir menteşe/kat (fold/hinge) özelliği olup olmadığını tespit eder
  static bool hasFoldingDisplayFeature() {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view == null) return false;
      return view.displayFeatures.any(
        (feature) =>
            feature.type == ui.DisplayFeatureType.fold ||
            feature.type == ui.DisplayFeatureType.hinge,
      );
    } catch (e) {
      debugPrint('[TvModeService] hasFoldingDisplayFeature error: $e');
      return false;
    }
  }

  /// Ekranın tablet, açılmış katlanabilir cihaz veya menteşeli cihaz olup olmadığını döndürür
  static bool isCurrentDisplayFoldableOrLarge() {
    return isCurrentDeviceTablet() || hasFoldingDisplayFeature();
  }

  /// Uygulama açılışında (main.dart) donanımsal TV olup olmadığını tespit eder
  static Future<bool> detectTvModeAtStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (testIsIosOverride == false ||
          (testIsIosOverride == null && Platform.isAndroid)) {
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
    } catch (e) {
      debugPrint('[TvModeService] detectTvModeAtStartup error: $e');
      _isTvModeActive = _isHardwareTv;
      return _isHardwareTv;
    }
  }

  static String _orientationModeKey({required bool isTvMode}) =>
      isTvMode ? 'tv_landscape' : 'adaptive_all';

  /// TV, katlanabilir telefonlar (Android & iOS) ve tabletler için yönelim politikasını uygular
  static Future<void> applyOrientationForMode({
    required bool isTvMode,
    required bool isTablet,
  }) async {
    _isTvModeActive = isTvMode;
    if (testIsIosOverride == null &&
        (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    final modeKey = _orientationModeKey(isTvMode: isTvMode);
    _lastAppliedOrientationMode = modeKey;

    if (isTvMode) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    } else {
      // Katlanabilir (Android/iOS), tablet ve telefon ekranlarında letterbox
      // olmaması için tüm yönelimleri dinamik olarak serbest bırakır.
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Pencere boyutu veya katlanma durumu değiştiğinde yalnızca politika değiştiyse yönelimi günceller
  static Future<void> syncOrientationForCurrentDisplay({
    required bool isTvMode,
  }) async {
    final targetMode = _orientationModeKey(isTvMode: isTvMode);
    if (_lastAppliedOrientationMode == targetMode) {
      return;
    }
    await applyOrientationForMode(
      isTvMode: isTvMode,
      isTablet: isCurrentDisplayFoldableOrLarge(),
    );
  }
}

final initialIsTvModeProvider = Provider<bool>((ref) => false);

class TvModeNotifier extends StateNotifier<bool> {
  TvModeNotifier(super.initialState);

  Future<void> setTvMode(bool enabled) async {
    if (state == enabled && enabled) return;
    state = enabled;
    TvModeService._isTvModeActive = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(TvModeService.prefsKey, enabled);
      await TvModeService.applyOrientationForMode(
        isTvMode: enabled,
        isTablet: TvModeService.isCurrentDisplayFoldableOrLarge(),
      );
      if (enabled) {
        await ScreenAwakeService.setKeepAwake(true);
      }
    } catch (e) {
      debugPrint('[TvModeNotifier] setTvMode($enabled) error: $e');
    }
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
