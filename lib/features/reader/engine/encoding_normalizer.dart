import 'dart:collection';

/// Eski ve sorunlu Türkçe PDF'lerdeki karakter kodlama hatalarını,
/// ligatür bozulmalarını ve mizanpaj kalıntılarını onaran saf ve deterministik normalizasyon motoru.
class EncodingNormalizer {
  const EncodingNormalizer._();

  /// Windows-1254 / ISO-8859-9 / CP1252 / MacTurkish yanlış kodlama haritası
  static final Map<String, String> _legacyEncodingReplacements = UnmodifiableMapView({
    // Windows-1254 -> CP1252 Bozulmaları
    'Ý': 'İ',
    'ý': 'ı',
    'Þ': 'Ş',
    'þ': 'ş',
    'ð': 'ğ',
    'Ð': 'Ğ',
    'º': 'ş',
    '°': 'ı',

    // Çift UTF-8 / Mojibake Bozulmaları
    'Ã§': 'ç',
    'Ã‡': 'Ç',
    'Ä±': 'ı',
    'Ä°': 'İ',
    'ÄŸ': 'ğ',
    'Äž': 'Ğ',
    'Ã¶': 'ö',
    'Ã–': 'Ö',
    'Ã¼': 'ü',
    'Ãœ': 'Ü',
    'ÅŸ': 'ş',
    'Åž': 'Ş',

    // Tipografik Ligatürler
    'ﬁ': 'fi',
    'ﬂ': 'fl',
    'ﬃ': 'ffi',
    'ﬄ': 'ffl',
    'ﬀ': 'ff',
    'ﬅ': 'st',
    'ﬆ': 'st',
  });

  /// Metindeki tüm kodlama bozulmalarını onarır
  static String normalizeEncodings(String input) {
    if (input.isEmpty) return input;
    var text = input;

    // 1. Bilinen bozuk karakter ve mojibake dizilerini değiştir
    _legacyEncodingReplacements.forEach((faulty, correct) {
      text = text.replaceAll(faulty, correct);
    });

    // 2. Özel font sembolleri ve soft hyphens temizliği
    text = text.replaceAll('\u00AD', ''); // Soft hyphen
    text = text.replaceAll('\u200B', ''); // Zero-width space
    text = text.replaceAll('\u200C', ''); // Zero-width non-joiner
    text = text.replaceAll('\u200D', ''); // Zero-width joiner
    text = text.replaceAll('\u00A0', ' '); // Non-breaking space
    text = text.replaceAll('\uFEFF', ''); // Byte order mark

    return text;
  }

  /// Satır sonu tirelerini (de-hyphenation) kusursuz şekilde birleştirir.
  /// Örnek: "müste-\n şar" -> "müsteşar", "yapıl-\n ması" -> "yapılması"
  static String deHyphenate(String input) {
    if (input.isEmpty) return input;
    var text = normalizeEncodings(input);

    // Satır sonu tirelerini birleştir
    // (\b\p{L}+) - \s*\n\s* (\p{L}+\b)
    text = text.replaceAllMapped(
      RegExp(r'([\p{L}]+)[-—–]\s*\r?\n\s*([\p{L}]+)', unicode: true),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    // Kelime içi pipe (|) harf tarama bozulmalarını onar (Ör: "binek|eriniz" -> "binekleriniz")
    text = text.replaceAllMapped(
      RegExp(r'([\p{L}]{2,})\|([\p{L}]{1,})', unicode: true),
      (m) {
        final prefix = m.group(1)!;
        final suffix = m.group(2)!;
        if (suffix.startsWith('e') ||
            suffix.startsWith('i') ||
            suffix.startsWith('a') ||
            suffix.startsWith('ı') ||
            suffix.startsWith('u') ||
            suffix.startsWith('ü')) {
          return '${prefix}l$suffix';
        }
        return '$prefix$suffix';
      },
    );

    return text;
  }

  /// Sayfa başı (%5-6) ve sayfa sonu (%5-6) tekrar eden üstbilgi/altbilgi (Header/Footer)
  /// ve sayfa numaralarını gövde metninden tamamen ayıklar.
  static String stripHeaderAndFooter(
    String pageText, {
    int totalLinesThreshold = 3,
    double topRatio = 0.10,
    double bottomRatio = 0.10,
  }) {
    if (pageText.isEmpty) return pageText;

    final rawLines = pageText.split('\n');
    final lines = rawLines.map((l) => l.trim()).toList();
    if (lines.length <= totalLinesThreshold) {
      return pageText.trim();
    }

    final topCutIndex = (lines.length * topRatio).ceil().clamp(2, 4);
    final bottomCutIndex = lines.length - (lines.length * bottomRatio).ceil().clamp(2, 4);

    final filtered = <String>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.isEmpty) {
        filtered.add('');
        continue;
      }

      // Noktalı fihrist liderlerini temizle
      line = line.replaceAll(RegExp(r'(\.{3,}|(\.\s*){4,})\s*\d*', unicode: true), '').trim();

      final isTop = i < topCutIndex;
      final isBottom = i >= bottomCutIndex;

      // Yalnızca sayı içeren sayfa numarası: "- 12 -", "12", "[ 12 ]", "12 / 240", "• 12 •"
      final isOnlyPageNumber = RegExp(r'^\s*[\-–—_~•\[\(]*\s*\d{1,4}\s*[\-–—_~•\]\)]*\s*$').hasMatch(line);
      // "Sayfa 45" veya "45 / 300"
      final isRunningPageHeader = RegExp(r'^\s*Sayfa\s+\d+(\s*/\s*\d+)?\s*$', caseSensitive: false).hasMatch(line);
      final isFractionNumber = RegExp(r'^\s*\d+\s*/\s*\d+\s*$').hasMatch(line);
      // Kısa altbilgi / üstbilgi tekrarı (< 60 karakter)
      final isShortRunningHeader = line.length < 80 &&
          (RegExp(r'^(Bölüm|Fasıl|BAB|Kısım|Sayfa|Sahife)\s*\d*$', caseSensitive: false).hasMatch(line) ||
           RegExp(r'^(?:İsl[aâ]m[\x27\x22’]?da\s+.*Görgü\s+Kuralları|Mukaddime|Bölüm\s+\d+|Fasıl\s+\d+)', caseSensitive: false).hasMatch(line) ||
           RegExp(r'^\d+\s+[A-ZÇĞİÖŞÜ\s]+$').hasMatch(line));

      if ((isTop || isBottom) && (isOnlyPageNumber || isRunningPageHeader || isFractionNumber || isShortRunningHeader)) {
        continue;
      }

      // Baştaki veya sondaki tekil sayfa numarasını her halükarda ayıkla
      if ((i == 0 || i == 1 || i >= lines.length - 2) && isOnlyPageNumber) {
        continue;
      }

      filtered.add(line);
    }

    return filtered.join('\n').trim();
  }

  /// Noktalama, tırnak ve apostrof boşluklarını düzeltir
  static String cleanPunctuationSpacing(String input) {
    var text = input;

    // Kesme işaretleri bitişikliği: "Allah' a" -> "Allah'a"
    text = text.replaceAllMapped(
      RegExp(r"([\p{L}]+)\s*([’'])\s+([\p{L}]+)", unicode: true),
      (m) => "${m.group(1)}${m.group(2)}${m.group(3)}",
    );

    // Noktalama öncesi gereksiz boşluk: "kelime , devam" -> "kelime, devam"
    text = text.replaceAllMapped(RegExp(r'\s+([,\.!?:;])'), (m) => m.group(1)!);

    // Çoklu boşlukları teke indir
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return text;
  }
}
