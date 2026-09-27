import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../constants/asset_constants.dart';

class SoundPoolService {
  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _bulbulPlayer = AudioPlayer();
  static final AudioPlayer _kumruPlayer = AudioPlayer();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      await _bulbulPlayer.setAsset(AppAssets.audioBulbul).catchError((e) {
        debugPrint('[SoundPoolService] Audio asset preload warning: $e');
        return null;
      });
      await _kumruPlayer.setAsset(AppAssets.audioKumru).catchError((e) {
        debugPrint('[SoundPoolService] Audio asset preload warning: $e');
        return null;
      });
      debugPrint('[SoundPoolService] Audio assets preloaded successfully.');
    } catch (e) {
      debugPrint('[SoundPoolService] Audio asset preload warning: $e');
    }
  }

  static DateTime _lastCounterSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Play bird chirp or counter sound (bulbul or kumru) on dhikr counter tap
  static Future<void> playCounterSound({String soundName = 'bulbul'}) async {
    final now = DateTime.now();
    // Protect ExoPlayer native queues from overflow during rapid consecutive tapping
    if (now.difference(_lastCounterSoundTime).inMilliseconds < 45) {
      return;
    }
    _lastCounterSoundTime = now;

    try {
      if (!_isInitialized) {
        await initialize();
      }
      final lower = soundName.toLowerCase();
      if (lower.contains('kumru')) {
        if (_kumruPlayer.playing) {
          await _kumruPlayer.stop();
        }
        await _kumruPlayer.seek(Duration.zero);
        await _kumruPlayer.play();
      } else {
        if (_bulbulPlayer.playing) {
          await _bulbulPlayer.stop();
        }
        await _bulbulPlayer.seek(Duration.zero);
        await _bulbulPlayer.play();
      }
    } catch (e) {
      debugPrint('[SoundPoolService] playCounterSound error: $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
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
        await _bulbulPlayer.seek(Duration.zero);
        await _bulbulPlayer.play();
      } else if (lower.contains('kumru')) {
        await _kumruPlayer.seek(Duration.zero);
        await _kumruPlayer.play();
      } else if (lower.contains('sessiz') || lower.contains('none')) {
        // Mute
      } else {
        await playCounterSound();
      }
    } catch (e) {
      debugPrint('[SoundPoolService] playSoundByName error ($nameOrFile): $e');
    }
  }

  static void dispose() {
    _clickPlayer.dispose();
    _bulbulPlayer.dispose();
    _kumruPlayer.dispose();
  }
}
