import 'package:flutter/gestures.dart';
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
import '../../data/risale_lugat_service.dart';
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
  final List<TapGestureRecognizer> _lugatTapRecognizers =
      <TapGestureRecognizer>[];

  void _disposeLugatRecognizers() {
    for (final r in _lugatTapRecognizers) {
      r.dispose();
    }
    _lugatTapRecognizers.clear();
  }

  TapGestureRecognizer _createLugatTapRecognizer(VoidCallback onTap) {
    if (_lugatTapRecognizers.length > 900) {
      const removeCount = 300;
      for (int i = 0; i < removeCount; i++) {
        _lugatTapRecognizers[i].dispose();
      }
      _lugatTapRecognizers.removeRange(0, removeCount);
    }
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _lugatTapRecognizers.add(recognizer);
    return recognizer;
  }

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
      await Future.wait<void>([
        TafseerService.initialize(),
        RisaleLugatService.instance.ensureLoaded(),
      ]);

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
    _disposeLugatRecognizers();
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
          // Risale-i Nur Lügati Arama & Kelime Vurgusu
          IconButton(
            tooltip: 'Risale-i Nur Lügati Sözlüğü',
            onPressed: () => _openRisaleLugatSearchSheet(book, settings),
            icon: Icon(
              Icons.menu_book_rounded,
              color: settings.showLugatWords ? accentColor : textColor,
              size: 21,
            ),
          ),
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
                                              label: 'Lügat Mânâsı',
                                              onPressed: () {
                                                final q = _selectedText.trim();
                                                ContextMenuController
                                                    .removeAny();
                                                final found = RisaleLugatService
                                                    .instance
                                                    .lookupWord(
                                                  q,
                                                  includeStopwords: true,
                                                );
                                                if (found != null) {
                                                  _showRisaleLugatPopup(
                                                    entry: found,
                                                    surfaceText: q,
                                                    book: book,
                                                    settings: settings,
                                                  );
                                                } else {
                                                  _openRisaleLugatSearchSheet(
                                                    book,
                                                    settings,
                                                    initialQuery: q,
                                                  );
                                                }
                                              },
                                            ),
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
  /// (Allah ve Rab lafızları her zaman kırmızı vurgulanır).
  Widget _buildUnifiedArabicText({
    required String rawArabic,
    required IslamicBookReaderSettings settings,
    String? ayahNumber,
    bool showStopMarker = false,
    TextAlign textAlign = TextAlign.right,
  }) {
    final arabicFont = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);

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
          enabled: true,
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

  static final RegExp _inlineArabicRunRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\u202E\u202C]+(?:\s*[\-–—٭۞()«»\[\]،؛؟]*\s*[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\u202E\u202C]+)*',
  );

  static bool _isPureArabicParagraph(String paragraph) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) return false;
    final hasArabic = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(trimmed);
    if (!hasArabic) return false;
    final hasLatin = RegExp(
      r'[A-Za-zÂÎÛÊÔâîûêôÇĞIİÖŞÜçğıiöşü]',
    ).hasMatch(trimmed);
    return !hasLatin;
  }

  /// Tema indeksine göre göz yormayan, örnek görseldekiyle birebir uyumlu sıcak kehribar/bakır lügat rengi.
  Color _resolveLugatWordColor(IslamicBookReaderSettings settings) {
    switch (settings.themeIndex) {
      case 0:
        return const Color(0xFFB5652B); // Parşömen sıcak bakır/kehribar
      case 1:
        return const Color(0xFFA85720); // Klasik Sahife tok kehribar/bronz
      case 2:
        return const Color(0xFFE59852); // Safir Gece parlak sıcak kehribar
      case 3:
        return const Color(0xFFE8A856); // Zümrüt altın kehribar
      case 4:
        return const Color(0xFFEDA658); // AMOLED sıcak altın kehribar
      default:
        return const Color(0xFFB5652B);
    }
  }

  /// Metin içindeki müstakil Arapça âyet/hadis/serlevha paragraflarını Kur'ân sayfası kalitesinde
  /// (RTL, AmasyaAbay, kırmızı Lafzatullah) ve Türkçe paragrafları lügat/vurgulama ile oluşturur.
  Widget _buildRichBodyWithArabicBlocks({
    required String text,
    required IslamicBookReaderSettings settings,
    required List<BookHighlightItem> pageHighlights,
    required IslamicShelfBook book,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final paragraphs = text.split(RegExp(r'\n{2,}'));
    final hasStandaloneArabic = paragraphs.any(_isPureArabicParagraph);
    if (!hasStandaloneArabic) {
      return Text.rich(
        _buildTextSpanWithHighlights(
          text: text,
          baseStyle: _resolveTurkishFont(settings),
          pageHighlights: pageHighlights,
          isDark: settings.isDarkTheme,
        ),
        textAlign: settings.justifyText ? TextAlign.justify : TextAlign.left,
      );
    }

    final children = <Widget>[];
    final trBuffer = <String>[];

    void flushTurkishBuffer() {
      if (trBuffer.isEmpty) return;
      final joined = trBuffer.join('\n\n');
      trBuffer.clear();
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            _buildTextSpanWithHighlights(
              text: joined,
              baseStyle: _resolveTurkishFont(settings),
              pageHighlights: pageHighlights,
              isDark: settings.isDarkTheme,
            ),
            textAlign:
                settings.justifyText ? TextAlign.justify : TextAlign.left,
          ),
        ),
      );
    }

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;
      if (_isPureArabicParagraph(trimmed)) {
        flushTurkishBuffer();
        if (settings.showArabicText) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: settings.cardColor.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: settings.accentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: _buildUnifiedArabicText(
                  rawArabic: trimmed,
                  settings: settings,
                  textAlign: book.category == IslamicBookCategory.risale
                      ? TextAlign.center
                      : TextAlign.right,
                ),
              ),
            ),
          );
        }
      } else {
        trBuffer.add(para);
      }
    }
    flushTurkishBuffer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Sayfadaki kayıtlı vurgulamaları (Highlights) ve Risale-i Nur Lügati kelimelerini
  /// metin içinde işaretler; lügatte bulunan kelimelere dokunulduğunda modern mânâ popup'ı açar.
  TextSpan _buildTextSpanWithHighlights({
    required String text,
    required TextStyle baseStyle,
    required List<BookHighlightItem> pageHighlights,
    required bool isDark,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final settings = ref.read(islamicBookReaderSettingsProvider);
    final books = ref.read(islamicBookshelfProvider);
    final currentBook = books.firstWhere(
      (b) => b.id == widget.bookId,
      orElse: () => books.first,
    );

    if (pageHighlights.isEmpty) {
      return _buildLugatAnnotatedTextSpan(
        text: text,
        baseStyle: baseStyle,
        settings: settings,
        book: currentBook,
      );
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
        spans.add(
          _buildLugatAnnotatedTextSpan(
            text: remaining,
            baseStyle: baseStyle,
            settings: settings,
            book: currentBook,
          ),
        );
        break;
      }

      if (earliestIndex > 0) {
        spans.add(
          _buildLugatAnnotatedTextSpan(
            text: remaining.substring(0, earliestIndex),
            baseStyle: baseStyle,
            settings: settings,
            book: currentBook,
          ),
        );
      }

      final needleLen = matchedHighlight.selectedText.trim().length;
      final highlightedChunk =
          remaining.substring(earliestIndex, earliestIndex + needleLen);
      spans.add(
        _buildLugatAnnotatedTextSpan(
          text: highlightedChunk,
          baseStyle: baseStyle.copyWith(
            backgroundColor: BookHighlightItem.colorForIndex(
              matchedHighlight.colorIndex,
              isDark: isDark,
            ),
            fontWeight: FontWeight.w600,
          ),
          settings: settings,
          book: currentBook,
        ),
      );

      remaining = remaining.substring(earliestIndex + needleLen);
    }

    return TextSpan(children: spans);
  }

  /// Metin parçasındaki satır içi Arapça ibareleri Kur'ân hattıyla (AmasyaAbay + kırmızı Lafzatullah)
  /// ve Risale-i Nur Lügati kelimelerini/tamlamalarını tema uyumlu renklendirmeyle (alt çizgisiz,
  /// yalnızca kök/tamlama kısmı renkli, Türkçe çekim ekleri normal metin renginde) oluşturur.
  TextSpan _buildLugatAnnotatedTextSpan({
    required String text,
    required TextStyle baseStyle,
    required IslamicBookReaderSettings settings,
    required IslamicShelfBook book,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final arabicMatches = _inlineArabicRunRegex.allMatches(text).toList(
          growable: false,
        );
    if (arabicMatches.isEmpty) {
      return _buildLugatPureTurkishTextSpan(
        text: text,
        baseStyle: baseStyle,
        settings: settings,
        book: book,
      );
    }

    final arabicFont = ref.read(arabicFontFamilyProvider);
    final isBoldArabic = ref.read(isBoldArabicProvider);
    final inlineArabicFontSize =
        ((baseStyle.fontSize ?? settings.turkishFontSize) * 1.42)
            .clamp(21.0, 38.0);

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final arMatch in arabicMatches) {
      if (arMatch.start > cursor) {
        spans.add(
          _buildLugatPureTurkishTextSpan(
            text: text.substring(cursor, arMatch.start),
            baseStyle: baseStyle,
            settings: settings,
            book: book,
          ),
        );
      }

      final arSegment = text.substring(arMatch.start, arMatch.end);
      if (settings.showArabicText) {
        spans.addAll(
          QuranWordHighlighter.buildHighlightedSpans(
            rawText: arSegment,
            baseStyle: TextStyle(
              fontFamily: arabicFont,
              fontSize: inlineArabicFontSize,
              fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
              color: baseStyle.color ?? settings.textColor,
              backgroundColor: baseStyle.backgroundColor,
              height: 1.95,
            ),
            isDark: settings.isDarkTheme,
            enabled: true,
            fontFamily: arabicFont,
            isBold: isBoldArabic,
          ),
        );
      }

      cursor = arMatch.end;
    }

    if (cursor < text.length) {
      spans.add(
        _buildLugatPureTurkishTextSpan(
          text: text.substring(cursor),
          baseStyle: baseStyle,
          settings: settings,
          book: book,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  TextSpan _buildLugatPureTurkishTextSpan({
    required String text,
    required TextStyle baseStyle,
    required IslamicBookReaderSettings settings,
    required IslamicShelfBook book,
  }) {
    final lugatService = RisaleLugatService.instance;
    if (!settings.showLugatWords || !lugatService.isLoaded || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final matches = lugatService.findMatchesInText(text);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lugatWordColor = _resolveLugatWordColor(settings);
    final children = <InlineSpan>[];
    int cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final recognizer = _createLugatTapRecognizer(() {
        HapticFeedback.selectionClick();
        _showRisaleLugatPopup(
          entry: match.entry,
          surfaceText: match.coloredStemText,
          book: book,
          settings: settings,
        );
      });

      // Yalnızca kök / tamlama kısmı (match.start .. match.stemEnd) tema uyumlu lügat rengiyle boyanır
      children.add(
        TextSpan(
          text: match.coloredStemText,
          recognizer: recognizer,
          style: baseStyle.copyWith(
            color: lugatWordColor,
          ),
        ),
      );

      // Türkçe çekim eki varsa (örn. hût[un], sahil-i selâmet[e], küre-i zemin[imizdir]) normal metin renginde kalır
      if (match.stemEnd < match.end) {
        children.add(
          TextSpan(
            text: text.substring(match.stemEnd, match.end),
            recognizer: recognizer,
            style: baseStyle,
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      children.add(
        TextSpan(
          text: text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(children: children);
  }

  /// Kelimeye dokunulduğunda açılan Modern Tahrir Risale-i Nur Lügati Popup'ı
  void _showRisaleLugatPopup({
    required RisaleLugatEntry entry,
    required String surfaceText,
    required IslamicShelfBook book,
    required IslamicBookReaderSettings settings,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Risale-i Nur Lügati',
      barrierColor: Colors.black.withValues(alpha: 0.58),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: _RisaleLugatWordPopupDialog(
            entry: entry,
            surfaceText: surfaceText,
            book: book,
            settings: settings,
            arabicFontFamily: ref.read(arabicFontFamilyProvider),
            onShareWord: () {
              Navigator.of(ctx).pop();
              final quote =
                  '${entry.headword}${entry.ottomanScript.isNotEmpty ? ' (${entry.ottomanScript})' : ''}: ${entry.definition}';
              _shareSelectedPassage(
                book: book,
                quoteText: quote,
                arabicText:
                    entry.ottomanScript.isNotEmpty ? entry.ottomanScript : null,
                customRef:
                    'Risale-i Nur Lügati • ${entry.headword} (${book.shortTitle})',
              );
            },
            onOpenFullSearch: (query) {
              Navigator.of(ctx).pop();
              _openRisaleLugatSearchSheet(
                book,
                settings,
                initialQuery: query,
              );
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// 54.039 Maddelik Tam Kapsamlı Risale-i Nur Lügati Arama ve Kelime Vurgusu Çekmecesi
  void _openRisaleLugatSearchSheet(
    IslamicShelfBook book,
    IslamicBookReaderSettings settings, {
    String initialQuery = '',
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RisaleLugatSearchBottomSheet(
        book: book,
        settings: settings,
        initialQuery: initialQuery,
        arabicFontFamily: ref.read(arabicFontFamilyProvider),
        onSelectEntry: (entry) {
          Navigator.of(ctx).pop();
          _showRisaleLugatPopup(
            entry: entry,
            surfaceText: entry.headword,
            book: book,
            settings: settings,
          );
        },
        onOpenLugatBookOnShelf: () {
          Navigator.of(ctx).pop();
          if (book.id == 'book_rn_lugat') return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const IslamicBookReaderScreen(bookId: 'book_rn_lugat'),
            ),
          );
        },
      ),
    );
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
            _buildRichBodyWithArabicBlocks(
              text: tefsirBody.isNotEmpty
                  ? tefsirBody
                  : 'Bu âyet-i kerîmenin tefsiri bir önceki âyet grubu bütünlüğü içinde beyan edilmiştir.',
              settings: settings,
              pageHighlights: pageHighlights,
              book: book,
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

            // Türkçe ve Arapça Karma Tam Metin (Seçilebilir, Vurgulanabilir ve Kuran Hattıyla Render Edilir)
            _buildRichBodyWithArabicBlocks(
              text: page.turkishText,
              settings: settings,
              pageHighlights: pageHighlights,
              book: book,
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

/// Kelimeye dokunulduğunda açılan Modern Tahrir Estetiğinde Risale-i Nur Lügati Popup Kartı
class _RisaleLugatWordPopupDialog extends StatelessWidget {
  final RisaleLugatEntry entry;
  final String surfaceText;
  final IslamicShelfBook book;
  final IslamicBookReaderSettings settings;
  final String arabicFontFamily;
  final VoidCallback onShareWord;
  final ValueChanged<String> onOpenFullSearch;

  const _RisaleLugatWordPopupDialog({
    required this.entry,
    required this.surfaceText,
    required this.book,
    required this.settings,
    required this.arabicFontFamily,
    required this.onShareWord,
    required this.onOpenFullSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = settings.isDarkTheme;
    final bgColor = isDark ? const Color(0xFF15201D) : const Color(0xFFFBF3E2);
    final cardColor = isDark ? const Color(0xFF1E2D29) : const Color(0xFFF5E8CE);
    final textColor = isDark ? const Color(0xFFF4EFE6) : const Color(0xFF231810);
    final subColor = textColor.withValues(alpha: 0.68);
    const goldColor = Color(0xFFD4AF37);

    final bullets = entry.meaningBullets;
    final risaleQuote = entry.risaleQuote;
    final cleanSurface = surfaceText.trim();
    final showSurfaceBadge = cleanSurface.isNotEmpty &&
        cleanSurface.toLowerCase() != entry.headword.toLowerCase();

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 410,
          maxHeight: 540,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: goldColor.withValues(alpha: 0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Üst Klasik Tezhip Başlık Şeridi
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF103327), Color(0xFF1A2622)]
                          : const [Color(0xFF2C1E14), Color(0xFF422C1D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22.5),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: goldColor.withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: goldColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: goldColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RİSALE-İ NUR BÜYÜK LÜGATİ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                                color: goldColor,
                              ),
                            ),
                            Text(
                              'Osmanlıca – Türkçe Külliyat Sözlüğü',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFFFDF8EE)
                                    .withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFFDF8EE),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Kelime Başlığı + Osmanlıca Hat Rozeti
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.headword,
                              style: GoogleFonts.merriweather(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            if (showSurfaceBadge) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: goldColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: goldColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  'Metindeki Lafız: “$cleanSurface”',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? goldColor
                                        : const Color(0xFF7A4B1E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (entry.ottomanScript.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: goldColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            entry.ottomanScript,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: arabicFontFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? goldColor
                                  : const Color(0xFF5A3514),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: goldColor.withValues(alpha: 0.22),
                ),

                // Lügat Mânâları ve Risale-i Nur İktibası (Kaydırılabilir İçerik)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...List.generate(bullets.length, (idx) {
                          final item = bullets[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: goldColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bullets.length > 1) ...[
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.only(
                                        right: 10,
                                        top: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: goldColor.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              goldColor.withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Text(
                                        '${idx + 1}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? goldColor
                                              : const Color(0xFF6B3F16),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: GoogleFonts.merriweather(
                                        fontSize: 14.2,
                                        height: 1.58,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (risaleQuote != null &&
                            risaleQuote.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(
                                alpha: isDark ? 0.12 : 0.14,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: goldColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.format_quote_rounded,
                                      size: 16,
                                      color: goldColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Risale-i Nur’dan İktibas / Misal',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? goldColor
                                            : const Color(0xFF6B3F16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  risaleQuote,
                                  style: GoogleFonts.merriweather(
                                    fontSize: 12.8,
                                    fontStyle: FontStyle.italic,
                                    height: 1.52,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Alt Aksiyon Çubuğu (Kopyala, Paylaşım Kartı, Lügatte Ara)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.75),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22.5),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: goldColor.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Kopyala
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                            color: goldColor.withValues(alpha: 0.42),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${entry.headword}${entry.ottomanScript.isNotEmpty ? ' (${entry.ottomanScript})' : ''}: ${entry.definition}\n— Risale-i Nur Lügati',
                            ),
                          );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '“${entry.headword}” lügat mânâsı panoya kopyalandı.',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text(
                          'Kopyala',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Paylaşım Kartı
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                            color: goldColor.withValues(alpha: 0.42),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: onShareWord,
                        icon: const Icon(Icons.ios_share_rounded, size: 14),
                        label: const Text(
                          'Paylaş',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Lügatte Ara
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: const Color(0xFF1F160E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: () => onOpenFullSearch(entry.headword),
                        icon: const Icon(Icons.search_rounded, size: 15),
                        label: const Text(
                          'Lügatte Ara',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 54.039 Maddelik Risale-i Nur Büyük Lügati Arama ve Kelime Vurgusu Yönetim Çekmecesi
class _RisaleLugatSearchBottomSheet extends ConsumerStatefulWidget {
  final IslamicShelfBook book;
  final IslamicBookReaderSettings settings;
  final String initialQuery;
  final String arabicFontFamily;
  final ValueChanged<RisaleLugatEntry> onSelectEntry;
  final VoidCallback onOpenLugatBookOnShelf;

  const _RisaleLugatSearchBottomSheet({
    required this.book,
    required this.settings,
    required this.initialQuery,
    required this.arabicFontFamily,
    required this.onSelectEntry,
    required this.onOpenLugatBookOnShelf,
  });

  @override
  ConsumerState<_RisaleLugatSearchBottomSheet> createState() =>
      _RisaleLugatSearchBottomSheetState();
}

class _RisaleLugatSearchBottomSheetState
    extends ConsumerState<_RisaleLugatSearchBottomSheet> {
  late final TextEditingController _searchController;
  List<RisaleLugatEntry> _results = const <RisaleLugatEntry>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _runSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    final found = RisaleLugatService.instance.searchEntries(query, limit: 50);
    setState(() => _results = found);
  }

  @override
  Widget build(BuildContext context) {
    final liveSettings = ref.watch(islamicBookReaderSettingsProvider);
    final isDark = liveSettings.isDarkTheme;
    final bgColor = liveSettings.backgroundColor;
    final cardColor = liveSettings.cardColor;
    final textColor = liveSettings.textColor;
    final accentColor = liveSettings.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.50,
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
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Risale-i Nur Büyük Lügati',
                            style: GoogleFonts.merriweather(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '84.141 Osmanlıca – Türkçe Kelime, Terkip ve Külliyat Istılahı',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.book.id != 'book_rn_lugat')
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                          backgroundColor: accentColor.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: widget.onOpenLugatBookOnShelf,
                        icon: const Icon(Icons.auto_stories_rounded, size: 15),
                        label: const Text(
                          'Kitabı Aç',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Sayfa İçi Kelime Vurgusu Hızlı Anahtarı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 17,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Okurken lügatteki kelimeleri belirt ve dokununca mânâ göster',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: liveSettings.showLugatWords,
                        activeThumbColor: accentColor,
                        onChanged: (v) {
                          ref
                              .read(islamicBookReaderSettingsProvider.notifier)
                              .updateSettings(
                                liveSettings.copyWith(showLugatWords: v),
                              );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Arama Çubuğu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _runSearch,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Kelime, terkip veya mânâ ara (örn: ubudiyet, tevekkül, ehadiyet)…',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.45),
                      fontSize: 12.5,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: accentColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _runSearch('');
                            },
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.30),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: accentColor, width: 1.4),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          'Aranan lafza uygun lügat maddesi bulunamadı.',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelectEntry(item),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.headword,
                                          style: GoogleFonts.merriweather(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? const Color(0xFFD4AF37)
                                                : accentColor,
                                          ),
                                        ),
                                      ),
                                      if (item.ottomanScript.isNotEmpty)
                                        Text(
                                          item.ottomanScript,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            fontFamily: widget.arabicFontFamily,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.definition,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.merriweather(
                                      fontSize: 12.8,
                                      height: 1.48,
                                      color: textColor.withValues(alpha: 0.88),
                                    ),
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
      },
    );
  }
}
