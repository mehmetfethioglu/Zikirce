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

  void _showReceiptSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Market Fişi Fotoğrafı Seçin (OCR)',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Market fişindeki gıda ürünleri otomatik ayrıştırılıp dolabınıza eklenir.',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primaryEmerald,
                  ),
                  title: const Text('Kamerayla Fişi Çek'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ReceiptOcrReviewSheet.scanAndShow(
                      context,
                      source: ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryMint,
                  ),
                  title: const Text('Galeriden Fiş Seç'),
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
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;

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

        return RefreshIndicator(
          color: AppColors.primaryEmerald,
          onRefresh: KilerService.instance.loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            children: [
              // 1. Smart Kitchen Dashboard Card
              _PantryDashboardBanner(
                totalCount: state.pantryItems.length,
                avgHealthScore: state.averageHealthScore,
                expiringCount: rescueItems.length,
                onOpenRecipes: widget.onOpenRecipesTab,
              ),
              const SizedBox(height: 14),

              // 1b. Daily Kitchen Assistant Prompts (missing ingredients, cook check, empty slots)
              if (activePrompts.isNotEmpty) ...[
                KitchenDailyAssistantBanner(
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
                const SizedBox(height: 14),
              ],

              // 2. 3-Way Smart Entry Action Bar
              Row(
                children: [
                  Expanded(
                    child: _SmartEntryActionCard(
                      icon: Icons.storefront_rounded,
                      title: 'Pazar & Kasap',
                      subtitle: 'Barkodsuz Sepet',
                      color: AppColors.primaryEmerald,
                      onTap: () => QuickIngredientAddSheet.show(
                        context,
                        onBatchAdd: KilerService.instance.addBatchDraftItems,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmartEntryActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Barkod Tara',
                      subtitle: 'Paketli Ürün',
                      color: AppColors.primaryMint,
                      onTap: widget.onOpenScannerTab,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmartEntryActionCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Market Fişi',
                      subtitle: 'Toplu OCR',
                      color: AppColors.cautionGold,
                      onTap: () => _showReceiptSourcePicker(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Waste Rescue Banner + Targeted Recipes (Expiring + Long-Waiting)
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
                const SizedBox(height: 14),
              ],

              // 4. Storage Zone Filter Tabs
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
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _StorageZoneFilterPill(
                          label: '${zone.emoji} ${zone.label} ($count)',
                          selected: _selectedZone == zone,
                          onTap: () => setState(() => _selectedZone = zone),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Pantry Inventory List
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                )
              else if (filteredItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      const Text('🥗', style: TextStyle(fontSize: 42)),
                      const SizedBox(height: 10),
                      Text(
                        'Bu alanda henüz ürün yok',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pazar & Kasap barkodsuz sepeti, Barkod Okuyucu veya Market Fişi OCR ile evdeki malzemelerinizi hemen ekleyin.',
                        style: TextStyle(color: textSecondary, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => QuickIngredientAddSheet.show(
                          context,
                          onBatchAdd: KilerService.instance.addBatchDraftItems,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Pazar / Ev Malzemesi Ekle'),
                      ),
                    ],
                  ),
                )
              else
                ...filteredItems.map(
                  (item) => _PantryItemCard(item: item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PantryDashboardBanner extends StatelessWidget {
  final int totalCount;
  final int avgHealthScore;
  final int expiringCount;
  final VoidCallback onOpenRecipes;

  const _PantryDashboardBanner({
    required this.totalCount,
    required this.avgHealthScore,
    required this.expiringCount,
    required this.onOpenRecipes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryEmerald.withValues(alpha: 0.22),
            AppColors.primaryMint.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🏡', style: TextStyle(fontSize: 19)),
                        const SizedBox(width: 8),
                        Text(
                          'Kilerim & Buzdolabım',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalCount malzeme kayıtlı',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    Text(
                      '$avgHealthScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Sağlık',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.restaurant_menu_rounded, size: 19),
              label: Text(
                expiringCount > 0
                    ? '👨‍🍳 Dolaptaki $totalCount Malzemeyle Ne Pişirsem? ($expiringCount Öncelikli)'
                    : '👨‍🍳 Dolaptaki Malzemelerle Ne Pişirsem?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartEntryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SmartEntryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 10,
              ),
            ),
          ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryEmerald : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryEmerald : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.textPrimaryColor,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PantryItemCard extends StatelessWidget {
  final PantryItem item;

  const _PantryItemCard({required this.item});

  Color _freshnessColor() {
    if (item.isExpired) return AppColors.dangerRed;
    if (item.isExpiringSoon || item.isLongWaiting) {
      return AppColors.cautionGold;
    }
    return AppColors.primaryEmerald;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final tpl = QuickIngredientCatalog.findByTag(item.normalizedTag);
    final emoji = tpl?.emoji ?? item.storageZone.emoji;
    final fColor = _freshnessColor();
    final String statusLabel =
        item.isLongWaiting && !item.isExpiringSoon && !item.isExpired
            ? item.waitingReasonLabel
            : item.freshnessLabel;
    final String brandPrefix =
        item.brand.trim().isNotEmpty ? '${item.brand} • ' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.needsWasteRescue
              ? fColor.withValues(alpha: 0.55)
              : borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: fColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: fColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$brandPrefix${item.storageZone.emoji} ${item.storageZone.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...QuantityLevel.values.map((level) {
                final isSelected = item.quantityLevel == level;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () =>
                        KilerService.instance.updateQuantityLevel(item, level),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryEmerald.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryEmerald
                              : borderColor,
                        ),
                      ),
                      child: Text(
                        level.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryEmerald
                              : textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await KilerService.instance.markItemFinished(
                    item,
                    addToShoppingList: true,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🛒 "${item.name}" bitti olarak işaretlendi ve Alışveriş Listesine eklendi.',
                      ),
                      backgroundColor: AppColors.primaryMint,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 15,
                  color: AppColors.cautionGold,
                ),
                label: const Text(
                  'Bitti -> Listeye',
                  style: TextStyle(
                    color: AppColors.cautionGold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
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
