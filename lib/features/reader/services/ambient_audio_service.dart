import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum AmbientSoundType {
  none,
  rain,
  fireplace,
  library,
  cafe,
  ney,
}

extension AmbientSoundTypeX on AmbientSoundType {
  String get title => switch (this) {
        AmbientSoundType.none => 'Kapalı',
        AmbientSoundType.rain => 'Hafif Yağmur',
        AmbientSoundType.fireplace => 'Şömine Çıtırtısı',
        AmbientSoundType.library => 'Kütüphane Ambiyansı',
        AmbientSoundType.cafe => 'Kafe Lo-Fi',
        AmbientSoundType.ney => 'Klasik Ney & Huzur',
      };

  String get icon => switch (this) {
        AmbientSoundType.none => '🔇',
        AmbientSoundType.rain => '🌧️',
        AmbientSoundType.fireplace => '🔥',
        AmbientSoundType.library => '🏛️',
        AmbientSoundType.cafe => '☕',
        AmbientSoundType.ney => '🪈',
      };
}

class AmbientAudioService {
  static final Map<AmbientSoundType, Uint8List> _wavCache = {};

  final AudioPlayer _player = AudioPlayer();
  AmbientSoundType _currentType = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isTtsDucking = false;

  AmbientSoundType get currentType => _currentType;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  AmbientAudioService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  double get _effectiveVolume => _isTtsDucking ? (_volume * 0.25) : _volume;

  Future<void> playSound(AmbientSoundType type) async {
    if (type == AmbientSoundType.none) {
      await stop();
      return;
    }

    _currentType = type;

    try {
      final wavBytes = _wavCache[type] ??= _generateProceduralWavBytes(type);
      await _player.stop();
      await _player.setVolume(_effectiveVolume);
      await _player.play(BytesSource(wavBytes));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Ambient audio error: $e');
      _isPlaying = false;
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_effectiveVolume);
    } catch (_) {}
  }

  Future<void> setTtsDucking(bool isTtsSpeaking) async {
    _isTtsDucking = isTtsSpeaking;
    try {
      await _player.setVolume(_effectiveVolume);
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

  Uint8List _generateProceduralWavBytes(AmbientSoundType type) {
    const int sampleRate = 22050;
    const int durationSeconds = 4;
    const int numSamples = sampleRate * durationSeconds;
    const int dataSize = numSamples * 2;
    final byteData = ByteData(44 + dataSize);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + dataSize, Endian.little);
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM = 1
    byteData.setUint16(22, 1, Endian.little); // Mono = 1
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, dataSize, Endian.little);

    final rng = math.Random(type.index * 9973 + 42);
    final samples = Float64List(numSamples);

    double lp1 = 0.0;
    double lp2 = 0.0;
    double brown = 0.0;
    double crackleEnv = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final white = rng.nextDouble() * 2.0 - 1.0;

      double sample = 0.0;
      switch (type) {
        case AmbientSoundType.none:
          sample = 0.0;
        case AmbientSoundType.rain:
          // Pink/brown filtered soft rain + gentle droplet modulation
          lp1 = lp1 * 0.88 + white * 0.12;
          lp2 = lp2 * 0.96 + lp1 * 0.04;
          final mod = 0.82 + 0.18 * math.sin(2.0 * math.pi * 0.5 * t);
          sample = (lp1 * 0.45 + lp2 * 0.35) * mod * 0.42;
        case AmbientSoundType.fireplace:
          // Deep warm low-pass rumble + soft crackle impulses
          brown = (brown + white * 0.04).clamp(-1.0, 1.0) * 0.992;
          if (rng.nextDouble() < 0.0018) {
            crackleEnv = 0.35 + rng.nextDouble() * 0.35;
          }
          crackleEnv *= 0.92;
          final crackle = white * crackleEnv;
          sample = brown * 0.48 + crackle * 0.28;
        case AmbientSoundType.library:
          // Very soft soothing Brownian room tone
          brown = (brown + white * 0.025).clamp(-1.0, 1.0) * 0.995;
          lp1 = lp1 * 0.97 + brown * 0.03;
          sample = lp1 * 0.32;
        case AmbientSoundType.cafe:
          // Warm mid-frequency acoustic ambiance + subtle lo-fi harmonic chord
          lp1 = lp1 * 0.93 + white * 0.07;
          lp2 = lp2 * 0.985 + lp1 * 0.015;
          final warmMurmur = (lp1 - lp2) * 0.35;
          final lofiPad = (math.sin(2.0 * math.pi * 174.0 * t) * 0.12 +
                  math.sin(2.0 * math.pi * 220.0 * t) * 0.10 +
                  math.sin(2.0 * math.pi * 261.63 * t) * 0.08 +
                  math.sin(2.0 * math.pi * 329.63 * t) * 0.06) *
              (0.85 + 0.15 * math.sin(2.0 * math.pi * 0.25 * t));
          sample = warmMurmur + lofiPad * 0.45;
        case AmbientSoundType.ney:
          // Peaceful classic Rast/Hüseyni dem drone (220Hz + 330Hz + 440Hz harmonics + breath texture)
          final vibrato = math.sin(2.0 * math.pi * 4.5 * t) * 0.8;
          final f1 = math.sin(2.0 * math.pi * (220.0 + vibrato * 0.3) * t);
          final f2 = math.sin(2.0 * math.pi * (330.0 + vibrato * 0.45) * t);
          final f3 = math.sin(2.0 * math.pi * (440.0 + vibrato * 0.6) * t);
          lp1 = lp1 * 0.92 + white * 0.08;
          final breath = lp1 * 0.06 * (0.7 + 0.3 * math.sin(2.0 * math.pi * 0.25 * t));
          final env = 0.88 + 0.12 * math.sin(2.0 * math.pi * 0.25 * t);
          sample = ((f1 * 0.48 + f2 * 0.28 + f3 * 0.14) * env + breath) * 0.36;
      }

      samples[i] = sample.clamp(-0.95, 0.95);
    }

    // Apply smooth loop crossfade on boundary (first/last 2205 samples = 100ms)
    const int fadeLen = 2205;
    for (int i = 0; i < fadeLen; i++) {
      final alpha = i / fadeLen;
      final startVal = samples[i];
      final endVal = samples[numSamples - fadeLen + i];
      final blended = startVal * alpha + endVal * (1.0 - alpha);
      samples[i] = blended;
      samples[numSamples - fadeLen + i] = endVal * alpha + startVal * (1.0 - alpha);
    }

    for (int i = 0; i < numSamples; i++) {
      final int pcm16 = (samples[i] * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
