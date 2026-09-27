import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/dashboard_providers.dart';

enum TrendPeriod { week, month, year }

class ActivityTrendChart extends ConsumerStatefulWidget {
  final Function(TrendPeriod period)? onPeriodChanged;

  const ActivityTrendChart({
    super.key,
    this.onPeriodChanged,
  });

  @override
  ConsumerState<ActivityTrendChart> createState() => _ActivityTrendChartState();
}

class _ActivityTrendChartState extends ConsumerState<ActivityTrendChart> {
  TrendPeriod _selectedPeriod = TrendPeriod.week;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trendDataAsync = ref.watch(activityTrendDataProvider);

    const defaultTrendData = ActivityTrendData(
      weekDays: [
        WeeklyTrendDay(day: 'Pzt', count: 0, color: Color(0xFF29B6F6)),
        WeeklyTrendDay(day: 'Sal', count: 0, color: Color(0xFF4CAF50)),
        WeeklyTrendDay(day: 'Çar', count: 0, color: Color(0xFFFFA726)),
        WeeklyTrendDay(day: 'Per', count: 0, color: Color(0xFFAB47BC)),
        WeeklyTrendDay(day: 'Cum', count: 0, color: Color(0xFFEF5350)),
        WeeklyTrendDay(day: 'Cmt', count: 0, color: Color(0xFF00BCD4)),
        WeeklyTrendDay(day: 'Paz', count: 0, color: Color(0xFFEC407A)),
      ],
      monthlyDailyAverage: 0,
      yearlyTotal: 0,
    );

    final trendData = trendDataAsync.valueOrNull ?? defaultTrendData;
    final weekDays = trendData.weekDays;
    final maxVal = max(1, weekDays.map((e) => e.count).fold<int>(0, max));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Filter Segmented Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Aktivite Trendleri',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
              // Segmented Tabs [ Hafta | Ay | Yıl ]
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabItem('Hafta', TrendPeriod.week, colors.accent, colors.secondaryTextAlt),
                    _buildTabItem('Ay', TrendPeriod.month, colors.accent, colors.secondaryTextAlt),
                    _buildTabItem('Yıl', TrendPeriod.year, colors.accent, colors.secondaryTextAlt),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart content
          if (_selectedPeriod == TrendPeriod.week) ...[
            SizedBox(
              height: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weekDays.map((item) {
                  final count = item.count;
                  final day = item.day;
                  final color = item.color;
                  final heightFactor = (count / (maxVal * 1.15)).clamp(0.12, 1.0);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value above bar matching bar color
                      Text(
                        count > 0 ? (count >= 1000 ? formatCompactNumber(count) : '$count') : '0',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: count > 0 ? color : colors.secondaryTextAlt.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Colored Rounded Bar
                      Container(
                        width: 22,
                        height: 90 * heightFactor,
                        decoration: BoxDecoration(
                          color: count > 0 ? color : colors.borderStroke.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Day text label
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ] else if (_selectedPeriod == TrendPeriod.month) ...[
            SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${trendData.monthlyDailyAverage} / gün',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bu Ayın Günlük Zikir Ortalaması',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.secondaryTextAlt,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatCompactNumber(trendData.yearlyTotal),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateTime.now().year} Yıllık Toplam Zikir',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.secondaryTextAlt,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, TrendPeriod period, Color activeColor, Color inactiveTextColor) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
        widget.onPeriodChanged?.call(period);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : inactiveTextColor,
          ),
        ),
      ),
    );
  }
}
