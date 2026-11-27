import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kiler/domain/kiler_models.dart';
import '../../domain/recipe_models.dart';

/// Compact expandable bar highlighting expiring/long-waiting pantry items
/// alongside horizontal waste-rescue recipe cards.
class PantryWasteRescueCard extends StatefulWidget {
  final List<PantryItem> rescueItems;
  final List<EvaluatedRecipeMatch> rescueRecipes;
  final ValueChanged<EvaluatedRecipeMatch> onOpenRecipe;
  final ValueChanged<EvaluatedRecipeMatch>? onAddRecipeToPlan;
  final VoidCallback? onOpenRecipesTab;

  const PantryWasteRescueCard({
    super.key,
    required this.rescueItems,
    required this.rescueRecipes,
    required this.onOpenRecipe,
    this.onAddRecipeToPlan,
    this.onOpenRecipesTab,
  });

  @override
  State<PantryWasteRescueCard> createState() => _PantryWasteRescueCardState();
}

class _PantryWasteRescueCardState extends State<PantryWasteRescueCard> {
  bool _expanded = false;

  String _collapsedHeadline() {
    if (widget.rescueItems.isEmpty) {
      return 'Öncelikli malzeme önerileri';
    }
    return '${widget.rescueItems.length} öncelikli malzeme';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rescueItems.isEmpty && widget.rescueRecipes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BioMinimalUi.cardDecoration(
        context,
        fillColor: context.pastelPeachTint,
        accentBorder: context.accentWarm.withValues(alpha: 0.28),
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: context.accentWarm,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _collapsedHeadline(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${widget.rescueRecipes.length} tarif',
                      style: TextStyle(
                        color: context.accentWarm,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 19,
                    color: context.textSecondaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.rescueItems.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.rescueItems
                          .take(5)
                          .map((item) => _RescueItemBadge(item: item))
                          .toList(),
                    ),
                  ],
                  if (widget.rescueRecipes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.rescueRecipes.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final match = widget.rescueRecipes[index];
                          return _RescueRecipeCard(
                            match: match,
                            onOpen: () => widget.onOpenRecipe(match),
                            onAddToPlan: widget.onAddRecipeToPlan != null
                                ? () => widget.onAddRecipeToPlan!(match)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                  if (widget.onOpenRecipesTab != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.onOpenRecipesTab,
                        style: TextButton.styleFrom(
                          foregroundColor: context.accentWarm,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Tümünü Gör',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RescueItemBadge extends StatelessWidget {
  final PantryItem item;

  const _RescueItemBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isUrgentExpiry = item.isExpired || item.isExpiringSoon;
    final isCritical = item.isExpired || item.daysRemaining <= 1;
    final badgeColor = isCritical ? context.accentDanger : context.accentWarm;
    final badgeBg =
        isCritical ? context.pastelBlushTint : context.surfaceColor;

    final String statusText;
    if (item.isExpired) {
      statusText = 'Süresi geçti (${item.daysRemaining.abs()}g)';
    } else if (item.daysRemaining == 0) {
      statusText = 'Bugün son';
    } else if (isUrgentExpiry) {
      statusText = 'Son ${item.daysRemaining}g';
    } else {
      statusText = '${item.daysInPantry}g bekliyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${item.name} · $statusText',
        style: TextStyle(
          color: badgeColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RescueRecipeCard extends StatelessWidget {
  final EvaluatedRecipeMatch match;
  final VoidCallback onOpen;
  final VoidCallback? onAddToPlan;

  const _RescueRecipeCard({
    required this.match,
    required this.onOpen,
    required this.onAddToPlan,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final totalMin =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;
    final rescuedNames = <String>{
      ...match.expiringIngredientsUsed.map((e) => e.name),
      ...match.longWaitingIngredientsUsed.map((e) => e.name),
    }.toList();

    return Container(
      width: 224,
      padding: const EdgeInsets.all(11),
      decoration: BioMinimalUi.cardDecoration(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$totalMin dk · %${match.matchPercent} Kiler · Skor ${match.combinedHealthScore}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              rescuedNames.isNotEmpty
                  ? 'Değerlendirir: ${rescuedNames.take(3).join(', ')}'
                  : recipe.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.accentWarm,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentPrimary,
                    side: BorderSide(
                      color: context.accentPrimary.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Tarifi Aç',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (onAddToPlan != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAddToPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: context.onAccentPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Takvime Ekle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
