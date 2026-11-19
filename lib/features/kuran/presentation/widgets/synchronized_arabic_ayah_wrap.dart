import 'dart:collection';
import 'package:flutter/material.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../data/tilavet_secdesi_data.dart';
import 'zikirce_ayah_stop_marker.dart';

/// Parsed Arabic word token paired with any attached waqf stop glyphs.
class QuranAyahWordToken {
  final String pureWord;
  final List<String> stops;

  const QuranAyahWordToken({
    required this.pureWord,
    required this.stops,
  });
}

/// Bounded LRU-style parser/cache for splitting Quranic verses into word tokens
/// and waqf stops identically across UI rendering and audio synchronization.
class QuranAyahWordParser {
  QuranAyahWordParser._();

  static const int _maxCacheEntries = 64;
  static final LinkedHashMap<String, List<QuranAyahWordToken>> _cache =
      LinkedHashMap<String, List<QuranAyahWordToken>>();

  static List<QuranAyahWordToken> parse(String ayetText) {
    final cached = _cache.remove(ayetText);
    if (cached != null) {
      _cache[ayetText] = cached;
      return cached;
    }

    final normalized = QuranWordHighlighter.cleanArabicText(ayetText).trim();
    if (normalized.isEmpty) {
      return const <QuranAyahWordToken>[];
    }

    final rawWords = normalized.split(RegExp(r'\s+'));
    final result = <QuranAyahWordToken>[];

    for (final w in rawWords) {
      final cleanWord = w.trim();
      if (cleanWord.isEmpty) continue;

      final cleanWordBuf = StringBuffer();
      final stops = <String>[];

      for (int cIdx = 0; cIdx < cleanWord.length; cIdx++) {
        final char = cleanWord[cIdx];
        if (QuranWordHighlighter.stopSigns.contains(char)) {
          stops.add(char);
        } else {
          cleanWordBuf.write(char);
        }
      }

      result.add(
        QuranAyahWordToken(
          pureWord: cleanWordBuf.toString(),
          stops: List<String>.unmodifiable(stops),
        ),
      );
    }

    final unmodifiable = List<QuranAyahWordToken>.unmodifiable(result);
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[ayetText] = unmodifiable;
    return unmodifiable;
  }
}

/// Shared RTL word-by-word verse display used by both Kelime Takipli Dinleme
/// and Mukabele List mode.
///
/// Guarantees:
/// - Zero layout shift during highlight, arrow, or masking updates.
/// - Clear ayah start ornament glued to the first word.
/// - Non-breaking ayah stop marker glued to the last word so it never orphans
///   at the start of a new line.
class SynchronizedArabicAyahWrap extends StatelessWidget {
  final QuranAyatModel verse;
  final int verseIndex;
  final bool isActiveVerse;
  final int activeWordOrder;
  final int activeWordDurationMs;
  final double playbackSpeed;
  final bool isPlaying;
  final bool isDark;
  final String fontFamily;
  final double fontSize;
  final bool isBoldArabic;
  final bool isArrowTracking;
  final bool maskingMode;
  final GlobalKey? activeWordKey;
  final void Function(int verseIndex, int wordOrder) onWordTap;
  final VoidCallback onAyahMarkerTap;

  const SynchronizedArabicAyahWrap({
    super.key,
    required this.verse,
    required this.verseIndex,
    required this.isActiveVerse,
    required this.activeWordOrder,
    required this.activeWordDurationMs,
    required this.playbackSpeed,
    required this.isPlaying,
    required this.isDark,
    required this.fontFamily,
    required this.fontSize,
    required this.isBoldArabic,
    required this.isArrowTracking,
    this.maskingMode = false,
    this.activeWordKey,
    required this.onWordTap,
    required this.onAyahMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final words = QuranAyahWordParser.parse(verse.ayetText);
    final divineColor = QuranWordHighlighter.getDivineWordColor(isDark);
    final waqfColor = QuranWordHighlighter.getWaqfColor(isDark);
    final activeArrowTextColor =
        QuranWordHighlighter.getDiyanetTrackingWordColor(isDark);
    final activeArrowShadows =
        QuranWordHighlighter.getDiyanetTrackingShadows(isDark);
    final markerNumber = verse.ayetNumber.isNotEmpty
        ? verse.ayetNumber
        : QuranWordHighlighter.toArabicDigits(verse.ayetId);
    final isSecde = TilavetSecdesiData.isSecdeVerse(
      verse.sureId,
      verse.ayetId,
    );
    final markerSize = (fontSize * 1.04).clamp(26.0, 34.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (words.isEmpty)
                GestureDetector(
                  onTap: onAyahMarkerTap,
                  child: ZikirceAyahStopMarker(
                    number: markerNumber,
                    size: markerSize,
                    isDark: isDark,
                    isHighlight: isActiveVerse,
                    isSecde: isSecde,
                    fontFamily: fontFamily,
                  ),
                ),
              for (int wIdx = 0; wIdx < words.length; wIdx++)
                _buildWordUnit(
                  wordToken: words[wIdx],
                  wordOrder: wIdx + 1,
                  isFirstWord: wIdx == 0,
                  isLastWord: wIdx == words.length - 1,
                  maxWidth: maxWidth,
                  divineColor: divineColor,
                  waqfColor: waqfColor,
                  activeArrowTextColor: activeArrowTextColor,
                  activeArrowShadows: activeArrowShadows,
                  markerNumber: markerNumber,
                  markerSize: markerSize,
                  isSecde: isSecde,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordUnit({
    required QuranAyahWordToken wordToken,
    required int wordOrder,
    required bool isFirstWord,
    required bool isLastWord,
    required double maxWidth,
    required Color divineColor,
    required Color waqfColor,
    required Color activeArrowTextColor,
    required List<Shadow> activeArrowShadows,
    required String markerNumber,
    required double markerSize,
    required bool isSecde,
  }) {
    final isWordActive = isActiveVerse && activeWordOrder == wordOrder;
    final isMasked =
        maskingMode && isActiveVerse && isPlaying && wordOrder > activeWordOrder;
    final pureWord = wordToken.pureWord;
    final stops = wordToken.stops;
    final isDivine =
        pureWord.isNotEmpty && QuranWordHighlighter.isDivineWord(pureWord);

    final Color normalTextColor = isDivine
        ? divineColor
        : (isDark ? Colors.white : const Color(0xFF1E2B27));
    final Color activeColor =
        isArrowTracking ? activeArrowTextColor : Colors.white;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          key: isWordActive
              ? activeWordKey
              : ValueKey<String>(
                  'w_${verseIndex}_${verse.sureId}_${verse.ayetId}_$wordOrder',
                ),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isFirstWord) ...[
              _AyahStartNib(isActive: isActiveVerse, isDark: isDark),
              const SizedBox(width: 4),
            ],
            if (pureWord.isNotEmpty)
              InkWell(
                onTap: () => onWordTap(verseIndex, wordOrder),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 45),
                  padding: isArrowTracking
                      ? const EdgeInsets.fromLTRB(5, 2, 5, 8)
                      : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (!isArrowTracking && isWordActive && !isMasked)
                        ? (isDark
                            ? const Color(0xFF059669)
                            : const Color(0xFF10B981))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      if (!isArrowTracking && isWordActive && !isMasked)
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Text(
                        pureWord,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                          fontWeight:
                              isBoldArabic ? FontWeight.bold : FontWeight.normal,
                          color: isMasked
                              ? Colors.transparent
                              : (isWordActive ? activeColor : normalTextColor),
                          shadows:
                              (isWordActive && isArrowTracking && !isMasked)
                                  ? activeArrowShadows
                                  : null,
                          height: 1.6,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (isMasked)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF283241)
                                      .withValues(alpha: 0.9)
                                  : const Color(0xFFE7EFEA)
                                      .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFF0F766E)
                                        .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '•••',
                                style: TextStyle(
                                  fontSize: (fontSize * 0.45).clamp(10.0, 16.0),
                                  letterSpacing: 1.5,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF506861),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (isArrowTracking && isWordActive && !isMasked)
                        Positioned(
                          bottom: -6,
                          left: 0,
                          right: 0,
                          child: QuranWordTrackingPointer(
                            isDark: isDark,
                            height: 7.5,
                            durationMs: activeWordDurationMs,
                            playbackSpeed: playbackSpeed,
                            isPlaying: isPlaying,
                            wordIdentity:
                                '${verse.sureId}_${verse.ayetId}_$wordOrder',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (stops.isNotEmpty)
              for (final stop in stops)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Text(
                    QuranWordHighlighter.mapStopCharacter(stop, fontFamily),
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: fontSize * 0.85,
                      fontWeight: FontWeight.normal,
                      color: waqfColor,
                    ),
                  ),
                ),
            if (isLastWord) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onAyahMarkerTap,
                child: ZikirceAyahStopMarker(
                  number: markerNumber,
                  size: markerSize,
                  isDark: isDark,
                  isHighlight: isActiveVerse,
                  isSecde: isSecde,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AyahStartNib extends StatelessWidget {
  final bool isActive;
  final bool isDark;

  const _AyahStartNib({
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = isActive
        ? (isDark ? const Color(0xFFD4AF37) : const Color(0xFF0F766E))
        : (isDark
            ? const Color(0xFFC5A358).withValues(alpha: 0.48)
            : const Color(0xFF8C5828).withValues(alpha: 0.42));

    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _AyahStartNibPainter(color: primary),
      ),
    );
  }
}

class _AyahStartNibPainter extends CustomPainter {
  final Color color;

  const _AyahStartNibPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double r = size.width * 0.42;

    final Path diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..isAntiAlias = true;
    canvas.drawPath(diamond, strokePaint);

    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), r * 0.34, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _AyahStartNibPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
