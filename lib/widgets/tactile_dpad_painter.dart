import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cue_models.dart';

/// 120 FPS CustomPainter for the Google TV G10 style donut D-Pad dial
/// supporting both True Black (`#000000`) Dark Mode and Reference White Light Mode.
class TactileDpadPainter extends CustomPainter {
  const TactileDpadPainter({
    required this.activeDirection,
    required this.accentColor,
    this.isDarkMode = true,
  });

  final TvKeyCommand? activeDirection;
  final Color accentColor;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 2;
    final innerRadius = outerRadius * 0.40;

    // 1. Soft outer elevation shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDarkMode ? 0.55 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center.translate(0, 3), outerRadius, shadowPaint);

    // 2. Main donut outer ring fill (Charcoal-black on Light mode, deep obsidian on True Black mode)
    final ringRect = Rect.fromCircle(center: center, radius: outerRadius);
    final ringPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? const <Color>[
                Color(0xFF1D202A),
                Color(0xFF141720),
                Color(0xFF0E1017),
              ]
            : const <Color>[
                Color(0xFF262A32),
                Color(0xFF1C2026),
                Color(0xFF15181D),
              ],
      ).createShader(ringRect);
    canvas.drawCircle(center, outerRadius, ringPaint);

    // 3. Outer rim hairline border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = isDarkMode
          ? const Color(0xFF2C3140)
          : Colors.black.withValues(alpha: 0.35);
    canvas.drawCircle(center, outerRadius, borderPaint);

    // 4. Active directional quadrant arc highlight
    if (activeDirection != null && activeDirection != TvKeyCommand.ok) {
      double? startAngle;
      switch (activeDirection!) {
        case TvKeyCommand.up:
          startAngle = -math.pi * 0.75;
        case TvKeyCommand.right:
          startAngle = -math.pi * 0.25;
        case TvKeyCommand.down:
          startAngle = math.pi * 0.25;
        case TvKeyCommand.left:
          startAngle = math.pi * 0.75;
        default:
          startAngle = null;
      }
      if (startAngle != null) {
        final arcRadius = (outerRadius + innerRadius) / 2;
        final highlightPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerRadius - innerRadius - 4
          ..strokeCap = StrokeCap.butt
          ..color = accentColor.withValues(alpha: 0.30);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcRadius),
          startAngle,
          math.pi / 2,
          false,
          highlightPaint,
        );
      }
    }

    // 5. Minimal directional cardinal dots (subtle tactile cues at 12, 3, 6, 9 o'clock)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final dotOrbit = outerRadius - 11;
    for (var i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final dotCenter = Offset(
        center.dx + dotOrbit * math.cos(angle),
        center.dy + dotOrbit * math.sin(angle),
      );
      canvas.drawCircle(dotCenter, 1.6, dotPaint);
    }

    // 6. Center OK flat high-contrast circle (True Black #000000 in dark mode, crisp White #F5F6F9 in light mode)
    final isOkPressed = activeDirection == TvKeyCommand.ok;
    final okFillColor = isOkPressed
        ? (isDarkMode ? const Color(0xFF1F2430) : const Color(0xFFE2E5EC))
        : (isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F6F9));

    final okFillPaint = Paint()
      ..color = okFillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, okFillPaint);

    final okBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isOkPressed ? 2.0 : 1.2
      ..color = isOkPressed
          ? accentColor
          : (isDarkMode
              ? const Color(0xFF2B303C)
              : Colors.black.withValues(alpha: 0.18));
    canvas.drawCircle(center, innerRadius, okBorderPaint);
  }

  @override
  bool shouldRepaint(covariant TactileDpadPainter oldDelegate) {
    return oldDelegate.activeDirection != activeDirection ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

/// 120 FPS CustomPainter for circular watch-plan mastery percentage ring.
class CircularProgressRingPainter extends CustomPainter {
  const CircularProgressRingPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    this.isDarkMode = true,
  });

  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;
    const strokeWidth = 8.5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.09);
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: <Color>[primaryColor, secondaryColor, primaryColor],
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * clamped,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
