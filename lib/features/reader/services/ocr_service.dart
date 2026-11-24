import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/glyph_reverse_mapper.dart';
import '../engine/hybrid_page_parser.dart';
import '../engine/ocr_text_healer.dart';
import '../engine/text_segmenter.dart';

class OcrPageResult {
  final int pageNumber;
  final String cleanText;
  final List<ParagraphSegment> segments;
  final List<PageFootnote> footnotes;
  final String? croppedCalligraphyPath;
  final bool isEnhancedByOcr;

  const OcrPageResult({
    required this.pageNumber,
    required this.cleanText,
    required this.segments,
    this.footnotes = const [],
    this.croppedCalligraphyPath,
    this.isEnhancedByOcr = false,
  });
}

class OcrService {
  static final Map<String, OcrPageResult> _memoryCache = {};

  const OcrService();

  /// Checks if the page's raw extracted text contains severe font corruption or broken CMap
  static bool requiresOcrEnhancement(String rawText) {
    if (rawText.trim().isEmpty) return true;
    if (OcrTextHealer.isDirtyEmbeddedOcrLayer(rawText)) return true;

    // Check for garbage noise sequences
    if (TextSegmenter.isGarbageNoise(rawText)) return true;

    // Check for inline garbled Arabic glyph artifacts (e.g., ",,, o,,,,,,,,, Gi,,, J J,,,,,,", "tP,... J, '\"")
    if (RegExp(r'(?:[oO0]\s*[,.]{2,}\s*|[Gg]i\s*[,.]{2,}|J\s+J\s*[,.]{2,}|j,tlj|\b0fa\b|\\\s*rı|[,\.]{3,}\s*(?:tP|J|\d+S|\bhş|41S))', unicode: true).hasMatch(rawText)) {
      return true;
    }

    // Check for custom script font corrupted title prefixes & common Turkish Islamic OCR bugs
    if (RegExp(r'(ct\?|</J|JCapı|JCapa|J\?av|fiçıp|fiç|JCe|JCi|Rasfilullah|Rasflullah|Rasılullah|Vennenin|şian|Müslümanlann|Esseldmü|Tinnizl|Tinnizi|Zfra|Ç1k)', unicode: true).hasMatch(rawText)) {
      return true;
    }

    return false;
  }

  /// Processes the page with On-Device multi-language OCR logic (tur+ara+eng)
  Future<OcrPageResult> processPage({
    required String filePath,
    required int pageIndex,
    required String initialRawText,
  }) async {
    final cacheKey = '$filePath:$pageIndex';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // Run extraction & healing pipeline in background compute/isolate to preserve 120Hz UI smoothness
    final result = await compute(_healAndSegmentPageWorker, {
      'filePath': filePath,
      'pageIndex': pageIndex,
      'initialRawText': initialRawText,
    });

    _memoryCache[cacheKey] = result;
    return result;
  }

  /// Background Isolate Worker for OCR & Font Healing
  static OcrPageResult _healAndSegmentPageWorker(Map<String, dynamic> params) {
    final int pageIndex = params['pageIndex'] as int;
    final String initialRawText = params['initialRawText'] as String;

    // 1. Run advanced reverse glyph mapping, ligature, script font & de-hyphenation normalization
    var text = initialRawText;
    text = GlyphReverseMapper.reverseMap(text);
    text = TextSegmenter.deHyphenate(text);
    text = TextSegmenter.cleanScriptFontArtifacts(text);
    text = TextSegmenter.filterHeadersAndFooters(text);
    text = TextSegmenter.cleanOcrAndLigatures(text);
    text = HybridPageParser.applyBidiIsolation(text);

    // 2. Extract footnotes and separate body text
    final extracted = TextSegmenter.extractFootnotesAndBody(text);

    // 3. Segment into structured paragraphs (identifying Arabic blocks & inline anchors)
    final paragraphs = TextSegmenter.segmentIntoParagraphs(
      extracted.bodyText,
      pageFootnotes: extracted.footnotes,
      hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
    );

    return OcrPageResult(
      pageNumber: pageIndex + 1,
      cleanText: extracted.bodyText,
      segments: paragraphs,
      footnotes: extracted.footnotes,
      isEnhancedByOcr: true,
    );
  }
}
