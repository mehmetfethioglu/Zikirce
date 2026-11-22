import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../domain/qibla_math.dart';
import '../domain/qibla_models.dart';

/// Kıble sensör verisi sağlayan soyut arayüz (DIP: testlerde sahtelenebilir).
abstract interface class QiblaSensorSource {
  Stream<QiblaSensorSample> get sampleStream;
  void start();
  void dispose();
}

/// Gerçek cihaz ivmeölçer + manyetometre birleşimiyle eğim düzeltmeli pusula verisi üretir.
class DeviceQiblaSensorSource implements QiblaSensorSource {
  final StreamController<QiblaSensorSample> _controller =
      StreamController<QiblaSensorSample>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  bool _started = false;
  bool _disposed = false;

  // Varsayılan düz zemin yerçekimi (ivmeölçer verisi henüz gelmezse veya yoksa).
  double _ax = 0.0;
  double _ay = 0.0;
  double _az = 9.80665;
  bool _hasAccelSample = false;

  double _mx = 0.0;
  double _my = 0.0;
  double _mz = 0.0;
  bool _hasMagSample = false;

  static const double _accelAlpha = 0.28;
  static const double _magAlpha = 0.30;

  @override
  Stream<QiblaSensorSample> get sampleStream => _controller.stream;

  @override
  void start() {
    if (_started || _disposed) return;
    _started = true;

    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(
        _onAccelerometerEvent,
        onError: (Object error) {
          debugPrint('[QiblaSensor] Accelerometer unavailable: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[QiblaSensor] Accelerometer stream init skipped: $e');
    }

    try {
      _magnetoSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(
        _onMagnetometerEvent,
        onError: (Object error) {
          debugPrint('[QiblaSensor] Magnetometer unavailable: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[QiblaSensor] Magnetometer stream init skipped: $e');
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (_disposed) return;
    if (!_hasAccelSample) {
      _ax = event.x;
      _ay = event.y;
      _az = event.z;
      _hasAccelSample = true;
      return;
    }
    _ax = _ax + (event.x - _ax) * _accelAlpha;
    _ay = _ay + (event.y - _ay) * _accelAlpha;
    _az = _az + (event.z - _az) * _accelAlpha;
  }

  void _onMagnetometerEvent(MagnetometerEvent event) {
    if (_disposed || _controller.isClosed) return;

    if (!_hasMagSample) {
      _mx = event.x;
      _my = event.y;
      _mz = event.z;
      _hasMagSample = true;
    } else {
      _mx = _mx + (event.x - _mx) * _magAlpha;
      _my = _my + (event.y - _my) * _magAlpha;
      _mz = _mz + (event.z - _mz) * _magAlpha;
    }

    final headingDeg = QiblaMath.calculateTiltCompensatedHeading(
      ax: _ax,
      ay: _ay,
      az: _az,
      mx: _mx,
      my: _my,
      mz: _mz,
    );
    if (headingDeg == null) return;

    final tilt = QiblaMath.calculateTiltDegrees(_ax, _ay, _az);
    final fieldUt = math.sqrt(_mx * _mx + _my * _my + _mz * _mz);

    _controller.add(
      QiblaSensorSample(
        headingDeg: headingDeg,
        tiltDeg: tilt.tiltDeg,
        pitchDeg: tilt.pitchDeg,
        rollDeg: tilt.rollDeg,
        magneticFieldUt: fieldUt,
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _accelSub?.cancel();
    _accelSub = null;
    _magnetoSub?.cancel();
    _magnetoSub = null;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
