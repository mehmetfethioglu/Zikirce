import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/core/config/kilerce_contact_config.dart';
import 'package:organicscore/core/services/kilerce_notification_service.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/onboarding/domain/user_guide_service.dart';
import 'package:organicscore/features/onboarding/presentation/kilerce_user_guide_screen.dart';
import 'package:organicscore/features/recipes/data/kilerce_recipe_catalog.dart';
import 'package:organicscore/features/recipes/domain/recipe_models.dart';
import 'package:organicscore/features/settings/presentation/widgets/recipe_photo_feedback_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  group('Morning Menu Notification Payload & Schedule Tests', () {
    test(
      'buildMenuMissingNotificationPayload detects missing non-staple ingredients for uncooked today meals',
      () {
        final menemen = findMasterRecipeById('menemen')!;
        final recipeById = {menemen.id: menemen};
        final nowMs = DateTime(2026, 11, 27, 8, 0).millisecondsSinceEpoch;

        final pantryOnlyEggs = [
          PantryItem(
            id: 1,
            name: 'Yumurta',
            normalizedTag: 'yumurta',
            brand: 'Çiftlik',
            category: 'Süt & Kahvaltılık',
            storageZone: StorageZone.fridge,
            quantityLevel: QuantityLevel.full,
            unitLabel: '10 Adet',
            healthScore: 95,
            addedAt: nowMs,
            expiresAt: nowMs + 86400000 * 7,
          ),
        ];

        final entries = [
          MealPlanEntry(
            id: 1,
            planDate: '2026-11-27',
            mealSlot: MealSlot.breakfast,
            recipeId: menemen.id,
            servings: 2,
            isCooked: false,
            addedAt: nowMs,
          ),
        ];

        final payload =
            KilerceNotificationService.buildMenuMissingNotificationPayload(
          dateIso: '2026-11-27',
          entries: entries,
          recipeById: recipeById,
          pantryItems: pantryOnlyEggs,
        );

        expect(payload, isNotNull);
        expect(payload!.missingCount, greaterThan(0));
        expect(payload.title, contains('eksik ürün var'));
        expect(payload.body, contains(menemen.title));
        expect(payload.recipeTitles, contains(menemen.title));

        // Cooked entry should not trigger an alert
        final cookedPayload =
            KilerceNotificationService.buildMenuMissingNotificationPayload(
          dateIso: '2026-11-27',
          entries: [entries.first.copyWith(isCooked: true)],
          recipeById: recipeById,
          pantryItems: pantryOnlyEggs,
        );
        expect(cookedPayload, isNull);

        // Full pantry covering all required tags should return null
        final fullPantry = menemen.requiredTags
            .asMap()
            .entries
            .map(
              (e) => PantryItem(
                id: e.key + 10,
                name: e.value,
                normalizedTag: e.value,
                brand: 'Pazar',
                category: 'Genel',
                storageZone: StorageZone.fridge,
                quantityLevel: QuantityLevel.full,
                unitLabel: '1 Adet',
                healthScore: 90,
                addedAt: nowMs,
                expiresAt: nowMs + 86400000 * 5,
              ),
            )
            .toList();

        final completePayload =
            KilerceNotificationService.buildMenuMissingNotificationPayload(
          dateIso: '2026-11-27',
          entries: entries,
          recipeById: recipeById,
          pantryItems: fullPantry,
        );
        expect(completePayload, isNull);
      },
    );

    test(
      'computeNextMorningTrigger picks today before cutoff and tomorrow after cutoff',
      () {
        final earlyMorning = KilerceNotificationService.computeNextMorningTrigger(
          now: DateTime(2026, 11, 27, 7, 15),
          hour: 8,
          minute: 30,
        );
        expect(earlyMorning.isToday, isTrue);
        expect(earlyMorning.targetDateIso, '2026-11-27');
        expect(earlyMorning.triggerAt, DateTime(2026, 11, 27, 8, 30));

        final afternoon = KilerceNotificationService.computeNextMorningTrigger(
          now: DateTime(2026, 11, 27, 14, 0),
          hour: 8,
          minute: 30,
        );
        expect(afternoon.isToday, isFalse);
        expect(afternoon.targetDateIso, '2026-11-28');
        expect(afternoon.triggerAt, DateTime(2026, 11, 28, 8, 30));
      },
    );
  });

  group('User Guide & Recipe Photo Feedback Tests', () {
    test('UserGuideService persists completion flag', () async {
      expect(await UserGuideService.instance.hasCompleted(), isFalse);
      await UserGuideService.instance.markCompleted();
      expect(await UserGuideService.instance.hasCompleted(), isTrue);
      await UserGuideService.instance.reset();
      expect(await UserGuideService.instance.hasCompleted(), isFalse);
    });

    testWidgets(
      'KilerceUserGuideScreen navigates 5 slides, shows representative photo info & marks complete on 360x780',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => KilerceUserGuideScreen.show(ctx),
                    child: const Text('Kılavuzu Aç'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Kılavuzu Aç'));
        await tester.pumpAndSettle();

        expect(find.text('Kilerce\'ye Hoş Geldiniz'), findsOneWidget);

        // Advance through slides 1 -> 5
        for (int i = 0; i < 4; i++) {
          await tester.tap(find.text('İleri'));
          await tester.pumpAndSettle();
        }

        expect(find.text('Yemek Görselleri & Katkınız'), findsOneWidget);
        expect(
          find.textContaining('temsili olarak hazırlanmıştır'),
          findsOneWidget,
        );
        expect(
          find.textContaining(KilerceContactConfig.supportEmail),
          findsOneWidget,
        );
        expect(find.text('Tarif Fotoğrafı Gönder'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Başla'));
        await tester.pumpAndSettle();

        expect(await UserGuideService.instance.hasCompleted(), isTrue);
        expect(find.byType(KilerceUserGuideScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RecipePhotoFeedbackSheet renders representative photo notice, prefilled title, and email actions cleanly on 360x780',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => RecipePhotoFeedbackSheet.show(
                      ctx,
                      initialRecipeTitle: 'Klasik Köy Menemeni',
                    ),
                    child: const Text('Sheet Aç'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Sheet Aç'));
        await tester.pumpAndSettle();

        expect(find.text('Tarif Fotoğrafı Gönder'), findsOneWidget);
        expect(
          find.textContaining('temsili olarak hazırlanmıştır'),
          findsOneWidget,
        );
        expect(find.text('Klasik Köy Menemeni'), findsOneWidget);
        expect(find.text(KilerceContactConfig.supportEmail), findsOneWidget);
        expect(find.text('Mail Aç'), findsOneWidget);
        expect(find.text('Kopyala'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
