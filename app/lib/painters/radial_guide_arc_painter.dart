import 'package:flutter/material.dart';

/// Subtle curved guide line connecting the radial setting buttons along their semi-circular fan.
class RadialButtonsGuideArcPainter extends CustomPainter {
  const RadialButtonsGuideArcPainter({
    required this.arcCenter,
    required this.arcRadius,
    required this.startAngle,
    required this.sweepAngle,
  });

  final Offset arcCenter;
  final double arcRadius;
  final double startAngle;
  final double sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: arcCenter, radius: arcRadius);
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant RadialButtonsGuideArcPainter oldDelegate) =>
      oldDelegate.arcCenter != arcCenter ||
      oldDelegate.arcRadius != arcRadius ||
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle;
}
