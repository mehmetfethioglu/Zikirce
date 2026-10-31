import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Risale-i Nur Büyük Lügati (Osmanlıca - Türkçe Külliyat Sözlüğü) tekil madde modeli.
@immutable
class RisaleLugatEntry {
  final String headword;
  final String ottomanScript;
  final String definition;

  const RisaleLugatEntry({
    required this.headword,
    required this.ottomanScript,
    required this.definition,
  });

  /// Tanım içindeki Risale-i Nur iktibaslarını `(...risale iktibası...)` ayıklar.
  String? get risaleQuote {
    final matches =
        RegExp(r'\((\.\.\.[^)]{25,}|[^)]{55,})\)').allMatches(definition);
    for (final m in matches) {
      final inner = (m.group(1) ?? '').trim();
      if (inner.startsWith('Bak:') ||
          inner.startsWith('C.:') ||
          inner.contains('. C.') ||
          inner.contains('. dan') ||
          inner.contains('. den')) {
        continue;
      }
      return inner;
    }
    return null;
  }

  /// Tanımı maddeler (`•` veya `*`) halinde temizlenmiş liste olarak döndürür.
  List<String> get meaningBullets {
    var cleaned = definition;
    final quote = risaleQuote;
    if (quote != null) {
      cleaned = cleaned.replaceAll('($quote)', '').trim();
    }
    final rawParts = cleaned
        .split(RegExp(r'\s*(?:•|\*)\s*'))
        .map((s) => s.replaceAll(RegExp(r'^\(\d+\)\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return rawParts.isEmpty ? [definition.trim()] : rawParts;
  }
}

/// Külliyat metni içerisinde tespit edilen tıklanabilir lügat kelimesi / terkibi.
/// `start..stemEnd` aralığı tema uyumlu lügat rengiyle boyanır;
/// `stemEnd..end` aralığındaki Türkçe çekim ekleri (`-un`, `-imizdir`, `-le` vb.) ana metin renginde kalır.
@immutable
class RisaleLugatTextMatch {
  final int start;
  final int stemEnd;
  final int end;
  final String surfaceText;
  final String coloredStemText;
  final RisaleLugatEntry entry;

  const RisaleLugatTextMatch({
    required this.start,
    required this.stemEnd,
    required this.end,
    required this.surfaceText,
    required this.coloredStemText,
    required this.entry,
  });
}

/// 84.141 maddelik Risale-i Nur Kelime ve Terkipler Büyük Lügati (O(1) bellek içi kök/ek ve tamlama çözümleyici).
class RisaleLugatService {
  RisaleLugatService._();
  static final RisaleLugatService instance = RisaleLugatService._();

  static const String _assetPath = 'assets/raw/risale_lugat.tsv.gz';

  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  final Map<String, RisaleLugatEntry> _exactMap = <String, RisaleLugatEntry>{};
  final Map<String, RisaleLugatEntry> _apostropheMap =
      <String, RisaleLugatEntry>{};
  final Set<String> _nisbaOnlySet = <String>{};
  final List<RisaleLugatEntry> _allEntries = <RisaleLugatEntry>[];

  bool get isLoaded => _isLoaded;
  int get totalEntries => _allEntries.length;

  /// Sözlük verisini arka plan izolatında (`Isolate.run`) açıp belleğe hazırlar.
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    if (_loadingFuture != null) return _loadingFuture;
    _loadingFuture = _loadInternal();
    return _loadingFuture;
  }

  Future<void> _loadInternal() async {
    try {
      final byteData = await rootBundle.load(_assetPath);
      final compressedBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final parsedRows = await Isolate.run<List<List<String>>>(() {
        final decompressed = GZipCodec().decode(compressedBytes);
        final content = utf8.decode(decompressed, allowMalformed: true);
        final lines = const LineSplitter().convert(content);
        final result = <List<String>>[];
        for (final line in lines) {
          if (line.isEmpty) continue;
          final parts = line.split('\t');
          if (parts.length >= 3) {
            result.add(<String>[parts[0], parts[1], parts[2]]);
          }
        }
        return result;
      });

      _exactMap.clear();
      _apostropheMap.clear();
      _nisbaOnlySet.clear();
      _allEntries.clear();

      for (final row in parsedRows) {
        final hw = row[0];
        final ott = row[1];
        final def = row[2];
        final entry = RisaleLugatEntry(
          headword: hw,
          ottomanScript: ott,
          definition: def,
        );
        _allEntries.add(entry);

        final nk = _normalizeKey(hw);
        if (nk.length < 3) continue;

        final hwLower = _trLower(hw);
        final isNisba = hwLower.endsWith('î') ||
            hwLower.endsWith('îsi') ||
            hwLower.endsWith('îdir');

        final hasInternalApostrophe =
            hw.contains("'") || hw.contains('’') || hw.contains('‘');
        if (!hasInternalApostrophe) {
          if (!_exactMap.containsKey(nk)) {
            _exactMap[nk] = entry;
            if (isNisba) {
              _nisbaOnlySet.add(nk);
            }
          } else if (!isNisba) {
            _nisbaOnlySet.remove(nk);
          }
        } else {
          _apostropheMap.putIfAbsent(nk, () => entry);
        }
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint('RisaleLugatService load error: $e');
    } finally {
      _loadingFuture = null;
    }
  }

  static String _trLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .replaceAll('Â', 'â')
        .replaceAll('Î', 'î')
        .replaceAll('Û', 'û')
        .replaceAll('Ô', 'ô')
        .replaceAll('Ê', 'ê')
        .toLowerCase();
  }

  static final RegExp _parenRegex = RegExp(r'\s*\(.*?\)');
  static final RegExp _stripCharsRegex = RegExp(r"['’‘`\- $]");

  /// Türkçe ünlü ayrımlarını (`u/ü`, `o/ö`, `ı/i`) koruyarak şapkalı harfleri ve
  /// Osmanlıca çift `y` (`iyyet -> iyet`) yazılışlarını normalize eder.
  static String _normalizeKey(String input) {
    var s = input.replaceAll(_parenRegex, '').trim();
    s = _trLower(s);
    s = s
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ê', 'e')
        .replaceAll('ô', 'o')
        .replaceAll(_stripCharsRegex, '')
        .replaceAll('iyyet', 'iyet')
        .replaceAll('uvvet', 'uvet');
    return s;
  }

  /// Günlük modern Türkçede herkesin bildiği bağlaç, zamir, sayı, fiil ve sıfatlar
  /// (okuma sırasında gereksiz renklendirme kalabalığı oluşturmaması için filtrelenir).
  static const Set<String> _modernTurkishStopwords = <String>{
    'bir', 'biri', 'birisi', 'birkac', 'birkaç', 'bircok', 'birçok', 'bütün',
    'her', 'hiç', 'hiçbir', 'hep', 'hepsi', 've', 'veya', 'yahut', 'ile',
    'için', 'gibi', 'kadar', 'göre', 'karşı', 'doğru', 'başka', 'diğer',
    'öteki', 'bu', 'şu', 'onun', 'ona', 'onu', 'onlar', 'onların', 'onlara',
    'bunu', 'buna', 'bunun', 'bunlar', 'şunu', 'şuna', 'ben', 'sen', 'biz',
    'siz', 'kendi', 'kendisi', 'kendini', 'kendine', 'benim', 'senin', 'bizim',
    'sizin', 'ne', 'nasıl', 'niçin', 'neden', 'nerede', 'nereye', 'nereden',
    'kim', 'kime', 'kimi', 'kimin', 'hangi', 'var', 'yok', 'evet', 'hayır',
    'değil', 'bile', 'dahi', 'hem', 'ama', 'fakat', 'ancak', 'lakin', 'çünkü',
    'zira', 'eğer', 'ise', 'ki', 'çok', 'az', 'daha', 'en', 'pek', 'gayet',
    'tam', 'böyle', 'şöyle', 'öyle', 'işte', 'şimdi', 'sonra', 'önce', 'evvel',
    'acaba', 'yani', 'idi', 'imiş', 'iken', 'gün', 'gece', 'gecemiz',
    'gecesinden', 'sabah', 'akşam', 'yıl', 'sene', 'ay', 'saat', 'vakit',
    'zaman', 'defa', 'kere', 'insan', 'insanlar', 'adam', 'kadın', 'erkek',
    'çocuk', 'anne', 'baba', 'kardeş', 'arkadaş', 'dost', 'dostluk', 'el',
    'eli', 'baş', 'başı', 'göz', 'gözü', 'yüz', 'yüzü', 'yüzünü', 'ağız',
    'dil', 'kulak', 'ayak', 'kalp', 'kalb', 'su', 'ateş', 'toprak', 'hava',
    'taş', 'ağaç', 'çiçek', 'meyve', 'güneş', 'yıldız', 'bulut', 'bulutlardan',
    'deniz', 'denizi', 'denizimiz', 'denizin', 'denizinden', 'dağ', 'yol',
    'yolu', 'yer', 'yeri', 'taraf', 'tarafa', 'taraftan', 'ev', 'kapı', 'oda',
    'şehir', 'köy', 'memleket', 'dünya', 'iyi', 'kötü', 'güzel', 'çirkin',
    'büyük', 'küçük', 'uzun', 'kısa', 'yüksek', 'alçak', 'yeni', 'eski',
    'genç', 'yaşlı', 'ak', 'beyaz', 'kara', 'karanlık', 'siyah', 'kırmızı',
    'yeşil', 'mavi', 'sarı', 'birinci', 'ikinci', 'üçüncü', 'dördüncü',
    'beşinci', 'altıncı', 'yedinci', 'sekizinci', 'dokuzuncu', 'onuncu',
    'onbirinci', 'onikinci', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi',
    'sekiz', 'dokuz', 'on', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış',
    'yetmiş', 'seksen', 'doksan', 'bin', 'binler', 'milyon', 'söz', 'sözler',
    'ses', 'iş', 'işi', 'şey', 'şeyi', 'şeyde', 'şeyden', 'şeyler', 'hal',
    'hali', 'ad', 'adı', 'isim', 'ismi', 'renk', 'şekil', 'şekli', 'ol',
    'olur', 'oldu', 'olmak', 'olan', 'olarak', 'olsa', 'olup', 'olmaz',
    'olmayan', 'olduğu', 'olduğunu', 'olduğundan', 'et', 'eder', 'etti',
    'etmiştir', 'etmek', 'eden', 'ederek', 'ediyor', 'edilir', 'edilen', 'yap',
    'yapar', 'yaptı', 'yapmak', 'yapan', 'gel', 'gelir', 'geldi', 'gelmek',
    'gelen', 'git', 'gider', 'gitti', 'gitmek', 'giden', 'giderler', 'getir',
    'getirip', 'al', 'alır', 'aldı', 'almak', 'alan', 'ver', 'verir', 'verdi',
    'vermek', 'veren', 'gör', 'görür', 'gördü', 'görmek', 'gören', 'göster',
    'gösterdiler', 'bak', 'bakar', 'baktı', 'bakmak', 'bakan', 'bil', 'bilir',
    'bildi', 'bilmek', 'bilen', 'de', 'der', 'dedi', 'demek', 'diyen', 'dinle',
    'dinler', 'iste', 'ister', 'istersen', 'istedin', 'bul', 'bulur', 'buldu',
    'bulmak', 'bulan', 'bulunur', 'bulunan', 'bulunuyor', 'bulundurdu',
    'bulunduğunu', 'çık', 'çıkar', 'çıktı', 'düş', 'düşer', 'düştü', 'kal',
    'kalır', 'kaldı', 'bırak', 'bırakır', 'tut', 'tutar', 'sev', 'sever',
    'kork', 'korkar', 'korkulu', 'korkuludur', 'anla', 'anlar', 'anlamak',
    'oku', 'okur', 'yaz', 'yazar', 'asker', 'askere', 'askerin', 'askerlik',
    'keyif', 'ticaret', 'seyahat', 'rahat', 'lezzet', 'çare', 'para', 'fiyat',
    'zengin', 'fakir', 'halk', 'halkın', 'akraba', 'teşekkür', 'teşekkürler',
    'kanun', 'altında', 'üstünde', 'içinde', 'dışında', 'yanında', 'arasında',
    'üzerine', 'üzerinde', 'önünde', 'arkasında', 'birlikte', 'beraber',
    'karşısında', 'karın', 'karnı', 'karnını', 'gemi', 'gemisi', 'lamba',
    'lâmba', 'süpür', 'süpürüp', 'derece', 'cenaze', 'dehşet', 'dehşeti',
    'dehşetlidir', 'müthiş', 'tehdit', 'emniyet', 'emniyetli', 'vaziyet',
    'vaziyetteyiz', 'vaziyetinden', 'cihet', 'cihette', 'sahra', 'sahrâ',
    'zelzele', 'zelzeleli', 'hüküm', 'hükmü', 'hükmüne', 'aleyhisselam',
    'aleyhisselâm', 'aleyhisselâmın', 'aleyhissalâtü', 'vesselâm',
  };

  /// Birleşik ve tekil Türkçe çekim ekleri (uzundan kısaya ve ünlüyle başlayanlar öncelikli).
  /// Bu sayede `küre-i zemin`imizdir, `hût`umuzdur, `sahil-i selâmet`e gibi kelimelerde
  /// yalnızca kök/tamlama kısmı renklendirilip Türkçe ek ana metin renginde bırakılır.
  static const List<String> _orderedSuffixes = <String>[
    'lerimizden',
    'larımızdan',
    'lerimizde',
    'larımızda',
    'lerimize',
    'larımıza',
    'lerimizi',
    'larımızı',
    'lerimizin',
    'larımızın',
    'lerimizdir',
    'larımızdır',
    'lerinden',
    'larından',
    'leriyle',
    'larıyla',
    'lerinin',
    'larının',
    'lerinde',
    'larında',
    'lerine',
    'larına',
    'lerini',
    'larını',
    'lerimiz',
    'larımız',
    'leridir',
    'larıdır',
    'imizden',
    'ımızdan',
    'ümüzden',
    'umuzdan',
    'imizde',
    'ımızda',
    'ümüzde',
    'umuzda',
    'imize',
    'ımıza',
    'ümüze',
    'umuza',
    'imizi',
    'ımızı',
    'ümüzü',
    'umuzu',
    'imizin',
    'ımızın',
    'ümüzün',
    'umuzun',
    'imizdir',
    'ımızdır',
    'ümüzdür',
    'umuzdur',
    'imizle',
    'ımızla',
    'ümüzle',
    'umuzla',
    'inden',
    'ından',
    'ünden',
    'undan',
    'inde',
    'ında',
    'ünde',
    'unda',
    'ine',
    'ına',
    'üne',
    'una',
    'ini',
    'ını',
    'ünü',
    'unu',
    'inin',
    'ının',
    'ünün',
    'unun',
    'iyle',
    'ıyla',
    'üyle',
    'uyla',
    'idir',
    'ıdır',
    'üdür',
    'udur',
    'imiz',
    'ımız',
    'ümüz',
    'umuz',
    'iniz',
    'ınız',
    'ünüz',
    'unuz',
    'ndeki',
    'ndaki',
    'deki',
    'daki',
    'teki',
    'taki',
    'lerden',
    'lardan',
    'nin',
    'nın',
    'nun',
    'nün',
    'in',
    'ın',
    'un',
    'ün',
    'yi',
    'yı',
    'yu',
    'yü',
    'ye',
    'ya',
    'si',
    'sı',
    'su',
    'sü',
    'im',
    'ım',
    'um',
    'üm',
    'i',
    'ı',
    'u',
    'ü',
    'e',
    'a',
    'ten',
    'tan',
    'den',
    'dan',
    'dir',
    'dır',
    'dur',
    'dür',
    'tir',
    'tır',
    'tur',
    'tür',
    'ler',
    'lar',
    'yle',
    'yla',
    'le',
    'la',
    'de',
    'da',
    'te',
    'ta',
    'siz',
    'sız',
    'suz',
    'süz',
    'lik',
    'lık',
    'luk',
    'lük',
  ];

  static final RegExp _izafetPrefixRegex = RegExp(
    r"^(.+?)-(?:i|ı|u|ü|yi|yı|yu|yü|ü'l|i'l|ü’l|i’l|ül|il)$",
    caseSensitive: false,
  );

  static bool _isIzafetConnectorWord(String word) {
    if (_izafetPrefixRegex.hasMatch(word)) return true;
    final low = _trLower(word);
    return low == 'hazret-i' ||
        low == 'hazreti' ||
        low == 'cenâb-ı' ||
        low == 'cenab-ı' ||
        low == 'resûl-i' ||
        low == 'resul-i';
  }

  RisaleLugatEntry? _matchStem(String stem, {required bool hasApostrophe}) {
    if (stem.length < 3 || _modernTurkishStopwords.contains(stem)) {
      return null;
    }
    if (hasApostrophe && _apostropheMap.containsKey(stem)) {
      return _apostropheMap[stem];
    }
    final exact = _exactMap[stem];
    if (exact != null) return exact;
    final apos = _apostropheMap[stem];
    if (apos != null) return apos;

    // Osmanlıca son ünsüz nöbetleşmesi (mektup->mektub, şakirt->şakird, miraç->mirac, reng->renk)
    if (stem.endsWith('p')) {
      final alt = '${stem.substring(0, stem.length - 1)}b';
      if (_exactMap.containsKey(alt)) return _exactMap[alt];
    } else if (stem.endsWith('t')) {
      final alt = '${stem.substring(0, stem.length - 1)}d';
      if (_exactMap.containsKey(alt)) return _exactMap[alt];
    } else if (stem.endsWith('ç')) {
      final alt = '${stem.substring(0, stem.length - 1)}c';
      if (_exactMap.containsKey(alt)) return _exactMap[alt];
    } else if (stem.endsWith('ğ')) {
      final alt = '${stem.substring(0, stem.length - 1)}k';
      if (_exactMap.containsKey(alt)) return _exactMap[alt];
    } else if (stem.length >= 4 &&
        stem[stem.length - 1] == stem[stem.length - 2]) {
      final singleConsonant = stem.substring(0, stem.length - 1);
      if (!_modernTurkishStopwords.contains(singleConsonant) &&
          _exactMap.containsKey(singleConsonant)) {
        return _exactMap[singleConsonant];
      }
    }
    return null;
  }

  /// Kelime veya terkibi çözümler ve `(RisaleLugatEntry, ekUzunluğu)` ikilisini döndürür.
  (RisaleLugatEntry, int)? _resolveWithSuffixLength(
    String rawWord, {
    bool includeStopwords = false,
  }) {
    if (!_isLoaded) return null;
    final trimmed = rawWord.trim();
    if (trimmed.length < 3) return null;

    final lowered = _trLower(trimmed);
    if (!includeStopwords && _modernTurkishStopwords.contains(lowered)) {
      return null;
    }

    // 1. Farsça/Arapça izafet terkibi eki (-i, -ı, -u, -ü) taşıyan tekil kelimeler:
    final izafetMatch = _izafetPrefixRegex.firstMatch(trimmed);
    if (izafetMatch != null && !trimmed.contains(' ')) {
      final basePart = izafetMatch.group(1)!;
      final baseKey = _normalizeKey(basePart);
      if (!includeStopwords && _modernTurkishStopwords.contains(baseKey)) {
        return null;
      }
      final entry = _matchStem(
        baseKey,
        hasApostrophe:
            basePart.contains("'") ||
            basePart.contains('’') ||
            basePart.contains('‘'),
      );
      if (entry != null) return (entry, 0);
    }

    final nk = _normalizeKey(trimmed);
    if (nk.length < 3) return null;
    if (!includeStopwords && _modernTurkishStopwords.contains(nk)) {
      return null;
    }

    // Eğer kelime modern Türkçe stopword'ün çekimli hâli ise (örn. şeyde, askere, sözlerin) atla
    if (!includeStopwords && !trimmed.contains(' ')) {
      for (final suf in _orderedSuffixes) {
        if (nk.endsWith(suf) && nk.length - suf.length >= 2) {
          final rootCandidate = nk.substring(0, nk.length - suf.length);
          if (_modernTurkishStopwords.contains(rootCandidate)) {
            return null;
          }
        }
      }
    }

    final hasApostrophe =
        trimmed.contains("'") || trimmed.contains('’') || trimmed.contains('‘');

    // 2. Kesme işaretiyle ayrılmış Türkçe çekim eki varsa (örn. Kur'ân'ın, Hâlık'ımız)
    for (final q in const <String>["'", '’', '‘']) {
      final lastIdx = trimmed.lastIndexOf(q);
      if (lastIdx >= 3) {
        final beforeQuote = trimmed.substring(0, lastIdx);
        final stemQ = _normalizeKey(beforeQuote);
        final matchQ = _matchStem(
          stemQ,
          hasApostrophe:
              beforeQuote.contains("'") ||
              beforeQuote.contains('’') ||
              beforeQuote.contains('‘'),
        );
        if (matchQ != null) {
          return (matchQ, trimmed.length - lastIdx);
        }
      }
    }

    // 3. Doğrudan eşleşme (ancak nisba `-î` veya şapkalı kök+ek çakışmalarını ayıkla: örn. kameri -> kamer+i, hûtun -> hût+un)
    if (nk == 'hevaya') {
      final heva = _exactMap['heva'];
      if (heva != null) return (heva, 2);
    }
    final direct = _matchStem(nk, hasApostrophe: hasApostrophe);
    if (direct != null) {
      // a) Sözlükte sadece nisba (-î) ile kayıtlıysa ama metindeki kelimede şapka yoksa ve -i/-ı çıkarılınca kök varsa (örn. kameri -> kamer + i)
      if (_nisbaOnlySet.contains(nk) &&
          !lowered.endsWith('î') &&
          nk.length >= 4) {
        final withoutI = nk.substring(0, nk.length - 1);
        final rootMatch = _matchStem(withoutI, hasApostrophe: hasApostrophe);
        if (rootMatch != null) {
          return (rootMatch, 1);
        }
      }
      // b) Metindeki kelimede şapkalı ünlü (`â`, `î`, `û`) varken doğrudan eşleşen maddede hiç şapka yoksa (örn. hûtun -> HUTUN yerine Hût + un)
      final surfaceHasCircumflex =
          lowered.contains('â') || lowered.contains('î') || lowered.contains('û');
      final dictLower = _trLower(direct.headword);
      final dictHasCircumflex = dictLower.contains('â') ||
          dictLower.contains('î') ||
          dictLower.contains('û');
      if (surfaceHasCircumflex && !dictHasCircumflex) {
        for (final suf in _orderedSuffixes) {
          if (nk.endsWith(suf) && nk.length - suf.length >= 3) {
            final stem = nk.substring(0, nk.length - suf.length);
            final matched = _matchStem(stem, hasApostrophe: hasApostrophe);
            if (matched != null) {
              return (matched, suf.length);
            }
          }
        }
      }
      // c) '-te/-ta' ile bitip '-e/-a' yönelme eki almış kelime (örn. âhirete -> âhiret + e)
      if ((nk.endsWith('te') || nk.endsWith('ta')) && nk.length >= 5) {
        final withoutVowel = nk.substring(0, nk.length - 1);
        final altMatch = _exactMap[withoutVowel];
        if (altMatch != null) return (altMatch, 1);
      }
      return (direct, 0);
    }

    // 4. Türkçe çekim eklerini sırasıyla soyarak kök/tamlama arama
    for (final suf in _orderedSuffixes) {
      if (nk.endsWith(suf) && nk.length - suf.length >= 3) {
        final stem = nk.substring(0, nk.length - suf.length);
        final matched = _matchStem(stem, hasApostrophe: hasApostrophe);
        if (matched != null) {
          return (matched, suf.length);
        }
      }
    }

    return null;
  }

  /// Tek bir kelime veya terkip için Risale-i Nur Lügati karşılığını çözümler.
  RisaleLugatEntry? lookupWord(
    String rawWord, {
    bool includeStopwords = false,
  }) {
    return _resolveWithSuffixLength(
      rawWord,
      includeStopwords: includeStopwords,
    )?.$1;
  }

  static final RegExp _tokenRegex = RegExp(
    r"[A-Za-zÂÎÛÊÔâîûêôÇĞIİÖŞÜçğıiöşü'’‘]+(?:-[A-Za-zÂÎÛÊÔâîûêôÇĞIİÖŞÜçğıiöşü'’‘]+)*",
  );

  /// Verilen paragraf/sayfa metni içindeki tüm Risale-i Nur Lügati kelimelerini ve
  /// 2-3 kelimelik Farsça/Arapça izafet tamlamalarını (`nur-u tevhid`, `sahil-i selâmet`e,
  /// `küre-i zemin`imizdir, `sikke-i tasdik-i gaybî` vb.) kalıp halinde tespit eder.
  List<RisaleLugatTextMatch> findMatchesInText(String text) {
    if (!_isLoaded || text.isEmpty) return const <RisaleLugatTextMatch>[];

    final rawTokens = _tokenRegex.allMatches(text).toList(growable: false);
    if (rawTokens.isEmpty) return const <RisaleLugatTextMatch>[];

    final results = <RisaleLugatTextMatch>[];
    int i = 0;
    while (i < rawTokens.length) {
      final current = rawTokens[i];
      final word1 = current.group(0)!;

      // 1. Önce 3 kelimelik zincirleme izafet tamlaması kontrolü (örn. "sikke-i tasdik-i gaybî", "vesîle-i icâbe-i duâ")
      if (i + 2 < rawTokens.length && _isIzafetConnectorWord(word1)) {
        final second = rawTokens[i + 1];
        final third = rawTokens[i + 2];
        final b1 = text.substring(current.end, second.start);
        final b2 = text.substring(second.end, third.start);
        final word2 = second.group(0)!;
        if (b1.trim().isEmpty &&
            b1.length <= 2 &&
            b2.trim().isEmpty &&
            b2.length <= 2 &&
            _isIzafetConnectorWord(word2)) {
          final word3 = third.group(0)!;
          final compound3 = '$word1 $word2 $word3';
          final resolved3 = _resolveWithSuffixLength(compound3);
          if (resolved3 != null) {
            final (entry3, sufLen3) = resolved3;
            final stemEnd3 =
                (third.end - sufLen3).clamp(current.start + 1, third.end);
            results.add(
              RisaleLugatTextMatch(
                start: current.start,
                stemEnd: stemEnd3,
                end: third.end,
                surfaceText: text.substring(current.start, third.end),
                coloredStemText: text.substring(current.start, stemEnd3),
                entry: entry3,
              ),
            );
            i += 3;
            continue;
          }
        }
      }

      // 2. 2 kelimelik izafet terkibi / tamlama kontrolü
      // (örn. "nur-u tevhid", "sahil-i selâmete", "lûtf-u Rabbânîyi", "Hazret-i Yunus", "küre-i zeminimizdir")
      if (i + 1 < rawTokens.length && _isIzafetConnectorWord(word1)) {
        final next = rawTokens[i + 1];
        final between = text.substring(current.end, next.start);
        if (between.trim().isEmpty && between.length <= 2) {
          final word2 = next.group(0)!;
          final compoundRaw = '$word1 $word2';
          final resolvedCompound = _resolveWithSuffixLength(compoundRaw);
          if (resolvedCompound != null) {
            final (compoundEntry, sufLen) = resolvedCompound;
            final stemEnd =
                (next.end - sufLen).clamp(current.start + 1, next.end);
            results.add(
              RisaleLugatTextMatch(
                start: current.start,
                stemEnd: stemEnd,
                end: next.end,
                surfaceText: text.substring(current.start, next.end),
                coloredStemText: text.substring(current.start, stemEnd),
                entry: compoundEntry,
              ),
            );
            i += 2;
            continue;
          }

          // Sözlükte tek satır olarak bulunmayan nadir bir izafet tamlaması ise bileşenlerini birleştirip kalıp olarak göster
          final r1 = _resolveWithSuffixLength(word1, includeStopwords: true);
          final r2 = _resolveWithSuffixLength(word2, includeStopwords: true);
          if (r1 != null && r2 != null) {
            final (e1, _) = r1;
            final (e2, sufLen2) = r2;
            final stemEnd =
                (next.end - sufLen2).clamp(current.start + 1, next.end);
            final coloredStem = text.substring(current.start, stemEnd);
            final ottCombined = <String>[
              if (e1.ottomanScript.isNotEmpty) e1.ottomanScript,
              if (e2.ottomanScript.isNotEmpty) e2.ottomanScript,
            ].join(' ');
            final defCombined =
                '${e1.headword}: ${e1.meaningBullets.first} • ${e2.headword}: ${e2.meaningBullets.first}';
            results.add(
              RisaleLugatTextMatch(
                start: current.start,
                stemEnd: stemEnd,
                end: next.end,
                surfaceText: text.substring(current.start, next.end),
                coloredStemText: coloredStem,
                entry: RisaleLugatEntry(
                  headword: coloredStem,
                  ottomanScript: ottCombined,
                  definition: defCombined,
                ),
              ),
            );
            i += 2;
            continue;
          }
        }
      }

      // 3. Tekil kelime / bitişik terkip kontrolü
      final resolvedSingle = _resolveWithSuffixLength(word1);
      if (resolvedSingle != null) {
        final (singleEntry, sufLen) = resolvedSingle;
        final stemEnd =
            (current.end - sufLen).clamp(current.start + 1, current.end);
        results.add(
          RisaleLugatTextMatch(
            start: current.start,
            stemEnd: stemEnd,
            end: current.end,
            surfaceText: word1,
            coloredStemText: text.substring(current.start, stemEnd),
            entry: singleEntry,
          ),
        );
      }
      i++;
    }

    return results;
  }

  /// Sözlük içinde başlık veya anlam bazlı hızlı arama yapar.
  List<RisaleLugatEntry> searchEntries(String query, {int limit = 40}) {
    if (!_isLoaded) return const <RisaleLugatEntry>[];
    final q = query.trim();
    if (q.isEmpty) {
      return _allEntries.take(limit).toList(growable: false);
    }

    final nq = _normalizeKey(q);
    final qLower = _trLower(q);

    final exactMatches = <RisaleLugatEntry>[];
    final prefixMatches = <RisaleLugatEntry>[];
    final meaningMatches = <RisaleLugatEntry>[];

    final direct = lookupWord(q, includeStopwords: true);
    if (direct != null) {
      exactMatches.add(direct);
    }

    for (final entry in _allEntries) {
      if (exactMatches.contains(entry)) continue;
      final hwNorm = _normalizeKey(entry.headword);
      if (hwNorm == nq) {
        exactMatches.add(entry);
      } else if (nq.isNotEmpty && hwNorm.startsWith(nq)) {
        if (prefixMatches.length < limit) {
          prefixMatches.add(entry);
        }
      } else if (meaningMatches.length < limit &&
          _trLower(entry.definition).contains(qLower)) {
        meaningMatches.add(entry);
      }
      if (exactMatches.length + prefixMatches.length >= limit) {
        break;
      }
    }

    return <RisaleLugatEntry>[
      ...exactMatches,
      ...prefixMatches,
      ...meaningMatches,
    ].take(limit).toList(growable: false);
  }
}

final risaleLugatServiceProvider = Provider<RisaleLugatService>((ref) {
  return RisaleLugatService.instance;
});
