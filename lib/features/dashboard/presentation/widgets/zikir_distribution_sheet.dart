import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/dashboard_providers.dart';

class ZikirDistributionSheet extends ConsumerStatefulWidget {
  const ZikirDistributionSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticService.selectionClick();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ZikirDistributionSheet(),
    );
  }

  @override
  ConsumerState<ZikirDistributionSheet> createState() => _ZikirDistributionSheetState();
}

class _ZikirDistributionSheetState extends ConsumerState<ZikirDistributionSheet> {
  int? _selectedIndex;

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final distributionItems = ref.watch(zikirDistributionProvider);
    final totalZikirAsync = ref.watch(totalZikirCountProvider);
    final totalZikir = totalZikirAsync.valueOrNull ?? 0;

    final selectedItem = (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < distributionItems.length)
        ? distributionItems[_selectedIndex!]
        : (distributionItems.isNotEmpty ? distributionItems.first : null);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // ----------------------------------------------------
          // Top Drag Handle & Header
          // ----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: colors.secondaryTextAlt.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.asset(
                          AppAssets.logo,
                          cacheWidth: 100,
                          cacheHeight: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.bismillahDistributionTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            distributionItems.isNotEmpty
                                ? (l10n.isTurkish
                                    ? '${_formatNumber(totalZikir)} zikir · ${distributionItems.length} farklı zikir'
                                    : '${_formatNumber(totalZikir)} dhikrs · ${distributionItems.length} types')
                                : (l10n.isTurkish
                                    ? 'Henüz zikir çekilmedi'
                                    : 'No dhikrs recorded yet'),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.secondaryTextAlt, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ----------------------------------------------------
          // Main Content Area
          // ----------------------------------------------------
          Flexible(
            child: distributionItems.isEmpty
                ? _buildEmptyState(context, colors, l10n)
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      // Interactive Donut Chart Container
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 210,
                            height: 210,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Donut Painter
                                CustomPaint(
                                  size: const Size(210, 210),
                                  painter: _InteractiveDonutPainter(
                                    items: distributionItems,
                                    selectedIndex: _selectedIndex,
                                    isDark: isDark,
                                  ),
                                ),

                                // Center Informational Badge
                                Container(
                                  width: 114,
                                  height: 114,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.cardBackground,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: selectedItem != null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: selectedItem.color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '%${selectedItem.percentage.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: selectedItem.color,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              selectedItem.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatNumber(selectedItem.totalCount),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: colors.accent,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              AppAssets.logo,
                                              width: 26,
                                              height: 26,
                                              cacheWidth: 80,
                                              cacheHeight: 80,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatNumber(totalZikir),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primaryText,
                                              ),
                                            ),
                                            Text(
                                              l10n.bismillahTotal,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: colors.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Section Title & Tap hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.isTurkish ? 'Zikir Detayları' : 'Dhikr Breakdown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.primaryText,
                            ),
                          ),
                          Text(
                            l10n.isTurkish ? 'Dokunarak vurgulayın' : 'Tap to highlight',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Zikir Breakdown List Items
                      ...List.generate(distributionItems.length, (index) {
                        final item = distributionItems[index];
                        final isSelected = _selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              HapticService.selectionClick();
                              setState(() {
                                if (_selectedIndex == index) {
                                  _selectedIndex = null;
                                } else {
                                  _selectedIndex = index;
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? item.color.withValues(alpha: 0.12)
                                    : colors.cardBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? item.color.withValues(alpha: 0.6)
                                      : colors.borderStroke,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Rank Index pill
                                      Container(
                                        width: 22,
                                        height: 22,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: item.color.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: item.color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Dot Indicator
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: item.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Zikir Name + Arabic text
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: colors.primaryText,
                                              ),
                                            ),
                                            if (item.arabic != null && item.arabic!.isNotEmpty)
                                              Text(
                                                item.arabic!,
                                                style: TextStyle(
                                                  fontFamily: ref.watch(arabicFontFamilyProvider),
                                                  fontSize: 12,
                                                  fontWeight: ref.watch(isBoldArabicProvider)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: colors.secondaryTextAlt,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Count & Percentage
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            item.formattedTotal,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: item.color,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: item.color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '%${item.percentage.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: item.color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Linear progress track
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: item.ratio.clamp(0.0, 1.0),
                                      backgroundColor: colors.headerBackground,
                                      valueColor: AlwaysStoppedAnimation<Color>(item.color),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          ),

          // ----------------------------------------------------
          // Bottom Close Button (MAUI exact parity)
          // ----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.bismillahClose,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildEmptyState(BuildContext context, dynamic colors, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.headerBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              size: 36,
              color: colors.secondaryTextAlt,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.bismillahNoHistory,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.bismillahNoHistoryDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.touch_app_rounded, size: 18),
            label: Text(l10n.isTurkish ? 'Zikir Çekmeye Başla' : 'Start Dhikr'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveDonutPainter extends CustomPainter {
  final List<ZikirDistributionItem> items;
  final int? selectedIndex;
  final bool isDark;

  _InteractiveDonutPainter({
    required this.items,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (min(size.width, size.height) - 40) / 2;

    double startAngle = -pi / 2;
    const gapAngle = 0.045; // Gap between slices

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = selectedIndex == i;
      final sweepAngle = max(0.01, (item.ratio * 2 * pi) - gapAngle);

      final strokeWidth = isSelected ? 26.0 : 20.0;
      final radius = isSelected ? baseRadius + 2.0 : baseRadius;

      // Glow effect for selected item
      if (isSelected) {
        final glowPaint = Paint()
          ..color = item.color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + (gapAngle / 2),
          sweepAngle,
          false,
          glowPaint,
        );
      }

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
  bool shouldRepaint(covariant _InteractiveDonutPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.items != items ||
        oldDelegate.isDark != isDark;
  }
}
