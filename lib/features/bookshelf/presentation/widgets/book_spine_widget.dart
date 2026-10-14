import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                if (hasCustomCover)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(book.coverImagePath!),
                      width: 110,
                      height: 154,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  BookCoverGenerator(
                    title: book.title,
                    author: book.author,
                    width: 110,
                    height: 154,
                  ),
                if (book.isCompleted)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, size: 14, color: Colors.black87),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    child: LinearProgressIndicator(
                      value: book.progressPercentage,
                      minHeight: 4,
                      backgroundColor: Colors.black45,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        book.isCompleted ? Colors.amber : Theme.of(context).colorScheme.primary,
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
              '${(book.progressPercentage * 100).toInt()}% • ${book.format.name.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

