import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../domain/content_block.dart';
import '../services/pdf_snippet_cropper.dart';
import '../services/scanned_pdf_ocr_service.dart';
import 'encoding_normalizer.dart';
import 'glyph_reverse_mapper.dart';
import 'layout_column_detector.dart';
import 'text_segmenter.dart';

/// Pipeline sayfa analiz sonucu (içerik blokları ve Latin dışı/hat bayrağı)
@immutable
class PipelinePageResult {
  final List<ContentBlock> blocks;
  final bool hasNonLatinOrVisualWarning;

  const PipelinePageResult({
    required this.blocks,
    this.hasNonLatinOrVisualWarning = false,
  });
}

/// Pipeline'ın Isolate içinde çalıştırılan ham metin ve satır çıkarma parametreleri
class _PdfExtractParams {
  final Uint8List pdfBytes;
  final int pageIndex;

  _PdfExtractParams({
    required this.pdfBytes,
    required this.pageIndex,
  });
}

/// Isolate çıktısı ham sayfa analizi
class _RawPageAnalysis {
  final List<PositionedTextLine> lines;
  final double pageWidth;
  final double pageHeight;
  final String rawText;

  _RawPageAnalysis({
    required this.lines,
    required this.pageWidth,
    required this.pageHeight,
    required this.rawText,
  });
}

/// Görsel Öncelikli Hibrit Akıllı Okuma (Smart Reflow + Interactive Snippets) Orkestratör Pipeline'ı
class SmartReflowPipeline {
  static final Map<String, Uint8List> _pdfBytesCache = {};

  final PdfSnippetCropper? snippetCropper;
  final ScannedPdfOcrService scannedOcrService;

  const SmartReflowPipeline({
    this.snippetCropper,
    this.scannedOcrService = const ScannedPdfOcrService(),
  });

  static Future<Uint8List> _getPdfBytes(File file, String filePath) async {
    final cached = _pdfBytesCache.remove(filePath);
    if (cached != null) {
      _pdfBytesCache[filePath] = cached;
      return cached;
    }
    final bytes = await file.readAsBytes();
    if (_pdfBytesCache.length >= 3) {
      _pdfBytesCache.remove(_pdfBytesCache.keys.first);
    }
    _pdfBytesCache[filePath] = bytes;
    return bytes;
  }

  /// PDF sayfasını analiz eder ve blok listesi ile Latin dışı uyarı bayrağını döndürür.
  Future<PipelinePageResult> processPageDetailed({
    required String filePath,
    required int pageIndex,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return PipelinePageResult(blocks: _generateSampleBlocks(filePath, pageIndex));
    }

    try {
      final bytes = await _getPdfBytes(file, filePath);

      // 1. ADIM: Isolate içinde PDF dijital metin ve koordinat çıkarımı
      final analysis = await compute(
        _isolateExtractPdfLines,
        _PdfExtractParams(pdfBytes: bytes, pageIndex: pageIndex),
      );

      // EĞER DİJİTAL METİN AKIŞI YOKSA -> TARANMIŞ PDF OCR SERVİSİNİ TETİKLE
      if (analysis.lines.isEmpty && analysis.rawText.trim().isEmpty) {
        final ocrResult = await scannedOcrService.processScannedPage(
          filePath: filePath,
          pageIndex: pageIndex,
          originalPageWidth: analysis.pageWidth,
          originalPageHeight: analysis.pageHeight,
        );

        return PipelinePageResult(
          blocks: ocrResult.blocks,
          hasNonLatinOrVisualWarning: ocrResult.hasNonLatinOrVisualWarning,
        );
      }

      // 2. ADIM: Koordinat Bazlı Sütun Tespiti ve Okuma Sıralaması
      final orderedLines = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: analysis.lines,
        pageWidth: analysis.pageWidth,
        pageHeight: analysis.pageHeight,
      );

      // 3. ADIM: Metin Temizleme, Kodlama Onarımı (EncodingNormalizer) & De-hyphenation
      final rawExtractedText = orderedLines.isNotEmpty
          ? _joinOrderedLinesWithParagraphBreaks(orderedLines, analysis.pageWidth)
          : analysis.rawText;

      final mappedGlifs = GlyphReverseMapper.reverseMap(rawExtractedText);
      final normalizedText = EncodingNormalizer.normalizeEncodings(mappedGlifs);
      final dehyphenatedText = EncodingNormalizer.deHyphenate(normalizedText);
      final headerStrippedText = EncodingNormalizer.stripHeaderAndFooter(dehyphenatedText);
      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(headerStrippedText);

      // 4. ADIM: Dipnotları ve Gövdeyi Ayrıştır
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);

      // 5. ADIM: Paragraflara Böl ve ContentBlock Listesini İnşa Et
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        pageResult.bodyText,
        pageFootnotes: pageResult.footnotes,
        hadCorruptedCalligraphy: pageResult.hadCorruptedCalligraphy,
      );

      final blocks = <ContentBlock>[];
      for (final para in paragraphs) {
        if (para.isCalligraphyFallback) continue;
        blocks.add(TextBlock(
          text: para.rawText,
          isHeading: para.isHeading,
          isArabic: para.isArabic,
          footnoteAnchors: para.footnoteAnchors,
        ));
      }

      final hasNonLatin = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(cleanText) ||
          pageResult.hadCorruptedCalligraphy;

      return PipelinePageResult(
        blocks: blocks,
        hasNonLatinOrVisualWarning: hasNonLatin,
      );
    } catch (e) {
      debugPrint('SmartReflowPipeline error: $e');
      return PipelinePageResult(blocks: _generateSampleBlocks(filePath, pageIndex));
    }
  }

  /// Ardışık satırlar arasındaki dikey boşluk, satır başı girintisi, erken satır sonu noktalaması
  /// ve punto farklarını analiz ederek paragraf ayrımlarını (`\n\n`) veya satır içi devamı (`\n`) belirler.
  static String _joinOrderedLinesWithParagraphBreaks(
    List<PositionedTextLine> orderedLines,
    double pageWidth,
  ) {
    if (orderedLines.isEmpty) return '';
    final buffer = StringBuffer(orderedLines.first.text);

    for (int i = 1; i < orderedLines.length; i++) {
      final prev = orderedLines[i - 1];
      final curr = orderedLines[i];

      final prevHeight = prev.bounds.height > 0 ? prev.bounds.height : 14.0;
      final verticalGap = curr.bounds.top - prev.bounds.bottom;
      final hasLargeVerticalGap = verticalGap > prevHeight * 0.65;
      final hasParagraphIndent = (curr.bounds.left - prev.bounds.left) > 14.0;

      final prevTrimmed = prev.text.trimRight();
      final endsWithTerminalPunct = prevTrimmed.isNotEmpty &&
          (prevTrimmed.endsWith('.') ||
              prevTrimmed.endsWith('!') ||
              prevTrimmed.endsWith('?') ||
              prevTrimmed.endsWith(':') ||
              prevTrimmed.endsWith('”') ||
              prevTrimmed.endsWith('"'));
      final isShortLineEnd = pageWidth > 0 && prev.bounds.right < pageWidth * 0.72;
      final hasEarlySentenceBreak = endsWithTerminalPunct && isShortLineEnd;

      final hasFontSizeJump =
          prev.bounds.height > 0 && curr.bounds.height > prev.bounds.height * 1.22;

      if (hasLargeVerticalGap ||
          hasParagraphIndent ||
          hasEarlySentenceBreak ||
          hasFontSizeJump) {
        buffer.write('\n\n');
      } else {
        buffer.write('\n');
      }
      buffer.write(curr.text);
    }

    return buffer.toString();
  }

  /// PDF dosyasından belirtilen sayfayı analiz eder ve UI'ın doğrudan tüketebileceği
  /// `List<ContentBlock>` listesini döndürür (Geriye dönük uyumluluk).
  Future<List<ContentBlock>> processPage({
    required String filePath,
    required int pageIndex,
  }) async {
    final res = await processPageDetailed(filePath: filePath, pageIndex: pageIndex);
    return res.blocks;
  }

  /// Isolate içinde Syncfusion ile PDF satır ve koordinat çıkarımı
  static _RawPageAnalysis _isolateExtractPdfLines(_PdfExtractParams params) {
    try {
      final doc = PdfDocument(inputBytes: params.pdfBytes);
      if (params.pageIndex >= doc.pages.count) {
        doc.dispose();
        return _RawPageAnalysis(lines: [], pageWidth: 0, pageHeight: 0, rawText: '');
      }

      final page = doc.pages[params.pageIndex];
      final pageWidth = page.size.width;
      final pageHeight = page.size.height;

      final textExtractor = PdfTextExtractor(doc);
      final rawText = textExtractor.extractText(
        startPageIndex: params.pageIndex,
        endPageIndex: params.pageIndex,
      );

      final extractedLines = <PositionedTextLine>[];
      try {
        final textLines = textExtractor.extractTextLines(
          startPageIndex: params.pageIndex,
          endPageIndex: params.pageIndex,
        );

        for (final l in textLines) {
          final bounds = l.bounds;
          extractedLines.add(PositionedTextLine(
            text: l.text,
            bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
            fontSize: bounds.height > 0 ? bounds.height : 12.0,
          ));
        }
      } catch (_) {}

      doc.dispose();

      return _RawPageAnalysis(
        lines: extractedLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        rawText: rawText,
      );
    } catch (e) {
      return _RawPageAnalysis(lines: [], pageWidth: 0, pageHeight: 0, rawText: '');
    }
  }

  /// Örnek / fallback içerik blokları
  List<ContentBlock> _generateSampleBlocks(String filePath, int pageIndex) {
    return [
      const TextBlock(
        text: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
        isHeading: true,
      ),
      const TextBlock(
        text: 'Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Âişe (radıyallâhu \'anhâ) validemizin Resûlullah (sallallâhu \'aleyhi ve sellem)\'den rivayet ettiği şu Hadîs-i Şerîfi duymuşsundur:',
      ),
      const TextBlock(
        text: 'إِنَّ الرِّفْقَ لَا يَكُونُ فِي شَيْءٍ إِلَّا زَانَهُ، وَلَا يُنْزَعُ مِنْ شَيْءٍ إِلَّا شَانَهُ',
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
  }
}
