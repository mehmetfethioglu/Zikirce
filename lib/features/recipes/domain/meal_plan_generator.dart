import '../../family_profiles/domain/family_profile_engine.dart';
import '../../kiler/domain/kiler_models.dart';
import 'recipe_recommendation_engine.dart';

typedef PresetScoreStrategy = double Function(
  EvaluatedRecipeMatch match,
  int dayIndex,
  String? previousDayMainCategory,
);

/// Generates balanced, pantry-aware and profile-safe 7-day meal plans via OCP preset strategies.
class MealPlanGenerator {
  static const List<MealSlot> defaultSlots = [
    MealSlot.breakfast,
    MealSlot.soupStarter,
    MealSlot.mainCourse,
    MealSlot.sideSnack,
  ];

  static final Map<MealPlanPreset, PresetScoreStrategy> _presetStrategies = {
    MealPlanPreset.zeroWasteSmart: (match, dayIndex, _) {
      final double wasteBoost =
          match.preventsFoodWaste ? (dayIndex <= 2 ? 130.0 : 65.0) : 0.0;
      final double readyBoost = match.isReadyToCook ? 55.0 : 0.0;
      return wasteBoost +
          readyBoost +
          (match.matchRatio * 80.0) +
          (match.expiringIngredientsUsed.length * 18.0) +
          (match.combinedHealthScore * 0.4);
    },
    MealPlanPreset.cleanFamilyBalanced: (match, _, previousMainCategory) {
      final double childBoost = match.recipe.isChildFriendly ? 25.0 : 0.0;
      final double diversityBoost = (previousMainCategory != null &&
              match.recipe.category != previousMainCategory)
          ? 24.0
          : 0.0;
      return (match.recipe.baseHealthScore * 0.8) +
          (match.matchRatio * 45.0) +
          (match.preventsFoodWaste ? 20.0 : 0.0) +
          childBoost +
          diversityBoost;
    },
    MealPlanPreset.highProteinFit: (match, _, _) {
      final double proteinScore = match.recipe.proteinGrams * 2.6;
      final double glycemicBoost = match.recipe.isLowGlycemic ? 30.0 : -20.0;
      final double fiberScore = match.recipe.fiberGrams * 1.5;
      return proteinScore +
          glycemicBoost +
          fiberScore +
          (match.matchRatio * 35.0) +
          (match.combinedHealthScore * 0.35);
    },
    MealPlanPreset.quickWeekdays: (match, dayIndex, _) {
      final bool isWeekday = dayIndex < 5;
      final int mins = match.recipe.totalMinutes;
      final double speedScore;
      if (isWeekday) {
        speedScore = mins <= 20 ? 85.0 : (mins <= 25 ? 40.0 : -35.0);
      } else {
        speedScore = mins <= 35 ? 25.0 : 5.0;
      }
      return speedScore +
          (match.isReadyToCook ? 45.0 : 0.0) +
          (match.matchRatio * 40.0) +
          (match.combinedHealthScore * 0.35);
    },
    MealPlanPreset.regionalAnatolianTour: (
      match,
      dayIndex,
      previousMainCategory,
    ) {
      final String targetRegionId = TurkishRegionRegistry
          .sevenRegions[dayIndex % TurkishRegionRegistry.sevenRegions.length]
          .id;
      final double regionBoost =
          match.recipe.regionId == targetRegionId ? 110.0 : 0.0;
      final double diversityBoost = (previousMainCategory != null &&
              match.recipe.category != previousMainCategory)
          ? 20.0
          : 0.0;
      return regionBoost +
          diversityBoost +
          (match.matchRatio * 45.0) +
          (match.preventsFoodWaste ? 18.0 : 0.0) +
          (match.combinedHealthScore * 0.35);
    },
  };

  /// Generates a 7-day weekly meal plan starting at [weekMondayIso].
  static List<MealPlanEntry> generateWeeklyPlan({
    required String weekMondayIso,
    required MealPlanPreset preset,
    required List<PantryItem> pantryItems,
    FamilyProfile? activeProfile,
    int servings = 2,
    List<KilerRecipe> customRecipes = const [],
    Set<String> favoriteIds = const {},
    List<MealSlot> slots = defaultSlots,
    String? preferredRegionId,
    int? addedAtMs,
  }) {
    final DateTime monday = MealDateUtils.startOfWeekMonday(
      MealDateUtils.fromIsoDate(weekMondayIso),
    );
    final List<DateTime> weekDays = MealDateUtils.daysOfWeek(monday);
    final int safeServings = servings.clamp(1, 12);
    final int timestamp = addedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final String? activePreferredRegion = (preferredRegionId != null &&
            preferredRegionId.isNotEmpty &&
            preferredRegionId != TurkishRegionRegistry.all)
        ? preferredRegionId
        : null;

    final List<EvaluatedRecipeMatch> allEvaluated =
        RecipeRecommendationEngine.evaluateAll(
      pantryItems: pantryItems,
      activeProfile: activeProfile,
      customRecipes: customRecipes,
      favoriteIds: favoriteIds,
    );
    if (allEvaluated.isEmpty) return const [];

    final PresetScoreStrategy strategy = _presetStrategies[preset] ??
        _presetStrategies[MealPlanPreset.zeroWasteSmart]!;

    final Map<String, int> weeklyUsageCount = {};
    final Map<MealSlot, String> lastSlotRecipeId = {};
    String? previousMainCategory;
    final List<MealPlanEntry> planEntries = [];

    for (int dayIdx = 0; dayIdx < weekDays.length; dayIdx++) {
      final String dayIso = MealDateUtils.toIsoDate(weekDays[dayIdx]);
      final Set<String> usedOnSameDay = {};

      for (final slot in slots) {
        final List<EvaluatedRecipeMatch> slotCandidates = allEvaluated
            .where((m) => m.recipe.mealSlots.contains(slot))
            .toList();
        final List<EvaluatedRecipeMatch> pool =
            slotCandidates.isNotEmpty ? slotCandidates : allEvaluated;

        final List<EvaluatedRecipeMatch> safePool =
            pool.where((m) => m.isProfileSafe).toList();
        final List<EvaluatedRecipeMatch> eligible =
            safePool.isNotEmpty ? safePool : pool;

        final EvaluatedRecipeMatch? chosen = _pickBestCandidate(
          candidates: eligible,
          strategy: strategy,
          dayIndex: dayIdx,
          previousMainCategory:
              slot == MealSlot.mainCourse ? previousMainCategory : null,
          weeklyUsageCount: weeklyUsageCount,
          lastUsedForSlot: lastSlotRecipeId[slot],
          usedOnSameDay: usedOnSameDay,
          preferredRegionId: activePreferredRegion,
        );

        if (chosen == null) continue;

        final String recipeId = chosen.recipe.id;
        usedOnSameDay.add(recipeId);
        weeklyUsageCount[recipeId] = (weeklyUsageCount[recipeId] ?? 0) + 1;
        lastSlotRecipeId[slot] = recipeId;
        if (slot == MealSlot.mainCourse) {
          previousMainCategory = chosen.recipe.category;
        }

        planEntries.add(
          MealPlanEntry(
            planDate: dayIso,
            mealSlot: slot,
            recipeId: recipeId,
            servings: safeServings,
            isCooked: false,
            addedAt: timestamp,
          ),
        );
      }
    }

    return planEntries;
  }

  static EvaluatedRecipeMatch? _pickBestCandidate({
    required List<EvaluatedRecipeMatch> candidates,
    required PresetScoreStrategy strategy,
    required int dayIndex,
    required String? previousMainCategory,
    required Map<String, int> weeklyUsageCount,
    required String? lastUsedForSlot,
    required Set<String> usedOnSameDay,
    String? preferredRegionId,
  }) {
    EvaluatedRecipeMatch? best;
    double bestScore = double.negativeInfinity;

    for (final match in candidates) {
      final String id = match.recipe.id;
      double score = strategy(match, dayIndex, previousMainCategory);

      if (preferredRegionId != null &&
          match.recipe.regionId == preferredRegionId) {
        score += 105.0;
      }
      if (match.isFavorite) {
        score += 12.0;
      }
      if (usedOnSameDay.contains(id)) {
        score -= 1000.0;
      }
      if (lastUsedForSlot == id) {
        score -= 450.0;
      }
      final int usage = weeklyUsageCount[id] ?? 0;
      if (usage > 0) {
        score -= usage * 190.0;
      }

      if (score > bestScore) {
        bestScore = score;
        best = match;
      }
    }
    return best;
  }
}

/// Computes net missing ingredients across un-cooked weekly meal plan entries.
class MealPlanShoppingAggregator {
  static List<PlannedShoppingGap> computeNetMissingIngredients({
    required List<MealPlanEntry> weekEntries,
    required Map<String, KilerRecipe> recipeById,
    required List<PantryItem> pantryItems,
    bool includeLowStockAsGap = true,
  }) {
    if (weekEntries.isEmpty) return const [];

    final Map<String, List<PantryItem>> pantryByTag = {};
    for (final item in pantryItems) {
      pantryByTag.putIfAbsent(item.normalizedTag, () => []).add(item);
    }

    final Map<String, _GapAccumulator> accumulators = {};

    for (final entry in weekEntries) {
      if (entry.isCooked) continue;
      final KilerRecipe? recipe = recipeById[entry.recipeId];
      if (recipe == null) continue;

      final Set<String> stapleOnlyTags = recipe.ingredients
          .where((ing) => ing.isPantryStaple || ing.isOptional)
          .map((ing) => ing.tag)
          .toSet();
      final Set<String> requiredNonStapleTags = recipe.ingredients
          .where((ing) => !ing.isPantryStaple && !ing.isOptional)
          .map((ing) => ing.tag)
          .toSet();

      final Set<String> entryRequiredTags = recipe.requiredTags
          .where(
            (tag) =>
                requiredNonStapleTags.contains(tag) ||
                !stapleOnlyTags.contains(tag),
          )
          .toSet();

      for (final tag in entryRequiredTags) {
        final List<PantryItem> stock = pantryByTag[tag] ?? const [];
        final bool hasHealthyStock =
            stock.any((item) => item.quantityLevel != QuantityLevel.low);
        if (hasHealthyStock) continue;

        final bool isLowStock = stock.isNotEmpty;
        if (isLowStock && !includeLowStockAsGap) continue;

        final acc = accumulators.putIfAbsent(
          tag,
          () => _GapAccumulator(tag: tag, isLowStock: isLowStock),
        );
        acc.neededMealCount += 1;
        acc.recipeTitles.add(recipe.title);
        if (!isLowStock) {
          acc.isLowStock = false;
        }
      }
    }

    final List<PlannedShoppingGap> gaps = accumulators.values.map((acc) {
      final QuickIngredientTemplate? tpl =
          QuickIngredientCatalog.findByTag(acc.tag);
      return PlannedShoppingGap(
        tag: acc.tag,
        displayName:
            tpl?.name ?? QuickIngredientCatalog.displayNameForTag(acc.tag),
        emoji: tpl?.emoji ?? '🛒',
        category: tpl?.category ?? 'Bakliyat & Tahıl',
        neededMealCount: acc.neededMealCount,
        recipeTitles: acc.recipeTitles.toList(),
        isLowStock: acc.isLowStock,
      );
    }).toList();

    gaps.sort((a, b) {
      if (a.isLowStock != b.isLowStock) {
        return a.isLowStock ? 1 : -1;
      }
      final countCmp = b.neededMealCount.compareTo(a.neededMealCount);
      if (countCmp != 0) return countCmp;
      return a.displayName.compareTo(b.displayName);
    });

    return gaps;
  }
}

class _GapAccumulator {
  final String tag;
  int neededMealCount = 0;
  final Set<String> recipeTitles = {};
  bool isLowStock;

  _GapAccumulator({required this.tag, required this.isLowStock});
}

/// Formats weekly meal plans and missing shopping items into readable Turkish share text.
class MealPlanTextFormatter {
  static String formatWeeklyPlanForShare({
    required String weekMondayIso,
    required List<MealPlanEntry> weekEntries,
    required Map<String, KilerRecipe> recipeById,
    List<PlannedShoppingGap> shoppingGaps = const [],
    String? profileName,
  }) {
    final DateTime monday = MealDateUtils.startOfWeekMonday(
      MealDateUtils.fromIsoDate(weekMondayIso),
    );
    final List<DateTime> days = MealDateUtils.daysOfWeek(monday);
    final String rangeLabel = MealDateUtils.weekRangeLabel(monday);

    final StringBuffer buffer = StringBuffer()
      ..writeln('🍽️ Kilerce Haftalık Yemek Planı ($rangeLabel)');
    if (profileName != null && profileName.trim().isNotEmpty) {
      buffer.writeln('👨‍👩‍👧‍👦 Profil: ${profileName.trim()}');
    }
    buffer.writeln();

    if (weekEntries.isEmpty) {
      buffer.writeln('Bu hafta için henüz planlanmış öğün bulunmuyor.');
      return buffer.toString().trimRight();
    }

    for (final day in days) {
      final String dayIso = MealDateUtils.toIsoDate(day);
      final List<MealPlanEntry> dayEntries =
          weekEntries.where((e) => e.planDate == dayIso).toList();
      if (dayEntries.isEmpty) continue;

      dayEntries.sort((a, b) => a.mealSlot.index.compareTo(b.mealSlot.index));
      buffer.writeln(
        '📅 ${MealDateUtils.weekdayFullLabel(day)} (${MealDateUtils.shortDayMonth(day)})',
      );
      for (final entry in dayEntries) {
        final KilerRecipe? recipe = recipeById[entry.recipeId];
        final String title = recipe?.title ?? entry.recipeId;
        final String cookedSuffix = entry.isCooked ? ' ✓ Pişirildi' : '';
        if (recipe != null) {
          final TurkishRegionMeta? regionMeta =
              TurkishRegionRegistry.findById(recipe.regionId);
          final String regionTag = regionMeta != null
              ? '${recipe.originCity} • ${regionMeta.shortLabel}'
              : recipe.originCity;
          buffer.writeln(
            '  • ${entry.mealSlot.emoji} ${entry.mealSlot.label}: $title [$regionTag] (${entry.servings} kişilik • ${recipe.portionGram} g / ${recipe.calories} kcal)$cookedSuffix',
          );
        } else {
          buffer.writeln(
            '  • ${entry.mealSlot.emoji} ${entry.mealSlot.label}: $title (${entry.servings} kişilik)$cookedSuffix',
          );
        }
      }
      buffer.writeln();
    }

    if (shoppingGaps.isNotEmpty) {
      buffer.writeln('🛒 Eksik Malzeme Listesi (${shoppingGaps.length} ürün):');
      for (final gap in shoppingGaps) {
        final String stockNote = gap.isLowStock ? ' [Az Kaldı]' : '';
        buffer.writeln(
          '  - ${gap.emoji} ${gap.displayName}$stockNote (${gap.neededMealCount} öğün)',
        );
      }
    }

    return buffer.toString().trimRight();
  }
}
