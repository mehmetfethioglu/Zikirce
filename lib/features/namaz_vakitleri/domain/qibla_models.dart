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

/// Kıble hizalanması ve İftitah Tekbiri durum makinesi aşamaları.
enum QiblaAlignmentPhase {
  searching,
  approaching,
  locked,
  takbir,
  qiyam,
}

/// Eğim düzeltmeli ham sensör ölçümü.
@immutable
class QiblaSensorSample {
  /// Cihazın +Y (üst) kenarının Manyetik Kuzey'e göre saat yönünde açısı [0, 360).
  final double headingDeg;

  /// Telefonun yatay düzlemden toplam eğimi (derece).
  final double tiltDeg;

  /// İleri-geri eğim (derece).
  final double pitchDeg;

  /// Sağa-sola eğim (derece).
  final double rollDeg;

  /// Manyetik alan büyüklüğü (µT).
  final double magneticFieldUt;

  const QiblaSensorSample({
    required this.headingDeg,
    required this.tiltDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.magneticFieldUt,
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
  });

  bool get isPhoneFlat => tiltDeg <= QiblaMath.maxFlatTiltDeg;

  bool get isSunVisible => sunElevationDeg > -2.0;

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
    );
  }
}
