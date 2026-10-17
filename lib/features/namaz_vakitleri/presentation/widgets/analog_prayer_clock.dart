import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../providers/prayer_providers.dart';

/// Zikirce Logo Rounded 8-Pointed Seljuk Star & Tesbih Analog Prayer Clock
/// Features:
/// - Light Theme: Pure white (#FFFFFF) background with Zikirce Deep Emerald & Gold palette
/// - Dark Theme: True OLED black (#000000) background with Zikirce Emerald & Gold palette
/// - Frame: Rounded 8-pointed Seljuk star (8 circular lobes) + draped Tesbih on upper-right lobe
/// - Dial: 12-3-6-9 numerals and clean tick lines for the remaining hours
/// - Countdown: Positioned outside the clock dial at the bottom of the widget
class AnalogPrayerClock extends ConsumerWidget {
  final PrayerTimings? timings;
  final double size;
  final bool? isDark;

  const AnalogPrayerClock({
    super.key,
    this.timings,
    this.size = 240,
    this.isDark,
  });

  static const List<Color> prayerColors = [
    Color(0xFF8B5CF6), // 0: İmsak
    Color(0xFFF59E0B), // 1: Güneş
    Color(0xFF10B981), // 2: Öğle
    Color(0xFF0EA5E9), // 3: İkindi
    Color(0xFFF97316), // 4: Akşam
    Color(0xFF6366F1), // 5: Yatsı
  ];

  static Color getPrayerThemeColor(int activeIndex) {
    if (activeIndex < 0 || activeIndex >= prayerColors.length) {
      return const Color(0xFFF59E0B);
    }
    return prayerColors[activeIndex];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(timeTickerStreamProvider).valueOrNull ?? DateTime.now();
    final effectiveIsDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final nextPrayer = ref.watch(nextPrayerInfoProvider);

    final prayerName = nextPrayer?.name ?? 'İmsak';
    final timerText = nextPrayer?.formattedRemaining ?? '00:00:00';
    final prayerTime = nextPrayer?.time ?? '05:07';

    return RepaintBoundary(
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            size: Size(size, size),
            painter: _ZikirceSeljukAnalogClockPainter(
              now: now,
              isDark: effectiveIsDark,
              prayerName: prayerName,
              timerText: timerText,
              prayerTime: prayerTime,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZikirceSeljukAnalogClockPainter extends CustomPainter {
  final DateTime now;
  final bool isDark;
  final String prayerName;
  final String timerText;
  final String prayerTime;

  _ZikirceSeljukAnalogClockPainter({
    required this.now,
    required this.isDark,
    required this.prayerName,
    required this.timerText,
    required this.prayerTime,
  });

  Path _buildRosettePath(Offset center, double scale, double rLobe) {
    final rc = 55.0 * scale;
    final rl = rLobe * scale;
    Path path = Path()..addOval(Rect.fromCircle(center: center, radius: rc));
    for (int k = 0; k < 8; k++) {
      final angle = k * math.pi / 4.0;
      final lobeCenter = Offset(
        center.dx + rc * math.cos(angle),
        center.dy + rc * math.sin(angle),
      );
      final circle = Path()
        ..addOval(Rect.fromCircle(center: lobeCenter, radius: rl));
      path = Path.combine(PathOperation.union, path, circle);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dim = math.min(size.width, size.height);
    final cardCenter = Offset(size.width / 2, size.height / 2);

    // 1. Zikirce Theme Palette
    // Outer card & bottom pill follow Light/Dark theme;
    // Inner clock medallion is ALWAYS filled with warm cream (#F1EACA) like the logo & light theme.
    final cardBgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final cardBorderColor = isDark ? const Color(0xFF222825) : const Color(0xFFE0EBE7);

    const dialBgColor = Color(0xFFF1EACA);
    final emeraldBorder = isDark ? const Color(0xFF1B5E45) : const Color(0xFF174D35);
    const goldPrimary = Color(0xFFC8A353);
    const goldHighlight = Color(0xFFE5C878);
    const hourDotColor = Color(0xFF174D35);
    const minuteTickColor = Color(0xFF9E7B32);

    const textPrimaryColor = Color(0xFF1E2B27);
    const textSecondaryColor = Color(0xFF236B56);

    final pillBgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F8F6);
    final pillBorderColor = isDark ? const Color(0x52D4AF37) : const Color(0xFFD8E5E1);
    final pillTextColor = isDark ? const Color(0xFFF7D15A) : const Color(0xFF1E2B27);

    // Canonical Zikirce Logo Brown Tesbih Palette
    const tesbihDarkColor = Color(0xFF442410);
    const tesbihMidColor = Color(0xFF62371A);
    const tesbihLightColor = Color(0xFF86522B);

    // 2. Outer Squircle Widget Card (Pure White in Light, True Black in Dark)
    final cardRect = Rect.fromCenter(center: cardCenter, width: dim - 1.5, height: dim - 1.5);
    final cardRRect = RRect.fromRectAndRadius(cardRect, Radius.circular(dim * 0.18));
    canvas.drawRRect(cardRRect, Paint()..color = cardBgColor);
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..color = cardBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Maximize clock size with minimal margin above the bottom countdown pill
    final bottomBarHeight = dim * 0.112;
    final topMargin = dim * 0.008;
    final bottomMargin = dim * 0.012;
    final clockAreaHeight = dim - bottomBarHeight - topMargin - bottomMargin;
    final clockCenter = Offset(size.width / 2, topMargin + clockAreaHeight / 2);
    // Outer rosette max radius is 55.0 + 42.8 = 97.8 (diameter 195.6); scale so 195.6 fills clockAreaHeight
    final scale = clockAreaHeight / 197.0;

    Offset pt(double x, double y) => Offset(
          clockCenter.dx + (x - 110.0) * scale,
          clockCenter.dy + (y - 110.0) * scale,
        );

    // 3. Exact ZikirceLogoPainter 3-Layer 8-Lobed Rosette Medallion
    final outerRosette = _buildRosettePath(clockCenter, scale, 42.8);
    final goldRosette = _buildRosettePath(clockCenter, scale, 32.5);
    final innerRosette = _buildRosettePath(clockCenter, scale, 25.5);

    canvas.drawPath(outerRosette, Paint()..color = emeraldBorder);
    canvas.drawPath(goldRosette, Paint()..color = goldPrimary);
    canvas.drawPath(innerRosette, Paint()..color = dialBgColor);
    canvas.drawPath(
      innerRosette,
      Paint()
        ..color = goldHighlight.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    // 4. Proportional Circular Chapter Ring:
    //    - Full hours (12, 1, 2, ..., 11) represented by dots at R = 58.5
    //    - 4 thin minute lines between every two adjacent hours at R = 57.1 .. 59.9
    final rTrack = 58.5 * scale;
    final rMinIn = 57.1 * scale;
    final rMinOut = 59.9 * scale;
    final hourDotRadius = 1.85 * scale;

    final minuteTickPaint = Paint()
      ..color = minuteTickColor
      ..strokeWidth = 0.95 * scale
      ..strokeCap = StrokeCap.round;

    final hourDotPaint = Paint()
      ..color = hourDotColor
      ..style = PaintingStyle.fill;

    for (int m = 0; m < 60; m++) {
      final angle = (m * 6.0 - 90.0) * (math.pi / 180.0);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      if (m % 5 == 0) {
        final dotCenter = Offset(
          clockCenter.dx + rTrack * cosA,
          clockCenter.dy + rTrack * sinA,
        );
        canvas.drawCircle(dotCenter, hourDotRadius, hourDotPaint);
      } else {
        final p1 = Offset(
          clockCenter.dx + rMinIn * cosA,
          clockCenter.dy + rMinIn * sinA,
        );
        final p2 = Offset(
          clockCenter.dx + rMinOut * cosA,
          clockCenter.dy + rMinOut * sinA,
        );
        canvas.drawLine(p1, p2, minuteTickPaint);
      }
    }

    // 5. Cardinal Numerals: 12 - 3 - 6 - 9 in the 4 cardinal lobes (R = 71.2)
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final numFontSize = (11.8 * scale).clamp(8.0, 16.0);
    final numStyle = TextStyle(
      color: textPrimaryColor,
      fontSize: numFontSize,
      fontWeight: FontWeight.w800,
    );
    final numRadius = 71.2 * scale;
    const cardinals = <int, String>{0: '12', 3: '3', 6: '6', 9: '9'};
    for (final entry in cardinals.entries) {
      final angle = (entry.key * 30.0 - 90.0) * (math.pi / 180.0);
      final pos = Offset(
        clockCenter.dx + numRadius * math.cos(angle),
        clockCenter.dy + numRadius * math.sin(angle),
      );
      textPainter.text = TextSpan(text: entry.value, style: numStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }

    // 6. Exact ZikirceLogoPainter Brown Tesbih:
    final strapPath = Path()
      ..moveTo(pt(147.2, 41.5).dx, pt(147.2, 41.5).dy)
      ..cubicTo(
        pt(148.5, 36.5).dx,
        pt(148.5, 36.5).dy,
        pt(152.0, 33.8).dx,
        pt(152.0, 33.8).dy,
        pt(156.2, 35.2).dx,
        pt(156.2, 35.2).dy,
      )
      ..cubicTo(
        pt(159.0, 36.2).dx,
        pt(159.0, 36.2).dy,
        pt(160.8, 38.8).dx,
        pt(160.8, 38.8).dy,
        pt(160.2, 40.5).dx,
        pt(160.2, 40.5).dy,
      )
      ..cubicTo(
        pt(157.5, 38.8).dx,
        pt(157.5, 38.8).dy,
        pt(154.5, 38.6).dx,
        pt(154.5, 38.6).dy,
        pt(152.2, 40.5).dx,
        pt(152.2, 40.5).dy,
      )
      ..cubicTo(
        pt(150.5, 41.8).dx,
        pt(150.5, 41.8).dy,
        pt(148.8, 43.2).dx,
        pt(148.8, 43.2).dy,
        pt(147.2, 41.5).dx,
        pt(147.2, 41.5).dy,
      )
      ..close();
    canvas.drawPath(strapPath, Paint()..color = tesbihDarkColor);

    final cordPath = Path()
      ..moveTo(pt(147.2, 43.0).dx, pt(147.2, 43.0).dy)
      ..cubicTo(
        pt(144.2, 53.0).dx,
        pt(144.2, 53.0).dy,
        pt(144.0, 67.0).dx,
        pt(144.0, 67.0).dy,
        pt(149.2, 78.5).dx,
        pt(149.2, 78.5).dy,
      )
      ..cubicTo(
        pt(153.2, 87.0).dx,
        pt(153.2, 87.0).dy,
        pt(159.5, 95.0).dx,
        pt(159.5, 95.0).dy,
        pt(165.0, 101.5).dx,
        pt(165.0, 101.5).dy,
      )
      ..moveTo(pt(181.5, 76.3).dx, pt(181.5, 76.3).dy)
      ..cubicTo(
        pt(180.5, 84.5).dx,
        pt(180.5, 84.5).dy,
        pt(175.0, 94.5).dx,
        pt(175.0, 94.5).dy,
        pt(165.0, 101.5).dx,
        pt(165.0, 101.5).dy,
      );
    canvas.drawPath(
      cordPath,
      Paint()
        ..color = tesbihDarkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round,
    );

    const beadCoords = <(double, double)>[
      (147.2, 43.0), (145.6, 48.6), (144.8, 54.5), (144.5, 60.5), (145.0, 66.5),
      (146.5, 72.6), (149.2, 78.5), (152.8, 84.2), (157.0, 89.6), (161.2, 95.0),
      (181.5, 76.3), (180.6, 82.2), (178.2, 88.0), (174.4, 93.4), (169.8, 97.8),
    ];
    final beadR = 2.85 * scale;
    final hiR = 0.85 * scale;
    final beadStrokePaint = Paint()
      ..color = tesbihDarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85 * scale;
    for (final (bx, by) in beadCoords) {
      final c = pt(bx, by);
      canvas.drawCircle(c, beadR, Paint()..color = tesbihMidColor);
      canvas.drawCircle(c, beadR, beadStrokePaint);
      canvas.drawCircle(
        Offset(c.dx - beadR * 0.28, c.dy - beadR * 0.28),
        hiR,
        Paint()..color = tesbihLightColor,
      );
    }

    // Knot Bead at (165.0, 101.5)
    final knotCenter = pt(165.0, 101.5);
    canvas.drawCircle(knotCenter, 3.1 * scale, Paint()..color = tesbihMidColor);
    canvas.drawCircle(knotCenter, 3.1 * scale, beadStrokePaint);
    canvas.drawCircle(
      Offset(knotCenter.dx - 0.85 * scale, knotCenter.dy - 0.85 * scale),
      hiR,
      Paint()..color = tesbihLightColor,
    );

    // Imame Body + Small Tip Bead (x=165.0, y=104.2..110.8)
    final imamePath = Path()
      ..moveTo(pt(163.8, 104.2).dx, pt(163.8, 104.2).dy)
      ..lineTo(pt(166.2, 104.2).dx, pt(166.2, 104.2).dy)
      ..cubicTo(
        pt(166.7, 106.5).dx,
        pt(166.7, 106.5).dy,
        pt(166.0, 108.8).dx,
        pt(166.0, 108.8).dy,
        pt(166.4, 110.2).dx,
        pt(166.4, 110.2).dy,
      )
      ..lineTo(pt(163.6, 110.2).dx, pt(163.6, 110.2).dy)
      ..cubicTo(
        pt(164.0, 108.8).dx,
        pt(164.0, 108.8).dy,
        pt(163.3, 106.5).dx,
        pt(163.3, 106.5).dy,
        pt(163.8, 104.2).dx,
        pt(163.8, 104.2).dy,
      )
      ..close();
    canvas.drawPath(imamePath, Paint()..color = tesbihMidColor);
    canvas.drawPath(imamePath, beadStrokePaint);

    final tipCenter = pt(165.0, 110.6);
    canvas.drawCircle(tipCenter, 1.75 * scale, Paint()..color = tesbihMidColor);
    canvas.drawCircle(tipCenter, 1.75 * scale, beadStrokePaint);

    // Tassel (Püskül) at x=161.0..169.0, y=111.8..124.2
    final tasselPath = Path()
      ..moveTo(pt(164.0, 111.8).dx, pt(164.0, 111.8).dy)
      ..lineTo(pt(166.0, 111.8).dx, pt(166.0, 111.8).dy)
      ..cubicTo(
        pt(167.2, 115.2).dx,
        pt(167.2, 115.2).dy,
        pt(168.4, 119.5).dx,
        pt(168.4, 119.5).dy,
        pt(169.0, 123.6).dx,
        pt(169.0, 123.6).dy,
      )
      ..cubicTo(
        pt(166.5, 124.5).dx,
        pt(166.5, 124.5).dy,
        pt(163.5, 124.5).dx,
        pt(163.5, 124.5).dy,
        pt(161.0, 123.6).dx,
        pt(161.0, 123.6).dy,
      )
      ..cubicTo(
        pt(161.6, 119.5).dx,
        pt(161.6, 119.5).dy,
        pt(162.8, 115.2).dx,
        pt(162.8, 115.2).dy,
        pt(164.0, 111.8).dx,
        pt(164.0, 111.8).dy,
      )
      ..close();
    canvas.drawPath(tasselPath, Paint()..color = tesbihDarkColor);

    final threadPaint = Paint()
      ..color = tesbihLightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pt(165.0, 112.5), pt(165.0, 123.8), threadPaint);
    canvas.drawLine(pt(164.1, 112.8), pt(162.7, 123.4), threadPaint);
    canvas.drawLine(pt(165.9, 112.8), pt(167.3, 123.4), threadPaint);

    // 7. Upper-Center Upcoming Prayer Name & Exact Time
    final nameFontSize = (9.8 * scale).clamp(8.0, 12.5);
    textPainter.text = TextSpan(
      text: prayerName,
      style: TextStyle(
        color: textSecondaryColor,
        fontSize: nameFontSize,
        fontWeight: FontWeight.w700,
      ),
    );
    textPainter.layout(maxWidth: 74.0 * scale);
    textPainter.paint(
      canvas,
      Offset(clockCenter.dx - textPainter.width / 2, clockCenter.dy - 36.5 * scale),
    );

    final timeFontSize = (10.8 * scale).clamp(8.5, 13.5);
    textPainter.text = TextSpan(
      text: prayerTime,
      style: TextStyle(
        color: textPrimaryColor,
        fontSize: timeFontSize,
        fontWeight: FontWeight.w800,
      ),
    );
    textPainter.layout(maxWidth: 74.0 * scale);
    textPainter.paint(
      canvas,
      Offset(clockCenter.dx - textPainter.width / 2, clockCenter.dy - 25.0 * scale),
    );

    // 8. Classic Dauphine Hands (Hour, Minute) + Red Second Hand
    final hourFraction = ((now.hour % 12) + (now.minute / 60.0) + (now.second / 3600.0)) / 12.0;
    final minFraction = (now.minute + (now.second / 60.0)) / 60.0;
    final secFraction = (now.second + (now.millisecond / 1000.0)) / 60.0;

    final hourAngle = (hourFraction * 360.0 - 90.0) * (math.pi / 180.0);
    final minAngle = (minFraction * 360.0 - 90.0) * (math.pi / 180.0);
    final secAngle = (secFraction * 360.0 - 90.0) * (math.pi / 180.0);

    const handFillColor = Color(0xFF163A2B);
    const redSecondColor = Color(0xFFDC2626);

    void drawDauphineHand({
      required double angle,
      required double length,
      required double halfWidth,
      required double tailLength,
      required Color fillColor,
      required Color strokeColor,
    }) {
      final ux = math.cos(angle);
      final uy = math.sin(angle);
      final px = -uy;
      final py = ux;

      final tip = Offset(clockCenter.dx + ux * length, clockCenter.dy + uy * length);
      final tail = Offset(clockCenter.dx - ux * tailLength, clockCenter.dy - uy * tailLength);
      final shoulderDist = length * 0.12;
      final leftWing = Offset(
        clockCenter.dx + ux * shoulderDist + px * halfWidth,
        clockCenter.dy + uy * shoulderDist + py * halfWidth,
      );
      final rightWing = Offset(
        clockCenter.dx + ux * shoulderDist - px * halfWidth,
        clockCenter.dy + uy * shoulderDist - py * halfWidth,
      );

      final handPath = Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(leftWing.dx, leftWing.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(rightWing.dx, rightWing.dy)
        ..close();

      canvas.drawPath(handPath, Paint()..color = fillColor);
      canvas.drawPath(
        handPath,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * scale
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawDauphineHand(
      angle: hourAngle,
      length: 37.0 * scale,
      halfWidth: 3.9 * scale,
      tailLength: 8.5 * scale,
      fillColor: handFillColor,
      strokeColor: goldPrimary,
    );
    drawDauphineHand(
      angle: minAngle,
      length: 50.5 * scale,
      halfWidth: 3.0 * scale,
      tailLength: 10.0 * scale,
      fillColor: handFillColor,
      strokeColor: goldPrimary,
    );

    // Center Gold Bezel Ring
    final bossR = 4.5 * scale;
    canvas.drawCircle(clockCenter, bossR, Paint()..color = goldPrimary);

    // Classic Red Second Hand
    final secTip = Offset(
      clockCenter.dx + (54.0 * scale) * math.cos(secAngle),
      clockCenter.dy + (54.0 * scale) * math.sin(secAngle),
    );
    final secTail = Offset(
      clockCenter.dx - (14.5 * scale) * math.cos(secAngle),
      clockCenter.dy - (14.5 * scale) * math.sin(secAngle),
    );
    canvas.drawLine(
      secTail,
      secTip,
      Paint()
        ..color = redSecondColor
        ..strokeWidth = (1.5 * scale).clamp(1.2, 2.4)
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(clockCenter, 2.7 * scale, Paint()..color = redSecondColor);
    canvas.drawCircle(clockCenter, 1.0 * scale, Paint()..color = goldHighlight);

    // 9. Bottom Bar Outside the Clock: Elegant Live Countdown Pill
    final pillWidth = dim * 0.46;
    final pillHeight = bottomBarHeight * 0.86;
    final pillCenter = Offset(size.width / 2, dim - bottomMargin - (pillHeight / 2));
    final pillRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pillCenter, width: pillWidth, height: pillHeight),
      Radius.circular(pillHeight / 2),
    );
    canvas.drawRRect(pillRRect, Paint()..color = pillBgColor);
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = pillBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final timerFontSize = (pillHeight * 0.58).clamp(9.0, 14.0);
    textPainter.text = TextSpan(
      text: timerText,
      style: TextStyle(
        color: pillTextColor,
        fontSize: timerFontSize,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    textPainter.layout(maxWidth: pillWidth - 8);
    textPainter.paint(
      canvas,
      Offset(pillCenter.dx - textPainter.width / 2, pillCenter.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ZikirceSeljukAnalogClockPainter oldDelegate) {
    return oldDelegate.now.second != now.second ||
        oldDelegate.now.minute != now.minute ||
        oldDelegate.now.hour != now.hour ||
        oldDelegate.isDark != isDark ||
        oldDelegate.prayerName != prayerName ||
        oldDelegate.timerText != timerText ||
        oldDelegate.prayerTime != prayerTime;
  }
}
