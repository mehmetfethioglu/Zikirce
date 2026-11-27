import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../recipes/domain/meal_module_notifier.dart';
import '../../recipes/presentation/kitchen_prompt_actions.dart';
import '../../recipes/presentation/widgets/kitchen_checkin_sheets.dart';
import '../../recipes/presentation/widgets/pantry_waste_rescue_card.dart';
import '../domain/kiler_models.dart';
import '../domain/kiler_service.dart';
import 'widgets/quick_ingredient_add_sheet.dart';
import 'widgets/receipt_ocr_review_sheet.dart';

class KilerPantryScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenRecipesTab;
  final VoidCallback onOpenScannerTab;
  final VoidCallback onOpenShoppingTab;

  const KilerPantryScreen({
    super.key,
    required this.onOpenRecipesTab,
    required this.onOpenScannerTab,
    required this.onOpenShoppingTab,
  });

  @override
  ConsumerState<KilerPantryScreen> createState() => _KilerPantryScreenState();
}

class _KilerPantryScreenState extends ConsumerState<KilerPantryScreen> {
  StorageZone? _selectedZone; // null = Tümü

  String _shortZoneLabel(StorageZone zone) {
    switch (zone) {
      case StorageZone.fridge:
        return 'Buzdolabı';
      case StorageZone.pantry:
        return 'Kiler';
      case StorageZone.freezer:
        return 'Dondurucu';
    }
  }

  void _showReceiptSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSecondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Market Fişi Tara',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fiş üzerindeki gıda ürünleri otomatik ayrıştırılıp kilere eklenir.',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: context.pastelSageTint,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: context.accentPrimary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Kamerayla Fişi Çek',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ReceiptOcrReviewSheet.scanAndShow(
                      context,
                      source: ImageSource.camera,
                    );
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: context.pastelLavenderTint,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: context.accentLavender,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Galeriden Fiş Seç',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ReceiptOcrReviewSheet.scanAndShow(
                      context,
                      source: ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePrompts = ref.watch(
      mealModuleNotifierProvider.select((s) => s.activePrompts),
    );
    final wasteRescueMatches = ref.watch(
      mealModuleNotifierProvider.select((s) => s.wasteRescueMatches),
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
    final mealNotifier = ref.read(mealModuleNotifierProvider.notifier);

    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, state, _) {
        final filteredItems = state.itemsForZone(_selectedZone);
        final rescueItems = state.rescueCandidateItems;

        return Stack(
          children: [
            RefreshIndicator(
              color: context.accentPrimary,
              onRefresh: KilerService.instance.loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
                children: [
                  // 1. Airy Pastel Header Card
                  _PantryHeaderCard(
                    totalCount: state.pantryItems.length,
                    avgHealthScore: state.averageHealthScore,
                    expiringCount: rescueItems.length,
                    onOpenRecipes: widget.onOpenRecipesTab,
                  ),
                  const SizedBox(height: 12),

                  // 2. Slim Single-Row Quick-Add Pills
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Pazar ve kasap barkodsuz sepet ekle',
                          child: _QuickEntryPill(
                            icon: Icons.storefront_rounded,
                            label: 'Pazar / Ev',
                            bgColor: context.pastelSageTint,
                            fgColor: context.accentPrimary,
                            onTap: () => QuickIngredientAddSheet.show(
                              context,
                              onBatchAdd: KilerService.instance.addBatchDraftItems,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Paketli ürün barkodu tara',
                          child: _QuickEntryPill(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Barkod',
                            bgColor: context.pastelSkyTint,
                            fgColor: context.accentSky,
                            onTap: widget.onOpenScannerTab,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Market fişi fotoğrafı ile toplu ürün tara',
                          child: _QuickEntryPill(
                            icon: Icons.receipt_long_rounded,
                            label: 'Fiş OCR',
                            bgColor: context.pastelLavenderTint,
                            fgColor: context.accentLavender,
                            onTap: () => _showReceiptSourcePicker(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Compact Waste Rescue Bar
                  if (rescueItems.isNotEmpty) ...[
                    PantryWasteRescueCard(
                      rescueItems: rescueItems,
                      rescueRecipes: wasteRescueMatches,
                      onOpenRecipesTab: widget.onOpenRecipesTab,
                      onOpenRecipe: (match) => KitchenPromptActions.openRecipeDetail(
                        context: context,
                        notifier: mealNotifier,
                        match: match,
                        weekMondayIso: currentWeekMondayIso,
                        selectedDateIso: selectedDateIso,
                        planServings: planServings,
                      ),
                      onAddRecipeToPlan: (match) =>
                          KitchenPromptActions.openAddRecipeToPlanSheet(
                        context: context,
                        notifier: mealNotifier,
                        recipe: match.recipe,
                        weekMondayIso: currentWeekMondayIso,
                        selectedDateIso: selectedDateIso,
                        planServings: planServings,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Minimal Text-Only Zone Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StorageZoneFilterPill(
                          label: 'Tümü (${state.pantryItems.length})',
                          selected: _selectedZone == null,
                          onTap: () => setState(() => _selectedZone = null),
                        ),
                        ...StorageZone.values.map((zone) {
                          final count = state.itemsForZone(zone).length;
                          final shortName = _shortZoneLabel(zone);
                          final label =
                              count > 0 ? '$shortName · $count' : shortName;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _StorageZoneFilterPill(
                              label: label,
                              selected: _selectedZone == zone,
                              onTap: () => setState(() => _selectedZone = zone),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Clean Single-Row Pantry Inventory List
                  if (state.isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.accentPrimary,
                        ),
                      ),
                    )
                  else if (filteredItems.isEmpty)
                    _EmptyPantryCard(
                      onAddTap: () => QuickIngredientAddSheet.show(
                        context,
                        onBatchAdd: KilerService.instance.addBatchDraftItems,
                      ),
                    )
                  else
                    ...filteredItems.map(
                      (item) => _PantryItemCard(
                        item: item,
                        showZoneLabel: _selectedZone == null,
                      ),
                    ),
                ],
              ),
            ),
            if (activePrompts.isNotEmpty)
              Positioned(
                right: 16,
                bottom: 16,
                child: KitchenDailyAssistantFab(
                  prompts: activePrompts,
                  onAddPromptMissingToShopping: (p) =>
                      KitchenPromptActions.addMissingToShopping(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onBoughtPromptMissingToPantry: (p) =>
                      KitchenPromptActions.boughtMissingToPantry(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onSnoozePromptMissing: (p) =>
                      KitchenPromptActions.snoozeMissing(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onConfirmPromptCooked: (p) =>
                      KitchenPromptActions.confirmPlannedCooked(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onPostponePromptPlanned: (p) =>
                      KitchenPromptActions.postponePlanned(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onSkipPromptPlanned: (p) => KitchenPromptActions.skipPlanned(
                    context,
                    mealNotifier,
                    p,
                  ),
                  onOpenUnplannedPrompt: (p) =>
                      KitchenPromptActions.openUnplannedCheckIn(
                    context,
                    mealNotifier,
                    dateIso: p.planDate,
                    slot: p.mealSlot,
                    pantryItems: state.pantryItems,
                    suggestedItems: p.suggestedPantryItems,
                  ),
                  onSkipUnplannedPrompt: (p) =>
                      KitchenPromptActions.skipUnplanned(
                    context,
                    mealNotifier,
                    p,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PantryHeaderCard extends StatelessWidget {
  final int totalCount;
  final int avgHealthScore;
  final int expiringCount;
  final VoidCallback onOpenRecipes;

  const _PantryHeaderCard({
    required this.totalCount,
    required this.avgHealthScore,
    required this.expiringCount,
    required this.onOpenRecipes,
  });

  @override
  Widget build(BuildContext context) {
    final String subtitle = expiringCount > 0
        ? '$totalCount malzeme · $expiringCount öncelikli'
        : '$totalCount malzeme · Skor $avgHealthScore';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.pastelSageTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.accentPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kilerim',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: onOpenRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentPrimary,
                foregroundColor: context.onAccentPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
              label: const Text(
                'Ne Pişirsem?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEntryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _QuickEntryPill({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: fgColor.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageZoneFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StorageZoneFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.pastelSageTint : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.accentPrimary.withValues(alpha: 0.35)
                : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.accentPrimary : context.textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyPantryCard extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyPantryCard({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BioMinimalUi.cardDecoration(context, radius: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.pastelSageTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.kitchen_outlined,
              size: 28,
              color: context.accentPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu alanda henüz malzeme yok',
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pazar alışverişi, barkod veya fiş ile hızlıca ekleyin.',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 12.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAddTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: context.onAccentPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Malzeme Ekle',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final bool showZoneLabel;

  const _PantryItemCard({
    required this.item,
    required this.showZoneLabel,
  });

  Color _statusAccent(BuildContext context) {
    if (item.isExpired) return context.accentDanger;
    if (item.isExpiringSoon || item.isLongWaiting) return context.accentWarm;
    return context.accentPrimary;
  }

  Color _statusTint(BuildContext context) {
    if (item.isExpired) return context.pastelBlushTint;
    if (item.isExpiringSoon || item.isLongWaiting) {
      return context.pastelPeachTint;
    }
    return context.pastelSageTint;
  }

  String _shortFreshnessLabel() {
    final days = item.daysRemaining;
    if (item.isExpired) return 'Süresi geçti';
    if (days == 0) return 'Bugün son';
    if (days <= 3) return 'Son ${days}g';
    if (item.isLongWaiting) return '${item.daysInPantry}g bekliyor';
    if (days > 45) return '${(days / 30).round()} ay';
    return '${days}g taze';
  }

  String _shortZoneLabel(StorageZone zone) {
    switch (zone) {
      case StorageZone.fridge:
        return 'Buzdolabı';
      case StorageZone.pantry:
        return 'Kiler';
      case StorageZone.freezer:
        return 'Dondurucu';
    }
  }

  QuantityLevel _nextCycleLevel(QuantityLevel current) {
    switch (current) {
      case QuantityLevel.full:
        return QuantityLevel.half;
      case QuantityLevel.half:
        return QuantityLevel.low;
      case QuantityLevel.low:
        return QuantityLevel.full;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _statusAccent(context);
    final tint = _statusTint(context);
    final String metaText = showZoneLabel
        ? '${_shortFreshnessLabel()} · ${_shortZoneLabel(item.storageZone)}'
        : _shortFreshnessLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BioMinimalUi.cardDecoration(
        context,
        accentBorder:
            item.needsWasteRescue ? accent.withValues(alpha: 0.4) : null,
        radius: 16,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _PantryItemDetailSheet.show(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.storageZone.icon,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: item.needsWasteRescue
                                    ? accent
                                    : context.textSecondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _QuantityCyclePill(
                  level: item.quantityLevel,
                  onTap: () => KilerService.instance.updateQuantityLevel(
                    item,
                    _nextCycleLevel(item.quantityLevel),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Bitti — Alışverişe ekle',
                  child: Material(
                    color: context.pastelPeachTint,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        await KilerService.instance.markItemFinished(
                          item,
                          addToShoppingList: true,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '"${item.name}" alışveriş listesine eklendi.',
                            ),
                            backgroundColor: context.accentSecondary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.shopping_cart_checkout_rounded,
                          size: 16,
                          color: context.accentWarm,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityCyclePill extends StatelessWidget {
  final QuantityLevel level;
  final VoidCallback onTap;

  const _QuantityCyclePill({
    required this.level,
    required this.onTap,
  });

  String _shortLabel() {
    switch (level) {
      case QuantityLevel.full:
        return 'Tam';
      case QuantityLevel.half:
        return 'Yarım';
      case QuantityLevel.low:
        return 'Az';
    }
  }

  int _filledBars() {
    switch (level) {
      case QuantityLevel.full:
        return 3;
      case QuantityLevel.half:
        return 2;
      case QuantityLevel.low:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBars = _filledBars();
    final activeColor = level == QuantityLevel.low
        ? context.accentWarm
        : context.accentPrimary;

    return Tooltip(
      message: 'Miktarı değiştir: ${level.label}',
      child: Material(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: List.generate(3, (idx) {
                    final filled = idx < activeBars;
                    return Container(
                      width: 3,
                      height: 6.0 + (idx * 2.5),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: filled
                            ? activeColor
                            : context.textSecondaryColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  _shortLabel(),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PantryItemDetailSheet extends StatelessWidget {
  final PantryItem initialItem;

  const _PantryItemDetailSheet({required this.initialItem});

  static Future<void> show(BuildContext context, PantryItem item) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PantryItemDetailSheet(initialItem: item),
    );
  }

  Color _statusAccent(BuildContext context, PantryItem item) {
    if (item.isExpired) return context.accentDanger;
    if (item.isExpiringSoon || item.isLongWaiting) return context.accentWarm;
    return context.accentPrimary;
  }

  Color _statusTint(BuildContext context, PantryItem item) {
    if (item.isExpired) return context.pastelBlushTint;
    if (item.isExpiringSoon || item.isLongWaiting) {
      return context.pastelPeachTint;
    }
    return context.pastelSageTint;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KilerState>(
      valueListenable: KilerService.instance,
      builder: (context, state, _) {
        final item = state.pantryItems.firstWhere(
          (p) => p.id != null && p.id == initialItem.id,
          orElse: () => initialItem,
        );
        final accent = _statusAccent(context, item);
        final tint = _statusTint(context, item);
        final metaParts = <String>[
          if (item.brand.trim().isNotEmpty) item.brand.trim(),
          if (item.unitLabel.trim().isNotEmpty) item.unitLabel.trim(),
          item.storageZone.label,
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textSecondaryColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.storageZone.icon,
                        size: 21,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            metaParts.join(' · '),
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.waitingReasonLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kalan Miktar',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: QuantityLevel.values.map((level) {
                    final selected = item.quantityLevel == level;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: level == QuantityLevel.low ? 0 : 8,
                        ),
                        child: GestureDetector(
                          onTap: () => KilerService.instance.updateQuantityLevel(
                            item,
                            level,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? context.pastelSageTint
                                  : context.subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? context.accentPrimary
                                    : context.cardBorderColor,
                              ),
                            ),
                            child: Text(
                              level.label,
                              style: TextStyle(
                                color: selected
                                    ? context.accentPrimary
                                    : context.textPrimaryColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await KilerService.instance.markItemFinished(
                        item,
                        addToShoppingList: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.pastelPeachTint,
                      foregroundColor: context.accentWarm,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Bitti · Alışveriş Listesine Ekle',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
