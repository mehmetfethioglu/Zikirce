import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
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
    final readerState = ref.watch(readerProvider);
    final themeState = ref.watch(readerThemeProvider);
    final theme = Theme.of(context);

    if (readerState.isLoading && readerState.currentReflowData == null && readerState.epubChapters.isEmpty) {
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
                      ? _buildOriginalPdfView(readerState)
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                'Sayfa ${readerState.currentPage} / ${widget.book.totalPages}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
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
                                readerState.isTtsPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () => ref.read(readerProvider.notifier).toggleTts(),
                            ),
                            IconButton(
                              tooltip: 'Odak Cetveli',
                              icon: Icon(
                                readerState.isLineFocusEnabled ? Icons.line_weight : Icons.crop_free,
                                color: readerState.isLineFocusEnabled ? theme.colorScheme.primary : null,
                              ),
                              onPressed: () => ref.read(readerProvider.notifier).toggleLineFocus(),
                            ),
                            IconButton(
                              tooltip: readerState.isOriginalPdfView ? 'Akıllı Akış Moduna Geç' : 'Orijinal PDF Görünümüne Geç',
                              icon: Icon(
                                readerState.isOriginalPdfView ? Icons.view_headline : Icons.picture_as_pdf,
                                color: readerState.isOriginalPdfView ? theme.colorScheme.primary : null,
                              ),
                              onPressed: () => ref.read(readerProvider.notifier).toggleDualView(),
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
    final total = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
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
    if ((contentBlocks.isEmpty && (reflowData?.paragraphs.isEmpty ?? true)) ||
        (reflowData != null && !reflowData.hasTextContent)) {
      return _buildEmptyOrCoverPage(readerState, themeState, theme);
    }

    final hasFootnotes = footnotes.isNotEmpty;
    final warningOffset = showWarning ? 1 : 0;
    final totalItems = contentBlocks.isNotEmpty
        ? (contentBlocks.length + (hasFootnotes ? 1 : 0) + warningOffset)
        : ((reflowData?.paragraphs.length ?? 0) + (hasFootnotes ? 1 : 0) + warningOffset);

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
                  onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
                  onOpenDictionary: (selected) => DictionarySheet.show(context, selected),
                  onOpenQuoteStudio: (selected) => QuoteStudioSheet.show(
                    context,
                    quoteText: selected,
                    bookTitle: widget.book.title,
                    author: widget.book.author,
                  ),
                  onAddHighlight: (selected) async {
                    final repo = ref.read(highlightRepositoryProvider);
                    await repo.insertHighlight(HighlightEntity(
                      bookId: widget.book.id ?? 1,
                      pageNumber: readerState.currentPage,
                      selectedText: selected,
                      userNote: 'Tahrir Şerhi',
                      createdAt: DateTime.now(),
                    ));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✨ Şerh kaydedildi!')),
                      );
                    }
                  },
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
            onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
            onOpenDictionary: (selected) => DictionarySheet.show(context, selected),
            onOpenQuoteStudio: (selected) => QuoteStudioSheet.show(
              context,
              quoteText: selected,
              bookTitle: widget.book.title,
              author: widget.book.author,
            ),
            onAddHighlight: (selected) async {
              final repo = ref.read(highlightRepositoryProvider);
              await repo.insertHighlight(HighlightEntity(
                bookId: widget.book.id ?? 1,
                pageNumber: readerState.currentPage,
                selectedText: selected,
                userNote: 'Tahrir Şerhi',
                createdAt: DateTime.now(),
              ));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✨ Şerh kaydedildi!')),
                );
              }
            },
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
      caption: segment.rawText.isNotEmpty ? segment.rawText : '📜 Asıl Hat / Kaligrafi (Orijinal Sayfa Kesiti)',
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
                    onPressed: () => ref.read(readerProvider.notifier).setOriginalPdfView(true),
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

  Widget _buildOriginalPdfView(ReaderState readerState) {
    final file = File(widget.book.filePath);
    if (file.existsSync()) {
      return Container(
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
      );
    }

    // Fallback if virtual/sample book or file not on disk
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('Akıllı Akış Moduna Geç'),
              onPressed: () => ref.read(readerProvider.notifier).setOriginalPdfView(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiInsightsDialog(BuildContext context) {
    final insights = ref.read(readerProvider.notifier).getPageInsights();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Çevrimdışı Akıllı Katip', style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kilit Kavramlar:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: insights.keyConcepts.map((k) => Chip(label: Text(k, style: const TextStyle(fontSize: 11)))).toList(),
            ),
            const SizedBox(height: 12),
            Text('3 Maddelik Hızlı Özet:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...insights.summaryBulletPoints.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $b', style: GoogleFonts.literata(fontSize: 13, height: 1.4)),
                )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım')),
        ],
      ),
    );
  }
}

