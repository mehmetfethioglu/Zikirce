import 'turkish_lexicon_data.dart';

/// Biçimbirimsel kategori: isim soylu gövde, fiil gövdesi, çekimli (yüklem) form.
enum _Cat { n, v, f, any }

/// Ek şablonu. Şablon harfleri:
/// - `A` → a/e (büyük ünlü uyumu), `I` → ı/i/u/ü (küçük ünlü uyumu)
/// - `D` → d/t, `C` → c/ç (sertleşme)
/// - `(x)` → kaynaştırma: ünsüzse yalnızca ünlüyle biten gövdeden sonra,
///   ünlüyse yalnızca ünsüzle biten gövdeden sonra gerçekleşir.
/// - Küçük harfler sabittir (`ki`, `yor`, `ken` …).
class _Suffix {
  final String template;
  final _Cat inner;
  final _Cat outer;

  /// Ekin dizilimdeki katmanı (0 yapım, 1 çokluk, 2 iyelik, 3 hâl, 5 çekim/kişi, 9 zarf-fiil).
  final int tier;

  /// Bu ekin içinde (soluna) gelebilecek en yüksek katman.
  final int innerMax;

  const _Suffix(this.template, this.inner, this.outer, this.tier, this.innerMax);
}

/// Zemberek-NLP sözlüğü (Apache 2.0) üzerine kurulu, tamamen çevrimdışı çalışan
/// Türkçe biçimbilim doğrulayıcısı.
///
/// Bir kelimenin geçerli bir Türkçe kök + ek dizilimi olup olmadığını; ünlü uyumu,
/// ünsüz sertleşmesi, kaynaştırma harfleri, ünsüz yumuşaması, ünlü düşmesi ve ek
/// sırası (yapım → çokluk → iyelik → hâl → ek-fiil/kişi) kurallarıyla denetler.
/// OCR tashih motoru bu sınıfı "doğruluk kâhini" olarak kullanır: geçerli kelimeler
/// asla değiştirilmez, geçersiz kelimeler için üretilen adaylar burada doğrulanır.
abstract final class TurkishMorphology {
  static Set<String>? _nouns;
  static Set<String>? _verbs;
  static Set<String>? _boundNominal;
  static Set<String>? _boundVerbal;
  static Set<String>? _voicedNominal;
  static Set<String>? _inverseHarmony;
  static final Set<String> _extraWords = <String>{};
  static final Map<String, bool> _memo = <String, bool>{};
  static final Map<String, bool> _wordCache = <String, bool>{};

  static const String _vowels = 'aeıioöuüâîû';
  static const String _backVowels = 'aıouâû';
  static const String _roundedVowels = 'oöuüû';
  static const String _voiceless = 'çfhkpsşt';

  static const Set<String> _copulaForms = <String>{
    'idi', 'idim', 'idin', 'idik', 'idiniz', 'idiler',
    'imiş', 'imişim', 'imişsin', 'imişiz', 'imişsiniz', 'imişler',
    'ise', 'isem', 'isen', 'isek', 'iseniz', 'iseler',
    'iken',
  };

  static const List<_Suffix> _suffixes = [
    // ── İsimden isim yapım ekleri (katman 0) ──
    _Suffix('lIk', _Cat.n, _Cat.n, 0, 0),
    _Suffix('lIğ', _Cat.n, _Cat.n, 0, 0),
    _Suffix('lI', _Cat.n, _Cat.n, 0, 0),
    _Suffix('sIz', _Cat.n, _Cat.n, 0, 0),
    _Suffix('CI', _Cat.n, _Cat.n, 0, 0),
    _Suffix('CIk', _Cat.n, _Cat.n, 0, 0),
    _Suffix('CIğ', _Cat.n, _Cat.n, 0, 0),
    _Suffix('DAş', _Cat.n, _Cat.n, 0, 0),
    _Suffix('sAl', _Cat.n, _Cat.n, 0, 0),
    _Suffix('(I)ncI', _Cat.n, _Cat.n, 0, 0),
    _Suffix('(ş)Ar', _Cat.n, _Cat.n, 0, 0),
    _Suffix('(I)msI', _Cat.n, _Cat.n, 0, 0),
    _Suffix('ki', _Cat.n, _Cat.n, 0, 3),
    _Suffix('kü', _Cat.n, _Cat.n, 0, 3),
    // ── İsimden fiil yapım ekleri (katman 0) ──
    _Suffix('lAş', _Cat.n, _Cat.v, 0, 0),
    // ── Çokluk (1), iyelik (2), hâl (3) ──
    _Suffix('lAr', _Cat.n, _Cat.n, 1, 0),
    _Suffix('(I)m', _Cat.n, _Cat.n, 2, 1),
    _Suffix('(I)n', _Cat.n, _Cat.n, 2, 1),
    _Suffix('(s)I', _Cat.n, _Cat.n, 2, 1),
    _Suffix('(I)mIz', _Cat.n, _Cat.n, 2, 1),
    _Suffix('(I)nIz', _Cat.n, _Cat.n, 2, 1),
    _Suffix('lArI', _Cat.n, _Cat.n, 2, 0),
    _Suffix('(y)I', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(n)I', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(y)A', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(n)A', _Cat.n, _Cat.n, 3, 2),
    _Suffix('DA', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(n)DA', _Cat.n, _Cat.n, 3, 2),
    _Suffix('DAn', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(n)DAn', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(n)In', _Cat.n, _Cat.n, 3, 2),
    _Suffix('(y)lA', _Cat.n, _Cat.n, 3, 2),
    _Suffix('CA', _Cat.n, _Cat.n, 3, 2),
    _Suffix('CAsInA', _Cat.n, _Cat.n, 3, 2),
    // ── İsim + ek-fiil / kişi (yüklem) ──
    _Suffix('DIr', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)DI', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)mIş', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)sA', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)ken', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)Im', _Cat.n, _Cat.f, 5, 3),
    _Suffix('sIn', _Cat.n, _Cat.f, 5, 3),
    _Suffix('(y)Iz', _Cat.n, _Cat.f, 5, 3),
    _Suffix('sInIz', _Cat.n, _Cat.f, 5, 3),
    // ── Fiilden fiil: çatı, olumsuzluk, yeterlik (katman 0) ──
    _Suffix('Il', _Cat.v, _Cat.v, 0, 0),
    _Suffix('In', _Cat.v, _Cat.v, 0, 0),
    _Suffix('(n)', _Cat.v, _Cat.v, 0, 0),
    _Suffix('Iş', _Cat.v, _Cat.v, 0, 0),
    _Suffix('DIr', _Cat.v, _Cat.v, 0, 0),
    _Suffix('(t)', _Cat.v, _Cat.v, 0, 0),
    _Suffix('mA', _Cat.v, _Cat.v, 1, 1),
    _Suffix('(y)AmA', _Cat.v, _Cat.v, 1, 1),
    _Suffix('(y)Abil', _Cat.v, _Cat.v, 1, 1),
    _Suffix('(y)Iver', _Cat.v, _Cat.v, 1, 1),
    _Suffix('(y)Agel', _Cat.v, _Cat.v, 1, 1),
    // ── Fiil çekimi: kip ve zaman (çekimli forma geçiş) ──
    _Suffix('(I)yor', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)AcAk', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)AcAğ', _Cat.v, _Cat.f, 5, 1),
    _Suffix('Ar', _Cat.v, _Cat.f, 5, 1),
    _Suffix('Ir', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(r)', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mAz', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mAm', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mAyIz', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mIş', _Cat.v, _Cat.f, 5, 1),
    _Suffix('DI', _Cat.v, _Cat.f, 5, 1),
    _Suffix('sA', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mAlI', _Cat.v, _Cat.f, 5, 1),
    _Suffix('mAktA', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)A', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)AlIm', _Cat.v, _Cat.f, 5, 1),
    _Suffix('sIn', _Cat.v, _Cat.f, 5, 1),
    _Suffix('sInlAr', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)In', _Cat.v, _Cat.f, 5, 1),
    _Suffix('(y)InIz', _Cat.v, _Cat.f, 5, 1),
    // ── Çekimli form + kişi / ek-fiil ──
    _Suffix('(y)Im', _Cat.f, _Cat.f, 5, 5),
    _Suffix('sIn', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(y)Iz', _Cat.f, _Cat.f, 5, 5),
    _Suffix('sInIz', _Cat.f, _Cat.f, 5, 5),
    _Suffix('lAr', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(m)', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(n)', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(k)', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(n)Iz', _Cat.f, _Cat.f, 5, 5),
    _Suffix('DIr', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(y)DI', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(y)mIş', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(y)sA', _Cat.f, _Cat.f, 5, 5),
    _Suffix('(y)ken', _Cat.f, _Cat.f, 5, 5),
    // ── Fiilden isim: isim-fiil, sıfat-fiil, yapım (isim soylu gövdeye geçiş) ──
    _Suffix('mAk', _Cat.v, _Cat.n, 0, 1),
    _Suffix('mA', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)Iş', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)An', _Cat.v, _Cat.n, 0, 1),
    _Suffix('DIk', _Cat.v, _Cat.n, 0, 1),
    _Suffix('DIğ', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)AcAk', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)AcAğ', _Cat.v, _Cat.n, 0, 1),
    _Suffix('mIş', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)AsI', _Cat.v, _Cat.n, 0, 1),
    _Suffix('mAz', _Cat.v, _Cat.n, 0, 1),
    _Suffix('Ar', _Cat.v, _Cat.n, 0, 1),
    _Suffix('Ir', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(r)', _Cat.v, _Cat.n, 0, 1),
    _Suffix('(y)IcI', _Cat.v, _Cat.n, 0, 1),
    _Suffix('Im', _Cat.v, _Cat.n, 0, 1),
    _Suffix('gI', _Cat.v, _Cat.n, 0, 1),
    // ── Zarf-fiiller (yalnızca kelime sonunda) ──
    _Suffix('(y)Ip', _Cat.v, _Cat.n, 9, 1),
    _Suffix('(y)ArAk', _Cat.v, _Cat.n, 9, 1),
    _Suffix('mAdAn', _Cat.v, _Cat.n, 9, 1),
    _Suffix('(y)IncA', _Cat.v, _Cat.n, 2, 1),
    _Suffix('DIkçA', _Cat.v, _Cat.n, 9, 1),
    _Suffix('(y)AlI', _Cat.v, _Cat.n, 9, 1),
    _Suffix('mAksIzIn', _Cat.v, _Cat.n, 9, 1),
  ];

  static void _ensureLoaded() {
    if (_nouns != null) return;
    Set<String> split(String s) =>
        s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    _nouns = split(TurkishLexiconData.nominalLemmas);
    _verbs = split(TurkishLexiconData.verbRoots);
    _inverseHarmony = split(TurkishLexiconData.inverseHarmony);
    final boundN = <String>{};
    final boundV = <String>{};
    final voicedN = <String>{};
    for (final entry in split(TurkishLexiconData.boundStems)) {
      if (entry.startsWith('NV:')) {
        final w = entry.substring(3);
        boundN.add(w);
        voicedN.add(w);
      } else if (entry.startsWith('VV:')) {
        boundV.add(entry.substring(3));
      } else if (entry.startsWith('N:')) {
        boundN.add(entry.substring(2));
      } else if (entry.startsWith('V:')) {
        boundV.add(entry.substring(2));
      }
    }
    _boundNominal = boundN;
    _boundVerbal = boundV;
    _voicedNominal = voicedN;

    final index = <String, List<_Suffix>>{};
    var maxLen = 0;
    for (final s in _suffixes) {
      for (final surface in _allSurfaces(s.template)) {
        index.putIfAbsent(surface, () => <_Suffix>[]).add(s);
        if (surface.length > maxLen) maxLen = surface.length;
      }
    }
    _surfaceIndex = index;
    _maxSurfaceLength = maxLen;
  }

  static Map<String, List<_Suffix>> _surfaceIndex = const {};
  static int _maxSurfaceLength = 0;

  /// Uygulamaya özel ek sözlükleri (klasik eser terimleri, kullanıcı sözlüğü) kaydeder.
  static void registerExtraWords(Iterable<String> words) {
    var changed = false;
    for (final w in words) {
      final clean = _stripCircumflex(_toLower(w.trim()));
      if (clean.length >= 2 && _extraWords.add(clean)) changed = true;
    }
    if (changed) {
      _memo.clear();
      _wordCache.removeWhere((_, valid) => !valid);
    }
  }

  /// Özel sözlükten çıkarılan kelimeyi önbellekten de temizleyerek yeniden doğrulamaya açar.
  static void unregisterExtraWord(String word) {
    final clean = _stripCircumflex(_toLower(word.trim()));
    if (_extraWords.remove(clean)) {
      _memo.clear();
      _wordCache.clear();
    }
  }

  /// Sözlükteki toplam lemma sayısı (teşhis/test amaçlı).
  static int get lemmaCount {
    _ensureLoaded();
    return _nouns!.length + _verbs!.length;
  }

  /// Kelimenin (büyük/küçük harf ve şapkadan bağımsız) geçerli bir Türkçe
  /// kök + ek dizilimi olup olmadığını döndürür.
  static bool isKnownWord(String word) {
    final lower = _toLower(word.trim());
    if (lower.isEmpty) return false;
    final cached = _wordCache[lower];
    if (cached != null) return cached;

    _ensureLoaded();
    final plain = _stripCircumflex(lower);
    final relaxHarmony = plain != lower;
    bool result;
    if (!RegExp(r'^[a-zçğıöşü]+$').hasMatch(plain)) {
      result = false;
    } else if (_copulaForms.contains(plain) ||
        _extraWords.contains(plain) ||
        _nouns!.contains(plain) ||
        _verbs!.contains(plain)) {
      result = true;
    } else if (plain.length < 3) {
      result = false;
    } else {
      result = _analyze(plain, _Cat.any, 9, false, relaxHarmony, 0);
    }

    if (_wordCache.length > 60000) _wordCache.clear();
    _wordCache[lower] = result;
    return result;
  }

  static bool _isBaseLemma(String word, _Cat req, bool boundOk) {
    final wantN = req == _Cat.any || req == _Cat.n;
    final wantV = req == _Cat.any || req == _Cat.v;
    // Ünsüz yumuşaması zorunlu gövdeler ünlüyle başlayan ek önünde sert hâlde kalamaz (kitap+ı ✗ → kitabı ✓)
    final voicedForm = boundOk ? _voicedFormOf(word) : null;
    if (wantN) {
      final mustVoice = voicedForm != null && _voicedNominal!.contains(voicedForm);
      if (!mustVoice && (_nouns!.contains(word) || _extraWords.contains(word))) return true;
      // Eski imlâda yumuşamış yazım (kitab, mektub, kalb) ek almadan da kabul edilir
      if (_voicedNominal!.contains(word)) return true;
      if (boundOk && _boundNominal!.contains(word)) return true;
    }
    if (wantV) {
      final mustVoice = voicedForm != null && _boundVerbal!.contains(voicedForm);
      if (!mustVoice && _verbs!.contains(word)) return true;
      if (boundOk && _boundVerbal!.contains(word)) return true;
    }
    return false;
  }

  static String? _voicedFormOf(String word) {
    if (word.length < 2) return null;
    final last = word[word.length - 1];
    final head = word.substring(0, word.length - 1);
    switch (last) {
      case 'p':
        return '${head}b';
      case 'ç':
        return '${head}c';
      case 't':
        return '${head}d';
      case 'k':
        return head.endsWith('n') ? '${head}g' : '$headğ';
    }
    return null;
  }

  static bool _analyze(
    String word,
    _Cat req,
    int maxTier,
    bool boundOk,
    bool relax,
    int depth,
  ) {
    if (_isBaseLemma(word, req, boundOk)) return true;
    if (depth >= 7 || word.length < 3) return false;

    final key = '${req.index}|$maxTier|${boundOk ? 1 : 0}|${relax ? 1 : 0}|$word';
    final memo = _memo[key];
    if (memo != null) return memo;
    if (_memo.length > 120000) _memo.clear();

    var result = false;
    final maxLen = word.length - 2 < _maxSurfaceLength ? word.length - 2 : _maxSurfaceLength;
    outer:
    for (int len = 1; len <= maxLen; len++) {
      final tail = word.substring(word.length - len);
      final templates = _surfaceIndex[tail];
      if (templates == null) continue;
      final stem = word.substring(0, word.length - len);
      final allowInverse = relax ||
          _inverseHarmony!.contains(stem) ||
          stem.endsWith('l');
      for (final s in templates) {
        if (s.tier > maxTier) continue;
        if (req != _Cat.any && s.outer != req) continue;
        for (final inverse in allowInverse ? const [false, true] : const [false]) {
          final realized = _realize(s.template, stem, inverse);
          if (realized == null || realized != tail) continue;
          final startsWithVowel = _vowels.contains(realized[0]);
          if (startsWithVowel && _vowels.contains(stem[stem.length - 1])) continue;
          if (_analyze(stem, s.inner, s.innerMax, startsWithVowel, relax, depth + 1)) {
            result = true;
            break outer;
          }
        }
      }
    }

    // '-Iyor' önünde fiil gövdesinin son ünlüsü düşer: başla+ıyor → başlıyor, gelme+iyor → gelmiyor
    if (!result && (req == _Cat.any || req == _Cat.f)) {
      final m = RegExp(r'^(.+[^aeıioöuü])[ıiuü]yor$').firstMatch(word);
      if (m != null) {
        final before = m.group(1)!;
        for (final v in const ['a', 'e']) {
          if (_analyze('$before$v', _Cat.v, 1, false, relax, depth + 1)) {
            result = true;
            break;
          }
        }
      }
    }

    _memo[key] = result;
    return result;
  }

  /// Bir şablonun gövdeden bağımsız tüm olası yüzey biçimleri (ör. `DA` → da, de, ta, te).
  static Set<String> _allSurfaces(String template) {
    var forms = <String>{''};
    var i = 0;
    List<String> expand(String ch) {
      switch (ch) {
        case 'A':
          return const ['a', 'e'];
        case 'I':
          return const ['ı', 'i', 'u', 'ü'];
        case 'D':
          return const ['d', 't'];
        case 'C':
          return const ['c', 'ç'];
        default:
          return [ch];
      }
    }

    while (i < template.length) {
      final t = template[i];
      if (t == '(') {
        final close = template.indexOf(')', i);
        final opt = template.substring(i + 1, close);
        var withOpt = <String>{...forms};
        for (final c in opt.split('')) {
          withOpt = {for (final f in withOpt) for (final e in expand(c)) '$f$e'};
        }
        forms = {...forms, ...withOpt};
        i = close + 1;
        continue;
      }
      forms = {for (final f in forms) for (final e in expand(t)) '$f$e'};
      i++;
    }
    return forms.where((f) => f.isNotEmpty).toSet();
  }

  /// Şablonu verilen gövdeye göre yüzey biçimine dönüştürür.
  static String? _realize(String template, String stem, bool inverseFirst) {
    final sb = StringBuffer();
    var prev = stem[stem.length - 1];
    String? lastVowel;
    for (int i = stem.length - 1; i >= 0; i--) {
      if (_vowels.contains(stem[i])) {
        lastVowel = stem[i];
        break;
      }
    }
    lastVowel ??= 'a';
    var firstHarmonic = true;

    String harmonize(String archi) {
      final lv = lastVowel ?? 'a';
      var back = _backVowels.contains(lv);
      if (firstHarmonic && inverseFirst) back = false;
      firstHarmonic = false;
      final rounded = _roundedVowels.contains(lv);
      if (archi == 'A') return back ? 'a' : 'e';
      if (back) return rounded ? 'u' : 'ı';
      return rounded ? 'ü' : 'i';
    }

    void emit(String ch) {
      sb.write(ch);
      prev = ch;
      if (_vowels.contains(ch)) lastVowel = ch;
    }

    for (int i = 0; i < template.length; i++) {
      final t = template[i];
      if (t == '(') {
        final close = template.indexOf(')', i);
        final opt = template.substring(i + 1, close);
        final optIsVowel = opt == 'I' || opt == 'A' || _vowels.contains(opt);
        final stemEndsVowel = _vowels.contains(prev);
        final include = optIsVowel ? !stemEndsVowel : stemEndsVowel;
        if (include) {
          for (final c in opt.split('')) {
            emit(c == 'I' || c == 'A' ? harmonize(c) : c);
          }
        }
        i = close;
        continue;
      }
      switch (t) {
        case 'A':
        case 'I':
          emit(harmonize(t));
        case 'D':
          emit(_voiceless.contains(prev) ? 't' : 'd');
        case 'C':
          emit(_voiceless.contains(prev) ? 'ç' : 'c');
        default:
          emit(t);
      }
    }
    final out = sb.toString();
    return out.isEmpty ? null : out;
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

  static String _stripCircumflex(String s) =>
      s.replaceAll('â', 'a').replaceAll('î', 'i').replaceAll('û', 'u');
}
