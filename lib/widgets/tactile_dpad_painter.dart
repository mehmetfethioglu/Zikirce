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
    this.isTouchpadMode = false,
    this.touchPosition,
  });

  final TvKeyCommand? activeDirection;
  final Color accentColor;
  final bool isDarkMode;
  final bool isTouchpadMode;
  final Offset? touchPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (isTouchpadMode) {
      // Studio-grade Glassmorphic Trackpad Surface (`RRect`) with micro-dot grid & corner brackets
      final padRect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
      final padRRect = RRect.fromRectAndRadius(
        padRect,
        const Radius.circular(20),
      );

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: isDarkMode ? 0.55 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(padRRect.shift(const Offset(0, 3)), shadowPaint);

      final surfacePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? const <Color>[
                  Color(0xFF1B202C),
                  Color(0xFF11151F),
                  Color(0xFF0A0D14),
                ]
              : const <Color>[
                  Color(0xFF262B35),
                  Color(0xFF1B1F27),
                  Color(0xFF13161C),
                ],
        ).createShader(padRect);
      canvas.drawRRect(padRRect, surfacePaint);

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accentColor.withValues(alpha: 0.68);
      canvas.drawRRect(padRRect, borderPaint);

      // Subtle micro-dot matrix across the trackpad surface for spatial tactile depth
      final dotMatrixPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.07);
      const stepX = 22.0;
      const stepY = 22.0;
      for (double x = padRect.left + 20; x <= padRect.right - 20; x += stepX) {
        for (double y = padRect.top + 20; y <= padRect.bottom - 20; y += stepY) {
          canvas.drawCircle(Offset(x, y), 0.95, dotMatrixPaint);
        }
      }

      // Precision Corner L-Brackets (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
      final bracketPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = accentColor.withValues(alpha: 0.52);
      const inset = 11.0;
      const arm = 10.0;
      // Top-Left
      canvas.drawLine(
        Offset(padRect.left + inset, padRect.top + inset + arm),
        Offset(padRect.left + inset, padRect.top + inset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(padRect.left + inset, padRect.top + inset),
        Offset(padRect.left + inset + arm, padRect.top + inset),
        bracketPaint,
      );
      // Top-Right
      canvas.drawLine(
        Offset(padRect.right - inset - arm, padRect.top + inset),
        Offset(padRect.right - inset, padRect.top + inset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(padRect.right - inset, padRect.top + inset),
        Offset(padRect.right - inset, padRect.top + inset + arm),
        bracketPaint,
      );
      // Bottom-Left
      canvas.drawLine(
        Offset(padRect.left + inset, padRect.bottom - inset - arm),
        Offset(padRect.left + inset, padRect.bottom - inset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(padRect.left + inset, padRect.bottom - inset),
        Offset(padRect.left + inset + arm, padRect.bottom - inset),
        bracketPaint,
      );
      // Bottom-Right
      canvas.drawLine(
        Offset(padRect.right - inset - arm, padRect.bottom - inset),
        Offset(padRect.right - inset, padRect.bottom - inset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(padRect.right - inset, padRect.bottom - inset - arm),
        Offset(padRect.right - inset, padRect.bottom - inset),
        bracketPaint,
      );

      if (touchPosition != null) {
        final clampedPos = Offset(
          touchPosition!.dx.clamp(padRect.left + 14, padRect.right - 14),
          touchPosition!.dy.clamp(padRect.top + 14, padRect.bottom - 14),
        );

        final guidePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = accentColor.withValues(alpha: 0.22);
        canvas.drawLine(
          Offset(padRect.left + 12, clampedPos.dy),
          Offset(padRect.right - 12, clampedPos.dy),
          guidePaint,
        );
        canvas.drawLine(
          Offset(clampedPos.dx, padRect.top + 12),
          Offset(clampedPos.dx, padRect.bottom - 12),
          guidePaint,
        );

        final outerRipplePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accentColor.withValues(alpha: 0.55);
        canvas.drawCircle(clampedPos, 20, outerRipplePaint);

        final haloPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = accentColor.withValues(alpha: 0.22);
        canvas.drawCircle(clampedPos, 15, haloPaint);

        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = accentColor;
        canvas.drawCircle(clampedPos, 5.0, corePaint);
      }
      return;
    }

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
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.isTouchpadMode != isTouchpadMode ||
        oldDelegate.touchPosition != touchPosition;
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

/// 120 FPS CustomPainter for the 3D Recessed Tactile Mouse Scroll Wheel
/// with animated rotary knurled ridges that shift with [scrollOffset].
class TactileScrollWheelPainter extends CustomPainter {
  const TactileScrollWheelPainter({
    required this.scrollOffset,
    required this.accentColor,
    this.isDarkMode = true,
    this.isScrolling = false,
  });

  final double scrollOffset;
  final Color accentColor;
  final bool isDarkMode;
  final bool isScrolling;

  @override
  void paint(Canvas canvas, Size size) {
    final wheelRect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final wheelRRect = RRect.fromRectAndRadius(
      wheelRect,
      const Radius.circular(14),
    );

    // 1. Cylindrical wheel body gradient (darker at top/bottom poles, brighter at center equator)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDarkMode
            ? const <Color>[
                Color(0xFF07090E),
                Color(0xFF1F2432),
                Color(0xFF282F40),
                Color(0xFF1F2432),
                Color(0xFF07090E),
              ]
            : const <Color>[
                Color(0xFF1A1E26),
                Color(0xFF323948),
                Color(0xFF3E4658),
                Color(0xFF323948),
                Color(0xFF1A1E26),
              ],
        stops: const <double>[0.0, 0.22, 0.50, 0.78, 1.0],
      ).createShader(wheelRect);
    canvas.drawRRect(wheelRRect, bodyPaint);

    // 2. Clip to wheel silhouette and render animated horizontal knurled ridges
    canvas.save();
    canvas.clipRRect(wheelRRect);

    const ridgeSpacing = 9.0;
    final phase = scrollOffset % ridgeSpacing;
    final centerY = wheelRect.center.dy;
    final halfHeight = (wheelRect.height / 2).clamp(1.0, 500.0);

    for (double y = wheelRect.top - ridgeSpacing + phase;
        y <= wheelRect.bottom + ridgeSpacing;
        y += ridgeSpacing) {
      final normDist = ((y - centerY).abs() / halfHeight).clamp(0.0, 1.0);
      final alphaFactor = (1.0 - (normDist * 0.75)).clamp(0.15, 1.0);

      final ridgeHighlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = (isScrolling ? accentColor : Colors.white)
            .withValues(alpha: (isScrolling ? 0.65 : 0.34) * alphaFactor);

      final ridgeShadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.65 * alphaFactor);

      final insetX = 6.0 + (normDist * 2.5);
      canvas.drawLine(
        Offset(wheelRect.left + insetX, y),
        Offset(wheelRect.right - insetX, y),
        ridgeHighlightPaint,
      );
      canvas.drawLine(
        Offset(wheelRect.left + insetX, y + 1.8),
        Offset(wheelRect.right - insetX, y + 1.8),
        ridgeShadowPaint,
      );
    }

    // 3. Center gold index ring marker
    final centerBandPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withValues(alpha: isScrolling ? 0.22 : 0.10);
    canvas.drawRect(
      Rect.fromCenter(
        center: wheelRect.center,
        width: wheelRect.width,
        height: 14,
      ),
      centerBandPaint,
    );
    canvas.restore();

    // 4. Outer metallic rim border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isScrolling ? 1.5 : 1.1
      ..color = isScrolling
          ? accentColor
          : accentColor.withValues(alpha: 0.48);
    canvas.drawRRect(wheelRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TactileScrollWheelPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.isScrolling != isScrolling;
  }
}
