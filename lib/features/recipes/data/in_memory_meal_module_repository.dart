import '../domain/meal_module_repository.dart';
import '../domain/recipe_models.dart';

/// LSP-compliant in-memory implementation of [MealModuleRepository] for unit/widget tests.
class InMemoryMealModuleRepository implements MealModuleRepository {
  final List<MealPlanEntry> _entries = [];
  final Set<String> _favoriteIds = {};
  final Map<String, KilerRecipe> _customRecipes = {};
  final List<MealCookLog> _cookLogs = [];
  final Map<String, SlotCheckInRecord> _slotCheckIns = {};
  final Map<String, String> _photoOverrides = {};

  int _nextEntryId = 1;
  int _nextCookLogId = 1;
  int _nextCheckInId = 1;

  InMemoryMealModuleRepository({
    List<MealPlanEntry>? initialEntries,
    Set<String>? initialFavorites,
    List<KilerRecipe>? initialCustomRecipes,
    List<MealCookLog>? initialCookLogs,
    List<SlotCheckInRecord>? initialSlotCheckIns,
    Map<String, String>? initialPhotoOverrides,
  }) {
    if (initialEntries != null) {
      for (final entry in initialEntries) {
        final assignedId = entry.id ?? _nextEntryId++;
        if (assignedId >= _nextEntryId) {
          _nextEntryId = assignedId + 1;
        }
        _entries.add(entry.copyWith(id: assignedId));
      }
    }
    if (initialFavorites != null) {
      _favoriteIds.addAll(initialFavorites);
    }
    if (initialCustomRecipes != null) {
      for (final recipe in initialCustomRecipes) {
        _customRecipes[recipe.id] = recipe.copyWith(isCustom: true);
      }
    }
    if (initialCookLogs != null) {
      for (final log in initialCookLogs) {
        final assignedId = log.id ?? _nextCookLogId++;
        if (assignedId >= _nextCookLogId) {
          _nextCookLogId = assignedId + 1;
        }
        _cookLogs.add(
          MealCookLog(
            id: assignedId,
            recipeId: log.recipeId,
            recipeTitle: log.recipeTitle,
            servings: log.servings,
            cookedAt: log.cookedAt,
          ),
        );
      }
    }
    if (initialSlotCheckIns != null) {
      for (final record in initialSlotCheckIns) {
        final assignedId = record.id ?? _nextCheckInId++;
        if (assignedId >= _nextCheckInId) {
          _nextCheckInId = assignedId + 1;
        }
        _slotCheckIns[record.slotKey] = SlotCheckInRecord(
          id: assignedId,
          planDate: record.planDate,
          mealSlot: record.mealSlot,
          resolutionType: record.resolutionType,
          note: record.note,
          resolvedAt: record.resolvedAt,
        );
      }
    }
    if (initialPhotoOverrides != null) {
      for (final entry in initialPhotoOverrides.entries) {
        final cleanId = entry.key.trim();
        final cleanPath = entry.value.trim();
        if (cleanId.isNotEmpty && cleanPath.isNotEmpty) {
          _photoOverrides[cleanId] = cleanPath;
        }
      }
    }
  }

  @override
  Future<List<MealPlanEntry>> getEntriesForDateRange(
    String startDateIso,
    String endDateIso,
  ) async {
    final matching = _entries
        .where(
          (e) =>
              e.planDate.compareTo(startDateIso) >= 0 &&
              e.planDate.compareTo(endDateIso) <= 0,
        )
        .toList();
    matching.sort((a, b) {
      final dateCmp = a.planDate.compareTo(b.planDate);
      if (dateCmp != 0) return dateCmp;
      final addedCmp = a.addedAt.compareTo(b.addedAt);
      if (addedCmp != 0) return addedCmp;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return matching;
  }

  @override
  Future<void> upsertMealPlanEntry(MealPlanEntry entry) async {
    final int effectiveAddedAt =
        entry.addedAt > 0 ? entry.addedAt : DateTime.now().millisecondsSinceEpoch;

    if (entry.id != null) {
      final byIdIdx = _entries.indexWhere((e) => e.id == entry.id);
      if (byIdIdx != -1) {
        _entries[byIdIdx] = entry.copyWith(addedAt: effectiveAddedAt);
        return;
      }
    }

    // Mirror UNIQUE(plan_date, meal_slot, recipe_id) constraint from SQLite.
    _entries.removeWhere(
      (e) =>
          e.planDate == entry.planDate &&
          e.mealSlot == entry.mealSlot &&
          e.recipeId == entry.recipeId,
    );

    final int assignedId = entry.id ?? _nextEntryId++;
    if (assignedId >= _nextEntryId) {
      _nextEntryId = assignedId + 1;
    }
    _entries.add(entry.copyWith(id: assignedId, addedAt: effectiveAddedAt));
  }

  @override
  Future<void> replaceWeekEntries(
    String startDateIso,
    String endDateIso,
    List<MealPlanEntry> entries,
  ) async {
    _entries.removeWhere(
      (e) =>
          e.planDate.compareTo(startDateIso) >= 0 &&
          e.planDate.compareTo(endDateIso) <= 0,
    );
    for (final entry in entries) {
      final int assignedId = _nextEntryId++;
      final int effectiveAddedAt =
          entry.addedAt > 0 ? entry.addedAt : DateTime.now().millisecondsSinceEpoch;
      _entries.removeWhere(
        (e) =>
            e.planDate == entry.planDate &&
            e.mealSlot == entry.mealSlot &&
            e.recipeId == entry.recipeId,
      );
      _entries.add(entry.copyWith(id: assignedId, addedAt: effectiveAddedAt));
    }
  }

  @override
  Future<void> markEntryCooked(int entryId, {required bool isCooked}) async {
    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(isCooked: isCooked);
  }

  @override
  Future<void> deleteMealPlanEntry(int entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
  }

  @override
  Future<void> clearDateRange(String startDateIso, String endDateIso) async {
    _entries.removeWhere(
      (e) =>
          e.planDate.compareTo(startDateIso) >= 0 &&
          e.planDate.compareTo(endDateIso) <= 0,
    );
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    return Set<String>.from(_favoriteIds);
  }

  @override
  Future<bool> toggleFavorite(String recipeId) async {
    if (_favoriteIds.remove(recipeId)) {
      return false;
    }
    _favoriteIds.add(recipeId);
    return true;
  }

  @override
  Future<List<KilerRecipe>> getCustomRecipes() async {
    return _customRecipes.values.toList().reversed.toList();
  }

  @override
  Future<void> saveCustomRecipe(KilerRecipe recipe) async {
    _customRecipes[recipe.id] = recipe.copyWith(isCustom: true);
  }

  @override
  Future<void> deleteCustomRecipe(String recipeId) async {
    _customRecipes.remove(recipeId);
    _entries.removeWhere((e) => e.recipeId == recipeId);
    _favoriteIds.remove(recipeId);
    _photoOverrides.remove(recipeId);
  }

  @override
  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required int servings,
  }) async {
    _cookLogs.add(
      MealCookLog(
        id: _nextCookLogId++,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        servings: servings <= 0 ? 1 : servings,
        cookedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<Map<String, int>> getCookCountsByRecipe() async {
    final Map<String, int> counts = {};
    for (final log in _cookLogs) {
      counts[log.recipeId] = (counts[log.recipeId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<MealCookLog>> getRecentCookLogs({int limit = 20}) async {
    final safeLimit = limit.clamp(1, 200);
    final sorted = List<MealCookLog>.from(_cookLogs)
      ..sort((a, b) {
        final timeCmp = b.cookedAt.compareTo(a.cookedAt);
        if (timeCmp != 0) return timeCmp;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
    return sorted.take(safeLimit).toList();
  }

  @override
  Future<Map<String, SlotCheckInRecord>> getSlotCheckInsForDateRange(
    String startDateIso,
    String endDateIso,
  ) async {
    final Map<String, SlotCheckInRecord> result = {};
    for (final record in _slotCheckIns.values) {
      if (record.planDate.compareTo(startDateIso) >= 0 &&
          record.planDate.compareTo(endDateIso) <= 0) {
        result[record.slotKey] = record;
      }
    }
    return result;
  }

  @override
  Future<void> upsertSlotCheckIn(SlotCheckInRecord record) async {
    final int effectiveResolvedAt = record.resolvedAt > 0
        ? record.resolvedAt
        : DateTime.now().millisecondsSinceEpoch;
    final int assignedId =
        record.id ?? _slotCheckIns[record.slotKey]?.id ?? _nextCheckInId++;
    if (assignedId >= _nextCheckInId) {
      _nextCheckInId = assignedId + 1;
    }
    _slotCheckIns[record.slotKey] = SlotCheckInRecord(
      id: assignedId,
      planDate: record.planDate,
      mealSlot: record.mealSlot,
      resolutionType: record.resolutionType,
      note: record.note,
      resolvedAt: effectiveResolvedAt,
    );
  }

  @override
  Future<Map<String, String>> getRecipePhotoOverrides() async {
    return Map<String, String>.from(_photoOverrides);
  }

  @override
  Future<void> setRecipePhotoOverride(RecipePhotoOverride override) async {
    final String cleanId = override.recipeId.trim();
    final String cleanPath = override.localPath.trim();
    if (cleanId.isEmpty || cleanPath.isEmpty) return;
    _photoOverrides[cleanId] = cleanPath;
  }

  @override
  Future<void> removeRecipePhotoOverride(String recipeId) async {
    final String cleanId = recipeId.trim();
    if (cleanId.isEmpty) return;
    _photoOverrides.remove(cleanId);
  }
}
