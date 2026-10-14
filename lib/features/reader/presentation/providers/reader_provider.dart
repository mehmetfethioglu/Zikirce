import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/footnote_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../../domain/entities/reading_session_entity.dart';
import '../../domain/content_block.dart';
import '../../engine/epub_parser_engine.dart';
import '../../engine/pdf_reflow_engine.dart';
import '../../services/ambient_audio_service.dart';
import '../../services/offline_ai_service.dart';
import '../../services/tts_service.dart';

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
  final bool showCompletionCelebration;

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
    this.showCompletionCelebration = false,
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
    bool? showCompletionCelebration,
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
      showCompletionCelebration: showCompletionCelebration ?? this.showCompletionCelebration,
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

  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  int _lastSavedSessionSeconds = 0;
  int _unsavedStreakSeconds = 0;

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

    return ReflowPageData(
      pageNumber: pageNumber,
      rawText: chapter.content,
      paragraphs: chapter.paragraphs,
      contentBlocks: blocks,
      hasTextContent: blocks.isNotEmpty || chapter.content.trim().isNotEmpty,
      isCoverOrImagePage: false,
    );
  }

  Future<void> openBook(BookEntity book) async {
    _startSessionTimer();
    state = state.copyWith(
      currentBook: book,
      currentPage: book.currentPage,
      isLoading: true,
      showCompletionCelebration: false,
    );

    if (_isChapterBasedFormat(book.format)) {
      final chapters = book.format == BookFormat.epub
          ? await _epubEngine.parseEpub(book.filePath)
          : await _epubEngine.parseMarkdownOrTxt(book.filePath);

      final targetIndex = chapters.isEmpty
          ? 0
          : (book.currentPage - 1).clamp(0, chapters.length - 1);
      final pageNum = targetIndex + 1;
      final updatedBook = chapters.isNotEmpty
          ? book.copyWith(totalPages: chapters.length)
          : book;
      final reflow = chapters.isNotEmpty
          ? _buildReflowDataFromChapter(chapters[targetIndex], pageNum)
          : null;

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
    if (filePath == null || filePath.startsWith('sample://')) return;

    // Sessizce arka planda çalıştır (UI state'i veya rebuild'i tetiklemez)
    unawaited(
      _pdfEngine.extractPage(filePath, nextPageIndex).catchError((_) => ReflowPageData(
            pageNumber: nextPageIndex + 1,
            rawText: '',
            paragraphs: const [],
          )),
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
      final reflow = _buildReflowDataFromChapter(state.epubChapters[targetIndex], pageNum);
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
        final reflow = _buildReflowDataFromChapter(state.epubChapters[nextIdx], pageNum);
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
        final reflow = _buildReflowDataFromChapter(state.epubChapters[prevIdx], pageNum);
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
    state = state.copyWith(isOriginalPdfView: !state.isOriginalPdfView);
  }

  void setOriginalPdfView(bool isOriginal) {
    state = state.copyWith(isOriginalPdfView: isOriginal);
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

  PageAiInsights getPageInsights() {
    final text = state.currentReflowData?.rawText ??
        (state.epubChapters.isNotEmpty
            ? state.epubChapters[state.currentEpubChapterIndex].content
            : '');
    return _aiService.analyzeText(text);
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _lastSavedSessionSeconds = 0;
    _unsavedStreakSeconds = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
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

    if (_unsavedStreakSeconds >= 60) {
      final sessionDuration = _unsavedStreakSeconds;
      _unsavedStreakSeconds = 0;
      await habitRepo.updateStreak((sessionDuration / 60).round());
      await bookRepo.recordReadingSession(ReadingSessionEntity(
        bookId: state.currentBook!.id!,
        sessionDate: DateTime.now(),
        durationSeconds: sessionDuration,
        pagesRead: 1,
        wordsRead: 250,
      ));
    }
  }

  @override
  void dispose() {
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

