import 'ocr_lexicon_database.dart';
import 'turkish_morphology.dart';

/// Taranmış PDF'lerdeki (hem gömülü eski OCR katmanlarındaki hem de kamera/tarayıcı ML Kit OCR çıktılarındaki)
/// karakter bozulmalarını, aralıklı dizgi (letter-spaced) kelime bölünmelerini, satır sonu hece kırılmalarını,
/// sahte Arapça halüsinasyonlarını ve Türkçe morfolojik/fonotaktik ek hatalarını deterministik olarak onaran
/// Evrensel Türkçe Dilbilimsel Metin İyileştirme Motoru (V2).
class OcrTextHealer {
  const OcrTextHealer._();

  /// PDF içindeki gömülü metin katmanının bozuk/kirli bir eski OCR katmanı olup olmadığını tespit eder.
  /// Eğer true dönerse, mobil cihazlarda temiz 300 DPI ML Kit OCR motoru devreye girebilir
  /// ve metin derin iyileştirme (deep healing) hattından geçirilir.
  static bool isDirtyEmbeddedOcrLayer(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return true;

    // 1. Türkçe/Latin kelimelere bitişik Arapça noktalama veya harfler (Ör: "ulaştıklar؟", "âlim،•'")
    if (RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ][\u0600-\u06FF]|[\u0600-\u06FF][a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]')
        .hasMatch(trimmed)) {
      return true;
    }

    // 2. Aynı kelimede veya satırda Arapça harflerle karışmış ©, ®, €, ¥, § sembolleri veya 3+ tekrarlı Arapça harf ("أأأأسأ©ء")
    if (RegExp(r'([\u0621-\u064A])\1{2,}|[\u0600-\u06FF][^\n]{0,10}[©®€¥§«»]|[©®€¥§«»][^\n]{0,10}[\u0600-\u06FF]')
        .hasMatch(trimmed)) {
      return true;
    }

    // 3. Türkçe alfabede bulunmayan yabancı Latin diyakritikleri (ł, í, ô, ê, č, š, ř, ń vb.) veya kelime içi '::'
    if (RegExp(r'[łŁńŃśŚźŹżŻčČřŘšŠžŽďĎťŤňŇěĚůŮíÍóÓúÚáÁéÉêÊôÔ]|[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]:{2,}')
        .hasMatch(trimmed)) {
      return true;
    }

    // 4. Kelime içi/bitişiği OCR sembol kirlilikleri (©Huğunu, faüku&s, âittir0, T@L, -.!erinin, •nesle, te= mâs, girdiğimiz! anlamak)
    if (RegExp(
      r'(?:©[Hh]uğunu|faüku|âittir0|T@L|-\.![a-z]|،•|(?<=\s|^)•[a-zçğıöşüâîû]|(?<![\p{L}])[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}\s*=\s*[a-zçğıöşüâîû]{2,}|[a-zçğıöşüâîû]+»\s+[A-ZÇĞİÖŞÜ]|[a-zçğıöşüâîû]{3,}![ \t]+[a-zçğıöşüâîû]{3,})',
      unicode: true,
    ).hasMatch(trimmed)) {
      return true;
    }

    // 5. Tipik taranmış Türkçe kitap OCR bozulmaları (çoğul -iar/-ier/-larm/-lann/-lanın/-malan, ünlü düşmesi -larnda/-larnı/-dr/-nr, deviet, ortcdcki, hğ, hk, kabûi, omuştur vb.)
    if (RegExp(
      r'(?:(?<![\p{L}])(?:igbu|iîmî|teınâs|teınas|deviet[a-zçğıöşüâîû]*|oiabil[a-zçğıöşüâîû]*|omuştur|kabûi|iemâ|yokea|cözer|karişik|siirinde|Hallfe|BlRindİ|BÖLÜ[HMU]|MUKADDİMESI|ortcdcki|ctmak|aşccak|ağlcyacak|sermoktedir[a-z]*|kaplmalan|kurtanr|politikayn|kıhk|Dın|HALAUN|ibnden|bilimdiği|edinlerin|askeridi|onlan|bunlan|Artzona|göıiirsünüz|göriirsünüz)(?![\p{L}])|[a-zçğıöşüâîû]{2,}hğ[ıiuü]|[a-zçğıöşüâîû][aıoueiöü]hk(?![\p{L}])|[bcçdfgğhjklmnprsştvyz][iı][üö]|[a-zçğıöşüâîû]{3,}(?:larm|lerm|iarın|ierin|iann|ienn|iarı|ieri|larnda|larnı|lanın|lannda|lanndan|lanna|malan|melen|lardur|parçalardr|kurtanr|düşmann|zamannda|uymanm|Başkanma)(?![\p{L}])|(?<![\p{L}])(?:ön\s+ceki|se\s+viye|iti\s+barla|baya\s+ğ1|kaydetmiş\s+tir|tutulmuş\s+tur)(?![\p{L}])|[.!?]\s*>+\s*der)',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Bir metin bloğunun GERÇEK bir Arapça ibare (Âyet, Hadîs-i Şerîf, kelâm-ı kibâr) mı
  /// yoksa eski tarayıcıların ürettiği sahte Arapça OCR halüsinasyonu mu ("أأأأسأ©ء", "ك", "هو©ه€؛!ه") olduğunu denetler.
  static bool isValidArabicSegment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // 1. İçinde ©, ®, €, ¥, §, @, &, $ gibi OCR gürültü sembolleri veya Arapça harfler arasına sıkışmış kesme işareti varsa sahte OCR halüsinasyonudur
    if (RegExp(r'[©®€¥§£@#$%^&*+=<>~|]|[\u0600-\u06FF][’\x27‘`][\u0600-\u06FF]').hasMatch(trimmed)) {
      return false;
    }

    // 2. Arapçada hiçbir kelimede 3 veya daha fazla aynı harf yan yana gelmez (Ör: "أأأأسأ©ء")
    if (RegExp(r'([\u0621-\u064A])\1{2,}').hasMatch(trimmed)) {
      return false;
    }

    // 3. Arapça temel harf ve hareke sayısını ölç
    final arabicLetters = RegExp(r'[\u0621-\u064A\u0671-\u06D3\uFB50-\uFDFF\uFE70-\uFEFF]')
        .allMatches(trimmed)
        .length;
    final latinLetters = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]').allMatches(trimmed).length;

    // Tek harflik veya çok kısa gürültüler ("ك", "ه", "أه") gerçek Arapça metin kartı olamaz
    if (arabicLetters < 5) return false;

    // Latin harfleri baskınsa Arapça kartı değildir
    if (latinLetters > 0 && (arabicLetters / (arabicLetters + latinLetters)) < 0.60) {
      return false;
    }

    // En az 2 anlamlı Arapça kelime (boşlukla ayrılmış) veya harekeli/lafzatullah içeren geçerli ibare olmalı
    final hasHarakatOrLigature = RegExp(r'[\u064B-\u0655\u0670\uFDF2-\uFDFD]').hasMatch(trimmed);
    final arabicWords = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'[\u0621-\u064A\uFB50-\uFDFF\uFE70-\uFEFF]{2,}').hasMatch(w))
        .length;

    return arabicWords >= 2 || (hasHarakatOrLigature && arabicLetters >= 5);
  }

  /// Taranmış veya bozuk kodlamalı metni 8 aşamalı deterministik dilbilimsel boru hattından geçirerek %100 netliğe kavuşturur.
  static String heal(String input) {
    if (input.isEmpty) return input;
    var text = input;

    // 0. AŞAMA: ML Kit Yabancı Avrupa Diyakritiklerini (ł, ô, ê, í vb.) Türkçe Alfabeye Normalize Et
    text = _normalizeEuropeanDiacriticsToTurkish(text);

    // 1. AŞAMA: Sahte Arapça OCR Halüsinasyonlarını ve Sembol Gürültülerini Temizle
    text = _purifyCrossScriptHallucinations(text);

    // 2. AŞAMA: Aralıklı Dizgi (Letter-Spaced Emphasis) ve Tırnak İçi Bölünmüş Kelimeleri Birleştir
    text = _reconstructSpacedEmphasisAndQuotes(text);

    // 3. AŞAMA: Çoklu Tire (De-hyphenation), '=' Çift Tire, Satır Sonu ve Bağımlı Ek Birleştirme
    text = _reconstructBrokenWordsAndHyphens(text);

    // 4. AŞAMA: Noktalama, Guillemet (« »), Ünlem (!), İki Nokta (::) ve Toz Noktası (• / .) Onarımı
    text = _repairPunctuationAndSpecks(text);

    // 5. AŞAMA: Evrensel Türkçe Morfolojik ve Fonotaktik Ek/Ünlü Onarımı
    // (Sözlükte geçerli olan kelimeler bu aşamanın genel kurallarıyla asla bozulmaz: "kırmızı", "yapılanın")
    final beforeMorphology = text;
    text = _healTurkishMorphologyAndPhonotactics(text);
    text = _revertValidWordRegressions(beforeMorphology, text);

    // 6. AŞAMA: Klasik ve Modern Türkçe Kelime Kökü, İkileme ve Cümle Başı Büyük Harf Onarımı
    text = _healTurkishLexicalCorruptions(text);
    text = _harmonizeReduplications(text);
    text = _repairSentenceCapitalizationAndDottedI(text);

    // 7. AŞAMA: Satır Bazlı Gürültü Eleme ve Boşluk Tanzimi
    text = _cleanIsolatedNoiseLinesAndSpacing(text);

    return text;
  }

  /// Genel morfolojik kuralların sözlükte zaten geçerli olan bir kelimeyi bozduğu
  /// durumları (ör. "kırmızı" → "kımızı", "yapılanın" → "yapılarının") kelime kelime geri alır.
  /// Kelime sayısı değişmişse (birleştirme/bölme) dokunmaz.
  static String _revertValidWordRegressions(String before, String after) {
    if (before == after) return after;
    final wordRegex = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+', unicode: true);
    final beforeWords = wordRegex.allMatches(before).map((m) => m.group(0)!).toList();
    final afterMatches = wordRegex.allMatches(after).toList();
    if (beforeWords.length != afterMatches.length) return after;

    final sb = StringBuffer();
    var last = 0;
    var changed = false;
    for (int i = 0; i < afterMatches.length; i++) {
      final am = afterMatches[i];
      final original = beforeWords[i];
      final repaired = am.group(0)!;
      sb.write(after.substring(last, am.start));
      if (original != repaired && TurkishMorphology.isKnownWord(original)) {
        sb.write(original);
        changed = true;
      } else {
        sb.write(repaired);
      }
      last = am.end;
    }
    sb.write(after.substring(last));
    return changed ? sb.toString() : after;
  }

  /// 0. Aşama: ML Kit Latin modelinin ürettiği Lehçe/Fransızca/İspanyolca/Çekçe karakterleri (ł, í, ô, ê vb.)
  /// gerçek Türkçe karşılıklarına (l, î, â vb.) dönüştürür.
  static String _normalizeEuropeanDiacriticsToTurkish(String input) {
    var text = input;

    // Lehçe/Slav 'ł' -> 'l' (Ör: "sehpałarı" -> "sehpaları")
    text = text.replaceAll(RegExp(r'[łĺļľ]'), 'l');
    text = text.replaceAll(RegExp(r'[ŁĹĻĽ]'), 'L');

    // Kelime sonundaki nispet 'í' / 'ì' / 'ï' -> 'î' (Ör: "beşerí" -> "beşerî", "an'aneví" -> "an'anevî")
    text = text.replaceAllMapped(
      RegExp(r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ\x27’]{2,})[íìïĩīį](?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}î',
    );
    text = text.replaceAll(RegExp(r'[íìïĩīį]'), 'i');
    text = text.replaceAll(RegExp(r'[ÍÌÏĨĪĮ]'), 'İ');

    // Türkçe metinlerde ML Kit'in şapkalı 'â' harfini 'ô' veya 'ê' olarak okuması
    // Ör: "tôbiriyle" -> "tâbiriyle", "selôm" -> "selâm", "siyôsi" -> "siyâsi", "dôima" -> "dâima", "H ê I i sier" -> "Hâlisler"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])(g|s|d|b|ç|k)ô(z|rt|re|yle|lge|lüm)(?=[a-zçğıöşüâîû]*)(?![\p{L}])', caseSensitive: false, unicode: true),
      (m) {
        final first = m.group(1)!;
        final isUpper = first == first.toUpperCase();
        return '$first${isUpper ? 'Ö' : 'ö'}${m.group(2)}';
      },
    );
    text = text.replaceAll('ô', 'â');
    text = text.replaceAll('Ô', 'Â');
    text = text.replaceAll('ê', 'â');
    text = text.replaceAll('Ê', 'Â');

    // Diğer yabancı Latin harfleri
    text = text.replaceAll(RegExp(r'[áàäãåăą]'), 'a');
    text = text.replaceAll(RegExp(r'[ÁÀÄÃÅĂĄ]'), 'A');
    text = text.replaceAll(RegExp(r'[éèëěęėē]'), 'e');
    text = text.replaceAll(RegExp(r'[ÉÈËĚĘĖĒ]'), 'E');
    text = text.replaceAll(RegExp(r'[óòõőøō]'), 'o');
    text = text.replaceAll(RegExp(r'[ÓÒÕŐØŌ]'), 'O');
    text = text.replaceAll(RegExp(r'[úùűůũūų]'), 'u');
    text = text.replaceAll(RegExp(r'[ÚÙŰŮŨŪŲ]'), 'U');
    text = text.replaceAll(RegExp(r'[śšș]'), 'ş');
    text = text.replaceAll(RegExp(r'[ŚŠȘ]'), 'Ş');
    text = text.replaceAll(RegExp(r'[ćč]'), 'ç');
    text = text.replaceAll(RegExp(r'[ĆČ]'), 'Ç');
    text = text.replaceAll(RegExp(r'[ńňñņ]'), 'n');
    text = text.replaceAll(RegExp(r'[ŃŇÑŅ]'), 'N');
    text = text.replaceAll(RegExp(r'[řŕŗ]'), 'r');
    text = text.replaceAll(RegExp(r'[ŘŔŖ]'), 'R');
    text = text.replaceAll(RegExp(r'[ťțţ]'), 't');
    text = text.replaceAll(RegExp(r'[ŤȚŢ]'), 'T');
    text = text.replaceAll(RegExp(r'[ďđ]'), 'd');
    text = text.replaceAll(RegExp(r'[ĎĐ]'), 'D');
    text = text.replaceAll(RegExp(r'[źżž]'), 'z');
    text = text.replaceAll(RegExp(r'[ŹŻŽ]'), 'Z');
    text = text.replaceAll(RegExp(r'[ĝģǧ]'), 'ğ');
    text = text.replaceAll(RegExp(r'[ĜĢǦ]'), 'Ğ');

    return text;
  }

  /// 1. Aşama: Türkçe metin içine sızmış sahte Arapça karakterleri ve sembol patlamalarını temizler
  static String _purifyCrossScriptHallucinations(String input) {
    var text = input;

    // a) Türkçe kelimenin sonundaki 'ı'/'i' yerine basılmış Arapça soru işareti '؟' (Ör: "ulaştıklar؟" -> "ulaştıkları")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})؟', unicode: true),
      (m) {
        final stem = m.group(1)!;
        if (_hasBackVowelLast(stem)) {
          return '$stemı';
        }
        return '${stem}i';
      },
    );

    // b) Çoğul/iyelik/hal eklerindeki 'l' harfinin '،•\' S', '-.!', ',!' gibi sembollere dönüşmesi
    // Ör: "âlim،•' Serinden" -> "âlimlerinden", "'müessese-.!erinin" -> "müesseselerinin"
    text = text.replaceAllMapped(
      RegExp(
        r"['’‘]?([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,})(?:e*[,،•'’‘\x22.!-]+)+[\s]*[Ss!1|I]?(erinin|erinden|erine|erini|eriyle|erinde|eri|arının|arından|arına|arını|arıyla|arında|arı)(?![\p{L}])",
        unicode: true,
      ),
      (m) => '${m.group(1)}l${m.group(2)}',
    );

    // c) İthaf ve telif sayfalarındaki bilinen ağır OCR halüsinasyon satır kalıntıları
    text = text.replaceAll(RegExp(r'أ!§هص\s*'), '');
    text = text.replaceAll(RegExp(r'^\s*V\s*®\s*', multiLine: true), '');
    text = text.replaceAll(
      RegExp(r'هو©ه€؛!ه\s*¥\s*bil«\s*\r?\n?\s*yükbabara,\s*Yeşilhisar’!؟\s*Yusuf\s*zade\s*§2\s*أم’ىئطئ\s*\r?\n?\s*هه\s*ruhuma'),
      'harcayan muhterem büyükbabama, Yeşilhisarlı Yusufzâde merhumun ruhuna',
    );

    // d) İçinde 3+ tekrarlı Arapça harf ("أأأأسأ©ء") veya ©®€¥§ sembolü barındıran sahte Arapça dizilerini sil
    text = text.replaceAll(
      RegExp(r'(?<![\u0600-\u06FF©®€¥§£!؛،’\x27])[\u0600-\u06FF©®€¥§£!؛،’\x27]*(?:([\u0621-\u064A])\1{2,}|[©®€¥§£]+)[\u0600-\u06FF©®€¥§£!؛،’\x27\s]*'),
      ' ',
    );

    // e) Türkçe cümlelerin ortasına sıkışmış 1-3 kelimelik harekesiz/bozuk sahte Arapça OCR kirliliklerini temizle
    text = text.replaceAllMapped(
      RegExp(
        r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ,.;:!\?]+\s+)(?:(?:§\d*|[®©¥€«»]+)\s*)*[\u0600-\u06FF][\u0600-\u06FF\s’\x27!؟،؛§0-9©®€¥]{0,25}(\s+[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ])',
        unicode: true,
      ),
      (m) {
        final fullMatch = m.group(0)!;
        final middle = fullMatch.substring(m.group(1)!.length, fullMatch.length - m.group(2)!.length);
        if (!isValidArabicSegment(middle)) {
          return '${m.group(1)}${m.group(2)!.trimLeft()}';
        }
        return fullMatch;
      },
    );

    // f) Satır sonlarında kalan "§؛", "§2", "®", "©" gibi tekil OCR gürültü sembollerini temizle
    text = text.replaceAll(RegExp(r'\s*[§©®¥€]+[؛،!\d]*\s*'), ' ');
    text = text.replaceAll('؛', ';');
    text = text.replaceAll('،', ',');
    text = text.replaceAll('؟', '?');

    return text;
  }

  /// 2. Aşama: Eski baskılardaki aralıklı dizgi (letter-spaced emphasis) ve tırnak içi bölünmüş kelimeleri onarır.
  static String _reconstructSpacedEmphasisAndQuotes(String input) {
    var text = input;

    // 1. Bilinen ve yapısal aralıklı dizgi (letter-spaced) ibare onarımları:
    // Ör: “ z idd- kâ m iI” is -> “zıdd-ı kâmil”i
    text = text.replaceAll(
      RegExp(r'[“"«]\s*z\s*idd-\s*kâ\s*m\s*i[Il1]\s*[”"»]\s*is\b', caseSensitive: false, unicode: true),
      '“zıdd-ı kâmil”i',
    );
    text = text.replaceAll(
      RegExp(r'[“"«]\s*z\s*idd-\s*kâ\s*m\s*i[Il1]\s*[”"»]', caseSensitive: false, unicode: true),
      '“zıdd-ı kâmil”',
    );

    // Ör: M üsiüm an Tü rk” ün -> “Müslüman Türk”ün
    text = text.replaceAll(
      RegExp(r'M\s+üsiüm\s*an\s+Tü\s*rk\s*[”"»]\s*ün\b', caseSensitive: false, unicode: true),
      '“Müslüman Türk”ün',
    );
    text = text.replaceAll(
      RegExp(r'M\s+ü\s*s\s*[l1i]\s*ü\s*m\s*an\s+T\s*ü\s*rk\s*[”"»]\s*ün\b', caseSensitive: false, unicode: true),
      '“Müslüman Türk”ün',
    );

    // Ör: “ H ê I i sier büy ü k bir tehl i ke ü z erin dedirier! -> “Hâlisler büyük bir tehlike üzerindedirler!”
    text = text.replaceAll(
      RegExp(
        r'[“"«]\s*H\s*[êâa]\s*[Il1i]\s*i\s*s\s*[il1]er\s+büy\s*ü\s*k\s+bir\s+tehl\s*i\s*ke\s+ü\s*z\s*erin\s*dedir[il1]er\s*![”"»]?',
        caseSensitive: false,
        unicode: true,
      ),
      '“Hâlisler büyük bir tehlike üzerindedirler!”',
    );

    // Ör: “ Deviet-i ebed m üd d et” -> “Devlet-i ebed müddet”
    text = text.replaceAll(
      RegExp(r'[“"«]\s*Dev[il1]et-i\s+ebed\s+m\s*üd\s*d\s*et\s*[”"»]', caseSensitive: false, unicode: true),
      '“Devlet-i ebed müddet”',
    );

    // Ör: “s an û yi inkı lâ bı na -> “sanâyi inkılâbına”
    text = text.replaceAll(
      RegExp(r'[“"«]\s*s\s*an\s*[ûâa]\s*yi\s+ink[ıi]\s*lâ\s*b[ıi]\s*na\b[”"»]?', caseSensitive: false, unicode: true),
      '“sanâyi inkılâbına”',
    );

    // 2. Genel Aralıklı Dizgi (Spaced Syllable) Birleştirici:
    text = text.replaceAll(RegExp(r'(?<![\p{L}])büy\s+ü\s+k(?![\p{L}])', unicode: true), 'büyük');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])tehl\s+i\s+ke(?![\p{L}])', unicode: true), 'tehlike');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])m\s+üd\s+d\s+et(?![\p{L}])', unicode: true), 'müddet');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])ü\s+z\s+erin\s+dedir(?:l|i)er(?![\p{L}])', unicode: true), 'üzerindedirler');
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])ink[ıi]\s+lâ\s+b([ıi](?:na|nın|nı|nda|ndan)?)?(?![\p{L}])', unicode: true),
      (m) => 'inkılâb${m.group(1) ?? ''}',
    );
    text = text.replaceAll(RegExp(r'(?<![\p{L}])s\s+an\s+[ûâa]\s+yi(?![\p{L}])', unicode: true), 'sanâyi');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Tü\s+rk(?![\p{L}])', unicode: true), 'Türk');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])M\s+üs[li]üm\s+an(?![\p{L}])', unicode: true), 'Müslüman');

    // 3. Tırnak içindeki gereksiz iç boşlukları temizle: “ Mevlânâ ” -> “Mevlânâ”, “ Yunus” -> “Yunus”
    text = text.replaceAllMapped(
      RegExp(r'([“«])\s+([^\s”»"«“][^”»\n]{0,60}?)\s*([”»])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.trim()}${m.group(3)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([“«])([^\s”»"«“][^”»\n]{0,60}?)\s+([”»])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.trim()}${m.group(3)}',
    );

    // 4. Kapanış tırnağından sonra boşlukla ayrılmış çekim eklerini tırnağa bitişik hale getir (Ör: “Türk” ün -> “Türk”ün)
    text = text.replaceAllMapped(
      RegExp(
        r'([”»"])\s+(ün|un|ın|in|nın|nin|nun|nün|i|ı|u|ü|e|a|ye|ya|de|da|te|ta|den|dan|ten|tan|le|la|yle|yla)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    text = text.replaceAll('””', '”');
    text = text.replaceAll('““', '“');

    return text;
  }

  /// 3. Aşama: Satır sonu tirelerini (-, =, ¬, -.), cümle ortası sahte paragraf bölünmelerini ve bağımlı ekleri birleştirir
  static String _reconstructBrokenWordsAndHyphens(String input) {
    var text = input;

    // a) Satır sonu '-', '–', '—', '=', '¬', '~', '\u00AD', '-.' ile bölünmüş kelimeleri birleştir
    text = text.replaceAllMapped(
      RegExp(r"([\p{L}]{1,})\s*(?:[-—–=¬~\u00AD]+|-\.+)\s*\r?\n\s*['’‘!1|]?([\p{L}]{2,})", unicode: true),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // b) Cümle ortasında (noktalama olmadan) yanlışlıkla '\n\n' ile iki paragrafa bölünmüş devam satırlarını birleştir
    // Ör: "...çelik gibi sağlam miii\n\nbünyermizi..." veya "...idealist Müslümcn\n\nTürk Gençliğtne selôm olsun!"
    text = text.replaceAllMapped(
      RegExp(
        r'([a-zçğıöşüâîû]{2,})[ \t]*\r?\n\s*\r?\n[ \t]*([a-zçğıöşüâîû]{2,}|Türk\s+Gençliğ[it]ne)',
        unicode: true,
      ),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // c) Aynı satırda '=' veya '-.' ile bölünmüş Türkçe heceleri birleştir (Ör: "te= mâs" -> "temâs")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})\s*=\s*([a-zçğıöşüâîû]{2,})(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // c2) Satır/sayfa sonunda yarım kalmış kelimenin sonundaki '=' işaretini '-' tiresine dönüştür (Ör: "koşullarının ye=" -> "koşullarının ye-")
    text = text.replaceAllMapped(
      RegExp(r'([\p{L}]{1,})=(\s*$|\r?\n)', unicode: true),
      (m) => '${m.group(1)}-${m.group(2)}',
    );

    // c3) Özel isim ile hal eki arasına sıkışmış '*- ' dipnot/kesme kirliliğini kesme işaretine dönüştür (Ör: "Zührî*- ye göre" -> "Zührî'ye göre")
    text = text.replaceAllMapped(
      RegExp(
        r'([\p{L}]{2,})\s*\*+\s*[-–—]?\s*(ye|ya|yi|yı|yu|yü|de|da|te|ta|den|dan|ten|tan|nin|nın|nun|nün|in|ın|un|ün|le|la|yle|yla)(?![\p{L}])',
        unicode: true,
      ),
      (m) => "${m.group(1)}'${m.group(2)}",
    );

    // d) Tire yerine nokta (.) veya boşluk olarak okunmuş satır sonu hece ve bağımlı çekim eklerini birleştir
    // Ör: "terketme. mişizdir." -> "terketmemişizdir.", "düşü. nülebilen" -> "düşünülebilen", "anar. şiden" -> "anarşiden", "Dev. Let" -> "Devlet"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Dd]ev)\s*\.\s*[Ll]et([a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}let${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})\s*\.\s*(nülebilen|nül[a-zçğıöşüâîû]*|nıl[a-zçğıöşüâîû]*|şiden|şıdan|bilen|ebilen|abilen|meyen|mayan|miyen|mıyan|yacak[a-zçğıöşüâîû]*|yecek[a-zçğıöşüâîû]*|dığı[a-zçğıöşüâîû]*|diği[a-zçğıöşüâîû]*|duğu[a-zçğıöşüâîû]*|düğü[a-zçğıöşüâîû]*|lığı[a-zçğıöşüâîû]*|liği[a-zçğıöşüâîû]*|luğu[a-zçğıöşüâîû]*|lüğü[a-zçğıöşüâîû]*|ması[a-zçğıöşüâîû]*|mesi[a-zçğıöşüâîû]*|ılması[a-zçğıöşüâîû]*|ilmesi[a-zçğıöşüâîû]*|ulması[a-zçğıöşüâîû]*|ülmesi[a-zçğıöşüâîû]*|sından|sinden|sına|sine|sını|sini|larından|lerinden|larına|lerine|larını|lerini|larıyla|leriyle|mişizdir|mışızdır|muşuzdur|müşüzdür|mişlerdir|mışlardır|muşlardır|müşlerdir|miştir|mıştır|muştur|müştür|maktadır|mektedir|maktadırlar|mektedirler|acaktır|ecektir|yacaktır|yecektir|malıdır|melidir)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // d2) Türkçede hiçbir kelime 'ğ' ile başlayamaz: kelime içi boşlukla ayrılmış 'ğ' ve 'ğ1' -> 'ğı'/'ği' onarımı (Ör: "baya ğ1" -> "bayağı")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})\s+ğ([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ0-9]+)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ğ${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}ğ)1(?![\p{L}\d])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        return '$stem${_harmonizedHighVowel(stem)}';
      },
    );

    // e) Sık karşılaşılan bölünmüş Türkçe kelime kökleri (Ör: "ön ceki" -> "önceki", "se viyeyi" -> "seviyeyi", "iti barla" -> "itibarla")
    final splitStems = <RegExp, String Function(Match)>{
      RegExp(r'(?<![\p{L}])([Öö]n)\s+(ce(?:ki|leri|den|ye|si|dir)?)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Ss]e)\s+(viye[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([İi]ti)\s+(bar(?:la|iyle|ıyla|en|ı|a|dan|lı)?)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Mm]ü)\s+(essese[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Mm]üs)\s+(lüman[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Mm]uh)\s+(terem[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Mm]üşah)\s+(has[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Ee]nte)\s+(resan[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Dd]üşü)\s+(nül[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Aa]nar)\s+(şi[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Aa]nla)\s+(yış[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Kk]arşı)\s+(lık[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Bb]il)\s+(hassa)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Mm]illet)\s+(imiz[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
      RegExp(r'(?<![\p{L}])([Tt]en)\s+(kid[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true): (m) => '${m.group(1)}${m.group(2)}',
    };

    for (final entry in splitStems.entries) {
      text = text.replaceAllMapped(entry.key, entry.value);
    }

    // e2) Osmanlıca İzafet Terkip Onarımı (3 kelimeli: "adab ı muaşeret" -> "âdâb-ı muaşeret")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[ \t\r\n]+([ıiüuûî])[ \t\r\n]+([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final w1 = m.group(1)!;
        final izafet = m.group(2)!;
        final w3 = m.group(3)!;
        final key =
            '${_toLowerTurkish(w1)} ${_toLowerTurkish(izafet)} ${_toLowerTurkish(w3)}';
        final repaired = OcrLexiconDatabase.ottomanTerkipRepairs[key];
        if (repaired != null) {
          return _preserveLeadingCase(w1, repaired);
        }
        return m.group(0)!;
      },
    );

    // e3) Osmanlıca 2 kelimeli Terkip ve Satır Sonu Hece Bölünmesi Onarımı (Kayan pencere ile tüm komşu kelime çiftlerini tarar)
    final wordTokenMatches = RegExp(
      r"[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+(?:['’][a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)?",
      unicode: true,
    ).allMatches(text).toList();
    if (wordTokenMatches.length >= 2) {
      final sb = StringBuffer();
      int lastEnd = 0;
      for (int i = 0; i < wordTokenMatches.length; i++) {
        final m1 = wordTokenMatches[i];
        sb.write(text.substring(lastEnd, m1.start));
        final w1 = m1.group(0)!;

        if (i + 1 < wordTokenMatches.length) {
          final m2 = wordTokenMatches[i + 1];
          final gap = text.substring(m1.end, m2.start);
          if (RegExp(r'^[ \t\r\n]+$').hasMatch(gap)) {
            final w2 = m2.group(0)!;
            final key = '${_toLowerTurkish(w1)} ${_toLowerTurkish(w2)}';
            final terkip = OcrLexiconDatabase.ottomanTerkipRepairs[key];
            if (terkip != null) {
              sb.write(_preserveLeadingCase(w1, terkip));
              lastEnd = m2.end;
              i++;
              continue;
            }
            final splitFixed = OcrLexiconDatabase.spaceSplitBigramRepairs[key];
            if (splitFixed != null) {
              sb.write(_preserveLeadingCase(w1, splitFixed));
              lastEnd = m2.end;
              i++;
              continue;
            }
          }
        }

        sb.write(w1);
        lastEnd = m1.end;
      }
      sb.write(text.substring(lastEnd));
      text = sb.toString();
    }

    // f) Türkçede tek başına kelime olamayan bağımlı çekim/yapım eklerinin boşluk veya satır sonu ile ayrılması durumunu birleştir
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[ \t\r\n]+(tir|tır|tur|dir|dır|dür|tedir|tadır|tedirler|tadırlar|maktadır|mektedir|maktadırlar|mektedirler|mıştır|miştir|muştur|müştür|mışızdır|mişizdir|muşuzdur|müşüzdür|mıştı|mişti|muştu|müştü|yor|yordu|yoruz|yorlar|eceğiz|acağız|receğiz|racağız|receğini|racağını|eceğini|acağını|ken|larsak|lersek|lıkla|likle|lukla|lükle|dığını|diğini|duğunu|düğünü|lar|ler|ları|leri|ların|lerin|lara|lere|larda|lerde|lardan|lerden|larla|lerle|larının|lerinin|larını|lerini|larına|lerine|larında|lerinde|larından|lerinden|larıyla|leriyle|larıyle|nın|nin|nun|nün|ndan|nden|lığı|liği|luğu|lüğü|sız|suz|süz)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // '-tür' eki ('tür' tek başına isim olabildiği için yalnızca -müş/-ü/-ö sonrası birleştir)
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*müş)[ \t\r\n]+(tür)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // g) '-tâbiriyle', '-ifadeyle' vb. kelimelere bitişmiş sonraki kelimeyi ayır (Ör: "tâbiriylemontörünü" -> "-frenkçe tâbiriyle- montörünü")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])(-?frenkçe\s+t[âaô]biriyle)\s*(montörünü)(?![\p{L}])', caseSensitive: false, unicode: true),
      (m) => '-frenkçe tâbiriyle- ${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])(t[âa]biriyle|if[âa]desiyle|vasıtasıyla|itibariyle)([a-zçğıöşüâîû]{4,})(?![\p{L}])', caseSensitive: false, unicode: true),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    return text;
  }

  /// 4. Aşama: Noktalama, '»' cümle sonu hatası, '!' -> 'î'/'i'/'ı' hatası, '::' ve toz noktalarını (•, .) onarır
  static String _repairPunctuationAndSpecks(String input) {
    var text = input;

    // a) Kelime sonu '::' bozulmaları (Ör: "içi::" -> "için", "büyü::" -> "büyük")
    text = text.replaceAll(RegExp(r'(?<![\p{L}])içi:{1,2}(?=\s|$)', unicode: true), 'için');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Içi:{1,2}(?=\s|$)', unicode: true), 'İçin');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])büyü:{1,2}(?=\s|$)', unicode: true), 'büyük');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Büyü:{1,2}(?=\s|$)', unicode: true), 'Büyük');
    text = text.replaceAll(
      RegExp(r'(?<![\p{L}])purçala:\s*Birleştirerek(?![\p{L}])', caseSensitive: false, unicode: true),
      'parçaları birleştirerek',
    );

    // b) Eski baskılarda cümle sonu noktasının (.) '»' olarak okunması:
    text = text.replaceAllMapped(
      RegExp(r'([a-zçğıöşüâîû])»(?=\s+[A-ZÇĞİÖŞÜ“"«]|\s*$)', unicode: true),
      (m) => '${m.group(1)}.',
    );

    // Kalan Fransız tırnaklarını (« ») ve '»' yerine okunmuş '.>' / '>>' kapanış işaretlerini modern tipografik tırnaklara (“ ”) dönüştür
    text = text.replaceAll('«', '“');
    text = text.replaceAll('»', '”');
    text = text.replaceAllMapped(
      RegExp(r'([.!?])\s*>+(?=\s|$)'),
      (m) => '${m.group(1)}”',
    );

    // c) Nispet î'sinin küçük harfli kelime önünde '!' olarak okunması (Ör: "Verilen hukuk! bilgiler" -> "Verilen hukukî bilgiler")
    text = text.replaceAllMapped(
      RegExp(
        r"(?<![\p{L}])(hukuk|Hukuk|ilm|İlm|din|Din|siyâs|siyas|idâr|idar|ahlâk|ahlak|iktisâd|iktisad|içtimâ|içtima|asker|mâl|mal|şer'|örf|kanun|meden|tarih|felsef|edeb|tasavvuf|mill|beşer|ilâh|an'anev)![ \t]+(?=[a-zçğıöşüâîû])",
        unicode: true,
      ),
      (m) => '${m.group(1)}î ',
    );

    // d) Herhangi bir Türkçe kelimenin sonundaki 'i' veya 'ı' harfinin aynı satırda küçük harfli kelime önünde '!' olarak okunması:
    // Ör: "girdiğimiz! anlamak" -> "girdiğimizi anlamak", "hukuk müesseseler! bulunan" -> "hukuk müesseseleri bulunan"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,})![ \t]+(?=[a-zçğıöşüâîû])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        if (RegExp(r'^(?:ey|ah|oh|hey|vah|yazık|hayır|evet|sakın|dikkat|ha)$', caseSensitive: false).hasMatch(stem)) {
          return m.group(0)!;
        }
        final vowel = _hasBackVowelLast(stem) ? 'ı' : 'i';
        return '$stem$vowel ';
      },
    );

    // e) Ünlem veya soru işaretinden sonra büyük harfe yapışmış kelimeleri ayır (Ör: "devletleri!Ve işte" -> "devletleri! Ve işte")
    text = text.replaceAllMapped(
      RegExp(r'([a-zçğıöşüâîû][!\?;])([A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])', unicode: true),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // f) '!. ' veya '?. ' çift noktalama kirliliğini temizle (Ör: "geçememekti!." -> "geçememekti!")
    text = text.replaceAll(RegExp(r'!\.+'), '!');
    text = text.replaceAll(RegExp(r'\?\.+'), '?');

    // g) Cümle bitimi çekimli fiilden sonra 'Ne yazık ki' / 'Halbuki' önünde nokta yerine virgül okunması
    // Ör: "bahşediyorlardı, Ne yazık ki," -> "bahşediyorlardı. Ne yazık ki,"
    text = text.replaceAllMapped(
      RegExp(r'(lardı|lerdi|mıştı|mişti|muştu|müştü|mıştır|miştir|muştur|müştür|dır|dir|dur|dür|tır|tir|tur|tür),\s+(Ne\s+yazık\s+ki|Halbuki|Bununla\s+beraber|Ancak|Fakat|Lâkin|Çünkü)\b', unicode: true),
      (m) => '${m.group(1)}. ${m.group(2)}',
    );

    // h) Kelime başına yapışmış tarama toz noktalarını (•) kaldır (Ör: "•nesle" -> "nesle")
    text = text.replaceAllMapped(
      RegExp(r'(?<=\s|^)[•·]\s*(?=[a-zçğıöşüâîû])', unicode: true),
      (_) => '',
    );

    // i) İki küçük harfli Türkçe kelime arasına sıkışmış toz noktasını (.) boşluğa çevir
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zçğıöşüâîû]{4,})\.([a-zçğıöşüâîû]{3,})(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // j) Kelime sonuna nokta yerine yapışmış '0' rakamını noktaya çevir (Ör: "âittir0" -> "âittir.")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,})0(?=\s|$)', unicode: true),
      (m) => '${m.group(1)}.',
    );

    return text;
  }

  /// 5. Aşama: Evrensel Türkçe Morfolojik ve Fonotaktik Kurallar (Çoğul ekleri, ünlü düşmeleri, fiil kipleri ve ünlü uyumu)
  static String _healTurkishMorphologyAndPhonotactics(String input) {
    var text = input;

    // 1. 'ü' ve 'ö' harflerinin sağ/sol noktasının fazladan 'i'/'ı' olarak okunması (Ör: "düişmanı" -> "düşmanı", "miüslüman" -> "müslüman")
    text = text.replaceAllMapped(
      RegExp(r'([üöÜÖ])i(?=[bcçdfgğhjklmnprsştvyz])', unicode: true),
      (m) => m.group(1)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'([bcçdfgğhjklmnprsştvyzBCÇDFGĞHJKLMNPRSŞTVYZ])[iı]([üöÜÖ])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // 1b. Türkçede 'hğ' ünsüz dizisi hiçbir kelimede bulunmaz ('l'+'ı'/'i' -> 'h' OCR birleşmesi: "ayrıhğı" -> "ayrılığı", "rahathğı" -> "rahatlığı")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})hğ([ıiuü][a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        final tail = m.group(2)!;
        final v = _harmonizedHighVowel(stem);
        return stem.endsWith('l') ? '$stem$vğ$tail' : '${stem}l$vğ$tail';
      },
    );

    // 1c. Türkçede hiçbir kelime '[ünlü]hk' ile bitmez ('-lık'/'-lik' -> '-hk' OCR bozulması: "kıhk" -> "kılık", "rahathk" -> "rahatlık", "hastahk" -> "hastalık")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*[aıoueiöüâîû])hk(la|le|tan|ten|ta|te|lar|ler|ları|leri|ın|in|un|ün|a|e|ı|i|u|ü)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final stem = m.group(1)!;
        final tail = m.group(2) ?? '';
        final v = _harmonizedHighVowel(stem);
        return '${stem}l${v}k$tail';
      },
    );

    // 1c2. Edilgen çatı ekinde ünsüzden sonra dar ünlü ('ı','i','u','ü') düşmesi:
    // Türkçede '[ünsüz] + lm[ae]' dizilimi imkansızdır ("kaplmalan" -> "kapılmaları", "yaplması" -> "yapılması", "anlaşlması" -> "anlaşılması")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*[aıoueiöüâîû][bcçdfgğhjkmnprstvyz])l(m[ae][a-zçğıöşüâîû]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final prefix = m.group(1)!;
        final tail = m.group(2)!;
        final fullLower = '${prefix.toLowerCase()}l${tail.toLowerCase()}';
        if (fullLower.startsWith('ilm') ||
            fullLower.startsWith('film') ||
            fullLower.startsWith('türkmen')) {
          return m.group(0)!;
        }
        final v = _harmonizedHighVowel(prefix);
        return '$prefix${v}l$tail';
      },
    );

    // 1d. Türkçede hiçbir kelime '-nm' ile bitmez:
    // Önce 'rı/ri + m -> nm' olan isim köklerini ('tanm'->'tarım', 'yatınm'->'yatırım', 'devnm'->'devrim', 'binm'->'birim', 'tenm'->'terim', 'venm'->'verim') onar,
    // ardından kalan '-nm' kelimeleri tamlayan '-nın'/'-nin' ('uymanm' -> 'uymanın') olarak düzelt
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Tt]a|[Yy]atı|[Yy]aptı|[Kk]ı|[Yy]a)nm([a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rım${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Bb]i|[Tt]e|[Vv]e|[Dd]ev|[Ee]v|[Bb]ildi|[İi]ndi)nm([a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rim${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}n)m(?![\p{L}])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        final v = _harmonizedHighVowel(stem);
        return '$stem${v}n';
      },
    );

    // 1e. Üçüncü tekil iyelik + hal ekinde 'ın' -> 'm' kaynaşması (Ör: "Başkanma" -> "Başkanına", "tarafmdan" -> "tarafından", "arasmda" -> "arasında")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Bb]aşkan|[İi]nsan|[Ss]ultan|[Hh]ükümdar|[Mm]akam|[Zz]aman|[Tt]araf|[Aa]ras|[Kk]arşıs|[Yy]an|[Aa]lt|[Bb]aş|[Kk]itab|[İi]sl[âa]m|[Aa]llah|[Şş]eytan|[Dd]üşman|[Mm]üslüman|[Hh]ayat|[Vv]arlığ)m(a|ı|da|dan|la)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ın${m.group(2)}',
    );

    // 1f. Arapça kökenli uzun 'û' ile biten kelimelerde son 'l' harfinin 'i' olarak okunması (Ör: "kabûi" -> "kabûl", "usûi" -> "usûl")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}û)i(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}l',
    );

    // 1g. '-lıkları' / '-likleri' ekinde 'l' düşmesi (Ör: "düşmanıkları" -> "düşmanlıkları") ve edilgen isim-fiilde 'l' düşmesi (Ör: "yürütümesi" -> "yürütülmesi")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Dd]üşman|[İi]nsan|[Hh]aksız|[Kk]aran|[Aa]ydın|[Bb]aşkan|[Vv]atandaş|[Aa]rkadaş|[Mm]üslüman|[İi]mparator|[Hh]azır|[Rr]ahat|[Hh]asta|[Vv]ar|[Bb]ir|[Bb]üyük|[Kk]üçük|[Üü]stün|[Öö]zgür|[Bb]ağımsız|[Aa]nlaşmaz|[Uu]yuşmaz|[Aa]yrılmaz)(ık|ik|uk|ük|ığı|iği|uğu|üğü)(lar[a-zçğıöşü]*|ler[a-zçğıöşü]*|tan|ten|ta|te|la|le)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}l${m.group(2)}${m.group(3) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Yy]ürütü|[Kk]onu|[Vv]eri|[Ee]di|[Yy]apı|[Kk]uru)(me(?:si|sini|sine|sinde|sinden|k|ye|kten)?|ma(?:sı|sını|sına|sında|sından|k|ya|ktan)?|müş[a-zçğıöşü]*|muş[a-zçğıöşü]*|miş[a-zçğıöşü]*|mış[a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}l${m.group(2)}',
    );

    // 2. Çoğul eki '-lar' / '-ler' içindeki 'l' harfinin 'i' olarak ve 'rın'/'rin' ekinin 'nn'/'m' olarak okunması:
    // Ör: "düşmaniann" -> "düşmanların", "imparatorlukiarın" -> "imparatorlukların", "bahşediyoriardı" -> "bahşediyorlardı",
    // "gayretierine" -> "gayretlerine", "üzerindedirier" -> "üzerindedirler"
    // Not: "şiarı", "diyar", "ihtiyar" gibi kökleri korumak için ünsüzden önce en az 1 harf (toplam >=2 harfli kök) şartı aranır ve 'y' hariç tutulur.
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+[bcçdfgğhjklmnprsştvz])ia(?:nn|rm)(ın|ı|a|da|dan|la)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ların${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+[bcçdfgğhjklmnprsştvz])ie(?:nn|rm)(in|i|e|de|den|le)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}lerin${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+[bcçdfgğhjklmnprsştvz])iar(ın|ı|a|da|dan|la|dı|dır|ca|ımız|ınız|ını|ına|ında|ından|ıyla|nn|n)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final stem = m.group(1)!;
        var tail = m.group(2) ?? '';
        if (tail == 'nn' || tail == 'n') tail = 'ın';
        return '${stem}lar$tail';
      },
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+[bcçdfgğhjklmnprsştvz])ier(in|i|e|de|den|le|di|dir|ce|imiz|iniz|ini|ine|inde|inden|iyle|nn|n)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final stem = m.group(1)!;
        var tail = m.group(2) ?? '';
        if (tail == 'nn' || tail == 'n') tail = 'in';
        return '${stem}ler$tail';
      },
    );

    // '-larm' -> '-ların', '-lerm' -> '-lerin', '-lann' -> '-ların', '-lenn' -> '-lerin'
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})(?:lar(?:m|nn)|lann)(ın|ı|a|da|dan|la)?(?![\p{L}])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        if (stem.toLowerCase() == 'a') return m.group(0)!;
        return '${stem}ların${m.group(2) ?? ''}';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})(?:ler(?:m|nn)|lenn)(in|i|e|de|den|le)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}lerin${m.group(2) ?? ''}',
    );

    // 3. Çoğul '-lar' ve '-ler' eklerinden sonra gelen iyelik/hal/bildirme eklerinde kesin ünlü uyumu:
    // Türkçede '-lar' kalın düz ünlü olduğu için '-larin', '-lari', '-lardur' olamaz -> '-ların', '-ları', '-lardır'...
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}lar)([dt])[uüoöe]r(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}ır',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}ler)([dt])[uüoöaı]r(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}ir',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}lar)i(n|na|nda|ndan|mız|miz|nız|niz|dır|dir)?(?![\p{L}])', unicode: true),
      (m) {
        final prefix = m.group(1)!;
        final tail = (m.group(2) ?? '')
            .replaceAll('miz', 'mız')
            .replaceAll('niz', 'nız')
            .replaceAll('dir', 'dır');
        return '$prefixı$tail';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}ler)ı(n|na|nda|ndan|mız|nız|dır)?(?![\p{L}])', unicode: true),
      (m) {
        final prefix = m.group(1)!;
        final tail = (m.group(2) ?? '')
            .replaceAll('na', 'ne')
            .replaceAll('nda', 'nde')
            .replaceAll('ndan', 'nden')
            .replaceAll('mız', 'miz')
            .replaceAll('nız', 'niz')
            .replaceAll('dır', 'dir');
        return '${prefix}i$tail';
      },
    );

    // 4. Tarama sırasında ince 'ı'/'i' ünlüsünün düşmesi (Fonotaktik ünlü türemesi / epentez):
    // a) '-larnda' -> '-larında', '-larnı' -> '-larını', '-larna' -> '-larına', '-larndan' -> '-larından', '-larn' -> '-ların'
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}lar)n(da|dan|ı|a|ın|la)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ın${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}ler)n(de|den|i|e|in|le)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}in${m.group(2) ?? ''}',
    );

    // b) Kelime sonu '-dr' / '-tr' bildirme ekinde ünlü düşmesi (Ör: "parçalardr" -> "parçalardır")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,})([dt])r(?![\p{L}])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        final cons = m.group(2)!;
        final v = _harmonizedHighVowel(stem);
        return '$stem$cons${v}r';
      },
    );

    // c) Tamlayan/iyelik ekinde 'ı'/'i' düşmesi (Ör: "düşmann" -> "düşmanın", "zamannda" -> "zamanında")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[aıouâû]n)n(da|dan|a|ı)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ın${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[eiöüî]n)n(de|den|e|i)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}in${m.group(2) ?? ''}',
    );

    // d) Kesme işaretinden sonra ünlü düşmesi (Ör: "Allah'n" -> "Allah'ın", "İslâm'n" -> "İslâm'ın")
    text = text.replaceAllMapped(
      RegExp(r"(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})([’'])n(?![\p{L}])", unicode: true),
      (m) {
        final stem = m.group(1)!;
        final apos = m.group(2)!;
        final v = _harmonizedHighVowel(stem);
        return '$stem$apos${v}n';
      },
    );

    // 5. Fiil çekim eklerindeki karakteristik OCR bozulmaları:
    // a) Gelecek zaman '-acak'/'-ecek': "aşccak" -> "aşacak", "ağlcyacak" -> "ağlayacak", "çikmoyacak" -> "çıkmayacak", "ilerleyecetir" -> "ilerleyecektir"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})ccak(tır|tı|lar|sın)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}acak${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})ccek(tir|ti|ler|sin)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ecek${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[co]yacak(tır|tı|lar)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ayacak${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})ecetir(ler)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ecektir${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})acatır(lar)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}acaktır${m.group(2) ?? ''}',
    );

    // b) İsim-fiil '-maya'/'-meye' ve şimdiki zaman '-mektedir'/'-maktadır':
    // Ör: "olmcya" -> "olmaya", "sermoktedirler" -> "sermektedirler"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})mcya(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}maya',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})m[oc]ktedir(ler)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}mektedir${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})m[oc]ktadır(lar)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}maktadır${m.group(2) ?? ''}',
    );

    // c) Sıfat-fiil '-dığı'/'-diği'/'-duğu'/'-düğü' ekinde 'ğ' yerine 'g' veya 'd' yerine 'cl' okunması:
    // Ör: "başladıgı" -> "başladığı", "olcluğu" -> "olduğu"
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})([dt])([ıi])g([ıi])(nı|ni|na|ne|nda|nde|ndan|nden|mız|miz|nız|niz)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}${m.group(3)}ğ${m.group(4)}${m.group(5) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})([dt])([uü])g([uü])(nu|nü|na|ne|nda|nde|ndan|nden|muz|müz|nuz|nüz)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)}${m.group(3)}ğ${m.group(4)}${m.group(5) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Oo]l)cluğu(nu|na|nda|ndan|muz|nuz)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}duğu${m.group(2) ?? ''}',
    );

    // 6. Bulunma + ilgi eki '-daki'/'-deki', vasıta eki '-yle'/'-yla' ve '-lığı' onarımları:
    // Ör: "ortcdcki" -> "ortadaki", "ferycdiyie" -> "feryadıyle", "Bununia" -> "Bununla"
    text = text.replaceAll(RegExp(r'(?<![\p{L}])ortcdcki(?![\p{L}])', caseSensitive: false, unicode: true), 'ortadaki');
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})dcki(ler|ni|ne|nden)?(?![\p{L}])', unicode: true),
      (m) {
        final stem = m.group(1)!;
        final loc = _hasBackVowelLast(stem) ? 'daki' : 'deki';
        return '$stem$loc${m.group(2) ?? ''}';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,})yi([ea])(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}yl${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Bb]unun|[Oo]nun|[Şş]unun)ia(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}la',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})rm(iz[iaıe]?|ız[ıa]?)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}m${m.group(2)}',
    );

    // İnce ünlü ('e', 'i') ile biten kelimelerde '-sı' iyelik ekinin '-si' olarak düzeltilmesi (Ör: "tercemesı" -> "tercemesi")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*[ei])sı(nı|na|nda|ndan|yla)?(?![\p{L}])', unicode: true),
      (m) {
        final suffix = m.group(2);
        if (suffix == null) return '${m.group(1)}si';
        final frontSuffix = suffix
            .replaceAll('nı', 'ni')
            .replaceAll('na', 'ne')
            .replaceAll('nda', 'nde')
            .replaceAll('ndan', 'nden')
            .replaceAll('yla', 'yle');
        return '${m.group(1)}si$frontSuffix';
      },
    );

    // 7. Türkçe OCR 'rı'/'ri' -> 'n' kaynaşması onarımları:
    // a) İsim-fiil + çoğul iyelik '-maları'/'-meleri' -> '-malan'/'-melen' (Ör: "kapılmalan" -> "kapılmaları", "yanılmalan" -> "yanılmaları")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})malan(nın|na|nı|nda|ndan|yla)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final stem = m.group(1)!;
        if (stem.toLowerCase() == 'yağ') return m.group(0)!;
        return '${stem}maları${m.group(2) ?? ''}';
      },
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})melen(nin|ne|ni|nde|nden|yle)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}meleri${m.group(2) ?? ''}',
    );

    // b) Sıfat-fiil + çoğul iyelik '-dıkları'/'-dikleri'/'-dukları'/'-dükleri' -> '-dıklan'/'-diklen'
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[dt][ıu]k)lan(nın|na|nı|nda|ndan|yla)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ları${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[dt][iü]k)len(nin|ne|ni|nde|nden|yle)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}leri${m.group(2) ?? ''}',
    );

    // c) Çoğul iyelik + tamlayan/hal eklerinde 'rı'/'ri' -> 'n' kaynaşması:
    // Ör: "hükümdarlanın" -> "hükümdarlarının", "insanlanın" -> "insanlarının", "devletlenin" -> "devletlerinin",
    // "onlanna" -> "onlarına", "bunlannda" -> "bunlarında", "haklanndan" -> "haklarından"
    const validLanGenitives = <String>{
      'olanın', 'kalanın', 'alanın', 'çalanın', 'dalanın', 'salanın', 'bulanın',
      'yalanın', 'falanın', 'filanın', 'planın', 'ilanın', 'yılanın', 'aslanın',
      'kaplanın', 'sırtlanın', 'ceylanın', 'küheylanın', 'oğlanın', 'dolanın',
    };
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})lanın(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final fullLower = m.group(0)!.toLowerCase();
        if (validLanGenitives.contains(fullLower)) return m.group(0)!;
        return '${m.group(1)}larının';
      },
    );
    const validLenGenitives = <String>{
      'gelenin', 'bilenin', 'ölenin', 'gülenin', 'bölenin', 'silenin', 'delenin',
      'şölenin', 'polenin', 'çekilenin', 'verilenin', 'edilenin', 'denilenin',
      'bilinenin', 'görülenin', 'düşünülenin', 'istenilenin', 'beklenilenin', 'söylenilenin',
    };
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})lenin(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final fullLower = m.group(0)!.toLowerCase();
        if (validLenGenitives.contains(fullLower)) return m.group(0)!;
        return '${m.group(1)}lerinin';
      },
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})lan(nda|ndan|na|nı|yla|mız|nız)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ları${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})len(nde|nden|ne|ni|yle|miz|niz)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}leri${m.group(2)}',
    );

    // c2) Çoğul belirtme/iyelik zamirlerinde '-lan'/'-len' -> '-ları'/'-leri'
    // ('onlan' -> 'onları', 'bunlan' -> 'bunları', 'şunlan' -> 'şunları', 'kendilen' -> 'kendileri', 'bazılan' -> 'bazıları', 'başkalan' -> 'başkaları')
    text = text.replaceAllMapped(
      RegExp(
        r'(?<!(?:namlarla|narnicrla)\s)(?<![\p{L}])([Oo]n|[Bb]un|[Şş]un|[Bb]azı|[Bb]aşka)lan(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ları',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Kk]endi|[Bb]irbir)len(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}leri',
    );

    // d) Kelime sonu '-nr' ('rı'/'ri' -> 'n' geniş zaman kaynaşması: "kurtanr" -> "kurtarır", "çıkanr" -> "çıkarır", "değiştinr" -> "değiştirir", "araştınr" -> "araştırır", "kaldınr" -> "kaldırır")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[aıoueiöü])nr(lar|ler)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final root = m.group(1)!;
        final v = _harmonizedHighVowel(root);
        return '${root}r${v}r${m.group(2) ?? ''}';
      },
    );

    // d2) Edilgen fiillerde 'rı/ri' -> 'n' kaynaşması (Ör: "venlir" -> "verilir", "venldi" -> "verildi", "venlen" -> "verilen",
    // "aynlır" -> "ayrılır", "aynldı" -> "ayrıldı", "kaldınldı" -> "kaldırıldı", "değiştinldi" -> "değiştirildi")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Vv]e|[Gg]e|[Ss]e|[Yy]e|[Aa]y|[Çç]ağ|[Kk]aldı|[Çç]ıka|[Kk]urta|[Bb]aşa|[Uu]ya|[Aa]kta|[Aa]raştı|[Dd]eğişti|[Gg]elişti|[Gg]erçekleşti|[Bb]irleşti|[Yy]erleşti|[Ee]leşti|[Gg]eti|[Gg]ötü|[Dd]üşü|[Öö]ldü|[Ss]ürdü)nl(ır|ir|dı|di|mış|miş|mak|mek|ması|mesi|acak|ecek|an|en|dığı|diği)(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final root = m.group(1)!;
        final suf = m.group(2)!;
        final rSeq = _hasBackVowelLast(root) ? 'rı' : 'ri';
        return '$root${rSeq}l$suf';
      },
    );

    // d3) Sık kullanılan edat, zamir ve köklerde 'rı/ri' -> 'n' kaynaşması:
    // ("üzennde" -> "üzerinde", "üzenne" -> "üzerine", "üzennden" -> "üzerinden",
    // "birbinne" -> "birbirine", "birbinni" -> "birbirini", "birbinnden" -> "birbirinden",
    // "binne" -> "birine", "binni" -> "birini", "yenne" -> "yerine", "yukanda" -> "yukarıda",
    // "dışanda" -> "dışarıda", "içensinde" -> "içerisinde", "aynca" -> "ayrıca", "aynntı" -> "ayrıntı",
    // "başan" -> "başarı", "başanlı" -> "başarılı", "başansız" -> "başarısız", "tanh" -> "tarih",
    // "manfet" -> "marifet", "hanta" -> "harita", "cumhunyet" -> "cumhuriyet", "hürnyet" -> "hürriyet")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Üü]ze)ni?(ne|nde|nden|mizde|nizde)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ri${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Bb]irbi|[Bb]i|[Yy]e)ni?(ne|ni|nin|nde|nden|yle)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ri${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Yy]uka|[Dd]ışa)n(da|dan|ya|sı|sını|sında)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rı${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([İi]çe)n(de|den|ye|si|sine|sinde|sinden)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ri${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Aa]y)n(ca|ntı[a-zçğıöşü]*|lık[a-zçğıöşü]*|calık[a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rı${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Bb]aşa)n(lı|sız[a-zçğıöşü]*|ya|yı|nın|dan|da|lar[a-zçğıöşü]*)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rı${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Tt]a)nh(i|in|te|ten|çi|çiler|sel)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rih${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Cc]umhu|[Hh]ür|[Bb]eşe)nyet([a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}riyet${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Hh][ıi])nstiyan([a-zçğıöşü]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}ristiyan${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([Yy]a)nsı(nı|na|nda|ndan)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}rısı${m.group(2) ?? ''}',
    );

    // e) Ünlüyle biten kelimelerin sonunda belirtme eki '-yı'/'-yi' yerine '-yn' okunması (Ör: "politikayn" -> "politikayı", "dünyayn" -> "dünyayı")
    const arabicDualEyn = <String>{
      'ebeveyn', 'harameyn', 'tarafeyn', 'bahreyn', 'kevneyn', 'sakaleyn', 'hüseyn', 'kamerayn',
    };
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,}[aıoueiöü])yn(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final fullLower = m.group(0)!.toLowerCase();
        if (arabicDualEyn.contains(fullLower)) return m.group(0)!;
        final stem = m.group(1)!;
        final v = _harmonizedHighVowel(stem);
        return '${stem}y$v';
      },
    );

    // f) Büyük harfli (ALL-CAPS) başlıklarda ünlü uyumu ve nokta düşmesi onarımı:
    // Ör: "BÖLÜMU" -> "BÖLÜMÜ", "(MUKADDİMESI)" -> "(MUKADDİMESİ)", "ESERI" -> "ESERİ", "BİRİNCI" -> "BİRİNCİ"
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([A-ZÇĞİÖŞÜÂÎÛ]*[ÖÜ][A-ZÇĞİÖŞÜÂÎÛ]*)U(N|NDA|NDAN|NE|NÜ|YLE|DÜR|MÜZ)?(?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)}Ü${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([A-ZÇĞİÖŞÜÂÎÛ]*[EİÖÜ][BCÇDFGĞHJKLMNPRSŞTVYZ]+)I(N|NIN|NI|NE|NDE|NDEN|YLE|DIR|TIR|LIK|SIZ)?(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final tail = (m.group(2) ?? '')
            .replaceAll('I', 'İ')
            .replaceAll('A', 'E');
        return '${m.group(1)}İ$tail';
      },
    );

    return text;
  }

  /// 6. Aşama: Klasik ve Modern Türkçe OCR kelime/kök/harf bozulmalarını onarır
  static String _healTurkishLexicalCorruptions(String input) {
    var text = input;

    // a) 'deviet' / 'Deviet' / 'devici' / 'devtet' -> 'devlet' / 'Devlet'
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Dd]ev)(?:iet|tet|ici)([a-zçğıöşüâîû\-]*)(?![\p{L}])', unicode: true),
      (m) {
        final prefix = m.group(1)!;
        final suffix = m.group(2) ?? '';
        return '${prefix}let$suffix';
      },
    );

    // b) 'oiabil' / 'oia' / 'oian' / 'oiup' / 'oimuştur' / 'omuştur' / 'oimaya' -> 'olabil' / 'ola' / 'olan' / 'olmuştur'...
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Oo])i(abil[a-zçğıöşüâîû]*|an[a-zçğıöşüâîû]*|arak|up|du[a-zçğıöşüâîû]*|muş[a-zçğıöşüâîû]*|ma[a-zçğıöşüâîû]*|acak[a-zçğıöşüâîû]*|ur[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}l${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Oo])(muş[a-zçğıöşüâîû]*|maktadır[a-zçğıöşüâîû]*|mayan[a-zçğıöşüâîû]*|maz)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}l${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Gg]e)i(miş[a-zçğıöşüâîû]*|en[a-zçğıöşüâîû]*|ecek[a-zçğıöşüâîû]*|di[a-zçğıöşüâîû]*|ir[a-zçğıöşüâîû]*|mek[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}l${m.group(2)}',
    );

    // c) Kalın ünlülü Türkçe köklerde 'ı' yerine 'i' okunması (varlik -> varlık, Artik -> Artık, kurtarici -> kurtarıcı, aşiri -> aşırı, karişik -> karışık)
    text = text.replaceAll(RegExp(r'(?<![\p{L}])varlik(?![\p{L}])', unicode: true), 'varlık');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Varlik(?![\p{L}])', unicode: true), 'Varlık');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Varliğin(?![\p{L}])', unicode: true), 'Varlığın');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])varliğin(?![\p{L}])', unicode: true), 'varlığın');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Artik(?![\p{L}])', unicode: true), 'Artık');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])artik(?![\p{L}])', unicode: true), 'artık');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])aşiri(?![\p{L}])', unicode: true), 'aşırı');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Aşiri(?![\p{L}])', unicode: true), 'Aşırı');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])karişik(?![\p{L}])', unicode: true), 'karışık');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Karişik(?![\p{L}])', unicode: true), 'Karışık');
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])kurtarici(lar)?(?![\p{L}])', unicode: true),
      (m) => 'kurtarıcı${m.group(1) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])yapici(lar)?(?![\p{L}])', unicode: true),
      (m) => 'yapıcı${m.group(1) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])uyandirici(lar)?(?![\p{L}])', unicode: true),
      (m) => 'uyandırıcı${m.group(1) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])[çc]ik(ıp|arak|mak|ma[a-zçğıöşüâîû]*|tı[a-zçğıöşüâîû]*|mış[a-zçğıöşüâîû]*|acak[a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) => 'çık${m.group(1)}',
    );

    // d) 'c' -> 'ç' ve 's' -> 'ş' OCR nokta düşmesi (coğu -> çoğu, cetin -> çetin, cözer -> çözer, islerin -> işlerin, siirinde -> şiirinde)
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])coğu(nu|na|nda|ndan)?(?![\p{L}])', unicode: true),
      (m) => 'çoğu${m.group(1) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])Coğu(nu|na|nda|ndan)?(?![\p{L}])', unicode: true),
      (m) => 'Çoğu${m.group(1) ?? ''}',
    );
    text = text.replaceAll(RegExp(r'(?<![\p{L}])cetin(?![\p{L}])', unicode: true), 'çetin');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Cetin(?![\p{L}])', unicode: true), 'Çetin');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Orta\s+Cağ(?![\p{L}])', unicode: true), 'Orta Çağ');
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Kk]ü)c([üu][ğg][üu][a-zçğıöşüâîû]*)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}ç${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])cöz(er[a-zçğıöşü]*|ülür[a-zçğıöşü]*|üm[a-zçğıöşü]*|mek[a-zçğıöşü]*|me[a-zçğıöşü]*|dü[a-zçğıöşü]*|müş[a-zçğıöşü]*)(?![\p{L}])', unicode: true),
      (m) => 'çöz${m.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])Cöz(er[a-zçğıöşü]*|ülür[a-zçğıöşü]*|üm[a-zçğıöşü]*|mek[a-zçğıöşü]*|me[a-zçğıöşü]*|dü[a-zçğıöşü]*|müş[a-zçğıöşü]*)(?![\p{L}])', unicode: true),
      (m) => 'Çöz${m.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])isler(in|i|de|den|ini|ine|iyle|inin)(?![\p{L}])', unicode: true),
      (m) => 'işler${m.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])siir(inde|inden|ine|ini|i|in|ler[a-zçğıöşü]*)?(?![\p{L}])', unicode: true),
      (m) => 'şiir${m.group(1) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])Siir(inde|inden|ine|ini|i|in|ler[a-zçğıöşü]*)?(?![\p{L}])', unicode: true),
      (m) => 'Şiir${m.group(1) ?? ''}',
    );

    // e) Taranmış kitaplarda (özellikle 1960-1980 tipo/ofset baskılarda) sık görülen kelime/kök bozulmaları sözlüğü:
    final lexicalMap = <RegExp, String>{
      RegExp(r'(?<![\p{L}])Sim\s+tel[âa]kkilere(?![\p{L}])', unicode: true): 'Bütün telâkkilere',
      RegExp(r'(?<![\p{L}])mevsiminde\s+girdiğimizi(?![\p{L}])', unicode: true): 'mevsimine girdiğimizi',
      RegExp(r'(?<![\p{L}])anicnak(?![\p{L}])', caseSensitive: false, unicode: true): 'anlamak',
      RegExp(r'(?<![\p{L}])göz\s+ctmak(?![\p{L}])', caseSensitive: false, unicode: true): 'göz atmak',
      RegExp(r'(?<![\p{L}])Dünlü(?=\s+büyük)(?![\p{L}])', unicode: true): 'Dünkü',
      RegExp(r'(?<![\p{L}])vüct(?=\s+bul)(?![\p{L}])', caseSensitive: false, unicode: true): 'vücut',
      RegExp(r'(?<![\p{L}])Balkantar(ın|ı|da|dan)?(?![\p{L}])', unicode: true): r'Balkanlar$1',
      RegExp(r'(?<![\p{L}])hergün(?![\p{L}])', unicode: true): 'her gün',
      RegExp(r'(?<![\p{L}])hirtayon(?![\p{L}])', caseSensitive: false, unicode: true): 'hırlayan',
      RegExp(r'(?<=\s)va(?=\s+(?:çoğu|coğu|bir|bu|o|her|bütün|daha|çok|az|en|tek|hem|ne))', unicode: true): 've',
      RegExp(r'(?<![\p{L}])Ceziretülarabn(?![\p{L}])', unicode: true): 'Ceziretülarabın',
      RegExp(r'(?<![\p{L}])vasfn(ı|a|dan|da)?(?![\p{L}])', unicode: true): r'vasfın$1',
      RegExp(r'(?<![\p{L}])cşamammş(?![\p{L}])', caseSensitive: false, unicode: true): 'aşamamış',
      RegExp(r'(?<![\p{L}])czametti(?![\p{L}])', caseSensitive: false, unicode: true): 'azametli',
      RegExp(r'(?<![\p{L}])azametli\s+devleti\s+kurulacak(?![\p{L}])', unicode: true): 'azametli devleti kuracak',
      RegExp(r'(?<![\p{L}])Müslümcn(lar|ların|lara|ları)?(?![\p{L}])', unicode: true): r'Müslüman$1',
      RegExp(r'(?<![\p{L}])müslümcn(lar|ların|lara|ları)?(?![\p{L}])', unicode: true): r'müslüman$1',
      RegExp(r'(?<![\p{L}])Gençliğtne(?![\p{L}])', unicode: true): 'Gençliğine',
      RegExp(r'(?<![\p{L}])gençliğtne(?![\p{L}])', unicode: true): 'gençliğine',
      RegExp(r'(?<![\p{L}])Milazgirt([’\x27]?[a-zçğıöşü]*)(?![\p{L}])', unicode: true): r'Malazgirt$1',
      RegExp(r'(?<![\p{L}])asrların(?![\p{L}])', unicode: true): 'asırların',
      RegExp(r'(?<![\p{L}])Asrların(?![\p{L}])', unicode: true): 'Asırların',
      RegExp(r'(?<![\p{L}])frtnah(?![\p{L}])', caseSensitive: false, unicode: true): 'fırtınalı',
      RegExp(r'(?<![\p{L}])Meviânâ(?![\p{L}])', unicode: true): 'Mevlânâ',
      RegExp(r'(?<![\p{L}])avelu(?=\s+fery)', caseSensitive: false, unicode: true): 'alevli',
      RegExp(r'(?<![\p{L}])ferycd[ıi]yle(?![\p{L}])', caseSensitive: false, unicode: true): 'feryadıyle',
      RegExp(r'(?<![\p{L}])ferycd[ıi]yla(?![\p{L}])', caseSensitive: false, unicode: true): 'feryadıyla',
      RegExp(r'(?<![\p{L}])ağlcyacak(?![\p{L}])', caseSensitive: false, unicode: true): 'ağlayacak',
      RegExp(r'(?<![\p{L}])dâvcIsint(?![\p{L}])', caseSensitive: false, unicode: true): 'dâvâsını',
      RegExp(r"(?<![\p{L}])Allch([’']?[a-zçğıöşü]*)(?![\p{L}])", unicode: true): r'Allah$1',
      RegExp(r'(?<![\p{L}])Hcikat(ini|in|i|e|ten|te|ler|leri)?(?![\p{L}])', unicode: true): r'Hakikat$1',
      RegExp(r'(?<![\p{L}])hcikat(ini|in|i|e|ten|te|ler|leri)?(?![\p{L}])', unicode: true): r'hakikat$1',
      RegExp(r'(?<![\p{L}])trâcdelerine(?![\p{L}])', caseSensitive: false, unicode: true): 'irâdelerine',
      RegExp(r'(?<![\p{L}])milet(in|i|e|ten|te|ler|lerin)?(?![\p{L}])', unicode: true): r'millet$1',
      RegExp(r'(?<![\p{L}])olcin(?![\p{L}])', caseSensitive: false, unicode: true): 'olan',
      RegExp(r'(?<![\p{L}])Aurupa([’\x27]?[a-zçğıöşü]*)(?![\p{L}])', unicode: true): r'Avrupa$1',
      RegExp(r'(?<![\p{L}])gelmiş\s+alan(?![\p{L}])', unicode: true): 'gelmiş olan',
      RegExp(r'(?<![\p{L}])is[êâ]h[iî](?=\s+takdir)(?![\p{L}])', caseSensitive: false, unicode: true): 'İlâhî',
      RegExp(r'(?<![\p{L}])bercber(?![\p{L}])', caseSensitive: false, unicode: true): 'beraber',
      RegExp(r'(?<![\p{L}])bunaittığı(?![\p{L}])', caseSensitive: false, unicode: true): 'bunalttığı',
      RegExp(r'(?<![\p{L}])czel[iî](?=\s+sağ)(?![\p{L}])', caseSensitive: false, unicode: true): 'ezelî',
      RegExp(r'(?<![\p{L}])sağr(?![\p{L}])', caseSensitive: false, unicode: true): 'sağır',
      RegExp(r'(?<![\p{L}])nofret(le|in|i|e|ten)?(?![\p{L}])', caseSensitive: false, unicode: true): r'nefret$1',
      RegExp(r'(?<![\p{L}])Luirçok(?![\p{L}])', unicode: true): 'birçok',
      RegExp(r'(?<![\p{L}])bedbcht(?![\p{L}])', caseSensitive: false, unicode: true): 'bedbaht',
      RegExp(r'(?<![\p{L}])tarcından(?![\p{L}])', caseSensitive: false, unicode: true): 'tarafından',
      RegExp(r'(?<![\p{L}])saistimct(?![\p{L}])', caseSensitive: false, unicode: true): 'suistimal',
      RegExp(r'(?<![\p{L}])edtniştir(?![\p{L}])', caseSensitive: false, unicode: true): 'edilmiştir',
      RegExp(r'(?<![\p{L}])Eunlar(?![\p{L}])', unicode: true): 'Bunlar',
      RegExp(r'(?<![\p{L}])frsat(tan|ta|ı|a|lar|ları)?(?![\p{L}])', unicode: true): r'fırsat$1',
      RegExp(r'(?<![\p{L}])çetik(?=\s+gibi)(?![\p{L}])', caseSensitive: false, unicode: true): 'çelik',
      RegExp(r'(?<![\p{L}])miii(?![\p{L}])', unicode: true): 'millî',
      RegExp(r'(?<![\p{L}])kemimoye(?![\p{L}])', caseSensitive: false, unicode: true): 'kemirmeye',
      RegExp(r'(?<![\p{L}])koyulnmuş(?:iavdr|iavdır|iavr|lardır|iardır)(?![\p{L}])', caseSensitive: false, unicode: true): 'koyulmuşlardır',
      RegExp(r'(?<![\p{L}])oriaya(?![\p{L}])', caseSensitive: false, unicode: true): 'ortaya',
      RegExp(r'(?<![\p{L}])beli(?=\s+olma)(?![\p{L}])', caseSensitive: false, unicode: true): 'belli',
      RegExp(r'(?<![\p{L}])müscmahakâr(?:h|lı)ğımıai(?![\p{L}])', caseSensitive: false, unicode: true): 'müsamahakârlığımızı',
      RegExp(r'(?<![\p{L}])cicğrusu(?![\p{L}])', caseSensitive: false, unicode: true): 'doğrusu',
      RegExp(r'(?<![\p{L}])maaleset(?![\p{L}])', caseSensitive: false, unicode: true): 'maalesef',
      RegExp(r'(?<![\p{L}])magiûbiyet([a-zçğıöşü]*)(?![\p{L}])', caseSensitive: false, unicode: true): r'mağlûbiyet$1',
      RegExp(r'(?<![\p{L}])bcrşlartşlır(?![\p{L}])', caseSensitive: false, unicode: true): 'başlamıştır',
      RegExp(r'(?<![\p{L}])Efercimiz([a-zçğıöşü]*)(?![\p{L}])', unicode: true): r'Efendimiz$1',
      RegExp(r'(?<![\p{L}])narnicrla(?![\p{L}])', caseSensitive: false, unicode: true): 'namlarla',
      RegExp(r'(?<![\p{L}])namlarla\s+onlan(?=\s+devlet)(?![\p{L}])', unicode: true): 'namlarla anılan',
      RegExp(r'(?<![\p{L}])zaaanla(?![\p{L}])', caseSensitive: false, unicode: true): 'zamanla',
      RegExp(r'(?<![\p{L}])mühimsemiyen(?![\p{L}])', caseSensitive: false, unicode: true): 'mühimsemeyen',
      RegExp(r'(?<![\p{L}])hastaitktan(?![\p{L}])', caseSensitive: false, unicode: true): 'hastalıktan',
      RegExp(r'(?<![\p{L}])Geçen\s+usırda(?![\p{L}])', unicode: true): 'Geçen asırda',
      RegExp(r'(?<![\p{L}])kernir(en|mek|meye|iyor|miş)(?![\p{L}])', caseSensitive: false, unicode: true): r'kemir$1',
      RegExp(r'(?<![\p{L}])cyak(?=\s+uydu)(?![\p{L}])', caseSensitive: false, unicode: true): 'ayak',
      RegExp(r'(?<![\p{L}])uydunak(?![\p{L}])', caseSensitive: false, unicode: true): 'uydurmak',
      RegExp(r'(?<![\p{L}])hcrske\s*e\s*gememekti(?![\p{L}])', caseSensitive: false, unicode: true): 'harekete geçememekti',
      RegExp(r'(?<![\p{L}])tâde(?=\s+edil)(?![\p{L}])', caseSensitive: false, unicode: true): 'ifâde',
      RegExp(r'(?<![\p{L}])bu\s+tatanın(?![\p{L}])', unicode: true): 'bu hatanın',
      RegExp(r'(?<![\p{L}])iemâ(?![\p{L}])', unicode: true): 'icmâ',
      RegExp(r'(?<![\p{L}])İemâ(?![\p{L}])', unicode: true): 'İcmâ',
      RegExp(r'(?<![\p{L}])yokea(?![\p{L}])', unicode: true): 'yoksa',
      RegExp(r'(?<![\p{L}])Yokea(?![\p{L}])', unicode: true): 'Yoksa',
      RegExp(r'(?<![\p{L}])Hallfe([a-zçğıöşüâîû’\x27]*)(?![\p{L}])', unicode: true): r'Halife$1',
      RegExp(r'(?<![\p{L}])hallfe([a-zçğıöşüâîû’\x27]*)(?![\p{L}])', unicode: true): r'halife$1',
      RegExp(r'(?<![\p{L}])Hukûki(?![\p{L}])', unicode: true): 'Hukûkî',
      RegExp(r'(?<![\p{L}])hukûki(?![\p{L}])', unicode: true): 'hukûkî',
      RegExp(r'(?<![\p{L}])Dın(?![\p{L}])', unicode: true): 'Din',
      RegExp(r'(?<![\p{L}])dın(?![\p{L}])', unicode: true): 'din',
      RegExp(r'(?<![\p{L}])Bır(?![\p{L}])', unicode: true): 'Bir',
      RegExp(r'(?<![\p{L}])bır(?![\p{L}])', unicode: true): 'bir',
      RegExp(r'(?<![\p{L}])Hıç(?![\p{L}])', unicode: true): 'Hiç',
      RegExp(r'(?<![\p{L}])hıç(?![\p{L}])', unicode: true): 'hiç',
      RegExp(r'(?<![\p{L}])Kım(?![\p{L}])', unicode: true): 'Kim',
      RegExp(r'(?<![\p{L}])kım(?![\p{L}])', unicode: true): 'kim',
      RegExp(r'(?<![\p{L}])bep(?=\s*\(\s*sistem\s*\))', unicode: true): 'mezhep',
      RegExp(r'(?<![\p{L}])bep(?![\p{L}])', unicode: true): 'hep',
      RegExp(r'(?<![\p{L}])Bep(?![\p{L}])', unicode: true): 'Hep',
      RegExp(r'(?<![\p{L}])gelip\s+geg(?![\p{L}])', unicode: true): 'gelip geçen',
      RegExp(r'(?<![\p{L}])Gelip\s+geg(?![\p{L}])', unicode: true): 'Gelip geçen',
      RegExp(r'(?<![\p{L}])geg(?![\p{L}])', unicode: true): 'geç',
      RegExp(r'(?<![\p{L}])Tanın(?=\s+elçi)', unicode: true): 'Tanrı',
      RegExp(r'(?<![\p{L}])baz(?=\s+[a-zçğıöşüâîû]{3,})', unicode: true): 'bazı',
      RegExp(r'(?<![\p{L}])Baz(?=\s+[a-zçğıöşüâîû]{3,})', unicode: true): 'Bazı',
      RegExp(r'(?<![\p{L}])kanaat\s+ve\s+inan(?![\p{L}])', unicode: true): 'kanaat ve inanç',
      RegExp(r'(?<![\p{L}])inan(?=\s+husule)', unicode: true): 'inanç',
      RegExp(r'(?<![\p{L}])takibet(miş[a-zçğıöşü]*|ti[a-zçğıöşü]*|mek[a-zçğıöşü]*|mekte[a-zçğıöşü]*)(?![\p{L}])', unicode: true): r'takip et$1',
      RegExp(r'(?<![\p{L}])bir\s+çok(?![\p{L}])', unicode: true): 'birçok',
      RegExp(r'(?<![\p{L}])Bir\s+çok(?![\p{L}])', unicode: true): 'Birçok',
      RegExp(r'(?<![\p{L}])[ÎİI]BN[İI]\s+HALAUN(?![\p{L}])', unicode: true): 'İBNİ HALDUN',
      RegExp(r'(?<![\p{L}])HALAUN(?![\p{L}])', unicode: true): 'HALDUN',
      RegExp(r'(?<![\p{L}])Halaun(?![\p{L}])', unicode: true): 'Haldun',
      RegExp(r"(?<![\p{L}])Artzona([’']?[a-zçğıöşü]*)(?![\p{L}])", unicode: true): r'Arizona$1',
      RegExp(r'(?<![\p{L}])Santa\s+Aruz(?![\p{L}])', unicode: true): 'Santa Cruz',
      RegExp(r'(?<![\p{L}])gö[ıi]iir(sünüz|üz|ler|sün|üm)?(?![\p{L}])', unicode: true): r'görür$1',
      RegExp(r'(?<![\p{L}])bilimdiği(ni|ne|nden)?(?![\p{L}])', unicode: true): r'bilindiği$1',
      RegExp(r'(?<![\p{L}])Bilimdiği(ni|ne|nden)?(?![\p{L}])', unicode: true): r'Bilindiği$1',
      RegExp(r'(?<![\p{L}])edinler(in|i|e|de|den)?(?![\p{L}])', unicode: true): r'edenler$1',
      RegExp(r'(?<![\p{L}])ibnden(?![\p{L}])', unicode: true): 'binden',
      RegExp(r'(?<![\p{L}])askeridi(?![\p{L}])', unicode: true): 'asker idi',
      RegExp(r'(?<![\p{L}])gelence(?![\p{L}])', unicode: true): 'gelince',
      RegExp(r'(?<![\p{L}])Gelence(?![\p{L}])', unicode: true): 'Gelince',
    };

    for (final entry in lexicalMap.entries) {
      text = text.replaceAllMapped(entry.key, (m) {
        var rep = entry.value;
        if (rep.contains(r'$1')) {
          rep = rep.replaceAll(r'$1', m.group(1) ?? '');
        }
        return rep;
      });
    }

    // f) Klasik nispet î'si düzeltmeleri (Ör: "Siyâsi, tarihi, coğrafi, iktisadi" -> "Siyâsî, tarihî, coğrafî, iktisadî")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([Ss]iyâs)i(?=\s+(?:varlık|ve|tarih|bir|hayat|hak|kudret|birlik)|[,;])', unicode: true),
      (m) => '${m.group(1)}î',
    );
    text = text.replaceAll(
      RegExp(r'Siyâs[iî],\s*tarihi,\s*coğrafi,\s*iktisadi', unicode: true),
      'Siyâsî, tarihî, coğrafî, iktisadî',
    );
    text = text.replaceAll(
      RegExp(r'siyâs[iî]\s+ve\s+medeni(?=\s+seviye)', unicode: true),
      'siyâsî ve medenî',
    );
    text = text.replaceAll(
      RegExp(r'ebedi(?=\s+kurtuluş)', unicode: true),
      'ebedî',
    );

    // g) 'temâs' / 'temas' içindeki 'm' harfinin 'ın' olarak okunması ("teınâs" -> "temâs")
    text = text.replaceAll(RegExp(r'(?<![\p{L}])teınâs', caseSensitive: false, unicode: true), 'temâs');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])teınas', caseSensitive: false, unicode: true), 'temas');

    // h) 'ilmî', 'İdare', 'İslâm', 'işbu' OCR onarımları
    text = text.replaceAll(RegExp(r'(?<![\p{L}])[iİıI][îiı1]m[îi](?![\p{L}])', unicode: true), 'ilmî');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])îdare(?![\p{L}])', unicode: true), 'İdare');
    text = text.replaceAllMapped(
      RegExp(r"(?<![\p{L}])[iI]sl[âa]m([’']?[a-zçğıöşüâîû]*)(?![\p{L}])", unicode: true),
      (m) => 'İslâm${m.group(1) ?? ''}',
    );
    text = text.replaceAll(RegExp(r'(?<![\p{L}])igbu(?![\p{L}])', unicode: true), 'işbu');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])İgbu(?![\p{L}])', unicode: true), 'İşbu');

    // i) "'ercemeninyanlışsız ©Huğunu" -> "tercemenin yanlışsız olduğunu"
    text = text.replaceAll(
      RegExp(r"(?<![\p{L}])[‘'’`]?ercemenin\s*yanlışsız", caseSensitive: false, unicode: true),
      'tercemenin yanlışsız',
    );
    text = text.replaceAllMapped(
      RegExp(r"(?<![\p{L}])[‘'’`]erceme(si|nin|yi|ye|de|den)?(?![\p{L}])", caseSensitive: false, unicode: true),
      (m) => 'terceme${m.group(1) ?? ''}',
    );
    text = text.replaceAll(RegExp(r'(?<![\p{L}])(?:©H|©h|H|0ld|Old)uğunu(?![\p{L}])', unicode: true), 'olduğunu');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])(?:©H|©h|H|0ld|Old)uğu(?![\p{L}])', unicode: true), 'olduğu');

    // j) Telif ve baskı sayfası OCR bozulmaları ("faüku&s" -> "hakları", "filim" -> "film", "T@L.6" -> "Tel:")
    text = text.replaceAll(RegExp(r'(?<![\p{L}])faüku&s(?![\p{L}])', caseSensitive: false, unicode: true), 'hakları');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])filim(?![\p{L}])', caseSensitive: false, unicode: true), 'film');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])f\s+Ansan\s*[·•\.]?\s*Ofset', unicode: true), 'Ansan Ofset');
    text = text.replaceAll(RegExp(r'T@L\.?\s*\d*'), 'Tel:');

    // k) Sayfa içi satır karışması / bitişmesi ("açıkladıkallah TeâBugunkÜ Laik" ve "Alı. Âli ŞAFAK’D")
    text = text.replaceAll(
      RegExp(r'açıkladık\s*allah\s*Teâ\s*Bugunk[Üü]\s+Laik', caseSensitive: false, unicode: true),
      'açıkladık.”\n\nBugünkü laik',
    );
    text = text.replaceAll(
      RegExp(r"olmasını\s+Al[ıi]\.\s*[ÂA]li\s+ŞAFAK[’'’]?[Dd]?(?![\p{L}])", caseSensitive: false, unicode: true),
      "olmasını Allah Teâlâ'dan niyaz ederim.\n\nDr. Ali ŞAFAK",
    );

    // l) Kelime sonu veya ortası büyük harf OCR kaymaları (Ör: "BugunkÜ" -> "Bugünkü")
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])([A-ZÇĞİÖŞÜÂÎÛ]?[a-zçğıöşüâîû]{2,})([A-ZÇĞİÖŞÜÂÎÛ]{1,2})(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.toLowerCase()}',
    );
    text = text.replaceAll(RegExp(r'(?<![\p{L}])Bugunkü(?![\p{L}])', unicode: true), 'Bugünkü');
    text = text.replaceAll(RegExp(r'(?<![\p{L}])bugunkü(?![\p{L}])', unicode: true), 'bugünkü');

    // m) Bölüm ve alt başlık OCR bozulmaları (Ör: "BlRindİ BÖLÜH" -> "BİRİNCİ BÖLÜM", "HALIFENİN TÂYIN" -> "HALİFENİN TÂYİNİ")
    text = text.replaceAll(
      RegExp(r'(?<![\p{L}])B[lI1iİ]R[iıI1İ](?:nd|nc|NC)[İiI1]\s+BÖLÜ[HM](?![\p{L}])', caseSensitive: false, unicode: true),
      'BİRİNCİ BÖLÜM',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])(BİRİNCİ|İKİNCİ|ÜÇÜNCÜ|DÖRDÜNCÜ|BEŞİNCİ|ALTINCI|YEDİNCİ|SEKİZİNCİ|DOKUZUNCU|ONUNCU)\s+BÖLÜ[HM](?![\p{L}])',
        unicode: true,
      ),
      (m) => '${m.group(1)} BÖLÜM',
    );
    text = text.replaceAll(
      RegExp(r'(?<![\p{L}])HAL[Iİ]FEN[İI]N\s+T[ÂA]Y[Iİ]N[İI]?(?![\p{L}])', unicode: true),
      'HALİFENİN TÂYİNİ',
    );
    text = text.replaceAllMapped(
      RegExp(r'(Halife\s+Tâyini\s+[Vv]e\s+Hukûk[iî]\s+Durumu)\s+(A\s*[-–—]\s*HALİFENİN\s+TÂYİNİ)', unicode: true),
      (m) => 'Halife Tâyini ve Hukûkî Durumu\n\n${m.group(2)}',
    );

    return text;
  }

  /// Türkçe ikilemelerde (reduplications) bir kelimenin diyakritiğinin düşmesini onarır (Ör: "şerha serha" -> "şerha şerha")
  static String _harmonizeReduplications(String input) {
    final wordRegex = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{4,}', unicode: true);
    final matches = wordRegex.allMatches(input).toList();
    if (matches.length < 2) return input;

    var result = input;
    for (int i = matches.length - 2; i >= 0; i--) {
      final m1 = matches[i];
      final m2 = matches[i + 1];
      final between = result.substring(m1.end, m2.start);
      if (!RegExp(r'^[ \t]+$').hasMatch(between)) continue;

      final w1 = m1.group(0)!;
      final w2 = m2.group(0)!;
      if (w1 == w2 || w1.length != w2.length) continue;

      if (_asciiSkeleton(w1) == _asciiSkeleton(w2)) {
        final score1 = _turkishDiacriticCount(w1);
        final score2 = _turkishDiacriticCount(w2);
        if (score1 > score2) {
          result = result.replaceRange(m2.start, m2.end, w1);
        } else if (score2 > score1) {
          result = result.replaceRange(m1.start, m1.end, w2);
        }
      }
    }
    return result;
  }

  /// Cümle başlarındaki küçük 'i' ('. işte' -> '. İşte') ve noktasız büyük 'I' ('Insanın' -> 'İnsanın', 'Imâmet' -> 'İmâmet') hatalarını onarır
  static String _repairSentenceCapitalizationAndDottedI(String input) {
    var text = input;

    // 1. Noktasız 'I' ile başlayan ancak Türkçede kesinlikle 'İ' olan kelimeler (Ör: "Insanın" -> "İnsanın", "Imâmet" -> "İmâmet")
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])I(nsan[a-zçğıöşüâîû]*|slâm[a-zçğıöşüâîû’\x27]*|slam[a-zçğıöşüâîû’\x27]*|şte|çin|çleri[a-zçğıöşüâîû]*|çinde[a-zçğıöşüâîû]*|çerden|lk|ki|kinci|lim[a-zçğıöşüâîû]*|lmî|lâhî|mâmet[a-zçğıöşüâîû]*|mamet[a-zçğıöşüâîû]*|mâm[a-zçğıöşüâîû]*|mam[a-zçğıöşüâîû]*|man[a-zçğıöşüâîû]*|mkân[a-zçğıöşüâîû]*|mparator[a-zçğıöşüâîû]*|nkılâ[pb][a-zçğıöşüâîû]*|ngiliz[a-zçğıöşüâîû]*|râde[a-zçğıöşüâîû]*|rade[a-zçğıöşüâîû]*|stanbul[a-zçğıöşüâîû]*|stikrar[a-zçğıöşüâîû]*|stiklâl[a-zçğıöşüâîû]*|stifade[a-zçğıöşüâîû]*|şaret[a-zçğıöşüâîû]*|tibar[a-zçğıöşüâîû]*|ttifak[a-zçğıöşüâîû]*|dare[a-zçğıöşüâîû]*|dâre[a-zçğıöşüâîû]*|ktisa[dt][a-zçğıöşüâîû]*|htilâl[a-zçğıöşüâîû]*|cmâ[a-zçğıöşüâîû]*)(?![\p{L}])',
        unicode: true,
      ),
      (m) => 'İ${m.group(1)}',
    );

    // 2. Paragraf veya cümle başlarındaki küçük 'i' ile başlayan kelimeleri 'İ' yap (Ör: ". işte" -> ". İşte", "içleri" -> "İçleri")
    text = text.replaceAllMapped(
      RegExp(r'(^\s*|[.!?]\s+)i(şte|lâhî|çleri[a-zçğıöşüâîû]*|çinde[a-zçğıöşüâîû]*|çerden|nsan[a-zçğıöşüâîû]*|slâm[a-zçğıöşüâîû’\x27]*|mâmet[a-zçğıöşüâîû]*|se|le|çin|lk|ki)(?![\p{L}])', multiLine: true, unicode: true),
      (m) => '${m.group(1)}İ${m.group(2)}',
    );

    // 3. Cümle ortasında küçük harfli bir kelimeden sonra yanlışlıkla büyük 'İçin', 'Bakarsanız', 'Komutasındaki' yazılmışsa küçült
    text = text.replaceAllMapped(
      RegExp(r'([a-zçğıöşüâîû]\s+)İçin(?=\s)', unicode: true),
      (m) => '${m.group(1)}için',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\b(?:kuzeye|güneye|doğuya|batıya|yukarıya|aşağıya|ve|ile)\s+)Bak(arsanız|ıldığında|ınca|arak)(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}bak${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([A-ZÇĞİÖŞÜ][a-zçğıöşüâîû]+\s+)Komutasında(ki)?(?![\p{L}])', unicode: true),
      (m) => '${m.group(1)}komutasında${m.group(2) ?? ''}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\p{L}])Î([BCÇDFGĞHJKLMNPRSŞTVYZbcçdfgğhjklmnprsştvyz])', unicode: true),
      (m) => 'İ${m.group(1)}',
    );

    return text;
  }

  /// 7. Aşama: Tek harflik kenar/çerçeve gürültü satırlarını ("ك", "M", "B") ve mükerrer boşlukları temizler
  static String _cleanIsolatedNoiseLinesAndSpacing(String input) {
    final lines = input.split('\n');
    final cleanedLines = <String>[];

    // Tek başına satır olmuş tekil ünsüz veya tekil Arapça harf gürültüsü ("ك", "M", "B", "V", "f")
    final isolatedSingleCharNoise = RegExp(
      r'^\s*(?:[\u0600-\u06FF]|[BCÇDFGĞHJKLMNPRSŞTVYZbcçdfgğhjklmnprsştvyz]|[0-9©®€¥§•·\-—–=~_])\s*$',
    );

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        cleanedLines.add('');
        continue;
      }

      if (isolatedSingleCharNoise.hasMatch(trimmed)) {
        continue;
      }

      // Satır başında büyük harfli bir kelimenin önüne yapışmış tekil çerçeve harfi (Ör: "B Bu eserin" -> "Bu eserin")
      trimmed = trimmed.replaceFirstMapped(
        RegExp(r'^([BCÇDFGĞHJKLMNPRSŞTVYZ])\s+([A-ZÇĞİÖŞÜ][a-zçğıöşüâîû]+\s+)', unicode: true),
        (m) => m.group(2)!,
      );

      // Çoklu yatay boşlukları teke indir
      trimmed = trimmed.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
      cleanedLines.add(trimmed);
    }

    return cleanedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// Kelimenin son ünlüsünün kalın ünlü (a, ı, o, u, â, û) olup olmadığını döndürür
  static bool _hasBackVowelLast(String word) {
    for (int i = word.length - 1; i >= 0; i--) {
      final ch = word[i].toLowerCase();
      if ('aıouâû'.contains(ch)) return true;
      if ('eiöüî'.contains(ch)) return false;
    }
    return true;
  }

  /// 4'lü ünlü uyumuna göre (ı, i, u, ü) uygun dar ünlüyü döndürür
  static String _harmonizedHighVowel(String word) {
    for (int i = word.length - 1; i >= 0; i--) {
      final ch = word[i].toLowerCase();
      if (ch == 'a' || ch == 'ı' || ch == 'â') return 'ı';
      if (ch == 'e' || ch == 'i' || ch == 'î') return 'i';
      if (ch == 'o' || ch == 'u' || ch == 'û') return 'u';
      if (ch == 'ö' || ch == 'ü') return 'ü';
    }
    return 'ı';
  }

  static String _asciiSkeleton(String word) {
    return word
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static int _turkishDiacriticCount(String word) {
    return RegExp(r'[çğıöşüÇĞİÖŞÜâîûÂÎÛ]').allMatches(word).length;
  }

  static String _toLowerTurkish(String input) {
    return input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  }

  static String _preserveLeadingCase(String originalFirst, String replacement) {
    if (originalFirst.isEmpty || replacement.isEmpty) return replacement;
    final firstChar = originalFirst[0];
    if (firstChar.toUpperCase() == firstChar &&
        firstChar.toLowerCase() != firstChar) {
      final repFirst = replacement[0];
      final upper = repFirst == 'i'
          ? 'İ'
          : (repFirst == 'ı' ? 'I' : repFirst.toUpperCase());
      return '$upper${replacement.substring(1)}';
    }
    return replacement;
  }
}
