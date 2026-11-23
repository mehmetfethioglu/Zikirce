import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/meal_module_repository.dart';
import '../domain/recipe_models.dart';

typedef DatabaseProvider = Future<Database> Function();

/// SQLite-backed implementation of [MealModuleRepository] using parameterized SQL.
class SqliteMealModuleRepository implements MealModuleRepository {
  static const Duration _dbTimeout = Duration(seconds: 10);

  final DatabaseProvider _databaseProvider;

  SqliteMealModuleRepository({DatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => DatabaseHelper().database);

  Future<Database> get _db => _databaseProvider().timeout(_dbTimeout);

  @override
  Future<List<MealPlanEntry>> getEntriesForDateRange(
    String startDateIso,
    String endDateIso,
  ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'meal_plan_entries',
        where: 'plan_date >= ? AND plan_date <= ?',
        whereArgs: [startDateIso, endDateIso],
        orderBy: 'plan_date ASC, added_at ASC, id ASC',
      );
      return rows.map(MealPlanEntry.fromMap).toList();
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.getEntriesForDateRange error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> upsertMealPlanEntry(MealPlanEntry entry) async {
    try {
      final db = await _db;
      final int effectiveAddedAt =
          entry.addedAt > 0 ? entry.addedAt : DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> payload =
          entry.copyWith(addedAt: effectiveAddedAt).toMap();

      if (entry.id != null) {
        final updated = await db.update(
          'meal_plan_entries',
          payload,
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        if (updated > 0) return;
      }

      payload.remove('id');
      await db.insert(
        'meal_plan_entries',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.upsertMealPlanEntry error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> replaceWeekEntries(
    String startDateIso,
    String endDateIso,
    List<MealPlanEntry> entries,
  ) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.delete(
          'meal_plan_entries',
          where: 'plan_date >= ? AND plan_date <= ?',
          whereArgs: [startDateIso, endDateIso],
        );
        final int now = DateTime.now().millisecondsSinceEpoch;
        for (final entry in entries) {
          final int effectiveAddedAt = entry.addedAt > 0 ? entry.addedAt : now;
          final Map<String, dynamic> row =
              entry.copyWith(addedAt: effectiveAddedAt).toMap()..remove('id');
          await txn.insert(
            'meal_plan_entries',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.replaceWeekEntries error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> markEntryCooked(int entryId, {required bool isCooked}) async {
    try {
      final db = await _db;
      await db.update(
        'meal_plan_entries',
        {'is_cooked': isCooked ? 1 : 0},
        where: 'id = ?',
        whereArgs: [entryId],
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.markEntryCooked error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> deleteMealPlanEntry(int entryId) async {
    try {
      final db = await _db;
      await db.delete(
        'meal_plan_entries',
        where: 'id = ?',
        whereArgs: [entryId],
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.deleteMealPlanEntry error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> clearDateRange(String startDateIso, String endDateIso) async {
    try {
      final db = await _db;
      await db.delete(
        'meal_plan_entries',
        where: 'plan_date >= ? AND plan_date <= ?',
        whereArgs: [startDateIso, endDateIso],
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.clearDateRange error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'recipe_favorites',
        columns: ['recipe_id'],
        orderBy: 'saved_at DESC',
      );
      return rows
          .map((row) => row['recipe_id'])
          .whereType<String>()
          .toSet();
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.getFavoriteIds error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<bool> toggleFavorite(String recipeId) async {
    try {
      final db = await _db;
      return await db.transaction((txn) async {
        final existing = await txn.query(
          'recipe_favorites',
          columns: ['recipe_id'],
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await txn.delete(
            'recipe_favorites',
            where: 'recipe_id = ?',
            whereArgs: [recipeId],
          );
          return false;
        }
        await txn.insert(
          'recipe_favorites',
          {
            'recipe_id': recipeId,
            'saved_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      });
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.toggleFavorite error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<KilerRecipe>> getCustomRecipes() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'custom_recipes',
        orderBy: 'created_at DESC',
      );
      return rows.map(KilerRecipe.fromCustomDbMap).toList();
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.getCustomRecipes error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> saveCustomRecipe(KilerRecipe recipe) async {
    try {
      final db = await _db;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final KilerRecipe normalized = recipe.copyWith(isCustom: true);
      await db.insert(
        'custom_recipes',
        normalized.toCustomDbMap(now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.saveCustomRecipe error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomRecipe(String recipeId) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.delete(
          'custom_recipes',
          where: 'id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'meal_plan_entries',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'recipe_favorites',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'recipe_photo_overrides',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
      });
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.deleteCustomRecipe error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> logRecipeCooked({
    required String recipeId,
    required String recipeTitle,
    required int servings,
  }) async {
    try {
      final db = await _db;
      await db.insert('recipe_cook_log', {
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        'servings': servings <= 0 ? 1 : servings,
        'cooked_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.logRecipeCooked error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getCookCountsByRecipe() async {
    try {
      final db = await _db;
      final rows = await db.rawQuery(
        'SELECT recipe_id, COUNT(*) AS cook_count FROM recipe_cook_log GROUP BY recipe_id',
      );
      final Map<String, int> counts = {};
      for (final row in rows) {
        final String? recipeId = row['recipe_id'] as String?;
        final int count = (row['cook_count'] as num?)?.toInt() ?? 0;
        if (recipeId != null && recipeId.isNotEmpty) {
          counts[recipeId] = count;
        }
      }
      return counts;
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.getCookCountsByRecipe error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<MealCookLog>> getRecentCookLogs({int limit = 20}) async {
    try {
      final db = await _db;
      final int safeLimit = limit.clamp(1, 200);
      final rows = await db.query(
        'recipe_cook_log',
        orderBy: 'cooked_at DESC, id DESC',
        limit: safeLimit,
      );
      return rows.map(MealCookLog.fromMap).toList();
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.getRecentCookLogs error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<Map<String, SlotCheckInRecord>> getSlotCheckInsForDateRange(
    String startDateIso,
    String endDateIso,
  ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'meal_slot_checkins',
        where: 'plan_date >= ? AND plan_date <= ?',
        whereArgs: [startDateIso, endDateIso],
        orderBy: 'plan_date ASC, resolved_at DESC, id DESC',
      );
      final Map<String, SlotCheckInRecord> result = {};
      for (final row in rows) {
        final record = SlotCheckInRecord.fromMap(row);
        if (record.planDate.isNotEmpty) {
          result[record.slotKey] = record;
        }
      }
      return result;
    } catch (e, st) {
      debugPrint(
        'SqliteMealModuleRepository.getSlotCheckInsForDateRange error: $e\n$st',
      );
      rethrow;
    }
  }

  @override
  Future<void> upsertSlotCheckIn(SlotCheckInRecord record) async {
    try {
      final db = await _db;
      final int effectiveResolvedAt = record.resolvedAt > 0
          ? record.resolvedAt
          : DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> payload = SlotCheckInRecord(
        id: record.id,
        planDate: record.planDate,
        mealSlot: record.mealSlot,
        resolutionType: record.resolutionType,
        note: record.note,
        resolvedAt: effectiveResolvedAt,
      ).toMap();
      if (record.id == null) {
        payload.remove('id');
      }
      await db.insert(
        'meal_slot_checkins',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('SqliteMealModuleRepository.upsertSlotCheckIn error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> getRecipePhotoOverrides() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'recipe_photo_overrides',
        orderBy: 'updated_at DESC',
      );
      final Map<String, String> overrides = {};
      for (final row in rows) {
        final parsed = RecipePhotoOverride.fromMap(row);
        if (parsed.recipeId.isNotEmpty && parsed.localPath.isNotEmpty) {
          overrides[parsed.recipeId] = parsed.localPath;
        }
      }
      return overrides;
    } catch (e, st) {
      debugPrint(
        'SqliteMealModuleRepository.getRecipePhotoOverrides error: $e\n$st',
      );
      rethrow;
    }
  }

  @override
  Future<void> setRecipePhotoOverride(RecipePhotoOverride override) async {
    final String cleanId = override.recipeId.trim();
    final String cleanPath = override.localPath.trim();
    if (cleanId.isEmpty || cleanPath.isEmpty) return;

    try {
      final db = await _db;
      final int effectiveUpdatedAt = override.updatedAt > 0
          ? override.updatedAt
          : DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'recipe_photo_overrides',
        RecipePhotoOverride(
          recipeId: cleanId,
          localPath: cleanPath,
          updatedAt: effectiveUpdatedAt,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint(
        'SqliteMealModuleRepository.setRecipePhotoOverride error: $e\n$st',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeRecipePhotoOverride(String recipeId) async {
    final String cleanId = recipeId.trim();
    if (cleanId.isEmpty) return;

    try {
      final db = await _db;
      await db.delete(
        'recipe_photo_overrides',
        where: 'recipe_id = ?',
        whereArgs: [cleanId],
      );
    } catch (e, st) {
      debugPrint(
        'SqliteMealModuleRepository.removeRecipePhotoOverride error: $e\n$st',
      );
      rethrow;
    }
  }
}
