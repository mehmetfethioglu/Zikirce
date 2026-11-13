import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'zamera_capture_platform_interface.dart';

/// Official 24-patch ColorChecker Classic metadata and D50 CIE L*a*b* reference values.
class ColorCheckerPatch {
  final int index;
  final String nameTr;
  final String nameEn;
  final List<double> labD50;
  final int previewArgb;

  const ColorCheckerPatch({
    required this.index,
    required this.nameTr,
    required this.nameEn,
    required this.labD50,
    required this.previewArgb,
  });
}

/// Complete 24-Patch ColorChecker Classic reference table (X-Rite / BabelColor D50).
const List<ColorCheckerPatch> kColorChecker24Patches = [
  ColorCheckerPatch(index: 1, nameTr: 'Koyu Ten', nameEn: 'Dark Skin', labD50: [37.986, 13.555, 14.059], previewArgb: 0xFF735244),
  ColorCheckerPatch(index: 2, nameTr: 'Açık Ten', nameEn: 'Light Skin', labD50: [65.711, 18.130, 17.810], previewArgb: 0xFFC29682),
  ColorCheckerPatch(index: 3, nameTr: 'Gök Mavisi', nameEn: 'Blue Sky', labD50: [49.927, -4.880, -21.925], previewArgb: 0xFF627A9D),
  ColorCheckerPatch(index: 4, nameTr: 'Yaprak Yeşili', nameEn: 'Foliage', labD50: [43.139, -13.095, 21.905], previewArgb: 0xFF576C43),
  ColorCheckerPatch(index: 5, nameTr: 'Mavi Çiçek', nameEn: 'Blue Flower', labD50: [55.112, 8.844, -25.399], previewArgb: 0xFF8580B1),
  ColorCheckerPatch(index: 6, nameTr: 'Mavimsi Yeşil', nameEn: 'Bluish Green', labD50: [70.719, -33.397, -0.199], previewArgb: 0xFF67BDAA),
  ColorCheckerPatch(index: 7, nameTr: 'Turuncu', nameEn: 'Orange', labD50: [62.661, 36.067, 57.096], previewArgb: 0xFFD67E2C),
  ColorCheckerPatch(index: 8, nameTr: 'Morumsu Mavi', nameEn: 'Purplish Blue', labD50: [40.020, 10.410, -45.964], previewArgb: 0xFF505BA6),
  ColorCheckerPatch(index: 9, nameTr: 'Orta Kırmızı', nameEn: 'Moderate Red', labD50: [51.124, 48.239, 16.248], previewArgb: 0xFFC15A63),
  ColorCheckerPatch(index: 10, nameTr: 'Mor', nameEn: 'Purple', labD50: [30.325, 22.976, -21.587], previewArgb: 0xFF5E3C6C),
  ColorCheckerPatch(index: 11, nameTr: 'Sarı Yeşil', nameEn: 'Yellow Green', labD50: [72.532, -23.709, 57.255], previewArgb: 0xFF9DBC40),
  ColorCheckerPatch(index: 12, nameTr: 'Turuncu Sarı', nameEn: 'Orange Yellow', labD50: [71.941, 19.363, 67.857], previewArgb: 0xFFE0A32E),
  ColorCheckerPatch(index: 13, nameTr: 'Kobalt Mavisi', nameEn: 'Blue', labD50: [28.778, 14.179, -50.297], previewArgb: 0xFF383D96),
  ColorCheckerPatch(index: 14, nameTr: 'Yeşil', nameEn: 'Green', labD50: [55.261, -38.342, 31.370], previewArgb: 0xFF469449),
  ColorCheckerPatch(index: 15, nameTr: 'Kırmızı', nameEn: 'Red', labD50: [42.101, 53.378, 28.190], previewArgb: 0xFFAF363C),
  ColorCheckerPatch(index: 16, nameTr: 'Sarı', nameEn: 'Yellow', labD50: [81.733, 4.039, 79.819], previewArgb: 0xFFE7C71F),
  ColorCheckerPatch(index: 17, nameTr: 'Macenta', nameEn: 'Magenta', labD50: [51.935, 49.986, -14.574], previewArgb: 0xFFBB5695),
  ColorCheckerPatch(index: 18, nameTr: 'Camgöbeği (Cyan)', nameEn: 'Cyan', labD50: [51.038, -28.631, -28.638], previewArgb: 0xFF0885A1),
  ColorCheckerPatch(index: 19, nameTr: 'Beyaz 9.5', nameEn: 'White 9.5', labD50: [96.539, -0.425, 1.186], previewArgb: 0xFFF3F3F2),
  ColorCheckerPatch(index: 20, nameTr: 'Nötr Gri 8 (WB Referans)', nameEn: 'Neutral 8', labD50: [81.257, -0.638, -0.335], previewArgb: 0xFFC8C8C8),
  ColorCheckerPatch(index: 21, nameTr: 'Nötr Gri 6.5', nameEn: 'Neutral 6.5', labD50: [66.766, -0.734, -0.504], previewArgb: 0xFFA0A0A0),
  ColorCheckerPatch(index: 22, nameTr: 'Nötr Gri 5 (%18 Gri Kart)', nameEn: 'Neutral 5 (18% Gray)', labD50: [50.867, -0.153, -0.270], previewArgb: 0xFF7A7A79),
  ColorCheckerPatch(index: 23, nameTr: 'Nötr Gri 3.5', nameEn: 'Neutral 3.5', labD50: [35.656, -0.421, -1.231], previewArgb: 0xFF555555),
  ColorCheckerPatch(index: 24, nameTr: 'Siyah 2', nameEn: 'Black 2', labD50: [20.461, -0.079, -0.973], previewArgb: 0xFF343434),
];

/// Result of the 24-Patch ColorChecker 3x3 calibration solver.
class ColorCheckerCalibrationResult {
  final List<double> wbGains;
  final List<List<double>> camToXyzD50;
  final double meanDeltaEBefore;
  final double meanDeltaEAfter;
  final double maxDeltaEAfter;
  final List<double> patchDeltaEBefore;
  final List<double> patchDeltaEAfter;
  final bool isMeasuredFromSensor;

  const ColorCheckerCalibrationResult({
    required this.wbGains,
    required this.camToXyzD50,
    required this.meanDeltaEBefore,
    required this.meanDeltaEAfter,
    required this.maxDeltaEAfter,
    required this.patchDeltaEBefore,
    required this.patchDeltaEAfter,
    this.isMeasuredFromSensor = false,
  });

  List<double> get flattenedCamToXyzD50 => [
        camToXyzD50[0][0],
        camToXyzD50[0][1],
        camToXyzD50[0][2],
        camToXyzD50[1][0],
        camToXyzD50[1][1],
        camToXyzD50[1][2],
        camToXyzD50[2][0],
        camToXyzD50[2][1],
        camToXyzD50[2][2],
      ];

  factory ColorCheckerCalibrationResult.fromMap(Map<dynamic, dynamic> map) {
    const fallbackMatrix = <List<double>>[
      [0.4360747, 0.3850649, 0.1430804],
      [0.2225045, 0.7168786, 0.0606169],
      [0.0139322, 0.0971045, 0.7141733],
    ];
    final rawMat = map['camToXyzD50'] ?? map['flattenedCamToXyzD50'];
    List<List<double>> parsedMat = fallbackMatrix;
    if (rawMat is List && rawMat.isNotEmpty) {
      if (rawMat.length == 3 && rawMat.first is List) {
        parsedMat = rawMat
            .map((row) => (row as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList(growable: false))
            .toList(growable: false);
      } else if (rawMat.length >= 9 && rawMat.first is num) {
        final f = rawMat.map((e) => (e as num).toDouble()).toList(growable: false);
        parsedMat = [
          [f[0], f[1], f[2]],
          [f[3], f[4], f[5]],
          [f[6], f[7], f[8]],
        ];
      }
    }

    final wbList = (map['wbGains'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList(growable: false);

    return ColorCheckerCalibrationResult(
      wbGains: (wbList != null && wbList.length >= 3)
          ? wbList.sublist(0, 3)
          : const [1.0, 1.0, 1.0],
      camToXyzD50: parsedMat,
      meanDeltaEBefore: (map['meanDeltaEBefore'] as num?)?.toDouble() ?? 0.0,
      meanDeltaEAfter: (map['meanDeltaEAfter'] as num?)?.toDouble() ?? 0.0,
      maxDeltaEAfter: (map['maxDeltaEAfter'] as num?)?.toDouble() ?? 0.0,
      patchDeltaEBefore: (map['patchDeltaEBefore'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(growable: false) ??
          List<double>.filled(24, 0.0),
      patchDeltaEAfter: (map['patchDeltaEAfter'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(growable: false) ??
          List<double>.filled(24, 0.0),
      isMeasuredFromSensor: map['isMeasuredFromSensor'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wbGains': wbGains,
      'camToXyzD50': camToXyzD50,
      'meanDeltaEBefore': meanDeltaEBefore,
      'meanDeltaEAfter': meanDeltaEAfter,
      'maxDeltaEAfter': maxDeltaEAfter,
      'patchDeltaEBefore': patchDeltaEBefore,
      'patchDeltaEAfter': patchDeltaEAfter,
      'isMeasuredFromSensor': isMeasuredFromSensor,
    };
  }
}

/// Active native preview texture session details.
class PreviewSessionInfo {
  final int textureId;
  final int previewWidth;
  final int previewHeight;
  final int sensorOrientation;
  final String activeCameraId;
  final bool supportsRawSensor;
  final double minimumFocusDistanceDiopters;
  final int isoMin;
  final int isoMax;
  final int exposureNsMin;
  final int exposureNsMax;

  const PreviewSessionInfo({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientation,
    required this.activeCameraId,
    required this.supportsRawSensor,
    this.minimumFocusDistanceDiopters = 10.0,
    this.isoMin = 50,
    this.isoMax = 3200,
    this.exposureNsMin = 50000,
    this.exposureNsMax = 1000000000,
  });

  bool get supportsVariableFocus => minimumFocusDistanceDiopters > 0.0;

  factory PreviewSessionInfo.fromMap(Map<dynamic, dynamic> map) {
    return PreviewSessionInfo(
      textureId: (map['textureId'] as num?)?.toInt() ?? -1,
      previewWidth: (map['previewWidth'] as num?)?.toInt() ?? 1440,
      previewHeight: (map['previewHeight'] as num?)?.toInt() ?? 1080,
      sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 90,
      activeCameraId: map['activeCameraId']?.toString() ?? '2',
      supportsRawSensor: map['supportsRawSensor'] == true,
      minimumFocusDistanceDiopters:
          (map['minimumFocusDistanceDiopters'] as num?)?.toDouble() ?? 10.0,
      isoMin: (map['isoMin'] as num?)?.toInt() ?? 50,
      isoMax: (map['isoMax'] as num?)?.toInt() ?? 3200,
      exposureNsMin: (map['exposureNsMin'] as num?)?.toInt() ?? 50000,
      exposureNsMax: (map['exposureNsMax'] as num?)?.toInt() ?? 1000000000,
    );
  }
}

/// Result of a still RAW (.dng) + TrueColor / OEM JPEG photo capture.
class CapturePhotoResult {
  final String? jpegPath;
  final String? oemJpegPath;
  final String? dngPath;
  final String? mediaStoreJpegUri;
  final String? mediaStoreDngUri;
  final String cameraId;
  final int? iso;
  final int? exposureTimeNs;
  final int? outputWidth;
  final int? outputHeight;
  final bool rustIspActive;
  final bool lensShadingApplied;
  final bool portraitDepthActive;
  final double? whiteLevel;
  final List<double>? blackLevel;
  final List<double>? wbGainsUsed;
  final List<double>? centerLinearCamRgb;
  final List<double>? meanRgb;
  final double? highlightClippedRatio;
  final double? gamutClippedRatio;
  final double? exposureNormGain;
  final double? solvedCctKelvin;
  final double? zebraRatio;
  final double? focusPeakingScore;
  final List<double>? rawHistogram32;
  final List<double>? measuredFlatField8x6;
  final ColorCheckerCalibrationResult? liveCalibrationResult;
  final List<double>? centerLabD50;
  final String? colorSpaceTag;

  const CapturePhotoResult({
    this.jpegPath,
    this.oemJpegPath,
    this.dngPath,
    this.mediaStoreJpegUri,
    this.mediaStoreDngUri,
    required this.cameraId,
    this.iso,
    this.exposureTimeNs,
    this.outputWidth,
    this.outputHeight,
    this.rustIspActive = false,
    this.lensShadingApplied = false,
    this.portraitDepthActive = false,
    this.whiteLevel,
    this.blackLevel,
    this.wbGainsUsed,
    this.centerLinearCamRgb,
    this.meanRgb,
    this.highlightClippedRatio,
    this.gamutClippedRatio,
    this.exposureNormGain,
    this.solvedCctKelvin,
    this.zebraRatio,
    this.focusPeakingScore,
    this.rawHistogram32,
    this.measuredFlatField8x6,
    this.liveCalibrationResult,
    this.centerLabD50,
    this.colorSpaceTag,
  });

  factory CapturePhotoResult.fromMap(Map<dynamic, dynamic> map) {
    return CapturePhotoResult(
      jpegPath: map['jpegPath']?.toString(),
      oemJpegPath: map['oemJpegPath']?.toString(),
      dngPath: map['dngPath']?.toString(),
      mediaStoreJpegUri: map['mediaStoreJpegUri']?.toString(),
      mediaStoreDngUri: map['mediaStoreDngUri']?.toString(),
      cameraId: map['cameraId']?.toString() ?? '2',
      iso: (map['iso'] as num?)?.toInt(),
      exposureTimeNs: (map['exposureTimeNs'] as num?)?.toInt(),
      outputWidth: (map['outputWidth'] as num?)?.toInt(),
      outputHeight: (map['outputHeight'] as num?)?.toInt(),
      rustIspActive: map['rustIspActive'] == true,
      lensShadingApplied: map['lensShadingApplied'] == true,
      portraitDepthActive: map['portraitDepthActive'] == true,
      whiteLevel: (map['whiteLevel'] as num?)?.toDouble(),
      blackLevel: (map['blackLevel'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      wbGainsUsed: (map['wbGainsUsed'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      centerLinearCamRgb: (map['centerLinearCamRgb'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      meanRgb: (map['meanRgb'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      highlightClippedRatio: (map['highlightClippedRatio'] as num?)?.toDouble(),
      gamutClippedRatio: (map['gamutClippedRatio'] as num?)?.toDouble(),
      exposureNormGain: (map['exposureNormGain'] as num?)?.toDouble(),
      solvedCctKelvin: (map['solvedCctKelvin'] as num?)?.toDouble(),
      zebraRatio: (map['zebraRatio'] as num?)?.toDouble(),
      focusPeakingScore: (map['focusPeakingScore'] as num?)?.toDouble(),
      rawHistogram32: (map['rawHistogram32'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      measuredFlatField8x6: (map['measuredFlatField8x6'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      liveCalibrationResult: map['liveCalibrationResult'] is Map
          ? ColorCheckerCalibrationResult.fromMap(
              map['liveCalibrationResult'] as Map<dynamic, dynamic>,
            )
          : null,
      centerLabD50: (map['centerLabD50'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      colorSpaceTag: map['colorSpaceTag']?.toString(),
    );
  }
}

/// Structured capability report for a single logical or physical camera unit.
class CameraUnitCapability {
  final String cameraId;
  final bool isDirectlyOpenable;
  final String facing;
  final String hardwareLevel;
  final int sensorOrientation;
  final bool lensShadingApplied;
  final List<String> capabilities;
  final bool supportsRawSensor;
  final List<String> rawSensorSizes;
  final List<String> maxResolutionRawSensorSizes;
  final List<String> physicalCameraIds;
  final List<double> focalLengthsMm;
  final List<double> apertures;
  final double minimumFocusDistanceDiopters;
  final List<double>? isoRange;
  final List<int>? exposureTimeRangeNs;
  final int? sensorWhiteLevel;
  final List<String> tenBitDynamicRangeProfiles;
  final bool supportsOis;
  final String? error;

  const CameraUnitCapability({
    required this.cameraId,
    required this.isDirectlyOpenable,
    required this.facing,
    required this.hardwareLevel,
    this.sensorOrientation = 90,
    this.lensShadingApplied = false,
    required this.capabilities,
    required this.supportsRawSensor,
    required this.rawSensorSizes,
    required this.maxResolutionRawSensorSizes,
    required this.physicalCameraIds,
    required this.focalLengthsMm,
    required this.apertures,
    this.minimumFocusDistanceDiopters = 0.0,
    this.isoRange,
    this.exposureTimeRangeNs,
    this.sensorWhiteLevel,
    required this.tenBitDynamicRangeProfiles,
    required this.supportsOis,
    this.error,
  });

  bool get supportsVariableFocus => minimumFocusDistanceDiopters > 0.0;

  String get opticalBadgeLabel {
    if (facing == 'FRONT') return 'Ön Kamera (#$cameraId)';
    final fl = focalLengthsMm.isNotEmpty ? focalLengthsMm.first : 0.0;
    final ap = apertures.isNotEmpty ? apertures.first : 0.0;
    final eqMm = fl >= 6.0
        ? '23mm'
        : (fl >= 2.0 ? '14mm Ultra' : '#$cameraId');
    final apStr = ap > 0 ? ' · f/${ap.toStringAsFixed(1)}' : '';
    final oisStr = supportsOis ? ' · OIS' : '';
    final bitStr = (sensorWhiteLevel ?? 0) > 4000 ? ' (14b)' : '';
    return '$eqMm$apStr$oisStr$bitStr (#$cameraId)';
  }

  factory CameraUnitCapability.fromMap(Map<dynamic, dynamic> map) {
    return CameraUnitCapability(
      cameraId: map['cameraId']?.toString() ?? 'unknown',
      isDirectlyOpenable: map['isDirectlyOpenableInCameraIdList'] == true,
      facing: map['facing']?.toString() ?? 'UNKNOWN',
      hardwareLevel: map['hardwareLevel']?.toString() ?? 'UNKNOWN',
      sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 90,
      lensShadingApplied: map['lensShadingApplied'] == true,
      capabilities: (map['capabilities'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      supportsRawSensor: map['supportsRawSensor'] == true,
      rawSensorSizes: (map['rawSensorSizes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      maxResolutionRawSensorSizes:
          (map['maxResolutionRawSensorSizes'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      physicalCameraIds:
          (map['physicalCameraIds'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      focalLengthsMm: (map['focalLengthsMm'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      apertures: (map['apertures'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      minimumFocusDistanceDiopters:
          (map['minimumFocusDistanceDiopters'] as num?)?.toDouble() ?? 0.0,
      isoRange: (map['isoRange'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      exposureTimeRangeNs: (map['exposureTimeRangeNs'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      sensorWhiteLevel: (map['sensorWhiteLevel'] as num?)?.toInt(),
      tenBitDynamicRangeProfiles:
          (map['tenBitDynamicRangeProfiles'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      supportsOis: map['supportsOis'] == true,
      error: map['error']?.toString(),
    );
  }
}

/// Complete device hardware & API probe report (Faz 0 deliverable).
class ZameraProbeReport {
  final String platform;
  final String manufacturer;
  final String brand;
  final String model;
  final String device;
  final int sdkInt;
  final String release;
  final String rustCoreVersion;
  final List<String> cameraIdList;
  final List<CameraUnitCapability> cameras;
  final Map<String, dynamic> rawJsonMap;

  const ZameraProbeReport({
    required this.platform,
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.sdkInt,
    required this.release,
    required this.rustCoreVersion,
    required this.cameraIdList,
    required this.cameras,
    required this.rawJsonMap,
  });

  CameraUnitCapability? cameraById(String id) {
    for (final c in cameras) {
      if (c.cameraId == id) return c;
    }
    return null;
  }

  factory ZameraProbeReport.fromMap(Map<dynamic, dynamic> map) {
    final normalized = Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
    final rawCams = map['cameras'] as List<dynamic>? ?? const [];
    return ZameraProbeReport(
      platform: map['platform']?.toString() ?? 'unknown',
      manufacturer: map['manufacturer']?.toString() ?? 'unknown',
      brand: map['brand']?.toString() ?? 'unknown',
      model: map['model']?.toString() ?? 'unknown',
      device: map['device']?.toString() ?? 'unknown',
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      release: map['release']?.toString() ?? '',
      rustCoreVersion: map['rustCoreVersion']?.toString() ?? 'UNKNOWN',
      cameraIdList: (map['cameraIdList'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      cameras: rawCams
          .whereType<Map<dynamic, dynamic>>()
          .map(CameraUnitCapability.fromMap)
          .toList(),
      rawJsonMap: normalized,
    );
  }

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(rawJsonMap);
}

/// Primary interface for `zamera_capture` (Sanat Modu + Pro Foto + Cihaz Probe).
class ZameraCapture {
  /// Returns the current platform version via platform interface.
  Future<String?> getPlatformVersion() {
    return ZameraCapturePlatform.instance.getPlatformVersion();
  }
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zamera/capture_probe');

  /// Runs the native Camera2 (Android) or AVFoundation (iOS) capability probe.
  static Future<ZameraProbeReport> probeDeviceCapabilities() async {
    final map = await _channel
        .invokeMapMethod<dynamic, dynamic>('probeDeviceCapabilities');
    if (map == null) {
      throw PlatformException(
        code: 'EMPTY_PROBE',
        message: 'Native probe returned null map',
      );
    }
    return ZameraProbeReport.fromMap(map);
  }

  /// Starts a zero-copy GPU texture preview session on the specified physical or logical lens.
  static Future<PreviewSessionInfo> startPreviewSession({
    required String cameraId,
    int width = 1920,
    int height = 1440,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'startPreviewSession',
      {'cameraId': cameraId, 'width': width, 'height': height},
    );
    if (map == null) {
      throw PlatformException(
        code: 'PREVIEW_NULL',
        message: 'startPreviewSession returned null',
      );
    }
    return PreviewSessionInfo.fromMap(map);
  }

  /// Dynamically locks/updates manual ISO, Shutter Speed, EV Compensation, Focus Distance,
  /// Optical/Digital Zoom Ratio, and DNG-interpolated Kelvin/Tint White Balance.
  static Future<bool> updateManualControls({
    required bool manualExposure,
    bool? manualIso,
    bool? manualShutter,
    bool aeAfLocked = false,
    required double iso,
    required int exposureTimeNs,
    double evCompensation = 0.0,
    required bool manualFocus,
    required double focusDistance,
    required bool manualWb,
    double kelvin = 5500.0,
    double tint = 0.0,
    required List<double> rggbGains,
    bool artworkLinearMode = false,
    double zoomRatio = 1.0,
    bool monoMode = false,
    List<double>? customWbGains,
    List<double>? camToXyzD50,
  }) async {
    final ok = await _channel.invokeMethod<bool>('updateManualControls', {
      'manualExposure': manualExposure,
      'manualIso': manualIso ?? manualExposure,
      'manualShutter': manualShutter ?? manualExposure,
      'aeAfLocked': aeAfLocked,
      'iso': iso,
      'exposureTimeNs': exposureTimeNs,
      'evCompensation': evCompensation,
      'manualFocus': manualFocus,
      'focusDistance': focusDistance,
      'manualWb': manualWb,
      'kelvin': kelvin,
      'tint': tint,
      'rggbGains': rggbGains,
      'artworkLinearMode': artworkLinearMode,
      'zoomRatio': zoomRatio,
      'monoMode': monoMode,
      'customWbGains': ?customWbGains,
      'camToXyzD50': ?camToXyzD50,
    });
    return ok == true;
  }

  /// Sets tap-to-focus and AE spot metering region at normalized coordinates `(x, y)` in `[0..1]`.
  static Future<bool> setFocusAndMeteringPoint({
    required double x,
    required double y,
    bool lockAeAf = false,
  }) async {
    final ok = await _channel.invokeMethod<bool>(
      'setFocusAndMeteringPoint',
      {
        'x': x,
        'y': y,
        'lockAeAf': lockAeAf,
      },
    );
    return ok == true;
  }

  /// Reads live hardware telemetry (`iso`, `exposureTimeNs`, `focusDistanceDiopters`, `wbGains`, `asShotNeutral`).
  static Future<Map<String, dynamic>> getLiveTelemetry() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('getLiveTelemetry');
    if (map == null) return const {};
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Triggers a still RAW (.dng) + TrueColor (12.6MP) / Pro / Portrait JPEG photo capture on the active camera session.
  static Future<CapturePhotoResult> capturePhoto({
    bool captureRaw = true,
    bool isArtworkMode = true,
    bool isPortraitMode = false,
    double portraitAperture = 2.8,
    int portraitLighting = 0,
    double portraitLightIntensity = 0.80,
    double portraitSubjectRadius = 0.36,
    double focusPointX = 0.5,
    double focusPointY = 0.45,
    double zoomRatio = 1.0,
    bool preferProRaw = false,
    bool useDisplayP3 = false,
    bool fullResolution = true,
    bool normalizeExposure = true,
    int artworkExposureMode = 2,
    bool calibrateColorChecker = false,
    bool losslessPng = false,
    bool applyPerspectiveWarp = false,
    List<double>? perspectiveCornersNorm,
    List<double>? wbGains,
    List<double>? camToXyzD50,
    List<double>? flatFieldGrid8x6,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'capturePhoto',
      {
        'captureRaw': captureRaw,
        'isArtworkMode': isArtworkMode,
        'isPortraitMode': isPortraitMode,
        'portraitAperture': portraitAperture,
        'portraitLighting': portraitLighting,
        'portraitLightIntensity': portraitLightIntensity,
        'portraitSubjectRadius': portraitSubjectRadius,
        'focusPointX': focusPointX,
        'focusPointY': focusPointY,
        'zoomRatio': zoomRatio,
        'preferProRaw': preferProRaw,
        'useDisplayP3': useDisplayP3,
        'fullResolution': fullResolution,
        'normalizeExposure': normalizeExposure,
        'artworkExposureMode': artworkExposureMode,
        'calibrateColorChecker': calibrateColorChecker,
        'losslessPng': losslessPng,
        'applyPerspectiveWarp': applyPerspectiveWarp,
        'perspectiveCornersNorm': ?perspectiveCornersNorm,
        'wbGains': ?wbGains,
        'camToXyzD50': ?camToXyzD50,
        'flatFieldGrid8x6': ?flatFieldGrid8x6,
      },
    );
    if (map == null) {
      throw PlatformException(
        code: 'CAPTURE_NULL',
        message: 'capturePhoto returned null',
      );
    }
    return CapturePhotoResult.fromMap(map);
  }

  /// Triggers a 3-frame AE Bracketed RAW+JPEG capture (`[-1.5 EV, 0.0 EV, +1.5 EV]`).
  static Future<List<CapturePhotoResult>> captureBracketedPhotos({
    List<double> evOffsets = const [-1.5, 0.0, 1.5],
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'captureBracketedPhotos',
      {'evOffsets': evOffsets},
    );
    final rawList = map?['captures'] as List<dynamic>? ?? const [];
    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map(CapturePhotoResult.fromMap)
        .toList();
  }

  /// Stops the active native preview session and releases the GPU texture.
  static Future<void> stopPreviewSession() async {
    await _channel.invokeMethod<void>('stopPreviewSession');
  }

  /// Post-capture interactive Portrait Re-Focus, Aperture (`f/1.4..f/16`), and Studio Lighting reprocessing.
  static Future<Map<String, dynamic>> reprocessPortraitPhoto({
    required String sourceJpegPath,
    required double aperture,
    required int lightingMode,
    required double lightIntensity,
    required double subjectRadiusRatio,
    required double focusX,
    required double focusY,
    bool isFrontCamera = false,
    bool saveToGallery = false,
    bool portraitEnabled = true,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'reprocessPortraitPhoto',
      {
        'sourceJpegPath': sourceJpegPath,
        'aperture': aperture,
        'lightingMode': lightingMode,
        'lightIntensity': lightIntensity,
        'subjectRadiusRatio': subjectRadiusRatio,
        'focusX': focusX,
        'focusY': focusY,
        'isFrontCamera': isFrontCamera,
        'saveToGallery': saveToGallery,
        'portraitEnabled': portraitEnabled,
      },
    );
    if (map == null) return const {};
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// iOS / Xiaomi Style Subject Lift & Cutout Sticker Extractor:
  /// Segments the person or tapped object into a 100% transparent PNG (`ZAM_..._CUTOUT.png`),
  /// copies the sticker to the system clipboard, optionally saves to gallery, and optionally opens Share sheet.
  static Future<Map<String, dynamic>> extractSubjectCutoutPng({
    required String sourceJpegPath,
    double focusX = 0.5,
    double focusY = 0.45,
    double subjectRadiusRatio = 0.36,
    bool isFrontCamera = false,
    bool shareNow = false,
    bool saveToGallery = false,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'extractSubjectCutoutPng',
      {
        'sourceJpegPath': sourceJpegPath,
        'focusX': focusX,
        'focusY': focusY,
        'subjectRadiusRatio': subjectRadiusRatio,
        'isFrontCamera': isFrontCamera,
        'shareNow': shareNow,
        'saveToGallery': saveToGallery,
      },
    );
    if (map == null) return const {};
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Converts Kelvin (2000K..10000K) and Tint (-50..+50) into RGGB channel gains.
  static List<double> kelvinAndTintToRggbGains(double kelvin, double tint) {
    final temp = kelvin.clamp(2000.0, 10000.0) / 100.0;
    final rGain = (temp / 55.0).clamp(0.8, 3.2);
    final bGain = (55.0 / temp).clamp(0.8, 3.2);
    final gTint = (1.0 - (tint / 250.0)).clamp(0.8, 1.5);
    return [rGain, gTint, gTint, bGain];
  }

  /// Converts CIE L*a*b* (D50) to CIE XYZ (D50).
  static List<double> labD50ToXyz(List<double> lab) {
    const d50 = [0.96422, 1.00000, 0.82521];
    const epsilon = 216.0 / 24389.0;
    const kappa = 24389.0 / 27.0;

    final fy = (lab[0] + 16.0) / 116.0;
    final fx = fy + (lab[1] / 500.0);
    final fz = fy - (lab[2] / 200.0);

    double invF(double fVal) {
      final f3 = fVal * fVal * fVal;
      return f3 > epsilon ? f3 : (116.0 * fVal - 16.0) / kappa;
    }

    return [d50[0] * invF(fx), d50[1] * invF(fy), d50[2] * invF(fz)];
  }

  /// Converts CIE XYZ (D50) to CIE L*a*b* (D50).
  static List<double> xyzD50ToLab(List<double> xyz) {
    const d50 = [0.96422, 1.00000, 0.82521];
    const epsilon = 216.0 / 24389.0;
    const kappa = 24389.0 / 27.0;

    double f(double t) =>
        t > epsilon ? math.pow(t, 1.0 / 3.0).toDouble() : (kappa * t + 16.0) / 116.0;

    final fx = f(xyz[0] / d50[0]);
    final fy = f(xyz[1] / d50[1]);
    final fz = f(xyz[2] / d50[2]);
    return [116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)];
  }

  static List<double> _mat3MulVec3(List<List<double>> m, List<double> v) {
    return [
      m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
      m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
      m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ];
  }

  static List<List<double>>? _mat3Inverse(List<List<double>> m) {
    final c00 = m[1][1] * m[2][2] - m[1][2] * m[2][1];
    final c01 = -(m[1][0] * m[2][2] - m[1][2] * m[2][0]);
    final c02 = m[1][0] * m[2][1] - m[1][1] * m[2][0];
    final det = m[0][0] * c00 + m[0][1] * c01 + m[0][2] * c02;
    if (det.abs() < 1e-12) return null;
    final invDet = 1.0 / det;

    final c10 = -(m[0][1] * m[2][2] - m[0][2] * m[2][1]);
    final c11 = m[0][0] * m[2][2] - m[0][2] * m[2][0];
    final c12 = -(m[0][0] * m[2][1] - m[0][1] * m[2][0]);
    final c20 = m[0][1] * m[1][2] - m[0][2] * m[1][1];
    final c21 = -(m[0][0] * m[1][2] - m[0][2] * m[1][0]);
    final c22 = m[0][0] * m[1][1] - m[0][1] * m[1][0];

    return [
      [c00 * invDet, c10 * invDet, c20 * invDet],
      [c01 * invDet, c11 * invDet, c21 * invDet],
      [c02 * invDet, c12 * invDet, c22 * invDet],
    ];
  }

  /// Solves the 24-Patch ColorChecker 3x3 calibration matrix and neutral Gray-Card WB gains
  /// with D50 white-point (`[0.96422, 1.0, 0.82521]`) constraint and neutral-gray weighting
  /// (exact mirror of `zamera_core::calibrate_colorchecker_24`).
  static ColorCheckerCalibrationResult calibrateColorChecker24(
    List<List<double>> measuredCamRgb, {
    bool isMeasuredFromSensor = false,
  }) {
    assert(measuredCamRgb.length == 24);
    const d50White = [0.96422, 1.00000, 0.82521];
    const mSrgbToXyzD50 = [
      [0.4360747, 0.3850649, 0.1430804],
      [0.2225045, 0.7168786, 0.0606169],
      [0.0139322, 0.0971045, 0.7141733],
    ];

    final refXyz = kColorChecker24Patches
        .map((p) => labD50ToXyz(p.labD50))
        .toList(growable: false);

    // Per-patch regression weights: boost neutral gray ramp (patches 19..24 -> indices 18..23)
    final weights = List<double>.generate(24, (i) {
      if (i >= 19 && i <= 22) return 4.0;
      if (i >= 18) return 2.5;
      return 1.0;
    });

    // Stage 1: Weighted unconstrained sensor->XYZ solve to locate exact D50 white response
    final rawXxt = [
      [1e-8, 0.0, 0.0],
      [0.0, 1e-8, 0.0],
      [0.0, 0.0, 1e-8],
    ];
    final rawYxt = [
      [0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0],
    ];
    for (var i = 0; i < 24; i++) {
      final w = weights[i];
      final x = measuredCamRgb[i];
      final y = refXyz[i];
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          rawXxt[r][c] += w * x[r] * x[c];
          rawYxt[r][c] += w * y[r] * x[c];
        }
      }
    }

    List<double>? solvedWbGains;
    final rawXxtInv = _mat3Inverse(rawXxt);
    if (rawXxtInv != null) {
      final mRaw = List<List<double>>.generate(3, (r) {
        return List<double>.generate(3, (c) {
          return rawYxt[r][0] * rawXxtInv[0][c] +
              rawYxt[r][1] * rawXxtInv[1][c] +
              rawYxt[r][2] * rawXxtInv[2][c];
        });
      });
      final mRawInv = _mat3Inverse(mRaw);
      if (mRawInv != null) {
        final camWhite = _mat3MulVec3(mRawInv, d50White);
        if (camWhite[0] > 1e-5 && camWhite[1] > 1e-5 && camWhite[2] > 1e-5) {
          solvedWbGains = [
            1.0 / camWhite[0],
            1.0 / camWhite[1],
            1.0 / camWhite[2],
          ];
        }
      }
    }

    final List<double> wbGains;
    if (solvedWbGains != null) {
      wbGains = solvedWbGains;
    } else {
      final p20 = measuredCamRgb[19];
      final p22 = measuredCamRgb[21];
      final rAvg = math.max(1e-6, 0.5 * (p20[0] + p22[0]));
      final gAvg = math.max(1e-6, 0.5 * (p20[1] + p22[1]));
      final bAvg = math.max(1e-6, 0.5 * (p20[2] + p22[2]));
      final exposureScale = refXyz[21][1] / math.max(1e-6, p22[1]);
      wbGains = [
        (gAvg / rAvg) * exposureScale,
        1.0 * exposureScale,
        (gAvg / bAvg) * exposureScale,
      ];
    }

    final wbRgb = List<List<double>>.generate(24, (i) {
      return [
        measuredCamRgb[i][0] * wbGains[0],
        measuredCamRgb[i][1] * wbGains[1],
        measuredCamRgb[i][2] * wbGains[2],
      ];
    });

    final patchDeBefore = <double>[];
    var sumBefore = 0.0;
    for (var i = 0; i < 24; i++) {
      final naiveXyz = _mat3MulVec3(mSrgbToXyzD50, measuredCamRgb[i]);
      final naiveLab = xyzD50ToLab(naiveXyz);
      final de = computeCiede2000(kColorChecker24Patches[i].labD50, naiveLab);
      patchDeBefore.add(de);
      sumBefore += de;
    }

    // Stage 2: Exact D50 white-point constrained (M * [1,1,1]^T = D50) + neutral-weighted 2x2 least squares per row
    var a00 = 1e-8;
    var a01 = 0.0;
    var a11 = 1e-8;
    final b0 = [0.0, 0.0, 0.0];
    final b1 = [0.0, 0.0, 0.0];

    for (var i = 0; i < 24; i++) {
      final w = weights[i];
      final r = wbRgb[i][0];
      final g = wbRgb[i][1];
      final b = wbRgb[i][2];
      final u = r - g;
      final v = b - g;
      a00 += w * u * u;
      a01 += w * u * v;
      a11 += w * v * v;
      for (var k = 0; k < 3; k++) {
        final zk = refXyz[i][k] - d50White[k] * g;
        b0[k] += w * u * zk;
        b1[k] += w * v * zk;
      }
    }

    final det2 = a00 * a11 - a01 * a01;
    final List<List<double>> camToXyzD50;
    if (det2.abs() > 1e-14) {
      final invDet2 = 1.0 / det2;
      camToXyzD50 = List<List<double>>.generate(3, (k) {
        final m0 = (a11 * b0[k] - a01 * b1[k]) * invDet2;
        final m2 = (-a01 * b0[k] + a00 * b1[k]) * invDet2;
        final m1 = d50White[k] - m0 - m2;
        return [m0, m1, m2];
      }, growable: false);
    } else {
      camToXyzD50 = mSrgbToXyzD50;
    }

    final patchDeAfter = <double>[];
    var sumAfter = 0.0;
    var maxAfter = 0.0;
    for (var i = 0; i < 24; i++) {
      final calXyz = _mat3MulVec3(camToXyzD50, wbRgb[i]);
      final calLab = xyzD50ToLab(calXyz);
      final de = computeCiede2000(kColorChecker24Patches[i].labD50, calLab);
      patchDeAfter.add(de);
      sumAfter += de;
      if (de > maxAfter) maxAfter = de;
    }

    return ColorCheckerCalibrationResult(
      wbGains: wbGains,
      camToXyzD50: camToXyzD50,
      meanDeltaEBefore: sumBefore / 24.0,
      meanDeltaEAfter: sumAfter / 24.0,
      maxDeltaEAfter: maxAfter,
      patchDeltaEBefore: patchDeBefore,
      patchDeltaEAfter: patchDeAfter,
      isMeasuredFromSensor: isMeasuredFromSensor,
    );
  }

  /// Converts 8-bit sRGB `(r, g, b)` in `[0..255]` to CIE L*a*b* (D50):
  /// IEC 61966-2-1 sRGB EOTF -> CIE XYZ (D65) -> Bradford D65->D50 -> CIE L*a*b* (D50).
  static List<double> srgb8ToLabD50(int r, int g, int b) {
    double eotf(int code) {
      final c = (code.clamp(0, 255)) / 255.0;
      return c <= 0.04045
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final lin = [eotf(r), eotf(g), eotf(b)];
    const mSrgbToXyzD65 = [
      [0.4124564, 0.3575761, 0.1804375],
      [0.2126729, 0.7151522, 0.0721750],
      [0.0193339, 0.1191920, 0.9503041],
    ];
    const mBradfordD65ToD50 = [
      [1.0478112, 0.0228866, -0.0501270],
      [0.0295424, 0.9904844, -0.0170491],
      [-0.0092345, 0.0150436, 0.7521316],
    ];
    final xyzD65 = _mat3MulVec3(mSrgbToXyzD65, lin);
    final xyzD50 = _mat3MulVec3(mBradfordD65ToD50, xyzD65);
    return xyzD50ToLab(xyzD50);
  }

  /// Finds the nearest official 24-Patch ColorChecker Classic patch using CIEDE2000 (`computeCiede2000`).
  static ColorCheckerPatch nearestColorCheckerPatch(List<double> labD50) {
    if (labD50.length < 3) return kColorChecker24Patches.first;
    var bestPatch = kColorChecker24Patches.first;
    var bestDe = double.infinity;
    for (final patch in kColorChecker24Patches) {
      final de = computeCiede2000(labD50, patch.labD50);
      if (de < bestDe) {
        bestDe = de;
        bestPatch = patch;
      }
    }
    return bestPatch;
  }

  /// Generates a realistic simulated uncalibrated camera sensor measurement of the 24 patches
  /// (modeling OEM warm/vibrant tint & cross-talk before calibration).
  static List<List<double>> simulateUncalibratedSensor24({
    double redShift = 1.45,
    double greenShift = 1.18,
    double blueShift = 0.82,
  }) {
    final sensorMatrix = [
      [redShift, 0.24, -0.04],
      [0.14, greenShift, 0.09],
      [-0.03, 0.16, blueShift],
    ];
    return kColorChecker24Patches.map((p) {
      final xyz = labD50ToXyz(p.labD50);
      return _mat3MulVec3(sensorMatrix, xyz);
    }).toList(growable: false);
  }

  /// Exact mirror of `zamera_core::ciede2000` (Sharma et al. 2005 verified).
  static double computeCiede2000(
    List<double> lab1,
    List<double> lab2,
  ) {
    final l1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
    final l2 = lab2[0], a2 = lab2[1], b2 = lab2[2];

    final c1 = math.sqrt(a1 * a1 + b1 * b1);
    final c2 = math.sqrt(a2 * a2 + b2 * b2);
    final cBar = 0.5 * (c1 + c2);

    final cBarPow7 = math.pow(cBar, 7).toDouble();
    final twentyFivePow7 = math.pow(25.0, 7).toDouble();
    final g = 0.5 * (1.0 - math.sqrt(cBarPow7 / (cBarPow7 + twentyFivePow7)));

    final a1Prime = (1.0 + g) * a1;
    final a2Prime = (1.0 + g) * a2;

    final c1Prime = math.sqrt(a1Prime * a1Prime + b1 * b1);
    final c2Prime = math.sqrt(a2Prime * a2Prime + b2 * b2);

    double hDeg(double ap, double b) {
      if (ap == 0.0 && b == 0.0) return 0.0;
      var deg = math.atan2(b, ap) * (180.0 / math.pi);
      if (deg < 0.0) deg += 360.0;
      return deg;
    }

    final h1Prime = hDeg(a1Prime, b1);
    final h2Prime = hDeg(a2Prime, b2);

    final deltaLPrime = l2 - l1;
    final deltaCPrime = c2Prime - c1Prime;

    final cProd = c1Prime * c2Prime;
    final double deltaHPrimeDeg;
    if (cProd == 0.0) {
      deltaHPrimeDeg = 0.0;
    } else {
      final diff = h2Prime - h1Prime;
      if (diff.abs() <= 180.0) {
        deltaHPrimeDeg = diff;
      } else if (diff > 180.0) {
        deltaHPrimeDeg = diff - 360.0;
      } else {
        deltaHPrimeDeg = diff + 360.0;
      }
    }

    final deltaBigHPrime = 2.0 *
        math.sqrt(cProd) *
        math.sin((deltaHPrimeDeg * 0.5) * (math.pi / 180.0));

    final lBarPrime = 0.5 * (l1 + l2);
    final cBarPrime = 0.5 * (c1Prime + c2Prime);

    final double hBarPrimeDeg;
    if (cProd == 0.0) {
      hBarPrimeDeg = h1Prime + h2Prime;
    } else if ((h1Prime - h2Prime).abs() <= 180.0) {
      hBarPrimeDeg = 0.5 * (h1Prime + h2Prime);
    } else if ((h1Prime + h2Prime) < 360.0) {
      hBarPrimeDeg = 0.5 * (h1Prime + h2Prime + 360.0);
    } else {
      hBarPrimeDeg = 0.5 * (h1Prime + h2Prime - 360.0);
    }

    final t = 1.0 -
        0.17 * math.cos((hBarPrimeDeg - 30.0) * (math.pi / 180.0)) +
        0.24 * math.cos((2.0 * hBarPrimeDeg) * (math.pi / 180.0)) +
        0.32 * math.cos((3.0 * hBarPrimeDeg + 6.0) * (math.pi / 180.0)) -
        0.20 * math.cos((4.0 * hBarPrimeDeg - 63.0) * (math.pi / 180.0));

    final deltaThetaDeg =
        30.0 * math.exp(-math.pow((hBarPrimeDeg - 275.0) / 25.0, 2));
    final cBarPrimePow7 = math.pow(cBarPrime, 7).toDouble();
    final rC = 2.0 *
        math.sqrt(cBarPrimePow7 / (cBarPrimePow7 + twentyFivePow7));

    final lMinus50Sq = math.pow(lBarPrime - 50.0, 2).toDouble();
    final sL = 1.0 + (0.015 * lMinus50Sq) / math.sqrt(20.0 + lMinus50Sq);
    final sC = 1.0 + 0.045 * cBarPrime;
    final sH = 1.0 + 0.015 * cBarPrime * t;
    final rT = -math.sin(2.0 * deltaThetaDeg * (math.pi / 180.0)) * rC;

    final termL = deltaLPrime / sL;
    final termC = deltaCPrime / sC;
    final termH = deltaBigHPrime / sH;

    return math.sqrt(
      termL * termL + termC * termC + termH * termH + rT * termC * termH,
    );
  }
}
