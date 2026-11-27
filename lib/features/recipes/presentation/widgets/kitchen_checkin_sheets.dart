import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kiler/domain/kiler_models.dart';
import '../../domain/recipe_models.dart';

/// Pure-prop daily assistant banner rendering the highest-priority prompt first
/// with an expand/collapse toggle when multiple prompts are active.
class KitchenDailyAssistantBanner extends StatefulWidget {
  final List<KitchenDailyPrompt> prompts;
  final ValueChanged<KitchenDailyPrompt>? onAddPromptMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtPromptMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozePromptMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmPromptCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplannedPrompt;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplannedPrompt;

  const KitchenDailyAssistantBanner({
    super.key,
    required this.prompts,
    this.onAddPromptMissingToShopping,
    this.onBoughtPromptMissingToPantry,
    this.onSnoozePromptMissing,
    this.onConfirmPromptCooked,
    this.onPostponePromptPlanned,
    this.onSkipPromptPlanned,
    this.onOpenUnplannedPrompt,
    this.onSkipUnplannedPrompt,
  });

  @override
  State<KitchenDailyAssistantBanner> createState() =>
      _KitchenDailyAssistantBannerState();
}

class _KitchenDailyAssistantBannerState
    extends State<KitchenDailyAssistantBanner> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.prompts.isEmpty) return const SizedBox.shrink();

    final visiblePrompts =
        _showAll ? widget.prompts : [widget.prompts.first];
    final extraCount = widget.prompts.length - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BioMinimalUi.cardDecoration(
        context,
        accentBorder: AppColors.primaryEmerald.withValues(alpha: 0.4),
        radius: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👨‍🍳', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Günlük Mutfak Asistanı',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.prompts.length} Yoklama',
                  style: const TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...visiblePrompts.asMap().entries.map((entry) {
            final isLast = entry.key == visiblePrompts.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: _KitchenPromptCard(
                prompt: entry.value,
                onAddMissingToShopping: widget.onAddPromptMissingToShopping,
                onBoughtMissingToPantry: widget.onBoughtPromptMissingToPantry,
                onSnoozeMissing: widget.onSnoozePromptMissing,
                onConfirmCooked: widget.onConfirmPromptCooked,
                onPostponePlanned: widget.onPostponePromptPlanned,
                onSkipPlanned: widget.onSkipPromptPlanned,
                onOpenUnplanned: widget.onOpenUnplannedPrompt,
                onSkipUnplanned: widget.onSkipUnplannedPrompt,
              ),
            );
          }),
          if (extraCount > 0) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAll = !_showAll),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryEmerald,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _showAll
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                ),
                label: Text(
                  _showAll
                      ? 'Daha az göster'
                      : 'Diğer $extraCount bildirimi göster',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// WhatsApp-style floating corner bubble for the daily kitchen assistant.
/// Shows the active prompt count badge and opens a reactive modal bottom sheet.
class KitchenDailyAssistantFab extends StatefulWidget {
  final List<KitchenDailyPrompt> prompts;
  final ValueChanged<KitchenDailyPrompt>? onAddPromptMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtPromptMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozePromptMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmPromptCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplannedPrompt;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplannedPrompt;

  const KitchenDailyAssistantFab({
    super.key,
    required this.prompts,
    this.onAddPromptMissingToShopping,
    this.onBoughtPromptMissingToPantry,
    this.onSnoozePromptMissing,
    this.onConfirmPromptCooked,
    this.onPostponePromptPlanned,
    this.onSkipPromptPlanned,
    this.onOpenUnplannedPrompt,
    this.onSkipUnplannedPrompt,
  });

  @override
  State<KitchenDailyAssistantFab> createState() =>
      _KitchenDailyAssistantFabState();
}

class _KitchenDailyAssistantFabState extends State<KitchenDailyAssistantFab> {
  late final ValueNotifier<List<KitchenDailyPrompt>> _promptsNotifier;
  bool _isSheetOpen = false;
  bool _notifierDisposed = false;

  @override
  void initState() {
    super.initState();
    _promptsNotifier = ValueNotifier<List<KitchenDailyPrompt>>(widget.prompts);
  }

  @override
  void didUpdateWidget(covariant KitchenDailyAssistantFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.prompts, widget.prompts)) {
      final nextPrompts = widget.prompts;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_notifierDisposed) return;
        _promptsNotifier.value = nextPrompts;
      });
    }
  }

  void _disposeNotifierSafely() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    _promptsNotifier.dispose();
  }

  @override
  void dispose() {
    if (_isSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_notifierDisposed) return;
        _promptsNotifier.value = const [];
      });
    } else {
      _disposeNotifierSafely();
    }
    super.dispose();
  }

  void _openAssistantSheet(BuildContext context) {
    _isSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _KitchenDailyAssistantSheet(
        promptsNotifier: _promptsNotifier,
        onAddPromptMissingToShopping: widget.onAddPromptMissingToShopping,
        onBoughtPromptMissingToPantry: widget.onBoughtPromptMissingToPantry,
        onSnoozePromptMissing: widget.onSnoozePromptMissing,
        onConfirmPromptCooked: widget.onConfirmPromptCooked == null
            ? null
            : (p) {
                Navigator.of(sheetContext).pop();
                widget.onConfirmPromptCooked!(p);
              },
        onPostponePromptPlanned: widget.onPostponePromptPlanned,
        onSkipPromptPlanned: widget.onSkipPromptPlanned,
        onOpenUnplannedPrompt: widget.onOpenUnplannedPrompt == null
            ? null
            : (p) {
                Navigator.of(sheetContext).pop();
                widget.onOpenUnplannedPrompt!(p);
              },
        onSkipUnplannedPrompt: widget.onSkipUnplannedPrompt,
      ),
    ).whenComplete(() {
      _isSheetOpen = false;
      if (!mounted) {
        _disposeNotifierSafely();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prompts.isEmpty) return const SizedBox.shrink();

    final count = widget.prompts.length;

    return Semantics(
      button: true,
      label: 'Günlük Mutfak Asistanı ($count yoklama)',
      child: Tooltip(
        message: 'Günlük Mutfak Asistanı ($count)',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: AppColors.primaryEmerald,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: AppColors.primaryEmerald.withValues(alpha: 0.45),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openAssistantSheet(context),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Icon(
                      Icons.assistant_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cautionGold,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0A120E),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
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

class _KitchenDailyAssistantSheet extends StatefulWidget {
  final ValueNotifier<List<KitchenDailyPrompt>> promptsNotifier;
  final ValueChanged<KitchenDailyPrompt>? onAddPromptMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtPromptMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozePromptMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmPromptCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPromptPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplannedPrompt;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplannedPrompt;

  const _KitchenDailyAssistantSheet({
    required this.promptsNotifier,
    required this.onAddPromptMissingToShopping,
    required this.onBoughtPromptMissingToPantry,
    required this.onSnoozePromptMissing,
    required this.onConfirmPromptCooked,
    required this.onPostponePromptPlanned,
    required this.onSkipPromptPlanned,
    required this.onOpenUnplannedPrompt,
    required this.onSkipUnplannedPrompt,
  });

  @override
  State<_KitchenDailyAssistantSheet> createState() =>
      _KitchenDailyAssistantSheetState();
}

class _KitchenDailyAssistantSheetState
    extends State<_KitchenDailyAssistantSheet> {
  bool _didAutoPop = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<KitchenDailyPrompt>>(
      valueListenable: widget.promptsNotifier,
      builder: (context, prompts, _) {
        if (prompts.isEmpty && !_didAutoPop) {
          _didAutoPop = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pop();
          });
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: context.cardBorderColor),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            context.textSecondaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryEmerald,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assistant_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Günlük Mutfak Asistanı',
                              style: TextStyle(
                                color: context.textPrimaryColor,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${prompts.length} aktif yoklama',
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Kapat',
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: prompts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _KitchenPromptCard(
                        prompt: prompts[index],
                        onAddMissingToShopping:
                            widget.onAddPromptMissingToShopping,
                        onBoughtMissingToPantry:
                            widget.onBoughtPromptMissingToPantry,
                        onSnoozeMissing: widget.onSnoozePromptMissing,
                        onConfirmCooked: widget.onConfirmPromptCooked,
                        onPostponePlanned: widget.onPostponePromptPlanned,
                        onSkipPlanned: widget.onSkipPromptPlanned,
                        onOpenUnplanned: widget.onOpenUnplannedPrompt,
                        onSkipUnplanned: widget.onSkipUnplannedPrompt,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KitchenPromptCard extends StatelessWidget {
  final KitchenDailyPrompt prompt;
  final ValueChanged<KitchenDailyPrompt>? onAddMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozeMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplanned;

  const _KitchenPromptCard({
    required this.prompt,
    required this.onAddMissingToShopping,
    required this.onBoughtMissingToPantry,
    required this.onSnoozeMissing,
    required this.onConfirmCooked,
    required this.onPostponePlanned,
    required this.onSkipPlanned,
    required this.onOpenUnplanned,
    required this.onSkipUnplanned,
  });

  Color get _accentColor {
    switch (prompt.type) {
      case KitchenPromptType.todayMissingIngredients:
        return AppColors.cautionGold;
      case KitchenPromptType.plannedMealCookCheck:
        return AppColors.primaryEmerald;
      case KitchenPromptType.unplannedSlotPantryCheck:
        return AppColors.primaryMint;
    }
  }

  String get _badgeText {
    switch (prompt.type) {
      case KitchenPromptType.todayMissingIngredients:
        return prompt.isTomorrowPreview
            ? 'Yarın İçin Eksik'
            : 'Bugün İçin Eksik';
      case KitchenPromptType.plannedMealCookCheck:
        return 'Pişirme Yoklaması';
      case KitchenPromptType.unplannedSlotPantryCheck:
        return 'Boş Öğün Kontrolü';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _badgeText,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${prompt.mealSlot.emoji} ${prompt.mealSlot.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prompt.title,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            prompt.subtitle,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11.5,
            ),
          ),
          if (prompt.missingTags.isNotEmpty ||
              prompt.lowStockTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PromptMissingTagsWrap(
              missingTags: prompt.missingTags,
              lowStockTags: prompt.lowStockTags,
            ),
          ],
          const SizedBox(height: 10),
          _PromptActionsSection(
            prompt: prompt,
            onAddMissingToShopping: onAddMissingToShopping,
            onBoughtMissingToPantry: onBoughtMissingToPantry,
            onSnoozeMissing: onSnoozeMissing,
            onConfirmCooked: onConfirmCooked,
            onPostponePlanned: onPostponePlanned,
            onSkipPlanned: onSkipPlanned,
            onOpenUnplanned: onOpenUnplanned,
            onSkipUnplanned: onSkipUnplanned,
          ),
        ],
      ),
    );
  }
}

class _PromptMissingTagsWrap extends StatelessWidget {
  final List<String> missingTags;
  final List<String> lowStockTags;

  const _PromptMissingTagsWrap({
    required this.missingTags,
    required this.lowStockTags,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        ...missingTags.map(
          (tag) => _SmallTagPill(
            label: 'Eksik: ${QuickIngredientCatalog.displayNameForTag(tag)}',
            color: AppColors.dangerRed,
          ),
        ),
        ...lowStockTags.map(
          (tag) => _SmallTagPill(
            label: 'Az: ${QuickIngredientCatalog.displayNameForTag(tag)}',
            color: AppColors.cautionGold,
          ),
        ),
      ],
    );
  }
}

class _SmallTagPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallTagPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PromptActionsSection extends StatelessWidget {
  final KitchenDailyPrompt prompt;
  final ValueChanged<KitchenDailyPrompt>? onAddMissingToShopping;
  final ValueChanged<KitchenDailyPrompt>? onBoughtMissingToPantry;
  final ValueChanged<KitchenDailyPrompt>? onSnoozeMissing;
  final ValueChanged<KitchenDailyPrompt>? onConfirmCooked;
  final ValueChanged<KitchenDailyPrompt>? onPostponePlanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipPlanned;
  final ValueChanged<KitchenDailyPrompt>? onOpenUnplanned;
  final ValueChanged<KitchenDailyPrompt>? onSkipUnplanned;

  const _PromptActionsSection({
    required this.prompt,
    required this.onAddMissingToShopping,
    required this.onBoughtMissingToPantry,
    required this.onSnoozeMissing,
    required this.onConfirmCooked,
    required this.onPostponePlanned,
    required this.onSkipPlanned,
    required this.onOpenUnplanned,
    required this.onSkipUnplanned,
  });

  @override
  Widget build(BuildContext context) {
    switch (prompt.type) {
      case KitchenPromptType.todayMissingIngredients:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CompactElevatedBtn(
              label: 'Alışverişe Ekle',
              icon: Icons.add_shopping_cart_rounded,
              color: AppColors.cautionGold,
              onPressed: onAddMissingToShopping != null
                  ? () => onAddMissingToShopping!(prompt)
                  : null,
            ),
            _CompactOutlinedBtn(
              label: 'Aldım, Kilere Ekle',
              icon: Icons.kitchen_rounded,
              color: AppColors.primaryEmerald,
              onPressed: onBoughtMissingToPantry != null
                  ? () => onBoughtMissingToPantry!(prompt)
                  : null,
            ),
            _CompactTextBtn(
              label: 'Sonraya Bırak',
              onPressed: onSnoozeMissing != null
                  ? () => onSnoozeMissing!(prompt)
                  : null,
            ),
          ],
        );
      case KitchenPromptType.plannedMealCookCheck:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CompactElevatedBtn(
              label: 'Pişirdim',
              icon: Icons.soup_kitchen_rounded,
              color: AppColors.primaryEmerald,
              onPressed:
                  onConfirmCooked != null ? () => onConfirmCooked!(prompt) : null,
            ),
            _CompactOutlinedBtn(
              label: 'Ertele',
              icon: Icons.schedule_rounded,
              color: AppColors.cautionGold,
              onPressed: onPostponePlanned != null
                  ? () => onPostponePlanned!(prompt)
                  : null,
            ),
            _CompactTextBtn(
              label: 'Dışarıdaydım / Geç',
              onPressed:
                  onSkipPlanned != null ? () => onSkipPlanned!(prompt) : null,
            ),
          ],
        );
      case KitchenPromptType.unplannedSlotPantryCheck:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CompactElevatedBtn(
              label: 'Kilerden Ne Tükettin?',
              icon: Icons.inventory_2_rounded,
              color: AppColors.primaryEmerald,
              onPressed: onOpenUnplanned != null
                  ? () => onOpenUnplanned!(prompt)
                  : null,
            ),
            _CompactTextBtn(
              label: 'Dışarıdaydım / Atla',
              onPressed: onSkipUnplanned != null
                  ? () => onSkipUnplanned!(prompt)
                  : null,
            ),
          ],
        );
    }
  }
}

class _CompactElevatedBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _CompactElevatedBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CompactOutlinedBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _CompactOutlinedBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CompactTextBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _CompactTextBtn({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.textSecondaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Modal check-in sheet confirming pantry consumption for a planned cooked meal.
class PlannedMealCookCheckSheet extends StatefulWidget {
  final KitchenDailyPrompt prompt;

  const PlannedMealCookCheckSheet({
    super.key,
    required this.prompt,
  });

  static Future<Map<int, QuantityConsumptionAction>?> show(
    BuildContext context, {
    required KitchenDailyPrompt prompt,
  }) {
    return showModalBottomSheet<Map<int, QuantityConsumptionAction>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlannedMealCookCheckSheet(prompt: prompt),
    );
  }

  @override
  State<PlannedMealCookCheckSheet> createState() =>
      _PlannedMealCookCheckSheetState();
}

class _PlannedMealCookCheckSheetState extends State<PlannedMealCookCheckSheet> {
  final Map<int, QuantityConsumptionAction> _actions = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.prompt.suggestedPantryItems) {
      final id = item.id;
      if (id == null) continue;
      _actions[id] = item.quantityLevel == QuantityLevel.low
          ? QuantityConsumptionAction.finished
          : QuantityConsumptionAction.stepDown;
    }
  }

  void _setItemAction(int itemId, QuantityConsumptionAction? action) {
    setState(() {
      if (action == null) {
        _actions.remove(itemId);
      } else {
        _actions[itemId] = action;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.prompt.suggestedPantryItems;
    final recipeTitle = widget.prompt.recipe?.title ?? widget.prompt.title;

    return Container(
      height: MediaQuery.of(context).size.height * 0.74,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                widget.prompt.recipe?.emoji ?? widget.prompt.mealSlot.emoji,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$recipeTitle Pişirildi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.prompt.mealSlot.label} • Kullanılan kiler malzemelerini işaretleyin',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(null),
                icon: Icon(
                  Icons.close_rounded,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Bu yemek için kilerinizde eşleşen stok bulunamadı. Doğrudan pişirildi olarak kaydedebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item.id;
                      final selectedAction =
                          itemId != null ? _actions[itemId] : null;
                      return _PlannedCookItemRow(
                        item: item,
                        selectedAction: selectedAction,
                        onSelect: itemId == null
                            ? null
                            : (action) => _setItemAction(itemId, action),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    Map<int, QuantityConsumptionAction>.from(_actions),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 19),
                  label: Text(
                    'Onayla (${_actions.length} Malzeme Düş)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlannedCookItemRow extends StatelessWidget {
  final PantryItem item;
  final QuantityConsumptionAction? selectedAction;
  final ValueChanged<QuantityConsumptionAction?>? onSelect;

  const _PlannedCookItemRow({
    required this.item,
    required this.selectedAction,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.storageZone.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                item.quantityLevel.label,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionChoiceChip(
                  label: 'Azaldı',
                  selected: selectedAction == QuantityConsumptionAction.stepDown,
                  color: AppColors.cautionGold,
                  onTap: onSelect != null
                      ? () => onSelect!(QuantityConsumptionAction.stepDown)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionChoiceChip(
                  label: 'Bitti',
                  selected: selectedAction == QuantityConsumptionAction.finished,
                  color: AppColors.dangerRed,
                  onTap: onSelect != null
                      ? () => onSelect!(QuantityConsumptionAction.finished)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionChoiceChip(
                  label: 'Kullanmadım',
                  selected: selectedAction == null,
                  color: AppColors.primaryEmerald,
                  onTap: onSelect != null ? () => onSelect!(null) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal sheet for recording pantry consumption during an unplanned meal slot.
class UnplannedPantryCheckInSheet extends StatefulWidget {
  final MealSlot slot;
  final String dateIso;
  final List<PantryItem> pantryItems;
  final List<PantryItem> suggestedItems;

  const UnplannedPantryCheckInSheet({
    super.key,
    required this.slot,
    required this.dateIso,
    required this.pantryItems,
    required this.suggestedItems,
  });

  static Future<Map<int, QuantityConsumptionAction>?> show(
    BuildContext context, {
    required MealSlot slot,
    required String dateIso,
    required List<PantryItem> pantryItems,
    required List<PantryItem> suggestedItems,
  }) {
    return showModalBottomSheet<Map<int, QuantityConsumptionAction>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnplannedPantryCheckInSheet(
        slot: slot,
        dateIso: dateIso,
        pantryItems: pantryItems,
        suggestedItems: suggestedItems,
      ),
    );
  }

  @override
  State<UnplannedPantryCheckInSheet> createState() =>
      _UnplannedPantryCheckInSheetState();
}

class _UnplannedPantryCheckInSheetState
    extends State<UnplannedPantryCheckInSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, QuantityConsumptionAction> _selections = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(int itemId, QuantityConsumptionAction action) {
    setState(() {
      if (_selections[itemId] == action) {
        _selections.remove(itemId);
      } else {
        _selections[itemId] = action;
      }
    });
  }

  List<PantryItem> _filteredItems() {
    final q = IngredientNormalizer.asciiLower(_searchController.text);
    if (q.isEmpty) return widget.pantryItems;
    return widget.pantryItems.where((item) {
      return IngredientNormalizer.asciiLower(item.name).contains(q) ||
          IngredientNormalizer.asciiLower(item.category).contains(q) ||
          IngredientNormalizer.asciiLower(item.brand).contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;
    final filtered = _filteredItems();
    final suggestedIds =
        widget.suggestedItems.map((e) => e.id).whereType<int>().toSet();
    final nonSuggestedItems = widget.pantryItems
        .where((e) => e.id == null || !suggestedIds.contains(e.id))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(widget.slot.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.slot.label} • Kilerden Ne Tükettiniz?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.dateIso} • Azalan veya biten ürünleri işaretleyin',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(null),
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
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Kilerde ürün ara (örn. yumurta, yoğurt, peynir)...',
              hintStyle: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryEmerald,
              ),
              suffixIcon: isSearching
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: widget.pantryItems.isEmpty
                ? Center(
                    child: Text(
                      'Kilerinizde henüz kayıtlı ürün yok.',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  )
                : isSearching
                    ? ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final id = item.id;
                          return _UnplannedItemRow(
                            item: item,
                            selectedAction: id != null ? _selections[id] : null,
                            onSelectAction: id == null
                                ? null
                                : (action) => _toggleSelection(id, action),
                          );
                        },
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (widget.suggestedItems.isNotEmpty) ...[
                            Text(
                              'Önerilenler (${widget.slot.label})',
                              style: const TextStyle(
                                color: AppColors.primaryEmerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...widget.suggestedItems.map((item) {
                              final id = item.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _UnplannedItemRow(
                                  item: item,
                                  selectedAction:
                                      id != null ? _selections[id] : null,
                                  onSelectAction: id == null
                                      ? null
                                      : (action) => _toggleSelection(id, action),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (nonSuggestedItems.isNotEmpty) ...[
                            Text(
                              'Tüm Kiler Ürünleri',
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...nonSuggestedItems.map((item) {
                              final id = item.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _UnplannedItemRow(
                                  item: item,
                                  selectedAction:
                                      id != null ? _selections[id] : null,
                                  onSelectAction: id == null
                                      ? null
                                      : (action) => _toggleSelection(id, action),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selections.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            Map<int, QuantityConsumptionAction>.from(
                              _selections,
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 19),
                  label: Text(
                    _selections.isEmpty
                        ? 'En Az 1 Ürün Seçin'
                        : 'Tüketimi Kaydet (${_selections.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnplannedItemRow extends StatelessWidget {
  final PantryItem item;
  final QuantityConsumptionAction? selectedAction;
  final ValueChanged<QuantityConsumptionAction>? onSelectAction;

  const _UnplannedItemRow({
    required this.item,
    required this.selectedAction,
    required this.onSelectAction,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAction != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryEmerald.withValues(alpha: 0.08)
            : context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryEmerald.withValues(alpha: 0.5)
              : context.cardBorderColor,
        ),
      ),
      child: Row(
        children: [
          Text(item.storageZone.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.quantityLevel.label} • ${item.unitLabel}',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionChoiceChip(
            label: 'Azaldı',
            selected: selectedAction == QuantityConsumptionAction.stepDown,
            color: AppColors.cautionGold,
            onTap: onSelectAction != null
                ? () => onSelectAction!(QuantityConsumptionAction.stepDown)
                : null,
          ),
          const SizedBox(width: 6),
          _ActionChoiceChip(
            label: 'Bitti',
            selected: selectedAction == QuantityConsumptionAction.finished,
            color: AppColors.dangerRed,
            onTap: onSelectAction != null
                ? () => onSelectAction!(QuantityConsumptionAction.finished)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ActionChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : context.surfaceColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? color : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : context.textPrimaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
