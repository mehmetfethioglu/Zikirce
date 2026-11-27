import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kilerce_logo_mark.dart';
import '../../domain/recipe_models.dart';
import 'kitchen_checkin_sheets.dart';
import 'recipe_match_card.dart';
import 'recipe_visual_header.dart';

/// Weekly meal planner view with week navigation, smart preset generator,
/// 7-day selector, daily nutrition summary, overview/detail toggle, and 4 meal slots.
class WeeklyMealPlannerView extends StatefulWidget {
  final MealModuleState state;
  final Set<String> pantryTags;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onGoToCurrentWeek;
  final ValueChanged<MealPlanPreset> onPresetChanged;
  final ValueChanged<int> onServingsChanged;
  final VoidCallback onGenerateSmartWeek;
  final VoidCallback onTransferMissingToShopping;
  final VoidCallback onShareWeek;
  final VoidCallback onClearWeek;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<bool> onToggleOverview;
  final void Function(String dateIso, MealSlot slot) onAddMealToSlot;
  final ValueChanged<MealPlanEntry> onMarkEntryCooked;
  final ValueChanged<MealPlanEntry> onRemoveEntry;
  final ValueChanged<String> onOpenRecipe;
  final ValueChanged<KitchenDailyPrompt>? onAddPromptMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtPromptMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozePromptMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmPromptCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplannedPrompt;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplannedPrompt;
  final void Function(String dateIso, MealSlot slot)? onQuickConsumeSlot;

  const WeeklyMealPlannerView({
    super.key,
    required this.state,
    required this.pantryTags,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPresetChanged,
    required this.onServingsChanged,
    required this.onGenerateSmartWeek,
    required this.onTransferMissingToShopping,
    required this.onShareWeek,
    required this.onClearWeek,
    required this.onSelectDate,
    required this.onToggleOverview,
    required this.onAddMealToSlot,
    required this.onMarkEntryCooked,
    required this.onRemoveEntry,
    required this.onOpenRecipe,
    this.onGoToCurrentWeek,
    this.onAddPromptMissingToShopping,
    this.onBoughtPromptMissingToPantry,
    this.onSnoozePromptMissing,
    this.onConfirmPromptCooked,
    this.onPostponePromptPlanned,
    this.onSkipPromptPlanned,
    this.onOpenUnplannedPrompt,
    this.onSkipUnplannedPrompt,
    this.onQuickConsumeSlot,
  });

  @override
  State<WeeklyMealPlannerView> createState() => _WeeklyMealPlannerViewState();
}

class _WeeklyMealPlannerViewState extends State<WeeklyMealPlannerView> {
  bool _showPlannerSetup = false;

  Future<void> _confirmClearWeek(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Haftalık Listeyi Temizle'),
        content: const Text(
          'Bu haftaya planlanmış tüm öğünler silinecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onClearWeek();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pantryTags = widget.pantryTags;
    final monday = MealDateUtils.fromIsoDate(state.currentWeekMondayIso);
    final days = MealDateUtils.daysOfWeek(monday);
    final todayIso = MealDateUtils.toIsoDate(DateTime.now());
    final selectedDate = MealDateUtils.fromIsoDate(state.selectedDateIso);
    final summary = state.dailySummaryFor(state.selectedDateIso, pantryTags);
    final hasEntries = state.weekEntries.isNotEmpty;

    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            state.activePrompts.isNotEmpty ? 92 : 28,
          ),
          children: [
            _WeekNavigatorBar(
              monday: monday,
              onPreviousWeek: widget.onPreviousWeek,
              onNextWeek: widget.onNextWeek,
              onGoToCurrentWeek: widget.onGoToCurrentWeek,
            ),
            const SizedBox(height: 10),
            if (!hasEntries || _showPlannerSetup) ...[
              _SmartPlannerConfigCard(
                selectedPreset: state.selectedPreset,
                planServings: state.planServings,
                isLoading: state.isLoading,
                onPresetChanged: widget.onPresetChanged,
                onServingsChanged: widget.onServingsChanged,
                onGenerateSmartWeek: () {
                  if (_showPlannerSetup) {
                    setState(() => _showPlannerSetup = false);
                  }
                  widget.onGenerateSmartWeek();
                },
              ),
              const SizedBox(height: 10),
            ],
            if (hasEntries) ...[
              _CompactPlannerToolbar(
                showSetup: _showPlannerSetup,
                gapsCount: state.weeklyShoppingGaps.length,
                onToggleSetup: () =>
                    setState(() => _showPlannerSetup = !_showPlannerSetup),
                onTransferMissing: state.weeklyShoppingGaps.isNotEmpty
                    ? widget.onTransferMissingToShopping
                    : null,
                onShareWeek: widget.onShareWeek,
                onClearWeek: () => _confirmClearWeek(context),
              ),
              const SizedBox(height: 10),
            ],
            _SevenDayStrip(
              days: days,
              selectedDateIso: state.selectedDateIso,
              todayIso: todayIso,
              countForDate: state.entriesCountForDate,
              onSelectDate: widget.onSelectDate,
            ),
            const SizedBox(height: 10),
            _DailySummaryAndModeCard(
              selectedDate: selectedDate,
              summary: summary,
              showFullWeekOverview: state.showFullWeekOverview,
              onToggleOverview: widget.onToggleOverview,
            ),
            const SizedBox(height: 10),
            if (state.showFullWeekOverview)
              _FullWeekOverviewSection(
                days: days,
                state: state,
                onSelectDayDetail: (iso) {
                  widget.onSelectDate(iso);
                  widget.onToggleOverview(false);
                },
              )
            else
              ...MealSlot.values.map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealSlotSectionCard(
                    slot: slot,
                    entries: state.entriesForDateAndSlot(
                      state.selectedDateIso,
                      slot,
                    ),
                    recipeById: state.recipeById,
                    pantryTags: pantryTags,
                    onAddMeal: () =>
                        widget.onAddMealToSlot(state.selectedDateIso, slot),
                    onQuickConsumeSlot: widget.onQuickConsumeSlot != null
                        ? () => widget.onQuickConsumeSlot!(
                              state.selectedDateIso,
                              slot,
                            )
                        : null,
                    onMarkCooked: widget.onMarkEntryCooked,
                    onRemoveEntry: widget.onRemoveEntry,
                    onOpenRecipe: widget.onOpenRecipe,
                  ),
                ),
              ),
          ],
        ),
        if (state.activePrompts.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: KitchenDailyAssistantFab(
              prompts: state.activePrompts,
              onAddPromptMissingToShopping: widget.onAddPromptMissingToShopping,
              onBoughtPromptMissingToPantry:
                  widget.onBoughtPromptMissingToPantry,
              onSnoozePromptMissing: widget.onSnoozePromptMissing,
              onConfirmPromptCooked: widget.onConfirmPromptCooked,
              onPostponePromptPlanned: widget.onPostponePromptPlanned,
              onSkipPromptPlanned: widget.onSkipPromptPlanned,
              onOpenUnplannedPrompt: widget.onOpenUnplannedPrompt,
              onSkipUnplannedPrompt: widget.onSkipUnplannedPrompt,
            ),
          ),
      ],
    );
  }
}

class _WeekNavigatorBar extends StatelessWidget {
  final DateTime monday;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onGoToCurrentWeek;

  const _WeekNavigatorBar({
    required this.monday,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onGoToCurrentWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BioMinimalUi.cardDecoration(context, radius: 18),
      child: Row(
        children: [
          IconButton(
            onPressed: onPreviousWeek,
            tooltip: 'Önceki Hafta',
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'HAFTALIK YEMEK PLANI',
                  style: TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  MealDateUtils.weekRangeLabel(monday),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onGoToCurrentWeek != null)
            TextButton(
              onPressed: onGoToCurrentWeek,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryEmerald,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Bu Hafta',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          IconButton(
            onPressed: onNextWeek,
            tooltip: 'Sonraki Hafta',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _SmartPlannerConfigCard extends StatelessWidget {
  static const List<int> _servingChoices = [1, 2, 4, 6, 8];

  final MealPlanPreset selectedPreset;
  final int planServings;
  final bool isLoading;
  final ValueChanged<MealPlanPreset> onPresetChanged;
  final ValueChanged<int> onServingsChanged;
  final VoidCallback onGenerateSmartWeek;

  const _SmartPlannerConfigCard({
    required this.selectedPreset,
    required this.planServings,
    required this.isLoading,
    required this.onPresetChanged,
    required this.onServingsChanged,
    required this.onGenerateSmartWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BioMinimalUi.cardDecoration(
        context,
        accentBorder: AppColors.primaryEmerald.withValues(alpha: 0.35),
        radius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Akıllı Haftalık Menü Modu',
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MealPlanPreset.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final preset = MealPlanPreset.values[index];
                final selected = preset == selectedPreset;
                return InkWell(
                  onTap: () => onPresetChanged(preset),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
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
                      '${preset.emoji} ${preset.label}',
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryEmerald
                            : context.textPrimaryColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedPreset.description,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Porsiyon:',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: _servingChoices.map((count) {
                    final selected = planServings == count;
                    return InkWell(
                      onTap: () => onServingsChanged(count),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryEmerald
                              : context.subtleSurfaceColor,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryEmerald
                                : context.cardBorderColor,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : context.textPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onGenerateSmartWeek,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Akıllı Haftalık Liste Oluştur',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPlannerToolbar extends StatelessWidget {
  final bool showSetup;
  final int gapsCount;
  final VoidCallback onToggleSetup;
  final VoidCallback? onTransferMissing;
  final VoidCallback onShareWeek;
  final VoidCallback onClearWeek;

  const _CompactPlannerToolbar({
    required this.showSetup,
    required this.gapsCount,
    required this.onToggleSetup,
    required this.onTransferMissing,
    required this.onShareWeek,
    required this.onClearWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BioMinimalUi.cardDecoration(context, radius: 16),
      child: Row(
        children: [
          Flexible(
            child: OutlinedButton.icon(
              onPressed: onToggleSetup,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryEmerald,
                backgroundColor: showSetup
                    ? AppColors.primaryEmerald.withValues(alpha: 0.14)
                    : null,
                side: BorderSide(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: Icon(
                showSetup
                    ? Icons.expand_less_rounded
                    : Icons.auto_awesome_rounded,
                size: 15,
              ),
              label: Text(
                showSetup ? 'Kapat' : 'Otomatik Plan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              onPressed: onTransferMissing,
              style: OutlinedButton.styleFrom(
                foregroundColor: gapsCount > 0
                    ? AppColors.cautionGold
                    : context.textSecondaryColor,
                side: BorderSide(
                  color: gapsCount > 0
                      ? AppColors.cautionGold
                      : context.cardBorderColor,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Eksikler ($gapsCount)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onShareWeek,
            tooltip: 'Paylaş',
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            color: AppColors.primaryEmerald,
            icon: const Icon(Icons.share_rounded, size: 19),
          ),
          IconButton(
            onPressed: onClearWeek,
            tooltip: 'Haftayı Temizle',
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            color: AppColors.dangerRed,
            icon: const Icon(Icons.delete_sweep_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _SevenDayStrip extends StatelessWidget {
  final List<DateTime> days;
  final String selectedDateIso;
  final String todayIso;
  final int Function(String dateIso) countForDate;
  final ValueChanged<String> onSelectDate;

  const _SevenDayStrip({
    required this.days,
    required this.selectedDateIso,
    required this.todayIso,
    required this.countForDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Row(
        children: days.map((date) {
          final iso = MealDateUtils.toIsoDate(date);
          final selected = iso == selectedDateIso;
          final isToday = iso == todayIso;
          final count = countForDate(iso);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: InkWell(
                onTap: () => onSelectDate(iso),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryEmerald
                        : context.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryEmerald
                          : isToday
                              ? AppColors.primaryEmerald.withValues(alpha: 0.55)
                              : context.cardBorderColor,
                      width: isToday && !selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        MealDateUtils.weekdayShortLabel(date),
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : context.textSecondaryColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : context.textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.24)
                              : count > 0
                                  ? AppColors.primaryEmerald.withValues(
                                      alpha: 0.14,
                                    )
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          count > 0 ? '$count' : '·',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : count > 0
                                    ? AppColors.primaryEmerald
                                    : context.textSecondaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DailySummaryAndModeCard extends StatelessWidget {
  final DateTime selectedDate;
  final DailyNutritionSummary summary;
  final bool showFullWeekOverview;
  final ValueChanged<bool> onToggleOverview;

  const _DailySummaryAndModeCard({
    required this.selectedDate,
    required this.summary,
    required this.showFullWeekOverview,
    required this.onToggleOverview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BioMinimalUi.cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showFullWeekOverview
                          ? '7 Günlük Haftalık Özet'
                          : '${MealDateUtils.weekdayFullLabel(selectedDate)}, ${MealDateUtils.shortDayMonth(selectedDate)}',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      summary.plannedCount == 0
                          ? 'Bu gün için henüz öğün planlanmadı'
                          : '${summary.cookedCount}/${summary.plannedCount} öğün pişirildi • ${(summary.readyInPantryRatio * 100).round()}% evde hazır',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeTogglePill(
                showFullWeekOverview: showFullWeekOverview,
                onToggle: onToggleOverview,
              ),
            ],
          ),
          if (!showFullWeekOverview && summary.plannedCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.subtleSurfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _SummaryStat(
                        label: 'Kalori',
                        value: '${summary.totalCalories} kcal',
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _SummaryStat(
                        label: 'Protein',
                        value: '${summary.totalProtein} g',
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _SummaryStat(
                        label: 'Lif',
                        value: '${summary.totalFiber} g',
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _SummaryStat(
                        label: 'Ort. Skor',
                        value: '${summary.averageCleanScore}/100',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTogglePill extends StatelessWidget {
  final bool showFullWeekOverview;
  final ValueChanged<bool> onToggle;

  const _ModeTogglePill({
    required this.showFullWeekOverview,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Detay',
            selected: !showFullWeekOverview,
            onTap: () => onToggle(false),
          ),
          _ToggleSegment(
            label: 'Özet',
            selected: showFullWeekOverview,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.textSecondaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.textPrimaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _FullWeekOverviewSection extends StatelessWidget {
  final List<DateTime> days;
  final MealModuleState state;
  final ValueChanged<String> onSelectDayDetail;

  const _FullWeekOverviewSection({
    required this.days,
    required this.state,
    required this.onSelectDayDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: days.map((date) {
        final iso = MealDateUtils.toIsoDate(date);
        final dayEntries =
            state.weekEntries.where((e) => e.planDate == iso).toList();
        int totalCalories = 0;
        for (final entry in dayEntries) {
          totalCalories += state.recipeById[entry.recipeId]?.calories ?? 0;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelectDayDetail(iso),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BioMinimalUi.cardDecoration(
                context,
                accentBorder: iso == state.selectedDateIso
                    ? AppColors.primaryEmerald.withValues(alpha: 0.5)
                    : null,
                radius: 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${MealDateUtils.weekdayFullLabel(date)} • ${MealDateUtils.shortDayMonth(date)}',
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dayEntries.isEmpty
                            ? 'Plan yok'
                            : '${dayEntries.length} öğün • $totalCalories kcal',
                        style: TextStyle(
                          color: dayEntries.isEmpty
                              ? context.textSecondaryColor
                              : AppColors.primaryEmerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (dayEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: dayEntries.map((entry) {
                        final recipe = state.recipeById[entry.recipeId];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: entry.isCooked
                                ? AppColors.primaryEmerald.withValues(
                                    alpha: 0.14,
                                  )
                                : context.subtleSurfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.cardBorderColor),
                          ),
                          child: Text(
                            '${entry.mealSlot.emoji} ${recipe?.title ?? entry.recipeId}${entry.isCooked ? ' ✓' : ''}',
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MealSlotSectionCard extends StatelessWidget {
  final MealSlot slot;
  final List<MealPlanEntry> entries;
  final Map<String, KilerRecipe> recipeById;
  final Set<String> pantryTags;
  final VoidCallback onAddMeal;
  final VoidCallback? onQuickConsumeSlot;
  final ValueChanged<MealPlanEntry> onMarkCooked;
  final ValueChanged<MealPlanEntry> onRemoveEntry;
  final ValueChanged<String> onOpenRecipe;

  const _MealSlotSectionCard({
    required this.slot,
    required this.entries,
    required this.recipeById,
    required this.pantryTags,
    required this.onAddMeal,
    required this.onQuickConsumeSlot,
    required this.onMarkCooked,
    required this.onRemoveEntry,
    required this.onOpenRecipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BioMinimalUi.cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(slot.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (entries.isEmpty && onQuickConsumeSlot != null) ...[
                OutlinedButton(
                  onPressed: onQuickConsumeSlot,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMint,
                    side: BorderSide(
                      color: AppColors.primaryMint.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    '🧺 Kilerden',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              TextButton.icon(
                onPressed: onAddMeal,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryEmerald,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                label: const Text(
                  'Tarif Ekle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Bu öğün için henüz tarif eklenmedi.',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            ...entries.asMap().entries.map((indexed) {
              final entry = indexed.value;
              final isLast = indexed.key == entries.length - 1;
              final recipe = recipeById[entry.recipeId];
              final missingCount = recipe == null
                  ? 0
                  : recipe.requiredTags
                      .where((tag) => !pantryTags.contains(tag))
                      .length;
              final isReady = recipe != null && missingCount == 0;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: _MealEntryTile(
                  entry: entry,
                  recipe: recipe,
                  isReadyInPantry: isReady,
                  missingCount: missingCount,
                  onOpen: () => onOpenRecipe(entry.recipeId),
                  onMarkCooked: () => onMarkCooked(entry),
                  onRemove: () => onRemoveEntry(entry),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MealEntryTile extends StatelessWidget {
  final MealPlanEntry entry;
  final KilerRecipe? recipe;
  final bool isReadyInPantry;
  final int missingCount;
  final VoidCallback onOpen;
  final VoidCallback onMarkCooked;
  final VoidCallback onRemove;

  const _MealEntryTile({
    required this.entry,
    required this.recipe,
    required this.isReadyInPantry,
    required this.missingCount,
    required this.onOpen,
    required this.onMarkCooked,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final KilerRecipe? resolvedRecipe = recipe;
    final title = resolvedRecipe?.title ?? entry.recipeId;
    final minutes = resolvedRecipe == null
        ? 0
        : (resolvedRecipe.totalMinutes > 0
            ? resolvedRecipe.totalMinutes
            : resolvedRecipe.prepMinutes);
    final String subtitleText = resolvedRecipe != null
        ? '${entry.servings} kişilik • $minutes dk • ${resolvedRecipe.scaledCalories(entry.servings)} kcal'
        : '${entry.servings} kişilik';

    return Container(
      height: 172,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: entry.isCooked
              ? AppColors.primaryEmerald.withValues(alpha: 0.85)
              : context.cardBorderColor,
          width: entry.isCooked ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedRecipe != null)
              RecipeVisualHeader(
                recipe: resolvedRecipe,
                height: 172,
                showOverlays: false,
                borderRadius: BorderRadius.zero,
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF10241C),
                      Color(0xFF0A1410),
                    ],
                  ),
                ),
                child: Center(
                  child: KilerceLogoMark(
                    size: 52,
                    borderRadius: 14,
                    showShadow: false,
                  ),
                ),
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
                  onTap: onOpen,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
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
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  if (resolvedRecipe != null) ...[
                    _MealOverlayCircleBadge(
                      tooltip: resolvedRecipe.category,
                      child: Icon(
                        RecipeMatchCard.iconForCategory(resolvedRecipe.category),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (resolvedRecipe != null && isReadyInPantry)
                    const _MealOverlayCircleBadge(
                      tooltip: 'Kilerde hazır',
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryEmerald,
                        size: 17,
                      ),
                    )
                  else if (resolvedRecipe != null && missingCount > 0)
                    _MealOverlayPill(
                      tooltip: '$missingCount malzeme eksik',
                      child: Text(
                        '-$missingCount',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const _MealOverlayCircleBadge(
                      tooltip: 'Tarif bilgisi yok',
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white70,
                        size: 15,
                      ),
                    ),
                  const Spacer(),
                  if (resolvedRecipe != null) ...[
                    _MealOverlayPill(
                      child: Text(
                        '${resolvedRecipe.baseHealthScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Semantics(
                    button: true,
                    label: entry.isCooked ? 'Pişirildi' : 'Pişirdim',
                    child: _MealOverlayCircleButton(
                      tooltip: entry.isCooked ? 'Pişirildi' : 'Pişirdim',
                      backgroundColor: entry.isCooked
                          ? AppColors.primaryEmerald.withValues(alpha: 0.92)
                          : const Color(0x78000000),
                      onTap: onMarkCooked,
                      child: Icon(
                        entry.isCooked
                            ? Icons.check_rounded
                            : Icons.local_dining_rounded,
                        size: entry.isCooked ? 18 : 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: 'Planlanan Öğünü Sil',
                    child: _MealOverlayCircleButton(
                      tooltip: 'Planlanan Öğünü Sil',
                      backgroundColor: const Color(0x78000000),
                      onTap: onRemove,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.90),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealOverlayCircleBadge extends StatelessWidget {
  final String tooltip;
  final Widget child;

  const _MealOverlayCircleBadge({
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

class _MealOverlayPill extends StatelessWidget {
  final String? tooltip;
  final Widget child;

  const _MealOverlayPill({
    this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x78000000),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}

class _MealOverlayCircleButton extends StatelessWidget {
  final String tooltip;
  final Color backgroundColor;
  final VoidCallback onTap;
  final Widget child;

  const _MealOverlayCircleButton({
    required this.tooltip,
    required this.backgroundColor,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
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
