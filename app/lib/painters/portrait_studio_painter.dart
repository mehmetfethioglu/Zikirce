import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// CustomPainter for rendering live portrait studio frame, lighting presets, and focus box.
class PortraitStudioFramePainter extends CustomPainter {
  const PortraitStudioFramePainter({
    required this.focusNorm,
    required this.aperture,
    required this.lightingIndex,
    required this.lightIntensity,
    required this.subjectRadiusRatio,
    required this.zoomFactor,
    required this.subjectDetectionLabel,
  });

  final Offset focusNorm;
  final double aperture;
  final int lightingIndex;
  final double lightIntensity;
  final double subjectRadiusRatio;
  final double zoomFactor;
  final String subjectDetectionLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * focusNorm.dx;
    final cy = size.height * focusNorm.dy;
    final minDim = math.min(size.width, size.height);
    final subjectR = minDim * subjectRadiusRatio;
    final intensity = lightIntensity.clamp(0.0, 1.0);

    // 1. Live preview of Studio / Contour / Stage / High-Key lighting
    final rect = Offset.zero & size;
    if (lightingIndex == 1 || lightingIndex == 2) {
      final vigAlpha =
          ((lightingIndex == 1 ? 0.28 : 0.52) * intensity).clamp(0.0, 0.78);
      final vigPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (focusNorm.dx - 0.5) * 2.0,
            (focusNorm.dy - 0.5) * 2.0,
          ),
          radius: subjectRadiusRatio * 2.1,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: vigAlpha * 0.35),
            Colors.black.withValues(alpha: vigAlpha),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, vigPaint);
    } else if (lightingIndex == 3 || lightingIndex == 4) {
      final stageAlpha = (0.92 * intensity).clamp(0.0, 0.96);
      final stagePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (focusNorm.dx - 0.5) * 2.0,
            (focusNorm.dy - 0.5) * 2.0,
          ),
          radius: subjectRadiusRatio * 1.65,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: stageAlpha * 0.65),
            Colors.black.withValues(alpha: stageAlpha),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, stagePaint);

      canvas.drawCircle(
        Offset(cx, cy),
        subjectR * 0.84,
        Paint()
          ..color = kIosYellow.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    } else if (lightingIndex == 5) {
      final hkAlpha = (0.90 * intensity).clamp(0.0, 0.96);
      final hkPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (focusNorm.dx - 0.5) * 2.0,
            (focusNorm.dy - 0.5) * 2.0,
          ),
          radius: subjectRadiusRatio * 1.68,
          colors: [
            Colors.transparent,
            const Color(0xFFF6F6F8).withValues(alpha: hkAlpha * 0.62),
            const Color(0xFFF6F6F8).withValues(alpha: hkAlpha),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, hkPaint);

      canvas.drawCircle(
        Offset(cx, cy),
        subjectR * 0.84,
        Paint()
          ..color = kIosYellow.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    } else if (lightingIndex == 6 || lightingIndex == 7) {
      final blindAlpha = (0.64 * intensity).clamp(0.18, 0.76);
      canvas.save();
      canvas.clipRect(rect);
      canvas.translate(cx, cy);
      canvas.rotate(-28.0 * math.pi / 180.0);
      final diag = math.sqrt(size.width * size.width + size.height * size.height);
      final slatPeriod = (minDim * 0.085).clamp(24.0, 42.0);
      final slatDarkH = slatPeriod * 0.48;
      final slatPaint = Paint()
        ..color = Colors.black.withValues(alpha: blindAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5);

      for (double yPos = -diag; yPos <= diag; yPos += slatPeriod) {
        canvas.drawRect(
          Rect.fromLTWH(-diag, yPos, diag * 2.0, slatDarkH),
          slatPaint,
        );
      }
      if (lightingIndex == 6) {
        final warmPaint = Paint()
          ..color = const Color(0xFFFFB74D).withValues(alpha: 0.14 * intensity);
        canvas.drawRect(
          Rect.fromLTWH(-diag, -diag, diag * 2.0, diag * 2.0),
          warmPaint,
        );
      }
      canvas.restore();
    } else if (lightingIndex == 8) {
      final goldAlpha = (0.38 * intensity).clamp(0.10, 0.52);
      final goldPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB300).withValues(alpha: goldAlpha),
            const Color(0xFFFF6F00).withValues(alpha: goldAlpha * 0.45),
            Colors.black.withValues(alpha: goldAlpha * 0.65),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, goldPaint);
    } else if (lightingIndex == 9) {
      final prismAlpha = (0.42 * intensity).clamp(0.12, 0.56);
      final prismPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: prismAlpha * 0.72),
            Colors.transparent,
            const Color(0xFFFF9100).withValues(alpha: prismAlpha * 0.78),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, prismPaint);
    }

    // 2. iOS Portrait Yellow Subject Focus Box
    final boxSide = (subjectR * 0.92).clamp(84.0, 148.0);
    final boxRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxSide,
      height: boxSide,
    );
    final boxPaint = Paint()
      ..color = kIosYellow.withValues(alpha: 0.90)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(boxRect, boxPaint);
    const tickLen = 6.5;
    canvas.drawLine(
      Offset(boxRect.center.dx, boxRect.top),
      Offset(boxRect.center.dx, boxRect.top + tickLen),
      boxPaint,
    );
    canvas.drawLine(
      Offset(boxRect.center.dx, boxRect.bottom - tickLen),
      Offset(boxRect.center.dx, boxRect.bottom),
      boxPaint,
    );
    canvas.drawLine(
      Offset(boxRect.left, boxRect.center.dy),
      Offset(boxRect.left + tickLen, boxRect.center.dy),
      boxPaint,
    );
    canvas.drawLine(
      Offset(boxRect.right - tickLen, boxRect.center.dy),
      Offset(boxRect.right, boxRect.center.dy),
      boxPaint,
    );

    // 3. Subject Detection Status Pill
    final tp = TextPainter(
      text: TextSpan(
        text: subjectDetectionLabel,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: kIosYellow,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = Rect.fromCenter(
      center: Offset(
        cx,
        (boxRect.top - 12.0).clamp(58.0, size.height - 220.0),
      ),
      width: tp.width + 12.0,
      height: tp.height + 4.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(6)),
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );
    tp.paint(canvas, Offset(pillRect.left + 6.0, pillRect.top + 2.0));
  }

  @override
  bool shouldRepaint(covariant PortraitStudioFramePainter oldDelegate) =>
      oldDelegate.focusNorm != focusNorm ||
      oldDelegate.aperture != aperture ||
      oldDelegate.lightingIndex != lightingIndex ||
      oldDelegate.lightIntensity != lightIntensity ||
      oldDelegate.subjectRadiusRatio != subjectRadiusRatio ||
      oldDelegate.zoomFactor != zoomFactor ||
      oldDelegate.subjectDetectionLabel != subjectDetectionLabel;
}
