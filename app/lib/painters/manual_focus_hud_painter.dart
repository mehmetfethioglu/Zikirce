import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// Live Manual Focus Distance Scale & Focus Peaking Reticle Painter.
class ManualFocusHudPainter extends CustomPainter {
  const ManualFocusHudPainter({
    required this.focusNorm,
    required this.focusDistanceNorm,
    required this.formattedDistance,
    required this.manualFocusLocked,
    required this.showPeaking,
  });

  final Offset focusNorm;
  final double focusDistanceNorm;
  final String formattedDistance;
  final bool manualFocusLocked;
  final bool showPeaking;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * focusNorm.dx;
    final cy = size.height * focusNorm.dy;

    // 1. Focus Peaking Reticle
    if (showPeaking) {
      final peakPaint = Paint()
        ..color = kZameraCyan.withValues(alpha: 0.85)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), 42.0, peakPaint);
      canvas.drawCircle(
        Offset(cx, cy),
        22.0,
        Paint()
          ..color = kIosYellow.withValues(alpha: 0.78)
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );
      canvas.drawLine(
        Offset(cx - 50, cy),
        Offset(cx - 34, cy),
        peakPaint,
      );
      canvas.drawLine(
        Offset(cx + 34, cy),
        Offset(cx + 50, cy),
        peakPaint,
      );
      canvas.drawLine(
        Offset(cx, cy - 50),
        Offset(cx, cy - 34),
        peakPaint,
      );
      canvas.drawLine(
        Offset(cx, cy + 34),
        Offset(cx, cy + 50),
        peakPaint,
      );
    }

    // 2. Vertical Optical Focus Distance Scale on Right Edge (∞ .. 10cm Makro)
    const railTop = 105.0;
    const railBottom = 285.0;
    const railH = railBottom - railTop;
    final railX = size.width - 20.0;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(railX - 16, railTop - 16, 28, railH + 32),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final trackPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(railX, railTop),
      Offset(railX, railBottom),
      trackPaint,
    );

    for (int i = 0; i <= 10; i++) {
      final y = railTop + (i / 10.0) * railH;
      final isMajor = i % 5 == 0;
      canvas.drawLine(
        Offset(railX - (isMajor ? 7.0 : 4.0), y),
        Offset(railX + 2.0, y),
        Paint()
          ..color = isMajor ? Colors.white70 : Colors.white38
          ..strokeWidth = isMajor ? 1.3 : 0.8,
      );
    }

    final cursorY = railTop + focusDistanceNorm.clamp(0.0, 1.0) * railH;
    canvas.drawCircle(
      Offset(railX, cursorY),
      5.5,
      Paint()..color = manualFocusLocked ? kIosYellow : kZameraCyan,
    );

    final labelTp = TextPainter(
      text: TextSpan(
        text: manualFocusLocked ? 'MF $formattedDistance' : 'AF $formattedDistance',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: manualFocusLocked ? kIosYellow : kZameraCyan,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(
      canvas,
      Offset(railX - labelTp.width - 12, cursorY - labelTp.height * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant ManualFocusHudPainter oldDelegate) =>
      oldDelegate.focusNorm != focusNorm ||
      oldDelegate.focusDistanceNorm != focusDistanceNorm ||
      oldDelegate.formattedDistance != formattedDistance ||
      oldDelegate.manualFocusLocked != manualFocusLocked ||
      oldDelegate.showPeaking != showPeaking;
}
