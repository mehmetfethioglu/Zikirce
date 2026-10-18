import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/bio_rpg/domain/bio_rpg_models.dart';
import 'package:organicscore/features/bio_rpg/domain/bio_rpg_service.dart';
import 'package:organicscore/features/bio_rpg/domain/bio_rhythm_telemetry_service.dart';
import 'package:organicscore/features/bio_rpg/presentation/widgets/pixar_3d_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BioRpgService.instance.loadState();
  });

  group('OrganicScore 2.0 Bio-Guardians RPG Engine Tests', () {
    test('Phase 1: Barcode with Gluten / Emulsifier spawns specific ToxicBoss', () {
      final glutenEncounter = BioRpgService.instance.evaluateProductEncounter(
        barcode: '8690000111222',
        productName: 'Kremalı Bisküvi',
        productScore: 32,
        ingredientsText: 'Buğday unu (gluten), şeker, palm yağı, emülgatör (E471)',
        violationTitles: ['Gluten İhlali'],
        additiveNames: ['E471 Mono ve Digliseritler'],
      );

      expect(glutenEncounter.isBossEncounter, isTrue);
      expect(glutenEncounter.spawnedBoss, isNotNull);
      expect(glutenEncounter.spawnedBoss!.archetype, equals(BossArchetype.glutenGolem));

      final msgEncounter = BioRpgService.instance.evaluateProductEncounter(
        barcode: '8690000333444',
        productName: 'Süper Baharatlı Cips',
        productScore: 25,
        ingredientsText: 'Patates, bitkisel yağ, aroma artırıcı (E621 monosodyum glutamat)',
        violationTitles: const [],
        additiveNames: ['E621 MSG'],
      );

      expect(msgEncounter.isBossEncounter, isTrue);
      expect(msgEncounter.spawnedBoss!.archetype, equals(BossArchetype.msgPhantom));
    });

    test('Phase 1: Rejecting harmful product boosts Personal OrganicScore and halves Boss HP with Willpower Shield', () async {
      final int initialScore = BioRpgService.instance.value.personalOrganicScore;
      final encounter = BioRpgService.instance.evaluateProductEncounter(
        barcode: '8690000999888',
        productName: 'Endüstriyel Gofret',
        productScore: 28,
        ingredientsText: 'Şeker, emülgatör E471',
        violationTitles: const [],
        additiveNames: ['E471'],
      );

      final record = await BioRpgService.instance.recordProductDecision(
        barcode: '8690000999888',
        productName: 'Endüstriyel Gofret',
        productScore: 28,
        decision: ScanDecisionType.rejected,
        encounter: encounter,
      );

      expect(record.personalScoreDelta, greaterThan(0));
      expect(BioRpgService.instance.value.personalOrganicScore, greaterThan(initialScore));

      final spawnedInQueue = BioRpgService.instance.value.bossQueue.first;
      expect(spawnedInQueue.willpowerBonusApplied, isTrue);
      expect(spawnedInQueue.currentHp, equals((spawnedInQueue.maxHp * 0.5).round()));
    });

    test('Phase 1 & 3: Consuming harmful product triggers 3000-step Detox Quest, and walking cleanses it', () async {
      final encounter = BioRpgService.instance.evaluateProductEncounter(
        barcode: '8690000777666',
        productName: 'Şuruplu Gazoz',
        productScore: 20,
        ingredientsText: 'Su, fruktoz-glikoz şurubu',
        violationTitles: const [],
        additiveNames: const [],
      );

      await BioRpgService.instance.recordProductDecision(
        barcode: '8690000777666',
        productName: 'Şuruplu Gazoz',
        productScore: 20,
        decision: ScanDecisionType.consumed,
        encounter: encounter,
      );

      expect(BioRpgService.instance.value.hasActiveDetoxQuest, isTrue);
      expect(BioRpgService.instance.value.activeDetoxTargetSteps, equals(3000));

      // Walk 3,000 steps via step counter
      await BioRpgService.instance.addSteps(3000);
      expect(BioRpgService.instance.value.hasActiveDetoxQuest, isFalse);
      expect(BioRpgService.instance.value.avatarConfig.expressionMood, equals('energized'));
    });

    test('Phase 2: 3D Bio-Arena duel turn deals elemental super-effective damage', () async {
      final activeBoss = BioRpgService.instance.value.activeBosses.first;
      final initialBossHp = activeBoss.currentHp;

      final turnResult = await BioRpgService.instance.executeDuelTurn(
        bossId: activeBoss.id,
        moveType: 'bio_burst',
      );

      expect(turnResult.playerDamageDealt, greaterThan(0));
      expect(turnResult.updatedBoss.currentHp, lessThan(initialBossHp));
    });

    test('Phase 3 & 4: Body metrics BMI/BMR calculation and OrganicPass activation work deterministically', () async {
      await BioRpgService.instance.updateBodyMetrics(heightCm: 180.0, weightKg: 75.0);
      final state = BioRpgService.instance.value;
      expect(state.bmi, closeTo(23.15, 0.1));
      expect(
        BioRhythmTelemetryService.calculateEstimatedBmr(heightCm: 180.0, weightKg: 75.0),
        greaterThan(1500),
      );

      await BioRpgService.instance.activateOrganicPass();
      expect(BioRpgService.instance.value.hasOrganicPass, isTrue);
      expect(BioRpgService.instance.value.guardians.every((g) => g.isUnlocked), isTrue);
    });

    testWidgets('Phase 2: Pixar 3D Guardian, Boss, and Animoji Avatar render without errors', (tester) async {
      final state = BioRpgService.instance.value;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.amoledDarkTheme,
          home: Scaffold(
            body: Column(
              children: [
                Pixar3DGuardianStage(guardian: state.activeGuardian, size: 120),
                Pixar3DBossStage(boss: state.bossQueue.first, size: 120),
                Pixar3DAvatarCanvas(
                  config: state.avatarConfig,
                  personalOrganicScore: state.personalOrganicScore,
                  bmi: state.bmi,
                  size: 120,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Pixar3DGuardianStage), findsOneWidget);
      expect(find.byType(Pixar3DBossStage), findsOneWidget);
      expect(find.byType(Pixar3DAvatarCanvas), findsOneWidget);
    });
  });
}
