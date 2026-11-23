import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/core/widgets/kilerce_logo_mark.dart';
import 'package:organicscore/features/family_profiles/domain/family_profile_engine.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/kiler_service.dart';
import 'package:organicscore/features/recipes/data/in_memory_meal_module_repository.dart';
import 'package:organicscore/features/recipes/data/kilerce_recipe_catalog.dart';
import 'package:organicscore/features/recipes/domain/meal_module_notifier.dart';
import 'package:organicscore/features/recipes/domain/meal_plan_generator.dart';
import 'package:organicscore/features/recipes/domain/recipe_recommendation_engine.dart';
import 'package:organicscore/features/recipes/presentation/recipe_explorer_screen.dart';

void main() {
  final DateTime now = DateTime.now();
  final int nowMs = now.millisecondsSinceEpoch;
  const int dayMs = 86400000;

  List<PantryItem> buildSamplePantry() {
    return [
      PantryItem(
        id: 1,
        name: 'Organik Yumurta',
        normalizedTag: 'yumurta',
        brand: 'Köy',
        category: 'Et, Tavuk & Yumurta',
        storageZone: StorageZone.fridge,
        quantityLevel: QuantityLevel.full,
        unitLabel: '10 Adet',
        healthScore: 96,
        addedAt: nowMs,
        expiresAt: nowMs + (12 * dayMs),
      ),
      PantryItem(
        id: 2,
        name: 'Salkım Domates',
        normalizedTag: 'domates',
        brand: 'Manav',
        category: 'Sebze & Meyve',
        storageZone: StorageZone.fridge,
        quantityLevel: QuantityLevel.full,
        unitLabel: '1 Kg',
        healthScore: 98,
        addedAt: nowMs,
        expiresAt: nowMs + (1 * dayMs), // Expiring soon!
      ),
      PantryItem(
        id: 3,
        name: 'Sivri Biber',
        normalizedTag: 'biber',
        brand: 'Manav',
        category: 'Sebze & Meyve',
        storageZone: StorageZone.fridge,
        quantityLevel: QuantityLevel.half,
        unitLabel: '500 gr',
        healthScore: 97,
        addedAt: nowMs,
        expiresAt: nowMs + (2 * dayMs), // Expiring soon!
      ),
      PantryItem(
        id: 4,
        name: 'Kuru Soğan',
        normalizedTag: 'sogan',
        brand: 'Kiler',
        category: 'Sebze & Meyve',
        storageZone: StorageZone.pantry,
        quantityLevel: QuantityLevel.full,
        unitLabel: '2 Kg',
        healthScore: 98,
        addedAt: nowMs,
        expiresAt: nowMs + (30 * dayMs),
      ),
      PantryItem(
        id: 5,
        name: 'Sızma Zeytinyağı',
        normalizedTag: 'zeytinyagi',
        brand: 'Ege',
        category: 'Sos, Yağ & Baharat',
        storageZone: StorageZone.pantry,
        quantityLevel: QuantityLevel.full,
        unitLabel: '1 Litre',
        healthScore: 99,
        addedAt: nowMs,
        expiresAt: nowMs + (180 * dayMs),
      ),
      PantryItem(
        id: 6,
        name: 'Kırmızı Mercimek',
        normalizedTag: 'kirmizi_mercimek',
        brand: 'Anadolu',
        category: 'Bakliyat & Tahıl',
        storageZone: StorageZone.pantry,
        quantityLevel: QuantityLevel.full,
        unitLabel: '1 Kg',
        healthScore: 96,
        addedAt: nowMs,
        expiresAt: nowMs + (180 * dayMs),
      ),
      PantryItem(
        id: 7,
        name: 'Ispanak',
        normalizedTag: 'ispanak',
        brand: 'Manav',
        category: 'Sebze & Meyve',
        storageZone: StorageZone.fridge,
        quantityLevel: QuantityLevel.low,
        unitLabel: '500 gr',
        healthScore: 99,
        addedAt: nowMs,
        expiresAt: nowMs + (1 * dayMs), // Expiring soon!
      ),
    ];
  }

  group('Kilerce Kapsamlı Yemek Listesi & Tarifler Modülü Testleri', () {
    test('Katalog bütünlüğü: ≥100 benzersiz tarif, 7 bölge, 7 kategori ve %100 geçerli etiketler', () {
      expect(kilerceMasterRecipes.length, greaterThanOrEqualTo(100));

      final Set<String> seenIds = {};
      final Set<String> categories = {};
      final Map<String, int> regionCounts = {};

      for (final recipe in kilerceMasterRecipes) {
        expect(seenIds.add(recipe.id), isTrue, reason: 'Tekrarlı id: ${recipe.id}');
        expect(recipe.ingredients.length, greaterThanOrEqualTo(3), reason: recipe.id);
        expect(recipe.steps.length, greaterThanOrEqualTo(3), reason: recipe.id);
        expect(recipe.mealSlots, isNotEmpty, reason: recipe.id);
        expect(recipe.portionGram, greaterThan(0), reason: recipe.id);
        expect(recipe.calories, greaterThan(0), reason: recipe.id);
        expect(recipe.originCity.trim(), isNotEmpty, reason: recipe.id);
        expect(recipe.sourceReference.trim(), isNotEmpty, reason: recipe.id);
        if (recipe.imageAsset != null && recipe.imageAsset!.trim().isNotEmpty) {
          expect(
            File(recipe.imageAsset!).existsSync(),
            isTrue,
            reason: 'Görsel diskte yok: ${recipe.imageAsset} (${recipe.id})',
          );
        }
        categories.add(recipe.category);
        regionCounts[recipe.regionId] = (regionCounts[recipe.regionId] ?? 0) + 1;

        for (final tag in recipe.requiredTags) {
          expect(
            QuickIngredientCatalog.findByTag(tag),
            isNotNull,
            reason: 'Geçersiz requiredTag "$tag" (${recipe.id})',
          );
        }
        for (final tag in recipe.optionalTags) {
          expect(
            QuickIngredientCatalog.findByTag(tag),
            isNotNull,
            reason: 'Geçersiz optionalTag "$tag" (${recipe.id})',
          );
        }
        const basicStapleTags = {
          'su',
          'tuz',
          'karabiber',
          'kekik',
          'kimyon',
          'tarcin',
        };
        for (final ing in recipe.ingredients) {
          if (ing.isPantryStaple || basicStapleTags.contains(ing.tag)) continue;
          expect(
            QuickIngredientCatalog.findByTag(ing.tag),
            isNotNull,
            reason: 'Geçersiz ingredient tag "${ing.tag}" (${recipe.id})',
          );
        }
      }

      expect(categories.length, 7);
      for (final region in TurkishRegionRegistry.sevenRegions) {
        expect(
          regionCounts[region.id] ?? 0,
          greaterThanOrEqualTo(4),
          reason: '${region.label} için en az 4 yöresel tarif olmalı',
        );
      }

      const legacyAndRegionalIds = [
        'menemen',
        'suzme_mercimek_corbasi',
        'domatesli_feslegenli_omlet',
        'tavuk_sote',
        'karniyarik_fırın',
        'mercimekli_bulgur_pilavi',
        'domates_soslu_makarna',
        'kremali_mantarli_tavuk',
        'kiymali_ispanak',
        'firinda_tavuk_patates',
        'zeytinyagli_kabak_kalye',
        'ev_koftesi_patates',
        'nohut_yemegi',
        'kuru_fasulye',
        'saksuka',
        'coban_salata_peynirli',
        'domates_corbasi',
        'kabak_mucver_firin',
        'yulafli_fit_kahvalti',
        'firinda_somon_sebze',
        'hunkar_begendi_istanbul',
        'zeytinyagli_canak_enginar',
        'izmir_tire_koftesi',
        'antalya_tahinli_piyaz',
        'kayseri_ev_mantisi',
        'trabzon_kuymak_mihlama',
        'erzurum_ayran_asi',
        'gaziantep_ali_nazik',
        'gaziantep_beyran_corbasi',
      ];
      for (final recipeId in legacyAndRegionalIds) {
        expect(findMasterRecipeById(recipeId), isNotNull, reason: recipeId);
      }
    });

    test('KilerRecipe porsiyon/kalori ölçekleme ve custom_recipes payload_json dönüşümü eksiksiz çalışır', () {
      final aliNazik = findMasterRecipeById('gaziantep_ali_nazik')!;
      expect(aliNazik.scaledCalories(1), aliNazik.calories);
      expect(aliNazik.scaledCalories(3), aliNazik.calories * 3);
      expect(aliNazik.scaledPortionGrams(3), aliNazik.portionGram * 3);
      expect(aliNazik.scaledMacro(aliNazik.proteinGrams, 3), aliNazik.proteinGrams * 3);

      final customOrig = aliNazik.copyWith(
        id: 'custom_ali_nazik',
        isCustom: true,
        sourceReference: 'Gaziantep Aile Tarifi',
        videoUrl: 'https://cdn.kilerce.app/videos/test.mp4',
      );
      final roundtrip = KilerRecipe.fromCustomDbMap(customOrig.toCustomDbMap(nowMs));
      expect(roundtrip.regionId, customOrig.regionId);
      expect(roundtrip.originCity, customOrig.originCity);
      expect(roundtrip.portionGram, customOrig.portionGram);
      expect(roundtrip.imageAsset, customOrig.imageAsset);
      expect(roundtrip.videoUrl, 'https://cdn.kilerce.app/videos/test.mp4');
      expect(roundtrip.sourceReference, 'Gaziantep Aile Tarifi');
      expect(roundtrip.isCustom, isTrue);
    });

    test('RecipeIngredient porsiyon ölçekleme tam sayı ve kesirleri doğru formatlar', () {
      const ing = RecipeIngredient(
        tag: 'zeytinyagi',
        name: 'Sızma Zeytinyağı',
        amount: 2,
        unit: 'Yemek Kaşığı',
      );
      expect(ing.scaledLabel(2, 2), '2 Yemek Kaşığı Sızma Zeytinyağı');
      expect(ing.scaledLabel(4, 2), '4 Yemek Kaşığı Sızma Zeytinyağı');
      expect(ing.scaledLabel(1, 2), '1 Yemek Kaşığı Sızma Zeytinyağı');

      const halfIng = RecipeIngredient(
        tag: 'sogan',
        name: 'Kuru Soğan',
        amount: 1,
        unit: 'Adet',
      );
      expect(halfIng.scaledLabel(1, 2), '½ Adet Kuru Soğan');
      expect(halfIng.scaledLabel(3, 2), '1 ½ Adet Kuru Soğan');
    });

    test('Yeni kiler etiketleri IngredientNormalizer ile çakışmasız çözülür', () {
      expect(IngredientNormalizer.resolveMetadata('Tam Buğday Unu').tag, 'tam_bugday_unu');
      expect(IngredientNormalizer.resolveMetadata('Taze Karnabahar').tag, 'karnabahar');
      expect(IngredientNormalizer.resolveMetadata('Ev Eriştesi').tag, 'eriste');
      expect(IngredientNormalizer.resolveMetadata('Tuzsuz Lor Peyniri').tag, 'lor_peyniri');
      expect(IngredientNormalizer.resolveMetadata('Taze Dereotu').tag, 'dereotu');
      expect(IngredientNormalizer.resolveMetadata('Doğal Kefir').tag, 'kefir');
      expect(IngredientNormalizer.resolveMetadata('Çanak Enginar').tag, 'enginar');
      expect(IngredientNormalizer.resolveMetadata('Karadeniz Karalahana').tag, 'karalahana');
      expect(IngredientNormalizer.resolveMetadata('Karadeniz Mısır Unu').tag, 'misir_unu');
      expect(IngredientNormalizer.resolveMetadata('Aşurelik Buğday').tag, 'asurelik_bugday');
      expect(IngredientNormalizer.resolveMetadata('Köftelik İnce Bulgur').tag, 'ince_bulgur');
      expect(IngredientNormalizer.resolveMetadata('Taze Barbunya').tag, 'barbunya');
      expect(IngredientNormalizer.resolveMetadata('Taze Hamsi').tag, 'hamsi');
      expect(IngredientNormalizer.resolveMetadata('Kuzu Kuşbaşı').tag, 'kuzu_eti');
      expect(IngredientNormalizer.resolveMetadata('Urfa Isot').tag, 'sumak_isot');
    });

    test('EvaluatedRecipeMatch tüm FamilyProfile kısıtlarını doğru denetler', () {
      final eriste = findMasterRecipeById('cevizli_peynirli_eriste')!;
      final profile = FamilyProfile(
        id: 1,
        profileName: 'Çoklu Hassasiyet',
        isActive: true,
        restrictions: const ['GLUTEN', 'LACTOSE', 'VEGAN', 'HIGH_SODIUM'],
      );
      final warnings = EvaluatedRecipeMatch.evaluateProfileWarnings(
        eriste,
        profile,
      );
      expect(warnings.length, 4);

      final mercimek = findMasterRecipeById('suzme_mercimek_corbasi')!;
      expect(
        EvaluatedRecipeMatch.evaluateProfileWarnings(mercimek, profile),
        isEmpty,
      );
    });

    test('RecipeRecommendationEngine Türkçe arama ve yeni filtreleri uygular', () {
      final pantry = buildSamplePantry();
      final searched = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        searchQuery: 'şifa çorbası',
      );
      expect(searched.any((m) => m.recipe.id == 'suzme_mercimek_corbasi'), isTrue);

      final highProtein = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        filter: RecipeFilterTab.highProtein,
      );
      expect(highProtein.isNotEmpty, isTrue);
      expect(highProtein.every((m) => m.recipe.proteinGrams >= 20), isTrue);

      final favoritesOnly = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        filter: RecipeFilterTab.favorites,
        favoriteIds: const {'menemen', 'nohut_yemegi'},
      );
      expect(favoritesOnly.map((m) => m.recipe.id).toSet(), {'menemen', 'nohut_yemegi'});

      final karadenizOnly = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        region: TurkishRegionRegistry.karadeniz,
      );
      expect(karadenizOnly, isNotEmpty);
      expect(
        karadenizOnly.every((m) => m.recipe.regionId == TurkishRegionRegistry.karadeniz),
        isTrue,
      );

      final antepSearch = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        searchQuery: 'gaziantep',
      );
      expect(antepSearch.any((m) => m.recipe.id == 'gaziantep_ali_nazik'), isTrue);
      expect(antepSearch.any((m) => m.recipe.id == 'gaziantep_beyran_corbasi'), isTrue);

      final trabzonSearch = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        searchQuery: 'trabzon',
      );
      expect(trabzonSearch.any((m) => m.recipe.id == 'trabzon_kuymak_mihlama'), isTrue);
    });

    test('MealPlanGenerator 7x4 profil-güvenli haftalık plan üretir ve eksik alışverişi hesaplar', () {
      final monday = MealDateUtils.startOfWeekMonday(now);
      final mondayIso = MealDateUtils.toIsoDate(monday);
      final pantry = buildSamplePantry();

      final glutenFreeProfile = FamilyProfile(
        id: 2,
        profileName: 'Glutensiz Aile',
        isActive: true,
        restrictions: const ['GLUTEN'],
      );

      final plan = MealPlanGenerator.generateWeeklyPlan(
        weekMondayIso: mondayIso,
        preset: MealPlanPreset.zeroWasteSmart,
        pantryItems: pantry,
        activeProfile: glutenFreeProfile,
        servings: 4,
      );

      expect(plan.length, 28);
      final byId = RecipeRecommendationEngine.buildRecipeIndex();
      for (final entry in plan) {
        expect(entry.servings, 4);
        final recipe = byId[entry.recipeId]!;
        expect(
          EvaluatedRecipeMatch.evaluateProfileWarnings(recipe, glutenFreeProfile),
          isEmpty,
          reason: '${recipe.id} glutensiz profili ihlal etmemeli',
        );
      }

      // First day should prioritize zero-waste recipes using soon-to-expire items
      const expiringTags = {'domates', 'biber', 'ispanak'};
      final dayOneUsesExpiring = plan
          .where((e) => e.planDate == mondayIso)
          .map((e) => findMasterRecipeById(e.recipeId))
          .whereType<KilerRecipe>()
          .any((r) => r.requiredTags.any(expiringTags.contains));
      expect(dayOneUsesExpiring, isTrue);

      final gaps = MealPlanShoppingAggregator.computeNetMissingIngredients(
        weekEntries: plan,
        recipeById: byId,
        pantryItems: pantry,
      );
      // Items already FULL in pantry (yumurta, domates, sogan, zeytinyagi, kirmizi_mercimek) must NOT appear as missing!
      final gapTags = gaps.map((g) => g.tag).toSet();
      expect(gapTags.contains('yumurta'), isFalse);
      expect(gapTags.contains('domates'), isFalse);
      expect(gapTags.contains('zeytinyagi'), isFalse);

      final shareText = MealPlanTextFormatter.formatWeeklyPlanForShare(
        weekMondayIso: mondayIso,
        weekEntries: plan,
        recipeById: byId,
        shoppingGaps: gaps,
        profileName: glutenFreeProfile.profileName,
      );
      expect(shareText, contains('Kilerce Haftalık Yemek Planı'));
      expect(shareText, contains('Glutensiz Aile'));

      final tourPlan = MealPlanGenerator.generateWeeklyPlan(
        weekMondayIso: mondayIso,
        preset: MealPlanPreset.regionalAnatolianTour,
        pantryItems: pantry,
        servings: 2,
      );
      expect(tourPlan.length, 28);
      final tourRegions = tourPlan
          .map((e) => byId[e.recipeId]?.regionId)
          .whereType<String>()
          .where((id) => TurkishRegionRegistry.sevenRegions.any((r) => r.id == id))
          .toSet();
      expect(tourRegions.length, 7);
    });

    test('MealModuleNotifier + InMemoryRepository tam CRUD, favori ve özel tarif akışını çalıştırır', () async {
      final repo = InMemoryMealModuleRepository();
      final kilerNotifier = ValueNotifier<KilerState>(
        KilerState(pantryItems: buildSamplePantry()),
      );

      final notifier = MealModuleNotifier(
        repository: repo,
        loadActiveProfile: () async => null,
        kilerListenable: kilerNotifier,
        initialNow: now,
        autoLoad: false,
      );

      await notifier.loadAll();
      await notifier.toggleFavorite('menemen');
      expect(notifier.state.favoriteIds.contains('menemen'), isTrue);

      notifier.setRegion(TurkishRegionRegistry.guneydogu);
      expect(notifier.state.selectedRegion, TurkishRegionRegistry.guneydogu);
      expect(notifier.state.evaluatedMatches, isNotEmpty);
      expect(
        notifier.state.evaluatedMatches
            .every((m) => m.recipe.regionId == TurkishRegionRegistry.guneydogu),
        isTrue,
      );
      notifier.setRegion(null);
      expect(notifier.state.selectedRegion, isNull);
      expect(notifier.state.evaluatedMatches.length, greaterThanOrEqualTo(84));

      const customRecipe = KilerRecipe(
        id: 'custom_test_corba',
        title: 'Ev Usulü Tarhana',
        subtitle: 'Yoğurtlu ve naneli şifa çorbası',
        emoji: '🥣',
        category: RecipeCategoryRegistry.soup,
        prepMinutes: 5,
        cookMinutes: 15,
        calories: 190,
        proteinGrams: 8,
        baseHealthScore: 95,
        requiredTags: ['yogurt', 'sarimsak'],
        steps: ['Soğuk suda açıp 15 dakika kaynatın.'],
        mealSlots: [MealSlot.soupStarter],
        chefTip: 'Sürekli karıştırarak topaklanmayı önleyin.',
        isCustom: true,
      );

      await notifier.saveCustomRecipe(customRecipe);
      expect(notifier.state.recipeById.containsKey('custom_test_corba'), isTrue);

      await notifier.addOrUpdatePlanEntry(
        dateIso: notifier.state.selectedDateIso,
        slot: MealSlot.soupStarter,
        recipeId: 'custom_test_corba',
        servings: 2,
      );
      expect(
        notifier.state.weekEntries.any((e) => e.recipeId == 'custom_test_corba'),
        isTrue,
      );

      // Cascade delete check: deleting custom recipe cleans linked meal_plan_entries & favorites
      await notifier.toggleFavorite('custom_test_corba');
      await notifier.deleteCustomRecipe('custom_test_corba');
      expect(notifier.state.recipeById.containsKey('custom_test_corba'), isFalse);
      expect(notifier.state.favoriteIds.contains('custom_test_corba'), isFalse);
      expect(
        notifier.state.weekEntries.any((e) => e.recipeId == 'custom_test_corba'),
        isFalse,
      );

      await notifier.generateWeeklyPlan(
        preset: MealPlanPreset.cleanFamilyBalanced,
        servings: 2,
      );
      expect(notifier.state.weekEntries.length, 28);

      final firstEntry = notifier.state.weekEntries.first;
      await notifier.toggleEntryCooked(firstEntry);
      expect(
        notifier.state.weekEntries
            .firstWhere((e) => e.id == firstEntry.id)
            .isCooked,
        isTrue,
      );

      await notifier.clearCurrentWeekPlan();
      expect(notifier.state.weekEntries, isEmpty);

      notifier.dispose();
      kilerNotifier.dispose();
    });

    testWidgets('RecipeExplorerScreen Tarif Keşfet ve Yemek Listem modları çalışır', (tester) async {
      final repo = InMemoryMealModuleRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealModuleRepositoryProvider.overrideWithValue(repo),
            activeProfileLoaderProvider.overrideWithValue(() async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: KilerceLogoMark(size: 36),
                    ),
                    Expanded(child: RecipeExplorerScreen()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KilerceLogoMark), findsWidgets);

      // Mode pills & streamlined single-row filter trigger visible
      expect(find.textContaining('Tarif Keşfet'), findsOneWidget);
      expect(find.textContaining('Yemek Listem'), findsOneWidget);
      expect(find.text('Filtrele'), findsOneWidget);
      expect(find.text('🫒 Ege'), findsNothing);

      // Open filter modal, select Ege region, and apply
      await tester.tap(find.text('Filtrele'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('🫒 Ege'));
      await tester.tap(find.text('🫒 Ege'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sonuçları Göster'));
      await tester.pumpAndSettle();

      // Only the selected chip appears in the single filter bar
      expect(find.text('🫒 Ege ×'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'enginar');
      await tester.pumpAndSettle();
      expect(
        find.text(findMasterRecipeById('zeytinyagli_canak_enginar')!.title),
        findsOneWidget,
      );

      // Clear region filter directly from selected chip
      await tester.tap(find.text('🫒 Ege ×'));
      await tester.pumpAndSettle();
      expect(find.text('🫒 Ege ×'), findsNothing);

      // Search for a recipe and verify compact card + quick Takvime Ekle button
      await tester.enterText(find.byType(TextField), 'menemen');
      await tester.pumpAndSettle();
      expect(find.text('Klasik Köy Menemeni'), findsOneWidget);
      expect(find.text('Takvime Ekle'), findsWidgets);

      // Switch to Yemek Listem mode and generate 7-day plan
      await tester.tap(find.textContaining('Yemek Listem'));
      await tester.pumpAndSettle();

      final generateButton = find.textContaining('Akıllı Haftalık Liste Oluştur');
      expect(generateButton, findsOneWidget);
      await tester.ensureVisible(generateButton);
      await tester.tap(generateButton);
      await tester.pumpAndSettle();

      final entries = await repo.getEntriesForDateRange('2020-01-01', '2099-12-31');
      expect(entries.length, 28);
    });
  });
}
