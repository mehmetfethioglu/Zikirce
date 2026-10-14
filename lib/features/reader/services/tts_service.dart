import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

class TtsProgress {
  final String currentWord;
  final int startOffset;
  final int endOffset;

  TtsProgress({
    required this.currentWord,
    required this.startOffset,
    required this.endOffset,
  });
}

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;
  void Function(TtsProgress)? onWordProgress;
  void Function(TtsState)? onStateChanged;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('tr-TR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
        onWordProgress?.call(TtsProgress(
          currentWord: word,
          startOffset: startOffset,
          endOffset: endOffset,
        ));
      });

      _flutterTts.setStartHandler(() {
        _state = TtsState.playing;
        onStateChanged?.call(_state);
      });

      _flutterTts.setCompletionHandler(() {
        _state = TtsState.stopped;
        onStateChanged?.call(_state);
      });

      _flutterTts.setPauseHandler(() {
        _state = TtsState.paused;
        onStateChanged?.call(_state);
      });

      _flutterTts.setContinueHandler(() {
        _state = TtsState.playing;
        onStateChanged?.call(_state);
      });

      _flutterTts.setErrorHandler((msg) {
        _state = TtsState.stopped;
        onStateChanged?.call(_state);
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _flutterTts.speak(text);
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _state = TtsState.paused;
      onStateChanged?.call(_state);
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      _state = TtsState.playing;
      onStateChanged?.call(_state);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    try {
      await _flutterTts.setSpeechRate(rate.clamp(0.2, 1.0));
    } catch (_) {}
  }

  void dispose() {
    _flutterTts.stop();
  }
}
