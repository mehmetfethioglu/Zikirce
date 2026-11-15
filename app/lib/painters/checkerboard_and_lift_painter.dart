import 'package:flutter/material.dart';

import '../constants/camera_colors.dart';
import '../models/inspector_colorimetry.dart';

/// Crisp dark-slate checkerboard painter visualizing 100% transparent PNG sticker alpha.
class TransparencyCheckerboardPainter extends CustomPainter {
  final double tileSize;
  final Color lightColor;
  final Color darkColor;

  const TransparencyCheckerboardPainter({
    this.tileSize = 12.0,
    this.lightColor = const Color(0xFF262D3D),
    this.darkColor = const Color(0xFF1A1F2B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || tileSize <= 0) return;
    final darkPaint = Paint()..color = darkColor;
    final lightPaint = Paint()..color = lightColor;
    canvas.drawRect(Offset.zero & size, darkPaint);

    final cols = (size.width / tileSize).ceil();
    final rows = (size.height / tileSize).ceil();
    for (var r = 0; r < rows; r++) {
      final y = r * tileSize;
      for (var c = 0; c < cols; c++) {
        if (((r + c) & 1) == 0) continue;
        final x = c * tileSize;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TransparencyCheckerboardPainter oldDelegate) {
    return oldDelegate.tileSize != tileSize ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.darkColor != darkColor;
  }
}

/// Animated luminous Subject Lift pulse anchored at [focusNorm] inside [imageRect].
class SubjectLiftGlowPainter extends CustomPainter {
  final Rect imageRect;
  final Offset focusNorm;
  final double progress;

  const SubjectLiftGlowPainter({
    required this.imageRect,
    required this.focusNorm,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || imageRect.isEmpty) return;
    final center = mapNormalizedImagePointToCanvasOffset(
      focusNorm: focusNorm,
      imageRect: imageRect,
    );
    final t = progress.clamp(0.0, 1.0);
    final baseR = (imageRect.shortestSide * 0.10).clamp(24.0, 64.0);
    final outerR = baseR * (0.75 + 1.45 * t);
    final innerR = baseR * (0.55 + 0.50 * t);
    final alpha = (1.0 - t * 0.28).clamp(0.0, 1.0);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          kIosYellow.withValues(alpha: 0.44 * alpha),
          kZameraCyan.withValues(alpha: 0.24 * alpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
    canvas.drawCircle(center, outerR, haloPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = kIosYellow.withValues(alpha: 0.90 * alpha);
    canvas.drawCircle(center, innerR, ringPaint);

    final scanRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = kZameraCyan.withValues(alpha: 0.72 * alpha);
    canvas.drawCircle(center, outerR * 0.88, scanRingPaint);
  }

  @override
  bool shouldRepaint(covariant SubjectLiftGlowPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.focusNorm != focusNorm ||
        oldDelegate.progress != progress;
  }
}

/// Multi-channel RGB + Luminance histogram curve painter with optional fallback 32-bin RAW curve.
class MultiChannelHistogramPainter extends CustomPainter {
  final RgbHistogramData? rgbHistogram;
  final List<double>? fallbackLumaBins;

  const MultiChannelHistogramPainter({
    this.rgbHistogram,
    this.fallbackLumaBins,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 3; i++) {
      final x = size.width * (i / 4.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var j = 1; j <= 2; j++) {
      final y = size.height * (j / 3.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final rgb = rgbHistogram;
    if (rgb != null && !rgb.isEmpty) {
      _drawCurve(canvas, size, rgb.redBins, const Color(0xFFFF453A), 0.22);
      _drawCurve(canvas, size, rgb.greenBins, const Color(0xFF32D74B), 0.20);
      _drawCurve(canvas, size, rgb.blueBins, const Color(0xFF0A84FF), 0.22);
      _drawCurve(canvas, size, rgb.lumaBins, Colors.white, 0.14);
      return;
    }

    final fallback = fallbackLumaBins;
    if (fallback != null && fallback.isNotEmpty) {
      var maxVal = 1e-5;
      for (final v in fallback) {
        if (v > maxVal) maxVal = v;
      }
      final norm = fallback
          .map((v) => (v / maxVal).clamp(0.0, 1.0))
          .toList(growable: false);
      _drawCurve(canvas, size, norm, kZameraCyan, 0.28);
    }
  }

  void _drawCurve(
    Canvas canvas,
    Size size,
    List<double> bins,
    Color color,
    double fillAlpha,
  ) {
    if (bins.length < 2) return;
    final fillPath = Path()..moveTo(0, size.height);
    final strokePath = Path();
    final stepX = size.width / (bins.length - 1);

    for (var i = 0; i < bins.length; i++) {
      final x = i * stepX;
      final norm = bins[i].clamp(0.0, 1.0);
      final y = size.height - norm * (size.height - 4.0);
      if (i == 0) {
        strokePath.moveTo(x, y);
      } else {
        strokePath.lineTo(x, y);
      }
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35,
    );
  }

  @override
  bool shouldRepaint(covariant MultiChannelHistogramPainter oldDelegate) {
    return oldDelegate.rgbHistogram != rgbHistogram ||
        oldDelegate.fallbackLumaBins != fallbackLumaBins;
  }
}
