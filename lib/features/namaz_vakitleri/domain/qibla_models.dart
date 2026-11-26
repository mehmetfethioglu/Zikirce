import 'package:flutter/foundation.dart';
import 'qibla_math.dart';

/// 3B Kıble ekranındaki figür görünüm tercihi.
enum QiblaFigureMode {
  male,
  female,
  prayerRugOnly,
}

/// Manyetik sensörün canlı durumu.
enum QiblaSensorStatus {
  active,
  interference,
  unavailable,
  interactivePreview,
}

/// Kıble koordinatlarının geldiği kaynak.
enum QiblaLocationSource {
  gps,
  manualParams,
  fallbackCity,
}

/// Cihaz GPS konum izni ve çözümleme durumu.
enum QiblaLocationStatus {
  resolving,
  gpsActive,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
}

/// Kıble hizalanması ve İftitah Tekbiri durum makinesi aşamaları.
enum QiblaAlignmentPhase {
  searching,
  approaching,
  locked,
  takbir,
  qiyam,
}

/// Eğim düzeltmeli ham veya native kalibreli sensör ölçümü.
@immutable
class QiblaSensorSample {
  /// Cihazın +Y (üst) kenarının Kuzey'e göre saat yönünde açısı [0, 360).
  /// `isTrueNorth` false ise Manyetik Kuzey'dir, true ise doğrudan Gerçek Kuzey'dir.
  final double headingDeg;

  /// Telefonun yatay düzlemden toplam eğimi (derece).
  final double tiltDeg;

  /// İleri-geri eğim (derece).
  final double pitchDeg;

  /// Sağa-sola eğim (derece).
  final double rollDeg;

  /// Manyetik alan büyüklüğü (µT); 0 ise raporlanmamış kabul edilir.
  final double magneticFieldUt;

  /// `true` ise `headingDeg` doğrudan Gerçek Kuzey'dir (declination eklenmez).
  final bool isTrueNorth;

  /// Native sensör düşük doğruluk / kalibrasyon ihtiyacı bildiriyorsa `true`.
  final bool needsCalibration;

  /// iOS CLHeading açısal belirsizliği (derece), bilinmiyorsa `null`.
  final double? headingAccuracyDeg;

  const QiblaSensorSample({
    required this.headingDeg,
    required this.tiltDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.magneticFieldUt,
    this.isTrueNorth = false,
    this.needsCalibration = false,
    this.headingAccuracyDeg,
  });
}

/// 3B Kıble Bulucu ekranının değişmez (immutable) Riverpod durumu.
@immutable
class QiblaState {
  final String cityName;
  final double latitude;
  final double longitude;
  final double qiblaBearingDeg;
  final double distanceKm;
  final double declinationDeg;
  final double sunAzimuthDeg;
  final double sunElevationDeg;

  /// Gerçek Kuzey'e göre yumuşatılmış cihaz yönü [0, 360).
  final double headingDeg;

  /// Kıbleye ulaşmak için en kısa dönüş açısı (-180, 180].
  /// Pozitif: sağa dön, Negatif: sola dön.
  final double angleDeltaDeg;

  final double tiltDeg;
  final double pitchDeg;
  final double rollDeg;
  final double magneticFieldUt;
  final QiblaSensorStatus sensorStatus;
  final QiblaAlignmentPhase phase;
  final QiblaFigureMode figureMode;
  final bool isSoundEnabled;
  final bool isInteractivePreview;
  final int takbirReplayTick;
  final QiblaLocationSource locationSource;
  final QiblaLocationStatus locationStatus;
  final bool isUsingTrueNorth;
  final double? gpsAccuracyMeters;
  final String? suggestedPrayerCity;

  const QiblaState({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.qiblaBearingDeg,
    required this.distanceKm,
    required this.declinationDeg,
    required this.sunAzimuthDeg,
    required this.sunElevationDeg,
    required this.headingDeg,
    required this.angleDeltaDeg,
    required this.tiltDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.magneticFieldUt,
    required this.sensorStatus,
    required this.phase,
    required this.figureMode,
    required this.isSoundEnabled,
    required this.isInteractivePreview,
    this.takbirReplayTick = 0,
    this.locationSource = QiblaLocationSource.fallbackCity,
    this.locationStatus = QiblaLocationStatus.unavailable,
    this.isUsingTrueNorth = false,
    this.gpsAccuracyMeters,
    this.suggestedPrayerCity,
  });

  bool get isPhoneFlat => tiltDeg <= QiblaMath.maxFlatTiltDeg;

  bool get isSunVisible => sunElevationDeg > -2.0;

  bool get isGpsLocation => locationSource == QiblaLocationSource.gps;

  bool get needsLocationWarning =>
      locationSource == QiblaLocationSource.fallbackCity &&
      locationStatus != QiblaLocationStatus.resolving;

  bool get isAligned =>
      phase == QiblaAlignmentPhase.locked ||
      phase == QiblaAlignmentPhase.takbir ||
      phase == QiblaAlignmentPhase.qiyam;

  QiblaState copyWith({
    String? cityName,
    double? latitude,
    double? longitude,
    double? qiblaBearingDeg,
    double? distanceKm,
    double? declinationDeg,
    double? sunAzimuthDeg,
    double? sunElevationDeg,
    double? headingDeg,
    double? angleDeltaDeg,
    double? tiltDeg,
    double? pitchDeg,
    double? rollDeg,
    double? magneticFieldUt,
    QiblaSensorStatus? sensorStatus,
    QiblaAlignmentPhase? phase,
    QiblaFigureMode? figureMode,
    bool? isSoundEnabled,
    bool? isInteractivePreview,
    int? takbirReplayTick,
    QiblaLocationSource? locationSource,
    QiblaLocationStatus? locationStatus,
    bool? isUsingTrueNorth,
    double? gpsAccuracyMeters,
    bool clearGpsAccuracy = false,
    String? suggestedPrayerCity,
    bool clearSuggestedPrayerCity = false,
  }) {
    return QiblaState(
      cityName: cityName ?? this.cityName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      qiblaBearingDeg: qiblaBearingDeg ?? this.qiblaBearingDeg,
      distanceKm: distanceKm ?? this.distanceKm,
      declinationDeg: declinationDeg ?? this.declinationDeg,
      sunAzimuthDeg: sunAzimuthDeg ?? this.sunAzimuthDeg,
      sunElevationDeg: sunElevationDeg ?? this.sunElevationDeg,
      headingDeg: headingDeg ?? this.headingDeg,
      angleDeltaDeg: angleDeltaDeg ?? this.angleDeltaDeg,
      tiltDeg: tiltDeg ?? this.tiltDeg,
      pitchDeg: pitchDeg ?? this.pitchDeg,
      rollDeg: rollDeg ?? this.rollDeg,
      magneticFieldUt: magneticFieldUt ?? this.magneticFieldUt,
      sensorStatus: sensorStatus ?? this.sensorStatus,
      phase: phase ?? this.phase,
      figureMode: figureMode ?? this.figureMode,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isInteractivePreview: isInteractivePreview ?? this.isInteractivePreview,
      takbirReplayTick: takbirReplayTick ?? this.takbirReplayTick,
      locationSource: locationSource ?? this.locationSource,
      locationStatus: locationStatus ?? this.locationStatus,
      isUsingTrueNorth: isUsingTrueNorth ?? this.isUsingTrueNorth,
      gpsAccuracyMeters:
          clearGpsAccuracy ? null : (gpsAccuracyMeters ?? this.gpsAccuracyMeters),
      suggestedPrayerCity: clearSuggestedPrayerCity
          ? null
          : (suggestedPrayerCity ?? this.suggestedPrayerCity),
    );
  }
}
