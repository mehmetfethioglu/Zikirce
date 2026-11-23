import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/recipe_models.dart';

/// Result returned when picking a meal plan slot or recipe.
class MealSlotSelectionResult {
  final String planDateIso;
  final MealSlot mealSlot;
  final String recipeId;
  final int servings;

  const MealSlotSelectionResult({
    required this.planDateIso,
    required this.mealSlot,
    required this.recipeId,
    required this.servings,
  });
}

/// Bottom sheet entry points for adding a recipe to a weekly slot
/// or picking a catalog recipe for a given date and meal slot.
class MealSlotPickerSheet {
  const MealSlotPickerSheet._();

  static Future<MealSlotSelectionResult?> showForRecipe(
    BuildContext context, {
    required KilerRecipe recipe,
    String? weekMondayIso,
    String? initialDateIso,
    MealSlot? initialSlot,
    int? initialServings,
    void Function(String dateIso, MealSlot slot, int servings)? onConfirm,
  }) {
    return showModalBottomSheet<MealSlotSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeToSlotSheet(
        recipe: recipe,
        weekMondayIso: weekMondayIso,
        initialDateIso: initialDateIso,
        initialSlot: initialSlot,
        initialServings: initialServings,
        onConfirm: onConfirm,
      ),
    );
  }

  static Future<MealSlotSelectionResult?> showForSlot(
    BuildContext context, {
    required String planDateIso,
    required MealSlot slot,
    required List<EvaluatedRecipeMatch> matches,
    int initialServings = 2,
    void Function(String recipeId, int servings)? onSelectRecipe,
  }) {
    return showModalBottomSheet<MealSlotSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotToRecipeSheet(
        planDateIso: planDateIso,
        slot: slot,
        matches: matches,
        initialServings: initialServings,
        onSelectRecipe: onSelectRecipe,
      ),
    );
  }
}

class _RecipeToSlotSheet extends StatefulWidget {
  final KilerRecipe recipe;
  final String? weekMondayIso;
  final String? initialDateIso;
  final MealSlot? initialSlot;
  final int? initialServings;
  final void Function(String dateIso, MealSlot slot, int servings)? onConfirm;

  const _RecipeToSlotSheet({
    required this.recipe,
    this.weekMondayIso,
    this.initialDateIso,
    this.initialSlot,
    this.initialServings,
    this.onConfirm,
  });

  @override
  State<_RecipeToSlotSheet> createState() => _RecipeToSlotSheetState();
}

class _RecipeToSlotSheetState extends State<_RecipeToSlotSheet> {
  static const List<int> _portionOptions = [1, 2, 4, 6, 8];

  late DateTime _weekMonday;
  late String _selectedDateIso;
  late MealSlot _selectedSlot;
  late int _servings;

  @override
  void initState() {
    super.initState();
    final nowIso = MealDateUtils.toIsoDate(DateTime.now());
    _selectedDateIso = widget.initialDateIso ?? nowIso;
    final anchor = widget.weekMondayIso != null
        ? MealDateUtils.fromIsoDate(widget.weekMondayIso!)
        : MealDateUtils.fromIsoDate(_selectedDateIso);
    _weekMonday = MealDateUtils.startOfWeekMonday(anchor);
    _selectedSlot = widget.initialSlot ?? widget.recipe.primarySlot;
    final baseServings = widget.initialServings ?? widget.recipe.defaultServings;
    _servings = baseServings > 0 ? baseServings : 2;
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _weekMonday = _weekMonday.add(Duration(days: 7 * deltaWeeks));
      _selectedDateIso = MealDateUtils.toIsoDate(_weekMonday);
    });
  }

  void _confirm() {
    widget.onConfirm?.call(_selectedDateIso, _selectedSlot, _servings);
    Navigator.of(context).pop(
      MealSlotSelectionResult(
        planDateIso: _selectedDateIso,
        mealSlot: _selectedSlot,
        recipeId: widget.recipe.id,
        servings: _servings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = MealDateUtils.daysOfWeek(_weekMonday);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DragHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(widget.recipe.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yemek Planına Ekle',
                        style: TextStyle(
                          color: AppColors.primaryEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        widget.recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Gün Seçimi',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
                Text(
                  MealDateUtils.weekRangeLabel(_weekMonday),
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = days[index];
                  final iso = MealDateUtils.toIsoDate(date);
                  return _DayPickerPill(
                    date: date,
                    selected: iso == _selectedDateIso,
                    onTap: () => setState(() => _selectedDateIso = iso),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Öğün Seçimi',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealSlot.values.map((slot) {
                final selected = slot == _selectedSlot;
                return _SelectableOptionChip(
                  label: '${slot.emoji} ${slot.label}',
                  selected: selected,
                  onTap: () => setState(() => _selectedSlot = slot),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Porsiyon Sayısı',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _PortionChipRow(
              options: _portionOptions,
              selected: _servings,
              onSelect: (val) => setState(() => _servings = val),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  '${MealDateUtils.shortDayMonth(MealDateUtils.fromIsoDate(_selectedDateIso))} • ${_selectedSlot.label} ($_servings Kişilik) Ekle',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotToRecipeSheet extends StatefulWidget {
  final String planDateIso;
  final MealSlot slot;
  final List<EvaluatedRecipeMatch> matches;
  final int initialServings;
  final void Function(String recipeId, int servings)? onSelectRecipe;

  const _SlotToRecipeSheet({
    required this.planDateIso,
    required this.slot,
    required this.matches,
    required this.initialServings,
    this.onSelectRecipe,
  });

  @override
  State<_SlotToRecipeSheet> createState() => _SlotToRecipeSheetState();
}

class _SlotToRecipeSheetState extends State<_SlotToRecipeSheet> {
  static const List<int> _portionOptions = [1, 2, 4, 6, 8];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _onlySlotAppropriate = true;
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.initialServings > 0 ? widget.initialServings : 2;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EvaluatedRecipeMatch> get _filteredMatches {
    final q = _query.trim().toLowerCase();
    return widget.matches.where((m) {
      if (_onlySlotAppropriate && !m.recipe.mealSlots.contains(widget.slot)) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.recipe.title.toLowerCase().contains(q) ||
          m.recipe.subtitle.toLowerCase().contains(q) ||
          m.recipe.category.toLowerCase().contains(q) ||
          m.recipe.requiredTags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void _pickRecipe(EvaluatedRecipeMatch match) {
    widget.onSelectRecipe?.call(match.recipe.id, _servings);
    Navigator.of(context).pop(
      MealSlotSelectionResult(
        planDateIso: widget.planDateIso,
        mealSlot: widget.slot,
        recipeId: match.recipe.id,
        servings: _servings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = MealDateUtils.fromIsoDate(widget.planDateIso);
    final filtered = _filteredMatches;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(widget.slot.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${MealDateUtils.weekdayFullLabel(date)}, ${MealDateUtils.shortDayMonth(date)}',
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.slot.label} İçin Tarif Seç',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              hintText: 'Tarif veya malzeme ara...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: context.subtleSurfaceColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SelectableOptionChip(
                        label: '${widget.slot.emoji} Öğüne Uygun',
                        selected: _onlySlotAppropriate,
                        onTap: () => setState(() => _onlySlotAppropriate = true),
                      ),
                      const SizedBox(width: 8),
                      _SelectableOptionChip(
                        label: '📖 Tüm Tarifler',
                        selected: !_onlySlotAppropriate,
                        onTap: () =>
                            setState(() => _onlySlotAppropriate = false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Porsiyon:',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PortionChipRow(
                  options: _portionOptions,
                  selected: _servings,
                  onSelect: (val) => setState(() => _servings = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyPickerNotice(
                    onlySlotAppropriate: _onlySlotAppropriate,
                    onShowAll: () =>
                        setState(() => _onlySlotAppropriate = false),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final match = filtered[index];
                      return _CatalogPickerRow(
                        match: match,
                        onTap: () => _pickRecipe(match),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: context.textSecondaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _DayPickerPill extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DayPickerPill({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primaryEmerald
                : context.cardBorderColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              MealDateUtils.weekdayShortLabel(date),
              style: TextStyle(
                color: selected ? Colors.white : context.textSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? Colors.white : context.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald.withValues(alpha: 0.16)
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? AppColors.primaryEmerald
                : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryEmerald
                : context.textPrimaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PortionChipRow extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  const _PortionChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: options.map((val) {
        final isSelected = val == selected;
        return InkWell(
          onTap: () => onSelect(val),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryEmerald
                  : context.subtleSurfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryEmerald
                    : context.cardBorderColor,
              ),
            ),
            child: Text(
              '$val Kişi',
              style: TextStyle(
                color: isSelected ? Colors.white : context.textPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CatalogPickerRow extends StatelessWidget {
  final EvaluatedRecipeMatch match;
  final VoidCallback onTap;

  const _CatalogPickerRow({
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final totalMin =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;
    final statusColor = match.isReadyToCook
        ? AppColors.primaryEmerald
        : AppColors.cautionGold;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: !match.isProfileSafe
                ? AppColors.dangerRed.withValues(alpha: 0.45)
                : context.cardBorderColor,
          ),
        ),
        child: Row(
          children: [
            Text(recipe.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '⏱️ $totalMin dk • 🔥 ${recipe.calories} kcal • 💪 ${recipe.proteinGrams}g',
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 11,
                    ),
                  ),
                  if (!match.isProfileSafe) ...[
                    const SizedBox(height: 3),
                    Text(
                      '⚠️ ${match.profileWarnings.first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.dangerRed,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.isReadyToCook
                        ? '%100 Hazır'
                        : '${match.missingRequiredTags.length} Eksik',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primaryEmerald,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPickerNotice extends StatelessWidget {
  final bool onlySlotAppropriate;
  final VoidCallback onShowAll;

  const _EmptyPickerNotice({
    required this.onlySlotAppropriate,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 8),
            Text(
              'Eşleşen tarif bulunamadı.',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onlySlotAppropriate) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onShowAll,
                child: const Text('Tüm Katalog Tariflerini Göster'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
