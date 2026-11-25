import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/reading_mode_hysteresis.dart';

/// Recognized single line from iOS Apple Vision `VNRecognizeTextRequest`.
@immutable
class AppleVisionTextLine {
  final String text;
  final double confidence;
  final double normalizedLeft;
  final double normalizedTop;
  final double normalizedWidth;
  final double normalizedHeight;
  final List<OcrWordBox> words;

  const AppleVisionTextLine({
    required this.text,
    required this.confidence,
    required this.normalizedLeft,
    required this.normalizedTop,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.words = const [],
  });
}

/// Complete page recognition result returned by Apple Vision on iOS.
@immutable
class AppleVisionOcrResult {
  final List<AppleVisionTextLine> lines;
  final List<OcrWordBox> wordBoxes;
  final double averageConfidence;

  const AppleVisionOcrResult({
    required this.lines,
    required this.wordBoxes,
    required this.averageConfidence,
  });

  bool get isNotEmpty => lines.isNotEmpty;

  static const AppleVisionOcrResult empty = AppleVisionOcrResult(
    lines: [],
    wordBoxes: [],
    averageConfidence: 0.0,
  );
}

/// Native iOS Apple Vision (`tr-TR`, `ar-SA`, `en-US`) OCR MethodChannel client.
class AppleVisionOcrService {
  static const MethodChannel _channel = MethodChannel(
    'com.akarworks.tahrir/apple_vision_ocr',
  );

  const AppleVisionOcrService();

  /// True only on native iOS devices outside headless tests.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
      return Platform.isIOS;
    } catch (e) {
      debugPrint('AppleVisionOcrService platform check notice: $e');
      return false;
    }
  }

  /// Runs Apple Vision `.accurate` OCR on a restored PNG file path.
  Future<AppleVisionOcrResult> recognizeImage({
    required String imagePath,
    List<String> languages = const ['tr-TR', 'ar-SA', 'en-US'],
  }) async {
    if (!isSupported || imagePath.isEmpty) {
      return AppleVisionOcrResult.empty;
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'recognizeImage',
        <String, dynamic>{
          'imagePath': imagePath,
          'languages': languages,
        },
      );
      if (raw == null) return AppleVisionOcrResult.empty;

      final rawLines = raw['lines'] as List<dynamic>? ?? const [];
      final lines = <AppleVisionTextLine>[];
      final allWords = <OcrWordBox>[];
      double confSum = 0.0;

      for (final item in rawLines) {
        if (item is! Map) continue;
        final text = (item['text'] as String?) ?? '';
        if (text.trim().isEmpty) continue;
        final conf = ((item['confidence'] as num?)?.toDouble() ?? 0.85)
            .clamp(0.0, 1.0);
        confSum += conf;

        final rawWords = item['words'] as List<dynamic>? ?? const [];
        final parsedWords = <OcrWordBox>[];
        for (final w in rawWords) {
          if (w is! Map) continue;
          final wText = (w['text'] as String?) ?? '';
          if (wText.isEmpty) continue;
          final box = OcrWordBox(
            word: wText,
            normalizedLeft: (w['left'] as num?)?.toDouble() ?? 0.0,
            normalizedTop: (w['top'] as num?)?.toDouble() ?? 0.0,
            normalizedWidth: (w['width'] as num?)?.toDouble() ?? 0.0,
            normalizedHeight: (w['height'] as num?)?.toDouble() ?? 0.0,
            confidence:
                ((w['confidence'] as num?)?.toDouble() ?? conf).clamp(0.0, 1.0),
          );
          parsedWords.add(box);
          allWords.add(box);
        }

        lines.add(
          AppleVisionTextLine(
            text: text,
            confidence: conf,
            normalizedLeft: (item['left'] as num?)?.toDouble() ?? 0.0,
            normalizedTop: (item['top'] as num?)?.toDouble() ?? 0.0,
            normalizedWidth: (item['width'] as num?)?.toDouble() ?? 0.0,
            normalizedHeight: (item['height'] as num?)?.toDouble() ?? 0.0,
            words: parsedWords,
          ),
        );
      }

      final avgConf = lines.isEmpty ? 0.0 : (confSum / lines.length);
      return AppleVisionOcrResult(
        lines: lines,
        wordBoxes: allWords,
        averageConfidence: avgConf,
      );
    } catch (e) {
      debugPrint('AppleVisionOcrService recognizeImage error: $e');
      return AppleVisionOcrResult.empty;
    }
  }
}
