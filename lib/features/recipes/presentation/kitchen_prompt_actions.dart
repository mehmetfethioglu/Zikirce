import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../kiler/domain/kiler_models.dart';
import '../domain/meal_lifecycle_assistant.dart';
import '../domain/meal_module_notifier.dart';
import '../domain/recipe_models.dart';
import 'widgets/kitchen_checkin_sheets.dart';
import 'widgets/meal_slot_picker_sheet.dart';
import 'widgets/recipe_detail_sheet.dart';

/// Shared UI action coordinator bridging daily kitchen prompts, meal planning,
/// and custom dish photo capture with [MealModuleNotifier].
class KitchenPromptActions {
  const KitchenPromptActions._();

  static Future<void> addMissingToShopping(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    final List<String> tags = {
      ...prompt.missingTags,
      ...prompt.lowStockTags,
    }.toList();
    if (tags.isEmpty) return;

    final int added = await notifier.addMissingIngredientsToShopping(
      tags,
      sourceLabel: prompt.recipe?.title ?? 'Günlük Öğün Planı',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🛒 $added eksik/azalan malzeme Alışveriş Listesine eklendi.',
        ),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  static Future<void> boughtMissingToPantry(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    final List<String> tags = {
      ...prompt.missingTags,
      ...prompt.lowStockTags,
    }.toList();
    if (tags.isEmpty) return;

    await notifier.markMissingIngredientsBoughtToPantry(tags);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🧺 Eksik malzemeler Pazar/Kasap kaydıyla Kilerinize eklendi!',
        ),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  static Future<void> snoozeMissing(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    await notifier.resolveSlotCheckIn(
      dateIso: prompt.planDate,
      slot: prompt.mealSlot,
      resolution: SlotResolutionType.snoozedMissingAlert,
    );
  }

  static Future<void> confirmPlannedCooked(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    final MealPlanEntry? entry = prompt.plannedEntry;
    if (entry == null) return;

    final Map<int, QuantityConsumptionAction>? actions =
        await PlannedMealCookCheckSheet.show(context, prompt: prompt);
    if (actions == null || !context.mounted) return;

    await notifier.confirmPlannedMealCooked(entry, customActions: actions);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👨‍🍳 Öğün pişirildi ve kiler stokları güncellendi!'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  static Future<void> postponePlanned(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    final MealPlanEntry? entry = prompt.plannedEntry;
    if (entry == null) return;

    await notifier.postponePlannedMealToTomorrow(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📅 Öğün yarının yemek planına ertelendi.'),
        backgroundColor: AppColors.primaryMint,
      ),
    );
  }

  static Future<void> skipPlanned(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    await notifier.resolveSlotCheckIn(
      dateIso: prompt.planDate,
      slot: prompt.mealSlot,
      resolution: SlotResolutionType.skippedOutside,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Öğün dışarıda/atlandı olarak işaretlendi.'),
      ),
    );
  }

  static Future<void> openUnplannedCheckIn(
    BuildContext context,
    MealModuleNotifier notifier, {
    required String dateIso,
    required MealSlot slot,
    required List<PantryItem> pantryItems,
    List<PantryItem>? suggestedItems,
  }) async {
    final List<PantryItem> suggestions = suggestedItems ??
        MealLifecycleAssistant.suggestSlotPantryItems(
          slot: slot,
          pantryItems: pantryItems,
        );
    final Map<int, QuantityConsumptionAction>? actions =
        await UnplannedPantryCheckInSheet.show(
      context,
      slot: slot,
      dateIso: dateIso,
      pantryItems: pantryItems,
      suggestedItems: suggestions,
    );
    if (actions == null || !context.mounted) return;

    await notifier.recordUnplannedSlotConsumption(
      dateIso: dateIso,
      slot: slot,
      actionsByItemId: actions,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🧺 ${slot.label} kiler tüketimi güncellendi!'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  static Future<void> skipUnplanned(
    BuildContext context,
    MealModuleNotifier notifier,
    KitchenDailyPrompt prompt,
  ) async {
    await notifier.resolveSlotCheckIn(
      dateIso: prompt.planDate,
      slot: prompt.mealSlot,
      resolution: SlotResolutionType.skippedOutside,
    );
  }

  static Future<void> openAddRecipeToPlanSheet({
    required BuildContext context,
    required MealModuleNotifier notifier,
    required KilerRecipe recipe,
    required String weekMondayIso,
    required String selectedDateIso,
    required int planServings,
  }) async {
    await MealSlotPickerSheet.showForRecipe(
      context,
      recipe: recipe,
      weekMondayIso: weekMondayIso,
      initialDateIso: selectedDateIso,
      initialSlot: recipe.primarySlot,
      initialServings: planServings,
      onConfirm: (dateIso, slot, servings) async {
        await notifier.addOrUpdatePlanEntry(
          dateIso: dateIso,
          slot: slot,
          recipeId: recipe.id,
          servings: servings,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📅 "${recipe.title}" ($servings kişilik) ${slot.label} listesine eklendi.',
            ),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      },
    );
  }

  static Future<void> openRecipeDetail({
    required BuildContext context,
    required MealModuleNotifier notifier,
    required EvaluatedRecipeMatch match,
    required String weekMondayIso,
    required String selectedDateIso,
    required int planServings,
  }) async {
    final bool hasCustomPhoto =
        match.recipe.localImagePath?.trim().isNotEmpty ?? false;

    await RecipeDetailSheet.show(
      context,
      match,
      isFavorite: match.isFavorite,
      onToggleFavorite: () => notifier.toggleFavorite(match.recipe.id),
      onAddToMealPlan: () => openAddRecipeToPlanSheet(
        context: context,
        notifier: notifier,
        recipe: match.recipe,
        weekMondayIso: weekMondayIso,
        selectedDateIso: selectedDateIso,
        planServings: planServings,
      ),
      onRecipeCooked: (servings) => notifier.logCookedRecipe(
        match.recipe,
        servings: servings,
        consumeFromPantry: false,
      ),
      onDeleteCustom: match.recipe.isCustom
          ? () => notifier.deleteCustomRecipe(match.recipe.id)
          : null,
      onPickCustomPhoto: () => _pickAndSaveRecipePhoto(
        context: context,
        notifier: notifier,
        recipeId: match.recipe.id,
        recipeTitle: match.recipe.title,
      ),
      onRemoveCustomPhoto: hasCustomPhoto
          ? () => _removeCustomRecipePhoto(
                context: context,
                notifier: notifier,
                recipeId: match.recipe.id,
                recipeTitle: match.recipe.title,
              )
          : null,
    );
  }

  static Future<void> _pickAndSaveRecipePhoto({
    required BuildContext context,
    required MealModuleNotifier notifier,
    required String recipeId,
    required String recipeTitle,
  }) async {
    final ImageSource? source = await _showPhotoSourceSheet(context, recipeTitle);
    if (source == null || !context.mounted) return;

    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (picked == null || picked.path.trim().isEmpty || !context.mounted) {
        return;
      }

      await notifier.saveRecipePhotoOverride(recipeId, picked.path);
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📸 "$recipeTitle" için gerçek yemek fotoğrafınız kaydedildi.',
          ),
          backgroundColor: AppColors.primaryEmerald,
        ),
      );
    } catch (e) {
      debugPrint('KitchenPromptActions._pickAndSaveRecipePhoto error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  static Future<void> _removeCustomRecipePhoto({
    required BuildContext context,
    required MealModuleNotifier notifier,
    required String recipeId,
    required String recipeTitle,
  }) async {
    await notifier.removeRecipePhotoOverride(recipeId);
    if (!context.mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$recipeTitle" özel fotoğrafı kaldırıldı.'),
      ),
    );
  }

  static Future<ImageSource?> _showPhotoSourceSheet(
    BuildContext context,
    String recipeTitle,
  ) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gerçek Yemek Fotoğrafı Seç',
                  style: TextStyle(
                    color: sheetContext.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$recipeTitle" pişirdiğiniz gerçek tabak görselini tarife bağlayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sheetContext.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primaryEmerald,
                  ),
                  title: const Text('Kamerayla Çek'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryMint,
                  ),
                  title: const Text('Galeriden Seç'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
