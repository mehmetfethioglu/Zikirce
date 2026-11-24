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
import 'ocr_proofreader_engine.dart';
import 'ocr_text_healer.dart';
import 'text_segmenter.dart';

/// Pipeline sayfa analiz sonucu (içerik blokları, Latin dışı/hat bayrağı ve OCR Gözden Geçir raporu)
@immutable
class PipelinePageResult {
  final List<ContentBlock> blocks;
  final bool hasNonLatinOrVisualWarning;
  final OcrPageReviewReport ocrReviewReport;

  const PipelinePageResult({
    required this.blocks,
    this.hasNonLatinOrVisualWarning = false,
    this.ocrReviewReport = const OcrPageReviewReport.empty(),
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
  final Map<String, String> crossPageFootnotes;

  _RawPageAnalysis({
    required this.lines,
    required this.pageWidth,
    required this.pageHeight,
    required this.rawText,
    this.crossPageFootnotes = const {},
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
    if (filePath.startsWith('sample://')) {
      return PipelinePageResult(blocks: _generateSampleBlocks(filePath, pageIndex));
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const PipelinePageResult(
        blocks: [
          TextBlock(
            text:
                "Bu sayfanın dijital metin katmanı okunamadı. Üst bardaki 'PDF' sekmesinden orijinal sayfa görünümüne geçebilirsiniz.",
          ),
        ],
      );
    }

    try {
      // 0. ADIM: SQLite önbelleğinde daha önce OCR yapılmış veya tashih edilmiş sayfa varsa 0ms'de getir
      final cachedPage = await scannedOcrService.tryGetCachedOrCorrectedPage(
        filePath: filePath,
        pageIndex: pageIndex,
      );
      if (cachedPage != null && cachedPage.blocks.isNotEmpty) {
        return PipelinePageResult(
          blocks: cachedPage.blocks,
          hasNonLatinOrVisualWarning: cachedPage.hasNonLatinOrVisualWarning,
          ocrReviewReport: cachedPage.ocrReviewReport,
        );
      }

      final bytes = await _getPdfBytes(file, filePath);

      // 1. ADIM: Isolate içinde PDF dijital metin ve koordinat çıkarımı
      final analysis = await compute(
        _isolateExtractPdfLines,
        _PdfExtractParams(pdfBytes: bytes, pageIndex: pageIndex),
      );

      final isEmptyDigitalText = analysis.lines.isEmpty && analysis.rawText.trim().isEmpty;
      final isDirtyEmbeddedOcr =
          !isEmptyDigitalText && OcrTextHealer.isDirtyEmbeddedOcrLayer(analysis.rawText);

      // EĞER DİJİTAL METİN AKIŞI YOKSA VEYA GÖMÜLÜ OCR KATMANI KİRLİ/BOZUKSA -> TARANMIŞ PDF OCR SERVİSİNİ TETİKLE
      if (isEmptyDigitalText || isDirtyEmbeddedOcr) {
        final ocrResult = await scannedOcrService.processScannedPage(
          filePath: filePath,
          pageIndex: pageIndex,
          originalPageWidth: analysis.pageWidth,
          originalPageHeight: analysis.pageHeight,
        );

        if (isEmptyDigitalText || ocrResult.blocks.isNotEmpty) {
          return PipelinePageResult(
            blocks: ocrResult.blocks,
            hasNonLatinOrVisualWarning: ocrResult.hasNonLatinOrVisualWarning,
            ocrReviewReport: ocrResult.ocrReviewReport,
          );
        }
      }

      await OcrProofreaderEngine.ensureInitialized();

      // 2. ADIM: Koordinat Bazlı Sütun Tespiti ve Okuma Sıralaması
      final orderedLines = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: analysis.lines,
        pageWidth: analysis.pageWidth,
        pageHeight: analysis.pageHeight,
      );

      // 3. ADIM: Metin Temizleme, Kodlama Onarımı (EncodingNormalizer + OcrTextHealer) & De-hyphenation
      final rawExtractedText = orderedLines.isNotEmpty
          ? joinOrderedLinesWithParagraphBreaks(orderedLines, analysis.pageWidth)
          : analysis.rawText;

      final mappedGlifs = GlyphReverseMapper.reverseMap(rawExtractedText);
      final normalizedText = EncodingNormalizer.normalizeEncodings(mappedGlifs);
      final dehyphenatedText = EncodingNormalizer.deHyphenate(normalizedText);
      final headerStrippedText = EncodingNormalizer.stripHeaderAndFooter(dehyphenatedText);
      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(headerStrippedText);

      // 4. ADIM: Dipnotları ve Gövdeyi Ayrıştır + Sayfalar Arası (Bölüm Sonu) Dipnotları Birleştir
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final mergedFootnotes = <PageFootnote>[...pageResult.footnotes];
      final existingKeys = mergedFootnotes.map((f) => f.key).toSet();
      for (final entry in analysis.crossPageFootnotes.entries) {
        if (!existingKeys.contains(entry.key) && entry.value.trim().isNotEmpty) {
          mergedFootnotes.add(PageFootnote(key: entry.key, content: entry.value.trim()));
          existingKeys.add(entry.key);
        }
      }

      // 5. ADIM: Paragraflara Böl ve ContentBlock Listesini İnşa Et
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        pageResult.bodyText,
        pageFootnotes: mergedFootnotes,
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

      final hasNonLatin = blocks.any((b) => b is TextBlock && b.isArabic) ||
          pageResult.hadCorruptedCalligraphy;

      // 6. ADIM: Word Tarzı Otomatik Gözden Geçirme & Kelime Tashih Motoru
      final proofread = OcrProofreaderEngine.proofreadBlocks(
        blocks,
        unhealedRawText: rawExtractedText,
      );

      return PipelinePageResult(
        blocks: proofread.blocks,
        hasNonLatinOrVisualWarning: hasNonLatin,
        ocrReviewReport: proofread.report,
      );
    } catch (e) {
      debugPrint('SmartReflowPipeline error: $e');
      return const PipelinePageResult(
        blocks: [
          TextBlock(
            text:
                "Bu sayfanın dijital metin katmanı okunamadı. Üst bardaki 'PDF' sekmesinden orijinal sayfa görünümüne geçebilirsiniz.",
          ),
        ],
      );
    }
  }

  /// Ardışık satırlar arasındaki dikey boşluk, satır başı girintisi, erken satır sonu noktalaması
  /// ve punto farklarını analiz ederek paragraf ayrımlarını (`\n\n`) veya satır içi devamı (`\n`) belirler.
  static String joinOrderedLinesWithParagraphBreaks(
    List<PositionedTextLine> orderedLines,
    double pageWidth,
  ) {
    if (orderedLines.isEmpty) return '';
    final buffer = StringBuffer(orderedLines.first.text);
    final isolatedMarkerRegex = RegExp(
      r'^\s*(\[\d{1,4}\]|\(\d{1,4}\)|[¹²³⁴⁵⁶⁷⁸⁹⁰]+|\*|\†)\s*$',
    );

    // Sayfadaki satır yüksekliklerinin medyanını hesapla (alt uzantısı olmayan 'g,y,p,ş,ç'siz satırlarda sahte paragraf kırılımını önler)
    final heights = orderedLines
        .map((l) => l.bounds.height)
        .where((h) => h > 2.0)
        .toList()
      ..sort();
    final medianHeight = heights.isNotEmpty
        ? heights[heights.length ~/ 2]
        : 14.0;

    for (int i = 1; i < orderedLines.length; i++) {
      final prev = orderedLines[i - 1];
      final curr = orderedLines[i];

      // Tek başına alt satıra düşmüş dipnot işaretini ("[9]") önceki satıra yapıştır
      if (isolatedMarkerRegex.hasMatch(curr.text)) {
        buffer.write(' ');
        buffer.write(curr.text.trim());
        continue;
      }

      final refHeight = medianHeight > 0
          ? medianHeight
          : (prev.bounds.height > 0 ? prev.bounds.height : 14.0);
      final verticalGap = curr.bounds.top - prev.bounds.bottom;
      final hasLargeVerticalGap = verticalGap > refHeight * 0.85;
      final hasHugeSectionGap = verticalGap > refHeight * 1.60;
      final isNewRowBelow = curr.bounds.top >= prev.bounds.top + refHeight * 0.50;
      final indentDelta = curr.bounds.left - prev.bounds.left;
      final hasParagraphIndent = isNewRowBelow &&
          indentDelta > 14.0 &&
          indentDelta < (pageWidth > 0 ? pageWidth * 0.25 : 120.0);

      final prevTrimmed = prev.text.trimRight();
      final currTrimmed = curr.text.trimLeft();
      final endsWithTerminalPunct = prevTrimmed.isNotEmpty &&
          (prevTrimmed.endsWith('.') ||
              prevTrimmed.endsWith('!') ||
              prevTrimmed.endsWith('?') ||
              prevTrimmed.endsWith(':') ||
              prevTrimmed.endsWith('”') ||
              prevTrimmed.endsWith('»') ||
              prevTrimmed.endsWith('"'));
      final isShortLineEnd = pageWidth > 0 && prev.bounds.right < pageWidth * 0.72;
      final hasEarlySentenceBreak = endsWithTerminalPunct && isShortLineEnd;

      final isPrevHeadingLike = prevTrimmed.length < 75 &&
          !endsWithTerminalPunct &&
          prevTrimmed == prevTrimmed.toUpperCase() &&
          RegExp(r'[\p{L}]', unicode: true).hasMatch(prevTrimmed);

      final startsWithLowercase = currTrimmed.isNotEmpty &&
          RegExp(r'^[a-zçğıöşüâîû]').hasMatch(currTrimmed);

      final hasFontSizeJump =
          refHeight > 0 && curr.bounds.height > refHeight * 1.38;

      // Poka-Yoke: Önceki satır cümle bitirici noktalama ile bitmiyorsa ve başlık değilse,
      // veya yeni satır küçük harfle başlıyorsa cümle ortasında sahte paragraf bölünmesi ('\n\n') yapma.
      final canBreakParagraph = isPrevHeadingLike ||
          (!startsWithLowercase &&
              (endsWithTerminalPunct ||
                  hasHugeSectionGap ||
                  hasFontSizeJump));

      if (canBreakParagraph &&
          (hasLargeVerticalGap ||
              hasParagraphIndent ||
              hasEarlySentenceBreak ||
              hasFontSizeJump ||
              isPrevHeadingLike)) {
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

  /// Isolate içinde Syncfusion ile PDF satır, koordinat ve sayfalar arası dipnot çıkarımı
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

      // Sayfada dipnot referansı ("[9]", "(9)", "⁹" vb.) varsa aynı sayfada ve komşu/bölüm sonu sayfalarında dipnot metnini ara
      final crossPageFootnotes = <String, String>{};
      try {
        final samePageMap = TextSegmenter.extractFootnoteMapFromRawText(rawText);
        crossPageFootnotes.addAll(samePageMap);

        final neededKeys = <String>{};
        final anchorMatches = RegExp(
          r'\[(\d{1,4})\]|\((\d{1,4})\)|([¹²³⁴⁵⁶⁷⁸⁹⁰]+)',
        ).allMatches(rawText);
        for (final m in anchorMatches) {
          final rawKey = m.group(1) ?? m.group(2) ?? m.group(3) ?? '';
          if (rawKey.isNotEmpty) {
            const supMap = {
              '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5',
              '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9', '⁰': '0',
            };
            var norm = rawKey;
            for (final e in supMap.entries) {
              norm = norm.replaceAll(e.key, e.value);
            }
            if (!crossPageFootnotes.containsKey(norm)) {
              neededKeys.add(norm);
            }
          }
        }

        if (neededKeys.isNotEmpty) {
          final totalPages = doc.pages.count;
          final candidatePages = <int>[];
          // Önce sonraki 15 sayfayı (bölüm sonu dipnotları, örn. El-Ezkâr Mukaddime sonu) ve önceki 2 sayfayı tara
          for (int offset = 1; offset <= 15; offset++) {
            if (params.pageIndex + offset < totalPages) {
              candidatePages.add(params.pageIndex + offset);
            }
          }
          if (params.pageIndex - 1 >= 0) {
            candidatePages.add(params.pageIndex - 1);
          }
          // Kitap sonu notları için son 12 sayfayı da aday listesine ekle
          for (int p = totalPages - 1; p >= 0 && p >= totalPages - 12; p--) {
            if (!candidatePages.contains(p) && p != params.pageIndex) {
              candidatePages.add(p);
            }
          }

          for (final candidateIdx in candidatePages) {
            if (neededKeys.isEmpty) break;
            final candidateRaw = textExtractor.extractText(
              startPageIndex: candidateIdx,
              endPageIndex: candidateIdx,
            );
            if (candidateRaw.trim().isEmpty) continue;
            final foundMap = TextSegmenter.extractFootnoteMapFromRawText(candidateRaw);
            for (final entry in foundMap.entries) {
              if (!crossPageFootnotes.containsKey(entry.key)) {
                crossPageFootnotes[entry.key] = entry.value;
                neededKeys.remove(entry.key);
              }
            }
          }
        }
      } catch (_) {}

      doc.dispose();

      return _RawPageAnalysis(
        lines: extractedLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        rawText: rawText,
        crossPageFootnotes: crossPageFootnotes,
      );
    } catch (e) {
      return _RawPageAnalysis(lines: [], pageWidth: 0, pageHeight: 0, rawText: '');
    }
  }

  /// Yalnızca sample:// örnek kitapları için 5 farklı sayfalık içerik blokları üretir
  List<ContentBlock> _generateSampleBlocks(String filePath, int pageIndex) {
    final variant = pageIndex % 5;
    switch (variant) {
      case 0:
        return [
          const TextBlock(
            text: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Âişe (radıyallâhu \'anhâ) validemizin Resûlullah (sallallâhu \'aleyhi ve sellem)\'den rivayet ettiği şu Hadîs-i Şerîfi duymuşsundur:',
          ),
          const TextBlock(
            text:
                'إِنَّ الرِّفْقَ لَا يَكُونُ فِي شَيْءٍ إِلَّا زَانَهُ، وَلَا يُنْزَعُ مِنْ شَيْءٍ إِلَّا شَانَهُ',
            isArabic: true,
          ),
          const TextBlock(
            text:
                '“Muhakkak ki yumuşaklık (kibarlık) bulunduğu şeyi güzelleştirir. Bir şeyden yumuşaklığı alındığı zaman da bu alınma o şeyi çirkinleştirir.”¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 133,
                content:
                    'Sahih-i Müslim, Kitabu\'l-Birr, Sıla ve Âdab, c.4, s.2004, Hadis No:2594',
              ),
            ],
          ),
        ];
      case 1:
        return [
          const TextBlock(
            text: 'Eve Girerken İzin İstemek ve Selam Vermek',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Bir kimsenin kendi hanesine veya bir dostunun meclisine girerken önce tatlı bir sesle selam vermesi ve izin istemesi İslam âdâbının en zarif esaslarındandır. Selam, gönüller arasındaki ülfet kapısını açan ilk anahtardır.',
          ),
          const TextBlock(
            text:
                'فَإِذَا دَخَلْتُمْ بُيُوتًا فَسَلِّمُوا عَلَى أَنْفُسِكُمْ تَحِيَّةً مِنْ عِنْدِ اللَّهِ مُبَارَكَةً طَيِّبَةً',
            isArabic: true,
          ),
          const TextBlock(
            text:
                '“Evlere girdiğiniz zaman birbirinize, Allah katından mübarek ve hoş bir esenlik dileği olarak selam verin.”¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 105,
                content: 'Nûr Sûresi, 61. Âyet-i Kerîme.',
              ),
            ],
          ),
        ];
      case 2:
        return [
          const TextBlock(
            text: 'Mecliste Oturuş ve Söz Dinleme Edebî',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'İlim ve sohbet meclislerinde konuşanın sözünü kesmemek, muhatabın yüzüne vakar ve tebessümle bakmak kâmil müminin şiarıdır. Bir sözü daha önce bilmiş olsan dahi ilk kez duyuyormuş gibi nezaketle dinlemek edeptendir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 221,
                content:
                    'Ata bin Ebî Rebah: "Bir genç bana bir hadis anlatır, ben onu kendisi doğmadan önce işitmişimdir; yine de ilk defa duyuyormuş gibi dinlerim."',
              ),
            ],
          ),
        ];
      case 3:
        return [
          const TextBlock(
            text: 'Ziyaret Vakitlerine Riayet ve Misafirperverlik',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Dost ziyareti muhabbeti artırır; ancak ziyaretin vakti ve süresi ev sahibine ağırlık vermeyecek ölçüde olmalıdır. İstirahat saatlerinde kapı çalmamak, misafiri güler yüzle karşılayıp uğurlamak sünnet-i seniyyedendir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 226,
                content:
                    'İbn Hacer el-Askalânî, Fethu\'l-Bârî, İsti\'zân Kitabı: Ziyaretlerde vakit ve hâl gözetimi.',
              ),
            ],
          ),
        ];
      default:
        return [
          const TextBlock(
            text: 'Büyüklere Hürmet ve Küçüklere Şefkat',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Toplumun nizamı ve huzuru, büyüklerin vakarına hürmet göstermek ve küçüklerin kalbine şefkatle dokunmakla kaimdir. Sözde, yürüyüşte ve ikramda önceliği ilim ve yaşça büyüklere vermek zarafetin zirvesidir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 215,
                content:
                    'Ebû Dâvûd, Edeb 58, Hadis No: 4943: "Küçüklerimize merhamet etmeyen, büyüklerimizin şerefini tanımayan bizden değildir."',
              ),
            ],
          ),
        ];
    }
  }
}
