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

      for (final ch in flatChapters) {
        final rawHtml = ch.HtmlContent ?? '';
        final cleanText = _stripHtml(rawHtml);
        if (cleanText.isEmpty) continue;

        final paragraphs = TextSegmenter.segmentIntoParagraphs(cleanText);
        if (paragraphs.isEmpty) continue;

        final rawTitle = ch.Title?.trim() ?? '';
        chapters.add(EpubParsedChapter(
          title: rawTitle.isNotEmpty ? rawTitle : 'Bölüm ${chapters.length + 1}',
          content: cleanText,
          paragraphs: paragraphs,
        ));
      }

      return chapters.isNotEmpty ? chapters : _generateSampleChapters();
    } catch (e) {
      return _generateSampleChapters();
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
      final headingRegex = RegExp(r'^(#{1,2})\s+(.+)$', multiLine: true);
      final chapters = <EpubParsedChapter>[];

      if (headingRegex.hasMatch(normalized)) {
        final lines = normalized.split('\n');
        String? currentTitle;
        final buffer = StringBuffer();

        void flushSection() {
          final sectionRaw = buffer.toString().trim();
          buffer.clear();
          if (sectionRaw.isEmpty) return;

          final cleaned = _cleanMarkdownSymbols(sectionRaw);
          final paragraphs = TextSegmenter.segmentIntoParagraphs(cleaned);
          if (paragraphs.isEmpty) return;

          final activeTitle = currentTitle;
          chapters.add(EpubParsedChapter(
            title: (activeTitle != null && activeTitle.isNotEmpty)
                ? activeTitle
                : 'Bölüm ${chapters.length + 1}',
            content: cleaned,
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

          final paragraphs = TextSegmenter.segmentIntoParagraphs(chunkText);
          if (paragraphs.isEmpty) return;

          chapters.add(EpubParsedChapter(
            title: 'Bölüm ${chapters.length + 1}',
            content: chunkText,
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
        .replaceAll('*', '')
        .replaceAll('`', '')
        .trim();
  }

  String _stripHtml(String htmlString) {
    var text = htmlString
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    text = text.replaceAll(
      RegExp(
        r'</(p|div|h[1-6]|li|blockquote)>|<(br\s*/?|hr\s*/?)>',
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
    final text1 = '''
BÖLÜM 1: DİYAR-I RÛM'A SEYAHAT

1040 senesinde İstanbul'dan hareket edip Anadolu ve Rumeli diyarına revan olduk. Şehirler gördük ki her biri birer inci misali parıldar. [1]

Çarşıları mamur, kervansarayları nakış nakış işlenmiş, insanları ise misafirperver ve ilim ehlidir. Çeşmelerinden buz gibi sular akar, bağlarında bülbüller ötüşür. [*]
''';

    final text2 = '''
BÖLÜM 2: KALELER VE NAKŞİLER

Şehrin kalesi yedi burç üzerine bina olunmuş olup, surları göklere ser çekmiştir. İçerisinde sultanın sarayı ve ulemanın meclisleri yer alır. [2]

Akşam olduğunda kandiller yanar, şairler ve edipler toplanıp tahrir ve nazım meclisleri kurarlar.
''';

    return [
      EpubParsedChapter(
        title: 'Diyar-ı Rûm\'a Seyahat',
        content: text1,
        paragraphs: TextSegmenter.segmentIntoParagraphs(text1),
      ),
      EpubParsedChapter(
        title: 'Kaleler ve Nakşiler',
        content: text2,
        paragraphs: TextSegmenter.segmentIntoParagraphs(text2),
      ),
    ];
  }
}
