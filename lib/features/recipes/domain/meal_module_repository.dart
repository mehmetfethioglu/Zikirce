import 'recipe_models.dart';

/// DIP repository abstraction for weekly meal planning, favorites, cook logs, and custom recipes.
abstract interface class MealModuleRepository {
  Future<List<MealPlanEntry>> getEntriesForDateRange(
    String startDateIso,
    String endDateIso,
  );

  Future<void> upsertMealPlanEntry(MealPlanEntry entry);

  Future<void> replaceWeekEntries(
    String startDateIso,
    String endDateIso,
    List<MealPlanEntry> entries,
  );

  Future<void> markEntryCooked(int entryId, {required bool isCooked});

  Future<void> deleteMealPlanEntry(int entryId);

  Future<void> clearDateRange(String startDateIso, String endDateIso);

  Future<Set<String>> getFavoriteIds();

  Future<bool> toggleFavorite(String recipeId);

  Future<List<KilerRecipe>> getCustomRecipes();

  Future<void> saveCustomRecipe(KilerRecipe recipe);

  Future<void> deleteCustomRecipe(String recipeId);

  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required int servings,
  });

  Future<Map<String, int>> getCookCountsByRecipe();

  Future<List<MealCookLog>> getRecentCookLogs({int limit = 20});

  Future<Map<String, SlotCheckInRecord>> getSlotCheckInsForDateRange(
    String startDateIso,
    String endDateIso,
  );

  Future<void> upsertSlotCheckIn(SlotCheckInRecord record);

  Future<Map<String, String>> getRecipePhotoOverrides();

  Future<void> setRecipePhotoOverride(RecipePhotoOverride override);

  Future<void> removeRecipePhotoOverride(String recipeId);
}
