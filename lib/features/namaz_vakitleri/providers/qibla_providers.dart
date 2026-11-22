import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/session/session_providers.dart';
import '../domain/qibla_math.dart';
import '../domain/qibla_models.dart';
import '../services/qibla_sensor_service.dart';
import 'prayer_providers.dart';

/// Kıble sensör sağlayıcısı (DIP: testlerde sahte kaynakla override edilebilir).
final qiblaSensorSourceProvider =
    Provider.autoDispose<QiblaSensorSource>((ref) {
  final source = DeviceQiblaSensorSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Kıble ekranı için isteğe bağlı koordinat parametresi.
@immutable
class QiblaParams {
  final double? userLat;
  final double? userLng;

  const QiblaParams({this.userLat, this.userLng});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QiblaParams &&
          runtimeType == other.runtimeType &&
          userLat == other.userLat &&
          userLng == other.userLng;

  @override
  int get hashCode => Object.hash(userLat, userLng);
}

class QiblaController extends StateNotifier<QiblaState> {
  static const String _prefFigureModeKey = 'qibla_figure_mode_v1';
  static const String _prefSoundEnabledKey = 'qibla_sound_enabled_v1';
  static const double _headingSmoothAlpha = 0.28;
  static const List<double> _approachingDetents = <double>[20.0, 12.0, 6.0];

  final QiblaSensorSource _sensorSource;

  StreamSubscription<QiblaSensorSample>? _sensorSub;
  Timer? _sensorTimeoutTimer;
  Timer? _lockDwellTimer;
  Timer? _takbirCompleteTimer;
  Timer? _solarRefreshTimer;

  bool _disposed = false;
  bool _hasSensorSample = false;
  bool _userForcedPreview = false;
  bool _figureModeOverridden = false;
  bool _soundOverridden = false;
  DateTime _lastDetentHapticAt = DateTime.fromMillisecondsSinceEpoch(0);

  QiblaController({
    required QiblaSensorSource sensorSource,
    required String cityName,
    required double latitude,
    required double longitude,
    required QiblaFigureMode initialFigureMode,
  })  : _sensorSource = sensorSource,
        super(
          _buildInitialState(
            cityName: cityName,
            latitude: latitude,
            longitude: longitude,
            initialFigureMode: initialFigureMode,
          ),
        ) {
    _initialize();
  }

  static QiblaState _buildInitialState({
    required String cityName,
    required double latitude,
    required double longitude,
    required QiblaFigureMode initialFigureMode,
  }) {
    final bearing = QiblaMath.calculateQiblaBearing(latitude, longitude);
    final distanceKm = QiblaMath.calculateDistanceToKaabaKm(latitude, longitude);
    final declination = QiblaMath.estimateMagneticDeclination(latitude, longitude);
    final solar = QiblaMath.calculateSolarPosition(
      latitude,
      longitude,
      DateTime.now().toUtc(),
    );
    const initialHeading = 0.0;
    final initialDelta = QiblaMath.shortestAngleDelta(initialHeading, bearing);

    return QiblaState(
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
      qiblaBearingDeg: bearing,
      distanceKm: distanceKm,
      declinationDeg: declination,
      sunAzimuthDeg: solar.azimuthDeg,
      sunElevationDeg: solar.elevationDeg,
      headingDeg: initialHeading,
      angleDeltaDeg: initialDelta,
      tiltDeg: 0.0,
      pitchDeg: 0.0,
      rollDeg: 0.0,
      magneticFieldUt: 45.0,
      sensorStatus: QiblaSensorStatus.active,
      phase: initialDelta.abs() <= QiblaMath.approachingThresholdDeg
          ? QiblaAlignmentPhase.approaching
          : QiblaAlignmentPhase.searching,
      figureMode: initialFigureMode,
      isSoundEnabled: false,
      isInteractivePreview: false,
    );
  }

  void _initialize() {
    unawaited(_loadPreferences());

    _sensorSub = _sensorSource.sampleStream.listen(
      onSensorSample,
      onError: (Object err) {
        debugPrint('[QiblaController] Sensor stream error: $err');
        if (!_disposed && !_hasSensorSample) {
          _activateInteractivePreview(
            status: QiblaSensorStatus.unavailable,
          );
        }
      },
    );
    _sensorSource.start();

    _sensorTimeoutTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!_disposed && !_hasSensorSample) {
        _activateInteractivePreview(
          status: QiblaSensorStatus.interactivePreview,
        );
      }
    });

    _solarRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_disposed) return;
      final solar = QiblaMath.calculateSolarPosition(
        state.latitude,
        state.longitude,
        DateTime.now().toUtc(),
      );
      state = state.copyWith(
        sunAzimuthDeg: solar.azimuthDeg,
        sunElevationDeg: solar.elevationDeg,
      );
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;

      QiblaFigureMode? savedMode;
      final modeStr = prefs.getString(_prefFigureModeKey);
      if (modeStr != null) {
        for (final mode in QiblaFigureMode.values) {
          if (mode.name == modeStr) {
            savedMode = mode;
            break;
          }
        }
      }

      final savedSound = prefs.getBool(_prefSoundEnabledKey);

      state = state.copyWith(
        figureMode: _figureModeOverridden ? null : savedMode,
        isSoundEnabled: _soundOverridden ? null : savedSound,
      );
    } catch (e) {
      debugPrint('[QiblaController] Preferences load warning: $e');
    }
  }

  void _activateInteractivePreview({required QiblaSensorStatus status}) {
    if (_disposed) return;
    state = state.copyWith(
      sensorStatus: status,
      isInteractivePreview: true,
      tiltDeg: 0.0,
      pitchDeg: 0.0,
      rollDeg: 0.0,
    );
    _evaluateAlignment(
      newHeadingDeg: state.headingDeg,
      tiltDeg: 0.0,
      pitchDeg: 0.0,
      rollDeg: 0.0,
      magneticFieldUt: state.magneticFieldUt,
      sensorStatus: status,
      isInteractive: true,
    );
  }

  /// Sensörden gelen yeni eğim düzeltmeli manyetik yön ölçümünü işler.
  void onSensorSample(QiblaSensorSample sample) {
    if (_disposed || _userForcedPreview) return;

    final isFirstSample = !_hasSensorSample;
    if (isFirstSample) {
      _hasSensorSample = true;
      _sensorTimeoutTimer?.cancel();
      _sensorTimeoutTimer = null;
    }

    final trueTargetHeading = QiblaMath.normalizeAngleDeg(
      sample.headingDeg + state.declinationDeg,
    );

    final double nextHeading;
    if (isFirstSample || state.isInteractivePreview) {
      nextHeading = trueTargetHeading;
    } else {
      final rawDiff = QiblaMath.shortestAngleDelta(
        state.headingDeg,
        trueTargetHeading,
      ).abs();
      final isLockedOrAligned = state.phase == QiblaAlignmentPhase.locked ||
          state.phase == QiblaAlignmentPhase.takbir ||
          state.phase == QiblaAlignmentPhase.qiyam;

      if (isLockedOrAligned && rawDiff < 1.5) {
        nextHeading = state.headingDeg;
      } else {
        final double alpha;
        if (isLockedOrAligned) {
          alpha = 0.08;
        } else if (state.angleDeltaDeg.abs() < 12.0) {
          alpha = 0.14;
        } else {
          alpha = _headingSmoothAlpha;
        }
        nextHeading = QiblaMath.smoothAngleDeg(
          state.headingDeg,
          trueTargetHeading,
          alpha,
        );
      }
    }

    final hasInterference = sample.magneticFieldUt > 0 &&
        (sample.magneticFieldUt < QiblaMath.minValidMagneticFieldUt ||
            sample.magneticFieldUt > QiblaMath.maxValidMagneticFieldUt);

    final status = hasInterference
        ? QiblaSensorStatus.interference
        : QiblaSensorStatus.active;

    _evaluateAlignment(
      newHeadingDeg: nextHeading,
      tiltDeg: sample.tiltDeg,
      pitchDeg: sample.pitchDeg,
      rollDeg: sample.rollDeg,
      magneticFieldUt: sample.magneticFieldUt,
      sensorStatus: status,
      isInteractive: false,
    );
  }

  /// Etkileşimli önizleme modunda cihazı parmakla döndürür.
  void rotateManualBy(double deltaDeg) {
    if (_disposed) return;
    setManualHeading(state.headingDeg + deltaDeg);
  }

  /// Etkileşimli önizleme modunda yönü doğrudan ayarlar.
  void setManualHeading(double deg) {
    if (_disposed) return;
    final normalized = QiblaMath.normalizeAngleDeg(deg);
    _evaluateAlignment(
      newHeadingDeg: normalized,
      tiltDeg: 0.0,
      pitchDeg: 0.0,
      rollDeg: 0.0,
      magneticFieldUt: state.magneticFieldUt,
      sensorStatus: state.sensorStatus == QiblaSensorStatus.unavailable
          ? QiblaSensorStatus.unavailable
          : QiblaSensorStatus.interactivePreview,
      isInteractive: true,
    );
  }

  void _evaluateAlignment({
    required double newHeadingDeg,
    required double tiltDeg,
    required double pitchDeg,
    required double rollDeg,
    required double magneticFieldUt,
    required QiblaSensorStatus sensorStatus,
    required bool isInteractive,
  }) {
    final prevAbsDelta = state.angleDeltaDeg.abs();
    final newDelta = QiblaMath.shortestAngleDelta(
      newHeadingDeg,
      state.qiblaBearingDeg,
    );
    final absDelta = newDelta.abs();

    final canAlign = isInteractive || tiltDeg <= QiblaMath.maxFlatTiltDeg;
    final canKeepAligned =
        isInteractive || tiltDeg <= QiblaMath.maxLockedTiltDeg;

    var nextPhase = state.phase;

    if (state.phase == QiblaAlignmentPhase.takbir ||
        state.phase == QiblaAlignmentPhase.qiyam) {
      if (!canKeepAligned || absDelta > QiblaMath.alignmentExitDeg) {
        _cancelAlignmentTimers();
        nextPhase = absDelta <= QiblaMath.approachingThresholdDeg
            ? QiblaAlignmentPhase.approaching
            : QiblaAlignmentPhase.searching;
      }
    } else if (state.phase == QiblaAlignmentPhase.locked) {
      if (!canAlign || absDelta > QiblaMath.alignmentEnterDeg) {
        _cancelAlignmentTimers();
        nextPhase = absDelta <= QiblaMath.approachingThresholdDeg
            ? QiblaAlignmentPhase.approaching
            : QiblaAlignmentPhase.searching;
      }
    } else {
      if (canAlign && absDelta <= QiblaMath.alignmentEnterDeg) {
        nextPhase = QiblaAlignmentPhase.locked;
        _startLockDwellTimer();
      } else {
        nextPhase = absDelta <= QiblaMath.approachingThresholdDeg
            ? QiblaAlignmentPhase.approaching
            : QiblaAlignmentPhase.searching;
        _maybeTriggerApproachingDetent(
          canAlign: canAlign,
          prevAbsDelta: prevAbsDelta,
          newAbsDelta: absDelta,
        );
      }
    }

    state = state.copyWith(
      headingDeg: newHeadingDeg,
      angleDeltaDeg: newDelta,
      tiltDeg: tiltDeg,
      pitchDeg: pitchDeg,
      rollDeg: rollDeg,
      magneticFieldUt: magneticFieldUt,
      sensorStatus: sensorStatus,
      phase: nextPhase,
      isInteractivePreview: isInteractive,
    );
  }

  void _maybeTriggerApproachingDetent({
    required bool canAlign,
    required double prevAbsDelta,
    required double newAbsDelta,
  }) {
    if (!canAlign || newAbsDelta >= prevAbsDelta) return;
    final now = DateTime.now();
    if (now.difference(_lastDetentHapticAt).inMilliseconds < 180) return;

    for (final threshold in _approachingDetents) {
      if (prevAbsDelta > threshold && newAbsDelta <= threshold) {
        _lastDetentHapticAt = now;
        HapticService.selectionClick();
        break;
      }
    }
  }

  void _startLockDwellTimer() {
    _lockDwellTimer?.cancel();
    _lockDwellTimer = Timer(const Duration(milliseconds: 350), () {
      if (_disposed || state.phase != QiblaAlignmentPhase.locked) return;
      _beginTakbirSequence();
    });
  }

  /// Kıyam aşamasındayken İftitah Tekbiri koreografisini yeniden oynatır.
  void replayTakbir() {
    if (_disposed || state.phase != QiblaAlignmentPhase.qiyam) return;
    _beginTakbirSequence(incrementReplayTick: true);
  }

  void _beginTakbirSequence({bool incrementReplayTick = false}) {
    state = state.copyWith(
      phase: QiblaAlignmentPhase.takbir,
      takbirReplayTick: incrementReplayTick
          ? state.takbirReplayTick + 1
          : state.takbirReplayTick,
    );
    HapticService.targetReached();
    if (state.isSoundEnabled) {
      unawaited(_playAlignmentAudio());
    }

    _takbirCompleteTimer?.cancel();
    _takbirCompleteTimer = Timer(const Duration(milliseconds: 1350), () {
      if (_disposed || state.phase != QiblaAlignmentPhase.takbir) return;
      state = state.copyWith(phase: QiblaAlignmentPhase.qiyam);
    });
  }

  Future<void> _playAlignmentAudio() async {
    try {
      await SoundPoolService.playChirp(type: 'kumru');
    } catch (e) {
      debugPrint('[QiblaController] Alignment audio warning: $e');
    }
  }

  void _cancelAlignmentTimers() {
    _lockDwellTimer?.cancel();
    _lockDwellTimer = null;
    _takbirCompleteTimer?.cancel();
    _takbirCompleteTimer = null;
  }

  /// Figür modunu Erkek -> Kadın -> Sadece Seccade sırasıyla değiştirir.
  void cycleFigureMode() {
    const order = QiblaFigureMode.values;
    final nextIndex = (order.indexOf(state.figureMode) + 1) % order.length;
    setFigureMode(order[nextIndex]);
  }

  void setFigureMode(QiblaFigureMode mode) {
    if (_disposed) return;
    _figureModeOverridden = true;
    HapticService.selectionClick();
    state = state.copyWith(figureMode: mode);
    unawaited(_savePreference(_prefFigureModeKey, mode.name));
  }

  /// İftitah tekbiri ses geri bildirimini açar veya kapatır (varsayılan kapalı).
  void toggleSound() {
    if (_disposed) return;
    _soundOverridden = true;
    final nextValue = !state.isSoundEnabled;
    HapticService.selectionClick();
    state = state.copyWith(isSoundEnabled: nextValue);
    unawaited(_saveBoolPreference(_prefSoundEnabledKey, nextValue));
  }

  /// Etkileşimli önizleme ile canlı pusula arasında geçiş yapar.
  void toggleInteractivePreview() {
    if (_disposed) return;
    HapticService.selectionClick();

    if (state.isInteractivePreview) {
      _userForcedPreview = false;
      if (_hasSensorSample) {
        state = state.copyWith(
          isInteractivePreview: false,
          sensorStatus: QiblaSensorStatus.active,
        );
      } else {
        state = state.copyWith(
          isInteractivePreview: false,
          sensorStatus: QiblaSensorStatus.active,
        );
        _sensorTimeoutTimer?.cancel();
        _sensorTimeoutTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!_disposed && !_hasSensorSample) {
            _activateInteractivePreview(
              status: QiblaSensorStatus.interactivePreview,
            );
          }
        });
      }
      return;
    }

    _userForcedPreview = true;
    _activateInteractivePreview(status: QiblaSensorStatus.interactivePreview);
  }

  Future<void> _savePreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[QiblaController] Save pref warning ($key): $e');
    }
  }

  Future<void> _saveBoolPreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('[QiblaController] Save bool pref warning ($key): $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sensorSub?.cancel();
    _sensorSub = null;
    _sensorTimeoutTimer?.cancel();
    _sensorTimeoutTimer = null;
    _solarRefreshTimer?.cancel();
    _solarRefreshTimer = null;
    _cancelAlignmentTimers();
    super.dispose();
  }
}

final qiblaControllerProvider = StateNotifierProvider.autoDispose
    .family<QiblaController, QiblaState, QiblaParams>((ref, params) {
  final sensorSource = ref.watch(qiblaSensorSourceProvider);
  final selectedCity = ref.watch(selectedCityProvider);
  final avatar = ref.watch(activeSessionProvider.select((s) => s.avatar));

  final coords = PrayerTimesService.cityCoordinates[selectedCity] ??
      PrayerTimesService.cityCoordinates['İstanbul'] ??
      (41.0082, 28.9784);

  final lat = params.userLat ?? coords.$1;
  final lng = params.userLng ?? coords.$2;
  final initialMode = avatar.toLowerCase().contains('female')
      ? QiblaFigureMode.female
      : QiblaFigureMode.male;

  return QiblaController(
    sensorSource: sensorSource,
    cityName: selectedCity,
    latitude: lat,
    longitude: lng,
    initialFigureMode: initialMode,
  );
});
