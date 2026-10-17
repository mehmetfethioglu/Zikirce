import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/ios_now_playing_service.dart';
import '../../../../core/services/quran_page_repository.dart';

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
  final double playbackProgress;
  final bool isBarVisible;

  KuranAudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.currentSurahId = 1,
    this.currentAyahId = 1,
    this.currentWordOrder = 0,
    this.playbackProgress = 0.0,
    this.isBarVisible = false,
  });

  KuranAudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    int? currentSurahId,
    int? currentAyahId,
    int? currentWordOrder,
    double? playbackProgress,
    bool? isBarVisible,
  }) {
    return KuranAudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentSurahId: currentSurahId ?? this.currentSurahId,
      currentAyahId: currentAyahId ?? this.currentAyahId,
      currentWordOrder: currentWordOrder ?? this.currentWordOrder,
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

  List<({int surahId, int ayahId, int pageId})> _queueVerses = [];
  int _lastIndex = -1;
  int? _activePageId;

  KuranAudioNotifier() : super(KuranAudioState()) {
    _initAudioListeners();
  }

  void _initAudioListeners() {
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null ||
          idx < 0 ||
          idx >= _queueVerses.length ||
          idx == _lastIndex) {
        return;
      }
      _lastIndex = idx;
      final item = _queueVerses[idx];
      state = state.copyWith(
        currentSurahId: item.surahId,
        currentAyahId: item.ayahId,
        currentWordOrder: 0,
        playbackProgress: 0.0,
      );
      _syncNowPlaying();

      if (idx + 1 < _queueVerses.length) {
        final next = _queueVerses[idx + 1];
        unawaited(AudioDownloadService.ensureVerseDownloaded(
          next.surahId,
          next.ayahId,
          pageId: next.pageId,
        ));
      }
    });

    _posSub = _player.positionStream.listen((pos) {
      final ms = pos.inMilliseconds.toDouble();
      final activeWord = AudioSyncService.getActiveWordOrder(
        state.currentSurahId,
        state.currentAyahId,
        ms,
      );

      final total = _player.duration?.inMilliseconds ?? 1;
      final prog = total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

      state = state.copyWith(
        currentWordOrder: activeWord,
        playbackProgress: prog,
      );
    });

    _stateSub = _player.playerStateStream.listen((pState) {
      if (pState.processingState == ProcessingState.completed) {
        if (_activePageId != null && _activePageId! < 604) {
          _advanceToNextPage(_activePageId! + 1);
        } else {
          state = state.copyWith(isPlaying: false, currentWordOrder: 0);
          IosNowPlayingService.clearNowPlaying();
        }
      } else {
        final wasPlaying = state.isPlaying;
        state = state.copyWith(
          isPlaying: pState.playing,
          isLoading: pState.processingState == ProcessingState.loading ||
              pState.processingState == ProcessingState.buffering,
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
      } else if (cmd == 'next' && _player.hasNext) {
        _player.seekToNext();
      } else if (cmd == 'previous' && _player.hasPrevious) {
        _player.seekToPrevious();
      }
    });

    await AudioSyncService.configureAudioSession();
    await IosNowPlayingService.beginTransitionTask();

    try {
      final soundsDir = await AudioDownloadService.getSoundsDirectory();
      final soundsDirPath = soundsDir.path;

      final queueItems = <({int surahId, int ayahId, int pageId})>[];
      int initialIdx = 0;

      if (pageId != null) {
        final pageData = await QuranPageRepository.getPage(pageId);
        for (int i = 0; i < pageData.quranAyats.length; i++) {
          final a = pageData.quranAyats[i];
          queueItems.add((surahId: a.sureId, ayahId: a.ayetId, pageId: pageId));
          if (a.sureId == surahId && a.ayetId == ayahId) {
            initialIdx = i;
          }
        }
      }

      if (queueItems.isEmpty) {
        queueItems.add((surahId: surahId, ayahId: ayahId, pageId: pageId ?? 1));
        initialIdx = 0;
      }

      final children = <AudioSource>[];
      for (final item in queueItems) {
        final localPath =
            '$soundsDirPath${Platform.pathSeparator}audio_${item.surahId}_${item.ayahId}.mp3';
        final localFile = File(localPath);
        if (localFile.existsSync() && localFile.lengthSync() > 1024) {
          children.add(AudioSource.file(localPath));
        } else {
          final url = useFallbackCdn
              ? AudioDownloadService.getFallbackAudioUrl(
                  item.surahId, item.ayahId)
              : AudioDownloadService.getDiyanetAudioUrl(
                  item.surahId, item.ayahId,
                  pageId: item.pageId);
          children.add(AudioSource.uri(Uri.parse(url)));
        }
      }

      _queueVerses = queueItems;
      _lastIndex = initialIdx;

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: children,
      );

      await _player.setLoopMode(LoopMode.off);
      await _player.setAudioSource(
        playlist,
        initialIndex: initialIdx,
        initialPosition: Duration.zero,
      );
      await _player.play();
      _syncNowPlaying();
      unawaited(AudioDownloadService.ensureVerseDownloaded(
        surahId,
        ayahId,
        pageId: pageId,
      ));
    } catch (e) {
      if (!useFallbackCdn) {
        await playVerse(
          surahId,
          ayahId,
          pageId: pageId,
          useFallbackCdn: true,
        );
        return;
      }
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
