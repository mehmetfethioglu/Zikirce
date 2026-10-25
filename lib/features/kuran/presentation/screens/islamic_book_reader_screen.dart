import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/meal_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../data/islamic_book_corpus_service.dart';
import '../../data/islamic_bookshelf_models.dart';
import '../../providers/kuran_providers.dart';
import '../widgets/tahrir_bookshelf_section.dart';

/// Külliyat Kitap Okuyucu (Meâller, 6.236 Âyetlik Tefsirler, Kütüb-i Sitte ve Risale-i Nur Külliyatı)
/// - Tefsir kitaplarında her âyet 1 sayfa (1..6236) olarak gösterilir.
/// - Hadis ve Risale-i Nur kitapları gerçek hacimli SQLite (.db.gz) veritabanından okunur.
/// - Tüm Arapça metinler Kur'ân okuma sayfasındakiyle aynı biçimde (AmasyaAbay + QuranWordHighlighter) render edilir.
/// - Metin seçme, 4 renk vurgulama (Highlight), ayraç (Bookmark) ve Paylaşım Kartı özelliklerini içerir.
class IslamicBookReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const IslamicBookReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  ConsumerState<IslamicBookReaderScreen> createState() =>
      _IslamicBookReaderScreenState();
}

class _IslamicBookReaderScreenState
    extends ConsumerState<IslamicBookReaderScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  bool _isReady = false;
  bool _isDownloadingCorpus = false;
  double _downloadProgress = 0.0;
  String? _downloadError;
  String _selectedText = '';

  final Map<int, QuranPageData> _quranPagesCache = {};
  final Map<int, IslamicBookPageData> _corpusPagesCache = {};

  @override
  void initState() {
    super.initState();
    final books = ref.read(islamicBookshelfProvider);
    final book = books.firstWhere(
      (b) => b.id == widget.bookId,
      orElse: () => books.first,
    );
    _currentPage = book.hasStartedReading
        ? book.currentPage.clamp(1, book.totalPages)
        : 1;
    _pageController = PageController(initialPage: _currentPage - 1);
    _initializeBook(book);
  }

  Future<void> _initializeBook(IslamicShelfBook book) async {
    try {
      await TafseerService.initialize();

      if (book.category == IslamicBookCategory.tafseer) {
        final tafseerService = ref.read(tafseerServiceProvider);
        final isReady = await tafseerService.isDownloaded(book.sourceKey);
        if (!isReady) {
          if (mounted) {
            setState(() {
              _isDownloadingCorpus = true;
              _downloadProgress = 0.05;
              _downloadError = null;
            });
          }
          final ok = await tafseerService.downloadSource(
            book.sourceKey,
            onProgress: (p) {
              if (mounted) {
                setState(() => _downloadProgress = p);
              }
            },
          );
          if (!ok && mounted) {
            setState(() {
              _isDownloadingCorpus = false;
              _downloadError =
                  'Tefsir veritabanı indirilemedi. Lütfen internet bağlantınızı kontrol edin.';
            });
            return;
          }
        }
      } else if (book.category == IslamicBookCategory.hadith ||
          book.category == IslamicBookCategory.risale) {
        final corpusService = ref.read(islamicBookCorpusServiceProvider);
        final isDownloaded =
            await corpusService.isBookDownloaded(book.sourceKey);
        if (!isDownloaded) {
          if (mounted) {
            setState(() {
              _isDownloadingCorpus = true;
              _downloadProgress = 0.05;
              _downloadError = null;
            });
          }
          final ok = await corpusService.downloadBook(
            book.sourceKey,
            onProgress: (p) {
              if (mounted) {
                setState(() => _downloadProgress = p);
              }
            },
          );
          if (!ok && mounted) {
            setState(() {
              _isDownloadingCorpus = false;
              _downloadError =
                  'Eser veritabanı indirilemedi. Lütfen internet bağlantınızı kontrol edin.';
            });
            return;
          }
        }
      }

      await ref.read(islamicBookshelfProvider.notifier).updateBookProgress(
            book.id,
            _currentPage,
          );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isDownloadingCorpus = false;
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  TextStyle _resolveTurkishFont(
    IslamicBookReaderSettings settings, {
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) {
    final sz = fontSize ?? settings.turkishFontSize;
    final h = height ?? settings.lineHeight;
    final c = color ?? settings.textColor;

    switch (settings.fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(
          fontSize: sz,
          fontWeight: fontWeight,
          color: c,
          height: h,
        );
      case 'Crimson Pro':
        return GoogleFonts.crimsonPro(
          fontSize: sz + 1.0,
          fontWeight: fontWeight,
          color: c,
          height: h,
        );
      case 'Plus Jakarta Sans':
        return GoogleFonts.plusJakartaSans(
          fontSize: sz - 0.5,
          fontWeight: fontWeight,
          color: c,
          height: h,
        );
      case 'Merriweather':
      default:
        return GoogleFonts.merriweather(
          fontSize: sz - 0.5,
          fontWeight: fontWeight,
          color: c,
          height: h,
        );
    }
  }

  void _onPageChanged(IslamicShelfBook book, int pageIndex) {
    final pageNo = (pageIndex + 1).clamp(1, book.totalPages);
    setState(() {
      _currentPage = pageNo;
      _selectedText = '';
    });
    ref.read(islamicBookshelfProvider.notifier).updateBookProgress(
          book.id,
          pageNo,
        );
  }

  void _jumpToPage(int pageNumber, int totalPages) {
    final target = pageNumber.clamp(1, totalPages);
    setState(() {
      _currentPage = target;
      _selectedText = '';
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(target - 1);
    }
  }

  String _currentPageReferenceLabel(IslamicShelfBook book, int pageNo) {
    if (book.category == IslamicBookCategory.tafseer) {
      final loc = QuranAyahPageMapper.fromGlobalPage(pageNo);
      return '${book.shortTitle} • ${loc.surahName} Sûresi, ${loc.ayahId}. Âyet';
    }
    final cached = _corpusPagesCache[pageNo];
    if (cached != null && cached.chapterTitle.isNotEmpty) {
      return '${book.shortTitle} • ${cached.chapterTitle} (s. $pageNo)';
    }
    return '${book.shortTitle} • Sayfa $pageNo';
  }

  Future<void> _toggleCurrentPageBookmark(IslamicShelfBook book) async {
    HapticFeedback.mediumImpact();
    String title = _currentPageReferenceLabel(book, _currentPage);
    String snippet = book.subtitle;

    if (book.category == IslamicBookCategory.tafseer) {
      final loc = QuranAyahPageMapper.fromGlobalPage(_currentPage);
      title = '${loc.surahName} Sûresi, ${loc.ayahId}. Âyet';
      snippet = '${book.shortTitle} • Âyet #$_currentPage / 6236';
    } else if (_corpusPagesCache.containsKey(_currentPage)) {
      final p = _corpusPagesCache[_currentPage]!;
      title = p.chapterTitle.isNotEmpty ? p.chapterTitle : 'Sayfa $_currentPage';
      snippet = p.turkishText;
    } else if (book.category == IslamicBookCategory.meal) {
      title = 'Sayfa $_currentPage';
      snippet = '${book.shortTitle} • Mushaf Sayfası $_currentPage';
    }

    final added =
        await ref.read(islamicBookAnnotationsProvider.notifier).toggleBookmark(
              bookId: book.id,
              pageNumber: _currentPage,
              title: title,
              snippet: snippet,
            );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Ayraç eklendi: $title'
              : 'Ayraç kaldırıldı: $title',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addHighlightFromSelection(
    IslamicShelfBook book,
    int colorIndex,
  ) async {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    final refLabel = _currentPageReferenceLabel(book, _currentPage);
    await ref.read(islamicBookAnnotationsProvider.notifier).addHighlight(
          bookId: book.id,
          pageNumber: _currentPage,
          selectedText: text,
          referenceLabel: refLabel,
          colorIndex: colorIndex,
        );
    ContextMenuController.removeAny();
    setState(() => _selectedText = '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seçilen metin vurgulandı ve kaydedildi.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareSelectedPassage({
    required IslamicShelfBook book,
    required String quoteText,
    String? arabicText,
    String? customRef,
  }) {
    final cleaned = quoteText.trim();
    if (cleaned.isEmpty) return;
    HapticFeedback.lightImpact();
    ContextMenuController.removeAny();
    final refLabel =
        customRef ?? _currentPageReferenceLabel(book, _currentPage);
    final arabicFont = ref.read(arabicFontFamilyProvider);

    ZikirSharePreviewModal.show(
      context: context,
      zikirName: refLabel,
      arabicText: arabicText,
      virtue: cleaned,
      customSource: refLabel,
      category: book.category.label,
      currentCount: 0,
      targetCount: 1,
      totalCount: 0,
      arabicFontFamily: arabicFont,
      initialShowCounterStats: false,
    );
  }

  void _openSettingsSheet(IslamicBookReaderSettings settings) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KulliyatManagementAndSettingsSheet(
        isDark: settings.isDarkTheme,
        initialSection: 2,
      ),
    );
  }

  void _openAnnotationsSheet(
    IslamicShelfBook book,
    IslamicBookReaderSettings settings,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookAnnotationsBottomSheet(
        book: book,
        settings: settings,
        onSelectPage: (pageNo) {
          Navigator.of(context).pop();
          _jumpToPage(pageNo, book.totalPages);
        },
        onShareHighlight: (h) {
          Navigator.of(context).pop();
          _shareSelectedPassage(
            book: book,
            quoteText: h.selectedText,
            customRef: h.referenceLabel,
          );
        },
      ),
    );
  }

  void _openTableOfContentsSheet(
    IslamicShelfBook book,
    IslamicBookReaderSettings settings,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookTableOfContentsSheet(
        book: book,
        currentPage: _currentPage,
        settings: settings,
        onSelectPage: (page) {
          Navigator.of(context).pop();
          _jumpToPage(page, book.totalPages);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(islamicBookshelfProvider);
    final book = books.firstWhere(
      (b) => b.id == widget.bookId,
      orElse: () => books.first,
    );
    final settings = ref.watch(islamicBookReaderSettingsProvider);
    final annotations = ref.watch(islamicBookAnnotationsProvider);
    final isBookmarked = annotations.isBookmarked(book.id, _currentPage);
    final bookHighlightsCount =
        annotations.bookmarksForBook(book.id).length +
            annotations.highlightsForBook(book.id).length;

    final bgColor = settings.backgroundColor;
    final textColor = settings.textColor;
    final accentColor = settings.accentColor;
    final subColor = textColor.withValues(alpha: 0.62);

    final progressPct =
        ((_currentPage / book.totalPages) * 100).round().clamp(1, 100);

    String pageCounterSubtitle;
    if (book.category == IslamicBookCategory.tafseer) {
      final loc = QuranAyahPageMapper.fromGlobalPage(_currentPage);
      pageCounterSubtitle =
          '${loc.surahName} ${loc.ayahId}. Âyet • $_currentPage / ${book.totalPages} (%$progressPct)';
    } else {
      pageCounterSubtitle =
          'Sayfa $_currentPage / ${book.totalPages} • %$progressPct Okundu';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 19,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.merriweather(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pageCounterSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        actions: [
          // Ayraç Ekle / Kaldır
          IconButton(
            tooltip: isBookmarked ? 'Ayracı Kaldır' : 'Bu Sayfaya Ayraç Koy',
            onPressed: () => _toggleCurrentPageBookmark(book),
            icon: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isBookmarked ? accentColor : textColor,
              size: 22,
            ),
          ),
          // Ayraçlar ve Vurgulamalar Listesi
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Ayraçlar & Vurgulamalar',
                onPressed: () => _openAnnotationsSheet(book, settings),
                icon: Icon(
                  Icons.collections_bookmark_outlined,
                  color: textColor,
                  size: 20,
                ),
              ),
              if (bookHighlightsCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$bookHighlightsCount',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // İçindekiler / Sûre & Bölüm Seçici
          IconButton(
            tooltip: 'İçindekiler & Bölüm Seç',
            onPressed: () => _openTableOfContentsSheet(book, settings),
            icon: Icon(
              Icons.format_list_bulleted_rounded,
              color: textColor,
              size: 21,
            ),
          ),
          // Kitap İçi Font ve Sayfa Düzeni Ayarları
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openSettingsSheet(settings),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Aa',
                  style: GoogleFonts.merriweather(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Üst İnce İlerleme Çizgisi
          LinearProgressIndicator(
            value: (_currentPage / book.totalPages).clamp(0.0, 1.0),
            minHeight: 2.5,
            backgroundColor: accentColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),

          // Sayfa İçeriği + Seçim Araç Çubuğu
          Expanded(
            child: _isDownloadingCorpus
                ? _buildDownloadProgressView(book, settings)
                : _downloadError != null
                    ? _buildDownloadErrorView(book, settings)
                    : !_isReady
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accentColor,
                            ),
                          )
                        : Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: book.totalPages,
                                onPageChanged: (idx) =>
                                    _onPageChanged(book, idx),
                                itemBuilder: (context, idx) {
                                  final pageNo = idx + 1;
                                  return SelectionArea(
                                    onSelectionChanged: (content) {
                                      final txt =
                                          content?.plainText.trim() ?? '';
                                      if (txt != _selectedText) {
                                        setState(() => _selectedText = txt);
                                      }
                                    },
                                    contextMenuBuilder:
                                        (ctx, selectableRegionState) {
                                      return AdaptiveTextSelectionToolbar
                                          .buttonItems(
                                        anchors: selectableRegionState
                                            .contextMenuAnchors,
                                        buttonItems: [
                                          ...selectableRegionState
                                              .contextMenuButtonItems,
                                          if (_selectedText.trim().isNotEmpty) ...[
                                            ContextMenuButtonItem(
                                              label: 'Vurgula',
                                              onPressed: () =>
                                                  _addHighlightFromSelection(
                                                book,
                                                0,
                                              ),
                                            ),
                                            ContextMenuButtonItem(
                                              label: 'Paylaşım Kartı',
                                              onPressed: () =>
                                                  _shareSelectedPassage(
                                                book: book,
                                                quoteText: _selectedText,
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                    child: _buildPageContentForCategory(
                                      book: book,
                                      pageNo: pageNo,
                                      settings: settings,
                                    ),
                                  );
                                },
                              ),

                              // Metin seçildiğinde altta beliren Vurgulama (4 Renk) ve Paylaşım Kartı Çubuğu
                              if (_selectedText.trim().isNotEmpty)
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 10,
                                  child: _buildSelectionFloatingBar(
                                    book: book,
                                    settings: settings,
                                  ),
                                ),
                            ],
                          ),
          ),

          // Alt Hızlı Sayfa / Âyet Geçiş Barı
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            decoration: BoxDecoration(
              color: settings.cardColor,
              border: Border(
                top: BorderSide(color: accentColor.withValues(alpha: 0.18)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _currentPage > 1
                        ? () => _jumpToPage(_currentPage - 1, book.totalPages)
                        : null,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: _currentPage > 1 ? textColor : subColor,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value:
                            _currentPage.toDouble().clamp(1, book.totalPages.toDouble()),
                        min: 1,
                        max: book.totalPages.toDouble(),
                        activeColor: accentColor,
                        inactiveColor: accentColor.withValues(alpha: 0.2),
                        onChanged: (v) {
                          setState(() => _currentPage = v.round());
                        },
                        onChangeEnd: (v) {
                          _jumpToPage(v.round(), book.totalPages);
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _currentPage < book.totalPages
                        ? () => _jumpToPage(_currentPage + 1, book.totalPages)
                        : null,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: _currentPage < book.totalPages
                          ? textColor
                          : subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Metin seçildiğinde beliren 4 renkli Vurgulama + Paylaşım Kartı + Kopyala çubuğu
  Widget _buildSelectionFloatingBar({
    required IslamicShelfBook book,
    required IslamicBookReaderSettings settings,
  }) {
    final isDark = settings.isDarkTheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF1A2420) : const Color(0xFF231C16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            const Text(
              'Vurgula:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFDF8EE),
              ),
            ),
            const SizedBox(width: 8),
            for (int cIdx = 0; cIdx < 4; cIdx++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _addHighlightFromSelection(book, cIdx),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: BookHighlightItem.badgeColorForIndex(cIdx),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFFD4AF37),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _shareSelectedPassage(
                book: book,
                quoteText: _selectedText,
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 14),
              label: const Text(
                'Paylaş',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Kopyala',
              icon: const Icon(
                Icons.copy_rounded,
                color: Colors.white70,
                size: 17,
              ),
              onPressed: () {
                final refLabel = _currentPageReferenceLabel(book, _currentPage);
                Clipboard.setData(
                  ClipboardData(text: '“$_selectedText”\n— $refLabel'),
                );
                ContextMenuController.removeAny();
                setState(() => _selectedText = '');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seçilen metin panoya kopyalandı.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgressView(
    IslamicShelfBook book,
    IslamicBookReaderSettings settings,
  ) {
    final pct = (_downloadProgress * 100).round().clamp(1, 99);
    final sizeLabel = ref
        .read(islamicBookCorpusServiceProvider)
        .getApproxSizeLabel(book.sourceKey);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: settings.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: settings.accentColor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress > 0.05 ? _downloadProgress : null,
                color: settings.accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                '${book.title} Hazırlanıyor (%$pct)',
                textAlign: TextAlign.center,
                style: _resolveTurkishFont(
                  settings,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tam hacimli eser veritabanı ($sizeLabel) çevrimdışı okuma için indiriliyor…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: settings.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadErrorView(
    IslamicShelfBook book,
    IslamicBookReaderSettings settings,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: settings.accentColor,
            ),
            const SizedBox(height: 12),
            Text(
              _downloadError ?? 'Eser yüklenemedi.',
              textAlign: TextAlign.center,
              style: _resolveTurkishFont(settings, fontSize: 14),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: settings.accentColor,
              ),
              onPressed: () => _initializeBook(book),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  /// Kur'ân okuma sayfasındakiyle birebir aynı kusursuz Arapça metin oluşturucu
  Widget _buildUnifiedArabicText({
    required String rawArabic,
    required IslamicBookReaderSettings settings,
    String? ayahNumber,
    bool showStopMarker = false,
    TextAlign textAlign = TextAlign.right,
  }) {
    final arabicFont = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final highlightDivine = ref.watch(highlightDivineWordsProvider);

    return Text.rich(
      TextSpan(
        children: QuranWordHighlighter.buildHighlightedSpans(
          rawText: rawArabic,
          baseStyle: TextStyle(
            fontFamily: arabicFont,
            fontSize: settings.arabicFontSize,
            fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
            color: settings.textColor,
            height: 2.0,
          ),
          isDark: settings.isDarkTheme,
          enabled: highlightDivine,
          fontFamily: arabicFont,
          isBold: isBoldArabic,
          ayahNumber: ayahNumber,
          showAyahStopMarker: showStopMarker,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
    );
  }

  /// Sayfadaki kayıtlı vurgulamaları (Highlights) metin içinde renkli olarak işaretler
  TextSpan _buildTextSpanWithHighlights({
    required String text,
    required TextStyle baseStyle,
    required List<BookHighlightItem> pageHighlights,
    required bool isDark,
  }) {
    if (pageHighlights.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // En uzun eşleşmeden başlayarak vurgulamaları uygula
    String remaining = text;
    final spans = <InlineSpan>[];

    while (remaining.isNotEmpty) {
      int earliestIndex = -1;
      BookHighlightItem? matchedHighlight;

      for (final h in pageHighlights) {
        final needle = h.selectedText.trim();
        if (needle.length < 3) continue;
        final idx = remaining.indexOf(needle);
        if (idx != -1 && (earliestIndex == -1 || idx < earliestIndex)) {
          earliestIndex = idx;
          matchedHighlight = h;
        }
      }

      if (earliestIndex == -1 || matchedHighlight == null) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
        break;
      }

      if (earliestIndex > 0) {
        spans.add(
          TextSpan(
            text: remaining.substring(0, earliestIndex),
            style: baseStyle,
          ),
        );
      }

      final needleLen = matchedHighlight.selectedText.trim().length;
      final highlightedChunk =
          remaining.substring(earliestIndex, earliestIndex + needleLen);
      spans.add(
        TextSpan(
          text: highlightedChunk,
          style: baseStyle.copyWith(
            backgroundColor: BookHighlightItem.colorForIndex(
              matchedHighlight.colorIndex,
              isDark: isDark,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      remaining = remaining.substring(earliestIndex + needleLen);
    }

    return TextSpan(children: spans);
  }

  Widget _buildPageHighlightsFooter({
    required String bookId,
    required int pageNo,
    required IslamicBookReaderSettings settings,
    required IslamicShelfBook book,
  }) {
    final pageHighlights = ref
        .watch(islamicBookAnnotationsProvider)
        .highlightsForPage(bookId, pageNo);
    if (pageHighlights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: settings.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: settings.accentColor.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.border_color_rounded,
                  size: 14,
                  color: settings.accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bu Sayfadaki Vurgulamalarınız (${pageHighlights.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: settings.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pageHighlights.map((h) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BookHighlightItem.colorForIndex(
                      h.colorIndex,
                      isDark: settings.isDarkTheme,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '“${h.selectedText}”',
                          style: _resolveTurkishFont(
                            settings,
                            fontSize: settings.turkishFontSize - 2.0,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Paylaş',
                        icon: Icon(
                          Icons.ios_share_rounded,
                          size: 16,
                          color: settings.textColor,
                        ),
                        onPressed: () => _shareSelectedPassage(
                          book: book,
                          quoteText: h.selectedText,
                          customRef: h.referenceLabel,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sil',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: settings.textColor.withValues(alpha: 0.65),
                        ),
                        onPressed: () => ref
                            .read(islamicBookAnnotationsProvider.notifier)
                            .removeHighlight(h.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContentForCategory({
    required IslamicShelfBook book,
    required int pageNo,
    required IslamicBookReaderSettings settings,
  }) {
    switch (book.category) {
      case IslamicBookCategory.tafseer:
        return _buildSingleAyahTafseerPage(
          book: book,
          globalAyahPage: pageNo,
          settings: settings,
        );
      case IslamicBookCategory.hadith:
      case IslamicBookCategory.risale:
        return _buildCorpusSqlitePage(
          book: book,
          pageNo: pageNo,
          settings: settings,
        );
      case IslamicBookCategory.meal:
      case IslamicBookCategory.quran:
        return _buildQuranMealPage(
          book: book,
          pageNo: pageNo,
          settings: settings,
        );
    }
  }

  /// TEFSİR KİTAPLARI: Her âyet 1 sayfa (1..6236) olarak gösterilir
  Widget _buildSingleAyahTafseerPage({
    required IslamicShelfBook book,
    required int globalAyahPage,
    required IslamicBookReaderSettings settings,
  }) {
    final loc = QuranAyahPageMapper.fromGlobalPage(globalAyahPage);
    final pageHighlights = ref
        .watch(islamicBookAnnotationsProvider)
        .highlightsForPage(book.id, globalAyahPage);

    final Future<(QuranAyatModel?, String, TafseerEntryResult?)> future =
        _loadSingleAyahAndTafseer(book.sourceKey, loc);

    return FutureBuilder<(QuranAyatModel?, String, TafseerEntryResult?)>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: settings.accentColor),
          );
        }

        final ayat = snapshot.data!.$1;
        final fallbackMeal = snapshot.data!.$2;
        final tafseer = snapshot.data!.$3;
        final rawArabic = ayat?.ayetText ?? '';
        final mealText =
            tafseer?.mealText.isNotEmpty == true ? tafseer!.mealText : fallbackMeal;
        final tefsirBody = tafseer?.tefsirText ?? '';

        return ListView(
          padding: EdgeInsets.fromLTRB(
            settings.horizontalMargin,
            16,
            settings.horizontalMargin,
            40,
          ),
          children: [
            // Sûre ve Âyet Başlık Kartı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: settings.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: settings.accentColor.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.surahName} Sûresi • ${loc.ayahId}. Âyet',
                          style: GoogleFonts.merriweather(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: settings.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${book.title} • Âyet #$globalAyahPage / 6236',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: settings.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loc.surahArabicName.isNotEmpty)
                    Text(
                      QuranWordHighlighter.formatArabicTextForFont(
                        loc.surahArabicName,
                        ref.watch(arabicFontFamilyProvider),
                      ),
                      style: TextStyle(
                        fontFamily: ref.watch(arabicFontFamilyProvider),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: settings.accentColor,
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Bu Âyeti Paylaş',
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: settings.accentColor,
                    ),
                    onPressed: () => _shareSelectedPassage(
                      book: book,
                      quoteText: mealText.isNotEmpty ? mealText : tefsirBody,
                      arabicText: rawArabic,
                      customRef:
                          '${loc.surahName} Sûresi, ${loc.ayahId}. Âyet • ${book.shortTitle}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Âyetin Kur'ân Hattı ve Meâli
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: settings.cardColor.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: settings.accentColor.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (settings.showArabicText && rawArabic.isNotEmpty) ...[
                    _buildUnifiedArabicText(
                      rawArabic: rawArabic,
                      settings: settings,
                      ayahNumber: loc.ayahId.toString(),
                      showStopMarker: true,
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: settings.accentColor.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (mealText.isNotEmpty)
                    Text.rich(
                      _buildTextSpanWithHighlights(
                        text: mealText,
                        baseStyle: _resolveTurkishFont(
                          settings,
                          fontWeight: FontWeight.w600,
                        ),
                        pageHighlights: pageHighlights,
                        isDark: settings.isDarkTheme,
                      ),
                      textAlign: settings.justifyText
                          ? TextAlign.justify
                          : TextAlign.left,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Tam Metin Tefsir İzahı
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: settings.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tafseer != null && tafseer.isVerseRange
                        ? '${book.shortTitle} (${tafseer.rangeLabel} Tefsiri)'
                        : '${book.shortTitle} İzahı',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: settings.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              _buildTextSpanWithHighlights(
                text: tefsirBody.isNotEmpty
                    ? tefsirBody
                    : 'Bu âyet-i kerîmenin tefsiri bir önceki âyet grubu bütünlüğü içinde beyan edilmiştir.',
                baseStyle: _resolveTurkishFont(settings),
                pageHighlights: pageHighlights,
                isDark: settings.isDarkTheme,
              ),
              textAlign:
                  settings.justifyText ? TextAlign.justify : TextAlign.left,
            ),

            _buildPageHighlightsFooter(
              bookId: book.id,
              pageNo: globalAyahPage,
              settings: settings,
              book: book,
            ),
          ],
        );
      },
    );
  }

  Future<(QuranAyatModel?, String, TafseerEntryResult?)> _loadSingleAyahAndTafseer(
    String sourceKey,
    QuranGlobalAyahLocation loc,
  ) async {
    QuranAyatModel? foundAyat;
    String foundMeal = '';
    for (int p = loc.mushafStartPage; p <= 604; p++) {
      final pageContent =
          _quranPagesCache[p] ?? await QuranPageRepository.getPage(p);
      _quranPagesCache[p] = pageContent;
      for (final a in pageContent.quranAyats) {
        if (a.sureId == loc.surahId && a.ayetId == loc.ayahId) {
          foundAyat = a;
          break;
        }
      }
      for (final m in pageContent.mealAyats) {
        if (m.sureId == loc.surahId && m.ayetId == loc.ayahId) {
          foundMeal = m.ayetText;
          break;
        }
      }
      if (foundAyat != null) break;
      if (pageContent.quranAyats.isNotEmpty &&
          pageContent.quranAyats.first.sureId > loc.surahId) {
        break;
      }
    }

    final tafseer = await ref.read(tafseerServiceProvider).getTafseerEntry(
          loc.surahId,
          loc.ayahId,
          loc.surahName,
          sourceId: sourceKey,
        );
    return (foundAyat, foundMeal, tafseer);
  }

  /// HADİS (Kütüb-i Sitte / Riyâzü's-Sâlihîn) ve RİSALE-İ NUR KÜLLİYATI Tam Hacim SQLite Sayfası
  Widget _buildCorpusSqlitePage({
    required IslamicShelfBook book,
    required int pageNo,
    required IslamicBookReaderSettings settings,
  }) {
    final pageHighlights = ref
        .watch(islamicBookAnnotationsProvider)
        .highlightsForPage(book.id, pageNo);

    return FutureBuilder<IslamicBookPageData?>(
      future: _loadCorpusPage(book.sourceKey, pageNo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: settings.accentColor),
          );
        }
        final page = snapshot.data!;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            settings.horizontalMargin,
            16,
            settings.horizontalMargin,
            40,
          ),
          children: [
            // Bölüm / Bab / Risale Başlık Kartı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: settings.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: settings.accentColor.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (page.subtitle.isNotEmpty)
                          Text(
                            page.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: settings.accentColor,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          page.chapterTitle,
                          style: _resolveTurkishFont(
                            settings,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Paylaşım Kartı Oluştur',
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: settings.accentColor,
                    ),
                    onPressed: () => _shareSelectedPassage(
                      book: book,
                      quoteText: page.turkishText,
                      arabicText:
                          page.arabicText.isNotEmpty ? page.arabicText : null,
                      customRef: page.reference.isNotEmpty
                          ? page.reference
                          : '${book.shortTitle} • ${page.chapterTitle}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Varsa Arapça Hadis Metni veya Risale Serlevhası (Kur'ân sayfası hattıyla kusursuz render)
            if (settings.showArabicText && page.arabicText.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: settings.cardColor.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: settings.accentColor.withValues(alpha: 0.20),
                  ),
                ),
                child: _buildUnifiedArabicText(
                  rawArabic: page.arabicText,
                  settings: settings,
                  textAlign: book.category == IslamicBookCategory.risale
                      ? TextAlign.center
                      : TextAlign.right,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Türkçe Tam Metin (Seçilebilir ve Vurgulanabilir)
            Text.rich(
              _buildTextSpanWithHighlights(
                text: page.turkishText,
                baseStyle: _resolveTurkishFont(settings),
                pageHighlights: pageHighlights,
                isDark: settings.isDarkTheme,
              ),
              textAlign:
                  settings.justifyText ? TextAlign.justify : TextAlign.left,
            ),

            if (page.reference.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Kaynak: ${page.reference}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: settings.textColor.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],

            _buildPageHighlightsFooter(
              bookId: book.id,
              pageNo: pageNo,
              settings: settings,
              book: book,
            ),
          ],
        );
      },
    );
  }

  Future<IslamicBookPageData?> _loadCorpusPage(
    String sourceKey,
    int pageNo,
  ) async {
    if (_corpusPagesCache.containsKey(pageNo)) {
      return _corpusPagesCache[pageNo];
    }
    final data = await ref
        .read(islamicBookCorpusServiceProvider)
        .getPage(sourceKey, pageNo);
    if (data != null) {
      _corpusPagesCache[pageNo] = data;
    }
    return data;
  }

  /// MEÂL KİTAPLARI (604 Sayfa)
  Widget _buildQuranMealPage({
    required IslamicShelfBook book,
    required int pageNo,
    required IslamicBookReaderSettings settings,
  }) {
    final pageHighlights = ref
        .watch(islamicBookAnnotationsProvider)
        .highlightsForPage(book.id, pageNo);

    return FutureBuilder<(QuranPageData, Map<String, String>)>(
      future: _loadQuranMealPageData(pageNo, book.sourceKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: settings.accentColor),
          );
        }
        final pageContent = snapshot.data!.$1;
        final resolvedMeals = snapshot.data!.$2;
        final ayats = pageContent.quranAyats;
        if (ayats.isEmpty) {
          return const Center(child: Text('Sayfa verisi bulunamadı.'));
        }

        final firstSurahName =
            ayats.first.sure?.sureNameTurkish ?? 'Sûre ${ayats.first.sureId}';

        return ListView(
          padding: EdgeInsets.fromLTRB(
            settings.horizontalMargin,
            16,
            settings.horizontalMargin,
            40,
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: settings.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: settings.accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$firstSurahName Sûresi',
                    style: GoogleFonts.merriweather(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: settings.textColor,
                    ),
                  ),
                  Text(
                    '${pageContent.cuzNo}. Cüz • Sayfa $pageNo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: settings.accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ...ayats.map((ayat) {
              final surahName =
                  ayat.sure?.sureNameTurkish ?? 'Sûre ${ayat.sureId}';
              final mealText =
                  resolvedMeals['${ayat.sureId}:${ayat.ayetId}'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: EdgeInsets.all(settings.isFlowingBookLayout ? 4 : 14),
                  decoration: settings.isFlowingBookLayout
                      ? null
                      : BoxDecoration(
                          color: settings.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: settings.accentColor.withValues(alpha: 0.20),
                          ),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (settings.showArabicText &&
                          ayat.ayetText.trim().isNotEmpty) ...[
                        _buildUnifiedArabicText(
                          rawArabic: ayat.ayetText,
                          settings: settings,
                          ayahNumber: ayat.ayetId.toString(),
                          showStopMarker: true,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '[${ayat.ayetId}] ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: settings.turkishFontSize - 1.5,
                                fontWeight: FontWeight.w800,
                                color: settings.accentColor,
                              ),
                            ),
                            _buildTextSpanWithHighlights(
                              text: mealText,
                              baseStyle: _resolveTurkishFont(settings),
                              pageHighlights: pageHighlights,
                              isDark: settings.isDarkTheme,
                            ),
                          ],
                        ),
                        textAlign: settings.justifyText
                            ? TextAlign.justify
                            : TextAlign.left,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Âyeti Paylaş',
                          icon: Icon(
                            Icons.ios_share_rounded,
                            size: 15,
                            color: settings.accentColor.withValues(alpha: 0.75),
                          ),
                          onPressed: () => _shareSelectedPassage(
                            book: book,
                            quoteText: mealText,
                            arabicText: ayat.ayetText,
                            customRef:
                                '$surahName Sûresi, ${ayat.ayetId}. Âyet • ${book.shortTitle}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            _buildPageHighlightsFooter(
              bookId: book.id,
              pageNo: pageNo,
              settings: settings,
              book: book,
            ),
          ],
        );
      },
    );
  }

  Future<(QuranPageData, Map<String, String>)> _loadQuranMealPageData(
    int pageNo,
    String sourceKey,
  ) async {
    final content =
        _quranPagesCache[pageNo] ?? await QuranPageRepository.getPage(pageNo);
    _quranPagesCache[pageNo] = content;

    final defaultMeals = <String, String>{};
    for (final m in content.mealAyats) {
      defaultMeals['${m.sureId}:${m.ayetId}'] = m.ayetText;
    }

    final mealService = ref.read(mealServiceProvider);
    final resolved = <String, String>{};
    for (final a in content.quranAyats) {
      final key = '${a.sureId}:${a.ayetId}';
      resolved[key] = await mealService.getVerseMeal(
        a.sureId,
        a.ayetId,
        sourceId: sourceKey,
        fallbackDiyanetText: defaultMeals[key] ?? '',
      );
    }
    return (content, resolved);
  }
}

/// Kitap Ayraçlar (Bookmarks) ve Vurgulamalar (Highlights) Alt Çekmecesi
class _BookAnnotationsBottomSheet extends ConsumerStatefulWidget {
  final IslamicShelfBook book;
  final IslamicBookReaderSettings settings;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<BookHighlightItem> onShareHighlight;

  const _BookAnnotationsBottomSheet({
    required this.book,
    required this.settings,
    required this.onSelectPage,
    required this.onShareHighlight,
  });

  @override
  ConsumerState<_BookAnnotationsBottomSheet> createState() =>
      _BookAnnotationsBottomSheetState();
}

class _BookAnnotationsBottomSheetState
    extends ConsumerState<_BookAnnotationsBottomSheet> {
  int _tabIndex = 0; // 0: Ayraçlar, 1: Vurgulamalar

  @override
  Widget build(BuildContext context) {
    final annotations = ref.watch(islamicBookAnnotationsProvider);
    final bookmarks = annotations.bookmarksForBook(widget.book.id);
    final highlights = annotations.highlightsForBook(widget.book.id);

    final bgColor = widget.settings.backgroundColor;
    final cardColor = widget.settings.cardColor;
    final textColor = widget.settings.textColor;
    final accentColor = widget.settings.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.book.shortTitle} • Ayraç & Vurgular',
                        style: GoogleFonts.merriweather(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Ayraçlar (${bookmarks.length})'),
                        selected: _tabIndex == 0,
                        onSelected: (_) => setState(() => _tabIndex = 0),
                        selectedColor: accentColor.withValues(alpha: 0.22),
                        backgroundColor: cardColor,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Vurgulamalar (${highlights.length})'),
                        selected: _tabIndex == 1,
                        onSelected: (_) => setState(() => _tabIndex = 1),
                        selectedColor: accentColor.withValues(alpha: 0.22),
                        backgroundColor: cardColor,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _tabIndex == 0
                    ? (bookmarks.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz kaydedilmiş bir ayraç bulunmuyor.\nÜst bardaki ayraç simgesine dokunarak ekleyebilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textColor.withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: bookmarks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final b = bookmarks[idx];
                              return ListTile(
                                tileColor: cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: accentColor.withValues(alpha: 0.22),
                                  ),
                                ),
                                leading: Icon(
                                  Icons.bookmark_rounded,
                                  color: accentColor,
                                ),
                                title: Text(
                                  b.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  b.snippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: textColor.withValues(alpha: 0.6),
                                    size: 19,
                                  ),
                                  onPressed: () => ref
                                      .read(
                                          islamicBookAnnotationsProvider.notifier)
                                      .removeBookmark(b.id),
                                ),
                                onTap: () => widget.onSelectPage(b.pageNumber),
                              );
                            },
                          ))
                    : (highlights.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz vurgulanmış bir metin bulunmuyor.\nKitap içindeki herhangi bir cümleyi basılı tutup seçerek vurgulayabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textColor.withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: highlights.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final h = highlights[idx];
                              return ListTile(
                                tileColor: cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: BookHighlightItem.badgeColorForIndex(
                                        h.colorIndex),
                                    width: 1.2,
                                  ),
                                ),
                                title: Text(
                                  '“${h.selectedText}”',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    h.referenceLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.ios_share_rounded,
                                        color: accentColor,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          widget.onShareHighlight(h),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: textColor.withValues(alpha: 0.6),
                                        size: 18,
                                      ),
                                      onPressed: () => ref
                                          .read(islamicBookAnnotationsProvider
                                              .notifier)
                                          .removeHighlight(h.id),
                                    ),
                                  ],
                                ),
                                onTap: () => widget.onSelectPage(h.pageNumber),
                              );
                            },
                          )),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// İçindekiler (Sûre / Âyet / Hadis Kitabı / Risale Bölümü) ve Kitap İçi Arama Çekmecesi
class _BookTableOfContentsSheet extends ConsumerStatefulWidget {
  final IslamicShelfBook book;
  final int currentPage;
  final IslamicBookReaderSettings settings;
  final ValueChanged<int> onSelectPage;

  const _BookTableOfContentsSheet({
    required this.book,
    required this.currentPage,
    required this.settings,
    required this.onSelectPage,
  });

  @override
  ConsumerState<_BookTableOfContentsSheet> createState() =>
      _BookTableOfContentsSheetState();
}

class _BookTableOfContentsSheetState
    extends ConsumerState<_BookTableOfContentsSheet> {
  String _searchQuery = '';
  int? _expandedSurahIdForTafseer;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.settings.backgroundColor;
    final cardColor = widget.settings.cardColor;
    final textColor = widget.settings.textColor;
    final accentColor = widget.settings.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İçindekiler • ${widget.book.shortTitle}',
                      style: GoogleFonts.merriweather(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${widget.currentPage} / ${widget.book.totalPages}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: TextStyle(fontSize: 13.5, color: textColor),
                  decoration: InputDecoration(
                    hintText: widget.book.category == IslamicBookCategory.tafseer
                        ? 'Sûre adı ara (örn: Bakara, Yâsîn)...'
                        : 'Bölüm başlığı veya metin içinde ara...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: accentColor,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: (widget.book.category == IslamicBookCategory.hadith ||
                        widget.book.category == IslamicBookCategory.risale)
                    ? _buildCorpusChaptersList(
                        scrollController: scrollController,
                        cardColor: cardColor,
                        textColor: textColor,
                        accentColor: accentColor,
                      )
                    : _buildSurahAndAyahList(
                        scrollController: scrollController,
                        cardColor: cardColor,
                        textColor: textColor,
                        accentColor: accentColor,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSurahAndAyahList({
    required ScrollController scrollController,
    required Color cardColor,
    required Color textColor,
    required Color accentColor,
  }) {
    final isTafseer = widget.book.category == IslamicBookCategory.tafseer;
    final surahs = SurahDataProvider.surahs.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.id.toString() == _searchQuery;
    }).toList();

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: surahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final surah = surahs[idx];
        final isExpanded = _expandedSurahIdForTafseer == surah.id;
        final targetPage = isTafseer
            ? QuranAyahPageMapper.toGlobalPage(surah.id, 1)
            : surah.startPage;

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  '${surah.id}. ${surah.name} Sûresi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  isTafseer
                      ? '${surah.ayetSayisi} Âyet • Âyet Sayfası $targetPage'
                      : '${surah.ayetSayisi} Âyet • Sayfa ${surah.startPage}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
                trailing: isTafseer
                    ? TextButton(
                        onPressed: () {
                          setState(() {
                            _expandedSurahIdForTafseer =
                                isExpanded ? null : surah.id;
                          });
                        },
                        child: Text(
                          isExpanded ? 'Kapat' : 'Âyet Seç',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: accentColor,
                      ),
                onTap: () => widget.onSelectPage(targetPage),
              ),
              if (isTafseer && isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(surah.ayetSayisi, (i) {
                      final ayahNo = i + 1;
                      final globalPage =
                          QuranAyahPageMapper.toGlobalPage(surah.id, ayahNo);
                      return InkWell(
                        onTap: () => widget.onSelectPage(globalPage),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 38,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '$ayahNo',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCorpusChaptersList({
    required ScrollController scrollController,
    required Color cardColor,
    required Color textColor,
    required Color accentColor,
  }) {
    final corpusService = ref.read(islamicBookCorpusServiceProvider);

    if (_searchQuery.length >= 2) {
      return FutureBuilder<List<IslamicBookPageData>>(
        future: corpusService.searchBook(widget.book.sourceKey, _searchQuery),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: accentColor));
          }
          final results = snapshot.data!;
          if (results.isEmpty) {
            return Center(
              child: Text(
                'Aranan ifadeyle eşleşen sayfa bulunamadı.',
                style: TextStyle(color: textColor.withValues(alpha: 0.65)),
              ),
            );
          }
          return ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final r = results[idx];
              return ListTile(
                tileColor: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  '${r.chapterTitle} (Sayfa ${r.pageNo})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  r.turkishText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                onTap: () => widget.onSelectPage(r.pageNo),
              );
            },
          );
        },
      );
    }

    return FutureBuilder<List<IslamicBookChapterData>>(
      future: corpusService.getChapters(widget.book.sourceKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }
        final chapters = snapshot.data!;
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final ch = chapters[idx];
            return ListTile(
              tileColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: accentColor.withValues(alpha: 0.20)),
              ),
              title: Text(
                ch.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                'Başlangıç Sayfası: ${ch.startPage} • ${ch.pageCount} Sayfa/Bölüm',
                style: TextStyle(
                  fontSize: 11.5,
                  color: textColor.withValues(alpha: 0.65),
                ),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: accentColor),
              onTap: () => widget.onSelectPage(ch.startPage),
            );
          },
        );
      },
    );
  }
}
