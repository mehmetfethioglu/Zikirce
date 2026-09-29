import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularCounterPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;

  const CircularCounterPainter({
    required this.progress,
    required this.progressColor,
    this.trackColor = Colors.transparent,
    this.strokeWidth = 9.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw Track if visible
    if (trackColor != Colors.transparent && trackColor.a > 0) {
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, trackPaint);
    }

    // 2. Draw Progress Arc starting from bottom (6 o'clock = 90 deg = math.pi / 2)
    // Matching MAUI OnCircularProgressPaintSurface: float startAngle = 90; float sweepAngle = 360 * progress;
    final safeProgress = (progress.isNaN || progress.isInfinite) ? 0.0 : progress.clamp(0.0, 1.0);
    if (safeProgress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * safeProgress;
      canvas.drawArc(
        rect,
        math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CircularCounterPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
