import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../engine/layout_column_detector.dart' show PositionedTextLine;
import '../engine/ocr_proofreader_engine.dart';
import '../engine/turkish_morphology.dart';
import 'native_document_restorer.dart';

/// Tesseract 5 LSTM tekil satır doğrulama isteği.
@immutable
class TesseractLineTask {
  final String id;
  final int cropX;
  final int cropY;
  final int cropWidth;
  final int cropHeight;
  final String languages;

  const TesseractLineTask({
    required this.id,
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
    required this.languages,
  });
}

/// Tesseract 5 LSTM tekil satır çıktısı.
@immutable
class TesseractLineResult {
  final String id;
  final String text;
  final int confidence;
  final bool succeeded;

  const TesseractLineResult({
    required this.id,
    required this.text,
    required this.confidence,
    required this.succeeded,
  });
}

/// Worker Isolate içine gönderilen sayfa bazlı tekil satır doğrulama paketi.
@immutable
class TesseractLineVerificationRequest {
  final String tessdataDir;
  final Uint8List restoredPngBytes;
  final List<TesseractLineTask> tasks;

  const TesseractLineVerificationRequest({
    required this.tessdataDir,
    required this.restoredPngBytes,
    required this.tasks,
  });
}

/// Sayfa bazlı Tesseract doğrulama çıktısı.
@immutable
class TesseractLineVerificationBatchResult {
  final Map<String, TesseractLineResult> results;
  final bool usedNativeTesseract;

  const TesseractLineVerificationBatchResult({
    required this.results,
    required this.usedNativeTesseract,
  });

  const TesseractLineVerificationBatchResult.empty()
      : results = const {},
        usedNativeTesseract = false;
}

/// Soyut tekil satır OCR doğrulama kapısı (DIP — UI/Servis C++ FFI'ya değil bu arayüze dayanır).
abstract class OcrLineVerifierGateway {
  bool get isAvailable;

  Future<TesseractLineVerificationBatchResult> verifyPageLines(
    TesseractLineVerificationRequest request,
  );
}

// ---------------------------------------------------------------------------
// C ABI FFI tanımları (`native/tahrir_ocr_native/tahrir_ocr_native.h` ABI v2)
// ---------------------------------------------------------------------------

final class _TahrirTesseractHandleNative extends ffi.Opaque {}

final class _TahrirTesseractLineResultNative extends ffi.Struct {
  external ffi.Pointer<Utf8> utf8Text;

  @ffi.Int32()
  external int confidence;

  @ffi.Int32()
  external int errorCode;
}

typedef _TessIsAvailableNative = ffi.Int32 Function();
typedef _TessIsAvailableDart = int Function();

typedef _TessCreateNative = ffi.Pointer<_TahrirTesseractHandleNative> Function(
  ffi.Pointer<Utf8> tessdataDir,
  ffi.Pointer<Utf8> languages,
);
typedef _TessCreateDart = ffi.Pointer<_TahrirTesseractHandleNative> Function(
  ffi.Pointer<Utf8> tessdataDir,
  ffi.Pointer<Utf8> languages,
);

typedef _TessRecognizeLineNative
    = ffi.Pointer<_TahrirTesseractLineResultNative> Function(
  ffi.Pointer<_TahrirTesseractHandleNative> handle,
  ffi.Pointer<ffi.Uint8> grayPixels,
  ffi.Int32 width,
  ffi.Int32 height,
  ffi.Int32 padPx,
);
typedef _TessRecognizeLineDart
    = ffi.Pointer<_TahrirTesseractLineResultNative> Function(
  ffi.Pointer<_TahrirTesseractHandleNative> handle,
  ffi.Pointer<ffi.Uint8> grayPixels,
  int width,
  int height,
  int padPx,
);

typedef _TessFreeLineResultNative = ffi.Void Function(
  ffi.Pointer<_TahrirTesseractLineResultNative> result,
);
typedef _TessFreeLineResultDart = void Function(
  ffi.Pointer<_TahrirTesseractLineResultNative> result,
);

typedef _TessDestroyNative = ffi.Void Function(
  ffi.Pointer<_TahrirTesseractHandleNative> handle,
);
typedef _TessDestroyDart = void Function(
  ffi.Pointer<_TahrirTesseractHandleNative> handle,
);

class _TesseractNativeBinding {
  final _TessIsAvailableDart isAvailable;
  final _TessCreateDart create;
  final _TessRecognizeLineDart recognizeLine;
  final _TessFreeLineResultDart freeLineResult;
  final _TessDestroyDart destroy;

  _TesseractNativeBinding({
    required this.isAvailable,
    required this.create,
    required this.recognizeLine,
    required this.freeLineResult,
    required this.destroy,
  });

  static _TesseractNativeBinding? tryLoad() {
    if (kIsWeb) return null;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      if (!Platform.isAndroid) {
        return null;
      }
      final lib = ffi.DynamicLibrary.open('libtahrir_ocr_native.so');
      return _TesseractNativeBinding(
        isAvailable:
            lib.lookupFunction<_TessIsAvailableNative, _TessIsAvailableDart>(
          'tahrir_tesseract_is_available',
        ),
        create: lib.lookupFunction<_TessCreateNative, _TessCreateDart>(
          'tahrir_tesseract_create',
        ),
        recognizeLine: lib
            .lookupFunction<_TessRecognizeLineNative, _TessRecognizeLineDart>(
          'tahrir_tesseract_recognize_line',
        ),
        freeLineResult: lib.lookupFunction<_TessFreeLineResultNative,
            _TessFreeLineResultDart>(
          'tahrir_tesseract_free_line_result',
        ),
        destroy: lib.lookupFunction<_TessDestroyNative, _TessDestroyDart>(
          'tahrir_tesseract_destroy',
        ),
      );
    } catch (e) {
      debugPrint('TesseractLineVerifier native bind unavailable: $e');
      return null;
    }
  }
}

/// Android'de `libtahrir_ocr_native.so` -> `dlopen("libtesseract.so")` C++ FFI köprüsü
/// üzerinden çalışan, `PSM_SINGLE_LINE` (7) + `OEM_LSTM_ONLY` (1) tekil satır doğrulayıcısı.
class TesseractLineVerifier implements OcrLineVerifierGateway {
  static final TesseractLineVerifier instance = TesseractLineVerifier();

  bool? _cachedAvailability;

  @override
  bool get isAvailable {
    if (_cachedAvailability != null) return _cachedAvailability!;
    if (kIsWeb ||
        Platform.environment.containsKey('FLUTTER_TEST') ||
        !Platform.isAndroid) {
      _cachedAvailability = false;
      return false;
    }
    final binding = _TesseractNativeBinding.tryLoad();
    _cachedAvailability = binding != null && binding.isAvailable() == 1;
    return _cachedAvailability!;
  }

  @override
  Future<TesseractLineVerificationBatchResult> verifyPageLines(
    TesseractLineVerificationRequest request,
  ) async {
    if (request.tasks.isEmpty ||
        request.tessdataDir.isEmpty ||
        request.restoredPngBytes.isEmpty) {
      return const TesseractLineVerificationBatchResult.empty();
    }
    if (!isAvailable) {
      return const TesseractLineVerificationBatchResult.empty();
    }
    try {
      return await compute(_verifyPageLinesInIsolate, request);
    } catch (e) {
      debugPrint('TesseractLineVerifier isolate error: $e');
      return const TesseractLineVerificationBatchResult.empty();
    }
  }
}

TesseractLineVerificationBatchResult _verifyPageLinesInIsolate(
  TesseractLineVerificationRequest request,
) {
  final binding = _TesseractNativeBinding.tryLoad();
  if (binding == null || binding.isAvailable() != 1) {
    return const TesseractLineVerificationBatchResult.empty();
  }

  final decoded = img.decodePng(request.restoredPngBytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return const TesseractLineVerificationBatchResult.empty();
  }

  final grouped = <String, List<TesseractLineTask>>{};
  for (final task in request.tasks) {
    grouped.putIfAbsent(task.languages, () => <TesseractLineTask>[]).add(task);
  }

  final outResults = <String, TesseractLineResult>{};
  final imgW = decoded.width;
  final imgH = decoded.height;

  for (final entry in grouped.entries) {
    final tessDirPtr = request.tessdataDir.toNativeUtf8();
    final langsPtr = entry.key.toNativeUtf8();
    ffi.Pointer<_TahrirTesseractHandleNative> handle = ffi.nullptr;
    try {
      handle = binding.create(tessDirPtr, langsPtr);
    } finally {
      calloc.free(tessDirPtr);
      calloc.free(langsPtr);
    }

    if (handle == ffi.nullptr) {
      continue;
    }

    try {
      for (final task in entry.value) {
        final left = (task.cropX - 4).clamp(0, imgW - 1);
        final top = (task.cropY - 4).clamp(0, imgH - 1);
        final right = (task.cropX + task.cropWidth + 4).clamp(left + 1, imgW);
        final bottom = (task.cropY + task.cropHeight + 4).clamp(top + 1, imgH);
        final cropW = right - left;
        final cropH = bottom - top;
        if (cropW <= 2 || cropH <= 2) continue;

        final gray = Uint8List(cropW * cropH);
        for (int dy = 0; dy < cropH; dy++) {
          final py = top + dy;
          final rowOffset = dy * cropW;
          for (int dx = 0; dx < cropW; dx++) {
            final pixel = decoded.getPixel(left + dx, py);
            final r = img.getRed(pixel);
            final g = img.getGreen(pixel);
            final b = img.getBlue(pixel);
            gray[rowOffset + dx] = ((r * 77 + g * 150 + b * 29) >> 8).clamp(0, 255);
          }
        }

        final bufPtr = calloc<ffi.Uint8>(gray.length);
        ffi.Pointer<_TahrirTesseractLineResultNative> resPtr = ffi.nullptr;
        try {
          bufPtr.asTypedList(gray.length).setAll(0, gray);
          resPtr = binding.recognizeLine(handle, bufPtr, cropW, cropH, 10);
          if (resPtr != ffi.nullptr) {
            final nativeRes = resPtr.ref;
            if (nativeRes.errorCode == 0 && nativeRes.utf8Text != ffi.nullptr) {
              final text = nativeRes.utf8Text.toDartString().trim();
              outResults[task.id] = TesseractLineResult(
                id: task.id,
                text: text,
                confidence: nativeRes.confidence.clamp(0, 100),
                succeeded: text.isNotEmpty,
              );
            }
          }
        } finally {
          if (resPtr != ffi.nullptr) {
            binding.freeLineResult(resPtr);
          }
          calloc.free(bufPtr);
        }
      }
    } finally {
      binding.destroy(handle);
    }
  }

  return TesseractLineVerificationBatchResult(
    results: outResults,
    usedNativeTesseract: true,
  );
}

/// ML Kit + Zemberek Biçimbilim + Tesseract 5 LSTM hibrit hakem motoru (Saf Deterministik).
///
/// Gereksiz CPU tüketimini önlemek için yalnızca düşük güvenli/şüpheli satırları ve ML Kit'in
/// atladığı C++ mürekkep satırlarını seçer; çıkan adayları bileşik dil kalitesi puanıyla yarışır.
abstract final class OcrEnsembleArbitrator {
  static const double lowConfidenceThreshold = 0.78;
  static const int maxSuspiciousMlKitLinesPerPage = 18;
  static const int maxSkippedInkLinesPerPage = 8;

  static final RegExp _noiseCharsRegex = RegExp(r'[|~^¬¤§¦]');
  static final RegExp _digitAlphaBlendRegex =
      RegExp(r'\b(?:[a-zçğıöşü]+[0-9]+[a-zçğıöşü]*|[a-zçğıöşü]*[0-9]+[a-zçğıöşü]+)\b',
          caseSensitive: false);
  static final RegExp _arabicCharsRegex =
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');
  static final RegExp _turkishDiacriticsRegex = RegExp(r'[çğışöüÇĞİŞÖÜ]');
  static final RegExp _allCapsOrRomanRegex =
      RegExp(r'^[A-ZÇĞİŞÖÜIVXLCDM]{2,}$');

  /// Bir ML Kit satırının Tesseract doğrulamasına aday olup olmadığını denetler.
  static bool isLineSuspicious(
    String text, {
    required double minWordConfidence,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (minWordConfidence < lowConfidenceThreshold) return true;
    if (_noiseCharsRegex.hasMatch(trimmed) ||
        _digitAlphaBlendRegex.hasMatch(trimmed)) {
      return true;
    }

    final stats = _analyzeTurkishWords(trimmed);
    return stats.unknownCount > 0;
  }

  /// Sayfadaki en şüpheli ML Kit satırlarının indekslerini öncelik sırasına göre seçer.
  static List<int> selectSuspiciousMlKitLineIndices(
    List<({String text, double minWordConfidence})> mlKitLines,
  ) {
    final scored = <({int index, double priority})>[];
    for (int i = 0; i < mlKitLines.length; i++) {
      final line = mlKitLines[i];
      if (!isLineSuspicious(
        line.text,
        minWordConfidence: line.minWordConfidence,
      )) {
        continue;
      }
      final stats = _analyzeTurkishWords(line.text);
      final noisePenalty = (_noiseCharsRegex.hasMatch(line.text) ||
              _digitAlphaBlendRegex.hasMatch(line.text))
          ? 0.35
          : 0.0;
      final priority =
          (1.0 - line.minWordConfidence) + stats.unknownCount * 0.22 + noisePenalty;
      scored.add((index: i, priority: priority));
    }

    scored.sort((a, b) => b.priority.compareTo(a.priority));
    return scored
        .take(maxSuspiciousMlKitLinesPerPage)
        .map((s) => s.index)
        .toList(growable: false);
  }

  /// ML Kit tarafından kapsanmayan C++ mürekkep satırlarını (Arapça / dipnot) bulur.
  static List<RestoredInkLine> selectSkippedInkLines({
    required DocumentRestorationResult restoration,
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

    final skipped = <RestoredInkLine>[];
    for (final inkLine in restoration.lines) {
      if (inkLine.width < restoration.width * 0.08 || inkLine.height < 10) {
        continue;
      }
      if (!isInkLineCoveredByOcr(
        inkLine: inkLine,
        imageWidth: restoration.width,
        imageHeight: restoration.height,
        ocrLines: ocrLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      )) {
        skipped.add(inkLine);
        if (skipped.length >= maxSkippedInkLinesPerPage) break;
      }
    }
    return skipped;
  }

  /// C++ mürekkep satırının herhangi bir OCR satırıyla `> %18` örtüşüp örtüşmediğini hesaplar.
  static bool isInkLineCoveredByOcr({
    required RestoredInkLine inkLine,
    required int imageWidth,
    required int imageHeight,
    required List<PositionedTextLine> ocrLines,
    required double pageWidth,
    required double pageHeight,
  }) {
    final normLeft = inkLine.x / imageWidth;
    final normTop = inkLine.y / imageHeight;
    final normRight = (inkLine.x + inkLine.width) / imageWidth;
    final normBottom = (inkLine.y + inkLine.height) / imageHeight;
    final inkArea = (normRight - normLeft) * (normBottom - normTop);
    if (inkArea <= 0) return false;

    for (final ocrLine in ocrLines) {
      final oLeft = ocrLine.bounds.left / pageWidth;
      final oTop = ocrLine.bounds.top / pageHeight;
      final oRight = ocrLine.bounds.right / pageWidth;
      final oBottom = ocrLine.bounds.bottom / pageHeight;

      final interW = math.min(normRight, oRight) - math.max(normLeft, oLeft);
      final interH = math.min(normBottom, oBottom) - math.max(normTop, oTop);
      if (interW > 0 && interH > 0) {
        final interArea = interW * interH;
        if (interArea / inkArea > 0.18) {
          return true;
        }
      }
    }
    return false;
  }

  /// ML Kit ve Tesseract Türkçe çıktılarını Zemberek + güven + gürültü cezasıyla yarıştırır.
  static ({String text, bool acceptedTesseract, double qualityScore})
      arbitrateTurkishLine({
    required String mlKitText,
    required double mlKitConfidence,
    required String tesseractText,
    required int tesseractConfidence,
  }) {
    final mlClean = mlKitText.trim();
    final tessClean = tesseractText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (mlClean.isEmpty && tessClean.isNotEmpty && tesseractConfidence >= 60) {
      return (
        text: tessClean,
        acceptedTesseract: true,
        qualityScore: _scoreTurkishCandidate(
          tessClean,
          tesseractConfidence / 100.0,
        ),
      );
    }

    final mlScore = _scoreTurkishCandidate(
      mlClean,
      mlKitConfidence.clamp(0.0, 1.0),
    );

    if (tessClean.isEmpty || tesseractConfidence < 55) {
      return (text: mlClean, acceptedTesseract: false, qualityScore: mlScore);
    }

    final tessScore = _scoreTurkishCandidate(
      tessClean,
      (tesseractConfidence / 100.0).clamp(0.0, 1.0),
    );

    if (tessScore > mlScore + 0.04) {
      return (text: tessClean, acceptedTesseract: true, qualityScore: tessScore);
    }
    return (text: mlClean, acceptedTesseract: false, qualityScore: mlScore);
  }

  /// ML Kit'in atladığı bir satırın gerçek metin blokuna mı yükseltileceğini,
  /// yoksa şeffaf `OpticalInkBlock` olarak mı kalacağını belirler.
  static ({bool promote, bool isArabic, String cleanedText})
      evaluateSkippedInkLine({
    required String tesseractText,
    required int tesseractConfidence,
  }) {
    final cleaned = tesseractText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty || tesseractConfidence < 65) {
      return (promote: false, isArabic: false, cleanedText: cleaned);
    }

    final arabicCount = _arabicCharsRegex.allMatches(cleaned).length;
    if (arabicCount >= 3) {
      return (promote: true, isArabic: true, cleanedText: cleaned);
    }

    final stats = _analyzeTurkishWords(cleaned);
    if (stats.totalChecked >= 2) {
      final knownRatio = stats.knownCount / stats.totalChecked;
      if (knownRatio >= 0.50) {
        return (promote: true, isArabic: false, cleanedText: cleaned);
      }
    }

    return (promote: false, isArabic: false, cleanedText: cleaned);
  }

  static double _scoreTurkishCandidate(String text, double normConfidence) {
    if (text.isEmpty) return -1.0;
    final stats = _analyzeTurkishWords(text);
    final knownRatio = stats.totalChecked == 0
        ? 0.5
        : (stats.knownCount / stats.totalChecked);
    final diacriticBonus =
        (stats.knownCount > 0 && _turkishDiacriticsRegex.hasMatch(text))
            ? 0.04
            : 0.0;
    final garbageCount = _noiseCharsRegex.allMatches(text).length +
        _digitAlphaBlendRegex.allMatches(text).length;
    final garbagePenalty = garbageCount * 0.18;
    return 0.55 * knownRatio +
        0.35 * normConfidence +
        diacriticBonus -
        garbagePenalty;
  }

  static ({int totalChecked, int knownCount, int unknownCount})
      _analyzeTurkishWords(String text) {
    int totalChecked = 0;
    int knownCount = 0;
    int unknownCount = 0;

    final rawTokens = text.split(RegExp(r'\s+'));
    for (final raw in rawTokens) {
      final stripped = raw.replaceAll(
        RegExp(r'''^[\(\[\{"'«“‘.,;:!?…—–-]+|[\)\]\}"'»”’.,;:!?…—–-]+$'''),
        '',
      );
      if (stripped.length < 3) continue;
      if (RegExp(r'^[0-9]+$').hasMatch(stripped)) continue;
      if (_allCapsOrRomanRegex.hasMatch(stripped)) continue;
      if (_arabicCharsRegex.hasMatch(stripped)) continue;

      totalChecked++;
      if (!RegExp(r'^[a-zA-ZçğıöşüÇĞİŞÖÜâîûÂÎÛ]+$').hasMatch(stripped)) {
        unknownCount++;
        continue;
      }
      final lower = OcrProofreaderEngine.toTurkishLower(stripped);
      if (TurkishMorphology.isKnownWord(lower)) {
        knownCount++;
      } else {
        unknownCount++;
      }
    }

    return (
      totalChecked: totalChecked,
      knownCount: knownCount,
      unknownCount: unknownCount,
    );
  }
}
