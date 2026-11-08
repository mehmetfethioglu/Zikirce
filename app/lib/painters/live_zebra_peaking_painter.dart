import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// Real-Time Sensor Overexposure Zebra Stripes, 6-Band IRE False Color & Focus Peaking.
class LiveZebraAndPeakingOverlayPainter extends CustomPainter {
  const LiveZebraAndPeakingOverlayPainter({
    required this.showZebra,
    required this.showZebra70,
    required this.showFalseColor,
    required this.showFocusPeaking,
    required this.zebraGrid16x12,
    required this.peakingGrid16x12,
    required this.falseColorGrid16x12,
    required this.zebraRatio,
    required this.zebra70Ratio,
    required this.peakingScore,
  });

  final bool showZebra;
  final bool showZebra70;
  final bool showFalseColor;
  final bool showFocusPeaking;
  final List<double> zebraGrid16x12;
  final List<double> peakingGrid16x12;
  final List<int> falseColorGrid16x12;
  final double zebraRatio;
  final double zebra70Ratio;
  final double peakingScore;

  static Color _falseColorForBand(int band) {
    switch (band) {
      case 0:
        return const Color(0xFFBF5AF2); // Deep shadow (<10% IRE)
      case 1:
        return const Color(0xFF0A84FF); // Near-black / cool shadow (10-20% IRE)
      case 2:
        return const Color(0xFF30D158); // 18% Middle grey (38-46% IRE)
      case 3:
        return const Color(0xFFFF9F0A); // Skin tone highlight (65-75% IRE)
      case 4:
        return const Color(0xFFFFD60A); // Shoulder (85-94% IRE)
      case 5:
        return const Color(0xFFFF453A); // Clipped (>=95% IRE)
      default:
        return Colors.transparent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const topFrameY = 52.0;
    final bottomFrameY =
        (size.height - 135.0).clamp(topFrameY + 100.0, size.height);
    final frameH = bottomFrameY - topFrameY;
    const cols = 12;
    const rows = 16;
    final cellW = size.width / cols;
    final cellH = frameH / rows;

    // 0. 6-Band IRE False Color Exposure Map
    if (showFalseColor && falseColorGrid16x12.length == cols * rows) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final band = falseColorGrid16x12[r * cols + c];
          final color = _falseColorForBand(band);
          if (color == Colors.transparent) continue;
          final rect = Rect.fromLTWH(
            c * cellW,
            topFrameY + r * cellH,
            cellW,
            cellH,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = color.withValues(alpha: 0.28)
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

    // 1. Live Zebra Overexposure Stripes
    if ((showZebra || showZebra70) && zebraGrid16x12.length == cols * rows) {
      final zebraStroke = Paint()
        ..color = (showZebra ? const Color(0xFFFF453A) : kIosYellow)
            .withValues(alpha: 0.72)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      final zebraFill = Paint()
        ..color = kIosYellow.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final ratio = zebraGrid16x12[r * cols + c];
          final band = falseColorGrid16x12.length == cols * rows
              ? falseColorGrid16x12[r * cols + c]
              : -1;
          final isSkinZebraCell = showZebra70 && (band == 3 || zebra70Ratio > 0.08);
          if (ratio < 0.04 && !isSkinZebraCell) continue;
          final left = c * cellW;
          final top = topFrameY + r * cellH;
          final rect = Rect.fromLTWH(left, top, cellW, cellH);
          canvas.drawRect(rect, zebraFill);
          canvas.save();
          canvas.clipRect(rect);
          const step = 6.0;
          for (double d = -cellH; d < cellW + cellH; d += step) {
            canvas.drawLine(
              Offset(left + d, top + cellH),
              Offset(left + d + cellH, top),
              zebraStroke,
            );
          }
          canvas.restore();
        }
      }
    }

    // 2. Live Sobel Edge Focus Peaking Highlights
    if (showFocusPeaking && peakingGrid16x12.length == cols * rows) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final score = peakingGrid16x12[r * cols + c];
          if (score < 0.22) continue;
          final alpha = ((score - 0.20) * 1.1).clamp(0.18, 0.82);
          final left = c * cellW;
          final top = topFrameY + r * cellH;
          final cx = left + cellW * 0.5;
          final cy = top + cellH * 0.5;
          final peakPaint = Paint()
            ..color = (score > 0.45 ? kIosYellow : kZameraCyan)
                .withValues(alpha: alpha)
            ..strokeWidth = score > 0.45 ? 1.8 : 1.3
            ..style = PaintingStyle.stroke;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(cx, cy),
                width: cellW * 0.72,
                height: cellH * 0.72,
              ),
              const Radius.circular(4),
            ),
            peakPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LiveZebraAndPeakingOverlayPainter oldDelegate) =>
      oldDelegate.showZebra != showZebra ||
      oldDelegate.showZebra70 != showZebra70 ||
      oldDelegate.showFalseColor != showFalseColor ||
      oldDelegate.showFocusPeaking != showFocusPeaking ||
      oldDelegate.zebraRatio != zebraRatio ||
      oldDelegate.zebra70Ratio != zebra70Ratio ||
      oldDelegate.peakingScore != peakingScore ||
      oldDelegate.zebraGrid16x12 != zebraGrid16x12 ||
      oldDelegate.peakingGrid16x12 != peakingGrid16x12 ||
      oldDelegate.falseColorGrid16x12 != falseColorGrid16x12;
}
