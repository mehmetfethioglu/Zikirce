import '../../kiler/domain/kiler_models.dart';
import 'recipe_models.dart';

/// Pure domain assistant producing daily kitchen prompts and slot-aware pantry suggestions.
class MealLifecycleAssistant {
  static const Map<MealSlot, int> _plannedCookCheckHours = {
    MealSlot.breakfast: 10,
    MealSlot.soupStarter: 14,
    MealSlot.sideSnack: 17,
    MealSlot.mainCourse: 19,
  };

  static const Map<MealSlot, int> _unplannedCheckHours = {
    MealSlot.breakfast: 11,
    MealSlot.mainCourse: 20,
  };

  static const Set<SlotResolutionType> _terminalCookResolutions = {
    SlotResolutionType.cookedPlanned,
    SlotResolutionType.ateFromPantry,
    SlotResolutionType.skippedOutside,
  };

  static const Map<MealSlot, Set<String>> _slotPreferredTags = {
    MealSlot.breakfast: {
      'yumurta',
      'peynir',
      'kasar',
      'lor_peyniri',
      'zeytin',
      'tereyagi',
      'bal',
      'pekmez',
      'tahin',
      'sut',
      'yogurt',
      'kefir',
      'domates',
      'salatalik',
      'biber',
      'sucuk',
      'yulaf',
      'avokado',
      'maydanoz',
      'yufka',
    },
    MealSlot.soupStarter: {
      'kirmizi_mercimek',
      'yesil_mercimek',
      'tarhana',
      'yogurt',
      'domates',
      'sogan',
      'sarimsak',
      'havuc',
      'patates',
      'un',
      'tereyagi',
      'tavuk',
      'balkabagi',
      'brokoli',
      'karnabahar',
      'taze_nane',
      'limon',
      'salca',
    },
    MealSlot.mainCourse: {
      'tavuk',
      'kiyma',
      'kusbasi_et',
      'kuzu_eti',
      'hindi',
      'balik',
      'hamsi',
      'nohut',
      'kuru_fasulye',
      'barbunya',
      'pirinc',
      'bulgur',
      'makarna',
      'eriste',
      'patlican',
      'kabak',
      'patates',
      'ispanak',
      'taze_fasulye',
      'karnabahar',
      'pirasa',
      'kereviz',
      'enginar',
      'karalahana',
      'bamya',
      'mantar',
      'domates',
      'biber',
      'sogan',
      'salca',
    },
    MealSlot.sideSnack: {
      'marul',
      'salatalik',
      'domates',
      'roka_tere',
      'semizotu',
      'maydanoz',
      'dereotu',
      'taze_nane',
      'yesil_sogan',
      'limon',
      'yogurt',
      'kefir',
      'elma',
      'muz',
      'portakal',
      'ceviz',
      'hurma',
      'incir_kayisi',
      'yulaf',
      'chia',
      'avokado',
      'nar_eksisi',
    },
  };

  static const Map<MealSlot, Set<String>> _slotPreferredCategories = {
    MealSlot.breakfast: {'Süt & Kahvaltılık'},
    MealSlot.soupStarter: {'Bakliyat & Tahıl', 'Sebze & Meyve'},
    MealSlot.mainCourse: {
      'Et, Tavuk & Yumurta',
      'Bakliyat & Tahıl',
      'Sebze & Meyve',
    },
    MealSlot.sideSnack: {'Sebze & Meyve', 'Süt & Kahvaltılık'},
  };

  static List<KitchenDailyPrompt> buildDailyPrompts({
    required DateTime now,
    required List<MealPlanEntry> entries,
    required Map<String, KilerRecipe> recipeById,
    required List<PantryItem> pantryItems,
    required Map<String, SlotCheckInRecord> checkIns,
  }) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final String todayIso = MealDateUtils.toIsoDate(today);
    final String yesterdayIso =
        MealDateUtils.toIsoDate(today.subtract(const Duration(days: 1)));
    final String tomorrowIso =
        MealDateUtils.toIsoDate(today.add(const Duration(days: 1)));

    final Map<String, List<PantryItem>> pantryByTag = {};
    for (final item in pantryItems) {
      pantryByTag.putIfAbsent(item.normalizedTag, () => []).add(item);
    }

    final List<KitchenDailyPrompt> missingPrompts = [];
    final List<KitchenDailyPrompt> cookCheckPrompts = [];
    final List<KitchenDailyPrompt> unplannedPrompts = [];
    final Set<String> plannedSlotKeys = {};

    for (final entry in entries) {
      final String key = _slotKey(entry.planDate, entry.mealSlot);
      plannedSlotKeys.add(key);
      if (entry.isCooked) continue;

      final KilerRecipe? recipe = recipeById[entry.recipeId];
      if (recipe == null) continue;

      final SlotCheckInRecord? checkIn = checkIns[key];

      final bool isMissingDateWindow = entry.planDate == todayIso ||
          (now.hour >= 18 && entry.planDate == tomorrowIso);
      final bool missingSuppressed = checkIn != null &&
          (checkIn.resolutionType == SlotResolutionType.snoozedMissingAlert ||
              _terminalCookResolutions.contains(checkIn.resolutionType));

      if (isMissingDateWindow && !missingSuppressed) {
        final prompt = _buildMissingIngredientsPrompt(
          entry: entry,
          recipe: recipe,
          pantryByTag: pantryByTag,
          isTomorrowPreview: entry.planDate == tomorrowIso,
        );
        if (prompt != null) {
          missingPrompts.add(prompt);
        }
      }

      final int cookHourCutoff =
          _plannedCookCheckHours[entry.mealSlot] ?? 19;
      final bool isCookCheckWindow = entry.planDate == yesterdayIso ||
          (entry.planDate == todayIso && now.hour >= cookHourCutoff);
      final bool cookResolved = checkIn != null &&
          _terminalCookResolutions.contains(checkIn.resolutionType);

      if (isCookCheckWindow && !cookResolved) {
        cookCheckPrompts.add(
          _buildPlannedCookCheckPrompt(
            entry: entry,
            recipe: recipe,
            pantryByTag: pantryByTag,
            isYesterday: entry.planDate == yesterdayIso,
          ),
        );
      }
    }

    if (pantryItems.isNotEmpty) {
      for (final slot in _unplannedCheckHours.keys) {
        final int hourCutoff = _unplannedCheckHours[slot]!;
        if (now.hour >= hourCutoff) {
          _maybeAddUnplannedPrompt(
            out: unplannedPrompts,
            dateIso: todayIso,
            slot: slot,
            isYesterday: false,
            plannedSlotKeys: plannedSlotKeys,
            checkIns: checkIns,
            pantryItems: pantryItems,
          );
        }
        _maybeAddUnplannedPrompt(
          out: unplannedPrompts,
          dateIso: yesterdayIso,
          slot: slot,
          isYesterday: true,
          plannedSlotKeys: plannedSlotKeys,
          checkIns: checkIns,
          pantryItems: pantryItems,
        );
      }
    }

    missingPrompts.sort((a, b) {
      if (a.isTomorrowPreview != b.isTomorrowPreview) {
        return a.isTomorrowPreview ? 1 : -1;
      }
      return a.mealSlot.index.compareTo(b.mealSlot.index);
    });
    cookCheckPrompts.sort((a, b) {
      final dateCmp = b.planDate.compareTo(a.planDate);
      if (dateCmp != 0) return dateCmp;
      return a.mealSlot.index.compareTo(b.mealSlot.index);
    });
    unplannedPrompts.sort((a, b) {
      final dateCmp = b.planDate.compareTo(a.planDate);
      if (dateCmp != 0) return dateCmp;
      return a.mealSlot.index.compareTo(b.mealSlot.index);
    });

    return [
      ...missingPrompts,
      ...cookCheckPrompts,
      ...unplannedPrompts,
    ];
  }

  static List<PantryItem> suggestSlotPantryItems({
    required MealSlot slot,
    required List<PantryItem> pantryItems,
  }) {
    if (pantryItems.isEmpty) return const [];

    final Set<String> preferredTags = _slotPreferredTags[slot] ?? const {};
    final Set<String> preferredCategories =
        _slotPreferredCategories[slot] ?? const {};

    int scoreItem(PantryItem item) {
      int score = 0;
      if (preferredTags.contains(item.normalizedTag)) score += 100;
      if (preferredCategories.contains(item.category)) score += 40;
      score += item.rescuePriorityScore ~/ 2;
      return score;
    }

    final List<PantryItem> sorted = List<PantryItem>.from(pantryItems);
    sorted.sort((a, b) {
      final scoreCmp = scoreItem(b).compareTo(scoreItem(a));
      if (scoreCmp != 0) return scoreCmp;
      final expCmp = a.expiresAt.compareTo(b.expiresAt);
      if (expCmp != 0) return expCmp;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  static KitchenDailyPrompt? _buildMissingIngredientsPrompt({
    required MealPlanEntry entry,
    required KilerRecipe recipe,
    required Map<String, List<PantryItem>> pantryByTag,
    required bool isTomorrowPreview,
  }) {
    final Set<String> stapleOnlyTags = recipe.ingredients
        .where((ing) => ing.isPantryStaple || ing.isOptional)
        .map((ing) => ing.tag)
        .toSet();
    final Set<String> requiredNonStapleTags = recipe.ingredients
        .where((ing) => !ing.isPantryStaple && !ing.isOptional)
        .map((ing) => ing.tag)
        .toSet();

    final List<String> missingTags = [];
    final List<String> lowStockTags = [];
    final Set<String> seenTags = {};

    for (final tag in recipe.requiredTags) {
      if (!seenTags.add(tag)) continue;
      if (!requiredNonStapleTags.contains(tag) && stapleOnlyTags.contains(tag)) {
        continue;
      }
      final List<PantryItem> stock = pantryByTag[tag] ?? const [];
      if (stock.isEmpty) {
        missingTags.add(tag);
      } else if (stock.every((item) => item.quantityLevel == QuantityLevel.low)) {
        lowStockTags.add(tag);
      }
    }

    if (missingTags.isEmpty && lowStockTags.isEmpty) return null;

    final String dayPrefix = isTomorrowPreview ? 'Yarın' : 'Bugün';
    final List<String> subtitleParts = [];
    if (missingTags.isNotEmpty) {
      final names = missingTags
          .map(QuickIngredientCatalog.displayNameForTag)
          .join(', ');
      subtitleParts.add('Eksik: $names');
    }
    if (lowStockTags.isNotEmpty) {
      final names = lowStockTags
          .map(QuickIngredientCatalog.displayNameForTag)
          .join(', ');
      subtitleParts.add('Az kalan: $names');
    }

    return KitchenDailyPrompt(
      id: 'missing_${entry.planDate}_${entry.mealSlot.dbCode}_${recipe.id}',
      type: KitchenPromptType.todayMissingIngredients,
      planDate: entry.planDate,
      mealSlot: entry.mealSlot,
      title: '$dayPrefix ${entry.mealSlot.label}: ${recipe.title} için eksik var',
      subtitle: subtitleParts.join(' • '),
      plannedEntry: entry,
      recipe: recipe,
      missingTags: missingTags,
      lowStockTags: lowStockTags,
      isTomorrowPreview: isTomorrowPreview,
    );
  }

  static KitchenDailyPrompt _buildPlannedCookCheckPrompt({
    required MealPlanEntry entry,
    required KilerRecipe recipe,
    required Map<String, List<PantryItem>> pantryByTag,
    required bool isYesterday,
  }) {
    final List<String> candidateTags = [
      ...recipe.requiredTags,
      ...recipe.optionalTags,
      for (final ing in recipe.ingredients)
        if (!ing.isPantryStaple) ing.tag,
    ];

    final List<PantryItem> suggestedItems = [];
    final Set<Object> seenKeys = {};
    for (final tag in candidateTags) {
      for (final item in (pantryByTag[tag] ?? const <PantryItem>[])) {
        final Object dedupKey = item.id ?? '${item.normalizedTag}:${item.name}';
        if (seenKeys.add(dedupKey)) {
          suggestedItems.add(item);
        }
      }
    }

    final String dayContext = isYesterday ? 'Dünkü' : 'Bugünkü';
    return KitchenDailyPrompt(
      id: 'cook_check_${entry.planDate}_${entry.mealSlot.dbCode}_${recipe.id}',
      type: KitchenPromptType.plannedMealCookCheck,
      planDate: entry.planDate,
      mealSlot: entry.mealSlot,
      title: 'Planlanan ${recipe.title} yapıldı mı?',
      subtitle:
          '$dayContext ${entry.mealSlot.label} öğünü • Onaylarsanız kiler stokları düşülür',
      plannedEntry: entry,
      recipe: recipe,
      suggestedPantryItems: suggestedItems,
    );
  }

  static void _maybeAddUnplannedPrompt({
    required List<KitchenDailyPrompt> out,
    required String dateIso,
    required MealSlot slot,
    required bool isYesterday,
    required Set<String> plannedSlotKeys,
    required Map<String, SlotCheckInRecord> checkIns,
    required List<PantryItem> pantryItems,
  }) {
    final String key = _slotKey(dateIso, slot);
    if (plannedSlotKeys.contains(key)) return;
    if (checkIns.containsKey(key)) return;

    final String dayPrefix = isYesterday ? 'Dünkü' : 'Bugünkü';
    out.add(
      KitchenDailyPrompt(
        id: 'unplanned_${dateIso}_${slot.dbCode}',
        type: KitchenPromptType.unplannedSlotPantryCheck,
        planDate: dateIso,
        mealSlot: slot,
        title: '$dayPrefix ${slot.label} öğününde kilerden bir şey tükettiniz mi?',
        subtitle:
            'Tüketilen ürünleri işaretlerseniz kiler stokları ve alışveriş listeniz güncellenir.',
        suggestedPantryItems: suggestSlotPantryItems(
          slot: slot,
          pantryItems: pantryItems,
        ),
      ),
    );
  }

  static String _slotKey(String planDate, MealSlot slot) =>
      '$planDate|${slot.dbCode}';
}
