import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/scoring/domain/organic_score_calculator.dart';
import 'package:organicscore/features/family_profiles/domain/family_profile_engine.dart';

void main() {
  group('Transparent Scoring & Itemized Ledger Tests', () {
    test('Calculates transparent score factors for clean organic product', () {
      final result = OrganicScoreCalculator.calculate(
        riskLevels: ['LOW'],
        sugarGramsPer100g: 2.0,
        satFatGramsPer100g: 1.0,
        sodiumGramsPer100g: 0.05,
        fiberGramsPer100g: 4.5,
        proteinGramsPer100g: 6.0,
        novaGroup: 1,
      );

      expect(result.overallScore, greaterThanOrEqualTo(85));
      expect(result.ratingCategory, equals('Mükemmel'));
      expect(result.factors, isNotEmpty);

      // Check positive bonuses
      final fiberBonus = result.factors.firstWhere((f) => f.title.contains('Lif'));
      expect(fiberBonus.isPositive, isTrue);
      expect(fiberBonus.impact, equals(15));

      final proteinBonus = result.factors.firstWhere((f) => f.title.contains('Protein'));
      expect(proteinBonus.isPositive, isTrue);
      expect(proteinBonus.impact, equals(15));

      final novaFactor = result.factors.firstWhere((f) => f.category == ScoreFactorCategory.nova);
      expect(novaFactor.isPositive, isTrue);
    });

    test('Calculates transparent score deductions for high sugar, high additive product', () {
      final result = OrganicScoreCalculator.calculate(
        riskLevels: ['TOXIC', 'HIGH'],
        sugarGramsPer100g: 28.0,
        satFatGramsPer100g: 8.0,
        sodiumGramsPer100g: 0.8,
        fiberGramsPer100g: 0.5,
        proteinGramsPer100g: 1.0,
        novaGroup: 4,
      );

      expect(result.overallScore, lessThan(40));
      expect(result.ratingCategory, anyOf(equals('Aşırı Zararlı'), equals('Düşük Kalite')));

      // Check deductions
      final sugarPenalty = result.factors.firstWhere((f) => f.title.contains('Şeker'));
      expect(sugarPenalty.isPositive, isFalse);
      expect(sugarPenalty.impact, equals(-25));

      final toxicAdditive = result.factors.firstWhere((f) => f.title.contains('Toksik'));
      expect(toxicAdditive.isPositive, isFalse);
      expect(toxicAdditive.impact, equals(-25));

      final novaPenalty = result.factors.firstWhere((f) => f.category == ScoreFactorCategory.nova);
      expect(novaPenalty.isPositive, isFalse);
    });

    test('fromDirectScore generates representative factors', () {
      final result = OrganicScoreCalculator.fromDirectScore(85, 1);
      expect(result.factors, isNotEmpty);
      expect(result.factors.any((f) => f.category == ScoreFactorCategory.nova), isTrue);
    });
  });

  group('Personal Sensitivity Config & Presets', () {
    test('Preset default values are accurately configured', () {
      const diabetes = PersonalSensitivityConfig.diabetes;
      expect(diabetes.presetId, equals('diabetes'));
      expect(diabetes.sugarStrictness, equals('strict'));

      const cleanEating = PersonalSensitivityConfig.cleanEating;
      expect(cleanEating.additiveStrictness, equals('zero_tolerance'));
      expect(cleanEating.avoidPalmOil, isTrue);
      expect(cleanEating.avoidNova4, isTrue);

      const heartHealth = PersonalSensitivityConfig.heartHealth;
      expect(heartHealth.sodiumStrictness, equals('strict'));
      expect(heartHealth.avoidPalmOil, isTrue);

      const childSafe = PersonalSensitivityConfig.childSafe;
      expect(childSafe.avoidPalmOil, isTrue);
      expect(childSafe.sugarStrictness, equals('strict'));
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      const config = PersonalSensitivityConfig(
        presetId: 'custom',
        sugarStrictness: 'strict',
        additiveStrictness: 'zero_tolerance',
        avoidPalmOil: true,
        avoidNova4: true,
        sodiumStrictness: 'strict',
      );

      final map = config.toMap();
      final restored = PersonalSensitivityConfig.fromMap(map);

      expect(restored.presetId, equals('custom'));
      expect(restored.sugarStrictness, equals('strict'));
      expect(restored.additiveStrictness, equals('zero_tolerance'));
      expect(restored.avoidPalmOil, isTrue);
      expect(restored.avoidNova4, isTrue);
      expect(restored.sodiumStrictness, equals('strict'));
    });
  });

  group('Personal Match Score Evaluation (%0 - %100)', () {
    test('Diabetes preset penalizes high sugar product on personal match', () {
      final scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: ['LOW'],
        sugarGramsPer100g: 22.0,
        satFatGramsPer100g: 1.0,
        sodiumGramsPer100g: 0.1,
        fiberGramsPer100g: 2.0,
        proteinGramsPer100g: 3.0,
        novaGroup: 2,
      );

      final match = OrganicScoreCalculator.evaluatePersonalMatch(
        scoreResult: scoreResult,
        sensitivity: PersonalSensitivityConfig.diabetes,
        profileName: 'Diyabet Profilim',
        rawIngredients: 'şeker, glikoz şurubu, un',
      );

      expect(match.matchPercentage, lessThan(scoreResult.overallScore));
      expect(match.personalFactors.any((f) => f.title.contains('Şeker')), isTrue);
    });

    test('Clean eating preset penalizes palm oil and additives', () {
      final scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: ['MODERATE'],
        sugarGramsPer100g: 2.0,
        satFatGramsPer100g: 4.0,
        sodiumGramsPer100g: 0.1,
        fiberGramsPer100g: 1.0,
        proteinGramsPer100g: 2.0,
        novaGroup: 4,
      );

      final match = OrganicScoreCalculator.evaluatePersonalMatch(
        scoreResult: scoreResult,
        sensitivity: PersonalSensitivityConfig.cleanEating,
        profileName: 'Temiz Beslenme',
        rawIngredients: 'buğday unu, bitkisel yağ (palm), e471 emülgatör',
        riskLevels: ['MODERATE'],
      );

      expect(match.personalFactors.any((f) => f.title.contains('Palm')), isTrue);
      expect(match.personalFactors.any((f) => f.title.contains('Katkı')), isTrue);
      expect(match.matchPercentage, lessThan(50));
    });

    test('Allergen critical violation drops match percentage to zero', () {
      final scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: ['LOW'],
        sugarGramsPer100g: 1.0,
        satFatGramsPer100g: 0.5,
        sodiumGramsPer100g: 0.05,
        fiberGramsPer100g: 5.0,
        proteinGramsPer100g: 7.0,
        novaGroup: 1,
      );

      final match = OrganicScoreCalculator.evaluatePersonalMatch(
        scoreResult: scoreResult,
        sensitivity: PersonalSensitivityConfig.standard,
        profileName: 'Çölyak Profilim',
        rawIngredients: 'tam buğday unu, gluten, su',
        activeProfileRestrictions: ['GLUTEN'],
      );

      expect(match.hasCriticalViolation, isTrue);
      expect(match.matchPercentage, equals(0));
      expect(match.statusLabel, equals('Profilinizle Uyuşmuyor'));
    });
  });

  group('FamilyProfile Integration', () {
    test('FamilyProfile handles sensitivity_json correctly', () {
      final profile = FamilyProfile.fromMap({
        'id': 1,
        'profile_name': 'Ali',
        'is_active': 1,
        'restrictions_json': '["HIGH_SUGAR", "PALM_OIL"]',
        'sensitivity_json': '{"presetId": "child_safe", "avoidPalmOil": true, "sugarStrictness": "strict"}',
      });

      expect(profile.sensitivity.presetId, equals('child_safe'));
      expect(profile.sensitivity.avoidPalmOil, isTrue);
      expect(profile.sensitivity.sugarStrictness, equals('strict'));

      final map = profile.toMap();
      expect(map['sensitivity_json'], contains('child_safe'));
    });

    test('All 8 restrictions are defined in restrictionMeta with icons', () {
      const expectedKeys = [
        'GLUTEN',
        'HALAL',
        'SYNTHETIC_COLORS',
        'HIGH_SUGAR',
        'PALM_OIL',
        'LACTOSE',
        'HIGH_SODIUM',
        'VEGAN',
      ];

      for (final key in expectedKeys) {
        expect(FamilyProfileEngine.restrictionMeta.containsKey(key), isTrue);
        expect(FamilyProfileEngine.restrictionMeta[key]!.label.isNotEmpty, isTrue);
        expect(FamilyProfileEngine.getRestrictionIcon(key), isNotNull);
      }
    });

    test('All 8 restrictions trigger violations appropriately in FamilyProfileEngine', () {
      final profile = FamilyProfile(
        id: 1,
        profileName: 'Kapsamlı Test',
        isActive: true,
        restrictions: [
          'GLUTEN',
          'HALAL',
          'SYNTHETIC_COLORS',
          'HIGH_SUGAR',
          'PALM_OIL',
          'LACTOSE',
          'HIGH_SODIUM',
          'VEGAN',
        ],
      );

      final violations = FamilyProfileEngine.evaluateViolations(
        activeProfile: profile,
        ingredientsText: 'buğday unu, sığır jelatini, e102 renklendirici, glikoz şurubu, palm yağı, süt tozu, et suyu, monosodyum glutamat',
        detectedRiskLevels: ['HIGH'],
        sugarPer100g: 18.0,
        sodiumPer100g: 0.8,
      );

      final violationKeys = violations.map((v) => v.restrictionKey).toSet();
      expect(violationKeys.contains('GLUTEN'), isTrue);
      expect(violationKeys.contains('HALAL'), isTrue);
      expect(violationKeys.contains('SYNTHETIC_COLORS'), isTrue);
      expect(violationKeys.contains('HIGH_SUGAR'), isTrue);
      expect(violationKeys.contains('PALM_OIL'), isTrue);
      expect(violationKeys.contains('LACTOSE'), isTrue);
      expect(violationKeys.contains('HIGH_SODIUM'), isTrue);
      expect(violationKeys.contains('VEGAN'), isTrue);
    });
  });
}

