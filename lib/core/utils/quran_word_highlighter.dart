import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../features/kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';

/// Utility class to identify and style Divine Names (Lafzatullah & Rab) and Waqf Stops in Quranic Arabic text.
class QuranWordHighlighter {
  // Classic Mushaf Red tones
  static const Color lightDivineRed = Color(0xFFDC2626); // Ruby Crimson
  static const Color darkDivineRed = Color(0xFFF87171);  // Luminous Coral Red

  static Color getDivineWordColor(bool isDark) {
    return isDark ? darkDivineRed : lightDivineRed;
  }

  // Classic Mushaf Waqf (Stop) Red tones
  static const Color lightWaqfRed = Color(0xFFD32F2F);
  static const Color darkWaqfRed = Color(0xFFFF5252);

  static Color getWaqfColor(bool isDark) {
    return isDark ? darkWaqfRed : lightWaqfRed;
  }

  /// All known Waqf (Stop) signs present in Quranic texts
  static const Set<String> stopSigns = {
    '\u0615', // Small High Tah (Tı - ط)
    '\u0617', // Small High Zain (Ze - ز)
    '\u06D6', // Small High Sad (Sâd - ص)
    '\u06D7', // Small High Qaf (Qaf - ق)
    '\u06D8', // Small High Meem (Mîm - م / Lâzım)
    '\u06D9', // Small High Lam Alef (Lâ - لا)
    '\u06DA', // Small High Jeem (Cim - ج)
    '\u06DB', // Small High Three Dots (Mu'anaqa 3 nokta - ۛ)
    '\u06DC', // Small High Seen (Tı / Sin - ۜ)
    '\u06DF', // Small High Rounded Zero (Ayn - ۟)
    '\u06E2', // Small High Meem Isolated (Mîm - ۢ)
    '\u06E3', // Small Low Seen (Sin - ۣ)
    '\u06E7', // Small High Qaf / Kef (Kef - ۧ)
    '\u08D5', // Arabic Small High Sad (Sâd - ࣕ)
    '\u08D6', // Arabic Small High Ain (Ayn / Rükû - ࣖ)
    '\u08D7', // Arabic Small High Qaf (Qaf - ࣗ)
    '\u08DE', // Arabic Small High Word Kaph (Kef - ࣞ)
  };

  /// Maps Quranic stop character to the appropriate font glyph code
  static String mapStopCharacter(String char, String fontFamily) {
    if (fontFamily == 'AmasyaAbay' || fontFamily == 'mushaf') {
      switch (char) {
        case '\u0615': return '\u06DC'; // Tı stop -> U+06DC (hightah in AmasyaAbay/mushaf)
        case '\u0617': return '\u0617'; // Ze stop -> U+0617
        case '\u06D6':
        case '\u08D5': return '\u06D6'; // Sâd stop -> U+06D6
        case '\u06D7':
        case '\u08D7': return '\u06D7'; // Qaf stop -> U+06D7
        case '\u06D8':
        case '\u06E2': return '\u06E2'; // Mîm stop -> U+06E2
        case '\u06D9': return '\u06D9'; // Lâ stop -> U+06D9
        case '\u06DA': return '\u06DA'; // Cim stop -> U+06DA
        case '\u06DB': return '\u06DB'; // Mu'anaqa 3 dots -> U+06DB
        case '\u06DC': return '\u06DC'; // Tı stop -> U+06DC
        case '\u06DF':
        case '\u08D6': return '\u06DF'; // Ayn stop -> U+06DF (highain in AmasyaAbay/mushaf)
        case '\u06E3': return '\u06E3'; // Sin stop -> U+06E3 (lowseen)
        case '\u06E7':
        case '\u08DE': return '\u06E7'; // Kef stop -> U+06E7 (highkaf)
        default: return char;
      }
    } else if (fontFamily == 'mushaf_bold') {
      switch (char) {
        case '\u0615':
        case '\u06DC': return '\u0615';
        case '\u0617': return '\u0617';
        case '\u06D6':
        case '\u08D5': return '\u06D6';
        case '\u06D7':
        case '\u08D7': return '\u06D7';
        case '\u06D8':
        case '\u06E2': return '\u06D8';
        case '\u06D9': return '\u06D9';
        case '\u06DA': return '\u06DA';
        case '\u06DB': return '\u06DB';
        case '\u06DF':
        case '\u08D6': return '\u08D6';
        case '\u06E3': return '\u06E3';
        case '\u06E7':
        case '\u08DE': return '\u06E7';
        default: return char;
      }
    }
    return char;
  }

  /// Converts Hindu-Arabic integer (e.g. 41) to Arabic numerals (e.g. ٤١)
  static String toArabicDigits(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return str.split('').map((char) {
      final val = int.tryParse(char);
      return val != null ? arabicDigits[val] : char;
    }).join();
  }

  /// Strips hidden control characters, surrogates, normalizes non-breaking spaces
  /// and critically replaces Farsi Yeh (U+06CC) with Arabic Yeh (U+064A) so ligatures don't break.
  static String cleanArabicText(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll(String.fromCharCode(0x10EFD), '')
        .replaceAll(String.fromCharCode(0x10EFE), '')
        .replaceAll(String.fromCharCode(0x10EFF), '')
        .replaceAll('\uD803\uDEFD', '')
        .replaceAll('\uD803\uDEFE', '')
        .replaceAll('\uD803\uDEFF', '')
        .replaceAll('\uEE00', '')
        .replaceAll('\uEE01', '')
        .replaceAll('\u08CF', '')
        .replaceAll('\u08D9', '')
        .replaceAll('\u06EA', '')
        .replaceAll('\u06EB', '')
        .replaceAll('\u06EC', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '').replaceAll('\u202E', '').replaceAll('\u202C', '')
        .replaceAll('\u061C', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u200B', ' ')
        .replaceAll('ی', 'ي')
        .replaceAllMapped(
          RegExp(r'(^|\s)ذُو(?![ق\s])'),
          (m) => '${m[1]}ذُو ',
        )
        .replaceAll('D', 'ْد');
  }

  /// Cleans and formats an Arabic string for plain Text widgets by mapping stop signs to the given font
  static String formatArabicTextForFont(String input, String fontFamily) {
    final cleaned = cleanArabicText(input);
    if (cleaned.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      if (stopSigns.contains(char)) {
        buffer.write(mapStopCharacter(char, fontFamily));
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  // Common Arabic Tashkeel (harakat / diacritics / Quranic annotations)
  static final RegExp _tashkeelAndMarksRegex = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED\u08D0-\u08FF\u0610-\u061A\u0656-\u065F\u0670\uEE00\uEE01\u200C\u200D\u200E\u200F\uFEFF\u00A0\u202F]',
  );

  /// Strips diacritics and normalizes letter variations for precise word-level matching
  static String normalizeWord(String input) {
    if (input.isEmpty) return '';
    var text = input
        .replaceAll(String.fromCharCode(0x10EFD), '')
        .replaceAll(String.fromCharCode(0x10EFE), '')
        .replaceAll(String.fromCharCode(0x10EFF), '')
        .replaceAll('\uD803\uDEFD', '')
        .replaceAll('\uD803\uDEFE', '')
        .replaceAll('\uD803\uDEFF', '')
        .replaceAll(_tashkeelAndMarksRegex, '');

    text = text.replaceAll(RegExp(r'[إأآٱ]'), 'ا');
    text = text.replaceAll('ة', 'ه');
    text = text.replaceAll('ى', 'ي');
    text = text.replaceAll('ـ', '');
    text = text.replaceAll('ی', 'ي');
    text = text.replaceAll('D', 'د');
    // strip non-arabic punctuation/stop markers
    text = text.replaceAll('\uFDF2', 'الله').replaceAll(RegExp(r'[\u0600-\u0620\u0640\u0660-\u066D\u06D4\u06DD\u06DE\u06E9]|[^\u0600-\u06FF]'), '');
    return text.trim();
  }

  // Exact set of normalized Allah forms in the Quran (2,700+ occurrences)
  static final Set<String> _allahForms = {
    'الله',      // Allāh
    'والله',     // Wa-Allāh
    'فالله',     // Fa-Allāh
    'بالله',     // Bi-Allāh
    'وبالله',    // Wa-bi-Allāh
    'فبالله',    // Fa-bi-Allāh
    'تالله',     // Ta-Allāh
    'وتالله',    // Wa-ta-Allāh
    'لله',       // Lillāh
    'ولله',      // Wa-lillāh
    'فلله',      // Fa-lillāh
    'اللهم',     // Allāhumma
    'واللهم',    // Wa-Allāhumma
    'ءالله',     // Ā-Allāhu (ءَآللّٰهُ / أَاللّٰهُ)
    'ءاللهم',    // Qul Allāhumma variant
    'االله',     // Normalized alif variant
    'فوالله',    // Fa-wa-Allāh
    'ابالله',    // A-bi-Allāh
    'افالله',    // A-fa-Allāh
    'فاللهم',    // Fa-Allāhumma
    'كالله',     // Ka-Allāh
    'وكالله',    // Wa-ka-Allāh
  };

  // Exact set of normalized Rab forms (Lord) in the Quran (960+ occurrences)
  static final Set<String> _rabForms = {
    // Yalın & Yaa (Rab / Rabbi)
    'رب', 'ورب', 'فرب', 'برب', 'وبرب', 'فبرب', 'لرب', 'ولرب', 'فلرب', 'فورب', 'الرب', 'والرب', 'ارب',
    'ربي', 'وربي', 'فربي', 'بربي', 'وبربي', 'فبربي', 'لربي', 'ولربي',
    // Naa (Rabbana)
    'ربنا', 'وربna', 'وربنا', 'فربنا', 'بربنا', 'وبربنا', 'لربنا', 'ولربنا', 'اربنا',
    // Ka / Ki (Rabbuka / Rabbiki)
    'ربك', 'ورbk', 'وربك', 'فربك', 'بربك', 'وبربك', 'فبربك', 'لربك', 'ولربك', 'اربك',
    // Kuma (Rabbikuma)
    'ربكما', 'وربكما', 'فربكما', 'بربكما', 'فبربكما', 'لربكما',
    // Kum (Rabbukum)
    'ربكم', 'وربكم', 'فربكم', 'بربكم', 'وبربكم', 'فبربكم', 'لربكم', 'ولربكم', 'اربكم', 'افبربكم',
    // Kunna (Rabbukunna)
    'ربكن', 'وربكن',
    // Hu (Rabbuho)
    'ربه', 'وربه', 'فربه', 'بربه', 'وبربه', 'لربه', 'ولربه',
    // Ha (Rabbuha)
    'ربها', 'وربها', 'فربها', 'بربها', 'وبربها', 'لربها', 'ولربها',
    // Huma (Rabbuhuma)
    'ربهما', 'وربهما', 'بربهما', 'لربهما',
    // Hum / Him (Rabbuhum / Rabbihim)
    'ربهم', 'وربهم', 'فربهم', 'بربهم', 'وبربهم', 'فبربهم', 'لربهم', 'ولربهم',
    // Hunna (Rabbuhunna)
    'ربهن', 'وربهن', 'بربهن', 'لربهن',
  };

  /// Returns true if the word is an occurrence of Lafzatullah (Allah) or Rab
  static bool isDivineWord(String word) {
    final norm = normalizeWord(word);
    return _allahForms.contains(norm) || _rabForms.contains(norm);
  }

  /// Returns true if the word is Lafzatullah (Allah)
  static bool isAllahWord(String word) {
    return _allahForms.contains(normalizeWord(word));
  }

  /// Returns true if the word is Rab
  static bool isRabWord(String word) {
    return _rabForms.contains(normalizeWord(word));
  }

  /// Diyanet Kur'an Platformu active word highlight color ("Ok Takibi" crimson red)
  static Color getDiyanetTrackingWordColor(bool isDark) {
    return isDark ? const Color(0xFFFF4D4D) : const Color(0xFFE60000);
  }

  /// Diyanet Kur'an Platformu subtle red text-shadow for active word (`0 0 2px rgba(255, 0, 0, .3)`)
  static List<Shadow> getDiyanetTrackingShadows(bool isDark) {
    return const [
      Shadow(
        color: Color(0x4DFF0000),
        blurRadius: 2.0,
      ),
    ];
  }

  /// Extracts pure Arabic words (with waqf stop signs stripped) matching `_parseAyahWords` 1-to-1
  static List<String> extractPureWords(String rawText) {
    final cleaned = cleanArabicText(rawText).trim();
    if (cleaned.isEmpty) return const [];
    final rawWords = cleaned.split(RegExp(r'\s+'));
    final result = <String>[];
    for (final w in rawWords) {
      final trimmed = w.trim();
      if (trimmed.isEmpty) continue;
      final buf = StringBuffer();
      for (int i = 0; i < trimmed.length; i++) {
        final ch = trimmed[i];
        if (!stopSigns.contains(ch)) {
          buf.write(ch);
        }
      }
      result.add(buf.toString());
    }
    return result;
  }

  /// Builds a list of [InlineSpan]s for a given raw Arabic verse with divine words highlighted,
  /// stops properly mapped & colored in waqf red, and optional Zikirce Ayah Stop Marker.
  static List<InlineSpan> buildHighlightedSpans({
    required String rawText,
    required TextStyle baseStyle,
    required bool isDark,
    bool enabled = true,
    String? fontFamily,
    Color? waqfColor,
    String? ayahNumber,
    bool showAyahStopMarker = false,
    VoidCallback? onAyahTap,
    GestureRecognizer? recognizer,
    bool isBold = false,
  }) {
    if (rawText.isEmpty) return const [];

    final clean = cleanArabicText(rawText);
    final effectiveFontFamily = fontFamily ?? baseStyle.fontFamily ?? 'AmasyaAbay';
    final effectiveWaqfColor = waqfColor ?? getWaqfColor(isDark);
    final divineColor = getDivineWordColor(isDark);

    final effectiveStyle = baseStyle.copyWith(
      fontFamily: effectiveFontFamily,
      letterSpacing: baseStyle.letterSpacing ?? -0.1,
      fontWeight: isBold ? FontWeight.bold : (baseStyle.fontWeight ?? FontWeight.normal),
    );

    final words = clean.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final cleanWordBuf = StringBuffer();
      final stops = <String>[];

      for (int cIdx = 0; cIdx < word.length; cIdx++) {
        final char = word[cIdx];
        if (stopSigns.contains(char)) {
          stops.add(char);
        } else {
          cleanWordBuf.write(char);
        }
      }

      final pureWord = cleanWordBuf.toString();
      final bool isDivine = enabled && pureWord.isNotEmpty && isDivineWord(pureWord);
      final wordStyle = isDivine ? effectiveStyle.copyWith(color: divineColor) : effectiveStyle;

      if (pureWord.isNotEmpty) {
        spans.add(TextSpan(
          text: pureWord,
          style: wordStyle,
          recognizer: recognizer,
        ));
      }

      for (int sIdx = 0; sIdx < stops.length; sIdx++) {
        final stop = stops[sIdx];
        final mappedStop = mapStopCharacter(stop, effectiveFontFamily);
        final prefix = sIdx == 0 ? '\u200B' : '\u200A';
        spans.add(TextSpan(
          text: '$prefix$mappedStop',
          style: effectiveStyle.copyWith(
            color: effectiveWaqfColor,
            fontWeight: FontWeight.normal,
          ),
          recognizer: recognizer,
        ));
      }

      if (i < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: effectiveStyle));
      }
    }

    if (showAyahStopMarker && ayahNumber != null && ayahNumber.isNotEmpty) {
      final formattedNumber = toArabicDigits(ayahNumber);
      spans.add(const TextSpan(text: '\u200F '));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: onAyahTap,
            child: ZikirceAyahStopMarker(
              number: formattedNumber,
              isDark: isDark,
              isHighlight: false,
              fontFamily: effectiveFontFamily,
              size: ((effectiveStyle.fontSize ?? 24.0) * 1.15).clamp(22.0, 42.0),
            ),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' \u200F'));
    }

    return spans;
  }
}

/// Diyanet Kur'an Platformu style upward red tracking arrow pointer for "Ok ile Takip" mode.
/// Slides smoothly from right to left (`0% { right: 0 }` -> `100% { right: 100% }`) linearly
/// across the width of the active word over [durationMs] / [playbackSpeed].
class QuranWordTrackingPointer extends StatefulWidget {
  final bool isDark;
  final double height;
  final int durationMs;
  final double playbackSpeed;
  final bool isPlaying;
  final bool animate;
  final Object? wordIdentity;

  const QuranWordTrackingPointer({
    super.key,
    required this.isDark,
    this.height = 7.5,
    this.durationMs = 500,
    this.playbackSpeed = 1.0,
    this.isPlaying = true,
    this.animate = true,
    this.wordIdentity,
  });

  @override
  State<QuranWordTrackingPointer> createState() =>
      _QuranWordTrackingPointerState();
}

class _QuranWordTrackingPointerState extends State<QuranWordTrackingPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _computeEffectiveDuration() {
    final speed = widget.playbackSpeed <= 0.1 ? 1.0 : widget.playbackSpeed;
    final scaledMs = (widget.durationMs / speed).round().clamp(120, 8000);
    return Duration(milliseconds: scaledMs);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _computeEffectiveDuration(),
      value: widget.animate ? 0.0 : 0.5,
    );
    if (widget.animate && widget.isPlaying) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant QuranWordTrackingPointer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) {
      _controller.stop();
      _controller.value = 0.5;
      return;
    }

    final identityChanged = widget.wordIdentity != oldWidget.wordIdentity;
    final timingChanged = widget.durationMs != oldWidget.durationMs ||
        (widget.playbackSpeed - oldWidget.playbackSpeed).abs() > 0.01;

    if (identityChanged) {
      _controller.duration = _computeEffectiveDuration();
      _controller.reset();
      if (widget.isPlaying) {
        _controller.forward();
      }
      return;
    }

    if (timingChanged) {
      final currentVal = _controller.value;
      _controller.duration = _computeEffectiveDuration();
      if (widget.isPlaying && currentVal < 1.0) {
        _controller.forward(from: currentVal);
      }
    }

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (_controller.value < 1.0) {
          _controller.forward();
        }
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: QuranTrackingArrowPainter(
                isDark: widget.isDark,
                progress: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class QuranTrackingArrowPainter extends CustomPainter {
  final bool isDark;
  final double progress;

  const QuranTrackingArrowPainter({
    required this.isDark,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Diyanet CSS:
    // border-left: 5px solid transparent;
    // border-right: 5px solid transparent;
    // border-bottom: 7px solid rgba(255, 0, 0, .9);
    // @keyframes _slideWord { 0% { right: 0; } to { right: 100%; } }
    final arrowColor =
        isDark ? const Color(0xEBFF3B30) : const Color(0xEBE60000);
    const halfBase = 5.0;
    final arrowHeight = size.height.clamp(6.0, 8.0);

    // At progress = 0.0, right edge of arrow is at right edge of word (right: 0).
    // At progress = 1.0, right edge of arrow reaches left edge of word (right: 100%).
    final t = progress.clamp(0.0, 1.0);
    final startCenterX =
        size.width > halfBase ? (size.width - halfBase) : (size.width / 2.0);
    const endCenterX = 0.0;
    final centerX = startCenterX - ((startCenterX - endCenterX) * t);

    final arrowPath = Path()
      ..moveTo(centerX, 0.0) // Sharp upward tip pointing at the word
      ..lineTo(centerX - halfBase, arrowHeight)
      ..lineTo(centerX + halfBase, arrowHeight)
      ..close();

    final glowPaint = Paint()
      ..color = arrowColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawPath(arrowPath, glowPaint);

    final arrowPaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant QuranTrackingArrowPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        (oldDelegate.progress - progress).abs() > 0.002;
  }
}


