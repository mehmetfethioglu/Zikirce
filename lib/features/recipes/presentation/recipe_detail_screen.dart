import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../kiler/domain/kiler_catalog.dart';
import '../../kiler/domain/kiler_service.dart';
import '../../settings/presentation/widgets/recipe_photo_feedback_sheet.dart';
import '../domain/recipe_models.dart';
import 'widgets/recipe_visual_header.dart';

enum _RecipeMenuAction { pickPhoto, removePhoto, deleteCustom }

/// Clean, breathable full-page recipe detail view replacing the dense bottom sheet.
class RecipeDetailScreen extends StatefulWidget {
  final EvaluatedRecipeMatch match;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToMealPlan;
  final ValueChanged<int>? onRecipeCooked;
  final VoidCallback? onDeleteCustom;
  final VoidCallback? onPickCustomPhoto;
  final VoidCallback? onRemoveCustomPhoto;

  const RecipeDetailScreen({
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

  static Future<void> open(
    BuildContext context,
    EvaluatedRecipeMatch match, {
    bool isFavorite = false,
    VoidCallback? onToggleFavorite,
    VoidCallback? onAddToMealPlan,
    ValueChanged<int>? onRecipeCooked,
    VoidCallback? onDeleteCustom,
    VoidCallback? onPickCustomPhoto,
    VoidCallback? onRemoveCustomPhoto,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(
          match: match,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
          onAddToMealPlan: onAddToMealPlan,
          onRecipeCooked: onRecipeCooked,
          onDeleteCustom: onDeleteCustom,
          onPickCustomPhoto: onPickCustomPhoto,
          onRemoveCustomPhoto: onRemoveCustomPhoto,
        ),
      ),
    );
  }

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const List<int> _portionPresets = [1, 2, 4, 6, 8];
  static final RegExp _durationRegex = RegExp(
    r'(\d+)\s*(?:dk|dakika)',
    caseSensitive: false,
  );

  late int _servings;
  late bool _isFavorite;
  bool _cookedCompleted = false;
  bool _missingAdded = false;
  final Set<int> _completedSteps = {};

  Timer? _stepTimer;
  int? _activeTimerStepIndex;
  int _remainingSeconds = 0;
  bool _isTimerPaused = false;

  @override
  void initState() {
    super.initState();
    final base = widget.match.recipe.defaultServings;
    _servings = base > 0 ? base : 2;
    _isFavorite = widget.isFavorite || widget.match.isFavorite;
  }

  @override
  void didUpdateWidget(covariant RecipeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _isFavorite = widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _stepTimer = null;
    super.dispose();
  }

  int? _extractMinutes(String stepText) {
    final m = _durationRegex.firstMatch(stepText);
    if (m == null) return null;
    final parsed = int.tryParse(m.group(1) ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  void _startStepTimer(int stepIndex, int minutes) {
    _stepTimer?.cancel();
    setState(() {
      _activeTimerStepIndex = stepIndex;
      _remainingSeconds = minutes * 60;
      _isTimerPaused = false;
    });

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isTimerPaused) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _activeTimerStepIndex = null;
          _isTimerPaused = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Adım ${stepIndex + 1} süresi tamamlandı!'),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _togglePauseTimer() {
    setState(() => _isTimerPaused = !_isTimerPaused);
  }

  void _cancelStepTimer() {
    _stepTimer?.cancel();
    _stepTimer = null;
    setState(() {
      _activeTimerStepIndex = null;
      _remainingSeconds = 0;
      _isTimerPaused = false;
    });
  }

  void _handleToggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    widget.onToggleFavorite?.call();
  }

  void _toggleStepCompleted(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  Future<void> _handleCookRecipe() async {
    final usedTags = <String>[
      ...widget.match.matchedRequiredTags,
      ...widget.match.matchedOptionalTags,
    ];
    final result = await KilerService.instance.consumeRecipeIngredients(
      usedTags,
      widget.match.recipe.title,
    );

    if (!mounted) return;
    setState(() => _cookedCompleted = true);
    widget.onRecipeCooked?.call(_servings);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '👨‍🍳 Afiyet olsun! ${result.updatedCount} malzemenin miktarı güncellendi, biten ${result.finishedCount} malzeme Alışveriş Listesine aktarıldı.',
        ),
        backgroundColor: AppColors.primaryEmerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleAddMissingToShopping() async {
    final count = await KilerService.instance
        .addMissingRecipeIngredientsToShopping(
          widget.match.missingRequiredTags,
          widget.match.recipe.title,
        );
    if (!mounted) return;
    setState(() => _missingAdded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🛒 Eksik $count malzeme Akıllı Alışveriş Listenize eklendi!',
        ),
        backgroundColor: AppColors.primaryMint,
      ),
    );
  }

  Future<void> _confirmDeleteCustom() async {
    final deleteCallback = widget.onDeleteCustom;
    if (deleteCallback == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Özel Tarifi Sil'),
        content: Text(
          '"${widget.match.recipe.title}" tarifini silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    deleteCallback();
  }

  void _handleMenuAction(_RecipeMenuAction action) {
    switch (action) {
      case _RecipeMenuAction.pickPhoto:
        widget.onPickCustomPhoto?.call();
        break;
      case _RecipeMenuAction.removePhoto:
        widget.onRemoveCustomPhoto?.call();
        break;
      case _RecipeMenuAction.deleteCustom:
        _confirmDeleteCustom();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.match.recipe;
    final totalMin =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;
    final hasCustomPhoto =
        recipe.localImagePath?.trim().isNotEmpty ?? false;
    final hasMenuActions = widget.onPickCustomPhoto != null ||
        (hasCustomPhoto && widget.onRemoveCustomPhoto != null) ||
        (recipe.isCustom && widget.onDeleteCustom != null);

    final expiringTags = widget.match.expiringIngredientsUsed
        .map((e) => e.normalizedTag)
        .toSet();
    final availableTags = <String>{
      ...widget.match.matchedRequiredTags,
      ...widget.match.matchedOptionalTags,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: context.surfaceColor,
            leadingWidth: 56,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Center(
                child: _CircleHeaderButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Geri',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              if (widget.onToggleFavorite != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: _CircleHeaderButton(
                      icon: _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor:
                          _isFavorite ? AppColors.dangerRed : Colors.white,
                      tooltip: _isFavorite
                          ? 'Favoriden Çıkar'
                          : 'Favorilere Ekle',
                      onTap: _handleToggleFavorite,
                    ),
                  ),
                ),
              if (hasMenuActions)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0x99091410),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: PopupMenuButton<_RecipeMenuAction>(
                        tooltip: 'Diğer İşlemler',
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: _handleMenuAction,
                        itemBuilder: (_) => [
                          if (widget.onPickCustomPhoto != null)
                            PopupMenuItem(
                              value: _RecipeMenuAction.pickPhoto,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 18,
                                    color: AppColors.primaryEmerald,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    hasCustomPhoto
                                        ? 'Fotoğrafı Değiştir'
                                        : 'Gerçek Fotoğraf Ekle',
                                  ),
                                ],
                              ),
                            ),
                          if (hasCustomPhoto &&
                              widget.onRemoveCustomPhoto != null)
                            const PopupMenuItem(
                              value: _RecipeMenuAction.removePhoto,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.hide_image_outlined,
                                    size: 18,
                                    color: AppColors.cautionGold,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Fotoğrafı Kaldır'),
                                ],
                              ),
                            ),
                          if (recipe.isCustom && widget.onDeleteCustom != null)
                            const PopupMenuItem(
                              value: _RecipeMenuAction.deleteCustom,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.dangerRed,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Özel Tarifi Sil',
                                    style: TextStyle(color: AppColors.dangerRed),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: RecipeVisualHeader(
                recipe: recipe,
                height: 250,
                heroMode: true,
                showOverlays: false,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  recipe.title,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recipe.category} • ${recipe.originCity} • $totalMin dk • ${recipe.cookingMethod.label}',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!hasCustomPhoto) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => RecipePhotoFeedbackSheet.show(
                      context,
                      initialRecipeTitle: recipe.title,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: context.pastelSageTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.accentPrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: context.accentPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Görsel temsilidir · Yaptığınız tarifin fotoğrafını paylaşın',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textPrimaryColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Gönder',
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _MinimalMetricStrip(match: widget.match),
                if (!widget.match.isProfileSafe) ...[
                  const SizedBox(height: 12),
                  _CompactAlertBanner(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.dangerRed,
                    text:
                        'Aile Profili: ${widget.match.profileWarnings.join(' • ')}',
                  ),
                ],
                if (widget.match.preventsFoodWaste) ...[
                  const SizedBox(height: 12),
                  _CompactAlertBanner(
                    icon: Icons.eco_rounded,
                    color: AppColors.cautionGold,
                    text:
                        'İsraf Önleyici: ${{
                      ...widget.match.expiringIngredientsUsed.map((e) => e.name),
                      ...widget.match.longWaitingIngredientsUsed
                          .map((e) => e.name),
                    }.join(', ')} değerlendirilir.',
                  ),
                ],
                const SizedBox(height: 16),
                _UnifiedPortionAndNutritionCard(
                  recipe: recipe,
                  presets: _portionPresets,
                  selectedServings: _servings,
                  onSelectServings: (val) => setState(() => _servings = val),
                ),
                const SizedBox(height: 22),
                Text(
                  'Malzemeler ($_servings Porsiyon)',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (recipe.ingredients.isNotEmpty)
                  _UnifiedIngredientsCard(
                    ingredients: recipe.ingredients,
                    targetServings: _servings,
                    baseServings: recipe.defaultServings,
                    availableTags: availableTags,
                    missingRequiredTags: widget.match.missingRequiredTags,
                    expiringTags: expiringTags,
                  )
                else
                  _TagFallbackIngredientsCard(match: widget.match),
                if (widget.match.missingRequiredTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _missingAdded ? null : _handleAddMissingToShopping,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cautionGold,
                        side: const BorderSide(color: AppColors.cautionGold),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        _missingAdded
                            ? Icons.check_circle_rounded
                            : Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _missingAdded
                            ? 'Eksikler Alışveriş Listesine Eklendi'
                            : 'Eksik ${widget.match.missingRequiredTags.length} Malzemeyi Listeye Ekle',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Hazırlanışı',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...recipe.steps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final text = entry.value;
                  final timerMinutes = _extractMinutes(text);
                  final isTimerActive = _activeTimerStepIndex == idx;

                  return _CleanStepTile(
                    stepNumber: idx + 1,
                    stepText: text,
                    isCompleted: _completedSteps.contains(idx),
                    timerMinutes: timerMinutes,
                    isTimerActive: isTimerActive,
                    isTimerPaused: isTimerActive && _isTimerPaused,
                    remainingSeconds: isTimerActive ? _remainingSeconds : 0,
                    onToggleComplete: () => _toggleStepCompleted(idx),
                    onStartTimer: timerMinutes != null
                        ? () => _startStepTimer(idx, timerMinutes)
                        : null,
                    onTogglePauseTimer:
                        isTimerActive ? _togglePauseTimer : null,
                    onCancelTimer: isTimerActive ? _cancelStepTimer : null,
                  );
                }),
                if (recipe.chefTip.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SubtleChefTipCard(tip: recipe.chefTip),
                ],
                const SizedBox(height: 16),
                if (recipe.cleanLabelBadges.isNotEmpty)
                  Text(
                    recipe.cleanLabelBadges.join(' • '),
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (recipe.sourceReference.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Kaynak: ${recipe.sourceReference}',
                    style: TextStyle(
                      color: context.textSecondaryColor.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyDetailActionBar(
        cookedCompleted: _cookedCompleted,
        servings: _servings,
        onCook: _handleCookRecipe,
        onAddToMealPlan: widget.onAddToMealPlan,
      ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleHeaderButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0x99091410),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MinimalMetricStrip extends StatelessWidget {
  final EvaluatedRecipeMatch match;

  const _MinimalMetricStrip({required this.match});

  @override
  Widget build(BuildContext context) {
    final pantryColor =
        match.isReadyToCook ? AppColors.primaryEmerald : AppColors.cautionGold;
    final healthColor =
        match.isProfileSafe ? AppColors.primaryEmerald : AppColors.dangerRed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Dolap Uyumu',
                value: '%${match.matchPercent}',
                valueColor: pantryColor,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: context.cardBorderColor,
            ),
            Expanded(
              child: _StatColumn(
                label: 'Sağlık Skoru',
                value: '${match.combinedHealthScore}/100',
                valueColor: healthColor,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: context.cardBorderColor,
            ),
            Expanded(
              child: _StatColumn(
                label: '1 Porsiyon',
                value: '${match.recipe.calories} kcal',
                valueColor: context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactAlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _CompactAlertBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedPortionAndNutritionCard extends StatelessWidget {
  final KilerRecipe recipe;
  final List<int> presets;
  final int selectedServings;
  final ValueChanged<int> onSelectServings;

  const _UnifiedPortionAndNutritionCard({
    required this.recipe,
    required this.presets,
    required this.selectedServings,
    required this.onSelectServings,
  });

  @override
  Widget build(BuildContext context) {
    final totalGrams = recipe.scaledPortionGrams(selectedServings);
    final totalCalories = recipe.scaledCalories(selectedServings);
    final totalProtein =
        recipe.scaledMacro(recipe.proteinGrams, selectedServings);
    final totalCarbs = recipe.scaledMacro(recipe.carbsGrams, selectedServings);
    final totalFat = recipe.scaledMacro(recipe.fatGrams, selectedServings);
    final totalFiber = recipe.scaledMacro(recipe.fiberGrams, selectedServings);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Porsiyon',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 6,
                      children: presets.map((count) {
                        final selected = selectedServings == count;
                        return InkWell(
                          onTap: () => onSelectServings(count),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            width: 32,
                            height: 30,
                            alignment: Alignment.center,
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 22, color: context.cardBorderColor),
          Row(
            children: [
              Expanded(
                child: _MacroCell(
                  label: 'Kalori',
                  value: '$totalCalories kcal',
                ),
              ),
              Expanded(
                child: _MacroCell(
                  label: 'Protein',
                  value: '$totalProtein g',
                ),
              ),
              Expanded(
                child: _MacroCell(
                  label: 'Karb',
                  value: '$totalCarbs g',
                ),
              ),
              Expanded(
                child: _MacroCell(
                  label: 'Yağ',
                  value: '$totalFat g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Toplam $totalGrams g • Lif $totalFiber g',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCell extends StatelessWidget {
  final String label;
  final String value;

  const _MacroCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.textPrimaryColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _UnifiedIngredientsCard extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final int targetServings;
  final int baseServings;
  final Set<String> availableTags;
  final List<String> missingRequiredTags;
  final Set<String> expiringTags;

  const _UnifiedIngredientsCard({
    required this.ingredients,
    required this.targetServings,
    required this.baseServings,
    required this.availableTags,
    required this.missingRequiredTags,
    required this.expiringTags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < ingredients.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 40,
                endIndent: 14,
                color: context.cardBorderColor,
              ),
            _IngredientLineRow(
              ingredient: ingredients[i],
              label: ingredients[i].scaledLabel(targetServings, baseServings),
              isMissing: !ingredients[i].isOptional &&
                  missingRequiredTags.contains(ingredients[i].tag),
              isAvailable: availableTags.contains(ingredients[i].tag) ||
                  (ingredients[i].isPantryStaple &&
                      !(!ingredients[i].isOptional &&
                          missingRequiredTags.contains(ingredients[i].tag))),
              isExpiring: expiringTags.contains(ingredients[i].tag),
            ),
          ],
        ],
      ),
    );
  }
}

class _IngredientLineRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final String label;
  final bool isMissing;
  final bool isAvailable;
  final bool isExpiring;

  const _IngredientLineRow({
    required this.ingredient,
    required this.label,
    required this.isMissing,
    required this.isAvailable,
    required this.isExpiring,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isMissing
        ? AppColors.cautionGold
        : isAvailable
            ? AppColors.primaryEmerald
            : context.textSecondaryColor;

    // Only highlight actionable exceptions; keep normal in-stock items calm.
    String? badgeLabel;
    Color badgeColor = iconColor;
    if (isMissing) {
      badgeLabel = 'Eksik';
      badgeColor = AppColors.cautionGold;
    } else if (isExpiring) {
      badgeLabel = 'SKT Yakın';
      badgeColor = AppColors.cautionGold;
    } else if (ingredient.isOptional && !isAvailable) {
      badgeLabel = 'İsteğe Bağlı';
      badgeColor = context.textSecondaryColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(
            isMissing
                ? Icons.shopping_basket_outlined
                : isAvailable
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (badgeLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagFallbackIngredientsCard extends StatelessWidget {
  final EvaluatedRecipeMatch match;

  const _TagFallbackIngredientsCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, bool available})>[
      for (final t in match.matchedRequiredTags)
        (label: QuickIngredientCatalog.displayNameForTag(t), available: true),
      for (final t in match.missingRequiredTags)
        (label: QuickIngredientCatalog.displayNameForTag(t), available: false),
      for (final t in match.matchedOptionalTags)
        (label: QuickIngredientCatalog.displayNameForTag(t), available: true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 40,
                endIndent: 14,
                color: context.cardBorderColor,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    entries[i].available
                        ? Icons.check_circle_rounded
                        : Icons.shopping_basket_outlined,
                    size: 17,
                    color: entries[i].available
                        ? AppColors.primaryEmerald
                        : AppColors.cautionGold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entries[i].label,
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!entries[i].available)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cautionGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Eksik',
                        style: TextStyle(
                          color: AppColors.cautionGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
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

class _CleanStepTile extends StatelessWidget {
  final int stepNumber;
  final String stepText;
  final bool isCompleted;
  final int? timerMinutes;
  final bool isTimerActive;
  final bool isTimerPaused;
  final int remainingSeconds;
  final VoidCallback onToggleComplete;
  final VoidCallback? onStartTimer;
  final VoidCallback? onTogglePauseTimer;
  final VoidCallback? onCancelTimer;

  const _CleanStepTile({
    required this.stepNumber,
    required this.stepText,
    required this.isCompleted,
    required this.timerMinutes,
    required this.isTimerActive,
    required this.isTimerPaused,
    required this.remainingSeconds,
    required this.onToggleComplete,
    required this.onStartTimer,
    required this.onTogglePauseTimer,
    required this.onCancelTimer,
  });

  String _formatRemaining(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isTimerActive
            ? AppColors.primaryEmerald.withValues(alpha: 0.08)
            : context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTimerActive
              ? AppColors.primaryEmerald
              : context.cardBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleComplete,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isCompleted
                      ? AppColors.primaryMint
                      : AppColors.primaryEmerald,
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : Text(
                          '$stepNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    stepText,
                    style: TextStyle(
                      color: isCompleted
                          ? context.textSecondaryColor
                          : context.textPrimaryColor,
                      fontSize: 13.5,
                      height: 1.45,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (timerMinutes != null) ...[
            const SizedBox(height: 8),
            if (isTimerActive)
              Row(
                children: [
                  const SizedBox(width: 37),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⏱️ ${_formatRemaining(remainingSeconds)}',
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTogglePauseTimer,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      isTimerPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 17,
                    ),
                    label: Text(isTimerPaused ? 'Devam' : 'Duraklat'),
                  ),
                  TextButton.icon(
                    onPressed: onCancelTimer,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.dangerRed,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 17),
                    label: const Text('Sıfırla'),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 37),
                child: InkWell(
                  onTap: onStartTimer,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.subtleSurfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.cardBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.primaryEmerald,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$timerMinutes dk sayaç',
                          style: const TextStyle(
                            color: AppColors.primaryEmerald,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _SubtleChefTipCard extends StatelessWidget {
  final String tip;

  const _SubtleChefTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: AppColors.primaryEmerald,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Şefin Notu: $tip',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyDetailActionBar extends StatelessWidget {
  final bool cookedCompleted;
  final int servings;
  final VoidCallback onCook;
  final VoidCallback? onAddToMealPlan;

  const _StickyDetailActionBar({
    required this.cookedCompleted,
    required this.servings,
    required this.onCook,
    required this.onAddToMealPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.cardBorderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (onAddToMealPlan != null) ...[
                OutlinedButton.icon(
                  onPressed: onAddToMealPlan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryEmerald,
                    side: const BorderSide(color: AppColors.primaryEmerald),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                  label: const Text(
                    'Plana Ekle',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: cookedCompleted ? null : onCook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: Icon(
                    cookedCompleted
                        ? Icons.check_circle_rounded
                        : Icons.soup_kitchen_rounded,
                  ),
                  label: Text(
                    cookedCompleted
                        ? 'Stoktan Düşüldü'
                        : 'Pişirdim ($servings Porsiyon)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
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
