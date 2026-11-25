import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Detected ink text line in pixel coordinates of the restored page image.
@immutable
class RestoredInkLine {
  final int x;
  final int y;
  final int width;
  final int height;
  final int columnIndex;
  final int baselineY;
  final bool isParagraphStart;

  const RestoredInkLine({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.columnIndex,
    required this.baselineY,
    required this.isParagraphStart,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': width,
        'h': height,
        'c': columnIndex,
        'by': baselineY,
        'ps': isParagraphStart,
      };

  factory RestoredInkLine.fromJson(Map<String, dynamic> json) {
    return RestoredInkLine(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
      columnIndex: (json['c'] as num?)?.toInt() ?? 0,
      baselineY: (json['by'] as num?)?.toInt() ?? 0,
      isParagraphStart: (json['ps'] as bool?) ?? false,
    );
  }
}

/// Word/phrase blob segmented directly from Sauvola-restored ink for K2pdfopt optical wrapping.
@immutable
class OpticalWordBlob {
  final int x;
  final int y;
  final int width;
  final int height;
  final int lineIndex;
  final int columnIndex;
  final int baselineY;
  final bool isParagraphStart;
  final bool isLineEnd;

  const OpticalWordBlob({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.lineIndex,
    required this.columnIndex,
    required this.baselineY,
    required this.isParagraphStart,
    required this.isLineEnd,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': width,
        'h': height,
        'li': lineIndex,
        'c': columnIndex,
        'by': baselineY,
        'ps': isParagraphStart,
        'le': isLineEnd,
      };

  factory OpticalWordBlob.fromJson(Map<String, dynamic> json) {
    return OpticalWordBlob(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
      lineIndex: (json['li'] as num?)?.toInt() ?? 0,
      columnIndex: (json['c'] as num?)?.toInt() ?? 0,
      baselineY: (json['by'] as num?)?.toInt() ?? 0,
      isParagraphStart: (json['ps'] as bool?) ?? false,
      isLineEnd: (json['le'] as bool?) ?? false,
    );
  }
}

/// Output of C++/FFI (or pure-Dart fallback) document restoration & optical segmentation.
@immutable
class DocumentRestorationResult {
  final int width;
  final int height;
  final double detectedSkewDeg;
  final int columnCount;
  final Uint8List restoredPngBytes;
  final Uint8List alphaMaskPngBytes;
  final List<RestoredInkLine> lines;
  final List<OpticalWordBlob> wordBlobs;
  final bool usedNativeFfi;

  const DocumentRestorationResult({
    required this.width,
    required this.height,
    required this.detectedSkewDeg,
    required this.columnCount,
    required this.restoredPngBytes,
    required this.alphaMaskPngBytes,
    required this.lines,
    required this.wordBlobs,
    required this.usedNativeFfi,
  });

  bool get isValid => width > 0 && height > 0 && restoredPngBytes.isNotEmpty;

  static final DocumentRestorationResult empty = DocumentRestorationResult(
    width: 0,
    height: 0,
    detectedSkewDeg: 0.0,
    columnCount: 1,
    restoredPngBytes: Uint8List(0),
    alphaMaskPngBytes: Uint8List(0),
    lines: const [],
    wordBlobs: const [],
    usedNativeFfi: false,
  );
}

// ---------------------------------------------------------------------------
// C ABI Struct Definitions matching `native/tahrir_ocr_native/tahrir_ocr_native.h`
// ---------------------------------------------------------------------------

final class _TahrirInkLineNative extends ffi.Struct {
  @ffi.Int32()
  external int x;
  @ffi.Int32()
  external int y;
  @ffi.Int32()
  external int width;
  @ffi.Int32()
  external int height;
  @ffi.Int32()
  external int columnIndex;
  @ffi.Int32()
  external int baselineY;
  @ffi.Uint8()
  external int isParagraphStart;
  @ffi.Uint8()
  external int pad0;
  @ffi.Uint8()
  external int pad1;
  @ffi.Uint8()
  external int pad2;
}

final class _TahrirWordBlobNative extends ffi.Struct {
  @ffi.Int32()
  external int x;
  @ffi.Int32()
  external int y;
  @ffi.Int32()
  external int width;
  @ffi.Int32()
  external int height;
  @ffi.Int32()
  external int lineIndex;
  @ffi.Int32()
  external int columnIndex;
  @ffi.Int32()
  external int baselineY;
  @ffi.Uint8()
  external int isParagraphStart;
  @ffi.Uint8()
  external int isLineEnd;
  @ffi.Uint8()
  external int pad0;
  @ffi.Uint8()
  external int pad1;
}

final class _TahrirPageResultNative extends ffi.Struct {
  @ffi.Int32()
  external int width;
  @ffi.Int32()
  external int height;
  @ffi.Float()
  external double detectedSkewDeg;
  external ffi.Pointer<ffi.Uint8> restoredGray;
  external ffi.Pointer<ffi.Uint8> inkAlphaMask;
  external ffi.Pointer<_TahrirInkLineNative> lines;
  @ffi.Int32()
  external int lineCount;
  external ffi.Pointer<_TahrirWordBlobNative> wordBlobs;
  @ffi.Int32()
  external int wordBlobCount;
  @ffi.Int32()
  external int columnCount;
}

typedef _RestoreNativeFn = ffi.Pointer<_TahrirPageResultNative> Function(
  ffi.Pointer<ffi.Uint8> rgbaPixels,
  ffi.Int32 width,
  ffi.Int32 height,
  ffi.Int32 sauvolaWindow,
  ffi.Float sauvolaK,
  ffi.Int32 enableDeskew,
);
typedef _RestoreDartFn = ffi.Pointer<_TahrirPageResultNative> Function(
  ffi.Pointer<ffi.Uint8> rgbaPixels,
  int width,
  int height,
  int sauvolaWindow,
  double sauvolaK,
  int enableDeskew,
);

typedef _FreeNativeFn = ffi.Void Function(ffi.Pointer<_TahrirPageResultNative>);
typedef _FreeDartFn = void Function(ffi.Pointer<_TahrirPageResultNative>);

class _NativeLibraryBinding {
  final _RestoreDartFn restore;
  final _FreeDartFn freeResult;

  _NativeLibraryBinding(this.restore, this.freeResult);

  static _NativeLibraryBinding? tryLoad() {
    if (kIsWeb) return null;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      ffi.DynamicLibrary? lib;
      if (Platform.isAndroid) {
        lib = ffi.DynamicLibrary.open('libtahrir_ocr_native.so');
      } else if (Platform.isIOS) {
        lib = ffi.DynamicLibrary.process();
      }
      if (lib == null) return null;

      final restore = lib.lookupFunction<_RestoreNativeFn, _RestoreDartFn>(
        'tahrir_restore_and_segment_page',
      );
      final freeResult = lib.lookupFunction<_FreeNativeFn, _FreeDartFn>(
        'tahrir_free_page_result',
      );
      return _NativeLibraryBinding(restore, freeResult);
    } catch (e) {
      debugPrint('NativeDocumentRestorer FFI fallback active: $e');
      return null;
    }
  }
}

/// Request payload passed across [compute] to execute restoration on a Worker Isolate.
@immutable
class DocumentRestorationRequest {
  final Uint8List pagePngBytes;
  final int sauvolaWindow;
  final double sauvolaK;
  final bool enableDeskew;

  const DocumentRestorationRequest({
    required this.pagePngBytes,
    this.sauvolaWindow = 29,
    this.sauvolaK = 0.22,
    this.enableDeskew = true,
  });
}

/// Executes 100% offline document restoration (illumination flattening, deskew,
/// Sauvola adaptive binarization, transparent ink alpha-masking, and column/word
/// segmentation) via native C++ FFI (zero-leak try/finally) or deterministic Dart mirror.
class NativeDocumentRestorer {
  const NativeDocumentRestorer._();

  /// Isolate-safe entry point (`compute(NativeDocumentRestorer.restoreIsolate, req)`).
  static DocumentRestorationResult restoreIsolate(
    DocumentRestorationRequest req,
  ) {
    return restoreAndSegmentSync(
      pagePngBytes: req.pagePngBytes,
      sauvolaWindow: req.sauvolaWindow,
      sauvolaK: req.sauvolaK,
      enableDeskew: req.enableDeskew,
    );
  }

  /// Asynchronous wrapper executing restoration off the UI thread.
  static Future<DocumentRestorationResult> restoreAndSegmentPage({
    required Uint8List pagePngBytes,
    int sauvolaWindow = 29,
    double sauvolaK = 0.22,
    bool enableDeskew = true,
  }) {
    if (pagePngBytes.isEmpty) {
      return Future.value(DocumentRestorationResult.empty);
    }
    return compute(
      restoreIsolate,
      DocumentRestorationRequest(
        pagePngBytes: pagePngBytes,
        sauvolaWindow: sauvolaWindow,
        sauvolaK: sauvolaK,
        enableDeskew: enableDeskew,
      ),
    );
  }

  /// Synchronous restoration pipeline (invoked inside Worker Isolate or tests).
  static DocumentRestorationResult restoreAndSegmentSync({
    required Uint8List pagePngBytes,
    int sauvolaWindow = 29,
    double sauvolaK = 0.22,
    bool enableDeskew = true,
  }) {
    if (pagePngBytes.isEmpty) return DocumentRestorationResult.empty;

    final decoded = img.decodeImage(pagePngBytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return DocumentRestorationResult.empty;
    }

    final width = decoded.width;
    final height = decoded.height;
    final rgbaBytes = decoded.getBytes(format: img.Format.rgba);

    final binding = _NativeLibraryBinding.tryLoad();
    if (binding != null) {
      final nativeRes = _runNativeFfi(
        binding: binding,
        rgbaBytes: rgbaBytes,
        width: width,
        height: height,
        sauvolaWindow: sauvolaWindow,
        sauvolaK: sauvolaK,
        enableDeskew: enableDeskew,
      );
      if (nativeRes != null) {
        return nativeRes;
      }
    }

    return _runPureDartFallback(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
      sauvolaWindow: sauvolaWindow,
      sauvolaK: sauvolaK,
      enableDeskew: enableDeskew,
    );
  }

  static DocumentRestorationResult? _runNativeFfi({
    required _NativeLibraryBinding binding,
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required int sauvolaWindow,
    required double sauvolaK,
    required bool enableDeskew,
  }) {
    final ffi.Pointer<ffi.Uint8> inPtr = calloc<ffi.Uint8>(rgbaBytes.length);
    ffi.Pointer<_TahrirPageResultNative> outPtr = ffi.nullptr;

    try {
      inPtr.asTypedList(rgbaBytes.length).setAll(0, rgbaBytes);
      outPtr = binding.restore(
        inPtr,
        width,
        height,
        sauvolaWindow,
        sauvolaK,
        enableDeskew ? 1 : 0,
      );
      if (outPtr == ffi.nullptr) return null;

      final resRef = outPtr.ref;
      final pixelCount = resRef.width * resRef.height;
      final grayBytes = Uint8List.fromList(
        resRef.restoredGray.asTypedList(pixelCount),
      );
      final alphaBytes = Uint8List.fromList(
        resRef.inkAlphaMask.asTypedList(pixelCount),
      );

      final lines = <RestoredInkLine>[];
      for (int i = 0; i < resRef.lineCount; i++) {
        final l = resRef.lines[i];
        lines.add(
          RestoredInkLine(
            x: l.x,
            y: l.y,
            width: l.width,
            height: l.height,
            columnIndex: l.columnIndex,
            baselineY: l.baselineY,
            isParagraphStart: l.isParagraphStart != 0,
          ),
        );
      }

      final blobs = <OpticalWordBlob>[];
      for (int i = 0; i < resRef.wordBlobCount; i++) {
        final b = resRef.wordBlobs[i];
        blobs.add(
          OpticalWordBlob(
            x: b.x,
            y: b.y,
            width: b.width,
            height: b.height,
            lineIndex: b.lineIndex,
            columnIndex: b.columnIndex,
            baselineY: b.baselineY,
            isParagraphStart: b.isParagraphStart != 0,
            isLineEnd: b.isLineEnd != 0,
          ),
        );
      }

      return _encodeResults(
        width: resRef.width,
        height: resRef.height,
        detectedSkewDeg: resRef.detectedSkewDeg,
        columnCount: resRef.columnCount,
        grayBytes: grayBytes,
        alphaBytes: alphaBytes,
        lines: lines,
        wordBlobs: blobs,
        usedNativeFfi: true,
      );
    } catch (e) {
      debugPrint('NativeDocumentRestorer FFI invocation error: $e');
      return null;
    } finally {
      if (outPtr != ffi.nullptr) {
        binding.freeResult(outPtr);
      }
      calloc.free(inPtr);
    }
  }

  static DocumentRestorationResult _runPureDartFallback({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required int sauvolaWindow,
    required double sauvolaK,
    required bool enableDeskew,
  }) {
    final pixelCount = width * height;
    var gray = Uint8List(pixelCount);
    for (int i = 0; i < pixelCount; i++) {
      final p = i * 4;
      final a = rgbaBytes[p + 3];
      if (a < 16) {
        gray[i] = 255;
      } else {
        gray[i] =
            ((rgbaBytes[p] * 77 + rgbaBytes[p + 1] * 150 + rgbaBytes[p + 2] * 29) >>
                    8)
                .clamp(0, 255);
      }
    }

    gray = _flattenIllumination(gray, width, height);

    double skew = 0.0;
    if (enableDeskew) {
      final res = _estimateAndDeskew(gray, width, height);
      skew = res.skewDeg;
      gray = res.gray;
    }

    final (outGray, outAlpha) = _applySauvolaBinarization(
      gray,
      width,
      height,
      sauvolaWindow > 4 ? sauvolaWindow : 29,
      sauvolaK > 0 ? sauvolaK : 0.22,
    );

    final (colCount, lines, blobs) =
        _detectColumnsAndSegment(outAlpha, width, height);

    return _encodeResults(
      width: width,
      height: height,
      detectedSkewDeg: skew,
      columnCount: colCount,
      grayBytes: outGray,
      alphaBytes: outAlpha,
      lines: lines,
      wordBlobs: blobs,
      usedNativeFfi: false,
    );
  }

  static DocumentRestorationResult _encodeResults({
    required int width,
    required int height,
    required double detectedSkewDeg,
    required int columnCount,
    required Uint8List grayBytes,
    required Uint8List alphaBytes,
    required List<RestoredInkLine> lines,
    required List<OpticalWordBlob> wordBlobs,
    required bool usedNativeFfi,
  }) {
    final pixelCount = width * height;
    final restoredRgba = Uint8List(pixelCount * 4);
    final maskRgba = Uint8List(pixelCount * 4);

    for (int i = 0; i < pixelCount; i++) {
      final p = i * 4;
      final g = grayBytes[i];
      restoredRgba[p] = g;
      restoredRgba[p + 1] = g;
      restoredRgba[p + 2] = g;
      restoredRgba[p + 3] = 255;

      // White RGB + ink alpha allows pure GPU BlendMode.srcIn theme tinting
      final a = alphaBytes[i];
      maskRgba[p] = 255;
      maskRgba[p + 1] = 255;
      maskRgba[p + 2] = 255;
      maskRgba[p + 3] = a;
    }

    final restoredImg = img.Image.fromBytes(
      width,
      height,
      restoredRgba,
      format: img.Format.rgba,
    );
    final maskImg = img.Image.fromBytes(
      width,
      height,
      maskRgba,
      format: img.Format.rgba,
    );

    return DocumentRestorationResult(
      width: width,
      height: height,
      detectedSkewDeg: detectedSkewDeg,
      columnCount: columnCount,
      restoredPngBytes: Uint8List.fromList(img.encodePng(restoredImg, level: 5)),
      alphaMaskPngBytes: Uint8List.fromList(img.encodePng(maskImg, level: 5)),
      lines: lines,
      wordBlobs: wordBlobs,
      usedNativeFfi: usedNativeFfi,
    );
  }

  static (Int64List sum, Int64List sumSq) _buildIntegral(
    Uint8List gray,
    int width,
    int height,
  ) {
    final stride = width + 1;
    final sum = Int64List(stride * (height + 1));
    final sumSq = Int64List(stride * (height + 1));

    for (int y = 1; y <= height; y++) {
      int rowSum = 0;
      int rowSq = 0;
      final srcOffset = (y - 1) * width;
      final prevOffset = (y - 1) * stride;
      final curOffset = y * stride;
      for (int x = 1; x <= width; x++) {
        final v = gray[srcOffset + x - 1];
        rowSum += v;
        rowSq += v * v;
        sum[curOffset + x] = sum[prevOffset + x] + rowSum;
        sumSq[curOffset + x] = sumSq[prevOffset + x] + rowSq;
      }
    }
    return (sum, sumSq);
  }

  static Uint8List _flattenIllumination(
    Uint8List gray,
    int width,
    int height,
  ) {
    final (sum, _) = _buildIntegral(gray, width, height);
    final stride = width + 1;
    final radius = (math.min(width, height) ~/ 14).clamp(18, 64);
    final out = Uint8List(gray.length);

    for (int y = 0; y < height; y++) {
      final y0 = math.max(0, y - radius);
      final y1 = math.min(height, y + radius + 1);
      final rowOff = y * width;
      for (int x = 0; x < width; x++) {
        final x0 = math.max(0, x - radius);
        final x1 = math.min(width, x + radius + 1);
        final area = (x1 - x0) * (y1 - y0);
        final total = sum[y1 * stride + x1] -
            sum[y0 * stride + x1] -
            sum[y1 * stride + x0] +
            sum[y0 * stride + x0];
        final localBg = math.max(32.0, total / area);
        final normalized = ((gray[rowOff + x] * 242.0) / localBg).round();
        out[rowOff + x] = normalized.clamp(0, 255);
      }
    }
    return out;
  }

  static double _projectionEnergy(
    Uint8List gray,
    int width,
    int height,
    double angleDeg,
    int step,
  ) {
    final rad = angleDeg * math.pi / 180.0;
    final sinA = math.sin(rad);
    final cosA = math.cos(rad);
    final cx = width ~/ 2;
    final cy = height ~/ 2;
    final proj = Int32List(height);

    for (int y = 0; y < height; y += step) {
      final rowOff = y * width;
      final dy = y - cy;
      for (int x = 0; x < width; x += step) {
        final v = gray[rowOff + x];
        if (v >= 170) continue;
        final dx = x - cx;
        final ry = (-dx * sinA + dy * cosA).round() + cy;
        if (ry >= 0 && ry < height) {
          proj[ry] += (200 - v);
        }
      }
    }

    double energy = 0.0;
    for (int i = 0; i < height; i++) {
      final dv = proj[i].toDouble();
      energy += dv * dv;
    }
    return energy;
  }

  static ({double skewDeg, Uint8List gray}) _estimateAndDeskew(
    Uint8List gray,
    int width,
    int height,
  ) {
    if (width < 40 || height < 40) {
      return (skewDeg: 0.0, gray: gray);
    }

    final step = (math.min(width, height) ~/ 360).clamp(1, 4);
    double bestAngle = 0.0;
    double bestEnergy = -1.0;

    for (double a = -5.0; a <= 5.001; a += 0.5) {
      final e = _projectionEnergy(gray, width, height, a, step);
      if (e > bestEnergy) {
        bestEnergy = e;
        bestAngle = a;
      }
    }

    final center = bestAngle;
    for (double a = center - 0.6; a <= center + 0.601; a += 0.15) {
      final e = _projectionEnergy(gray, width, height, a, step);
      if (e > bestEnergy) {
        bestEnergy = e;
        bestAngle = a;
      }
    }

    if (bestAngle.abs() < 0.35) {
      return (skewDeg: 0.0, gray: gray);
    }

    final rad = -bestAngle * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    final cx = width * 0.5;
    final cy = height * 0.5;

    final rotated = Uint8List(gray.length)..fillRange(0, gray.length, 255);
    for (int y = 0; y < height; y++) {
      final dy = y - cy;
      final rowOff = y * width;
      for (int x = 0; x < width; x++) {
        final dx = x - cx;
        final sx = dx * cosA - dy * sinA + cx;
        final sy = dx * sinA + dy * cosA + cy;
        final x0 = sx.floor();
        final y0 = sy.floor();
        if (x0 < 0 || y0 < 0 || x0 + 1 >= width || y0 + 1 >= height) {
          continue;
        }
        final fx = sx - x0;
        final fy = sy - y0;
        final idx00 = y0 * width + x0;
        final top = gray[idx00] + (gray[idx00 + 1] - gray[idx00]) * fx;
        final bot =
            gray[idx00 + width] + (gray[idx00 + width + 1] - gray[idx00 + width]) * fx;
        rotated[rowOff + x] = (top + (bot - top) * fy).round().clamp(0, 255);
      }
    }
    return (skewDeg: bestAngle, gray: rotated);
  }

  static (Uint8List outGray, Uint8List outAlpha) _applySauvolaBinarization(
    Uint8List gray,
    int width,
    int height,
    int windowSize,
    double sauvolaK,
  ) {
    final (sum, sumSq) = _buildIntegral(gray, width, height);
    final half = math.max(4, windowSize ~/ 2);
    final stride = width + 1;
    final outGray = Uint8List(gray.length)..fillRange(0, gray.length, 255);
    final outAlpha = Uint8List(gray.length);

    for (int y = 0; y < height; y++) {
      final y0 = math.max(0, y - half);
      final y1 = math.min(height, y + half + 1);
      final rowOff = y * width;
      for (int x = 0; x < width; x++) {
        final x0 = math.max(0, x - half);
        final x1 = math.min(width, x + half + 1);
        final area = ((x1 - x0) * (y1 - y0)).toDouble();
        final s1 = sum[y1 * stride + x1] -
            sum[y0 * stride + x1] -
            sum[y1 * stride + x0] +
            sum[y0 * stride + x0];
        final s2 = sumSq[y1 * stride + x1] -
            sumSq[y0 * stride + x1] -
            sumSq[y1 * stride + x0] +
            sumSq[y0 * stride + x0];
        final mean = s1 / area;
        final variance = math.max(0.0, (s2 / area) - mean * mean);
        final stddev = math.sqrt(variance);
        final thresh = mean * (1.0 + sauvolaK * (stddev / 128.0 - 1.0));
        final px = gray[rowOff + x].toDouble();
        const softBand = 24.0;
        final strength = (thresh + softBand * 0.45 - px) / softBand;
        if (strength > 0.0) {
          final alpha = (math.min(1.0, strength) * 255.0).round().clamp(0, 255);
          outAlpha[rowOff + x] = alpha;
          outGray[rowOff + x] = (255 - alpha).clamp(0, 255);
        }
      }
    }

    final cleaned = Uint8List.fromList(outAlpha);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        if (outAlpha[idx] == 0) continue;
        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (outAlpha[(y + dy) * width + (x + dx)] >= 64) {
              neighbors++;
            }
          }
        }
        if (neighbors == 0) {
          cleaned[idx] = 0;
          outGray[idx] = 255;
        }
      }
    }
    return (outGray, cleaned);
  }

  static (int colCount, List<RestoredInkLine> lines, List<OpticalWordBlob> blobs)
      _detectColumnsAndSegment(
    Uint8List alpha,
    int width,
    int height,
  ) {
    final minX = math.max(2, width ~/ 60);
    final maxX = math.min(width - 2, width - minX);
    final minY = math.max(2, height ~/ 80);
    final maxY = math.min(height - 2, height - minY);

    final colInk = Int32List(width);
    for (int y = minY; y < maxY; y++) {
      final rowOff = y * width;
      for (int x = minX; x < maxX; x++) {
        if (alpha[rowOff + x] >= 80) colInk[x]++;
      }
    }

    final gutterStart = (width * 0.36).round();
    final gutterEnd = (width * 0.64).round();
    int bestStart = -1;
    int bestLen = 0;
    int curStart = -1;
    final quietThresh = math.max(2, height ~/ 180);

    for (int x = gutterStart; x <= gutterEnd; x++) {
      if (colInk[x] <= quietThresh) {
        if (curStart < 0) curStart = x;
        final len = x - curStart + 1;
        if (len > bestLen) {
          bestLen = len;
          bestStart = curStart;
        }
      } else {
        curStart = -1;
      }
    }

    final cols = <({int x0, int x1, int index})>[];
    final minGutterPx = math.max(10, width ~/ 32);
    int colCount = 1;
    if (bestLen >= minGutterPx && bestStart > 0) {
      final mid = bestStart + (bestLen ~/ 2);
      cols.add((x0: minX, x1: mid - 1, index: 0));
      cols.add((x0: mid + 1, x1: maxX, index: 1));
      colCount = 2;
    } else {
      cols.add((x0: minX, x1: maxX, index: 0));
    }

    final outLines = <RestoredInkLine>[];
    final outBlobs = <OpticalWordBlob>[];

    for (final col in cols) {
      final rowInk = Int32List(height);
      for (int y = minY; y < maxY; y++) {
        int c = 0;
        final rowOff = y * width;
        for (int x = col.x0; x <= col.x1; x++) {
          if (alpha[rowOff + x] >= 80) c++;
        }
        rowInk[y] = c;
      }

      int prevBottom = -1;
      int colLeftEdge = col.x1;
      final colLines = <RestoredInkLine>[];

      int y = minY;
      while (y < maxY) {
        while (y < maxY && rowInk[y] < 2) {
          y++;
        }
        if (y >= maxY) break;
        final y0 = y;
        while (y < maxY &&
            (rowInk[y] >= 2 || (y + 1 < maxY && rowInk[y + 1] >= 2))) {
          y++;
        }
        final y1 = y - 1;
        final lineH = y1 - y0 + 1;
        if (lineH < 3 || lineH > height ~/ 4) continue;

        int lx0 = col.x1;
        int lx1 = col.x0;
        for (int ly = y0; ly <= y1; ly++) {
          final rowOff = ly * width;
          for (int lx = col.x0; lx <= col.x1; lx++) {
            if (alpha[rowOff + lx] >= 80) {
              if (lx < lx0) lx0 = lx;
              if (lx > lx1) lx1 = lx;
            }
          }
        }
        if (lx1 <= lx0) continue;
        if (lx0 < colLeftEdge) colLeftEdge = lx0;

        final rx = (lx0 - 1).clamp(0, width - 1);
        final ry = (y0 - 1).clamp(0, height - 1);
        final rw = (lx1 - rx + 2).clamp(1, width - rx);
        final rh = (y1 - ry + 2).clamp(1, height - ry);
        final vGap = prevBottom >= 0 ? (y0 - prevBottom) : lineH * 2;
        final paraStart =
            colLines.isEmpty || vGap > (lineH * 0.72).round();
        prevBottom = y1;
        colLines.add(
          RestoredInkLine(
            x: rx,
            y: ry,
            width: rw,
            height: rh,
            columnIndex: col.index,
            baselineY: y1,
            isParagraphStart: paraStart,
          ),
        );
      }

      for (final rawLine in colLines) {
        final isPara = rawLine.isParagraphStart ||
            (rawLine.x - colLeftEdge) > (rawLine.height * 0.9).round();
        final line = RestoredInkLine(
          x: rawLine.x,
          y: rawLine.y,
          width: rawLine.width,
          height: rawLine.height,
          columnIndex: rawLine.columnIndex,
          baselineY: rawLine.baselineY,
          isParagraphStart: isPara,
        );
        final lineIdx = outLines.length;
        outLines.add(line);

        final hasCol = Uint8List(line.width);
        for (int lx = 0; lx < line.width; lx++) {
          final px = line.x + lx;
          for (int ly = line.y; ly < line.y + line.height; ly++) {
            if (alpha[ly * width + px] >= 75) {
              hasCol[lx] = 1;
              break;
            }
          }
        }

        final wordGapThresh = math.max(4, (line.height * 0.34).round());
        final blobStartIdx = outBlobs.length;
        int lx = 0;
        while (lx < line.width) {
          while (lx < line.width && hasCol[lx] == 0) {
            lx++;
          }
          if (lx >= line.width) break;
          final bx0 = lx;
          int gap = 0;
          int bx1 = lx;
          while (lx < line.width) {
            if (hasCol[lx] != 0) {
              bx1 = lx;
              gap = 0;
            } else {
              gap++;
              if (gap > wordGapThresh) break;
            }
            lx++;
          }
          final bw = bx1 - bx0 + 1;
          if (bw < 2) continue;
          outBlobs.add(
            OpticalWordBlob(
              x: line.x + bx0,
              y: line.y,
              width: bw,
              height: line.height,
              lineIndex: lineIdx,
              columnIndex: line.columnIndex,
              baselineY: line.baselineY,
              isParagraphStart:
                  outBlobs.length == blobStartIdx ? line.isParagraphStart : false,
              isLineEnd: false,
            ),
          );
        }
        if (outBlobs.length > blobStartIdx) {
          final last = outBlobs.removeLast();
          outBlobs.add(
            OpticalWordBlob(
              x: last.x,
              y: last.y,
              width: last.width,
              height: last.height,
              lineIndex: last.lineIndex,
              columnIndex: last.columnIndex,
              baselineY: last.baselineY,
              isParagraphStart: last.isParagraphStart,
              isLineEnd: true,
            ),
          );
        }
      }
    }

    return (colCount, outLines, outBlobs);
  }
}
