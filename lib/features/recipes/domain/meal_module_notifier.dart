import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../kiler/domain/kiler_models.dart';
import '../../kiler/domain/kiler_service.dart';
import '../data/sqlite_meal_module_repository.dart';
import 'meal_lifecycle_assistant.dart';
import 'meal_module_repository.dart';
import 'meal_plan_generator.dart';
import 'recipe_recommendation_engine.dart';

typedef ActiveProfileLoader = Future<FamilyProfile?> Function();
typedef PantryIngredientConsumer = Future<void> Function(
  List<String> usedTags,
  String recipeTitle,
);
typedef BatchPantryDraftAdder = Future<int> Function(
  List<DraftPantryAddition> items,
);
typedef QuickPantryConsumer = Future<({int updatedCount, int finishedCount})>
    Function(
  Map<int, QuantityConsumptionAction> actionsByItemId,
  String reasonNote,
);
typedef MissingShoppingAdder = Future<int> Function(
  List<String> missingTags,
  String sourceLabel,
);
typedef NowProvider = DateTime Function();

/// DIP provider for the meal module persistence repository.
final mealModuleRepositoryProvider = Provider<MealModuleRepository>((ref) {
  return SqliteMealModuleRepository();
});

/// DIP provider for resolving the currently active family nutrition profile.
final activeProfileLoaderProvider = Provider<ActiveProfileLoader>((ref) {
  return FamilyProfileEngine.getActiveProfile;
});

/// Reactive Riverpod controller provider for Yemek & Haftalık Plan module.
final mealModuleNotifierProvider =
    StateNotifierProvider<MealModuleNotifier, MealModuleState>((ref) {
  final repository = ref.watch(mealModuleRepositoryProvider);
  final activeProfileLoader = ref.watch(activeProfileLoaderProvider);
  return MealModuleNotifier(
    repository: repository,
    loadActiveProfile: activeProfileLoader,
    kilerListenable: KilerService.instance,
    onConsumeIngredients: (tags, title) =>
        KilerService.instance.consumeRecipeIngredients(tags, title),
    onBatchAddDrafts: KilerService.instance.addBatchDraftItems,
    onQuickConsume: (actions, note) =>
        KilerService.instance.recordQuickConsumption(actions, reasonNote: note),
    onAddMissingToShopping:
        KilerService.instance.addMissingRecipeIngredientsToShopping,
  );
});

/// Coordinates pantry changes, active profile restrictions, recipe filtering, and weekly meal planning.
class MealModuleNotifier extends StateNotifier<MealModuleState> {
  final MealModuleRepository _repository;
  final ActiveProfileLoader _loadActiveProfile;
  final ValueListenable<KilerState> _kilerListenable;
  final PantryIngredientConsumer? _onConsumeIngredients;
  final BatchPantryDraftAdder _onBatchAddDrafts;
  final QuickPantryConsumer _onQuickConsume;
  final MissingShoppingAdder _onAddMissingToShopping;
  final NowProvider _nowProvider;

  List<MealPlanEntry> _lifecycleEntries = const [];

  MealModuleNotifier({
    required this._repository,
    required this._loadActiveProfile,
    ValueListenable<KilerState>? kilerListenable,
    this._onConsumeIngredients,
    BatchPantryDraftAdder? onBatchAddDrafts,
    QuickPantryConsumer? onQuickConsume,
    MissingShoppingAdder? onAddMissingToShopping,
    NowProvider? nowProvider,
    DateTime? initialNow,
    bool autoLoad = true,
  })  : _kilerListenable = kilerListenable ?? KilerService.instance,
        _onBatchAddDrafts =
            onBatchAddDrafts ?? KilerService.instance.addBatchDraftItems,
        _onQuickConsume = onQuickConsume ??
            ((actions, note) => KilerService.instance.recordQuickConsumption(
                  actions,
                  reasonNote: note,
                )),
        _onAddMissingToShopping = onAddMissingToShopping ??
            KilerService.instance.addMissingRecipeIngredientsToShopping,
        _nowProvider = nowProvider ??
            (initialNow != null ? () => initialNow : DateTime.now),
        super(
          _createInitialState(
            kilerState: (kilerListenable ?? KilerService.instance).value,
            now: initialNow ?? nowProvider?.call(),
          ),
        ) {
    _kilerListenable.addListener(_onKilerChanged);
    if (autoLoad) {
      Future.microtask(loadAll);
    }
  }

  static MealModuleState _createInitialState({
    required KilerState kilerState,
    DateTime? now,
  }) {
    final base = MealModuleState.initial(now: now);
    final recipeById = RecipeRecommendationEngine.buildRecipeIndex();
    final matches = RecipeRecommendationEngine.evaluateAll(
      pantryItems: kilerState.pantryItems,
      filter: base.selectedFilter,
      searchQuery: base.searchQuery,
      category: base.selectedCategory,
      region: base.selectedRegion,
    );
    final wasteRescue = RecipeRecommendationEngine.topWasteRescueRecipes(
      pantryItems: kilerState.pantryItems,
    );
    return base.copyWith(
      recipeById: recipeById,
      evaluatedMatches: matches,
      wasteRescueMatches: wasteRescue,
    );
  }

  void _onKilerChanged() {
    if (!mounted) return;
    _commitDerivedState(state);
  }

  @override
  void dispose() {
    _kilerListenable.removeListener(_onKilerChanged);
    super.dispose();
  }

  /// Loads persisted week plan, lifecycle check-ins, photo overrides, favorites, custom recipes, cook counts, and active profile.
  Future<void> loadAll() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final (startIso, endIso) = _weekBounds(state.currentWeekMondayIso);
      final (lifecycleStartIso, lifecycleEndIso) =
          _lifecycleBounds(startIso, endIso);

      final results = await Future.wait<dynamic>([
        _loadActiveProfile(),
        _repository.getFavoriteIds(),
        _repository.getCustomRecipes(),
        _repository.getCookCountsByRecipe(),
        _repository.getEntriesForDateRange(lifecycleStartIso, lifecycleEndIso),
        _repository.getSlotCheckInsForDateRange(
          lifecycleStartIso,
          lifecycleEndIso,
        ),
        _repository.getRecipePhotoOverrides(),
      ]);

      if (!mounted) return;

      final FamilyProfile? profile = results[0] as FamilyProfile?;
      final Set<String> favoriteIds = results[1] as Set<String>;
      final List<KilerRecipe> customRecipes = results[2] as List<KilerRecipe>;
      final Map<String, int> cookCounts = results[3] as Map<String, int>;
      final List<MealPlanEntry> allEntries = results[4] as List<MealPlanEntry>;
      final Map<String, SlotCheckInRecord> checkIns =
          results[5] as Map<String, SlotCheckInRecord>;
      final Map<String, String> photoOverrides =
          results[6] as Map<String, String>;

      _lifecycleEntries = allEntries;
      final List<MealPlanEntry> weekEntries =
          _filterWeekEntries(allEntries, startIso, endIso);

      final nextState = state.copyWith(
        activeProfile: profile,
        clearActiveProfile: profile == null,
        favoriteIds: favoriteIds,
        customRecipes: customRecipes,
        cookCounts: cookCounts,
        weekEntries: weekEntries,
        slotCheckIns: checkIns,
        recipePhotoOverrides: photoOverrides,
        isLoading: false,
        clearErrorMessage: true,
      );
      _commitDerivedState(nextState);
    } catch (e, st) {
      debugPrint('MealModuleNotifier.loadAll error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Yemek modülü verileri yüklenemedi: $e',
      );
    }
  }

  Future<void> reloadProfile() async {
    try {
      final profile = await _loadActiveProfile();
      if (!mounted) return;
      _commitDerivedState(
        state.copyWith(
          activeProfile: profile,
          clearActiveProfile: profile == null,
          clearErrorMessage: true,
        ),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.reloadProfile error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Aile profili güncellenemedi: $e',
      );
    }
  }

  void setMode(YemekModuleMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode, clearErrorMessage: true);
  }

  void setFilter(RecipeFilterTab filter) {
    if (state.selectedFilter == filter) return;
    _commitDerivedState(state.copyWith(selectedFilter: filter));
  }

  void setCategory(String? category) {
    final bool shouldClear =
        category == null || category.isEmpty || category == state.selectedCategory;
    _commitDerivedState(
      state.copyWith(
        selectedCategory: shouldClear ? null : category,
        clearSelectedCategory: shouldClear,
      ),
    );
  }

  void setRegion(String? regionId) {
    final bool shouldClear = regionId == null ||
        regionId.isEmpty ||
        regionId == TurkishRegionRegistry.all;
    final String? targetRegion = shouldClear ? null : regionId;
    if (state.selectedRegion == targetRegion) return;
    _commitDerivedState(
      state.copyWith(
        selectedRegion: targetRegion,
        clearSelectedRegion: shouldClear,
      ),
    );
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    _commitDerivedState(state.copyWith(searchQuery: query));
  }

  void setPreset(MealPlanPreset preset) {
    if (state.selectedPreset == preset) return;
    state = state.copyWith(selectedPreset: preset);
  }

  void setPlanServings(int servings) {
    final clamped = servings.clamp(1, 12);
    if (state.planServings == clamped) return;
    state = state.copyWith(planServings: clamped);
  }

  void toggleFullWeekOverview() {
    state = state.copyWith(showFullWeekOverview: !state.showFullWeekOverview);
  }

  void setFullWeekOverview(bool value) {
    if (state.showFullWeekOverview == value) return;
    state = state.copyWith(showFullWeekOverview: value);
  }

  Future<void> selectDate(String dateIso) async {
    final DateTime parsed = MealDateUtils.fromIsoDate(dateIso);
    final String mondayIso =
        MealDateUtils.toIsoDate(MealDateUtils.startOfWeekMonday(parsed));

    if (mondayIso == state.currentWeekMondayIso) {
      state = state.copyWith(selectedDateIso: dateIso);
      return;
    }

    await _loadWeek(mondayIso: mondayIso, selectedDateIso: dateIso);
  }

  Future<void> previousWeek() async {
    final DateTime currentMonday =
        MealDateUtils.fromIsoDate(state.currentWeekMondayIso);
    final DateTime prevMonday = currentMonday.subtract(const Duration(days: 7));
    final String prevIso = MealDateUtils.toIsoDate(prevMonday);
    await _loadWeek(mondayIso: prevIso, selectedDateIso: prevIso);
  }

  Future<void> nextWeek() async {
    final DateTime currentMonday =
        MealDateUtils.fromIsoDate(state.currentWeekMondayIso);
    final DateTime nextMonday = currentMonday.add(const Duration(days: 7));
    final String nextIso = MealDateUtils.toIsoDate(nextMonday);
    await _loadWeek(mondayIso: nextIso, selectedDateIso: nextIso);
  }

  Future<void> selectWeek(DateTime anyDateInWeek) async {
    final DateTime monday = MealDateUtils.startOfWeekMonday(anyDateInWeek);
    final String mondayIso = MealDateUtils.toIsoDate(monday);
    final String selectedIso = MealDateUtils.toIsoDate(anyDateInWeek);
    await _loadWeek(mondayIso: mondayIso, selectedDateIso: selectedIso);
  }

  Future<void> _loadWeek({
    required String mondayIso,
    required String selectedDateIso,
  }) async {
    state = state.copyWith(
      currentWeekMondayIso: mondayIso,
      selectedDateIso: selectedDateIso,
      isLoading: true,
      clearErrorMessage: true,
    );
    try {
      final (startIso, endIso) = _weekBounds(mondayIso);
      final (lifecycleStartIso, lifecycleEndIso) =
          _lifecycleBounds(startIso, endIso);

      final results = await Future.wait<dynamic>([
        _repository.getEntriesForDateRange(lifecycleStartIso, lifecycleEndIso),
        _repository.getSlotCheckInsForDateRange(
          lifecycleStartIso,
          lifecycleEndIso,
        ),
      ]);
      if (!mounted) return;

      final List<MealPlanEntry> allEntries = results[0] as List<MealPlanEntry>;
      final Map<String, SlotCheckInRecord> checkIns =
          results[1] as Map<String, SlotCheckInRecord>;

      _lifecycleEntries = allEntries;
      final List<MealPlanEntry> weekEntries =
          _filterWeekEntries(allEntries, startIso, endIso);

      _commitDerivedState(
        state.copyWith(
          weekEntries: weekEntries,
          slotCheckIns: checkIns,
          isLoading: false,
        ),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier._loadWeek error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Haftalık plan yüklenemedi: $e',
      );
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    try {
      final bool isNowFav = await _repository.toggleFavorite(recipeId);
      if (!mounted) return;
      final Set<String> updatedFavs = Set<String>.from(state.favoriteIds);
      if (isNowFav) {
        updatedFavs.add(recipeId);
      } else {
        updatedFavs.remove(recipeId);
      }
      _commitDerivedState(
        state.copyWith(favoriteIds: updatedFavs, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.toggleFavorite error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Favori durumu güncellenemedi: $e',
      );
    }
  }

  Future<void> addOrUpdatePlanEntry({
    required String dateIso,
    required MealSlot slot,
    required String recipeId,
    int? servings,
  }) async {
    try {
      final int now = _nowProvider().millisecondsSinceEpoch;
      final entry = MealPlanEntry(
        planDate: dateIso,
        mealSlot: slot,
        recipeId: recipeId,
        servings: (servings ?? state.planServings).clamp(1, 12),
        isCooked: false,
        addedAt: now,
      );
      await _repository.upsertMealPlanEntry(entry);
      if (!mounted) return;
      await _reloadEntriesWindow();
    } catch (e, st) {
      debugPrint('MealModuleNotifier.addOrUpdatePlanEntry error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Öğün plana eklenemedi: $e',
      );
    }
  }

  Future<void> removePlanEntry(int entryId) async {
    try {
      await _repository.deleteMealPlanEntry(entryId);
      if (!mounted) return;
      _lifecycleEntries =
          _lifecycleEntries.where((e) => e.id != entryId).toList();
      final updated = state.weekEntries.where((e) => e.id != entryId).toList();
      _commitDerivedState(
        state.copyWith(weekEntries: updated, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.removePlanEntry error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Planlı öğün silinemedi: $e',
      );
    }
  }

  Future<void> toggleEntryCooked(
    MealPlanEntry entry, {
    bool consumeFromPantry = false,
  }) async {
    final int? entryId = entry.id;
    if (entryId == null) return;
    final bool targetCooked = !entry.isCooked;

    try {
      await _repository.markEntryCooked(entryId, isCooked: targetCooked);
      Map<String, int> nextCookCounts = state.cookCounts;
      final KilerRecipe? recipe = state.recipeById[entry.recipeId];

      if (targetCooked && recipe != null) {
        await _repository.logRecipeCooked(
          recipeId: recipe.id,
          recipeTitle: recipe.title,
          servings: entry.servings,
        );
        nextCookCounts = await _repository.getCookCountsByRecipe();
        if (consumeFromPantry && _onConsumeIngredients != null) {
          final List<String> usedTags = {
            ...recipe.requiredTags,
            ...recipe.optionalTags,
          }.toList();
          await _onConsumeIngredients(usedTags, recipe.title);
        }
      }

      if (!mounted) return;
      _lifecycleEntries = _lifecycleEntries
          .map((e) => e.id == entryId ? e.copyWith(isCooked: targetCooked) : e)
          .toList();
      final updatedEntries = state.weekEntries
          .map(
            (e) => e.id == entryId ? e.copyWith(isCooked: targetCooked) : e,
          )
          .toList();

      _commitDerivedState(
        state.copyWith(
          weekEntries: updatedEntries,
          cookCounts: nextCookCounts,
          clearErrorMessage: true,
        ),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.toggleEntryCooked error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Pişirme durumu güncellenemedi: $e',
      );
    }
  }

  Future<void> logCookedRecipe(
    KilerRecipe recipe, {
    int? servings,
    bool consumeFromPantry = false,
  }) async {
    try {
      await _repository.logRecipeCooked(
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        servings: (servings ?? recipe.defaultServings).clamp(1, 12),
      );
      if (consumeFromPantry && _onConsumeIngredients != null) {
        final List<String> usedTags = {
          ...recipe.requiredTags,
          ...recipe.optionalTags,
        }.toList();
        await _onConsumeIngredients(usedTags, recipe.title);
      }
      final updatedCounts = await _repository.getCookCountsByRecipe();
      if (!mounted) return;
      _commitDerivedState(
        state.copyWith(cookCounts: updatedCounts, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.logCookedRecipe error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Pişirme kaydı tutulamadı: $e',
      );
    }
  }

  Future<void> confirmPlannedMealCooked(
    MealPlanEntry entry, {
    Map<int, QuantityConsumptionAction>? customActions,
  }) async {
    try {
      final KilerRecipe? recipe = state.recipeById[entry.recipeId];
      final String recipeTitle = recipe?.title ?? entry.recipeId;

      if (entry.id != null) {
        await _repository.markEntryCooked(entry.id!, isCooked: true);
      } else {
        await _repository.upsertMealPlanEntry(entry.copyWith(isCooked: true));
      }

      await _repository.logRecipeCooked(
        recipeId: entry.recipeId,
        recipeTitle: recipeTitle,
        servings: entry.servings,
      );

      if (customActions != null) {
        if (customActions.isNotEmpty) {
          await _onQuickConsume(customActions, '$recipeTitle pişirildi');
        }
      } else if (recipe != null && _onConsumeIngredients != null) {
        final List<String> usedTags = {
          ...recipe.requiredTags,
          ...recipe.optionalTags,
        }.toList();
        await _onConsumeIngredients(usedTags, recipeTitle);
      }

      final checkIn = SlotCheckInRecord(
        planDate: entry.planDate,
        mealSlot: entry.mealSlot,
        resolutionType: SlotResolutionType.cookedPlanned,
        note: recipeTitle,
        resolvedAt: _nowProvider().millisecondsSinceEpoch,
      );
      await _repository.upsertSlotCheckIn(checkIn);

      if (!mounted) return;
      final cookCounts = await _repository.getCookCountsByRecipe();
      if (!mounted) return;
      final updatedCheckIns =
          Map<String, SlotCheckInRecord>.from(state.slotCheckIns)
            ..[checkIn.slotKey] = checkIn;
      await _reloadEntriesWindow(
        cookCounts: cookCounts,
        slotCheckIns: updatedCheckIns,
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.confirmPlannedMealCooked error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Planlı öğün onayı kaydedilemedi: $e',
      );
    }
  }

  Future<void> postponePlannedMealToTomorrow(MealPlanEntry entry) async {
    try {
      final DateTime now = _nowProvider();
      final DateTime todayDate = DateTime(now.year, now.month, now.day);
      final DateTime parsedEntryDate =
          MealDateUtils.fromIsoDate(entry.planDate);
      final DateTime entryDate = DateTime(
        parsedEntryDate.year,
        parsedEntryDate.month,
        parsedEntryDate.day,
      );
      final DateTime baseDate =
          entryDate.isBefore(todayDate) ? todayDate : entryDate;
      final String targetDateIso =
          MealDateUtils.toIsoDate(baseDate.add(const Duration(days: 1)));

      if (entry.id != null) {
        await _repository.deleteMealPlanEntry(entry.id!);
      }
      await _repository.upsertMealPlanEntry(
        MealPlanEntry(
          planDate: targetDateIso,
          mealSlot: entry.mealSlot,
          recipeId: entry.recipeId,
          servings: entry.servings,
          isCooked: false,
          addedAt: now.millisecondsSinceEpoch,
        ),
      );
      if (!mounted) return;
      await _reloadEntriesWindow();
    } catch (e, st) {
      debugPrint(
        'MealModuleNotifier.postponePlannedMealToTomorrow error: $e\n$st',
      );
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Öğün yarına ertelenemedi: $e',
      );
    }
  }

  Future<void> resolveSlotCheckIn({
    required String dateIso,
    required MealSlot slot,
    required SlotResolutionType resolution,
    String? note,
  }) async {
    try {
      final String? cleanNote =
          (note == null || note.trim().isEmpty) ? null : note.trim();
      final record = SlotCheckInRecord(
        planDate: dateIso,
        mealSlot: slot,
        resolutionType: resolution,
        note: cleanNote,
        resolvedAt: _nowProvider().millisecondsSinceEpoch,
      );
      await _repository.upsertSlotCheckIn(record);
      if (!mounted) return;

      final updatedCheckIns =
          Map<String, SlotCheckInRecord>.from(state.slotCheckIns)
            ..[record.slotKey] = record;
      _commitDerivedState(
        state.copyWith(slotCheckIns: updatedCheckIns, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.resolveSlotCheckIn error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Öğün durumu kaydedilemedi: $e',
      );
    }
  }

  Future<void> recordUnplannedSlotConsumption({
    required String dateIso,
    required MealSlot slot,
    required Map<int, QuantityConsumptionAction> actionsByItemId,
    String? note,
  }) async {
    try {
      final String? cleanNote =
          (note == null || note.trim().isEmpty) ? null : note.trim();
      final String reasonNote = cleanNote ?? '${slot.label} öğününde tüketildi';

      if (actionsByItemId.isNotEmpty) {
        await _onQuickConsume(actionsByItemId, reasonNote);
      }

      final record = SlotCheckInRecord(
        planDate: dateIso,
        mealSlot: slot,
        resolutionType: SlotResolutionType.ateFromPantry,
        note: cleanNote,
        resolvedAt: _nowProvider().millisecondsSinceEpoch,
      );
      await _repository.upsertSlotCheckIn(record);
      if (!mounted) return;

      final updatedCheckIns =
          Map<String, SlotCheckInRecord>.from(state.slotCheckIns)
            ..[record.slotKey] = record;
      _commitDerivedState(
        state.copyWith(slotCheckIns: updatedCheckIns, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint(
        'MealModuleNotifier.recordUnplannedSlotConsumption error: $e\n$st',
      );
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Kiler tüketimi kaydedilemedi: $e',
      );
    }
  }

  Future<void> markMissingIngredientsBoughtToPantry(
    List<String> tags, {
    String brand = 'Pazar / Kasap',
  }) async {
    final List<String> uniqueTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueTags.isEmpty) return;

    try {
      final String cleanBrand =
          brand.trim().isEmpty ? 'Pazar / Kasap' : brand.trim();
      final List<DraftPantryAddition> drafts = uniqueTags.map((tag) {
        final QuickIngredientTemplate tpl =
            QuickIngredientCatalog.findByTag(tag) ??
            IngredientNormalizer.resolveMetadata(tag);
        return DraftPantryAddition.fromTemplate(tpl).copyWith(brand: cleanBrand);
      }).toList();

      await _onBatchAddDrafts(drafts);
      if (!mounted) return;
      _commitDerivedState(state.copyWith(clearErrorMessage: true));
    } catch (e, st) {
      debugPrint(
        'MealModuleNotifier.markMissingIngredientsBoughtToPantry error: $e\n$st',
      );
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Alınan malzemeler kilere eklenemedi: $e',
      );
    }
  }

  Future<int> addMissingIngredientsToShopping(
    List<String> tags, {
    String sourceLabel = 'Günlük Öğün Planı',
  }) async {
    final List<String> uniqueTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueTags.isEmpty) return 0;

    try {
      final int added = await _onAddMissingToShopping(uniqueTags, sourceLabel);
      if (!mounted) return added;
      _commitDerivedState(state.copyWith(clearErrorMessage: true));
      return added;
    } catch (e, st) {
      debugPrint(
        'MealModuleNotifier.addMissingIngredientsToShopping error: $e\n$st',
      );
      if (!mounted) return 0;
      state = state.copyWith(
        errorMessage: 'Eksikler alışveriş listesine eklenemedi: $e',
      );
      return 0;
    }
  }

  Future<void> saveRecipePhotoOverride(
    String recipeId,
    String localPath,
  ) async {
    final String cleanId = recipeId.trim();
    final String cleanPath = localPath.trim();
    if (cleanId.isEmpty || cleanPath.isEmpty) return;

    try {
      final override = RecipePhotoOverride(
        recipeId: cleanId,
        localPath: cleanPath,
        updatedAt: _nowProvider().millisecondsSinceEpoch,
      );
      await _repository.setRecipePhotoOverride(override);
      if (!mounted) return;

      final updatedOverrides =
          Map<String, String>.from(state.recipePhotoOverrides)
            ..[cleanId] = cleanPath;
      _commitDerivedState(
        state.copyWith(
          recipePhotoOverrides: updatedOverrides,
          clearErrorMessage: true,
        ),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.saveRecipePhotoOverride error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Tarif fotoğrafı kaydedilemedi: $e',
      );
    }
  }

  Future<void> removeRecipePhotoOverride(String recipeId) async {
    final String cleanId = recipeId.trim();
    if (cleanId.isEmpty) return;

    try {
      await _repository.removeRecipePhotoOverride(cleanId);
      if (!mounted) return;

      final updatedOverrides =
          Map<String, String>.from(state.recipePhotoOverrides)
            ..remove(cleanId);
      _commitDerivedState(
        state.copyWith(
          recipePhotoOverrides: updatedOverrides,
          clearErrorMessage: true,
        ),
      );
    } catch (e, st) {
      debugPrint(
        'MealModuleNotifier.removeRecipePhotoOverride error: $e\n$st',
      );
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Tarif fotoğrafı kaldırılamadı: $e',
      );
    }
  }

  Future<void> generateWeeklyPlan({
    MealPlanPreset? preset,
    int? servings,
  }) async {
    final MealPlanPreset effectivePreset = preset ?? state.selectedPreset;
    final int effectiveServings =
        (servings ?? state.planServings).clamp(1, 12);

    state = state.copyWith(
      selectedPreset: effectivePreset,
      planServings: effectiveServings,
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final (startIso, endIso) = _weekBounds(state.currentWeekMondayIso);
      final generated = MealPlanGenerator.generateWeeklyPlan(
        weekMondayIso: state.currentWeekMondayIso,
        preset: effectivePreset,
        pantryItems: _kilerListenable.value.pantryItems,
        activeProfile: state.activeProfile,
        servings: effectiveServings,
        customRecipes: state.customRecipes,
        favoriteIds: state.favoriteIds,
        preferredRegionId: state.selectedRegion,
      );
      await _repository.replaceWeekEntries(startIso, endIso, generated);
      if (!mounted) return;
      await _reloadEntriesWindow(isLoading: false);
    } catch (e, st) {
      debugPrint('MealModuleNotifier.generateWeeklyPlan error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Haftalık plan oluşturulamadı: $e',
      );
    }
  }

  Future<void> clearCurrentWeekPlan() async {
    try {
      final (startIso, endIso) = _weekBounds(state.currentWeekMondayIso);
      await _repository.clearDateRange(startIso, endIso);
      if (!mounted) return;
      _lifecycleEntries = _lifecycleEntries
          .where(
            (e) =>
                e.planDate.compareTo(startIso) < 0 ||
                e.planDate.compareTo(endIso) > 0,
          )
          .toList();
      _commitDerivedState(
        state.copyWith(weekEntries: const [], clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.clearCurrentWeekPlan error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Haftalık plan temizlenemedi: $e',
      );
    }
  }

  Future<void> saveCustomRecipe(KilerRecipe recipe) async {
    try {
      final KilerRecipe normalized = recipe.copyWith(isCustom: true);
      await _repository.saveCustomRecipe(normalized);
      final updatedCustoms = await _repository.getCustomRecipes();
      if (!mounted) return;
      _commitDerivedState(
        state.copyWith(customRecipes: updatedCustoms, clearErrorMessage: true),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.saveCustomRecipe error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Özel tarif kaydedilemedi: $e',
      );
    }
  }

  Future<void> deleteCustomRecipe(String recipeId) async {
    try {
      await _repository.deleteCustomRecipe(recipeId);
      final (startIso, endIso) = _weekBounds(state.currentWeekMondayIso);
      final (lifecycleStartIso, lifecycleEndIso) =
          _lifecycleBounds(startIso, endIso);
      final results = await Future.wait<dynamic>([
        _repository.getCustomRecipes(),
        _repository.getFavoriteIds(),
        _repository.getEntriesForDateRange(lifecycleStartIso, lifecycleEndIso),
        _repository.getRecipePhotoOverrides(),
      ]);
      if (!mounted) return;
      final List<MealPlanEntry> allEntries = results[2] as List<MealPlanEntry>;
      _lifecycleEntries = allEntries;
      _commitDerivedState(
        state.copyWith(
          customRecipes: results[0] as List<KilerRecipe>,
          favoriteIds: results[1] as Set<String>,
          weekEntries: _filterWeekEntries(allEntries, startIso, endIso),
          recipePhotoOverrides: results[3] as Map<String, String>,
          clearErrorMessage: true,
        ),
      );
    } catch (e, st) {
      debugPrint('MealModuleNotifier.deleteCustomRecipe error: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: 'Özel tarif silinemedi: $e',
      );
    }
  }

  String buildWeeklyShareText() {
    return MealPlanTextFormatter.formatWeeklyPlanForShare(
      weekMondayIso: state.currentWeekMondayIso,
      weekEntries: state.weekEntries,
      recipeById: state.recipeById,
      shoppingGaps: state.weeklyShoppingGaps,
      profileName: state.activeProfile?.profileName,
    );
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> _reloadEntriesWindow({
    Map<String, int>? cookCounts,
    Map<String, SlotCheckInRecord>? slotCheckIns,
    bool? isLoading,
  }) async {
    final (startIso, endIso) = _weekBounds(state.currentWeekMondayIso);
    final (lifecycleStartIso, lifecycleEndIso) =
        _lifecycleBounds(startIso, endIso);
    final allEntries = await _repository.getEntriesForDateRange(
      lifecycleStartIso,
      lifecycleEndIso,
    );
    if (!mounted) return;
    _lifecycleEntries = allEntries;
    _commitDerivedState(
      state.copyWith(
        weekEntries: _filterWeekEntries(allEntries, startIso, endIso),
        cookCounts: cookCounts,
        slotCheckIns: slotCheckIns,
        isLoading: isLoading,
        clearErrorMessage: true,
      ),
    );
  }

  void _commitDerivedState(MealModuleState next) {
    final List<PantryItem> pantryItems = _kilerListenable.value.pantryItems;
    final Map<String, String> overrides = next.recipePhotoOverrides;

    final Map<String, KilerRecipe> rawRecipeById =
        RecipeRecommendationEngine.buildRecipeIndex(
      customRecipes: next.customRecipes,
    );
    final Map<String, KilerRecipe> recipeById = overrides.isEmpty
        ? rawRecipeById
        : {
            for (final entry in rawRecipeById.entries)
              entry.key: _applyPhotoOverride(entry.value, overrides),
          };

    final List<EvaluatedRecipeMatch> rawMatches =
        RecipeRecommendationEngine.evaluateAll(
      pantryItems: pantryItems,
      activeProfile: next.activeProfile,
      filter: next.selectedFilter,
      searchQuery: next.searchQuery,
      category: next.selectedCategory,
      region: next.selectedRegion,
      favoriteIds: next.favoriteIds,
      customRecipes: next.customRecipes,
      cookCounts: next.cookCounts,
    );
    final List<EvaluatedRecipeMatch> matches = overrides.isEmpty
        ? rawMatches
        : rawMatches
            .map((m) => _applyPhotoOverrideToMatch(m, overrides))
            .toList();

    final List<EvaluatedRecipeMatch> rawWasteRescue =
        RecipeRecommendationEngine.topWasteRescueRecipes(
      pantryItems: pantryItems,
      activeProfile: next.activeProfile,
      favoriteIds: next.favoriteIds,
      customRecipes: next.customRecipes,
    );
    final List<EvaluatedRecipeMatch> wasteRescueMatches = overrides.isEmpty
        ? rawWasteRescue
        : rawWasteRescue
            .map((m) => _applyPhotoOverrideToMatch(m, overrides))
            .toList();

    final List<PlannedShoppingGap> gaps =
        MealPlanShoppingAggregator.computeNetMissingIngredients(
      weekEntries: next.weekEntries,
      recipeById: recipeById,
      pantryItems: pantryItems,
    );

    final List<MealPlanEntry> promptEntries =
        _lifecycleEntries.isNotEmpty ? _lifecycleEntries : next.weekEntries;
    final List<KitchenDailyPrompt> activePrompts =
        MealLifecycleAssistant.buildDailyPrompts(
      now: _nowProvider(),
      entries: promptEntries,
      recipeById: recipeById,
      pantryItems: pantryItems,
      checkIns: next.slotCheckIns,
    );

    state = next.copyWith(
      recipeById: recipeById,
      evaluatedMatches: matches,
      weeklyShoppingGaps: gaps,
      wasteRescueMatches: wasteRescueMatches,
      activePrompts: activePrompts,
    );
  }

  static KilerRecipe _applyPhotoOverride(
    KilerRecipe recipe,
    Map<String, String> overrides,
  ) {
    final String? overridePath = overrides[recipe.id];
    if (overridePath == null || overridePath.isEmpty) {
      return recipe;
    }
    if (recipe.localImagePath == overridePath) return recipe;
    return recipe.copyWith(localImagePath: overridePath);
  }

  static EvaluatedRecipeMatch _applyPhotoOverrideToMatch(
    EvaluatedRecipeMatch match,
    Map<String, String> overrides,
  ) {
    final KilerRecipe updatedRecipe =
        _applyPhotoOverride(match.recipe, overrides);
    if (identical(updatedRecipe, match.recipe)) return match;
    return EvaluatedRecipeMatch(
      recipe: updatedRecipe,
      matchedRequiredTags: match.matchedRequiredTags,
      missingRequiredTags: match.missingRequiredTags,
      matchedOptionalTags: match.matchedOptionalTags,
      expiringIngredientsUsed: match.expiringIngredientsUsed,
      longWaitingIngredientsUsed: match.longWaitingIngredientsUsed,
      combinedHealthScore: match.combinedHealthScore,
      profileWarnings: match.profileWarnings,
      isFavorite: match.isFavorite,
      cookCount: match.cookCount,
    );
  }

  (String startIso, String endIso) _lifecycleBounds(
    String weekStartIso,
    String weekEndIso,
  ) {
    final DateTime now = _nowProvider();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final String yesterdayIso =
        MealDateUtils.toIsoDate(today.subtract(const Duration(days: 1)));
    final String tomorrowIso =
        MealDateUtils.toIsoDate(today.add(const Duration(days: 1)));
    final String minIso =
        weekStartIso.compareTo(yesterdayIso) <= 0 ? weekStartIso : yesterdayIso;
    final String maxIso =
        weekEndIso.compareTo(tomorrowIso) >= 0 ? weekEndIso : tomorrowIso;
    return (minIso, maxIso);
  }

  static List<MealPlanEntry> _filterWeekEntries(
    List<MealPlanEntry> entries,
    String startIso,
    String endIso,
  ) {
    return entries
        .where(
          (e) =>
              e.planDate.compareTo(startIso) >= 0 &&
              e.planDate.compareTo(endIso) <= 0,
        )
        .toList();
  }

  static (String startIso, String endIso) _weekBounds(String mondayIso) {
    final DateTime monday = MealDateUtils.startOfWeekMonday(
      MealDateUtils.fromIsoDate(mondayIso),
    );
    final DateTime sunday = monday.add(const Duration(days: 6));
    return (MealDateUtils.toIsoDate(monday), MealDateUtils.toIsoDate(sunday));
  }
}
