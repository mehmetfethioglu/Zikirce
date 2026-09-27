import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/dashboard/providers/dashboard_providers.dart';

void main() {
  group('ZikirDistributionItem Tests', () {
    test('Formatted number adds dot separators accurately', () {
      final item1 = ZikirDistributionItem(
        id: 1,
        name: 'İstiğfar',
        totalCount: 19450,
        ratio: 0.5,
        percentage: 50.0,
        color: kDistributionPalette[0],
      );

      expect(item1.formattedTotal, '19.450');

      final item2 = ZikirDistributionItem(
        id: 2,
        name: 'Besmele',
        totalCount: 1250300,
        ratio: 0.3,
        percentage: 30.0,
        color: kDistributionPalette[1],
      );

      expect(item2.formattedTotal, '1.250.300');
    });

    test('Palette has distinct non-empty colors', () {
      expect(kDistributionPalette.length, greaterThanOrEqualTo(10));
      for (final c in kDistributionPalette) {
        expect((c.a * 255).round(), 255);
      }
    });
  });
}
