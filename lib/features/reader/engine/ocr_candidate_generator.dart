import 'dart:math' as math;

import 'turkish_morphology.dart';

/// Sözlükle doğrulanmış OCR düzeltme adayı.
class OcrVerifiedCandidate {
  final String word;

  /// Toplam OCR karışıklık maliyeti (düşük = daha olası).
  final double cost;

  const OcrVerifiedCandidate(this.word, this.cost);

  @override
  String toString() => '$word(${cost.toStringAsFixed(2)})';
}

/// Otomatik düzeltme kararı: en iyi aday ve ikinci adaya göre güven farkı.
class OcrCorrectionDecision {
  final List<OcrVerifiedCandidate> candidates;

  const OcrCorrectionDecision(this.candidates);

  OcrVerifiedCandidate? get best => candidates.isEmpty ? null : candidates.first;

  /// En iyi adayla ikinci aday arasındaki maliyet farkı (tek aday varsa sonsuz).
  double get margin => candidates.length < 2
      ? double.infinity
      : candidates[1].cost - candidates[0].cost;

  /// Kesin (tartışmasız) düzeltme: düşük maliyetli ve rakipsiz tek aday.
  /// Tek bir nokta/çengel kaybının onarımı (maliyet ≤ 0.2) daha düşük farkla da kabul edilir.
  bool isDecisive({double maxCost = 0.55, double minMargin = 0.2}) {
    final b = best;
    if (b == null || b.cost > maxCost) return false;
    if (b.cost <= 0.2 && margin >= 0.1) return true;
    return margin >= minMargin;
  }
}

/// "Üret ve doğrula" (generate-and-test) tabanlı OCR aday üreticisi.
///
/// Bozuk kelimeye OCR'ın tipik görsel karışıklıklarını (ı↔i↔l↔1, c↔ç, s↔ş, g↔ğ,
/// o↔ö, u↔ü, rn↔m, cl↔d, rı/ri↔n, lı/li↔h, ın/in↔m, ii↔ü, düşen ünlü, fazladan
/// harf, yer değiştirme) uygular ve yalnızca [TurkishMorphology] tarafından geçerli
/// kabul edilen biçimleri aday olarak döndürür. Böylece sözlükte olmayan bir
/// "düzeltme" asla üretilmez.
abstract final class OcrCandidateGenerator {
  static const String _vowels = 'aeıioöuüâîû';

  /// Tek karakter yer değiştirmeleri ve OCR görsel benzerlik maliyetleri.
  static const Map<String, List<(String, double)>> _substitutions = {
    'ı': [('i', 0.20), ('l', 0.35), ('t', 0.6)],
    'i': [('ı', 0.20), ('l', 0.35), ('j', 0.6)],
    'l': [('i', 0.35), ('ı', 0.35), ('t', 0.55), ('k', 0.6)],
    'c': [('ç', 0.20), ('e', 0.45), ('a', 0.50), ('o', 0.6)],
    'ç': [('c', 0.25), ('ş', 0.5)],
    'g': [('ğ', 0.20), ('k', 0.45), ('q', 0.6)],
    'ğ': [('g', 0.30)],
    'o': [('ö', 0.20), ('c', 0.6), ('e', 0.6), ('a', 0.6)],
    'ö': [('o', 0.30)],
    'u': [('ü', 0.20), ('n', 0.5), ('a', 0.6)],
    'ü': [('u', 0.30), ('ii', 0.5)],
    'a': [('e', 0.55), ('o', 0.6)],
    'e': [('a', 0.55), ('c', 0.55), ('o', 0.6)],
    'n': [('u', 0.50), ('m', 0.55), ('r', 0.6), ('h', 0.6)],
    'm': [('n', 0.55), ('rn', 0.45), ('ın', 0.40), ('in', 0.40), ('un', 0.42), ('ün', 0.42)],
    'h': [('b', 0.50), ('k', 0.50), ('lı', 0.40), ('li', 0.40), ('n', 0.6)],
    'b': [('h', 0.50), ('p', 0.40), ('d', 0.55)],
    'p': [('b', 0.40)],
    'd': [('t', 0.35), ('b', 0.55), ('cl', 0.50)],
    't': [('d', 0.40), ('l', 0.50), ('f', 0.50), ('ı', 0.6)],
    'f': [('t', 0.50)],
    'r': [('t', 0.60), ('n', 0.6)],
    'y': [('v', 0.50)],
    'v': [('y', 0.50)],
    'k': [('h', 0.50), ('g', 0.50), ('l', 0.6)],
    's': [('ş', 0.20), ('z', 0.50)],
    'z': [('s', 0.45)],
    '1': [('ı', 0.15), ('i', 0.15), ('l', 0.25)],
    '0': [('o', 0.15)],
    '5': [('s', 0.25)],
    '8': [('b', 0.35)],
  };

  /// Çok karakterli OCR kaynaşmaları (bozuk → doğru).
  static const List<(String, String, double)> _multiCharFusions = [
    ('rn', 'm', 0.30),
    ('cl', 'd', 0.30),
    ('ii', 'ü', 0.30),
    ('ıi', 'ü', 0.30),
    ('iı', 'ü', 0.40),
    ('ıı', 'ü', 0.42),
    ('lı', 'h', 0.45),
    ('li', 'h', 0.45),
    ('ın', 'm', 0.45),
    ('in', 'm', 0.45),
    ('nm', 'nın', 0.36),
    ('nm', 'nin', 0.36),
    ('nm', 'nun', 0.40),
    ('nm', 'nün', 0.40),
    ('nn', 'nın', 0.38),
    ('nn', 'nin', 0.38),
    ('nn', 'nun', 0.40),
    ('nn', 'nün', 0.40),
    ('larm', 'ların', 0.32),
    ('lerm', 'lerin', 0.32),
    ('masl', 'ması', 0.30),
    ('mesl', 'mesi', 0.30),
    ('n', 'rı', 0.40),
    ('n', 'ri', 0.40),
    ('n', 'ru', 0.50),
    ('n', 'rü', 0.50),
    ('nn', 'rın', 0.45),
    ('nn', 'rin', 0.45),
    ('vv', 'w', 0.6),
  ];

  /// Diyakritik (nokta/çengel/şapka) kayıpları — birlikte çoklu uygulanabilir.
  static const Map<String, List<String>> _diacritics = {
    'c': ['ç'],
    'ç': ['c'],
    's': ['ş'],
    'ş': ['s'],
    'g': ['ğ'],
    'ğ': ['g'],
    'o': ['ö'],
    'ö': ['o'],
    'u': ['ü'],
    'ü': ['u'],
    'i': ['ı'],
    'ı': ['i'],
  };

  static final Map<String, OcrCorrectionDecision> _cache = {};

  /// Dinamik sözlük değişikliği sonrası aday karar önbelleğini temizler.
  static void clearCache() => _cache.clear();

  /// Bozuk kelime için sözlük doğrulamalı adayları maliyet sırasıyla döndürür.
  ///
  /// [pageVocabulary]: aynı sayfada/kitapta geçen kelimelerin frekansı; sayfada zaten
  /// doğru yazılmış hâli bulunan adaylar öne alınır.
  static OcrCorrectionDecision decide(
    String rawWord, {
    Map<String, int>? pageVocabulary,
    int maxResults = 5,
  }) {
    final lower = _toLower(rawWord);
    if (lower.length < 2 || lower.length > 30) {
      return const OcrCorrectionDecision([]);
    }
    final cacheKey = pageVocabulary == null ? lower : '';
    if (cacheKey.isNotEmpty) {
      final cached = _cache[cacheKey];
      if (cached != null) return cached;
    }

    final found = <String, double>{};
    int budget = 2500;

    void consider(String cand, double cost) {
      if (cand == lower || cand.length < 2) return;
      final prev = found[cand];
      if (prev != null && prev <= cost) return;
      if (budget-- <= 0) return;
      if (TurkishMorphology.isKnownWord(cand)) {
        found[cand] = cost;
      }
    }

    // 1) Yalnızca diyakritik kayıpları (aynı anda en fazla 4 konum)
    for (final v in _diacriticVariants(lower, maxChanges: 4)) {
      consider(v.$1, v.$2);
    }

    // 2) Tek işlemli varyantlar (+ ardından diyakritik genişletme)
    final level1 = _singleEdits(lower);
    for (final e in level1) {
      consider(e.$1, e.$2);
      if (e.$2 <= 0.6) {
        for (final d in _diacriticVariants(e.$1, maxChanges: 2)) {
          consider(d.$1, e.$2 + d.$2);
        }
      }
    }

    // 3) Ucuz bir aday bulunamadıysa iki işlemli varyantlar
    final bestSoFar = found.values.isEmpty ? 99.0 : found.values.reduce(math.min);
    if (bestSoFar > 0.5 && lower.length <= 16) {
      for (final e in level1) {
        if (e.$2 > 0.55) continue;
        for (final e2 in _singleEdits(e.$1)) {
          if (e.$2 + e2.$2 > 1.1) continue;
          consider(e2.$1, e.$2 + e2.$2);
        }
        if (budget <= 0) break;
      }
    }

    final scored = <OcrVerifiedCandidate>[];
    for (final entry in found.entries) {
      var cost = entry.value;
      final freq = pageVocabulary?[entry.key] ?? 0;
      if (freq > 0) cost -= 0.12 * math.min(freq, 3);
      // Uzunluk farkı arttıkça hafif ceza (aşırı ekleme/silmeyi caydırır)
      cost += 0.04 * (entry.key.length - lower.length).abs();
      scored.add(OcrVerifiedCandidate(entry.key, cost));
    }
    scored.sort((a, b) {
      final c = a.cost.compareTo(b.cost);
      return c != 0 ? c : a.word.compareTo(b.word);
    });

    final decision = OcrCorrectionDecision(scored.take(maxResults).toList());
    if (cacheKey.isNotEmpty) {
      if (_cache.length > 4000) _cache.clear();
      _cache[cacheKey] = decision;
    }
    return decision;
  }

  static List<(String, double)> _singleEdits(String w) {
    final out = <(String, double)>[];

    // Tek karakter yer değiştirme
    for (int i = 0; i < w.length; i++) {
      final subs = _substitutions[w[i]];
      if (subs == null) continue;
      for (final s in subs) {
        out.add(('${w.substring(0, i)}${s.$1}${w.substring(i + 1)}', s.$2));
      }
    }

    // Çok karakterli kaynaşmalar
    for (final f in _multiCharFusions) {
      int idx = w.indexOf(f.$1);
      while (idx >= 0) {
        out.add(('${w.substring(0, idx)}${f.$2}${w.substring(idx + f.$1.length)}', f.$3));
        idx = w.indexOf(f.$1, idx + 1);
      }
    }

    // Düşen dar/geniş ünlüyü geri ekle (iki ünsüz arasına veya kelime sonundaki ünsüzden önce)
    for (int i = 1; i <= w.length; i++) {
      final left = w[i - 1];
      final right = i < w.length ? w[i] : '';
      final leftIsCons = !_vowels.contains(left);
      final rightIsCons = right.isEmpty || !_vowels.contains(right);
      if (!leftIsCons || !rightIsCons) continue;
      for (final v in const ['ı', 'i', 'u', 'ü', 'a', 'e']) {
        out.add(('${w.substring(0, i)}$v${w.substring(i)}', right.isEmpty ? 0.55 : 0.5));
      }
    }
    // Kelime başında düşen ünlü (ilk iki harf ünsüz)
    if (w.length >= 3 && !_vowels.contains(w[0]) && !_vowels.contains(w[1])) {
      for (final v in const ['ı', 'i', 'u', 'ü', 'a', 'e']) {
        out.add(('${w[0]}$v${w.substring(1)}', 0.45));
      }
    }

    // Fazladan harf (gürültü) silme — çift harf silmek daha ucuz
    for (int i = 0; i < w.length; i++) {
      final doubled = (i > 0 && w[i - 1] == w[i]);
      out.add(('${w.substring(0, i)}${w.substring(i + 1)}', doubled ? 0.4 : 0.65));
    }

    // Komşu harflerin yer değiştirmesi
    for (int i = 0; i + 1 < w.length; i++) {
      if (w[i] == w[i + 1]) continue;
      out.add(('${w.substring(0, i)}${w[i + 1]}${w[i]}${w.substring(i + 2)}', 0.6));
    }

    return out;
  }

  static Iterable<(String, double)> _diacriticVariants(String w, {required int maxChanges}) sync* {
    final positions = <int>[];
    for (int i = 0; i < w.length; i++) {
      if (_diacritics.containsKey(w[i])) positions.add(i);
    }
    if (positions.isEmpty) return;
    final limit = math.min(positions.length, 10);
    final chars = w.split('');
    int emitted = 0;

    Iterable<(String, double)> rec(int start, int changes, double cost) sync* {
      for (int p = start; p < limit; p++) {
        final i = positions[p];
        final original = chars[i];
        for (final alt in _diacritics[original]!) {
          chars[i] = alt;
          final c = cost + 0.15;
          yield (chars.join(), c);
          if (changes + 1 < maxChanges) {
            yield* rec(p + 1, changes + 1, c);
          }
          chars[i] = original;
        }
      }
    }

    for (final v in rec(0, 0, 0)) {
      if (emitted++ > 400) return;
      yield v;
    }
  }

  static String _toLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Â', 'â')
        .replaceAll('Î', 'î')
        .replaceAll('Û', 'û')
        .toLowerCase();
  }
}
