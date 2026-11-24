import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' hide TextBlock;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../data/datasources/database_helper.dart';
import '../domain/content_block.dart';
import '../engine/encoding_normalizer.dart';
import '../engine/glyph_reverse_mapper.dart';
import '../engine/layout_column_detector.dart';
import '../engine/ocr_proofreader_engine.dart';
import '../engine/ocr_text_healer.dart';
import '../engine/smart_reflow_pipeline.dart';
import '../engine/text_segmenter.dart';

/// Taranmış PDF OCR Sonuç DTO'su
@immutable
class ScannedPageOcrResult {
  final List<ContentBlock> blocks;
  final String rawText;
  final bool hasNonLatinOrVisualWarning;
  final bool isFromCache;
  final OcrPageReviewReport ocrReviewReport;

  const ScannedPageOcrResult({
    required this.blocks,
    required this.rawText,
    this.hasNonLatinOrVisualWarning = false,
    this.isFromCache = false,
    this.ocrReviewReport = const OcrPageReviewReport.empty(),
  });

  const ScannedPageOcrResult.empty()
      : blocks = const [],
        rawText = '',
        hasNonLatinOrVisualWarning = false,
        isFromCache = false,
        ocrReviewReport = const OcrPageReviewReport.empty();
}

/// Taranmış (Raster/Görsel) PDF Sayfalarını On-Device 240 DPI ile
/// Google ML Kit (Latin/Türkçe) üzerinden tanıyan, sütun/mizanpaj tanzimi yapan
/// ve sonuçları SQLite'ta kalıcı önbelleğe alan servis.
class ScannedPdfOcrService {
  final DatabaseHelper? dbHelper;

  const ScannedPdfOcrService({
    this.dbHelper,
  });

  DatabaseHelper get _db => dbHelper ?? DatabaseHelper.instance;

  /// SQLite önbelleğinde bu sayfa için daha önce kaydedilmiş veya düzeltilmiş veri varsa
  /// en güncel OcrTextHealer + OcrProofreaderEngine kurallarını uygulayarak döndürür.
  Future<ScannedPageOcrResult?> tryGetCachedOrCorrectedPage({
    required String filePath,
    required int pageIndex,
  }) async {
    if (filePath.isEmpty || filePath.startsWith('sample://')) return null;
    await OcrProofreaderEngine.ensureInitialized();
    try {
      final cachedRow = await _db.getScannedOcrPage(filePath, pageIndex);
      if (cachedRow == null) return null;

      final storedRaw = cachedRow['raw_text'] as String? ?? '';
      final jsonStr = cachedRow['structured_json'] as String? ?? '[]';
      final hasNonLatin = (cachedRow['has_non_latin'] as int? ?? 0) == 1;
      final cachedBlocks = _deserializeBlocks(jsonStr);
      if (cachedBlocks.isEmpty) return null;

      final proofread = OcrProofreaderEngine.proofreadBlocks(
        cachedBlocks,
        unhealedRawText: storedRaw,
      );
      final updatedJsonStr = _serializeBlocks(proofread.blocks);
      if (proofread.didModifyBlocks || updatedJsonStr != jsonStr) {
        await _db.saveScannedOcrPage(
          filePath: filePath,
          pageIndex: pageIndex,
          rawText: storedRaw,
          structuredJson: updatedJsonStr,
          hasNonLatin: hasNonLatin,
        );
      }
      final finalRawText = proofread.blocks
          .whereType<TextBlock>()
          .map((b) => b.text)
          .join('\n\n');
      return ScannedPageOcrResult(
        blocks: proofread.blocks,
        rawText: finalRawText.isNotEmpty ? finalRawText : OcrTextHealer.heal(storedRaw),
        hasNonLatinOrVisualWarning: hasNonLatin,
        isFromCache: true,
        ocrReviewReport: proofread.report,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService tryGetCachedOrCorrectedPage notice: $e');
      return null;
    }
  }

  /// Belirtilen taranmış PDF sayfasını çözümler.
  /// Önce SQLite önbelleğine bakar (0ms hit), yoksa 240 DPI render ve ML Kit OCR çalıştırır.
  Future<ScannedPageOcrResult> processScannedPage({
    required String filePath,
    required int pageIndex,
    double originalPageWidth = 0,
    double originalPageHeight = 0,
  }) async {
    // Sanal / örnek kitaplar ve var olmayan dosyalar için doğrudan dön
    if (filePath.isEmpty || filePath.startsWith('sample://')) {
      return const ScannedPageOcrResult.empty();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const ScannedPageOcrResult.empty();
    }

    // 1. ADIM: SQLite Önbellek Kontrolü (Sıfır tekrar maliyeti + Otomatik Gözden Geçir Tashihi)
    final cachedResult = await tryGetCachedOrCorrectedPage(
      filePath: filePath,
      pageIndex: pageIndex,
    );
    if (cachedResult != null) {
      return cachedResult;
    }

    // 2. ADIM: PDF Sayfasını 240 DPI Çözünürlükte Render Et (Düşük RAM & Küçük Puntolarda Yüksek Doğruluk)
    pdfx.PdfDocument? doc;
    pdfx.PdfPage? page;
    String? tempImagePath;

    try {
      doc = await pdfx.PdfDocument.openFile(filePath);
      if (pageIndex < 0 || pageIndex >= doc.pagesCount) {
        return const ScannedPageOcrResult.empty();
      }

      page = await doc.getPage(pageIndex + 1);
      final pageWidth = originalPageWidth > 0 ? originalPageWidth : page.width.toDouble();
      final pageHeight = originalPageHeight > 0 ? originalPageHeight : page.height.toDouble();

      const targetDpiScale = 300.0 / 72.0; // ~4.16x çarpan (300 DPI endüstri standardı keskinlik)
      final renderWidth = (page.width * targetDpiScale).roundToDouble().clamp(400.0, 3200.0);
      final renderHeight = (page.height * targetDpiScale).roundToDouble().clamp(400.0, 3200.0);
      final effectiveScaleX = page.width > 0 ? (renderWidth / page.width) : targetDpiScale;
      final effectiveScaleY = page.height > 0 ? (renderHeight / page.height) : targetDpiScale;

      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      if (pageImage == null || pageImage.bytes.isEmpty) {
        return const ScannedPageOcrResult.empty();
      }

      // Sayfa ve dokümanı anında serbest bırak (OOM koruması)
      await page.close();
      page = null;
      await doc.close();
      doc = null;

      // 3. ADIM: Platform Kontrolü ve On-Device ML Kit OCR
      final lines = <PositionedTextLine>[];
      final pageLowConfidenceWords = <String, double>{};
      bool hasNonLatinOrVisual = false;

      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (isMobile) {
        // Görseli geçici dosyaya yazıp ML Kit InputImage oluştur
        final tempDir = await getTemporaryDirectory();
        final tempFileName = 'ocr_${filePath.hashCode}_p$pageIndex.png';
        tempImagePath = p.join(tempDir.path, tempFileName);
        final tempFile = File(tempImagePath);
        await tempFile.writeAsBytes(pageImage.bytes, flush: true);

        final inputImage = InputImage.fromFilePath(tempImagePath);
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

        try {
          final recognizedText = await recognizer.processImage(inputImage);

          for (final block in recognizedText.blocks) {
            for (final line in block.lines) {
              final box = line.boundingBox;
              final unscaledRect = Rect.fromLTWH(
                box.left / effectiveScaleX,
                box.top / effectiveScaleY,
                box.width / effectiveScaleX,
                box.height / effectiveScaleY,
              );

              final lineAnalysis =
                  analyzeMlKitLineGeometryAndConfidence(line);
              lineAnalysis.$2.forEach((wordKey, conf) {
                final existing = pageLowConfidenceWords[wordKey];
                if (existing == null || conf < existing) {
                  pageLowConfidenceWords[wordKey] = conf;
                }
              });

              lines.add(PositionedTextLine(
                text: lineAnalysis.$1,
                bounds: unscaledRect,
                fontSize: unscaledRect.height > 0 ? unscaledRect.height : 12.0,
              ));
            }
          }
        } finally {
          await recognizer.close();
          // Geçici dosyayı deterministik temizle
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          tempImagePath = null;
        }
      }

      if (lines.isEmpty) {
        return const ScannedPageOcrResult.empty();
      }

      // 4. ADIM: Sütun Mizanpajı & Paragraf Kırılımlı Okuma Akışı Tanzimi
      final orderedLines = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: lines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      final rawExtractedText = orderedLines.isNotEmpty
          ? SmartReflowPipeline.joinOrderedLinesWithParagraphBreaks(orderedLines, pageWidth)
          : lines.map((l) => l.text).join('\n');

      // 5. ADIM: Glif Onarımı, Üstbilgi/Altbilgi Ayıklama, OcrTextHealer & De-hyphenation
      final mapped = GlyphReverseMapper.reverseMap(rawExtractedText);
      final normalized = EncodingNormalizer.normalizeEncodings(mapped);
      final dehyphenated = EncodingNormalizer.deHyphenate(normalized);
      final headerStripped = EncodingNormalizer.stripHeaderAndFooter(dehyphenated);
      final punctCleaned = EncodingNormalizer.cleanPunctuationSpacing(headerStripped);
      final cleanText = TextSegmenter.cleanOcrAndLigatures(punctCleaned);

      // 6. ADIM: Dipnotları ve Gövdeyi Ayrıştır
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);

      // 7. ADIM: Paragraflara Böl ve ContentBlock Listesini İnşa Et
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

      hasNonLatinOrVisual = blocks.any((b) => b is TextBlock && b.isArabic) ||
          pageResult.hadCorruptedCalligraphy;

      // 7.5 ADIM: Word Tarzı Otomatik Gözden Geçirme & Kelime Tashih Motorunu Çalıştır
      final proofread = OcrProofreaderEngine.proofreadBlocks(
        blocks,
        unhealedRawText: rawExtractedText,
        mlKitLowConfidenceWords: pageLowConfidenceWords,
      );
      final finalBlocks = proofread.blocks;
      final finalBodyText = finalBlocks
          .whereType<TextBlock>()
          .map((b) => b.text)
          .join('\n\n');

      // 8. ADIM: Otomatik Düzeltilmiş Sonucu SQLite'a Kalıcı Olarak Yaz (Gelecek açılışlar için 0ms)
      try {
        final jsonStr = _serializeBlocks(finalBlocks);
        await _db.saveScannedOcrPage(
          filePath: filePath,
          pageIndex: pageIndex,
          rawText: rawExtractedText,
          structuredJson: jsonStr,
          hasNonLatin: hasNonLatinOrVisual,
        );
      } catch (e) {
        debugPrint('ScannedPdfOcrService cache write notice: $e');
      }

      return ScannedPageOcrResult(
        blocks: finalBlocks,
        rawText: finalBodyText.isNotEmpty ? finalBodyText : pageResult.bodyText,
        hasNonLatinOrVisualWarning: hasNonLatinOrVisual,
        isFromCache: false,
        ocrReviewReport: proofread.report,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService exception: $e');
      return const ScannedPageOcrResult.empty();
    } finally {
      // Sızıntı önleme: Kapanmamış nesneleri temizle
      try {
        if (page != null) await page.close();
        if (doc != null) await doc.close();
        if (tempImagePath != null) {
          final tf = File(tempImagePath);
          if (await tf.exists()) await tf.delete();
        }
      } catch (_) {}
    }
  }

  /// Kullanıcının "Gözden Geçir" panelinden yaptığı kelime düzeltmelerini ilgili sayfa önbelleğine kalıcı yazar
  Future<void> persistCorrectedPageBlocks({
    required String filePath,
    required int pageIndex,
    required List<ContentBlock> blocks,
    bool hasNonLatin = false,
  }) async {
    if (filePath.isEmpty || filePath.startsWith('sample://')) return;
    try {
      final existing = await _db.getScannedOcrPage(filePath, pageIndex);
      final rawText = existing?['raw_text'] as String? ??
          blocks.whereType<TextBlock>().map((b) => b.text).join('\n\n');
      final jsonStr = _serializeBlocks(blocks);
      await _db.saveScannedOcrPage(
        filePath: filePath,
        pageIndex: pageIndex,
        rawText: rawText,
        structuredJson: jsonStr,
        hasNonLatin: hasNonLatin,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService persistCorrectedPageBlocks notice: $e');
    }
  }

  /// ContentBlock listesini hafif JSON dizesine serileştirir
  static String _serializeBlocks(List<ContentBlock> blocks) {
    final list = <Map<String, dynamic>>[];
    for (final b in blocks) {
      if (b is TextBlock) {
        list.add({
          'type': 'text',
          'text': b.text,
          'isHeading': b.isHeading,
          'isArabic': b.isArabic,
          'footnoteAnchors': b.footnoteAnchors.map((a) => {
            'key': a.key,
            'indexInText': a.indexInText,
            'content': a.content,
          }).toList(),
        });
      }
    }
    return jsonEncode(list);
  }

  /// JSON dizesini ContentBlock listesine dönüştürür ve cümle ortası sahte bölünmeleri birleştirir
  static List<ContentBlock> _deserializeBlocks(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final blocks = <ContentBlock>[];
      final runningHeaderRegex = RegExp(
        r'^(?:\d{1,4}\s+[A-ZÇĞİÖŞÜÂÎÛ\s\-’\x27]{3,}|[A-ZÇĞİÖŞÜÂÎÛ\s\-’\x27]{3,}\s+\d{1,4})$',
      );
      final chapterTitleRegex = RegExp(
        r'^(?:BÖLÜM|Bölüm|FASIL|Fasıl|BAB|Bab|KISIM|Kısım|CİLT|Cilt|MADDE|Madde)\s+\d+',
      );

      for (int idx = 0; idx < decoded.length; idx++) {
        final item = decoded[idx];
        final map = item as Map<String, dynamic>;
        final type = map['type'] as String?;

        if (type == 'text') {
          final anchors = <FootnoteAnchor>[];
          final rawAnchors = map['footnoteAnchors'] as List<dynamic>? ?? [];
          for (final a in rawAnchors) {
            final aMap = a as Map<String, dynamic>;
            anchors.add(FootnoteAnchor(
              key: aMap['key'] as String? ?? '',
              indexInText: aMap['indexInText'] as int? ?? 0,
              content: aMap['content'] as String?,
            ));
          }

          final rawBlockText = map['text'] as String? ?? '';
          final healedFull = OcrTextHealer.heal(rawBlockText);
          if (healedFull.isEmpty) continue;

          // Sayfa başı/sonu tekrar eden "YUNAN MEZÂLİMİ 7" / "YUNAN MEZÂLİMİ 39" gibi serlevhaları ayıkla
          if ((idx == 0 || idx == decoded.length - 1) &&
              healedFull.length < 75 &&
              !chapterTitleRegex.hasMatch(healedFull) &&
              runningHeaderRegex.hasMatch(healedFull)) {
            continue;
          }

          final subParagraphs = healedFull.split(RegExp(r'\n\s*\n'));
          for (final sub in subParagraphs) {
            final healedText = OcrTextHealer.heal(sub.trim());
            if (healedText.isEmpty) continue;

            final wasArabic = map['isArabic'] as bool? ?? false;
            final validArabic = wasArabic && OcrTextHealer.isValidArabicSegment(healedText);
            final looksLikeHeading = !validArabic &&
                healedText.length < 80 &&
                !healedText.endsWith('.') &&
                !healedText.endsWith('!') &&
                !healedText.endsWith('?') &&
                ((healedText.toUpperCase() == healedText &&
                        healedText.length >= 3 &&
                        RegExp(r'[\p{L}]', unicode: true).hasMatch(healedText)) ||
                    RegExp(r'^[A-ZÇĞİÖŞÜ][\p{L}\s,\-’\x27]+(?:Önemi|Hakkında|Gereği|Bölümü|Adabı|Edebleri|Kuralları|Durumu)$',
                            unicode: true)
                        .hasMatch(healedText));
            final isHeading =
                ((map['isHeading'] as bool? ?? false) || looksLikeHeading) && !validArabic;

            if (blocks.isNotEmpty &&
                blocks.last is TextBlock &&
                !isHeading &&
                !validArabic) {
              final prev = blocks.last as TextBlock;
              final prevTrimmed = prev.text.trimRight();
              final prevEndsWithPunct = prevTrimmed.endsWith('.') ||
                  prevTrimmed.endsWith('!') ||
                  prevTrimmed.endsWith('?') ||
                  prevTrimmed.endsWith(':') ||
                  prevTrimmed.endsWith('”') ||
                  prevTrimmed.endsWith('"');
              final startsLower = RegExp(r'^[a-zçğıöşüâîû]').hasMatch(healedText);
              final currStartsLowerOrContinuation = startsLower ||
                  RegExp(r'^Türk\s+Gençliğine', unicode: true).hasMatch(healedText);

              if (!prev.isHeading &&
                  !prev.isArabic &&
                  (startsLower || (!prevEndsWithPunct && currStartsLowerOrContinuation))) {
                final combinedRaw = OcrTextHealer.heal('$prevTrimmed $healedText');
                blocks[blocks.length - 1] = TextBlock(
                  text: combinedRaw,
                  isHeading: false,
                  isArabic: false,
                  footnoteAnchors: [...prev.footnoteAnchors, ...anchors],
                );
                continue;
              }
            }

            blocks.add(TextBlock(
              text: healedText,
              isHeading: isHeading,
              isArabic: validArabic,
              footnoteAnchors: anchors,
            ));
          }
        }
      }

      return blocks;
    } catch (_) {
      return [];
    }
  }

  /// Katman 1: ML Kit `TextElement` & `TextSymbol` Güven (Confidence) Çıkarımı
  /// ve Mikro-Boşluk (Micro-Gap) Piksel Geometrisi Füzyonu.
  ///
  /// 1) Her `TextElement` için hem kelime düzeyindeki `element.confidence` hem de
  ///    alt karakter `symbol.confidence` değerlerinin minimumunu hesaplar; `< 0.78`
  ///    olan şüpheli kelimeleri `lowConfidenceWords` haritasına kaydeder.
  /// 2) Satırdaki ortalama karakter piksel genişliğini (`avgCharWidth`) hesaplar;
  ///    ardışık iki `TextElement` arasındaki yatay piksel boşluğu `avgCharWidth * 0.48`
  ///    eşiğinden küçükse ve Türkçe morfolojik/sözlük denetimi (`shouldFuseMicroGapElements`)
  ///    onaylarsa iki heceyi boşluksuz birleştirir.
  static (String, Map<String, double>) analyzeMlKitLineGeometryAndConfidence(
    TextLine line,
  ) {
    final elements = line.elements;
    if (elements.isEmpty) {
      return (line.text, const {});
    }

    final lowConfidenceWords = <String, double>{};
    double totalCharWidth = 0.0;
    int totalChars = 0;

    for (final el in elements) {
      final len = el.text.trim().length;
      if (len > 0 && el.boundingBox.width > 0) {
        totalCharWidth += el.boundingBox.width;
        totalChars += len;
      }

      double minConf = el.confidence ?? 1.0;
      for (final sym in el.symbols) {
        final sConf = sym.confidence;
        if (sConf != null && sConf < minConf) {
          minConf = sConf;
        }
      }

      if (minConf < 0.78) {
        final cleanLower = el.text
            .replaceAll('İ', 'i')
            .replaceAll('I', 'ı')
            .toLowerCase()
            .replaceAll(
              RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
              '',
            );
        if (cleanLower.length >= 2 && cleanLower.length <= 48) {
          final prev = lowConfidenceWords[cleanLower];
          if (prev == null || minConf < prev) {
            lowConfidenceWords[cleanLower] = minConf;
          }
        }
      }
    }

    final avgCharWidth =
        totalChars > 0 ? (totalCharWidth / totalChars) : 12.0;
    final microGapThreshold = avgCharWidth * 0.48;

    final sb = StringBuffer(elements.first.text);
    for (int i = 1; i < elements.length; i++) {
      final prev = elements[i - 1];
      final curr = elements[i];
      final gap = curr.boundingBox.left - prev.boundingBox.right;

      if (gap >= -2.0 &&
          gap < microGapThreshold &&
          OcrProofreaderEngine.shouldFuseMicroGapElements(
            prev.text,
            curr.text,
          )) {
        sb.write(curr.text);
      } else {
        sb.write(' ');
        sb.write(curr.text);
      }
    }

    return (sb.toString(), lowConfidenceWords);
  }
}
