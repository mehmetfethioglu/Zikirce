import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../../../core/theme/app_colors.dart';
import '../../domain/reading_mode_hysteresis.dart';
import '../../engine/ocr_proofreader_engine.dart';

/// Magnifier ("Orijinal Tarama Büyüteci / Peek") modal shown when long-pressing
/// an OCR-recognized word in Text Reflow, rendering a crisp 300 DPI crop of the
/// original scanned PDF line alongside confidence & 1-tap correction actions.
class WordPeekSheet extends StatefulWidget {
  final String word;
  final String bookFilePath;
  final int pageNumber;
  final List<OcrWordBox> wordBoxes;
  final OcrCorrectionItem? correction;
  final VoidCallback? onCorrectWord;

  const WordPeekSheet({
    super.key,
    required this.word,
    required this.bookFilePath,
    required this.pageNumber,
    required this.wordBoxes,
    this.correction,
    this.onCorrectWord,
  });

  static Future<void> show(
    BuildContext context, {
    required String word,
    required String bookFilePath,
    required int pageNumber,
    required List<OcrWordBox> wordBoxes,
    OcrCorrectionItem? correction,
    VoidCallback? onCorrectWord,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WordPeekSheet(
        word: word,
        bookFilePath: bookFilePath,
        pageNumber: pageNumber,
        wordBoxes: wordBoxes,
        correction: correction,
        onCorrectWord: onCorrectWord,
      ),
    );
  }

  @override
  State<WordPeekSheet> createState() => _WordPeekSheetState();
}

class _WordPeekSheetState extends State<WordPeekSheet> {
  Uint8List? _croppedScanBytes;
  OcrWordBox? _matchedBox;
  bool _loading = true;
  String? _statusNote;

  @override
  void initState() {
    super.initState();
    _matchedBox = _findBestWordBox(widget.word, widget.wordBoxes);
    _loadOriginalScanCrop();
  }

  static OcrWordBox? _findBestWordBox(
    String targetWord,
    List<OcrWordBox> boxes,
  ) {
    if (boxes.isEmpty) return null;
    final targetLower = OcrProofreaderEngine.toTurkishLower(
      targetWord.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
    );
    if (targetLower.isEmpty) return null;

    for (final box in boxes) {
      final bLower = OcrProofreaderEngine.toTurkishLower(
        box.word.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
      );
      if (bLower == targetLower) return box;
    }
    for (final box in boxes) {
      final bLower = OcrProofreaderEngine.toTurkishLower(box.word);
      if (bLower.contains(targetLower) || targetLower.contains(bLower)) {
        return box;
      }
    }
    return null;
  }

  Future<void> _loadOriginalScanCrop() async {
    if (widget.bookFilePath.isEmpty ||
        widget.bookFilePath.startsWith('sample://') ||
        _matchedBox == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusNote = _matchedBox == null
              ? 'Bu kelime için sayfa koordinat verisi bulunamadı.'
              : 'Örnek eser için orijinal PDF taraması bulunmuyor.';
        });
      }
      return;
    }

    final file = File(widget.bookFilePath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusNote = 'PDF dosyasına erişilemedi.';
        });
      }
      return;
    }

    pdfx.PdfDocument? doc;
    pdfx.PdfPage? page;
    try {
      doc = await pdfx.PdfDocument.openFile(widget.bookFilePath);
      final safePage = widget.pageNumber.clamp(1, doc.pagesCount);
      page = await doc.getPage(safePage);

      const scale = 300.0 / 72.0;
      final rw = (page.width * scale).roundToDouble().clamp(400.0, 2800.0);
      final rh = (page.height * scale).roundToDouble().clamp(400.0, 2800.0);
      final rendered = await page.render(
        width: rw,
        height: rh,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      page = null;
      await doc.close();
      doc = null;

      if (rendered == null || rendered.bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _statusNote = 'Orijinal sayfa görseli oluşturulamadı.';
          });
        }
        return;
      }

      final box = _matchedBox!;
      final cropBytes = await compute(_cropRegionIsolate, (
        pngBytes: rendered.bytes,
        normLeft: box.normalizedLeft,
        normTop: box.normalizedTop,
        normWidth: box.normalizedWidth,
        normHeight: box.normalizedHeight,
      ));

      if (!mounted) return;
      setState(() {
        _croppedScanBytes = cropBytes.isNotEmpty ? cropBytes : null;
        _loading = false;
        if (cropBytes.isEmpty) {
          _statusNote = 'Kesit kırpılamadı.';
        }
      });
    } catch (e) {
      debugPrint('WordPeekSheet crop error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _statusNote = 'Tarama kesiti yüklenemedi.';
        });
      }
    } finally {
      try {
        if (page != null) await page.close();
        if (doc != null) await doc.close();
      } catch (e) {
        debugPrint('WordPeekSheet close warning: $e');
      }
    }
  }

  static Uint8List _cropRegionIsolate(
    ({
      Uint8List pngBytes,
      double normLeft,
      double normTop,
      double normWidth,
      double normHeight,
    }) req,
  ) {
    final decoded = img.decodeImage(req.pngBytes);
    if (decoded == null) return Uint8List(0);

    final padX = decoded.width * 0.14;
    final padY = mathMax(28.0, decoded.height * 0.035);
    final rawX = (req.normLeft * decoded.width - padX).round();
    final rawY = (req.normTop * decoded.height - padY).round();
    final rawR =
        ((req.normLeft + req.normWidth) * decoded.width + padX).round();
    final rawB =
        ((req.normTop + req.normHeight) * decoded.height + padY).round();

    final x = rawX.clamp(0, decoded.width - 1);
    final y = rawY.clamp(0, decoded.height - 1);
    final w = (rawR - x).clamp(1, decoded.width - x);
    final h = (rawB - y).clamp(1, decoded.height - y);

    final cropped = img.copyCrop(decoded, x, y, w, h);
    return Uint8List.fromList(img.encodePng(cropped, level: 5));
  }

  static double mathMax(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confPct = _matchedBox != null
        ? (_matchedBox!.confidence * 100).round().clamp(0, 100)
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.zoom_in_rounded,
                  color: AppColors.amberGold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Orijinal Tarama Büyüteci • "${widget.word}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.literata(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (confPct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (confPct < 75
                              ? Colors.redAccent
                              : const Color(0xFF10B981))
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '%$confPct Güven',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: confPct < 75
                            ? Colors.redAccent
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.correction != null) ...[
              const SizedBox(height: 6),
              Text(
                'Otomatik Tashih: "${widget.correction!.originalWord}" → "${widget.correction!.correctedWord}" (${widget.correction!.ruleCategory})',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              height: 112,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.amberGold.withValues(alpha: 0.45),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : _croppedScanBytes != null
                      ? InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.memory(
                            _croppedScanBytes!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Text(
                          _statusNote ?? 'Orijinal tarama kesiti gösterilemiyor.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
            ),
            const SizedBox(height: 14),
            if (widget.onCorrectWord != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCorrectWord?.call();
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(
                  'Kelimeyi Düzelt',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
