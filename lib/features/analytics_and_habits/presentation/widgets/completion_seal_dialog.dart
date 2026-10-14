import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';

class CompletionSealDialog extends StatefulWidget {
  final String bookTitle;
  final String author;
  final int totalPages;
  final int readingMinutes;
  final BookEntity? book;

  const CompletionSealDialog({
    super.key,
    required this.bookTitle,
    this.author = 'Tahrir Külliyatı',
    this.totalPages = 100,
    this.readingMinutes = 45,
    this.book,
  });

  static void show(
    BuildContext context, {
    required String bookTitle,
    String author = 'Tahrir Külliyatı',
    int totalPages = 100,
    int readingMinutes = 45,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CompletionSealDialog(
        bookTitle: bookTitle,
        author: author,
        totalPages: totalPages,
        readingMinutes: readingMinutes,
      ),
    );
  }

  @override
  State<CompletionSealDialog> createState() => _CompletionSealDialogState();
}

class _CompletionSealDialogState extends State<CompletionSealDialog> {
  final GlobalKey _sealBoundaryKey = GlobalKey();
  bool _isExporting = false;

  String get _effectiveTitle => widget.book?.title ?? widget.bookTitle;
  String get _effectiveAuthor => widget.book?.author ?? widget.author;
  int get _effectivePages => widget.book?.totalPages ?? widget.totalPages;
  int get _effectiveMinutes => widget.book != null
      ? (widget.book!.totalReadingTimeSeconds / 60).round()
      : widget.readingMinutes;

  Future<void> _exportAndShareSealPng() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundaryContext = _sealBoundaryKey.currentContext;
      final boundary =
          boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Share.share(
          '🎉 "$_effectiveTitle" ($_effectiveAuthor) eserini Tahrir ile tamamladım!\n📜 Tahrir Mühür & Okuma Beratı',
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Berat PNG verisi üretilemedi.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/tahrir_berat_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            '🎉 "$_effectiveTitle" — $_effectiveAuthor eserinin tahrir ve mütalaa yolculuğunu tamamladım!\n📜 Tahrir Mühür & Okuma Beratı',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berat paylaşılırken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd.MM.yyyy').format(DateTime.now());

    return Dialog(
      backgroundColor: AppColors.parchmentBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.amberGold, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sertifika Kartı (RepaintBoundary ile Yüksek Çözünürlüklü PNG Üretimi)
            RepaintBoundary(
              key: _sealBoundaryKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.parchmentBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.amberGold, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Geleneksel Mühür & İcazet Damgası
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.parchmentAccent,
                        border: Border.all(color: AppColors.amberGold, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('📜', style: TextStyle(fontSize: 34)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TAHRİR MÜHÜR & OKUMA BERATI',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.literata(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: AppColors.parchmentAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tebrikler! Bir eserin tahrir, mütalaa ve tedkik yolculuğunu muvaffakiyetle ikmal ettiniz.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.literata(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.parchmentText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.parchmentSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.parchmentBorder),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _effectiveTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.literata(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.parchmentText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '— $_effectiveAuthor',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.parchmentSecondary,
                            ),
                          ),
                          const Divider(
                            height: 20,
                            color: AppColors.parchmentBorder,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '$_effectivePages Sayfa',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.parchmentText,
                                    ),
                                  ),
                                  Text(
                                    'Hacim',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.parchmentSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$_effectiveMinutes Dk',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.parchmentText,
                                    ),
                                  ),
                                  Text(
                                    'Mütalaa Süresi',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.parchmentSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.parchmentText,
                                    ),
                                  ),
                                  Text(
                                    'Ketebe Tarihi',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.parchmentSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.parchmentAccent.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✒️ Ketebe: Tahrir İlim & Mütalaa Meclisi',
                        style: GoogleFonts.literata(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700,
                          color: AppColors.parchmentAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.parchmentAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.image_outlined, size: 16),
                    label: Text(
                      _isExporting
                          ? 'Hazırlanıyor...'
                          : 'Beratı Görsel Olarak Paylaş (PNG)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _isExporting ? null : _exportAndShareSealPng,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
