import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kiler/domain/kiler_models.dart';
import '../../../kiler/domain/kiler_service.dart';
import '../../domain/recipe_models.dart';
import 'recipe_visual_header.dart';

class RecipeDetailSheet extends StatefulWidget {
  final EvaluatedRecipeMatch match;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToMealPlan;
  final ValueChanged<int>? onRecipeCooked;
  final VoidCallback? onDeleteCustom;
  final VoidCallback? onPickCustomPhoto;
  final VoidCallback? onRemoveCustomPhoto;

  const RecipeDetailSheet({
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

  static Future<void> show(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeDetailSheet(
        match: match,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
        onAddToMealPlan: onAddToMealPlan,
        onRecipeCooked: onRecipeCooked,
        onDeleteCustom: onDeleteCustom,
        onPickCustomPhoto: onPickCustomPhoto,
        onRemoveCustomPhoto: onRemoveCustomPhoto,
      ),
    );
  }

  @override
  State<RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<RecipeDetailSheet> {
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
  void didUpdateWidget(covariant RecipeDetailSheet oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final recipe = widget.match.recipe;
    final expiringTags = widget.match.expiringIngredientsUsed
        .map((e) => e.normalizedTag)
        .toSet();
    final availableTags = <String>{
      ...widget.match.matchedRequiredTags,
      ...widget.match.matchedOptionalTags,
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          _SheetHeaderRow(
            recipe: recipe,
            isFavorite: _isFavorite,
            onToggleFavorite:
                widget.onToggleFavorite != null ? _handleToggleFavorite : null,
            onAddToMealPlan: widget.onAddToMealPlan,
            onDeleteCustom:
                recipe.isCustom && widget.onDeleteCustom != null
                    ? _confirmDeleteCustom
                    : null,
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecipeVisualHeader(
                    recipe: recipe,
                    height: 196,
                    heroMode: true,
                  ),
                  if (widget.onPickCustomPhoto != null ||
                      ((recipe.localImagePath?.trim().isNotEmpty ?? false) &&
                          widget.onRemoveCustomPhoto != null)) ...[
                    const SizedBox(height: 8),
                    _CustomPhotoActionStrip(
                      hasCustomPhoto:
                          recipe.localImagePath?.trim().isNotEmpty ?? false,
                      onPickCustomPhoto: widget.onPickCustomPhoto,
                      onRemoveCustomPhoto: widget.onRemoveCustomPhoto,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _RegionAndSourceStrip(recipe: recipe),
                  const SizedBox(height: 12),
                  _MetricsSummaryRow(match: widget.match),
                  const SizedBox(height: 12),
                  _PortionScalerSection(
                    presets: _portionPresets,
                    selectedServings: _servings,
                    baseServings: recipe.defaultServings,
                    onSelect: (val) => setState(() => _servings = val),
                  ),
                  const SizedBox(height: 10),
                  _LiveScaledNutritionPanel(
                    recipe: recipe,
                    servings: _servings,
                  ),
                  if (recipe.cleanLabelBadges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CleanBadgeStrip(badges: recipe.cleanLabelBadges),
                  ],
                  if (!widget.match.isProfileSafe) ...[
                    const SizedBox(height: 12),
                    _DetailAlertBanner(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.dangerRed,
                      text:
                          'Aile Profili Uyarısı: ${widget.match.profileWarnings.join(' • ')}',
                    ),
                  ],
                  if (widget.match.preventsFoodWaste) ...[
                    const SizedBox(height: 12),
                    _DetailAlertBanner(
                      icon: Icons.eco_rounded,
                      color: AppColors.cautionGold,
                      text:
                          'İsraf Önleyici Tarif: Dolabınızda değerlendirilmesi gereken (${{
                        ...widget.match.expiringIngredientsUsed.map((e) => e.name),
                        ...widget.match.longWaitingIngredientsUsed.map((e) => e.name),
                      }.join(', ')}) malzemelerini kullanır!',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Malzemeler ($_servings Porsiyon)',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (recipe.ingredients.isNotEmpty)
                    _MeasuredIngredientList(
                      ingredients: recipe.ingredients,
                      targetServings: _servings,
                      baseServings: recipe.defaultServings,
                      availableTags: availableTags,
                      missingRequiredTags: widget.match.missingRequiredTags,
                      expiringTags: expiringTags,
                    )
                  else
                    _TagFallbackIngredientWrap(match: widget.match),
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
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
                              : 'Eksik ${widget.match.missingRequiredTags.length} Malzemeyi Alışveriş Listesine Ekle',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Adım Adım Hazırlanışı',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe.steps.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final text = entry.value;
                    final timerMinutes = _extractMinutes(text);
                    final isTimerActive = _activeTimerStepIndex == idx;

                    return _StepCard(
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
                  const SizedBox(height: 8),
                  _ChefTipBox(tip: recipe.chefTip),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BottomActionBar(
            cookedCompleted: _cookedCompleted,
            servings: _servings,
            onCook: _handleCookRecipe,
            onAddToMealPlan: widget.onAddToMealPlan,
          ),
        ],
      ),
    );
  }
}

class _SheetHeaderRow extends StatelessWidget {
  final KilerRecipe recipe;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToMealPlan;
  final VoidCallback? onDeleteCustom;
  final VoidCallback onClose;

  const _SheetHeaderRow({
    required this.recipe,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToMealPlan,
    required this.onDeleteCustom,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final totalMin =
        recipe.totalMinutes > 0 ? recipe.totalMinutes : recipe.prepMinutes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryEmerald.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${recipe.category} • ${recipe.cookingMethod.emoji} ${recipe.cookingMethod.label} • ⏱️ $totalMin dk',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (onToggleFavorite != null)
          IconButton(
            onPressed: onToggleFavorite,
            tooltip: isFavorite ? 'Favoriden Çıkar' : 'Favorilere Ekle',
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite
                  ? AppColors.dangerRed
                  : context.textSecondaryColor,
            ),
          ),
        if (onDeleteCustom != null)
          IconButton(
            onPressed: onDeleteCustom,
            tooltip: 'Özel Tarifi Sil',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.dangerRed,
            ),
          ),
        if (onAddToMealPlan != null && onDeleteCustom == null)
          IconButton(
            onPressed: onAddToMealPlan,
            tooltip: 'Yemek Listesine Ekle',
            icon: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primaryEmerald,
            ),
          ),
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: context.textSecondaryColor),
        ),
      ],
    );
  }
}

class _MetricsSummaryRow extends StatelessWidget {
  final EvaluatedRecipeMatch match;

  const _MetricsSummaryRow({required this.match});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricInfoBox(
            title: 'Dolap Eşleşmesi',
            value: '%${match.matchPercent}',
            subtitle: match.isReadyToCook
                ? 'Tüm ana malzemeler evde!'
                : '${match.missingRequiredTags.length} malzeme eksik',
            color: match.isReadyToCook
                ? AppColors.primaryEmerald
                : AppColors.cautionGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricInfoBox(
            title: 'Yemek Sağlık Skoru',
            value: '${match.combinedHealthScore}/100',
            subtitle: match.isProfileSafe
                ? 'Aile profiliyle %100 uyumlu'
                : match.profileWarnings.first,
            color: match.isProfileSafe
                ? AppColors.primaryEmerald
                : AppColors.dangerRed,
          ),
        ),
      ],
    );
  }
}

class _MetricInfoBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricInfoBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionAndSourceStrip extends StatelessWidget {
  final KilerRecipe recipe;

  const _RegionAndSourceStrip({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final regionMeta = TurkishRegionRegistry.findById(recipe.regionId);
    final regionText = regionMeta != null
        ? '📍 ${recipe.originCity} • ${regionMeta.label}'
        : '📍 ${recipe.originCity}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            regionText,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Kaynak: ${recipe.sourceReference}',
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveScaledNutritionPanel extends StatelessWidget {
  final KilerRecipe recipe;
  final int servings;

  const _LiveScaledNutritionPanel({
    required this.recipe,
    required this.servings,
  });

  @override
  Widget build(BuildContext context) {
    final totalGrams = recipe.scaledPortionGrams(servings);
    final totalCalories = recipe.scaledCalories(servings);
    final totalProtein = recipe.scaledMacro(recipe.proteinGrams, servings);
    final totalCarbs = recipe.scaledMacro(recipe.carbsGrams, servings);
    final totalFat = recipe.scaledMacro(recipe.fatGrams, servings);
    final totalFiber = recipe.scaledMacro(recipe.fiberGrams, servings);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Canlı Besin & Gramaj ($servings Porsiyon)',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 12.5,
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
                  '1 Porsiyon: ${recipe.portionGram} g / ${recipe.calories} kcal',
                  style: const TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.cardBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚖️ Toplam: $totalGrams g',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '🔥 Toplam: $totalCalories kcal',
                  style: const TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MacroCell(label: 'Kalori', value: '$totalCalories kcal'),
              _MacroCell(label: 'Protein', value: '$totalProtein g'),
              _MacroCell(label: 'Karb', value: '$totalCarbs g'),
              _MacroCell(label: 'Yağ', value: '$totalFat g'),
              _MacroCell(label: 'Lif', value: '$totalFiber g'),
            ],
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

class _CleanBadgeStrip extends StatelessWidget {
  final List<String> badges;

  const _CleanBadgeStrip({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges
          .map(
            (b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '✓ $b',
                style: const TextStyle(
                  color: AppColors.primaryEmerald,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DetailAlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _DetailAlertBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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

class _PortionScalerSection extends StatelessWidget {
  final List<int> presets;
  final int selectedServings;
  final int baseServings;
  final ValueChanged<int> onSelect;

  const _PortionScalerSection({
    required this.presets,
    required this.selectedServings,
    required this.baseServings,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Porsiyon Ölçekleyici',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Standart: $baseServings kişilik',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            children: presets.map((count) {
              final selected = selectedServings == count;
              return InkWell(
                onTap: () => onSelect(count),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryEmerald
                        : context.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryEmerald
                          : context.cardBorderColor,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : context.textPrimaryColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MeasuredIngredientList extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final int targetServings;
  final int baseServings;
  final Set<String> availableTags;
  final List<String> missingRequiredTags;
  final Set<String> expiringTags;

  const _MeasuredIngredientList({
    required this.ingredients,
    required this.targetServings,
    required this.baseServings,
    required this.availableTags,
    required this.missingRequiredTags,
    required this.expiringTags,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ingredients.map((ing) {
        final isMissing =
            !ing.isOptional && missingRequiredTags.contains(ing.tag);
        final isAvailable = availableTags.contains(ing.tag) ||
            (ing.isPantryStaple && !isMissing);
        final isExpiring = expiringTags.contains(ing.tag);
        final Color statusColor = isMissing
            ? AppColors.cautionGold
            : isAvailable
                ? AppColors.primaryEmerald
                : context.textSecondaryColor;

        final statusLabel = isMissing
            ? 'Eksik'
            : isExpiring
                ? 'SKT Yakın ⏳'
                : isAvailable
                    ? 'Evde Var'
                    : ing.isOptional
                        ? 'İsteğe Bağlı'
                        : 'Kilerde Yok';

        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Icon(
                isMissing
                    ? Icons.shopping_basket_rounded
                    : isAvailable
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  ing.scaledLabel(targetServings, baseServings),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TagFallbackIngredientWrap extends StatelessWidget {
  final EvaluatedRecipeMatch match;

  const _TagFallbackIngredientWrap({required this.match});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...match.matchedRequiredTags.map(
          (tag) => _IngredientChip(
            label: QuickIngredientCatalog.displayNameForTag(tag),
            isAvailable: true,
          ),
        ),
        ...match.missingRequiredTags.map(
          (tag) => _IngredientChip(
            label: QuickIngredientCatalog.displayNameForTag(tag),
            isAvailable: false,
          ),
        ),
        ...match.matchedOptionalTags.map(
          (tag) => _IngredientChip(
            label: '${QuickIngredientCatalog.displayNameForTag(tag)} (Bonus)',
            isAvailable: true,
          ),
        ),
      ],
    );
  }
}

class _IngredientChip extends StatelessWidget {
  final String label;
  final bool isAvailable;

  const _IngredientChip({
    required this.label,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppColors.primaryEmerald : AppColors.cautionGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable
                ? Icons.check_circle_rounded
                : Icons.shopping_basket_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isAvailable ? '$label (Evde Var)' : '$label (Eksik)',
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
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

  const _StepCard({
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
    final borderColor = isTimerActive
        ? AppColors.primaryEmerald
        : isCompleted
            ? AppColors.primaryEmerald.withValues(alpha: 0.45)
            : context.cardBorderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTimerActive
            ? AppColors.primaryEmerald.withValues(alpha: 0.08)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stepText,
                    style: TextStyle(
                      color: isCompleted
                          ? context.textSecondaryColor
                          : context.textPrimaryColor,
                      fontSize: 13,
                      height: 1.4,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⏱️ ${_formatRemaining(remainingSeconds)}',
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTogglePauseTimer,
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
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 17),
                    label: const Text('Sıfırla'),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onStartTimer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryEmerald,
                    side: BorderSide(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.timer_outlined, size: 15),
                  label: Text(
                    '$timerMinutes dk Sayaç Başlat',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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

class _ChefTipBox extends StatelessWidget {
  final String tip;

  const _ChefTipBox({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryMint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryMint.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Şefin Püf Noktası: $tip',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool cookedCompleted;
  final int servings;
  final VoidCallback onCook;
  final VoidCallback? onAddToMealPlan;

  const _BottomActionBar({
    required this.cookedCompleted,
    required this.servings,
    required this.onCook,
    required this.onAddToMealPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onAddToMealPlan != null) ...[
          OutlinedButton.icon(
            onPressed: onAddToMealPlan,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryEmerald,
              side: const BorderSide(color: AppColors.primaryEmerald),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              cookedCompleted
                  ? Icons.check_circle_rounded
                  : Icons.soup_kitchen_rounded,
            ),
            label: Text(
              cookedCompleted
                  ? 'Stoktan Düşüldü — Afiyet Olsun!'
                  : 'Pişirdim ($servings Porsiyon • Stoktan Düş)',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomPhotoActionStrip extends StatelessWidget {
  final bool hasCustomPhoto;
  final VoidCallback? onPickCustomPhoto;
  final VoidCallback? onRemoveCustomPhoto;

  const _CustomPhotoActionStrip({
    required this.hasCustomPhoto,
    required this.onPickCustomPhoto,
    required this.onRemoveCustomPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickCustomPhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryEmerald,
                side: BorderSide(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                hasCustomPhoto
                    ? Icons.refresh_rounded
                    : Icons.add_a_photo_rounded,
                size: 15,
              ),
              label: Text(
                hasCustomPhoto
                    ? '🔄 Fotoğrafı Değiştir'
                    : '📸 Gerçek Fotoğrafını Ekle',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (hasCustomPhoto && onRemoveCustomPhoto != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRemoveCustomPhoto,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text(
                'Kaldır',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
