import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Zikirce 8-halkalı Selçuklu & İslam geometrik motifine sahip özel Ayet Durak Gülü
class ZikirceAyahStopMarker extends StatelessWidget {
  final String number;
  final bool isDark;
  final bool isHighlight;
  final String fontFamily;
  final double size;

  const ZikirceAyahStopMarker({
    super.key,
    required this.number,
    required this.isDark,
    required this.isHighlight,
    required this.fontFamily,
    this.size = 26.0,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic emerald & gold palette
    final emeraldPrimary = isHighlight
        ? const Color(0xFFD4AF37)
        : (isDark ? const Color(0xFF135B47) : const Color(0xFF0F4335));
    final emeraldSecondary = isHighlight
        ? const Color(0xFFFFD54F)
        : (isDark ? const Color(0xFF082E24) : const Color(0xFF072B21));
    final goldBorder = isHighlight
        ? const Color(0xFFFFE082)
        : (isDark ? const Color(0xFFD4AF37) : const Color(0xFFC5A358));
    final textColor = isHighlight
        ? const Color(0xFF452B00)
        : (isDark ? const Color(0xFFFFF8E7) : const Color(0xFFFFFDF8));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ZikirceEightRingRosettePainter(
          primaryColor: emeraldPrimary,
          secondaryColor: emeraldSecondary,
          goldBorderColor: goldBorder,
          isHighlight: isHighlight,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: size * 0.44,
                color: textColor,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZikirceEightRingRosettePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color goldBorderColor;
  final bool isHighlight;

  _ZikirceEightRingRosettePainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.goldBorderColor,
    required this.isHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Glowing aura if highlighted
    if (isHighlight) {
      final glowPaint = Paint()
        ..color = goldBorderColor.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, radius * 0.9, glowPaint);
    }

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, secondaryColor],
        center: Alignment.center,
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = goldBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlight ? 1.4 : 1.0;

    // Construct 8-lobed Islamic Rosette Path (8 Petal circles radiating around center)
    const int lobes = 8;
    final double lobeDistance = radius * 0.58;
    final double lobeRadius = radius * 0.38;

    for (int i = 0; i < lobes; i++) {
      final double angle = (i * 2 * math.pi) / lobes;
      final double cx = center.dx + lobeDistance * math.cos(angle);
      final double cy = center.dy + lobeDistance * math.sin(angle);

      canvas.drawCircle(Offset(cx, cy), lobeRadius, fillPaint);
      canvas.drawCircle(Offset(cx, cy), lobeRadius, borderPaint);
    }

    // Central core disc
    final coreRadius = radius * 0.68;
    canvas.drawCircle(center, coreRadius, fillPaint);

    // Inner gold ring
    final innerRingPaint = Paint()
      ..color = goldBorderColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, coreRadius, innerRingPaint);

    // Subtle 8 inner mini gold dots on petal roots
    final dotPaint = Paint()
      ..color = goldBorderColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final double dotDistance = radius * 0.72;
    for (int i = 0; i < lobes; i++) {
      final double angle = (i * 2 * math.pi) / lobes + (math.pi / lobes);
      final double dx = center.dx + dotDistance * math.cos(angle);
      final double dy = center.dy + dotDistance * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 0.7, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZikirceEightRingRosettePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.goldBorderColor != goldBorderColor ||
        oldDelegate.isHighlight != isHighlight;
  }
}
