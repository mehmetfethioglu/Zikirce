import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../analytics_and_habits/presentation/widgets/completion_seal_dialog.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../../speed_reading/domain/guided_flow_models.dart';
import '../../../speed_reading/presentation/providers/speed_reading_provider.dart';
import '../../../speed_reading/presentation/widgets/lexical_warmup_sheet.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/tahrir_pro_sheet.dart';
import '../providers/bookshelf_provider.dart';
import '../widgets/book_spine_widget.dart';
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
    ('txt', 'TXT / MD'),
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

  void _openBook(BookEntity book) {
    final notifier = ref.read(bookshelfProvider.notifier);
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
        )
        .then((_) => notifier.loadBooks());
  }

  void _openBookWithWarmup(BookEntity book) {
    final isPro = ref.read(subscriptionProvider).isPro;
    final speedState = ref.read(speedReadingProvider);
    if (!speedState.canStartFreeFasilToday(isPro: isPro)) {
      TahrirProSheet.show(context);
      return;
    }

    final speedNotifier = ref.read(speedReadingProvider.notifier);
    final bookshelfNotifier = ref.read(bookshelfProvider.notifier);
    LexicalWarmupSheet.show(
      context,
      loadPack: () => speedNotifier.prepareBookWarmupPack(book: book),
      preset: FasilDurationPreset.spark5,
      onLaunchFasil: () {
        if (!mounted) return;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  book: book,
                  initialGuidedFasilMinutes: 5,
                ),
              ),
            )
            .then((_) => bookshelfNotifier.loadBooks());
      },
    );
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
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.primary),
                title: const Text('Okuma Beratını Gör'),
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
                  leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                  title: const Text('Tamamlandı İşaretle'),
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
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(
                  'Kitabı Kaldır',
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
    final recentThreeBooks = filteredBooks.take(3).toList();
    final readingBooks = filteredBooks.where((b) => !b.isCompleted).toList();
    final completedBooks = filteredBooks.where((b) => b.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tahrir Kütüphanesi',
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.literata(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () async {
              final newBook = await notifier.importBook();
              if (newBook != null && context.mounted) {
                _openBook(newBook);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Kitap Ekle',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.loadBooks(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Kompakt Arama Çubuğu
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => notifier.setSearchQuery(val),
                      style: GoogleFonts.inter(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Kütüphanede kitap veya yazar ara...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: state.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Kategori Filtre Çipleri
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((opt) {
                          final (key, label) = opt;
                          final isSelected = state.selectedFilter == key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) => notifier.setFilter(key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (filteredBooks.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 48,
                                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bu filtrede eser bulunamadı',
                                style: GoogleFonts.literata(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sağ üstteki "Kitap Ekle" butonuyla PDF, EPUB, TXT veya Markdown eserlerinizi kütüphaneye ekleyebilirsiniz.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // ÜST BÖLÜM: Rafların Üstünde "OKUMAYA DEVAM ET" Kartı
                      Text(
                        'OKUMAYA DEVAM ET',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CurrentlyReadingCard(
                        book: filteredBooks.first,
                        streakDays: state.habitProfile?.currentStreak ?? 0,
                        todayMinutesRead: state.todayMinutesRead,
                        dailyGoalMinutes:
                            state.habitProfile?.dailyGoalMinutes ?? 20,
                        onOpen: () => _openBook(filteredBooks.first),
                        onWarmupAndRead: () =>
                            _openBookWithWarmup(filteredBooks.first),
                        onShowOptions: () =>
                            _showBookActionsSheet(context, filteredBooks.first),
                      ),
                      const SizedBox(height: 18),

                      // 1. RAF: Son Açılan 3 Kitap (Mevcut Ön Kapak Görüntüsü ile)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1. RAF • SON AÇILAN ESERLER',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Son ${recentThreeBooks.length} Kitap',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      WoodenShelfWidget(
                        children: recentThreeBooks.map((book) {
                          return BookSpineWidget(
                            book: book,
                            onTap: () => _openBook(book),
                            onLongPress: () => _showBookActionsSheet(context, book),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 2. RAF: Kütüphane Rafı (Normal Kitaplıklardaki Gibi Dikey Sırt Dizilimi)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '2. RAF • KÜTÜPHANE RAFI (OKUNANLAR)',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${readingBooks.length} Eser',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClassicalSpineShelfWidget(
                        books: readingBooks,
                        onBookTap: _openBook,
                        onBookLongPress: (book) =>
                            _showBookActionsSheet(context, book),
                        emptyMessage:
                            'Okunmakta olan tüm eserler tamamlandı.',
                      ),
                      const SizedBox(height: 20),

                      // 3. RAF: Tamamlanan Kitaplar Rafı (2. Raf Gibi Dikey Sırt Dizilimi)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '3. RAF • TAMAMLANAN KİTAPLAR',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${completedBooks.length} Eser',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClassicalSpineShelfWidget(
                        books: completedBooks,
                        onBookTap: _openBook,
                        onBookLongPress: (book) =>
                            _showBookActionsSheet(context, book),
                        isCompletedShelf: true,
                        emptyMessage:
                            'Bitirdiğiniz eserler 2. raf gibi dikey sırt dizilimiyle bu rafa yerleşir.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _CurrentlyReadingCard extends StatelessWidget {
  final BookEntity book;
  final int streakDays;
  final int todayMinutesRead;
  final int dailyGoalMinutes;
  final VoidCallback onOpen;
  final VoidCallback onWarmupAndRead;
  final VoidCallback onShowOptions;

  const _CurrentlyReadingCard({
    required this.book,
    required this.streakDays,
    required this.todayMinutesRead,
    required this.dailyGoalMinutes,
    required this.onOpen,
    required this.onWarmupAndRead,
    required this.onShowOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPct = (book.progressPercentage * 100).round().clamp(0, 100);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      onLongPress: onShowOptions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.literata(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${book.author} • S. ${book.currentPage}/${book.totalPages > 0 ? book.totalPages : 1} (%$progressPct)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: book.progressPercentage,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Eser İşlemleri',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onShowOptions,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.amberGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.amberGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '🔥 $streakDays Gün • $todayMinutesRead/$dailyGoalMinutes dk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onWarmupAndRead,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '⚡ Isın & Oku',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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



