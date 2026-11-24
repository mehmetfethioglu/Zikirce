import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/reading_notification_service.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/footnote_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../../domain/entities/reading_session_entity.dart';
import '../../domain/content_block.dart';
import '../../engine/epub_parser_engine.dart';
import '../../engine/ocr_proofreader_engine.dart';
import '../../engine/pdf_reflow_engine.dart';
import '../../engine/text_segmenter.dart';
import '../../services/ambient_audio_service.dart';
import '../../services/offline_ai_service.dart';
import '../../services/scanned_pdf_ocr_service.dart';
import '../../services/tts_service.dart';
import '../../../speed_reading/presentation/providers/speed_reading_provider.dart';

/// Kitap geneli Gözden Geçir taramasında şüpheli kelime bulunan sayfa/bölüm özeti
@immutable
class BookPageIssueSummary {
  final int pageNumber;
  final String title;
  final int suggestionCount;
  final int autoCorrectedCount;
  final List<String> previewWords;

  const BookPageIssueSummary({
    required this.pageNumber,
    required this.title,
    required this.suggestionCount,
    required this.autoCorrectedCount,
    this.previewWords = const [],
  });
}

/// Tüm kitabı Gözden Geçir tarama durumu
@immutable
class BookOcrScanState {
  final bool isScanning;
  final int scannedPages;
  final int totalPages;
  final int totalAutoCorrected;
  final int totalRemainingSuggestions;
  final List<BookPageIssueSummary> pagesWithIssues;

  const BookOcrScanState({
    this.isScanning = false,
    this.scannedPages = 0,
    this.totalPages = 0,
    this.totalAutoCorrected = 0,
    this.totalRemainingSuggestions = 0,
    this.pagesWithIssues = const [],
  });

  BookOcrScanState copyWith({
    bool? isScanning,
    int? scannedPages,
    int? totalPages,
    int? totalAutoCorrected,
    int? totalRemainingSuggestions,
    List<BookPageIssueSummary>? pagesWithIssues,
  }) {
    return BookOcrScanState(
      isScanning: isScanning ?? this.isScanning,
      scannedPages: scannedPages ?? this.scannedPages,
      totalPages: totalPages ?? this.totalPages,
      totalAutoCorrected: totalAutoCorrected ?? this.totalAutoCorrected,
      totalRemainingSuggestions:
          totalRemainingSuggestions ?? this.totalRemainingSuggestions,
      pagesWithIssues: pagesWithIssues ?? this.pagesWithIssues,
    );
  }
}

class ReaderState {
  final BookEntity? currentBook;
  final int currentPage;
  final bool isOriginalPdfView;
  final bool isLineFocusEnabled;
  final bool isLoading;
  final ReflowPageData? currentReflowData;
  final List<EpubParsedChapter> epubChapters;
  final int currentEpubChapterIndex;
  final String? activeTtsWord;
  final int ttsWordStart;
  final int ttsWordEnd;
  final bool isTtsPlaying;
  final List<InlineFootnoteEntity> footnotes;
  final List<HighlightEntity> currentPageHighlights;
  final bool isPdfAutoCrop;
  final bool isZenMode;
  final bool isXRaySplitMode;
  final bool isRitualActive;
  final int ritualRemainingSeconds;
  final bool showCompletionCelebration;
  final bool isOcrReviewHighlightEnabled;
  final BookOcrScanState bookOcrScan;

  const ReaderState({
    this.currentBook,
    this.currentPage = 1,
    this.isOriginalPdfView = false,
    this.isLineFocusEnabled = false,
    this.isLoading = true,
    this.currentReflowData,
    this.epubChapters = const [],
    this.currentEpubChapterIndex = 0,
    this.activeTtsWord,
    this.ttsWordStart = 0,
    this.ttsWordEnd = 0,
    this.isTtsPlaying = false,
    this.footnotes = const [],
    this.currentPageHighlights = const [],
    this.isPdfAutoCrop = false,
    this.isZenMode = false,
    this.isXRaySplitMode = false,
    this.isRitualActive = false,
    this.ritualRemainingSeconds = 900,
    this.showCompletionCelebration = false,
    this.isOcrReviewHighlightEnabled = false,
    this.bookOcrScan = const BookOcrScanState(),
  });

  ReaderState copyWith({
    BookEntity? currentBook,
    int? currentPage,
    bool? isOriginalPdfView,
    bool? isLineFocusEnabled,
    bool? isLoading,
    ReflowPageData? currentReflowData,
    List<EpubParsedChapter>? epubChapters,
    int? currentEpubChapterIndex,
    String? activeTtsWord,
    int? ttsWordStart,
    int? ttsWordEnd,
    bool? isTtsPlaying,
    List<InlineFootnoteEntity>? footnotes,
    List<HighlightEntity>? currentPageHighlights,
    bool? isPdfAutoCrop,
    bool? isZenMode,
    bool? isXRaySplitMode,
    bool? isRitualActive,
    int? ritualRemainingSeconds,
    bool? showCompletionCelebration,
    bool? isOcrReviewHighlightEnabled,
    BookOcrScanState? bookOcrScan,
  }) {
    return ReaderState(
      currentBook: currentBook ?? this.currentBook,
      currentPage: currentPage ?? this.currentPage,
      isOriginalPdfView: isOriginalPdfView ?? this.isOriginalPdfView,
      isLineFocusEnabled: isLineFocusEnabled ?? this.isLineFocusEnabled,
      isLoading: isLoading ?? this.isLoading,
      currentReflowData: currentReflowData ?? this.currentReflowData,
      epubChapters: epubChapters ?? this.epubChapters,
      currentEpubChapterIndex: currentEpubChapterIndex ?? this.currentEpubChapterIndex,
      activeTtsWord: activeTtsWord,
      ttsWordStart: ttsWordStart ?? this.ttsWordStart,
      ttsWordEnd: ttsWordEnd ?? this.ttsWordEnd,
      isTtsPlaying: isTtsPlaying ?? this.isTtsPlaying,
      footnotes: footnotes ?? this.footnotes,
      currentPageHighlights: currentPageHighlights ?? this.currentPageHighlights,
      isPdfAutoCrop: isPdfAutoCrop ?? this.isPdfAutoCrop,
      isZenMode: isZenMode ?? this.isZenMode,
      isXRaySplitMode: isXRaySplitMode ?? this.isXRaySplitMode,
      isRitualActive: isRitualActive ?? this.isRitualActive,
      ritualRemainingSeconds: ritualRemainingSeconds ?? this.ritualRemainingSeconds,
      showCompletionCelebration: showCompletionCelebration ?? this.showCompletionCelebration,
      isOcrReviewHighlightEnabled:
          isOcrReviewHighlightEnabled ?? this.isOcrReviewHighlightEnabled,
      bookOcrScan: bookOcrScan ?? this.bookOcrScan,
    );
  }
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final Ref _ref;
  final PdfReflowEngine _pdfEngine = const PdfReflowEngine();
  final EpubParserEngine _epubEngine = const EpubParserEngine();
  final OfflineAiService _aiService = const OfflineAiService();
  final TtsService ttsService = TtsService();
  final AmbientAudioService ambientService = AmbientAudioService();
  final Map<int, String> _bookPageTextIndex = {};

  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  int _lastSavedSessionSeconds = 0;
  int _unsavedStreakSeconds = 0;
  bool _cancelBookScanRequested = false;

  ReaderNotifier(this._ref) : super(const ReaderState()) {
    ttsService.onWordProgress = (progress) {
      state = state.copyWith(
        activeTtsWord: progress.currentWord,
        ttsWordStart: progress.startOffset,
        ttsWordEnd: progress.endOffset,
      );
    };

    ttsService.onStateChanged = (ttsState) {
      final isPlaying = ttsState == TtsState.playing;
      state = state.copyWith(
        isTtsPlaying: isPlaying,
        activeTtsWord: isPlaying ? state.activeTtsWord : null,
      );
      unawaited(ambientService.setTtsDucking(isPlaying));
    };
  }

  bool _isChapterBasedFormat(BookFormat format) {
    return format == BookFormat.epub ||
        format == BookFormat.markdown ||
        format == BookFormat.txt;
  }

  ReflowPageData _buildReflowDataFromChapter(EpubParsedChapter chapter, int pageNumber) {
    final hasTitleInParagraphs = chapter.paragraphs.isNotEmpty &&
        chapter.paragraphs.first.rawText.trim().toLowerCase() ==
            chapter.title.trim().toLowerCase();

    final blocks = <ContentBlock>[
      if (chapter.title.trim().isNotEmpty && !hasTitleInParagraphs)
        TextBlock(
          text: chapter.title.trim(),
          isHeading: true,
        ),
      ...chapter.paragraphs.map(
        (p) => TextBlock(
          text: p.rawText,
          isHeading: p.isHeading,
          isArabic: p.isArabic,
          footnoteAnchors: p.footnoteAnchors,
        ),
      ),
    ];

    final proofread = OcrProofreaderEngine.proofreadBlocks(blocks);
    final updatedParagraphs = proofread.blocks
        .whereType<TextBlock>()
        .map(
          (b) => ParagraphSegment(
            rawText: b.text,
            isHeading: b.isHeading,
            isArabic: b.isArabic,
            footnoteAnchors: b.footnoteAnchors,
          ),
        )
        .toList();
    final updatedRawText = proofread.blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n\n');

    return ReflowPageData(
      pageNumber: pageNumber,
      rawText: updatedRawText.isNotEmpty ? updatedRawText : chapter.content,
      paragraphs: updatedParagraphs.isNotEmpty ? updatedParagraphs : chapter.paragraphs,
      contentBlocks: proofread.blocks,
      hasTextContent: proofread.blocks.isNotEmpty || chapter.content.trim().isNotEmpty,
      isCoverOrImagePage: false,
      ocrReviewReport: proofread.report,
    );
  }

  Future<ReflowPageData> _loadChapterReflow(
    int chapterIndex, {
    BookEntity? bookOverride,
    List<EpubParsedChapter>? chaptersOverride,
  }) async {
    final book = bookOverride ?? state.currentBook;
    final chapters = chaptersOverride ?? state.epubChapters;
    if (chapters.isEmpty) {
      return ReflowPageData(
        pageNumber: chapterIndex + 1,
        rawText: '',
        paragraphs: const [],
        hasTextContent: false,
      );
    }
    final safeIndex = chapterIndex.clamp(0, chapters.length - 1);
    final pageNumber = safeIndex + 1;
    final chapter = chapters[safeIndex];
    final filePath = book?.filePath ?? '';

    if (filePath.isNotEmpty && !filePath.startsWith('sample://')) {
      try {
        final cached = await const ScannedPdfOcrService()
            .tryGetCachedOrCorrectedPage(
          filePath: filePath,
          pageIndex: safeIndex,
        );
        if (cached != null && cached.blocks.isNotEmpty) {
          final updatedParagraphs = cached.blocks
              .whereType<TextBlock>()
              .map(
                (b) => ParagraphSegment(
                  rawText: b.text,
                  isHeading: b.isHeading,
                  isArabic: b.isArabic,
                  footnoteAnchors: b.footnoteAnchors,
                ),
              )
              .toList();
          return ReflowPageData(
            pageNumber: pageNumber,
            rawText: cached.rawText,
            paragraphs: updatedParagraphs,
            contentBlocks: cached.blocks,
            hasTextContent: cached.blocks.isNotEmpty,
            isCoverOrImagePage: false,
            hasNonLatinOrVisualWarning: cached.hasNonLatinOrVisualWarning,
            ocrReviewReport: cached.ocrReviewReport,
          );
        }
      } catch (e) {
        debugPrint('ReaderNotifier chapter cache load warning: $e');
      }
    }

    return _buildReflowDataFromChapter(chapter, pageNumber);
  }

  Future<void> openBook(BookEntity book) async {
    _startSessionTimer();
    _bookPageTextIndex.clear();
    _cancelBookScanRequested = true;
    await OcrProofreaderEngine.ensureInitialized();
    state = state.copyWith(
      currentBook: book,
      currentPage: book.currentPage,
      isLoading: true,
      showCompletionCelebration: false,
      bookOcrScan: const BookOcrScanState(),
    );

    if (_isChapterBasedFormat(book.format)) {
      final chapters = book.format == BookFormat.epub
          ? await _epubEngine.parseEpub(book.filePath)
          : await _epubEngine.parseMarkdownOrTxt(book.filePath);

      for (int i = 0; i < chapters.length; i++) {
        _bookPageTextIndex[i + 1] = chapters[i].content;
      }

      final targetIndex = chapters.isEmpty
          ? 0
          : (book.currentPage - 1).clamp(0, chapters.length - 1);
      final pageNum = targetIndex + 1;
      final updatedBook = chapters.isNotEmpty
          ? book.copyWith(totalPages: chapters.length)
          : book;
      final reflow = chapters.isNotEmpty
          ? await _loadChapterReflow(
              targetIndex,
              bookOverride: updatedBook,
              chaptersOverride: chapters,
            )
          : null;
      if (reflow != null && reflow.rawText.trim().isNotEmpty) {
        _bookPageTextIndex[pageNum] = reflow.rawText;
      }

      state = state.copyWith(
        currentBook: updatedBook,
        epubChapters: chapters,
        currentEpubChapterIndex: targetIndex,
        currentPage: pageNum,
        currentReflowData: reflow,
        isLoading: false,
      );
      await loadCurrentPageHighlights();
    } else {
      await _loadPdfPage(book.currentPage);
    }

    await _loadFootnotes(book.id ?? 1);
  }

  Future<void> _loadPdfPage(int pageNumber) async {
    state = state.copyWith(isLoading: true);
    final total = state.currentBook?.totalPages ?? 1;
    final validPage = pageNumber.clamp(1, total > 0 ? total : 1);
    final pageIndex = validPage - 1;
    final reflow = await _pdfEngine.extractPage(state.currentBook?.filePath ?? '', pageIndex);

    if (reflow.rawText.trim().isNotEmpty) {
      _bookPageTextIndex[validPage] = reflow.rawText;
    }

    state = state.copyWith(
      currentPage: validPage,
      currentReflowData: reflow,
      isLoading: false,
    );

    await loadCurrentPageHighlights();
    unawaited(_saveProgress());

    // Arka Planda Sonraki 1 Sayfayı Prefetch Et (JIT + 0ms Sayfa Geçişi)
    _prefetchNextPage(validPage, total);
  }

  void _prefetchNextPage(int currentPage, int totalPages) {
    if (currentPage >= totalPages) return;
    final nextPageIndex = currentPage; // (currentPage + 1) - 1
    final filePath = state.currentBook?.filePath;
    if (filePath == null) return;

    // Sessizce arka planda çalıştır ve Kavram Radarı indeksine kaydet
    unawaited(
      _pdfEngine
          .extractPage(filePath, nextPageIndex)
          .then((prefetched) {
            if (prefetched.rawText.trim().isNotEmpty) {
              _bookPageTextIndex[nextPageIndex + 1] = prefetched.rawText;
            }
          })
          .catchError((Object e) {
            debugPrint('ReaderNotifier prefetch notice: $e');
          }),
    );
  }

  Future<void> _loadFootnotes(int bookId) async {
    final repo = _ref.read(bookRepositoryProvider);
    final res = await repo.getFootnotesForBook(bookId);
    if (res.isSuccess) {
      state = state.copyWith(footnotes: res.dataOrNull ?? []);
    }
  }

  Future<void> loadCurrentPageHighlights() async {
    final bookId = state.currentBook?.id;
    if (bookId == null) return;
    final repo = _ref.read(highlightRepositoryProvider);
    final res = await repo.getHighlightsForBook(bookId);
    if (res.isSuccess) {
      final all = res.dataOrNull ?? const <HighlightEntity>[];
      final filtered = all.where((h) => h.pageNumber == state.currentPage).toList();
      state = state.copyWith(currentPageHighlights: filtered);
    }
  }

  Future<void> jumpToPage(int pageNumber) async {
    if (state.currentBook == null) return;
    if (_isChapterBasedFormat(state.currentBook!.format)) {
      if (state.epubChapters.isEmpty) return;
      final targetIndex = (pageNumber - 1).clamp(0, state.epubChapters.length - 1);
      final pageNum = targetIndex + 1;
      final reflow = await _loadChapterReflow(targetIndex);
      if (reflow.rawText.trim().isNotEmpty) {
        _bookPageTextIndex[pageNum] = reflow.rawText;
      }
      state = state.copyWith(
        currentEpubChapterIndex: targetIndex,
        currentPage: pageNum,
        currentReflowData: reflow,
      );
      await loadCurrentPageHighlights();
      unawaited(_saveProgress());
    } else {
      await _loadPdfPage(pageNumber);
    }
  }

  void syncPdfPage(int pageNumber) {
    if (state.currentPage != pageNumber) {
      state = state.copyWith(currentPage: pageNumber);
      unawaited(loadCurrentPageHighlights());
      unawaited(_saveProgress());
    }
  }

  Future<void> nextPage() async {
    if (state.currentBook == null) return;
    if (_isChapterBasedFormat(state.currentBook!.format)) {
      if (state.currentEpubChapterIndex < state.epubChapters.length - 1) {
        final nextIdx = state.currentEpubChapterIndex + 1;
        final pageNum = nextIdx + 1;
        final reflow = await _loadChapterReflow(nextIdx);
        if (reflow.rawText.trim().isNotEmpty) {
          _bookPageTextIndex[pageNum] = reflow.rawText;
        }
        state = state.copyWith(
          currentEpubChapterIndex: nextIdx,
          currentPage: pageNum,
          currentReflowData: reflow,
        );
        await loadCurrentPageHighlights();
        unawaited(_saveProgress());
      }
    } else {
      if (state.currentPage < state.currentBook!.totalPages) {
        await _loadPdfPage(state.currentPage + 1);
      }
    }
  }

  Future<void> previousPage() async {
    if (state.currentBook == null) return;
    if (_isChapterBasedFormat(state.currentBook!.format)) {
      if (state.currentEpubChapterIndex > 0) {
        final prevIdx = state.currentEpubChapterIndex - 1;
        final pageNum = prevIdx + 1;
        final reflow = await _loadChapterReflow(prevIdx);
        if (reflow.rawText.trim().isNotEmpty) {
          _bookPageTextIndex[pageNum] = reflow.rawText;
        }
        state = state.copyWith(
          currentEpubChapterIndex: prevIdx,
          currentPage: pageNum,
          currentReflowData: reflow,
        );
        await loadCurrentPageHighlights();
        unawaited(_saveProgress());
      }
    } else {
      if (state.currentPage > 1) {
        await _loadPdfPage(state.currentPage - 1);
      }
    }
  }

  void toggleDualView() {
    state = state.copyWith(
      isOriginalPdfView: !state.isOriginalPdfView,
      isXRaySplitMode: false,
    );
  }

  void toggleXRaySplitMode() {
    state = state.copyWith(
      isXRaySplitMode: !state.isXRaySplitMode,
      isOriginalPdfView: false,
    );
  }

  void setOriginalPdfView(bool isOriginal) {
    state = state.copyWith(
      isOriginalPdfView: isOriginal,
      isXRaySplitMode: false,
    );
  }

  void toggleLineFocus() {
    state = state.copyWith(isLineFocusEnabled: !state.isLineFocusEnabled);
  }

  void togglePdfAutoCrop() {
    state = state.copyWith(isPdfAutoCrop: !state.isPdfAutoCrop);
  }

  void toggleZenMode() {
    state = state.copyWith(isZenMode: !state.isZenMode);
  }

  void toggleOcrReviewHighlight() {
    state = state.copyWith(
      isOcrReviewHighlightEnabled: !state.isOcrReviewHighlightEnabled,
    );
  }

  /// Word tarzı Gözden Geçir panelinden veya metin seçiminden gelen kelime düzeltmesini
  /// ilgili sayfaya anında uygular ve kalıcı olarak SQLite sayfa önbelleğine yazar.
  Future<void> applyOcrWordCorrection({
    required String originalWord,
    required String correctedWord,
    int? blockIndex,
    bool addToAutoCorrectRules = false,
  }) async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return;

    final cleanOriginal = originalWord.trim();
    final cleanCorrected = correctedWord.trim();
    if (cleanOriginal.isEmpty || cleanCorrected.isEmpty) return;

    if (addToAutoCorrectRules) {
      await OcrProofreaderEngine.addAutoCorrectRule(cleanOriginal, cleanCorrected);
    }

    final updatedBlocks = OcrProofreaderEngine.replaceWordInBlocks(
      blocks: currentReflow.contentBlocks,
      targetWord: cleanOriginal,
      replacementWord: cleanCorrected,
      onlyBlockIndex: addToAutoCorrectRules ? null : blockIndex,
    );

    await _commitUpdatedPageBlocks(
      updatedBlocks,
      addedCorrection: OcrCorrectionItem(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        originalWord: cleanOriginal,
        correctedWord: cleanCorrected,
        contextSnippet: '$cleanOriginal ➔ $cleanCorrected',
        blockIndex: blockIndex ?? 0,
        ruleCategory: addToAutoCorrectRules
            ? 'Kalıcı Otomatik Düzeltme Kuralı'
            : 'Sayfa İçi Tashih',
        confidence: 1.0,
      ),
      resolvedSuspiciousWord: cleanOriginal,
    );
  }

  /// Otomatik düzeltilmiş bir kelimeyi eski (ham OCR) hâline geri döndürür ve sözlüğe ekler
  Future<void> revertOcrAutoCorrection(OcrCorrectionItem item) async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return;

    await OcrProofreaderEngine.addIgnoredWord(item.originalWord);

    final updatedBlocks = OcrProofreaderEngine.replaceWordInBlocks(
      blocks: currentReflow.contentBlocks,
      targetWord: item.correctedWord,
      replacementWord: item.originalWord,
      onlyBlockIndex: item.blockIndex,
    );

    final existingReport = currentReflow.ocrReviewReport;
    final remainingAuto = existingReport.autoCorrections
        .where((c) => c.id != item.id)
        .toList();

    await _commitUpdatedPageBlocks(
      updatedBlocks,
      overrideAutoCorrections: remainingAuto,
    );
  }

  /// Şüpheli bir kelimeyi "Yoksay / Sözlüğe Ekle" olarak işaretler
  Future<void> ignoreOcrSuggestion(String suspiciousWord) async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return;

    await OcrProofreaderEngine.addIgnoredWord(suspiciousWord);

    final targetLower = OcrProofreaderEngine.toTurkishLower(suspiciousWord);
    final existingReport = currentReflow.ocrReviewReport;
    final remainingSuggestions = existingReport.suggestions
        .where(
          (s) => OcrProofreaderEngine.toTurkishLower(s.suspiciousWord) != targetLower,
        )
        .toList();

    state = state.copyWith(
      currentReflowData: currentReflow.copyWith(
        ocrReviewReport: existingReport.copyWith(
          suggestions: remainingSuggestions,
        ),
      ),
    );
  }

  /// Geçerli sayfa veya bölümü en güncel sözlük ve otomatik düzeltme kurallarıyla yeniden tarar
  Future<void> recheckCurrentPage() async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return;

    await OcrProofreaderEngine.ensureInitialized();
    final proofread = OcrProofreaderEngine.proofreadBlocks(
      currentReflow.contentBlocks,
      unhealedRawText: currentReflow.rawText,
      cachedAutoCorrections: currentReflow.ocrReviewReport.autoCorrections,
    );

    await _commitUpdatedPageBlocks(
      proofread.blocks,
      overrideAutoCorrections: proofread.report.autoCorrections,
      overrideSuggestions: proofread.report.suggestions,
      overrideTotalWordsScanned: proofread.report.totalWordsScanned,
    );
  }

  /// Kalıcı özel otomatik düzeltme kuralı ekler ve geçerli sayfayı anında günceller
  Future<void> addCustomAutoCorrectRule(
    String wrongWord,
    String correctWord,
  ) async {
    await OcrProofreaderEngine.addAutoCorrectRule(wrongWord, correctWord);
    await recheckCurrentPage();
  }

  /// Kalıcı özel otomatik düzeltme kuralını siler ve geçerli sayfayı yeniden değerlendirir
  Future<void> removeCustomAutoCorrectRule(String wrongWordKey) async {
    await OcrProofreaderEngine.removeAutoCorrectRule(wrongWordKey);
    await recheckCurrentPage();
  }

  /// Yoksayılan kelimeler listesinden bir kelimeyi çıkarır ve geçerli sayfada tekrar denetler
  Future<void> unignoreOcrWord(String word) async {
    await OcrProofreaderEngine.removeIgnoredWord(word);
    await recheckCurrentPage();
  }

  /// Devam eden kitap geneli Gözden Geçir taramasını güvenli biçimde iptal eder
  void cancelBookOcrScan() {
    _cancelBookScanRequested = true;
    if (state.bookOcrScan.isScanning) {
      state = state.copyWith(
        bookOcrScan: state.bookOcrScan.copyWith(isScanning: false),
      );
    }
  }

  /// Kitabın tamamını (bölümleri veya taranmış/metin PDF sayfalarını) tarar,
  /// otomatik onarımları kalıcı önbelleğe yazar ve şüpheli sayfaları özetler.
  Future<void> scanEntireBookForOcr({int maxPdfPages = 80}) async {
    final book = state.currentBook;
    if (book == null || state.bookOcrScan.isScanning) return;

    await OcrProofreaderEngine.ensureInitialized();
    _cancelBookScanRequested = false;

    final isChapterBased = _isChapterBasedFormat(book.format);
    final int totalPagesToScan = isChapterBased
        ? state.epubChapters.length
        : (book.totalPages > 0 ? book.totalPages : 1).clamp(1, maxPdfPages);

    if (totalPagesToScan <= 0) return;

    state = state.copyWith(
      bookOcrScan: BookOcrScanState(
        isScanning: true,
        scannedPages: 0,
        totalPages: totalPagesToScan,
      ),
    );

    final issues = <BookPageIssueSummary>[];
    final updatedChapters = isChapterBased
        ? List<EpubParsedChapter>.from(state.epubChapters)
        : null;
    int totalAutoCorrected = 0;
    int totalRemainingSuggestions = 0;

    for (int pageNum = 1; pageNum <= totalPagesToScan; pageNum++) {
      if (_cancelBookScanRequested) break;

      final outcome = await _scanBookPageForOcr(
        book: book,
        pageNum: pageNum,
        isChapterBased: isChapterBased,
        updatedChapters: updatedChapters,
      );

      if (_cancelBookScanRequested) break;

      if (outcome != null) {
        totalAutoCorrected += outcome.report.autoCorrectedCount;
        totalRemainingSuggestions += outcome.report.suggestionCount;

        if (outcome.report.suggestionCount > 0) {
          issues.add(
            BookPageIssueSummary(
              pageNumber: pageNum,
              title: outcome.title,
              suggestionCount: outcome.report.suggestionCount,
              autoCorrectedCount: outcome.report.autoCorrectedCount,
              previewWords: outcome.report.suggestions
                  .take(4)
                  .map((s) => s.suspiciousWord)
                  .toList(),
            ),
          );
        }

        if (pageNum == state.currentPage && outcome.reflow != null) {
          state = state.copyWith(currentReflowData: outcome.reflow);
        }
      }

      state = state.copyWith(
        epubChapters: updatedChapters,
        bookOcrScan: BookOcrScanState(
          isScanning: !_cancelBookScanRequested && pageNum < totalPagesToScan,
          scannedPages: pageNum,
          totalPages: totalPagesToScan,
          totalAutoCorrected: totalAutoCorrected,
          totalRemainingSuggestions: totalRemainingSuggestions,
          pagesWithIssues: List<BookPageIssueSummary>.unmodifiable(issues),
        ),
      );

      await Future<void>.delayed(Duration.zero);
    }

    if (state.bookOcrScan.isScanning) {
      state = state.copyWith(
        bookOcrScan: state.bookOcrScan.copyWith(isScanning: false),
      );
    }
  }

  Future<({String title, OcrPageReviewReport report, ReflowPageData? reflow})?>
      _scanBookPageForOcr({
    required BookEntity book,
    required int pageNum,
    required bool isChapterBased,
    required List<EpubParsedChapter>? updatedChapters,
  }) async {
    final pageIndex = pageNum - 1;
    try {
      if (isChapterBased) {
        if (pageIndex < 0 || pageIndex >= state.epubChapters.length) {
          return null;
        }
        final chapter = state.epubChapters[pageIndex];
        final reflow = await _loadChapterReflow(pageIndex, bookOverride: book);

        if (updatedChapters != null && reflow.rawText.trim().isNotEmpty) {
          updatedChapters[pageIndex] = EpubParsedChapter(
            title: chapter.title,
            content: reflow.rawText,
            paragraphs: reflow.paragraphs,
          );
        }
        if (reflow.rawText.trim().isNotEmpty) {
          _bookPageTextIndex[pageNum] = reflow.rawText;
        }
        if (reflow.ocrReviewReport.autoCorrectedCount > 0 &&
            reflow.contentBlocks.isNotEmpty &&
            book.filePath.isNotEmpty &&
            !book.filePath.startsWith('sample://')) {
          await const ScannedPdfOcrService().persistCorrectedPageBlocks(
            filePath: book.filePath,
            pageIndex: pageIndex,
            blocks: reflow.contentBlocks,
            hasNonLatin: reflow.hasNonLatinOrVisualWarning,
          );
        }
        final title = chapter.title.trim().isNotEmpty
            ? chapter.title.trim()
            : 'Bölüm $pageNum';
        return (title: title, report: reflow.ocrReviewReport, reflow: reflow);
      }

      const titlePrefix = 'Sayfa';
      if (book.filePath.isNotEmpty && !book.filePath.startsWith('sample://')) {
        final cached = await const ScannedPdfOcrService()
            .tryGetCachedOrCorrectedPage(
          filePath: book.filePath,
          pageIndex: pageIndex,
        );
        if (cached != null) {
          if (cached.rawText.trim().isNotEmpty) {
            _bookPageTextIndex[pageNum] = cached.rawText;
          }
          final updatedParagraphs = cached.blocks
              .whereType<TextBlock>()
              .map(
                (b) => ParagraphSegment(
                  rawText: b.text,
                  isHeading: b.isHeading,
                  isArabic: b.isArabic,
                  footnoteAnchors: b.footnoteAnchors,
                ),
              )
              .toList();
          final cachedReflow = ReflowPageData(
            pageNumber: pageNum,
            rawText: cached.rawText,
            paragraphs: updatedParagraphs,
            contentBlocks: cached.blocks,
            hasTextContent: cached.blocks.isNotEmpty,
            hasNonLatinOrVisualWarning: cached.hasNonLatinOrVisualWarning,
            ocrReviewReport: cached.ocrReviewReport,
          );
          return (
            title: '$titlePrefix $pageNum',
            report: cached.ocrReviewReport,
            reflow: cachedReflow,
          );
        }
      }

      final reflow = await _pdfEngine.extractPage(book.filePath, pageIndex);
      if (reflow.rawText.trim().isNotEmpty) {
        _bookPageTextIndex[pageNum] = reflow.rawText;
      }
      if (reflow.ocrReviewReport.autoCorrectedCount > 0 &&
          reflow.contentBlocks.isNotEmpty &&
          book.filePath.isNotEmpty &&
          !book.filePath.startsWith('sample://')) {
        await const ScannedPdfOcrService().persistCorrectedPageBlocks(
          filePath: book.filePath,
          pageIndex: pageIndex,
          blocks: reflow.contentBlocks,
          hasNonLatin: reflow.hasNonLatinOrVisualWarning,
        );
      }
      return (
        title: '$titlePrefix $pageNum',
        report: reflow.ocrReviewReport,
        reflow: reflow,
      );
    } catch (e) {
      debugPrint('ReaderNotifier book scan page $pageNum warning: $e');
      return null;
    }
  }

  /// Sayfadaki tüm şüpheli kelimeleri birinci önerileriyle tek dokunuşta otomatik düzeltir
  Future<int> applyAllPageOcrSuggestions() async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return 0;

    final pending = currentReflow.ocrReviewReport.suggestions
        .where((s) => s.suggestions.isNotEmpty)
        .toList();
    if (pending.isEmpty) return 0;

    var workingBlocks = currentReflow.contentBlocks;
    final newlyApplied = <OcrCorrectionItem>[
      ...currentReflow.ocrReviewReport.autoCorrections,
    ];

    int appliedCount = 0;
    for (final item in pending) {
      final bestCandidate = item.suggestions.first;
      workingBlocks = OcrProofreaderEngine.replaceWordInBlocks(
        blocks: workingBlocks,
        targetWord: item.suspiciousWord,
        replacementWord: bestCandidate,
      );
      newlyApplied.add(OcrCorrectionItem(
        id: 'batch_${DateTime.now().millisecondsSinceEpoch}_$appliedCount',
        originalWord: item.suspiciousWord,
        correctedWord: bestCandidate,
        contextSnippet: item.contextSnippet,
        blockIndex: item.blockIndex,
        ruleCategory: 'Toplu Otomatik Tashih',
        confidence: 0.92,
      ));
      appliedCount++;
    }

    await _commitUpdatedPageBlocks(
      workingBlocks,
      overrideAutoCorrections: newlyApplied,
      clearAllSuggestions: true,
    );

    return appliedCount;
  }

  Future<void> _commitUpdatedPageBlocks(
    List<ContentBlock> updatedBlocks, {
    OcrCorrectionItem? addedCorrection,
    String? resolvedSuspiciousWord,
    List<OcrCorrectionItem>? overrideAutoCorrections,
    List<OcrSuggestionItem>? overrideSuggestions,
    int? overrideTotalWordsScanned,
    bool clearAllSuggestions = false,
  }) async {
    final currentReflow = state.currentReflowData;
    if (currentReflow == null) return;

    final updatedParagraphs = updatedBlocks
        .whereType<TextBlock>()
        .map(
          (b) => ParagraphSegment(
            rawText: b.text,
            isHeading: b.isHeading,
            isArabic: b.isArabic,
            footnoteAnchors: b.footnoteAnchors,
          ),
        )
        .toList();

    final updatedRawText = updatedBlocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n\n');

    final prevReport = currentReflow.ocrReviewReport;
    final nextAutoCorrections = overrideAutoCorrections ??
        <OcrCorrectionItem>[
          if (addedCorrection != null) addedCorrection,
          ...prevReport.autoCorrections,
        ];

    final resolvedLower = resolvedSuspiciousWord == null
        ? null
        : OcrProofreaderEngine.toTurkishLower(resolvedSuspiciousWord);
    final nextSuggestions = clearAllSuggestions
        ? const <OcrSuggestionItem>[]
        : (overrideSuggestions ??
            prevReport.suggestions
                .where(
                  (s) =>
                      resolvedLower == null ||
                      OcrProofreaderEngine.toTurkishLower(s.suspiciousWord) !=
                          resolvedLower,
                )
                .toList());

    final nextReport = prevReport.copyWith(
      autoCorrections: nextAutoCorrections,
      suggestions: nextSuggestions,
      totalWordsScanned: overrideTotalWordsScanned,
    );

    final nextReflow = currentReflow.copyWith(
      rawText: updatedRawText,
      paragraphs: updatedParagraphs,
      contentBlocks: updatedBlocks,
      ocrReviewReport: nextReport,
    );

    List<EpubParsedChapter>? nextChapters;
    final book = state.currentBook;
    if (book != null &&
        _isChapterBasedFormat(book.format) &&
        state.epubChapters.isNotEmpty &&
        state.currentEpubChapterIndex >= 0 &&
        state.currentEpubChapterIndex < state.epubChapters.length) {
      final idx = state.currentEpubChapterIndex;
      final oldChapter = state.epubChapters[idx];
      nextChapters = List<EpubParsedChapter>.from(state.epubChapters);
      nextChapters[idx] = EpubParsedChapter(
        title: oldChapter.title,
        content: updatedRawText,
        paragraphs: updatedParagraphs,
      );
    }

    _bookPageTextIndex[state.currentPage] = updatedRawText;
    state = state.copyWith(
      currentReflowData: nextReflow,
      epubChapters: nextChapters,
    );

    // İlgili sayfayı SQLite önbelleğinde de kalıcı olarak güncelle
    final bookPath = state.currentBook?.filePath ?? '';
    if (bookPath.isNotEmpty && !bookPath.startsWith('sample://')) {
      await const ScannedPdfOcrService().persistCorrectedPageBlocks(
        filePath: bookPath,
        pageIndex: (state.currentPage - 1).clamp(0, 99999),
        blocks: updatedBlocks,
        hasNonLatin: currentReflow.hasNonLatinOrVisualWarning,
      );
    }
  }

  Future<void> startMutalaaRitual({
    int durationMinutes = 15,
    AmbientSoundType sound = AmbientSoundType.ney,
  }) async {
    state = state.copyWith(
      isRitualActive: true,
      ritualRemainingSeconds: durationMinutes * 60,
      isLineFocusEnabled: true,
    );
    if (ambientService.currentType == AmbientSoundType.none) {
      await ambientService.playSound(sound);
    }
  }

  Future<void> stopMutalaaRitual() async {
    state = state.copyWith(
      isRitualActive: false,
      isLineFocusEnabled: false,
    );
    await ambientService.stop();
  }

  void clearCompletionCelebration() {
    state = state.copyWith(showCompletionCelebration: false);
  }

  Future<void> toggleTts() async {
    if (ttsService.isPlaying) {
      await ttsService.pause();
    } else {
      final text = state.currentReflowData?.rawText ??
          (state.epubChapters.isNotEmpty
              ? state.epubChapters[state.currentEpubChapterIndex].content
              : '');
      await ttsService.speak(text);
    }
  }

  String getCurrentPagePlainText() {
    final reflowText = state.currentReflowData?.rawText.trim() ?? '';
    if (reflowText.isNotEmpty) {
      return reflowText;
    }
    if (state.epubChapters.isNotEmpty &&
        state.currentEpubChapterIndex >= 0 &&
        state.currentEpubChapterIndex < state.epubChapters.length) {
      return state.epubChapters[state.currentEpubChapterIndex].content.trim();
    }
    return '';
  }

  List<(int, String)> getCurrentPageIndexableBlocks() {
    final reflowData = state.currentReflowData;
    final contentBlocks = reflowData?.contentBlocks ?? const <ContentBlock>[];
    if (contentBlocks.isNotEmpty) {
      final result = <(int, String)>[];
      for (int i = 0; i < contentBlocks.length; i++) {
        final block = contentBlocks[i];
        if (block is TextBlock && block.text.trim().isNotEmpty) {
          result.add((i, block.text));
        }
      }
      return result;
    }

    final paragraphs = reflowData?.paragraphs ??
        (state.epubChapters.isNotEmpty &&
                state.currentEpubChapterIndex >= 0 &&
                state.currentEpubChapterIndex < state.epubChapters.length
            ? state.epubChapters[state.currentEpubChapterIndex].paragraphs
            : const <ParagraphSegment>[]);
    final result = <(int, String)>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final segment = paragraphs[i];
      if (!segment.isCalligraphyFallback &&
          !segment.isArabic &&
          !segment.isHeading &&
          segment.rawText.trim().isNotEmpty) {
        result.add((i, segment.rawText));
      }
    }
    return result;
  }

  PageAiInsights getPageInsights() {
    return _aiService.analyzeText(getCurrentPagePlainText());
  }

  PageAiInsights collectInsightsForPages(Iterable<int> pages) {
    final buffer = StringBuffer();
    final seenPages = <int>{};
    for (final page in pages) {
      if (!seenPages.add(page)) continue;
      final pageText = _bookPageTextIndex[page]?.trim();
      if (pageText != null && pageText.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(pageText);
      }
    }
    var combined = buffer.toString().trim();
    if (combined.isEmpty) {
      combined = getCurrentPagePlainText();
    }
    if (combined.length > 8000) {
      combined = combined.substring(0, 8000);
    }
    return _aiService.analyzeText(combined);
  }

  /// Kitabın sayfalarını tarayarak hedef kavram için Çapraz İndeks (Concordance) üretir.
  Future<ConceptRadarResult> buildConceptRadar(String concept) async {
    final currentText = state.currentReflowData?.rawText ?? '';
    if (currentText.trim().isNotEmpty) {
      _bookPageTextIndex[state.currentPage] = currentText;
    }

    // PDF kitabında henüz az sayfa indekslendiyse yakın sayfaları hızlıca indeksle
    final book = state.currentBook;
    if (book != null &&
        !_isChapterBasedFormat(book.format) &&
        _bookPageTextIndex.length < 5) {
      final total = book.totalPages > 0 ? book.totalPages : 5;
      final maxScan = total < 8 ? total : 8;
      for (int p = 1; p <= maxScan; p++) {
        if (!_bookPageTextIndex.containsKey(p)) {
          try {
            final pageData = await _pdfEngine.extractPage(book.filePath, p - 1);
            if (pageData.rawText.trim().isNotEmpty) {
              _bookPageTextIndex[p] = pageData.rawText;
            }
          } catch (e) {
            debugPrint('ReaderNotifier buildConceptRadar page $p warning: $e');
          }
        }
      }
    }

    return _aiService.buildConcordance(
      concept: concept,
      pageTexts: Map<int, String>.unmodifiable(_bookPageTextIndex),
    );
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _lastSavedSessionSeconds = 0;
    _unsavedStreakSeconds = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
      if (state.isRitualActive) {
        final nextRem = state.ritualRemainingSeconds - 1;
        if (nextRem <= 0) {
          state = state.copyWith(
            isRitualActive: false,
            ritualRemainingSeconds: 0,
          );
          unawaited(ambientService.stop());
        } else {
          state = state.copyWith(ritualRemainingSeconds: nextRem);
        }
      }
    });
  }

  Future<void> _saveProgress() async {
    if (state.currentBook == null || state.currentBook!.id == null) return;
    final bookRepo = _ref.read(bookRepositoryProvider);
    final habitRepo = _ref.read(habitRepositoryProvider);

    final totalPages = state.currentBook!.totalPages > 0 ? state.currentBook!.totalPages : 1;
    final current = state.currentPage;
    final progress = (current / totalPages).clamp(0.0, 1.0);

    final delta = (_sessionSeconds - _lastSavedSessionSeconds).clamp(0, 86400);
    _lastSavedSessionSeconds = _sessionSeconds;
    _unsavedStreakSeconds += delta;

    await bookRepo.updateBookProgress(
      bookId: state.currentBook!.id!,
      currentPage: current,
      progressPercentage: progress,
      additionalReadingTimeSeconds: delta,
    );

    if (progress >= 1.0) {
      final wasAlreadyCompleted = state.currentBook!.isCompleted;
      await bookRepo.markBookCompleted(state.currentBook!.id!);
      await habitRepo.addEarnedSeal('seal_first_book');
      await habitRepo.addEarnedSeal('seal_completed_${state.currentBook!.id}');
      if (!wasAlreadyCompleted) {
        state = state.copyWith(
          currentBook: state.currentBook!.copyWith(
            isCompleted: true,
            progressPercentage: 1.0,
            totalReadingTimeSeconds: state.currentBook!.totalReadingTimeSeconds + delta,
          ),
          showCompletionCelebration: true,
        );
      }
    }

    final rawPageText = state.currentReflowData?.rawText.trim() ?? '';
    final pageText = rawPageText.length > 3500
        ? rawPageText.substring(0, 3500)
        : rawPageText;
    final rawWordCount = pageText.isEmpty
        ? 0
        : pageText
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty)
            .length;
    final pageWords = rawWordCount >= 30 ? rawWordCount : 240;

    if (delta >= 12) {
      final measuredWpm = ((pageWords / delta) * 60.0).clamp(90.0, 850.0).round();
      unawaited(
        _ref.read(speedReadingProvider.notifier).syncFromBookReading(
              measuredBookWpm: measuredWpm,
              bookTitle: state.currentBook!.title,
              bookAuthor: state.currentBook!.author,
              pageNumber: current,
              pageExcerpt: pageText.isNotEmpty ? pageText : null,
              complexityLabel: _aiService.analyzeText(pageText).complexityLevel,
            ),
      );
    }

    if (_unsavedStreakSeconds >= 60) {
      final sessionDuration = _unsavedStreakSeconds;
      _unsavedStreakSeconds = 0;
      final sessionWpm =
          ((pageWords / sessionDuration.clamp(15, 3600)) * 60.0).clamp(90.0, 850.0);
      await habitRepo.updateStreak((sessionDuration / 60).round());
      await bookRepo.recordReadingSession(ReadingSessionEntity(
        bookId: state.currentBook!.id!,
        sessionDate: DateTime.now(),
        durationSeconds: sessionDuration,
        pagesRead: 1,
        wordsRead: pageWords,
        calculatedWpm: sessionWpm,
      ));
    }

    final habitProfileRes = await habitRepo.getHabitProfile();
    final sessionsRes = await bookRepo.getReadingSessions();
    final now = DateTime.now();
    int todaySeconds = 0;
    for (final s in sessionsRes.dataOrNull ?? const <ReadingSessionEntity>[]) {
      if (s.sessionDate.year == now.year &&
          s.sessionDate.month == now.month &&
          s.sessionDate.day == now.day) {
        todaySeconds += s.durationSeconds;
      }
    }
    final todayMinutes = ((todaySeconds + _unsavedStreakSeconds) / 60).round();
    final profile = habitProfileRes.dataOrNull;
    final excerptLine = pageText.isNotEmpty
        ? pageText.split('\n').firstWhere(
              (l) => l.trim().length > 20,
              orElse: () => state.currentBook!.title,
            )
        : state.currentBook!.title;

    unawaited(
      _ref.read(readingNotificationProvider.notifier).syncHomeScreenWidget(
            streakDays: profile?.currentStreak ?? 0,
            todayMinutesRead: todayMinutes,
            dailyGoalMinutes: profile?.dailyGoalMinutes ?? 20,
            currentBookTitle: state.currentBook!.title,
            currentBookAuthor: state.currentBook!.author,
            progressPercent: (progress * 100).round().clamp(0, 100),
            dailyQuote: excerptLine.length > 120
                ? '${excerptLine.substring(0, 117)}...'
                : excerptLine,
          ),
    );
  }

  @override
  void dispose() {
    _cancelBookScanRequested = true;
    _sessionTimer?.cancel();
    ttsService.dispose();
    ambientService.dispose();
    _saveProgress();
    super.dispose();
  }
}

final readerProvider = StateNotifierProvider<ReaderNotifier, ReaderState>((ref) {
  return ReaderNotifier(ref);
});

