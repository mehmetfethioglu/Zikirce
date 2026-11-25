import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/content_block.dart';
import '../domain/reading_mode_hysteresis.dart';
import '../services/native_document_restorer.dart';
import 'ocr_proofreader_engine.dart';
import 'smart_reflow_pipeline.dart';
import 'text_segmenter.dart';

class ReflowPageData {
  final int pageNumber;
  final String rawText;
  final List<ParagraphSegment> paragraphs;
  final List<ContentBlock> contentBlocks;
  final List<PageFootnote> footnotes;
  final List<String> extractedImages;
  final bool hasTextContent;
  final bool isCoverOrImagePage;
  final bool hadCorruptedCalligraphy;
  final bool isOcrEnhanced;
  final bool hasNonLatinOrVisualWarning;
  final OcrPageReviewReport ocrReviewReport;
  final double ocrConfidence;
  final List<OcrWordBox> wordBoxes;
  final String? opticalAlphaMaskPath;
  final List<OpticalWordBlob> opticalWordBlobs;
  final int opticalImageWidth;
  final int opticalImageHeight;
  final double detectedSkewDeg;

  ReflowPageData({
    required this.pageNumber,
    required this.rawText,
    required this.paragraphs,
    this.contentBlocks = const [],
    this.footnotes = const [],
    this.extractedImages = const [],
    this.hasTextContent = true,
    this.isCoverOrImagePage = false,
    this.hadCorruptedCalligraphy = false,
    this.isOcrEnhanced = false,
    this.hasNonLatinOrVisualWarning = false,
    this.ocrReviewReport = const OcrPageReviewReport.empty(),
    this.ocrConfidence = 1.0,
    this.wordBoxes = const [],
    this.opticalAlphaMaskPath,
    this.opticalWordBlobs = const [],
    this.opticalImageWidth = 0,
    this.opticalImageHeight = 0,
    this.detectedSkewDeg = 0.0,
  });

  ReflowPageData copyWith({
    int? pageNumber,
    String? rawText,
    List<ParagraphSegment>? paragraphs,
    List<ContentBlock>? contentBlocks,
    List<PageFootnote>? footnotes,
    List<String>? extractedImages,
    bool? hasTextContent,
    bool? isCoverOrImagePage,
    bool? hadCorruptedCalligraphy,
    bool? isOcrEnhanced,
    bool? hasNonLatinOrVisualWarning,
    OcrPageReviewReport? ocrReviewReport,
    double? ocrConfidence,
    List<OcrWordBox>? wordBoxes,
    String? opticalAlphaMaskPath,
    List<OpticalWordBlob>? opticalWordBlobs,
    int? opticalImageWidth,
    int? opticalImageHeight,
    double? detectedSkewDeg,
  }) {
    return ReflowPageData(
      pageNumber: pageNumber ?? this.pageNumber,
      rawText: rawText ?? this.rawText,
      paragraphs: paragraphs ?? this.paragraphs,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      footnotes: footnotes ?? this.footnotes,
      extractedImages: extractedImages ?? this.extractedImages,
      hasTextContent: hasTextContent ?? this.hasTextContent,
      isCoverOrImagePage: isCoverOrImagePage ?? this.isCoverOrImagePage,
      hadCorruptedCalligraphy: hadCorruptedCalligraphy ?? this.hadCorruptedCalligraphy,
      isOcrEnhanced: isOcrEnhanced ?? this.isOcrEnhanced,
      hasNonLatinOrVisualWarning:
          hasNonLatinOrVisualWarning ?? this.hasNonLatinOrVisualWarning,
      ocrReviewReport: ocrReviewReport ?? this.ocrReviewReport,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      wordBoxes: wordBoxes ?? this.wordBoxes,
      opticalAlphaMaskPath: opticalAlphaMaskPath ?? this.opticalAlphaMaskPath,
      opticalWordBlobs: opticalWordBlobs ?? this.opticalWordBlobs,
      opticalImageWidth: opticalImageWidth ?? this.opticalImageWidth,
      opticalImageHeight: opticalImageHeight ?? this.opticalImageHeight,
      detectedSkewDeg: detectedSkewDeg ?? this.detectedSkewDeg,
    );
  }
}

class PdfReflowEngine {
  static const String _unreadablePageNotice =
      "Bu sayfanın dijital metin katmanı okunamadı. Üst bardaki 'PDF' sekmesinden orijinal sayfa görünümüne geçebilirsiniz.";

  final SmartReflowPipeline pipeline;

  const PdfReflowEngine({
    this.pipeline = const SmartReflowPipeline(),
  });

  /// PDF sayfasından akıllı metin, glif onarımı, 300 DPI kesit kırpıcı ve dipnotları ayrıştırır.
  Future<ReflowPageData> extractPage(String filePath, int pageIndex) async {
    // YALNIZCA sanal / örnek kitaplar (sample://) için yerleşik veri üret
    if (filePath.startsWith('sample://')) {
      return _generateSamplePage(filePath, pageIndex);
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return _buildUnreadablePageData(pageIndex);
    }

    try {
      // 1. Akıllı Hibrit Reflow & Snippet Pipeline'ını çalıştır
      final pipelineResult = await pipeline.processPageDetailed(
        filePath: filePath,
        pageIndex: pageIndex,
      );
      final contentBlocks = pipelineResult.blocks;
      final hasNonLatinWarning = pipelineResult.hasNonLatinOrVisualWarning;

      if (contentBlocks.isEmpty ||
          (contentBlocks.length == 1 &&
              contentBlocks.first is TextBlock &&
              (contentBlocks.first as TextBlock).text == _unreadablePageNotice)) {
        return _buildUnreadablePageData(pageIndex);
      }

      // 2. Geriye dönük uyumluluk için ParagraphSegment listesini türet
      final paragraphs = <ParagraphSegment>[];
      final extractedFootnotes = <PageFootnote>[];

      for (final block in contentBlocks) {
        switch (block) {
          case TextBlock():
            paragraphs.add(ParagraphSegment(
              rawText: block.text,
              isHeading: block.isHeading,
              isArabic: block.isArabic,
              footnoteAnchors: block.footnoteAnchors,
            ));
            for (final anchor in block.footnoteAnchors) {
              if (anchor.content != null &&
                  !extractedFootnotes.any((f) => f.key == anchor.key)) {
                extractedFootnotes.add(
                  PageFootnote(key: anchor.key, content: anchor.content!),
                );
              }
            }
          case InteractiveSnippetBlock():
            paragraphs.add(ParagraphSegment(
              rawText: block.fallbackText ?? block.title,
              isCalligraphyFallback: block.type == SnippetType.arabicCalligraphy,
              isImagePlaceholder: true,
              imagePath: block.croppedImagePath,
              imageBytes: block.rawBytes,
            ));
          case CalligraphyHeaderBlock():
            paragraphs.insert(0, ParagraphSegment(
              rawText: block.title,
              isHeading: true,
              isCalligraphyFallback: true,
              imagePath: block.croppedImagePath,
              imageBytes: block.rawBytes,
            ));
          case OpticalInkBlock():
            paragraphs.add(ParagraphSegment(
              rawText: block.fallbackText ?? block.title,
              isCalligraphyFallback: block.isArabic,
              isImagePlaceholder: true,
              imagePath: block.alphaMaskPath,
              imageBytes: block.rawAlphaMaskBytes,
            ));
        }
      }

      final hasText = contentBlocks.isNotEmpty;
      final isCoverOrImage = !hasText || (pageIndex == 0 && contentBlocks.length <= 1);

      // Ham metni birleştir
      final rawText = contentBlocks
          .whereType<TextBlock>()
          .map((t) => t.text)
          .join('\n\n');

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: rawText,
        paragraphs: paragraphs,
        contentBlocks: contentBlocks,
        footnotes: extractedFootnotes,
        hasTextContent: hasText,
        isCoverOrImagePage: isCoverOrImage,
        hadCorruptedCalligraphy:
            paragraphs.any((p) => p.isArabic || p.isCalligraphyFallback),
        isOcrEnhanced: true,
        hasNonLatinOrVisualWarning: hasNonLatinWarning,
        ocrReviewReport: pipelineResult.ocrReviewReport,
        ocrConfidence: pipelineResult.ocrConfidence,
        wordBoxes: pipelineResult.wordBoxes,
        opticalAlphaMaskPath: pipelineResult.opticalAlphaMaskPath,
        opticalWordBlobs: pipelineResult.opticalWordBlobs,
        opticalImageWidth: pipelineResult.opticalImageWidth,
        opticalImageHeight: pipelineResult.opticalImageHeight,
        detectedSkewDeg: pipelineResult.detectedSkewDeg,
      );
    } catch (e) {
      debugPrint('PdfReflowEngine extraction exception: $e');
      return _buildUnreadablePageData(pageIndex);
    }
  }

  ReflowPageData _buildUnreadablePageData(int pageIndex) {
    return ReflowPageData(
      pageNumber: pageIndex + 1,
      rawText: _unreadablePageNotice,
      paragraphs: [
        ParagraphSegment(
          rawText: _unreadablePageNotice,
        ),
      ],
      contentBlocks: const [
        TextBlock(
          text: _unreadablePageNotice,
        ),
      ],
      footnotes: const [],
      hasTextContent: false,
      isCoverOrImagePage: true,
    );
  }

  ReflowPageData _generateSamplePage(String identifier, int pageIndex) {
    final variant = pageIndex % 5;

    if (identifier.contains('adab') || identifier.contains('muaseret')) {
      final blocks = _buildAdabSampleBlocks(variant);
      final paragraphs = <ParagraphSegment>[];
      final footnotes = <PageFootnote>[];

      for (final b in blocks) {
        if (b is TextBlock) {
          paragraphs.add(ParagraphSegment(
            rawText: b.text,
            isHeading: b.isHeading,
            isArabic: b.isArabic,
            footnoteAnchors: b.footnoteAnchors,
          ));
          for (final a in b.footnoteAnchors) {
            if (a.content != null && !footnotes.any((f) => f.key == a.key)) {
              footnotes.add(PageFootnote(key: a.key, content: a.content!));
            }
          }
        }
      }

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: blocks.whereType<TextBlock>().map((b) => b.text).join('\n\n'),
        paragraphs: paragraphs,
        contentBlocks: blocks,
        footnotes: footnotes,
        hasTextContent: true,
        isCoverOrImagePage: false,
        hadCorruptedCalligraphy: false,
        isOcrEnhanced: true,
      );
    }

    if (identifier.contains('kutadgu_bilig')) {
      final pages = <({String content, List<PageFootnote> notes})>[
        (
          content: '''
BÖLÜM 1: KUT VE ADALET ÜZERİNE

Bayat atı birle sözüg başladım,
Törütgen igidgen keçürgen idim. [1]

Kişi gönlünü akıl ile süsler, aklı ise bilgi ile aydınlatır. Söz söyleyen insan akıllı olmalı, dinleyen insan ise anlayan ve tartan olmalı. Dünya mülkü geçicidir; kalıcı olan ise adalet ve doğruluk üzerine kurulmuş nizâmdır.

Beylik makamına oturan kişi gözünü adalet terazisinden ayırmamalıdır. Güneş gibi herkese eşit ışık vermeli, gece gibi kusurları örtmelidir. [2]

Akıl nerede olursa, orada ululuk olur; bilgi kimde bulunursa, o büyüklük kazanır.
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Kutadgu Bilig 1. Beyit: "Tanrı adıyla söze başladım; O yaratan, besleyen ve bağışlayan Rabbimdir."',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Kutadgu Bilig Adalet Temsili: Hükümdar Kün-Toğdı (Güneş Doğdu) adaleti ve kanunu simgeler.',
            ),
          ],
        ),
        (
          content: '''
BÖLÜM 2: BİLGİ VE AKLIN FAZİLETİ

Anlayış ve bilgi çok iyi şeydir; eğer bulursan onları kullan ve uçup göğe çık. [1]

Bilgisiz insan meyvesiz ağaca benzer; meyvesiz ağaca aç insan göz ucuyla bile bakmaz. Akıl karanlık gecede yanan bir meşaledir, bilgi ise insanı yükselten kanattır.

İnsan bilmediği şeyin düşmanıdır. Bilgi sahibi oldukça gönlü genişler, tevazu kazanır ve sözü hikmetle yoğrulur. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Yusuf Has Hacib, Kutadgu Bilig, Beyit 152: Bilginin insanı yücelten manevi mertebesi.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Ögdülmiş (Övülmüş): Eserde aklı ve ilmi temsil eden vezir karakteridir.',
            ),
          ],
        ),
        (
          content: '''
BÖLÜM 3: DİLİN EDEBİ VE SÖZÜN KIYMETİ

Anlayış ve bilgiye tercüman olan dildir; insanı aydınlatan açık dilin kıymetini bil. [1]

İnsanı dil kıymetlendirir ve insan onunla saadet bulur; insanı dil kıymetten düşürür ve insanın dili yüzünden başı gider. Sözünü bilerek söyle, az söyle ama öz söyle; bin kelimeyi bir nükteli sözde topla.

Söz ağızdan çıkana kadar senin esirindir; ağızdan çıktıktan sonra sen onun esiri olursun. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Kutadgu Bilig, 7. Bab: Dilin fazileti ve kusuru, söz söylemenin adabı.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Klasik Türk-İslam siyasetnamelerinde "hıfz-ı lisan" (dili koruma) ilkesi.',
            ),
          ],
        ),
        (
          content: '''
BÖLÜM 4: SAADET (AY-TOLDI) VE DEVLET NİZAMI

Saadet (Kut) doğan ay gibidir; önce küçüktür, günden güne büyür, dolunay olunca tekrar eksilmeye yüz tutar. [1]

Bu yüzden devlet ve nimete kavuşan kimse gurura kapılmamalı; elindeki imkânı hayırda, adalette ve halkın refahında kullanmalıdır. Bağışlayıcı ol, tuz-ekmek hakkını gözet ve iyilik tohumu ek.

Zulüm yanan ateştir, yaklaşanı yakar; kanun ise su gibidir, aktığı yerde hayat yeşertir. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Ay-Toldı (Dolunay): Kutadgu Bilig\'de ikbali, saadeti ve devlet nimetini temsil eder.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Beyit 2032: Töre ve adaletin su ile, zulmün ise ateş ile mukayesesi.',
            ),
          ],
        ),
        (
          content: '''
BÖLÜM 5: AKIBET (ODGURMIŞ) VE KANAAT HİKMETİ

Dünya bir kervansaraydır; gelen konar, konan göçer. Akıllı insan bu konakta ebedî kalacakmış gibi hırsa kapılmaz, yarın göçecekmiş gibi hazırlıklı yaşar. [1]

Kanaat tükenmez bir hazinedir. Gözü tok olanın gönlü sultan olur; hırs sahibinin ise dünyalar elinde olsa bile ruhu fakirdir.

İyilik et, iyilik bul; güzel ad bırak ki senden sonra hayırla yâd edilesin. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Odgurmış (Uyanmış): Eserde kanaati, tefekkürü ve akıbet bilincini temsil eden zahid.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Kutadgu Bilig Hatimesi: İnsanın fani ömürde baki bir güzel isim bırakması.',
            ),
          ],
        ),
      ];

      final selected = pages[variant];
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        selected.content,
        pageFootnotes: selected.notes,
      );
      final blocks = paragraphs
          .map(
            (p) => TextBlock(
              text: p.rawText,
              isHeading: p.isHeading,
              isArabic: p.isArabic,
              footnoteAnchors: p.footnoteAnchors,
            ),
          )
          .toList();

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: selected.content,
        paragraphs: paragraphs,
        contentBlocks: blocks,
        footnotes: selected.notes,
        hasTextContent: true,
        isCoverOrImagePage: false,
      );
    }

    if (identifier.contains('mukaddime')) {
      final pages = <({String content, List<PageFootnote> notes})>[
        (
          content: '''
FASIL 1: ÜMRAN İLMİ VE ASABİYET TEORİSİ

İnsan tabiatı icabı medenîdir; yani cemiyet hâlinde yaşamak zorundadır. [1] Filozoflar bu hakikati "insan tabiatı itibarıyla medenîdir" sözüyle ifade etmişlerdir ki bunun manası, insan için içtimaî hayatın (toplumsal yaşamın) zaruri oluşudur.

İbn Haldun'a göre tarih ilmi, zahirde geçmiş devletlerin ve kavimlerin haberlerinden ibaret görünse de batında (hakikatte) ince bir نظر (nazar), tahkik ve varlıkların sebeplerini araştırma ilmidir. Asabiyet bağı, göçebe (bedevî) toplulukların mülk ve devlet (hadarî medeniyet) kurmasındaki temel harçtır. [2]

Devletlerin de insanlar gibi doğal ömürleri vardır; kuruluş, yükseliş ve duraklama evrelerinden geçerler. Adalet mülkün temelidir; zulüm ise ümranın (medeniyetin) harap olmasına yol açar.
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'İbn Haldun, Mukaddime, Birinci Umran Kitabı: İnsanların yardımlaşma (teavün) ve şehirleşme zorunluluğu.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Asabiyet: Topluluğu birbirine kenetleyen dayanışma ruhu, müşterek gaye ve aidiyet şuuru.',
            ),
          ],
        ),
        (
          content: '''
FASIL 2: BEDEVÎ VE HADARÎ UMRANIN TABİATI

Toplumlar geçim tarzlarına ve yerleşim biçimlerine göre bedevî (kırsal/göçebe) ve hadarî (şehirli/yerleşik) olmak üzere iki ana safhaya ayrılır. [1] Bedevî yaşam zaruri ihtiyaçlarla yetinmeyi öğretirken, şehir hayatı sanatları, ilimleri ve refahı geliştirir.

Ancak aşırı refah ve konfor zamanla insanları rehavete sürükler, dayanışma ruhunu zayıflatır. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Mukaddime, 2. Bölüm: Bedevî umran hadarî umranın aslı ve öncüsüdür.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Hadaret (Şehir Medeniyeti): İlim ve sanatın kemal noktası olduğu kadar lüks ve israf imtihanıdır.',
            ),
          ],
        ),
        (
          content: '''
FASIL 3: İKLİM VE COĞRAFYANIN İNSAN MİZACINA TESİRİ

Yeryüzünün mutedil kuşaklarında yaşayan toplumlar, mimaride, ilimde ve devlet nizamında daha dengeli eserler ortaya koymuşlardır. [1] Hava, su ve coğrafi şartlar insanların yalnız bedenlerini değil, ahlak ve karakterlerini de şekillendirir.

Bolluk içinde yaşayanlarla zorlu doğa şartlarında mücadele edenlerin sabır ve tevekkül mertebeleri birbirinden farklıdır. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Mukaddime, Yedi İklim Teorisi: Dördüncü kuşağın medeniyet merkezleri üzerindeki etkisi.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Çevre ve iktisadi şartların beşerî psikolojiye doğrudan yansıması.',
            ),
          ],
        ),
        (
          content: '''
FASIL 4: İKTİSAT, EMEK VE DEĞER TEORİSİ

Kazanılan her malın ve servetin hakiki kaynağı insan emeğidir (sa'y ve amel). [1] Sanatlar ve meslekler ancak şehirlerdeki iş bölümü ve talep sayesinde tekâmül eder.

Devletin vergileri adaletli tutması üretimi teşvik eder; ağır vergiler ve mülkiyet emniyetsizliği ise ticareti kurutur ve hazineyi zayıflatır. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Mukaddime, 5. Bölüm: Emek-değer teorisinin klasik İslam iktisadındaki ilk sistemli izahı.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'İbn Haldun\'un ünlü vergi-gelir eğrisi: "Zulüm umranın yıkılışını haber verir."',
            ),
          ],
        ),
        (
          content: '''
FASIL 5: İLİMLERİN TASNİFİ VE TALİM METODU

İlim öğretmek bir sanattır (sınaat). [1] Öğrencinin zihnine konuları önce ana hatlarıyla (icmâlî), ardından kademe kademe derinleştirerek (tafsîlî) sunmak en sahih eğitim usulüdür.

Talebe üzerinde sertlik ve baskı kurmak zihni köreltir, şevki kırar ve insanı tembelliğe sevk eder. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content:
                  'Mukaddime, 6. Bölüm: Tedrisatta tedricilik (kademeli öğretim) ilkesi.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'İbn Haldun Pedagojisi: "Eğitimde şiddet öğrencinin ruh genişliğini ve özgüvenini yok eder."',
            ),
          ],
        ),
      ];

      final selected = pages[variant];
      final paragraphs = TextSegmenter.segmentIntoParagraphs(
        selected.content,
        pageFootnotes: selected.notes,
      );
      final blocks = paragraphs
          .map(
            (p) => TextBlock(
              text: p.rawText,
              isHeading: p.isHeading,
              isArabic: p.isArabic,
              footnoteAnchors: p.footnoteAnchors,
            ),
          )
          .toList();

      return ReflowPageData(
        pageNumber: pageIndex + 1,
        rawText: selected.content,
        paragraphs: paragraphs,
        contentBlocks: blocks,
        footnotes: selected.notes,
        hasTextContent: true,
        isCoverOrImagePage: false,
        isOcrEnhanced: true,
      );
    }

    final seyahatPages = <({String content, List<PageFootnote> notes})>[
      (
        content: '''
BÖLÜM 1: DERSAADET'TEN ANADOLU'YA SEYAHAT

1040 senesinde İstanbul'dan hareket edip Anadolu ve Rumeli diyarına revan olduk. Şehirler gördük ki her biri birer inci misali parıldar. [1]

Çarşıları mamur, kervansarayları nakış nakış işlenmiş, insanları ise misafirperver ve ilim ehlidir. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Evliyâ Çelebi, Seyahatnâme, 1. Cilt: Dersaadet\'ten Anadolu\'ya ilk çıkış menzilleri.',
          ),
          PageFootnote(
            key: '*',
            content:
                'Klasik Osmanlı şehirciliğinde külliye, bedesten ve su yolları vakıf nizamıyla idare olunurdu.',
          ),
        ],
      ),
      (
        content: '''
BÖLÜM 2: BURSA VE ULUDAĞ'IN AB-I HAYATI

Bursa ruhaniyetli bir belde-i tayyibedir ki Ulu Camii'nin yirmi kubbesi altında kırk çeşmeli şadırvanı gece gündüz çağlar. [1]

Keşiş Dağı'ndan (Uludağ) inen buz gibi pınarlar şehrin üç yüz altmış mahallesine hayat bahşeder. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 2. Cilt: Bursa Ulu Camii\'nin hat levhaları ve mimari letafeti.',
          ),
          PageFootnote(
            key: '*',
            content:
                'Evliyâ Çelebi Bursa\'yı "Veliler ve Pınarlar Şehri" olarak tavsif eder.',
          ),
        ],
      ),
      (
        content: '''
BÖLÜM 3: EDİRNE VE MİMAR SİNAN'IN ŞAHESERİ

Edirne'ye vardığımızda uzaktan Selimiye'nin dört zarif minaresi gökyüzüne yükselen birer kalem gibi göründü. [1]

Koca Mimar Sinan kubbeyi öyle bir vüs'at ve hendese ile kurmuştur ki altında duran insanın gönlüne ferahlık dolar. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 3. Cilt: Selimiye Camii\'nin kubbe açıklığı ve üç şerefeli minare yolları.',
          ),
          PageFootnote(
            key: '*',
            content:
                'Mimar Sinan\'ın "Ustalık Eserim" dediği Selimiye külliyesi.',
          ),
        ],
      ),
      (
        content: '''
BÖLÜM 4: AMASYA VE ŞEHZADELER DİYARI

Yeşilırmak kenarına dizilmiş yalıboyu konaklarıyla Amasya, ilim ve hattatlar ocağıdır. [1]

Şeyh Hamdullah gibi hat üstatlarının yetiştiği bu şehirde medrese talebeleri sabah seherinde ders halkaları kurar. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Amasya: Klasik dönemde Osmanlı şehzadelerinin sancak ve ilim merkezi.',
          ),
          PageFootnote(
            key: '*',
            content:
                'Şeyh Hamdullah (1436-1520): Türk hat sanatında "Kıbletü\'l-Küttâb" unvanıyla anılır.',
          ),
        ],
      ),
      (
        content: '''
BÖLÜM 5: MOSTAR KÖPRÜSÜ VE BALKAN MENZİLLERİ

Neretva Nehri üzerinde yükselen Mostar Köprüsü, sanki gökyüzündeki samanyolu kuşağı gibi iki yakayı tek bir taş kemerle birleştirir. [1]

Gezdiğimiz her beldede gördük ki insanı yaşatan adalet, şehri yaşatan ise vakıf ve irfandır. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 6. Cilt: Mimar Hayreddin tarafından 1566\'da inşa edilen Mostar Köprüsü.',
          ),
          PageFootnote(
            key: '*',
            content:
                'Evliyâ Çelebi\'nin kırk yılı aşan seyahatlerinin hülasası.',
          ),
        ],
      ),
    ];

    final selected = seyahatPages[variant];
    final paragraphs = TextSegmenter.segmentIntoParagraphs(
      selected.content,
      pageFootnotes: selected.notes,
    );
    final blocks = paragraphs
        .map(
          (p) => TextBlock(
            text: p.rawText,
            isHeading: p.isHeading,
            isArabic: p.isArabic,
            footnoteAnchors: p.footnoteAnchors,
          ),
        )
        .toList();

    return ReflowPageData(
      pageNumber: pageIndex + 1,
      rawText: selected.content,
      paragraphs: paragraphs,
      contentBlocks: blocks,
      footnotes: selected.notes,
      hasTextContent: true,
      isCoverOrImagePage: false,
    );
  }

  List<ContentBlock> _buildAdabSampleBlocks(int variant) {
    switch (variant) {
      case 0:
        return [
          const TextBlock(
            text: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Eve girip çıkarken kapıyı sert bir şekilde kapatma veya kapıyı şiddetli kapanacak şekilde bırakma! Çünkü bu davranış, müntesibi olmakla şeref duyduğumuz İslam nezaketine aykırıdır. Bilakis kapıyı elinle yavaş bir şekilde kapat! Umulur ki sen Âişe (radıyallâhu \'anhâ) validemizin Resûlullah (sallallâhu \'aleyhi ve sellem)\'den rivayet ettiği şu Hadîs-i Şerîfi duymuşsundur:',
          ),
          const TextBlock(
            text:
                'إِنَّ الرِّفْقَ لَا يَكُونُ فِي شَيْءٍ إِلَّا زَانَهُ، وَلَا يُنْزَعُ مِنْ شَيْءٍ إِلَّا شَانَهُ',
            isArabic: true,
          ),
          const TextBlock(
            text:
                '“Muhakkak ki yumuşaklık (kibarlık) bulunduğu şeyi güzelleştirir. Bir şeyden yumuşaklığı alındığı zaman da bu alınma o şeyi çirkinleştirir.”¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 133,
                content:
                    'Sahih-i Müslim, Kitabu\'l-Birr, Sıla ve Âdab, c.4, s.2004, Hadis No:2594',
              ),
            ],
          ),
        ];
      case 1:
        return [
          const TextBlock(
            text: 'Eve Girerken İzin İstemek ve Selam Vermek',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Bir kimsenin kendi hanesine veya bir dostunun meclisine girerken önce tatlı bir sesle selam vermesi ve izin istemesi İslam âdâbının en zarif esaslarındandır. Selam, gönüller arasındaki ülfet kapısını açan ilk anahtardır.',
          ),
          const TextBlock(
            text:
                'فَإِذَا دَخَلْتُمْ بُيُوتًا فَسَلِّمُوا عَلَى أَنْفُسِكُمْ تَحِيَّةً مِنْ عِنْدِ اللَّهِ مُبَارَكَةً طَيِّبَةً',
            isArabic: true,
          ),
          const TextBlock(
            text:
                '“Evlere girdiğiniz zaman birbirinize, Allah katından mübarek ve hoş bir esenlik dileği olarak selam verin.”¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 105,
                content: 'Nûr Sûresi, 61. Âyet-i Kerîme.',
              ),
            ],
          ),
        ];
      case 2:
        return [
          const TextBlock(
            text: 'Mecliste Oturuş ve Söz Dinleme Edebî',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'İlim ve sohbet meclislerinde konuşanın sözünü kesmemek, muhatabın yüzüne vakar ve tebessümle bakmak kâmil müminin şiarıdır. Bir sözü daha önce bilmiş olsan dahi ilk kez duyuyormuş gibi nezaketle dinlemek edeptendir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 221,
                content:
                    'Ata bin Ebî Rebah: "Bir genç bana bir hadis anlatır, ben onu kendisi doğmadan önce işitmişimdir; yine de ilk defa duyuyormuş gibi dinlerim."',
              ),
            ],
          ),
        ];
      case 3:
        return [
          const TextBlock(
            text: 'Ziyaret Vakitlerine Riayet ve Misafirperverlik',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Dost ziyareti muhabbeti artırır; ancak ziyaretin vakti ve süresi ev sahibine ağırlık vermeyecek ölçüde olmalıdır. İstirahat saatlerinde kapı çalmamak, misafiri güler yüzle karşılayıp uğurlamak sünnet-i seniyyedendir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 226,
                content:
                    'İbn Hacer el-Askalânî, Fethu\'l-Bârî, İsti\'zân Kitabı: Ziyaretlerde vakit ve hâl gözetimi.',
              ),
            ],
          ),
        ];
      default:
        return [
          const TextBlock(
            text: 'Büyüklere Hürmet ve Küçüklere Şefkat',
            isHeading: true,
          ),
          const TextBlock(
            text:
                'Toplumun nizamı ve huzuru, büyüklerin vakarına hürmet göstermek ve küçüklerin kalbine şefkatle dokunmakla kaimdir. Sözde, yürüyüşte ve ikramda önceliği ilim ve yaşça büyüklere vermek zarafetin zirvesidir.¹',
            footnoteAnchors: [
              FootnoteAnchor(
                key: '1',
                indexInText: 215,
                content:
                    'Ebû Dâvûd, Edeb 58, Hadis No: 4943: "Küçüklerimize merhamet etmeyen, büyüklerimizin şerefini tanımayan bizden değildir."',
              ),
            ],
          ),
        ];
    }
  }
}
