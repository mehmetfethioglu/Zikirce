import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../domain/content_block.dart';
import '../../services/native_document_restorer.dart';

/// Positioned word rectangle ready for GPU painting from the transparent ink alpha mask.
@immutable
class _WrappedOpticalWord {
  final OpticalWordBlob blob;
  final Rect dstRect;

  const _WrappedOpticalWord({
    required this.blob,
    required this.dstRect,
  });
}

/// K2pdfopt-style word/phrase-wrapped Optical Print Flow (`Baskı Akışı`).
/// Renders each segmented word blob directly at phone viewport width & user font scale,
/// tinting transparent Sauvola ink masks cleanly with the active reader theme's ink color.
class OpticalReflowView extends StatefulWidget {
  final String? alphaMaskPath;
  final Uint8List? inlineMaskBytes;
  final List<OpticalWordBlob> wordBlobs;
  final int imageWidth;
  final int imageHeight;
  final ReaderThemeState themeState;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onSwitchToOriginalPdf;

  const OpticalReflowView({
    super.key,
    required this.alphaMaskPath,
    this.inlineMaskBytes,
    required this.wordBlobs,
    required this.imageWidth,
    required this.imageHeight,
    required this.themeState,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(16, 84, 16, 136),
    this.onSwitchToOriginalPdf,
  });

  @override
  State<OpticalReflowView> createState() => _OpticalReflowViewState();
}

class _OpticalReflowViewState extends State<OpticalReflowView> {
  ui.Image? _maskImage;
  bool _isLoading = true;
  Object? _lastLoadKey;

  @override
  void initState() {
    super.initState();
    _loadMaskImage();
  }

  @override
  void didUpdateWidget(covariant OpticalReflowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = Object.hash(
      widget.alphaMaskPath,
      widget.inlineMaskBytes?.length,
    );
    if (newKey != _lastLoadKey) {
      _loadMaskImage();
    }
  }

  @override
  void dispose() {
    _maskImage?.dispose();
    _maskImage = null;
    super.dispose();
  }

  Future<void> _loadMaskImage() async {
    _lastLoadKey = Object.hash(
      widget.alphaMaskPath,
      widget.inlineMaskBytes?.length,
    );
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      Uint8List? bytes = widget.inlineMaskBytes;
      if ((bytes == null || bytes.isEmpty) &&
          widget.alphaMaskPath != null &&
          widget.alphaMaskPath!.isNotEmpty) {
        final f = File(widget.alphaMaskPath!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        _maskImage?.dispose();
        _maskImage = null;
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        if (!completer.isCompleted) completer.complete(img);
      });
      final decoded = await completer.future;

      if (!mounted) {
        decoded.dispose();
        return;
      }

      final previous = _maskImage;
      setState(() {
        _maskImage = decoded;
        _isLoading = false;
      });
      previous?.dispose();
    } catch (e) {
      debugPrint('OpticalReflowView mask decode error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ({List<_WrappedOpticalWord> words, double totalHeight}) _layoutOpticalWords({
    required double maxWidth,
    required double fontSize,
    required double lineHeightMultiplier,
  }) {
    if (widget.wordBlobs.isEmpty || maxWidth <= 20) {
      return (words: const [], totalHeight: 0.0);
    }

    final heights = widget.wordBlobs
        .map((b) => b.height)
        .where((h) => h > 3)
        .toList()
      ..sort();
    final medianBlobHeight =
        heights.isNotEmpty ? heights[heights.length ~/ 2].toDouble() : 28.0;

    // Normalize line heights cleanly relative to median body line height and user fontSize
    final targetCapHeight = fontSize * 1.18;
    final baseScale = (targetCapHeight / medianBlobHeight).clamp(0.42, 2.4);
    final wordSpace = fontSize * 0.34;
    final paragraphSpacing = fontSize * 0.72;
    final indentWidth = fontSize * 1.1;

    final wrapped = <_WrappedOpticalWord>[];
    double cursorX = 0.0;
    double cursorY = 0.0;
    double currentLineMaxH = targetCapHeight * lineHeightMultiplier;
    final currentLineBuffer = <_WrappedOpticalWord>[];

    void flushLine({bool isParagraphBreak = false}) {
      wrapped.addAll(currentLineBuffer);
      currentLineBuffer.clear();
      cursorX = 0.0;
      cursorY += currentLineMaxH + (isParagraphBreak ? paragraphSpacing : 0.0);
      currentLineMaxH = targetCapHeight * lineHeightMultiplier;
    }

    for (final blob in widget.wordBlobs) {
      if (blob.isParagraphStart && currentLineBuffer.isNotEmpty) {
        flushLine(isParagraphBreak: true);
      }
      if (blob.isParagraphStart && cursorX == 0.0) {
        cursorX = indentWidth;
      }

      final drawW = (blob.width * baseScale).clamp(2.0, maxWidth);
      final drawH = (blob.height * baseScale).clamp(6.0, targetCapHeight * 3.2);

      if (cursorX > 0 && cursorX + drawW > maxWidth && currentLineBuffer.isNotEmpty) {
        flushLine();
      }

      final lineSlotH = drawH * lineHeightMultiplier;
      if (lineSlotH > currentLineMaxH) {
        currentLineMaxH = lineSlotH;
      }

      currentLineBuffer.add(
        _WrappedOpticalWord(
          blob: blob,
          dstRect: Rect.fromLTWH(cursorX, cursorY, drawW, drawH),
        ),
      );
      cursorX += drawW + wordSpace;
    }

    if (currentLineBuffer.isNotEmpty) {
      flushLine();
    }

    return (words: wrapped, totalHeight: cursorY + 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Baskı Akışı (K2pdfopt) hazırlanıyor...',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
      );
    }

    final maskImg = _maskImage;
    if (maskImg == null || widget.wordBlobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Bu sayfa için Baskı Akışı katmanı bulunamadı.',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.onSwitchToOriginalPdf != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onSwitchToOriginalPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Orijinal PDF Görünümüne Geç'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = widget.padding.resolve(Directionality.of(context));
        final contentWidth =
            (constraints.maxWidth - resolvedPadding.horizontal).clamp(80.0, 2000.0);
        final layout = _layoutOpticalWords(
          maxWidth: contentWidth,
          fontSize: widget.themeState.fontSize,
          lineHeightMultiplier: widget.themeState.lineHeight,
        );

        return SingleChildScrollView(
          controller: widget.scrollController,
          physics: const BouncingScrollPhysics(),
          padding: widget.padding,
          child: SizedBox(
            width: contentWidth,
            height: layout.totalHeight,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(contentWidth, layout.totalHeight),
                painter: _OpticalWordMaskPainter(
                  maskImage: maskImg,
                  words: layout.words,
                  inkColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OpticalWordMaskPainter extends CustomPainter {
  final ui.Image maskImage;
  final List<_WrappedOpticalWord> words;
  final Color inkColor;

  const _OpticalWordMaskPainter({
    required this.maskImage,
    required this.words,
    required this.inkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(inkColor, BlendMode.srcIn);

    final imgW = maskImage.width.toDouble();
    final imgH = maskImage.height.toDouble();

    for (final item in words) {
      final b = item.blob;
      final src = Rect.fromLTWH(
        b.x.toDouble().clamp(0.0, imgW - 1),
        b.y.toDouble().clamp(0.0, imgH - 1),
        b.width.toDouble().clamp(1.0, imgW),
        b.height.toDouble().clamp(1.0, imgH),
      );
      canvas.drawImageRect(maskImage, src, item.dstRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OpticalWordMaskPainter oldDelegate) {
    return oldDelegate.maskImage != maskImage ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.words.length != words.length;
  }
}

/// Inline theme-tinted transparent ink block embedded inside Text Reflow for
/// dense Arabic, ornamented titles, or OCR-skipped segments (zero white box).
class OpticalInkBlockWidget extends StatefulWidget {
  final OpticalInkBlock block;

  const OpticalInkBlockWidget({
    super.key,
    required this.block,
  });

  @override
  State<OpticalInkBlockWidget> createState() => _OpticalInkBlockWidgetState();
}

class _OpticalInkBlockWidgetState extends State<OpticalInkBlockWidget> {
  ui.Image? _maskImage;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadMask();
  }

  @override
  void didUpdateWidget(covariant OpticalInkBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.alphaMaskPath != widget.block.alphaMaskPath ||
        oldWidget.block.rawAlphaMaskBytes?.length !=
            widget.block.rawAlphaMaskBytes?.length) {
      _loadMask();
    }
  }

  @override
  void dispose() {
    _maskImage?.dispose();
    _maskImage = null;
    super.dispose();
  }

  Future<void> _loadMask() async {
    try {
      Uint8List? bytes = widget.block.rawAlphaMaskBytes;
      if ((bytes == null || bytes.isEmpty) &&
          widget.block.alphaMaskPath.isNotEmpty) {
        final f = File(widget.block.alphaMaskPath);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        if (!completer.isCompleted) completer.complete(img);
      });
      final decoded = await completer.future;
      if (!mounted) {
        decoded.dispose();
        return;
      }
      final prev = _maskImage;
      setState(() {
        _maskImage = decoded;
        _loaded = true;
      });
      prev?.dispose();
    } catch (e) {
      debugPrint('OpticalInkBlockWidget decode notice: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskImg = _maskImage;
    final crop = widget.block.cropRect;
    final aspect = crop.width > 0 && crop.height > 0
        ? (crop.width / crop.height).clamp(1.0, 14.0)
        : 6.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: maskImg == null
          ? Text(
              widget.block.fallbackText ??
                  (_loaded ? widget.block.title : 'Baskı kesiti yükleniyor...'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            )
          : AspectRatio(
              aspectRatio: aspect,
              child: CustomPaint(
                painter: _SingleCropInkPainter(
                  maskImage: maskImg,
                  cropRect: crop,
                  inkColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
    );
  }
}

class _SingleCropInkPainter extends CustomPainter {
  final ui.Image maskImage;
  final Rect cropRect;
  final Color inkColor;

  const _SingleCropInkPainter({
    required this.maskImage,
    required this.cropRect,
    required this.inkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.mode(inkColor, BlendMode.srcIn);

    final imgW = maskImage.width.toDouble();
    final imgH = maskImage.height.toDouble();
    final src = cropRect.width > 1 && cropRect.height > 1
        ? Rect.fromLTWH(
            cropRect.left.clamp(0.0, imgW - 1),
            cropRect.top.clamp(0.0, imgH - 1),
            cropRect.width.clamp(1.0, imgW),
            cropRect.height.clamp(1.0, imgH),
          )
        : Rect.fromLTWH(0, 0, imgW, imgH);
    canvas.drawImageRect(maskImage, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _SingleCropInkPainter oldDelegate) {
    return oldDelegate.maskImage != maskImage ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.inkColor != inkColor;
  }
}
