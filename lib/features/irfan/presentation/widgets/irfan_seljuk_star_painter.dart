import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Selçuklu 8 Köşeli İrfan Yıldızı & Kündekârî Rozet Çizicisi (120 FPS CustomPainter).
class IrfanSeljukStarPainter extends CustomPainter {
  final Color color;
  final Color? accentColor;
  final double strokeWidth;
  final bool filled;
  final bool showInnerRosette;
  final double rotation;

  const IrfanSeljukStarPainter({
    required this.color,
    this.accentColor,
    this.strokeWidth = 1.4,
    this.filled = false,
    this.showInnerRosette = true,
    this.rotation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double shortest = math.min(size.width, size.height);
    if (shortest <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = shortest * 0.46;
    final double innerNotchRadius = outerRadius * 0.742;

    canvas.save();
    if (rotation != 0.0) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    final Path starPath = _buildEightPointStarPath(
      center: center,
      outerR: outerRadius,
      innerR: innerNotchRadius,
    );

    if (filled) {
      final Paint fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = color.withValues(alpha: 0.14);
      canvas.drawPath(starPath, fillPaint);
    }

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true
      ..color = color;
    canvas.drawPath(starPath, strokePaint);

    if (showInnerRosette) {
      final Color secondary = accentColor ?? color;
      final Path innerStar = _buildEightPointStarPath(
        center: center,
        outerR: outerRadius * 0.62,
        innerR: innerNotchRadius * 0.62,
      );
      final Paint innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, strokeWidth * 0.72)
        ..isAntiAlias = true
        ..color = secondary.withValues(alpha: 0.68);
      canvas.drawPath(innerStar, innerPaint);

      // Merkezde 4 kollu Nur kıvılcımı
      final Path nurSpark = _buildFourRayNurPath(
        center: center,
        outerR: outerRadius * 0.28,
        waistR: outerRadius * 0.09,
      );
      final Paint nurPaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = secondary;
      canvas.drawPath(nurSpark, nurPaint);
    }

    canvas.restore();
  }

  Path _buildEightPointStarPath({
    required Offset center,
    required double outerR,
    required double innerR,
  }) {
    final Path path = Path();
    const int totalVertices = 16;
    const double step = (2 * math.pi) / totalVertices;
    const double startAngle = -math.pi / 2;

    for (int i = 0; i < totalVertices; i++) {
      final double r = i.isEven ? outerR : innerR;
      final double angle = startAngle + (i * step);
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _buildFourRayNurPath({
    required Offset center,
    required double outerR,
    required double waistR,
  }) {
    final Path path = Path();
    const int vertices = 8;
    const double step = (2 * math.pi) / vertices;
    const double startAngle = -math.pi / 2;

    for (int i = 0; i < vertices; i++) {
      final double r = i.isEven ? outerR : waistR;
      final double angle = startAngle + (i * step);
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant IrfanSeljukStarPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled ||
        oldDelegate.showInnerRosette != showInnerRosette ||
        oldDelegate.rotation != rotation;
  }
}

/// Atomik `const` Selçuklu Yıldızı rozet bileşeni.
class IrfanSeljukStarBadge extends StatelessWidget {
  final double size;
  final Color color;
  final Color? accentColor;
  final double strokeWidth;
  final bool filled;
  final bool showInnerRosette;

  const IrfanSeljukStarBadge({
    super.key,
    this.size = 36,
    required this.color,
    this.accentColor,
    this.strokeWidth = 1.4,
    this.filled = true,
    this.showInnerRosette = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: IrfanSeljukStarPainter(
          color: color,
          accentColor: accentColor,
          strokeWidth: strokeWidth,
          filled: filled,
          showInnerRosette: showInnerRosette,
        ),
      ),
    );
  }
}
