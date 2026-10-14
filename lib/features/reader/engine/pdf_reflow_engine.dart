import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/content_block.dart';
import 'smart_reflow_pipeline.dart';
import 'text_segmenter.dart';

class ReflowPageData {
  final int pageNumber;
  final String rawText;
  final List<ParagraphSegment> paragraphs;
  final List<ContentBlock> contentBlocks;
  final List<PageFootnote> footnotes;
  final List<String> extractedImages;
  final bool hasTextContent;
  final bool isCoverOrImagePage;
  final bool hadCorruptedCalligraphy;
  final bool isOcrEnhanced;
  final bool hasNonLatinOrVisualWarning;

  ReflowPageData({
    required this.pageNumber,
    required this.rawText,
    required this.paragraphs,
    this.contentBlocks = const [],
    this.footnotes = const [],
    this.extractedImages = const [],
    this.hasTextContent = true,
    this.isCoverOrImagePage = false,
    this.hadCorruptedCalligraphy = false,
    this.isOcrEnhanced = false,
    this.hasNonLatinOrVisualWarning = false,
  });
}

class PdfReflowEngine {
  final SmartReflowPipeline pipeline;

  const PdfReflowEngine({
    this.pipeline = const SmartReflowPipeline(),
  });

  /// PDF sayfasından akıllı metin, glif onarımı, 300 DPI kesit kırpıcı ve dipnotları ayrıştırır.
  Future<ReflowPageData> extractPage(String filePath, int pageIndex) async {
    // Sanal / örnek kitaplar için yerleşik veri üret
    if (filePath.startsWith('sample://')) {
      return _generateSamplePage(filePath, pageIndex);
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return _generateSamplePage('sample://fallback', pageIndex);
    }

    try {
      // 1. Akıllı Hibrit Reflow & Snippet Pipeline'ını çalıştır
      final pipelineResult = await pipeline.processPageDetailed(
        filePath: filePath,
        pageIndex: pageIndex,
      );
      final contentBlocks = pipelineResult.blocks;
      final hasNonLatinWarning = pipelineResult.hasNonLatinOrVisualWarning;

      // 2. Geriye dönük uyumluluk için ParagraphSegment listesini türet
      final paragraphs = <ParagraphSegment>[];
      final extractedFootnotes = <PageFootnote>[];

      for (final block in contentBlocks) {
        switch (block) {
          case TextBlock():
            paragraphs.add(ParagraphSegment(
              rawText: block.text,
              isHeading: block.isHeading,
              isArabic: block.isArabic,
              footnoteAnchors: block.footnoteAnchors,
            ));
            for (final anchor in block.footnoteAnchors) {
              if (anchor.content != null && !extractedFootnotes.any((f) => f.key == anchor.key)) {
                extractedFootnotes.add(PageFootnote(key: anchor.key, content: anchor.content!));
              }
            }
          case InteractiveSnippetBlock():
            paragraphs.add(ParagraphSegment(
              rawText: block.fallbackText ?? block.title,
              isCalligraphyFallback: block.type == SnippetType.arabicCalligraphy,
              isImagePlaceholder: true,
              imagePath: block.croppedImagePath,
              imageBytes: block.rawBytes,
            ));
          case CalligraphyHeaderBlock():
            paragraphs.insert(0, ParagraphSegment(
              rawText: block.title,
              isHeading: true,
              isCalligraphyFallback: true,
              imagePath: block.croppedImagePath,
              imageBytes: block.rawBytes,
            ));
        }
      }

      final hasText = contentBlocks.isNotEmpty;
      final isCoverOrImage = !hasText || (pageIndex == 0 && contentBlocks.length <= 1);

      // Ham metni birleştir
      final rawText = contentBlocks
          .whereType<TextBlock>()
          .map((t) => t.text)
          .join('\n\n');

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: rawText,
        paragraphs: paragraphs,
        contentBlocks: contentBlocks,
        footnotes: extractedFootnotes,
        hasTextContent: hasText,
        isCoverOrImagePage: isCoverOrImage,
        hadCorruptedCalligraphy: paragraphs.any((p) => p.isArabic || p.isCalligraphyFallback),
        isOcrEnhanced: true,
        hasNonLatinOrVisualWarning: hasNonLatinWarning,
      );
    } catch (e) {
      debugPrint('PdfReflowEngine extraction exception: $e');
      return _generateSamplePage(filePath, pageIndex);
    }
  }

  ReflowPageData _generateSamplePage(String identifier, int pageIndex) {
    if (identifier.contains('adab') || identifier.contains('muaseret')) {
      const sampleArabic = 'إِنَّ الرِّفْقَ لَا يَكُونُ فِي شَيْءٍ إِلَّا زَانَهُ، وَلَا يُنْزَعُ مِنْ شَيْءٍ إِلَّا شَانَهُ';
      final sampleFootnotes = [
        const PageFootnote(
          key: '1',
          content: 'Sahih-i Müslim, Kitabu\'l-Birr, Sıla ve Âdab, c.4, s.2004, Hadis No:2594',
        ),
      ];

      final sampleBlocks = <ContentBlock>[
        const TextBlock(
          text: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
          isHeading: true,
        ),
        const TextBlock(
          text: 'Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Âişe (radıyallâhu \'anhâ) validemizin Resûlullah (sallallâhu \'aleyhi ve sellem)\'den rivayet ettiği şu Hadîs-i Şerîfi duymuşsundur:',
        ),
        const TextBlock(
          text: sampleArabic,
          isArabic: true,
        ),
        const TextBlock(
          text: '“Muhakkak ki yumuşaklık (kibarlık) bulunduğu şeyi güzelleştirir. Bir şeyden yumuşaklığı alındığı zaman da bu alınma o şeyi çirkinleştirir.”¹',
          footnoteAnchors: [
            FootnoteAnchor(
              key: '1',
              indexInText: 133,
              content: 'Sahih-i Müslim, Kitabu\'l-Birr, Sıla ve Âdab, c.4, s.2004, Hadis No:2594',
            ),
          ],
        ),
      ];

      final sampleParagraphs = [
        ParagraphSegment(
          rawText: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
          isHeading: true,
        ),
        ParagraphSegment(
          rawText: 'Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Âişe (radıyallâhu \'anhâ) validemizin Resûlullah (sallallâhu \'aleyhi ve sellem)\'den rivayet ettiği şu Hadîs-i Şerîfi duymuşsundur:',
        ),
        ParagraphSegment(
          rawText: sampleArabic,
          isArabic: true,
        ),
        ParagraphSegment(
          rawText: '“Muhakkak ki yumuşaklık (kibarlık) bulunduğu şeyi güzelleştirir. Bir şeyden yumuşaklığı alındığı zaman da bu alınma o şeyi çirkinleştirir.”¹',
          footnoteAnchors: [
            FootnoteAnchor(key: '1', indexInText: 133, content: sampleFootnotes.first.content),
          ],
        ),
      ];

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
        paragraphs: sampleParagraphs,
        contentBlocks: sampleBlocks,
        footnotes: sampleFootnotes,
        hasTextContent: true,
        isCoverOrImagePage: false,
        hadCorruptedCalligraphy: false,
        isOcrEnhanced: true,
      );
    }

    if (identifier.contains('kutadgu_bilig')) {
      final content = '''
BÖLÜM ${pageIndex + 1}: KUT VE ADALET ÜZERİNE

Bayat atı birle sözüg başladım,
Törütgen igidgen keçürgen idim. [1]

Kişi gönlünü akıl ile süsler, aklı ise bilgi ile aydınlatır. Söz söyleyen insan akıllı olmalı, dinleyen insan ise anlayan ve tartan olmalı. Dünya mülkü geçicidir; kalıcı olan ise adalet ve doğruluk üzerine kurulmuş nizâmdır.

Beylik makamına oturan kişi gözünü adalet terazisinden ayırmamalıdır. Güneş gibi herkese eşit ışık vermeli, gece gibi kusurları örtmelidir. [2]

Akıl nerede olursa, orada ululuk olur; bilgi kimde bulunursa, o büyüklük kazanır.
''';
      final sampleFootnotes = [
        const PageFootnote(key: '1', content: 'Kutadgu Bilig 1. Beyit: "Tanrı adıyla söze başladım; O yaratan, besleyen ve bağışlayan Rabbimdir."'),
        const PageFootnote(key: '2', content: 'Kutadgu Bilig Adalet Temsili: Hükümdar Kün-Toğdı (Güneş Doğdu) adaleti ve kanunu simgeler.'),
      ];

      final paragraphs = TextSegmenter.segmentIntoParagraphs(content, pageFootnotes: sampleFootnotes);
      final blocks = paragraphs.map((p) {
        return TextBlock(
          text: p.rawText,
          isHeading: p.isHeading,
          isArabic: p.isArabic,
          footnoteAnchors: p.footnoteAnchors,
        );
      }).toList();

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: content,
        paragraphs: paragraphs,
        contentBlocks: blocks,
        footnotes: sampleFootnotes,
        hasTextContent: true,
        isCoverOrImagePage: false,
      );
    }

    final defaultText = '''
BÖLÜM ${pageIndex + 1}: TAHRİR İLE OKUMA DENEYİMİ

Okumak, zihnin sonsuz vadilerinde yapılan en zarif seyahattir. [1] Bir kitabın sayfaları arasında gezinirken zamanın ve mekânın sınırları silinir; insan kendini düşüncenin saf akışına bırakır.

Gözlerin satırlar üzerinde zahmetsizce akması, tipografinin zarafeti ve sessizliğin derinliği ile birleştiğinde okuma bir alışkanlıktan öte, ruhani bir sığınak haline gelir. [*]
''';
    final sampleFootnotes = [
      const PageFootnote(key: '1', content: 'Tahrir Şerhi: Okuma eyleminin bilişsel akış (Flow State) teorisindeki yeri.'),
      const PageFootnote(key: '*', content: 'Lügat: Ruhani Sığınak - Dış dünyadan soyutlanarak derin odaklanma sağlanan manevi zemin.'),
    ];

    final paragraphs = TextSegmenter.segmentIntoParagraphs(defaultText, pageFootnotes: sampleFootnotes);
    final blocks = paragraphs.map((p) {
      return TextBlock(
        text: p.rawText,
        isHeading: p.isHeading,
        isArabic: p.isArabic,
        footnoteAnchors: p.footnoteAnchors,
      );
    }).toList();

    return ReflowPageData(
      pageNumber: pageIndex + 1,
      rawText: defaultText,
      paragraphs: paragraphs,
      contentBlocks: blocks,
      footnotes: sampleFootnotes,
      hasTextContent: true,
      isCoverOrImagePage: false,
    );
  }
}
