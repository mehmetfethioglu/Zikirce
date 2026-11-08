import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';
import '../models/active_pro_dial.dart';

/// Authentic semi-circular rotating radial wheel painter for manual settings.
class IosCameraRadialWheelPainter extends CustomPainter {
  const IosCameraRadialWheelPainter({
    required this.dial,
    required this.normalizedValue,
    required this.centerValueText,
    required this.stops,
  });

  final ActiveProDial dial;
  final double normalizedValue;
  final String centerValueText;
  final List<({double norm, String primary, String secondary})> stops;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final radius = math.min(size.width * 0.64, 256.0);
    final center = Offset(size.width * 0.5, size.height - 46.0);
    final wheelRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Smoked Dome Fill
    final domeShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.black.withValues(alpha: 0.25),
        Colors.black.withValues(alpha: 0.44),
      ],
      stops: const [0.4, 1.0],
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
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    const scaleSpanRad = math.pi * 0.64;
    const topApexAngle = -math.pi * 0.5;

    double angleForNorm(double stopNorm) {
      return topApexAngle + (stopNorm - normalizedValue) * scaleSpanRad;
    }

    // 2. Minor Vernier Ticks
    const totalMinorTicks = 60;
    for (int i = 0; i <= totalMinorTicks; i++) {
      final t = i / totalMinorTicks;
      final angle = angleForNorm(t);
      if (angle < -math.pi * 0.91 || angle > -math.pi * 0.09) continue;

      bool nearMajor = false;
      for (final s in stops) {
        if ((s.norm - t).abs() < 0.011) {
          nearMajor = true;
          break;
        }
      }
      if (nearMajor) continue;

      final outerR = radius - 1.5;
      final innerR = outerR - 8.5;
      final edgeDist =
          ((angle - topApexAngle).abs() / (math.pi * 0.42)).clamp(0.0, 1.0);
      final alpha = (1.0 - edgeDist * 0.65) * 0.32;

      canvas.drawLine(
        Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        ),
        Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 0.9,
      );
    }

    // 3. Major Stop Ticks + Labels
    for (final stop in stops) {
      final angle = angleForNorm(stop.norm);
      if (angle < -math.pi * 0.90 || angle > -math.pi * 0.10) continue;

      final edgeDist =
          ((angle - topApexAngle).abs() / (math.pi * 0.42)).clamp(0.0, 1.0);
      final tickAlpha = (1.0 - edgeDist * 0.55) * 0.92;

      final outerR = radius - 1.0;
      final innerR = outerR - 15.5;
      canvas.drawLine(
        Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        ),
        Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: tickAlpha)
          ..strokeWidth = 1.5,
      );

      if ((angle - topApexAngle).abs() < 0.085) continue;

      final textStartR = radius - 23.0;
      final startPos = Offset(
        center.dx + textStartR * math.cos(angle),
        center.dy + textStartR * math.sin(angle),
      );

      canvas.save();
      canvas.translate(startPos.dx, startPos.dy);
      canvas.rotate(angle + math.pi);

      final primaryTp = TextPainter(
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
        final secTp = TextPainter(
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

    // 4. Top Indicator & Value
    final apexX = center.dx;
    final apexY = center.dy - radius;

    final pointerPath = Path()
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

    final activeTp = TextPainter(
      text: TextSpan(
        text: centerValueText,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: kIosYellow,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    activeTp.paint(canvas, Offset(0, -activeTp.height * 0.5));
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IosCameraRadialWheelPainter oldDelegate) =>
      oldDelegate.dial != dial ||
      oldDelegate.normalizedValue != normalizedValue ||
      oldDelegate.centerValueText != centerValueText;
}
