import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';

class WoodenShelfWidget extends StatelessWidget {
  final List<Widget> children;

  const WoodenShelfWidget({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <List<Widget>>[];
    for (var i = 0; i < children.length; i += 3) {
      final end = (i + 3 < children.length) ? i + 3 : children.length;
      rows.add(children.sublist(i, end));
    }

    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int c = 0; c < 3; c++)
                  Expanded(
                    child: c < rows[r].length
                        ? rows[r][c]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const WoodenShelfPlank(),
          if (r < rows.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// 2. ve 3. Raflar için geleneksel kütüphane dizilimi:
/// Kitaplar tıpkı gerçek bir kitaplıktaki gibi dikey sırtları yan yana gelecek şekilde ahşap rafa dizilir.
class ClassicalSpineShelfWidget extends StatelessWidget {
  final List<BookEntity> books;
  final void Function(BookEntity book) onBookTap;
  final void Function(BookEntity book)? onBookLongPress;
  final String emptyMessage;
  final bool isCompletedShelf;

  const ClassicalSpineShelfWidget({
    super.key,
    required this.books,
    required this.onBookTap,
    this.onBookLongPress,
    this.emptyMessage = 'Bu rafta henüz eser bulunmuyor.',
    this.isCompletedShelf = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (books.isEmpty) {
      return Column(
        children: [
          Container(
            height: 92,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCompletedShelf
                      ? Icons.workspace_premium_outlined
                      : Icons.menu_book_outlined,
                  size: 22,
                  color: theme.colorScheme.primary.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.literata(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const WoodenShelfPlank(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _BookendSupport(isLeft: true),
                  ...books.map((book) {
                    return VerticalLibrarySpineWidget(
                      book: book,
                      onTap: () => onBookTap(book),
                      onLongPress: onBookLongPress != null
                          ? () => onBookLongPress!(book)
                          : null,
                    );
                  }),
                  const _BookendSupport(isLeft: false),
                ],
              ),
            ),
          ),
        ),
        const WoodenShelfPlank(),
      ],
    );
  }
}

/// Gerçek kitaplıklardaki gibi dikey duran klasik ciltli kitap sırtı (Book Spine).
class VerticalLibrarySpineWidget extends StatelessWidget {
  final BookEntity book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VerticalLibrarySpineWidget({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  static const List<(Color, Color, Color)> _spinePalettes = [
    (Color(0xFF6B1D1D), Color(0xFF3F0E0E), Color(0xFFE5B84B)), // Klasik Bordo
    (Color(0xFF174A36), Color(0xFF0C2B1E), Color(0xFFD9A441)), // Zümrüt Cilt
    (Color(0xFF1C355E), Color(0xFF0E1D36), Color(0xFFE0B454)), // Çini Laciverti
    (Color(0xFF5A381E), Color(0xFF331E0E), Color(0xFFE6BA58)), // Deri Kahve
    (Color(0xFF47255C), Color(0xFF281236), Color(0xFFE2B659)), // Enderun Moru
    (Color(0xFF7A3B1E), Color(0xFF47200D), Color(0xFFF0C665)), // Kiremit Deri
    (Color(0xFF254B59), Color(0xFF132932), Color(0xFFDDB352)), // Petrol Mavisi
    (Color(0xFF3D352B), Color(0xFF211C16), Color(0xFFE5B84B)), // İsli Antrasit
  ];

  @override
  Widget build(BuildContext context) {
    final hash = book.title.hashCode.abs();
    final (baseColor, darkColor, goldAccent) =
        _spinePalettes[hash % _spinePalettes.length];

    final spineWidth = 44.0 + (hash % 10);
    final spineHeight = 140.0 + ((book.totalPages + hash) % 12);
    final progress = book.progressPercentage.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();

    return Tooltip(
      message: '${book.title} — ${book.author} (%$progressPercent)',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: spineWidth,
          height: spineHeight,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(5),
              bottom: Radius.circular(2),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.18, 0.52, 0.85, 1.0],
              colors: [
                darkColor,
                Color.lerp(baseColor, Colors.white, 0.14)!,
                baseColor,
                darkColor,
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(2, 1),
              ),
            ],
            border: Border.all(
              color: goldAccent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 6),
              // Üst altın şiraze şeridi
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: goldAccent.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 2),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: goldAccent.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 6),

              // Dikey Kitap Adı (Aşağıdan yukarıya klasik sırt yazısı)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.literata(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFDF8EE),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),
              // Okuma yüzdesi veya Tamamlandı Mührü
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: book.isCompleted
                    ? Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: goldAccent,
                      )
                    : Text(
                        '%$progressPercent',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: goldAccent,
                        ),
                      ),
              ),
              const SizedBox(height: 5),

              // Alt altın şiraze şeridi
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: goldAccent.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 3),

              // Alt ilerleme çubuğu
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3.5,
                  backgroundColor: Colors.black54,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    book.isCompleted ? AppColors.amberGold : goldAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookendSupport extends StatelessWidget {
  final bool isLeft;

  const _BookendSupport({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 52,
      margin: EdgeInsets.only(
        right: isLeft ? 3 : 0,
        left: isLeft ? 0 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(4),
          bottom: Radius.circular(2),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB88A38),
            Color(0xFF6B4C1B),
          ],
        ),
      ),
    );
  }
}

class WoodenShelfPlank extends StatelessWidget {
  const WoodenShelfPlank({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 12,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5A2B), Color(0xFF654321), Color(0xFF4A2F13)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

