import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family_profiles/domain/family_profile_engine.dart';
import '../../../kiler/domain/kiler_models.dart';
import '../../../kiler/presentation/widgets/quick_ingredient_add_sheet.dart';
import '../../domain/recipe_models.dart';
import 'pantry_waste_rescue_card.dart';
import 'recipe_match_card.dart';

/// Streamlined explore view with compact search, single-row active filter bar,
/// modal multi-facet filter sheet, and clutter-free recipe match cards.
class RecipeCatalogExploreView extends StatefulWidget {
  final List<EvaluatedRecipeMatch> matches;
  final RecipeFilterTab selectedFilter;
  final String? selectedCategory;
  final String? selectedRegion;
  final String searchQuery;
  final FamilyProfile? activeProfile;
  final int pantryItemCount;
  final int readyNowCount;
  final int wasteSaverCount;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<RecipeFilterTab> onFilterChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?>? onRegionChanged;
  final ValueChanged<EvaluatedRecipeMatch> onRecipeTap;
  final ValueChanged<EvaluatedRecipeMatch> onToggleFavorite;
  final ValueChanged<EvaluatedRecipeMatch> onQuickAddToPlan;
  final VoidCallback? onOpenCustomRecipeForm;
  final VoidCallback? onPantryUpdated;
  final List<PantryItem> rescueItems;
  final List<EvaluatedRecipeMatch> wasteRescueMatches;
  final ValueChanged<EvaluatedRecipeMatch>? onAddRescueRecipeToPlan;
  final Future<int> Function(List<DraftPantryAddition> drafts)?
      onBatchAddPantryItems;

  const RecipeCatalogExploreView({
    super.key,
    required this.matches,
    required this.selectedFilter,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCategoryChanged,
    required this.onRecipeTap,
    required this.onToggleFavorite,
    required this.onQuickAddToPlan,
    this.selectedRegion,
    this.onRegionChanged,
    this.activeProfile,
    this.pantryItemCount = 0,
    this.readyNowCount = 0,
    this.wasteSaverCount = 0,
    this.isLoading = false,
    this.onOpenCustomRecipeForm,
    this.onPantryUpdated,
    this.rescueItems = const [],
    this.wasteRescueMatches = const [],
    this.onAddRescueRecipeToPlan,
    this.onBatchAddPantryItems,
  });

  @override
  State<RecipeCatalogExploreView> createState() =>
      _RecipeCatalogExploreViewState();
}

class _RecipeCatalogExploreViewState extends State<RecipeCatalogExploreView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant RecipeCatalogExploreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: widget.searchQuery.length,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openQuickIngredientAdd() async {
    await QuickIngredientAddSheet.show(
      context,
      onBatchAdd: widget.onBatchAddPantryItems,
    );
    if (!mounted) return;
    widget.onPantryUpdated?.call();
  }

  Future<void> _openFilterSheet() async {
    final result = await _RecipeFilterSheet.show(
      context,
      initialFilter: widget.selectedFilter,
      initialRegion: widget.selectedRegion,
      initialCategory: widget.selectedCategory,
    );
    if (!mounted || result == null) return;

    if (result.filter != widget.selectedFilter) {
      widget.onFilterChanged(result.filter);
    }
    if (result.region != widget.selectedRegion) {
      widget.onRegionChanged?.call(result.region);
    }
    if (result.category != widget.selectedCategory) {
      widget.onCategoryChanged(result.category);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
  }

  void _resetAllFilters() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      widget.onSearchChanged('');
    }
    if (widget.selectedFilter != RecipeFilterTab.all) {
      widget.onFilterChanged(RecipeFilterTab.all);
    }
    if (widget.selectedCategory != null) {
      widget.onCategoryChanged(null);
    }
    if (widget.selectedRegion != null) {
      widget.onRegionChanged?.call(null);
    }
  }

  bool get _hasRegionFilter =>
      widget.selectedRegion != null &&
      widget.selectedRegion!.isNotEmpty &&
      widget.selectedRegion != TurkishRegionRegistry.all;

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = widget.selectedFilter != RecipeFilterTab.all ||
        widget.selectedCategory != null ||
        _hasRegionFilter ||
        widget.searchQuery.trim().isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RecipeSearchBar(
                        controller: _searchController,
                        hasQuery: widget.searchQuery.isNotEmpty,
                        onChanged: widget.onSearchChanged,
                        onClear: _clearSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Dolaba Malzeme Ekle',
                      child: OutlinedButton.icon(
                        onPressed: _openQuickIngredientAdd,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryEmerald,
                          side: BorderSide(
                            color: AppColors.primaryEmerald
                                .withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 11,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.kitchen_rounded, size: 17),
                        label: const Text(
                          'Malzeme',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SingleRowSmartFilterBar(
                  selectedFilter: widget.selectedFilter,
                  selectedRegion: widget.selectedRegion,
                  selectedCategory: widget.selectedCategory,
                  readyNowCount: widget.readyNowCount,
                  wasteSaverCount: widget.wasteSaverCount,
                  activeProfile: widget.activeProfile,
                  onOpenFilterSheet: _openFilterSheet,
                  onFilterChanged: widget.onFilterChanged,
                  onRegionChanged: widget.onRegionChanged,
                  onCategoryChanged: widget.onCategoryChanged,
                  onClearAll: _resetAllFilters,
                ),
                if (widget.rescueItems.isNotEmpty ||
                    widget.wasteRescueMatches.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  PantryWasteRescueCard(
                    rescueItems: widget.rescueItems,
                    rescueRecipes: widget.wasteRescueMatches,
                    onOpenRecipe: widget.onRecipeTap,
                    onAddRecipeToPlan:
                        widget.onAddRescueRecipeToPlan ?? widget.onQuickAddToPlan,
                    onOpenRecipesTab: widget.wasteRescueMatches.isNotEmpty
                        ? () =>
                            widget.onFilterChanged(RecipeFilterTab.wasteSaver)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.isLoading && widget.matches.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryEmerald,
              ),
            ),
          )
        else if (widget.matches.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ExploreEmptyState(
              selectedFilter: widget.selectedFilter,
              hasActiveFilters: hasActiveFilters,
              onResetFilters: _resetAllFilters,
              onQuickAddIngredient: _openQuickIngredientAdd,
              onOpenCustomRecipeForm: widget.onOpenCustomRecipeForm,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
            sliver: SliverList.separated(
              itemCount: widget.matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final match = widget.matches[index];
                return RecipeMatchCard(
                  key: ValueKey(match.recipe.id),
                  match: match,
                  onTap: () => widget.onRecipeTap(match),
                  onToggleFavorite: () => widget.onToggleFavorite(match),
                  onQuickAddToPlan: () => widget.onQuickAddToPlan(match),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecipeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _RecipeSearchBar({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: context.textPrimaryColor, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Tarif veya malzeme ara...',
        hintStyle: TextStyle(color: context.textSecondaryColor, fontSize: 12.5),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primaryEmerald,
          size: 20,
        ),
        suffixIcon: hasQuery
            ? IconButton(
                onPressed: onClear,
                tooltip: 'Aramayı Temizle',
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : null,
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.cardBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.cardBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryEmerald,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SingleRowSmartFilterBar extends StatelessWidget {
  final RecipeFilterTab selectedFilter;
  final String? selectedRegion;
  final String? selectedCategory;
  final int readyNowCount;
  final int wasteSaverCount;
  final FamilyProfile? activeProfile;
  final VoidCallback onOpenFilterSheet;
  final ValueChanged<RecipeFilterTab> onFilterChanged;
  final ValueChanged<String?>? onRegionChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClearAll;

  const _SingleRowSmartFilterBar({
    required this.selectedFilter,
    required this.selectedRegion,
    required this.selectedCategory,
    required this.readyNowCount,
    required this.wasteSaverCount,
    required this.activeProfile,
    required this.onOpenFilterSheet,
    required this.onFilterChanged,
    required this.onRegionChanged,
    required this.onCategoryChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFilterTab = selectedFilter != RecipeFilterTab.all;
    final TurkishRegionMeta? regionMeta = (selectedRegion != null &&
            selectedRegion!.isNotEmpty &&
            selectedRegion != TurkishRegionRegistry.all)
        ? TurkishRegionRegistry.findById(selectedRegion)
        : null;
    final RecipeCategoryMeta? categoryMeta =
        RecipeCategoryRegistry.findById(selectedCategory);

    final int activeCount = (hasFilterTab ? 1 : 0) +
        (regionMeta != null ? 1 : 0) +
        (categoryMeta != null ? 1 : 0);

    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _FilterTriggerButton(
              activeCount: activeCount,
              onTap: onOpenFilterSheet,
            ),
            const SizedBox(width: 7),
            if (activeCount > 0) ...[
              if (hasFilterTab) ...[
                _SelectedFacetChip(
                  label: '${selectedFilter.label} ×',
                  accent: AppColors.primaryEmerald,
                  onTap: () => onFilterChanged(RecipeFilterTab.all),
                ),
                const SizedBox(width: 6),
              ],
              if (regionMeta != null) ...[
                _SelectedFacetChip(
                  label: '${regionMeta.emoji} ${regionMeta.shortLabel} ×',
                  accent: AppColors.cautionGold,
                  onTap: () => onRegionChanged?.call(null),
                ),
                const SizedBox(width: 6),
              ],
              if (categoryMeta != null) ...[
                _SelectedFacetChip(
                  label: '${categoryMeta.emoji} ${categoryMeta.shortLabel} ×',
                  accent: AppColors.primaryMint,
                  onTap: () => onCategoryChanged(null),
                ),
                const SizedBox(width: 6),
              ],
              if (activeCount >= 2)
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Temizle',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ] else ...[
              _QuickSummaryChip(
                label: '✅ Hazır ($readyNowCount)',
                accent: AppColors.primaryEmerald,
                onTap: () => onFilterChanged(RecipeFilterTab.readyNow),
              ),
              if (wasteSaverCount > 0) ...[
                const SizedBox(width: 6),
                _QuickSummaryChip(
                  label: '♻️ İsraf Önleyici ($wasteSaverCount)',
                  accent: AppColors.cautionGold,
                  onTap: () => onFilterChanged(RecipeFilterTab.wasteSaver),
                ),
              ],
              if (activeProfile != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '🛡️ ${activeProfile!.profileName}',
                    style: const TextStyle(
                      color: AppColors.primaryEmerald,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterTriggerButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterTriggerButton({
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasActive = activeCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: hasActive
              ? AppColors.primaryEmerald
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasActive
                ? AppColors.primaryEmerald
                : context.cardBorderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: hasActive ? Colors.white : context.textPrimaryColor,
            ),
            const SizedBox(width: 5),
            Text(
              hasActive ? 'Filtrele ($activeCount)' : 'Filtrele',
              style: TextStyle(
                color: hasActive ? Colors.white : context.textPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFacetChip extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SelectedFacetChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.65)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _QuickSummaryChip extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickSummaryChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.textPrimaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FilterSelectionResult {
  final RecipeFilterTab filter;
  final String? region;
  final String? category;

  const _FilterSelectionResult({
    required this.filter,
    required this.region,
    required this.category,
  });
}

class _RecipeFilterSheet extends StatefulWidget {
  final RecipeFilterTab initialFilter;
  final String? initialRegion;
  final String? initialCategory;

  const _RecipeFilterSheet({
    required this.initialFilter,
    required this.initialRegion,
    required this.initialCategory,
  });

  static Future<_FilterSelectionResult?> show(
    BuildContext context, {
    required RecipeFilterTab initialFilter,
    required String? initialRegion,
    required String? initialCategory,
  }) {
    return showModalBottomSheet<_FilterSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeFilterSheet(
        initialFilter: initialFilter,
        initialRegion: initialRegion,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<_RecipeFilterSheet> createState() => _RecipeFilterSheetState();
}

class _RecipeFilterSheetState extends State<_RecipeFilterSheet> {
  late RecipeFilterTab _filter;
  String? _region;
  String? _category;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _region = widget.initialRegion;
    _category = widget.initialCategory;
  }

  void _resetDraft() {
    setState(() {
      _filter = RecipeFilterTab.all;
      _region = null;
      _category = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeClassics = TurkishRegionRegistry.findById(
      TurkishRegionRegistry.tumTurkiye,
    );
    final regions = <TurkishRegionMeta>[
      ...TurkishRegionRegistry.sevenRegions,
      ?homeClassics,
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: AppColors.primaryEmerald,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tarif Filtreleri',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetDraft,
                child: const Text(
                  'Sıfırla',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FilterSectionTitle('Görünüm & Öncelik'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: RecipeFilterTab.values.map((tab) {
                      return _ModalSelectChip(
                        label: tab.label,
                        selected: _filter == tab,
                        accent: AppColors.primaryEmerald,
                        onTap: () => setState(() => _filter = tab),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const _FilterSectionTitle('Yöre / Bölge'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _ModalSelectChip(
                        label: '🗺️ Tümü',
                        selected: _region == null,
                        accent: AppColors.cautionGold,
                        onTap: () => setState(() => _region = null),
                      ),
                      ...regions.map((region) {
                        final selected = _region == region.id;
                        return _ModalSelectChip(
                          label: '${region.emoji} ${region.shortLabel}',
                          selected: selected,
                          accent: AppColors.cautionGold,
                          onTap: () => setState(
                            () => _region = selected ? null : region.id,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _FilterSectionTitle('Yemek Kategorisi'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _ModalSelectChip(
                        label: '🍽️ Tümü',
                        selected: _category == null,
                        accent: AppColors.primaryMint,
                        onTap: () => setState(() => _category = null),
                      ),
                      ...RecipeCategoryRegistry.categories.map((cat) {
                        final selected = _category == cat.id;
                        return _ModalSelectChip(
                          label: '${cat.emoji} ${cat.shortLabel}',
                          selected: selected,
                          accent: AppColors.primaryMint,
                          onTap: () => setState(
                            () => _category = selected ? null : cat.id,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _FilterSelectionResult(
                    filter: _filter,
                    region: _region,
                    category: _category,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sonuçları Göster',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String text;

  const _FilterSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ModalSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModalSelectChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : context.textPrimaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExploreEmptyState extends StatelessWidget {
  final RecipeFilterTab selectedFilter;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;
  final VoidCallback onQuickAddIngredient;
  final VoidCallback? onOpenCustomRecipeForm;

  const _ExploreEmptyState({
    required this.selectedFilter,
    required this.hasActiveFilters,
    required this.onResetFilters,
    required this.onQuickAddIngredient,
    required this.onOpenCustomRecipeForm,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomTab = selectedFilter == RecipeFilterTab.custom;
    final isFavTab = selectedFilter == RecipeFilterTab.favorites;

    final title = isCustomTab
        ? 'Henüz özel tarif eklemediniz'
        : isFavTab
            ? 'Henüz favori tarifiniz yok'
            : 'Aradığınız kriterlere uygun tarif bulunamadı';
    final subtitle = isCustomTab
        ? 'Kendi ev tariflerinizi ekleyin, dolabınızdaki malzemelerle otomatik eşleşsin.'
        : isFavTab
            ? 'Beğendiğiniz tariflerdeki kalp simgesine dokunarak favorilere ekleyin.'
            : 'Filtreleri temizleyebilir veya dolabınıza yeni malzeme ekleyebilirsiniz.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCustomTab
                  ? '📝'
                  : isFavTab
                      ? '❤️'
                      : '🍲',
              style: const TextStyle(fontSize: 42),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (isCustomTab && onOpenCustomRecipeForm != null)
                  ElevatedButton.icon(
                    onPressed: onOpenCustomRecipeForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('İlk Özel Tarifi Oluştur'),
                  ),
                if (hasActiveFilters)
                  OutlinedButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                    label: const Text('Filtreleri Temizle'),
                  ),
                OutlinedButton.icon(
                  onPressed: onQuickAddIngredient,
                  icon: const Icon(Icons.kitchen_rounded, size: 17),
                  label: const Text('Dolaba Malzeme Ekle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
