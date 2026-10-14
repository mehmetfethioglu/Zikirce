import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum AmbientSoundType {
  none,
  rain,       // Yağmur
  fireplace,  // Şömine çıtırtısı
  library,    // Kütüphane sessizliği
  cafe,       // Kafe lo-fi
}

extension AmbientSoundTypeX on AmbientSoundType {
  String get title => switch (this) {
        AmbientSoundType.none => 'Kapalı',
        AmbientSoundType.rain => 'Hafif Yağmur',
        AmbientSoundType.fireplace => 'Şömine Çıtırtısı',
        AmbientSoundType.library => 'Kütüphane Ambiyansı',
        AmbientSoundType.cafe => 'Kafe Lo-Fi',
      };

  String get icon => switch (this) {
        AmbientSoundType.none => '🔇',
        AmbientSoundType.rain => '🌧️',
        AmbientSoundType.fireplace => '🔥',
        AmbientSoundType.library => '🏛️',
        AmbientSoundType.cafe => '☕',
      };

  String? get streamUrl => switch (this) {
        AmbientSoundType.none => null,
        AmbientSoundType.rain => 'https://actions.google.com/sounds/v1/weather/rain_heavy.ogg',
        AmbientSoundType.fireplace => 'https://actions.google.com/sounds/v1/ambiences/fireplace.ogg',
        AmbientSoundType.library => 'https://actions.google.com/sounds/v1/ambiences/room_tone.ogg',
        AmbientSoundType.cafe => 'https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
      };
}

class AmbientAudioService {
  final AudioPlayer _player = AudioPlayer();
  AmbientSoundType _currentType = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;

  AmbientSoundType get currentType => _currentType;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  AmbientAudioService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playSound(AmbientSoundType type) async {
    if (type == AmbientSoundType.none) {
      await stop();
      return;
    }

    _currentType = type;
    final url = type.streamUrl;
    if (url == null) return;

    try {
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(UrlSource(url));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Ambient audio error: $e');
      _isPlaying = false;
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentType != AmbientSoundType.none) {
      try {
        await _player.resume();
        _isPlaying = true;
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentType = AmbientSoundType.none;
      _isPlaying = false;
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
