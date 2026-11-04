import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/kuran/data/islamic_bookshelf_models.dart';
import 'package:zikirce/features/kuran/presentation/widgets/rahle_open_book_spread_widget.dart';

void main() {
  group('RahlePageTextChunker & Külliyat Sync Model Tests', () {
    test('Short text fits on a single Rahle leaf without splitting', () {
      final leaves = RahlePageTextChunker.chunkPage(
        turkishText: 'Bismillâhirrahmânirrahîm. Her hayrın başı Besmeledir.',
        arabicText: 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ',
        pageNumber: 5,
        headerTitle: 'Birinci Söz',
        subtitle: 'Sözler • Risale-i Nur',
        reference: 'Sözler, s. 5',
        maxCharsPerLeaf: 800,
      );

      expect(leaves.length, 1);
      expect(leaves.first.pageNumber, 5);
      expect(leaves.first.leafIndex, 1);
      expect(leaves.first.totalLeavesForPage, 1);
      expect(leaves.first.isMultiLeaf, isFalse);
      expect(leaves.first.arabicText, isNotEmpty);
      expect(leaves.first.leafBadgeLabel, 'Sayfa 5');
    });

    test('Long page splits into multiple zero-scroll leaves preserving sentences', () {
      final para1 = List.filled(
        10,
        'İman hem nurdur hem kuvvettir. Hakikî imanı elde eden adam kâinata meydan okuyabilir.',
      ).join(' ');
      final para2 = List.filled(
        10,
        'İbâdet ise kalbin gıdası ve ruhun ziyasıdır. Tefekkür ile kâinat kitabı okunur.',
      ).join(' ');

      final leaves = RahlePageTextChunker.chunkPage(
        turkishText: '$para1\n\n$para2',
        arabicText: 'آللّٰهُ نُورُ السَّمٰوَاتِ وَالْاَرْضِ',
        pageNumber: 24,
        headerTitle: 'Yirmi Üçüncü Söz',
        subtitle: 'Sözler',
        reference: 'Sözler, s. 24',
        maxCharsPerLeaf: 600,
      );

      expect(leaves.length, greaterThanOrEqualTo(2));
      expect(leaves.first.leafIndex, 1);
      expect(leaves.first.totalLeavesForPage, leaves.length);
      expect(leaves.first.arabicText, isNotEmpty);
      expect(leaves[1].arabicText, isEmpty);
      expect(leaves.first.leafBadgeLabel, 'Sayfa 24 • Yaprak 1/${leaves.length}');
    });

    test('IslamicShelfBook & IslamicBookReaderSettings serialize TV/Sync fields', () {
      final book = IslamicBookshelfCatalog.defaultBooks().first.copyWith(
        currentPage: 42,
        hasStartedReading: true,
        lastReadAtMs: 1793515000000,
      );
      final json = book.toJson();

      expect(json['currentPage'], 42);
      expect(json['hasStartedReading'], isTrue);
      expect(json['lastReadAtMs'], 1793515000000);

      const settings = IslamicBookReaderSettings(isRahleSpreadMode: true);
      final restoredSettings = IslamicBookReaderSettings.fromJson(settings.toJson());
      expect(restoredSettings.isRahleSpreadMode, isTrue);
    });
  });
}
