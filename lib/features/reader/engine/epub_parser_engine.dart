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

      final spine = book.Chapters ?? [];
      for (final ch in spine) {
        final rawHtml = ch.HtmlContent ?? '';
        final cleanText = _stripHtml(rawHtml);
        final paragraphs = TextSegmenter.segmentIntoParagraphs(cleanText);

        chapters.add(EpubParsedChapter(
          title: ch.Title ?? 'Bölüm ${chapters.length + 1}',
          content: cleanText,
          paragraphs: paragraphs,
        ));
      }

      return chapters.isNotEmpty ? chapters : _generateSampleChapters();
    } catch (e) {
      return _generateSampleChapters();
    }
  }

  String _stripHtml(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
