import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/kiler_service.dart';
import 'package:organicscore/features/monetization/domain/kilerce_pro_models.dart';
import 'package:organicscore/features/recipes/data/kilerce_cloud_recipe_client.dart';
import 'package:organicscore/features/recipes/domain/meal_module_notifier.dart';
import 'package:organicscore/features/recipes/domain/meal_module_repository.dart';
import 'package:organicscore/features/recipes/domain/recipe_models.dart';

class _FakeMealModuleRepository implements MealModuleRepository {
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

class _CountingCloudGateway implements KilerceCloudRecipeGateway {
  int matchPantryCalls = 0;
  int searchRecipesCalls = 0;
  int signMediaBatchCalls = 0;
  bool nextHasMore = false;
  bool returnEmptyMedia = false;

  static KilerRecipe _sampleRecipe(String id, String category) => KilerRecipe(
        id: id,
        title: 'Test $id',
        subtitle: category,
        emoji: '🍲',
        category: category,
        prepMinutes: 10,
        calories: 250,
        proteinGrams: 12,
        baseHealthScore: 90,
        requiredTags: const ['domates', 'sogan'],
        steps: const [],
        chefTip: 'Test şef ipucu',
      );

  @override
  Future<KilerceEntitlementSnapshot?> fetchEntitlement() async => null;

  @override
  Future<CloudRecipeDetailResult> fetchRecipeDetail(String recipeId) async =>
      const CloudRecipeDetailFailure('unused');

  @override
  Future<String> getOrCreateAppUserId() async => 'kilerce_test_user';

  @override
  Future<CloudRecipeSearchPage> matchPantry({
    required List<String> pantryTags,
    List<String> expiringTags = const [],
    String? kilerceCategory,
    int limit = 20,
    int offset = 0,
  }) async {
    matchPantryCalls++;
    return CloudRecipeSearchPage(
      page: 1,
      limit: limit,
      hasMore: nextHasMore,
      items: [_sampleRecipe('cloud_pantry_$matchPantryCalls', kilerceCategory ?? 'Çorba')],
    );
  }

  @override
  Future<KilerceEntitlementSnapshot?> recordRewardedAdStepOnCloud() async =>
      null;

  @override
  Future<KilerceEntitlementSnapshot?> redeemPromoCodeOnCloud(
    String code,
  ) async =>
      null;

  @override
  Future<CloudRecipeSearchPage> searchRecipes({
    String query = '',
    String? kilerceCategory,
    String? regionId,
    bool healthyOnly = false,
    bool veganOnly = false,
    bool glutenFree = false,
    int? maxMinutes,
    int page = 1,
    int limit = 20,
  }) async {
    searchRecipesCalls++;
    return CloudRecipeSearchPage(
      page: page,
      limit: limit,
      hasMore: nextHasMore,
      items: [_sampleRecipe('cloud_search_$searchRecipesCalls', kilerceCategory ?? 'Çorba')],
    );
  }

  @override
  Future<Map<String, String>> signMediaBatch(List<String> relPaths) async {
    signMediaBatchCalls++;
    if (returnEmptyMedia) return const {};
    return {
      for (final p in relPaths)
        p: 'https://kilerce-edge-api.kilerce.workers.dev/api/media/$p?exp=$signMediaBatchCalls&sig=test',
    };
  }
}

PantryItem _pantryItem({
  required int id,
  required String tag,
  QuantityLevel quantity = QuantityLevel.full,
  int daysToExpire = 10,
}) {
  final int nowMs = DateTime(2026, 11, 28, 12).millisecondsSinceEpoch;
  return PantryItem(
    id: id,
    name: tag,
    normalizedTag: tag,
    brand: 'Ev',
    category: 'Sebze',
    storageZone: StorageZone.fridge,
    quantityLevel: quantity,
    unitLabel: '1 adet',
    healthScore: 90,
    addedAt: nowMs - const Duration(days: 1).inMilliseconds,
    expiresAt: nowMs + Duration(days: daysToExpire).inMilliseconds,
  );
}

void main() {
  group('MealModuleNotifier cloud request throttling & caching', () {
    test('filter tabs sharing pantry endpoint trigger only 1 matchPantry call', () async {
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_pantryItem(id: 1, tag: 'domates'), _pantryItem(id: 2, tag: 'sogan')]),
      );
      final gateway = _CountingCloudGateway();
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => DateTime(2026, 11, 28, 12),
        autoLoad: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(1));

      notifier.setFilter(RecipeFilterTab.readyNow);
      notifier.setFilter(RecipeFilterTab.wasteSaver);
      notifier.setFilter(RecipeFilterTab.almostReady);
      notifier.setFilter(RecipeFilterTab.all);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.matchPantryCalls, equals(1));
    });

    test('category toggles reuse 10-minute client TTL cache with 0 extra network calls', () async {
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_pantryItem(id: 1, tag: 'domates')]),
      );
      final gateway = _CountingCloudGateway();
      DateTime now = DateTime(2026, 11, 28, 12, 0);
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => now,
        autoLoad: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(1));

      notifier.setCategory('Çorba');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(2));

      // Clear category -> cache hit for null category
      notifier.setCategory('Çorba');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(2));

      // Re-select Çorba -> cache hit for Çorba
      notifier.setCategory('Çorba');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(2));

      // Advance past 10m TTL -> forces fresh fetch on category change
      now = now.add(const Duration(minutes: 11));
      notifier.setCategory(null);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(3));
    });

    test('kiler changes without tag or expiring-tag changes trigger 0 matchPantry calls', () async {
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_pantryItem(id: 1, tag: 'domates', quantity: QuantityLevel.full)]),
      );
      final gateway = _CountingCloudGateway();
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => DateTime(2026, 11, 28, 12),
        autoLoad: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(1));

      // Quantity level and loading-state changes must not trigger cloud refresh
      kiler.value = KilerState(
        pantryItems: [_pantryItem(id: 1, tag: 'domates', quantity: QuantityLevel.half)],
        isLoading: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(gateway.matchPantryCalls, equals(1));
    });

    test('lazy tab loading defers cloud fetch until Recipes tab becomes active', () async {
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_pantryItem(id: 1, tag: 'domates')]),
      );
      final gateway = _CountingCloudGateway();
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => DateTime(2026, 11, 28, 12),
        autoLoad: false,
        isRecipesTabActive: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      expect(gateway.matchPantryCalls, equals(0));

      // Multiple pantry updates while on Kiler tab coalesce into 0 calls until Recipes tab opens
      kiler.value = KilerState(
        pantryItems: [_pantryItem(id: 1, tag: 'domates'), _pantryItem(id: 2, tag: 'sogan')],
      );
      kiler.value = KilerState(
        pantryItems: [
          _pantryItem(id: 1, tag: 'domates'),
          _pantryItem(id: 2, tag: 'sogan'),
          _pantryItem(id: 3, tag: 'tavuk'),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(gateway.matchPantryCalls, equals(0));

      notifier.setRecipesTabActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(1));
    });

    test('loadMoreCloudRecipes does nothing when cloudHasMore is false', () async {
      final kiler = ValueNotifier<KilerState>(
        KilerState(pantryItems: [_pantryItem(id: 1, tag: 'domates')]),
      );
      final gateway = _CountingCloudGateway()..nextHasMore = false;
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => DateTime(2026, 11, 28, 12),
        autoLoad: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.matchPantryCalls, equals(1));
      expect(notifier.state.cloudHasMore, isFalse);

      await notifier.loadMoreCloudRecipes();
      expect(gateway.matchPantryCalls, equals(1));
    });

    test('builtin recipe photos retry on tab activation after failure and refresh after 12 hours', () async {
      final kiler = ValueNotifier<KilerState>(const KilerState());
      final gateway = _CountingCloudGateway()..returnEmptyMedia = true;
      DateTime now = DateTime(2026, 11, 28, 10, 0);
      final notifier = MealModuleNotifier(
        repository: _FakeMealModuleRepository(),
        loadActiveProfile: () async => null,
        kilerListenable: kiler,
        onBatchAddDrafts: (_) async => 0,
        onQuickConsume: (_, _) async => (updatedCount: 0, finishedCount: 0),
        onAddMissingToShopping: (_, _) async => 0,
        cloudGateway: gateway,
        nowProvider: () => now,
        autoLoad: false,
        isRecipesTabActive: false,
      );
      addTearDown(notifier.dispose);

      await notifier.loadAll();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.signMediaBatchCalls, equals(1));
      expect(notifier.state.builtinSignedImageUrls, isEmpty);

      // Network recovers -> switching to Recipes tab retries hydration
      gateway.returnEmptyMedia = false;
      notifier.setRecipesTabActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.signMediaBatchCalls, equals(2));
      expect(notifier.state.builtinSignedImageUrls, isNotEmpty);
      final firstSigned = notifier.state.builtinSignedImageUrls['menemen'];
      expect(firstSigned, contains('exp=2'));

      // Switching away and back within 12 hours does NOT re-sign
      notifier.setRecipesTabActive(false);
      now = now.add(const Duration(hours: 6));
      notifier.setRecipesTabActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.signMediaBatchCalls, equals(2));

      // After 12+ hours, re-opening Recipes tab refreshes signed URLs
      notifier.setRecipesTabActive(false);
      now = now.add(const Duration(hours: 7));
      notifier.setRecipesTabActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.signMediaBatchCalls, equals(3));
      expect(notifier.state.builtinSignedImageUrls['menemen'], contains('exp=3'));
    });
  });
}
