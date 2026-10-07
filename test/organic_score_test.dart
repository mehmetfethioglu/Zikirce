import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/scoring/domain/organic_score_calculator.dart';
import 'package:organicscore/features/family_profiles/domain/family_profile_engine.dart';

void main() {
  group('OrganicScoreCalculator Unit Tests', () {
    test('Clean product with no additives, low sugar, NOVA 1 should score high (>= 90)', () {
      final result = OrganicScoreCalculator.calculate(
        riskLevels: [],
        sugarGramsPer100g: 2.0,
        satFatGramsPer100g: 1.0,
        sodiumGramsPer100g: 0.1,
        fiberGramsPer100g: 5.0,
        proteinGramsPer100g: 8.0,
        novaGroup: 1,
      );

      expect(result.overallScore, greaterThanOrEqualTo(90));
      expect(result.ratingCategory, equals('Mükemmel'));
      expect(result.novaVerdict, contains('NOVA 1'));
    });

    test('Ultra-processed product with TOXIC and HIGH risk E-numbers, high sugar, NOVA 4 should score low (< 35)', () {
      final result = OrganicScoreCalculator.calculate(
        riskLevels: ['TOXIC', 'HIGH', 'HIGH'],
        sugarGramsPer100g: 25.0,
        satFatGramsPer100g: 8.0,
        sodiumGramsPer100g: 0.8,
        fiberGramsPer100g: 0.0,
        proteinGramsPer100g: 1.0,
        novaGroup: 4,
      );

      expect(result.overallScore, lessThan(35));
      expect(result.ratingCategory, equals('Aşırı Zararlı'));
      expect(result.novaVerdict, contains('NOVA 4'));
    });

    test('Incomplete product should yield overallScore -1 and isDataIncomplete true', () {
      final result = OrganicScoreResult.incomplete(reason: 'İçerik Bilgisi Eksik');

      expect(result.overallScore, equals(-1));
      expect(result.isDataIncomplete, isTrue);
      expect(result.ratingCategory, equals('İçerik Doğrulanmadı'));
    });
  });

  group('FamilyProfileEngine Rule Tests', () {
    test('Child profile should flag synthetic colorants and palm oil', () {
      final childProfile = FamilyProfile(
        id: 1,
        profileName: 'Çocuk Profili',
        isActive: true,
        restrictions: ['SYNTHETIC_COLORS', 'PALM_OIL'],
      );

      final violations = FamilyProfileEngine.evaluateViolations(
        activeProfile: childProfile,
        ingredientsText: 'Buğday unu, Şeker, Palm yağı, Tartrazin E102, Koruyucu.',
        detectedRiskLevels: ['HIGH'],
        sugarPer100g: 12.0,
        sodiumPer100g: 0.2,
      );

      expect(violations.length, equals(2));
      expect(violations.any((v) => v.restrictionKey == 'SYNTHETIC_COLORS'), isTrue);
      expect(violations.any((v) => v.restrictionKey == 'PALM_OIL'), isTrue);
    });

    test('Gluten-free profile should trigger violation when wheat is detected', () {
      final celiacProfile = FamilyProfile(
        id: 2,
        profileName: 'Çölyak / Glutensiz',
        isActive: true,
        restrictions: ['GLUTEN'],
      );

      final violations = FamilyProfileEngine.evaluateViolations(
        activeProfile: celiacProfile,
        ingredientsText: 'Tam buğday unu, Su, Maya, Tuz.',
        detectedRiskLevels: [],
        sugarPer100g: 1.0,
        sodiumPer100g: 0.3,
      );

      expect(violations.length, equals(1));
      expect(violations.first.restrictionKey, equals('GLUTEN'));
      expect(violations.first.severity, equals('CRITICAL'));
    });
  });
}
