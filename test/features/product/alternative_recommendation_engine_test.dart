import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/product/domain/alternative_recommendation_engine.dart';

void main() {
  group('AlternativeRecommendationEngine Tests', () {
    test('detectCategory accurately classifies product types', () {
      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Coca-Cola 1L', brand: 'Coca Cola'),
        equals(ProductCategory.beverage),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Lays Klasik Patates Cipsi', brand: 'Frito Lay'),
        equals(ProductCategory.snack),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Nutella Kakaolu Fındık Kreması', brand: 'Ferrero'),
        equals(ProductCategory.breakfastSpread),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Karam Gurme Bitter Gofret', brand: 'Eti'),
        equals(ProductCategory.confectionery),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Sütaş Doğal Yoğurt', brand: 'Sütaş'),
        equals(ProductCategory.dairy),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Komili Sızma Zeytinyağı', brand: 'Komili'),
        equals(ProductCategory.condimentsOils),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Barilla Burgu Makarna', brand: 'Barilla'),
        equals(ProductCategory.stapleFood),
      );

      expect(
        AlternativeRecommendationEngine.detectCategory(productName: 'Aptamil Bebek Sütü', brand: 'Aptamil'),
        equals(ProductCategory.babyFood),
      );
    });

    test('Recommends meaningful beverage alternatives for boycotted soda', () {
      final rec = AlternativeRecommendationEngine.getRecommendations(
        currentBarcode: '5000112664492',
        currentProductName: 'coca-cola 1 L',
        currentBrand: 'Coca Cola',
        currentScore: 28,
        currentBoycottStatus: 'FLAGGED',
      );

      expect(rec.isAlreadyOptimal, isFalse);
      expect(rec.category, equals(ProductCategory.beverage));
      expect(rec.alternatives, isNotEmpty);

      // Verify all alternatives are from beverage pool, have real barcodes and higher score
      for (final alt in rec.alternatives) {
        expect(alt.barcode, isNotEmpty);
        expect(alt.score, greaterThan(28));
        // Should have boycott and score improvement badges
        expect(alt.badges, contains('🇹🇷 Boykotsuz & Yerli'));
        expect(alt.badges.any((b) => b.contains('Puan')), isTrue);
      }
    });

    test('Marks product as already optimal if score is >=80 and boycott is CLEAR', () {
      final rec = AlternativeRecommendationEngine.getRecommendations(
        currentBarcode: '8691381000486',
        currentProductName: 'Beypazarı Doğal Maden Suyu',
        currentBrand: 'Beypazarı',
        currentScore: 88,
        currentBoycottStatus: 'CLEAR',
      );

      expect(rec.isAlreadyOptimal, isTrue);
      expect(rec.alternatives, isNotEmpty);
      // Filtered out self
      expect(rec.alternatives.any((a) => a.barcode == '8691381000486'), isFalse);
    });
  });
}
