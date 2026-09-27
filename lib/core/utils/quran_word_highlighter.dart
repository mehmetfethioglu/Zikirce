import 'package:flutter/material.dart';

/// Utility class to identify and style Divine Names (Lafzatullah & Rab) in Quranic Arabic text.
class QuranWordHighlighter {
  // Classic Mushaf Red tones
  static const Color lightDivineRed = Color(0xFFDC2626); // Ruby Crimson
  static const Color darkDivineRed = Color(0xFFF87171);  // Luminous Coral Red

  static Color getDivineWordColor(bool isDark) {
    return isDark ? darkDivineRed : lightDivineRed;
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
    text = text.replaceAll(RegExp(r'[^\u0600-\u06FF]'), '');
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

  /// Builds a list of [InlineSpan]s for a given raw Arabic verse with divine words highlighted
  static List<InlineSpan> buildHighlightedSpans({
    required String rawText,
    required TextStyle baseStyle,
    required bool isDark,
    bool enabled = true,
  }) {
    if (rawText.isEmpty) return const [];
    final words = rawText.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];
    final divineColor = getDivineWordColor(isDark);

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final bool isDivine = enabled && isDivineWord(word);
      final wordStyle = isDivine ? baseStyle.copyWith(color: divineColor) : baseStyle;

      spans.add(TextSpan(text: word, style: wordStyle));

      if (i < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return spans;
  }
}
