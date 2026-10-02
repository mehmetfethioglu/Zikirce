import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
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

  KuranAudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.currentSurahId = 1,
    this.currentAyahId = 1,
    this.currentWordOrder = 0,
    this.playbackProgress = 0.0,
  });

  KuranAudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    int? currentSurahId,
    int? currentAyahId,
    int? currentWordOrder,
    double? playbackProgress,
  }) {
    return KuranAudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentSurahId: currentSurahId ?? this.currentSurahId,
      currentAyahId: currentAyahId ?? this.currentAyahId,
      currentWordOrder: currentWordOrder ?? this.currentWordOrder,
      playbackProgress: playbackProgress ?? this.playbackProgress,
    );
  }
}

class KuranAudioNotifier extends StateNotifier<KuranAudioState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  KuranAudioNotifier() : super(KuranAudioState()) {
    _initAudioListeners();
  }

  void _initAudioListeners() {
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
        // Auto play next verse if needed
        state = state.copyWith(isPlaying: false, currentWordOrder: 0);
      } else {
        state = state.copyWith(
          isPlaying: pState.playing,
          isLoading: pState.processingState == ProcessingState.loading ||
              pState.processingState == ProcessingState.buffering,
        );
      }
    });
  }

  Future<void> playVerse(int surahId, int ayahId, {int? pageId}) async {
    state = state.copyWith(
      currentSurahId: surahId,
      currentAyahId: ayahId,
      isLoading: true,
      currentWordOrder: 0,
    );

    try {
      final localPath = await AudioDownloadService.getLocalAudioPath(surahId, ayahId);
      final localFile = File(localPath);

      if (localFile.existsSync() && localFile.lengthSync() > 0) {
        await _player.setFilePath(localPath);
      } else {
        // Stream directly from Diyanet CDN
        final diyanetUrl = AudioDownloadService.getDiyanetAudioUrl(surahId, ayahId, pageId: pageId);
        try {
          await _player.setUrl(diyanetUrl);
          // Trigger background caching for offline use
          unawaited(AudioDownloadService.ensureVerseDownloaded(surahId, ayahId, pageId: pageId));
        } catch (_) {
          // Fallback to EveryAyah Alafasy
          final fallbackUrl = AudioDownloadService.getFallbackAudioUrl(surahId, ayahId);
          await _player.setUrl(fallbackUrl);
        }
      }
      await _player.play();
    } catch (e) {
      state = state.copyWith(isPlaying: false, isLoading: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void syncExternalState(KuranAudioState newState) {
    state = newState;
  }

  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    state = state.copyWith(isPlaying: false, currentWordOrder: 0);
  }

  @override
  void dispose() {
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
