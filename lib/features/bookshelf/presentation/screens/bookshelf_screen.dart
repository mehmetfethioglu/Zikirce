import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../analytics_and_habits/presentation/widgets/completion_seal_dialog.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../providers/bookshelf_provider.dart';
import '../widgets/book_spine_widget.dart';
import '../widgets/streak_header_badge.dart';
import '../widgets/wooden_shelf_widget.dart';

class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  late final TextEditingController _searchController;

  static const List<(String, String)> _filterOptions = [
    ('all', 'Tümü'),
    ('reading', 'Okunuyor'),
    ('completed', 'Tamamlanan'),
    ('pdf', 'PDF'),
    ('epub', 'EPUB'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBookActionsSheet(BuildContext context, BookEntity book) {
    final theme = Theme.of(context);
    final notifier = ref.read(bookshelfProvider.notifier);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                book.author,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('📜', style: TextStyle(fontSize: 22)),
                title: const Text('📜 Okuma Beratını Gör'),
                subtitle: const Text('Eserin tahrir mührünü ve okuma beratını görüntüle'),
                onTap: () {
                  Navigator.pop(ctx);
                  CompletionSealDialog.show(
                    context,
                    bookTitle: book.title,
                    author: book.author,
                    totalPages: book.totalPages > 0 ? book.totalPages : 1,
                    readingMinutes:
                        (book.totalReadingTimeSeconds / 60).round().clamp(1, 99999),
                  );
                },
              ),
              if (!book.isCompleted)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('✅', style: TextStyle(fontSize: 22)),
                  title: const Text('✅ Tamamlandı İşaretle'),
                  subtitle: const Text('Eseri bitirildi olarak işaretle ve mührü kazan'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await notifier.markBookCompleted(book);
                    if (context.mounted) {
                      CompletionSealDialog.show(
                        context,
                        bookTitle: book.title,
                        author: book.author,
                        totalPages: book.totalPages > 0 ? book.totalPages : 1,
                        readingMinutes:
                            (book.totalReadingTimeSeconds / 60).round().clamp(1, 99999),
                      );
                    }
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('🗑️', style: TextStyle(fontSize: 22)),
                title: Text(
                  '🗑️ Kitabı Kaldır',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('Eseri kütüphane rafından kaldır'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (book.id != null) {
                    await notifier.deleteBook(book.id!);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookshelfProvider.select((s) => s));
    final notifier = ref.read(bookshelfProvider.notifier);
    final theme = Theme.of(context);
    final filteredBooks = state.filteredBooks;

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
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(builder: (_) => ReaderScreen(book: newBook)),
                    )
                    .then((_) => notifier.loadBooks());
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
                      todayMinutesRead: state.todayMinutesRead,
                    ),
                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => notifier.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Kütüphanede kitap veya yazar ara...',
                        hintStyle: GoogleFonts.inter(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: state.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const SizedBox(height: 12),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((opt) {
                          final (key, label) = opt;
                          final isSelected = state.selectedFilter == key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (_) => notifier.setFilter(key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Currently Reading Section
                    if (filteredBooks.isNotEmpty) ...[
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
                        book: filteredBooks.first,
                        onOpen: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => ReaderScreen(book: filteredBooks.first),
                                ),
                              )
                              .then((_) => notifier.loadBooks());
                        },
                        onShowOptions: () =>
                            _showBookActionsSheet(context, filteredBooks.first),
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
                      children: filteredBooks.map((book) {
                        return BookSpineWidget(
                          book: book,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
                                )
                                .then((_) => notifier.loadBooks());
                          },
                          onLongPress: () => _showBookActionsSheet(context, book),
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
  final VoidCallback onShowOptions;

  const _CurrentlyReadingCard({
    required this.book,
    required this.onOpen,
    required this.onShowOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: onShowOptions,
      child: Container(
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
              child: const Center(
                child: Text(
                  '📖',
                  style: TextStyle(fontSize: 24),
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
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Eser İşlemleri',
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onShowOptions,
            ),
            IconButton.filled(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

