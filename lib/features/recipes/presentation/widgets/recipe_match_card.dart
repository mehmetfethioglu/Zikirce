import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/recipe_models.dart';
import 'recipe_visual_header.dart';

/// Editorial full-bleed recipe card keeping dish imagery and title front and center
/// with minimal monochrome overlay icons and zero text clutter.
class RecipeMatchCard extends StatelessWidget {
  final EvaluatedRecipeMatch match;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onQuickAddToPlan;
  final bool? isFavorite;

  const RecipeMatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.onToggleFavorite,
    this.onQuickAddToPlan,
    this.isFavorite,
  });

  static const Map<String, IconData> _categoryIcons = {
    RecipeCategoryRegistry.soup: Icons.soup_kitchen_rounded,
    RecipeCategoryRegistry.breakfast: Icons.egg_alt_rounded,
    RecipeCategoryRegistry.meatFish: Icons.set_meal_rounded,
    RecipeCategoryRegistry.vegOliveOil: Icons.eco_rounded,
    RecipeCategoryRegistry.legumesGrains: Icons.rice_bowl_rounded,
    RecipeCategoryRegistry.saladMeze: Icons.spa_rounded,
    RecipeCategoryRegistry.healthyDessertKids: Icons.cake_rounded,
  };

  /// Returns the shared minimal monochrome icon for a recipe category.
  static IconData iconForCategory(String category) =>
      _categoryIcons[category] ?? Icons.restaurant_rounded;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final effectiveFavorite = isFavorite ?? match.isFavorite;
    final int minutes =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;
    final IconData categoryIcon = iconForCategory(recipe.category);

    return Container(
      height: 192,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.cardBorderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RecipeVisualHeader(
              recipe: recipe,
              height: 192,
              showOverlays: false,
              borderRadius: BorderRadius.zero,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x28000000),
                      Color(0x00000000),
                      Color(0xD6060C0A),
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$minutes dk • ${recipe.calories} kcal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _GlassCircleBadge(
                    tooltip: recipe.category,
                    child: Icon(categoryIcon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 6),
                  _PantryStatusDot(match: match),
                  const Spacer(),
                  _ScoreNumberPill(score: match.combinedHealthScore),
                  if (onToggleFavorite != null) ...[
                    const SizedBox(width: 6),
                    _GlassCircleButton(
                      tooltip: effectiveFavorite
                          ? 'Favoriden Çıkar'
                          : 'Favorilere Ekle',
                      onTap: onToggleFavorite!,
                      child: Icon(
                        effectiveFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 17,
                        color: effectiveFavorite
                            ? AppColors.dangerRed
                            : Colors.white,
                      ),
                    ),
                  ] else if (effectiveFavorite) ...[
                    const SizedBox(width: 6),
                    const _GlassCircleBadge(
                      tooltip: 'Favori',
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: AppColors.dangerRed,
                      ),
                    ),
                  ],
                  if (onQuickAddToPlan != null) ...[
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      label: 'Takvime Ekle',
                      child: _GlassCircleButton(
                        tooltip: 'Takvime Ekle',
                        onTap: onQuickAddToPlan!,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryStatusDot extends StatelessWidget {
  final EvaluatedRecipeMatch match;

  const _PantryStatusDot({required this.match});

  @override
  Widget build(BuildContext context) {
    if (!match.isProfileSafe) {
      final warningText = match.profileWarnings.isNotEmpty
          ? match.profileWarnings.first
          : 'Aile profili uyarısı';
      return _GlassCircleBadge(
        tooltip: warningText,
        child: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFF87171),
          size: 16,
        ),
      );
    }

    if (match.isReadyToCook) {
      return const _GlassCircleBadge(
        tooltip: 'Kilerde hazır',
        child: Icon(
          Icons.check_circle_rounded,
          color: AppColors.primaryEmerald,
          size: 17,
        ),
      );
    }

    final missingCount = match.missingRequiredTags.length;
    return Tooltip(
      message: '$missingCount malzeme eksik',
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x78000000),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(
          '-$missingCount',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ScoreNumberPill extends StatelessWidget {
  final int score;

  const _ScoreNumberPill({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x78000000),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlassCircleBadge extends StatelessWidget {
  final String tooltip;
  final Widget child;

  const _GlassCircleBadge({
    required this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x78000000),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: child,
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _GlassCircleButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0x78000000),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
