import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/dashboard_providers.dart';
import '../../../gamification/providers/gamification_providers.dart';

/// Responsive, tablet and desktop-optimized Annual Heatmap Widget
/// Ported from .NET MAUI HeatmapView with CustomPainter and adaptive scaling.
class AnnualHeatmapWidget extends ConsumerStatefulWidget {
  final Map<String, int>? dailyCounts;

  const AnnualHeatmapWidget({
    super.key,
    this.dailyCounts,
  });

  @override
  ConsumerState<AnnualHeatmapWidget> createState() => _AnnualHeatmapWidgetState();
}

class _AnnualHeatmapWidgetState extends ConsumerState<AnnualHeatmapWidget> {
  DateTime? _selectedDate;
  int? _selectedCount;
  bool _selectedIsShielded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final contributionAsync = ref.watch(dailyZikirContributionProvider);
    final shieldedDatesAsync = ref.watch(shieldedDatesStreamProvider);
    final data = widget.dailyCounts ?? contributionAsync.valueOrNull ?? {};
    final shieldedDates = shieldedDatesAsync.valueOrNull ?? const <String>{};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Year Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.bismillahHeatmapTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
              // Year badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderStroke),
                ),
                child: Text(
                  DateTime.now().year.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Responsive Heatmap Grid + Legend Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              const double startX = 4.0;
              const double startY = 20.0;

              // On mobile: step scales smoothly down to fit width without scroll.
              // On tablet/desktop: step is clamped so cells do not balloon into giant tiles.
              final double uncappedStep = (maxWidth - (startX * 2)) / 37.0;
              final double step = uncappedStep.clamp(7.5, 16.5);
              final double gridWidth = (step * 37.0) + (startX * 2);
              final double gridHeight = startY + (10 * step) + 4.0;

              return Center(
                child: SizedBox(
                  width: min(gridWidth, maxWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: gridWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Selected Day Tooltip (If tapped)
                          if (_selectedDate != null) ...[
                            _buildSelectedTooltip(colors, isDark, l10n),
                            const SizedBox(height: 10),
                          ],

                          // Interactive Custom Heatmap Grid
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                _handleTap(
                                  details.localPosition,
                                  step,
                                  startX,
                                  startY,
                                  data,
                                  shieldedDates,
                                );
                              },
                              child: CustomPaint(
                                size: Size(gridWidth, gridHeight),
                                painter: _HeatmapCustomPainter(
                                  contributionData: data,
                                  shieldedDates: shieldedDates,
                                  isDark: isDark,
                                  isTurkish: l10n.isTurkish,
                                  selectedDate: _selectedDate,
                                  step: step,
                                  startX: startX,
                                  startY: startY,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Legend Bar (Aligned with grid boundaries)
                          _buildLegendBar(colors, isDark, l10n, step),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTooltip(AppThemeColors colors, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedIsShielded ? Icons.shield_rounded : Icons.touch_app_rounded,
            size: 14,
            color: _selectedIsShielded
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                : colors.accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _formatTooltipDate(_selectedDate!, _selectedCount ?? 0, _selectedIsShielded, l10n),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = null;
                _selectedCount = null;
                _selectedIsShielded = false;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: colors.secondaryTextAlt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBar(AppThemeColors colors, bool isDark, AppLocalizations l10n, double step) {
    final double boxSize = (step * 0.58).clamp(7.0, 9.5);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1st of month + Shielded legend
        Row(
          children: [
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFFEAB308),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.isTurkish ? "1'i" : '1st',
              style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 10),
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0284C7) : const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.isTurkish ? 'Kalkanlı' : 'Shielded',
              style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt, fontWeight: FontWeight.w500),
            ),
          ],
        ),

        // Activity Levels Legend
        Row(
          children: [
            Text(
              l10n.isTurkish ? 'Az' : 'Less',
              style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            _buildLegendBox(isDark ? const Color(0xFF161B22) : const Color(0xFFEBEDF0), boxSize),
            _buildLegendBox(isDark ? const Color(0xFF0E4429) : const Color(0xFF9BE9A8), boxSize),
            _buildLegendBox(isDark ? const Color(0xFF006D32) : const Color(0xFF40C463), boxSize),
            _buildLegendBox(isDark ? const Color(0xFF26A641) : const Color(0xFF30A14E), boxSize),
            _buildLegendBox(isDark ? const Color(0xFF39D353) : const Color(0xFF216E39), boxSize),
            const SizedBox(width: 4),
            Text(
              l10n.isTurkish ? 'Çok' : 'More',
              style: TextStyle(fontSize: 9.5, color: colors.secondaryTextAlt, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendBox(Color color, double size) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  String _formatTooltipDate(DateTime date, int count, bool isShielded, AppLocalizations l10n) {
    const monthsTr = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    const monthsEn = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final monthName = l10n.isTurkish ? monthsTr[date.month] : monthsEn[date.month];
    final datePrefix = '${date.day} $monthName ${date.year}';
    if (isShielded) {
      if (count > 0) {
        return '$datePrefix: $count zikir (🛡️ Kalkanla Korundu)';
      }
      return '$datePrefix: 🛡️ Kalkanla Korundu / Kurtarıldı';
    }
    final countFormatted = count > 0 ? '$count' : (l10n.isTurkish ? 'Zikir yok' : 'No dhikr');
    final suffix = count > 0 ? (l10n.isTurkish ? ' zikir' : ' dhikr') : '';
    return '$datePrefix: $countFormatted$suffix';
  }

  void _handleTap(
    Offset localPos,
    double step,
    double startX,
    double startY,
    Map<String, int> data,
    Set<String> shieldedDates,
  ) {
    final tapX = localPos.dx - startX;
    final tapY = localPos.dy - startY;

    if (tapX < 0 || tapY < 0) return;

    final col = (tapX / step).floor();
    final row = (tapY / step).floor();

    if (col >= 0 && col < 37 && row >= 0 && row < 10) {
      final dayOfYearIndex = col * 10 + row;
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final date = startOfYear.add(Duration(days: dayOfYearIndex));

      // Disallow clicking outside the current year
      if (date.year != now.year) return;

      // Toggle off if already selected
      if (_selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day) {
        setState(() {
          _selectedDate = null;
          _selectedCount = null;
          _selectedIsShielded = false;
        });
        return;
      }

      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = data[dateKey] ?? 0;
      final isShielded = shieldedDates.contains(dateKey);

      setState(() {
        _selectedDate = date;
        _selectedCount = count;
        _selectedIsShielded = isShielded;
      });
    }
  }
}

class _HeatmapCustomPainter extends CustomPainter {
  final Map<String, int> contributionData;
  final Set<String> shieldedDates;
  final bool isDark;
  final bool isTurkish;
  final DateTime? selectedDate;
  final double step;
  final double startX;
  final double startY;

  _HeatmapCustomPainter({
    required this.contributionData,
    required this.shieldedDates,
    required this.isDark,
    required this.isTurkish,
    required this.selectedDate,
    required this.step,
    required this.startX,
    required this.startY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);

    final boxSize = max(2.0, step - 1.2);
    final cornerRadius = (boxSize * 0.22).clamp(1.5, 3.5);

    // Premium theme color palette (Light Mode vs Elite Dark Mode 1:1 with MAUI)
    final emptyColor = isDark ? const Color(0xFF161B22) : const Color(0xFFEBEDF0);
    final colorLevel1 = isDark ? const Color(0xFF0E4429) : const Color(0xFF9BE9A8);
    final colorLevel2 = isDark ? const Color(0xFF006D32) : const Color(0xFF40C463);
    final colorLevel3 = isDark ? const Color(0xFF26A641) : const Color(0xFF30A14E);
    final colorLevel4 = isDark ? const Color(0xFF39D353) : const Color(0xFF216E39);

    final shieldColor = isDark ? const Color(0xFF0284C7) : const Color(0xFF38BDF8); // Cyan / Shield Blue
    final shieldBright = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    final brightYellow = isDark ? const Color(0xFFFFD700) : const Color(0xFFEAB308);
    final paleYellow = isDark ? const Color(0xFF3E3A1A) : const Color(0xFFFEF9C3);
    final labelColor = isDark ? const Color(0xFFAEAEB2) : const Color(0xFF8E8E93);

    // 1. Draw Month labels at equal intervals of 3 columns (0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33)
    final double labelFontSize = (step * 0.62).clamp(7.5, 10.5);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int m = 1; m <= 12; m++) {
      final monthLabel = _getMonthAbbreviation(m, isTurkish);
      final colIndex = (m - 1) * 3;
      final labelX = startX + colIndex * step;

      textPainter.text = TextSpan(
        text: monthLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: labelFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(labelX, startY - labelFontSize - 4));
    }

    // 2. Compute Max Count
    final maxCount = contributionData.values.isNotEmpty
        ? contributionData.values.reduce(max)
        : 0;

    final cellPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFD4A574);

    // 3. Draw 37 Columns x 10 Rows Matrix (370 Cells)
    for (int col = 0; col < 37; col++) {
      for (int row = 0; row < 10; row++) {
        final dayOfYearIndex = col * 10 + row;
        final date = startOfYear.add(Duration(days: dayOfYearIndex));

        // Skip any cell that rolls over to the next year
        if (date.year != now.year) continue;

        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final count = contributionData[dateKey] ?? 0;
        final isShielded = shieldedDates.contains(dateKey);

        Color fill = emptyColor;
        if (date.day == 1) {
          fill = count > 0
              ? brightYellow
              : (isShielded ? shieldBright : paleYellow);
        } else if (isShielded && count == 0) {
          fill = shieldColor;
        } else if (count > 0) {
          if (maxCount <= 30) {
            if (count <= 3) {
              fill = colorLevel1;
            } else if (count <= 10) {
              fill = colorLevel2;
            } else if (count <= 30) {
              fill = colorLevel3;
            } else {
              fill = colorLevel4;
            }
          } else {
            final ratio = count / maxCount;
            if (ratio <= 0.25) {
              fill = colorLevel1;
            } else if (ratio <= 0.50) {
              fill = colorLevel2;
            } else if (ratio <= 0.75) {
              fill = colorLevel3;
            } else {
              fill = colorLevel4;
            }
          }
        }

        cellPaint.color = fill;
        final x = startX + col * step;
        final y = startY + row * step;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, boxSize, boxSize),
          Radius.circular(cornerRadius),
        );
        canvas.drawRRect(rrect, cellPaint);

        // Highlight selected cell
        if (selectedDate != null &&
            selectedDate!.year == date.year &&
            selectedDate!.month == date.month &&
            selectedDate!.day == date.day) {
          canvas.drawRRect(rrect, strokePaint);
        }
      }
    }
  }

  static String _getMonthAbbreviation(int month, bool isTr) {
    if (isTr) {
      switch (month) {
        case 1: return 'Oca';
        case 2: return 'Şub';
        case 3: return 'Mar';
        case 4: return 'Nis';
        case 5: return 'May';
        case 6: return 'Haz';
        case 7: return 'Tem';
        case 8: return 'Ağu';
        case 9: return 'Eyl';
        case 10: return 'Eki';
        case 11: return 'Kas';
        case 12: return 'Ara';
        default: return '';
      }
    } else {
      switch (month) {
        case 1: return 'Jan';
        case 2: return 'Feb';
        case 3: return 'Mar';
        case 4: return 'Apr';
        case 5: return 'May';
        case 6: return 'Jun';
        case 7: return 'Jul';
        case 8: return 'Aug';
        case 9: return 'Sep';
        case 10: return 'Oct';
        case 11: return 'Nov';
        case 12: return 'Dec';
        default: return '';
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapCustomPainter oldDelegate) {
    return oldDelegate.contributionData != contributionData ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isTurkish != isTurkish ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.step != step ||
        oldDelegate.startX != startX ||
        oldDelegate.startY != startY;
  }
}
