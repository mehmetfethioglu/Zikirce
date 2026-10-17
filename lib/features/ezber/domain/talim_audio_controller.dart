import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/services/audio_download_service.dart';
import '../../../core/services/audio_sync_service.dart';

class TalimAudioController {
  final AudioPlayer _versePlayer = AudioPlayer();
  final AudioPlayer _wordSlicePlayer = AudioPlayer();
  final AudioPlayer _userRecordPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _lastUserRecordingPath;
  bool _isRecording = false;
  bool _isPlayingUserRecording = false;

  bool get isRecording => _isRecording;
  bool get hasUserRecording => _lastUserRecordingPath != null && File(_lastUserRecordingPath!).existsSync();
  bool get isPlayingUserRecording => _isPlayingUserRecording;
  String? get userRecordingPath => _lastUserRecordingPath;

  Stream<PlayerState> get versePlayerStateStream => _versePlayer.playerStateStream;

  TalimAudioController() {
    _userRecordPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlayingUserRecording = false;
      }
    });
  }

  /// Get the standard online audio URL for a verse
  static String getVerseAudioUrl(int surahId, int verseId, {int? pageNumber}) {
    return AudioDownloadService.getDiyanetAudioUrl(surahId, verseId, pageId: pageNumber);
  }

  /// Returns UriAudioSource prioritizing local downloaded files
  static Future<UriAudioSource> getVerseAudioSource(int surahId, int verseId, {int? pageNumber}) async {
    final localPath = await AudioDownloadService.getLocalAudioPath(surahId, verseId);
    final file = File(localPath);
    if (file.existsSync() && file.lengthSync() > 0) {
      return AudioSource.file(localPath);
    }
    final url = getVerseAudioUrl(surahId, verseId, pageNumber: pageNumber);
    return AudioSource.uri(Uri.parse(url));
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  /// Play verse audio to completion or until interrupted
  Future<void> playVerseAudio(
    int surahId,
    int verseId, {
    int? pageNumber,
    double speed = 1.0,
  }) async {
    if (_isDisposed) return;
    try {
      await stopAll();
      if (_isDisposed) return;
      final audioSource = await getVerseAudioSource(surahId, verseId, pageNumber: pageNumber);
      if (_isDisposed) return;
      await _versePlayer.setAudioSource(audioSource);
      await _versePlayer.setSpeed(speed);
      await _versePlayer.play();
    } catch (e) {
      debugPrint('[TalimAudioController] playVerseAudio Error: $e');
    }
  }

  Completer<void>? _activeWaitCompleter;
  StreamSubscription<PlayerState>? _activePlayerSub;

  /// Play verse audio and await its completion
  Future<void> playVerseAudioAndWait(
    int surahId,
    int verseId, {
    int? pageNumber,
    double speed = 1.0,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_isDisposed) return;
    try {
      await stopAll();
      if (_isDisposed) return;
      final audioSource = await getVerseAudioSource(surahId, verseId, pageNumber: pageNumber);
      if (_isDisposed) return;
      await _versePlayer.setAudioSource(audioSource);
      await _versePlayer.setSpeed(speed);

      final completer = Completer<void>();
      _activeWaitCompleter = completer;
      _activePlayerSub?.cancel();
      _activePlayerSub = _versePlayer.playerStateStream.listen((pState) {
        if (pState.processingState == ProcessingState.completed) {
          _activePlayerSub?.cancel();
          _activePlayerSub = null;
          if (!completer.isCompleted) completer.complete();
        }
      });

      await _versePlayer.play();
      await completer.future.timeout(timeout, onTimeout: () {
        _activePlayerSub?.cancel();
        _activePlayerSub = null;
        if (!completer.isCompleted) completer.complete();
      });
    } catch (e) {
      debugPrint('[TalimAudioController] playVerseAudioAndWait Error: $e');
    }
  }

  /// Plays a single word audio slice if timestamps are available, or subtle cue
  Future<void> playWordSlice(int surahId, int verseId, int wordOrder) async {
    if (_isDisposed) return;
    try {
      final timestamp = AudioSyncService.getWordTimestamp(surahId, verseId, wordOrder);
      if (timestamp != null) {
        final audioSource = await getVerseAudioSource(surahId, verseId);
        if (_isDisposed) return;
        if (_wordSlicePlayer.playing) await _wordSlicePlayer.pause();
        if (_isDisposed) return;
        await _wordSlicePlayer.setAudioSource(
          ClippingAudioSource(
            child: audioSource,
            start: Duration(milliseconds: timestamp.startTime.toInt()),
            end: Duration(milliseconds: timestamp.endTime.toInt()),
          ),
        );
        await _wordSlicePlayer.play();
      }
    } catch (e) {
      debugPrint('[TalimAudioController] playWordSlice Error: $e');
    }
  }

  /// Start recording user voice from microphone
  Future<bool> startVoiceRecording() async {
    if (_isDisposed) return false;
    try {
      await stopAll();
      if (_isDisposed) return false;
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/talim_user_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
          path: path,
        );

        _isRecording = true;
        _lastUserRecordingPath = path;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[TalimAudioController] startVoiceRecording Error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording user voice
  Future<String?> stopVoiceRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _isRecording = false;
        await AudioSyncService.configureAudioSession();
        if (path != null && File(path).existsSync()) {
          _lastUserRecordingPath = path;
        }
        return _lastUserRecordingPath;
      }
      return null;
    } catch (e) {
      debugPrint('[TalimAudioController] stopVoiceRecording Error: $e');
      _isRecording = false;
      await AudioSyncService.configureAudioSession();
      return null;
    }
  }

  /// Play or Pause user recorded audio
  Future<void> togglePlayUserRecording() async {
    if (_isDisposed) return;
    if (_lastUserRecordingPath == null || !File(_lastUserRecordingPath!).existsSync()) return;

    if (_isPlayingUserRecording) {
      await _userRecordPlayer.pause();
      _isPlayingUserRecording = false;
    } else {
      await stopAll();
      if (_isDisposed) return;
      try {
        await _userRecordPlayer.setFilePath(_lastUserRecordingPath!);
        _isPlayingUserRecording = true;
        await _userRecordPlayer.play();
      } catch (e) {
        _isPlayingUserRecording = false;
        debugPrint('[TalimAudioController] playUserRecording Error: $e');
      }
    }
  }

  /// Stop all active audio streams
  Future<void> stopAll() async {
    try {
      _activePlayerSub?.cancel();
      _activePlayerSub = null;
      if (_activeWaitCompleter != null && !_activeWaitCompleter!.isCompleted) {
        _activeWaitCompleter!.complete();
        _activeWaitCompleter = null;
      }
      if (_versePlayer.playing) await _versePlayer.pause();
      if (_wordSlicePlayer.playing) await _wordSlicePlayer.pause();
      if (_userRecordPlayer.playing) await _userRecordPlayer.pause();
      if (_isRecording) await _audioRecorder.stop();
      _isRecording = false;
      _isPlayingUserRecording = false;
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    _activePlayerSub?.cancel();
    _activePlayerSub = null;
    if (_activeWaitCompleter != null && !_activeWaitCompleter!.isCompleted) {
      _activeWaitCompleter!.complete();
      _activeWaitCompleter = null;
    }
    _isRecording = false;
    _isPlayingUserRecording = false;
    _versePlayer.dispose();
    _wordSlicePlayer.dispose();
    _userRecordPlayer.dispose();
    _audioRecorder.dispose();
  }
}
