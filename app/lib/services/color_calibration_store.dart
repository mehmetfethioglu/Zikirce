import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera_capture/zamera_capture.dart';

/// Immutable per-lens calibration snapshot persisted via [ColorCalibrationStore].
class StoredLensCalibration {
  final String cameraId;
  final ColorCheckerCalibrationResult? calibrationResult;
  final List<double>? grayCardWbGains;
  final bool useGrayCardWb;
  final List<double>? flatField8x6;

  const StoredLensCalibration({
    required this.cameraId,
    this.calibrationResult,
    this.grayCardWbGains,
    this.useGrayCardWb = false,
    this.flatField8x6,
  });

  bool get hasSensorCalibration =>
      calibrationResult != null && calibrationResult!.isMeasuredFromSensor;

  bool get hasGrayCardWb =>
      grayCardWbGains != null && grayCardWbGains!.length >= 3;

  bool get hasFlatField => flatField8x6 != null && flatField8x6!.length == 48;
}

/// Single-responsibility persistence service for per-lens 24-patch ColorChecker 3x3
/// matrices, measured 18% Gray-Card WB gains, and 8x6 flat-field shading grids.
class ColorCalibrationStore {
  static const String _kCalPrefix = 'zamera_cal_v2_cc_';
  static const String _kWbGainsPrefix = 'zamera_cal_v2_wb_gains_';
  static const String _kWbActivePrefix = 'zamera_cal_v2_wb_active_';
  static const String _kFlatFieldPrefix = 'zamera_cal_v2_flatfield_';

  const ColorCalibrationStore();

  String _normalizedLensKey(String cameraId) {
    final trimmed = cameraId.trim();
    return trimmed.isEmpty ? '2' : trimmed;
  }

  /// Loads persisted ColorChecker calibration, Gray-Card WB gains, and 8x6 flat-field
  /// for the given physical/logical [cameraId].
  Future<StoredLensCalibration> loadForLens(String cameraId) async {
    final lensId = _normalizedLensKey(cameraId);
    try {
      final prefs = await SharedPreferences.getInstance();
      ColorCheckerCalibrationResult? calResult;
      final rawCalJson = prefs.getString('$_kCalPrefix$lensId');
      if (rawCalJson != null && rawCalJson.isNotEmpty) {
        final decoded = jsonDecode(rawCalJson);
        if (decoded is Map) {
          final parsed = ColorCheckerCalibrationResult.fromMap(decoded);
          if (parsed.isMeasuredFromSensor) {
            calResult = parsed;
          }
        }
      }

      List<double>? wbGains;
      final rawWbJson = prefs.getString('$_kWbGainsPrefix$lensId');
      if (rawWbJson != null && rawWbJson.isNotEmpty) {
        final decodedWb = jsonDecode(rawWbJson);
        if (decodedWb is List && decodedWb.length >= 3) {
          wbGains = decodedWb
              .map((e) => (e as num).toDouble())
              .toList(growable: false);
        }
      }
      final useWb =
          (prefs.getBool('$_kWbActivePrefix$lensId') ?? false) &&
          wbGains != null;

      List<double>? flatField;
      final rawFfJson = prefs.getString('$_kFlatFieldPrefix$lensId');
      if (rawFfJson != null && rawFfJson.isNotEmpty) {
        final decodedFf = jsonDecode(rawFfJson);
        if (decodedFf is List && decodedFf.length == 48) {
          flatField = decodedFf
              .map((e) => (e as num).toDouble())
              .toList(growable: false);
        }
      }

      return StoredLensCalibration(
        cameraId: lensId,
        calibrationResult: calResult,
        grayCardWbGains: wbGains,
        useGrayCardWb: useWb,
        flatField8x6: flatField,
      );
    } catch (e, st) {
      debugPrint('ColorCalibrationStore.loadForLens($lensId) error: $e\n$st');
      return StoredLensCalibration(cameraId: lensId);
    }
  }

  /// Persists a real sensor-measured [ColorCheckerCalibrationResult] for [cameraId].
  Future<bool> saveCalibrationResult(
    String cameraId,
    ColorCheckerCalibrationResult result,
  ) async {
    final lensId = _normalizedLensKey(cameraId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(result.toMap());
      return await prefs.setString('$_kCalPrefix$lensId', encoded);
    } catch (e, st) {
      debugPrint(
        'ColorCalibrationStore.saveCalibrationResult($lensId) error: $e\n$st',
      );
      return false;
    }
  }

  /// Persists measured Gray-Card WB gains and active state for [cameraId].
  Future<bool> saveGrayCardWb(
    String cameraId, {
    required List<double>? wbGains,
    required bool enabled,
  }) async {
    final lensId = _normalizedLensKey(cameraId);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (wbGains == null || wbGains.length < 3) {
        await prefs.remove('$_kWbGainsPrefix$lensId');
        await prefs.setBool('$_kWbActivePrefix$lensId', false);
        return true;
      }
      final cleanGains = <double>[wbGains[0], wbGains[1], wbGains[2]];
      final okGains = await prefs.setString(
        '$_kWbGainsPrefix$lensId',
        jsonEncode(cleanGains),
      );
      final okFlag = await prefs.setBool('$_kWbActivePrefix$lensId', enabled);
      return okGains && okFlag;
    } catch (e, st) {
      debugPrint(
        'ColorCalibrationStore.saveGrayCardWb($lensId) error: $e\n$st',
      );
      return false;
    }
  }

  /// Persists a measured 48-cell (`8x6`) flat-field shading map for [cameraId].
  Future<bool> saveFlatField8x6(
    String cameraId,
    List<double> flatField8x6,
  ) async {
    final lensId = _normalizedLensKey(cameraId);
    if (flatField8x6.length != 48) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        '$_kFlatFieldPrefix$lensId',
        jsonEncode(flatField8x6),
      );
    } catch (e, st) {
      debugPrint(
        'ColorCalibrationStore.saveFlatField8x6($lensId) error: $e\n$st',
      );
      return false;
    }
  }

  /// Clears all persisted ColorChecker, Gray-Card WB, and flat-field data for [cameraId].
  Future<bool> resetForLens(String cameraId) async {
    final lensId = _normalizedLensKey(cameraId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kCalPrefix$lensId');
      await prefs.remove('$_kWbGainsPrefix$lensId');
      await prefs.remove('$_kWbActivePrefix$lensId');
      await prefs.remove('$_kFlatFieldPrefix$lensId');
      return true;
    } catch (e, st) {
      debugPrint('ColorCalibrationStore.resetForLens($lensId) error: $e\n$st');
      return false;
    }
  }
}
