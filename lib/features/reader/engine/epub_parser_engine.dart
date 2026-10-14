import 'dart:io';
import 'package:epubx/epubx.dart';
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

  Future<List<EpubParsedChapter>> parseEpub(String filePath) async {
    if (filePath.startsWith('sample://')) {
      return _generateSampleChapters();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return _generateSampleChapters();
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
            mergedFootnotes.add(PageFootnote(key: entry.key, content: entry.value.trim()));
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

      return chapters.isNotEmpty ? chapters : _generateSampleChapters();
    } catch (e) {
      return _generateSampleChapters();
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
      content = content.replaceFirst(RegExp(r'^\s*(\[\d{1,4}\]|\(\d{1,4}\)|\d{1,4}[.):\-—]?)\s*'), '').trim();
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
      return _generateSampleChapters();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      final sample = _generateSampleChapters();
      return [sample.first];
    }

    try {
      final rawContent = await file.readAsString();
      if (rawContent.trim().isEmpty) {
        final sample = _generateSampleChapters();
        return [sample.first];
      }

      final normalized = rawContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final globalFootnoteMap = TextSegmenter.extractFootnoteMapFromRawText(normalized);
      final headingRegex = RegExp(r'^(#{1,2})\s+(.+)$', multiLine: true);
      final chapters = <EpubParsedChapter>[];

      List<PageFootnote> buildMergedFootnotes(List<PageFootnote> localFootnotes) {
        final merged = <PageFootnote>[...localFootnotes];
        final keys = merged.map((f) => f.key).toSet();
        for (final entry in globalFootnoteMap.entries) {
          if (!keys.contains(entry.key) && entry.value.trim().isNotEmpty) {
            merged.add(PageFootnote(key: entry.key, content: entry.value.trim()));
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
          final paraWords = para.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          if (currentCharCount > 0 &&
              (currentCharCount + para.length > 1800 || currentWordCount + paraWords > 250)) {
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
      final sample = _generateSampleChapters();
      return [sample.first];
    } catch (_) {
      final sample = _generateSampleChapters();
      return [sample.first];
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

    return text;
  }

  List<EpubParsedChapter> _generateSampleChapters() {
    const text1 = '''
BÖLÜM 1: DİYAR-I RÛM'A SEYAHAT

1040 senesinde İstanbul'dan hareket edip Anadolu ve Rumeli diyarına revan olduk. Şehirler gördük ki her biri birer inci misali parıldar. [1]

Çarşıları mamur, kervansarayları nakış nakış işlenmiş, insanları ise misafirperver ve ilim ehlidir. Çeşmelerinden buz gibi sular akar, bağlarında bülbüller ötüşür. [*]
''';

    const text2 = '''
BÖLÜM 2: KALELER VE NAKŞİLER

Şehrin kalesi yedi burç üzerine bina olunmuş olup, surları göklere ser çekmiştir. İçerisinde sultanın sarayı ve ulemanın meclisleri yer alır. [2]

Akşam olduğunda kandiller yanar, şairler ve edipler toplanıp tahrir ve nazım meclisleri kurarlar.
''';

    const sampleFootnotes1 = [
      PageFootnote(
        key: '1',
        content: 'Evliyâ Çelebi, Seyahatnâme, 1. Cilt: Dersaadet\'ten Anadolu\'ya ilk çıkış menzilleri (H. 1040 / M. 1630).',
      ),
      PageFootnote(
        key: '*',
        content: 'Klasik Osmanlı şehirciliğinde külliye, bedesten ve su yolları vakıf nizamıyla idare olunurdu.',
      ),
    ];

    const sampleFootnotes2 = [
      PageFootnote(
        key: '2',
        content: 'Yedikule ve İç Kale tahkimatı; devrin tarihçileri tarafından "Sedd-i İskender" teşbihiyle tavsif edilmiştir.',
      ),
    ];

    return [
      EpubParsedChapter(
        title: 'Diyar-ı Rûm\'a Seyahat',
        content: text1,
        paragraphs: TextSegmenter.segmentIntoParagraphs(text1, pageFootnotes: sampleFootnotes1),
      ),
      EpubParsedChapter(
        title: 'Kaleler ve Nakşiler',
        content: text2,
        paragraphs: TextSegmenter.segmentIntoParagraphs(text2, pageFootnotes: sampleFootnotes2),
      ),
    ];
  }
}
