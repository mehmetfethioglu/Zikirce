import 'package:flutter/material.dart';
import '../../domain/recipe_models.dart';
import '../recipe_detail_screen.dart';

/// Backward-compatible facade forwarding to the full-page [RecipeDetailScreen].
class RecipeDetailSheet extends StatelessWidget {
  final EvaluatedRecipeMatch match;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToMealPlan;
  final ValueChanged<int>? onRecipeCooked;
  final VoidCallback? onDeleteCustom;
  final VoidCallback? onPickCustomPhoto;
  final VoidCallback? onRemoveCustomPhoto;

  const RecipeDetailSheet({
    super.key,
    required this.match,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onAddToMealPlan,
    this.onRecipeCooked,
    this.onDeleteCustom,
    this.onPickCustomPhoto,
    this.onRemoveCustomPhoto,
  });

  static Future<void> show(
    BuildContext context,
    EvaluatedRecipeMatch match, {
    bool isFavorite = false,
    VoidCallback? onToggleFavorite,
    VoidCallback? onAddToMealPlan,
    ValueChanged<int>? onRecipeCooked,
    VoidCallback? onDeleteCustom,
    VoidCallback? onPickCustomPhoto,
    VoidCallback? onRemoveCustomPhoto,
  }) {
    return RecipeDetailScreen.open(
      context,
      match,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onAddToMealPlan: onAddToMealPlan,
      onRecipeCooked: onRecipeCooked,
      onDeleteCustom: onDeleteCustom,
      onPickCustomPhoto: onPickCustomPhoto,
      onRemoveCustomPhoto: onRemoveCustomPhoto,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RecipeDetailScreen(
      match: match,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onAddToMealPlan: onAddToMealPlan,
      onRecipeCooked: onRecipeCooked,
      onDeleteCustom: onDeleteCustom,
      onPickCustomPhoto: onPickCustomPhoto,
      onRemoveCustomPhoto: onRemoveCustomPhoto,
    );
  }
}
