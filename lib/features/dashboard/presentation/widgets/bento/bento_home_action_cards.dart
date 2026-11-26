import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/haptic_service.dart';
import '../../../../../core/theme/app_theme_colors.dart';
import '../../../../../core/utils/quran_word_highlighter.dart';
import '../../../../kuran/providers/kuran_providers.dart';
import '../../../../settings/providers/settings_provider.dart';
import '../../../../zikir/providers/zikir_providers.dart';
import '../../../providers/dashboard_providers.dart';

/// En çok çekilen zikirleri tek seferde 1 zikir kartı olacak şekilde kaydırılabilir sunan ana sayfa modülü.
class FavoriteZikirsCarouselCard extends ConsumerStatefulWidget {
  const FavoriteZikirsCarouselCard({super.key});

  @override
  ConsumerState<FavoriteZikirsCarouselCard> createState() =>
      _FavoriteZikirsCarouselCardState();
}

class _FavoriteZikirsCarouselCardState
    extends ConsumerState<FavoriteZikirsCarouselCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int index, int count) {
    if (index < 0 || index >= count || !_pageController.hasClients) return;
    HapticService.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = ref.watch(dashboardFavoriteZikirsProvider);
    final arabicFontFamily = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final highlightDivine = ref.watch(highlightDivineWordsProvider);

    final safePage = items.isEmpty ? 0 : _currentPage.clamp(0, items.length - 1);

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ZikirSlideOrnamentPainter(
                    color: colors.accent.withValues(
                      alpha: isDark ? 0.08 : 0.045,
                    ),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final hasBoundedHeight = constraints.hasBoundedHeight;
                if (items.isEmpty) {
                  return hasBoundedHeight
                      ? const Center(child: _EmptyZikirCarouselHint())
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: _EmptyZikirCarouselHint(),
                        );
                }

                final activeItem = items[safePage];
                final pageView = PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  onPageChanged: (idx) {
                    HapticService.selectionClick();
                    setState(() => _currentPage = idx);
                  },
                  itemBuilder: (context, index) {
                    return _FavoriteZikirPageSlide(
                      key: ValueKey('favorite_zikir_page_${items[index].id}'),
                      item: items[index],
                      arabicFontFamily: arabicFontFamily,
                      isBoldArabic: isBoldArabic,
                      highlightDivine: highlightDivine,
                    );
                  },
                );

                return Column(
                  mainAxisSize:
                      hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (hasBoundedHeight)
                      Expanded(child: pageView)
                    else
                      SizedBox(height: 130, child: pageView),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _FavoriteZikirBottomBar(
                        item: activeItem,
                        count: items.length,
                        currentIndex: safePage,
                        onPrevious: safePage > 0
                            ? () => _animateToPage(safePage - 1, items.length)
                            : null,
                        onNext: safePage < items.length - 1
                            ? () => _animateToPage(safePage + 1, items.length)
                            : null,
                        onSelectIndex: (idx) =>
                            _animateToPage(idx, items.length),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteZikirBottomBar extends StatelessWidget {
  final FavoriteZikirCardItem item;
  final int count;
  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onSelectIndex;

  const _FavoriteZikirBottomBar({
    required this.item,
    required this.count,
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FavoriteZikirTotalBadge(item: item),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _ZikirSwipeDotsIndicator(
                  key: const Key('favorite_zikir_dots_indicator'),
                  count: count,
                  currentIndex: currentIndex,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onSelectIndex: onSelectIndex,
                ),
              ),
            ),
          ),
        ),
        _FavoriteZikirStartButton(item: item),
      ],
    );
  }
}

class _FavoriteZikirTotalBadge extends StatelessWidget {
  final FavoriteZikirCardItem item;

  const _FavoriteZikirTotalBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBadgeText = item.effectiveTotal > 0
        ? '${formatCompactNumber(item.effectiveTotal)} ${l10n.isTurkish ? 'kez' : 'x'}'
        : (l10n.isTurkish ? 'Yeni' : 'New');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: Key('favorite_zikir_total_badge_${item.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: isDark ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          totalBadgeText,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: colors.accentText,
          ),
        ),
      ),
    );
  }
}

class _FavoriteZikirStartButton extends ConsumerWidget {
  final FavoriteZikirCardItem item;

  const _FavoriteZikirStartButton({required this.item});

  Future<void> _continueZikir(BuildContext context, WidgetRef ref) async {
    HapticService.selectionClick();
    try {
      await ref.read(selectedZikirIdProvider.notifier).select(item.id);
    } catch (e) {
      debugPrint('[FavoriteZikirsCarouselCard] Failed to select zikir: $e');
    }
    if (context.mounted) {
      context.go('/zikir');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFgColor = colors.activeNavIconColor == const Color(0xFF000000)
        ? Colors.black
        : Colors.white;

    return TextButton.icon(
      key: Key('favorite_zikir_continue_${item.id}'),
      onPressed: () => _continueZikir(context, ref),
      style: TextButton.styleFrom(
        backgroundColor: item.isActive
            ? colors.accent
            : colors.accent.withValues(alpha: isDark ? 0.22 : 0.12),
        foregroundColor: item.isActive ? activeFgColor : colors.accentText,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      icon: const Icon(Icons.fingerprint_rounded, size: 14),
      label: Text(
        l10n.isTurkish ? 'Zikre Başla' : 'Start Dhikr',
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _ZikirSwipeDotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onSelectIndex;

  const _ZikirSwipeDotsIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPrevious,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 13,
              color: onPrevious != null
                  ? colors.secondaryTextAlt
                  : colors.secondaryTextAlt.withValues(alpha: 0.28),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (idx) {
            final isSelected = idx == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectIndex(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 12 : 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent
                        : colors.accent.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 1),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onNext,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 13,
              color: onNext != null
                  ? colors.secondaryTextAlt
                  : colors.secondaryTextAlt.withValues(alpha: 0.28),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyZikirCarouselHint extends StatelessWidget {
  const _EmptyZikirCarouselHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticService.selectionClick();
            context.go('/zikir');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.borderStroke),
            ),
            child: Row(
              children: [
                Icon(Icons.fingerprint_rounded, color: colors.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.isTurkish
                        ? 'İlk zikrine başlamak için zikirmatiği aç'
                        : 'Open dhikr counter to begin your first dhikr',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.secondaryTextAlt),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteZikirPageSlide extends StatefulWidget {
  final FavoriteZikirCardItem item;
  final String arabicFontFamily;
  final bool isBoldArabic;
  final bool highlightDivine;

  const _FavoriteZikirPageSlide({
    super.key,
    required this.item,
    required this.arabicFontFamily,
    required this.isBoldArabic,
    required this.highlightDivine,
  });

  @override
  State<_FavoriteZikirPageSlide> createState() =>
      _FavoriteZikirPageSlideState();
}

class _FavoriteZikirPageSlideState extends State<_FavoriteZikirPageSlide> {
  bool _showDescription = false;

  @override
  void didUpdateWidget(covariant _FavoriteZikirPageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id && _showDescription) {
      _showDescription = false;
    }
  }

  void _toggleDescription() {
    HapticService.selectionClick();
    setState(() => _showDescription = !_showDescription);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final descriptionText =
        l10n.isTurkish && widget.item.virtueSummary.trim().isNotEmpty
            ? widget.item.virtueSummary.trim()
            : '${widget.item.name} • ${widget.item.category}';

    return Semantics(
      button: true,
      label: _showDescription
          ? (l10n.isTurkish ? 'Zikrin Arapçasını göster' : 'Show Arabic text')
          : (l10n.isTurkish
              ? 'Zikir açıklamasını göster'
              : 'Show dhikr description'),
      child: GestureDetector(
        key: Key('favorite_zikir_slide_${widget.item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggleDescription,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final scale = Tween<double>(begin: 0.96, end: 1.0).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: _showDescription
              ? _ZikirDescriptionView(
                  key: ValueKey('favorite_zikir_description_${widget.item.id}'),
                  description: descriptionText,
                )
              : _ArabicCalligraphyFitBox(
                  key: ValueKey('favorite_zikir_arabic_${widget.item.id}'),
                  arabicText: widget.item.arabic,
                  fallbackName: widget.item.name,
                  arabicFontFamily: widget.arabicFontFamily,
                  isBoldArabic: widget.isBoldArabic,
                  highlightDivine: widget.highlightDivine,
                ),
        ),
      ),
    );
  }
}

class _ArabicCalligraphyFitBox extends StatelessWidget {
  final String arabicText;
  final String fallbackName;
  final String arabicFontFamily;
  final bool isBoldArabic;
  final bool highlightDivine;

  const _ArabicCalligraphyFitBox({
    super.key,
    required this.arabicText,
    required this.fallbackName,
    required this.arabicFontFamily,
    required this.isBoldArabic,
    required this.highlightDivine,
  });

  double _resolveBestArabicFontSize({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required int maxLines,
    required double maxFontSize,
    required TextScaler textScaler,
  }) {
    const double minFontSize = 14.0;
    final upper = maxFontSize < minFontSize ? minFontSize : maxFontSize;
    final formattedText =
        QuranWordHighlighter.formatArabicTextForFont(text, arabicFontFamily);
    final measureWidth = (maxWidth - 4).clamp(1.0, double.infinity);
    final measureHeight = (maxHeight - 4).clamp(1.0, double.infinity);

    double low = minFontSize;
    double high = upper;
    double best = minFontSize;

    for (int i = 0; i < 8; i++) {
      final mid = (low + high) * 0.5;
      final tp = TextPainter(
        text: TextSpan(
          text: formattedText,
          style: TextStyle(
            fontFamily: arabicFontFamily,
            fontSize: mid,
            fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
            height: 1.42,
            letterSpacing: -0.1,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        textScaler: textScaler,
      );
      bool fits = false;
      try {
        tp.layout(maxWidth: measureWidth);
        fits = !tp.didExceedMaxLines &&
            tp.height <= measureHeight &&
            tp.width <= (maxWidth - 3.5);
      } finally {
        tp.dispose();
      }
      if (fits) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trimmedArabic = arabicText.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 120;
        final topPad = constraints.maxHeight < 95 ? 6.0 : (isCompact ? 8.0 : 12.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(18, topPad, 18, 4),
          child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final availW = innerConstraints.maxWidth;
              final availH = innerConstraints.maxHeight;
              if (availW <= 0 || availH <= 0) {
                return const SizedBox.shrink();
              }

              if (trimmedArabic.isEmpty) {
                return Center(
                  child: Text(
                    fallbackName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (availH * 0.22).clamp(18.0, 28.0),
                      fontWeight: FontWeight.w700,
                      color: colors.zikirArabicColor,
                    ),
                  ),
                );
              }

              final wordCount = trimmedArabic
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .length;
              final len = trimmedArabic.length;

              final int maxLines;
              final double maxFontSize;
              if (len <= 28 && wordCount <= 3) {
                maxLines = 1;
                maxFontSize = (availH * 0.46).clamp(30.0, 56.0);
              } else if (len <= 52) {
                maxLines = 2;
                maxFontSize = (availH * 0.34).clamp(26.0, 44.0);
              } else if (len <= 105) {
                maxLines = 3;
                maxFontSize = (availH * 0.28).clamp(22.0, 36.0);
              } else {
                maxLines = 5;
                maxFontSize = (availH * 0.24).clamp(18.0, 30.0);
              }

              final fontSize = _resolveBestArabicFontSize(
                text: trimmedArabic,
                maxWidth: availW,
                maxHeight: availH,
                maxLines: maxLines,
                maxFontSize: maxFontSize,
                textScaler: MediaQuery.textScalerOf(context),
              );

              final richText = Text.rich(
                TextSpan(
                  children: QuranWordHighlighter.buildHighlightedSpans(
                    rawText: trimmedArabic,
                    baseStyle: TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: fontSize,
                      fontWeight:
                          isBoldArabic ? FontWeight.bold : FontWeight.normal,
                      height: 1.42,
                      letterSpacing: -0.1,
                      color: colors.zikirArabicColor,
                    ),
                    isDark: isDark,
                    enabled: highlightDivine,
                    fontFamily: arabicFontFamily,
                    isBold: isBoldArabic,
                  ),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              );

              return Center(
                child: maxLines == 1
                    ? FittedBox(fit: BoxFit.scaleDown, child: richText)
                    : richText,
              );
            },
          ),
        );
      },
    );
  }
}

class _ZikirDescriptionView extends StatelessWidget {
  final String description;

  const _ZikirDescriptionView({
    super.key,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 120;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(18, isCompact ? 8 : 12, 18, 6),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - (isCompact ? 14 : 18))
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 12.0 : 13.0,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: colors.primaryText.withValues(alpha: isDark ? 0.90 : 0.86),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ZikirSlideOrnamentPainter extends CustomPainter {
  final Color color;

  const _ZikirSlideOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final topRight = Offset(size.width - 14, 14);
    canvas.drawCircle(topRight, 24, paint);
    canvas.drawCircle(topRight, 38, paint);

    const topLeft = Offset(14, 14);
    canvas.drawCircle(topLeft, 28, paint);
  }

  @override
  bool shouldRepaint(covariant _ZikirSlideOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
