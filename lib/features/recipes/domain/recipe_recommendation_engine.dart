import '../../family_profiles/domain/family_profile_engine.dart';
import '../../kiler/domain/kiler_models.dart';
import '../data/kilerce_recipe_catalog.dart';
import 'recipe_models.dart';

export 'recipe_models.dart';

/// 3-Tier Smart Chef recommendation and Turkish search engine.
class RecipeRecommendationEngine {
  static const List<KilerRecipe> catalog = kilerceMasterRecipes;

  static final Map<RecipeFilterTab, bool Function(EvaluatedRecipeMatch match)>
      _filterRules = {
    RecipeFilterTab.all: (_) => true,
    RecipeFilterTab.readyNow: (m) => m.isReadyToCook,
    RecipeFilterTab.wasteSaver: (m) => m.preventsFoodWaste,
    RecipeFilterTab.almostReady: (m) => m.isAlmostReady,
    RecipeFilterTab.quick: (m) => m.recipe.totalMinutes <= 20,
    RecipeFilterTab.highProtein: (m) => m.recipe.proteinGrams >= 20,
    RecipeFilterTab.favorites: (m) => m.isFavorite,
    RecipeFilterTab.custom: (m) => m.recipe.isCustom,
  };

  /// Folds Turkish diacritics to ASCII lowercase for reliable search matching.
  static String normalizeTurkish(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('\u0307', '')
        .toLowerCase()
        .trim();
  }

  /// Builds a combined ID-to-recipe index including built-in and custom recipes.
  static Map<String, KilerRecipe> buildRecipeIndex({
    List<KilerRecipe> customRecipes = const [],
  }) {
    final Map<String, KilerRecipe> index = {
      for (final recipe in catalog) recipe.id: recipe,
    };
    for (final custom in customRecipes) {
      index[custom.id] = custom;
    }
    return index;
  }

  /// Evaluates built-in and custom recipes against the current Pantry state and active Family Profile.
  static List<EvaluatedRecipeMatch> evaluateAll({
    required List<PantryItem> pantryItems,
    FamilyProfile? activeProfile,
    RecipeFilterTab filter = RecipeFilterTab.all,
    String searchQuery = '',
    String? category,
    String? region,
    Set<String> favoriteIds = const {},
    List<KilerRecipe> customRecipes = const [],
    Map<String, int> cookCounts = const {},
  }) {
    final Set<String> availableTags =
        pantryItems.map((e) => e.normalizedTag).toSet();

    final Map<String, List<PantryItem>> itemsByTag = {};
    for (final item in pantryItems) {
      itemsByTag.putIfAbsent(item.normalizedTag, () => []).add(item);
    }

    final List<String> queryTokens = normalizeTurkish(searchQuery)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final List<KilerRecipe> allRecipes = _mergeCatalogWithCustom(customRecipes);
    final List<EvaluatedRecipeMatch> evaluated = [];

    for (final recipe in allRecipes) {
      if (!RecipeCategoryRegistry.matchesCategory(recipe.category, category)) {
        continue;
      }
      if (!TurkishRegionRegistry.matchesRegion(recipe.regionId, region)) {
        continue;
      }
      if (queryTokens.isNotEmpty && !_matchesSearch(recipe, queryTokens)) {
        continue;
      }

      final match = evaluateSingle(
        recipe: recipe,
        availableTags: availableTags,
        itemsByTag: itemsByTag,
        activeProfile: activeProfile,
        isFavorite: favoriteIds.contains(recipe.id),
        cookCount: cookCounts[recipe.id] ?? 0,
      );

      final predicate = _filterRules[filter];
      if (predicate != null && !predicate(match)) continue;
      evaluated.add(match);
    }

    // 3-Tier Smart Chef Sorting:
    // 1. Ready-to-cook + Waste-saver recipes first
    // 2. Match ratio descending
    // 3. Expiring ingredients count descending
    // 4. Long-waiting pantry ingredients count descending
    // 5. Profile-safe recipes preferred over restricted ones
    // 6. Combined health score descending
    evaluated.sort((a, b) {
      if (a.isReadyToCook != b.isReadyToCook) {
        return a.isReadyToCook ? -1 : 1;
      }
      if (a.preventsFoodWaste != b.preventsFoodWaste) {
        return a.preventsFoodWaste ? -1 : 1;
      }
      final ratioCmp = b.matchRatio.compareTo(a.matchRatio);
      if (ratioCmp != 0) return ratioCmp;

      final expCmp = b.expiringIngredientsUsed.length
          .compareTo(a.expiringIngredientsUsed.length);
      if (expCmp != 0) return expCmp;

      final waitCmp = b.longWaitingIngredientsUsed.length
          .compareTo(a.longWaitingIngredientsUsed.length);
      if (waitCmp != 0) return waitCmp;

      if (a.isProfileSafe != b.isProfileSafe) {
        return a.isProfileSafe ? -1 : 1;
      }

      return b.combinedHealthScore.compareTo(a.combinedHealthScore);
    });

    return evaluated;
  }

  /// Returns top waste-rescue recipes prioritizing ready-to-cook and expiring/long-waiting counts.
  static List<EvaluatedRecipeMatch> topWasteRescueRecipes({
    required List<PantryItem> pantryItems,
    FamilyProfile? activeProfile,
    Set<String> favoriteIds = const {},
    List<KilerRecipe> customRecipes = const [],
    int limit = 6,
  }) {
    if (pantryItems.isEmpty || limit <= 0) return const [];
    final rescueMatches = evaluateAll(
      pantryItems: pantryItems,
      activeProfile: activeProfile,
      filter: RecipeFilterTab.wasteSaver,
      favoriteIds: favoriteIds,
      customRecipes: customRecipes,
    );
    rescueMatches.sort((a, b) {
      if (a.isReadyToCook != b.isReadyToCook) {
        return a.isReadyToCook ? -1 : 1;
      }
      final int aRescued =
          a.expiringIngredientsUsed.length + a.longWaitingIngredientsUsed.length;
      final int bRescued =
          b.expiringIngredientsUsed.length + b.longWaitingIngredientsUsed.length;
      final int rescuedCmp = bRescued.compareTo(aRescued);
      if (rescuedCmp != 0) return rescuedCmp;

      final int expCmp = b.expiringIngredientsUsed.length
          .compareTo(a.expiringIngredientsUsed.length);
      if (expCmp != 0) return expCmp;

      final int ratioCmp = b.matchRatio.compareTo(a.matchRatio);
      if (ratioCmp != 0) return ratioCmp;

      if (a.isProfileSafe != b.isProfileSafe) {
        return a.isProfileSafe ? -1 : 1;
      }

      return b.combinedHealthScore.compareTo(a.combinedHealthScore);
    });
    return rescueMatches.take(limit).toList();
  }

  /// Evaluates a single [KilerRecipe] against pre-indexed pantry data.
  static EvaluatedRecipeMatch evaluateSingle({
    required KilerRecipe recipe,
    required Set<String> availableTags,
    required Map<String, List<PantryItem>> itemsByTag,
    FamilyProfile? activeProfile,
    bool isFavorite = false,
    int cookCount = 0,
  }) {
    final List<String> matchedReq = [];
    final List<String> missingReq = [];
    final List<PantryItem> expiringUsed = [];
    final List<PantryItem> longWaitingUsed = [];
    final Set<Object> seenExpiring = {};
    final Set<Object> seenLongWaiting = {};
    final List<int> usedScores = [recipe.baseHealthScore];

    void collectTagItems(String tag) {
      final matchingItems = itemsByTag[tag] ?? const [];
      for (final pItem in matchingItems) {
        usedScores.add(pItem.healthScore);
        final Object dedupKey = pItem.id ?? '${pItem.normalizedTag}:${pItem.name}';
        if (pItem.isExpiringSoon || pItem.isExpired) {
          if (seenExpiring.add(dedupKey)) {
            expiringUsed.add(pItem);
          }
        } else if (pItem.isLongWaiting) {
          if (seenLongWaiting.add(dedupKey)) {
            longWaitingUsed.add(pItem);
          }
        }
      }
    }

    for (final reqTag in recipe.requiredTags) {
      if (availableTags.contains(reqTag)) {
        matchedReq.add(reqTag);
        collectTagItems(reqTag);
      } else {
        missingReq.add(reqTag);
      }
    }

    final List<String> matchedOpt = [];
    for (final optTag in recipe.optionalTags) {
      if (availableTags.contains(optTag)) {
        matchedOpt.add(optTag);
        collectTagItems(optTag);
      }
    }

    final int avgScore = (usedScores.reduce((a, b) => a + b) / usedScores.length)
        .round()
        .clamp(0, 100);

    final warnings = EvaluatedRecipeMatch.evaluateProfileWarnings(
      recipe,
      activeProfile,
    );

    return EvaluatedRecipeMatch(
      recipe: recipe,
      matchedRequiredTags: matchedReq,
      missingRequiredTags: missingReq,
      matchedOptionalTags: matchedOpt,
      expiringIngredientsUsed: expiringUsed,
      longWaitingIngredientsUsed: longWaitingUsed,
      combinedHealthScore: avgScore,
      profileWarnings: warnings,
      isFavorite: isFavorite,
      cookCount: cookCount,
    );
  }

  static List<KilerRecipe> _mergeCatalogWithCustom(
    List<KilerRecipe> customRecipes,
  ) {
    if (customRecipes.isEmpty) return catalog;
    final Set<String> customIds = customRecipes.map((e) => e.id).toSet();
    return [
      ...customRecipes,
      ...catalog.where((r) => !customIds.contains(r.id)),
    ];
  }

  static bool _matchesSearch(KilerRecipe recipe, List<String> queryTokens) {
    final TurkishRegionMeta? regionMeta =
        TurkishRegionRegistry.findById(recipe.regionId);
    final buffer = StringBuffer()
      ..write(recipe.title)
      ..write(' ')
      ..write(recipe.subtitle)
      ..write(' ')
      ..write(recipe.category)
      ..write(' ')
      ..write(recipe.originCity);
    if (regionMeta != null) {
      buffer
        ..write(' ')
        ..write(regionMeta.label)
        ..write(' ')
        ..write(regionMeta.shortLabel);
    }

    for (final tag in recipe.requiredTags) {
      buffer
        ..write(' ')
        ..write(tag)
        ..write(' ')
        ..write(QuickIngredientCatalog.displayNameForTag(tag));
    }
    for (final tag in recipe.optionalTags) {
      buffer
        ..write(' ')
        ..write(tag)
        ..write(' ')
        ..write(QuickIngredientCatalog.displayNameForTag(tag));
    }
    for (final ing in recipe.ingredients) {
      buffer
        ..write(' ')
        ..write(ing.name);
    }

    final String haystack = normalizeTurkish(buffer.toString());
    return queryTokens.every(haystack.contains);
  }
}
