import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/kiler_service.dart';
import 'package:organicscore/features/kiler/presentation/widgets/quick_ingredient_add_sheet.dart';
import 'package:organicscore/features/recipes/data/in_memory_meal_module_repository.dart';
import 'package:organicscore/features/recipes/domain/meal_module_notifier.dart';
import 'package:organicscore/features/recipes/domain/recipe_recommendation_engine.dart';
import 'package:organicscore/features/recipes/presentation/widgets/kitchen_checkin_sheets.dart';
import 'package:organicscore/features/recipes/presentation/widgets/recipe_visual_header.dart';

void main() {
  const int dayMs = 86400000;

  PantryItem buildItem({
    required int id,
    required String name,
    required String tag,
    required String category,
    required StorageZone zone,
    required QuantityLevel level,
    required DateTime now,
    required int ageDays,
    required int remainingDays,
  }) {
    final int nowMs = now.millisecondsSinceEpoch;
    return PantryItem(
      id: id,
      name: name,
      normalizedTag: tag,
      brand: 'Pazar / Ev',
      category: category,
      storageZone: zone,
      quantityLevel: level,
      unitLabel: '1 Adet',
      healthScore: 95,
      addedAt: nowMs - (ageDays * dayMs),
      expiresAt: nowMs + (remainingDays * dayMs),
    );
  }

  group('Kilerce Barkodsuz Giriş & Günlük Yaşam Döngüsü Testleri', () {
    test(
      '1. NaturalPantryInputParser pazar/kasap/ev yapımı doğal metni toplu ayrıştırır',
      () {
        final drafts = NaturalPantryInputParser.parseBatch(
          'yarım kilo kıyma, 2 kg salkım domates, 15 köy yumurtası, 1 kavanoz ev biber salçası, taze hamsi',
        );

        expect(drafts.length, 5);

        expect(drafts[0].tag, 'kiyma');
        expect(drafts[0].unitLabel, '500 gr');
        expect(drafts[0].sourceChannel, UnbarcodedSourceChannel.kasapKoy);

        expect(drafts[1].tag, 'domates');
        expect(drafts[1].unitLabel, '2 Kg');
        expect(drafts[1].sourceChannel, UnbarcodedSourceChannel.manavPazar);

        expect(drafts[2].tag, 'yumurta');
        expect(drafts[2].unitLabel, '15 Adet');
        expect(drafts[2].sourceChannel, UnbarcodedSourceChannel.kasapKoy);

        expect(drafts[3].tag, 'salca');
        expect(drafts[3].unitLabel, '1 Kavanoz');
        expect(drafts[3].storageZone, StorageZone.pantry);
        expect(drafts[3].shelfDays, greaterThanOrEqualTo(180));
        expect(drafts[3].sourceChannel, UnbarcodedSourceChannel.aktarEvYapimi);

        expect(drafts[4].tag, 'hamsi');
        expect(drafts[4].sourceChannel, UnbarcodedSourceChannel.balikci);
      },
    );

    test(
      '2. Uzun süre bekleyen ürünler isLongWaiting ile yakalanır ve kurtarma tariflerinde önceliklenir',
      () {
        final now = DateTime(2026, 11, 18, 10, 0);
        final stagnantFridgeEgg = buildItem(
          id: 10,
          name: 'Köy Yumurtası',
          tag: 'yumurta',
          category: 'Et, Tavuk & Yumurta',
          zone: StorageZone.fridge,
          level: QuantityLevel.full,
          now: now,
          ageDays: 7,
          remainingDays: 6,
        );
        final stagnantFridgeTomato = buildItem(
          id: 11,
          name: 'Salkım Domates',
          tag: 'domates',
          category: 'Sebze & Meyve',
          zone: StorageZone.fridge,
          level: QuantityLevel.half,
          now: now,
          ageDays: 6,
          remainingDays: 5,
        );
        final stagnantFridgePepper = buildItem(
          id: 12,
          name: 'Sivri Biber',
          tag: 'biber',
          category: 'Sebze & Meyve',
          zone: StorageZone.fridge,
          level: QuantityLevel.full,
          now: now,
          ageDays: 5,
          remainingDays: 6,
        );
        final stagnantPantryRice = buildItem(
          id: 13,
          name: 'Baldo Pirinç',
          tag: 'pirinc',
          category: 'Bakliyat & Tahıl',
          zone: StorageZone.pantry,
          level: QuantityLevel.full,
          now: now,
          ageDays: 22,
          remainingDays: 90,
        );
        final freshOil = buildItem(
          id: 14,
          name: 'Sızma Zeytinyağı',
          tag: 'zeytinyagi',
          category: 'Sos, Yağ & Baharat',
          zone: StorageZone.pantry,
          level: QuantityLevel.full,
          now: now,
          ageDays: 1,
          remainingDays: 180,
        );

        expect(stagnantFridgeEgg.isExpiringSoon, isFalse);
        expect(stagnantFridgeEgg.isLongWaiting, isTrue);
        expect(stagnantFridgeEgg.needsWasteRescue, isTrue);
        expect(stagnantPantryRice.isLongWaiting, isTrue);
        expect(stagnantPantryRice.needsWasteRescue, isTrue);
        expect(freshOil.isLongWaiting, isFalse);

        final rescueRecipes = RecipeRecommendationEngine.topWasteRescueRecipes(
          pantryItems: [
            stagnantFridgeEgg,
            stagnantFridgeTomato,
            stagnantFridgePepper,
            stagnantPantryRice,
            freshOil,
          ],
        );

        expect(rescueRecipes, isNotEmpty);
        expect(
          rescueRecipes.any(
            (m) =>
                m.rescuesStagnantItems &&
                m.longWaitingIngredientsUsed.isNotEmpty &&
                m.preventsFoodWaste,
          ),
          isTrue,
        );
      },
    );

    test(
      '3. Takvim günü geldiğinde eksik malzeme habercisi çalışır ve tek dokunuşla kilere eklenince temizlenir',
      () async {
        final morningNow = DateTime(2026, 11, 18, 9, 0);
        final todayIso = MealDateUtils.toIsoDate(morningNow);
        final repo = InMemoryMealModuleRepository();
        await repo.upsertMealPlanEntry(
          MealPlanEntry(
            planDate: todayIso,
            mealSlot: MealSlot.breakfast,
            recipeId: 'menemen',
            servings: 2,
            addedAt: morningNow.millisecondsSinceEpoch,
          ),
        );

        final kilerNotifier = ValueNotifier<KilerState>(
          KilerState(
            pantryItems: [
              buildItem(
                id: 1,
                name: 'Köy Yumurtası',
                tag: 'yumurta',
                category: 'Et, Tavuk & Yumurta',
                zone: StorageZone.fridge,
                level: QuantityLevel.full,
                now: morningNow,
                ageDays: 1,
                remainingDays: 10,
              ),
            ],
          ),
        );
        addTearDown(kilerNotifier.dispose);

        int nextId = 200;
        final notifier = MealModuleNotifier(
          repository: repo,
          loadActiveProfile: () async => null,
          kilerListenable: kilerNotifier,
          nowProvider: () => morningNow,
          autoLoad: false,
          onBatchAddDrafts: (drafts) async {
            final current = List<PantryItem>.from(kilerNotifier.value.pantryItems);
            for (final d in drafts) {
              current.add(d.toPantryItem(nowMs: morningNow.millisecondsSinceEpoch).copyWith(id: nextId++));
            }
            kilerNotifier.value = kilerNotifier.value.copyWith(pantryItems: current);
            return drafts.length;
          },
        );
        addTearDown(notifier.dispose);

        await notifier.loadAll();

        final missingPrompts = notifier.state.activePrompts
            .where((p) => p.type == KitchenPromptType.todayMissingIngredients)
            .toList();
        expect(missingPrompts.length, 1);
        expect(missingPrompts.first.missingTags, containsAll(['domates', 'biber']));

        await notifier.markMissingIngredientsBoughtToPantry(
          missingPrompts.first.missingTags,
        );

        final remainingMissing = notifier.state.activePrompts
            .where((p) => p.type == KitchenPromptType.todayMissingIngredients)
            .toList();
        expect(remainingMissing, isEmpty);
        expect(kilerNotifier.value.availableTags, containsAll(['domates', 'biber']));
      },
    );

    test(
      '4. Öğün saati gelince planlanan yemek sorulur; Pişirdim stok düşer ve Ertele yarına taşır',
      () async {
        final eveningNow = DateTime(2026, 11, 18, 20, 30);
        final todayIso = MealDateUtils.toIsoDate(eveningNow);
        final tomorrowIso =
            MealDateUtils.toIsoDate(eveningNow.add(const Duration(days: 1)));

        final repo = InMemoryMealModuleRepository();
        await repo.upsertMealPlanEntry(
          MealPlanEntry(
            planDate: todayIso,
            mealSlot: MealSlot.mainCourse,
            recipeId: 'hunkar_begendi_istanbul',
            servings: 4,
            addedAt: eveningNow.millisecondsSinceEpoch,
          ),
        );
        await repo.upsertMealPlanEntry(
          MealPlanEntry(
            planDate: todayIso,
            mealSlot: MealSlot.soupStarter,
            recipeId: 'menemen',
            servings: 2,
            addedAt: eveningNow.millisecondsSinceEpoch,
          ),
        );

        final kilerNotifier = ValueNotifier<KilerState>(
          KilerState(
            pantryItems: [
              buildItem(
                id: 50,
                name: 'Kemer Patlıcan',
                tag: 'patlican',
                category: 'Sebze & Meyve',
                zone: StorageZone.fridge,
                level: QuantityLevel.full,
                now: eveningNow,
                ageDays: 1,
                remainingDays: 6,
              ),
            ],
          ),
        );
        addTearDown(kilerNotifier.dispose);

        final Map<int, QuantityConsumptionAction> capturedActions = {};
        final notifier = MealModuleNotifier(
          repository: repo,
          loadActiveProfile: () async => null,
          kilerListenable: kilerNotifier,
          nowProvider: () => eveningNow,
          autoLoad: false,
          onQuickConsume: (actions, note) async {
            capturedActions.addAll(actions);
            return (updatedCount: actions.length, finishedCount: 0);
          },
        );
        addTearDown(notifier.dispose);

        await notifier.loadAll();

        final cookPrompts = notifier.state.activePrompts
            .where((p) => p.type == KitchenPromptType.plannedMealCookCheck)
            .toList();
        expect(cookPrompts.length, 2);

        final mainPrompt = cookPrompts.firstWhere(
          (p) => p.mealSlot == MealSlot.mainCourse,
        );
        await notifier.confirmPlannedMealCooked(
          mainPrompt.plannedEntry!,
          customActions: {50: QuantityConsumptionAction.stepDown},
        );

        expect(capturedActions[50], QuantityConsumptionAction.stepDown);
        final updatedMain = notifier.state.weekEntries.firstWhere(
          (e) => e.planDate == todayIso && e.mealSlot == MealSlot.mainCourse,
        );
        expect(updatedMain.isCooked, isTrue);
        expect(
          notifier.state.slotCheckIns['$todayIso|${MealSlot.mainCourse.dbCode}']
              ?.resolutionType,
          SlotResolutionType.cookedPlanned,
        );

        final soupEntry = notifier.state.weekEntries.firstWhere(
          (e) => e.planDate == todayIso && e.mealSlot == MealSlot.soupStarter,
        );
        await notifier.postponePlannedMealToTomorrow(soupEntry);

        expect(
          notifier.state.weekEntries.any(
            (e) => e.planDate == tomorrowIso && e.mealSlot == MealSlot.soupStarter,
          ),
          isTrue,
        );
      },
    );

    test(
      '5. Boş geçen öğün yoklaması stok düşer ve gerçek yemek fotoğrafı override edilir',
      () async {
        final noonNow = DateTime(2026, 11, 18, 12, 30);
        final todayIso = MealDateUtils.toIsoDate(noonNow);
        final repo = InMemoryMealModuleRepository();

        final kilerNotifier = ValueNotifier<KilerState>(
          KilerState(
            pantryItems: [
              buildItem(
                id: 77,
                name: 'Köy Yumurtası',
                tag: 'yumurta',
                category: 'Et, Tavuk & Yumurta',
                zone: StorageZone.fridge,
                level: QuantityLevel.half,
                now: noonNow,
                ageDays: 2,
                remainingDays: 10,
              ),
            ],
          ),
        );
        addTearDown(kilerNotifier.dispose);

        final Map<int, QuantityConsumptionAction> consumed = {};
        final notifier = MealModuleNotifier(
          repository: repo,
          loadActiveProfile: () async => null,
          kilerListenable: kilerNotifier,
          nowProvider: () => noonNow,
          autoLoad: false,
          onQuickConsume: (actions, note) async {
            consumed.addAll(actions);
            return (updatedCount: 1, finishedCount: 0);
          },
        );
        addTearDown(notifier.dispose);

        await notifier.loadAll();

        final unplannedTodayBreakfast = notifier.state.activePrompts.where(
          (p) =>
              p.type == KitchenPromptType.unplannedSlotPantryCheck &&
              p.planDate == todayIso &&
              p.mealSlot == MealSlot.breakfast,
        );
        expect(unplannedTodayBreakfast.length, 1);
        expect(
          unplannedTodayBreakfast.first.suggestedPantryItems.first.normalizedTag,
          'yumurta',
        );

        await notifier.recordUnplannedSlotConsumption(
          dateIso: todayIso,
          slot: MealSlot.breakfast,
          actionsByItemId: {77: QuantityConsumptionAction.stepDown},
        );

        expect(consumed[77], QuantityConsumptionAction.stepDown);
        expect(
          notifier.state.activePrompts.where(
            (p) =>
                p.type == KitchenPromptType.unplannedSlotPantryCheck &&
                p.planDate == todayIso &&
                p.mealSlot == MealSlot.breakfast,
          ),
          isEmpty,
        );

        // Recipe photo override projection lifecycle
        final tempDir = Directory.systemTemp.createTempSync('kilerce_photo_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final tempFile = File('${tempDir.path}/hunkar_gercek.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

        await notifier.saveRecipePhotoOverride(
          'hunkar_begendi_istanbul',
          tempFile.path,
        );
        expect(
          notifier.state.recipeById['hunkar_begendi_istanbul']?.localImagePath,
          tempFile.path,
        );

        await notifier.removeRecipePhotoOverride('hunkar_begendi_istanbul');
        expect(
          notifier.state.recipeById['hunkar_begendi_istanbul']?.localImagePath,
          isNull,
        );
      },
    );

    testWidgets(
      '6. Barkodsuz Pazar/Kasap giriş sheeti 6 kanalı ve doğal dil sepetini kaydeder',
      (tester) async {
        final List<DraftPantryAddition> savedDrafts = [];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (btnContext) => ElevatedButton(
                  onPressed: () => QuickIngredientAddSheet.show(
                    btnContext,
                    onBatchAdd: (drafts) async {
                      savedDrafts.addAll(drafts);
                      return drafts.length;
                    },
                  ),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle();

        final channelScrollable = find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is ListView && w.scrollDirection == Axis.horizontal,
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final channel in UnbarcodedSourceChannel.values) {
          final labelFinder = find.text('${channel.emoji} ${channel.label}');
          await tester.scrollUntilVisible(
            labelFinder,
            140,
            scrollable: channelScrollable,
          );
          expect(labelFinder, findsOneWidget);
        }

        await tester.enterText(
          find.byType(TextField),
          '2 kg domates, yarım kilo kıyma',
        );
        await tester.pump();

        expect(find.textContaining('Algılanan (2)'), findsOneWidget);

        await tester.tap(find.text('Ekle'));
        await tester.pumpAndSettle();

        final saveButton = find.textContaining('Seçili 2 Ürünü Kilere Kaydet');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(savedDrafts.length, 2);
      },
    );

    testWidgets(
      '7. Günlük asistan bannerı ve gerçek yemek fotoğrafı rozeti etkileşimleri çalışır',
      (tester) async {
        int tappedCount = 0;
        final menemen = RecipeRecommendationEngine.catalog.firstWhere(
          (r) => r.id == 'menemen',
        );
        final prompts = [
          KitchenDailyPrompt(
            id: 'p1',
            type: KitchenPromptType.todayMissingIngredients,
            planDate: '2026-11-18',
            mealSlot: MealSlot.breakfast,
            title: 'Bugün Menemen için eksik var',
            subtitle: '2 malzeme eksik',
            recipe: menemen,
            missingTags: const ['domates', 'biber'],
          ),
          KitchenDailyPrompt(
            id: 'p2',
            type: KitchenPromptType.plannedMealCookCheck,
            planDate: '2026-11-18',
            mealSlot: MealSlot.mainCourse,
            title: 'Planlanan yemek yapıldı mı?',
            subtitle: 'Onaylarsanız stok güncellenir',
            recipe: menemen,
          ),
          const KitchenDailyPrompt(
            id: 'p3',
            type: KitchenPromptType.unplannedSlotPantryCheck,
            planDate: '2026-11-17',
            mealSlot: MealSlot.breakfast,
            title: 'Dünkü Kahvaltı öğününde kilerden bir şey tükettiniz mi?',
            subtitle: 'Kileri güncel tutun',
          ),
        ];

        final tempDir = Directory.systemTemp.createTempSync('kilerce_badge_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        // Valid 1x1 transparent PNG bytes so Image.file decodes cleanly in widget tests
        final realPhoto = File('${tempDir.path}/menemen_real.png')
          ..writeAsBytesSync(const [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82,
          ]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  children: [
                    RecipeVisualHeader(
                      recipe: menemen.copyWith(localImagePath: realPhoto.path),
                      heroMode: true,
                    ),
                    KitchenDailyAssistantBanner(
                      prompts: prompts,
                      onAddPromptMissingToShopping: (_) => tappedCount++,
                      onConfirmPromptCooked: (_) => tappedCount++,
                      onOpenUnplannedPrompt: (_) => tappedCount++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('📸 Gerçek Fotoğraf'), findsOneWidget);
        expect(find.text('3 Yoklama'), findsOneWidget);
        expect(find.text('Alışverişe Ekle'), findsOneWidget);
        expect(find.text('Diğer 2 bildirimi göster'), findsOneWidget);
        expect(find.text('Pişirdim'), findsNothing);

        await tester.ensureVisible(find.text('Alışverişe Ekle'));
        await tester.tap(find.text('Alışverişe Ekle'));

        await tester.ensureVisible(find.text('Diğer 2 bildirimi göster'));
        await tester.tap(find.text('Diğer 2 bildirimi göster'));
        await tester.pumpAndSettle();

        expect(find.text('Pişirdim'), findsOneWidget);
        expect(find.text('Kilerden Ne Tükettin?'), findsOneWidget);

        await tester.ensureVisible(find.text('Pişirdim'));
        await tester.tap(find.text('Pişirdim'));
        await tester.ensureVisible(find.text('Kilerden Ne Tükettin?'));
        await tester.tap(find.text('Kilerden Ne Tükettin?'));
        await tester.pump();
        expect(tappedCount, 3);
      },
    );
  });
}
