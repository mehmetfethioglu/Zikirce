import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// CustomPainter for rendering crystal-clear live iPhone-style Portrait studio HUD:
/// - Zero RadialGradient fog clouds (100% optically clear viewfinder)
/// - Iconic iPhone Portrait yellow corner-bracket focus reticle
/// - Top iPhone-style yellow/dark Studio Lighting & Aperture capsule
/// - Optional distance guidance capsule ("Daha uzağa gidin" / "Nesneyi 2.5 m yakına yerleştirin")
class PortraitStudioFramePainter extends CustomPainter {
  const PortraitStudioFramePainter({
    required this.focusNorm,
    required this.aperture,
    required this.lightingIndex,
    required this.lightIntensity,
    required this.subjectRadiusRatio,
    required this.zoomFactor,
    required this.subjectDetectionLabel,
    this.distanceWarning,
  });

  static const List<String> kLightingLabels = [
    'DOĞAL IŞIK',
    'STÜDYO IŞIĞI',
    'KONTUR IŞIĞI',
    'SAHNE IŞIĞI',
    'SAHNE MONO',
    'YÜKSEK ANAHTAR MONO',
    'PANJUR GÖLGESİ',
    'PANJUR MONO',
    'ALTIN SAAT',
    'PRİZMA & SİNEMA',
  ];

  final Offset focusNorm;
  final double aperture;
  final int lightingIndex;
  final double lightIntensity;
  final double subjectRadiusRatio;
  final double zoomFactor;
  final String subjectDetectionLabel;
  final String? distanceWarning;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final minDim = math.min(size.width, size.height);
    final subjectR = minDim * subjectRadiusRatio.clamp(0.18, 0.65);
    final boxSide = (subjectR * 0.94).clamp(88.0, 152.0);
    final halfBox = boxSide * 0.5;
    final cx = (size.width * focusNorm.dx)
        .clamp(
          halfBox + 12.0,
          math.max(halfBox + 12.0, size.width - halfBox - 12.0),
        )
        .toDouble();
    final cy = (size.height * focusNorm.dy)
        .clamp(
          math.max(halfBox + 112.0, 140.0),
          math.max(140.0, size.height - halfBox - 136.0),
        )
        .toDouble();
    final hasWarning =
        distanceWarning != null && distanceWarning!.trim().isNotEmpty;

    // 1. Stage / High-Key Backdrop Cutout Mask & Optical Alignment Ring
    if (lightingIndex >= 3 && lightingIndex <= 5) {
      final stageRadius = (subjectR * 0.86).clamp(64.0, minDim * 0.42);
      final stageCutoutPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(
          Rect.fromCircle(center: Offset(cx, cy), radius: stageRadius),
        );
      final clampedIntensity = lightIntensity.clamp(0.0, 1.0);
      final backdropColor = (lightingIndex == 3 || lightingIndex == 4)
          ? Colors.black.withValues(
              alpha: (0.42 + 0.30 * clampedIntensity).clamp(0.42, 0.72),
            )
          : const Color(0xFFF7F7F9).withValues(
              alpha: (0.40 + 0.28 * clampedIntensity).clamp(0.40, 0.68),
            );
      canvas.drawPath(stageCutoutPath, Paint()..color = backdropColor);

      final ringPaint = Paint()
        ..color = kIosYellow.withValues(alpha: hasWarning ? 0.40 : 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15;
      canvas.drawCircle(Offset(cx, cy), stageRadius, ringPaint);
    }

    // 2. Iconic iPhone Portrait Yellow Corner-Bracket Focus Reticle
    final boxRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxSide,
      height: boxSide,
    );
    final bracketLen = (boxSide * 0.22).clamp(16.0, 28.0);
    final reticleColor =
        hasWarning ? Colors.white.withValues(alpha: 0.82) : kIosYellow;

    final subtleFramePaint = Paint()
      ..color = reticleColor.withValues(alpha: 0.22)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    canvas.drawRect(boxRect, subtleFramePaint);

    final bracketPaint = Paint()
      ..color = reticleColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final cornersPath = Path()
      // Top-Left L-bracket
      ..moveTo(boxRect.left, boxRect.top + bracketLen)
      ..lineTo(boxRect.left, boxRect.top)
      ..lineTo(boxRect.left + bracketLen, boxRect.top)
      // Top-Right L-bracket
      ..moveTo(boxRect.right - bracketLen, boxRect.top)
      ..lineTo(boxRect.right, boxRect.top)
      ..lineTo(boxRect.right, boxRect.top + bracketLen)
      // Bottom-Right L-bracket
      ..moveTo(boxRect.right, boxRect.bottom - bracketLen)
      ..lineTo(boxRect.right, boxRect.bottom)
      ..lineTo(boxRect.right - bracketLen, boxRect.bottom)
      // Bottom-Left L-bracket
      ..moveTo(boxRect.left + bracketLen, boxRect.bottom)
      ..lineTo(boxRect.left, boxRect.bottom)
      ..lineTo(boxRect.left, boxRect.bottom - bracketLen);
    canvas.drawPath(cornersPath, bracketPaint);

    // Subtle iPhone mid-edge focus ticks
    const tickLen = 5.5;
    final tickPaint = Paint()
      ..color = reticleColor.withValues(alpha: 0.78)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(boxRect.center.dx, boxRect.top),
      Offset(boxRect.center.dx, boxRect.top + tickLen),
      tickPaint,
    );
    canvas.drawLine(
      Offset(boxRect.center.dx, boxRect.bottom - tickLen),
      Offset(boxRect.center.dx, boxRect.bottom),
      tickPaint,
    );
    canvas.drawLine(
      Offset(boxRect.left, boxRect.center.dy),
      Offset(boxRect.left + tickLen, boxRect.center.dy),
      tickPaint,
    );
    canvas.drawLine(
      Offset(boxRect.right - tickLen, boxRect.center.dy),
      Offset(boxRect.right, boxRect.center.dy),
      tickPaint,
    );

    // 3. Top iPhone-Style Yellow/Dark Studio Lighting Capsule
    final safeLightIdx = lightingIndex.clamp(0, kLightingLabels.length - 1);
    final intensityPct = (lightIntensity.clamp(0.0, 1.0) * 100).round();
    final studioText = safeLightIdx == 0
        ? '${kLightingLabels[0]} · ƒ ${aperture.toStringAsFixed(1)}'
        : '${kLightingLabels[safeLightIdx]} %$intensityPct · ƒ ${aperture.toStringAsFixed(1)}';

    final studioTp = TextPainter(
      text: TextSpan(
        text: studioText,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.55,
          color: hasWarning ? kIosYellow : Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(80.0, size.width - 32.0));

    final topPillCenterY = 58.0;
    final studioPillRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, topPillCenterY),
      width: studioTp.width + 20.0,
      height: studioTp.height + 8.0,
    );
    final studioPillRRect = RRect.fromRectAndRadius(
      studioPillRect,
      const Radius.circular(14),
    );

    if (hasWarning) {
      canvas.drawRRect(
        studioPillRRect,
        Paint()..color = const Color(0xBD12141A),
      );
      canvas.drawRRect(
        studioPillRRect,
        Paint()
          ..color = kIosYellow.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      canvas.drawRRect(
        studioPillRRect,
        Paint()..color = kIosYellow,
      );
    }
    studioTp.paint(
      canvas,
      Offset(studioPillRect.left + 10.0, studioPillRect.top + 4.0),
    );

    // 4. Optional iPhone Distance Guidance Capsule ("Daha uzağa gidin" / "Nesneyi 2.5 m yakına yerleştirin")
    if (hasWarning) {
      final warnTp = TextPainter(
        text: TextSpan(
          text: distanceWarning!,
          style: const TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(80.0, size.width - 40.0));

      final warnRect = Rect.fromCenter(
        center: Offset(size.width * 0.5, studioPillRect.bottom + 18.0),
        width: warnTp.width + 22.0,
        height: warnTp.height + 8.0,
      );
      final warnRRect = RRect.fromRectAndRadius(
        warnRect,
        const Radius.circular(8),
      );
      canvas.drawRRect(
        warnRRect,
        Paint()..color = Colors.black.withValues(alpha: 0.74),
      );
      canvas.drawRRect(
        warnRRect,
        Paint()
          ..color = kIosYellow.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      warnTp.paint(
        canvas,
        Offset(warnRect.left + 11.0, warnRect.top + 4.0),
      );
    }

    // 5. Subtle Subject Detection Micro-Badge Adjacent to Reticle
    if (subjectDetectionLabel.isNotEmpty) {
      final subjTp = TextPainter(
        text: TextSpan(
          text: subjectDetectionLabel,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
            color: kIosYellow,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(80.0, size.width - 32.0));

      final badgeCenterY = (boxRect.bottom + 14.0 <= size.height - 130.0)
          ? boxRect.bottom + 14.0
          : boxRect.top - 14.0;
      final subjRect = Rect.fromCenter(
        center: Offset(cx, badgeCenterY),
        width: subjTp.width + 12.0,
        height: subjTp.height + 4.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(subjRect, const Radius.circular(6)),
        Paint()..color = Colors.black.withValues(alpha: 0.56),
      );
      subjTp.paint(
        canvas,
        Offset(subjRect.left + 6.0, subjRect.top + 2.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PortraitStudioFramePainter oldDelegate) =>
      oldDelegate.focusNorm != focusNorm ||
      oldDelegate.aperture != aperture ||
      oldDelegate.lightingIndex != lightingIndex ||
      oldDelegate.lightIntensity != lightIntensity ||
      oldDelegate.subjectRadiusRatio != subjectRadiusRatio ||
      oldDelegate.zoomFactor != zoomFactor ||
      oldDelegate.subjectDetectionLabel != subjectDetectionLabel ||
      oldDelegate.distanceWarning != distanceWarning;
}
