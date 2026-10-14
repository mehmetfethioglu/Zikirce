import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';

class CompletionSealDialog extends StatelessWidget {
  final BookEntity book;

  const CompletionSealDialog({super.key, required this.book});

  static void show(BuildContext context, BookEntity book) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CompletionSealDialog(book: book),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.parchmentBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.amberGold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seal Graphic
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.parchmentAccent,
                border: Border.all(color: AppColors.amberGold, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Text('📜', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TAHRİR OKUMA BERATI',
              style: GoogleFonts.literata(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.parchmentAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tebrikler! Bir eserin tahrir ve tedkik yolculuğunu muvaffakiyetle tamamladınız.',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 13,
                height: 1.5,
                color: AppColors.parchmentText,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.parchmentSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.parchmentBorder),
              ),
              child: Column(
                children: [
                  Text(
                    book.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.literata(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.parchmentText,
                    ),
                  ),
                  Text(
                    '— ${book.author}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.parchmentSecondary),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('${book.totalPages} Sayfa', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${(book.totalReadingTimeSeconds / 60).round()} Dk Okuma', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Beratı Paylaş'),
                    onPressed: () {
                      Share.share('🎉 "${book.title}" eserini Tahrir ile tamamladım!\n📜 Tahrir Mührü & Okuma Beratı');
                      Navigator.pop(context);
                    },
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
