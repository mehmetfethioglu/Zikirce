import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../kiler/domain/kiler_models.dart';
import '../../kiler/domain/kiler_service.dart';
import '../domain/meal_module_notifier.dart';
import '../domain/recipe_recommendation_engine.dart';
import 'kitchen_prompt_actions.dart';
import 'widgets/custom_recipe_form_sheet.dart';
import 'widgets/meal_slot_picker_sheet.dart';
import 'widgets/recipe_catalog_explore_view.dart';
import 'widgets/weekly_meal_planner_view.dart';

/// Main entry screen for Kilerce's Recipe Discovery and Weekly Meal Planner module.
class RecipeExplorerScreen extends ConsumerWidget {
  const RecipeExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mealModuleNotifierProvider.select((s) => s.mode));
    final errorMessage = ref.watch(
      mealModuleNotifierProvider.select((s) => s.errorMessage),
    );
    final plannedCount = ref.watch(
      mealModuleNotifierProvider.select((s) => s.weekEntries.length),
    );
    final notifier = ref.read(mealModuleNotifierProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: _ModeSegmentedHeader(
            selectedMode: mode,
            plannedMealCount: plannedCount,
            onModeSelected: (nextMode) {
              notifier.setMode(nextMode);
              notifier.reloadProfile();
            },
            onOpenCustomForm: () => _openCustomRecipeForm(context, notifier),
          ),
        ),
        if (errorMessage != null && errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _ModuleErrorStrip(
              message: errorMessage,
              onDismiss: notifier.clearError,
            ),
          ),
        Expanded(
          child: mode == YemekModuleMode.explore
              ? _ExploreTabBody(
                  onOpenCustomForm: () =>
                      _openCustomRecipeForm(context, notifier),
                )
              : const _PlannerTabBody(),
        ),
      ],
    );
  }

  static Future<void> _openCustomRecipeForm(
    BuildContext context,
    MealModuleNotifier notifier,
  ) async {
    await CustomRecipeFormSheet.show(
      context,
      onSave: (recipe) async {
        await notifier.saveCustomRecipe(recipe);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📝 "${recipe.title}" özel tariflerinize eklendi.'),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      },
    );
  }
}

class _ModeSegmentedHeader extends StatelessWidget {
  final YemekModuleMode selectedMode;
  final int plannedMealCount;
  final ValueChanged<YemekModuleMode> onModeSelected;
  final VoidCallback onOpenCustomForm;

  const _ModeSegmentedHeader({
    required this.selectedMode,
    required this.plannedMealCount,
    required this.onModeSelected,
    required this.onOpenCustomForm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorderColor),
            ),
            child: Row(
              children: YemekModuleMode.values.map((mode) {
                final isSelected = selectedMode == mode;
                final suffix = mode == YemekModuleMode.mealList &&
                        plannedMealCount > 0
                    ? ' ($plannedMealCount)'
                    : '';
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onModeSelected(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryEmerald
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${mode.label}$suffix',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : context.textPrimaryColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Özel ev tarifi ekle',
          child: Tooltip(
            message: 'Kendi Ev Tarifini Ekle',
            child: InkWell(
              onTap: onOpenCustomForm,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.post_add_rounded,
                  size: 20,
                  color: AppColors.primaryEmerald,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleErrorStrip extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ModuleErrorStrip({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.dangerRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ExploreTabBody extends ConsumerWidget {
  final VoidCallback onOpenCustomForm;

  const _ExploreTabBody({required this.onOpenCustomForm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(
      mealModuleNotifierProvider.select((s) => s.evaluatedMatches),
    );
    final selectedFilter = ref.watch(
      mealModuleNotifierProvider.select((s) => s.selectedFilter),
    );
    final selectedCategory = ref.watch(
      mealModuleNotifierProvider.select((s) => s.selectedCategory),
    );
    final selectedRegion = ref.watch(
      mealModuleNotifierProvider.select((s) => s.selectedRegion),
    );
    final searchQuery = ref.watch(
      mealModuleNotifierProvider.select((s) => s.searchQuery),
    );
    final activeProfile = ref.watch(
      mealModuleNotifierProvider.select((s) => s.activeProfile),
    );
    final customRecipes = ref.watch(
      mealModuleNotifierProvider.select((s) => s.customRecipes),
    );
    final isLoading = ref.watch(
      mealModuleNotifierProvider.select((s) => s.isLoading),
    );
    final isCloudLoading = ref.watch(
      mealModuleNotifierProvider.select((s) => s.isCloudLoading),
    );
    final cloudHasMore = ref.watch(
      mealModuleNotifierProvider.select((s) => s.cloudHasMore),
    );
    final currentWeekMondayIso = ref.watch(
      mealModuleNotifierProvider.select((s) => s.currentWeekMondayIso),
    );
    final selectedDateIso = ref.watch(
      mealModuleNotifierProvider.select((s) => s.selectedDateIso),
    );
    final planServings = ref.watch(
      mealModuleNotifierProvider.select((s) => s.planServings),
    );
    final wasteRescueMatches = ref.watch(
      mealModuleNotifierProvider.select((s) => s.wasteRescueMatches),
    );
    final notifier = ref.read(mealModuleNotifierProvider.notifier);

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, kilerState, _) {
        final bool isUnfiltered = selectedFilter == RecipeFilterTab.all &&
            selectedCategory == null &&
            selectedRegion == null &&
            searchQuery.trim().isEmpty;

        final List<EvaluatedRecipeMatch> baseline = isUnfiltered
            ? matches
            : RecipeRecommendationEngine.evaluateAll(
                pantryItems: kilerState.pantryItems,
                activeProfile: activeProfile,
                customRecipes: customRecipes,
              );

        final int readyNowCount =
            baseline.where((m) => m.isReadyToCook).length;
        final int wasteSaverCount =
            baseline.where((m) => m.preventsFoodWaste).length;

        return RecipeCatalogExploreView(
          matches: matches,
          selectedFilter: selectedFilter,
          selectedCategory: selectedCategory,
          selectedRegion: selectedRegion,
          searchQuery: searchQuery,
          activeProfile: activeProfile,
          activeDaypart: notifier.currentDaypart,
          pantryItemCount: kilerState.pantryItems.length,
          readyNowCount: readyNowCount,
          wasteSaverCount: wasteSaverCount,
          isLoading: isLoading,
          isCloudLoading: isCloudLoading,
          cloudHasMore: cloudHasMore,
          onLoadMoreCloud: notifier.loadMoreCloudRecipes,
          rescueItems: kilerState.rescueCandidateItems,
          wasteRescueMatches: wasteRescueMatches,
          onBatchAddPantryItems: KilerService.instance.addBatchDraftItems,
          onAddRescueRecipeToPlan: (match) =>
              KitchenPromptActions.openAddRecipeToPlanSheet(
            context: context,
            notifier: notifier,
            recipe: match.recipe,
            weekMondayIso: currentWeekMondayIso,
            selectedDateIso: selectedDateIso,
            planServings: planServings,
          ),
          onSearchChanged: notifier.setSearchQuery,
          onFilterChanged: notifier.setFilter,
          onCategoryChanged: notifier.setCategory,
          onRegionChanged: notifier.setRegion,
          onOpenCustomRecipeForm: onOpenCustomForm,
          onPantryUpdated: notifier.loadAll,
          onToggleFavorite: (match) => notifier.toggleFavorite(match.recipe.id),
          onQuickAddToPlan: (match) =>
              KitchenPromptActions.openAddRecipeToPlanSheet(
            context: context,
            notifier: notifier,
            recipe: match.recipe,
            weekMondayIso: currentWeekMondayIso,
            selectedDateIso: selectedDateIso,
            planServings: planServings,
          ),
          onRecipeTap: (match) => KitchenPromptActions.openRecipeDetail(
            context: context,
            notifier: notifier,
            match: match,
            weekMondayIso: currentWeekMondayIso,
            selectedDateIso: selectedDateIso,
            planServings: planServings,
          ),
        );
      },
    );
  }
}

class _PlannerTabBody extends ConsumerWidget {
  const _PlannerTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealModuleNotifierProvider);
    final notifier = ref.read(mealModuleNotifierProvider.notifier);

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, kilerState, _) {
        final pantryTags = kilerState.availableTags;
        final currentMondayIso = MealDateUtils.toIsoDate(
          MealDateUtils.startOfWeekMonday(DateTime.now()),
        );
        final bool isDifferentWeek =
            state.currentWeekMondayIso != currentMondayIso;

        return WeeklyMealPlannerView(
          state: state,
          pantryTags: pantryTags,
          onPreviousWeek: notifier.previousWeek,
          onNextWeek: notifier.nextWeek,
          onGoToCurrentWeek: isDifferentWeek
              ? () => notifier.selectWeek(DateTime.now())
              : null,
          onPresetChanged: notifier.setPreset,
          onServingsChanged: notifier.setPlanServings,
          onGenerateSmartWeek: () async {
            await notifier.generateWeeklyPlan();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚡ Haftalık yemek listeniz kiler ve aile profiline göre oluşturuldu!',
                ),
                backgroundColor: AppColors.primaryEmerald,
              ),
            );
          },
          onTransferMissingToShopping: () => _transferGapsToShopping(
            context: context,
            gaps: state.weeklyShoppingGaps,
          ),
          onShareWeek: () => _shareWeeklyPlan(context, notifier),
          onClearWeek: () async {
            await notifier.clearCurrentWeekPlan();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Haftalık yemek listesi temizlendi.'),
              ),
            );
          },
          onSelectDate: notifier.selectDate,
          onToggleOverview: notifier.setFullWeekOverview,
          onAddMealToSlot: (dateIso, slot) => _openSlotRecipePicker(
            context: context,
            notifier: notifier,
            state: state,
            kilerState: kilerState,
            dateIso: dateIso,
            slot: slot,
          ),
          onAddPromptMissingToShopping: (p) =>
              KitchenPromptActions.addMissingToShopping(context, notifier, p),
          onBoughtPromptMissingToPantry: (p) =>
              KitchenPromptActions.boughtMissingToPantry(context, notifier, p),
          onSnoozePromptMissing: (p) =>
              KitchenPromptActions.snoozeMissing(context, notifier, p),
          onConfirmPromptCooked: (p) =>
              KitchenPromptActions.confirmPlannedCooked(context, notifier, p),
          onPostponePromptPlanned: (p) =>
              KitchenPromptActions.postponePlanned(context, notifier, p),
          onSkipPromptPlanned: (p) =>
              KitchenPromptActions.skipPlanned(context, notifier, p),
          onOpenUnplannedPrompt: (p) =>
              KitchenPromptActions.openUnplannedCheckIn(
            context,
            notifier,
            dateIso: p.planDate,
            slot: p.mealSlot,
            pantryItems: kilerState.pantryItems,
            suggestedItems: p.suggestedPantryItems,
          ),
          onSkipUnplannedPrompt: (p) =>
              KitchenPromptActions.skipUnplanned(context, notifier, p),
          onQuickConsumeSlot: (dateIso, slot) =>
              KitchenPromptActions.openUnplannedCheckIn(
            context,
            notifier,
            dateIso: dateIso,
            slot: slot,
            pantryItems: kilerState.pantryItems,
          ),
          onMarkEntryCooked: (entry) async {
            final willCook = !entry.isCooked;
            await notifier.toggleEntryCooked(
              entry,
              consumeFromPantry: willCook,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  willCook
                      ? '👨‍🍳 Öğün pişirildi ve kiler stokları güncellendi!'
                      : 'Öğün pişirilmedi olarak işaretlendi.',
                ),
                backgroundColor: willCook ? AppColors.primaryEmerald : null,
              ),
            );
          },
          onRemoveEntry: (entry) async {
            final id = entry.id;
            if (id == null) return;
            await notifier.removePlanEntry(id);
          },
          onOpenRecipe: (recipeId) {
            final recipe = state.recipeById[recipeId];
            if (recipe == null) return;
            final Map<String, List<PantryItem>> itemsByTag = {};
            for (final item in kilerState.pantryItems) {
              itemsByTag.putIfAbsent(item.normalizedTag, () => []).add(item);
            }
            final match = RecipeRecommendationEngine.evaluateSingle(
              recipe: recipe,
              availableTags: pantryTags,
              itemsByTag: itemsByTag,
              activeProfile: state.activeProfile,
              isFavorite: state.favoriteIds.contains(recipe.id),
              cookCount: state.cookCounts[recipe.id] ?? 0,
            );
            KitchenPromptActions.openRecipeDetail(
              context: context,
              notifier: notifier,
              match: match,
              weekMondayIso: state.currentWeekMondayIso,
              selectedDateIso: state.selectedDateIso,
              planServings: state.planServings,
            );
          },
        );
      },
    );
  }

  static Future<void> _openSlotRecipePicker({
    required BuildContext context,
    required MealModuleNotifier notifier,
    required MealModuleState state,
    required KilerState kilerState,
    required String dateIso,
    required MealSlot slot,
  }) async {
    final allMatches = RecipeRecommendationEngine.evaluateAll(
      pantryItems: kilerState.pantryItems,
      activeProfile: state.activeProfile,
      favoriteIds: state.favoriteIds,
      customRecipes: state.customRecipes,
      cookCounts: state.cookCounts,
    ).map((m) {
      final resolved = state.recipeById[m.recipe.id];
      if (resolved == null || identical(resolved, m.recipe)) return m;
      return EvaluatedRecipeMatch(
        recipe: resolved,
        matchedRequiredTags: m.matchedRequiredTags,
        missingRequiredTags: m.missingRequiredTags,
        matchedOptionalTags: m.matchedOptionalTags,
        expiringIngredientsUsed: m.expiringIngredientsUsed,
        longWaitingIngredientsUsed: m.longWaitingIngredientsUsed,
        combinedHealthScore: m.combinedHealthScore,
        profileWarnings: m.profileWarnings,
        isFavorite: m.isFavorite,
        cookCount: m.cookCount,
      );
    }).toList();

    await MealSlotPickerSheet.showForSlot(
      context,
      planDateIso: dateIso,
      slot: slot,
      matches: allMatches,
      initialServings: state.planServings,
      onSelectRecipe: (recipeId, servings) async {
        await notifier.addOrUpdatePlanEntry(
          dateIso: dateIso,
          slot: slot,
          recipeId: recipeId,
          servings: servings,
        );
        if (!context.mounted) return;
        final title = state.recipeById[recipeId]?.title ?? 'Tarif';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📅 "$title" ${slot.label} listesine eklendi.'),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      },
    );
  }

  static Future<void> _transferGapsToShopping({
    required BuildContext context,
    required List<PlannedShoppingGap> gaps,
  }) async {
    if (gaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Haftalık plan için eksik malzemeniz bulunmuyor!'),
          backgroundColor: AppColors.primaryEmerald,
        ),
      );
      return;
    }

    final tags = gaps.map((g) => g.tag).toList();
    final added = await KilerService.instance.addMissingRecipeIngredientsToShopping(
      tags,
      'Haftalık Yemek Listesi',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🛒 Haftalık eksik $added malzeme Akıllı Alışveriş Listenize aktarıldı!',
        ),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  static Future<void> _shareWeeklyPlan(
    BuildContext context,
    MealModuleNotifier notifier,
  ) async {
    try {
      final shareText = notifier.buildWeeklyShareText();
      await Share.share(shareText, subject: 'Kilerce Haftalık Yemek Planım');
    } catch (e) {
      debugPrint('RecipeExplorerScreen._shareWeeklyPlan error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan paylaşılamadı: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }
}
