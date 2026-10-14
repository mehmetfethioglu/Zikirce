import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/content_block.dart';
import '../services/islamic_hadith_corpus.dart';

export '../domain/content_block.dart' show FootnoteAnchor;

class PageFootnote {
  final String key;
  final String content;

  const PageFootnote({
    required this.key,
    required this.content,
  });
}

class ParagraphSegment {
  final String rawText;
  final bool isHeading;
  final bool isArabic;
  final bool isCalligraphyFallback;
  final bool isImagePlaceholder;
  final String? imagePath;
  final Uint8List? imageBytes;
  final List<FootnoteAnchor> footnoteAnchors;

  ParagraphSegment({
    required this.rawText,
    this.isHeading = false,
    this.isArabic = false,
    this.isCalligraphyFallback = false,
    this.isImagePlaceholder = false,
    this.imagePath,
    this.imageBytes,
    this.footnoteAnchors = const [],
  });
}

class ExtractedPageResult {
  final String bodyText;
  final List<PageFootnote> footnotes;
  final bool hadCorruptedCalligraphy;

  const ExtractedPageResult({
    required this.bodyText,
    required this.footnotes,
    this.hadCorruptedCalligraphy = false,
  });
}

class TextSegmenter {
  const TextSegmenter._();

  /// Removes hyphenation at line breaks (e.g., "ge- \n çiş" -> "geçiş")
  static String deHyphenate(String input) {
    var text = input.replaceAll('\u00AD', ''); // remove soft hyphens
    text = text.replaceAll('\u200B', ''); // remove zero-width space

    return text.replaceAllMapped(
      RegExp(r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)-\s*\n\s*([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)', unicode: true),
      (match) => '${match.group(1)}${match.group(2)}',
    );
  }

  /// Normalizes custom calligraphic / script font mis-encodings in Turkish books
  /// Normalizes custom calligraphic / script font mis-encodings in Turkish books
  static String cleanScriptFontArtifacts(String input) {
    var text = input;

    // 1. Specific known script ligature corruptions (e.g. "JCapıyı J?avça fiçıp JCapatmanın Önemi", "ct?e Geldiğini, ct?dekilere </Jildirmenin Önemi")
    text = text.replaceAll(RegExp(r'JCapıyı', caseSensitive: false), 'Kapıyı');
    text = text.replaceAll(RegExp(r'JCapatmanın', caseSensitive: false), 'Kapatmanın');
    text = text.replaceAll(RegExp(r'J\?avça', caseSensitive: false), 'Yavaşça');
    text = text.replaceAll(RegExp(r'fiçıp', caseSensitive: false), 'Açıp');

    // 2. Generic script 'K' mapped to 'JC' (e.g., "JCapı" -> "Kapı", "JCapa" -> "Kapa")
    text = text.replaceAllMapped(
      RegExp(r'JC([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)', unicode: true),
      (m) => 'K${m.group(1)}',
    );

    // 3. Generic script 'Y' mapped to 'J?'
    text = text.replaceAllMapped(
      RegExp(r'J\?([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)', unicode: true),
      (m) => 'Y${m.group(1)}',
    );

    // 4. Specific known script ligatures for 'A'
    text = text.replaceAll(RegExp(r'\bfiçıp\b', caseSensitive: false), 'Açıp');
    text = text.replaceAll(RegExp(r'\bfiçık\b', caseSensitive: false), 'Açık');
    text = text.replaceAll(RegExp(r'\bfiçılan\b', caseSensitive: false), 'Açılan');
    text = text.replaceAll(RegExp(r'\bfiçma\b', caseSensitive: false), 'Açma');

    // 5. Script 'Ev' mapped to 'ct?' or 'ct?e' (e.g., "ct?e Geldiğini, ct?dekilere" -> "Eve Geldiğini, Evdekilere")
    text = text.replaceAll(RegExp(r'\bct\?e\b', caseSensitive: false), 'Eve');
    text = text.replaceAll(RegExp(r'\bct\?dekilere\b', caseSensitive: false), 'Evdekilere');
    text = text.replaceAll(RegExp(r'\bct\?dekileri\b', caseSensitive: false), 'Evdekileri');
    text = text.replaceAll(RegExp(r'\bct\?deki\b', caseSensitive: false), 'Evdeki');
    text = text.replaceAll(RegExp(r'\bct\?den\b', caseSensitive: false), 'Evden');
    text = text.replaceAll(RegExp(r'\bct\?in\b', caseSensitive: false), 'Evin');
    text = text.replaceAll(RegExp(r'\bct\?i\b', caseSensitive: false), 'Evi');
    text = text.replaceAll(RegExp(r'\bct\?\b', caseSensitive: false), 'Ev');

    // 6. Script 'B' mapped to '</J' or '</' in headings (e.g. "</Jildirmenin" -> "Bildirmenin", "</Jölüm" -> "Bölüm")
    text = text.replaceAllMapped(
      RegExp(r'</[Jj]?([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)', unicode: true),
      (m) => 'B${m.group(1)}',
    );

    return text;
  }

  /// Removes dotted leaders, page numbers, repeating symbols, and running headers/footers
  static String filterHeadersAndFooters(String pageText) {
    var text = pageText;

    // 1. Remove dotted leader patterns in place (e.g., "... ..... ... 19" or "................")
    text = text.replaceAll(RegExp(r'(\.{3,}|(\.\s*){4,})\s*\d*', unicode: true), '');
    
    // 2. Remove specific trailing running footers like "26 İslâm'da Adab-ı Muaşeret Görgü Kuralları" or "Aile İçindeki Edebler 23"
    text = text.replaceAll(
      RegExp(r'(?:^|[^\p{L}\p{N}])(?:\d+\s+)?İsl[aâ]m(?:\x27|\x22|’)?da\s+(?:[AÂaâ]d[aâ]b|[AÂaâ]dab)-ı\s+Mu[aâ]şeret\s+Görgü\s+Kuralları(?:\s*\d+)?(?=[^\p{L}\p{N}]|$)', unicode: true, caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\b(Aile İçindeki Edebler|Mukaddime|Edeb|Bölüm|Fasıl|BAB)\s*\d+\s*$', caseSensitive: false), '');

    final lines = text.split('\n');
    final filtered = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        filtered.add('');
        continue;
      }

      // If line is short and looks like an isolated running header/page number at top/bottom
      if (line.length < 80) {
        final isTopOrBottom = i <= 2 || i >= lines.length - 3;
        final isOnlyNumber = RegExp(r'^\s*(\-|\–|\[|\()?s*\d{1,4}\s*(\-|\–|\]|\))?\s*$').hasMatch(line);
        final isRunningPageHeader = RegExp(r'^\s*Sayfa\s+\d+(\s*/\s*\d+)?\s*$', caseSensitive: false).hasMatch(line);
        final isPageFraction = line.contains(' / ') || RegExp(r'^\s*\d+\s*/\s*\d+\s*$').hasMatch(line);
        final isChapterFooterWithNumber = RegExp(r'^(Aile İçindeki Edebler|Mukaddime|Edeb|Bölüm|Fasıl)\s*\d+$', caseSensitive: false).hasMatch(line);
        final isBottomChapterFooter = (i >= lines.length - 3) && RegExp(r'^(Aile İçindeki Edebler|Mukaddime|Edeb|Bölüm|Fasıl|(?:\d+\s+)?İsl[aâ]m.*[Aa]dab.*)\s*\d*$', caseSensitive: false).hasMatch(line);

        if ((isTopOrBottom && (isOnlyNumber || isRunningPageHeader || isPageFraction || isChapterFooterWithNumber)) || isBottomChapterFooter) {
          continue;
        }
      }

      filtered.add(line);
    }

    return filtered.join('\n');
  }

  /// Cleans OCR errors, broken slashes in words, split Turkish suffixes, and spacing glitches
  static String cleanOcrAndLigatures(String input) {
    var text = cleanScriptFontArtifacts(input);

    // 1. Fix Turkish letter OCR confusions ('ll' -> 'l', 'rn' -> 'm', 'almdığı' -> 'alındığı')
    text = text.replaceAll(RegExp(r'yumuşakllk', caseSensitive: false), 'yumuşaklık');
    text = text.replaceAll(RegExp(r'yumuşakllğı', caseSensitive: false), 'yumuşaklığı');
    text = text.replaceAll(RegExp(r'kibarllk', caseSensitive: false), 'kibarlık');
    text = text.replaceAll(RegExp(r'almdığı', caseSensitive: false), 'alındığı');
    text = text.replaceAll(RegExp(r'a/mma', caseSensitive: false), 'alınma');

    // 2. Fix slash / pipe inside words (e.g., "binek/eriniz" -> "binekleriniz", "göz/eri" -> "gözleri", "i/e" -> "ile")
    text = text.replaceAllMapped(
      RegExp(r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[/|]([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{1,})', unicode: true),
      (m) {
        final prefix = m.group(1)!;
        final suffix = m.group(2)!;
        if (suffix.startsWith('e') || suffix.startsWith('i') || suffix.startsWith('a') || suffix.startsWith('ı') || suffix.startsWith('u') || suffix.startsWith('ü')) {
          return '${prefix}l$suffix';
        }
        return '$prefix$suffix';
      },
    );

    text = text.replaceAll(RegExp(r'\bi/e\b', caseSensitive: false), 'ile');
    text = text.replaceAll(RegExp(r'\bve/a\b', caseSensitive: false), 'veya');

    // 3. Fix split Turkish words & suffixes
    final splitSuffixMap = [
      (RegExp(r'develerin\s+izi', caseSensitive: false), 'develerinizi'),
      (RegExp(r'güzelleş\s+tirin', caseSensitive: false), 'güzelleştirin'),
      (RegExp(r'geldik\s+lerinde', caseSensitive: false), 'geldiklerinde'),
      (RegExp(r'olduk\s+ları', caseSensitive: false), 'oldukları'),
      (RegExp(r'yapma\s+lı', caseSensitive: false), 'yapmalı'),
      (RegExp(r'etmiş\s+lerdir', caseSensitive: false), 'etmişlerdir'),
      (RegExp(r'rivayet\s+et\s+miş\s*lerdir', caseSensitive: false), 'rivayet etmişlerdir'),
      (RegExp(r'yanma\s+gelmeyi', caseSensitive: false), 'yanına gelmeyi'),
    ];

    for (final pair in splitSuffixMap) {
      text = text.replaceAll(pair.$1, pair.$2);
    }

    // 4. Fix common OCR character confusions & Islamic honorific ligatures
    text = text.replaceAll(RegExp(r'Ras(?:fi|fl|ı|ı1)lullah', caseSensitive: false), 'Rasûlullah');
    text = text.replaceAll(RegExp(r'Res(?:fi|fl|ı|ı1)lullah', caseSensitive: false), 'Resûlullah');
    text = text.replaceAll(RegExp(r'Esseldmü', caseSensitive: false), 'Esselâmü');
    text = text.replaceAll(RegExp(r'Esselamü', caseSensitive: false), 'Esselâmü');
    text = text.replaceAll(RegExp(r'seldmı', caseSensitive: false), 'selâmı');
    text = text.replaceAll(RegExp(r'keldmı', caseSensitive: false), 'kelâmı');
    text = text.replaceAll(RegExp(r'kadınerkek', caseSensitive: false), 'kadın-erkek');
    text = text.replaceAllMapped(
      RegExp(r'(^|[^\p{L}\p{N}])şian(?=[^\p{L}\p{N}]|$)', caseSensitive: false, unicode: true),
      (m) => '${m.group(1)}şiarı',
    );
    text = text.replaceAll(RegExp(r'Vennenin'), 'Vermenin');
    text = text.replaceAll(RegExp(r'vennenin'), 'vermenin');
    text = text.replaceAll(RegExp(r'Vennek'), 'Vermek');
    text = text.replaceAll(RegExp(r'vennek'), 'vermek');
    text = text.replaceAll(RegExp(r'Venne\b'), 'Verme');
    text = text.replaceAll(RegExp(r'venne\b'), 'verme');
    text = text.replaceAll(RegExp(r'gönnek'), 'görmek');
    text = text.replaceAll(RegExp(r'Gönnek'), 'Görmek');
    text = text.replaceAll(RegExp(r'Tinnizl', caseSensitive: false), 'Tirmizî');
    text = text.replaceAll(RegExp(r'Tinnizi', caseSensitive: false), 'Tirmizî');
    text = text.replaceAll(RegExp(r'Tirmizl', caseSensitive: false), 'Tirmizî');
    text = text.replaceAll(RegExp(r'\bTirmizi\b'), 'Tirmizî');
    text = text.replaceAll(RegExp(r'sevrnez', caseSensitive: false), 'sevmez');
    text = text.replaceAll(RegExp(r'Hanbl', caseSensitive: false), 'Hanbel');
    text = text.replaceAll(RegExp(r'Eb[uû]\s+Davud', caseSensitive: false), 'Ebû Dâvûd');

    // Suffix 'lann' -> 'ların', 'lenn' -> 'lerin' (OCR 'rı' read as 'n')
    text = text.replaceAllMapped(
      RegExp(r'\b([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)lann(ın|a|dan|da)?\b', unicode: true),
      (m) => '${m.group(1)}ların${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\b([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)lenn(in|e|den|de)?\b', unicode: true),
      (m) => '${m.group(1)}lerin${m.group(2) ?? ''}',
    );

    // 5. Fix casing glitches inside words (e.g., "ÇıkarkEn" -> "Çıkarken")
    text = text.replaceAllMapped(
      RegExp(r'\b([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)([A-ZÇĞİÖŞÜÂÎÛ])([a-zçğıöşüâîû]+)\b', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.toLowerCase()}${m.group(3)}',
    );

    // Fix leading lowercase word at start of sentence or heading (e.g. "eve Girip" -> "Eve Girip")
    text = text.replaceAllMapped(
      RegExp(r'(^|\n)\s*([a-zçğıöşüâîû])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*\s+[A-ZÇĞİÖŞÜÂÎÛ])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}${m.group(3)}',
    );

    // 6. Fix space before apostrophes and attached suffixes (e.g., "Allah-ü Teala' dır" -> "Allah-ü Teala'dır")
    text = text.replaceAllMapped(
      RegExp(r"([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)\s*([’'])\s+([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)", unicode: true),
      (m) => "${m.group(1)}${m.group(2)}${m.group(3)}",
    );

    // Numbers/OCR misreads in Turkish words (e.g. "Ç1kacağmız" -> "çıkacağınız", "Ç1karken" -> "çıkarken", "Zfra" -> "Zira")
    text = text.replaceAll(RegExp(r'Ç1kacağmız', caseSensitive: false), 'çıkacağınız');
    text = text.replaceAll(RegExp(r'ç1kacağmız', caseSensitive: false), 'çıkacağınız');
    text = text.replaceAll(RegExp(r'ç1kacağımız', caseSensitive: false), 'çıkacağınız');
    text = text.replaceAll(RegExp(r'Ç1k', caseSensitive: false), 'Çık');
    text = text.replaceAll(RegExp(r'ç1k', caseSensitive: false), 'çık');
    text = text.replaceAll(RegExp(r'\bZfra\b'), 'Zira');
    text = text.replaceAll(RegExp(r'\bzfra\b'), 'zira');
    text = text.replaceAll(RegExp(r'\bZîra\b'), 'Zira');

    // Fix space inside closing parenthesis with quote/footnote anchor (e.g. "daha üstündür ).\"3" -> "daha üstündür).\"3")
    text = text.replaceAll(RegExp(r'\s+\)\s*\.\s*([”"])'), r').$1');
    text = text.replaceAll(RegExp(r'\s+\)\s*([”"])'), r')$1');

    // 7. Clean spaces before punctuation
    text = text.replaceAllMapped(RegExp(r'\s+([,\.!?:;])'), (m) => m.group(1)!);

    return text;
  }

  /// Detects whether a string or substring is non-Unicode corrupted font noise
  static bool isGarbageNoise(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    int symbolCount = 0;
    int letterCount = 0;
    for (int rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[<>;:_~^\\|!*+=.,"\u0027\-\/\[\]\{\}\(\)]').hasMatch(char)) {
        symbolCount++;
      } else if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char)) {
        letterCount++;
      }
    }

    final total = symbolCount + letterCount;
    if (total == 0) return false;

    // Isolated short noise line
    if (letterCount < 25 &&
        RegExp(r'(?:[oO0]\s*[,.]{2,}\s*|[Gg]i\s*[,.]{2,}|J\s+J\s*[,.]{2,}|j,tlj|\b0fa\b|\\\s*rı|[,\.]{3,}\s*(?:tP|J|\d+S|\bhş|41S))',
                unicode: true)
            .hasMatch(trimmed)) {
      return true;
    }

    // Any short block where symbols make up >= 35% and symbol count >= 6 and letterCount < 40 is corrupted font noise
    if (symbolCount >= 6 && (symbolCount / total) >= 0.35 && letterCount < 40) {
      return true;
    }

    return false;
  }

  /// Checks if a text block contains Arabic Unicode characters as its dominant script
  static bool isArabicText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final arabicLetters = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').allMatches(trimmed).length;
    final latinLetters = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]').allMatches(trimmed).length;

    if (arabicLetters == 0) return false;
    if (latinLetters == 0) return arabicLetters >= 3;

    final totalLetters = arabicLetters + latinLetters;
    return arabicLetters >= 6 && (arabicLetters / totalLetters) >= 0.40;
  }

  /// Isolates Arabic Unicode text sequences into distinct paragraph blocks
  static String isolateArabicBlocks(String text) {
    final arabicSequenceRegex = RegExp(
      r'(?:^|\n|\s)([\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF][\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s\.,،؛:!\-\(\)«»"”\x27\x22]{2,}[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF])(?:\s|\n|$)',
      unicode: true,
    );

    return text.replaceAllMapped(arabicSequenceRegex, (m) {
      final matched = m.group(1)!;
      final trimmed = matched.trim();
      final hasLatin = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]').hasMatch(trimmed);
      if (!hasLatin && isArabicText(trimmed)) {
        return '\n\n$trimmed\n\n';
      }
      return m.group(0)!;
    });
  }

  /// Resolves Arabic vocalized Unicode text for known Hadith references, verses and quotes
  static String? resolveKnownHadithArabic(String text) {
    return IslamicTextResolver.resolve(text);
  }

  /// Extracts footnote definitions from the bottom of the page and separates them from body text
  static ExtractedPageResult extractFootnotesAndBody(String rawPageText) {
    var text = deHyphenate(rawPageText);
    text = cleanScriptFontArtifacts(text);
    text = filterHeadersAndFooters(text);

    bool hadCorruptedCalligraphy = false;

    // 1. Detect and strip inline / leading corrupted font encoding glyph noise
    final embeddedNoiseRegex = RegExp(
      r':\s*[,.\s\x27\x22\(\)\\\/\-~_~;0-9a-zA-Z]*(?:tP|0fa|Gi|j,tlj|41S|hş4|r\u0131)[\s\S]*?(?=["”]\s*(?:Ey|Muhakkak|Kesinlikle|Şüphesiz|[A-ZÇĞİÖŞÜ]))',
      unicode: true,
    );
    if (embeddedNoiseRegex.hasMatch(text)) {
      hadCorruptedCalligraphy = true;
      text = text.replaceAll(embeddedNoiseRegex, ':\n\n📜 [Hadîs-i Şerîf Orijinal Metni]\n\n');
    }

    // Also check for trailing footnote definition in continuous text (e.g. "...bereket getirir.\"2 z Sünen-i Tinnizl, Kitabu'l-İsti'zan...")
    final footnoteList = <PageFootnote>[];

    final trailingHadithFootnoteRegex = RegExp(
      r'(\d{1,2}|[¹²³⁴⁵⁶⁷⁸⁹⁰]|\*)\s*(?:[1l|\/zZ]\s*)?(Sünen-i\s+|Sahih-i\s+|Buhari|Buhârî|Tirmizi|Tirmizî|Tinnizl|Tinnizi|Ebu\s+Davud|Ebû\s+Dâvûd|Ahmed\s+b\.\s+Hanbel|Nesai|Nesâî|İbn\s+Mace|İbn\s+Mâce|Kütüb-i\s+Sitte|Bu\s+Hadis)[\s\S]*?(?:Hadis\s+No\s*:\s*\d+|s\.\s*\d+|sayfa\s*\d+|c\.\s*\d+)[^\n\r]*',
      caseSensitive: false,
      unicode: true,
    );

    final trailingMatch = trailingHadithFootnoteRegex.firstMatch(text);
    if (trailingMatch != null && trailingMatch.start > text.length * 0.3) {
      final rawKey = trailingMatch.group(1)!;
      final rawContent = trailingMatch.group(0)!;
      final cleanContent = cleanOcrAndLigatures(rawContent.replaceFirst(RegExp(r'^\s*(\d{1,2}|[¹²³⁴⁵⁶⁷⁸⁹⁰]|\*)\s*(?:[1l|\/zZ]\s*)?'), ''));
      final normalizedKey = _normalizeFootnoteKey(rawKey);
      
      final sanitizedContent = cleanContent.replaceAll(RegExp(r'\s*(?:Aile İçindeki Edebler|İslâm.*Adab.*).*$', caseSensitive: false), '').trim();
      footnoteList.add(PageFootnote(key: normalizedKey, content: sanitizedContent));
      
      final beforeFootnote = text.substring(0, trailingMatch.start).trim();
      final hasAnchorAtEnd = RegExp(r'(\d{1,2}|[¹²³⁴⁵⁶⁷⁸⁹⁰]|\*|\[\d{1,2}\])$').hasMatch(beforeFootnote);
      text = hasAnchorAtEnd ? beforeFootnote : '$beforeFootnote${_toSuperscript(normalizedKey)}';
      text = text.replaceAll(RegExp(r'[_\-—=]{3,}\s*$'), '').trim();
    }

    // 2. Line-by-line processing for multi-line text
    final lines = text.split('\n');
    final bodyLines = <String>[];
    bool inFootnoteSection = false;

    final footnoteDividerRegex = RegExp(r'^\s*([_\-—=]{3,})\s*$');
    final strictFootnoteDefRegex = RegExp(r'^\s*(\d{1,2}|[¹²³⁴⁵⁶⁷⁸⁹⁰]|\*|\[\d{1,2}\]|\(\d{1,2}\))[.\s:—\-]\s*(.+)$');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (!inFootnoteSection) bodyLines.add('');
        continue;
      }

      // Check for garbage noise lines (corrupted font encoding)
      if (isGarbageNoise(line)) {
        hadCorruptedCalligraphy = true;
        continue;
      }

      // Check if we encountered a footnote separator line
      if (footnoteDividerRegex.hasMatch(line)) {
        inFootnoteSection = true;
        continue;
      }

      // Strict footnote check only in the bottom-most lines (last 3-4 lines or after divider)
      if (inFootnoteSection || (lines.length > 4 && i >= lines.length - 3)) {
        final fnMatch = strictFootnoteDefRegex.firstMatch(line);
        if (fnMatch != null) {
          inFootnoteSection = true;
          final rawKey = fnMatch.group(1)!;
          final content = cleanOcrAndLigatures(fnMatch.group(2)!);
          final normalizedKey = _normalizeFootnoteKey(rawKey);
          footnoteList.add(PageFootnote(key: normalizedKey, content: content));
          continue;
        }
      }

      if (inFootnoteSection) {
        if (footnoteList.isNotEmpty && line.isNotEmpty) {
          final last = footnoteList.removeLast();
          final updatedContent = '${last.content} ${cleanOcrAndLigatures(line)}';
          footnoteList.add(PageFootnote(key: last.key, content: updatedContent));
        }
      } else {
        bodyLines.add(line);
      }
    }

    var cleanBody = cleanOcrAndLigatures(bodyLines.join('\n'));

    // Separate fused headings from first paragraph if concatenated (e.g. "Eve Girip Çıkarken Selam Vermenin Önemi Eve girerken...")
    cleanBody = cleanBody.replaceAllMapped(
      RegExp(r'(^|\n)([\p{L}\s,\-’\x27]+(?:Önemi|Hakkında|Gereği|Bölümü|Adabı|Edebleri|Kuralları))\s+([A-ZÇĞİÖŞÜ][\p{L}]+)', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}\n\n${m.group(3)}',
    );

    // Separate quotes after dialogue colon (e.g. 'bana: "Ey oğulcağızım!' -> 'bana:\n\n"Ey oğulcağızım!')
    cleanBody = cleanBody.replaceAllMapped(
      RegExp(r'(\bbana:|\bbuyuruyor:)\s*([“"][A-ZÇĞİÖŞÜ])', unicode: true),
      (m) => '${m.group(1)}\n\n${m.group(2)}',
    );

    // Isolate Arabic Unicode blocks into dedicated paragraphs
    cleanBody = isolateArabicBlocks(cleanBody);

    return ExtractedPageResult(
      bodyText: cleanBody,
      footnotes: footnoteList,
      hadCorruptedCalligraphy: hadCorruptedCalligraphy,
    );
  }

  static String _normalizeFootnoteKey(String raw) {
    var key = raw.replaceAll(RegExp(r'[\[\]\(\)\.\:\-\s"”’“\x27\x22]'), '');
    const superscriptMap = {
      '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5',
      '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9', '⁰': '0',
    };
    for (final entry in superscriptMap.entries) {
      key = key.replaceAll(entry.key, entry.value);
    }
    return key.isEmpty ? '*' : key;
  }

  static String _toSuperscript(String key) {
    const map = {
      '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵',
      '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '0': '⁰',
    };
    return key.split('').map((c) => map[c] ?? c).join();
  }

  /// Segments clean body text into structured paragraphs with inline footnote anchors
  static List<ParagraphSegment> segmentIntoParagraphs(
    String bodyText, {
    List<PageFootnote> pageFootnotes = const [],
    bool hadCorruptedCalligraphy = false,
  }) {
    final rawBlocks = bodyText.split(RegExp(r'\n\s*\n'));
    final segments = <ParagraphSegment>[];

    final knownArabic = hadCorruptedCalligraphy ? resolveKnownHadithArabic(bodyText) : null;

    // If page had an unextractable Arabic calligraphy block at top and not inside blocks
    if (hadCorruptedCalligraphy && !rawBlocks.any((b) => b.contains('📜'))) {
      if (knownArabic != null) {
        segments.add(ParagraphSegment(
          rawText: knownArabic,
          isArabic: true,
        ));
      }
    }

    final footnoteAnchorRegex = RegExp(
      r'([”"]\s*(\d{1,2})|[¹²³⁴⁵⁶⁷⁸⁹⁰]|\b\.\s*(\d{1,2})\b|\[(\d{1,2}|\*|\†)\]|\((\d{1,2}|\*|\†)\))',
    );

    for (final block in rawBlocks) {
      final text = block.trim();
      if (text.isEmpty) continue;

      if (isGarbageNoise(text)) continue;

      // Handle Calligraphy Fallback / Hadith marker
      if (text.contains('📜 [Hadîs-i Şerîf Orijinal Metni]') || text.contains('📜 Asıl Hat / Arapça Metin')) {
        final blockArabic = resolveKnownHadithArabic(bodyText);
        if (blockArabic != null) {
          segments.add(ParagraphSegment(
            rawText: blockArabic,
            isArabic: true,
          ));
        }
        continue;
      }

      final isArabic = isArabicText(text);
      
      final isHeading = !isArabic &&
          text.length < 80 &&
          !text.endsWith('.') &&
          !text.endsWith('!') &&
          !text.endsWith('?') &&
          (text.startsWith('#') ||
              (text.toUpperCase() == text && text.length >= 3 && RegExp(r'[\p{L}]', unicode: true).hasMatch(text)) ||
              text.startsWith('BÖLÜM') ||
              text.startsWith('Bölüm') ||
              text.startsWith('FASIL') ||
              text.startsWith('BAB') ||
              RegExp(r'^[A-ZÇĞİÖŞÜ][\p{L}\s,\-’\x27]+(?:Önemi|Hakkında|Gereği|Bölümü|Adabı|Edebleri|Kuralları)$', unicode: true).hasMatch(text));

      final anchors = <FootnoteAnchor>[];
      for (final match in footnoteAnchorRegex.allMatches(text)) {
        final matchStr = match.group(0)!;
        final cleanKey = _normalizeFootnoteKey(matchStr);

        String? resolvedContent;
        for (final fn in pageFootnotes) {
          if (fn.key == cleanKey) {
            resolvedContent = fn.content;
            break;
          }
        }

        anchors.add(FootnoteAnchor(
          key: cleanKey,
          indexInText: match.start,
          content: resolvedContent,
        ));
      }

      // Re-flow intra-paragraph newlines for non-heading paragraphs to provide smooth fluid reading
      final reflowedText = isHeading
          ? text
          : text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ').replaceAll(RegExp(r'[ \t]{2,}'), ' ');

      segments.add(ParagraphSegment(
        rawText: reflowedText,
        isHeading: isHeading,
        isArabic: isArabic,
        footnoteAnchors: anchors,
      ));
    }

    return segments;
  }

  /// Converts text into Bionic Reading TextSpans (Bold start for rapid saccadic eye movement)
  static List<TextSpan> buildBionicSpans(
    String text, {
    required TextStyle normalStyle,
    required TextStyle boldStyle,
  }) {
    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final length = word.length;
      final highlightLength = (length <= 3) ? 1 : (length <= 6 ? 2 : (length * 0.45).round());

      final boldPart = word.substring(0, highlightLength);
      final restPart = word.substring(highlightLength);

      spans.add(TextSpan(text: boldPart, style: boldStyle));
      spans.add(TextSpan(text: restPart, style: normalStyle));

      if (i < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: normalStyle));
      }
    }

    return spans;
  }
}
