import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/engine/encoding_normalizer.dart';
import 'package:tahrir/features/reader/engine/glyph_reverse_mapper.dart';
import 'package:tahrir/features/reader/engine/layout_column_detector.dart';
import 'package:tahrir/features/reader/engine/smart_reflow_pipeline.dart';
import 'package:tahrir/features/reader/engine/snippet_detector.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';

void main() {
  group('1. EncodingNormalizer Tests', () {
    test('Turkish Legacy Encoding Repair (Ý, Þ, ð, ý, þ, ligatures)', () {
      const corrupted = 'Ýstanbul ve Ýzmir’de kapýlarýn açýlmasý, baþlýca deðiþiklikler ve ﬁkri geliþim.';
      final normalized = EncodingNormalizer.normalizeEncodings(corrupted);
      expect(normalized, 'İstanbul ve İzmir’de kapıların açılması, başlıca değişiklikler ve fikri gelişim.');
    });

    test('De-hyphenation across line breaks', () {
      const hyphenated = 'Eve girip çıkarken müste-\nşar kapıyı yavaş-\nça kapatmalı ve edep-\nli davranmalıdır.';
      final dehyphenated = EncodingNormalizer.deHyphenate(hyphenated);
      expect(dehyphenated.contains('müsteşar'), isTrue);
      expect(dehyphenated.contains('yavaşça'), isTrue);
      expect(dehyphenated.contains('edepli'), isTrue);
    });

    test('Header/Footer Stripping (%5-6 top and bottom)', () {
      const fullPage = '''
- 42 -
Bölüm 3: Adab-ı Muaşeret
Kapıyı Yavaşça Açıp Kapatmanın Önemi
Eve girerken kapıyı yavaşça kapatmak edeptendir.
Bunu her mümin tatbik etmelidir.
İslâm'da Adab-ı Muaşeret Görgü Kuralları 42
''';
      final stripped = EncodingNormalizer.stripHeaderAndFooter(fullPage);
      expect(stripped.contains('- 42 -'), isFalse);
      expect(stripped.contains('Kapıyı Yavaşça Açıp Kapatmanın Önemi'), isTrue);
    });
  });

  group('2. LayoutColumnDetector Tests', () {
    test('Two-column layout detection and top-to-bottom reading order', () {
      const pageWidth = 600.0;
      const pageHeight = 800.0;

      // Sol sütun satırları (X: 50, Y: 100, 150, 200)
      // Sağ sütun satırları (X: 350, Y: 100, 150, 200)
      final rawLines = [
        const PositionedTextLine(text: 'Sol Satır 1', bounds: Rect.fromLTWH(50, 100, 200, 20)),
        const PositionedTextLine(text: 'Sağ Satır 1', bounds: Rect.fromLTWH(350, 100, 200, 20)),
        const PositionedTextLine(text: 'Sol Satır 2', bounds: Rect.fromLTWH(50, 150, 200, 20)),
        const PositionedTextLine(text: 'Sağ Satır 2', bounds: Rect.fromLTWH(350, 150, 200, 20)),
        const PositionedTextLine(text: 'Sol Satır 3', bounds: Rect.fromLTWH(50, 200, 200, 20)),
        const PositionedTextLine(text: 'Sağ Satır 3', bounds: Rect.fromLTWH(350, 200, 200, 20)),
        const PositionedTextLine(text: 'Sol Satır 4', bounds: Rect.fromLTWH(50, 250, 200, 20)),
        const PositionedTextLine(text: 'Sağ Satır 4', bounds: Rect.fromLTWH(350, 250, 200, 20)),
      ];

      final ordered = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: rawLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      final texts = ordered.map((l) => l.text).toList();
      // Sol sütunun tamamı sağ sütundan önce gelmeli
      expect(texts.indexOf('Sol Satır 1') < texts.indexOf('Sol Satır 2'), isTrue);
      expect(texts.indexOf('Sol Satır 4') < texts.indexOf('Sağ Satır 1'), isTrue);
      expect(texts.indexOf('Sağ Satır 1') < texts.indexOf('Sağ Satır 2'), isTrue);
    });
  });

  group('3. SnippetDetector Tests', () {
    test('Detects corrupted CMap / ASCII symbol noise as Arabic calligraphy candidates', () {
      const pageWidth = 500.0;
      const pageHeight = 700.0;

      final lines = [
        const PositionedTextLine(text: 'BÖLÜM 1', bounds: Rect.fromLTWH(40, 80, 200, 20)),
        const PositionedTextLine(text: '... tP ... j,tlj \\ rı ...', bounds: Rect.fromLTWH(40, 150, 300, 30)),
        const PositionedTextLine(text: 'Eve girerken kapıyı yavaşça kapat.', bounds: Rect.fromLTWH(40, 220, 400, 20)),
      ];

      final snippets = SnippetDetector.detectSnippets(
        lines: lines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(snippets.any((s) => s.type == SnippetType.arabicCalligraphy), isTrue);
    });

    test('Detects table structures', () {
      const pageWidth = 500.0;
      const pageHeight = 700.0;

      final lines = [
        const PositionedTextLine(text: 'Sıra \t İsim \t Değer', bounds: Rect.fromLTWH(40, 100, 300, 20)),
        const PositionedTextLine(text: '1    \t Ali  \t 100', bounds: Rect.fromLTWH(40, 130, 300, 20)),
        const PositionedTextLine(text: '2    \t Veli \t 200', bounds: Rect.fromLTWH(40, 160, 300, 20)),
        const PositionedTextLine(text: '3    \t Ayşe \t 300', bounds: Rect.fromLTWH(40, 190, 300, 20)),
      ];

      final snippets = SnippetDetector.detectSnippets(
        lines: lines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(snippets.any((s) => s.type == SnippetType.table), isTrue);
    });
  });

  group('4. ContentBlock Sealed Class Hierarchy Tests', () {
    test('Sealed class pattern matching on ContentBlock', () {
      const ContentBlock text = TextBlock(text: 'Örnek metin');
      const ContentBlock snippet = InteractiveSnippetBlock(
        type: SnippetType.arabicCalligraphy,
        title: 'Hadîs-i Şerîf',
        croppedImagePath: '/path/to/crop.png',
      );
      const ContentBlock header = CalligraphyHeaderBlock(
        title: 'Başlık',
        croppedImagePath: '/path/to/header.png',
      );

      String getTypeName(ContentBlock block) {
        return switch (block) {
          TextBlock() => 'text',
          InteractiveSnippetBlock() => 'snippet',
          CalligraphyHeaderBlock() => 'header',
          OpticalInkBlock() => 'optical_ink',
        };
      }

      expect(getTypeName(text), 'text');
      expect(getTypeName(snippet), 'snippet');
      expect(getTypeName(header), 'header');
    });
  });

  group('5. Smart Reflow Clean Extraction Tests', () {
    test('SmartReflowPipeline produces clean TextBlocks with Arabic block and no random image snippets', () async {
      const pipeline = SmartReflowPipeline();
      final blocks = await pipeline.processPage(
        filePath: 'sample://adab_muaseret',
        pageIndex: 0,
      );

      expect(blocks, isNotEmpty);
      expect(blocks.every((b) => b is TextBlock), isTrue);
      
      final arabicBlock = blocks.whereType<TextBlock>().firstWhere((b) => b.isArabic);
      expect(arabicBlock.text, contains('إِنَّ الرِّفْقَ'));
    });
  });

  group('6. Turkish Literature & General Book Reflow Stability Tests (Cemil Meriç Case)', () {
    test('Cemil Meriç Bu Ülke: Correctly identifies headings, preserves "fikir", "Cemil Meriç", quotes, and never misclassifies as Arabic', () {
      const page9RawText = '''
ENTELEKTÜEL BİR OTOBİYOGRAFİ

Kimim ben? Hayatını, Türk
irfanına adayan, münzevi
ve mütecessis bir fikir işçisi.

1970'te Cemil Meriç'le ilgili, o daha hayattayken bir biyografi yazmak çok zor ve biraz da zamansız geldi bize. Kaldı ki, Cemil Meriç'in "Jurnal"inde, mektuplarında, kitaplarında çeşitli zaman ve vesilelerle yapılmış röportajlarda öyle bir kendini tanıma ve tanıtma cehdi vardır ki...
''';

      final mappedGlifs = GlyphReverseMapper.reverseMap(page9RawText);
      final normalizedText = EncodingNormalizer.normalizeEncodings(mappedGlifs);
      final dehyphenatedText = EncodingNormalizer.deHyphenate(normalizedText);
      final headerStripped = EncodingNormalizer.stripHeaderAndFooter(dehyphenatedText);
      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(headerStripped);
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);

      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        pageResult.bodyText,
        pageFootnotes: pageResult.footnotes,
      );

      expect(paragraphs.length, greaterThanOrEqualTo(3));

      // 1. Heading block check
      final heading = paragraphs[0];
      expect(heading.isHeading, isTrue);
      expect(heading.isArabic, isFalse);
      expect(heading.rawText, equals('ENTELEKTÜEL BİR OTOBİYOGRAFİ'));

      // 2. First paragraph check: "fikir" must not be converted to "Akir"
      final firstPara = paragraphs[1];
      expect(firstPara.isHeading, isFalse);
      expect(firstPara.isArabic, isFalse);
      expect(firstPara.rawText, contains('fikir işçisi'));
      expect(firstPara.rawText, isNot(contains('Akir')));
      expect(firstPara.rawText, contains('münzevi'));
      expect(firstPara.rawText, contains('mütecessis'));

      // 3. Second paragraph check: "Cemil Meriç", quotes, and 1970'te must be intact
      final secondPara = paragraphs[2];
      expect(secondPara.isHeading, isFalse);
      expect(secondPara.isArabic, isFalse);
      expect(secondPara.rawText, contains('1970\'te'));
      expect(secondPara.rawText, contains('Cemil Meriç'));
      expect(secondPara.rawText, contains('"Jurnal"inde'));
      expect(secondPara.rawText, contains('biyografi'));

      // 4. Ensure no paragraph in this literary text is flagged as Arabic
      expect(paragraphs.every((p) => p.isArabic == false), isTrue);
    });
  });
}
