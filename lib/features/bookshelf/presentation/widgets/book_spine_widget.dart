import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';
import 'book_cover_generator.dart';

class BookSpineWidget extends StatelessWidget {
  final BookEntity book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookSpineWidget({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomCover =
        book.coverImagePath != null && File(book.coverImagePath!).existsSync();
    final progress = book.progressPercentage.clamp(0.0, 1.0);
    // Fiziksel ayraç kurdelesi okuma yüzdesine göre aşağı doğru uzar (24px -> 108px)
    final ribbonHeight = 24.0 + (progress * 84.0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (hasCustomCover)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(book.coverImagePath!),
                      width: 100,
                      height: 142,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  BookCoverGenerator(
                    title: book.title,
                    author: book.author,
                    width: 100,
                    height: 142,
                  ),

                // Fiziksel Ayraç Kurdelesi (Dynamic Bookmark Ribbon)
                if (progress > 0.01)
                  Positioned(
                    top: -2,
                    left: 14,
                    child: ClipPath(
                      clipper: const _BookmarkRibbonClipper(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 13,
                        height: ribbonHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: book.isCompleted
                                ? const [
                                    AppColors.amberGold,
                                    Color(0xFFB87D14),
                                  ]
                                : const [
                                    AppColors.terracotta,
                                    Color(0xFF993818),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Altın Varak Hatim Mührü veya Format Rozeti
                if (book.isCompleted)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.amberGold, Color(0xFFE5B84B)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 2),
                          Text(
                            'MÜHÜR',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.format.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.black45,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        book.isCompleted
                            ? AppColors.amberGold
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}% • ${book.format.name.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkRibbonClipper extends CustomClipper<Path> {
  const _BookmarkRibbonClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
