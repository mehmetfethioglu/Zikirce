import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/footnote_entity.dart';
import '../../../../domain/entities/reading_session_entity.dart';
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

  ReaderNotifier(this._ref) : super(const ReaderState()) {
    ttsService.onWordProgress = (progress) {
      state = state.copyWith(
        activeTtsWord: progress.currentWord,
        ttsWordStart: progress.startOffset,
        ttsWordEnd: progress.endOffset,
      );
    };

    ttsService.onStateChanged = (ttsState) {
      state = state.copyWith(isTtsPlaying: ttsState == TtsState.playing);
    };
  }

  Future<void> openBook(BookEntity book) async {
    _startSessionTimer();
    state = state.copyWith(
      currentBook: book,
      currentPage: book.currentPage,
      isLoading: true,
    );

    if (book.format == BookFormat.epub) {
      final chapters = await _epubEngine.parseEpub(book.filePath);
      state = state.copyWith(
        epubChapters: chapters,
        currentEpubChapterIndex: (book.currentPage - 1).clamp(0, chapters.length - 1),
        isLoading: false,
      );
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

    _saveProgress();

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

  Future<void> jumpToPage(int pageNumber) async {
    if (state.currentBook == null) return;
    if (state.currentBook!.format == BookFormat.epub) {
      final targetIndex = (pageNumber - 1).clamp(0, state.epubChapters.length - 1);
      state = state.copyWith(
        currentEpubChapterIndex: targetIndex,
        currentPage: targetIndex + 1,
      );
      _saveProgress();
    } else {
      await _loadPdfPage(pageNumber);
    }
  }

  void syncPdfPage(int pageNumber) {
    if (state.currentPage != pageNumber) {
      state = state.copyWith(currentPage: pageNumber);
      _saveProgress();
    }
  }

  Future<void> nextPage() async {
    if (state.currentBook == null) return;
    if (state.currentBook!.format == BookFormat.epub) {
      if (state.currentEpubChapterIndex < state.epubChapters.length - 1) {
        state = state.copyWith(
          currentEpubChapterIndex: state.currentEpubChapterIndex + 1,
          currentPage: state.currentEpubChapterIndex + 2,
        );
        _saveProgress();
      }
    } else {
      if (state.currentPage < state.currentBook!.totalPages) {
        await _loadPdfPage(state.currentPage + 1);
      }
    }
  }

  Future<void> previousPage() async {
    if (state.currentBook == null) return;
    if (state.currentBook!.format == BookFormat.epub) {
      if (state.currentEpubChapterIndex > 0) {
        state = state.copyWith(
          currentEpubChapterIndex: state.currentEpubChapterIndex - 1,
          currentPage: state.currentEpubChapterIndex,
        );
        _saveProgress();
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

    await bookRepo.updateBookProgress(
      bookId: state.currentBook!.id!,
      currentPage: current,
      progressPercentage: progress,
      additionalReadingTimeSeconds: _sessionSeconds,
    );

    if (progress >= 1.0) {
      await bookRepo.markBookCompleted(state.currentBook!.id!);
      await habitRepo.addEarnedSeal('seal_completed_${state.currentBook!.id}');
    }

    if (_sessionSeconds >= 60) {
      await habitRepo.updateStreak((_sessionSeconds / 60).round());
      await bookRepo.recordReadingSession(ReadingSessionEntity(
        bookId: state.currentBook!.id!,
        sessionDate: DateTime.now(),
        durationSeconds: _sessionSeconds,
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
