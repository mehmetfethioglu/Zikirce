import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'kiler_models.dart';

class KilerState {
  final List<PantryItem> pantryItems;
  final List<ShoppingListItem> shoppingItems;
  final bool isLoading;
  final String? errorMessage;

  const KilerState({
    this.pantryItems = const [],
    this.shoppingItems = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  KilerState copyWith({
    List<PantryItem>? pantryItems,
    List<ShoppingListItem>? shoppingItems,
    bool? isLoading,
    String? errorMessage,
  }) {
    return KilerState(
      pantryItems: pantryItems ?? this.pantryItems,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  Set<String> get availableTags =>
      pantryItems.map((e) => e.normalizedTag).toSet();

  Set<String> get expiringTags => pantryItems
      .where((e) => e.isExpiringSoon || e.isExpired)
      .map((e) => e.normalizedTag)
      .toSet();

  List<PantryItem> get expiringSoonItems {
    final list = pantryItems
        .where((e) => e.isExpiringSoon || e.isExpired)
        .toList();
    list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return list;
  }

  List<PantryItem> get longWaitingItems {
    final list = pantryItems.where((e) => e.isLongWaiting).toList();
    list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return list;
  }

  List<PantryItem> get rescueCandidateItems {
    final list = pantryItems.where((e) => e.needsWasteRescue).toList();
    list.sort((a, b) {
      final scoreCmp = b.rescuePriorityScore.compareTo(a.rescuePriorityScore);
      if (scoreCmp != 0) return scoreCmp;
      return a.expiresAt.compareTo(b.expiresAt);
    });
    return list;
  }

  int get averageHealthScore {
    if (pantryItems.isEmpty) return 90;
    final validScores = pantryItems
        .map((e) => e.healthScore)
        .where((s) => s > 0)
        .toList();
    if (validScores.isEmpty) return 90;
    final sum = validScores.reduce((a, b) => a + b);
    return (sum / validScores.length).round();
  }

  List<PantryItem> itemsForZone(StorageZone? zone) {
    if (zone == null) return pantryItems;
    return pantryItems.where((e) => e.storageZone == zone).toList();
  }
}

class KilerService extends ValueNotifier<KilerState> {
  static final KilerService instance = KilerService._internal();
  KilerService._internal() : super(const KilerState());

  static const int _dayMs = 86400000;

  Future<void> loadAll() async {
    value = value.copyWith(isLoading: true, errorMessage: null);
    try {
      final db = await DatabaseHelper().database;
      final pantryRows = await db.query(
        'pantry_items',
        orderBy: 'expires_at ASC, added_at DESC',
      );
      final shoppingRows = await db.query(
        'shopping_list',
        orderBy: 'is_checked ASC, added_at DESC',
      );

      value = KilerState(
        pantryItems: pantryRows.map(PantryItem.fromMap).toList(),
        shoppingItems: shoppingRows.map(ShoppingListItem.fromMap).toList(),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('KilerService.loadAll error: $e');
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Kiler verileri yüklenemedi: $e',
      );
    }
  }

  Future<void> addQuickTemplate(
    QuickIngredientTemplate tpl, {
    StorageZone? customZone,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final zone = customZone ?? tpl.defaultZone;
    final int shelfDays = zone == StorageZone.freezer
        ? 90
        : tpl.defaultShelfDays;

    await upsertPantryItem(
      PantryItem(
        name: tpl.name,
        normalizedTag: tpl.tag,
        brand: 'Mutfak',
        category: tpl.category,
        storageZone: zone,
        quantityLevel: QuantityLevel.full,
        unitLabel: tpl.defaultUnit,
        healthScore: tpl.defaultHealthScore,
        addedAt: now,
        expiresAt: now + (shelfDays * _dayMs),
      ),
    );
  }

  Future<void> addScannedProduct({
    required String name,
    required String brand,
    String? barcode,
    required int healthScore,
    StorageZone? overrideZone,
    String? unitLabel,
  }) async {
    final resolved = IngredientNormalizer.resolveMetadata(
      name,
      healthScore: healthScore > 0 ? healthScore : 75,
    );
    final zone = overrideZone ?? resolved.defaultZone;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int shelfDays = zone == StorageZone.freezer
        ? 90
        : resolved.defaultShelfDays;

    await upsertPantryItem(
      PantryItem(
        barcode: barcode,
        name: name,
        normalizedTag: resolved.tag,
        brand: brand.isEmpty ? 'Markalı Ürün' : brand,
        category: resolved.category,
        storageZone: zone,
        quantityLevel: QuantityLevel.full,
        unitLabel: unitLabel ?? resolved.defaultUnit,
        healthScore: healthScore > 0 ? healthScore : resolved.defaultHealthScore,
        addedAt: now,
        expiresAt: now + (shelfDays * _dayMs),
      ),
    );
  }

  Future<void> upsertPantryItem(PantryItem item) async {
    try {
      final db = await DatabaseHelper().database;
      await _upsertPantryItemDb(db, item);
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.upsertPantryItem error: $e');
      value = value.copyWith(errorMessage: 'Ürün kilere kaydedilemedi: $e');
    }
  }

  /// Inserts or updates a batch of unbarcoded pantry drafts in a single DB transaction.
  Future<int> addBatchDraftItems(List<DraftPantryAddition> items) async {
    if (items.isEmpty) return 0;

    try {
      final db = await DatabaseHelper().database;
      final int now = DateTime.now().millisecondsSinceEpoch;
      int processedCount = 0;

      await db.transaction((txn) async {
        for (final draft in items) {
          if (draft.tag.trim().isEmpty || draft.name.trim().isEmpty) continue;
          final PantryItem pantryItem = draft.toPantryItem(nowMs: now);
          await _upsertPantryItemDb(txn, pantryItem);
          processedCount++;
        }
      });

      await loadAll();
      return processedCount;
    } catch (e) {
      debugPrint('KilerService.addBatchDraftItems error: $e');
      value = value.copyWith(
        errorMessage: 'Toplu kiler ürünleri kaydedilemedi: $e',
      );
      return 0;
    }
  }

  Future<void> _upsertPantryItemDb(
    DatabaseExecutor db,
    PantryItem item,
  ) async {
    final existing = await db.query(
      'pantry_items',
      where: 'normalized_tag = ? AND storage_zone = ?',
      whereArgs: [item.normalizedTag, item.storageZone.dbCode],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        'pantry_items',
        item.copyWith(id: existingId, quantityLevel: QuantityLevel.full).toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return;
    }

    await db.insert(
      'pantry_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateQuantityLevel(PantryItem item, QuantityLevel newLevel) async {
    if (item.id == null) return;
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'pantry_items',
        {'quantity_level': newLevel.dbCode},
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.updateQuantityLevel error: $e');
      value = value.copyWith(errorMessage: 'Miktar güncellenemedi: $e');
    }
  }

  Future<void> updateStorageZone(PantryItem item, StorageZone newZone) async {
    if (item.id == null) return;
    try {
      final db = await DatabaseHelper().database;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final resolved = IngredientNormalizer.resolveMetadata(item.name);
      final int newDays = newZone == StorageZone.freezer
          ? 90
          : resolved.defaultShelfDays;

      await db.update(
        'pantry_items',
        {
          'storage_zone': newZone.dbCode,
          'expires_at': now + (newDays * _dayMs),
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.updateStorageZone error: $e');
      value = value.copyWith(errorMessage: 'Saklama alanı güncellenemedi: $e');
    }
  }

  Future<void> markItemFinished(
    PantryItem item, {
    bool addToShoppingList = true,
  }) async {
    if (item.id == null) return;
    try {
      final db = await DatabaseHelper().database;
      await db.delete('pantry_items', where: 'id = ?', whereArgs: [item.id]);
      if (addToShoppingList) {
        await _insertShoppingItemDb(
          db,
          name: item.name,
          normalizedTag: item.normalizedTag,
          category: item.category,
          sourceNote: '${item.storageZone.label}nda bitti',
        );
      }
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.markItemFinished error: $e');
      value = value.copyWith(errorMessage: 'Ürün durumu güncellenemedi: $e');
    }
  }

  Future<void> deletePantryItem(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.deletePantryItem error: $e');
      value = value.copyWith(errorMessage: 'Ürün silinemedi: $e');
    }
  }

  /// Deducts ingredients used in a cooked recipe and moves depleted ones to shopping list.
  Future<({int updatedCount, int finishedCount})> consumeRecipeIngredients(
    List<String> usedTags,
    String recipeTitle,
  ) async {
    int updatedCount = 0;
    int finishedCount = 0;

    try {
      final db = await DatabaseHelper().database;
      for (final tag in usedTags) {
        final matches = value.pantryItems
            .where((p) => p.normalizedTag == tag && p.id != null)
            .toList();
        if (matches.isEmpty) continue;

        final item = matches.first;
        if (item.quantityLevel == QuantityLevel.low) {
          await db.delete('pantry_items', where: 'id = ?', whereArgs: [item.id]);
          await _insertShoppingItemDb(
            db,
            name: item.name,
            normalizedTag: item.normalizedTag,
            category: item.category,
            sourceNote: '$recipeTitle pişirilince bitti',
          );
          finishedCount++;
        } else {
          final nextLevel = item.quantityLevel.nextStepDown;
          await db.update(
            'pantry_items',
            {'quantity_level': nextLevel.dbCode},
            where: 'id = ?',
            whereArgs: [item.id],
          );
          updatedCount++;
        }
      }
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.consumeRecipeIngredients error: $e');
      value = value.copyWith(errorMessage: 'Tarif malzemeleri stoktan düşülemedi: $e');
    }

    return (updatedCount: updatedCount, finishedCount: finishedCount);
  }

  /// Records quick meal consumption actions in a single transaction, moving finished or low items to shopping list.
  Future<({int updatedCount, int finishedCount})> recordQuickConsumption(
    Map<int, QuantityConsumptionAction> actionsByItemId, {
    String reasonNote = 'Öğün tüketimi',
  }) async {
    if (actionsByItemId.isEmpty) {
      return (updatedCount: 0, finishedCount: 0);
    }

    int updatedCount = 0;
    int finishedCount = 0;
    final String cleanNote =
        reasonNote.trim().isEmpty ? 'Öğün tüketimi' : reasonNote.trim();

    try {
      final db = await DatabaseHelper().database;
      await db.transaction((txn) async {
        for (final entry in actionsByItemId.entries) {
          final int itemId = entry.key;
          final QuantityConsumptionAction action = entry.value;
          final rows = await txn.query(
            'pantry_items',
            where: 'id = ?',
            whereArgs: [itemId],
            limit: 1,
          );
          if (rows.isEmpty) continue;
          final item = PantryItem.fromMap(rows.first);

          if (action == QuantityConsumptionAction.finished ||
              item.quantityLevel == QuantityLevel.low) {
            await txn.delete(
              'pantry_items',
              where: 'id = ?',
              whereArgs: [itemId],
            );
            await _insertShoppingItemDb(
              txn,
              name: item.name,
              normalizedTag: item.normalizedTag,
              category: item.category,
              sourceNote: cleanNote,
            );
            finishedCount++;
          } else {
            final nextLevel = item.quantityLevel.nextStepDown;
            await txn.update(
              'pantry_items',
              {'quantity_level': nextLevel.dbCode},
              where: 'id = ?',
              whereArgs: [itemId],
            );
            updatedCount++;
          }
        }
      });

      await loadAll();
      return (updatedCount: updatedCount, finishedCount: finishedCount);
    } catch (e) {
      debugPrint('KilerService.recordQuickConsumption error: $e');
      value = value.copyWith(errorMessage: 'Hızlı tüketim kaydedilemedi: $e');
      return (updatedCount: 0, finishedCount: 0);
    }
  }

  Future<void> addShoppingItem({
    required String name,
    String? sourceNote,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    try {
      final db = await DatabaseHelper().database;
      final resolved = IngredientNormalizer.resolveMetadata(cleanName);
      await _insertShoppingItemDb(
        db,
        name: cleanName,
        normalizedTag: resolved.tag,
        category: resolved.category,
        sourceNote: sourceNote ?? 'Manuel eklendi',
      );
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.addShoppingItem error: $e');
      value = value.copyWith(errorMessage: 'Alışveriş listesine eklenemedi: $e');
    }
  }

  Future<int> addMissingRecipeIngredientsToShopping(
    List<String> missingTags,
    String recipeTitle,
  ) async {
    if (missingTags.isEmpty) return 0;
    int added = 0;
    try {
      final db = await DatabaseHelper().database;
      for (final tag in missingTags) {
        final displayName = QuickIngredientCatalog.displayNameForTag(tag);
        final resolved = IngredientNormalizer.resolveMetadata(displayName);
        await _insertShoppingItemDb(
          db,
          name: resolved.name,
          normalizedTag: tag,
          category: resolved.category,
          sourceNote: '$recipeTitle tarifi için eksik',
        );
        added++;
      }
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.addMissingRecipeIngredientsToShopping error: $e');
      value = value.copyWith(errorMessage: 'Eksik malzemeler listeye eklenemedi: $e');
    }
    return added;
  }

  Future<void> _insertShoppingItemDb(
    DatabaseExecutor db, {
    required String name,
    required String normalizedTag,
    required String category,
    required String sourceNote,
  }) async {
    final existing = await db.query(
      'shopping_list',
      where: 'normalized_tag = ?',
      whereArgs: [normalizedTag],
      limit: 1,
    );
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (existing.isNotEmpty) {
      await db.update(
        'shopping_list',
        {
          'is_checked': 0,
          'source_note': sourceNote,
          'added_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    await db.insert('shopping_list', {
      'name': name,
      'normalized_tag': normalizedTag,
      'category': category,
      'is_checked': 0,
      'source_note': sourceNote,
      'added_at': now,
    });
  }

  /// Transfers a purchased shopping list item directly into the pantry with smart defaults.
  Future<void> moveShoppingItemToPantry(ShoppingListItem item) async {
    try {
      final db = await DatabaseHelper().database;
      if (item.id != null) {
        await db.delete('shopping_list', where: 'id = ?', whereArgs: [item.id]);
      }

      final resolved = IngredientNormalizer.resolveMetadata(item.name);
      final int now = DateTime.now().millisecondsSinceEpoch;

      await upsertPantryItem(
        PantryItem(
          name: item.name,
          normalizedTag: item.normalizedTag,
          brand: 'Market Alışverişi',
          category: item.category,
          storageZone: resolved.defaultZone,
          quantityLevel: QuantityLevel.full,
          unitLabel: resolved.defaultUnit,
          healthScore: resolved.defaultHealthScore,
          addedAt: now,
          expiresAt: now + (resolved.defaultShelfDays * _dayMs),
        ),
      );
    } catch (e) {
      debugPrint('KilerService.moveShoppingItemToPantry error: $e');
      value = value.copyWith(errorMessage: 'Ürün kilere aktarılamadı: $e');
    }
  }

  Future<void> deleteShoppingItem(int id) async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('shopping_list', where: 'id = ?', whereArgs: [id]);
      await loadAll();
    } catch (e) {
      debugPrint('KilerService.deleteShoppingItem error: $e');
      value = value.copyWith(errorMessage: 'Liste öğesi silinemedi: $e');
    }
  }
}
