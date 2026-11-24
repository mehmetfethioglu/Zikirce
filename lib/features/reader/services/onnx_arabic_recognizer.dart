import 'dart:async';
import 'package:flutter/foundation.dart';

/// OCR Çıkarım Sonucu DTO
@immutable
class OcrRecognitionResult {
  final String text;
  final double confidence;
  final bool isSuccessful;

  const OcrRecognitionResult({
    required this.text,
    required this.confidence,
    this.isSuccessful = true,
  });

  const OcrRecognitionResult.empty()
      : text = '',
        confidence = 0.0,
        isSuccessful = false;
}

/// Arapça CTC Kod Çözücü ve Görsel Kesit Yönlendirici Servisi
class OnnxArabicRecognizer {
  const OnnxArabicRecognizer();

  /// Ön yükleme kancası (No-op: MLKit & 300 DPI Kesit Kırpıcı kullanılmaktadır)
  static Future<void> preload() async {}

  /// Arapça hat ve kaligrafi bloklarında sahte model tahmini yerine
  /// doğrudan 300 DPI orijinal PDF görsel kesit (Inline Image Crop) katmanına yönlendirir.
  Future<OcrRecognitionResult> recognizeBlock(Uint8List imageBytes) async {
    return const OcrRecognitionResult.empty();
  }

  /// CTC Greedy Decoder: ArgMax, ardışık mükerrer karakterleri birleştirme ve blank token eleme
  static OcrRecognitionResult decodeCtcOutput({
    required List<dynamic> outputData,
    required List<String> dictionary,
  }) {
    if (outputData.isEmpty) return const OcrRecognitionResult.empty();

    final batch = outputData[0] as List<dynamic>;
    final timeSteps = batch.length;
    if (timeSteps == 0) return const OcrRecognitionResult.empty();
    final numClasses = (batch[0] as List<dynamic>).length;

    final recognizedChars = <String>[];
    var totalConfidence = 0.0;
    var validCharCount = 0;
    var lastClassIndex = -1;

    for (var t = 0; t < timeSteps; t++) {
      final stepProbs = batch[t] as List<dynamic>;
      var maxProb = -1.0;
      var maxIndex = 0;

      for (var c = 0; c < numClasses; c++) {
        final prob = (stepProbs[c] as num).toDouble();
        if (prob > maxProb) {
          maxProb = prob;
          maxIndex = c;
        }
      }

      // 0. index <blank> CTC token'ıdır
      if (maxIndex != 0 && maxIndex != lastClassIndex) {
        if (maxIndex < dictionary.length) {
          final char = dictionary[maxIndex];
          recognizedChars.add(char);
          totalConfidence += maxProb;
          validCharCount++;
        }
      }
      lastClassIndex = maxIndex;
    }

    if (validCharCount == 0) {
      return const OcrRecognitionResult.empty();
    }

    final fullText = recognizedChars.join('');
    final averageConfidence = totalConfidence / validCharCount;

    return OcrRecognitionResult(
      text: fullText,
      confidence: averageConfidence,
      isSuccessful: averageConfidence >= 0.50,
    );
  }
}
