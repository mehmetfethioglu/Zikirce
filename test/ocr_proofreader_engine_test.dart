import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' hide TextBlock;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahrir/features/marginalia/services/dictionary_service.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/engine/encoding_normalizer.dart';
import 'package:tahrir/features/reader/engine/ocr_lexicon_database.dart';
import 'package:tahrir/features/reader/engine/ocr_local_ai_language_model.dart';
import 'package:tahrir/features/reader/engine/ocr_proofreader_engine.dart';
import 'package:tahrir/features/reader/services/scanned_pdf_ocr_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OcrProofreaderEngine.ensureInitialized();
  });

  group('OcrProofreaderEngine — Word Tarzı Otomatik Tashih ve Gözden Geçir Testleri', () {
    test('1. Otomatik OCR Sonrası Tashih: rn->m, cl->d, c->a/e, g->ğ, rakam-harf ve diyakritik hatalarını sayfada otomatik düzeltir', () {
      const dirtyBlocks = <ContentBlock>[
        TextBlock(
          text:
              'Bu zarnan içinde clünya ve clevlet işlerinde bercber hareket etmek, k1tap ve ilim yolunda oldugu gibi hakıkat arayışında da müslümanlarn vazifesidir.',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(dirtyBlocks);
      final healedText = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(healedText, contains('Bu zaman içinde'));
      expect(healedText, contains('dünya ve devlet işlerinde'));
      expect(healedText, contains('beraber hareket etmek'));
      expect(healedText, contains('kitap ve ilim yolunda'));
      expect(healedText, contains('olduğu gibi'));
      expect(healedText, contains('hakikat arayışında'));
      expect(healedText, contains('müslümanların vazifesidir.'));

      // Gözden Geçir raporunda yapılan otomatik düzeltmelerin kayıt altına alındığını doğrula
      expect(result.report.autoCorrectedCount, greaterThanOrEqualTo(6));
      expect(
        result.report.autoCorrections.any(
          (c) => c.originalWord == 'zarnan' && c.correctedWord == 'zaman',
        ),
        isTrue,
      );
      expect(
        result.report.autoCorrections.any(
          (c) => c.originalWord == 'clünya' && c.correctedWord == 'dünya',
        ),
        isTrue,
      );
    });

    test('2. Ham OCR metni (unhealedRawText) ile iyileştirilmiş sayfa arasındaki farkları Gözden Geçir geçmişine kaydeder', () {
      const rawOcr =
          'Kitap 941 sene ön ceki müslümanlarm ulaştıklar؟ seviyeyi göstermektedir.';
      const healedBlocks = <ContentBlock>[
        TextBlock(
          text: 'Kitap 941 sene önceki müslümanların ulaştıkları seviyeyi göstermektedir.',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(
        healedBlocks,
        unhealedRawText: rawOcr,
      );

      expect(result.report.autoCorrectedCount, greaterThanOrEqualTo(2));
      expect(
        result.report.autoCorrections.any(
          (c) => c.correctedWord == 'müslümanların' || c.correctedWord == 'ulaştıkları',
        ),
        isTrue,
      );
    });

    test('3. Word "Öneriler" motoru hatalı kelimeler için doğru Türkçe/Osmanlıca adaylar üretir', () {
      final suggestionsForDeviet = OcrProofreaderEngine.suggestForWord('deviet');
      expect(suggestionsForDeviet, contains('devlet'));

      final suggestionsForZarnan = OcrProofreaderEngine.suggestForWord('zarnan');
      expect(suggestionsForZarnan, contains('zaman'));

      final suggestionsForHakikat = OcrProofreaderEngine.suggestForWord('hakıkat');
      expect(suggestionsForHakikat, contains('hakikat'));
    });

    test('4. Kullanıcı Otomatik Düzeltme (AutoCorrect) kuralı eklendiğinde sonraki sayfaları otomatik düzeltir', () async {
      await OcrProofreaderEngine.addAutoCorrectRule('müellifln', 'müellifin');

      const blocks = <ContentBlock>[
        TextBlock(text: 'Bu risale müellifln kendi el yazısı nüshasıdır.'),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final updatedText = (result.blocks.first as TextBlock).text;

      expect(updatedText, 'Bu risale müellifin kendi el yazısı nüshasıdır.');
      expect(
        result.report.autoCorrections.any(
          (c) =>
              c.originalWord == 'müellifln' &&
              c.correctedWord == 'müellifin' &&
              c.ruleCategory == 'Kullanıcı Tashih Kuralı',
        ),
        isTrue,
      );

      await OcrProofreaderEngine.removeAutoCorrectRule('müellifln');
    });

    test('5. Sayfa içi kelime değiştirme (replaceWordInBlocks) büyük/küçük harf uyumunu koruyarak ilgili sayfayı günceller', () {
      const blocks = <ContentBlock>[
        TextBlock(text: 'Bercber yürüdük ve bercber çalıştık.'),
      ];

      final updated = OcrProofreaderEngine.replaceWordInBlocks(
        blocks: blocks,
        targetWord: 'bercber',
        replacementWord: 'beraber',
      );

      expect(
        (updated.first as TextBlock).text,
        'Beraber yürüdük ve beraber çalıştık.',
      );
    });

    test('6. İbn Haldun Mukaddime Sayfa 45: BÖLÜMU, MUKADDİMESI, kaplmalan, kıhk, hükümdarlanın, politikayn, Dın, kurtanr hatalarını otomatik düzeltir', () {
      const blocks = <ContentBlock>[
        TextBlock(text: 'ESERİN ÖNSÖZ BÖLÜMU', isHeading: true),
        TextBlock(text: '(MUKADDİMESI)', isHeading: true),
        TextBlock(
          text:
              'Tarih ilminin fazilet ve meziyetleri, bep (sistem) ve metodlarının incelenmesi, tarihçilerin yanılmaları, vehme kaplmalan ve bunun baz sebepleri.',
        ),
        TextBlock(
          text:
              'Bil ki, tarih, gaye ve amacı şerefli ve faydaları çok olan bir ilimdir. Tarih, gelip geg kavimlerin hal ve ahlâklarını, Tanın elçilerinin kıhk hal ve hareketlerini, hükümdarlanın ve idare ettikleri devletlerin durumunu ve takibetmiş oldukları politikayn öğretir. Dın ve dünya işlerini bütünlemek isteyen kimse, tarihe başvurarak onu kendisine örnek edinir ve bu ilimden faydalanır. Tarih bu cihetlerden bir çok kaynaklara, türlü bilgilere, dikkatle bakış ve incelemelere ve kalblerde kanaat ve inan husule gelinceye kadar tesbite muhtaçtır. Bu gibi dikkat ve incelemeler, bu yolda hareket eden kimseyi, sürçme ve yanılmalardan kurtanr.',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final h1 = (result.blocks[0] as TextBlock).text;
      final h2 = (result.blocks[1] as TextBlock).text;
      final p1 = (result.blocks[2] as TextBlock).text;
      final p2 = (result.blocks[3] as TextBlock).text;

      expect(h1, 'ESERİN ÖNSÖZ BÖLÜMÜ');
      expect(h2, '(MUKADDİMESİ)');
      expect(p1, contains('mezhep (sistem)'));
      expect(p1, contains('vehme kapılmaları'));
      expect(p1, contains('bunun bazı sebepleri.'));
      expect(p2, contains('gelip geçen kavimlerin'));
      expect(p2, contains('Tanrı elçilerinin kılık hal'));
      expect(p2, contains('hükümdarlarının ve idare ettikleri'));
      expect(p2, contains('takip etmiş oldukları politikayı öğretir.'));
      expect(p2, contains('Din ve dünya işlerini'));
      expect(p2, contains('birçok kaynaklara'));
      expect(p2, contains('kanaat ve inanç husule'));
      expect(p2, contains('yanılmalardan kurtarır.'));
      expect(result.report.suggestionCount, 0);
    });

    test('7. Ulusların Düşüşü (Sayfa 14) gerçek cihaz ekran görüntüsü: satır sonu ve hece bölünmelerini eksiksiz birleştirir ve raporlar', () {
      const brokenParagraph =
          'Mısır’daki sıradan yurt taşlar için sorunların çözüm biçimi, siyasi gücün tek elde toplanmasının önüne geçmek ve toplumun geniş kesimlerinin siyasal sürece katılmasını sağlamaktır. '
          'İngiltere, Fransa ve Birleşik Devletler’de bu sürecin bi çimini inceleyeceğiz. '
          'Bunun için yapılması gere ken, hakikaten siyasal bir dönüşümdür di yor. '
          'Bu dönüşümün nasıl gerçekleştiğini gö receğiz. '
          'Eğer bu dönüşümün nedenlerini an larsak, '
          'Tunus ve Mısır’daki gibi toplumsal hareketlerin neden sık ilkle başarısızlıkla sonuçlandığını ve bir diktatörün devrilmesinin neden yeni bir diktatörlüğe götü receğini daha iyi değerlendirebiliriz.';

      final result = OcrProofreaderEngine.proofreadBlocks([
        const TextBlock(text: brokenParagraph),
      ]);
      final healed = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(healed, contains('sıradan yurttaşlar için'));
      expect(healed, contains('sürecin biçimini inceleyeceğiz.'));
      expect(healed, contains('yapılması gereken, hakikaten'));
      expect(healed, contains('bir dönüşümdür diyor.'));
      expect(healed, contains('gerçekleştiğini göreceğiz.'));
      expect(healed, contains('nedenlerini anlarsak,'));
      expect(healed, contains('neden sıklıkla başarısızlıkla'));
      expect(healed, contains('diktatörlüğe götüreceğini daha iyi'));

      final mergeCorrections = result.report.autoCorrections
          .where((c) => c.ruleCategory == 'Bölünmüş Kelime Birleştirme')
          .toList();
      expect(mergeCorrections.length, greaterThanOrEqualTo(8));

      // Soft-hyphen (\u00AD) satır sonu bölünmesi testi
      final deHyphenated = EncodingNormalizer.deHyphenate(
        'sürecin bi\u00AD\nçimini ve yurt\n taşlar',
      );
      expect(deHyphenated, contains('biçimini'));
      expect(deHyphenated, contains('yurttaşlar'));
    });

    test('8. Osmanlıca İzafet Terkip Tashihi: tire düşmesiyle 2 veya 3 kelimeye bölünmüş terkipleri standart tireli forma dönüştürür', () {
      const blocks = <ContentBlock>[
        TextBlock(
          text:
              'Osmanlı toplumunda adab ı muaşeret ve ehl i sünnet anlayışı, devlet i aliyye asırlarında kanun ı kadim ve nizamı alem ilkeleriyle birlikte yaşatılmıştır.',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final healed = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(healed, contains('âdâb-ı muaşeret'));
      expect(healed, contains('ehl-i sünnet'));
      expect(healed, contains('devlet-i aliyye'));
      expect(healed, contains('kânûn-ı kadîm'));
      expect(healed, contains('nizâm-ı âlem'));
      expect(
        result.report.autoCorrections.any(
          (c) => c.ruleCategory == 'Osmanlıca Terkip Tashihi',
        ),
        isTrue,
      );
    });

    test('9. DictionaryService: Osmanlıca terkipleri bağlamsal olarak ve çekimli fiil/isim gövdelerini morfolojik olarak çözümler', () {
      final dict = DictionaryService();

      // Bağlamsal Osmanlıca terkip çözümlemesi
      final terkipByPart = dict.lookup(
        'adab',
        surroundingText: 'Toplumda âdâb-ı muaşeret kurallarına riayet edilmelidir.',
      );
      expect(terkipByPart.word, 'Âdâb-ı Muaşeret');

      final terkipDirect = dict.lookup('adabı muaşeret');
      expect(terkipDirect.word, 'Âdâb-ı Muaşeret');

      // Çekimli fiil ve isim kök çözümlemesi (Ulusların Düşüşü kelimeleri)
      expect(dict.lookup('göreceğiz').word, 'Görmek');
      expect(dict.lookup('anlarsak').word, 'Anlamak');
      expect(dict.lookup('götüreceğini').word, 'Götürmek');
      expect(dict.lookup('diyor').word, 'Demek');
      expect(dict.lookup('gereken').word, 'Gerekmek');
      expect(dict.lookup('yurttaşlar').word, 'Yurttaş');
      expect(dict.lookup('biçimini').word, 'Biçim');
      expect(dict.lookup('dönüşümdür').word, 'Dönüşüm');
    });

    test('10. Katman 1 (ML Kit Geometri & Confidence): Mikro-boşluklu heceleri piksel geometrisiyle birleştirir ve düşük güvenli kelimeleri yakalar', () {
      // Ortalama karakter genişliği ~10px:
      // "sürecin" (0..70), "bi" (82..102), "çimini" (105..165 -> gap=3px < 10*0.48=4.8px -> birleşmeli!), "ilkle" (178..228, confidence=0.58)
      final mockLine = TextLine(
        text: 'sürecin bi çimini ilkle',
        boundingBox: const Rect.fromLTWH(0, 0, 228, 20),
        recognizedLanguages: const ['tr'],
        cornerPoints: const [],
        confidence: 0.85,
        angle: 0.0,
        elements: [
          TextElement(
            text: 'sürecin',
            symbols: const [],
            boundingBox: const Rect.fromLTWH(0, 0, 70, 20),
            recognizedLanguages: const ['tr'],
            cornerPoints: const [],
            confidence: 0.96,
            angle: 0.0,
          ),
          TextElement(
            text: 'bi',
            symbols: const [],
            boundingBox: const Rect.fromLTWH(82, 0, 20, 20),
            recognizedLanguages: const ['tr'],
            cornerPoints: const [],
            confidence: 0.91,
            angle: 0.0,
          ),
          TextElement(
            text: 'çimini',
            symbols: const [],
            boundingBox: const Rect.fromLTWH(105, 0, 60, 20),
            recognizedLanguages: const ['tr'],
            cornerPoints: const [],
            confidence: 0.92,
            angle: 0.0,
          ),
          TextElement(
            text: 'görecegiz',
            symbols: const [],
            boundingBox: const Rect.fromLTWH(178, 0, 90, 20),
            recognizedLanguages: const ['tr'],
            cornerPoints: const [],
            confidence: 0.58,
            angle: 0.0,
          ),
        ],
      );

      final (reconstructed, lowConf) =
          ScannedPdfOcrService.analyzeMlKitLineGeometryAndConfidence(mockLine);

      expect(reconstructed, 'sürecin biçimini görecegiz');
      expect(lowConf.containsKey('görecegiz'), isTrue);
      expect(lowConf['görecegiz'], closeTo(0.58, 0.001));
    });

    test('11. Katman 2 & 3 (Yerel AI SymSpell + Bağlamsal N-Gram + Char-Beam-Search): Sabit tabloda yer almayan bozuk ve bölünmüş kelimeleri bağlam içinde onarır', () {
      const unseenCorruptedParagraph =
          'Bu dönüşümün nasıl gercek lestiğini gö recegiz ve toplumsal hareketlerin neden basarısız ilkle sonuçlandığını daha iyi deger lendirebilmek için çalışacağız.';

      final result = OcrProofreaderEngine.proofreadBlocks(
        const [TextBlock(text: unseenCorruptedParagraph)],
        mlKitLowConfidenceWords: const {'recegiz': 0.61, 'ilkle': 0.54},
      );
      final healed = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(healed, contains('nasıl gerçekleştiğini göreceğiz'));
      expect(healed, contains('neden başarısızlıkla sonuçlandığını'));
      expect(healed, contains('daha iyi değerlendirebilmek için'));

      // Bağlamsal N-Gram puanlayıcı doğrulaması: "neden ... sonuçlandığını" bağlamında "sıklıkla" > "sıkıysa"
      final scoreSiklikla = OcrLocalAiLanguageModel.scoreCandidateInContext(
        candidate: 'sıklıkla',
        lexicon: OcrLexiconDatabase.extendedTurkishAndOttomanStems,
        prevWord: 'neden',
        nextWord: 'başarısızlıkla',
        editDistance: 1.0,
      );
      expect(scoreSiklikla, greaterThan(0.85));
    });

    test('12. İbn Haldun Mukaddimesi (Sayfa 48) gerçek ekran görüntüsü: bağlamsal gerçek-kelime ve morfolojik POS hatalarını eksiksiz onarır', () {
      const blocks = <ContentBlock>[
        TextBlock(text: 'ÎBNİ HALAUN MUKADDİMESİ I. 21', isHeading: true),
        TextBlock(
          text:
              'kıl eden askerlerin sayısı 120 dini geçmemiştir. '
              'Yine Seyfin rivayetine göre bu savaşa iştikak edinlerin hepsi de savaşan askerler idi. '
              'Hizmetçi, işçi vesaire 200 ibnden fazla idi. '
              'Ayşe ile Zührî*- ye göre Kadisiyye’de Sa’d komutasında bu savaşa iştikak eden İslâm askeri ile savaşan Rüstem Komutasındaki Fark Devleti askerlerinin sayısı 60 bin oluş, bunların hepsi de savaşan askeridi. '
              'Yani işçi gibi yardımcı sınıf bu sayının dışında idi. '
              'İsrail oğullarının askeri yukarda sözü geçen sayıda olduğu takdirde, devletlerinin sınıf, yurt ve bölgeleri genişlerdi. '
              'Çünkü yurdun genişliği veya küçüklüğü, onlan koruyan askerin, o yurt ve ülkelerde yaşayan uruğ ve insanların çokluğu veya azlığı ile mütenasip okur. '
              'Bu hususta bu eserin birinci kitabında bilgiler vereceğiz. '
              'İsrail oğullarına gelence, bilimdiği gibi, onların yurtları Ürdün ve Şam’ın Filistin kısım ile Hicaz’da Yesrib (Medine) ve nüfustan ibaret idiler. '
              'Kıptîlerden olan Firavunlar onlan',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final heading = (result.blocks[0] as TextBlock).text;
      final body = (result.blocks[1] as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(heading, 'İBNİ HALDUN MUKADDİMESİ I. 21');
      expect(body, contains('teşkil eden askerlerin sayısı 120 bini geçmemiştir.'));
      expect(body, contains('bu savaşa iştirak edenlerin hepsi de'));
      expect(body, contains('200 binden fazla idi.'));
      expect(body, contains("Ayşe ile Zührî'ye göre"));
      expect(body, contains('bu savaşa iştirak eden İslâm askeri'));
      expect(body, contains('Rüstem komutasındaki Fars Devleti askerlerinin sayısı 60 bin olup, bunların hepsi de savaşan asker idi.'));
      expect(body, contains('devletlerinin sınır, yurt ve bölgeleri genişlerdi.'));
      expect(body, contains('onları koruyan askerin'));
      expect(body, contains('mütenasip olur.'));
      expect(body, contains('İsrail oğullarına gelince, bilindiği gibi,'));
      expect(body, contains('Filistin kısmı ile'));
      expect(body, contains('Firavunlar onları'));
    });

    test('13. Ulusların Düşüşü (Sayfa 15) gerçek ekran görüntüsü: ayrılık->ayrılır, durum->durun, Santa Aruz->Cruz, Artzona->Arizona, göıiirsünüz->görürsünüz, getir->gelir, yaklaşım->yaklaşık, yoğunluğu->çoğunluğu, diridir->biridir onarımı', () {
      const blocks = <ContentBlock>[
        TextBlock(
          text:
              "Nogales kenti bir çitle ikiye ayrılık. Yanında durum ve kuzeye Bakarsanız Santa Aruz County'deki Nogales Artzona'yı göıiirsünüz. "
              'Hane başına ortalama getir yıllık yaklaşım 30 bin dolar kadardır. '
              'Gençlerin çoğu okula gider ve yetişkinlerin büyük yoğunluğu lise mezunudur. '
              'Bu, devletin sağladığı, elektrik, telefon, kanalizasyon sistemi, halk sağlığı, onları diğer kentlere bağlayan yol ağı ve elbette yasa ve düzen gibi çoğu insanın hak olarak gördüğü hizmetlerden yalnızca diridir. '
              'Nogales Artzona halkı can ve mal güvenliği Anneler bebek ölümlerindeki yüksek oran nedeniyle endişe içindedir. '
              'Halk sağlığı koşullarının ye=',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final body = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(body, contains('Nogales kenti bir çitle ikiye ayrılır.'));
      expect(body, contains("Yanında durun ve kuzeye bakarsanız Santa Cruz County'deki Nogales Arizona'yı görürsünüz."));
      expect(body, contains('Hane başına ortalama gelir yıllık yaklaşık 30 bin dolar kadardır.'));
      expect(body, contains('yetişkinlerin büyük çoğunluğu lise mezunudur.'));
      expect(body, contains('hizmetlerden yalnızca biridir.'));
      expect(body, contains('Nogales Arizona halkı'));
      expect(body.endsWith('koşullarının ye-'), isTrue);
    });

    test('14. Kapsamlı rı/ri -> n Ligatür Kaynaşması Onarımı: ünsüz sonrası, alıntı kelimeler, çoğul -lan/-len/-lann/-lenn, çift ligatür ve bağlamsal gerçek-kelime rı/ri->n hatalarını kusursuz onarır', () {
      const blocks = <ContentBlock>[
        TextBlock(
          text:
              'Aynca bu konunun aynntılan üzennde durmak gerekir. '
              'İnsanlann ve devletlenn tanh boyunca birbinne karşı tutumu, '
              'kurumlan, koşullan ve haklan doğrudan etkilemiştir. '
              'Nüfusun yansından fazlası tanm ve yatınmlan ile geçinir, '
              'bunlardan bin gen çekildiğinde diğeri içen girdi. '
              'Cumhunyet ve hürnyet fikn, şehn ve nehn aşarak Afrikadan Amerikaya yayıldı. '
              'Yapılan anlaşmalar ve verilen sözler olan biteni değiştirmedi.',
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final body = (result.blocks.first as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(
        body,
        contains('Ayrıca bu konunun ayrıntıları üzerinde durmak gerekir.'),
      );
      expect(
        body,
        contains(
          'İnsanların ve devletlerin tarih boyunca birbirine karşı tutumu,',
        ),
      );
      expect(
        body,
        contains('kurumları, koşulları ve hakları doğrudan etkilemiştir.'),
      );
      expect(
        body,
        contains('Nüfusun yarısından fazlası tarım ve yatırımları ile geçinir,'),
      );
      expect(
        body,
        contains('bunlardan biri geri çekildiğinde diğeri içeri girdi.'),
      );
      expect(
        body,
        contains('Cumhuriyet ve hürriyet fikri, şehri ve nehri aşarak'),
      );
      // Geçerli edilgen ortaçların ('Yapılan', 'verilen', 'olan') bozulmadığını doğrula
      expect(
        body,
        contains('Yapılan anlaşmalar ve verilen sözler olan biteni değiştirmedi.'),
      );
    });

    test('15. Görünmez yumuşak tire (\\u00AD) ve bloklar arası kırık tireli kelime onarımı çalışır', () {
      const blocks = <ContentBlock>[
        TextBlock(text: 'Osmanlı me\u00ADdeniyeti ve dev-'),
        TextBlock(text: 'let teşkilatı güçlüdür.'),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final firstText = (result.blocks[0] as TextBlock).text;
      final secondText = (result.blocks[1] as TextBlock).text;

      expect(result.didModifyBlocks, isTrue);
      expect(firstText, contains('Osmanlı medeniyeti ve devlet'));
      expect(secondText, startsWith('teşkilatı güçlüdür.'));
    });

    test('16. Dipnot (FootnoteAnchor) içeriği de proofreadBlocks ve replaceWordInBlocks ile tashih edilir', () {
      const blocks = <ContentBlock>[
        TextBlock(
          text: 'Tarih ilmi önemlidir. [1]',
          footnoteAnchors: [
            FootnoteAnchor(
              key: '1',
              indexInText: 22,
              content: 'Bu kıtap müslümanlarn eseridir.',
            ),
          ],
        ),
      ];

      final result = OcrProofreaderEngine.proofreadBlocks(blocks);
      final updatedBlock = result.blocks.first as TextBlock;
      expect(
        updatedBlock.footnoteAnchors.first.content,
        'Bu kitap müslümanların eseridir.',
      );

      final replaced = OcrProofreaderEngine.replaceWordInBlocks(
        blocks: result.blocks,
        targetWord: 'eseridir',
        replacementWord: 'kaynağıdır',
      );
      final replacedBlock = replaced.first as TextBlock;
      expect(
        replacedBlock.footnoteAnchors.first.content,
        'Bu kitap müslümanların kaynağıdır.',
      );
    });

    test('17. Türkçe I/İ küçük harf dönüşümü, sıfır sızıntılı şüpheli kelime yakalama ve removeIgnoredWord çalışır', () async {
      expect(
        OcrProofreaderEngine.toTurkishLower('IŞIK İNSANLARIN'),
        'ışık insanların',
      );

      const corruptBlock = <ContentBlock>[
        TextBlock(text: 'Bu kxtqpz metinde bozuk bir kelimedir.'),
      ];

      final firstPass = OcrProofreaderEngine.proofreadBlocks(corruptBlock);
      expect(
        firstPass.report.suggestions.any(
          (s) => OcrProofreaderEngine.toTurkishLower(s.suspiciousWord) == 'kxtqpz',
        ),
        isTrue,
      );

      await OcrProofreaderEngine.addIgnoredWord('kxtqpz');
      final ignoredPass = OcrProofreaderEngine.proofreadBlocks(corruptBlock);
      expect(
        ignoredPass.report.suggestions.any(
          (s) => OcrProofreaderEngine.toTurkishLower(s.suspiciousWord) == 'kxtqpz',
        ),
        isFalse,
      );

      await OcrProofreaderEngine.removeIgnoredWord('kxtqpz');
      final unignoredPass = OcrProofreaderEngine.proofreadBlocks(corruptBlock);
      expect(
        unignoredPass.report.suggestions.any(
          (s) => OcrProofreaderEngine.toTurkishLower(s.suspiciousWord) == 'kxtqpz',
        ),
        isTrue,
      );
    });
  });
}
