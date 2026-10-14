import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../providers/bookshelf_provider.dart';
import '../widgets/book_spine_widget.dart';
import '../widgets/streak_header_badge.dart';
import '../widgets/wooden_shelf_widget.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookshelfProvider);
    final notifier = ref.read(bookshelfProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('📜 ', style: TextStyle(fontSize: 22)),
            Text(
              'Tahrir Kütüphanesi',
              style: GoogleFonts.literata(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kitap Ekle (PDF/EPUB/MD)',
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () async {
              final newBook = await notifier.importBook();
              if (newBook != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.loadBooks(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak & Today Goal Header
                    StreakHeaderBadge(
                      streakDays: state.habitProfile?.currentStreak ?? 0,
                      dailyMinutesGoal: state.habitProfile?.dailyGoalMinutes ?? 20,
                      todayMinutesRead: 15,
                    ),
                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      onChanged: (val) => notifier.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Kütüphanede kitap veya yazar ara...',
                        hintStyle: GoogleFonts.inter(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Currently Reading Section
                    if (state.filteredBooks.isNotEmpty) ...[
                      Text(
                        'ŞU AN OKUNAN ESER',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CurrentlyReadingCard(
                        book: state.filteredBooks.first,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(book: state.filteredBooks.first),
                            ),
                          ).then((_) => notifier.loadBooks());
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Wooden Bookshelf (Visual Spines)
                    Text(
                      'KİTAPLIK RAFI',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    WoodenShelfWidget(
                      children: state.filteredBooks.map((book) {
                        return BookSpineWidget(
                          book: book,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
                            ).then((_) => notifier.loadBooks());
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CurrentlyReadingCard extends StatelessWidget {
  final BookEntity book;
  final VoidCallback onOpen;

  const _CurrentlyReadingCard({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary),
            ),
            child: Center(
              child: Text(
                '📖',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  book.author,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: book.progressPercentage,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
