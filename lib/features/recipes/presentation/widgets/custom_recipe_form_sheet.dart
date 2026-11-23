import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kiler/domain/kiler_models.dart';
import '../../domain/recipe_models.dart';

/// Modal bottom sheet form to create a custom KilerRecipe with automatic
/// IngredientNormalizer tag resolution.
class CustomRecipeFormSheet extends StatefulWidget {
  final ValueChanged<KilerRecipe> onSave;

  const CustomRecipeFormSheet({
    super.key,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<KilerRecipe> onSave,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomRecipeFormSheet(onSave: onSave),
    );
  }

  @override
  State<CustomRecipeFormSheet> createState() => _CustomRecipeFormSheetState();
}

class _CustomRecipeFormSheetState extends State<CustomRecipeFormSheet> {
  static const List<String> _emojiChoices = [
    '🍲',
    '🥗',
    '🍳',
    '🥣',
    '🍗',
    '🐟',
    '🍝',
    '🥘',
    '🥞',
    '🍰',
  ];

  static const List<String> _unitChoices = [
    'Adet',
    'gr',
    'Kg',
    'ml',
    'Yemek Kaşığı',
    'Su Bardağı',
    'Demet',
    'Paket',
  ];

  static const List<int> _servingChoices = [1, 2, 4, 6, 8];

  static const List<String> _quickStarterTags = [
    'zeytinyagi',
    'sogan',
    'sarimsak',
    'domates',
    'yumurta',
    'tavuk',
    'kiyma',
    'yogurt',
    'kirmizi_mercimek',
    'bulgur',
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _originCityController = TextEditingController();
  final TextEditingController _prepMinutesController = TextEditingController(
    text: '15',
  );
  final TextEditingController _cookMinutesController = TextEditingController(
    text: '20',
  );
  final TextEditingController _portionGramController = TextEditingController(
    text: '250',
  );
  final TextEditingController _caloriesController = TextEditingController(
    text: '320',
  );
  final TextEditingController _proteinController = TextEditingController(
    text: '18',
  );
  final TextEditingController _ingredientNameController =
      TextEditingController();
  final TextEditingController _ingredientAmountController =
      TextEditingController(text: '1');
  final TextEditingController _stepController = TextEditingController();
  final TextEditingController _chefTipController = TextEditingController();

  String _selectedEmoji = '🍲';
  String _selectedCategory = RecipeCategoryRegistry.vegOliveOil;
  String _selectedRegionId = TurkishRegionRegistry.tumTurkiye;
  final Set<MealSlot> _selectedSlots = {MealSlot.mainCourse};
  CookingMethod _cookingMethod = CookingMethod.pot;
  RecipeDifficulty _difficulty = RecipeDifficulty.easy;
  int _defaultServings = 2;

  String _selectedUnit = 'Adet';
  bool _ingredientOptional = false;
  QuickIngredientTemplate? _resolvedPreview;

  final List<RecipeIngredient> _ingredients = [];
  final List<String> _steps = [];

  bool _containsGluten = false;
  bool _containsLactose = false;
  bool _isVegan = false;
  bool _isChildFriendly = true;
  bool _isLowGlycemic = true;
  bool _isLowSodium = true;

  String? _validationError;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _originCityController.dispose();
    _prepMinutesController.dispose();
    _cookMinutesController.dispose();
    _portionGramController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _ingredientNameController.dispose();
    _ingredientAmountController.dispose();
    _stepController.dispose();
    _chefTipController.dispose();
    super.dispose();
  }

  void _onIngredientInputChanged(String raw) {
    final trimmed = raw.trim();
    setState(() {
      _resolvedPreview = trimmed.isEmpty
          ? null
          : IngredientNormalizer.resolveMetadata(trimmed);
    });
  }

  void _addIngredientFromInput() {
    final raw = _ingredientNameController.text.trim();
    if (raw.isEmpty) return;

    final resolved = IngredientNormalizer.resolveMetadata(raw);
    final amountRaw =
        _ingredientAmountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountRaw) ?? 1.0;

    setState(() {
      _ingredients.add(
        RecipeIngredient(
          tag: resolved.tag,
          name: raw,
          amount: amount > 0 ? amount : 1.0,
          unit: _selectedUnit,
          isOptional: _ingredientOptional,
        ),
      );
      _ingredientNameController.clear();
      _ingredientAmountController.text = '1';
      _ingredientOptional = false;
      _resolvedPreview = null;
      _validationError = null;
    });
  }

  void _addQuickTemplateIngredient(QuickIngredientTemplate tpl) {
    setState(() {
      _ingredients.add(
        RecipeIngredient(
          tag: tpl.tag,
          name: tpl.name,
          amount: 1,
          unit: 'Adet',
        ),
      );
      _validationError = null;
    });
  }

  void _addStepFromInput() {
    final text = _stepController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _steps.add(text);
      _stepController.clear();
      _validationError = null;
    });
  }

  void _toggleSlot(MealSlot slot) {
    setState(() {
      if (_selectedSlots.contains(slot)) {
        if (_selectedSlots.length > 1) {
          _selectedSlots.remove(slot);
        }
      } else {
        _selectedSlots.add(slot);
      }
    });
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Lütfen tarif adını girin.');
      return;
    }

    final pendingIngredient = _ingredientNameController.text.trim();
    if (pendingIngredient.isNotEmpty) {
      _addIngredientFromInput();
    }

    final pendingStep = _stepController.text.trim();
    if (pendingStep.isNotEmpty) {
      _addStepFromInput();
    }

    if (_ingredients.isEmpty) {
      setState(() => _validationError = 'En az 1 malzeme ekleyin.');
      return;
    }

    if (_steps.isEmpty) {
      setState(() => _validationError = 'En az 1 hazırlanış adımı ekleyin.');
      return;
    }

    final requiredTags = _ingredients
        .where((i) => !i.isOptional)
        .map((i) => i.tag)
        .toSet()
        .toList();
    final optionalTags = _ingredients
        .where((i) => i.isOptional)
        .map((i) => i.tag)
        .toSet()
        .toList();

    final effectiveRequired = requiredTags.isNotEmpty
        ? requiredTags
        : _ingredients.map((i) => i.tag).toSet().toList();

    final prep = int.tryParse(_prepMinutesController.text.trim()) ?? 15;
    final cook = int.tryParse(_cookMinutesController.text.trim()) ?? 20;
    final parsedPortionGram =
        int.tryParse(_portionGramController.text.trim()) ?? 250;
    final portionGram = parsedPortionGram > 0 ? parsedPortionGram : 250;
    final kcal = int.tryParse(_caloriesController.text.trim()) ?? 320;
    final protein = int.tryParse(_proteinController.text.trim()) ?? 18;
    final subtitle = _subtitleController.text.trim();
    final originCityRaw = _originCityController.text.trim();
    final originCity = originCityRaw.isEmpty ? 'Ev Mutfağı' : originCityRaw;
    final tip = _chefTipController.text.trim();

    final recipe = KilerRecipe(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle.isEmpty ? 'Ev yapımı özel tarif' : subtitle,
      emoji: _selectedEmoji,
      category: _selectedCategory,
      regionId: _selectedRegionId,
      originCity: originCity,
      prepMinutes: prep >= 0 ? prep : 15,
      cookMinutes: cook >= 0 ? cook : 0,
      defaultServings: _defaultServings,
      portionGram: portionGram,
      calories: kcal > 0 ? kcal : 280,
      proteinGrams: protein >= 0 ? protein : 12,
      baseHealthScore: 94,
      difficulty: _difficulty,
      cookingMethod: _cookingMethod,
      requiredTags: effectiveRequired,
      optionalTags: optionalTags,
      ingredients: List<RecipeIngredient>.unmodifiable(_ingredients),
      steps: List<String>.unmodifiable(_steps),
      containsGluten: _containsGluten,
      containsLactose: _containsLactose,
      isVegan: _isVegan,
      isChildFriendly: _isChildFriendly,
      isLowGlycemic: _isLowGlycemic,
      isLowSodium: _isLowSodium,
      cleanLabelBadges: const ['Özel Ev Tarifi', 'Katkısız'],
      mealSlots: _selectedSlots.toList(),
      chefTip: tip.isEmpty
          ? 'Taze malzemelerle kısık ateşte pişirerek besin değerini koruyun.'
          : tip,
      sourceReference: 'Özel Ev Tarifi',
      isCustom: true,
    );

    widget.onSave(recipe);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quickTemplates = _quickStarterTags
        .map(QuickIngredientCatalog.findByTag)
        .whereType<QuickIngredientTemplate>()
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.cardBorderColor),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        children: [
          const _SheetHandle(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Özel Tarif Oluştur',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Malzemeler otomatik olarak dolap etiketleriyle eşleşir',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 11.5,
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
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _validationError!),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormSectionTitle(title: 'İkon & Tarif Başlığı'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojiChoices.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final emoji = _emojiChoices[index];
                        final selected = emoji == _selectedEmoji;
                        return InkWell(
                          onTap: () => setState(() => _selectedEmoji = emoji),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryEmerald.withValues(
                                      alpha: 0.18,
                                    )
                                  : context.subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primaryEmerald
                                    : context.cardBorderColor,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StyledTextField(
                    controller: _titleController,
                    label: 'Tarif Adı *',
                    hint: 'Örn: Zeytinyağlı Kabak Mücver',
                    onChanged: (_) {
                      if (_validationError != null) {
                        setState(() => _validationError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _StyledTextField(
                    controller: _subtitleController,
                    label: 'Kısa Açıklama',
                    hint: 'Örn: Fırında çıtır, hafif akşam yemeği',
                  ),
                  const SizedBox(height: 16),
                  const _FormSectionTitle(title: 'Kategori'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: RecipeCategoryRegistry.categories.map((cat) {
                      return _FormChoiceChip(
                        label: '${cat.emoji} ${cat.shortLabel}',
                        selected: _selectedCategory == cat.id,
                        onTap: () => setState(() => _selectedCategory = cat.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const _FormSectionTitle(title: 'Mutfak Bölgesi & İl / Yöre'),
                  const SizedBox(height: 8),
                  _RegionDropdownField(
                    selectedRegionId: _selectedRegionId,
                    onChanged: (regionId) {
                      if (regionId != null) {
                        setState(() => _selectedRegionId = regionId);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _StyledTextField(
                    controller: _originCityController,
                    label: 'İl / Yöre',
                    hint: 'Örn: Gaziantep, İzmir, Trabzon',
                  ),
                  const SizedBox(height: 16),
                  const _FormSectionTitle(title: 'Uygun Öğünler'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MealSlot.values.map((slot) {
                      return _FormChoiceChip(
                        label: '${slot.emoji} ${slot.label}',
                        selected: _selectedSlots.contains(slot),
                        onTap: () => _toggleSlot(slot),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const _FormSectionTitle(title: 'Pişirme Metodu & Zorluk'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: CookingMethod.values.map((method) {
                      return _FormChoiceChip(
                        label: '${method.emoji} ${method.label}',
                        selected: _cookingMethod == method,
                        onTap: () => setState(() => _cookingMethod = method),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: RecipeDifficulty.values.map((diff) {
                      return _FormChoiceChip(
                        label: diff.label,
                        selected: _difficulty == diff,
                        onTap: () => setState(() => _difficulty = diff),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const _FormSectionTitle(title: 'Süre, Porsiyon & Besin'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StyledTextField(
                          controller: _prepMinutesController,
                          label: 'Hazırlık (dk)',
                          hint: '15',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StyledTextField(
                          controller: _cookMinutesController,
                          label: 'Pişirme (dk)',
                          hint: '20',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StyledTextField(
                          controller: _caloriesController,
                          label: 'Kalori (kcal)',
                          hint: '320',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StyledTextField(
                          controller: _proteinController,
                          label: 'Protein (g)',
                          hint: '18',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StyledTextField(
                    controller: _portionGramController,
                    label: '1 Porsiyon Gramajı (g)',
                    hint: '250',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: _servingChoices.map((count) {
                      return _FormChoiceChip(
                        label: '$count Porsiyon',
                        selected: _defaultServings == count,
                        onTap: () => setState(() => _defaultServings = count),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const _FormSectionTitle(
                    title: 'Malzemeler (Otomatik Etiket Eşleştirme)',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickTemplates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final tpl = quickTemplates[index];
                        return ActionChip(
                          label: Text(
                            '+ ${tpl.emoji} ${tpl.name}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _addQuickTemplateIngredient(tpl),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _StyledTextField(
                          controller: _ingredientNameController,
                          label: 'Malzeme Adı',
                          hint: 'Örn: Kuru Soğan, Tavuk Göğsü',
                          onChanged: _onIngredientInputChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StyledTextField(
                          controller: _ingredientAmountController,
                          label: 'Miktar',
                          hint: '2',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_resolvedPreview != null) ...[
                    const SizedBox(height: 6),
                    _TagResolutionPreview(template: _resolvedPreview!),
                  ],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _unitChoices.map((unit) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FormChoiceChip(
                            label: unit,
                            selected: _selectedUnit == unit,
                            onTap: () => setState(() => _selectedUnit = unit),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text(
                          'İsteğe Bağlı',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: _ingredientOptional,
                        onSelected: (val) =>
                            setState(() => _ingredientOptional = val),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _addIngredientFromInput,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Malzeme Ekle'),
                      ),
                    ],
                  ),
                  if (_ingredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._ingredients.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ing = entry.value;
                      return _AddedIngredientTile(
                        ingredient: ing,
                        onRemove: () =>
                            setState(() => _ingredients.removeAt(idx)),
                      );
                    }),
                  ],
                  const SizedBox(height: 18),
                  const _FormSectionTitle(title: 'Hazırlanış Adımları'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _StyledTextField(
                          controller: _stepController,
                          label: 'Adım Açıklaması',
                          hint: 'Örn: Sebzeleri 10 dk kısık ateşte pişirin',
                          onSubmitted: (_) => _addStepFromInput(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ElevatedButton(
                          onPressed: _addStepFromInput,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ],
                  ),
                  if (_steps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._steps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      return _AddedStepTile(
                        stepNumber: idx + 1,
                        text: entry.value,
                        onRemove: () => setState(() => _steps.removeAt(idx)),
                      );
                    }),
                  ],
                  const SizedBox(height: 18),
                  const _FormSectionTitle(title: 'Beslenme Profili & Şef Notu'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('Gluten İçerir'),
                        selected: _containsGluten,
                        onSelected: (v) => setState(() => _containsGluten = v),
                      ),
                      FilterChip(
                        label: const Text('Laktoz İçerir'),
                        selected: _containsLactose,
                        onSelected: (v) => setState(() => _containsLactose = v),
                      ),
                      FilterChip(
                        label: const Text('Vegan'),
                        selected: _isVegan,
                        onSelected: (v) => setState(() => _isVegan = v),
                      ),
                      FilterChip(
                        label: const Text('Çocuk Dostu'),
                        selected: _isChildFriendly,
                        onSelected: (v) => setState(() => _isChildFriendly = v),
                      ),
                      FilterChip(
                        label: const Text('Düşük Glisemik'),
                        selected: _isLowGlycemic,
                        onSelected: (v) => setState(() => _isLowGlycemic = v),
                      ),
                      FilterChip(
                        label: const Text('Az Tuzlu'),
                        selected: _isLowSodium,
                        onSelected: (v) => setState(() => _isLowSodium = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StyledTextField(
                    controller: _chefTipController,
                    label: 'Şefin Püf Noktası (İsteğe Bağlı)',
                    hint: 'Örn: Servis öncesi taze limon suyu gezdirin',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Özel Tarifi Kaydet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

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

class _FormSectionTitle extends StatelessWidget {
  final String title;

  const _FormSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.textPrimaryColor,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.45)),
      ),
      child: Text(
        '⚠️ $message',
        style: const TextStyle(
          color: AppColors.dangerRed,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: context.subtleSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
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
    );
  }
}

class _FormChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald.withValues(alpha: 0.16)
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(10),
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
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TagResolutionPreview extends StatelessWidget {
  final QuickIngredientTemplate template;

  const _TagResolutionPreview({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryEmerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '${template.emoji} Otomatik Etiket: #${template.tag} • ${template.category}',
        style: const TextStyle(
          color: AppColors.primaryEmerald,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddedIngredientTile extends StatelessWidget {
  final RecipeIngredient ingredient;
  final VoidCallback onRemove;

  const _AddedIngredientTile({
    required this.ingredient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.scaledLabel(1, 1),
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '#${ingredient.tag}${ingredient.isOptional ? ' • İsteğe Bağlı' : ''}',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.dangerRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddedStepTile extends StatelessWidget {
  final int stepNumber;
  final String text;
  final VoidCallback onRemove;

  const _AddedStepTile({
    required this.stepNumber,
    required this.text,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.primaryEmerald,
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.textPrimaryColor, fontSize: 12.5),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.dangerRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionDropdownField extends StatelessWidget {
  final String selectedRegionId;
  final ValueChanged<String?> onChanged;

  const _RegionDropdownField({
    required this.selectedRegionId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedRegionId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Coğrafi Bölge',
        filled: true,
        fillColor: context.subtleSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
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
      items: TurkishRegionRegistry.allRegions.map((region) {
        return DropdownMenuItem<String>(
          value: region.id,
          child: Text(
            '${region.emoji} ${region.label}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
