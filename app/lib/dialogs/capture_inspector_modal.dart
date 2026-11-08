import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';
import '../constants/camera_colors.dart';

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

/// Modal bottom sheet for post-capture portrait refocus, bokeh adjustment, and sticker lifting.
class CaptureInspectorModal extends StatefulWidget {
  final CapturePhotoResult captureResult;
  final double initialAperture;
  final int initialLightingIndex;
  final double initialLightIntensity;
  final double subjectRadiusRatio;
  final Offset? initialFocusTapNorm;

  const CaptureInspectorModal({
    super.key,
    required this.captureResult,
    this.initialAperture = 2.8,
    this.initialLightingIndex = 0,
    this.initialLightIntensity = 0.80,
    this.subjectRadiusRatio = 0.36,
    this.initialFocusTapNorm,
  });

  static Future<void> show(
    BuildContext context, {
    required CapturePhotoResult captureResult,
    double initialAperture = 2.8,
    int initialLightingIndex = 0,
    double initialLightIntensity = 0.80,
    double subjectRadiusRatio = 0.36,
    Offset? initialFocusTapNorm,
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
      ),
    );
  }

  @override
  State<CaptureInspectorModal> createState() => _CaptureInspectorModalState();
}

class _CaptureInspectorModalState extends State<CaptureInspectorModal> {
  late double _editAperture;
  late int _editLighting;
  late double _editIntensity;
  late Offset _editFocusNorm;
  late String _currentDisplayPath;
  String? _extractedCutoutPngPath;
  bool _isReprocessing = false;
  bool _isExtractingCutout = false;
  String _statusBanner =
      'Fotoğrafa dokunarak odak noktasını sonradan değiştirebilir, uzun basarak özneyi kopyalayabilirsiniz.';

  @override
  void initState() {
    super.initState();
    _editAperture = widget.initialAperture;
    _editLighting = widget.initialLightingIndex;
    _editIntensity = widget.initialLightIntensity;
    _editFocusNorm = widget.initialFocusTapNorm ?? const Offset(0.5, 0.45);
    _currentDisplayPath = widget.captureResult.jpegPath ??
        widget.captureResult.oemJpegPath ??
        '';
  }

  Future<void> _triggerRefocus({bool saveToGallery = false}) async {
    final sourcePath = widget.captureResult.oemJpegPath ??
        widget.captureResult.jpegPath;
    if (sourcePath == null || _isReprocessing) return;

    setState(() {
      _isReprocessing = true;
      _statusBanner = saveToGallery
          ? 'Yeni odak ve diyafram galeriye kaydediliyor...'
          : 'Odak noktası ve f/${_editAperture.toStringAsFixed(1)} bokeh yeniden hesaplanıyor...';
    });

    try {
      final out = await ZameraCapture.reprocessPortraitPhoto(
        sourceJpegPath: sourcePath,
        aperture: _editAperture,
        lightingMode: _editLighting,
        lightIntensity: _editIntensity,
        subjectRadiusRatio: widget.subjectRadiusRatio,
        focusX: _editFocusNorm.dx,
        focusY: _editFocusNorm.dy,
        isFrontCamera: widget.captureResult.cameraId == '1' ||
            widget.captureResult.cameraId.contains('Front'),
        saveToGallery: saveToGallery,
      );
      final newPath = out['reprocessedJpegPath']?.toString() ?? out['jpegPath']?.toString();
      if (newPath != null && File(newPath).existsSync()) {
        setState(() {
          _currentDisplayPath = newPath;
          _statusBanner = saveToGallery
              ? 'Yeni odak & bokeh DCIM/Zamera veya Fotoğraflar galerisine kaydedildi!'
              : 'Odak (${(_editFocusNorm.dx * 100).round()}%, ${(_editFocusNorm.dy * 100).round()}%) · f/${_editAperture.toStringAsFixed(1)} güncellendi';
        });
      }
    } catch (e) {
      setState(() {
        _statusBanner = 'Yeniden odaklama hatası: $e';
      });
    } finally {
      setState(() {
        _isReprocessing = false;
      });
    }
  }

  Future<void> _triggerSubjectCutout({bool shareNow = false}) async {
    final sourcePath = widget.captureResult.oemJpegPath ??
        widget.captureResult.jpegPath;
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
        isFrontCamera: widget.captureResult.cameraId == '1' ||
            widget.captureResult.cameraId.contains('Front'),
        shareNow: shareNow,
      );
      final pngPath = out['cutoutPngPath']?.toString() ?? out['pngPath']?.toString();
      if (pngPath != null && File(pngPath).existsSync()) {
        HapticFeedback.mediumImpact();
        setState(() {
          _extractedCutoutPngPath = pngPath;
          _statusBanner =
              'Özne seçildi, panoya kopyalandı ve galeriye şeffaf PNG olarak kaydedildi!';
        });
      }
    } catch (e) {
      setState(() {
        _statusBanner = 'Özne ayırma hatası: $e';
      });
    } finally {
      setState(() {
        _isExtractingCutout = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayFile = File(_currentDisplayPath);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Top Handle & Title Bar
            Row(
              children: [
                const Icon(
                  Icons.blur_on_rounded,
                  color: kIosYellow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Portre Odak Düzenleyici & Özne Kopyalama',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
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

            // Photo Canvas
            LayoutBuilder(
              builder: (context, boxConstraints) {
                final canvasW = boxConstraints.maxWidth;
                const canvasH = 360.0;
                return GestureDetector(
                  onTapUp: (details) {
                    final nx = (details.localPosition.dx / canvasW)
                        .clamp(0.06, 0.94);
                    final ny = (details.localPosition.dy / canvasH)
                        .clamp(0.06, 0.94);
                    HapticFeedback.selectionClick();
                    setState(() {
                      _editFocusNorm = Offset(nx, ny);
                    });
                    _triggerRefocus();
                  },
                  onLongPressStart: (details) {
                    final nx = (details.localPosition.dx / canvasW)
                        .clamp(0.08, 0.92);
                    final ny = (details.localPosition.dy / canvasH)
                        .clamp(0.08, 0.92);
                    setState(() {
                      _editFocusNorm = Offset(nx, ny);
                    });
                    _triggerSubjectCutout(shareNow: false);
                  },
                  child: Container(
                    width: canvasW,
                    height: canvasH,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white24,
                        width: 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (displayFile.existsSync())
                          Image.file(
                            displayFile,
                            key: ValueKey(_currentDisplayPath),
                            fit: BoxFit.contain,
                          ),

                        // Focus Reticle
                        Positioned(
                          left: (_editFocusNorm.dx * canvasW - 34).clamp(
                            4.0,
                            canvasW - 72.0,
                          ),
                          top: (_editFocusNorm.dy * canvasH - 34).clamp(
                            4.0,
                            canvasH - 72.0,
                          ),
                          child: IgnorePointer(
                            child: Container(
                              width: 68,
                              height: 68,
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
                                  'ODAK f/${_editAperture.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: kIosYellow,
                                  ),
                                ),
                              ),
                            ),
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
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

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
                    icon: const Icon(
                      Icons.content_cut_rounded,
                      size: 17,
                    ),
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

            if (_extractedCutoutPngPath != null &&
                File(_extractedCutoutPngPath!).existsSync()) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF151922),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kIosYellow.withValues(alpha: 0.7),
                  ),
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

            const SizedBox(height: 14),

            // Post-Capture Aperture Slider & Lighting Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const Text(
                        'ÇEKİM SONRASI DİYAFRAM (BOKEH BULANIKLIĞI)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'f/${_editAperture.toStringAsFixed(1)}',
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
                      value: _editAperture.clamp(1.4, 16.0),
                      min: 1.4,
                      max: 16.0,
                      onChanged: (v) {
                        setState(() => _editAperture = v);
                      },
                      onChangeEnd: (_) => _triggerRefocus(),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < kPortraitLightingNames.length; i++)
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
                                setState(() => _editLighting = i);
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
        );
      },
    );
  }
}
