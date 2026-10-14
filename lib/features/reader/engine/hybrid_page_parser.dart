import 'package:flutter/foundation.dart';
import 'glyph_reverse_mapper.dart';
import 'text_segmenter.dart';
import '../services/onnx_arabic_recognizer.dart';

/// Ayrıştırılan Segment Türleri
enum HybridSegmentType {
  standardText,
  arabicBlock,
  heading,
  inlineImageCrop,
  footnote,
}

/// UI Tarafına İletilen Ayrıştırılmış Blok Modeli
@immutable
class ParsedBlock {
  final String text;
  final HybridSegmentType type;
  final double confidence;
  final String? imageCropPath;
  final Uint8List? rawCropBytes;
  final List<FootnoteAnchor> footnoteAnchors;

  const ParsedBlock({
    required this.text,
    required this.type,
    this.confidence = 1.0,
    this.imageCropPath,
    this.rawCropBytes,
    this.footnoteAnchors = const [],
  });

  bool get isArabic => type == HybridSegmentType.arabicBlock;
  bool get isCrop => type == HybridSegmentType.inlineImageCrop;
  bool get isHeading => type == HybridSegmentType.heading;
}

/// Glif Çözümleme, Yerel ONNX ve Görsel Kesit (Crop) Arasında Karar Veren Hibrit Orkestratör
class HybridPageParser {
  final OnnxArabicRecognizer onnxRecognizer;

  const HybridPageParser({
    this.onnxRecognizer = const OnnxArabicRecognizer(),
  });

  /// Sayfayı analiz eder, kalite skoruna göre Glif -> ONNX -> Inline Crop yolunu izler.
  Future<List<ParsedBlock>> parsePage({
    required String rawExtractedText,
    required int pageIndex,
    Uint8List? pageImageBytes,
  }) async {
    // 1. ADIM: Katman 1 - Glif & CMap Çözümleme
    final glifMappedText = GlyphReverseMapper.reverseMap(rawExtractedText);
    final sanitizedText = sanitizeAndDehyphenate(glifMappedText);

    // Kalite ve Çöp Gürültü (Entropy/Noise) Analizi
    final qualityScore = calculateConfidenceScore(sanitizedText);

    // Yeterli kalitede dijital metin varsa doğrudan metin bloklarına ayır
    if (qualityScore >= 0.75 && !TextSegmenter.isGarbageNoise(sanitizedText)) {
      return buildTextBlocks(sanitizedText, qualityScore);
    }

    // 2. ADIM: Katman 2 - Yerel ONNX OCR Fallback (Taranmış veya Bozuk CMap)
    if (pageImageBytes != null && pageImageBytes.isNotEmpty) {
      final ocrResult = await onnxRecognizer.recognizeBlock(pageImageBytes);

      if (ocrResult.isSuccessful && ocrResult.confidence >= 0.60) {
        final cleanOcrText = sanitizeAndDehyphenate(ocrResult.text);
        return buildTextBlocks(cleanOcrText, ocrResult.confidence);
      }

      // 3. ADIM: Katman 3 - Inline Image Crop Fallback (Kritik Eşik Altı)
      return [
        ParsedBlock(
          text: '📜 Kaligrafi / Başlık Kesiti (Orijinal PDF Görünümü)',
          type: HybridSegmentType.inlineImageCrop,
          confidence: ocrResult.confidence,
          rawCropBytes: pageImageBytes,
        ),
      ];
    }

    // Görsel yoksa ve metin bozuksa son çare temizlenmiş metni döndür
    return buildTextBlocks(sanitizedText, qualityScore);
  }

  /// Satır sonu tirelerini birleştirir ve BiDi (RTL/LTR) izolasyonu uygular
  static String sanitizeAndDehyphenate(String input) {
    var text = input;

    // Satır Sonu Tirelerini Birleştir (De-hyphenation)
    // Ör: "müste-\nşar" -> "müsteşar"
    text = text.replaceAllMapped(
      RegExp(r'(\b\p{L}+)-\s*\n\s*(\p{L}+\b)', unicode: true),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    // Genel tire ve boşluk temizliği
    text = TextSegmenter.cleanScriptFontArtifacts(text);
    text = TextSegmenter.cleanOcrAndLigatures(text);

    // BiDi (Right-to-Left) İzolasyonu:
    // Arapça blokların arasına giren Türkçe noktalama ve dipnotların ters dönmesini önler
    text = applyBidiIsolation(text);

    return text;
  }

  /// Unicode Directional Marks ekleyerek RTL Arapça ile LTR Türkçe'yi izole eder
  static String applyBidiIsolation(String input) {
    final lines = input.split('\n');
    final buffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        buffer.writeln();
        continue;
      }

      if (TextSegmenter.isArabicText(line)) {
        // \u2067: Right-to-Left Isolate, \u2069: Pop Directional Isolate
        buffer.writeln('\u2067$line\u2069');
      } else {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trimRight();
  }

  /// Metnin bozuk CMap / Glif içerip içermediğini ve güven skorunu (0.0 - 1.0) hesaplar
  static double calculateConfidenceScore(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0.0;
    if (TextSegmenter.isGarbageNoise(trimmed)) return 0.15;

    var totalChars = trimmed.length;
    var badChars = 0;

    for (final rune in trimmed.runes) {
      // Bilinmeyen / Bozuk karakterler
      if (rune == 0xFFFD || (rune == 0x003F && trimmed.contains('???'))) {
        badChars += 3;
      }
      // Kontrol karakterleri
      if (rune < 0x0020 && rune != 0x000A && rune != 0x0009 && rune != 0x000D) {
        badChars += 2;
      }
    }

    // Çöp ardışık noktalama / sembol patlaması
    if (RegExp(r'[,.\-_~]{2,}').hasMatch(trimmed)) {
      badChars += 15;
    }

    // Harf yoğunluğu düşüklüğü (sembol/gürültü baskınlığı)
    final letterCount = RegExp(r'\p{L}', unicode: true).allMatches(trimmed).length;
    if (totalChars > 10 && (letterCount / totalChars) < 0.4) {
      badChars += (totalChars * 0.7).round();
    }

    final penalty = (badChars / totalChars).clamp(0.0, 1.0);
    return (1.0 - penalty).clamp(0.0, 1.0);
  }

  /// Metni başlık, paragraf ve Arapça blok kartlarına ayırır
  static List<ParsedBlock> buildTextBlocks(String text, double confidence) {
    final extracted = TextSegmenter.extractFootnotesAndBody(text);
    final segments = TextSegmenter.segmentIntoParagraphs(
      extracted.bodyText,
      pageFootnotes: extracted.footnotes,
    );

    return segments.map((seg) {
      var type = HybridSegmentType.standardText;
      if (seg.isHeading) {
        type = HybridSegmentType.heading;
      } else if (seg.isArabic || TextSegmenter.isArabicText(seg.rawText)) {
        type = HybridSegmentType.arabicBlock;
      }

      return ParsedBlock(
        text: seg.rawText,
        type: type,
        confidence: confidence,
        footnoteAnchors: seg.footnoteAnchors,
      );
    }).toList();
  }
}
