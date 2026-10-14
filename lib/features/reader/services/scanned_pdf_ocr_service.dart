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
import '../engine/text_segmenter.dart';

/// Taranmış PDF OCR Sonuç DTO'su
@immutable
class ScannedPageOcrResult {
  final List<ContentBlock> blocks;
  final String rawText;
  final bool hasNonLatinOrVisualWarning;
  final bool isFromCache;

  const ScannedPageOcrResult({
    required this.blocks,
    required this.rawText,
    this.hasNonLatinOrVisualWarning = false,
    this.isFromCache = false,
  });

  const ScannedPageOcrResult.empty()
      : blocks = const [],
        rawText = '',
        hasNonLatinOrVisualWarning = false,
        isFromCache = false;
}

/// Taranmış (Raster/Görsel) PDF Sayfalarını On-Device 180 DPI ile
/// Google ML Kit (Latin/Türkçe) üzerinden tanıyan, sütun/mizanpaj tanzimi yapan
/// ve sonuçları SQLite'ta kalıcı önbelleğe alan servis.
class ScannedPdfOcrService {
  final DatabaseHelper? dbHelper;

  const ScannedPdfOcrService({
    this.dbHelper,
  });

  DatabaseHelper get _db => dbHelper ?? DatabaseHelper.instance;

  /// Belirtilen taranmış PDF sayfasını çözümler.
  /// Önce SQLite önbelleğine bakar (0ms hit), yoksa 180 DPI render ve ML Kit OCR çalıştırır.
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

    // 1. ADIM: SQLite Önbellek Kontrolü (Sıfır tekrar maliyeti)
    try {
      final cachedRow = await _db.getScannedOcrPage(filePath, pageIndex);
      if (cachedRow != null) {
        final rawText = cachedRow['raw_text'] as String? ?? '';
        final jsonStr = cachedRow['structured_json'] as String? ?? '[]';
        final hasNonLatin = (cachedRow['has_non_latin'] as int? ?? 0) == 1;
        final blocks = _deserializeBlocks(jsonStr);

        if (blocks.isNotEmpty) {
          return ScannedPageOcrResult(
            blocks: blocks,
            rawText: rawText,
            hasNonLatinOrVisualWarning: hasNonLatin,
            isFromCache: true,
          );
        }
      }
    } catch (e) {
      debugPrint('ScannedPdfOcrService cache read notice: $e');
    }

    // 2. ADIM: PDF Sayfasını 180 DPI Çözünürlükte Render Et (Düşük RAM & Yüksek Doğruluk)
    pdfx.PdfDocument? doc;
    pdfx.PdfPage? page;
    String? tempImagePath;

    try {
      doc = await pdfx.PdfDocument.openFile(filePath);
      if (pageIndex >= doc.pagesCount) {
        return const ScannedPageOcrResult.empty();
      }

      page = await doc.getPage(pageIndex + 1);
      final pageWidth = originalPageWidth > 0 ? originalPageWidth : page.width.toDouble();
      final pageHeight = originalPageHeight > 0 ? originalPageHeight : page.height.toDouble();

      const targetDpiScale = 180.0 / 72.0; // 2.5x çarpan
      final renderWidth = (page.width * targetDpiScale).roundToDouble();
      final renderHeight = (page.height * targetDpiScale).roundToDouble();

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
                box.left / targetDpiScale,
                box.top / targetDpiScale,
                box.width / targetDpiScale,
                box.height / targetDpiScale,
              );

              lines.add(PositionedTextLine(
                text: line.text,
                bounds: unscaledRect,
              ));

              // Latin harfleri dışındaki alfabeleri (Arapça, Farsça, Osmanlıca veya bozuk glifler) tespit et
              if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(line.text) ||
                  TextSegmenter.isGarbageNoise(line.text)) {
                hasNonLatinOrVisual = true;
              }
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

      // 4. ADIM: Sütun Mizanpajı & Okuma Akışı Tanzimi
      final orderedLines = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: lines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      final rawExtractedText = orderedLines.isNotEmpty
          ? orderedLines.map((l) => l.text).join('\n')
          : lines.map((l) => l.text).join('\n');

      // 5. ADIM: Glif Onarımı, Temizleme & De-hyphenation
      final mapped = GlyphReverseMapper.reverseMap(rawExtractedText);
      final normalized = EncodingNormalizer.normalizeEncodings(mapped);
      final dehyphenated = EncodingNormalizer.deHyphenate(normalized);
      final cleanText = TextSegmenter.cleanOcrAndLigatures(dehyphenated);

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

      // 8. ADIM: Sonucu SQLite'a Kalıcı Olarak Yaz (Gelecek açılışlar için 0ms)
      try {
        final jsonStr = _serializeBlocks(blocks);
        await _db.saveScannedOcrPage(
          filePath: filePath,
          pageIndex: pageIndex,
          rawText: pageResult.bodyText,
          structuredJson: jsonStr,
          hasNonLatin: hasNonLatinOrVisual,
        );
      } catch (e) {
        debugPrint('ScannedPdfOcrService cache write notice: $e');
      }

      return ScannedPageOcrResult(
        blocks: blocks,
        rawText: pageResult.bodyText,
        hasNonLatinOrVisualWarning: hasNonLatinOrVisual,
        isFromCache: false,
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

  /// JSON dizesini ContentBlock listesine dönüştürür
  static List<ContentBlock> _deserializeBlocks(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final blocks = <ContentBlock>[];

      for (final item in decoded) {
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

          blocks.add(TextBlock(
            text: map['text'] as String? ?? '',
            isHeading: map['isHeading'] as bool? ?? false,
            isArabic: map['isArabic'] as bool? ?? false,
            footnoteAnchors: anchors,
          ));
        }
      }

      return blocks;
    } catch (_) {
      return [];
    }
  }
}
