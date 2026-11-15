import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:zamera_capture/zamera_capture.dart';

import '../widgets/truecolor_spot_meter_badge.dart';

/// Pure helper computing the exact rendered image [Rect] inside [containerSize]
/// under [BoxFit.contain] using [imageWidth]/[imageHeight] or a default `3:4` ratio.
Rect computeContainedImageRect({
  required Size containerSize,
  int? imageWidth,
  int? imageHeight,
}) {
  final cw = containerSize.width;
  final ch = containerSize.height;
  if (cw <= 0.0 || ch <= 0.0) {
    return Rect.zero;
  }

  final aspect =
      (imageWidth != null &&
          imageHeight != null &&
          imageWidth > 0 &&
          imageHeight > 0)
      ? (imageWidth / imageHeight)
      : (3.0 / 4.0);

  final containerAspect = cw / ch;
  if (containerAspect > aspect) {
    final renderH = ch;
    final renderW = ch * aspect;
    final left = (cw - renderW) * 0.5;
    return Rect.fromLTWH(left, 0.0, renderW, renderH);
  } else {
    final renderW = cw;
    final renderH = cw / aspect;
    final top = (ch - renderH) * 0.5;
    return Rect.fromLTWH(0.0, top, renderW, renderH);
  }
}

/// Pure helper mapping a local canvas touch coordinate into a letterbox/pillarbox-free
/// `[0.0, 1.0]` normalized image coordinate within [imageRect].
Offset mapLocalTapToNormalizedImagePoint({
  required Offset localPosition,
  required Rect imageRect,
}) {
  if (imageRect.width <= 0.0 || imageRect.height <= 0.0) {
    return const Offset(0.5, 0.5);
  }
  final nx = ((localPosition.dx - imageRect.left) / imageRect.width).clamp(
    0.0,
    1.0,
  );
  final ny = ((localPosition.dy - imageRect.top) / imageRect.height).clamp(
    0.0,
    1.0,
  );
  return Offset(nx, ny);
}

/// Pure helper mapping a `[0.0, 1.0]` normalized image coordinate back into
/// the exact canvas pixel offset inside [imageRect].
Offset mapNormalizedImagePointToCanvasOffset({
  required Offset focusNorm,
  required Rect imageRect,
}) {
  if (imageRect.width <= 0.0 || imageRect.height <= 0.0) {
    return imageRect.center;
  }
  final dx = imageRect.left + focusNorm.dx.clamp(0.0, 1.0) * imageRect.width;
  final dy = imageRect.top + focusNorm.dy.clamp(0.0, 1.0) * imageRect.height;
  return Offset(dx, dy);
}

/// Immutable colorimeter reading for a tapped pixel in Artwork 1:1 TrueColor mode.
class InspectedPixelMeasurement {
  final Offset normalizedPoint;
  final int pixelX;
  final int pixelY;
  final int r;
  final int g;
  final int b;
  final List<int> displayP3Rgb8;
  final List<double> labD50;
  final ColorCheckerPatch nearestPatch;
  final double deltaE00;
  final String colorSpaceTag;
  final bool isDecodedPixel;

  const InspectedPixelMeasurement({
    required this.normalizedPoint,
    required this.pixelX,
    required this.pixelY,
    required this.r,
    required this.g,
    required this.b,
    required this.displayP3Rgb8,
    required this.labD50,
    required this.nearestPatch,
    required this.deltaE00,
    required this.colorSpaceTag,
    required this.isDecodedPixel,
  });

  String get hexString => TrueColorSpotMeterBadge.formatHex(r, g, b);

  static double _srgbToLinear(int channel8) {
    final c = channel8.clamp(0, 255) / 255.0;
    return c <= 0.04045
        ? (c / 12.92)
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _linearToSrgb8(double lin) {
    final clamped = lin.clamp(0.0, 1.0);
    final enc = clamped <= 0.0031308
        ? (12.92 * clamped)
        : (1.055 * math.pow(clamped, 1.0 / 2.4).toDouble() - 0.055);
    return (enc * 255.0).round().clamp(0, 255);
  }

  /// Converts sRGB 8-bit `(r, g, b)` to Display P3 8-bit `(r, g, b)` via D65 linear gamut transform.
  static List<int> srgb8ToDisplayP3Rgb8(int r, int g, int b) {
    final lr = _srgbToLinear(r);
    final lg = _srgbToLinear(g);
    final lb = _srgbToLinear(b);
    final p3r = 0.8224621 * lr + 0.1775380 * lg + 0.0000000 * lb;
    final p3g = 0.0331941 * lr + 0.9668058 * lg + 0.0000000 * lb;
    final p3b = 0.0170827 * lr + 0.0723974 * lg + 0.9105199 * lb;
    return [_linearToSrgb8(p3r), _linearToSrgb8(p3g), _linearToSrgb8(p3b)];
  }

  factory InspectedPixelMeasurement.fromSrgb8({
    required Offset normalizedPoint,
    required int pixelX,
    required int pixelY,
    required int r,
    required int g,
    required int b,
    required String colorSpaceTag,
    required bool isDecodedPixel,
    List<double>? overrideLabD50,
  }) {
    final lab = (overrideLabD50 != null && overrideLabD50.length >= 3)
        ? overrideLabD50
        : ZameraCapture.srgb8ToLabD50(r, g, b);
    final patch = ZameraCapture.nearestColorCheckerPatch(lab);
    final de00 = ZameraCapture.computeCiede2000(lab, patch.labD50);
    return InspectedPixelMeasurement(
      normalizedPoint: normalizedPoint,
      pixelX: pixelX,
      pixelY: pixelY,
      r: r,
      g: g,
      b: b,
      displayP3Rgb8: srgb8ToDisplayP3Rgb8(r, g, b),
      labD50: lab,
      nearestPatch: patch,
      deltaE00: de00,
      colorSpaceTag: colorSpaceTag,
      isDecodedPixel: isDecodedPixel,
    );
  }
}

/// 64-bin normalized multi-channel RGB + Luminance histogram and clipping ratios.
class RgbHistogramData {
  final List<double> redBins;
  final List<double> greenBins;
  final List<double> blueBins;
  final List<double> lumaBins;
  final double highlightClipRatio;
  final double shadowClipRatio;
  final double meanLuma01;

  const RgbHistogramData({
    required this.redBins,
    required this.greenBins,
    required this.blueBins,
    required this.lumaBins,
    required this.highlightClipRatio,
    required this.shadowClipRatio,
    required this.meanLuma01,
  });

  bool get isEmpty => lumaBins.isEmpty;
}

/// Computes normalized 64-bin R, G, B, and Rec.709 Luminance histograms plus clipping stats
/// in a fast single linear pass (strided when very large).
RgbHistogramData computeRgbaHistogram64(
  Uint8List rgbaBytes,
  int width,
  int height,
) {
  final pixelCount = width * height;
  if (width <= 0 || height <= 0 || rgbaBytes.length < pixelCount * 4) {
    return const RgbHistogramData(
      redBins: [],
      greenBins: [],
      blueBins: [],
      lumaBins: [],
      highlightClipRatio: 0.0,
      shadowClipRatio: 0.0,
      meanLuma01: 0.0,
    );
  }

  final rCounts = List<int>.filled(64, 0);
  final gCounts = List<int>.filled(64, 0);
  final bCounts = List<int>.filled(64, 0);
  final yCounts = List<int>.filled(64, 0);

  final stride = math.max(1, pixelCount ~/ 60000);
  var sampled = 0;
  var highlightClip = 0;
  var shadowClip = 0;
  var lumaSum = 0.0;

  for (var p = 0; p < pixelCount; p += stride) {
    final off = p * 4;
    final a = rgbaBytes[off + 3];
    if (a < 16) continue;
    final r = rgbaBytes[off];
    final g = rgbaBytes[off + 1];
    final b = rgbaBytes[off + 2];
    final y = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);

    rCounts[r >> 2]++;
    gCounts[g >> 2]++;
    bCounts[b >> 2]++;
    yCounts[y >> 2]++;

    lumaSum += y / 255.0;
    if (r >= 252 || g >= 252 || b >= 252) highlightClip++;
    if (r <= 3 && g <= 3 && b <= 3) shadowClip++;
    sampled++;
  }

  if (sampled == 0) {
    return const RgbHistogramData(
      redBins: [],
      greenBins: [],
      blueBins: [],
      lumaBins: [],
      highlightClipRatio: 0.0,
      shadowClipRatio: 0.0,
      meanLuma01: 0.0,
    );
  }

  var maxPeak = 1;
  for (var i = 0; i < 64; i++) {
    if (rCounts[i] > maxPeak) maxPeak = rCounts[i];
    if (gCounts[i] > maxPeak) maxPeak = gCounts[i];
    if (bCounts[i] > maxPeak) maxPeak = bCounts[i];
    if (yCounts[i] > maxPeak) maxPeak = yCounts[i];
  }

  final invPeak = 1.0 / maxPeak;
  return RgbHistogramData(
    redBins: List<double>.generate(64, (i) => (rCounts[i] * invPeak).clamp(0.0, 1.0), growable: false),
    greenBins: List<double>.generate(64, (i) => (gCounts[i] * invPeak).clamp(0.0, 1.0), growable: false),
    blueBins: List<double>.generate(64, (i) => (bCounts[i] * invPeak).clamp(0.0, 1.0), growable: false),
    lumaBins: List<double>.generate(64, (i) => (yCounts[i] * invPeak).clamp(0.0, 1.0), growable: false),
    highlightClipRatio: highlightClip / sampled,
    shadowClipRatio: shadowClip / sampled,
    meanLuma01: (lumaSum / sampled).clamp(0.0, 1.0),
  );
}
