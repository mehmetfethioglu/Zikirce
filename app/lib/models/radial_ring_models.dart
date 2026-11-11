import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show IconData;

/// Concentric radial dial touch/render band classification.
enum RadialRingBand {
  none,
  innerPrimary,
  middleSecondary,
  outerFeature;

  bool get isInteractive => this != RadialRingBand.none;
}

/// Immutable descriptor for an item rendered on the outermost concentric feature arc.
@immutable
class RadialOuterFeatureSpec {
  final String id;
  final String label;
  final String? secondaryLabel;
  final IconData? icon;
  final bool isActive;
  final Color accentColor;

  const RadialOuterFeatureSpec({
    required this.id,
    required this.label,
    this.secondaryLabel,
    this.icon,
    this.isActive = false,
    this.accentColor = const Color(0xFFFFD60A),
  });

  RadialOuterFeatureSpec copyWith({
    String? id,
    String? label,
    String? secondaryLabel,
    bool clearSecondaryLabel = false,
    IconData? icon,
    bool clearIcon = false,
    bool? isActive,
    Color? accentColor,
  }) {
    return RadialOuterFeatureSpec(
      id: id ?? this.id,
      label: label ?? this.label,
      secondaryLabel:
          clearSecondaryLabel ? null : (secondaryLabel ?? this.secondaryLabel),
      icon: clearIcon ? null : (icon ?? this.icon),
      isActive: isActive ?? this.isActive,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RadialOuterFeatureSpec &&
        other.id == id &&
        other.label == label &&
        other.secondaryLabel == secondaryLabel &&
        other.icon == icon &&
        other.isActive == isActive &&
        other.accentColor == accentColor;
  }

  @override
  int get hashCode => Object.hash(
        id,
        label,
        secondaryLabel,
        icon,
        isActive,
        accentColor,
      );
}

/// Pure, stateless polar geometry and hit-testing engine for Zamera's 3-tier concentric radial dial.
class RadialRingGeometry {
  const RadialRingGeometry._();

  /// Width of the middle concentric secondary parameter band in logical pixels.
  static const double kSecondaryBandWidth = 26.0;

  /// Width of the outermost concentric quick-feature band in logical pixels.
  static const double kOuterFeatureBandWidth = 28.0;

  /// Default angular spacing (radians) between items on the middle secondary arc.
  static const double kSecondaryAngleStep = 0.36;

  /// Angular spacing (radians) between items on the outer feature arc.
  static const double kOuterFeatureAngleStep = 0.40;

  /// Top apex reference angle (-90°, 12 o'clock) in standard screen polar coordinates.
  static const double kTopApexAngle = -math.pi * 0.5;

  /// Default horizontal drag distance (px) corresponding to 1 discrete arc item step.
  static const double kDefaultDragPixelsPerStep = 42.0;

  /// Computes the inner primary wheel radius constrained so concentric outer bands fit within [width].
  static double computeInnerWheelRadius(double width) {
    if (width <= 0.0 || !width.isFinite) return 0.0;
    return math.min(width * 0.60, 236.0);
  }

  /// Computes `(inner, mid, outer)` radii for the middle secondary band around [innerWheelRadius].
  static ({double inner, double mid, double outer}) secondaryBandRadii(
    double innerWheelRadius,
  ) {
    final inner = innerWheelRadius.isFinite ? math.max(0.0, innerWheelRadius) : 0.0;
    final outer = inner + kSecondaryBandWidth;
    return (
      inner: inner,
      mid: inner + kSecondaryBandWidth * 0.5,
      outer: outer,
    );
  }

  /// Computes `(inner, mid, outer)` radii for the outermost feature band.
  /// Collapses directly onto [innerWheelRadius] when [hasSecondary] is false.
  static ({double inner, double mid, double outer}) outerFeatureBandRadii(
    double innerWheelRadius, {
    bool hasSecondary = true,
  }) {
    final safeInner =
        innerWheelRadius.isFinite ? math.max(0.0, innerWheelRadius) : 0.0;
    final base = safeInner + (hasSecondary ? kSecondaryBandWidth : 0.0);
    final outer = base + kOuterFeatureBandWidth;
    return (
      inner: base,
      mid: base + kOuterFeatureBandWidth * 0.5,
      outer: outer,
    );
  }

  /// Classifies [point] into one of the mutually exclusive concentric radial bands.
  static RadialRingBand hitTestBand({
    required Offset point,
    required Offset center,
    required double innerWheelRadius,
    bool hasSecondary = true,
    bool hasOuterFeature = true,
    double outerTouchSlop = 12.0,
  }) {
    if (innerWheelRadius <= 0.0 || !innerWheelRadius.isFinite) {
      return RadialRingBand.none;
    }
    if (point.dy > center.dy + 46.0) {
      return RadialRingBand.none;
    }

    final dist = (point - center).distance;
    final safeSlop = outerTouchSlop.isFinite ? math.max(0.0, outerTouchSlop) : 0.0;

    if (!hasSecondary && !hasOuterFeature) {
      return dist <= innerWheelRadius + safeSlop
          ? RadialRingBand.innerPrimary
          : RadialRingBand.none;
    }

    if (dist < innerWheelRadius) {
      return RadialRingBand.innerPrimary;
    }

    if (hasSecondary) {
      final sec = secondaryBandRadii(innerWheelRadius);
      if (!hasOuterFeature) {
        return dist <= sec.outer + safeSlop
            ? RadialRingBand.middleSecondary
            : RadialRingBand.none;
      }
      if (dist < sec.outer) {
        return RadialRingBand.middleSecondary;
      }
    }

    if (hasOuterFeature) {
      final ext = outerFeatureBandRadii(
        innerWheelRadius,
        hasSecondary: hasSecondary,
      );
      if (dist <= ext.outer + safeSlop) {
        return RadialRingBand.outerFeature;
      }
    }

    return RadialRingBand.none;
  }

  /// Computes clamped arc scroll position after horizontal drag [deltaDx].
  static double scrollPosAfterDrag({
    required double currentScrollPos,
    required double deltaDx,
    required int itemCount,
    double pixelsPerStep = kDefaultDragPixelsPerStep,
  }) {
    if (itemCount <= 1 || !currentScrollPos.isFinite || !deltaDx.isFinite) {
      return 0.0;
    }
    final safeStep = (!pixelsPerStep.isFinite || pixelsPerStep.abs() < 1.0)
        ? kDefaultDragPixelsPerStep
        : pixelsPerStep.abs();
    final maxIdx = (itemCount - 1).toDouble();
    return (currentScrollPos - deltaDx / safeStep).clamp(0.0, maxIdx);
  }

  /// Resolves which arc item index (`0..itemCount-1`) was tapped at [point], or `null` if out of bounds.
  static int? hitTestArcItemIndex({
    required Offset point,
    required Offset center,
    required double currentScrollPos,
    required int itemCount,
    required double angleStep,
    double maxHalfSpanRad = math.pi * 0.46,
    double slotTolerance = 0.75,
  }) {
    if (itemCount <= 0 ||
        angleStep <= 0.0 ||
        !angleStep.isFinite ||
        !currentScrollPos.isFinite) {
      return null;
    }

    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    if (dx == 0.0 && dy == 0.0) {
      return null;
    }

    final tapAngle = math.atan2(dy, dx);
    double deltaAngle = tapAngle - kTopApexAngle;
    while (deltaAngle <= -math.pi) {
      deltaAngle += 2.0 * math.pi;
    }
    while (deltaAngle > math.pi) {
      deltaAngle -= 2.0 * math.pi;
    }

    if (deltaAngle.abs() > maxHalfSpanRad) {
      return null;
    }

    final rawIndex = currentScrollPos + (deltaAngle / angleStep);
    final clampedCandidate = rawIndex.round().clamp(0, itemCount - 1);
    if ((rawIndex - clampedCandidate).abs() > slotTolerance) {
      return null;
    }
    return clampedCandidate;
  }

  /// Converts polar coordinates `(radius, angleRad)` around [center] to Cartesian [Offset].
  static Offset polarPoint(Offset center, double radius, double angleRad) {
    return Offset(
      center.dx + radius * math.cos(angleRad),
      center.dy + radius * math.sin(angleRad),
    );
  }

  /// Computes polar angle (radians) for an arc item [index] given [scrollPos] and [angleStep].
  static double itemAngle({
    required int index,
    required double scrollPos,
    required double angleStep,
  }) {
    return kTopApexAngle + (index - scrollPos) * angleStep;
  }
}
