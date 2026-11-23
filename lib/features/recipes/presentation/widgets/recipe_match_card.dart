import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/recipe_models.dart';
import 'recipe_visual_header.dart';

/// Compact recipe summary card displaying critical visual, pantry-readiness,
/// core nutrition metrics, and a direct calendar-add action.
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

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final effectiveFavorite = isFavorite ?? match.isFavorite;
    final accentBorder = !match.isProfileSafe
        ? AppColors.dangerRed.withValues(alpha: 0.5)
        : match.preventsFoodWaste
            ? AppColors.cautionGold.withValues(alpha: 0.48)
            : match.isReadyToCook
                ? AppColors.primaryEmerald.withValues(alpha: 0.42)
                : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BioMinimalUi.cardDecoration(
            context,
            accentBorder: accentBorder,
            radius: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeVisualHeader(
                recipe: recipe,
                height: 124,
                combinedScore: match.combinedHealthScore,
              ),
              const SizedBox(height: 10),
              _TitleAndFavoriteRow(
                title: recipe.title,
                isFavorite: effectiveFavorite,
                onToggleFavorite: onToggleFavorite,
              ),
              const SizedBox(height: 4),
              _CompactCriticalMetaRow(recipe: recipe),
              const SizedBox(height: 10),
              _BottomActionRow(
                match: match,
                onQuickAddToPlan: onQuickAddToPlan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleAndFavoriteRow extends StatelessWidget {
  final String title;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _TitleAndFavoriteRow({
    required this.title,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
        if (onToggleFavorite != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: isFavorite ? 'Favoriden Çıkar' : 'Favorilere Ekle',
            child: InkWell(
              onTap: onToggleFavorite,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.subtleSurfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.cardBorderColor),
                ),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: isFavorite
                      ? AppColors.dangerRed
                      : context.textSecondaryColor,
                ),
              ),
            ),
          ),
        ] else if (isFavorite) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.favorite_rounded,
            size: 18,
            color: AppColors.dangerRed,
          ),
        ],
      ],
    );
  }
}

class _CompactCriticalMetaRow extends StatelessWidget {
  final KilerRecipe recipe;

  const _CompactCriticalMetaRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final int minutes =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;
    return Text(
      '⏱️ $minutes dk  •  🔥 ${recipe.calories} kcal  •  💪 ${recipe.proteinGrams}g Prot.  •  📍 ${recipe.originCity}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.textSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BottomActionRow extends StatelessWidget {
  final EvaluatedRecipeMatch match;
  final VoidCallback? onQuickAddToPlan;

  const _BottomActionRow({
    required this.match,
    required this.onQuickAddToPlan,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = !match.isProfileSafe
        ? AppColors.dangerRed
        : match.isReadyToCook
            ? AppColors.primaryEmerald
            : AppColors.cautionGold;

    final String statusLabel = !match.isProfileSafe
        ? '⚠️ Profil Uyarısı'
        : match.isReadyToCook
            ? '✅ Kilerde Hazır'
            : '🛒 ${match.missingRequiredTags.length} Eksik';

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: _StatusBadgePill(
                  label: statusLabel,
                  color: statusColor,
                ),
              ),
              if (match.preventsFoodWaste) ...[
                const SizedBox(width: 6),
                const _StatusBadgePill(
                  label: '♻️',
                  color: AppColors.cautionGold,
                ),
              ],
            ],
          ),
        ),
        if (onQuickAddToPlan != null) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onQuickAddToPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text(
              'Takvime Ekle',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBadgePill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadgePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
