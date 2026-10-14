import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/core/errors/app_error.dart';
import 'package:tahrir/core/services/changelog_service.dart';
import 'package:tahrir/features/marginalia/services/dictionary_service.dart';
import 'package:tahrir/features/reader/engine/epub_parser_engine.dart';
import 'package:tahrir/features/reader/engine/pdf_reflow_engine.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';
import 'package:tahrir/features/reader/services/offline_ai_service.dart';

void main() {
  group('Tahrir Unit & Smoke Tests', () {
    test('TextSegmenter deHyphenate removes line-break hyphens correctly', () {
      const sample = 'Tahrir ile yapılan tahrir-\nler zihni açar.';
      final cleaned = TextSegmenter.deHyphenate(sample);
      expect(cleaned, equals('Tahrir ile yapılan tahrirler zihni açar.'));
    });

    test('DictionaryService local lookup finds root entries and stems inflected Turkish words', () {
      final service = DictionaryService();
      final entry = service.lookup('tahrir');
      expect(entry.word, equals('Tahrir'));
      expect(entry.origin, contains('Arapça'));

      // Morphological suffix stripping & consonant softening test
      final inflected1 = service.lookup('hikmetin');
      expect(inflected1.word, equals('Hikmet'));

      final inflected2 = service.lookup('şerhleri');
      expect(inflected2.word, equals('Şerh'));

      final searchResults = service.search('belagat');
      expect(searchResults, isNotEmpty);
    });

    test('OfflineAiService extracts key concepts, TextRank summaries, and studyQuestions without network', () {
      const aiService = OfflineAiService();
      final insights = aiService.analyzeText(
        'Kutadgu Bilig eseri adalet, akıl ve nizam üzerine kurulmuş bir Türk klasiğidir. '
        'Yusuf Has Hacib bu eserde devlet yönetiminde hikmet ve faziletin önemini vurgular. '
        'İrfan sahibi insan, bilgisini toplumun saadeti için kullanan kimsedir.',
      );
      expect(insights.keyConcepts, isNotEmpty);
      expect(insights.summaryBulletPoints, isNotEmpty);
      expect(insights.studyQuestions, isNotEmpty);
    });

    test('EpubParserEngine parseMarkdownOrTxt fallback produces structured chapters', () async {
      const epubEngine = EpubParserEngine();
      final chapters = await epubEngine.parseMarkdownOrTxt('sample://markdown_test.md');
      expect(chapters, isNotEmpty);
      expect(chapters.first.paragraphs, isNotEmpty);
    });

    test('ChangelogService provides bilingual TR and EN release notes (Zikirce_ Standard)', () {
      expect(ChangelogService.releases, isNotEmpty);
      const service = ChangelogService();
      final latest = service.latestRelease;
      expect(latest.version, equals('v1.0.0'));
      expect(latest.highlightsTr, isNotEmpty);
      expect(latest.highlightsEn, isNotEmpty);
    });

    test('Result type handles success and failure folds cleanly', () {
      const success = Result.success(42);
      expect(success.isSuccess, isTrue);
      expect(success.dataOrNull, equals(42));

      final failure = Result<int>.failure(const GeneralError('Hata'));
      expect(failure.isFailure, isTrue);
      expect(failure.errorOrNull?.message, equals('Hata'));
    });

    test('PdfReflowEngine extracts sample page and flags text presence', () async {
      const engine = PdfReflowEngine();
      final pageData = await engine.extractPage('sample://kutadgu_bilig', 0);
      expect(pageData.pageNumber, equals(1));
      expect(pageData.hasTextContent, isTrue);
      expect(pageData.paragraphs, isNotEmpty);
    });
  });
}
