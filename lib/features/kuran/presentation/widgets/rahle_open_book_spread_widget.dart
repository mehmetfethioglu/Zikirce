import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/tv_focusable.dart';

/// Rahle üzerindeki tek bir yaprağın (Sol veya Sağ yaprak) veri modeli.
class RahleSpreadLeafData {
  final int pageNumber;
  final int leafIndex;
  final int totalLeavesForPage;
  final String headerTitle;
  final String subtitle;
  final String arabicText;
  final String bodyText;
  final String footerReference;

  const RahleSpreadLeafData({
    required this.pageNumber,
    this.leafIndex = 1,
    this.totalLeavesForPage = 1,
    this.headerTitle = '',
    this.subtitle = '',
    this.arabicText = '',
    this.bodyText = '',
    this.footerReference = '',
  });

  bool get isMultiLeaf => totalLeavesForPage > 1;

  String get leafBadgeLabel => totalLeavesForPage > 1
      ? 'Sayfa $pageNumber • Yaprak $leafIndex/$totalLeavesForPage'
      : 'Sayfa $pageNumber';
}

/// Uzun bir veritabanı sayfasını paragraf ve cümle bütünlüğünü bozmadan
/// dikey kaydırma (scroll) gerektirmeyen Rahle yapraklarına bölen yardımcı sınıf.
class RahlePageTextChunker {
  const RahlePageTextChunker._();

  static List<RahleSpreadLeafData> chunkPage({
    required String turkishText,
    String arabicText = '',
    required int pageNumber,
    String headerTitle = '',
    String subtitle = '',
    String reference = '',
    int maxCharsPerLeaf = 920,
  }) {
    final cleanedTurkish = turkishText
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final cleanedArabic = arabicText.trim();

    final safeMaxChars = maxCharsPerLeaf.clamp(320, 2400);
    if (cleanedTurkish.isEmpty) {
      return <RahleSpreadLeafData>[
        RahleSpreadLeafData(
          pageNumber: pageNumber,
          leafIndex: 1,
          totalLeavesForPage: 1,
          headerTitle: headerTitle,
          subtitle: subtitle,
          arabicText: cleanedArabic,
          bodyText: '',
          footerReference: reference,
        ),
      ];
    }

    // İlk yaprakta Arapça metin varsa Türkçe metin kapasitesini dengeli şekilde azalt
    final firstLeafCapacity = cleanedArabic.isNotEmpty
        ? (safeMaxChars - (cleanedArabic.length * 0.55).round())
            .clamp(340, safeMaxChars)
        : safeMaxChars;

    if (cleanedTurkish.length <= firstLeafCapacity) {
      return <RahleSpreadLeafData>[
        RahleSpreadLeafData(
          pageNumber: pageNumber,
          leafIndex: 1,
          totalLeavesForPage: 1,
          headerTitle: headerTitle,
          subtitle: subtitle,
          arabicText: cleanedArabic,
          bodyText: cleanedTurkish,
          footerReference: reference,
        ),
      ];
    }

    final chunks = <String>[];
    final paragraphs = cleanedTurkish.split(RegExp(r'\n\s*\n'));
    final currentBuffer = StringBuffer();

    int currentCapacity() =>
        chunks.isEmpty ? firstLeafCapacity : safeMaxChars;

    void flushCurrent() {
      final text = currentBuffer.toString().trim();
      if (text.isNotEmpty) {
        chunks.add(text);
      }
      currentBuffer.clear();
    }

    for (final rawPara in paragraphs) {
      final para = rawPara.trim();
      if (para.isEmpty) continue;

      final cap = currentCapacity();
      final candidateLen = currentBuffer.isEmpty
          ? para.length
          : currentBuffer.length + 2 + para.length;

      if (candidateLen <= cap) {
        if (currentBuffer.isNotEmpty) {
          currentBuffer.write('\n\n');
        }
        currentBuffer.write(para);
        continue;
      }

      // Paragraf mevcut yaprağa sığmıyorsa cümle bazında böl
      final sentences = _splitIntoSentences(para);
      for (final sentence in sentences) {
        final s = sentence.trim();
        if (s.isEmpty) continue;

        final activeCap = currentCapacity();
        if (s.length > activeCap) {
          // Çok uzun tek cümleyi kelime bütünlüğünü koruyarak böl
          final words = s.split(RegExp(r'\s+'));
          for (final word in words) {
            final wCap = currentCapacity();
            final nextLen = currentBuffer.isEmpty
                ? word.length
                : currentBuffer.length + 1 + word.length;
            if (nextLen > wCap && currentBuffer.isNotEmpty) {
              flushCurrent();
            }
            if (currentBuffer.isNotEmpty) {
              currentBuffer.write(' ');
            }
            currentBuffer.write(word);
          }
          continue;
        }

        final nextLen = currentBuffer.isEmpty
            ? s.length
            : currentBuffer.length + 1 + s.length;
        if (nextLen > activeCap && currentBuffer.isNotEmpty) {
          flushCurrent();
        }
        if (currentBuffer.isNotEmpty) {
          currentBuffer.write(' ');
        }
        currentBuffer.write(s);
      }

      if (currentBuffer.isNotEmpty &&
          currentBuffer.length >= (currentCapacity() * 0.82).round()) {
        flushCurrent();
      } else if (currentBuffer.isNotEmpty) {
        currentBuffer.write('\n\n');
      }
    }

    flushCurrent();

    if (chunks.isEmpty) {
      chunks.add(cleanedTurkish);
    }

    final total = chunks.length;
    return List<RahleSpreadLeafData>.generate(total, (index) {
      return RahleSpreadLeafData(
        pageNumber: pageNumber,
        leafIndex: index + 1,
        totalLeavesForPage: total,
        headerTitle: headerTitle,
        subtitle: subtitle,
        arabicText: index == 0 ? cleanedArabic : '',
        bodyText: chunks[index],
        footerReference: reference,
      );
    });
  }

  /// Konumsal (positional) çağrılar için yardımcı sarmalayıcı
  static List<RahleSpreadLeafData> split(
    String turkishText,
    String arabicText,
    int pageNumber,
    String headerTitle,
    String subtitle,
    String reference, {
    int maxCharsPerLeaf = 920,
  }) {
    return chunkPage(
      turkishText: turkishText,
      arabicText: arabicText,
      pageNumber: pageNumber,
      headerTitle: headerTitle,
      subtitle: subtitle,
      reference: reference,
      maxCharsPerLeaf: maxCharsPerLeaf,
    );
  }

  static List<String> _splitIntoSentences(String paragraph) {
    final matches = RegExp(r'[^.!?…]+[.!?…]*\s*').allMatches(paragraph);
    final result = <String>[];
    for (final m in matches) {
      final part = m.group(0)?.trim() ?? '';
      if (part.isNotEmpty) {
        result.add(part);
      }
    }
    return result.isEmpty ? <String>[paragraph] : result;
  }
}

/// Bir [RahleSpreadLeafData] nesnesini dikey kaydırma olmadan,
/// yüksekliğe göre otomatik ölçeklenen tipografi ve Osmanlı serlevhasıyla çizen bileşen.
class RahleAutoFitLeafContent extends StatelessWidget {
  final RahleSpreadLeafData leaf;
  final Color paperColor;
  final Color inkColor;
  final Color accentColor;
  final bool isDark;
  final double baseFontSize;
  final String arabicFontFamily;

  const RahleAutoFitLeafContent({
    super.key,
    required this.leaf,
    this.paperColor = const Color(0xFFF6EFE0),
    this.inkColor = const Color(0xFF231911),
    this.accentColor = const Color(0xFFC59B27),
    this.isDark = false,
    this.baseFontSize = 19.0,
    this.arabicFontFamily = 'AmasyaAbay',
  });

  double _computeOptimalFontSize({
    required double maxWidth,
    required double maxHeight,
    required int charCount,
    required bool hasArabic,
  }) {
    if (charCount <= 0) return baseFontSize;
    final area = (maxWidth * maxHeight).clamp(40000.0, 1200000.0);
    final density = area / charCount.clamp(120, 1800);
    final rawSize = math.sqrt(density) * 0.44;
    final minSize = hasArabic ? 13.5 : 14.0;
    final maxSize = (baseFontSize + 5.0).clamp(18.0, 26.0);
    return rawSize.clamp(minSize, maxSize);
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = leaf.headerTitle.trim().isNotEmpty ||
        leaf.subtitle.trim().isNotEmpty;
    final hasArabic = leaf.arabicText.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) ...[
            _RahleOttomanHeaderBanner(
              title: leaf.headerTitle,
              subtitle: leaf.subtitle,
              leafIndex: leaf.leafIndex,
              totalLeaves: leaf.totalLeavesForPage,
              accentColor: accentColor,
              inkColor: inkColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (hasArabic) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.10 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.1,
                ),
              ),
              child: Text(
                leaf.arabicText,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: arabicFontFamily,
                  fontSize: (baseFontSize + 6).clamp(20.0, 30.0),
                  height: 1.75,
                  color: inkColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fontSize = _computeOptimalFontSize(
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  charCount: leaf.bodyText.length,
                  hasArabic: hasArabic,
                );
                return Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    leaf.bodyText,
                    textAlign: TextAlign.justify,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.56,
                      color: inkColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _RahleLeafFooterBar(
            leaf: leaf,
            accentColor: accentColor,
            inkColor: inkColor,
          ),
        ],
      ),
    );
  }
}

class _RahleOttomanHeaderBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final int leafIndex;
  final int totalLeaves;
  final Color accentColor;
  final Color inkColor;
  final bool isDark;

  const _RahleOttomanHeaderBanner({
    required this.title,
    required this.subtitle,
    required this.leafIndex,
    required this.totalLeaves,
    required this.accentColor,
    required this.inkColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
            accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
            accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.48),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 15,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.trim().isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: inkColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: inkColor.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (totalLeaves > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$leafIndex/$totalLeaves',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: inkColor,
                ),
              ),
            )
          else
            Icon(
              Icons.auto_awesome,
              size: 15,
              color: accentColor,
            ),
        ],
      ),
    );
  }
}

class _RahleLeafFooterBar extends StatelessWidget {
  final RahleSpreadLeafData leaf;
  final Color accentColor;
  final Color inkColor;

  const _RahleLeafFooterBar({
    required this.leaf,
    required this.accentColor,
    required this.inkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leaf.footerReference.trim().isNotEmpty)
          Expanded(
            child: Text(
              leaf.footerReference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: inkColor.withValues(alpha: 0.68),
              ),
            ),
          )
        else
          const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Text(
            leaf.leafBadgeLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: inkColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sedef kakmalı ahşap rahle üzerinde tam ekranda açık duran çift yaprak (Sol Yaprak + Sağ Yaprak)
/// görünümü ve Android TV Kumandası (D-Pad + OK) etkileşim sarmalayıcısı.
class RahleOpenBookSpreadWidget extends StatefulWidget {
  final Widget leftLeaf;
  final Widget rightLeaf;
  final String bookTitle;
  final String spreadSubtitle;
  final Color paperColor;
  final Color inkColor;
  final Color accentColor;
  final Color leatherColor;
  final bool isDark;
  final bool isRtl;
  final VoidCallback? onPreviousSpread;
  final VoidCallback? onNextSpread;
  final VoidCallback? onOpenTableOfContents;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onExit;
  final bool isBookmarked;

  const RahleOpenBookSpreadWidget({
    super.key,
    required this.leftLeaf,
    required this.rightLeaf,
    required this.bookTitle,
    required this.spreadSubtitle,
    this.paperColor = const Color(0xFFF6EFE0),
    this.inkColor = const Color(0xFF231911),
    this.accentColor = const Color(0xFFC59B27),
    this.leatherColor = const Color(0xFF3A1F14),
    this.isDark = false,
    this.isRtl = false,
    this.onPreviousSpread,
    this.onNextSpread,
    this.onOpenTableOfContents,
    this.onToggleBookmark,
    this.onOpenSettings,
    this.onExit,
    this.isBookmarked = false,
  });

  @override
  State<RahleOpenBookSpreadWidget> createState() =>
      _RahleOpenBookSpreadWidgetState();
}

class _RahleOpenBookSpreadWidgetState extends State<RahleOpenBookSpreadWidget> {
  late final FocusNode _spreadFocusNode;
  bool _showHud = true;
  int _turnDirection = 1; // 1: ileri, -1: geri

  @override
  void initState() {
    super.initState();
    _spreadFocusNode = FocusNode(debugLabel: 'RahleOpenBookSpreadFocus');
  }

  @override
  void dispose() {
    _spreadFocusNode.dispose();
    super.dispose();
  }

  void _triggerPrevious() {
    if (widget.onPreviousSpread == null) return;
    HapticFeedback.selectionClick();
    setState(() => _turnDirection = -1);
    widget.onPreviousSpread!();
  }

  void _triggerNext() {
    if (widget.onNextSpread == null) return;
    HapticFeedback.selectionClick();
    setState(() => _turnDirection = 1);
    widget.onNextSpread!();
  }

  void _toggleHud() {
    HapticFeedback.lightImpact();
    setState(() => _showHud = !_showHud);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (widget.isRtl) {
        _triggerNext();
      } else {
        _triggerPrevious();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (widget.isRtl) {
        _triggerPrevious();
      } else {
        _triggerNext();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _toggleHud();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.onOpenTableOfContents != null) {
        HapticFeedback.selectionClick();
        widget.onOpenTableOfContents!();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.onOpenSettings != null) {
        HapticFeedback.selectionClick();
        widget.onOpenSettings!();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (widget.onExit != null) {
        widget.onExit!();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _spreadFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleHud,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: widget.isDark
                  ? const [
                      Color(0xFF1A1410),
                      Color(0xFF0C0907),
                    ]
                  : const [
                      Color(0xFF2C1D14),
                      Color(0xFF150D09),
                    ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Ana Rahle + Açık Kitap Çift Yaprak Alanı
                Positioned.fill(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      _showHud ? 68 : 18,
                      24,
                      _showHud ? 76 : 22,
                    ),
                    child: CustomPaint(
                      painter: _RahleWoodAndBindingPainter(
                        paperColor: widget.paperColor,
                        accentColor: widget.accentColor,
                        leatherColor: widget.leatherColor,
                        isDark: widget.isDark,
                        isBookmarked: widget.isBookmarked,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 20, 30, 26),
                        child: PhysicalBookSpreadTurnTransition(
                          spreadKey: widget.spreadSubtitle,
                          leftLeaf: widget.leftLeaf,
                          rightLeaf: widget.rightLeaf,
                          paperColor: widget.paperColor,
                          accentColor: widget.accentColor,
                          isRtl: widget.isRtl,
                          turnDirection: _turnDirection,
                          spineGap: 28,
                        ),
                      ),
                    ),
                  ),
                ),

                // Üst HUD Çubuğu (Kitap Adı, Sayfa/İlerleme ve Hızlı Aksiyonlar)
                Positioned(
                  top: 8,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    ignoring: !_showHud,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showHud ? 1.0 : 0.0,
                      child: _buildTopHudBar(),
                    ),
                  ),
                ),

                // Alt HUD Çubuğu (Kumanda Tuş İpuçları ve Sayfa Çevirme Butonları)
                Positioned(
                  bottom: 8,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    ignoring: !_showHud,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showHud ? 1.0 : 0.0,
                      child: _buildBottomHudBar(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHudBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF140E0A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (widget.onExit != null) ...[
            TvFocusable(
              onPressed: widget.onExit,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: widget.accentColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Kitaplığa Dön',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDF8EE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Icon(
            Icons.menu_book_rounded,
            size: 20,
            color: widget.accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFDF8EE),
                  ),
                ),
                Text(
                  widget.spreadSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onOpenTableOfContents != null) ...[
            TvFocusable(
              onPressed: widget.onOpenTableOfContents,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 17,
                    color: widget.accentColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'İçindekiler (▲)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDF8EE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onToggleBookmark != null) ...[
            TvFocusable(
              onPressed: widget.onToggleBookmark,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: widget.isBookmarked
                        ? const Color(0xFFE53935)
                        : widget.accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isBookmarked ? 'Ayraçlı' : 'Ayraç Ekle',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDF8EE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onOpenSettings != null)
            TvFocusable(
              onPressed: widget.onOpenSettings,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: widget.accentColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Görünüm (▼)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDF8EE),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomHudBar() {
    final leftLabel =
        widget.isRtl ? '▶ Sonraki Çift Sayfa' : '◀ Önceki Çift Sayfa';
    final rightLabel =
        widget.isRtl ? '◀ Önceki Çift Sayfa' : '▶ Sonraki Çift Sayfa';
    final leftAction = widget.isRtl ? _triggerNext : _triggerPrevious;
    final rightAction = widget.isRtl ? _triggerPrevious : _triggerNext;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF140E0A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.40),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TvFocusable(
            onPressed: leftAction,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              '[$leftLabel]',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: widget.accentColor,
              ),
            ),
          ),
          const Flexible(
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _RemoteKeyHintBadge(label: '[OK Araç Çubuğu]'),
                _RemoteKeyHintBadge(label: '[▲ İçindekiler]'),
                _RemoteKeyHintBadge(label: '[▼ Yazı & Tema]'),
                _RemoteKeyHintBadge(label: '[0-9 Sayfaya Atla]'),
              ],
            ),
          ),
          TvFocusable(
            onPressed: rightAction,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              '[$rightLabel]',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: widget.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteKeyHintBadge extends StatelessWidget {
  final String label;

  const _RemoteKeyHintBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEAE0D0),
        ),
      ),
    );
  }
}

/// Ceviz/abanoz ahşap rahle kanatları, sedef kakma geometrik köşe motifleri,
/// deri cilt payı, katmanlı kitap yaprakları, orta cilt oluğu gölgesi (central spine shadow)
/// ve üstten sarkan kırmızı/altın ipek kitap ayracı kurdelesini çizen CustomPainter.
class _RahleWoodAndBindingPainter extends CustomPainter {
  final Color paperColor;
  final Color accentColor;
  final Color leatherColor;
  final bool isDark;
  final bool isBookmarked;

  const _RahleWoodAndBindingPainter({
    required this.paperColor,
    required this.accentColor,
    required this.leatherColor,
    required this.isDark,
    required this.isBookmarked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w * 0.5;

    // 1. Alt Ahşap Rahle Kaidesi ve Ceviz Kanatlar
    final woodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 4, w, h - 4),
      const Radius.circular(22),
    );
    final woodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3E2415),
          Color(0xFF26140B),
          Color(0xFF472918),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(woodRect, woodPaint);

    // Sedef Kakma (Mother-of-Pearl) Köşe Motifleri
    _drawMotherOfPearlCorner(canvas, const Offset(16, 18));
    _drawMotherOfPearlCorner(canvas, Offset(w - 16, 18));
    _drawMotherOfPearlCorner(canvas, Offset(16, h - 18));
    _drawMotherOfPearlCorner(canvas, Offset(w - 16, h - 18));

    // 2. Klasik Deri Cilt Payı (Leather Binding)
    final leatherRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 8, w - 20, h - 18),
      const Radius.circular(18),
    );
    final leatherPaint = Paint()..color = leatherColor;
    canvas.drawRRect(leatherRect, leatherPaint);

    // Deri Cilt Üzeri Altın Tezhip Cetveli
    final goldBorderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 12, w - 28, h - 26),
        const Radius.circular(15),
      ),
      goldBorderPaint,
    );

    // 3. Katmanlı Kitap Yaprakları (Sol ve Sağ Dış Kenarlarda Sayfa Kalınlığı Efekti)
    final pageStackPaint = Paint()
      ..color = paperColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      final inset = 18.0 + (i * 2.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, 14 + (i * 1.0), w - (inset * 2), h - 30 - (i * 2.0)),
          const Radius.circular(13),
        ),
        pageStackPaint,
      );
    }

    // 4. Açık Kitap Kağıt Yüzeyi (Sol Yaprak + Sağ Yaprak)
    final spreadRect = Rect.fromLTWH(28, 16, w - 56, h - 36);
    final spreadRRect = RRect.fromRectAndRadius(
      spreadRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(spreadRRect, Paint()..color = paperColor);

    // Yaprak Çerçevesi (Tezhip İç Cetveli)
    final innerFramePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.35 : 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(34, 22, (w * 0.5) - 48, h - 48),
        const Radius.circular(8),
      ),
      innerFramePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w * 0.5) + 14, 22, (w * 0.5) - 48, h - 48),
        const Radius.circular(8),
      ),
      innerFramePaint,
    );

    // 5. Orta Cilt Oluğu Gölgesi (Central Spine Shadow Gradient)
    final spineShadowRect = Rect.fromLTWH(
      centerX - 26,
      spreadRect.top,
      52,
      spreadRect.height,
    );
    final spineShadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
          Colors.black.withValues(alpha: isDark ? 0.55 : 0.32),
          Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
          Colors.black.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
      ).createShader(spineShadowRect);
    canvas.drawRect(spineShadowRect, spineShadowPaint);

    // Orta Cilt Dikiş İzi
    final spineLinePaint = Paint()
      ..color = leatherColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(centerX, spreadRect.top),
      Offset(centerX, spreadRect.bottom),
      spineLinePaint,
    );

    // 6. Üstten Sarkan Kırmızı / Altın İpek Kitap Ayracı Kurdelesi
    final ribbonHeight = isBookmarked ? h * 0.32 : h * 0.14;
    final ribbonPath = Path()
      ..moveTo(centerX - 6, spreadRect.top - 4)
      ..lineTo(centerX + 6, spreadRect.top - 4)
      ..lineTo(centerX + 6, spreadRect.top + ribbonHeight)
      ..lineTo(centerX, spreadRect.top + ribbonHeight - 9)
      ..lineTo(centerX - 6, spreadRect.top + ribbonHeight)
      ..close();

    final ribbonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFB71C1C),
          Color(0xFFD32F2F),
          Color(0xFF8E0000),
        ],
      ).createShader(
        Rect.fromLTWH(centerX - 6, spreadRect.top - 4, 12, ribbonHeight + 4),
      );
    canvas.drawPath(ribbonPath, ribbonPaint);

    final ribbonGoldBorder = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(ribbonPath, ribbonGoldBorder);
  }

  void _drawMotherOfPearlCorner(Canvas canvas, Offset center) {
    final pearlPaint = Paint()
      ..color = const Color(0xFFF3EFE6).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..lineTo(center.dx + 5, center.dy)
      ..lineTo(center.dx, center.dy + 5)
      ..lineTo(center.dx - 5, center.dy)
      ..close();
    canvas.drawPath(path, pearlPaint);
  }

  @override
  bool shouldRepaint(covariant _RahleWoodAndBindingPainter oldDelegate) {
    return oldDelegate.paperColor != paperColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.leatherColor != leatherColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isBookmarked != isBookmarked;
  }
}

/// Rahlede açık duran çift yapraklı kitabın (Sol Yaprak + Sağ Yaprak)
/// orta sırt (cilt oluğu) ekseninde gerçek 3B fiziki sayfa çevirme (3D Page Turn / Curl)
/// animasyonunu yürüten bileşen.
class PhysicalBookSpreadTurnTransition extends StatefulWidget {
  final String spreadKey;
  final Widget leftLeaf;
  final Widget rightLeaf;
  final Color paperColor;
  final Color accentColor;
  final bool isRtl;
  final int turnDirection; // 1: ileri, -1: geri
  final double spineGap;

  const PhysicalBookSpreadTurnTransition({
    super.key,
    required this.spreadKey,
    required this.leftLeaf,
    required this.rightLeaf,
    this.paperColor = const Color(0xFFF6EFE0),
    this.accentColor = const Color(0xFFC59B27),
    this.isRtl = false,
    this.turnDirection = 1,
    this.spineGap = 28.0,
  });

  @override
  State<PhysicalBookSpreadTurnTransition> createState() =>
      _PhysicalBookSpreadTurnTransitionState();
}

class _PhysicalBookSpreadTurnTransitionState
    extends State<PhysicalBookSpreadTurnTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  Widget? _prevLeftLeaf;
  Widget? _prevRightLeaf;
  int _activeDirection = 1;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
  }

  @override
  void didUpdateWidget(covariant PhysicalBookSpreadTurnTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spreadKey != widget.spreadKey) {
      _prevLeftLeaf = oldWidget.leftLeaf;
      _prevRightLeaf = oldWidget.rightLeaf;
      _activeDirection = widget.turnDirection;
      _flipController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, _) {
        final isFlipping = _flipController.isAnimating &&
            _prevLeftLeaf != null &&
            _prevRightLeaf != null;

        if (!isFlipping) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: widget.leftLeaf,
                ),
              ),
              SizedBox(width: widget.spineGap),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: widget.rightLeaf,
                ),
              ),
            ],
          );
        }

        final rawT = _flipController.value.clamp(0.0, 1.0);
        final t = Curves.easeInOutCubic.transform(rawT);
        // LTR'de ileri (+1): Sağ yaprak kalkıp sola kapanır.
        // RTL'de ileri (+1): Sol yaprak kalkıp sağa kapanır.
        final flipRightToLeft =
            widget.isRtl ? (_activeDirection < 0) : (_activeDirection >= 0);

        // Alt zemin yaprakları (kalkan yaprağın altından yeni yaprak görünür)
        final baseLeft = flipRightToLeft ? _prevLeftLeaf! : widget.leftLeaf;
        final baseRight = flipRightToLeft ? widget.rightLeaf : _prevRightLeaf!;

        // Alt yaprakların üzerine düşen dinamik sayfa gölgesi
        final leftUnderShadowAlpha = flipRightToLeft
            ? ((t - 0.35).clamp(0.0, 0.65) * 0.42)
            : ((1.0 - t) * 0.28);
        final rightUnderShadowAlpha = flipRightToLeft
            ? ((1.0 - t) * 0.28)
            : ((t - 0.35).clamp(0.0, 0.65) * 0.42);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Alt Sabit Yapraklar + Düşen Gölge Katmanı
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        baseLeft,
                        if (leftUnderShadowAlpha > 0.01)
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(
                                        alpha: leftUnderShadowAlpha * 0.45),
                                    Colors.black.withValues(
                                        alpha: leftUnderShadowAlpha),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: widget.spineGap),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        baseRight,
                        if (rightUnderShadowAlpha > 0.01)
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(
                                        alpha: rightUnderShadowAlpha),
                                    Colors.black.withValues(
                                        alpha: rightUnderShadowAlpha * 0.45),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. Orta Sırt (Cilt) Ekseninde Dönen 3B Fiziki Yaprak
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol Yarı (t > 0.5 iken sağdan sola geçen yaprak buraya iner veya t <= 0.5 iken soldan sağa kalkan yaprak buradan kalkar)
                Expanded(
                  child: _buildLeftHalfFlippingLeaf(
                    t: t,
                    flipRightToLeft: flipRightToLeft,
                  ),
                ),
                SizedBox(width: widget.spineGap),
                // Sağ Yarı (t <= 0.5 iken sağdan sola kalkan yaprak buradan kalkar veya t > 0.5 iken soldan sağa geçen yaprak buraya iner)
                Expanded(
                  child: _buildRightHalfFlippingLeaf(
                    t: t,
                    flipRightToLeft: flipRightToLeft,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftHalfFlippingLeaf({
    required double t,
    required bool flipRightToLeft,
  }) {
    if (flipRightToLeft) {
      // Sağdan sola çevriliyorken ikinci yarıda (t > 0.5) yeni sol yaprak orta sırttan sola doğru iner
      if (t <= 0.5) return const SizedBox.shrink();
      final localProgress = (t - 0.5) * 2.0; // 0.0 -> 1.0
      final angle = -(1.0 - localProgress) * (math.pi / 2.0);
      final curlShadow = (1.0 - localProgress) * 0.35;

      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateY(angle);

      return Transform(
        alignment: Alignment.centerRight,
        transform: matrix,
        child: _buildTurningPaperSheet(
          isLeftHalf: true,
          curlShadowAlpha: curlShadow,
          child: widget.leftLeaf,
        ),
      );
    } else {
      // Soldan sağa çevriliyorken ilk yarıda (t <= 0.5) eski sol yaprak orta sırttan sağa doğru kalkar
      if (t > 0.5) return const SizedBox.shrink();
      final localProgress = t * 2.0; // 0.0 -> 1.0
      final angle = -localProgress * (math.pi / 2.0);
      final curlShadow = localProgress * 0.35;

      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateY(angle);

      return Transform(
        alignment: Alignment.centerRight,
        transform: matrix,
        child: _buildTurningPaperSheet(
          isLeftHalf: true,
          curlShadowAlpha: curlShadow,
          child: _prevLeftLeaf!,
        ),
      );
    }
  }

  Widget _buildRightHalfFlippingLeaf({
    required double t,
    required bool flipRightToLeft,
  }) {
    if (flipRightToLeft) {
      // Sağdan sola çevriliyorken ilk yarıda (t <= 0.5) eski sağ yaprak orta sırttan sola doğru kalkar
      if (t > 0.5) return const SizedBox.shrink();
      final localProgress = t * 2.0; // 0.0 -> 1.0
      final angle = localProgress * (math.pi / 2.0);
      final curlShadow = localProgress * 0.35;

      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateY(angle);

      return Transform(
        alignment: Alignment.centerLeft,
        transform: matrix,
        child: _buildTurningPaperSheet(
          isLeftHalf: false,
          curlShadowAlpha: curlShadow,
          child: _prevRightLeaf!,
        ),
      );
    } else {
      // Soldan sağa çevriliyorken ikinci yarıda (t > 0.5) yeni sağ yaprak orta sırttan sağa doğru iner
      if (t <= 0.5) return const SizedBox.shrink();
      final localProgress = (t - 0.5) * 2.0; // 0.0 -> 1.0
      final angle = (1.0 - localProgress) * (math.pi / 2.0);
      final curlShadow = (1.0 - localProgress) * 0.35;

      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0014)
        ..rotateY(angle);

      return Transform(
        alignment: Alignment.centerLeft,
        transform: matrix,
        child: _buildTurningPaperSheet(
          isLeftHalf: false,
          curlShadowAlpha: curlShadow,
          child: widget.rightLeaf,
        ),
      );
    }
  }

  Widget _buildTurningPaperSheet({
    required bool isLeftHalf,
    required double curlShadowAlpha,
    required Widget child,
  }) {
    final radius = isLeftHalf
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    return Container(
      decoration: BoxDecoration(
        color: widget.paperColor,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: Offset(isLeftHalf ? 6 : -6, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Fiziki kağıt bükülme ışık ve gölge gradyanı
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isLeftHalf
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: isLeftHalf
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    colors: [
                      Colors.white.withValues(alpha: curlShadowAlpha * 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: curlShadowAlpha),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
