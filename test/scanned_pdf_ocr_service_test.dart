import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/engine/encoding_normalizer.dart';
import 'package:tahrir/features/reader/engine/layout_column_detector.dart';
import 'package:tahrir/features/reader/engine/ocr_text_healer.dart';
import 'package:tahrir/features/reader/engine/pdf_reflow_engine.dart';
import 'package:tahrir/features/reader/engine/smart_reflow_pipeline.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';
import 'package:tahrir/features/reader/services/scanned_pdf_ocr_service.dart';

void main() {
  group('ScannedPdfOcrService & PipelinePageResult Tests', () {
    test('1. ScannedPageOcrResult default empty state is clean and non-null', () {
      const empty = ScannedPageOcrResult.empty();
      expect(empty.blocks, isEmpty);
      expect(empty.rawText, '');
      expect(empty.hasNonLatinOrVisualWarning, isFalse);
      expect(empty.isFromCache, isFalse);
    });

    test('2. PipelinePageResult holds contentBlocks and hasNonLatinOrVisualWarning flag', () {
      const result = PipelinePageResult(
        blocks: [
          TextBlock(text: 'Deneme Başlığı', isHeading: true),
          TextBlock(text: 'Taranmış sayfadan elde edilen Türkçe metin gövdesi.'),
        ],
        hasNonLatinOrVisualWarning: true,
      );

      expect(result.blocks.length, 2);
      expect(result.hasNonLatinOrVisualWarning, isTrue);
      expect((result.blocks.first as TextBlock).isHeading, isTrue);
    });

    test('3. ReflowPageData correctly propagates hasNonLatinOrVisualWarning', () {
      final pageData = ReflowPageData(
        pageNumber: 5,
        rawText: 'Taranmış sayfa gövdesi',
        paragraphs: const [],
        contentBlocks: const [TextBlock(text: 'Taranmış metin')],
        hasTextContent: true,
        isOcrEnhanced: true,
        hasNonLatinOrVisualWarning: true,
      );

      expect(pageData.pageNumber, 5);
      expect(pageData.hasTextContent, isTrue);
      expect(pageData.isOcrEnhanced, isTrue);
      expect(pageData.hasNonLatinOrVisualWarning, isTrue);
    });

    test('4. ScannedPdfOcrService handles sample:// and non-existent files gracefully without crashing', () async {
      const service = ScannedPdfOcrService();
      final result = await service.processScannedPage(
        filePath: 'sample://non_existent_scanned.pdf',
        pageIndex: 0,
      );

      expect(result.blocks, isEmpty);
      expect(result.rawText, '');
      expect(result.hasNonLatinOrVisualWarning, isFalse);
    });

    test('5. El-Ahkamu\'s-Sultaniyye Sayfa 6: Rejects hallucinated Arabic card ("أأأأسأ©ء", "ك") and heals copyright page', () {
      const page6DirtyOcr = '''
أأأأسأ©ء
ك
أ!§هص Islâm!
V ® tedris uğruna ömrünü هو©ه€؛!ه ¥ bil« yükbabara, Yeşilhisar’!؟ Yusuf zade §2 أم’ىئطئ هه ruhuma
ithaf ediyorum.
Dr. A. ŞAFAK
B Bu eserin bütün faüku&s, Bedir Yayınevine âittir0
M
Kapak filim ve baskısı f Ansan · Ofset - T@L.6 22 22 §؛
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page6DirtyOcr), isTrue);
      expect(OcrTextHealer.isValidArabicSegment('أأأأسأ©ء'), isFalse);
      expect(OcrTextHealer.isValidArabicSegment('ك'), isFalse);

      final normalized = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.stripHeaderAndFooter(
          EncodingNormalizer.deHyphenate(page6DirtyOcr),
        ),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(normalized);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        pageResult.bodyText,
        pageFootnotes: pageResult.footnotes,
      );

      // Hiçbir paragraf sahte Arapça kartı olarak işaretlenmemeli
      expect(paragraphs.any((p) => p.isArabic), isFalse);
      expect(pageResult.bodyText, isNot(contains('أأأأسأ©ء')));
      expect(pageResult.bodyText, isNot(contains('هو©ه€؛!ه')));
      expect(pageResult.bodyText, isNot(contains('faüku&s')));
      expect(pageResult.bodyText, isNot(contains('âittir0')));
      expect(pageResult.bodyText, contains('İslâm!'));
      expect(pageResult.bodyText, contains('Bu eserin bütün hakları, Bedir Yayınevine âittir.'));
      expect(pageResult.bodyText, contains('Kapak film ve baskısı'));
    });

    test('6. El-Ahkamu\'s-Sultaniyye Sayfa 8: Heals split Turkish words, guillemets, exclamation marks, bullets, and corrupted suffixes', () {
      const page8DirtyOcr = '''
anlayışlarıyle karşı karşıya olduğumuzu unutmamalıyız. Kitap 941 sene ön ceki müslümanlarm ulaştıklar؟ Âmme ve îdare Hukuku alanındaki se viyeyi göstermektedir. Böyle düşünüldüğünde eser oldukça enteresandır» Verilen hukuk! bilgiler için müşahhas.örnekler vermiş, şiirler kaydetmiş tir» Eserde anlatılan konular hakkında bizzat kendisi eserinin sonunda şöyle demektedir:

«Bizim bu kitapta temas ettiğimiz konular, diğer hukukçuların hiç teınâs etmediği veya çok kısa temas ettikleri konulardır. Onların hiç te= mâs etmediklerini anlattık, kısa olarak geçtiklerini açıkladıkallah TeâBugunkÜ Laik hukuklarda da benzeri hukuk müesseseler! bulunan igbu eserin tercemesı ile yeni •nesle eski hukukumuzun kaidelerinin neler olduğunu •okuyup öğrenme fırsatını sağlama gayesi göz önünde tutulmuş tur» Eser iîmî ve teknik konuları ihtiva ettiğinden ‘ercemeninyanlışsız ©Huğunu iddia edemeyiz» Metne sadakat yanında bazı hukuk 'müessese-.!erinin bugünkü hukuklardaki karşılıklarını birlikte kullandık. Bu iti barla muhterem okuyuculardan bilhassa Âmme ve İdare Hukuku âlim،•' Serinden yapıcı tenkidlerini bekler, eserin milletimize faydalı olmasını Alı. Âli ŞAFAK’D
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page8DirtyOcr), isTrue);

      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.deHyphenate(page8DirtyOcr),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final body = pageResult.bodyText;

      // 1. Hece ve ek bölünmeleri birleşmeli
      expect(body, contains('941 sene önceki'));
      expect(body, contains('müslümanların ulaştıkları'));
      expect(body, contains('Âmme ve İdare Hukuku alanındaki seviyeyi'));
      expect(body, contains('kaydetmiştir.'));
      expect(body, contains('tutulmuştur.'));
      expect(body, contains('Bu itibarla'));

      // 2. Noktalama, ünlem ve sembol bozulmaları onarılmalı
      expect(body, contains('oldukça enteresandır. Verilen'));
      expect(body, contains('Verilen hukukî bilgiler için'));
      expect(body, contains('müşahhas örnekler vermiş'));
      expect(body, contains('hiç temâs etmediği'));
      expect(body, contains('hiç temâs etmediklerini'));
      expect(body, contains('hukuk müesseseleri bulunan'));
      expect(body, contains('işbu eserin tercemesi ile'));
      expect(body, contains('yeni nesle'));
      expect(body, contains('olduğunu okuyup'));
      expect(body, contains('Eser ilmî ve teknik'));
      expect(body, contains('tercemenin yanlışsız olduğunu iddia edemeyiz.'));
      expect(body, contains('hukuk müesseselerinin bugünkü'));
      expect(body, contains('Âmme ve İdare Hukuku âlimlerinden'));
      expect(body, isNot(contains('©Huğunu')));
      expect(body, isNot(contains('•nesle')));
      expect(body, isNot(contains('•okuyup')));
      expect(body, isNot(contains('ulaştıklar؟')));
      expect(body, isNot(contains('âlim،•\'')));
    });

    test('7. LayoutColumnDetector merges horizontally fragmented boxes on the same visual row without false paragraph breaks', () {
      const pageWidth = 500.0;
      const pageHeight = 700.0;

      // Aynı görsel satırda 3 ayrı kutuya bölünmüş ve hafif dikey kayması (skew) olan OCR satırı
      final fragmentedLines = [
        const PositionedTextLine(text: 'Kitap 941 sene', bounds: Rect.fromLTWH(40, 100, 120, 16)),
        const PositionedTextLine(text: 'önceki müslümanların', bounds: Rect.fromLTWH(168, 103, 150, 16)),
        const PositionedTextLine(text: 'ulaştıkları seviyeyi', bounds: Rect.fromLTWH(325, 101, 130, 16)),
        const PositionedTextLine(text: 'açıkça göstermektedir.', bounds: Rect.fromLTWH(40, 124, 180, 16)),
      ];

      final ordered = LayoutColumnDetector.orderLinesByReadingFlow(
        rawLines: fragmentedLines,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(ordered.length, 2);
      expect(ordered.first.text, 'Kitap 941 sene önceki müslümanların ulaştıkları seviyeyi');
      expect(ordered.last.text, 'açıkça göstermektedir.');
    });

    test('8. Yunan Mezalimi Sayfa 36: Reconstructs letter-spaced quotes, "::", "!" suffix, and merges false paragraph split', () {
      const page36DirtyOcr = '''
YUNAN MEZÂLİMİ 7

Sim telâkkilere karşı da bir “ z idd- kâ m iI” is nasıl müstesna bir mevsiminde girdiğimiz! anicnak içi:: ortcdcki hâdiselere bir göz ctmak yeter. Dünlü büyü:: devietimizin terkettiğimiz kısımları üzerinde henüz devici oiabilmiş ve istikrara kavuşmuş tek bir siyâsi varlik vüct bulmamıştır. işte Balkantarın hergün birbirine hirtayon va coğu esir küçük devletleri!Ve işte Ceziretülarabn aşiret vasfnı cşamammş devtetçikleri!

Siyâsi, tarihi, coğrafi, iktisadi ve hattâ manevî tek bir ünite teşkil eden bu geniş topraklar -frenkçe tôbiriylemontörünü bekleyen demonte parçalardr. Bu purçala: Birleştirerek M üsiüm an Tü rk” ün idâresinde büyük ve czametti devieti kurulacak idealist Müslümcn

Türk Gençliğtne selôm olsun!

KADİR MISIROĞLU 25 Eylül 1968 Serencebey - İstanbul
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page36DirtyOcr), isTrue);

      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.stripHeaderAndFooter(
          EncodingNormalizer.deHyphenate(page36DirtyOcr),
        ),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(pageResult.bodyText);

      expect(paragraphs.length, 3);
      expect(
        paragraphs[0].rawText,
        'Bütün telâkkilere karşı da bir “zıdd-ı kâmil”i nasıl müstesna bir mevsimine girdiğimizi anlamak için ortadaki hâdiselere bir göz atmak yeter. Dünkü büyük devletimizin terkettiğimiz kısımları üzerinde henüz devlet olabilmiş ve istikrara kavuşmuş tek bir siyâsî varlık vücut bulmamıştır. İşte Balkanların her gün birbirine hırlayan ve çoğu esir küçük devletleri! Ve işte Ceziretülarabın aşiret vasfını aşamamış devletçikleri!',
      );
      expect(
        paragraphs[1].rawText,
        'Siyâsî, tarihî, coğrafî, iktisadî ve hattâ manevî tek bir ünite teşkil eden bu geniş topraklar -frenkçe tâbiriyle- montörünü bekleyen demonte parçalardır. Bu parçaları birleştirerek “Müslüman Türk”ün idâresinde büyük ve azametli devleti kuracak idealist Müslüman Türk Gençliğine selâm olsun!',
      );
      expect(
        paragraphs[2].rawText,
        'KADİR MISIROĞLU 25 Eylül 1968 Serencebey - İstanbul',
      );
    });

    test('9. Yunan Mezalimi Sayfa 38: Heals Polish/European diacritics (ł, ô, ê, í), reduplications, and plural/verb suffixes', () {
      const page38DirtyOcr = '''
YUNAN MEZÂLİMİ 39
Bu müstesna hüviyet, Milazgirt'te eskiden kurmuş olcluğu imparatorlukiarın siyôsi ve medeni seviyesini çok aşccak yeni bir devletin temelini atıyordu. Artik, asriarın başı frtnah süvarileri, “ Meviânâ ” olup ney'in avelu ferycdiyie ağlcyacak, “ Yunus” olup aşkın cetin yollarnda ayakları şerha serha kanayarak ilerleyecetir. Kendi ruhlarnı fethetmeden ülkeler fethine çikmoyacak, kendi nefislerini zaptetmeden şehirler zaptetmiyecektir. Kuru kavga ile cihangirlik dâvcIsint bırakıp, Allch'n namını yüceltmek için yapıcı, kurtarici, uyandırıcı başbuğlarin ardından gidecektir.

Hcikatini kabul ettirmek için şiddet kullanmayı meneden islâm'ın, bu mübârek gâzileri, trâcdelerine ram ettikleri ülkelere henüz hiçbir miletin ulaşmamış olduğu derecede geniş bir hürriyet bahşediyoriardı, Ne yazık ki, bütün Orta Cağ boyunca Engizisyon sehpałarı kurup kaldırmakla meşgul olcin Aurupa, bu asil davranışı değerlendirememiş, kapısına kadar geimiş alan bu ebedi kurtuluş imkânını tepmiştir. isêhi takdir ve beşerí nasip meselesi.
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page38DirtyOcr), isTrue);

      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.stripHeaderAndFooter(
          EncodingNormalizer.deHyphenate(page38DirtyOcr),
        ),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(pageResult.bodyText);

      expect(paragraphs.length, 2);
      expect(
        paragraphs[0].rawText,
        "Bu müstesna hüviyet, Malazgirt'te eskiden kurmuş olduğu imparatorlukların siyâsî ve medenî seviyesini çok aşacak yeni bir devletin temelini atıyordu. Artık, asırların başı fırtınalı süvarileri, “Mevlânâ” olup ney'in alevli feryadıyle ağlayacak, “Yunus” olup aşkın çetin yollarında ayakları şerha şerha kanayarak ilerleyecektir. Kendi ruhlarını fethetmeden ülkeler fethine çıkmayacak, kendi nefislerini zaptetmeden şehirler zaptetmiyecektir. Kuru kavga ile cihangirlik dâvâsını bırakıp, Allah'ın namını yüceltmek için yapıcı, kurtarıcı, uyandırıcı başbuğların ardından gidecektir.",
      );
      expect(
        paragraphs[1].rawText,
        "Hakikatini kabul ettirmek için şiddet kullanmayı meneden İslâm'ın, bu mübârek gâzileri, irâdelerine ram ettikleri ülkelere henüz hiçbir milletin ulaşmamış olduğu derecede geniş bir hürriyet bahşediyorlardı. Ne yazık ki, bütün Orta Çağ boyunca Engizisyon sehpaları kurup kaldırmakla meşgul olan Avrupa, bu asil davranışı değerlendirememiş, kapısına kadar gelmiş olan bu ebedî kurtuluş imkânını tepmiştir. İlâhî takdir ve beşerî nasip meselesi.",
      );
    });

    test('10. Yunan Mezalimi Sayfa 40: Heals letter-spaced Hadith quote, ". mişizdir" false period, "üi" ghost dot, and mid-sentence split', () {
      const page40DirtyOcr = '''
içleri kin ve nofretle dolu Luirçok bedbcht tarcından da saistimct edtniştir. Euniar, her frsattan istifade ederek çetik gibi sağlam miii

bünyermizi içerden ve dışardan kemimoye koyulnmuşiavdr. Hiyânetleri birer birer oriaya cikıp beli olmcya başladıgı zamanda da aşiri an'aneví müscmahakârhğımıai, daha cicğrusu affedici ve unutuculuğumuzu maaleset terketme. mişizdir. işte magiûbiyet ve yıkım bizim için o zaman bcrşlartşlır. Varliğin tâcı Efercimiz “ H ê I i sier büy ü k bir tehl i ke ü z erin dedirier! buyurarak bu mevzudaki tehlikeye işaret etmişlerdi. “ Deviet-i ebed m üd d et” gibi narnicrla onlan devletimizin kudretine güvenerek düşmanı dôima küçümsedik. Halbuki düşmann kücüğü yoktur. Insanın en küçük düişmanı olan mikroplar, nice çınar gibi yiğitleri zaaanla yere sermoktedirler. Muhakkak ki; mikrobu müihimsemiyen bir bünye, ne kadar sağlam olursa olsun eninde sonunda hastaitktan korunamaz.

Geçen usırda bu içten kerniren düşmaniann gayretierine yeni ve müthiş bir başka müessir eklendi: Dünyada süratle gerçekleşen “s an û yi inkı lâ bı na cyak uydunak için zamannda ve gereği gibi hcrske e gememekti!. Burada böyle basit bir şekilde tâde edilen bu tatanın
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page40DirtyOcr), isTrue);

      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.stripHeaderAndFooter(
          EncodingNormalizer.deHyphenate(page40DirtyOcr),
        ),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(pageResult.bodyText);

      expect(paragraphs.length, 2);
      expect(
        paragraphs[0].rawText,
        "İçleri kin ve nefretle dolu birçok bedbaht tarafından da suistimal edilmiştir. Bunlar, her fırsattan istifade ederek çelik gibi sağlam millî bünyemizi içerden ve dışardan kemirmeye koyulmuşlardır. Hiyânetleri birer birer ortaya çıkıp belli olmaya başladığı zamanda da aşırı an'anevî müsamahakârlığımızı, daha doğrusu affedici ve unutuculuğumuzu maalesef terketmemişizdir. İşte mağlûbiyet ve yıkım bizim için o zaman başlamıştır. Varlığın tâcı Efendimiz “Hâlisler büyük bir tehlike üzerindedirler!” buyurarak bu mevzudaki tehlikeye işaret etmişlerdi. “Devlet-i ebed müddet” gibi namlarla anılan devletimizin kudretine güvenerek düşmanı dâima küçümsedik. Halbuki düşmanın küçüğü yoktur. İnsanın en küçük düşmanı olan mikroplar, nice çınar gibi yiğitleri zamanla yere sermektedirler. Muhakkak ki; mikrobu mühimsemeyen bir bünye, ne kadar sağlam olursa olsun eninde sonunda hastalıktan korunamaz.",
      );
      expect(
        paragraphs[1].rawText,
        'Geçen asırda bu içten kemiren düşmanların gayretlerine yeni ve müthiş bir başka müessir eklendi: Dünyada süratle gerçekleşen “sanâyi inkılâbına” ayak uydurmak için zamanında ve gereği gibi harekete geçememekti! Burada böyle basit bir şekilde ifâde edilen bu hatanın',
      );
    });

    test('11. El-Ahkamu\'s-Sultaniyye Sayfa 23: Heals chapter headings, hğ->lığ, nm->nın, period-hyphens, and .> closing quote', () {
      const page23DirtyOcr = '''
BlRindİ BÖLÜH

Halife Tâyini Ve Hukûki Durumu A - HALIFENİN TÂYIN

Imâmet ismi verilen Hilâfet, Din ve Dünyâya âit islerin yürütümesi İçin Nübüvvete halef olarak konulmuş, kabûi edilmiş bir müessesedir. Devlet Başkanlığı vazifesini yürütene, sağırlar hariç bütün miüslüman topluluğunun uymasının gerektiği hususunda iemâ vâki omuştur. Dev. Let Başkanma uymanın bir akıl işi mi yokea dînin emri mi olduğu konusunda görüş ayrıhğı vardır.

a) Halifeye uymanm aklen vâcib olduğunu söyleyenlerin görüşü: Devlet Başkanına uyma, halkı kötülükten, zulümden uzaklaştırır, Hallfe taraflar arası düşmanıkları cözer, giderir. Bütün bunlar akılla düşü. nülebilen hususlardır. İdareciler olmasa halk son derece karişik, baya ğ1, zulümler içinde yüzen bir hayat içinde yaşar. Câhiliyet devri Arap Şâirlerinden El-Afuhu'l-Evdî siirinde, “İnsanların câhilleri idareci olduğunda, insanlar kötülüklerden, anar. şiden kurtulamıyacağı gibi sürûr ve rahathğı da bulamıyacaklardur.> der.
''';

      expect(OcrTextHealer.isDirtyEmbeddedOcrLayer(page23DirtyOcr), isTrue);

      final cleanText = EncodingNormalizer.cleanPunctuationSpacing(
        EncodingNormalizer.stripHeaderAndFooter(
          EncodingNormalizer.deHyphenate(page23DirtyOcr),
        ),
      );
      final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
      final paragraphs = TextSegmenter.segmentIntoParagraphs(pageResult.bodyText);

      expect(paragraphs.length, 5);
      expect(paragraphs[0].rawText, 'BİRİNCİ BÖLÜM');
      expect(paragraphs[0].isHeading, isTrue);
      expect(paragraphs[1].rawText, 'Halife Tâyini ve Hukûkî Durumu');
      expect(paragraphs[1].isHeading, isTrue);
      expect(paragraphs[2].rawText, 'A - HALİFENİN TÂYİNİ');
      expect(paragraphs[2].isHeading, isTrue);
      expect(
        paragraphs[3].rawText,
        'İmâmet ismi verilen Hilâfet, Din ve Dünyâya âit işlerin yürütülmesi için Nübüvvete halef olarak konulmuş, kabûl edilmiş bir müessesedir. Devlet Başkanlığı vazifesini yürütene, sağırlar hariç bütün müslüman topluluğunun uymasının gerektiği hususunda icmâ vâki olmuştur. Devlet Başkanına uymanın bir akıl işi mi yoksa dînin emri mi olduğu konusunda görüş ayrılığı vardır.',
      );
      expect(
        paragraphs[4].rawText,
        "a) Halifeye uymanın aklen vâcib olduğunu söyleyenlerin görüşü: Devlet Başkanına uyma, halkı kötülükten, zulümden uzaklaştırır, Halife taraflar arası düşmanlıkları çözer, giderir. Bütün bunlar akılla düşünülebilen hususlardır. İdareciler olmasa halk son derece karışık, bayağı, zulümler içinde yüzen bir hayat içinde yaşar. Câhiliyet devri Arap Şâirlerinden El-Afuhu'l-Evdî şiirinde, “İnsanların câhilleri idareci olduğunda, insanlar kötülüklerden, anarşiden kurtulamıyacağı gibi sürûr ve rahatlığı da bulamıyacaklardır.” der.",
      );
    });
  });
}


