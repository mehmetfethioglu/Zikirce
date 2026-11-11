import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../constants/camera_colors.dart';
import '../models/active_pro_dial.dart';
import '../models/radial_ring_models.dart';

/// Authentic 3-tier concentric semi-circular rotating radial wheel painter:
/// - Ring 0 (Inner): primary manual scale driven solely by [normalizedValue].
/// - Ring 1 (Middle): secondary parameter band driven solely by [secondaryScrollPos].
/// - Ring 2 (Outer): mode quick-feature band driven solely by [outerFeatureScrollPos].
class IosCameraRadialWheelPainter extends CustomPainter {
  const IosCameraRadialWheelPainter({
    required this.dial,
    required this.normalizedValue,
    required this.centerValueText,
    required this.stops,
    this.secondaryItems = const <String>[],
    this.secondaryScrollPos = 0.0,
    this.outerFeatureItems = const <RadialOuterFeatureSpec>[],
    this.outerFeatureScrollPos = 0.0,
    this.activeRingBand = RadialRingBand.none,
  });

  /// 4mm concentric middle band width in logical pixels (~26 lp).
  static const double kOuterBandWidth = RadialRingGeometry.kSecondaryBandWidth;

  /// Concentric outermost quick-feature band width in logical pixels (~28 lp).
  static const double kOuterFeatureBandWidth =
      RadialRingGeometry.kOuterFeatureBandWidth;

  /// Angular spacing (radians) between consecutive labels on Ring 1.
  static const double kSecondaryItemAngleStep =
      RadialRingGeometry.kSecondaryAngleStep;

  /// Angular spacing (radians) between consecutive feature specs on Ring 2.
  static const double kOuterFeatureItemAngleStep =
      RadialRingGeometry.kOuterFeatureAngleStep;

  final ActiveProDial dial;
  final double normalizedValue;
  final String centerValueText;
  final List<({double norm, String primary, String secondary})> stops;
  final List<String> secondaryItems;
  final double secondaryScrollPos;
  final List<RadialOuterFeatureSpec> outerFeatureItems;
  final double outerFeatureScrollPos;
  final RadialRingBand activeRingBand;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius =
        RadialRingGeometry.computeInnerWheelRadius(size.width);
    if (radius <= 0.0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final Offset center = Offset(size.width * 0.5, size.height - 46.0);
    const double topApexAngle = RadialRingGeometry.kTopApexAngle;
    final bool hasSecondary = secondaryItems.isNotEmpty;
    final bool hasOuterFeature = outerFeatureItems.isNotEmpty;

    // Ring 2 (Outermost): Quick-Feature Band — 100% independent scroll state
    if (hasOuterFeature) {
      final ({double inner, double mid, double outer}) outerRadii =
          RadialRingGeometry.outerFeatureBandRadii(
        radius,
        hasSecondary: hasSecondary,
      );
      _paintOuterFeatureRing(
        canvas: canvas,
        center: center,
        innerRadius: outerRadii.inner,
        midRadius: outerRadii.mid,
        outerRadius: outerRadii.outer,
        topApexAngle: topApexAngle,
        isBandHighlighted: activeRingBand == RadialRingBand.outerFeature,
      );
    }

    // Ring 1 (Middle): Secondary Settings Band — 100% independent scroll state
    if (hasSecondary) {
      final ({double inner, double mid, double outer}) secRadii =
          RadialRingGeometry.secondaryBandRadii(radius);
      _paintConcentricSecondaryRing(
        canvas: canvas,
        center: center,
        innerRadius: secRadii.inner,
        midRadius: secRadii.mid,
        outerRadius: secRadii.outer,
        topApexAngle: topApexAngle,
        isBandHighlighted: activeRingBand == RadialRingBand.middleSecondary,
      );
    }

    // Ring 0 (Inner): Primary Scale Dome — 100% independent normalizedValue
    _paintInnerPrimaryWheel(
      canvas: canvas,
      center: center,
      radius: radius,
      topApexAngle: topApexAngle,
      isBandHighlighted: activeRingBand == RadialRingBand.innerPrimary,
    );

    canvas.restore();
  }

  void _paintInnerPrimaryWheel({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double topApexAngle,
    required bool isBandHighlighted,
  }) {
    final Rect wheelRect = Rect.fromCircle(center: center, radius: radius);

    final Shader domeShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: <Color>[
        Colors.black.withValues(alpha: isBandHighlighted ? 0.42 : 0.34),
        Colors.black.withValues(alpha: isBandHighlighted ? 0.64 : 0.56),
      ],
      stops: const <double>[0.4, 1.0],
    ).createShader(wheelRect);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = domeShader
        ..style = PaintingStyle.fill,
    );

    canvas.drawArc(
      wheelRect,
      -math.pi,
      math.pi,
      false,
      Paint()
        ..color = isBandHighlighted
            ? kIosYellow.withValues(alpha: 0.48)
            : Colors.white.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isBandHighlighted ? 1.25 : 1.0,
    );

    const double scaleSpanRad = math.pi * 0.64;
    double angleForNorm(double stopNorm) {
      return topApexAngle + (stopNorm - normalizedValue) * scaleSpanRad;
    }

    // Minor Vernier Ticks
    const int totalMinorTicks = 60;
    for (int i = 0; i <= totalMinorTicks; i++) {
      final double t = i / totalMinorTicks;
      final double angle = angleForNorm(t);
      if (angle < -math.pi * 0.91 || angle > -math.pi * 0.09) continue;

      bool nearMajor = false;
      for (final ({double norm, String primary, String secondary}) s in stops) {
        if ((s.norm - t).abs() < 0.011) {
          nearMajor = true;
          break;
        }
      }
      if (nearMajor) continue;

      final double outerR = radius - 1.5;
      final double innerR = outerR - 8.5;
      final double edgeDist =
          ((angle - topApexAngle).abs() / (math.pi * 0.42)).clamp(0.0, 1.0);
      final double alpha = (1.0 - edgeDist * 0.65) * 0.32;

      canvas.drawLine(
        RadialRingGeometry.polarPoint(center, innerR, angle),
        RadialRingGeometry.polarPoint(center, outerR, angle),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 0.9,
      );
    }

    // Major Stop Ticks + Labels
    for (final ({double norm, String primary, String secondary}) stop
        in stops) {
      final double angle = angleForNorm(stop.norm);
      if (angle < -math.pi * 0.90 || angle > -math.pi * 0.10) continue;

      final double edgeDist =
          ((angle - topApexAngle).abs() / (math.pi * 0.42)).clamp(0.0, 1.0);
      final double tickAlpha = (1.0 - edgeDist * 0.55) * 0.92;

      final double outerR = radius - 1.0;
      final double innerR = outerR - 15.5;
      canvas.drawLine(
        RadialRingGeometry.polarPoint(center, innerR, angle),
        RadialRingGeometry.polarPoint(center, outerR, angle),
        Paint()
          ..color = Colors.white.withValues(alpha: tickAlpha)
          ..strokeWidth = 1.5,
      );

      if ((angle - topApexAngle).abs() < 0.085) continue;

      final Offset startPos =
          RadialRingGeometry.polarPoint(center, radius - 23.0, angle);

      canvas.save();
      canvas.translate(startPos.dx, startPos.dy);
      canvas.rotate(angle + math.pi);

      final TextPainter primaryTp = TextPainter(
        text: TextSpan(
          text: stop.primary,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: Colors.white.withValues(alpha: tickAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      primaryTp.paint(canvas, Offset(0, -primaryTp.height * 0.5));

      if (stop.secondary.isNotEmpty) {
        final TextPainter secTp = TextPainter(
          text: TextSpan(
            text: stop.secondary,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Colors.white.withValues(alpha: tickAlpha * 0.42),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        secTp.paint(
          canvas,
          Offset(primaryTp.width + 5.0, -secTp.height * 0.5),
        );
      }

      canvas.restore();
    }

    // Top Indicator & Value
    final double apexX = center.dx;
    final double apexY = center.dy - radius;

    final Path pointerPath = Path()
      ..moveTo(apexX - 3.6, apexY + 2.5)
      ..lineTo(apexX + 3.6, apexY + 2.5)
      ..lineTo(apexX, apexY + 13.0)
      ..close();
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = kIosYellow
        ..style = PaintingStyle.fill,
    );

    canvas.save();
    canvas.translate(apexX, apexY + 22.0);
    canvas.rotate(math.pi * 0.5);

    final TextPainter activeTp = TextPainter(
      text: TextSpan(
        text: centerValueText,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: kIosYellow,
          shadows: <Shadow>[
            Shadow(color: Colors.black87, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    activeTp.paint(canvas, Offset(0, -activeTp.height * 0.5));
    canvas.restore();
  }

  void _paintConcentricSecondaryRing({
    required Canvas canvas,
    required Offset center,
    required double innerRadius,
    required double midRadius,
    required double outerRadius,
    required double topApexAngle,
    required bool isBandHighlighted,
  }) {
    final Rect outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final Rect innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    final Path ringPath = Path()
      ..addOval(outerRect)
      ..addOval(innerRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      ringPath,
      Paint()
        ..color = Colors.black.withValues(alpha: isBandHighlighted ? 0.74 : 0.64)
        ..style = PaintingStyle.fill,
    );

    canvas.drawArc(
      outerRect,
      -math.pi,
      math.pi,
      false,
      Paint()
        ..color = isBandHighlighted
            ? kIosYellow.withValues(alpha: 0.48)
            : Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isBandHighlighted ? 1.2 : 0.9,
    );

    final int activeIdx =
        secondaryScrollPos.round().clamp(0, secondaryItems.length - 1);

    for (int i = 0; i < secondaryItems.length; i++) {
      final double itemAngle = RadialRingGeometry.itemAngle(
        index: i,
        scrollPos: secondaryScrollPos,
        angleStep: kSecondaryItemAngleStep,
      );
      if (itemAngle < -math.pi * 0.92 || itemAngle > -math.pi * 0.08) {
        continue;
      }

      final bool isSelected = i == activeIdx;
      final double distFromApex = (itemAngle - topApexAngle).abs();
      final double edgeFade =
          1.0 - (distFromApex / (math.pi * 0.42)).clamp(0.0, 1.0);
      final double textAlpha =
          isSelected ? 1.0 : (0.35 + 0.50 * edgeFade).clamp(0.22, 0.85);

      _paintCurvedArcText(
        canvas: canvas,
        center: center,
        radius: midRadius,
        centerAngle: itemAngle,
        text: secondaryItems[i],
        style: TextStyle(
          fontSize: isSelected ? 10.5 : 9.8,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.3,
          color: isSelected
              ? kIosYellow
              : Colors.white.withValues(alpha: textAlpha),
          shadows: isSelected
              ? const <Shadow>[Shadow(color: Colors.black87, blurRadius: 4)]
              : null,
        ),
      );

      if (i < secondaryItems.length - 1) {
        final double sepAngle = itemAngle + kSecondaryItemAngleStep * 0.5;
        if (sepAngle > -math.pi * 0.88 && sepAngle < -math.pi * 0.12) {
          final Offset dotPos =
              RadialRingGeometry.polarPoint(center, midRadius, sepAngle);
          canvas.drawCircle(
            dotPos,
            1.3,
            Paint()..color = Colors.white.withValues(alpha: 0.22 * edgeFade),
          );
        }
      }
    }
  }

  void _paintOuterFeatureRing({
    required Canvas canvas,
    required Offset center,
    required double innerRadius,
    required double midRadius,
    required double outerRadius,
    required double topApexAngle,
    required bool isBandHighlighted,
  }) {
    final Rect outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final Rect innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final Rect midRect = Rect.fromCircle(center: center, radius: midRadius);

    final Path ringPath = Path()
      ..addOval(outerRect)
      ..addOval(innerRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      ringPath,
      Paint()
        ..color = Colors.black.withValues(alpha: isBandHighlighted ? 0.72 : 0.58)
        ..style = PaintingStyle.fill,
    );

    canvas.drawArc(
      outerRect,
      -math.pi,
      math.pi,
      false,
      Paint()
        ..color = isBandHighlighted
            ? kZameraCyan.withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isBandHighlighted ? 1.25 : 0.9,
    );

    // Top apex reference marker on Ring 2 rim
    final Offset apexOuter =
        RadialRingGeometry.polarPoint(center, outerRadius, topApexAngle);
    final Offset apexInner =
        RadialRingGeometry.polarPoint(center, outerRadius - 4.0, topApexAngle);
    canvas.drawLine(
      apexOuter,
      apexInner,
      Paint()
        ..color = kIosYellow.withValues(alpha: 0.65)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    final int focusedIdx =
        outerFeatureScrollPos.round().clamp(0, outerFeatureItems.length - 1);

    for (int i = 0; i < outerFeatureItems.length; i++) {
      final RadialOuterFeatureSpec spec = outerFeatureItems[i];
      final double itemAngle = RadialRingGeometry.itemAngle(
        index: i,
        scrollPos: outerFeatureScrollPos,
        angleStep: kOuterFeatureItemAngleStep,
      );
      if (itemAngle < -math.pi * 0.93 || itemAngle > -math.pi * 0.07) {
        continue;
      }

      final bool isFocused = i == focusedIdx;
      final double distFromApex = (itemAngle - topApexAngle).abs();
      final double edgeFade =
          1.0 - (distFromApex / (math.pi * 0.44)).clamp(0.0, 1.0);
      final double textAlpha = spec.isActive
          ? 1.0
          : (isFocused ? 0.95 : (0.36 + 0.48 * edgeFade).clamp(0.24, 0.84));

      final String displayLabel = (spec.secondaryLabel != null &&
              spec.secondaryLabel!.isNotEmpty)
          ? '${spec.label}·${spec.secondaryLabel}'
          : spec.label;

      if (spec.isActive) {
        // Subtle illuminated arc highlight behind active feature
        const double highlightSweep = 0.24;
        canvas.drawArc(
          midRect,
          itemAngle - highlightSweep * 0.5,
          highlightSweep,
          false,
          Paint()
            ..color = spec.accentColor.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = kOuterFeatureBandWidth - 6.0
            ..strokeCap = StrokeCap.round,
        );

        // Bright active highlight dot near outer rim of Ring 2
        final Offset dotPos = RadialRingGeometry.polarPoint(
          center,
          outerRadius - 4.2,
          itemAngle,
        );
        canvas.drawCircle(
          dotPos,
          4.2,
          Paint()..color = spec.accentColor.withValues(alpha: 0.30),
        );
        canvas.drawCircle(
          dotPos,
          2.1,
          Paint()..color = spec.accentColor,
        );
      }

      final Color labelColor = spec.isActive
          ? spec.accentColor
          : Colors.white.withValues(alpha: textAlpha);

      _paintCurvedArcText(
        canvas: canvas,
        center: center,
        radius: spec.isActive ? midRadius - 1.5 : midRadius,
        centerAngle: itemAngle,
        text: displayLabel,
        style: TextStyle(
          fontSize: (spec.isActive || isFocused) ? 10.2 : 9.4,
          fontWeight:
              (spec.isActive || isFocused) ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.25,
          color: labelColor,
          shadows: (spec.isActive || isFocused)
              ? const <Shadow>[Shadow(color: Colors.black87, blurRadius: 4)]
              : null,
        ),
      );

      if (i < outerFeatureItems.length - 1) {
        final double sepAngle = itemAngle + kOuterFeatureItemAngleStep * 0.5;
        if (sepAngle > -math.pi * 0.89 && sepAngle < -math.pi * 0.11) {
          final Offset sepPos =
              RadialRingGeometry.polarPoint(center, midRadius, sepAngle);
          canvas.drawCircle(
            sepPos,
            1.2,
            Paint()..color = Colors.white.withValues(alpha: 0.20 * edgeFade),
          );
        }
      }
    }
  }

  void _paintCurvedArcText({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double centerAngle,
    required String text,
    required TextStyle style,
  }) {
    if (text.isEmpty || radius <= 0.0) return;
    final List<TextPainter> charPainters = <TextPainter>[];
    double totalArcLength = 0.0;

    for (int i = 0; i < text.length; i++) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      charPainters.add(tp);
      totalArcLength += tp.width;
    }

    double currentArcOffset = -totalArcLength * 0.5;
    for (final TextPainter tp in charPainters) {
      final double charCenterOffset = currentArcOffset + tp.width * 0.5;
      final double charAngle = centerAngle + (charCenterOffset / radius);
      final Offset pos = RadialRingGeometry.polarPoint(center, radius, charAngle);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(charAngle + math.pi * 0.5);
      tp.paint(canvas, Offset(-tp.width * 0.5, -tp.height * 0.5));
      canvas.restore();

      currentArcOffset += tp.width;
    }
  }

  @override
  bool shouldRepaint(covariant IosCameraRadialWheelPainter oldDelegate) =>
      oldDelegate.dial != dial ||
      oldDelegate.normalizedValue != normalizedValue ||
      oldDelegate.centerValueText != centerValueText ||
      oldDelegate.stops.length != stops.length ||
      oldDelegate.secondaryScrollPos != secondaryScrollPos ||
      !listEquals(oldDelegate.secondaryItems, secondaryItems) ||
      oldDelegate.outerFeatureScrollPos != outerFeatureScrollPos ||
      !listEquals(oldDelegate.outerFeatureItems, outerFeatureItems) ||
      oldDelegate.activeRingBand != activeRingBand;
}
