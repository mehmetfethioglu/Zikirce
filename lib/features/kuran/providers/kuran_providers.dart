import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/ios_now_playing_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/quran_word_highlighter.dart';

import 'package:shared_preferences/shared_preferences.dart';

final currentMushafPageProvider = StateProvider<int>((ref) => 1);

class QuranFontNotifier extends StateNotifier<String> {
  static const _key = 'quran_font_family';

  QuranFontNotifier() : super('AmasyaAbay') {
    _loadFont();
  }

  Future<void> _loadFont() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setFont(String font) async {
    state = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, font);
  }
}

final quranFontFamilyProvider =
    StateNotifierProvider<QuranFontNotifier, String>((ref) {
  return QuranFontNotifier();
});

/// Global Arabic font family provider across the entire application
final arabicFontFamilyProvider = quranFontFamilyProvider;

class QuranFontSizeNotifier extends StateNotifier<double> {
  static const _key = 'quran_font_size';

  QuranFontSizeNotifier() : super(34.0) {
    _loadSize();
  }

  Future<void> _loadSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null && saved >= 14 && saved <= 72) {
      state = saved;
    }
  }

  Future<void> setFontSize(double size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, size);
  }
}

final quranFontSizeProvider =
    StateNotifierProvider<QuranFontSizeNotifier, double>((ref) {
  return QuranFontSizeNotifier();
});

class QuranLineHeightNotifier extends StateNotifier<double> {
  static const _key = 'quran_line_height';

  QuranLineHeightNotifier() : super(2.0) {
    _loadLineHeight();
  }

  Future<void> _loadLineHeight() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null && saved >= 1.4 && saved <= 3.2) {
      state = saved;
    }
  }

  Future<void> setLineHeight(double height) async {
    state = height;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, height);
  }
}

final quranLineHeightProvider =
    StateNotifierProvider<QuranLineHeightNotifier, double>((ref) {
  return QuranLineHeightNotifier();
});

class HighlightDivineWordsNotifier extends StateNotifier<bool> {
  static const _key = 'highlight_divine_words';

  HighlightDivineWordsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final highlightDivineWordsProvider =
    StateNotifierProvider<HighlightDivineWordsNotifier, bool>((ref) {
  return HighlightDivineWordsNotifier();
});

final quranPageDataProvider = FutureProvider.family<QuranPageData, int>((ref, pageNumber) async {
  return QuranPageRepository.getPage(pageNumber);
});

// Audio Recitation Controller
class KuranAudioState {
  final bool isPlaying;
  final bool isLoading;
  final int currentSurahId;
  final int currentAyahId;
  final int currentWordOrder;
  final int activeWordDurationMs;
  final double playbackSpeed;
  final double playbackProgress;
  final bool isBarVisible;

  KuranAudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.currentSurahId = 1,
    this.currentAyahId = 1,
    this.currentWordOrder = 0,
    this.activeWordDurationMs = 500,
    this.playbackSpeed = 1.0,
    this.playbackProgress = 0.0,
    this.isBarVisible = false,
  });

  KuranAudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    int? currentSurahId,
    int? currentAyahId,
    int? currentWordOrder,
    int? activeWordDurationMs,
    double? playbackSpeed,
    double? playbackProgress,
    bool? isBarVisible,
  }) {
    return KuranAudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentSurahId: currentSurahId ?? this.currentSurahId,
      currentAyahId: currentAyahId ?? this.currentAyahId,
      currentWordOrder: currentWordOrder ?? this.currentWordOrder,
      activeWordDurationMs: activeWordDurationMs ?? this.activeWordDurationMs,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      isBarVisible: isBarVisible ?? this.isBarVisible,
    );
  }
}

class KuranAudioNotifier extends StateNotifier<KuranAudioState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription<int?>? _indexSub;

  List<({int surahId, int ayahId, int pageId, List<String> words})>
      _queueVerses = [];
  int _lastIndex = -1;
  bool _isAdvancingItem = false;
  int? _activePageId;
  int _queueGen = 0;
  final Stopwatch _verseStopwatch = Stopwatch();
  final Stopwatch _microInterpStopwatch = Stopwatch();
  double _verseSeekAnchorMs = 0.0;
  double _lastSampledPlayerMs = -1.0;
  double _maxObservedVerseMs = 0.0;
  Timer? _wordSyncTimer;

  KuranAudioNotifier() : super(KuranAudioState()) {
    _initAudioListeners();
  }

  void _resetVerseClock({int seekMs = 0, bool isPlaying = true}) {
    _verseSeekAnchorMs = seekMs.toDouble();
    _lastSampledPlayerMs = -1.0;
    _maxObservedVerseMs = seekMs.toDouble();
    _verseStopwatch.reset();
    _microInterpStopwatch.reset();
    final isReady = _player.processingState == ProcessingState.ready;
    if (isPlaying && !state.isLoading && isReady) {
      _verseStopwatch.start();
    }
  }

  double _currentEffectivePositionMs() {
    if (_isAdvancingItem ||
        _player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.idle) {
      return _verseSeekAnchorMs;
    }

    final playerMs = _player.position.inMilliseconds.toDouble();
    if ((playerMs - _lastSampledPlayerMs).abs() >= 1.0) {
      _lastSampledPlayerMs = playerMs;
      _microInterpStopwatch
        ..reset()
        ..start();
    }

    double effectiveMs = playerMs;
    if (_player.playing &&
        _player.processingState == ProcessingState.ready &&
        playerMs > 0) {
      final interpDelta =
          (_microInterpStopwatch.elapsedMilliseconds * state.playbackSpeed)
              .clamp(0.0, 45.0);
      effectiveMs = playerMs + interpDelta;
    }

    if (effectiveMs > _maxObservedVerseMs) {
      _maxObservedVerseMs = effectiveMs;
    }
    return effectiveMs.clamp(0.0, 600000.0);
  }

  void _tickWordSync() {
    if (_isAdvancingItem ||
        !state.isBarVisible ||
        (!_player.playing && !state.isPlaying)) {
      return;
    }
    final ms = _currentEffectivePositionMs();
    final currentWords = (_lastIndex >= 0 && _lastIndex < _queueVerses.length)
        ? _queueVerses[_lastIndex].words
        : null;
    final activeWord = AudioSyncService.getActiveWordOrder(
      state.currentSurahId,
      state.currentAyahId,
      ms,
      renderedWordCount:
          (currentWords != null && currentWords.isNotEmpty)
              ? currentWords.length
              : null,
      ayahWords: currentWords,
    );

    final total = _player.duration?.inMilliseconds ?? 1;
    final prog = total > 0 ? (ms / total).clamp(0.0, 1.0) : 0.0;

    if (activeWord != state.currentWordOrder ||
        (prog - state.playbackProgress).abs() > 0.01) {
      final wordDur = activeWord != state.currentWordOrder
          ? AudioSyncService.getWordDurationMs(
              state.currentSurahId,
              state.currentAyahId,
              activeWord,
              ayahWords: currentWords,
              trackDurationMs: _player.duration?.inMilliseconds,
            )
          : state.activeWordDurationMs;
      state = state.copyWith(
        currentWordOrder: activeWord,
        activeWordDurationMs: wordDur,
        playbackProgress: prog,
      );
    }
  }

  void _initAudioListeners() {
    _posSub = _player
        .createPositionStream(
          steps: 1000,
          minPeriod: const Duration(milliseconds: 20),
          maxPeriod: const Duration(milliseconds: 30),
        )
        .listen((_) => _tickWordSync());

    _wordSyncTimer?.cancel();
    _wordSyncTimer = Timer.periodic(
      const Duration(milliseconds: 25),
      (_) => _tickWordSync(),
    );

    _stateSub = _player.playerStateStream.listen((pState) {
      final isBuffering = pState.processingState == ProcessingState.loading ||
          pState.processingState == ProcessingState.buffering;
      final isReady = pState.processingState == ProcessingState.ready;

      if (pState.playing && isReady) {
        if (!_verseStopwatch.isRunning) {
          _verseStopwatch.start();
        }
      } else {
        if (_verseStopwatch.isRunning) {
          _verseStopwatch.stop();
        }
      }

      if (pState.processingState == ProcessingState.completed &&
          !_isAdvancingItem) {
        _isAdvancingItem = true;
        if (_lastIndex >= 0 && _lastIndex + 1 < _queueVerses.length) {
          unawaited(_playSingleQueueItem(_lastIndex + 1));
        } else if (_activePageId != null && _activePageId! < 604) {
          _isAdvancingItem = false;
          _advanceToNextPage(_activePageId! + 1);
        } else {
          _isAdvancingItem = false;
          state = state.copyWith(isPlaying: false, currentWordOrder: 0);
          IosNowPlayingService.clearNowPlaying();
        }
      } else if (pState.processingState != ProcessingState.completed) {
        final wasPlaying = state.isPlaying;
        state = state.copyWith(
          isPlaying: pState.playing,
          isLoading: isBuffering,
        );
        if (wasPlaying != pState.playing && state.isBarVisible) {
          _syncNowPlaying();
        }
      }
    });
  }

  void _syncNowPlaying() {
    if (!state.isBarVisible) return;
    final surah = SurahDataProvider.surahs
        .where((s) => s.id == state.currentSurahId)
        .firstOrNull;
    final surahName = surah?.name ?? '${state.currentSurahId}. Sûre';
    IosNowPlayingService.updateNowPlaying(
      title: '$surahName Sûresi · ${state.currentAyahId}. Âyet',
      subtitle: 'Zikirce • Kur\'an-ı Kerim Mushaf Tilaveti',
      isPlaying: state.isPlaying,
      durationMs: _player.duration?.inMilliseconds ?? 0,
      positionMs: _player.position.inMilliseconds,
    );
  }

  Future<void> _advanceToNextPage(int nextPageId) async {
    try {
      await IosNowPlayingService.beginTransitionTask();
      final pageData = await QuranPageRepository.getPage(nextPageId);
      if (pageData.quranAyats.isEmpty) {
        state = state.copyWith(isPlaying: false, currentWordOrder: 0);
        return;
      }
      final first = pageData.quranAyats.first;
      await playVerse(first.sureId, first.ayetId, pageId: nextPageId);
    } catch (_) {
      state = state.copyWith(isPlaying: false, currentWordOrder: 0);
    }
  }

  Future<void> _playSingleQueueItem(
    int idx, {
    bool useFallbackCdn = false,
  }) async {
    if (idx < 0 || idx >= _queueVerses.length) {
      _isAdvancingItem = false;
      return;
    }

    final myGen = ++_queueGen;
    _isAdvancingItem = true;
    _lastIndex = idx;
    final item = _queueVerses[idx];
    _resetVerseClock(seekMs: 0, isPlaying: false);

    final initialWordDur = AudioSyncService.getWordDurationMs(
      item.surahId,
      item.ayahId,
      1,
      ayahWords: item.words.isNotEmpty ? item.words : null,
    );

    state = state.copyWith(
      currentSurahId: item.surahId,
      currentAyahId: item.ayahId,
      currentWordOrder: 1,
      activeWordDurationMs: initialWordDur,
      playbackProgress: 0.0,
      isBarVisible: true,
    );

    try {
      final soundsDir = await AudioDownloadService.getSoundsDirectory();
      final soundsDirPath = soundsDir.path;

      await AudioDownloadService.ensureVerseDownloaded(
        item.surahId,
        item.ayahId,
        pageId: item.pageId,
      ).timeout(const Duration(milliseconds: 1800), onTimeout: () => null);

      if (myGen != _queueGen) return;

      final localPath =
          '$soundsDirPath${Platform.pathSeparator}audio_${item.surahId}_${item.ayahId}.mp3';
      final localFile = File(localPath);
      final AudioSource source;
      if (AudioDownloadService.isValidDiyanetAudioFile(localFile)) {
        source = AudioSource.file(localPath);
      } else {
        final url = AudioDownloadService.getDiyanetAudioUrl(
          item.surahId,
          item.ayahId,
          pageId: item.pageId,
        );
        source = AudioSource.uri(Uri.parse(url));
      }

      if (_player.playing) {
        await _player.pause();
      }
      await _player.setLoopMode(LoopMode.off);
      await _player.setAudioSource(
        source,
        initialPosition: Duration.zero,
      );

      if (myGen != _queueGen) return;

      _resetVerseClock(seekMs: 0, isPlaying: true);
      _isAdvancingItem = false;
      unawaited(_player.play());
      _syncNowPlaying();

      for (int offset = 1; offset <= 3; offset++) {
        final nextIdx = idx + offset;
        if (nextIdx < _queueVerses.length) {
          final next = _queueVerses[nextIdx];
          unawaited(AudioDownloadService.ensureVerseDownloaded(
            next.surahId,
            next.ayahId,
            pageId: next.pageId,
          ));
        }
      }
    } catch (_) {
      _isAdvancingItem = false;
      if (!useFallbackCdn && myGen == _queueGen) {
        await _playSingleQueueItem(idx, useFallbackCdn: true);
        return;
      }
      state = state.copyWith(isPlaying: false, isLoading: false);
    }
  }

  Future<void> playVerse(
    int surahId,
    int ayahId, {
    int? pageId,
    bool useFallbackCdn = false,
  }) async {
    _activePageId = pageId;
    state = state.copyWith(
      currentSurahId: surahId,
      currentAyahId: ayahId,
      isLoading: true,
      currentWordOrder: 0,
      isBarVisible: true,
    );

    IosNowPlayingService.setRemoteCommandCallback((cmd) {
      if (cmd == 'play' && !_player.playing) {
        togglePlayPause();
      } else if (cmd == 'pause' && _player.playing) {
        togglePlayPause();
      } else if (cmd == 'togglePlayPause') {
        togglePlayPause();
      } else if (cmd == 'next' && _lastIndex + 1 < _queueVerses.length) {
        _playSingleQueueItem(_lastIndex + 1);
      } else if (cmd == 'previous' && _lastIndex > 0) {
        _playSingleQueueItem(_lastIndex - 1);
      }
    });

    final myGen = ++_queueGen;
    await AudioSyncService.configureAudioSession();
    await IosNowPlayingService.beginTransitionTask();

    try {
      final queueItems =
          <({int surahId, int ayahId, int pageId, List<String> words})>[];
      int initialIdx = 0;

      if (pageId != null) {
        final pageData = await QuranPageRepository.getPage(pageId);
        for (int i = 0; i < pageData.quranAyats.length; i++) {
          final a = pageData.quranAyats[i];
          queueItems.add((
            surahId: a.sureId,
            ayahId: a.ayetId,
            pageId: pageId,
            words: QuranWordHighlighter.extractPureWords(a.ayetText),
          ));
          if (a.sureId == surahId && a.ayetId == ayahId) {
            initialIdx = i;
          }
        }
      }

      if (queueItems.isEmpty) {
        queueItems.add((
          surahId: surahId,
          ayahId: ayahId,
          pageId: pageId ?? 1,
          words: const <String>[],
        ));
        initialIdx = 0;
      }

      if (myGen != _queueGen) return;

      _queueVerses = queueItems;
      await _playSingleQueueItem(initialIdx, useFallbackCdn: useFallbackCdn);
    } catch (_) {
      state = state.copyWith(isPlaying: false, isLoading: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await AudioSyncService.configureAudioSession();
      await _player.play();
    }
  }

  void syncExternalState(KuranAudioState newState) {
    // Harici oynatıcılar (ör. Mukabele) Mushaf kelime renklendirmesi için durumu günceller.
    // Mushaf altındaki bağımsız oynatıcı barı kesinlikle kapalı kalmalıdır.
    state = newState.copyWith(isBarVisible: false);
  }

  Future<void> stop() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {}
    if (state.isBarVisible) {
      IosNowPlayingService.clearNowPlaying();
    }
    state = state.copyWith(
      isPlaying: false,
      isLoading: false,
      currentWordOrder: 0,
      playbackProgress: 0.0,
      isBarVisible: false,
    );
  }

  void reset() {
    try {
      _player.pause();
      _player.seek(Duration.zero);
    } catch (_) {}
    state = KuranAudioState();
  }

  @override
  void dispose() {
    _wordSyncTimer?.cancel();
    _verseStopwatch.stop();
    _microInterpStopwatch.stop();
    _indexSub?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final kuranAudioNotifierProvider =
    StateNotifierProvider<KuranAudioNotifier, KuranAudioState>((ref) {
  return KuranAudioNotifier();
});
