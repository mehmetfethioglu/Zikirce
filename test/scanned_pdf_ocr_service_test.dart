import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/engine/pdf_reflow_engine.dart';
import 'package:tahrir/features/reader/engine/smart_reflow_pipeline.dart';
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
  });
}
