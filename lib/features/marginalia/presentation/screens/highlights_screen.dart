import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../services/qr_p2p_sync_service.dart';
import '../widgets/dictionary_sheet.dart';
import '../widgets/qr_sync_modal.dart';
import '../widgets/quote_studio_sheet.dart';

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key});

  @override
  ConsumerState<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<HighlightEntity> _highlights = [];
  final Map<int, BookEntity> _bookCache = {};
  HighlightCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHighlights() async {
    final highlightRepo = ref.read(highlightRepositoryProvider);
    final bookRepo = ref.read(bookRepositoryProvider);

    final res = await highlightRepo.getAllHighlights();
    final items = res.dataOrNull ?? [];

    // İlgili kitapların gerçek başlık ve yazar bilgilerini önbelleğe al
    final bookIds = items.map((e) => e.bookId).toSet();
    for (final id in bookIds) {
      if (!_bookCache.containsKey(id)) {
        final bookRes = await bookRepo.getBookById(id);
        final book = bookRes.dataOrNull;
        if (book != null) {
          _bookCache[id] = book;
        }
      }
    }

    if (mounted) {
      setState(() {
        _highlights = items;
        _isLoading = false;
      });
    }
  }

  List<HighlightEntity> get _filteredHighlights {
    final q = _searchQuery.trim().toLowerCase();
    return _highlights.where((h) {
      if (_selectedCategory != null && h.category != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      final inText = h.selectedText.toLowerCase().contains(q);
      final inNote = (h.userNote ?? '').toLowerCase().contains(q);
      final bookTitle = (_bookCache[h.bookId]?.title ?? '').toLowerCase();
      return inText || inNote || bookTitle.contains(q);
    }).toList();
  }

  Future<void> _openQuoteStudioForHighlight(HighlightEntity h) async {
    var book = _bookCache[h.bookId];
    if (book == null) {
      final bookRepo = ref.read(bookRepositoryProvider);
      final bookRes = await bookRepo.getBookById(h.bookId);
      book = bookRes.dataOrNull;
      if (book != null) {
        _bookCache[h.bookId] = book;
      }
    }

    if (!mounted) return;
    QuoteStudioSheet.show(
      context,
      quoteText: h.selectedText,
      bookTitle: book?.title ?? 'Tahrir Kitaplığı',
      author: book?.author ?? 'Yazar',
    );
  }

  Future<void> _showEditNoteDialog(HighlightEntity h) async {
    if (h.id == null) return;

    final newNote = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditHighlightNoteDialog(
        initialNote: h.userNote ?? '',
      ),
    );

    if (newNote != null && mounted) {
      final highlightRepo = ref.read(highlightRepositoryProvider);
      await highlightRepo.updateHighlightNote(h.id!, newNote.trim());
      await _loadHighlights();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✍️ Şerh notu güncellendi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightRepo = ref.read(highlightRepositoryProvider);
    final qrService = QrP2pSyncService(highlightRepo);
    final filtered = _filteredHighlights;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Şerh & Not Defteri',
          style: GoogleFonts.literata(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '📖 Klasik Lügat',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => DictionarySheet.show(context),
          ),
          IconButton(
            tooltip: 'Çevrimdışı QR Not Takası',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () async {
              final imported = await QrSyncModal.show(context, qrService);
              if (imported == true && mounted) {
                _loadHighlights();
              }
            },
          ),
          IconButton(
            tooltip: 'Markdown Dışa Aktar (Obsidian/Notion)',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final mdRes = await highlightRepo.exportHighlightsToMarkdown();
              if (mdRes.isSuccess && mdRes.dataOrNull != null) {
                Share.share(mdRes.dataOrNull!, subject: 'Tahrir Şerh Arşivi.md');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Üst Arama ve Kategori Filtre Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.inter(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Şerhlerde, alıntılarda veya kitap adında ara...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        label: 'Tümü',
                        category: null,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: 'Düşünce 💡',
                        category: HighlightCategory.thought,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: 'Alıntı ✨',
                        category: HighlightCategory.quote,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: 'Soru ❓',
                        category: HighlightCategory.question,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        label: 'Eleştiri ⚡',
                        category: HighlightCategory.critical,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Şerh Listesi
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✍️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                _highlights.isEmpty
                                    ? 'Henüz bir şerh veya not kaydedilmedi.'
                                    : 'Arama veya filtreyle eşleşen şerh bulunamadı.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.literata(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Okuma ekranında metni seçip "Şerh Düş" eylemini kullanabilirsiniz.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final h = filtered[index];
                          final book = _bookCache[h.bookId];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          h.category.displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          book != null
                                              ? '${book.title} • Sayfa ${h.pageNumber}'
                                              : 'Sayfa ${h.pageNumber}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '“${h.selectedText}”',
                                    style: GoogleFonts.literata(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (h.userNote != null &&
                                      h.userNote!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✍️ Not: ${h.userNote}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.share, size: 16),
                                        label: const Text('Alıntı Kartı'),
                                        onPressed: () =>
                                            _openQuoteStudioForHighlight(h),
                                      ),
                                      IconButton(
                                        tooltip: 'Notu Düzenle',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => _showEditNoteDialog(h),
                                      ),
                                      IconButton(
                                        tooltip: 'Şerhi Sil',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          if (h.id != null) {
                                            await highlightRepo.deleteHighlight(
                                              h.id!,
                                            );
                                            _loadHighlights();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required HighlightCategory? category,
    required ThemeData theme,
  }) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onSelected: (_) {
        setState(() => _selectedCategory = category);
      },
    );
  }
}

class _EditHighlightNoteDialog extends StatefulWidget {
  final String initialNote;

  const _EditHighlightNoteDialog({required this.initialNote});

  @override
  State<_EditHighlightNoteDialog> createState() =>
      _EditHighlightNoteDialogState();
}

class _EditHighlightNoteDialogState extends State<_EditHighlightNoteDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Şerh Notunu Düzenle',
        style: GoogleFonts.literata(
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: TextField(
        controller: _noteController,
        maxLines: 4,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Kenar notunuzu veya şerhinizi yazın...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_noteController.text),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
