import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import '../constants/camera_colors.dart';
import '../widgets/truecolor_spot_meter_badge.dart';

const List<String> kPortraitLightingNames = [
  'DOĞAL IŞIK',
  'STÜDYO IŞIĞI',
  'KONTUR IŞIK',
  'SAHNE IŞIĞI',
  'SAHNE MONO',
  'HIGH-KEY MONO',
  'PANJUR GÖLGESİ',
  'PANJUR MONO',
  'ALTIN SAAT (3500K)',
  'PRİZMA & SİNEMA',
];

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
    // Linear sRGB (D65) -> Linear Display P3 (D65)
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

/// Modal bottom sheet for:
/// - **Portrait Mode (`isPortrait`)**: Post-capture refocus, `f/1.4..16` bokeh, studio lighting & subject cutout.
/// - **Sanat Modu (`!isPortrait`)**: 1:1 TrueColor vs OEM A/B comparison & `dart:ui` pixel `CIE L*a*b* (D50)` / `ΔE00` inspector.
class CaptureInspectorModal extends StatefulWidget {
  final CapturePhotoResult captureResult;
  final double initialAperture;
  final int initialLightingIndex;
  final double initialLightIntensity;
  final double subjectRadiusRatio;
  final Offset? initialFocusTapNorm;
  final bool? initialPortraitEnabled;
  final bool? isPortraitCapture;

  const CaptureInspectorModal({
    super.key,
    required this.captureResult,
    this.initialAperture = 2.8,
    this.initialLightingIndex = 0,
    this.initialLightIntensity = 0.80,
    this.subjectRadiusRatio = 0.36,
    this.initialFocusTapNorm,
    this.initialPortraitEnabled,
    this.isPortraitCapture,
  });

  static Future<void> show(
    BuildContext context, {
    required CapturePhotoResult captureResult,
    double initialAperture = 2.8,
    int initialLightingIndex = 0,
    double initialLightIntensity = 0.80,
    double subjectRadiusRatio = 0.36,
    Offset? initialFocusTapNorm,
    bool? initialPortraitEnabled,
    bool? isPortraitCapture,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => CaptureInspectorModal(
        captureResult: captureResult,
        initialAperture: initialAperture,
        initialLightingIndex: initialLightingIndex,
        initialLightIntensity: initialLightIntensity,
        subjectRadiusRatio: subjectRadiusRatio,
        initialFocusTapNorm: initialFocusTapNorm,
        initialPortraitEnabled: initialPortraitEnabled,
        isPortraitCapture: isPortraitCapture,
      ),
    );
  }

  @override
  State<CaptureInspectorModal> createState() => _CaptureInspectorModalState();
}

class _CaptureInspectorModalState extends State<CaptureInspectorModal> {
  late bool _isPortrait;
  late double _editAperture;
  late int _editLighting;
  late double _editIntensity;
  late Offset _editFocusNorm;
  late bool _portraitEnabled;
  late String _currentDisplayPath;
  bool _hasDisplayFile = false;
  bool _showingOemComparison = false;
  String? _extractedCutoutPngPath;
  bool _hasCutoutFile = false;
  bool _isReprocessing = false;
  bool _isExtractingCutout = false;
  late String _statusBanner;

  // Decoded RGBA8888 pixel buffer for Sanat Modu 1:1 Colorimeter (`dart:ui`)
  Uint8List? _decodedRgbaBytes;
  int _decodedImgWidth = 0;
  int _decodedImgHeight = 0;
  int _decodeGeneration = 0;
  InspectedPixelMeasurement? _pixelMeasurement;

  bool get _hasOemComparisonAvailable =>
      widget.captureResult.oemJpegPath != null &&
      widget.captureResult.oemJpegPath!.isNotEmpty;

  String get _resolvedColorSpaceTag {
    final String? rawTag = widget.captureResult.colorSpaceTag;
    if (rawTag != null && rawTag.trim().isNotEmpty) {
      return rawTag.trim();
    }
    return 'sRGB';
  }

  @override
  void initState() {
    super.initState();
    _isPortrait =
        widget.isPortraitCapture ??
        widget.initialPortraitEnabled ??
        widget.captureResult.portraitDepthActive;
    _editAperture = widget.initialAperture;
    _editLighting = widget.initialLightingIndex;
    _editIntensity = widget.initialLightIntensity;
    _editFocusNorm =
        widget.initialFocusTapNorm ??
        (_isPortrait ? const Offset(0.5, 0.45) : const Offset(0.5, 0.5));
    _portraitEnabled =
        widget.initialPortraitEnabled ??
        (_isPortrait ? true : widget.captureResult.portraitDepthActive);

    final String initialPath;
    if (_isPortrait) {
      initialPath =
          (!_portraitEnabled &&
              widget.captureResult.oemJpegPath != null &&
              widget.captureResult.oemJpegPath!.isNotEmpty)
          ? widget.captureResult.oemJpegPath!
          : (widget.captureResult.jpegPath ??
                widget.captureResult.oemJpegPath ??
                '');
      _statusBanner =
          'Fotoğrafa dokunarak odak noktasını sonradan değiştirebilir, uzun basarak özneyi kopyalayabilirsiniz.';
    } else {
      initialPath =
          widget.captureResult.jpegPath ??
          widget.captureResult.oemJpegPath ??
          '';
      _statusBanner =
          'Fotoğrafta herhangi bir noktaya dokunarak gerçek piksel CIE L*a*b* (D50), #HEX ve ΔE00 ölçün.';
    }

    _currentDisplayPath = initialPath;
    _hasDisplayFile = initialPath.isNotEmpty && File(initialPath).existsSync();

    if (!_isPortrait) {
      _pixelMeasurement = _buildFallbackMeasurement(_editFocusNorm);
      if (_hasDisplayFile) {
        _decodeArtworkImageBuffer(_currentDisplayPath);
      }
    }
  }

  @override
  void dispose() {
    _decodeGeneration++;
    _decodedRgbaBytes = null;
    super.dispose();
  }

  InspectedPixelMeasurement _buildFallbackMeasurement(Offset normPoint) {
    final mean = widget.captureResult.meanRgb;
    int r = 128;
    int g = 128;
    int b = 128;
    if (mean != null && mean.length >= 3) {
      final scale = (mean[0] <= 1.0 && mean[1] <= 1.0 && mean[2] <= 1.0)
          ? 255.0
          : 1.0;
      r = (mean[0] * scale).round().clamp(0, 255);
      g = (mean[1] * scale).round().clamp(0, 255);
      b = (mean[2] * scale).round().clamp(0, 255);
    }
    final w = widget.captureResult.outputWidth ?? 1;
    final h = widget.captureResult.outputHeight ?? 1;
    return InspectedPixelMeasurement.fromSrgb8(
      normalizedPoint: normPoint,
      pixelX: (normPoint.dx * (w - 1)).round().clamp(0, math.max(0, w - 1)),
      pixelY: (normPoint.dy * (h - 1)).round().clamp(0, math.max(0, h - 1)),
      r: r,
      g: g,
      b: b,
      colorSpaceTag: _showingOemComparison ? 'sRGB (OEM)' : _resolvedColorSpaceTag,
      isDecodedPixel: false,
      overrideLabD50: !_showingOemComparison
          ? widget.captureResult.centerLabD50
          : null,
    );
  }

  Future<void> _decodeArtworkImageBuffer(String filePath) async {
    final gen = ++_decodeGeneration;
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (!mounted || gen != _decodeGeneration) return;

      final codec = await ui.instantiateImageCodec(bytes);
      Uint8List? rgba;
      int imgW = 0;
      int imgH = 0;
      try {
        final frame = await codec.getNextFrame();
        final uiImage = frame.image;
        try {
          imgW = uiImage.width;
          imgH = uiImage.height;
          final byteData = await uiImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (byteData != null) {
            rgba = byteData.buffer.asUint8List(
              byteData.offsetInBytes,
              byteData.lengthInBytes,
            );
          }
        } finally {
          uiImage.dispose();
        }
      } finally {
        codec.dispose();
      }

      if (!mounted || gen != _decodeGeneration || rgba == null) return;
      setState(() {
        _decodedRgbaBytes = rgba;
        _decodedImgWidth = imgW;
        _decodedImgHeight = imgH;
        _pixelMeasurement = _sampleFromDecodedRgba(_editFocusNorm);
      });
    } catch (e) {
      if (!mounted || gen != _decodeGeneration) return;
      setState(() {
        _statusBanner = 'Piksel tamponu okunamadı: $e';
      });
    }
  }

  InspectedPixelMeasurement _sampleFromDecodedRgba(Offset normPoint) {
    final rgba = _decodedRgbaBytes;
    final w = _decodedImgWidth;
    final h = _decodedImgHeight;
    if (rgba == null || w <= 0 || h <= 0) {
      return _buildFallbackMeasurement(normPoint);
    }
    final px = (normPoint.dx.clamp(0.0, 1.0) * (w - 1)).round().clamp(0, w - 1);
    final py = (normPoint.dy.clamp(0.0, 1.0) * (h - 1)).round().clamp(0, h - 1);
    final idx = (py * w + px) * 4;
    if (idx + 3 >= rgba.length) {
      return _buildFallbackMeasurement(normPoint);
    }

    // `ui.ImageByteFormat.rawRgba` is premultiplied RGBA; un-premultiply if alpha < 255
    final a = rgba[idx + 3];
    int r = rgba[idx];
    int g = rgba[idx + 1];
    int b = rgba[idx + 2];
    if (a > 0 && a < 255) {
      r = ((r * 255) / a).round().clamp(0, 255);
      g = ((g * 255) / a).round().clamp(0, 255);
      b = ((b * 255) / a).round().clamp(0, 255);
    }

    return InspectedPixelMeasurement.fromSrgb8(
      normalizedPoint: normPoint,
      pixelX: px,
      pixelY: py,
      r: r,
      g: g,
      b: b,
      colorSpaceTag: _showingOemComparison
          ? 'sRGB (OEM)'
          : _resolvedColorSpaceTag,
      isDecodedPixel: true,
    );
  }

  void _toggleArtworkOemComparison() {
    if (!_hasOemComparisonAvailable) return;
    HapticFeedback.selectionClick();
    final nextShowOem = !_showingOemComparison;
    final nextPath = nextShowOem
        ? widget.captureResult.oemJpegPath!
        : (widget.captureResult.jpegPath ??
              widget.captureResult.oemJpegPath ??
              '');
    final exists = nextPath.isNotEmpty && File(nextPath).existsSync();

    setState(() {
      _showingOemComparison = nextShowOem;
      _currentDisplayPath = nextPath;
      _hasDisplayFile = exists;
      _decodedRgbaBytes = null;
      _pixelMeasurement = _buildFallbackMeasurement(_editFocusNorm);
      _statusBanner = nextShowOem
          ? 'Stok Kamera (OEM) karşılaştırması aktif · gerçek piksel farkını görmek için dokunun.'
          : '1:1 TrueColor görünümü aktif · gerçek piksel CIE L*a*b* (D50) ve ΔE00 ölçülüyor.';
    });

    if (exists) {
      _decodeArtworkImageBuffer(nextPath);
    }
  }

  void _onArtworkPointSelected(Offset mappedNorm) {
    HapticFeedback.selectionClick();
    setState(() {
      _editFocusNorm = mappedNorm;
      _pixelMeasurement = _sampleFromDecodedRgba(mappedNorm);
      final m = _pixelMeasurement!;
      _statusBanner =
          'Piksel (${m.pixelX}, ${m.pixelY}) · ${m.hexString} · L*${m.labD50[0].toStringAsFixed(1)} · ΔE00 ${m.deltaE00.toStringAsFixed(2)}';
    });
  }

  void _togglePortraitEnabled() {
    if (_isReprocessing) return;
    HapticFeedback.selectionClick();
    final nextEnabled = !_portraitEnabled;
    final oemPath = widget.captureResult.oemJpegPath;
    final oemExists =
        oemPath != null && oemPath.isNotEmpty && File(oemPath).existsSync();

    setState(() {
      _portraitEnabled = nextEnabled;
      if (!nextEnabled && oemExists) {
        _currentDisplayPath = oemPath;
        _hasDisplayFile = true;
      }
      _statusBanner = nextEnabled
          ? 'Portre efekti açıldı · ƒ ${_editAperture.toStringAsFixed(1)} bokeh hesaplanıyor...'
          : 'Portre efekti kapatıldı · orijinal optik görünüm aktif.';
    });
    _triggerRefocus();
  }

  Future<void> _triggerRefocus({bool saveToGallery = false}) async {
    final sourcePath =
        widget.captureResult.oemJpegPath ?? widget.captureResult.jpegPath;
    if (sourcePath == null || _isReprocessing) return;

    if (!_portraitEnabled && !saveToGallery) {
      final oemPath = widget.captureResult.oemJpegPath;
      if (oemPath != null && oemPath.isNotEmpty && File(oemPath).existsSync()) {
        setState(() {
          _currentDisplayPath = oemPath;
          _hasDisplayFile = true;
        });
      }
    }

    setState(() {
      _isReprocessing = true;
      _statusBanner = saveToGallery
          ? 'Görüntü galeriye kaydediliyor...'
          : (_portraitEnabled
                ? 'Odak noktası ve ƒ ${_editAperture.toStringAsFixed(1)} bokeh yeniden hesaplanıyor...'
                : 'Portre efekti kapalı görünüm güncelleniyor...');
    });

    try {
      final out = await ZameraCapture.reprocessPortraitPhoto(
        sourceJpegPath: sourcePath,
        aperture: _editAperture,
        lightingMode: _portraitEnabled ? _editLighting : 0,
        lightIntensity: _editIntensity,
        subjectRadiusRatio: widget.subjectRadiusRatio,
        focusX: _editFocusNorm.dx,
        focusY: _editFocusNorm.dy,
        isFrontCamera:
            widget.captureResult.cameraId == '1' ||
            widget.captureResult.cameraId.contains('Front'),
        saveToGallery: saveToGallery,
        portraitEnabled: _portraitEnabled,
      );
      final newPath =
          out['reprocessedJpegPath']?.toString() ?? out['jpegPath']?.toString();
      if (newPath != null && newPath.isNotEmpty && File(newPath).existsSync()) {
        if (!mounted) return;
        setState(() {
          _currentDisplayPath = newPath;
          _hasDisplayFile = true;
          _statusBanner = saveToGallery
              ? 'Görüntü DCIM/Zamera veya Fotoğraflar galerisine kaydedildi!'
              : (_portraitEnabled
                    ? 'Odak (${(_editFocusNorm.dx * 100).round()}%, ${(_editFocusNorm.dy * 100).round()}%) · ƒ ${_editAperture.toStringAsFixed(1)} güncellendi'
                    : 'Portre efekti kapatıldı · orijinal fotoğraf gösteriliyor');
        });
      } else if (!_portraitEnabled && mounted) {
        final fallbackOem = widget.captureResult.oemJpegPath;
        if (fallbackOem != null &&
            fallbackOem.isNotEmpty &&
            File(fallbackOem).existsSync()) {
          setState(() {
            _currentDisplayPath = fallbackOem;
            _hasDisplayFile = true;
          });
        }
        setState(() {
          _statusBanner =
              'Portre efekti kapatıldı · orijinal fotoğraf gösteriliyor';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Yeniden odaklama hatası: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReprocessing = false;
        });
      }
    }
  }

  Future<void> _triggerSubjectCutout({
    bool shareNow = false,
    bool saveToGallery = false,
  }) async {
    final sourcePath =
        widget.captureResult.oemJpegPath ?? widget.captureResult.jpegPath;
    if (sourcePath == null || _isExtractingCutout) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _isExtractingCutout = true;
      _statusBanner =
          'Özne arka plandan ayrılıyor ve şeffaf PNG çıkartılıyor...';
    });

    try {
      final out = await ZameraCapture.extractSubjectCutoutPng(
        sourceJpegPath: sourcePath,
        focusX: _editFocusNorm.dx,
        focusY: _editFocusNorm.dy,
        subjectRadiusRatio: widget.subjectRadiusRatio,
        isFrontCamera:
            widget.captureResult.cameraId == '1' ||
            widget.captureResult.cameraId.contains('Front'),
        shareNow: shareNow,
        saveToGallery: saveToGallery,
      );
      final pngPath =
          out['cutoutPngPath']?.toString() ?? out['pngPath']?.toString();
      if (pngPath != null && pngPath.isNotEmpty && File(pngPath).existsSync()) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _extractedCutoutPngPath = pngPath;
          _hasCutoutFile = true;
          _statusBanner = shareNow
              ? 'Özne ayrıldı, panoya kopyalandı ve paylaşım açıldı'
              : 'Özne ayrıldı ve şeffaf çıkartma olarak panoya kopyalandı';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Özne ayırma hatası: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingCutout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final intensityPercent = (_editIntensity.clamp(0.0, 1.0) * 100.0);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Top Handle & Mode-Aware Title Bar
            Row(
              children: [
                Icon(
                  _isPortrait ? Icons.blur_on_rounded : Icons.palette_outlined,
                  color: _isPortrait ? kIosYellow : kZameraCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPortrait
                        ? 'Portre Odak Düzenleyici & Özne Kopyalama'
                        : 'Sanat Modu — 1:1 Gerçek Renk Denetçisi',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_isPortrait)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kIosYellow.withValues(alpha: 0.20),
                      foregroundColor: kIosYellow,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isReprocessing
                        ? null
                        : () => _triggerRefocus(saveToGallery: true),
                    icon: const Icon(Icons.save_alt_rounded, size: 16),
                    label: const Text(
                      'Kaydet',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _statusBanner,
              style: const TextStyle(
                fontSize: 11,
                color: kZameraCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Photo Canvas with BoxFit.contain True Image Rect Mapping
            LayoutBuilder(
              builder: (context, boxConstraints) {
                final canvasW = boxConstraints.maxWidth;
                const canvasH = 360.0;
                final effW = (_decodedImgWidth > 0)
                    ? _decodedImgWidth
                    : widget.captureResult.outputWidth;
                final effH = (_decodedImgHeight > 0)
                    ? _decodedImgHeight
                    : widget.captureResult.outputHeight;
                final imageRect = computeContainedImageRect(
                  containerSize: Size(canvasW, canvasH),
                  imageWidth: effW,
                  imageHeight: effH,
                );
                final focusCanvasPt = mapNormalizedImagePointToCanvasOffset(
                  focusNorm: _editFocusNorm,
                  imageRect: imageRect,
                );
                final reticleSize = _isPortrait ? 68.0 : 46.0;
                final minReticleLeft = imageRect.left;
                final maxReticleLeft = math.max(
                  minReticleLeft,
                  imageRect.right - reticleSize,
                );
                final minReticleTop = imageRect.top;
                final maxReticleTop = math.max(
                  minReticleTop,
                  imageRect.bottom - reticleSize,
                );
                final reticleLeft = (focusCanvasPt.dx - reticleSize * 0.5)
                    .clamp(minReticleLeft, maxReticleLeft);
                final reticleTop = (focusCanvasPt.dy - reticleSize * 0.5).clamp(
                  minReticleTop,
                  maxReticleTop,
                );

                return Container(
                  width: canvasW,
                  height: canvasH,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_hasDisplayFile)
                        Image.file(
                          File(_currentDisplayPath),
                          key: ValueKey(_currentDisplayPath),
                          fit: BoxFit.contain,
                        ),

                      // Touch & Long-Press Surface Mapped Strictly to Contained Image Rect
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey('inspector_photo_canvas'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final mapped = mapLocalTapToNormalizedImagePoint(
                              localPosition: details.localPosition,
                              imageRect: imageRect,
                            );
                            if (_isPortrait) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _editFocusNorm = mapped;
                                if (!_portraitEnabled) {
                                  _portraitEnabled = true;
                                }
                              });
                              _triggerRefocus();
                            } else {
                              _onArtworkPointSelected(mapped);
                            }
                          },
                          onPanUpdate: _isPortrait
                              ? null
                              : (details) {
                                  final mapped =
                                      mapLocalTapToNormalizedImagePoint(
                                        localPosition: details.localPosition,
                                        imageRect: imageRect,
                                      );
                                  setState(() {
                                    _editFocusNorm = mapped;
                                    _pixelMeasurement = _sampleFromDecodedRgba(
                                      mapped,
                                    );
                                  });
                                },
                          onLongPressStart: (details) {
                            final mapped = mapLocalTapToNormalizedImagePoint(
                              localPosition: details.localPosition,
                              imageRect: imageRect,
                            );
                            setState(() {
                              _editFocusNorm = mapped;
                              if (!_isPortrait) {
                                _pixelMeasurement = _sampleFromDecodedRgba(
                                  mapped,
                                );
                              }
                            });
                          },
                        ),
                      ),

                      // Reticle Anchored to Contained Image Coordinates
                      Positioned(
                        left: reticleLeft,
                        top: reticleTop,
                        child: _isPortrait
                            ? IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: _portraitEnabled ? 1.0 : 0.35,
                                  child: Container(
                                    width: reticleSize,
                                    height: reticleSize,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: kIosYellow,
                                        width: 1.6,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      color: Colors.black87,
                                      child: Text(
                                        _portraitEnabled
                                            ? 'ODAK ƒ ${_editAperture.toStringAsFixed(1)}'
                                            : 'ODAK KAPALI',
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: kIosYellow,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : TrueColorCenterReticle(
                                size: reticleSize,
                                srgb8: _pixelMeasurement != null
                                    ? [
                                        _pixelMeasurement!.r,
                                        _pixelMeasurement!.g,
                                        _pixelMeasurement!.b,
                                      ]
                                    : const [128, 128, 128],
                                isCalibrated: !_showingOemComparison,
                              ),
                      ),

                      // Top-Left Mode Pill: PORTRE On/Off in Portrait vs TrueColor/OEM A/B in Sanat Modu
                      if (_isPortrait)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _PortraitModeTogglePill(
                            enabled: _portraitEnabled,
                            onTap: _togglePortraitEnabled,
                          ),
                        )
                      else if (_hasOemComparisonAvailable)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _TrueColorOemAbTogglePill(
                            showingOem: _showingOemComparison,
                            onTap: _toggleArtworkOemComparison,
                          ),
                        ),

                      if (_isReprocessing || _isExtractingCutout)
                        Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: kIosYellow,
                                strokeWidth: 2.5,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isExtractingCutout
                                    ? 'Özne Çıkartılıyor...'
                                    : 'Odak & Bokeh Hesaplanıyor...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            if (!_isPortrait && _pixelMeasurement != null) ...[
              _ArtworkColorimeterCard(
                measurement: _pixelMeasurement!,
                showingOem: _showingOemComparison,
                hasOemComparison: _hasOemComparisonAvailable,
                onToggleOem: _toggleArtworkOemComparison,
              ),
              const SizedBox(height: 12),
            ],

            // Cutout Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kIosYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isExtractingCutout
                        ? null
                        : () => _triggerSubjectCutout(shareNow: false),
                    icon: const Icon(Icons.content_cut_rounded, size: 17),
                    label: const Text(
                      'Özneyi Seç & Kopyala',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kZameraCyan,
                      side: const BorderSide(color: kZameraCyan),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isExtractingCutout
                        ? null
                        : () => _triggerSubjectCutout(shareNow: true),
                    icon: const Icon(Icons.ios_share_rounded, size: 17),
                    label: const Text(
                      'Çıkartma Paylaş (PNG)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_extractedCutoutPngPath != null && _hasCutoutFile) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF151922),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kIosYellow.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 78,
                        height: 78,
                        color: Colors.black54,
                        child: Image.file(
                          File(_extractedCutoutPngPath!),
                          key: ValueKey(_extractedCutoutPngPath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Özne Çıkartması Hazır (Şeffaf PNG)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: kIosYellow,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Panoya kopyalandı! WhatsApp, iMessage, Telegram veya Notlar içine doğrudan yapıştırabilirsiniz.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isPortrait) ...[
              const SizedBox(height: 14),
              // Post-Capture Aperture Slider (f/1.4..16), Light Intensity Slider (0..100) & Lighting Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141821),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'ÇEKİM SONRASI DİYAFRAM (BOKEH BULANIKLIĞI)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ƒ ${_editAperture.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kIosYellow,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kIosYellow,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: kIosYellow,
                      ),
                      child: Slider(
                        key: const ValueKey('inspector_aperture_slider'),
                        value: _editAperture.clamp(1.4, 16.0),
                        min: 1.4,
                        max: 16.0,
                        onChanged: _portraitEnabled
                            ? (v) {
                                setState(() => _editAperture = v);
                              }
                            : null,
                        onChangeEnd: _portraitEnabled
                            ? (_) => _triggerRefocus()
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'IŞIK ŞİDDETİ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _editLighting > 0
                                  ? Colors.white70
                                  : Colors.white38,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${intensityPercent.round()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _editLighting > 0
                                ? kIosYellow
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kIosYellow,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: kIosYellow,
                        disabledActiveTrackColor: Colors.white12,
                        disabledInactiveTrackColor: Colors.white10,
                        disabledThumbColor: Colors.white24,
                      ),
                      child: Slider(
                        key: const ValueKey('inspector_light_intensity_slider'),
                        value: intensityPercent,
                        min: 0.0,
                        max: 100.0,
                        onChanged: _editLighting > 0
                            ? (v) {
                                setState(
                                  () => _editIntensity = (v / 100.0).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                );
                              }
                            : null,
                        onChangeEnd: _editLighting > 0
                            ? (_) => _triggerRefocus()
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            int i = 0;
                            i < kPortraitLightingNames.length;
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  kPortraitLightingNames[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _editLighting == i
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                                selected: _editLighting == i,
                                selectedColor: kIosYellow,
                                backgroundColor: Colors.black45,
                                onSelected: (_) {
                                  setState(() {
                                    _editLighting = i;
                                    if (!_portraitEnabled && i > 0) {
                                      _portraitEnabled = true;
                                    }
                                  });
                                  _triggerRefocus();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PortraitModeTogglePill extends StatelessWidget {
  const _PortraitModeTogglePill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('inspector_portrait_toggle_pill'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: enabled ? kIosYellow : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? kIosYellow : Colors.white38,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.blur_on_rounded : Icons.blur_off_rounded,
              size: 14,
              color: enabled ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              'PORTRE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: enabled ? Colors.black : Colors.white70,
              ),
            ),
            if (!enabled) ...[
              const SizedBox(width: 4),
              const Text(
                'KAPALI',
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrueColorOemAbTogglePill extends StatelessWidget {
  final bool showingOem;
  final VoidCallback onTap;

  const _TrueColorOemAbTogglePill({
    required this.showingOem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = showingOem ? kIosYellow : kZameraCyan;
    return GestureDetector(
      key: const ValueKey('inspector_ab_oem_toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColor, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_rounded, size: 14, color: activeColor),
            const SizedBox(width: 5),
            Text(
              showingOem ? 'A/B: STOK KAMERA (OEM)' : 'A/B: TRUECOLOR 1:1',
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkColorimeterCard extends StatelessWidget {
  final InspectedPixelMeasurement measurement;
  final bool showingOem;
  final bool hasOemComparison;
  final VoidCallback onToggleOem;

  const _ArtworkColorimeterCard({
    required this.measurement,
    required this.showingOem,
    required this.hasOemComparison,
    required this.onToggleOem,
  });

  static String _signed(double v) =>
      '${v >= 0.0 ? '+' : ''}${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final deColor = m.deltaE00 <= 2.0
        ? const Color(0xFF30D158)
        : (m.deltaE00 <= 4.5 ? kIosYellow : const Color(0xFFFF9F0A));

    return Container(
      key: const ValueKey('inspector_artwork_colorimeter_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kZameraCyan.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, m.r, m.g, m.b),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54, width: 1.0),
                ),
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(m.nearestPatch.previewArgb),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomRight: Radius.circular(7),
                    ),
                    border: Border.all(color: Colors.black54, width: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.hexString,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kZameraCyan.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            m.colorSpaceTag,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: kZameraCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'CIE L*a*b* (D50): L* ${m.labD50[0].toStringAsFixed(2)}  a* ${_signed(m.labD50[1])}  b* ${_signed(m.labD50[2])}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: kIosYellow,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '#HEX Kopyala',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${m.hexString} | L*=${m.labD50[0].toStringAsFixed(2)} a*=${m.labD50[1].toStringAsFixed(2)} b*=${m.labD50[2].toStringAsFixed(2)} | ΔE00=${m.deltaE00.toStringAsFixed(2)}',
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${m.hexString} ve CIE L*a*b* kopyalandı'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'sRGB (${m.r}, ${m.g}, ${m.b})  ·  Display P3 (${m.displayP3Rgb8[0]}, ${m.displayP3Rgb8[1]}, ${m.displayP3Rgb8[2]})',
            style: const TextStyle(
              fontSize: 10.0,
              fontFamily: 'monospace',
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ColorChecker #${m.nearestPatch.index} ${m.nearestPatch.nameTr} · ΔE00 = ${m.deltaE00.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: deColor,
                  ),
                ),
              ),
              if (hasOemComparison)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: showingOem ? kIosYellow : kZameraCyan,
                  ),
                  onPressed: onToggleOem,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: Text(
                    showingOem ? 'TrueColor Göster' : 'Stok (OEM) Göster',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
