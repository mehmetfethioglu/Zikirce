import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';
import 'package:tahrir/features/reader/services/ocr_service.dart';

void main() {
  group('Tahrir Text Quality & Footnote Extraction Tests', () {
    test('1. Garbage noise detection flags non-Unicode font encoding artifacts', () {
      const garbageSample =
          """J o ,.. ''' ,,. J 1;ii '! <:1 -. 1 1;.._ 0 J l,j ! <:1 r 1.f"' Y, r- ts-1; J> ,L>- . ! _il' :; - ..:..__i1 1...r----J . ,.""";

      expect(TextSegmenter.isGarbageNoise(garbageSample), isTrue);

      const normalSample =
          'Kesinlikle siz kardeşlerinizin yanına gelmeyi murad ettiğinizde develerinizi ve elbisenizi güzelleştirin.';
      expect(TextSegmenter.isGarbageNoise(normalSample), isFalse);
    });

    test('2. Arabic Unicode text detection', () {
      const arabicVerse =
          'إِنَّكُمْ قَادِمُونَ عَلَىٰ إِخْوَانِكُمْ، فَأَحْسِنُوا لِبَاسَكُمْ، وَأَصْلِحُوا رِحَالَكُمْ، حَتَّىٰ تَكُونُوا كَأَنَّكُمْ شَامَةٌ فِي النَّاسِ';
      expect(TextSegmenter.isArabicText(arabicVerse), isTrue);

      const turkishText = "Doğru yola ulaştıran ancak Allah-ü Teala'dır.";
      expect(TextSegmenter.isArabicText(turkishText), isFalse);
    });

    test('3. OCR, ligatures, split suffixes and punctuation fixes', () {
      const sample =
          "yanma gelmeyi murad ettiğinizde, (binek/eriniz olan) develerin izi ve elbisenizi güzelleş tirin ve düzeltin! Şüphesiz ki Allah çirkin olan söz ve fiili sevrnez. Doğru yola ulaştıran ancak Allah-ü Teala' dır.";

      final cleaned = TextSegmenter.cleanOcrAndLigatures(sample);

      expect(cleaned, contains('yanına gelmeyi'));
      expect(cleaned, contains('binekleriniz olan'));
      expect(cleaned, contains('develerinizi ve'));
      expect(cleaned, contains('güzelleştirin ve'));
      expect(cleaned, contains('fiili sevmez.'));
      expect(cleaned, contains("Allah-ü Teala'dır."));
    });

    test('4. Dotted leaders and running headers/footers removal', () {
      const sampleWithFooter = '''
Dolayısıyla bir müslümanın giyim ve kuşamdaki güzelliğine dikkat etmesi gerekir.
Edeb ............................................................................................ 19
''';

      final filtered = TextSegmenter.filterHeadersAndFooters(sampleWithFooter);
      expect(filtered, isNot(contains('Edeb .....')));
      expect(filtered, isNot(contains('..................')));
      expect(filtered.trim(), equals('Dolayısıyla bir müslümanın giyim ve kuşamdaki güzelliğine dikkat etmesi gerekir.'));
    });

    test('5. Full End-to-End Page Extraction (Sayfa 19 case)', () {
      const fullPageText = """
J o ,.. ''' ,,. J 1;ii '! <:1 -. 1 1;.._ 0 J l,j ! <:1 r 1.f"' Y, r- ts-1; J> ,L>- . ! _il' :; - ..:..__i1 1...r----J . ,.

"Kesinlikle siz kardeşlerinizin yanma gelmeyi murad ettiğinizde, (binek/eriniz olan) develerin izi ve elbisenizi güzelleş tirin ve düzeltin! Hatta (o kadar düzgün olsun ki), {insanın vücudundaki) ben nasıl fark ediliyorsa, siz de (güzelliğiniz ve temizliğinizle) öyle fark edilin! Şüphesiz ki Allah (celle celalüh) çirkin olan söz ve fiili sevrnez."4

Dolayısıyla bir müslümanın giyim ve kuşamdaki güzelliğine, görünüşüne, düzen ve tertibine ziyade dikkat etmesi gerekir.

Doğru yola ulaştıran ancak Allah-ü Teala' dır.

__________
4 Bu Hadis-i Şerifi Ebu Davud, Ahmed b. Hanbl ve Hakim "Müstedrek" isimli eserinde, Sehl b. Hanzala (radıyallahu 'anh)'dan rivayet etmişlerdir.

Edeb ............................................................................................ 19
""";

      final extracted = TextSegmenter.extractFootnotesAndBody(fullPageText);

      // Footnote separation
      expect(extracted.footnotes, isNotEmpty);
      expect(extracted.footnotes.first.key, equals('4'));
      expect(extracted.footnotes.first.content, contains('Bu Hadis-i Şerifi Ebû Dâvûd, Ahmed b. Hanbel'));

      // Garbage filter
      expect(extracted.hadCorruptedCalligraphy, isTrue);
      expect(extracted.bodyText, isNot(contains('J o ,..')));

      // OCR fixes in body
      expect(extracted.bodyText, contains('yanına gelmeyi'));
      expect(extracted.bodyText, contains('binekleriniz'));
      expect(extracted.bodyText, contains('develerinizi'));
      expect(extracted.bodyText, contains('güzelleştirin'));
      expect(extracted.bodyText, contains('sevmez'));
      expect(extracted.bodyText, contains('Allah-ü Teala\'dır'));

      // Clean footer
      expect(extracted.bodyText, isNot(contains('Edeb .....')));

      // Paragraph segmentation
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
      );

      expect(paragraphs.first.isArabic || paragraphs.first.isCalligraphyFallback, isTrue);
      final pWithFootnote = paragraphs.firstWhere((p) => p.footnoteAnchors.isNotEmpty);
      expect(pWithFootnote.footnoteAnchors.first.key, equals('4'));
      expect(pWithFootnote.footnoteAnchors.first.content, contains('Bu Hadis-i Şerifi'));
    });

    test('6. Sayfa 15 (Mukaddime) with circumflex letters and brackets is preserved and not dropped', () {
      const page15Text = '''
Mukaddime

Ta'zim (saygı) ve senanın (övgünün) merkezi âlemlerin Rabb-i Allah'ü Teâlâ'ya hamdü senalar olsun.

Yüce yaratıcısının kendisine salât ettiği efendimiz Muhammed (sallallâhu 'aleyhi ve sellem)'e, âline, ashâbına ve onlara tâbi olan pak ve temiz kimseler üzerine de salât ve selâm olsun. Allah'tan hakkıyla sakınan kimseler, efendimiz (sallallâhu 'aleyhi ve sellem)'in göstermiş olduğu hidâyet yoluna ve edeplerine tâbi olan (uyan) seçilmiş kimselerdir.

Allah'ım! Sözümüzde ve yaptığımız işlerde onlara ittibayı bizlere rızık olarak ver! Bizim canımızı onların yolu ve sevgisi üzerinde al!

Bu risaleyi "Âdâb-ı Muâşeret ve Ahlâk-ı Hamîde" diye isimlendirdim ve bu risalede kardeşlerimin, dostlarımın, hanımıyla ve erkeğiyle tüm müslümanların düşmeye ve gaflete düştüğünü gördüğüm, aynı zamanda faydalanabileceği, İslam'ın edeplerinden derlenmiş bir muhteva getirdim.

Mukaddime ................................................................ 13
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(page15Text);
      expect(extracted.bodyText, isNotEmpty);
      expect(extracted.bodyText, contains('Mukaddime'));
      expect(extracted.bodyText, contains('Ta\'zim (saygı)'));
      expect(extracted.bodyText, contains('Muhammed'));
      expect(extracted.bodyText, contains('seçilmiş kimselerdir'));
      expect(extracted.bodyText, isNot(contains('..................')));

      final paragraphs = TextSegmenter.segmentIntoParagraphs(extracted.bodyText);
      expect(paragraphs.length, greaterThanOrEqualTo(4));
    });

    test('7. Sayfa 25 (Kapıyı Yavaşça Açıp Kapatmanın Önemi) with corrupted script title, embedded Arabic glyph noise & footnote extraction', () {
      const page25RawText = '''
JCapıyı J?avça fiçıp JCapatmanın Önemi

Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Aişe (radıyallahu'anha) validemizin Rasılullah (sallallahu 'aleyhi ve sellem)'den rivayet ettiği şu Hadis-i Şerifi duymuşsundur:,,, o,,,,,,,,, Gi,,, J J,,,,,, o " 8 j,tlj 1..i 0fa. )l (J L.!. \\rı "Muhakkak ki yumuşakllk (kibarllk) bulunduğu şeyi güzelleştirir. Bir şeyden yumuşakllğı almdığı zaman da bu a/mma o şeyi çirkinleştirir."1 l Sahih-i Müslim, Kitabu'l-Birr, Sıla ve Adab,c.4, s.2004, Hadis No:2594 Aile İçindeki Edebler
''';

      // Verify OCR detector catches this page
      expect(OcrService.requiresOcrEnhancement(page25RawText), isTrue);

      final extracted = TextSegmenter.extractFootnotesAndBody(page25RawText);

      // Title must be healed from "JCapıyı J?avça fiçıp JCapatmanın" -> "Kapıyı Yavaşça Açıp Kapatmanın"
      expect(extracted.bodyText, contains('Kapıyı Yavaşça Açıp Kapatmanın Önemi'));
      expect(extracted.bodyText, isNot(contains('JCapıyı')));
      expect(extracted.bodyText, isNot(contains('fiçıp')));
      expect(extracted.bodyText, isNot(contains('JCapatmanın')));

      // Embedded Arabic glyph noise must be removed from Turkish body
      expect(extracted.bodyText, isNot(contains('j,tlj')));
      expect(extracted.bodyText, isNot(contains('0fa')));
      expect(extracted.bodyText, isNot(contains('Gi,,,')));

      // Turkish typos healed
      expect(extracted.bodyText, contains('yumuşaklık (kibarlık)'));
      expect(extracted.bodyText, contains('yumuşaklığı alındığı zaman'));
      expect(extracted.bodyText, contains('alınma o şeyi'));

      // Footnote properly extracted
      expect(extracted.footnotes, isNotEmpty);
      expect(extracted.footnotes.first.key, equals('1'));
      expect(extracted.footnotes.first.content, contains('Sahih-i Müslim'));
      expect(extracted.footnotes.first.content, isNot(contains('Aile İçindeki Edebler')));

      // Segment into structured paragraphs
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
      );

      // Heading segment check
      final headingSegment = paragraphs.firstWhere((p) => p.isHeading);
      expect(headingSegment.rawText, equals('Kapıyı Yavaşça Açıp Kapatmanın Önemi'));

      // Calligraphy fallback or body check
      expect(paragraphs.any((p) => p.isCalligraphyFallback || p.isArabic), isTrue);
    });

    test('8. Sayfa 26 (Eve Girip Çıkarken Selam Vermenin Önemi) heals Rasfilullah, Esseldmü, Arabic hadith & footnote', () {
      const page26RawText = '''
eve Girip ÇıkarkEn Selam Vennenin Önemi
Eve girerken veya evden çıkarken ehlinden olan kadınerkek herkese İslamın şian ve Müslümanlann selamı olan "Esseldmü aleyküm ve rahmetullahi ve berakatüh" diyerek selam ver. İslamın alameti olan bu selamı "iyi sabahlar", "günaydın", "tünaydın" ve "merhaba" gibi lafızlarla değiştirme! Zira senin bu selamı, başka lafızlar ile değiştirmen İslam alameti olan bu selamın yok olmasına sebeptir. İslamın şian ve Müslümanların alameti olan bu selamı Rasfilullah (sallallahu 'aleyhi ve sellem) hem kavliyle (sözüyle) hem de fiiliyle (yaşantısıyla) bizzat tatbik etmiş ve onu güzel hizmetçisi Enes (radıyallahu 'anh)'ya öğretmiştir. Nitekim Enes (radıyallahu 'anh) şöyle buyuruyor: "Rasfilullah (sallallahu 'aleyhi ve sellem) bana:,,,,,,,,,,,.. tP,... J, "',,,,,,,,,,, O 1 J'41S-; .A'F11hş4 "Ey oğulcağızım! Evine girdiğin zaman ailene selam ver! Bu hem sana hem de ailene bereket getirir."2 z Sünen-i Tinnizl, Kitabu'l-İsti'zan, c.5, s.59, Hadis No:2698
''';

      expect(OcrService.requiresOcrEnhancement(page26RawText), isTrue);

      final extracted = TextSegmenter.extractFootnotesAndBody(page26RawText);

      // Title must be healed
      expect(extracted.bodyText, contains('Eve Girip Çıkarken Selam Vermenin Önemi'));
      expect(extracted.bodyText, isNot(contains('eve Girip')));
      expect(extracted.bodyText, isNot(contains('ÇıkarkEn')));
      expect(extracted.bodyText, isNot(contains('Vennenin')));

      // Turkish typos & ligatures healed
      expect(extracted.bodyText, contains('kadın-erkek'));
      expect(extracted.bodyText, contains('şiarı'));
      expect(extracted.bodyText, contains('Müslümanların'));
      expect(extracted.bodyText, contains('Esselâmü'));
      expect(extracted.bodyText, contains('Rasûlullah'));
      expect(extracted.bodyText, isNot(contains('Rasfilullah')));

      // Garbled Arabic noise excised
      expect(extracted.bodyText, isNot(contains('tP')));
      expect(extracted.bodyText, isNot(contains('J\'41S-')));
      expect(extracted.bodyText, isNot(contains('A\'F11hş4')));

      // Footnote extracted
      expect(extracted.footnotes, isNotEmpty);
      expect(extracted.footnotes.first.key, equals('2'));
      expect(extracted.footnotes.first.content, contains('Sünen-i Tirmizî'));
      expect(extracted.footnotes.first.content, contains('Hadis No:2698'));

      // Paragraph segmentation & Arabic Hadith resolution
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
      );

      final headingSegment = paragraphs.firstWhere((p) => p.isHeading);
      expect(headingSegment.rawText, equals('Eve Girip Çıkarken Selam Vermenin Önemi'));

      final arabicSegment = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSegment.rawText, contains('يَا بُنَيَّ'));
      expect(arabicSegment.rawText, contains('فَسَلِّمْ'));
      expect(arabicSegment.rawText, contains('بَرَكَةً'));

      final translationSegment = paragraphs.firstWhere((p) => p.rawText.contains('Ey oğulcağızım'));
      expect(translationSegment.footnoteAnchors, isNotEmpty);
      expect(translationSegment.footnoteAnchors.first.key, equals('2'));
    });

    test('9. Arabic text isolation extracts embedded Arabic into standalone Arabic segments', () {
      const mixedText = '''
Resûlullah (sallallâhu 'aleyhi ve sellem) şöyle buyurmuştur:
أَفْشُوا السَّلَامَ بَيْنَكُمْ
"Aranızda selâmı yayınız."
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(mixedText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(extracted.bodyText);

      expect(paragraphs.length, equals(3));
      expect(paragraphs[0].isArabic, isFalse);
      expect(paragraphs[1].isArabic, isTrue);
      expect(paragraphs[1].rawText, contains('أَفْشُوا السَّلَامَ'));
      expect(paragraphs[2].isArabic, isFalse);
    });

    test('10. Multi-hadith resolution across other chapters (isti\'zan, selamlaşma, sağ el) produces Arabic cards', () {
      const istizanText = '''
İzin İstemenin Üç Defa Olması

Kişi bir kapıyı en fazla üç defa çalmalıdır. Nitekim Efendimiz (sallallâhu 'aleyhi ve sellem) şöyle buyurmuştur:
"İzin istemek üç defadır. Eğer izin verilirse gir, yoksa geri dön!"1
__________
1 Sahih-i Buhari, İsti'zan, 6245
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(istizanText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: true, // simulated unencoded Arabic hat
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('الِاسْتِئْذَانُ ثَلَاثٌ'));
    });

    test('11. Sayfa 27 (Meclise Giriş ve Çıkışta Selam) heals Ç1kacağmız, Zfra, resolves Arabic hadith and footnote', () {
      const page27Raw = '''
şöyle buyurmuştur: "Eve girdiğin zaman ailene selam ver! Çünkü onlar, senin selamına en layık kimselerdir."
Ebu Hüreyre (radıyallahu'anh) şöyle nakletmiştir: "Rasûlullah (sallallahu 'aleyhi ve sellem) şöyle buyurdu:
,,,,,,,,,,,.. tP,... J, "',,,,,,,,,,, O 1 J'41S-; .A'F11hş4
"Bir meclise girdiğiniz vakit selam verin! Oradan Ç1kacağmız vakit yine selam verin! Zfra girerken verilen selam, çıkarken verilen selamdan üstün değildir. (çıkarken verilen selam daha üstündür )."3
3 Sünen-i Tirmizi, Kitabu'l-İsti'zan, c.5, s.62-63, Hadis No:2706
''';

      expect(OcrService.requiresOcrEnhancement(page27Raw), isTrue);

      final extracted = TextSegmenter.extractFootnotesAndBody(page27Raw);
      expect(extracted.bodyText, contains('çıkacağınız'));
      expect(extracted.bodyText, contains('Zira'));
      expect(extracted.bodyText, isNot(contains('Ç1kacağmız')));
      expect(extracted.bodyText, isNot(contains('Zfra')));

      expect(extracted.footnotes, isNotEmpty);
      expect(extracted.footnotes.first.key, equals('3'));
      expect(extracted.footnotes.first.content, contains('Sünen-i Tirmizî'));

      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('إِذَا انْتَهَى أَحَدُكُمْ إِلَى الْمَجْلِسِ فَلْيُسَلِّمْ'));
      expect(arabicSeg.rawText, contains('فَلَيْسَتِ الْأُولَى بِأَحَقَّ مِنَ الْآخِرَةِ'));
    });

    test('12. Sayfa 28 (Eve Geldiğini Evdekilere Bildirmenin Önemi) heals ct?e, </Jildirmenin title, removes footer', () {
      const page28Raw = '''
ct?e Geldiğini, ct?dekilere </Jildirmenin Önemi Eve geldiğin zaman, içerdekileri korkutmamak için veya ailesine güvenmeyip baskın yapan biri durumuna düşmemek için, yanlarına girmeden önce geldiğini onlara bildir! Ebu Ubeyde Amir b. Abdullah b. Mes'ud (radıyallahu 'anh) şöyle anlatıyor: "Babam (Abdullah b. Mes'ud) eve geldiği zaman, yüksek sesle konuşarak, kendisinin geldiğini bize bildirirdi." Ahmed b. Hanbel (rahimehullah) şöyle demiştir: "Kişi evine geldiği zaman öksürmesi veya ayaklarını yere vurarak geldiğini haber vermesi, çok güzel bir davranıştır." Ahmed b. Hanbel (rahimehullah)'ın oğlu Abdullah da babasını şöyle anlatıyor: "Babam mescidden eve geldiği zamanda içeriye girmeden önce bazen ayaklarını yere vurarak bazen de öksürerek geldiğini bize haber verirdi." Buhari ve Müslim'in Cabir (radıyallahu 'anh)'dan aktardıkları rivayete göre: 26 İslâm'da Adab-ı Muaşeret Görgü Kuralları
''';

      expect(OcrService.requiresOcrEnhancement(page28Raw), isTrue);

      final extracted = TextSegmenter.extractFootnotesAndBody(page28Raw);
      expect(extracted.bodyText, contains('Eve Geldiğini, Evdekilere Bildirmenin Önemi'));
      expect(extracted.bodyText, isNot(contains('ct?e')));
      expect(extracted.bodyText, isNot(contains('</Jildirmenin')));
      expect(extracted.bodyText, isNot(contains('26 İslâm\'da Adab-ı Muaşeret Görgü Kuralları')));

      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: extracted.hadCorruptedCalligraphy,
      );

      final headingSeg = paragraphs.firstWhere((p) => p.isHeading);
      expect(headingSeg.rawText, equals('Eve Geldiğini, Evdekilere Bildirmenin Önemi'));
    });

    test('13. Yeme-İçme Edebi (Sağ Elle Yeme Hadisi) resolves Arabic card', () {
      const yemeText = '''
Yeme ve İçme Edebleri

Ömer b. Ebî Seleme (radıyallahu 'anh) şöyle nakletmiştir:
"Resûlullah (sallallahu 'aleyhi ve sellem) bana şöyle buyurdu: 'Ey çocuk! Besmele çek, sağ elinle ye ve önünden ye!'"1
__________
1 Sahih-i Buhari, Et'ime, 5376
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(yemeText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: true,
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('يَا غُلَامُ'));
      expect(arabicSeg.rawText, contains('سَمِّ اللَّهَ'));
      expect(arabicSeg.rawText, contains('وَكُلْ بِيَمِينِكَ'));
    });

    test('14. Aksırma ve Teşmît Duası resolves Arabic card', () {
      const aksirmaText = '''
Aksırma ve Esneme Edebi

Ebû Hüreyre (radıyallahu 'anh) rivayet ediyor:
"Sizden biriniz aksırdığı zaman 'Elhamdülillah' desin. Kardeşi de ona 'Yerhamükellah' desin. O da 'Yehdîkümullâh ve yuslihu bâleküm' diye mukabelede bulunsun."
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(aksirmaText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        hadCorruptedCalligraphy: true,
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('إِذَا عَطَسَ أَحَدُكُمْ'));
      expect(arabicSeg.rawText, contains('الْحَمْدُ لِلَّهِ'));
      expect(arabicSeg.rawText, contains('يَهْدِيكُمُ اللَّهُ'));
    });

    test('15. Komşuluk Hakkı ve Cebrail Hadisi resolves Arabic card', () {
      const komsuText = '''
Komşuluk Edebi ve Hakları

Hz. Âişe (radıyallahu 'anhâ)'dan rivayet edildiğine göre Efendimiz şöyle buyurdu:
"Cebrail bana komşuyu o kadar tavsiye etti ki, neredeyse onu mirasçı kılacak zannettim."1
__________
1 Sahih-i Buhari, Edeb, 6014
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(komsuText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
        hadCorruptedCalligraphy: true,
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('مَا زَالَ جِبْرِيلُ'));
      expect(arabicSeg.rawText, contains('بِالْجَارِ'));
    });

    test('16. Nur Suresi 27. Ayet (İsti\'zân) resolves Quranic verse Arabic card', () {
      const ayetText = '''
Evlere Girişte İzin İsteme Âyeti

Yüce Allah Nur Suresi 27. ayetinde şöyle buyurmaktadır:
"Ey iman edenler! Kendi evlerinizden başka evlere izin alıp halkına selam vermedikçe girmeyiniz!"
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(ayetText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        hadCorruptedCalligraphy: true,
      );

      final arabicSeg = paragraphs.firstWhere((p) => p.isArabic);
      expect(arabicSeg.rawText, contains('يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَدْخُلُوا بُيُوتًا غَيْرَ بُيُوتِكُمْ'));
      expect(arabicSeg.rawText, contains('حَتَّىٰ تَسْتَأْنِسُوا وَتُسَلِّمُوا'));
    });

    test('17. El-Ezkar Sayfa 20 Dipnot [9] merges standalone [9] line and resolves real Muslim 2674 tahric footnote', () {
      const elEzkarPage20 = '''
Sahîh-i Müslim'de Ebû Hüreyre radıyallahu anh'den rivayet edildiğine göre Resûlullah sallallahu aleyhi ve sellem şöyle buyurdu:

“İnsanları doğru yola (hidâyete) çağıran kimseye, kendisine uyanların sevabı kadar sevap verilir. Bu, onların sevaplarından bir şey azaltmaz.”

[9]
''';

      final extracted = TextSegmenter.extractFootnotesAndBody(elEzkarPage20);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        extracted.bodyText,
        pageFootnotes: extracted.footnotes,
      );

      // Standalone [9] must be merged into the preceding hadith paragraph, leaving 2 paragraphs instead of 3
      expect(paragraphs.length, equals(2));
      final hadithParagraph = paragraphs.last;
      expect(hadithParagraph.rawText, contains('azaltmaz.” [9]'));
      expect(hadithParagraph.footnoteAnchors, isNotEmpty);
      expect(hadithParagraph.footnoteAnchors.first.key, equals('9'));
      expect(
        hadithParagraph.footnoteAnchors.first.content,
        contains('Müslim, İlim 16, nr. 2674'),
      );
      expect(
        hadithParagraph.footnoteAnchors.first.content,
        isNot(contains('Bu sayfadaki ilgili izahat.')),
      );
    });

    test('18. Cross-page bracketed footnote extraction without space after bracket ([9]Müslim...)', () {
      const elEzkarEndnotesPage21 = '''
[1]Buhârî, Daavât 64, Tevhîd 50; Müslim, Zikir 2, 19, 22.
[3]Münker, zayıf râvinin sika (güvenilir) râvilere muhâlefet ederek tek başına rivâyet ettiği hadistir.
[9]Müslim, İlim 16, nr. 2674; Ebû Dâvûd, Sünnet 6, nr. 4609; Tirmizî, İlim 15, nr. 2674; İbn Mâce, Mukaddime 14, nr. 206. Bu hadisin daha uzun bir rivâyeti 925 numara ile gelecektir.
''';

      final footnoteMap = TextSegmenter.extractFootnoteMapFromRawText(elEzkarEndnotesPage21);
      expect(footnoteMap['1'], contains('Buhârî, Daavât 64'));
      expect(footnoteMap['3'], contains('Münker, zayıf râvinin'));
      expect(footnoteMap['9'], contains('Müslim, İlim 16, nr. 2674'));
      expect(footnoteMap['9'], contains('925 numara ile gelecektir'));
    });
  });
}
