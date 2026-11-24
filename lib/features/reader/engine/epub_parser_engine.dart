import 'dart:io';
import 'package:epubx/epubx.dart';
import 'encoding_normalizer.dart';
import 'text_segmenter.dart';

class EpubParsedChapter {
  final String title;
  final String content;
  final List<ParagraphSegment> paragraphs;

  EpubParsedChapter({
    required this.title,
    required this.content,
    required this.paragraphs,
  });
}

class EpubParserEngine {
  const EpubParserEngine();

  List<EpubParsedChapter> _buildEpubWarningChapters() {
    const warningTitle = 'EPUB Okuma Uyarısı';
    const warningContent =
        'Bu EPUB dosyası okunamadı veya DRM korumalı. Lütfen dosyanın bozuk olmadığından emin olun.';
    return [
      EpubParsedChapter(
        title: warningTitle,
        content: warningContent,
        paragraphs: [
          ParagraphSegment(rawText: warningTitle, isHeading: true),
          ParagraphSegment(rawText: warningContent),
        ],
      ),
    ];
  }

  Future<List<EpubParsedChapter>> parseEpub(String filePath) async {
    if (filePath.startsWith('sample://')) {
      return _generateSampleChapters(filePath);
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return _buildEpubWarningChapters();
    }

    try {
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapters = <EpubParsedChapter>[];

      final flatChapters = <EpubChapter>[];
      _collectChapters(book.Chapters, flatChapters);

      // 1. Kitap genelindeki tüm HTML dosyalarından ve bölümlerden dipnot havuzunu (bölüm sonu / kitap sonu / HTML id) topla
      final globalFootnoteMap = <String, String>{};
      final htmlFiles = book.Content?.Html;
      if (htmlFiles != null) {
        for (final htmlFile in htmlFiles.values) {
          final rawHtml = htmlFile.Content ?? '';
          if (rawHtml.isEmpty) continue;
          _extractHtmlFootnotes(rawHtml, globalFootnoteMap);
          final stripped = _stripHtml(rawHtml);
          final map = TextSegmenter.extractFootnoteMapFromRawText(stripped);
          for (final entry in map.entries) {
            globalFootnoteMap.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }

      for (final ch in flatChapters) {
        final rawHtml = ch.HtmlContent ?? '';
        if (rawHtml.isEmpty) continue;
        _extractHtmlFootnotes(rawHtml, globalFootnoteMap);
        final stripped = _stripHtml(rawHtml);
        final map = TextSegmenter.extractFootnoteMapFromRawText(stripped);
        for (final entry in map.entries) {
          globalFootnoteMap.putIfAbsent(entry.key, () => entry.value);
        }
      }

      // 2. Bölümleri ayrıştır ve dipnotları paragraf çapalarıyla eşleştir
      for (final ch in flatChapters) {
        final rawHtml = ch.HtmlContent ?? '';
        final cleanText = _stripHtml(rawHtml);
        if (cleanText.isEmpty) continue;

        final pageResult = TextSegmenter.extractFootnotesAndBody(cleanText);
        final mergedFootnotes = <PageFootnote>[...pageResult.footnotes];
        final existingKeys = mergedFootnotes.map((f) => f.key).toSet();
        for (final entry in globalFootnoteMap.entries) {
          if (!existingKeys.contains(entry.key) && entry.value.trim().isNotEmpty) {
            mergedFootnotes.add(
              PageFootnote(key: entry.key, content: entry.value.trim()),
            );
            existingKeys.add(entry.key);
          }
        }

        final paragraphs = TextSegmenter.segmentIntoParagraphs(
          pageResult.bodyText,
          pageFootnotes: mergedFootnotes,
          hadCorruptedCalligraphy: pageResult.hadCorruptedCalligraphy,
        );
        if (paragraphs.isEmpty) continue;

        final rawTitle = ch.Title?.trim() ?? '';
        chapters.add(EpubParsedChapter(
          title: rawTitle.isNotEmpty ? rawTitle : 'Bölüm ${chapters.length + 1}',
          content: pageResult.bodyText,
          paragraphs: paragraphs,
        ));
      }

      return chapters.isNotEmpty ? chapters : _buildEpubWarningChapters();
    } catch (e) {
      return _buildEpubWarningChapters();
    }
  }

  /// EPUB HTML içerisindeki `<aside epub:type="footnote">`, `<div id="fn9">`, `<p id="footnote-9">`, `<li id="fn9">` yapılarını yakalar
  void _extractHtmlFootnotes(String rawHtml, Map<String, String> targetMap) {
    // 1. id="fn9", id="footnote9", id="note-9" vb. blok etiketleri
    final idBlockRegex = RegExp(
      r'<(?:p|div|li|aside|dd)[^>]*\bid=["\x27](?:fn|footnote|note|endnote|dipnot)[_\-:]?(\d{1,4})["\x27][^>]*>([\s\S]*?)<\/(?:p|div|li|aside|dd)>',
      caseSensitive: false,
    );
    for (final m in idBlockRegex.allMatches(rawHtml)) {
      final key = m.group(1)!.trim();
      var content = _stripHtml(m.group(2)!);
      content = content
          .replaceFirst(
            RegExp(r'^\s*(\[\d{1,4}\]|\(\d{1,4}\)|\d{1,4}[.):\-—]?)\s*'),
            '',
          )
          .trim();
      if (key.isNotEmpty && content.length >= 4) {
        targetMap.putIfAbsent(key, () => content);
      }
    }

    // 2. <a href="...">[9]</a> Müslim, İlim 16... şeklinde paragraf içi HTML dipnot tanımları
    final anchorDefRegex = RegExp(
      r'<(?:p|div|li)[^>]*>\s*(?:<a[^>]*>\s*)?\[(\d{1,4})\](?:\s*<\/a>)?\s*([\s\S]*?)<\/(?:p|div|li)>',
      caseSensitive: false,
    );
    for (final m in anchorDefRegex.allMatches(rawHtml)) {
      final key = m.group(1)!.trim();
      final content = _stripHtml(m.group(2)!).trim();
      if (key.isNotEmpty && content.length >= 4) {
        targetMap.putIfAbsent(key, () => content);
      }
    }
  }

  void _collectChapters(
    List<EpubChapter>? source,
    List<EpubChapter> accumulator,
  ) {
    if (source == null || source.isEmpty) return;
    for (final ch in source) {
      accumulator.add(ch);
      final sub = ch.SubChapters;
      if (sub != null && sub.isNotEmpty) {
        _collectChapters(sub, accumulator);
      }
    }
  }

  Future<List<EpubParsedChapter>> parseMarkdownOrTxt(String filePath) async {
    if (filePath.startsWith('sample://')) {
      return _generateSampleChapters(filePath);
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return _buildEpubWarningChapters();
    }

    try {
      final rawContent = await file.readAsString();
      if (rawContent.trim().isEmpty) {
        return _buildEpubWarningChapters();
      }

      final normalized = EncodingNormalizer.normalizeEncodings(
        rawContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      );
      final globalFootnoteMap =
          TextSegmenter.extractFootnoteMapFromRawText(normalized);
      final headingRegex = RegExp(r'^(#{1,2})\s+(.+)$', multiLine: true);
      final chapters = <EpubParsedChapter>[];

      List<PageFootnote> buildMergedFootnotes(List<PageFootnote> localFootnotes) {
        final merged = <PageFootnote>[...localFootnotes];
        final keys = merged.map((f) => f.key).toSet();
        for (final entry in globalFootnoteMap.entries) {
          if (!keys.contains(entry.key) && entry.value.trim().isNotEmpty) {
            merged.add(
              PageFootnote(key: entry.key, content: entry.value.trim()),
            );
            keys.add(entry.key);
          }
        }
        return merged;
      }

      if (headingRegex.hasMatch(normalized)) {
        final lines = normalized.split('\n');
        String? currentTitle;
        final buffer = StringBuffer();

        void flushSection() {
          final sectionRaw = buffer.toString().trim();
          buffer.clear();
          if (sectionRaw.isEmpty) return;

          final cleaned = _cleanMarkdownSymbols(sectionRaw);
          final pageResult = TextSegmenter.extractFootnotesAndBody(cleaned);
          final paragraphs = TextSegmenter.segmentIntoParagraphs(
            pageResult.bodyText,
            pageFootnotes: buildMergedFootnotes(pageResult.footnotes),
            hadCorruptedCalligraphy: pageResult.hadCorruptedCalligraphy,
          );
          if (paragraphs.isEmpty) return;

          final activeTitle = currentTitle;
          chapters.add(EpubParsedChapter(
            title: (activeTitle != null && activeTitle.isNotEmpty)
                ? activeTitle
                : 'Bölüm ${chapters.length + 1}',
            content: pageResult.bodyText,
            paragraphs: paragraphs,
          ));
        }

        for (final line in lines) {
          final match = RegExp(r'^(#{1,2})\s+(.+)$').firstMatch(line.trim());
          if (match != null) {
            flushSection();
            currentTitle = _cleanMarkdownSymbols(match.group(2)!.trim());
            buffer.writeln(currentTitle);
            buffer.writeln();
          } else {
            buffer.writeln(line);
          }
        }
        flushSection();
      } else {
        final rawParagraphs = normalized
            .split(RegExp(r'\n\s*\n'))
            .map((p) => _cleanMarkdownSymbols(p.trim()))
            .where((p) => p.isNotEmpty)
            .toList();

        final chunkBuffer = StringBuffer();
        int currentCharCount = 0;
        int currentWordCount = 0;

        void flushChunk() {
          final chunkText = chunkBuffer.toString().trim();
          chunkBuffer.clear();
          currentCharCount = 0;
          currentWordCount = 0;
          if (chunkText.isEmpty) return;

          final pageResult = TextSegmenter.extractFootnotesAndBody(chunkText);
          final paragraphs = TextSegmenter.segmentIntoParagraphs(
            pageResult.bodyText,
            pageFootnotes: buildMergedFootnotes(pageResult.footnotes),
            hadCorruptedCalligraphy: pageResult.hadCorruptedCalligraphy,
          );
          if (paragraphs.isEmpty) return;

          chapters.add(EpubParsedChapter(
            title: 'Bölüm ${chapters.length + 1}',
            content: pageResult.bodyText,
            paragraphs: paragraphs,
          ));
        }

        for (final para in rawParagraphs) {
          final paraWords =
              para.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          if (currentCharCount > 0 &&
              (currentCharCount + para.length > 1800 ||
                  currentWordCount + paraWords > 250)) {
            flushChunk();
          }
          if (chunkBuffer.isNotEmpty) {
            chunkBuffer.write('\n\n');
          }
          chunkBuffer.write(para);
          currentCharCount += para.length;
          currentWordCount += paraWords;
        }
        flushChunk();
      }

      if (chapters.isNotEmpty) {
        return chapters;
      }
      return _buildEpubWarningChapters();
    } catch (_) {
      return _buildEpubWarningChapters();
    }
  }

  String _cleanMarkdownSymbols(String input) {
    return input
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'(?<!\[)\*(?!\])'), '')
        .replaceAll('`', '')
        .trim();
  }

  String _stripHtml(String htmlString) {
    var text = htmlString
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    text = text.replaceAll(
      RegExp(
        r'</(p|div|h[1-6]|li|blockquote|aside)>|<(br\s*/?|hr\s*/?)>',
        caseSensitive: false,
      ),
      '\n\n',
    );

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'");

    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text.replaceAll(RegExp(r'\[\s*(\d{1,4}|\*|\†)\s*\]'), r'[$1]');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return EncodingNormalizer.normalizeEncodings(text);
  }

  List<EpubParsedChapter> _generateSampleChapters([String identifier = 'sample://seyahatname']) {
    if (identifier.contains('kutadgu_bilig')) {
      final kutadguSections = <({String title, String content, List<PageFootnote> notes})>[
        (
          title: 'Bölüm 1: Kut ve Adalet Üzerine',
          content: '''
BÖLÜM 1: KUT VE ADALET ÜZERİNE

Bayat atı birle sözüg başladım,
Törütgen igidgen keçürgen idim. [1]

Kişi gönlünü akıl ile süsler, aklı ise bilgi ile aydınlatır. Söz söyleyen insan akıllı olmalı, dinleyen insan ise anlayan ve tartan olmalı. Dünya mülkü geçicidir; kalıcı olan ise adalet ve doğruluk üzerine kurulmuş nizâmdır.

Beylik makamına oturan kişi gözünü adalet terazisinden ayırmamalıdır. Güneş gibi herkese eşit ışık vermeli, gece gibi kusurları örtmelidir. [2]
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
          title: 'Bölüm 2: Bilgi ve Aklın Fazileti',
          content: '''
BÖLÜM 2: BİLGİ VE AKLIN FAZİLETİ

Anlayış ve bilgi çok iyi şeydir; eğer bulursan onları kullan ve uçup göğe çık. [1]

Bilgisiz insan meyvesiz ağaca benzer; meyvesiz ağaca aç insan göz ucuyla bile bakmaz. Akıl karanlık gecede yanan bir meşaledir, bilgi ise insanı yükselten kanattır. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content: 'Yusuf Has Hacib, Kutadgu Bilig, Beyit 152.',
            ),
            PageFootnote(
              key: '2',
              content:
                  'Ögdülmiş (Övülmüş): Eserde aklı ve ilmi temsil eden vezir karakteridir.',
            ),
          ],
        ),
        (
          title: 'Bölüm 3: Dilin Edebi ve Sözün Kıymeti',
          content: '''
BÖLÜM 3: DİLİN EDEBİ VE SÖZÜN KIYMETİ

Anlayış ve bilgiye tercüman olan dildir; insanı aydınlatan açık dilin kıymetini bil. [1]

İnsanı dil kıymetlendirir ve insan onunla saadet bulur; sözünü bilerek söyle, az söyle ama öz söyle; bin kelimeyi bir nükteli sözde topla. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content: 'Kutadgu Bilig, 7. Bab: Dilin fazileti ve söz söylemenin adabı.',
            ),
            PageFootnote(
              key: '2',
              content: 'Söz ağızdan çıkana kadar senin esirindir; çıktıktan sonra sen onun esiri olursun.',
            ),
          ],
        ),
        (
          title: 'Bölüm 4: Saadet (Ay-Toldı) ve Devlet Nizamı',
          content: '''
BÖLÜM 4: SAADET (AY-TOLDI) VE DEVLET NİZAMI

Saadet (Kut) doğan ay gibidir; önce küçüktür, günden güne büyür, dolunay olunca tekrar eksilmeye yüz tutar. [1]

Zulüm yanan ateştir, yaklaşanı yakar; kanun ise su gibidir, aktığı yerde hayat yeşertir. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content: 'Ay-Toldı (Dolunay): İkbali ve devlet nimetini temsil eder.',
            ),
            PageFootnote(
              key: '2',
              content: 'Beyit 2032: Töre ve adaletin su ile mukayesesi.',
            ),
          ],
        ),
        (
          title: 'Bölüm 5: Akıbet (Odgurmış) ve Kanaat Hikmeti',
          content: '''
BÖLÜM 5: AKIBET (ODGURMIŞ) VE KANAAT HİKMETİ

Dünya bir kervansaraydır; gelen konar, konan göçer. Akıllı insan bu konakta ebedî kalacakmış gibi hırsa kapılmaz, yarın göçecekmiş gibi hazırlıklı yaşar. [1]

Kanaat tükenmez bir hazinedir. İyilik et, iyilik bul; güzel ad bırak ki senden sonra hayırla yâd edilesin. [2]
''',
          notes: const [
            PageFootnote(
              key: '1',
              content: 'Odgurmış (Uyanmış): Kanaat ve tefekkürü temsil eden zahid.',
            ),
            PageFootnote(
              key: '2',
              content: 'Kutadgu Bilig Hatimesi: Baki kubbede hoş bir sada bırakmak.',
            ),
          ],
        ),
      ];

      return kutadguSections
          .map(
            (s) => EpubParsedChapter(
              title: s.title,
              content: s.content,
              paragraphs: TextSegmenter.segmentIntoParagraphs(
                s.content,
                pageFootnotes: s.notes,
              ),
            ),
          )
          .toList();
    }

    final seyahatSections = <({String title, String content, List<PageFootnote> notes})>[
      (
        title: 'Diyar-ı Rûm\'a Seyahat',
        content: '''
BÖLÜM 1: DİYAR-I RÛM'A SEYAHAT

1040 senesinde İstanbul'dan hareket edip Anadolu ve Rumeli diyarına revan olduk. Şehirler gördük ki her biri birer inci misali parıldar. [1]

Çarşıları mamur, kervansarayları nakış nakış işlenmiş, insanları ise misafirperver ve ilim ehlidir. Çeşmelerinden buz gibi sular akar, bağlarında bülbüller ötüşür. [*]
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Evliyâ Çelebi, Seyahatnâme, 1. Cilt: Dersaadet\'ten Anadolu\'ya ilk çıkış menzilleri (H. 1040 / M. 1630).',
          ),
          PageFootnote(
            key: '*',
            content:
                'Klasik Osmanlı şehirciliğinde külliye, bedesten ve su yolları vakıf nizamıyla idare olunurdu.',
          ),
        ],
      ),
      (
        title: 'Kaleler ve Nakşiler',
        content: '''
BÖLÜM 2: KALELER VE NAKŞİLER

Şehrin kalesi yedi burç üzerine bina olunmuş olup, surları göklere ser çekmiştir. İçerisinde sultanın sarayı ve ulemanın meclisleri yer alır. [2]

Akşam olduğunda kandiller yanar, şairler ve edipler toplanıp tahrir ve nazım meclisleri kurarlar.
''',
        notes: const [
          PageFootnote(
            key: '2',
            content:
                'Yedikule ve İç Kale tahkimatı; devrin tarihçileri tarafından "Sedd-i İskender" teşbihiyle tavsif edilmiştir.',
          ),
        ],
      ),
      (
        title: 'Bursa ve Uludağ\'ın Pınarları',
        content: '''
BÖLÜM 3: BURSA VE ULUDAĞ'IN PINARLARI

Bursa ruhaniyetli bir belde-i tayyibedir ki Ulu Camii'nin yirmi kubbesi altında kırk çeşmeli şadırvanı gece gündüz çağlar. [1]

Keşiş Dağı'ndan inen pınarlar şehrin mahallelerine hayat bahşeder, çarşılarında ipek dokuyan esnaf dua ile kepenk açar.
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 2. Cilt: Bursa Ulu Camii\'nin hat levhaları ve mimari letafeti.',
          ),
        ],
      ),
      (
        title: 'Edirne ve Selimiye Külliyesi',
        content: '''
BÖLÜM 4: EDİRNE VE SELİMİYE KÜLLİYESİ

Edirne'ye vardığımızda uzaktan Selimiye'nin dört zarif minaresi gökyüzüne yükselen birer kalem gibi göründü. [1]

Koca Mimar Sinan kubbeyi öyle bir hendese ile kurmuştur ki altında duran insanın gönlüne ferahlık ve huşû dolar.
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 3. Cilt: Mimar Sinan\'ın ustalık eseri Selimiye Camii\'nin tavsifi.',
          ),
        ],
      ),
      (
        title: 'Mostar Köprüsü ve Balkan Menzilleri',
        content: '''
BÖLÜM 5: MOSTAR KÖPRÜSÜ VE BALKAN MENZİLLERİ

Neretva Nehri üzerinde yükselen Mostar Köprüsü, sanki gökyüzündeki samanyolu kuşağı gibi iki yakayı tek bir taş kemerle birleştirir. [1]

Gezdiğimiz her beldede gördük ki insanı yaşatan adalet, şehri yaşatan ise vakıf ve irfandır.
''',
        notes: const [
          PageFootnote(
            key: '1',
            content:
                'Seyahatnâme, 6. Cilt: Mimar Hayreddin tarafından 1566\'da inşa edilen Mostar Köprüsü.',
          ),
        ],
      ),
    ];

    return seyahatSections
        .map(
          (s) => EpubParsedChapter(
            title: s.title,
            content: s.content,
            paragraphs: TextSegmenter.segmentIntoParagraphs(
              s.content,
              pageFootnotes: s.notes,
            ),
          ),
        )
        .toList();
  }
}
