import 'dart:math' as math;

/// DSLR exposure priority and manual shooting modes (P / Tv / Sv / M).
enum DslrExposureMode {
  programP,
  shutterTv,
  isoSv,
  manualM;

  String get shortLabel {
    switch (this) {
      case DslrExposureMode.programP:
        return 'P';
      case DslrExposureMode.shutterTv:
        return 'Tv';
      case DslrExposureMode.isoSv:
        return 'Sv';
      case DslrExposureMode.manualM:
        return 'M';
    }
  }

  String get badgeLabelTr {
    switch (this) {
      case DslrExposureMode.programP:
        return 'PROGRAM';
      case DslrExposureMode.shutterTv:
        return 'ENSTANTANE ÖNC.';
      case DslrExposureMode.isoSv:
        return 'ISO ÖNCELİKLİ';
      case DslrExposureMode.manualM:
        return 'TAM MANUEL';
    }
  }

  bool get isIsoManual =>
      this == DslrExposureMode.isoSv || this == DslrExposureMode.manualM;

  bool get isShutterManual =>
      this == DslrExposureMode.shutterTv || this == DslrExposureMode.manualM;
}

/// DSLR drive and release modes (Single, 3-frame AEB ±2 EV, 2s/10s self-timer).
enum ProDriveMode {
  single,
  aeb3,
  timer2s,
  timer10s;

  String get shortLabel {
    switch (this) {
      case ProDriveMode.single:
        return 'TEK';
      case ProDriveMode.aeb3:
        return 'AEB ±2';
      case ProDriveMode.timer2s:
        return '2SN';
      case ProDriveMode.timer10s:
        return '10SN';
    }
  }

  int get timerSeconds {
    switch (this) {
      case ProDriveMode.single:
      case ProDriveMode.aeb3:
        return 0;
      case ProDriveMode.timer2s:
        return 2;
      case ProDriveMode.timer10s:
        return 10;
    }
  }

  ProDriveMode get next =>
      ProDriveMode.values[(index + 1) % ProDriveMode.values.length];
}

/// Standard 1/3-EV DSLR ISO and Shutter speed stop tables with logarithmic mapping.
class DslrStopsRegistry {
  const DslrStopsRegistry._();

  static const List<int> isoThirdStops = <int>[
    50,
    64,
    80,
    100,
    125,
    160,
    200,
    250,
    320,
    400,
    500,
    640,
    800,
    1000,
    1250,
    1600,
    2000,
    2500,
    3200,
    4000,
    5000,
    6400,
    8000,
    10000,
    12800,
  ];

  /// Standard 1/3-EV DSLR shutter stops from 1/8000s (125,000 ns) to 30" (30,000,000,000 ns).
  static const List<int> shutterStopsNs = <int>[
    125000, // 1/8000s
    156250, // 1/6400s
    200000, // 1/5000s
    250000, // 1/4000s
    312500, // 1/3200s
    400000, // 1/2500s
    500000, // 1/2000s
    625000, // 1/1600s
    800000, // 1/1250s
    1000000, // 1/1000s
    1250000, // 1/800s
    1562500, // 1/640s
    2000000, // 1/500s
    2500000, // 1/400s
    3125000, // 1/320s
    4000000, // 1/250s
    5000000, // 1/200s
    6250000, // 1/160s
    8000000, // 1/125s
    10000000, // 1/100s
    12500000, // 1/80s
    16666667, // 1/60s
    20000000, // 1/50s
    25000000, // 1/40s
    33333333, // 1/30s
    40000000, // 1/25s
    50000000, // 1/20s
    66666667, // 1/15s
    76923077, // 1/13s
    100000000, // 1/10s
    125000000, // 1/8s
    166666667, // 1/6s
    200000000, // 1/5s
    250000000, // 1/4s
    300000000, // 0.3"
    400000000, // 0.4"
    500000000, // 0.5"
    600000000, // 0.6"
    800000000, // 0.8"
    1000000000, // 1"
    1300000000, // 1.3"
    1600000000, // 1.6"
    2000000000, // 2"
    2500000000, // 2.5"
    3200000000, // 3.2"
    4000000000, // 4"
    5000000000, // 5"
    6000000000, // 6"
    8000000000, // 8"
    10000000000, // 10"
    13000000000, // 13"
    15000000000, // 15"
    20000000000, // 20"
    25000000000, // 25"
    30000000000, // 30"
  ];

  static int nearestIso(num raw, {int minIso = 50, int maxIso = 12800}) {
    final int lo = math.max(1, math.min(minIso, maxIso));
    final int hi = math.max(lo, math.max(minIso, maxIso));
    final double clamped = raw.toDouble().clamp(lo.toDouble(), hi.toDouble());
    final double targetLog = math.log(clamped);

    int? bestStop;
    double bestDist = double.infinity;
    for (final int stop in isoThirdStops) {
      if (stop < lo || stop > hi) continue;
      final double dist = (math.log(stop) - targetLog).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestStop = stop;
      }
    }
    return bestStop ?? clamped.round().clamp(lo, hi);
  }

  static int nearestShutterNs(
    int rawNs, {
    int minNs = 125000,
    int maxNs = 30000000000,
  }) {
    final int lo = math.max(1, math.min(minNs, maxNs));
    final int hi = math.max(lo, math.max(minNs, maxNs));
    final int clamped = rawNs.clamp(lo, hi);
    final double targetLog = math.log(clamped);

    int? bestStop;
    double bestDist = double.infinity;
    for (final int stop in shutterStopsNs) {
      if (stop < lo || stop > hi) continue;
      final double dist = (math.log(stop) - targetLog).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestStop = stop;
      }
    }
    return bestStop ?? clamped;
  }

  static String formatShutterNs(int exposureNs) {
    if (exposureNs <= 0) return '1/8000s';
    if (exposureNs >= 300000000) {
      final double seconds = exposureNs / 1000000000.0;
      final double tenth = (seconds * 10.0).round() / 10.0;
      if ((tenth - tenth.roundToDouble()).abs() < 0.01) {
        return '${tenth.round()}"';
      }
      return '${tenth.toStringAsFixed(1)}"';
    }
    final int denom = math.max(1, (1000000000.0 / exposureNs).round());
    return '1/${denom}s';
  }

  static double isoToNorm(num iso, {int minIso = 50, int maxIso = 12800}) {
    final int lo = math.max(1, math.min(minIso, maxIso));
    final int hi = math.max(lo, math.max(minIso, maxIso));
    if (hi <= lo) return 0.0;
    final double clamped = iso.toDouble().clamp(lo.toDouble(), hi.toDouble());
    final double minLog = math.log(lo);
    final double maxLog = math.log(hi);
    return ((math.log(clamped) - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  static int isoFromNorm(double norm, {int minIso = 50, int maxIso = 12800}) {
    final int lo = math.max(1, math.min(minIso, maxIso));
    final int hi = math.max(lo, math.max(minIso, maxIso));
    if (hi <= lo) return lo;
    final double t = norm.clamp(0.0, 1.0);
    final double raw = lo * math.pow(hi / lo, t).toDouble();
    return nearestIso(raw, minIso: lo, maxIso: hi);
  }

  static double shutterNsToNorm(
    int ns, {
    int minNs = 125000,
    int maxNs = 30000000000,
  }) {
    final int lo = math.max(1, math.min(minNs, maxNs));
    final int hi = math.max(lo, math.max(minNs, maxNs));
    if (hi <= lo) return 0.0;
    final double clamped = ns.toDouble().clamp(lo.toDouble(), hi.toDouble());
    final double minLog = math.log(lo);
    final double maxLog = math.log(hi);
    return ((math.log(clamped) - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  static int shutterNsFromNorm(
    double norm, {
    int minNs = 125000,
    int maxNs = 30000000000,
  }) {
    final int lo = math.max(1, math.min(minNs, maxNs));
    final int hi = math.max(lo, math.max(minNs, maxNs));
    if (hi <= lo) return lo;
    final double t = norm.clamp(0.0, 1.0);
    final int rawNs = (lo * math.pow(hi / lo, t).toDouble()).round();
    return nearestShutterNs(rawNs, minNs: lo, maxNs: hi);
  }

  /// Snaps live AE telemetry to nearest 1/3-EV DSLR stops for bumpless P -> Tv/Sv/M transition.
  static ({int iso, int shutterNs}) bumplessTransfer({
    required num? liveIso,
    required int? liveShutterNs,
    int minIso = 50,
    int maxIso = 12800,
    int minNs = 125000,
    int maxNs = 30000000000,
  }) {
    final num seedIso = (liveIso != null && liveIso > 0) ? liveIso : 100;
    final int seedNs =
        (liveShutterNs != null && liveShutterNs > 0) ? liveShutterNs : 8000000;
    return (
      iso: nearestIso(seedIso, minIso: minIso, maxIso: maxIso),
      shutterNs: nearestShutterNs(seedNs, minNs: minNs, maxNs: maxNs),
    );
  }
}

/// DSLR White Balance Kelvin + Green/Magenta Tint preset model.
class WbPresetEntry {
  final String labelTr;
  final int kelvin;
  final double tint;

  const WbPresetEntry({
    required this.labelTr,
    required this.kelvin,
    this.tint = 0.0,
  });
}

/// Registry of standard DSLR White Balance presets and Green/Magenta tint stops.
class WbPresetRegistry {
  const WbPresetRegistry._();

  static const List<WbPresetEntry> presets = <WbPresetEntry>[
    WbPresetEntry(labelTr: 'TUNGSTEN', kelvin: 3200),
    WbPresetEntry(labelTr: 'FLORESAN', kelvin: 4000),
    WbPresetEntry(labelTr: 'GÜN IŞIĞI', kelvin: 5500),
    WbPresetEntry(labelTr: 'FLAŞ', kelvin: 6000),
    WbPresetEntry(labelTr: 'BULUTLU', kelvin: 6500),
    WbPresetEntry(labelTr: 'GÖLGE', kelvin: 7500),
  ];

  static const List<double> tintPresets = <double>[-30, -15, 0, 15, 30];
}
