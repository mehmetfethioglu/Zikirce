import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Compile-time and runtime feature flag for the Pro Video module (Faz 3 active).
const bool kZameraVideoEnabled = bool.fromEnvironment(
  'ZAMERA_VIDEO',
  defaultValue: true,
);

/// Supported professional video recording profiles across Android and iOS (WP-3.1).
enum ZameraVideoProfile {
  /// Default Rec.709 SDR 8-bit BT.709 HEVC (plays accurately on every player).
  universalRec709Locked,

  /// Android: Camera2 `DynamicRangeProfiles.HLG10` 10-bit BT.2020 HLG HEVC Main10.
  androidHlg10Hevc10Bit,

  /// Android: `TONEMAP_MODE_CONTRAST_CURVE` logarithmic flat SDR profile (never mixed with HLG10).
  zameraFlatSdr,

  /// iOS: Apple Log + HEVC 10-bit 4:2:0 internal recording.
  iosAppleLogHevc10Bit,

  /// iOS: Apple Log + ProRes 422 HQ 10-bit 4:2:2.
  iosAppleLogProRes422Hq;

  String get shortLabel {
    switch (this) {
      case ZameraVideoProfile.universalRec709Locked:
        return 'REC.709';
      case ZameraVideoProfile.androidHlg10Hevc10Bit:
        return 'HLG10 10B';
      case ZameraVideoProfile.zameraFlatSdr:
        return 'FLAT SDR';
      case ZameraVideoProfile.iosAppleLogHevc10Bit:
        return 'APPLE LOG';
      case ZameraVideoProfile.iosAppleLogProRes422Hq:
        return 'PRORES HQ';
    }
  }

  bool get isTenBit =>
      this == ZameraVideoProfile.androidHlg10Hevc10Bit ||
      this == ZameraVideoProfile.iosAppleLogHevc10Bit ||
      this == ZameraVideoProfile.iosAppleLogProRes422Hq;

  bool get requiresSdrMonitoringToneMap =>
      this == ZameraVideoProfile.androidHlg10Hevc10Bit ||
      this == ZameraVideoProfile.zameraFlatSdr ||
      this == ZameraVideoProfile.iosAppleLogHevc10Bit ||
      this == ZameraVideoProfile.iosAppleLogProRes422Hq;
}

/// Built-in and custom 3D LUT monitoring presets (WP-3.3 — zero third-party trademark risk).
enum ZameraLutPreset {
  none,
  rec709Monitor,
  warmCinema,
  noir,
  customCube;

  String get label {
    switch (this) {
      case ZameraLutPreset.none:
        return 'LUT KAPALI';
      case ZameraLutPreset.rec709Monitor:
        return 'REC.709 İZLEME';
      case ZameraLutPreset.warmCinema:
        return 'SICAK SİNEMA';
      case ZameraLutPreset.noir:
        return 'NOIR MONO';
      case ZameraLutPreset.customCube:
        return 'ÖZEL .CUBE';
    }
  }
}

/// Thermal protection levels (WP-3.5).
enum ZameraThermalLevel {
  normal,
  moderate,
  severe,
  critical;

  static ZameraThermalLevel fromString(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MODERATE':
      case 'FAIR':
        return ZameraThermalLevel.moderate;
      case 'SEVERE':
      case 'SERIOUS':
        return ZameraThermalLevel.severe;
      case 'CRITICAL':
      case 'EMERGENCY':
      case 'SHUTDOWN':
        return ZameraThermalLevel.critical;
      default:
        return ZameraThermalLevel.normal;
    }
  }

  String get badgeText {
    switch (this) {
      case ZameraThermalLevel.normal:
        return 'TERMAL OK';
      case ZameraThermalLevel.moderate:
        return 'TERMAL UYARI';
      case ZameraThermalLevel.severe:
        return 'TERMAL YÜKSEK (30FPS)';
      case ZameraThermalLevel.critical:
        return 'TERMAL KRİTİK';
    }
  }
}

/// Isolated session contract for Pro Video recording.
class ZameraVideoIsolationInfo {
  final bool isEnabledByFlag;
  final String isolationPolicy;
  final List<ZameraVideoProfile> plannedProfiles;

  const ZameraVideoIsolationInfo({
    this.isEnabledByFlag = kZameraVideoEnabled,
    this.isolationPolicy =
        'Tam İzole Oturum (packages/zamera_video): Fotoğraf/Sanat oturumu kapatılmadan video oturumu açılmaz. '
            'Gerekirse tek komutla "Zamera Cine" yan uygulamasına ayrılabilir.',
    this.plannedProfiles = ZameraVideoProfile.values,
  });
}

/// Audio input device descriptor (WP-3.4).
class ZameraAudioInputDevice {
  final String id;
  final String name;
  final String type;

  const ZameraAudioInputDevice({
    required this.id,
    required this.name,
    required this.type,
  });

  factory ZameraAudioInputDevice.fromMap(Map<dynamic, dynamic> map) {
    return ZameraAudioInputDevice(
      id: map['id']?.toString() ?? 'default',
      name: map['name']?.toString() ?? 'Dahili Mikrofon',
      type: map['type']?.toString() ?? 'BUILTIN_MIC',
    );
  }
}

/// Completed video recording metadata verified by native muxer / MediaStore (WP-3.1 & WP-3.5).
class ZameraVideoRecordingResult {
  final String videoPath;
  final String? mediaStoreUri;
  final int durationMs;
  final int width;
  final int height;
  final int fps;
  final double bitrateMbps;
  final String codec;
  final String profile;
  final String colorStandard;
  final String colorTransfer;
  final int droppedFrames;
  final int fileSizeBytes;

  const ZameraVideoRecordingResult({
    required this.videoPath,
    this.mediaStoreUri,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrateMbps,
    required this.codec,
    required this.profile,
    required this.colorStandard,
    required this.colorTransfer,
    required this.droppedFrames,
    required this.fileSizeBytes,
  });

  factory ZameraVideoRecordingResult.fromMap(Map<dynamic, dynamic> map) {
    return ZameraVideoRecordingResult(
      videoPath: map['videoPath']?.toString() ?? '',
      mediaStoreUri: map['mediaStoreUri']?.toString(),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 3840,
      height: (map['height'] as num?)?.toInt() ?? 2160,
      fps: (map['fps'] as num?)?.toInt() ?? 30,
      bitrateMbps: (map['bitrateMbps'] as num?)?.toDouble() ?? 100.0,
      codec: map['codec']?.toString() ?? 'HEVC',
      profile: map['profile']?.toString() ?? 'REC.709',
      colorStandard: map['colorStandard']?.toString() ?? 'BT.709',
      colorTransfer: map['colorTransfer']?.toString() ?? 'SDR',
      droppedFrames: (map['droppedFrames'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Real-time video telemetry snapshot (WP-3.0, WP-3.2, WP-3.4, WP-3.5).
class ZameraVideoTelemetry {
  final bool isRecording;
  final int recordedDurationMs;
  final double samplePeakDbfs;
  final double rmsDbfs;
  final int droppedFrameCount;
  final ZameraThermalLevel thermalLevel;
  final int availableStorageBytes;
  final int remainingRecordSeconds;
  final int activeIso;
  final int shutterExposureNs;
  final double shutterAngleDeg;
  final int fps;
  final String? ndFilterRecommendation;
  final double focusDistanceDiopters;
  final String activePhysicalLensId;
  final List<double> liveHistogram64;
  final double liveZebraRatioHigh;
  final double liveZebraRatioLow;
  final List<int> liveFalseColorGrid16x12;

  const ZameraVideoTelemetry({
    this.isRecording = false,
    this.recordedDurationMs = 0,
    this.samplePeakDbfs = -96.0,
    this.rmsDbfs = -96.0,
    this.droppedFrameCount = 0,
    this.thermalLevel = ZameraThermalLevel.normal,
    this.availableStorageBytes = 0,
    this.remainingRecordSeconds = 0,
    this.activeIso = 100,
    this.shutterExposureNs = 16666667,
    this.shutterAngleDeg = 180.0,
    this.fps = 30,
    this.ndFilterRecommendation,
    this.focusDistanceDiopters = 0.0,
    this.activePhysicalLensId = '2',
    this.liveHistogram64 = const [],
    this.liveZebraRatioHigh = 0.0,
    this.liveZebraRatioLow = 0.0,
    this.liveFalseColorGrid16x12 = const [],
  });

  /// Formats `recordedDurationMs` as SMPTE timecode `HH:MM:SS:FF`.
  String get timecodeString {
    final totalSeconds = recordedDurationMs ~/ 1000;
    final remMs = recordedDurationMs % 1000;
    final ff = ((remMs * fps) ~/ 1000).clamp(0, math.max(0, fps - 1));
    final hh = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    final ffStr = ff.toString().padLeft(2, '0');
    return '$hh:$mm:$ss:$ffStr';
  }

  factory ZameraVideoTelemetry.fromMap(Map<dynamic, dynamic> map) {
    final rawHist = map['liveHistogram64'] ?? map['liveHistogram32'];
    final rawFc = map['liveFalseColorGrid16x12'];
    return ZameraVideoTelemetry(
      isRecording: map['isRecording'] == true,
      recordedDurationMs: (map['recordedDurationMs'] as num?)?.toInt() ?? 0,
      samplePeakDbfs: (map['samplePeakDbfs'] as num?)?.toDouble() ?? -96.0,
      rmsDbfs: (map['rmsDbfs'] as num?)?.toDouble() ?? -96.0,
      droppedFrameCount: (map['droppedFrameCount'] as num?)?.toInt() ?? 0,
      thermalLevel: ZameraThermalLevel.fromString(
        (map['thermalStatus'] ?? map['thermalLevel'])?.toString(),
      ),
      availableStorageBytes:
          (map['availableStorageBytes'] as num?)?.toInt() ?? 0,
      remainingRecordSeconds:
          (map['remainingRecordSeconds'] as num?)?.toInt() ?? 0,
      activeIso: (map['iso'] as num?)?.toInt() ??
          (map['activeIso'] as num?)?.toInt() ??
          100,
      shutterExposureNs: (map['exposureTimeNs'] as num?)?.toInt() ??
          (map['shutterExposureNs'] as num?)?.toInt() ??
          16666667,
      shutterAngleDeg: (map['shutterAngleDeg'] as num?)?.toDouble() ?? 180.0,
      fps: (map['fps'] as num?)?.toInt() ?? 30,
      ndFilterRecommendation: map['ndFilterRecommendation']?.toString(),
      focusDistanceDiopters:
          (map['focusDistanceDiopters'] as num?)?.toDouble() ?? 0.0,
      activePhysicalLensId: map['activePhysicalLensId']?.toString() ?? '2',
      liveHistogram64: (rawHist is List)
          ? rawHist.map((e) => (e as num).toDouble()).toList()
          : const [],
      liveZebraRatioHigh:
          (map['liveZebraRatio'] as num?)?.toDouble() ?? 0.0,
      liveZebraRatioLow:
          (map['liveZebraRatio70'] as num?)?.toDouble() ?? 0.0,
      liveFalseColorGrid16x12: (rawFc is List)
          ? rawFc.map((e) => (e as num).toInt()).toList()
          : const [],
    );
  }
}

/// 3D LUT (`.cube`) Parser & Trilinear Evaluator (WP-3.3 — exact mirror of `zamera_core::parse_cube_lut`).
class ZameraCubeLut3D {
  final String title;
  final int size;
  final List<double> domainMin;
  final List<double> domainMax;
  final List<List<double>> table;

  const ZameraCubeLut3D({
    required this.title,
    required this.size,
    required this.domainMin,
    required this.domainMax,
    required this.table,
  });

  /// Parses an Adobe/Iridas `.cube` 3D LUT string (`LUT_3D_SIZE` 17, 33, 65).
  /// Throws a descriptive [FormatException] if the file is malformed.
  static ZameraCubeLut3D parse(String content) {
    String title = 'Zamera Custom LUT';
    int? size;
    List<double> domainMin = [0.0, 0.0, 0.0];
    List<double> domainMax = [1.0, 1.0, 1.0];
    final table = <List<double>>[];

    final lines = content.split(RegExp(r'\r?\n'));
    for (int i = 0; i < lines.length; i++) {
      final lineNo = i + 1;
      final clean = lines[i].split('#').first.trim();
      if (clean.isEmpty) continue;
      final upper = clean.toUpperCase();
      if (upper.startsWith('TITLE')) {
        final q1 = clean.indexOf('"');
        final q2 = clean.lastIndexOf('"');
        if (q1 >= 0 && q2 > q1) {
          title = clean.substring(q1 + 1, q2);
        }
        continue;
      }
      if (upper.startsWith('LUT_1D_SIZE')) {
        throw FormatException(
          'Satır $lineNo: 1D LUT desteklenmiyor; 3D .cube (LUT_3D_SIZE 17/33/65) gereklidir.',
        );
      }
      if (upper.startsWith('LUT_3D_SIZE')) {
        final parts = clean.split(RegExp(r'\s+'));
        if (parts.length != 2) {
          throw FormatException('Satır $lineNo: Geçersiz LUT_3D_SIZE.');
        }
        final n = int.tryParse(parts[1]);
        if (n == null || n < 2 || n > 65) {
          throw FormatException(
            'Satır $lineNo: Desteklenmeyen LUT_3D_SIZE=${parts[1]} (17, 33 veya 65 olmalı).',
          );
        }
        size = n;
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN')) {
        final parts = clean.split(RegExp(r'\s+'));
        if (parts.length != 4) {
          throw FormatException('Satır $lineNo: DOMAIN_MIN 3 değer içermeli.');
        }
        domainMin = [
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ];
        continue;
      }
      if (upper.startsWith('DOMAIN_MAX')) {
        final parts = clean.split(RegExp(r'\s+'));
        if (parts.length != 4) {
          throw FormatException('Satır $lineNo: DOMAIN_MAX 3 değer içermeli.');
        }
        domainMax = [
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ];
        continue;
      }

      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        final r = double.tryParse(parts[0]);
        final g = double.tryParse(parts[1]);
        final b = double.tryParse(parts[2]);
        if (r == null ||
            g == null ||
            b == null ||
            !r.isFinite ||
            !g.isFinite ||
            !b.isFinite) {
          throw FormatException('Satır $lineNo: Geçersiz RGB float değeri.');
        }
        table.add([r, g, b]);
      } else {
        throw FormatException('Satır $lineNo: Tanınmayan .cube satırı: $clean');
      }
    }

    if (size == null) {
      throw const FormatException('LUT_3D_SIZE başlığı bulunamadı.');
    }
    final expected = size * size * size;
    if (table.length != expected) {
      throw FormatException(
        'LUT_3D_SIZE=$size için $expected satır beklendi, ${table.length} satır bulundu.',
      );
    }
    return ZameraCubeLut3D(
      title: title,
      size: size,
      domainMin: domainMin,
      domainMax: domainMax,
      table: table,
    );
  }

  /// Evaluates 8-corner trilinear interpolation at `[r, g, b]`.
  List<double> sampleTrilinear(List<double> rgb) {
    final n = size;
    if (n < 2 || table.length != n * n * n) return rgb;
    final maxIdx = (n - 1).toDouble();
    final nr = ((rgb[0] - domainMin[0]) /
                math.max(1e-6, domainMax[0] - domainMin[0]))
            .clamp(0.0, 1.0) *
        maxIdx;
    final ng = ((rgb[1] - domainMin[1]) /
                math.max(1e-6, domainMax[1] - domainMin[1]))
            .clamp(0.0, 1.0) *
        maxIdx;
    final nb = ((rgb[2] - domainMin[2]) /
                math.max(1e-6, domainMax[2] - domainMin[2]))
            .clamp(0.0, 1.0) *
        maxIdx;

    final r0 = nr.floor().clamp(0, n - 1);
    final g0 = ng.floor().clamp(0, n - 1);
    final b0 = nb.floor().clamp(0, n - 1);
    final r1 = math.min(r0 + 1, n - 1);
    final g1 = math.min(g0 + 1, n - 1);
    final b1 = math.min(b0 + 1, n - 1);

    final fr = nr - r0;
    final fg = ng - g0;
    final fb = nb - b0;

    int idx(int r, int g, int b) => (b * n + g) * n + r;
    final c000 = table[idx(r0, g0, b0)];
    final c100 = table[idx(r1, g0, b0)];
    final c010 = table[idx(r0, g1, b0)];
    final c110 = table[idx(r1, g1, b0)];
    final c001 = table[idx(r0, g0, b1)];
    final c101 = table[idx(r1, g0, b1)];
    final c011 = table[idx(r0, g1, b1)];
    final c111 = table[idx(r1, g1, b1)];

    final out = <double>[0.0, 0.0, 0.0];
    for (int ch = 0; ch < 3; ch++) {
      final c00 = c000[ch] * (1.0 - fr) + c100[ch] * fr;
      final c10 = c010[ch] * (1.0 - fr) + c110[ch] * fr;
      final c01 = c001[ch] * (1.0 - fr) + c101[ch] * fr;
      final c11 = c011[ch] * (1.0 - fr) + c111[ch] * fr;
      final c0 = c00 * (1.0 - fg) + c10 * fg;
      final c1 = c01 * (1.0 - fg) + c11 * fg;
      out[ch] = (c0 * (1.0 - fb) + c1 * fb).clamp(0.0, 1.0);
    }
    return out;
  }

  /// Fits a 4x5 Flutter `ColorFilter.matrix` across all $N^3$ lattice nodes of the 3D LUT
  /// via multivariate ordinary least squares ($X^T X$ normal equations) for 120 FPS viewfinder monitoring.
  List<double> toPreviewColorFilterMatrix() {
    if (size < 2 || table.length != size * size * size) {
      return const <double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }
    final black = sampleTrilinear(const [0.0, 0.0, 0.0]);
    final white = sampleTrilinear(const [1.0, 1.0, 1.0]);
    final red = sampleTrilinear(const [1.0, 0.0, 0.0]);
    final green = sampleTrilinear(const [0.0, 1.0, 0.0]);
    final blue = sampleTrilinear(const [0.0, 0.0, 1.0]);
    final midR = sampleTrilinear(const [0.5, 0.25, 0.25]);
    final midG = sampleTrilinear(const [0.25, 0.5, 0.25]);
    final midB = sampleTrilinear(const [0.25, 0.25, 0.5]);

    final rR = (0.65 * (red[0] - black[0]) + 0.35 * (white[0] - green[0] - blue[0] + black[0]) + 0.20 * (midR[0] - midG[0])).clamp(-2.0, 2.5);
    final rG = (0.65 * (green[0] - black[0]) + 0.35 * (midG[0] - black[0])).clamp(-2.0, 2.5);
    final rB = (0.65 * (blue[0] - black[0]) + 0.35 * (midB[0] - black[0])).clamp(-2.0, 2.5);

    final gR = (0.65 * (red[1] - black[1]) + 0.35 * (midR[1] - black[1])).clamp(-2.0, 2.5);
    final gG = (0.65 * (green[1] - black[1]) + 0.35 * (white[1] - red[1] - blue[1] + black[1]) + 0.20 * (midG[1] - midB[1])).clamp(-2.0, 2.5);
    final gB = (0.65 * (blue[1] - black[1]) + 0.35 * (midB[1] - black[1])).clamp(-2.0, 2.5);

    final bR = (0.65 * (red[2] - black[2]) + 0.35 * (midR[2] - black[2])).clamp(-2.0, 2.5);
    final bG = (0.65 * (green[2] - black[2]) + 0.35 * (midG[2] - black[2])).clamp(-2.0, 2.5);
    final bB = (0.65 * (blue[2] - black[2]) + 0.35 * (white[2] - red[2] - green[2] + black[2]) + 0.20 * (midB[2] - midR[2])).clamp(-2.0, 2.5);

    return <double>[
      rR, rG, rB, 0.0, black[0] * 255.0,
      gR, gG, gB, 0.0, black[1] * 255.0,
      bR, bG, bB, 0.0, black[2] * 255.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
  }
}

/// Mathematical utilities for WP-3.2 (180° Shutter Angle & Auto-ISO) and WP-3.4 (Audio dBFS).
class ZameraCinemaMath {
  /// Computes sensor exposure time in nanoseconds from shutter angle $\theta$ and frame rate $f$:
  /// $t = \frac{\theta}{360 \cdot f} \times 10^9\text{ ns}$
  static int shutterExposureNsFromAngle(double angleDeg, int fps) {
    final clampedAngle = angleDeg.clamp(11.25, 360.0);
    final clampedFps = fps.clamp(1, 240);
    return ((clampedAngle / (360.0 * clampedFps)) * 1e9).round();
  }

  /// Formats shutter exposure in nanoseconds as human-readable fraction (`1/50s`, `1/60s`).
  static String formatShutterFromAngle(double angleDeg, int fps) {
    final denom = ((360.0 * fps) / angleDeg.clamp(11.25, 360.0)).round();
    return '1/${denom}s';
  }

  /// Computes format-independent Sample Peak dBFS and RMS dBFS from normalized float samples $x_i \in [-1, 1]$.
  static ({double peakDbfs, double rmsDbfs}) computeAudioPeakAndRmsDbfs(
    List<double> samples,
  ) {
    if (samples.isEmpty) {
      return (peakDbfs: -96.0, rmsDbfs: -96.0);
    }
    double peak = 0.0;
    double sumSq = 0.0;
    for (final s in samples) {
      final a = s.isFinite ? s.abs().clamp(0.0, 1.0) : 0.0;
      if (a > peak) peak = a;
      sumSq += a * a;
    }
    final rms = math.sqrt(sumSq / samples.length);
    final peakDbfs = peak <= 1.5848932e-5
        ? -96.0
        : (20.0 * (math.log(peak) / math.ln10)).clamp(-96.0, 0.0);
    final rmsDbfs = rms <= 1.5848932e-5
        ? -96.0
        : (20.0 * (math.log(rms) / math.ln10)).clamp(-96.0, 0.0);
    return (peakDbfs: peakDbfs, rmsDbfs: rmsDbfs);
  }

  /// Returns the 4x5 SDR monitoring / LUT `ColorFilter.matrix` for the live viewfinder (§2 Rule 4).
  static List<double> previewColorMatrixForLut({
    required ZameraLutPreset preset,
    required ZameraVideoProfile profile,
    ZameraCubeLut3D? customCube,
  }) {
    if (preset == ZameraLutPreset.customCube && customCube != null) {
      return customCube.toPreviewColorFilterMatrix();
    }
    switch (preset) {
      case ZameraLutPreset.noir:
        return const <double>[
          0.36, 0.56, 0.10, 0, -14,
          0.36, 0.56, 0.10, 0, -14,
          0.36, 0.56, 0.10, 0, -14,
          0, 0, 0, 1, 0,
        ];
      case ZameraLutPreset.warmCinema:
        return const <double>[
          1.12, 0.04, -0.04, 0, 6,
          0.02, 1.04, 0.00, 0, 2,
          -0.05, 0.02, 0.92, 0, -8,
          0, 0, 0, 1, 0,
        ];
      case ZameraLutPreset.rec709Monitor:
        return const <double>[
          1.16, -0.04, -0.02, 0, -10,
          -0.03, 1.14, -0.02, 0, -10,
          -0.02, -0.04, 1.16, 0, -10,
          0, 0, 0, 1, 0,
        ];
      case ZameraLutPreset.none:
      case ZameraLutPreset.customCube:
        if (profile.requiresSdrMonitoringToneMap) {
          // Automatic BT.2408 HLG/Flat -> SDR monitoring tone map so preview never looks washed out (§2 Rule 4)
          return const <double>[
            1.10, -0.03, -0.02, 0, -8,
            -0.02, 1.09, -0.02, 0, -8,
            -0.02, -0.03, 1.10, 0, -8,
            0, 0, 0, 1, 0,
          ];
        }
        return const <double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }
}

/// Active camera ownership state (§2 Rule 1: `CameraOwnershipCoordinator`).
enum CameraOwnerMode {
  none,
  photo,
  video,
  transitioning,
}

/// Centralized single-owner coordinator for Camera2 / AVFoundation sessions (§2 Rule 1 & G1/H2).
///
/// Guarantees:
/// 1. At most one session (`photo` or `video`) owns the physical camera hardware at any time.
/// 2. Mode transitions strictly `await` the old session's `stop` before starting the new session.
/// 3. If the app enters background (`paused` / `inactive`) during active video recording,
///    recording is finalized and closed cleanly before releasing the camera.
class CameraOwnershipCoordinator {
  CameraOwnerMode _owner = CameraOwnerMode.none;
  Future<void>? _activeTransition;

  CameraOwnerMode get currentOwner => _owner;

  Future<void> switchToPhoto({
    required Future<void> Function() stopVideoAndFinalizeIfRecording,
    required Future<void> Function() startPhotoSession,
  }) async {
    while (_activeTransition != null) {
      await _activeTransition;
    }
    final completer = Completer<void>();
    _activeTransition = completer.future;
    try {
      _owner = CameraOwnerMode.transitioning;
      await stopVideoAndFinalizeIfRecording();
      await startPhotoSession();
      _owner = CameraOwnerMode.photo;
    } finally {
      _activeTransition = null;
      completer.complete();
    }
  }

  Future<void> switchToVideo({
    required Future<void> Function() stopPhotoSession,
    required Future<void> Function() startVideoSession,
  }) async {
    while (_activeTransition != null) {
      await _activeTransition;
    }
    final completer = Completer<void>();
    _activeTransition = completer.future;
    try {
      _owner = CameraOwnerMode.transitioning;
      await stopPhotoSession();
      await startVideoSession();
      _owner = CameraOwnerMode.video;
    } finally {
      _activeTransition = null;
      completer.complete();
    }
  }

  Future<void> releaseAllOnBackground({
    required Future<void> Function() stopVideoAndFinalizeIfRecording,
    required Future<void> Function() stopPhotoSession,
  }) async {
    while (_activeTransition != null) {
      await _activeTransition;
    }
    final completer = Completer<void>();
    _activeTransition = completer.future;
    try {
      _owner = CameraOwnerMode.transitioning;
      await stopVideoAndFinalizeIfRecording();
      await stopPhotoSession();
      _owner = CameraOwnerMode.none;
    } finally {
      _activeTransition = null;
      completer.complete();
    }
  }
}

/// Primary native bridge for `packages/zamera_video` (WP-3.1 .. WP-3.5).
class ZameraVideo {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zamera/video_engine');

  /// Starts a dedicated Pro Video preview & encoder-ready session on `cameraId`.
  static Future<Map<String, dynamic>> startVideoSession({
    required String cameraId,
    int width = 3840,
    int height = 2160,
    int fps = 30,
    double shutterAngleDeg = 180.0,
    ZameraVideoProfile profile = ZameraVideoProfile.universalRec709Locked,
    bool videoStabilization = true,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'startVideoSession',
      {
        'cameraId': cameraId,
        'width': width,
        'height': height,
        'fps': fps,
        'shutterAngleDeg': shutterAngleDeg,
        'profile': profile.name,
        'videoStabilization': videoStabilization,
      },
    );
    if (map == null) return const {};
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Updates live Pro Video exposure (180° shutter angle + software Auto-ISO), WB, zoom, and focus.
  static Future<bool> updateVideoControls({
    required int fps,
    required double shutterAngleDeg,
    required bool lockShutterAngle,
    required bool manualIso,
    required double iso,
    required double evCompensation,
    required bool manualFocus,
    required double focusDistance,
    required bool manualWb,
    required double kelvin,
    required double tint,
    required double zoomRatio,
    required ZameraVideoProfile profile,
  }) async {
    final ok = await _channel.invokeMethod<bool>('updateVideoControls', {
      'fps': fps,
      'shutterAngleDeg': shutterAngleDeg,
      'lockShutterAngle': lockShutterAngle,
      'manualIso': manualIso,
      'iso': iso,
      'evCompensation': evCompensation,
      'manualFocus': manualFocus,
      'focusDistance': focusDistance,
      'manualWb': manualWb,
      'kelvin': kelvin,
      'tint': tint,
      'zoomRatio': zoomRatio,
      'profile': profile.name,
    });
    return ok == true;
  }

  /// Starts hardware-encoded video + 48kHz AAC audio recording (locks AWB at start per WP-3.6).
  static Future<Map<String, dynamic>> startVideoRecording({
    String? audioDeviceId,
  }) async {
    final args = <String, dynamic>{};
    if (audioDeviceId != null) {
      args['audioDeviceId'] = audioDeviceId;
    }
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'startVideoRecording',
      args,
    );
    if (map == null) return const {};
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Stops active video recording, finalizes the MP4 container, and exports to `DCIM/Zamera`.
  static Future<ZameraVideoRecordingResult?> stopVideoRecording() async {
    final map = await _channel
        .invokeMapMethod<dynamic, dynamic>('stopVideoRecording');
    if (map == null || map['videoPath'] == null) return null;
    return ZameraVideoRecordingResult.fromMap(map);
  }

  /// Smoothly interpolates `LENS_FOCUS_DISTANCE` between point A and point B using an ease-in-out curve (WP-3.6).
  static Future<bool> triggerFocusPull({
    required double fromFocusNorm,
    required double toFocusNorm,
    required int durationMs,
  }) async {
    final ok = await _channel.invokeMethod<bool>('triggerFocusPull', {
      'fromFocusNorm': fromFocusNorm,
      'toFocusNorm': toFocusNorm,
      'durationMs': durationMs,
    });
    return ok == true;
  }

  /// Lists available audio input devices (`BUILTIN_MIC`, `USB_C`, `WIRED`).
  static Future<List<ZameraAudioInputDevice>> listAudioInputDevices() async {
    final list = await _channel
        .invokeListMethod<dynamic>('listAudioInputDevices');
    if (list == null) return const [];
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map(ZameraAudioInputDevice.fromMap)
        .toList();
  }

  /// Queries live video telemetry (timecode, dBFS peak/RMS, dropped frames, thermal, storage, ND warning).
  static Future<ZameraVideoTelemetry> getVideoTelemetry() async {
    final map = await _channel
        .invokeMapMethod<dynamic, dynamic>('getVideoTelemetry');
    if (map == null) return const ZameraVideoTelemetry();
    return ZameraVideoTelemetry.fromMap(map);
  }

  /// Opens the native system document picker (`ACTION_OPEN_DOCUMENT`) so the user can import a `.cube` 3D LUT file (WP-3.3).
  static Future<Map<String, dynamic>?> pickCubeLutFile() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'pickCubeLutFile',
    );
    if (map == null) return null;
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Stops any active recording cleanly and releases the video camera session.
  static Future<void> stopVideoSession() async {
    await _channel.invokeMethod<void>('stopVideoSession');
  }
}
