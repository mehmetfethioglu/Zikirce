import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/core/errors/app_error.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';
import 'package:tahrir/features/reader/engine/pdf_reflow_engine.dart';
import 'package:tahrir/features/marginalia/services/dictionary_service.dart';
import 'package:tahrir/features/reader/services/offline_ai_service.dart';

void main() {
  group('Tahrir Unit & Smoke Tests', () {
    test('TextSegmenter deHyphenate removes line-break hyphens correctly', () {
      const sample = 'Tahrir ile yapılan tahrir-\nler zihni açar.';
      final cleaned = TextSegmenter.deHyphenate(sample);
      expect(cleaned, equals('Tahrir ile yapılan tahrirler zihni açar.'));
    });

    test('DictionaryService local lookup finds root entries', () {
      final service = DictionaryService();
      final entry = service.lookup('tahrir');
      expect(entry.word, equals('Tahrir'));
      expect(entry.origin, contains('Arapça'));
    });

    test('OfflineAiService extracts key concepts and summaries without network', () {
      const aiService = OfflineAiService();
      final insights = aiService.analyzeText(
        'Kutadgu Bilig eseri adalet, akıl ve nizam üzerine kurulmuş bir Türk klasiğidir.',
      );
      expect(insights.keyConcepts, isNotEmpty);
      expect(insights.summaryBulletPoints, isNotEmpty);
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
