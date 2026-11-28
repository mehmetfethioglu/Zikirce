import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/kiler_service.dart';
import 'package:organicscore/features/recipes/domain/meal_module_notifier.dart';
import 'package:organicscore/features/recipes/domain/meal_module_repository.dart';
import 'package:organicscore/features/recipes/domain/recipe_recommendation_engine.dart';

class _StubMealModuleRepository implements MealModuleRepository {
  @override
  Future<void> clearDateRange(String startDateIso, String endDateIso) async {}
  @override
  Future<void> deleteCustomRecipe(String recipeId) async {}
  @override
  Future<void> deleteMealPlanEntry(int entryId) async {}
  @override
  Future<Map<String, int>> getCookCountsByRecipe() async => const {};
  @override
  Future<List<KilerRecipe>> getCustomRecipes() async => const [];
  @override
  Future<List<MealPlanEntry>> getEntriesForDateRange(
    String startDateIso,
    String endDateIso,
  ) async =>
      const [];
  @override
  Future<Set<String>> getFavoriteIds() async => const {};
  @override
  Future<Map<String, String>> getRecipePhotoOverrides() async => const {};
  @override
  Future<List<MealCookLog>> getRecentCookLogs({int limit = 20}) async =>
      const [];
  @override
  Future<Map<String, SlotCheckInRecord>> getSlotCheckInsForDateRange(
    String startDateIso,
    String endDateIso,
  ) async =>
      const {};
  @override
  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required int servings,
  }) async {}
  @override
  Future<void> markEntryCooked(int entryId, {required bool isCooked}) async {}
  @override
  Future<void> removeRecipePhotoOverride(String recipeId) async {}
  @override
  Future<void> replaceWeekEntries(
    String startDateIso,
    String endDateIso,
    List<MealPlanEntry> entries,
  ) async {}
  @override
  Future<void> saveCustomRecipe(KilerRecipe recipe) async {}
  @override
  Future<void> setRecipePhotoOverride(RecipePhotoOverride override) async {}
  @override
  Future<bool> toggleFavorite(String recipeId) async => false;
  @override
  Future<void> upsertMealPlanEntry(MealPlanEntry entry) async {}
  @override
  Future<void> upsertSlotCheckIn(SlotCheckInRecord record) async {}
}

KilerRecipe _makeRecipe({
  required String id,
  required String category,
  required List<MealSlot> slots,
  required List<String> requiredTags,
  int prepMinutes = 15,
  int cookMinutes = 15,
  int baseHealthScore = 90,
}) {
  return KilerRecipe(
    id: id,
    title: id,
    subtitle: category,
    emoji: '🍽️',
    category: category,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    calories: 300,
    proteinGrams: 15,
    baseHealthScore: baseHealthScore,
    requiredTags: requiredTags,
    steps: const ['Adım 1'],
    mealSlots: slots,
    chefTip: 'Test şef ipucu',
  );
}

PantryItem _makePantryItem(String tag, {int daysToExpire = 10}) {
  final int nowMs = DateTime(2026, 11, 28, 12).millisecondsSinceEpoch;
  return PantryItem(
    name: tag,
    normalizedTag: tag,
    brand: 'Ev',
    category: 'Genel',
    storageZone: StorageZone.fridge,
    quantityLevel: QuantityLevel.full,
    unitLabel: '1 adet',
    healthScore: 95,
    addedAt: nowMs - const Duration(days: 1).inMilliseconds,
    expiresAt: nowMs + Duration(days: daysToExpire).inMilliseconds,
  );
}

void main() {
  group('Dynamic Time-of-Day Recipe Explore Ranking', () {
    test('RecipeDaypart.fromDateTime maps boundary hours accurately', () {
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 5, 0)),
        equals(RecipeDaypart.morning),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 11, 59)),
        equals(RecipeDaypart.morning),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 12, 0)),
        equals(RecipeDaypart.lunch),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 15, 59)),
        equals(RecipeDaypart.lunch),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 16, 0)),
        equals(RecipeDaypart.dinner),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 21, 59)),
        equals(RecipeDaypart.dinner),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 22, 0)),
        equals(RecipeDaypart.lateNight),
      );
      expect(
        RecipeDaypart.fromDateTime(DateTime(2026, 11, 28, 4, 59)),
        equals(RecipeDaypart.lateNight),
      );
    });

    test('morning (09:00) prioritizes breakfast recipes ahead of main courses while preserving pantry readiness within breakfast', () {
      final breakfastReady = _makeRecipe(
        id: 'test_breakfast_ready',
        category: RecipeCategoryRegistry.breakfast,
        slots: const [MealSlot.breakfast],
        requiredTags: const ['yumurta'],
        baseHealthScore: 84,
      );
      final breakfastMissing = _makeRecipe(
        id: 'test_breakfast_missing',
        category: RecipeCategoryRegistry.breakfast,
        slots: const [MealSlot.breakfast],
        requiredTags: const ['avokado', 'peynir'],
        baseHealthScore: 95,
      );
      final dinnerReady = _makeRecipe(
        id: 'test_dinner_ready',
        category: RecipeCategoryRegistry.meatFish,
        slots: const [MealSlot.mainCourse],
        requiredTags: const ['yumurta'],
        baseHealthScore: 98,
      );

      final matches = RecipeRecommendationEngine.evaluateAll(
        pantryItems: [_makePantryItem('yumurta')],
        customRecipes: [dinnerReady, breakfastMissing, breakfastReady],
        now: DateTime(2026, 11, 28, 9, 0),
      );

      final ids = matches.map((m) => m.recipe.id).toList();
      final idxBreakfastReady = ids.indexOf('test_breakfast_ready');
      final idxBreakfastMissing = ids.indexOf('test_breakfast_missing');
      final idxDinnerReady = ids.indexOf('test_dinner_ready');

      expect(idxBreakfastReady, lessThan(idxBreakfastMissing));
      expect(idxBreakfastMissing, lessThan(idxDinnerReady));
    });

    test('afternoon (14:00) and evening (19:00) prioritize main courses and soups ahead of breakfast recipes', () {
      final breakfastReady = _makeRecipe(
        id: 'test_breakfast_ready',
        category: RecipeCategoryRegistry.breakfast,
        slots: const [MealSlot.breakfast],
        requiredTags: const ['yumurta'],
        baseHealthScore: 98,
      );
      final mainReady = _makeRecipe(
        id: 'test_main_ready',
        category: RecipeCategoryRegistry.vegOliveOil,
        slots: const [MealSlot.mainCourse],
        requiredTags: const ['kabak'],
        baseHealthScore: 86,
      );
      final soupReady = _makeRecipe(
        id: 'test_soup_ready',
        category: RecipeCategoryRegistry.soup,
        slots: const [MealSlot.soupStarter],
        requiredTags: const ['mercimek'],
        baseHealthScore: 85,
      );

      for (final time in [
        DateTime(2026, 11, 28, 14, 0),
        DateTime(2026, 11, 28, 19, 0),
      ]) {
        final matches = RecipeRecommendationEngine.evaluateAll(
          pantryItems: [
            _makePantryItem('yumurta'),
            _makePantryItem('kabak'),
            _makePantryItem('mercimek'),
          ],
          customRecipes: [breakfastReady, mainReady, soupReady],
          now: time,
        );
        final ids = matches.map((m) => m.recipe.id).toList();
        expect(ids.indexOf('test_main_ready'), lessThan(ids.indexOf('test_breakfast_ready')));
        expect(ids.indexOf('test_soup_ready'), lessThan(ids.indexOf('test_breakfast_ready')));
      }
    });

    test('lateNight (23:30) prioritizes light/soup/quick recipes over heavy slow main courses', () {
      final heavyMain = _makeRecipe(
        id: 'test_heavy_main',
        category: RecipeCategoryRegistry.meatFish,
        slots: const [MealSlot.mainCourse],
        requiredTags: const ['dana_eti'],
        prepMinutes: 30,
        cookMinutes: 60,
        baseHealthScore: 96,
      );
      final quickSoup = _makeRecipe(
        id: 'test_quick_soup',
        category: RecipeCategoryRegistry.soup,
        slots: const [MealSlot.soupStarter],
        requiredTags: const ['dana_eti'],
        prepMinutes: 5,
        cookMinutes: 10,
        baseHealthScore: 82,
      );

      final matches = RecipeRecommendationEngine.evaluateAll(
        pantryItems: [_makePantryItem('dana_eti')],
        customRecipes: [heavyMain, quickSoup],
        now: DateTime(2026, 11, 28, 23, 30),
      );

      final ids = matches.map((m) => m.recipe.id).toList();
      expect(ids.indexOf('test_quick_soup'), lessThan(ids.indexOf('test_heavy_main')));
    });

    test('explicit category, search query, and wasteSaver filter keep pantry/waste order above daypart', () {
      final expiringDinner = _makeRecipe(
        id: 'test_expiring_dinner',
        category: RecipeCategoryRegistry.meatFish,
        slots: const [MealSlot.mainCourse],
        requiredTags: const ['tavuk'],
        baseHealthScore: 85,
      );
      final freshBreakfast = _makeRecipe(
        id: 'test_fresh_breakfast',
        category: RecipeCategoryRegistry.breakfast,
        slots: const [MealSlot.breakfast],
        requiredTags: const ['yumurta'],
        baseHealthScore: 95,
      );

      final wasteMatches = RecipeRecommendationEngine.evaluateAll(
        pantryItems: [
          _makePantryItem('tavuk', daysToExpire: 1),
          _makePantryItem('yumurta', daysToExpire: 20),
        ],
        filter: RecipeFilterTab.wasteSaver,
        customRecipes: [freshBreakfast, expiringDinner],
        now: DateTime(2026, 11, 28, 9, 0),
      );
      expect(
        wasteMatches.any((m) => m.recipe.id == 'test_expiring_dinner'),
        isTrue,
      );
      expect(
        wasteMatches.any((m) => m.recipe.id == 'test_fresh_breakfast'),
        isFalse,
      );

      final searchMatches = RecipeRecommendationEngine.evaluateAll(
        pantryItems: [_makePantryItem('tavuk')],
        searchQuery: 'test_expiring_dinner',
        customRecipes: [freshBreakfast, expiringDinner],
        now: DateTime(2026, 11, 28, 9, 0),
      );
      expect(searchMatches.first.recipe.id, equals('test_expiring_dinner'));
    });

    test('MealModuleNotifier re-sorts dynamically when hour moves from morning to afternoon on tab focus', () async {
      DateTime clock = DateTime(2026, 11, 28, 9, 0);
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_makePantryItem('yumurta')]),
      );
      final notifier = MealModuleNotifier(
        repository: _StubMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        nowProvider: () => clock,
        initialNow: clock,
        autoLoad: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      expect(notifier.currentDaypart, equals(RecipeDaypart.morning));
      expect(
        notifier.state.evaluatedMatches.first.recipe.category,
        equals(RecipeCategoryRegistry.breakfast),
      );

      // Simulate user returning in the afternoon
      clock = DateTime(2026, 11, 28, 14, 30);
      notifier.setRecipesTabActive(true);
      expect(notifier.currentDaypart, equals(RecipeDaypart.lunch));
      expect(
        notifier.state.evaluatedMatches.first.recipe.category,
        isNot(equals(RecipeCategoryRegistry.breakfast)),
      );
    });
  });
}
