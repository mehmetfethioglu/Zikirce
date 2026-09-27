import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/dashboard_providers.dart';
import 'zikir_distribution_sheet.dart';

class ZikirDistributionDonut extends ConsumerWidget {
  final VoidCallback? onTap;

  const ZikirDistributionDonut({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = ref.watch(zikirDistributionProvider);

    return InkWell(
      onTap: onTap ?? () => ZikirDistributionSheet.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.borderStroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row with Title and Expand/Detail Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.bismillahDistributionTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Modern Donut Chart
            Center(
              child: SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(108, 108),
                      painter: _ModernDonutPainter(
                        items: items,
                        isDark: isDark,
                        emptyColor: colors.headerBackground,
                      ),
                    ),

                    // Center Zikirce Logo Badge
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.headerBackground,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : colors.borderStroke.withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipOval(
                          child: Image.asset(
                            AppAssets.logo,
                            width: 44,
                            height: 44,
                            cacheWidth: 100,
                            cacheHeight: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.pie_chart_rounded,
                              size: 22,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (items.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: items.first.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${items.first.name} (%${items.first.percentage.toStringAsFixed(0)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ModernDonutPainter extends CustomPainter {
  final List<ZikirDistributionItem> items;
  final bool isDark;
  final Color emptyColor;

  _ModernDonutPainter({
    required this.items,
    required this.isDark,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 15.0;
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // If no items with counts, draw sleek empty background track
    if (items.isEmpty) {
      final trackPaint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, trackPaint);
      return;
    }

    // Draw subtle track behind
    final bgTrackPaint = Paint()
      ..color = emptyColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgTrackPaint);

    double startAngle = -pi / 2;
    const gapAngle = 0.05; // Gap between slices

    for (final item in items) {
      final sweepAngle = max(0.02, (item.ratio * 2 * pi) - gapAngle);

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      startAngle += item.ratio * 2 * pi;
    }
  }

  @override
  bool shouldRepaint(covariant _ModernDonutPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.isDark != isDark ||
        oldDelegate.emptyColor != emptyColor;
  }
}
