import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../speed_reading/domain/guided_flow_models.dart';
import '../../../speed_reading/engine/speed_reading_engine.dart';

@immutable
class GuidedFlowState {
  final bool isActive;
  final bool isPaused;
  final bool pausedByInteraction;
  final bool isOriginalPdfMode;
  final bool scaffoldingEnabled;
  final TextDensityTier densityTier;
  final int baseTargetWpm;
  final int currentEffectiveWpm;
  final int totalDurationSeconds;
  final int remainingSeconds;
  final int startPage;
  final int currentPage;
  final int pagesRead;
  final int wordsRead;
  final List<SemanticChunkSpan> chunks;
  final int currentChunkIndex;
  final double pdfLineProgress;
  final GuidedFlowPhase phase;
  final bool justCompletedFasil;
  final Set<int> visitedPages;

  const GuidedFlowState({
    this.isActive = false,
    this.isPaused = false,
    this.pausedByInteraction = false,
    this.isOriginalPdfMode = false,
    this.scaffoldingEnabled = false,
    this.densityTier = TextDensityTier.literary,
    this.baseTargetWpm = 260,
    this.currentEffectiveWpm = 260,
    this.totalDurationSeconds = 300,
    this.remainingSeconds = 300,
    this.startPage = 1,
    this.currentPage = 1,
    this.pagesRead = 0,
    this.wordsRead = 0,
    this.chunks = const [],
    this.currentChunkIndex = 0,
    this.pdfLineProgress = 0.0,
    this.phase = GuidedFlowPhase.overdrive,
    this.justCompletedFasil = false,
    this.visitedPages = const {},
  });

  SemanticChunkSpan? get activeChunk {
    if (chunks.isEmpty ||
        currentChunkIndex < 0 ||
        currentChunkIndex >= chunks.length) {
      return null;
    }
    return chunks[currentChunkIndex];
  }

  double get progressRatio {
    if (totalDurationSeconds <= 0) return 0.0;
    final elapsed =
        (totalDurationSeconds - remainingSeconds).clamp(0, totalDurationSeconds);
    return (elapsed / totalDurationSeconds).clamp(0.0, 1.0);
  }

  GuidedFlowState copyWith({
    bool? isActive,
    bool? isPaused,
    bool? pausedByInteraction,
    bool? isOriginalPdfMode,
    bool? scaffoldingEnabled,
    TextDensityTier? densityTier,
    int? baseTargetWpm,
    int? currentEffectiveWpm,
    int? totalDurationSeconds,
    int? remainingSeconds,
    int? startPage,
    int? currentPage,
    int? pagesRead,
    int? wordsRead,
    List<SemanticChunkSpan>? chunks,
    int? currentChunkIndex,
    double? pdfLineProgress,
    GuidedFlowPhase? phase,
    bool? justCompletedFasil,
    Set<int>? visitedPages,
  }) {
    return GuidedFlowState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      pausedByInteraction: pausedByInteraction ?? this.pausedByInteraction,
      isOriginalPdfMode: isOriginalPdfMode ?? this.isOriginalPdfMode,
      scaffoldingEnabled: scaffoldingEnabled ?? this.scaffoldingEnabled,
      densityTier: densityTier ?? this.densityTier,
      baseTargetWpm: baseTargetWpm ?? this.baseTargetWpm,
      currentEffectiveWpm: currentEffectiveWpm ?? this.currentEffectiveWpm,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      startPage: startPage ?? this.startPage,
      currentPage: currentPage ?? this.currentPage,
      pagesRead: pagesRead ?? this.pagesRead,
      wordsRead: wordsRead ?? this.wordsRead,
      chunks: chunks ?? this.chunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      pdfLineProgress: pdfLineProgress ?? this.pdfLineProgress,
      phase: phase ?? this.phase,
      justCompletedFasil: justCompletedFasil ?? this.justCompletedFasil,
      visitedPages: visitedPages ?? this.visitedPages,
    );
  }
}

class GuidedFlowNotifier extends StateNotifier<GuidedFlowState> {
  Timer? _countdownTimer;
  Timer? _pacerTimer;
  Timer? _pdfTimer;
  Future<bool> Function()? _onRequestNextPage;
  bool _isRequestingNextPage = false;
  bool _disposed = false;
  int _currentPageWordCount = 220;
  double _pdfWordAccumulator = 0.0;
  String _lastParagraphSignature = '';

  GuidedFlowNotifier() : super(const GuidedFlowState());

  void startFasil({
    required int durationMinutes,
    required int targetWpm,
    required TextDensityTier densityTier,
    required bool scaffoldingEnabled,
    required int currentPage,
    required List<(int, String)> paragraphs,
    required bool isOriginalPdfMode,
    required Future<bool> Function() onRequestNextPage,
  }) {
    _cancelAllTimers();
    _isRequestingNextPage = false;
    _pdfWordAccumulator = 0.0;
    _onRequestNextPage = onRequestNextPage;

    final safeDurationSec = durationMinutes.clamp(1, 240) * 60;
    final safeBaseWpm = targetWpm.clamp(120, 900);
    final safePage = currentPage < 1 ? 1 : currentPage;

    _currentPageWordCount = _estimateWordCount(paragraphs);
    _lastParagraphSignature = _buildParagraphSignature(paragraphs);

    final chunks = isOriginalPdfMode
        ? const <SemanticChunkSpan>[]
        : SpeedReadingEngine.buildParagraphSemanticChunks(
            paragraphs: paragraphs,
            preferredChunkWords: densityTier.chunkWords,
          );

    final initialPhase = GuidedFlowPhase.forProgress(
      0.0,
      scaffoldingEnabled: scaffoldingEnabled,
    );
    final effectiveWpm =
        (safeBaseWpm * initialPhase.wpmFactor).round().clamp(120, 900);
    final visited = Set<int>.unmodifiable({safePage});

    state = GuidedFlowState(
      isActive: true,
      isPaused: false,
      pausedByInteraction: false,
      isOriginalPdfMode: isOriginalPdfMode,
      scaffoldingEnabled: scaffoldingEnabled,
      densityTier: densityTier,
      baseTargetWpm: safeBaseWpm,
      currentEffectiveWpm: effectiveWpm,
      totalDurationSeconds: safeDurationSec,
      remainingSeconds: safeDurationSec,
      startPage: safePage,
      currentPage: safePage,
      pagesRead: visited.length,
      wordsRead: 0,
      chunks: List<SemanticChunkSpan>.unmodifiable(chunks),
      currentChunkIndex: 0,
      pdfLineProgress: 0.0,
      phase: initialPhase,
      justCompletedFasil: false,
      visitedPages: visited,
    );

    _startCountdownTimer();
    _scheduleActiveModeTimer();
  }

  void syncPageContent({
    required int currentPage,
    required List<(int, String)> paragraphs,
    required bool isOriginalPdfMode,
  }) {
    if (_disposed || !state.isActive) return;

    final safePage = currentPage < 1 ? 1 : currentPage;
    final nextSignature = _buildParagraphSignature(paragraphs);
    if (safePage == state.currentPage &&
        isOriginalPdfMode == state.isOriginalPdfMode &&
        nextSignature == _lastParagraphSignature) {
      return;
    }

    _cancelModeTimers();
    _pdfWordAccumulator = 0.0;
    _currentPageWordCount = _estimateWordCount(paragraphs);
    _lastParagraphSignature = nextSignature;

    final updatedVisited = Set<int>.unmodifiable({
      ...state.visitedPages,
      safePage,
    });
    final chunks = isOriginalPdfMode
        ? const <SemanticChunkSpan>[]
        : SpeedReadingEngine.buildParagraphSemanticChunks(
            paragraphs: paragraphs,
            preferredChunkWords: state.densityTier.chunkWords,
          );

    state = state.copyWith(
      currentPage: safePage,
      isOriginalPdfMode: isOriginalPdfMode,
      visitedPages: updatedVisited,
      pagesRead: updatedVisited.length,
      chunks: List<SemanticChunkSpan>.unmodifiable(chunks),
      currentChunkIndex: 0,
      pdfLineProgress: 0.0,
    );

    if (!state.isPaused) {
      _scheduleActiveModeTimer();
    }
  }

  void pauseForInteraction() {
    if (_disposed || !state.isActive) return;
    _cancelModeTimers();
    state = state.copyWith(
      isPaused: true,
      pausedByInteraction: true,
    );
  }

  void togglePause() {
    if (_disposed || !state.isActive) return;
    if (state.isPaused) {
      state = state.copyWith(
        isPaused: false,
        pausedByInteraction: false,
      );
      _scheduleActiveModeTimer();
    } else {
      _cancelModeTimers();
      state = state.copyWith(
        isPaused: true,
        pausedByInteraction: false,
      );
    }
  }

  void adjustWpm(int delta) {
    if (_disposed) return;
    final nextBase = (state.baseTargetWpm + delta).clamp(120, 900);
    final phase = GuidedFlowPhase.forProgress(
      state.progressRatio,
      scaffoldingEnabled: state.scaffoldingEnabled,
    );
    final nextEffective =
        (nextBase * phase.wpmFactor).round().clamp(120, 900);
    state = state.copyWith(
      baseTargetWpm: nextBase,
      currentEffectiveWpm: nextEffective,
      phase: phase,
    );
  }

  void finishEarlyAndReflect() {
    if (_disposed) return;
    _cancelAllTimers();
    _onRequestNextPage = null;
    _isRequestingNextPage = false;
    state = state.copyWith(
      isActive: false,
      isPaused: false,
      pausedByInteraction: false,
      justCompletedFasil: true,
    );
  }

  void stopWithoutReflection() {
    if (_disposed) return;
    _cancelAllTimers();
    _onRequestNextPage = null;
    _isRequestingNextPage = false;
    state = state.copyWith(
      isActive: false,
      isPaused: false,
      pausedByInteraction: false,
      justCompletedFasil: false,
      chunks: const [],
      currentChunkIndex: 0,
      pdfLineProgress: 0.0,
    );
  }

  void clearCompletionFlag() {
    if (_disposed || !state.justCompletedFasil) return;
    state = state.copyWith(justCompletedFasil: false);
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !state.isActive || state.isPaused) return;
      final nextRem =
          (state.remainingSeconds - 1).clamp(0, state.totalDurationSeconds);
      if (nextRem <= 0) {
        _completeFasilNaturally();
        return;
      }

      final elapsed = state.totalDurationSeconds - nextRem;
      final ratio = state.totalDurationSeconds > 0
          ? (elapsed / state.totalDurationSeconds).clamp(0.0, 1.0)
          : 1.0;
      final nextPhase = GuidedFlowPhase.forProgress(
        ratio,
        scaffoldingEnabled: state.scaffoldingEnabled,
      );
      final nextEffective =
          (state.baseTargetWpm * nextPhase.wpmFactor).round().clamp(120, 900);

      state = state.copyWith(
        remainingSeconds: nextRem,
        phase: nextPhase,
        currentEffectiveWpm: nextEffective,
      );
    });
  }

  void _completeFasilNaturally() {
    _cancelAllTimers();
    _onRequestNextPage = null;
    _isRequestingNextPage = false;
    final finalPhase = GuidedFlowPhase.forProgress(
      1.0,
      scaffoldingEnabled: state.scaffoldingEnabled,
    );
    state = state.copyWith(
      isActive: false,
      isPaused: false,
      pausedByInteraction: false,
      remainingSeconds: 0,
      phase: finalPhase,
      justCompletedFasil: true,
    );
  }

  void _scheduleActiveModeTimer() {
    _cancelModeTimers();
    if (_disposed || !state.isActive || state.isPaused) return;

    if (state.isOriginalPdfMode) {
      _pdfTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_disposed ||
            !state.isActive ||
            state.isPaused ||
            !state.isOriginalPdfMode ||
            _isRequestingNextPage) {
          return;
        }

        final pageWords = _currentPageWordCount.clamp(100, 500);
        final pageSeconds = ((pageWords / state.currentEffectiveWpm) * 60.0)
            .clamp(10.0, 150.0);
        final step = 0.1 / pageSeconds;
        final nextProgress = (state.pdfLineProgress + step).clamp(0.0, 1.0);

        _pdfWordAccumulator += (state.currentEffectiveWpm / 60.0) * 0.1;
        final wholeWords = _pdfWordAccumulator.floor();
        if (wholeWords > 0) {
          _pdfWordAccumulator -= wholeWords;
        }

        state = state.copyWith(
          pdfLineProgress: nextProgress,
          wordsRead: state.wordsRead + wholeWords,
        );

        if (nextProgress >= 1.0) {
          _pdfTimer?.cancel();
          _pdfTimer = null;
          unawaited(_advanceToNextPage());
        }
      });
      return;
    }

    if (state.chunks.isEmpty) {
      _pacerTimer = Timer(const Duration(milliseconds: 1200), () {
        if (_disposed ||
            !state.isActive ||
            state.isPaused ||
            state.isOriginalPdfMode) {
          return;
        }
        unawaited(_advanceToNextPage());
      });
      return;
    }

    final idx = state.currentChunkIndex.clamp(0, state.chunks.length - 1);
    final active = state.chunks[idx];
    final delayMs = SpeedReadingEngine.calculateChunkDelayMs(
      chunk: active.text,
      targetWpm: state.currentEffectiveWpm,
      wordsInChunk: active.wordCount,
    );

    _pacerTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_disposed ||
          !state.isActive ||
          state.isPaused ||
          state.isOriginalPdfMode) {
        return;
      }

      final nextWords = state.wordsRead + active.wordCount;
      if (idx + 1 < state.chunks.length) {
        state = state.copyWith(
          currentChunkIndex: idx + 1,
          wordsRead: nextWords,
        );
        _scheduleActiveModeTimer();
      } else {
        state = state.copyWith(wordsRead: nextWords);
        unawaited(_advanceToNextPage());
      }
    });
  }

  Future<void> _advanceToNextPage() async {
    if (_disposed || !state.isActive || _isRequestingNextPage) return;
    final callback = _onRequestNextPage;
    if (callback == null) return;

    _isRequestingNextPage = true;
    bool moved = false;
    try {
      moved = await callback();
    } catch (e) {
      debugPrint('GuidedFlowNotifier onRequestNextPage error: $e');
      moved = false;
    } finally {
      _isRequestingNextPage = false;
    }

    if (_disposed || !state.isActive) return;

    if (!moved) {
      finishEarlyAndReflect();
    }
  }

  int _estimateWordCount(List<(int, String)> paragraphs) {
    int count = 0;
    for (final (_, text) in paragraphs) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      count += trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
    return count >= 20 ? count : 220;
  }

  String _buildParagraphSignature(List<(int, String)> paragraphs) {
    final buffer = StringBuffer('${paragraphs.length}:');
    for (final (idx, text) in paragraphs) {
      buffer.write('$idx#${text.length}#${text.hashCode};');
    }
    return buffer.toString();
  }

  void _cancelModeTimers() {
    _pacerTimer?.cancel();
    _pacerTimer = null;
    _pdfTimer?.cancel();
    _pdfTimer = null;
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cancelModeTimers();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelAllTimers();
    _onRequestNextPage = null;
    super.dispose();
  }
}

final guidedFlowProvider =
    StateNotifierProvider.autoDispose<GuidedFlowNotifier, GuidedFlowState>(
  (ref) => GuidedFlowNotifier(),
);
