import 'package:flutter/material.dart';

/// Kilerce brand emblem in quiet-luxury emerald-obsidian, champagne-gold,
/// and warm terracotta tones:
/// - Deep emerald-obsidian backdrop with a warm champagne-gold top-right glow
/// - Rounded ivory Menu Card with 3 gold menu lines & 3 emerald check dots
/// - Front-center warm Terracotta & Gold-banded serving bowl
/// - Twin graceful steam ribbons arching into a heart/pulse cradle around a
///   luminous Emerald Health Leaf with white heartbeat line & sparkle accents
class KilerceLogoMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const KilerceLogoMark({
    super.key,
    this.size = 38,
    this.borderRadius = 11,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          size: Size.square(size),
          painter: const _KilerceLogoPainter(),
        ),
      ),
    );
  }
}

class _KilerceLogoPainter extends CustomPainter {
  const _KilerceLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 1. Deep Emerald-Obsidian Luxury Background (#0B241C -> #163F31)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFF0B241C),
          Color(0xFF103126),
          Color(0xFF163F31),
        ],
        stops: [0.0, 0.50, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Top-Right Soft Champagne-Gold Ambient Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.60, -0.64),
        radius: 0.88,
        colors: [
          const Color(0xFFEAD098).withValues(alpha: 0.30),
          const Color(0xFFD99B26).withValues(alpha: 0.11),
          const Color(0xFF0B241C).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    final goldShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFF8E4),
        Color(0xFFE8C67D),
        Color(0xFFB9832E),
      ],
      stops: [0.0, 0.50, 1.0],
    ).createShader(rect);

    // 3. Back-Left-Center Rounded Ivory Menu Card
    final menuRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.165, h * 0.270, w * 0.370, h * 0.420),
      Radius.circular(w * 0.060),
    );
    canvas.drawRRect(
      menuRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFDF8),
            Color(0xFFF5EAD5),
            Color(0xFFE6D5B6),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      menuRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..color = const Color(0xFFDEC592).withValues(alpha: 0.72),
    );

    // 3 Emerald Check Dots + 3 Gold Menu Lines
    const rowYs = [0.365, 0.435, 0.505];
    const lineWidths = [0.195, 0.165, 0.135];
    const dotColors = [
      Color(0xFF10B981),
      Color(0xFF10B981),
      Color(0xFF059669),
    ];
    for (var i = 0; i < 3; i++) {
      final cy = h * rowYs[i];
      canvas.drawCircle(
        Offset(w * 0.235, cy),
        w * 0.021,
        Paint()..color = dotColors[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * 0.280,
            cy - h * 0.011,
            w * lineWidths[i],
            h * 0.022,
          ),
          Radius.circular(w * 0.011),
        ),
        Paint()..shader = goldShader,
      );
    }

    // 4. Front-Center Warm Terracotta & Gold-Banded Bowl
    // Pedestal Foot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.440, h * 0.785, w * 0.180, h * 0.050),
        Radius.circular(w * 0.022),
      ),
      Paint()..color = const Color(0xFF8C3A16),
    );

    // Bowl Body
    final bowlPath = Path()
      ..moveTo(w * 0.250, h * 0.570)
      ..cubicTo(
        w * 0.250,
        h * 0.730,
        w * 0.370,
        h * 0.805,
        w * 0.530,
        h * 0.805,
      )
      ..cubicTo(
        w * 0.690,
        h * 0.805,
        w * 0.810,
        h * 0.730,
        w * 0.810,
        h * 0.570,
      )
      ..close();
    canvas.drawPath(
      bowlPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEA9B59),
            Color(0xFFCD6A33),
            Color(0xFF8D3A17),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Decorative Curved Gold Band on Bowl Belly
    final bandPath = Path()
      ..moveTo(w * 0.272, h * 0.648)
      ..quadraticBezierTo(w * 0.530, h * 0.735, w * 0.788, h * 0.648);
    canvas.drawPath(
      bandPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.026
        ..strokeCap = StrokeCap.round
        ..shader = goldShader,
    );

    // Bowl Rim Interior & Champagne-Gold Rim Stroke
    final rimRect = Rect.fromCenter(
      center: Offset(w * 0.530, h * 0.570),
      width: w * 0.560,
      height: h * 0.088,
    );
    canvas.drawOval(
      rimRect,
      Paint()..color = const Color(0xFF24120B),
    );
    canvas.drawOval(
      rimRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..shader = goldShader,
    );

    // 5. Twin Graceful Heart/Pulse Steam Ribbons Rising from the Bowl
    final steamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0xD8E8C67D),
          Color(0xF2FFF8E7),
        ],
      ).createShader(rect);

    final leftSteam = Path()
      ..moveTo(w * 0.455, h * 0.555)
      ..cubicTo(
        w * 0.365,
        h * 0.485,
        w * 0.365,
        h * 0.355,
        w * 0.465,
        h * 0.295,
      )
      ..quadraticBezierTo(w * 0.495, h * 0.275, w * 0.520, h * 0.292);
    canvas.drawPath(leftSteam, steamPaint);

    final rightSteam = Path()
      ..moveTo(w * 0.615, h * 0.555)
      ..cubicTo(
        w * 0.735,
        h * 0.485,
        w * 0.775,
        h * 0.370,
        w * 0.705,
        h * 0.300,
      )
      ..quadraticBezierTo(w * 0.678, h * 0.278, w * 0.655, h * 0.295);
    canvas.drawPath(rightSteam, steamPaint);

    // 6. Luminous Central-Top Emerald Health Leaf
    final leafPath = Path()
      ..moveTo(w * 0.550, h * 0.445)
      ..cubicTo(
        w * 0.470,
        h * 0.345,
        w * 0.505,
        h * 0.195,
        w * 0.695,
        h * 0.160,
      )
      ..cubicTo(
        w * 0.735,
        h * 0.315,
        w * 0.665,
        h * 0.425,
        w * 0.550,
        h * 0.445,
      )
      ..close();
    canvas.drawPath(
      leafPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFF047857),
            Color(0xFF10B981),
            Color(0xFF34D399),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      leafPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..color = const Color(0xFFA7F3D0).withValues(alpha: 0.72),
    );

    // White Heartbeat / Pulse Line inside Leaf
    final pulsePath = Path()
      ..moveTo(w * 0.515, h * 0.320)
      ..lineTo(w * 0.555, h * 0.320)
      ..lineTo(w * 0.580, h * 0.252)
      ..lineTo(w * 0.610, h * 0.365)
      ..lineTo(w * 0.635, h * 0.285)
      ..lineTo(w * 0.655, h * 0.312)
      ..lineTo(w * 0.690, h * 0.312);
    canvas.drawPath(
      pulsePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.023
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    // Sparkle / Parıltı Accents
    _drawFourPointSparkle(
      canvas,
      Offset(w * 0.765, h * 0.195),
      w * 0.046,
      const Color(0xFFFFFDF4),
    );
    _drawFourPointSparkle(
      canvas,
      Offset(w * 0.515, h * 0.185),
      w * 0.025,
      const Color(0xFFF6DBA0),
    );
    canvas.drawCircle(
      Offset(w * 0.805, h * 0.265),
      w * 0.015,
      Paint()..color = const Color(0xFFF6DBA0),
    );
  }

  void _drawFourPointSparkle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final inner = radius * 0.28;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + inner * 0.45,
        center.dy - inner * 0.45,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + inner * 0.45,
        center.dy + inner * 0.45,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - inner * 0.45,
        center.dy + inner * 0.45,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - inner * 0.45,
        center.dy - inner * 0.45,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
