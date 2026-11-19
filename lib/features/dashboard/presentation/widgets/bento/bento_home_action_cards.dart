import 'dart:math';
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
    final isInfinite = ref.watch(
      zikirQuickSettingsProvider.select((s) => s.isInfiniteMode),
    );
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
                    color: colors.accent.withValues(alpha: isDark ? 0.11 : 0.06),
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
                      item: items[index],
                      isInfiniteMode: isInfinite,
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
                      SizedBox(height: 172, child: pageView),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 2),
                      child: _ZikirSwipeDotsIndicator(
                        key: const Key('favorite_zikir_dots_indicator'),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 14,
              color: onPrevious != null
                  ? colors.secondaryTextAlt
                  : colors.secondaryTextAlt.withValues(alpha: 0.28),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (idx) {
            final isSelected = idx == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectIndex(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 14 : 5,
                  height: 5,
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
        const SizedBox(width: 2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onNext,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 14,
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

class _FavoriteZikirPageSlide extends ConsumerWidget {
  final FavoriteZikirCardItem item;
  final bool isInfiniteMode;
  final String arabicFontFamily;
  final bool isBoldArabic;
  final bool highlightDivine;

  const _FavoriteZikirPageSlide({
    required this.item,
    required this.isInfiniteMode,
    required this.arabicFontFamily,
    required this.isBoldArabic,
    required this.highlightDivine,
  });

  Future<void> _continueZikir(BuildContext context, WidgetRef ref) async {
    HapticService.selectionClick();
    await ref.read(selectedZikirIdProvider.notifier).select(item.id);
    if (context.mounted) {
      context.go('/zikir');
    }
  }

  double _resolveArabicFontSize(String text, bool isCompact) {
    final len = text.trim().length;
    final double base;
    if (len <= 24) {
      base = 23.0;
    } else if (len <= 55) {
      base = 19.5;
    } else {
      base = 16.5;
    }
    return isCompact ? (base * 0.84).clamp(14.5, 19.0) : base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final safeTarget = max(1, item.target);
    final progress = isInfiniteMode
        ? 1.0
        : (item.currentCount / safeTarget).clamp(0.0, 1.0);
    final countLabel = isInfiniteMode
        ? '${item.currentCount} ∞'
        : '${item.currentCount} / $safeTarget';
    final totalBadgeText = item.effectiveTotal > 0
        ? '${formatCompactNumber(item.effectiveTotal)} ${l10n.isTurkish ? 'kez' : 'x'}'
        : (l10n.isTurkish ? 'Yeni' : 'New');
    final activeFgColor = colors.activeNavIconColor == const Color(0xFF000000)
        ? Colors.black
        : Colors.white;
    final hasArabic = item.arabic.trim().isNotEmpty;
    final infoLine = l10n.isTurkish && item.virtueSummary.isNotEmpty
        ? item.virtueSummary
        : '${item.category} • ${l10n.isTurkish ? 'Hedef' : 'Target'}: $safeTarget';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.hasBoundedHeight && constraints.maxHeight < 155;
        final arabicFontSize = _resolveArabicFontSize(item.arabic, isCompact);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            isCompact ? 9 : 12,
            16,
            isCompact ? 2 : 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst satır: Zikir adı + kategori/aktif rozeti + toplam çekim
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (item.isActive) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isCompact ? 14.5 : 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primaryText,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (item.isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  l10n.isTurkish ? 'Aktif' : 'Active',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.accentText,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (!isCompact)
                          Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(
                        alpha: isDark ? 0.2 : 0.11,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      totalBadgeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: colors.accentText,
                      ),
                    ),
                  ),
                ],
              ),

              // Orta alan: Zikir metni (Arapça hat) ve kısa açıklama
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasArabic)
                          Text.rich(
                            TextSpan(
                              children: QuranWordHighlighter.buildHighlightedSpans(
                                rawText: item.arabic,
                                baseStyle: TextStyle(
                                  fontFamily: arabicFontFamily,
                                  fontSize: arabicFontSize,
                                  fontWeight: isBoldArabic
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  height: 1.4,
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
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: colors.zikirArabicColor,
                            ),
                          ),
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          infoLine,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.secondaryTextAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Alt satır: Solda ilerleme sayacı/çizgisi, sağ altta Zikre Başla butonu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          countLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor:
                                colors.primaryText.withValues(alpha: 0.08),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: Key('favorite_zikir_continue_${item.id}'),
                      onPressed: () => _continueZikir(context, ref),
                      style: TextButton.styleFrom(
                        backgroundColor: item.isActive
                            ? colors.accent
                            : colors.accent.withValues(alpha: 0.12),
                        foregroundColor:
                            item.isActive ? activeFgColor : colors.accent,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 15,
                          vertical: isCompact ? 7 : 9,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 16),
                      label: Text(
                        l10n.isTurkish ? 'Zikre Başla' : 'Start Dhikr',
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

    final center = Offset(size.width - 14, 14);
    canvas.drawCircle(center, 24, paint);
    canvas.drawCircle(center, 38, paint);
  }

  @override
  bool shouldRepaint(covariant _ZikirSlideOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
