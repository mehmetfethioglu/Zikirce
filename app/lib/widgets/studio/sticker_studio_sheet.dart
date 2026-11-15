import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';

import '../../constants/camera_colors.dart';
import '../../models/media_archive_item.dart';
import '../../painters/checkerboard_and_lift_painter.dart';
import '../../services/zamera_media_archive_store.dart';

/// Modal studio sheet for inspecting, restyling (pure transparent vs white contour),
/// copying, sharing, and archiving extracted transparent PNG stickers.
class StickerStudioSheet extends StatefulWidget {
  final String sourceImagePath;
  final Offset focusNorm;
  final double subjectRadiusRatio;
  final bool isFrontCamera;
  final String? sourceMediaId;
  final MediaArchiveRepository? archiveRepository;
  final ValueChanged<ZameraMediaItem>? onStickerArchived;

  const StickerStudioSheet({
    super.key,
    required this.sourceImagePath,
    required this.focusNorm,
    this.subjectRadiusRatio = 0.36,
    this.isFrontCamera = false,
    this.sourceMediaId,
    this.archiveRepository,
    this.onStickerArchived,
  });

  static Future<void> show(
    BuildContext context, {
    required String sourceImagePath,
    required Offset focusNorm,
    double subjectRadiusRatio = 0.36,
    bool isFrontCamera = false,
    String? sourceMediaId,
    MediaArchiveRepository? archiveRepository,
    ValueChanged<ZameraMediaItem>? onStickerArchived,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1017),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StickerStudioSheet(
        sourceImagePath: sourceImagePath,
        focusNorm: focusNorm,
        subjectRadiusRatio: subjectRadiusRatio,
        isFrontCamera: isFrontCamera,
        sourceMediaId: sourceMediaId,
        archiveRepository: archiveRepository,
        onStickerArchived: onStickerArchived,
      ),
    );
  }

  @override
  State<StickerStudioSheet> createState() => _StickerStudioSheetState();
}

class _StickerStudioSheetState extends State<StickerStudioSheet> {
  bool _whiteOutline = false;
  bool _isExtracting = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _transparentPngPath;
  String? _outlinedPngPath;
  int? _widthPx;
  int? _heightPx;
  String _statusMessage = 'Özne seçiliyor ve şeffaf PNG hazırlanıyor...';

  String? get _activePngPath =>
      _whiteOutline ? _outlinedPngPath : _transparentPngPath;

  @override
  void initState() {
    super.initState();
    _extractCutout(addWhiteOutline: _whiteOutline);
  }

  Future<void> _extractCutout({required bool addWhiteOutline}) async {
    final cached = addWhiteOutline ? _outlinedPngPath : _transparentPngPath;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _whiteOutline = addWhiteOutline;
        _isExtracting = false;
        _errorMessage = null;
        _statusMessage = addWhiteOutline
            ? 'Beyaz konturlu sticker hazır (Şeffaf PNG)'
            : 'Saf şeffaf sticker hazır';
      });
      return;
    }

    setState(() {
      _whiteOutline = addWhiteOutline;
      _isExtracting = true;
      _errorMessage = null;
      _statusMessage = addWhiteOutline
          ? 'Beyaz sticker konturu işleniyor...'
          : 'Özne arka plandan ayrılıyor...';
    });

    try {
      final out = await ZameraCapture.extractSubjectCutoutPng(
        sourceJpegPath: widget.sourceImagePath,
        focusX: widget.focusNorm.dx,
        focusY: widget.focusNorm.dy,
        subjectRadiusRatio: widget.subjectRadiusRatio,
        isFrontCamera: widget.isFrontCamera,
        shareNow: false,
        saveToGallery: false,
        addWhiteOutline: addWhiteOutline,
        copyToClipboard: false,
      );
      if (!mounted) return;
      final pngPath =
          out['cutoutPngPath']?.toString() ?? out['pngPath']?.toString();
      if (pngPath == null || pngPath.isEmpty) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Sticker dosyası oluşturulamadı.';
          _statusMessage = 'Ayrıştırma tamamlanamadı';
        });
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() {
        if (addWhiteOutline) {
          _outlinedPngPath = pngPath;
        } else {
          _transparentPngPath = pngPath;
        }
        _widthPx = (out['width'] as num?)?.toInt() ?? _widthPx;
        _heightPx = (out['height'] as num?)?.toInt() ?? _heightPx;
        _isExtracting = false;
        _errorMessage = null;
        _statusMessage = addWhiteOutline
            ? 'Beyaz konturlu sticker hazır'
            : 'Saf şeffaf sticker hazır';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isNoSubject = e.code == 'NO_SUBJECT' || e.code == 'NO_MASK';
      setState(() {
        _isExtracting = false;
        _errorMessage = isNoSubject
            ? 'Dokunulan noktada belirgin bir nesne seçilemedi. Lütfen nesnenin merkezine dokunun.'
            : (e.message ?? 'Özne ayırma hatası: ${e.code}');
        _statusMessage = 'Özne bulunamadı';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Özne ayırma hatası: $e';
        _statusMessage = 'İşlem başarısız';
      });
    }
  }

  Future<void> _copyToClipboard() async {
    final path = _activePngPath;
    if (path == null || path.isEmpty) return;
    try {
      HapticFeedback.selectionClick();
      final ok = await ZameraCapture.copyPngToClipboard(pngPath: path);
      if (!mounted) return;
      setState(() {
        _statusMessage = ok
            ? 'Şeffaf PNG panoya kopyalandı! İstediğiniz sohbete yapıştırın.'
            : 'Panoya kopyalama desteklenmedi.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Pano hatası: $e';
      });
    }
  }

  Future<void> _shareSticker() async {
    final path = _activePngPath;
    if (path == null || path.isEmpty) return;
    try {
      HapticFeedback.lightImpact();
      await ZameraCapture.shareMediaFiles(
        filePaths: [path],
        mimeType: 'image/png',
        title: 'Zamera Sticker Paylaş',
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Sticker paylaşım menüsü açıldı';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Paylaşım hatası: $e';
      });
    }
  }

  Future<void> _saveToShelfAndGallery() async {
    if (_isExtracting || _isSaving) return;
    setState(() {
      _isSaving = true;
      _statusMessage = 'Sticker rafına ve galeriye kaydediliyor...';
    });
    try {
      final out = await ZameraCapture.extractSubjectCutoutPng(
        sourceJpegPath: widget.sourceImagePath,
        focusX: widget.focusNorm.dx,
        focusY: widget.focusNorm.dy,
        subjectRadiusRatio: widget.subjectRadiusRatio,
        isFrontCamera: widget.isFrontCamera,
        shareNow: false,
        saveToGallery: true,
        addWhiteOutline: _whiteOutline,
        copyToClipboard: false,
      );
      if (!mounted) return;
      final pngPath =
          out['cutoutPngPath']?.toString() ??
          out['pngPath']?.toString() ??
          _activePngPath;
      if (pngPath != null && pngPath.isNotEmpty) {
        final item = ZameraMediaItem.fromStickerCutout(
          pngPath: pngPath,
          mediaStoreUri: out['mediaStoreUri']?.toString(),
          width: (out['width'] as num?)?.toInt() ?? _widthPx,
          height: (out['height'] as num?)?.toInt() ?? _heightPx,
          hasWhiteOutline: _whiteOutline,
          sourceMediaId: widget.sourceMediaId,
        );
        await widget.archiveRepository?.addOrUpdate(item);
        widget.onStickerArchived?.call(item);
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() {
          if (_whiteOutline) {
            _outlinedPngPath = pngPath;
          } else {
            _transparentPngPath = pngPath;
          }
          _isSaving = false;
          _statusMessage = 'Sticker rafına ve galeriye kaydedildi!';
        });
      } else {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Sticker kaydedilemedi';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _statusMessage = 'Kaydetme hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePath = _activePngPath;
    final hasFile =
        activePath != null &&
        activePath.isNotEmpty &&
        File(activePath).existsSync();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: kIosYellow,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sticker Stüdyosu (Şeffaf PNG)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_widthPx != null && _heightPx != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kZameraCyan.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_widthPx×$_heightPx',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: kZameraCyan,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kZameraCyan,
              ),
            ),
            const SizedBox(height: 12),

            // Style Segmented Toggle: Pure Transparent vs White Sticker Border
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF151924),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StyleOptionButton(
                      key: const ValueKey('sticker_style_transparent'),
                      label: 'Saf Şeffaf',
                      icon: Icons.layers_clear_rounded,
                      selected: !_whiteOutline,
                      onTap: _isExtracting
                          ? null
                          : () => _extractCutout(addWhiteOutline: false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StyleOptionButton(
                      key: const ValueKey('sticker_style_outline'),
                      label: 'Beyaz Konturlu Sticker',
                      icon: Icons.border_outer_rounded,
                      selected: _whiteOutline,
                      onTap: _isExtracting
                          ? null
                          : () => _extractCutout(addWhiteOutline: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transparency Checkerboard Preview Canvas
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 250,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(
                      painter: TransparencyCheckerboardPainter(tileSize: 14),
                    ),
                    if (_isExtracting)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: kIosYellow),
                            SizedBox(height: 10),
                            Text(
                              'Özne kesiliyor...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.center_focus_weak_rounded,
                                color: kIosYellow,
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (hasFile)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.file(
                          File(activePath),
                          key: ValueKey('sticker_preview_$activePath'),
                          fit: BoxFit.contain,
                        ),
                      )
                    else if (activePath != null)
                      const Center(
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          color: kZameraCyan,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Primary Action Row: Copy & Share
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('sticker_copy_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kIosYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: (_isExtracting || activePath == null)
                        ? null
                        : _copyToClipboard,
                    icon: const Icon(Icons.content_copy_rounded, size: 17),
                    label: const Text(
                      'Panoya Kopyala',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('sticker_share_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kZameraCyan,
                      side: const BorderSide(color: kZameraCyan),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: (_isExtracting || activePath == null)
                        ? null
                        : _shareSticker,
                    icon: const Icon(Icons.ios_share_rounded, size: 17),
                    label: const Text(
                      'Paylaş (PNG)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('sticker_save_shelf_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: (_isExtracting || _isSaving || _errorMessage != null)
                  ? null
                  : _saveToShelfAndGallery,
              icon: _isSaving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kIosYellow,
                      ),
                    )
                  : const Icon(Icons.bookmark_add_rounded, size: 17),
              label: const Text(
                'Sticker Rafına & Galeriye Kaydet',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _StyleOptionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kIosYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
