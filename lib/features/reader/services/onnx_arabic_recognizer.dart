import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// ONNX Model Çıkarım Sonucu DTO
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

/// Arka Plan Isolate Parametresi
class _OcrWorkerPayload {
  final Uint8List imageBytes;
  final Uint8List modelBytes;
  final List<String> dictionary;

  const _OcrWorkerPayload({
    required this.imageBytes,
    required this.modelBytes,
    required this.dictionary,
  });
}

/// On-Device PP-OCRv4 Mobile Arabic Inference Servisi
class OnnxArabicRecognizer {
  static const String modelAssetPath = 'assets/models/pp_ocrv4_mobile_arabic_int8.onnx';
  static const String keysAssetPath = 'assets/models/pp_ocr_keys_ar.txt';

  static Uint8List? _cachedModelBytes;
  static List<String>? _cachedDictionary;

  const OnnxArabicRecognizer();

  /// Model ve Karakter Sözlüğünü belleğe (AOT) önceden yükler
  static Future<void> preload() async {
    if (_cachedModelBytes == null) {
      try {
        final modelByteData = await rootBundle.load(modelAssetPath);
        _cachedModelBytes = modelByteData.buffer.asUint8List();
      } catch (e) {
        debugPrint('ONNX Model Load Notice: $e');
      }
    }

    if (_cachedDictionary == null) {
      try {
        final keysString = await rootBundle.loadString(keysAssetPath);
        final lines = keysString.split('\n');
        _cachedDictionary = lines.map((e) => e.replaceAll('\r', '')).toList();
        if (!_cachedDictionary!.contains('<blank>')) {
          _cachedDictionary!.insert(0, '<blank>');
        }
      } catch (e) {
        debugPrint('ONNX Keys Load Notice: $e');
      }
    }
  }

  /// Verilen görsel kesiti arka plan Isolate'te INT8 PP-OCRv4 ile tanır.
  /// UI thread asla bloke olmaz (120 FPS korunur).
  Future<OcrRecognitionResult> recognizeBlock(Uint8List imageBytes) async {
    await preload();

    if (_cachedModelBytes == null || _cachedDictionary == null) {
      return const OcrRecognitionResult.empty();
    }

    final payload = _OcrWorkerPayload(
      imageBytes: imageBytes,
      modelBytes: _cachedModelBytes!,
      dictionary: _cachedDictionary!,
    );

    // Compute / Worker Isolate üzerinden sıfır UI kilitlemesi
    return await compute(_isolateOcrInferenceWorker, payload);
  }

  /// İzole edilmiş Arka Plan İşçisi (Worker Isolate)
  static OcrRecognitionResult _isolateOcrInferenceWorker(_OcrWorkerPayload payload) {
    OrtSession? session;
    OrtRunOptions? runOptions;
    OrtValue? inputTensor;

    try {
      // 1. Görseli Decode Et ve Boyutlandır (PP-OCRv4 sabit yükseklik: 48 px, orantılı genişlik)
      final decodedImage = img.decodeImage(payload.imageBytes);
      if (decodedImage == null) {
        return const OcrRecognitionResult.empty();
      }

      const targetHeight = 48;
      final aspect = decodedImage.width / decodedImage.height;
      var targetWidth = (targetHeight * aspect).round();
      // 32'nin katlarına yuvarla (Tensor Core / NEON optimizasyonu)
      targetWidth = math.max(32, ((targetWidth + 31) ~/ 32) * 32);

      final resized = img.copyResize(
        decodedImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

      // 2. Pre-Processing: [1, 3, 48, W] CHW Float32 Normalizasyonu ((pixel / 255.0 - 0.5) / 0.5)
      final float32List = Float32List(1 * 3 * targetHeight * targetWidth);
      final channelStride = targetHeight * targetWidth;

      for (var y = 0; y < targetHeight; y++) {
        for (var x = 0; x < targetWidth; x++) {
          final pixel = resized.getPixel(x, y);
          final r = ((img.getRed(pixel) / 255.0) - 0.5) / 0.5;
          final g = ((img.getGreen(pixel) / 255.0) - 0.5) / 0.5;
          final b = ((img.getBlue(pixel) / 255.0) - 0.5) / 0.5;

          final spatialIndex = y * targetWidth + x;
          float32List[0 * channelStride + spatialIndex] = r.toDouble();
          float32List[1 * channelStride + spatialIndex] = g.toDouble();
          float32List[2 * channelStride + spatialIndex] = b.toDouble();
        }
      }

      // 3. ONNX Runtime Session Başlatma
      OrtEnv.instance.init();

      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(2)
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

      session = OrtSession.fromBuffer(payload.modelBytes, sessionOptions);
      runOptions = OrtRunOptions();

      // 4. Tensör Tahsisi & Model Çıkarımı (Inference)
      final inputShape = [1, 3, targetHeight, targetWidth];
      inputTensor = OrtValueTensor.createTensorWithDataList(float32List, inputShape);

      final outputs = session.run(runOptions, {'x': inputTensor});
      if (outputs.isEmpty || outputs.first == null) {
        return const OcrRecognitionResult.empty();
      }

      final rawOutputValue = outputs.first!;
      final outputList = rawOutputValue.value as List<dynamic>;

      // 5. CTC Greedy Decoder & Skor Hesaplama
      final result = decodeCtcOutput(
        outputData: outputList,
        dictionary: payload.dictionary,
      );

      // Çıktı tensörlerini temizle
      for (final element in outputs) {
        element?.release();
      }

      return result;
    } catch (e) {
      debugPrint('ONNX OCR Worker Notice: $e');
      return const OcrRecognitionResult.empty();
    } finally {
      // 6. Bellek Sızıntılarını (OOM) Önlemek İçin Deterministik Dispose
      inputTensor?.release();
      runOptions?.release();
      session?.release();
    }
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
