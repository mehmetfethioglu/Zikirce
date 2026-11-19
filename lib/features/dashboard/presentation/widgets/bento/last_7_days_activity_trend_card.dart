import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../providers/dashboard_providers.dart';

const double _kWaveTopPadding = 28.0;
const double _kWaveBottomPadding = 8.0;

List<Offset> _computeSevenDayWavePoints({
  required List<Last7DaysPoint> days,
  required int peakCount,
  required Size size,
}) {
  if (days.isEmpty) return const [];
  final plotBottom = max(_kWaveTopPadding + 16.0, size.height - _kWaveBottomPadding);
  final usableHeight = max(12.0, plotBottom - _kWaveTopPadding);
  final colWidth = size.width / days.length;

  return List<Offset>.generate(days.length, (i) {
    final x = colWidth * (i + 0.5);
    final double y;
    if (peakCount <= 0) {
      y = plotBottom - 6.0;
    } else {
      final ratio = (days[i].count / peakCount).clamp(0.0, 1.0);
      y = plotBottom - 4.0 - ((usableHeight - 4.0) * ratio);
    }
    return Offset(x, y);
  });
}

/// Ana sayfada son 7 günün aktivite trendini sade ve modern dalga grafiğiyle sunan kart.
class Last7DaysActivityTrendCard extends ConsumerStatefulWidget {
  const Last7DaysActivityTrendCard({super.key});

  @override
  ConsumerState<Last7DaysActivityTrendCard> createState() =>
      _Last7DaysActivityTrendCardState();
}

class _Last7DaysActivityTrendCardState
    extends ConsumerState<Last7DaysActivityTrendCard> {
  int _selectedIndex = 6;

  void _selectAtDx(double dx, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final idx = (dx / width * count).floor().clamp(0, count - 1);
    if (idx != _selectedIndex) {
      HapticService.selectionClick();
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendAsync = ref.watch(last7DaysTrendProvider);

    final trend = trendAsync.valueOrNull ??
        buildLast7DaysTrendData(
          anchorDate: DateTime.now(),
          countsByDate: const {},
        );
    final days = trend.days;
    final safeIndex = _selectedIndex.clamp(0, max(0, days.length - 1)).toInt();
    final selectedDay = days.isNotEmpty ? days[safeIndex] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.hasBoundedHeight;

          Widget buildWaveArea(double width, double height) {
            final points = _computeSevenDayWavePoints(
              days: days,
              peakCount: trend.peakCount,
              size: Size(width, height),
            );
            final selectedPt =
                points.isNotEmpty ? points[safeIndex] : Offset(width * 0.5, height * 0.5);
            const pillContainerWidth = 64.0;
            final pillLeft = (selectedPt.dx - pillContainerWidth / 2)
                .clamp(0.0, max(0.0, width - pillContainerWidth))
                .toDouble();
            final pillTop = (selectedPt.dy - 26.0)
                .clamp(2.0, max(2.0, height - 28.0))
                .toDouble();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _selectAtDx(details.localPosition.dx, width, days.length),
              onHorizontalDragUpdate: (details) =>
                  _selectAtDx(details.localPosition.dx, width, days.length),
              onLongPress: () {
                HapticService.selectionClick();
                context.push('/stats');
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CleanReferenceWavePainter(
                        days: days,
                        peakCount: trend.peakCount,
                        selectedIndex: safeIndex,
                        accentColor: colors.accent,
                        cardBgColor: colors.cardBackground,
                        guideColor: colors.borderStroke.withValues(
                          alpha: isDark ? 0.32 : 0.48,
                        ),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  if (selectedDay != null)
                    Positioned(
                      left: pillLeft,
                      top: pillTop,
                      width: pillContainerWidth,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.selectionClick();
                            context.push('/stats');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.cardBackgroundAlt
                                  : colors.cardBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.35),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.07,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              formatCompactNumber(selectedDay.count),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: colors.primaryText,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          final chartWidget = hasBoundedHeight
              ? Expanded(
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) => buildWaveArea(
                      chartConstraints.maxWidth,
                      chartConstraints.maxHeight,
                    ),
                  ),
                )
              : SizedBox(
                  height: 108,
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) => buildWaveArea(
                      chartConstraints.maxWidth,
                      chartConstraints.maxHeight,
                    ),
                  ),
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize:
                hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              chartWidget,
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: Row(
                  children: List.generate(days.length, (index) {
                    final point = days[index];
                    final isSelected = index == safeIndex;
                    final label =
                        l10n.isTurkish ? point.dayShortTr : point.dayShortEn;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_selectedIndex != index) {
                            HapticService.selectionClick();
                            setState(() => _selectedIndex = index);
                          }
                        },
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : (point.isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500),
                                color: isSelected
                                    ? colors.accentText
                                    : (point.isToday
                                        ? colors.primaryText
                                        : colors.secondaryTextAlt),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CleanReferenceWavePainter extends CustomPainter {
  final List<Last7DaysPoint> days;
  final int peakCount;
  final int selectedIndex;
  final Color accentColor;
  final Color cardBgColor;
  final Color guideColor;
  final bool isDark;

  const _CleanReferenceWavePainter({
    required this.days,
    required this.peakCount,
    required this.selectedIndex,
    required this.accentColor,
    required this.cardBgColor,
    required this.guideColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width <= 0 || size.height <= 0) return;

    final plotBottom =
        max(_kWaveTopPadding + 16.0, size.height - _kWaveBottomPadding);
    final usableHeight = max(12.0, plotBottom - _kWaveTopPadding);

    // 1. Çok silik 2 yatay kesikli kılavuz çizgi
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final factor in const [0.35, 0.70]) {
      final y = _kWaveTopPadding + usableHeight * factor;
      const dashWidth = 4.0;
      const dashGap = 4.0;
      double x = 4.0;
      while (x < size.width - 4.0) {
        canvas.drawLine(
          Offset(x, y),
          Offset(min(x + dashWidth, size.width - 4.0), y),
          guidePaint,
        );
        x += dashWidth + dashGap;
      }
    }

    final points = _computeSevenDayWavePoints(
      days: days,
      peakCount: peakCount,
      size: size,
    );
    if (points.length < 2) return;

    // 2. Monotone Yatay-Teğet Kübik Bezier Eğrisi (sıfır overshoot)
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final midX = (p1.dx + p2.dx) / 2.0;
      linePath.cubicTo(midX, p1.dy, midX, p2.dy, p2.dx, p2.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, plotBottom)
      ..lineTo(points.first.dx, plotBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.65, 1.0],
        colors: [
          accentColor.withValues(alpha: isDark ? 0.24 : 0.16),
          accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, _kWaveTopPadding, size.width, usableHeight));

    canvas.drawPath(fillPath, fillPaint);

    // 3. Seçili günden tabana inen zarif dikey vurgu çizgisi
    final safeIdx = selectedIndex.clamp(0, points.length - 1).toInt();
    final selectedPt = points[safeIdx];
    final verticalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.42),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTRB(
          selectedPt.dx - 1,
          selectedPt.dy,
          selectedPt.dx + 1,
          plotBottom,
        ),
      )
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      selectedPt,
      Offset(selectedPt.dx, plotBottom),
      verticalPaint,
    );

    // 4. Ana dalga çizgisi
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // 5. Diğer gün noktaları (minimal)
    final mutedDotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      if (i != safeIdx) {
        canvas.drawCircle(points[i], 2.2, mutedDotPaint);
      }
    }

    // 6. Seçili gün halkası (hale + dolgu + canlı çerçeve)
    canvas.drawCircle(
      selectedPt,
      9.0,
      Paint()..color = accentColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      selectedPt,
      5.0,
      Paint()..color = cardBgColor,
    );
    canvas.drawCircle(
      selectedPt,
      5.0,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CleanReferenceWavePainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.peakCount != peakCount ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.cardBgColor != cardBgColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.days != days;
  }
}
