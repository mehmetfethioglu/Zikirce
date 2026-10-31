import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/zikir/domain/share_card_data_helper.dart';

void main() {
  group('ShareCardDataHelper Dynamic & Selectable Quotes Tests', () {
    test('nextDynamicQuoteIndex never returns the same index twice in a row', () {
      final zikirQuotes = ShareCardDataHelper.getQuotesForTopic('zikir');
      expect(zikirQuotes.length, greaterThan(5));

      int prev = ShareCardDataHelper.nextDynamicQuoteIndex(
        'zikir',
        listLength: zikirQuotes.length,
      );
      for (int i = 0; i < 25; i++) {
        final next = ShareCardDataHelper.nextDynamicQuoteIndex(
          'zikir',
          listLength: zikirQuotes.length,
          avoidIndex: prev,
        );
        expect(next, isNot(equals(prev)));
        prev = next;
      }
    });

    test('nextRandomQuote never repeats avoided quote and respects type filter', () {
      SpiritualQuote prev = ShareCardDataHelper.nextRandomQuote(
        acrossAllTopics: true,
      );
      for (int i = 0; i < 20; i++) {
        final next = ShareCardDataHelper.nextRandomQuote(
          avoidQuote: prev,
          acrossAllTopics: true,
        );
        expect(next, isNot(equals(prev)));
        prev = next;
      }

      final onlyAyet = ShareCardDataHelper.nextRandomQuote(
        filterType: SpiritualQuoteType.ayet,
        acrossAllTopics: true,
      );
      expect(onlyAyet.type, equals(SpiritualQuoteType.ayet));

      final onlyHadis = ShareCardDataHelper.nextRandomQuote(
        filterType: SpiritualQuoteType.hadis,
        acrossAllTopics: true,
      );
      expect(onlyHadis.type, equals(SpiritualQuoteType.hadis));
    });

    test('resolveQuote prioritizes explicitQuote when user selects from picker', () {
      const custom = SpiritualQuote(
        text: 'Seçilen Özel Ayet Meâli',
        source: 'İnşirâh Sûresi, 5-6',
        type: SpiritualQuoteType.ayet,
        topic: 'zikir',
      );

      final resolved = ShareCardDataHelper.resolveQuote(
        zikirName: 'Zikir',
        category: 'Günlük Zikir',
        explicitQuote: custom,
        quoteIndex: 3,
      );
      expect(resolved, equals(custom));
    });
  });
}
