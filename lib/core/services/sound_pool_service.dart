import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../constants/asset_constants.dart';

class SoundPoolService {
  static final AudioPlayer _bulbulPlayer = AudioPlayer();
  static final AudioPlayer _kumruPlayer = AudioPlayer();
  static Future<void>? _initFuture;
  static DateTime _lastCounterSoundTime = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _isPlaybackBusy = false;

  static Future<void> initialize() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    try {
      await Future.wait([
        _bulbulPlayer.setAsset(AppAssets.audioBulbul).catchError((e) {
          debugPrint('[SoundPoolService] Audio asset preload warning: $e');
          return null;
        }),
        _kumruPlayer.setAsset(AppAssets.audioKumru).catchError((e) {
          debugPrint('[SoundPoolService] Audio asset preload warning: $e');
          return null;
        }),
      ]);
      debugPrint('[SoundPoolService] Audio assets preloaded successfully.');
    } catch (e) {
      debugPrint('[SoundPoolService] Audio asset preload warning: $e');
    }
  }

  /// Play bird chirp or counter sound (bulbul or kumru) on dhikr counter tap
  static Future<void> playCounterSound({String soundName = 'bulbul'}) async {
    final now = DateTime.now();
    // Protect ExoPlayer native queues from overflow during rapid consecutive tapping
    if (now.difference(_lastCounterSoundTime).inMilliseconds < 60) {
      return;
    }
    _lastCounterSoundTime = now;

    if (_isPlaybackBusy) return;
    _isPlaybackBusy = true;

    try {
      if (_initFuture == null) {
        await initialize();
      }
      final lower = soundName.toLowerCase();
      final player = lower.contains('kumru') ? _kumruPlayer : _bulbulPlayer;
      await _safePlay(player);
    } catch (e) {
      debugPrint('[SoundPoolService] playCounterSound error: $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    } finally {
      _isPlaybackBusy = false;
    }
  }

  /// Play bird chirp sound (bulbul or kumru) on dhikr completion
  static Future<void> playChirp({String type = 'bulbul'}) async {
    try {
      await playCounterSound(soundName: type);
    } catch (_) {}
  }

  /// Play sound preview or sound effect by name or filename
  static Future<void> playSoundByName(String nameOrFile) async {
    try {
      final lower = nameOrFile.toLowerCase();
      if (lower.contains('bulbul') || lower.contains('bülbül')) {
        await _safePlay(_bulbulPlayer);
      } else if (lower.contains('kumru')) {
        await _safePlay(_kumruPlayer);
      } else if (lower.contains('sessiz') || lower.contains('none')) {
        // Mute
      } else {
        await playCounterSound();
      }
    } catch (e) {
      debugPrint('[SoundPoolService] playSoundByName error ($nameOrFile): $e');
    }
  }

  /// Safely rewinds and plays sound effect without tearing down native ExoPlayer decoders.
  /// Calling stop() in just_audio deallocates native platform decoders asynchronously,
  /// leading to "Platform player <id> already exists" if play() is invoked before disposal finishes.
  static Future<void> _safePlay(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      if (!player.playing) {
        await player.play();
      }
    } catch (e) {
      debugPrint('[SoundPoolService] Audio playback warning: $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static void dispose() {
    _bulbulPlayer.dispose();
    _kumruPlayer.dispose();
  }
}
