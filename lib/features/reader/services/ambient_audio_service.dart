import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum AmbientSoundType {
  none,
  rain,
  thunderstorm,
  ney,
  fireplace,
  library,
  nightGarden,
  oceanWaves,
  forestWind,
  binauralFocus,
  cafe,
}

extension AmbientSoundTypeX on AmbientSoundType {
  String get title => switch (this) {
        AmbientSoundType.none => 'Kapalı',
        AmbientSoundType.rain => 'Pencere Önü Yağmur',
        AmbientSoundType.thunderstorm => 'Uzak Gök Gürültüsü & Sağanak',
        AmbientSoundType.ney => 'Klasik Ney & Rast Dem',
        AmbientSoundType.fireplace => 'Şömine & Sedir Çıtırtısı',
        AmbientSoundType.library => 'Beyazıt Kütüphanesi',
        AmbientSoundType.nightGarden => 'Gece Bahçesi & Şadırvan',
        AmbientSoundType.oceanWaves => 'Boğaz Dalgaları & Kıyı',
        AmbientSoundType.forestWind => 'Çam Ormanı & Rüzgar',
        AmbientSoundType.binauralFocus => 'Derin Odak (Alfa/Gamma)',
        AmbientSoundType.cafe => 'Sahaflar Çarşısı & Lo-Fi',
      };

  String get subtitle => switch (this) {
        AmbientSoundType.none => 'Sessiz okuma modu',
        AmbientSoundType.rain => 'Kadife pembe gürültü ve su damlaları',
        AmbientSoundType.thunderstorm => 'Derin bas gök gürültüsü ve sağanak',
        AmbientSoundType.ney => 'Nefes dokulu Rast/Hüseyni dem ve tanbur tınısı',
        AmbientSoundType.fireplace => 'Sıcak kor uğultusu ve doğal odun çıtırtısı',
        AmbientSoundType.library => 'Ahşap kubbe akustiği ve sarkaç saat ritmi',
        AmbientSoundType.nightGarden => 'Mermer şadırvan su akışı ve gece esintisi',
        AmbientSoundType.oceanWaves => 'Kıyıya vuran ritmik dalga döngüsü',
        AmbientSoundType.forestWind => 'Çam iğneleri arasından geçen rüzgar',
        AmbientSoundType.binauralFocus => 'Bilişsel odak sağlayan akustik kalkan',
        AmbientSoundType.cafe => 'Sıcak akustik uğultu ve yumuşak akorlar',
      };

  String get category => switch (this) {
        AmbientSoundType.none => 'Tümü',
        AmbientSoundType.rain ||
        AmbientSoundType.thunderstorm ||
        AmbientSoundType.oceanWaves ||
        AmbientSoundType.forestWind =>
          'Doğa',
        AmbientSoundType.ney ||
        AmbientSoundType.nightGarden ||
        AmbientSoundType.library =>
          'Klasik & Mekân',
        AmbientSoundType.fireplace ||
        AmbientSoundType.cafe ||
        AmbientSoundType.binauralFocus =>
          'Odak & Sıcaklık',
      };

  String get icon => switch (this) {
        AmbientSoundType.none => '🔇',
        AmbientSoundType.rain => '🌧️',
        AmbientSoundType.thunderstorm => '⛈️',
        AmbientSoundType.ney => '🪈',
        AmbientSoundType.fireplace => '🔥',
        AmbientSoundType.library => '🏛️',
        AmbientSoundType.nightGarden => '🌙',
        AmbientSoundType.oceanWaves => '🌊',
        AmbientSoundType.forestWind => '🌲',
        AmbientSoundType.binauralFocus => '🧠',
        AmbientSoundType.cafe => '☕',
      };
}

class AmbientAudioService {
  static final Map<AmbientSoundType, Uint8List> _wavCache = {};

  final AudioPlayer _primaryPlayer = AudioPlayer();
  final AudioPlayer _secondaryPlayer = AudioPlayer();

  AmbientSoundType _currentType = AmbientSoundType.none;
  AmbientSoundType _secondaryType = AmbientSoundType.none;
  double _volume = 0.55;
  double _secondaryVolume = 0.35;
  bool _isPlaying = false;
  bool _isTtsDucking = false;

  AmbientSoundType get currentType => _currentType;
  AmbientSoundType get secondaryType => _secondaryType;
  double get volume => _volume;
  double get secondaryVolume => _secondaryVolume;
  bool get isPlaying => _isPlaying;

  AmbientAudioService() {
    _primaryPlayer.setReleaseMode(ReleaseMode.loop);
    _secondaryPlayer.setReleaseMode(ReleaseMode.loop);
  }

  double get _effectivePrimaryVolume =>
      _isTtsDucking ? (_volume * 0.25) : _volume;

  double get _effectiveSecondaryVolume =>
      _isTtsDucking ? (_secondaryVolume * 0.25) : _secondaryVolume;

  Future<void> playSound(AmbientSoundType type) async {
    if (type == AmbientSoundType.none) {
      await stop();
      return;
    }

    _currentType = type;

    try {
      final wavBytes = _wavCache[type] ??=
          await compute(_synthesizeSeamlessStudioWav, type);
      await _primaryPlayer.stop();
      await _primaryPlayer.setReleaseMode(ReleaseMode.loop);
      await _primaryPlayer.setVolume(_effectivePrimaryVolume);
      await _primaryPlayer.play(BytesSource(wavBytes));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Primary ambient audio error: $e');
      _isPlaying = false;
    }
  }

  /// İkinci katman ambiyans sesi (Örn: Yağmur + Klasik Ney mikseri)
  Future<void> playSecondarySound(AmbientSoundType type) async {
    _secondaryType = type;
    if (type == AmbientSoundType.none) {
      try {
        await _secondaryPlayer.stop();
      } catch (_) {}
      return;
    }

    try {
      final wavBytes = _wavCache[type] ??=
          await compute(_synthesizeSeamlessStudioWav, type);
      await _secondaryPlayer.stop();
      await _secondaryPlayer.setReleaseMode(ReleaseMode.loop);
      await _secondaryPlayer.setVolume(_effectiveSecondaryVolume);
      await _secondaryPlayer.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('Secondary ambient audio error: $e');
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _primaryPlayer.setVolume(_effectivePrimaryVolume);
    } catch (_) {}
  }

  Future<void> setSecondaryVolume(double vol) async {
    _secondaryVolume = vol.clamp(0.0, 1.0);
    try {
      await _secondaryPlayer.setVolume(_effectiveSecondaryVolume);
    } catch (_) {}
  }

  Future<void> setTtsDucking(bool isTtsSpeaking) async {
    _isTtsDucking = isTtsSpeaking;
    try {
      await _primaryPlayer.setVolume(_effectivePrimaryVolume);
      if (_secondaryType != AmbientSoundType.none) {
        await _secondaryPlayer.setVolume(_effectiveSecondaryVolume);
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _primaryPlayer.pause();
      await _secondaryPlayer.pause();
      _isPlaying = false;
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentType != AmbientSoundType.none) {
      try {
        await _primaryPlayer.resume();
        if (_secondaryType != AmbientSoundType.none) {
          await _secondaryPlayer.resume();
        }
        _isPlaying = true;
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await _primaryPlayer.stop();
      await _secondaryPlayer.stop();
      _currentType = AmbientSoundType.none;
      _secondaryType = AmbientSoundType.none;
      _isPlaying = false;
    } catch (_) {}
  }

  /// Test ve senkron çağrılar için doğrudan erişilebilir sentezleyici
  static Uint8List generateSeamlessWavSync(AmbientSoundType type) {
    return _wavCache[type] ??= _synthesizeSeamlessStudioWav(type);
  }

  void dispose() {
    _primaryPlayer.dispose();
    _secondaryPlayer.dispose();
  }
}

/// 44.1 kHz, Paul Kellet Pembe Gürültü + Biquad Akustik Rezonatör +
/// Dairesel Eş-Güçlü (Equal-Power Circular Overlap) Kesintisiz Sonsuz Döngü Sentezleyicisi.
Uint8List _synthesizeSeamlessStudioWav(AmbientSoundType type) {
  const int sampleRate = 44100;
  const int loopSeconds = 10; // Tam periyodik faz kilidi için 10 saniye
  const int overlapSeconds = 2; // 2 saniyelik dairesel (circular) kuyruk örtüşmesi
  const int numSamples = sampleRate * loopSeconds;
  const int overlapSamples = sampleRate * overlapSeconds;
  const int totalGenerated = numSamples + overlapSamples;

  const int dataSize = numSamples * 2;
  final byteData = ByteData(44 + dataSize);

  // RIFF WAVE PCM 16-bit 44.1kHz Başlığı
  byteData.setUint8(0, 0x52); // 'R'
  byteData.setUint8(1, 0x49); // 'I'
  byteData.setUint8(2, 0x46); // 'F'
  byteData.setUint8(3, 0x46); // 'F'
  byteData.setUint32(4, 36 + dataSize, Endian.little);
  byteData.setUint8(8, 0x57); // 'W'
  byteData.setUint8(9, 0x41); // 'A'
  byteData.setUint8(10, 0x56); // 'V'
  byteData.setUint8(11, 0x45); // 'E'

  byteData.setUint8(12, 0x66); // 'f'
  byteData.setUint8(13, 0x6D); // 'm'
  byteData.setUint8(14, 0x74); // 't'
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // PCM = 1
  byteData.setUint16(22, 1, Endian.little); // Mono
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);

  byteData.setUint8(36, 0x64); // 'd'
  byteData.setUint8(37, 0x61); // 'a'
  byteData.setUint8(38, 0x74); // 't'
  byteData.setUint8(39, 0x61); // 'a'
  byteData.setUint32(40, dataSize, Endian.little);

  final rng = math.Random(type.index * 15485863 + 7919);
  final raw = Float64List(totalGenerated);

  // Paul Kellet 6-kutuplu stüdyo pembe gürültü (Pink Noise) durum değişkenleri
  double pk0 = 0.0, pk1 = 0.0, pk2 = 0.0, pk3 = 0.0, pk4 = 0.0, pk5 = 0.0, pk6 = 0.0;
  // Yumuşatıcı kademeli filtre durumları
  double lpA = 0.0, lpB = 0.0, lpC = 0.0;
  double brown = 0.0;

  // Fiziksel olay (su damlası, odun çıtırtısı, gök gürültüsü, şadırvan) zarfları
  double eventEnv1 = 0.0;
  double eventEnv2 = 0.0;
  double eventFreq1 = 800.0;
  double thunderEnv = 0.0;

  // Schroeder Comb / All-Pass akustik mekan yankı tamponu (37 ms)
  const int reverbLen = 1637;
  final reverbBuf = Float64List(reverbLen);
  int revIdx = 0;

  // Filtreleri ısıtmak için 8820 örnek (200ms) ön-koşturma (Warm-up)
  for (int w = 0; w < 8820; w++) {
    final white = rng.nextDouble() * 2.0 - 1.0;
    pk0 = 0.99886 * pk0 + white * 0.0555179;
    pk1 = 0.99332 * pk1 + white * 0.0750759;
    pk2 = 0.96900 * pk2 + white * 0.1538520;
    pk3 = 0.86650 * pk3 + white * 0.3104856;
    pk4 = 0.55000 * pk4 + white * 0.5329522;
    pk5 = -0.7616 * pk5 - white * 0.0168980;
    final pink = (pk0 + pk1 + pk2 + pk3 + pk4 + pk5 + pk6 + white * 0.5362) * 0.04;
    pk6 = white * 0.115926;
    lpA = lpA * 0.94 + pink * 0.06;
    lpB = lpB * 0.98 + lpA * 0.02;
    brown = (brown + white * 0.018).clamp(-1.0, 1.0) * 0.996;
  }

  for (int i = 0; i < totalGenerated; i++) {
    final t = i / sampleRate;
    final white = rng.nextDouble() * 2.0 - 1.0;

    // Paul Kellet Pembe Gürültü Üretimi (-3dB/oktav doğal akustik spektrum)
    pk0 = 0.99886 * pk0 + white * 0.0555179;
    pk1 = 0.99332 * pk1 + white * 0.0750759;
    pk2 = 0.96900 * pk2 + white * 0.1538520;
    pk3 = 0.86650 * pk3 + white * 0.3104856;
    pk4 = 0.55000 * pk4 + white * 0.5329522;
    pk5 = -0.7616 * pk5 - white * 0.0168980;
    final pink = (pk0 + pk1 + pk2 + pk3 + pk4 + pk5 + pk6 + white * 0.5362) * 0.045;
    pk6 = white * 0.115926;

    brown = (brown + white * 0.016).clamp(-1.0, 1.0) * 0.9965;

    double dry = 0.0;

    switch (type) {
      case AmbientSoundType.none:
        dry = 0.0;

      case AmbientSoundType.rain:
        // Kadife pencere önü yağmuru + su damlası rezonansları
        lpA = lpA * 0.91 + pink * 0.09;
        lpB = lpB * 0.975 + lpA * 0.025;
        final swell = 0.88 + 0.12 * math.sin(2.0 * math.pi * 0.2 * t);
        if (rng.nextDouble() < 0.00055) {
          eventEnv1 = 0.18 + rng.nextDouble() * 0.22;
          eventFreq1 = 650.0 + rng.nextDouble() * 750.0;
        }
        eventEnv1 *= 0.9965;
        final droplet = math.sin(2.0 * math.pi * eventFreq1 * t) * eventEnv1 * 0.12;
        dry = ((lpA * 0.58 + lpB * 0.42) * swell + droplet) * 0.72;

      case AmbientSoundType.thunderstorm:
        // Sağanak yağmur + derin bas uzak gök gürültüsü
        lpA = lpA * 0.89 + pink * 0.11;
        lpB = lpB * 0.97 + brown * 0.03;
        if (rng.nextDouble() < 0.000045) {
          thunderEnv = 0.75;
        }
        thunderEnv *= 0.99993;
        lpC = lpC * 0.994 + (brown * thunderEnv) * 0.006;
        final rumble = lpC * (0.7 + 0.3 * math.sin(2.0 * math.pi * 28.0 * t));
        dry = (lpA * 0.52 + lpB * 0.35 + rumble * 0.85) * 0.68;

      case AmbientSoundType.ney:
        // Klasik Ney & Rast/Hüseyni Dem (Tam periyodik harmonikler + nefes dokusu + tanbur dem)
        final breathLfo = 0.82 +
            0.18 * math.sin(2.0 * math.pi * 0.1 * t) +
            0.06 * math.cos(2.0 * math.pi * 0.2 * t);
        final vibrato = math.sin(2.0 * math.pi * 4.5 * t) * 0.18;
        final phase1 = 2.0 * math.pi * 220.0 * t + vibrato;
        final phase2 = 2.0 * math.pi * 330.0 * t + vibrato * 1.4;
        final phase3 = 2.0 * math.pi * 440.0 * t + vibrato * 1.8;
        final subDem = math.sin(2.0 * math.pi * 110.0 * t) * 0.24;
        final fifthDem = math.sin(2.0 * math.pi * 165.0 * t) * 0.16;

        final reedTone = math.sin(phase1) * 0.44 +
            math.sin(phase2) * 0.26 +
            math.sin(phase3) * 0.11;

        lpA = lpA * 0.94 + pink * 0.06;
        lpB = lpB * 0.985 + lpA * 0.015;
        final reedBreath = (lpA - lpB) * 0.32 * breathLfo;
        dry = ((reedTone * breathLfo) + subDem + fifthDem + reedBreath) * 0.40;

      case AmbientSoundType.fireplace:
        // Sıcak şömine kor uğultusu + sedir odunu çıtırtısı
        lpA = lpA * 0.982 + brown * 0.018;
        if (rng.nextDouble() < 0.00085) {
          eventEnv1 = 0.45 + rng.nextDouble() * 0.45;
          eventFreq1 = 1100.0 + rng.nextDouble() * 1600.0;
        }
        if (rng.nextDouble() < 0.0016) {
          eventEnv2 = 0.25 + rng.nextDouble() * 0.30;
        }
        eventEnv1 *= 0.991;
        eventEnv2 *= 0.965;
        final pop = math.sin(2.0 * math.pi * eventFreq1 * t) * eventEnv1 * 0.22;
        final crackle = pink * eventEnv2 * 0.55;
        dry = (lpA * 0.65 + pop + crackle) * 0.72;

      case AmbientSoundType.library:
        // Beyazıt Devlet Kütüphanesi: Derin ahşap kubbe sessizliği + yumuşak sarkaç saat tik-takı
        lpA = lpA * 0.988 + brown * 0.012;
        // Saniyede 1 kez çok zarif, uzak sarkaç saat tıkırtısı (1.0 Hz -> 10 sn'de tam 10 vuruş)
        final secPhase = (t * 1.0) % 1.0;
        final tickEnv = secPhase < 0.018 ? math.exp(-secPhase * 260.0) : 0.0;
        final tickTone =
            math.sin(2.0 * math.pi * 520.0 * t) * tickEnv * 0.055;
        dry = (lpA * 0.58 + tickTone) * 0.65;

      case AmbientSoundType.nightGarden:
        // Gece Bahçesi & Mermer Şadırvan Su Sesi
        lpA = lpA * 0.86 + pink * 0.14;
        lpB = lpB * 0.96 + lpA * 0.04;
        final waterStream = (lpA - lpB) * 0.52;
        if (rng.nextDouble() < 0.0012) {
          eventEnv1 = 0.28 + rng.nextDouble() * 0.25;
          eventFreq1 = 580.0 + rng.nextDouble() * 620.0;
        }
        eventEnv1 *= 0.9972;
        final fountainDrop =
            math.sin(2.0 * math.pi * eventFreq1 * t) * eventEnv1 * 0.16;
        final nightPad = (math.sin(2.0 * math.pi * 146.8 * t) * 0.10 +
                math.sin(2.0 * math.pi * 220.0 * t) * 0.08) *
            (0.85 + 0.15 * math.sin(2.0 * math.pi * 0.1 * t));
        dry = (waterStream + fountainDrop + nightPad) * 0.66;

      case AmbientSoundType.oceanWaves:
        // Boğaz Dalgaları & Kıyı (Her 5 saniyede bir kıyıya vuran ve çekilen dalga: 0.2 Hz)
        final waveCycle = 0.52 +
            0.42 * math.sin(2.0 * math.pi * 0.2 * t) +
            0.06 * math.cos(2.0 * math.pi * 0.4 * t);
        lpA = lpA * (0.985 - 0.06 * waveCycle) +
            pink * (0.015 + 0.06 * waveCycle);
        lpB = lpB * 0.992 + brown * 0.008;
        dry = (lpA * waveCycle * 0.78 + lpB * 0.35) * 0.68;

      case AmbientSoundType.forestWind:
        // Çam Ormanı & Rüzgar Esintisi
        final gust = 0.55 +
            0.30 * math.sin(2.0 * math.pi * 0.1 * t) +
            0.15 * math.sin(2.0 * math.pi * 0.3 * t);
        final alpha = (0.02 + 0.05 * gust).clamp(0.01, 0.12);
        lpA = lpA * (1.0 - alpha) + pink * alpha;
        lpB = lpB * 0.97 + lpA * 0.03;
        dry = (lpB * 0.65 + (lpA - lpB) * 0.35 * gust) * 0.72;

      case AmbientSoundType.binauralFocus:
        // Derin Odak: Kadife Brown Kalkanı + 160Hz / 200Hz / 240Hz Alfa-Gamma Uyum Akoru
        lpA = lpA * 0.99 + brown * 0.01;
        final mod = 0.88 + 0.12 * math.sin(2.0 * math.pi * 0.1 * t);
        final focusChord = (math.sin(2.0 * math.pi * 160.0 * t) * 0.22 +
                math.sin(2.0 * math.pi * 200.0 * t) * 0.18 +
                math.sin(2.0 * math.pi * 240.0 * t) * 0.14 +
                math.sin(2.0 * math.pi * 300.0 * t) * 0.08) *
            mod;
        dry = (lpA * 0.55 + focusChord * 0.45) * 0.52;

      case AmbientSoundType.cafe:
        // Sahaflar Çarşısı & Lo-Fi Sıcak Akorlar
        lpA = lpA * 0.93 + pink * 0.07;
        lpB = lpB * 0.985 + lpA * 0.015;
        final murmur = (lpA - lpB) * 0.42;
        final chordEnv = 0.82 + 0.18 * math.sin(2.0 * math.pi * 0.2 * t);
        final rhodesPad = (math.sin(2.0 * math.pi * 174.6 * t) * 0.16 +
                math.sin(2.0 * math.pi * 220.0 * t) * 0.13 +
                math.sin(2.0 * math.pi * 261.6 * t) * 0.11 +
                math.sin(2.0 * math.pi * 329.6 * t) * 0.08) *
            chordEnv;
        dry = (murmur + rhodesPad * 0.55) * 0.62;
    }

    // Doğal mekan yankısı (Schroeder Comb-Allpass difüzyonu)
    final delayed = reverbBuf[revIdx];
    final wet = dry + delayed * 0.24;
    reverbBuf[revIdx] = dry + delayed * 0.32;
    revIdx = (revIdx + 1) % reverbLen;

    raw[i] = wet.clamp(-0.92, 0.92);
  }

  // Dairesel Eş-Güçlü (Equal-Power Circular Overlap) Kesintisiz Sonsuz Döngü Sentezi:
  // [numSamples .. numSamples + overlapSamples - 1] kuyruğunu [0 .. overlapSamples - 1]
  // başlangıcı üzerine sin/cos eş-güç eğrisiyle sarar. Böylece hem N-1 -> 0 geçişi hem
  // overlap sonu %100 faz ve filtre-durumu sürekliliğine sahip olur (Sıfır Tıkırtı).
  final out = Float64List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    if (i < overlapSamples) {
      final phase = (i / overlapSamples) * (math.pi * 0.5);
      final fadeIn = math.sin(phase);
      final fadeOut = math.cos(phase);
      out[i] = raw[i] * fadeIn + raw[numSamples + i] * fadeOut;
    } else {
      out[i] = raw[i];
    }
  }

  for (int i = 0; i < numSamples; i++) {
    final int pcm16 = (out[i] * 32767.0).round().clamp(-32768, 32767);
    byteData.setInt16(44 + i * 2, pcm16, Endian.little);
  }

  return byteData.buffer.asUint8List();
}
