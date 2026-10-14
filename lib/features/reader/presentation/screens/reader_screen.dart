import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../analytics_and_habits/presentation/widgets/completion_seal_dialog.dart';
import '../../../marginalia/presentation/widgets/dictionary_sheet.dart';
import '../../../marginalia/presentation/widgets/quote_studio_sheet.dart';
import '../../domain/content_block.dart';
import '../../engine/text_segmenter.dart';
import '../providers/reader_provider.dart';
import '../widgets/ambient_sound_sheet.dart';
import '../widgets/arabic_text_card.dart';
import '../widgets/calligraphy_header_widget.dart';
import '../widgets/inline_crop_card.dart';
import '../widgets/interactive_snippet_badge_widget.dart';
import '../widgets/line_focus_overlay.dart';
import '../widgets/non_latin_warning_banner.dart';
import '../widgets/reading_settings_sheet.dart';
import '../widgets/text_block_widget.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookEntity book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  bool _showControls = true;
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerProvider.notifier).openBook(widget.book);
    });
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _goToNextPage() {
    ref.read(readerProvider.notifier).nextPage();
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.nextPage();
    }
  }

  void _goToPreviousPage() {
    ref.read(readerProvider.notifier).previousPage();
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.previousPage();
    }
  }

  void _jumpToPage(int page) {
    ref.read(readerProvider.notifier).jumpToPage(page);
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.jumpToPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerProvider.select((s) => s));
    final themeState = ref.watch(readerThemeProvider.select((s) => s));
    final showCelebration = ref.watch(
      readerProvider.select((s) => s.showCompletionCelebration),
    );
    final theme = Theme.of(context);

    if (showCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final activeBook = readerState.currentBook ?? widget.book;
        ref.read(readerProvider.notifier).clearCompletionCelebration();
        CompletionSealDialog.show(
          context,
          bookTitle: activeBook.title,
          author: activeBook.author,
          totalPages: activeBook.totalPages > 0 ? activeBook.totalPages : 1,
          readingMinutes: (activeBook.totalReadingTimeSeconds / 60).round().clamp(1, 99999),
        );
      });
    }

    if (readerState.isLoading &&
        readerState.currentReflowData == null &&
        readerState.epubChapters.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Tahrir metin akışı tanzim ediliyor...',
                style: GoogleFonts.literata(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (readerState.currentBook?.totalPages ?? widget.book.totalPages) > 0
        ? (readerState.currentBook?.totalPages ?? widget.book.totalPages)
        : 1;

    return Scaffold(
      body: LineFocusOverlay(
        isEnabled: readerState.isLineFocusEnabled,
        child: SafeArea(
          child: Stack(
            children: [
              // Main Reading Content with Touch & Gesture Navigation
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final dx = details.localPosition.dx;
                  if (dx < screenWidth * 0.20) {
                    _goToPreviousPage();
                  } else if (dx > screenWidth * 0.80) {
                    _goToNextPage();
                  } else {
                    _toggleControls();
                  }
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity;
                  if (velocity != null) {
                    if (velocity < -200) {
                      _goToNextPage();
                    } else if (velocity > 200) {
                      _goToPreviousPage();
                    }
                  }
                },
                child: SizedBox.expand(
                  child: readerState.isOriginalPdfView
                      ? _buildOriginalPdfView(readerState, themeState, theme)
                      : _buildSmartReflowContent(readerState, themeState, theme),
                ),
              ),

              // Sayfa yüklenirken / OCR taranırken üstte ince akıcı ilerleme çubuğu
              if (readerState.isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // Top Minimal App Bar (Auto-hiding)
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.literata(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Sayfa ${readerState.currentPage} / $totalPages',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'İçindekiler & Sayfa Gezgini',
                          icon: const Icon(Icons.format_list_bulleted, size: 20),
                          onPressed: () => _showTableOfContentsSheet(context, readerState),
                        ),
                        IconButton(
                          tooltip: 'Bilişsel Özet (Yerel AI)',
                          icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                          onPressed: () => _showAiInsightsDialog(context),
                        ),
                        IconButton(
                          tooltip: 'Ambiyans Sesleri',
                          icon: const Icon(Icons.headphones_outlined, size: 20),
                          onPressed: () {
                            final notifier = ref.read(readerProvider.notifier);
                            AmbientSoundSheet.show(context, notifier.ambientService);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Reading Toolbar (Auto-hiding)
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                      border: Border(top: BorderSide(color: theme.colorScheme.outline)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page Scrubber Slider
                        _buildPageSlider(readerState, theme),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              tooltip: 'Önceki Sayfa',
                              icon: const Icon(Icons.chevron_left, size: 28),
                              onPressed: _goToPreviousPage,
                            ),
                            IconButton(
                              tooltip: 'Sesli Dinle (TTS)',
                              icon: Icon(
                                readerState.isTtsPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () => ref.read(readerProvider.notifier).toggleTts(),
                            ),
                            IconButton(
                              tooltip: 'Odak Cetveli',
                              icon: Icon(
                                readerState.isLineFocusEnabled
                                    ? Icons.line_weight
                                    : Icons.crop_free,
                                color: readerState.isLineFocusEnabled
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              onPressed: () =>
                                  ref.read(readerProvider.notifier).toggleLineFocus(),
                            ),
                            IconButton(
                              tooltip: readerState.isOriginalPdfView
                                  ? 'Akıllı Akış Moduna Geç'
                                  : 'Orijinal PDF Görünümüne Geç',
                              icon: Icon(
                                readerState.isOriginalPdfView
                                    ? Icons.view_headline
                                    : Icons.picture_as_pdf,
                                color: readerState.isOriginalPdfView
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              onPressed: () =>
                                  ref.read(readerProvider.notifier).toggleDualView(),
                            ),
                            IconButton(
                              tooltip: 'Tipografi & Temalar',
                              icon: const Icon(Icons.text_format),
                              onPressed: () => ReadingSettingsSheet.show(context),
                            ),
                            IconButton(
                              tooltip: 'Sonraki Sayfa',
                              icon: const Icon(Icons.chevron_right, size: 28),
                              onPressed: _goToNextPage,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageSlider(ReaderState readerState, ThemeData theme) {
    final rawTotal = readerState.currentBook?.totalPages ?? widget.book.totalPages;
    final total = rawTotal > 0 ? rawTotal : 1;
    final current = readerState.currentPage.clamp(1, total).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        children: [
          Text(
            '${readerState.currentPage}',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: current,
                min: 1,
                max: total.toDouble(),
                divisions: total > 1 ? total - 1 : 1,
                onChanged: (val) {
                  _jumpToPage(val.round());
                },
              ),
            ),
          ),
          Text(
            '$total',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartReflowContent(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    final reflowData = readerState.currentReflowData;
    final contentBlocks = reflowData?.contentBlocks ?? const <ContentBlock>[];
    final footnotes = reflowData?.footnotes ?? const <PageFootnote>[];
    final showWarning = reflowData?.hasNonLatinOrVisualWarning ?? false;

    // If page contains no text (e.g. cover page, illustration, or scanned PDF)
    if ((contentBlocks.isEmpty &&
            (reflowData?.paragraphs.isEmpty ?? true) &&
            readerState.epubChapters.isEmpty) ||
        (reflowData != null && !reflowData.hasTextContent && readerState.epubChapters.isEmpty)) {
      return _buildEmptyOrCoverPage(readerState, themeState, theme);
    }

    final hasFootnotes = footnotes.isNotEmpty;
    final warningOffset = showWarning ? 1 : 0;
    final totalItems = contentBlocks.isNotEmpty
        ? (contentBlocks.length + (hasFootnotes ? 1 : 0) + warningOffset)
        : ((reflowData?.paragraphs.length ??
                (readerState.epubChapters.isNotEmpty
                    ? readerState.epubChapters[readerState.currentEpubChapterIndex]
                        .paragraphs
                        .length
                    : 0)) +
            (hasFootnotes ? 1 : 0) +
            warningOffset);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        themeState.sideMargin,
        _showControls ? 70 : 24,
        themeState.sideMargin,
        _showControls ? 120 : 40,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // En üstte Latin harfleri dışındaki dil / hat / görsel uyarısı
        if (showWarning && index == 0) {
          return NonLatinWarningBanner(
            onTap: () => ref.read(readerProvider.notifier).setOriginalPdfView(true),
          );
        }

        final effectiveIndex = index - warningOffset;

        // ContentBlock tabanlı modern render
        if (contentBlocks.isNotEmpty) {
          if (effectiveIndex < contentBlocks.length) {
            final block = contentBlocks[effectiveIndex];
            switch (block) {
              case CalligraphyHeaderBlock():
                return CalligraphyHeaderWidget(headerBlock: block);
              case TextBlock():
                return TextBlockWidget(
                  block: block,
                  themeState: themeState,
                  activeTtsWord: readerState.activeTtsWord,
                  blockHighlights: readerState.currentPageHighlights,
                  onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
                  onOpenDictionary: (selected) => DictionarySheet.show(context, selected),
                  onOpenQuoteStudio: (selected) => QuoteStudioSheet.show(
                    context,
                    quoteText: selected,
                    bookTitle: widget.book.title,
                    author: widget.book.author,
                  ),
                  onAddHighlight: (selected) => _showAddHighlightDialog(
                    context,
                    selectedText: selected,
                    pageNumber: readerState.currentPage,
                  ),
                );
              case InteractiveSnippetBlock():
                return InteractiveSnippetBadgeWidget(snippet: block);
            }
          }
          return _buildPageFootnotesSection(footnotes, themeState, theme);
        }

        // Geriye dönük uyumluluk (Epub / legacy paragraphs)
        final paragraphs = reflowData?.paragraphs ??
            (readerState.epubChapters.isNotEmpty
                ? readerState.epubChapters[readerState.currentEpubChapterIndex].paragraphs
                : <ParagraphSegment>[]);

        if (effectiveIndex < paragraphs.length) {
          final segment = paragraphs[effectiveIndex];
          if (segment.isCalligraphyFallback) {
            return _buildCalligraphyFallbackBanner(segment, theme);
          }
          if (segment.isArabic) {
            return _buildArabicBlock(segment, themeState, theme);
          }
          if (segment.isHeading) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                segment.rawText,
                style: GoogleFonts.literata(
                  fontSize: themeState.fontSize + 4,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  height: 1.3,
                ),
              ),
            );
          }
          return TextBlockWidget(
            block: TextBlock(
              text: segment.rawText,
              isHeading: segment.isHeading,
              isArabic: segment.isArabic,
              footnoteAnchors: segment.footnoteAnchors,
            ),
            themeState: themeState,
            activeTtsWord: readerState.activeTtsWord,
            blockHighlights: readerState.currentPageHighlights,
            onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
            onOpenDictionary: (selected) => DictionarySheet.show(context, selected),
            onOpenQuoteStudio: (selected) => QuoteStudioSheet.show(
              context,
              quoteText: selected,
              bookTitle: widget.book.title,
              author: widget.book.author,
            ),
            onAddHighlight: (selected) => _showAddHighlightDialog(
              context,
              selectedText: selected,
              pageNumber: readerState.currentPage,
            ),
          );
        }

        return _buildPageFootnotesSection(footnotes, themeState, theme);
      },
    );
  }

  Widget _buildCalligraphyFallbackBanner(ParagraphSegment segment, ThemeData theme) {
    return InlineCropCard(
      imageBytes: segment.imageBytes,
      imagePath: segment.imagePath,
      caption: segment.rawText.isNotEmpty
          ? segment.rawText
          : '📜 Asıl Hat / Kaligrafi (Orijinal Sayfa Kesiti)',
      onSwitchToOriginalPdf: () => ref.read(readerProvider.notifier).toggleDualView(),
    );
  }

  Widget _buildArabicBlock(
    ParagraphSegment segment,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    return ArabicTextCard(
      arabicText: segment.rawText,
      themeState: themeState,
      onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
    );
  }

  Widget _buildPageFootnotesSection(
    List<PageFootnote> footnotes,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'SAYFA DİPNOTLARI',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...footnotes.map((fn) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fn.key,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fn.content,
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.literata(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyOrCoverPage(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    final isFirstPage = readerState.currentPage == 1;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isFirstPage ? Icons.menu_book_rounded : Icons.image_outlined,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFirstPage ? 'Kitap Kapağı / Ön Sayfa' : 'Görsel / Taranmış Mizanpaj',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sayfa ${readerState.currentPage} / ${widget.book.totalPages}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isFirstPage
                    ? 'Bu sayfa kapak görseli veya tipografik mizanpaj içeriyor. Sayfayı orijinal PDF formatında görüntüleyebilir veya okumaya devam etmek için sonraki sayfaya geçebilirsiniz.'
                    : 'Bu sayfada seçilebilir metin bulunamadı (taranmış sayfa, resim veya boş sayfa). Orijinal PDF görünümünde tam detaylı inceleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Orijinal PDF Görünümü'),
                    onPressed: () =>
                        ref.read(readerProvider.notifier).setOriginalPdfView(true),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Sonraki Sayfa'),
                    onPressed: _goToNextPage,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(
                    'Sayfa çevirmek için ekranda kaydırın (Swipe)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ColorFilter _resolvePdfColorFilter(ReaderThemeState themeState, Brightness brightness) {
    final isDark = brightness == Brightness.dark ||
        themeState.preset == TahrirThemePreset.amoled ||
        themeState.preset == TahrirThemePreset.sapphire ||
        themeState.preset == TahrirThemePreset.forest;

    if (isDark) {
      return const ColorFilter.matrix(<double>[
        -0.85, 0.0, 0.0, 0.0, 235.0,
        0.0, -0.85, 0.0, 0.0, 235.0,
        0.0, 0.0, -0.82, 0.0, 235.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }

    if (themeState.preset == TahrirThemePreset.parchment) {
      return const ColorFilter.matrix(<double>[
        0.96, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.93, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.85, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }

    // paperWhite (doğal kağıt tonu)
    return const ColorFilter.matrix(<double>[
      0.98, 0.0, 0.0, 0.0, 0.0,
      0.0, 0.975, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.96, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]);
  }

  Widget _buildOriginalPdfView(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    final file = File(widget.book.filePath);
    if (file.existsSync()) {
      final colorFilter = _resolvePdfColorFilter(themeState, theme.brightness);

      return Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: colorFilter,
              child: Container(
                color: Colors.white,
                child: SfPdfViewer.file(
                  file,
                  controller: _pdfViewerController,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  enableDoubleTapZooming: true,
                  pageLayoutMode: PdfPageLayoutMode.single,
                  onPageChanged: (PdfPageChangedDetails details) {
                    ref.read(readerProvider.notifier).syncPdfPage(details.newPageNumber);
                  },
                  initialPageNumber: readerState.currentPage,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: _showControls ? 116 : 24,
            child: Material(
              color: theme.colorScheme.surface.withOpacity(0.92),
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  final nextCrop = !readerState.isPdfAutoCrop;
                  ref.read(readerProvider.notifier).togglePdfAutoCrop();
                  _pdfViewerController.zoomLevel = nextCrop ? 1.18 : 1.0;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        readerState.isPdfAutoCrop ? Icons.crop : Icons.crop_free,
                        size: 16,
                        color: readerState.isPdfAutoCrop
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        readerState.isPdfAutoCrop ? 'Auto-Crop 1.18x' : 'Auto-Crop 1.0x',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: readerState.isPdfAutoCrop
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Fallback if virtual/sample book or file not on disk
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 56, color: Colors.deepOrangeAccent),
            const SizedBox(height: 16),
            Text(
              'Orijinal Vektörel Mizanpaj (Sayfa ${readerState.currentPage})',
              style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu örnek eser için dijital reflow modu önerilmektedir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('Akıllı Akış Moduna Geç'),
              onPressed: () =>
                  ref.read(readerProvider.notifier).setOriginalPdfView(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHighlightDialog(
    BuildContext context, {
    required String selectedText,
    required int pageNumber,
  }) {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddHighlightBottomSheet(
        selectedText: trimmed,
        onSave: (category, colorHex, note) async {
          final repo = ref.read(highlightRepositoryProvider);
          final habitRepo = ref.read(habitRepositoryProvider);
          final bookId = widget.book.id ?? 1;
          await repo.insertHighlight(HighlightEntity(
            bookId: bookId,
            pageNumber: pageNumber,
            selectedText: trimmed,
            userNote: note.trim().isEmpty ? null : note.trim(),
            category: category,
            colorHex: colorHex,
            createdAt: DateTime.now(),
          ));
          await ref.read(readerProvider.notifier).loadCurrentPageHighlights();
          final allRes = await repo.getAllHighlights();
          if ((allRes.dataOrNull?.length ?? 0) >= 10) {
            await habitRepo.addEarnedSeal('seal_scholar');
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✨ Şerh ve vurgu derkenara kaydedildi!')),
            );
          }
        },
      ),
    );
  }

  void _showTableOfContentsSheet(BuildContext context, ReaderState readerState) {
    final theme = Theme.of(context);
    final chapters = readerState.epubChapters;
    final totalPages = (readerState.currentBook?.totalPages ?? widget.book.totalPages) > 0
        ? (readerState.currentBook?.totalPages ?? widget.book.totalPages)
        : 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
              Row(
                children: [
                  Icon(Icons.format_list_bulleted, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chapters.isNotEmpty
                          ? 'İçindekiler & Bölümler (${chapters.length})'
                          : 'Sayfa Gezgini ($totalPages Sayfa)',
                      style: GoogleFonts.literata(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: chapters.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        itemCount: chapters.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final ch = chapters[idx];
                          final isCurrent = idx == readerState.currentEpubChapterIndex;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.12),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              ch.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.literata(
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            trailing: isCurrent
                                ? Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _jumpToPage(idx + 1);
                            },
                          );
                        },
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: totalPages,
                        itemBuilder: (_, idx) {
                          final pageNum = idx + 1;
                          final isCurrent = pageNum == readerState.currentPage;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(ctx);
                              _jumpToPage(pageNum);
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                '$pageNum',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiInsightsDialog(BuildContext context) {
    final insights = ref.read(readerProvider.notifier).getPageInsights();
    final theme = Theme.of(context);
    final estMins = (insights.estimatedReadTimeSeconds / 60).ceil().clamp(1, 120);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Çevrimdışı Akıllı Katip',
                style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📊 ${insights.complexityLevel}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⏱️ ~$estMins dk okuma (${insights.estimatedReadTimeSeconds} sn)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Kilit Kavramlar:',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: insights.keyConcepts
                    .map((k) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(k, style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '3 Maddelik Hızlı Özet:',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...insights.summaryBulletPoints.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $b',
                    style: GoogleFonts.literata(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
              if (insights.studyQuestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '🤔 Sokratik Tefekkür & Çalışma Soruları:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                ...insights.studyQuestions.map(
                  (q) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '❓ $q',
                      style: GoogleFonts.literata(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }
}

class _AddHighlightBottomSheet extends StatefulWidget {
  final String selectedText;
  final Future<void> Function(
    HighlightCategory category,
    String colorHex,
    String note,
  ) onSave;

  const _AddHighlightBottomSheet({
    required this.selectedText,
    required this.onSave,
  });

  @override
  State<_AddHighlightBottomSheet> createState() => _AddHighlightBottomSheetState();
}

class _AddHighlightBottomSheetState extends State<_AddHighlightBottomSheet> {
  late final TextEditingController _noteController;
  HighlightCategory _selectedCategory = HighlightCategory.thought;
  String _selectedColorHex = '#F59E0B';

  static const List<(String, String, Color)> _colorOptions = [
    ('#F59E0B', 'Kehribar', Color(0xFFF59E0B)),
    ('#10B981', 'Zümrüt', Color(0xFF10B981)),
    ('#EF4444', 'Lal', Color(0xFFEF4444)),
    ('#3B82F6', 'Safir', Color(0xFF3B82F6)),
    ('#8B5CF6', 'Mor', Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _categoryEmoji(HighlightCategory cat) => switch (cat) {
        HighlightCategory.thought => '💡',
        HighlightCategory.quote => '✨',
        HighlightCategory.question => '❓',
        HighlightCategory.critical => '⚡',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: SingleChildScrollView(
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
              const SizedBox(height: 14),
              Text(
                '✍️ Derkenar Şerhi & Vurgu Ekle',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  '“${widget.selectedText}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kategori Seçin',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HighlightCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text('${_categoryEmoji(cat)} ${cat.displayName}'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Vurgu Rengi',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colorOptions.map((opt) {
                  final (hex, name, color) = opt;
                  final isSelected = _selectedColorHex == hex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isSelected ? 0.25 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color : color.withOpacity(0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Haşiye / Şerh Notunuz (İsteğe Bağlı)',
                  hintText: 'Bu ibare hakkındaki tefekkür, sual veya şerhinizi yazın...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Şerhi Kaydet'),
                  onPressed: () async {
                    final note = _noteController.text;
                    Navigator.pop(context);
                    await widget.onSave(
                      _selectedCategory,
                      _selectedColorHex,
                      note,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


