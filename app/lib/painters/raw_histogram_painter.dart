import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// Real-time RAW luminance histogram bar chart.
class RawHistogramPainter extends CustomPainter {
  const RawHistogramPainter(this.bins);
  final List<double> bins;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;
    double maxVal = 1e-5;
    for (final v in bins) {
      if (v > maxVal) maxVal = v;
    }
    final barW = size.width / bins.length;
    for (int i = 0; i < bins.length; i++) {
      final norm = (bins[i] / maxVal).clamp(0.0, 1.0);
      final barH = norm * (size.height - 2);
      final isHighlightZone = i >= (bins.length * 0.90).floor();
      final paint = Paint()
        ..color = isHighlightZone
            ? kIosYellow
            : kZameraCyan.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          i * barW,
          size.height - barH,
          (barW - 1.0).clamp(1.0, barW),
          barH,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RawHistogramPainter oldDelegate) =>
      oldDelegate.bins != bins;
}
