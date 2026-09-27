import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../providers/prayer_providers.dart';

/// Hygge-inspired Minimalist Designer Analog Prayer Clock
/// Pointer Directions:
/// - Akrep (Hour): Outward triangular wedge on colored ring outer edge.
/// - Yelkovan (Minute): Outward arrow originating from colored ring INNER edge and pointing outward across the ring.
/// - Saniye (Second): Inward slim triangle on outer perimeter ring.
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
    Color(0xFF8B5CF6), // 0: İmsak - Mistik Mor
    Color(0xFFF59E0B), // 1: Güneş - Şafak Amber
    Color(0xFF10B981), // 2: Öğle - İslam Zümrüt Yeşili
    Color(0xFF0EA5E9), // 3: İkindi - Safir / Gök Mavisi
    Color(0xFFF97316), // 4: Akşam - Gün Batımı Kızılı
    Color(0xFF6366F1), // 5: Yatsı - Gece İndigo Mavisi
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

    final activeIndex = nextPrayer?.activePrayerIndex ?? 0;
    final prayerColor = getPrayerThemeColor(activeIndex);

    final prayerName = nextPrayer?.name.toUpperCase() ?? 'AKŞAM';
    final timerText = nextPrayer?.formattedRemaining ?? '00:00:00';
    final prayerTime = nextPrayer?.time ?? '00:00';

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _HyggeAnalogPrayerClockPainter(
            now: now,
            isDark: effectiveIsDark,
            prayerThemeColor: prayerColor,
            prayerName: prayerName,
            timerText: timerText,
            prayerTime: prayerTime,
          ),
        ),
      ),
    );
  }
}

class _HyggeAnalogPrayerClockPainter extends CustomPainter {
  final DateTime now;
  final bool isDark;
  final Color prayerThemeColor;
  final String prayerName;
  final String timerText;
  final String prayerTime;

  _HyggeAnalogPrayerClockPainter({
    required this.now,
    required this.isDark,
    required this.prayerThemeColor,
    required this.prayerName,
    required this.timerText,
    required this.prayerTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dim = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = dim / 2 - 2.0;

    // 1. Palette definition
    final cardBgColor = isDark ? const Color(0xFF161618) : const Color(0xFFFFFFFF);
    final cardBorderColor = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB);
    final dialBgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF8FAFC);
    final centerDiscBgColor = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final centerDiscBorderColor = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB);

    final tickMajorColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF18181B);
    final tickMinorColor = isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

    // Yelkovan (Minute pointer): Pure white in light mode, Dark charcoal in dark mode with high-contrast outlines
    final yelkovanFillColor = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final yelkovanStrokeColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF334155);
    final yelkovanRayColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final akrepRayColor = prayerThemeColor.withValues(alpha: 0.85);

    final textPrimaryColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF18181B);
    final textSecondaryColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    // 2. Outer Rounded Card Background
    final cardRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: dim - 2.0, height: dim - 2.0),
      Radius.circular(dim * 0.18),
    );
    final cardPaint = Paint()
      ..color = cardBgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRRect, cardPaint);

    final cardBorderPaint = Paint()
      ..color = cardBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(cardRRect, cardBorderPaint);

    // 3. Dial Surface
    final dialRadius = radius * 0.94;
    final dialPaint = Paint()
      ..color = dialBgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dialRadius, dialPaint);

    // 4. OUTER SECONDS RING (Placed at outer perimeter)
    final secondsRingR = dialRadius - (radius * 0.03);
    final secRingPaint = Paint()
      ..color = isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, secondsRingR, secRingPaint);

    // Saniye: Merkeze (içeriye) bakan ince üçgen ok
    final secFraction = (now.second + (now.millisecond / 1000.0)) / 60.0;
    final secAngle = (secFraction * 360.0 - 90.0) * (math.pi / 180);

    final secTipR = secondsRingR - (radius * 0.055);
    final secBaseR = secondsRingR + 1.0;
    const secHalfSpread = 0.038;

    final secPath = Path()
      ..moveTo(
        center.dx + secTipR * math.cos(secAngle),
        center.dy + secTipR * math.sin(secAngle),
      )
      ..lineTo(
        center.dx + secBaseR * math.cos(secAngle - secHalfSpread),
        center.dy + secBaseR * math.sin(secAngle - secHalfSpread),
      )
      ..lineTo(
        center.dx + secBaseR * math.cos(secAngle + secHalfSpread),
        center.dy + secBaseR * math.sin(secAngle + secHalfSpread),
      )
      ..close();

    final secPointerPaint = Paint()
      ..color = prayerThemeColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(secPath, secPointerPaint);

    // 5. 12 MINIMALIST DESIGNER INDEX TICKS (Inside the Seconds Ring)
    final tickOuterR = secondsRingR - (radius * 0.06);
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * (math.pi / 180);
      final isMajor = (i % 3 == 0); // 12, 3, 6, 9
      final tickLength = isMajor ? (radius * 0.08) : (radius * 0.045);
      final tickInnerR = tickOuterR - tickLength;

      tickPaint.color = isMajor ? tickMajorColor : tickMinorColor;
      tickPaint.strokeWidth = isMajor ? (dim * 0.013).clamp(2.2, 3.6) : (dim * 0.007).clamp(1.2, 2.0);

      final p1 = Offset(center.dx + tickOuterR * math.cos(angle), center.dy + tickOuterR * math.sin(angle));
      final p2 = Offset(center.dx + tickInnerR * math.cos(angle), center.dy + tickInnerR * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 6. MAIN MIDDLE ROTATING RING (Dynamic Prayer Theme Color)
    final ringOuterR = tickOuterR - (radius * 0.09);
    final ringStrokeWidth = (dim * 0.072).clamp(12.0, 24.0);
    final ringInnerR = ringOuterR - ringStrokeWidth;
    final ringMidR = (ringOuterR + ringInnerR) / 2.0;

    // Draw Main Colored Ring Body
    final mainRingPaint = Paint()
      ..color = prayerThemeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStrokeWidth;
    canvas.drawCircle(center, ringMidR, mainRingPaint);

    // Subtle lighting border on colored ring
    final ringBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, ringOuterR, ringBorderPaint);
    canvas.drawCircle(center, ringInnerR, ringBorderPaint);

    // 7. AKREP: Dış çeperden dışarıya bakan geniş üçgen ok (Saat) + İnce Lazer Işını
    final hourFraction = ((now.hour % 12) + (now.minute / 60.0) + (now.second / 3600.0)) / 12.0;
    final hourAngle = (hourFraction * 360.0 - 90.0) * (math.pi / 180);

    final hourTipR = ringOuterR + (radius * 0.065);
    final hourBaseR = ringOuterR - 1.0;
    const hourHalfSpread = 0.09; // radians

    final hourPath = Path()
      ..moveTo(
        center.dx + hourTipR * math.cos(hourAngle),
        center.dy + hourTipR * math.sin(hourAngle),
      )
      ..lineTo(
        center.dx + hourBaseR * math.cos(hourAngle - hourHalfSpread),
        center.dy + hourBaseR * math.sin(hourAngle - hourHalfSpread),
      )
      ..lineTo(
        center.dx + hourBaseR * math.cos(hourAngle + hourHalfSpread),
        center.dy + hourBaseR * math.sin(hourAngle + hourHalfSpread),
      )
      ..close();

    final hourArrowPaint = Paint()
      ..color = prayerThemeColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(hourPath, hourArrowPaint);

    // Akrep Lazer Işını (Guidance ray towards ticks)
    final hourRayEndR = tickOuterR - (radius * 0.02);
    final hourRayPaint = Paint()
      ..color = akrepRayColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (dim * 0.007).clamp(1.2, 2.0);
    canvas.drawLine(
      Offset(center.dx + hourTipR * math.cos(hourAngle), center.dy + hourTipR * math.sin(hourAngle)),
      Offset(center.dx + hourRayEndR * math.cos(hourAngle), center.dy + hourRayEndR * math.sin(hourAngle)),
      hourRayPaint,
    );

    // 8. YELKOVAN: Akrep gibi dış çeperde aynı üçgen formunda ok (Dakika) + Dış Çembere Uzanan Lazer Işını
    final minFraction = (now.minute + (now.second / 60.0)) / 60.0;
    final minAngle = (minFraction * 360.0 - 90.0) * (math.pi / 180);

    final minTipR = ringOuterR + (radius * 0.065);
    final minBaseR = ringOuterR - 1.0;
    const minHalfSpread = 0.08;

    final minPath = Path()
      ..moveTo(
        center.dx + minTipR * math.cos(minAngle),
        center.dy + minTipR * math.sin(minAngle),
      )
      ..lineTo(
        center.dx + minBaseR * math.cos(minAngle - minHalfSpread),
        center.dy + minBaseR * math.sin(minAngle - minHalfSpread),
      )
      ..lineTo(
        center.dx + minBaseR * math.cos(minAngle + minHalfSpread),
        center.dy + minBaseR * math.sin(minAngle + minHalfSpread),
      )
      ..close();

    final minArrowPaint = Paint()
      ..color = yelkovanFillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(minPath, minArrowPaint);

    final minBorderPaint = Paint()
      ..color = yelkovanStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(minPath, minBorderPaint);

    // Yelkovan Lazer Işını: Kadranın en dış çemberine kadar uzanan net kılavuz çizgisi
    final minRayEndR = secondsRingR;
    final minRayPaint = Paint()
      ..color = yelkovanRayColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (dim * 0.006).clamp(1.0, 1.8);
    canvas.drawLine(
      Offset(center.dx + minTipR * math.cos(minAngle), center.dy + minTipR * math.sin(minAngle)),
      Offset(center.dx + minRayEndR * math.cos(minAngle), center.dy + minRayEndR * math.sin(minAngle)),
      minRayPaint,
    );

    // 9. CENTER HUB / DISC (Clean circular disc for prayer information)
    final centerDiscR = ringInnerR - (radius * 0.04);
    final centerDiscPaint = Paint()
      ..color = centerDiscBgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerDiscR, centerDiscPaint);

    final centerDiscBorderPaint = Paint()
      ..color = centerDiscBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, centerDiscR, centerDiscBorderPaint);

    // 10. Typography in Center Disc (Prayer Name + Live Countdown + Prayer Time)
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // A. Top: Upcoming Prayer Name
    final nameFontSize = (dim * 0.048).clamp(9.0, 13.5);
    textPainter.text = TextSpan(
      text: prayerName,
      style: TextStyle(
        color: prayerThemeColor,
        fontSize: nameFontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
    textPainter.layout(maxWidth: centerDiscR * 1.8);
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (dim * 0.16)),
    );

    // B. Middle: Live Countdown Timer
    final timerFontSize = (dim * 0.078).clamp(14.0, 23.0);
    textPainter.text = TextSpan(
      text: timerText,
      style: TextStyle(
        color: textPrimaryColor,
        fontSize: timerFontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
    textPainter.layout(maxWidth: centerDiscR * 1.8);
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (dim * 0.045)),
    );

    // C. Bottom: Prayer Exact Time
    final timeFontSize = (dim * 0.044).clamp(8.5, 12.0);
    textPainter.text = TextSpan(
      text: prayerTime,
      style: TextStyle(
        color: textSecondaryColor,
        fontSize: timeFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
    textPainter.layout(maxWidth: centerDiscR * 1.8);
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy + (dim * 0.08)),
    );
  }

  @override
  bool shouldRepaint(covariant _HyggeAnalogPrayerClockPainter oldDelegate) {
    return oldDelegate.now.second != now.second ||
        oldDelegate.now.minute != now.minute ||
        oldDelegate.now.hour != now.hour ||
        oldDelegate.isDark != isDark ||
        oldDelegate.prayerThemeColor != prayerThemeColor ||
        oldDelegate.prayerName != prayerName ||
        oldDelegate.timerText != timerText ||
        oldDelegate.prayerTime != prayerTime;
  }
}
