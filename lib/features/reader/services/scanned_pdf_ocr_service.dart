import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    hide TextBlock;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../../data/datasources/database_helper.dart';
import '../domain/content_block.dart';
import '../domain/reading_mode_hysteresis.dart';
import '../engine/encoding_normalizer.dart';
import '../engine/glyph_reverse_mapper.dart';
import '../engine/layout_column_detector.dart';
import '../engine/ocr_proofreader_engine.dart';
import '../engine/ocr_text_healer.dart';
import '../engine/smart_reflow_pipeline.dart';
import '../engine/text_segmenter.dart';
import 'apple_vision_ocr_service.dart';
import 'native_document_restorer.dart';
import 'optical_mask_cache_service.dart';
import 'tesseract_line_verifier.dart';
import 'tesseract_model_manager.dart';

/// Taranmış PDF OCR Sonuç DTO'su (metin blokları, kelime kutuları, güven skoru ve optik alfa maskesi)
@immutable
class ScannedPageOcrResult {
  final List<ContentBlock> blocks;
  final String rawText;
  final bool hasNonLatinOrVisualWarning;
  final bool isFromCache;
  final OcrPageReviewReport ocrReviewReport;
  final double ocrConfidence;
  final List<OcrWordBox> wordBoxes;
  final String? opticalAlphaMaskPath;
  final List<OpticalWordBlob> opticalWordBlobs;
  final int opticalImageWidth;
  final int opticalImageHeight;
  final double detectedSkewDeg;

  const ScannedPageOcrResult({
    required this.blocks,
    required this.rawText,
    this.hasNonLatinOrVisualWarning = false,
    this.isFromCache = false,
    this.ocrReviewReport = const OcrPageReviewReport.empty(),
    this.ocrConfidence = 1.0,
    this.wordBoxes = const [],
    this.opticalAlphaMaskPath,
    this.opticalWordBlobs = const [],
    this.opticalImageWidth = 0,
    this.opticalImageHeight = 0,
    this.detectedSkewDeg = 0.0,
  });

  const ScannedPageOcrResult.empty()
      : blocks = const [],
        rawText = '',
        hasNonLatinOrVisualWarning = false,
        isFromCache = false,
        ocrReviewReport = const OcrPageReviewReport.empty(),
        ocrConfidence = 1.0,
        wordBoxes = const [],
        opticalAlphaMaskPath = null,
        opticalWordBlobs = const [],
        opticalImageWidth = 0,
        opticalImageHeight = 0,
        detectedSkewDeg = 0.0;
}

/// Taranmış PDF sayfalarını Worker Isolate içinde C++/FFI Sauvola restorasyonundan geçirip
/// iOS Apple Vision / Android ML Kit + Tesseract 5 LSTM hibrit doğrulayıcısı + Zemberek ile okuyan,
/// atlanan satırları şeffaf `OpticalInkBlock` olarak gömen ve sonuçları Çift Katmanlı Önbelleğe
/// (SQLite + 150 MB Disk LRU) yazan servis.
class ScannedPdfOcrService {
  final DatabaseHelper? dbHelper;
  final OpticalMaskCacheService opticalCache;
  final AppleVisionOcrService appleVision;
  final TesseractModelManager? tesseractModelManager;
  final OcrLineVerifierGateway? lineVerifierGateway;

  const ScannedPdfOcrService({
    this.dbHelper,
    this.opticalCache = const OpticalMaskCacheService(),
    this.appleVision = const AppleVisionOcrService(),
    this.tesseractModelManager,
    this.lineVerifierGateway,
  });

  DatabaseHelper get _db => dbHelper ?? DatabaseHelper.instance;
  TesseractModelManager get _modelManager =>
      tesseractModelManager ?? TesseractModelManager.instance;
  OcrLineVerifierGateway get _lineVerifier =>
      lineVerifierGateway ?? TesseractLineVerifier.instance;

  /// SQLite önbelleğinde bu sayfa için kaydedilmiş OCR sonucu varsa döndürür.
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
      final wordBoxesJson = cachedRow['word_boxes_json'] as String? ?? '[]';
      final storedConfidence =
          (cachedRow['ocr_confidence'] as num?)?.toDouble() ?? 1.0;

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
          wordBoxesJson: wordBoxesJson,
          ocrConfidence: storedConfidence,
        );
      }

      final wordBoxes = _deserializeWordBoxes(wordBoxesJson);
      final opticalMask = await opticalCache.getMask(
        filePath: filePath,
        pageIndex: pageIndex,
      );

      final finalRawText = proofread.blocks
          .whereType<TextBlock>()
          .map((b) => b.text)
          .join('\n\n');

      return ScannedPageOcrResult(
        blocks: proofread.blocks,
        rawText: finalRawText.isNotEmpty
            ? finalRawText
            : OcrTextHealer.heal(storedRaw),
        hasNonLatinOrVisualWarning: hasNonLatin,
        isFromCache: true,
        ocrReviewReport: proofread.report,
        ocrConfidence: storedConfidence,
        wordBoxes: wordBoxes,
        opticalAlphaMaskPath: opticalMask?.maskImagePath,
        opticalWordBlobs: opticalMask?.wordBlobs ?? const [],
        opticalImageWidth: opticalMask?.imageWidth ?? 0,
        opticalImageHeight: opticalMask?.imageHeight ?? 0,
        detectedSkewDeg: opticalMask?.detectedSkewDeg ?? 0.0,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService tryGetCachedOrCorrectedPage notice: $e');
      return null;
    }
  }

  /// Herhangi bir PDF sayfası için (dijital veya optik maskesi LRU'dan silinmiş) yalnızca
  /// şeffaf K2pdfopt optik baskı maskesini üretir/önbellekten getirir.
  Future<OpticalMaskEntry?> generateOpticalMaskOnly({
    required String filePath,
    required int pageIndex,
  }) async {
    if (filePath.isEmpty || filePath.startsWith('sample://')) return null;

    final existing = await opticalCache.getMask(
      filePath: filePath,
      pageIndex: pageIndex,
    );
    if (existing != null) return existing;

    final rendered = await _renderPdfPageAt300Dpi(
      filePath: filePath,
      pageIndex: pageIndex,
    );
    if (rendered == null) return null;

    final restoration = await NativeDocumentRestorer.restoreAndSegmentPage(
      pagePngBytes: rendered.pngBytes,
    );
    if (!restoration.isValid) return null;

    return opticalCache.putMask(
      filePath: filePath,
      pageIndex: pageIndex,
      restoration: restoration,
    );
  }

  /// Belirtilen taranmış PDF sayfasını C++ restorasyonu + yerel OCR + K2pdfopt optik
  /// segmentasyon ile çözümler.
  Future<ScannedPageOcrResult> processScannedPage({
    required String filePath,
    required int pageIndex,
    double originalPageWidth = 0,
    double originalPageHeight = 0,
  }) async {
    if (filePath.isEmpty || filePath.startsWith('sample://')) {
      return const ScannedPageOcrResult.empty();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const ScannedPageOcrResult.empty();
    }

    final cachedResult = await tryGetCachedOrCorrectedPage(
      filePath: filePath,
      pageIndex: pageIndex,
    );
    if (cachedResult != null) {
      return cachedResult;
    }

    String? tempImagePath;

    try {
      final rendered = await _renderPdfPageAt300Dpi(
        filePath: filePath,
        pageIndex: pageIndex,
        originalPageWidth: originalPageWidth,
        originalPageHeight: originalPageHeight,
      );
      if (rendered == null) {
        return const ScannedPageOcrResult.empty();
      }

      // 2.5 ADIM: Worker Isolate üzerinde C++ / Dart Restorasyon (Deskew + Sauvola + Alpha Mask)
      final restoration = await NativeDocumentRestorer.restoreAndSegmentPage(
        pagePngBytes: rendered.pngBytes,
      );
      final ocrInputBytes = restoration.isValid
          ? restoration.restoredPngBytes
          : rendered.pngBytes;

      final OpticalMaskEntry? maskEntry = restoration.isValid
          ? await opticalCache.putMask(
              filePath: filePath,
              pageIndex: pageIndex,
              restoration: restoration,
            )
          : null;

      // 3. ADIM: iOS Apple Vision veya Android ML Kit OCR
      final lines = <PositionedTextLine>[];
      final pageLowConfidenceWords = <String, double>{};
      final wordBoxes = <OcrWordBox>[];
      double recognizerMeanConfidence = 0.90;
      bool hasNonLatinOrVisual = false;

      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (isMobile) {
        final tempDir = await getTemporaryDirectory();
        final tempFileName = 'ocr_${filePath.hashCode}_p$pageIndex.png';
        tempImagePath = p.join(tempDir.path, tempFileName);
        final tempFile = File(tempImagePath);
        await tempFile.writeAsBytes(ocrInputBytes, flush: true);

        try {
          bool handledByAppleVision = false;
          if (AppleVisionOcrService.isSupported) {
            final avRes = await appleVision.recognizeImage(
              imagePath: tempImagePath,
            );
            if (avRes.isNotEmpty) {
              handledByAppleVision = true;
              recognizerMeanConfidence = avRes.averageConfidence;
              wordBoxes.addAll(avRes.wordBoxes);
              for (final avLine in avRes.lines) {
                final bounds = Rect.fromLTWH(
                  avLine.normalizedLeft * rendered.pageWidth,
                  avLine.normalizedTop * rendered.pageHeight,
                  avLine.normalizedWidth * rendered.pageWidth,
                  avLine.normalizedHeight * rendered.pageHeight,
                );
                lines.add(
                  PositionedTextLine(
                    text: avLine.text,
                    bounds: bounds,
                    fontSize: bounds.height > 0 ? bounds.height : 12.0,
                  ),
                );
                for (final wb in avLine.words) {
                  if (wb.confidence < 0.78) {
                    final lower = OcrProofreaderEngine.toTurkishLower(wb.word);
                    if (lower.length >= 2) {
                      pageLowConfidenceWords[lower] = wb.confidence;
                    }
                  }
                }
              }
            }
          }

          if (!handledByAppleVision) {
            if (!kIsWeb && Platform.isAndroid) {
              unawaited(_modelManager.ensureModelsDownloadedInBackground());
            }

            final inputImage = InputImage.fromFilePath(tempImagePath);
            final recognizer = TextRecognizer(
              script: TextRecognitionScript.latin,
            );
            final mlKitLineMinConfidences = <double>[];
            final mlKitLinePixelRects = <Rect>[];
            double confSum = 0.0;
            int confCount = 0;

            try {
              final recognizedText = await recognizer.processImage(inputImage);
              final normW = rendered.renderWidth > 0
                  ? rendered.renderWidth
                  : rendered.pageWidth;
              final normH = rendered.renderHeight > 0
                  ? rendered.renderHeight
                  : rendered.pageHeight;

              for (final block in recognizedText.blocks) {
                for (final line in block.lines) {
                  final box = line.boundingBox;
                  final unscaledRect = Rect.fromLTWH(
                    box.left / rendered.scaleX,
                    box.top / rendered.scaleY,
                    box.width / rendered.scaleX,
                    box.height / rendered.scaleY,
                  );

                  final lineAnalysis = analyzeMlKitLineGeometryAndConfidence(
                    line,
                  );
                  double lineMinConf = 1.0;
                  lineAnalysis.$2.forEach((wordKey, conf) {
                    if (conf < lineMinConf) {
                      lineMinConf = conf;
                    }
                    final existing = pageLowConfidenceWords[wordKey];
                    if (existing == null || conf < existing) {
                      pageLowConfidenceWords[wordKey] = conf;
                    }
                  });

                  for (final el in line.elements) {
                    final elConf = (el.confidence ?? 0.90).clamp(0.0, 1.0);
                    if (elConf < lineMinConf) {
                      lineMinConf = elConf;
                    }
                    confSum += elConf;
                    confCount++;
                    wordBoxes.add(
                      OcrWordBox(
                        word: el.text.trim(),
                        normalizedLeft:
                            (el.boundingBox.left / normW).clamp(0.0, 1.0),
                        normalizedTop:
                            (el.boundingBox.top / normH).clamp(0.0, 1.0),
                        normalizedWidth:
                            (el.boundingBox.width / normW).clamp(0.0, 1.0),
                        normalizedHeight:
                            (el.boundingBox.height / normH).clamp(0.0, 1.0),
                        confidence: elConf,
                      ),
                    );
                  }

                  lines.add(
                    PositionedTextLine(
                      text: lineAnalysis.$1,
                      bounds: unscaledRect,
                      fontSize:
                          unscaledRect.height > 0 ? unscaledRect.height : 12.0,
                    ),
                  );
                  mlKitLineMinConfidences.add(lineMinConf);
                  mlKitLinePixelRects.add(box);
                }
              }

              // Faz 2 Hibrit Doğrulama: modeller indirilmişse yalnızca düşük güvenli / şüpheli
              // satırları ve ML Kit'in atladığı Arapça/dipnot satırlarını Tesseract 5 LSTM ile onar
              if (restoration.isValid) {
                await applyHybridLineVerification(
                  restoration: restoration,
                  lines: lines,
                  mlKitLineMinConfidences: mlKitLineMinConfidences,
                  mlKitLinePixelRects: mlKitLinePixelRects,
                  pageLowConfidenceWords: pageLowConfidenceWords,
                  pageWidth: rendered.pageWidth,
                  pageHeight: rendered.pageHeight,
                  scaleX: rendered.scaleX,
                  scaleY: rendered.scaleY,
                );
              }

              if (confCount > 0) {
                recognizerMeanConfidence = (confSum / confCount).clamp(0.0, 1.0);
              }
            } finally {
              await recognizer.close();
            }
          }
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          tempImagePath = null;
        }
      }

      if (lines.isEmpty && (restoration.lines.isEmpty || maskEntry == null)) {
        return const ScannedPageOcrResult.empty();
      }

      // 4. ADIM: Sütun Mizanpajı & Paragraf Kırılımlı Okuma Akışı Tanzimi
      final orderedLines = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: lines,
        pageWidth: rendered.pageWidth,
        pageHeight: rendered.pageHeight,
      );

      final rawExtractedText = orderedLines.isNotEmpty
          ? SmartReflowPipeline.joinOrderedLinesWithParagraphBreaks(
              orderedLines,
              rendered.pageWidth,
            )
          : lines.map((l) => l.text).join('\n');

      // 5. ADIM: Glif Onarımı, Üstbilgi/Altbilgi Ayıklama & De-hyphenation
      final mapped = GlyphReverseMapper.reverseMap(rawExtractedText);
      final normalized = EncodingNormalizer.normalizeEncodings(mapped);
      final dehyphenated = EncodingNormalizer.deHyphenate(normalized);
      final headerStripped = EncodingNormalizer.stripHeaderAndFooter(
        dehyphenated,
      );
      final punctCleaned = EncodingNormalizer.cleanPunctuationSpacing(
        headerStripped,
      );
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
        blocks.add(
          TextBlock(
            text: para.rawText,
            isHeading: para.isHeading,
            isArabic: para.isArabic,
            footnoteAnchors: para.footnoteAnchors,
          ),
        );
      }

      // 7.2 ADIM: C++ mürekkep satırlarının OCR tarafından atlananlarını (Arapça/Dipnot/Formül)
      // şeffaf temalı OpticalInkBlock olarak akışa ekle
      if (maskEntry != null && restoration.lines.isNotEmpty) {
        final missedBlocks = _extractMissedInkBlocks(
          restoration: restoration,
          maskPath: maskEntry.maskImagePath,
          ocrLines: lines,
          pageWidth: rendered.pageWidth,
          pageHeight: rendered.pageHeight,
        );
        blocks.addAll(missedBlocks);
      }

      hasNonLatinOrVisual =
          blocks.any((b) => b is TextBlock && b.isArabic) ||
          blocks.any((b) => b is OpticalInkBlock) ||
          pageResult.hadCorruptedCalligraphy;

      // 7.5 ADIM: Zemberek Gözden Geçirme & Kelime Tashih Motoru
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

      final totalWords = math.max(1, proofread.report.totalWordsScanned);
      final unknownRatio = proofread.report.suggestionCount / totalWords;
      final pageConfidence =
          (recognizerMeanConfidence - unknownRatio * 0.55).clamp(0.0, 1.0);
      final recommendedMode =
          pageConfidence < ReadingModeHysteresis.singlePageFallbackThreshold
              ? ReaderDisplayMode.opticalReflow
              : ReaderDisplayMode.textReflow;

      // 8. ADIM: Kalıcı SQLite önbelleğine metin + kelime koordinatları + güven skorunu yaz
      try {
        final jsonStr = _serializeBlocks(finalBlocks);
        final wordBoxesJson = jsonEncode(
          wordBoxes.map((w) => w.toJson()).toList(),
        );
        await _db.saveScannedOcrPage(
          filePath: filePath,
          pageIndex: pageIndex,
          rawText: rawExtractedText,
          structuredJson: jsonStr,
          hasNonLatin: hasNonLatinOrVisual,
          wordBoxesJson: wordBoxesJson,
          ocrConfidence: pageConfidence,
          recommendedMode: recommendedMode.name,
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
        ocrConfidence: pageConfidence,
        wordBoxes: wordBoxes,
        opticalAlphaMaskPath: maskEntry?.maskImagePath,
        opticalWordBlobs: maskEntry?.wordBlobs ?? const [],
        opticalImageWidth: maskEntry?.imageWidth ?? restoration.width,
        opticalImageHeight: maskEntry?.imageHeight ?? restoration.height,
        detectedSkewDeg: restoration.detectedSkewDeg,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService exception: $e');
      return const ScannedPageOcrResult.empty();
    } finally {
      try {
        if (tempImagePath != null) {
          final tf = File(tempImagePath);
          if (await tf.exists()) await tf.delete();
        }
      } catch (e) {
        debugPrint('ScannedPdfOcrService cleanup warning: $e');
      }
    }
  }

  Future<
      ({
        Uint8List pngBytes,
        double pageWidth,
        double pageHeight,
        double renderWidth,
        double renderHeight,
        double scaleX,
        double scaleY,
      })?> _renderPdfPageAt300Dpi({
    required String filePath,
    required int pageIndex,
    double originalPageWidth = 0,
    double originalPageHeight = 0,
  }) async {
    pdfx.PdfDocument? doc;
    pdfx.PdfPage? page;
    try {
      doc = await pdfx.PdfDocument.openFile(filePath);
      if (pageIndex < 0 || pageIndex >= doc.pagesCount) return null;
      page = await doc.getPage(pageIndex + 1);

      final pageWidth =
          originalPageWidth > 0 ? originalPageWidth : page.width.toDouble();
      final pageHeight =
          originalPageHeight > 0 ? originalPageHeight : page.height.toDouble();

      const targetDpiScale = 300.0 / 72.0;
      final renderWidth =
          (page.width * targetDpiScale).roundToDouble().clamp(400.0, 3200.0);
      final renderHeight =
          (page.height * targetDpiScale).roundToDouble().clamp(400.0, 3200.0);
      final scaleX =
          page.width > 0 ? (renderWidth / page.width) : targetDpiScale;
      final scaleY =
          page.height > 0 ? (renderHeight / page.height) : targetDpiScale;

      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (pageImage == null || pageImage.bytes.isEmpty) return null;

      return (
        pngBytes: pageImage.bytes,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        renderWidth: renderWidth,
        renderHeight: renderHeight,
        scaleX: scaleX,
        scaleY: scaleY,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService PDF render error: $e');
      return null;
    } finally {
      try {
        if (page != null) await page.close();
        if (doc != null) await doc.close();
      } catch (e) {
        debugPrint('ScannedPdfOcrService PDF close warning: $e');
      }
    }
  }

  /// Faz 2 hibrit doğrulama katmanı:
  /// Modeller SHA-256 doğrulanmış olarak hazırsa ve Tesseract köprüsü etkinse, yalnızca
  /// şüpheli ML Kit satırlarını (`tur`) ve ML Kit'in atladığı C++ mürekkep satırlarını (`ara+tur`)
  /// tekil satır bazında doğrular ve kazanan adayı `lines` listesine işler.
  @visibleForTesting
  Future<({int upgradedMlLines, int promotedSkippedLines})>
      applyHybridLineVerification({
    required DocumentRestorationResult restoration,
    required List<PositionedTextLine> lines,
    required List<double> mlKitLineMinConfidences,
    required List<Rect> mlKitLinePixelRects,
    required Map<String, double> pageLowConfidenceWords,
    required double pageWidth,
    required double pageHeight,
    required double scaleX,
    required double scaleY,
  }) async {
    if (!restoration.isValid || restoration.restoredPngBytes.isEmpty) {
      return (upgradedMlLines: 0, promotedSkippedLines: 0);
    }

    try {
      final tessdataDir = await _modelManager.getTessdataDirectoryIfReady();
      if (tessdataDir == null || !_lineVerifier.isAvailable) {
        return (upgradedMlLines: 0, promotedSkippedLines: 0);
      }

      final mlPairs = <({String text, double minWordConfidence})>[];
      for (int i = 0; i < lines.length; i++) {
        final conf =
            i < mlKitLineMinConfidences.length ? mlKitLineMinConfidences[i] : 1.0;
        mlPairs.add((text: lines[i].text, minWordConfidence: conf));
      }

      final suspiciousIndices =
          OcrEnsembleArbitrator.selectSuspiciousMlKitLineIndices(mlPairs);
      final skippedLines = OcrEnsembleArbitrator.selectSkippedInkLines(
        restoration: restoration,
        ocrLines: lines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      final tasks = <TesseractLineTask>[];
      for (final idx in suspiciousIndices) {
        if (idx >= mlKitLinePixelRects.length) continue;
        final rect = mlKitLinePixelRects[idx];
        final x = rect.left.floor().clamp(0, restoration.width - 1);
        final y = rect.top.floor().clamp(0, restoration.height - 1);
        final w = rect.width.ceil().clamp(1, restoration.width - x);
        final h = rect.height.ceil().clamp(1, restoration.height - y);
        tasks.add(
          TesseractLineTask(
            id: 'ml_$idx',
            cropX: x,
            cropY: y,
            cropWidth: w,
            cropHeight: h,
            languages: 'tur',
          ),
        );
      }

      for (int sIdx = 0; sIdx < skippedLines.length; sIdx++) {
        final ink = skippedLines[sIdx];
        tasks.add(
          TesseractLineTask(
            id: 'skip_$sIdx',
            cropX: ink.x,
            cropY: ink.y,
            cropWidth: ink.width,
            cropHeight: ink.height,
            languages: 'ara+tur',
          ),
        );
      }

      if (tasks.isEmpty) {
        return (upgradedMlLines: 0, promotedSkippedLines: 0);
      }

      final batch = await _lineVerifier.verifyPageLines(
        TesseractLineVerificationRequest(
          tessdataDir: tessdataDir,
          restoredPngBytes: restoration.restoredPngBytes,
          tasks: tasks,
        ),
      );
      if (batch.results.isEmpty) {
        return (upgradedMlLines: 0, promotedSkippedLines: 0);
      }

      int upgradedMlLines = 0;
      for (final idx in suspiciousIndices) {
        final res = batch.results['ml_$idx'];
        if (res == null || !res.succeeded) continue;

        final oldLine = lines[idx];
        final oldConf =
            idx < mlKitLineMinConfidences.length ? mlKitLineMinConfidences[idx] : 0.7;
        final decision = OcrEnsembleArbitrator.arbitrateTurkishLine(
          mlKitText: oldLine.text,
          mlKitConfidence: oldConf,
          tesseractText: res.text,
          tesseractConfidence: res.confidence,
        );

        if (decision.acceptedTesseract && decision.text.isNotEmpty) {
          lines[idx] = PositionedTextLine(
            text: decision.text,
            bounds: oldLine.bounds,
            fontSize: oldLine.fontSize,
          );
          upgradedMlLines++;

          for (final oldToken in oldLine.text.split(RegExp(r'\s+'))) {
            final key = OcrProofreaderEngine.toTurkishLower(
              oldToken.replaceAll(
                RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
                '',
              ),
            );
            if (key.length >= 2) {
              pageLowConfidenceWords.remove(key);
            }
          }
        }
      }

      int promotedSkippedLines = 0;
      final safeScaleX = scaleX > 0 ? scaleX : 1.0;
      final safeScaleY = scaleY > 0 ? scaleY : 1.0;

      for (int sIdx = 0; sIdx < skippedLines.length; sIdx++) {
        final res = batch.results['skip_$sIdx'];
        if (res == null || !res.succeeded) continue;

        final eval = OcrEnsembleArbitrator.evaluateSkippedInkLine(
          tesseractText: res.text,
          tesseractConfidence: res.confidence,
        );
        if (!eval.promote || eval.cleanedText.isEmpty) continue;

        final ink = skippedLines[sIdx];
        final bounds = Rect.fromLTWH(
          ink.x / safeScaleX,
          ink.y / safeScaleY,
          ink.width / safeScaleX,
          ink.height / safeScaleY,
        );
        lines.add(
          PositionedTextLine(
            text: eval.cleanedText,
            bounds: bounds,
            fontSize: bounds.height > 0 ? bounds.height : 12.0,
          ),
        );
        promotedSkippedLines++;
      }

      return (
        upgradedMlLines: upgradedMlLines,
        promotedSkippedLines: promotedSkippedLines,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService hybrid verification fallback: $e');
      return (upgradedMlLines: 0, promotedSkippedLines: 0);
    }
  }

  List<OpticalInkBlock> _extractMissedInkBlocks({
    required DocumentRestorationResult restoration,
    required String maskPath,
    required List<PositionedTextLine> ocrLines,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (restoration.width <= 0 ||
        restoration.height <= 0 ||
        pageWidth <= 0 ||
        pageHeight <= 0) {
      return const [];
    }

    final blocks = <OpticalInkBlock>[];
    for (final inkLine in restoration.lines) {
      if (inkLine.width < restoration.width * 0.08 || inkLine.height < 10) {
        continue;
      }
      final coveredByOcr = OcrEnsembleArbitrator.isInkLineCoveredByOcr(
        inkLine: inkLine,
        imageWidth: restoration.width,
        imageHeight: restoration.height,
        ocrLines: ocrLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      if (!coveredByOcr) {
        blocks.add(
          OpticalInkBlock(
            title: 'Orijinal Baskı / Arapça Satır Kesiti',
            alphaMaskPath: maskPath,
            cropRect: Rect.fromLTWH(
              inkLine.x.toDouble(),
              inkLine.y.toDouble(),
              inkLine.width.toDouble(),
              inkLine.height.toDouble(),
            ),
            isArabic: true,
          ),
        );
        if (blocks.length >= 6) break;
      }
    }
    return blocks;
  }

  /// Kullanıcının "Gözden Geçir" panelinden yaptığı kelime düzeltmelerini kaydeder.
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
      final wordBoxesJson = existing?['word_boxes_json'] as String? ?? '[]';
      final ocrConf =
          (existing?['ocr_confidence'] as num?)?.toDouble() ?? 1.0;
      final jsonStr = _serializeBlocks(blocks);
      await _db.saveScannedOcrPage(
        filePath: filePath,
        pageIndex: pageIndex,
        rawText: rawText,
        structuredJson: jsonStr,
        hasNonLatin: hasNonLatin,
        wordBoxesJson: wordBoxesJson,
        ocrConfidence: ocrConf,
      );
    } catch (e) {
      debugPrint('ScannedPdfOcrService persistCorrectedPageBlocks notice: $e');
    }
  }

  static List<OcrWordBox> _deserializeWordBoxes(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OcrWordBox.fromJson)
          .toList();
    } catch (e) {
      debugPrint('ScannedPdfOcrService _deserializeWordBoxes notice: $e');
      return const [];
    }
  }

  /// ContentBlock listesini JSON dizesine serileştirir.
  static String _serializeBlocks(List<ContentBlock> blocks) {
    final list = <Map<String, dynamic>>[];
    for (final b in blocks) {
      if (b is TextBlock) {
        list.add({
          'type': 'text',
          'text': b.text,
          'isHeading': b.isHeading,
          'isArabic': b.isArabic,
          'footnoteAnchors': b.footnoteAnchors
              .map(
                (a) => {
                  'key': a.key,
                  'indexInText': a.indexInText,
                  'content': a.content,
                },
              )
              .toList(),
        });
      } else if (b is OpticalInkBlock) {
        list.add({
          'type': 'optical_ink',
          'title': b.title,
          'alphaMaskPath': b.alphaMaskPath,
          'left': b.cropRect.left,
          'top': b.cropRect.top,
          'width': b.cropRect.width,
          'height': b.cropRect.height,
          'isArabic': b.isArabic,
          'fallbackText': b.fallbackText,
        });
      }
    }
    return jsonEncode(list);
  }

  /// JSON dizesini ContentBlock listesine dönüştürür ve cümle ortası sahte bölünmeleri birleştirir.
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

        if (type == 'optical_ink') {
          final maskPath = map['alphaMaskPath'] as String? ?? '';
          if (maskPath.isNotEmpty) {
            blocks.add(
              OpticalInkBlock(
                title: map['title'] as String? ?? 'Orijinal Baskı Kesiti',
                alphaMaskPath: maskPath,
                cropRect: Rect.fromLTWH(
                  (map['left'] as num?)?.toDouble() ?? 0.0,
                  (map['top'] as num?)?.toDouble() ?? 0.0,
                  (map['width'] as num?)?.toDouble() ?? 0.0,
                  (map['height'] as num?)?.toDouble() ?? 0.0,
                ),
                isArabic: (map['isArabic'] as bool?) ?? false,
                fallbackText: map['fallbackText'] as String?,
              ),
            );
          }
          continue;
        }

        if (type == 'text') {
          final anchors = <FootnoteAnchor>[];
          final rawAnchors = map['footnoteAnchors'] as List<dynamic>? ?? [];
          for (final a in rawAnchors) {
            final aMap = a as Map<String, dynamic>;
            anchors.add(
              FootnoteAnchor(
                key: aMap['key'] as String? ?? '',
                indexInText: aMap['indexInText'] as int? ?? 0,
                content: aMap['content'] as String?,
              ),
            );
          }

          final rawBlockText = map['text'] as String? ?? '';
          final healedFull = OcrTextHealer.heal(rawBlockText);
          if (healedFull.isEmpty) continue;

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
            final validArabic =
                wasArabic && OcrTextHealer.isValidArabicSegment(healedText);
            final looksLikeHeading =
                !validArabic &&
                healedText.length < 80 &&
                !healedText.endsWith('.') &&
                !healedText.endsWith('!') &&
                !healedText.endsWith('?') &&
                ((healedText.toUpperCase() == healedText &&
                        healedText.length >= 3 &&
                        RegExp(r'[\p{L}]', unicode: true)
                            .hasMatch(healedText)) ||
                    RegExp(
                      r'^[A-ZÇĞİÖŞÜ][\p{L}\s,\-’\x27]+(?:Önemi|Hakkında|Gereği|Bölümü|Adabı|Edebleri|Kuralları|Durumu)$',
                      unicode: true,
                    ).hasMatch(healedText));
            final isHeading =
                ((map['isHeading'] as bool? ?? false) || looksLikeHeading) &&
                !validArabic;

            if (blocks.isNotEmpty &&
                blocks.last is TextBlock &&
                !isHeading &&
                !validArabic) {
              final prev = blocks.last as TextBlock;
              final prevTrimmed = prev.text.trimRight();
              final prevEndsWithPunct =
                  prevTrimmed.endsWith('.') ||
                  prevTrimmed.endsWith('!') ||
                  prevTrimmed.endsWith('?') ||
                  prevTrimmed.endsWith(':') ||
                  prevTrimmed.endsWith('”') ||
                  prevTrimmed.endsWith('"');
              final startsLower =
                  RegExp(r'^[a-zçğıöşüâîû]').hasMatch(healedText);
              final currStartsLowerOrContinuation =
                  startsLower ||
                  RegExp(
                    r'^Türk\s+Gençliğine',
                    unicode: true,
                  ).hasMatch(healedText);

              if (!prev.isHeading &&
                  !prev.isArabic &&
                  (startsLower ||
                      (!prevEndsWithPunct && currStartsLowerOrContinuation))) {
                final combinedRaw =
                    OcrTextHealer.heal('$prevTrimmed $healedText');
                blocks[blocks.length - 1] = TextBlock(
                  text: combinedRaw,
                  isHeading: false,
                  isArabic: false,
                  footnoteAnchors: [...prev.footnoteAnchors, ...anchors],
                );
                continue;
              }
            }

            blocks.add(
              TextBlock(
                text: healedText,
                isHeading: isHeading,
                isArabic: validArabic,
                footnoteAnchors: anchors,
              ),
            );
          }
        }
      }

      return blocks;
    } catch (e) {
      debugPrint('ScannedPdfOcrService _deserializeBlocks notice: $e');
      return [];
    }
  }

  /// Katman 1: ML Kit `TextElement` & `TextSymbol` Güven Çıkarımı ve Mikro-Boşluk Füzyonu.
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
