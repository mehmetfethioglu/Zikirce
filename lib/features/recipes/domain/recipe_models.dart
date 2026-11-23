import 'dart:convert';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../kiler/domain/kiler_models.dart';

/// Top-level mode of the Yemek & Tarifler module.
enum YemekModuleMode {
  explore('📖 Tarif Keşfet'),
  mealList('📅 Yemek Listem');

  final String label;
  const YemekModuleMode(this.label);
}

/// Filter tabs for exploring recipes.
enum RecipeFilterTab {
  all('Tümü'),
  readyNow('Hemen Pişir (%100)'),
  wasteSaver('İsraf Önleyici ⏳'),
  almostReady('1-2 Eksikli'),
  quick('Pratik (<20 dk)'),
  highProtein('Yüksek Protein 💪'),
  favorites('Favorilerim ❤️'),
  custom('Özel Tariflerim 📝');

  final String label;
  const RecipeFilterTab(this.label);
}

enum RecipeDifficulty {
  easy('Kolay'),
  medium('Orta'),
  chef('Özenli');

  final String label;
  const RecipeDifficulty(this.label);

  static RecipeDifficulty fromName(String? name) {
    for (final d in RecipeDifficulty.values) {
      if (d.name == name) return d;
    }
    return RecipeDifficulty.easy;
  }
}

enum CookingMethod {
  pot('pot', 'Tencere', '🍲'),
  oven('oven', 'Fırın (Kızartmasız)', '🔥'),
  pan('pan', 'Tava / Sote', '🍳'),
  raw('raw', 'Çiğ / Pratik', '🥗'),
  blender('blender', 'Blender', '🥣');

  final String code;
  final String label;
  final String emoji;
  const CookingMethod(this.code, this.label, this.emoji);

  static CookingMethod fromCode(String? code) {
    for (final m in CookingMethod.values) {
      if (m.code == code || m.name == code) return m;
    }
    return CookingMethod.pot;
  }
}

enum MealSlot {
  breakfast('BREAKFAST', 'Kahvaltı', '🍳'),
  soupStarter('SOUP_STARTER', 'Çorba & Başlangıç', '🥣'),
  mainCourse('MAIN_COURSE', 'Ana Yemek', '🍲'),
  sideSnack('SIDE_SNACK', 'Salata / Ara Öğün', '🥗');

  final String dbCode;
  final String label;
  final String emoji;
  const MealSlot(this.dbCode, this.label, this.emoji);

  static MealSlot fromDb(String? code) {
    for (final s in MealSlot.values) {
      if (s.dbCode == code || s.name == code) return s;
    }
    return MealSlot.mainCourse;
  }
}

enum MealPlanPreset {
  zeroWasteSmart(
    'İsraf Önleyici Kiler',
    '⏳',
    'SKT yaklaşan ve evde olan malzemeleri ilk günlerde önceliklendirir',
  ),
  cleanFamilyBalanced(
    'Dengeli Temiz Aile',
    '🏡',
    'Çorba, sebze, bakliyat ve et dengeli geleneksel ev menüsü',
  ),
  highProteinFit(
    'Yüksek Protein & Fit',
    '💪',
    'Yüksek proteinli, düşük glisemik indeksli temiz öğünler',
  ),
  quickWeekdays(
    'Pratik Hafta İçi',
    '⚡',
    'Hafta içi 25 dk altı hızlı ve sağlıklı tarifler',
  ),
  regionalAnatolianTour(
    '7 Bölge Yöresel Sofra',
    '🗺️',
    'Haftanın 7 günü Türkiye\'nin 7 bölgesinden kiler uyumlu yöresel menü',
  );

  final String label;
  final String emoji;
  final String description;
  const MealPlanPreset(this.label, this.emoji, this.description);
}

/// Geographical region metadata for Türkiye's 7 regional cuisines.
class TurkishRegionMeta {
  final String id;
  final String label;
  final String shortLabel;
  final String emoji;
  final String subtitle;

  const TurkishRegionMeta({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.emoji,
    required this.subtitle,
  });
}

/// OCP registry for Türkiye's 7 geographical cuisines + common Anatolian home kitchen.
class TurkishRegionRegistry {
  static const String all = 'tum_turler';
  static const String marmara = 'marmara';
  static const String ege = 'ege';
  static const String akdeniz = 'akdeniz';
  static const String icAnadolu = 'ic_anadolu';
  static const String karadeniz = 'karadeniz';
  static const String doguAnadolu = 'dogu_anadolu';
  static const String guneydogu = 'guneydogu';
  static const String tumTurkiye = 'tum_turkiye';

  static const List<TurkishRegionMeta> sevenRegions = [
    TurkishRegionMeta(
      id: marmara,
      label: 'Marmara Bölgesi',
      shortLabel: 'Marmara',
      emoji: '🏰',
      subtitle: 'Saray mutfağı, Bursa, Trakya & zeytinyağlılar',
    ),
    TurkishRegionMeta(
      id: ege,
      label: 'Ege Bölgesi',
      shortLabel: 'Ege',
      emoji: '🫒',
      subtitle: 'Enginar, zeytinyağlı sebzeler & İzmir-Bodrum klasikleri',
    ),
    TurkishRegionMeta(
      id: akdeniz,
      label: 'Akdeniz Bölgesi',
      shortLabel: 'Akdeniz',
      emoji: '🍊',
      subtitle: 'Tahinli piyaz, Hatay-Adana-Mersin yöresel sofrası',
    ),
    TurkishRegionMeta(
      id: icAnadolu,
      label: 'İç Anadolu Bölgesi',
      shortLabel: 'İç Anadolu',
      emoji: '🌾',
      subtitle: 'Kayseri mantısı, Ankara tava, bakliyat & erişte',
    ),
    TurkishRegionMeta(
      id: karadeniz,
      label: 'Karadeniz Bölgesi',
      shortLabel: 'Karadeniz',
      emoji: '🌊',
      subtitle: 'Kuymak, karalahana, hamsili pilav & yayla lezzetleri',
    ),
    TurkishRegionMeta(
      id: doguAnadolu,
      label: 'Doğu Anadolu Bölgesi',
      shortLabel: 'Doğu Anadolu',
      emoji: '🏔️',
      subtitle: 'Ayran aşı, dövme keşkek, Harput & yayla aşları',
    ),
    TurkishRegionMeta(
      id: guneydogu,
      label: 'Güneydoğu Anadolu',
      shortLabel: 'Güneydoğu',
      emoji: '🌶️',
      subtitle: 'Gaziantep-Urfa-Mardin şifa çorbaları, köz & kebaplar',
    ),
  ];

  static const List<TurkishRegionMeta> allRegions = [
    ...sevenRegions,
    TurkishRegionMeta(
      id: tumTurkiye,
      label: 'Ortak Ev Mutfağı',
      shortLabel: 'Ev Klasikleri',
      emoji: '🇹🇷',
      subtitle: 'Türkiye genelinde günlük pişen pratik sağlıklı tarifler',
    ),
  ];

  static TurkishRegionMeta? findById(String? regionId) {
    if (regionId == null || regionId.isEmpty) return null;
    for (final region in allRegions) {
      if (region.id == regionId) return region;
    }
    return null;
  }

  static bool matchesRegion(String recipeRegionId, String? selectedRegionId) {
    if (selectedRegionId == null ||
        selectedRegionId.isEmpty ||
        selectedRegionId == all) {
      return true;
    }
    return recipeRegionId == selectedRegionId;
  }
}

class RecipeCategoryMeta {
  final String id;
  final String label;
  final String emoji;
  final String shortLabel;

  const RecipeCategoryMeta({
    required this.id,
    required this.label,
    required this.emoji,
    required this.shortLabel,
  });
}

/// OCP registry of all 7 standard Kilerce recipe categories.
class RecipeCategoryRegistry {
  static const String breakfast = 'Kahvaltı & Pratik';
  static const String soup = 'Çorba';
  static const String meatFish = 'Et, Tavuk & Balık';
  static const String vegOliveOil = 'Sebze & Zeytinyağlı';
  static const String legumesGrains = 'Bakliyat & Pilav';
  static const String saladMeze = 'Salata & Meze';
  static const String healthyDessertKids = 'Sağlıklı Tatlı & Çocuk';

  static const List<RecipeCategoryMeta> categories = [
    RecipeCategoryMeta(
      id: breakfast,
      label: breakfast,
      emoji: '🍳',
      shortLabel: 'Kahvaltı',
    ),
    RecipeCategoryMeta(
      id: soup,
      label: soup,
      emoji: '🥣',
      shortLabel: 'Çorba',
    ),
    RecipeCategoryMeta(
      id: meatFish,
      label: meatFish,
      emoji: '🍗',
      shortLabel: 'Et & Balık',
    ),
    RecipeCategoryMeta(
      id: vegOliveOil,
      label: vegOliveOil,
      emoji: '🥬',
      shortLabel: 'Sebze',
    ),
    RecipeCategoryMeta(
      id: legumesGrains,
      label: legumesGrains,
      emoji: '🫘',
      shortLabel: 'Bakliyat',
    ),
    RecipeCategoryMeta(
      id: saladMeze,
      label: saladMeze,
      emoji: '🥗',
      shortLabel: 'Salata',
    ),
    RecipeCategoryMeta(
      id: healthyDessertKids,
      label: healthyDessertKids,
      emoji: '🍯',
      shortLabel: 'Tatlı & Çocuk',
    ),
  ];

  static RecipeCategoryMeta? findById(String? category) {
    if (category == null) return null;
    for (final c in categories) {
      if (c.id == category) return c;
    }
    return null;
  }

  static bool matchesCategory(String recipeCategory, String? filterCategory) {
    if (filterCategory == null || filterCategory.isEmpty) return true;
    if (recipeCategory == filterCategory) return true;
    // Backward compatibility if any older caller passes 'Et & Tavuk'
    if (filterCategory == 'Et & Tavuk' && recipeCategory == meatFish) {
      return true;
    }
    if (filterCategory == meatFish && recipeCategory == 'Et & Tavuk') {
      return true;
    }
    return false;
  }
}

/// Measured recipe ingredient with dynamic portion scaling.
class RecipeIngredient {
  final String tag;
  final String name;
  final double amount;
  final String unit;
  final bool isOptional;
  final bool isPantryStaple;

  const RecipeIngredient({
    required this.tag,
    required this.name,
    required this.amount,
    required this.unit,
    this.isOptional = false,
    this.isPantryStaple = false,
  });

  double scaledAmount(int targetServings, int baseServings) {
    final safeBase = baseServings <= 0 ? 1 : baseServings;
    final safeTarget = targetServings <= 0 ? 1 : targetServings;
    return (amount * safeTarget) / safeBase;
  }

  String scaledLabel(int targetServings, int baseServings) {
    final val = scaledAmount(targetServings, baseServings);
    final formatted = _formatAmount(val);
    final cleanUnit = unit.trim();
    if (cleanUnit.isEmpty) {
      return '$formatted $name'.trim();
    }
    return '$formatted $cleanUnit $name'.trim();
  }

  static String _formatAmount(double value) {
    if (value <= 0) return '1';
    final roundedQuarter = (value * 4).round() / 4.0;
    final intPart = roundedQuarter.floor();
    final frac = roundedQuarter - intPart;

    String? fracSymbol;
    if ((frac - 0.25).abs() < 0.05) {
      fracSymbol = '¼';
    } else if ((frac - 0.5).abs() < 0.05) {
      fracSymbol = '½';
    } else if ((frac - 0.75).abs() < 0.05) {
      fracSymbol = '¾';
    }

    if (frac < 0.05) {
      return '$intPart';
    }
    if (frac > 0.95) {
      return '${intPart + 1}';
    }
    if (fracSymbol != null) {
      return intPart == 0 ? fracSymbol : '$intPart $fracSymbol';
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'name': name,
        'amount': amount,
        'unit': unit,
        'isOptional': isOptional,
        'isPantryStaple': isPantryStaple,
      };

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      tag: (map['tag'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      amount: ((map['amount'] as num?) ?? 1).toDouble(),
      unit: (map['unit'] as String?) ?? 'Adet',
      isOptional: (map['isOptional'] as bool?) ?? false,
      isPantryStaple: (map['isPantryStaple'] as bool?) ?? false,
    );
  }
}

class KilerRecipe {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String category;
  final String regionId;
  final String originCity;
  final int prepMinutes;
  final int cookMinutes;
  final int defaultServings;
  final int portionGram;
  final int calories;
  final int proteinGrams;
  final int fiberGrams;
  final int carbsGrams;
  final int fatGrams;
  final int baseHealthScore;
  final RecipeDifficulty difficulty;
  final CookingMethod cookingMethod;
  final List<String> requiredTags;
  final List<String> optionalTags;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final bool containsGluten;
  final bool containsLactose;
  final bool isVegan;
  final bool isChildFriendly;
  final bool isLowGlycemic;
  final bool isLowSodium;
  final List<String> cleanLabelBadges;
  final List<MealSlot> mealSlots;
  final String chefTip;
  final String? imageAsset;
  final String? localImagePath;
  final String? imageUrl;
  final String? photoCredit;
  final String? videoUrl;
  final String sourceReference;
  final bool isCustom;

  const KilerRecipe({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.category,
    this.regionId = TurkishRegionRegistry.tumTurkiye,
    this.originCity = 'Anadolu Mutfağı',
    required this.prepMinutes,
    this.cookMinutes = 0,
    this.defaultServings = 2,
    this.portionGram = 250,
    required this.calories,
    required this.proteinGrams,
    this.fiberGrams = 5,
    this.carbsGrams = 22,
    this.fatGrams = 11,
    required this.baseHealthScore,
    this.difficulty = RecipeDifficulty.easy,
    this.cookingMethod = CookingMethod.pot,
    required this.requiredTags,
    this.optionalTags = const [],
    this.ingredients = const [],
    required this.steps,
    this.containsGluten = false,
    this.containsLactose = false,
    this.isVegan = false,
    this.isChildFriendly = true,
    this.isLowGlycemic = true,
    this.isLowSodium = true,
    this.cleanLabelBadges = const ['Katkısız Ev Yapımı', 'Rafine Şekersiz'],
    this.mealSlots = const [MealSlot.mainCourse],
    required this.chefTip,
    this.imageAsset,
    this.localImagePath,
    this.imageUrl,
    this.photoCredit,
    this.videoUrl,
    this.sourceReference = 'Geleneksel Ev Ölçüsü',
    this.isCustom = false,
  });

  int get totalMinutes => prepMinutes + cookMinutes;

  MealSlot get primarySlot =>
      mealSlots.isNotEmpty ? mealSlots.first : MealSlot.mainCourse;

  /// Total energy (kcal) scaled to [targetServings] (base macros are per 1 portion).
  int scaledCalories(int targetServings) {
    final safe = targetServings <= 0 ? 1 : targetServings;
    return calories * safe;
  }

  /// Total weight (grams) scaled to [targetServings].
  int scaledPortionGrams(int targetServings) {
    final safe = targetServings <= 0 ? 1 : targetServings;
    return portionGram * safe;
  }

  /// Scales any 1-serving macro gram value to [targetServings].
  int scaledMacro(int baseGrams, int targetServings) {
    final safe = targetServings <= 0 ? 1 : targetServings;
    return baseGrams * safe;
  }

  KilerRecipe copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? emoji,
    String? category,
    String? regionId,
    String? originCity,
    int? prepMinutes,
    int? cookMinutes,
    int? defaultServings,
    int? portionGram,
    int? calories,
    int? proteinGrams,
    int? fiberGrams,
    int? carbsGrams,
    int? fatGrams,
    int? baseHealthScore,
    RecipeDifficulty? difficulty,
    CookingMethod? cookingMethod,
    List<String>? requiredTags,
    List<String>? optionalTags,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    bool? containsGluten,
    bool? containsLactose,
    bool? isVegan,
    bool? isChildFriendly,
    bool? isLowGlycemic,
    bool? isLowSodium,
    List<String>? cleanLabelBadges,
    List<MealSlot>? mealSlots,
    String? chefTip,
    String? imageAsset,
    bool clearImageAsset = false,
    String? localImagePath,
    bool clearLocalImagePath = false,
    String? imageUrl,
    String? photoCredit,
    String? videoUrl,
    bool clearVideoUrl = false,
    String? sourceReference,
    bool? isCustom,
  }) {
    return KilerRecipe(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      regionId: regionId ?? this.regionId,
      originCity: originCity ?? this.originCity,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      defaultServings: defaultServings ?? this.defaultServings,
      portionGram: portionGram ?? this.portionGram,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fiberGrams: fiberGrams ?? this.fiberGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      baseHealthScore: baseHealthScore ?? this.baseHealthScore,
      difficulty: difficulty ?? this.difficulty,
      cookingMethod: cookingMethod ?? this.cookingMethod,
      requiredTags: requiredTags ?? this.requiredTags,
      optionalTags: optionalTags ?? this.optionalTags,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      containsGluten: containsGluten ?? this.containsGluten,
      containsLactose: containsLactose ?? this.containsLactose,
      isVegan: isVegan ?? this.isVegan,
      isChildFriendly: isChildFriendly ?? this.isChildFriendly,
      isLowGlycemic: isLowGlycemic ?? this.isLowGlycemic,
      isLowSodium: isLowSodium ?? this.isLowSodium,
      cleanLabelBadges: cleanLabelBadges ?? this.cleanLabelBadges,
      mealSlots: mealSlots ?? this.mealSlots,
      chefTip: chefTip ?? this.chefTip,
      imageAsset: clearImageAsset ? null : (imageAsset ?? this.imageAsset),
      localImagePath:
          clearLocalImagePath ? null : (localImagePath ?? this.localImagePath),
      imageUrl: imageUrl ?? this.imageUrl,
      photoCredit: photoCredit ?? this.photoCredit,
      videoUrl: clearVideoUrl ? null : (videoUrl ?? this.videoUrl),
      sourceReference: sourceReference ?? this.sourceReference,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toCustomDbMap(int createdAt) {
    final payload = {
      'regionId': regionId,
      'originCity': originCity,
      'portionGram': portionGram,
      'imageAsset': imageAsset,
      'localImagePath': localImagePath,
      'imageUrl': imageUrl,
      'photoCredit': photoCredit,
      'videoUrl': videoUrl,
      'sourceReference': sourceReference,
      'fiberGrams': fiberGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'baseHealthScore': baseHealthScore,
      'difficulty': difficulty.name,
      'cookingMethod': cookingMethod.code,
      'requiredTags': requiredTags,
      'optionalTags': optionalTags,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
      'steps': steps,
      'containsGluten': containsGluten,
      'containsLactose': containsLactose,
      'isVegan': isVegan,
      'isChildFriendly': isChildFriendly,
      'isLowGlycemic': isLowGlycemic,
      'isLowSodium': isLowSodium,
      'cleanLabelBadges': cleanLabelBadges,
      'mealSlots': mealSlots.map((e) => e.dbCode).toList(),
      'chefTip': chefTip,
    };

    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'emoji': emoji,
      'category': category,
      'prep_minutes': prepMinutes,
      'cook_minutes': cookMinutes,
      'servings': defaultServings,
      'calories': calories,
      'protein_grams': proteinGrams,
      'payload_json': jsonEncode(payload),
      'created_at': createdAt,
    };
  }

  factory KilerRecipe.fromCustomDbMap(Map<String, dynamic> row) {
    Map<String, dynamic> payload = {};
    final rawPayload = row['payload_json'] as String?;
    if (rawPayload != null && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        payload = {};
      }
    }

    final rawIngredients = (payload['ingredients'] as List<dynamic>?) ?? const [];
    final parsedIngredients = rawIngredients
        .whereType<Map<String, dynamic>>()
        .map(RecipeIngredient.fromMap)
        .toList();

    final rawSlots = (payload['mealSlots'] as List<dynamic>?) ?? const [];
    final parsedSlots = rawSlots
        .map((e) => MealSlot.fromDb(e?.toString()))
        .toList();

    return KilerRecipe(
      id: (row['id'] as String?) ?? 'custom_recipe',
      title: (row['title'] as String?) ?? 'Özel Tarif',
      subtitle: (row['subtitle'] as String?) ?? 'Ev yapımı özel tarif',
      emoji: (row['emoji'] as String?) ?? '🍲',
      category: (row['category'] as String?) ?? RecipeCategoryRegistry.vegOliveOil,
      regionId: (payload['regionId'] as String?) ?? TurkishRegionRegistry.tumTurkiye,
      originCity: (payload['originCity'] as String?) ?? 'Ev Mutfağı',
      prepMinutes: (row['prep_minutes'] as int?) ?? 15,
      cookMinutes: (row['cook_minutes'] as int?) ?? 15,
      defaultServings: (row['servings'] as int?) ?? 2,
      portionGram: (payload['portionGram'] as int?) ?? 250,
      calories: (row['calories'] as int?) ?? 280,
      proteinGrams: (row['protein_grams'] as int?) ?? 12,
      fiberGrams: (payload['fiberGrams'] as int?) ?? 5,
      carbsGrams: (payload['carbsGrams'] as int?) ?? 22,
      fatGrams: (payload['fatGrams'] as int?) ?? 10,
      baseHealthScore: (payload['baseHealthScore'] as int?) ?? 94,
      difficulty: RecipeDifficulty.fromName(payload['difficulty'] as String?),
      cookingMethod: CookingMethod.fromCode(payload['cookingMethod'] as String?),
      requiredTags: ((payload['requiredTags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      optionalTags: ((payload['optionalTags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      ingredients: parsedIngredients,
      steps: ((payload['steps'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      containsGluten: (payload['containsGluten'] as bool?) ?? false,
      containsLactose: (payload['containsLactose'] as bool?) ?? false,
      isVegan: (payload['isVegan'] as bool?) ?? false,
      isChildFriendly: (payload['isChildFriendly'] as bool?) ?? true,
      isLowGlycemic: (payload['isLowGlycemic'] as bool?) ?? true,
      isLowSodium: (payload['isLowSodium'] as bool?) ?? true,
      cleanLabelBadges: ((payload['cleanLabelBadges'] as List<dynamic>?) ??
              const ['Özel Ev Tarifi', 'Katkısız'])
          .map((e) => e.toString())
          .toList(),
      mealSlots: parsedSlots.isEmpty ? const [MealSlot.mainCourse] : parsedSlots,
      chefTip: (payload['chefTip'] as String?) ??
          'Taze malzemelerle kısık ateşte pişirerek besin değerini koruyun.',
      imageAsset: payload['imageAsset'] as String?,
      localImagePath: payload['localImagePath'] as String?,
      imageUrl: payload['imageUrl'] as String?,
      photoCredit: payload['photoCredit'] as String?,
      videoUrl: payload['videoUrl'] as String?,
      sourceReference:
          (payload['sourceReference'] as String?) ?? 'Özel Ev Tarifi',
      isCustom: true,
    );
  }
}

class EvaluatedRecipeMatch {
  final KilerRecipe recipe;
  final List<String> matchedRequiredTags;
  final List<String> missingRequiredTags;
  final List<String> matchedOptionalTags;
  final List<PantryItem> expiringIngredientsUsed;
  final List<PantryItem> longWaitingIngredientsUsed;
  final int combinedHealthScore;
  final List<String> profileWarnings;
  final bool isFavorite;
  final int cookCount;

  const EvaluatedRecipeMatch({
    required this.recipe,
    required this.matchedRequiredTags,
    required this.missingRequiredTags,
    required this.matchedOptionalTags,
    required this.expiringIngredientsUsed,
    this.longWaitingIngredientsUsed = const [],
    required this.combinedHealthScore,
    required this.profileWarnings,
    this.isFavorite = false,
    this.cookCount = 0,
  });

  bool get isReadyToCook => missingRequiredTags.isEmpty;
  bool get isAlmostReady =>
      missingRequiredTags.isNotEmpty && missingRequiredTags.length <= 2;
  bool get rescuesStagnantItems => longWaitingIngredientsUsed.isNotEmpty;
  bool get preventsFoodWaste =>
      expiringIngredientsUsed.isNotEmpty || longWaitingIngredientsUsed.isNotEmpty;
  bool get isProfileSafe => profileWarnings.isEmpty;

  double get matchRatio {
    if (recipe.requiredTags.isEmpty) return 1.0;
    return matchedRequiredTags.length / recipe.requiredTags.length;
  }

  int get matchPercent => (matchRatio * 100).round();

  static final Map<String, String? Function(KilerRecipe recipe, String name)>
      _restrictionRules = {
    'GLUTEN': (r, name) => r.containsGluten ? '$name: Gluten içerir' : null,
    'LACTOSE': (r, name) =>
        r.containsLactose ? '$name: Süt/Laktoz içerir' : null,
    'VEGAN': (r, name) => !r.isVegan ? '$name: Hayvansal gıda içerir' : null,
    'HIGH_SUGAR': (r, name) =>
        !r.isLowGlycemic ? '$name: Yüksek glisemik karbonhidrat içerir' : null,
    'HIGH_SODIUM': (r, name) =>
        !r.isLowSodium ? '$name: Tuz/Sodyum hassasiyeti uyarısı' : null,
  };

  /// Checks active FamilyProfile restrictions against recipe attributes via OCP table.
  static List<String> evaluateProfileWarnings(
    KilerRecipe recipe,
    FamilyProfile? profile,
  ) {
    if (profile == null) return const [];
    final List<String> warnings = [];

    for (final r in profile.restrictions) {
      final evaluator = _restrictionRules[r];
      if (evaluator == null) continue;
      final warning = evaluator(recipe, profile.profileName);
      if (warning != null) {
        warnings.add(warning);
      }
    }
    return warnings;
  }
}

class MealPlanEntry {
  final int? id;
  final String planDate;
  final MealSlot mealSlot;
  final String recipeId;
  final int servings;
  final bool isCooked;
  final int addedAt;

  const MealPlanEntry({
    this.id,
    required this.planDate,
    required this.mealSlot,
    required this.recipeId,
    this.servings = 2,
    this.isCooked = false,
    required this.addedAt,
  });

  MealPlanEntry copyWith({
    int? id,
    String? planDate,
    MealSlot? mealSlot,
    String? recipeId,
    int? servings,
    bool? isCooked,
    int? addedAt,
  }) {
    return MealPlanEntry(
      id: id ?? this.id,
      planDate: planDate ?? this.planDate,
      mealSlot: mealSlot ?? this.mealSlot,
      recipeId: recipeId ?? this.recipeId,
      servings: servings ?? this.servings,
      isCooked: isCooked ?? this.isCooked,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_date': planDate,
        'meal_slot': mealSlot.dbCode,
        'recipe_id': recipeId,
        'servings': servings,
        'is_cooked': isCooked ? 1 : 0,
        'added_at': addedAt,
      };

  factory MealPlanEntry.fromMap(Map<String, dynamic> map) {
    return MealPlanEntry(
      id: map['id'] as int?,
      planDate: (map['plan_date'] as String?) ?? '',
      mealSlot: MealSlot.fromDb(map['meal_slot'] as String?),
      recipeId: (map['recipe_id'] as String?) ?? '',
      servings: (map['servings'] as int?) ?? 2,
      isCooked: ((map['is_cooked'] as int?) ?? 0) == 1,
      addedAt: (map['added_at'] as int?) ?? 0,
    );
  }
}

class MealCookLog {
  final int? id;
  final String recipeId;
  final String recipeTitle;
  final int servings;
  final int cookedAt;

  const MealCookLog({
    this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.servings,
    required this.cookedAt,
  });

  factory MealCookLog.fromMap(Map<String, dynamic> map) {
    return MealCookLog(
      id: map['id'] as int?,
      recipeId: (map['recipe_id'] as String?) ?? '',
      recipeTitle: (map['recipe_title'] as String?) ?? '',
      servings: (map['servings'] as int?) ?? 2,
      cookedAt: (map['cooked_at'] as int?) ?? 0,
    );
  }
}

class PlannedShoppingGap {
  final String tag;
  final String displayName;
  final String emoji;
  final String category;
  final int neededMealCount;
  final List<String> recipeTitles;
  final bool isLowStock;

  const PlannedShoppingGap({
    required this.tag,
    required this.displayName,
    required this.emoji,
    required this.category,
    required this.neededMealCount,
    required this.recipeTitles,
    this.isLowStock = false,
  });
}

class DailyNutritionSummary {
  final int totalCalories;
  final int totalProtein;
  final int totalFiber;
  final int averageCleanScore;
  final int plannedCount;
  final int cookedCount;
  final double readyInPantryRatio;

  const DailyNutritionSummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFiber,
    required this.averageCleanScore,
    required this.plannedCount,
    required this.cookedCount,
    required this.readyInPantryRatio,
  });

  static const DailyNutritionSummary empty = DailyNutritionSummary(
    totalCalories: 0,
    totalProtein: 0,
    totalFiber: 0,
    averageCleanScore: 0,
    plannedCount: 0,
    cookedCount: 0,
    readyInPantryRatio: 0,
  );
}

class MealDateUtils {
  static const List<String> _shortWeekdays = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static const List<String> _fullWeekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const List<String> _shortMonths = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  static DateTime startOfWeekMonday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static String toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime fromIsoDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  static List<DateTime> daysOfWeek(DateTime monday) {
    final base = startOfWeekMonday(monday);
    return List<DateTime>.generate(7, (i) => base.add(Duration(days: i)));
  }

  static String weekdayShortLabel(DateTime date) =>
      _shortWeekdays[(date.weekday - 1).clamp(0, 6)];

  static String weekdayFullLabel(DateTime date) =>
      _fullWeekdays[(date.weekday - 1).clamp(0, 6)];

  static String shortDayMonth(DateTime date) =>
      '${date.day} ${_shortMonths[(date.month - 1).clamp(0, 11)]}';

  static String weekRangeLabel(DateTime monday) {
    final start = startOfWeekMonday(monday);
    final end = start.add(const Duration(days: 6));
    return '${shortDayMonth(start)} – ${shortDayMonth(end)}';
  }
}

enum SlotResolutionType {
  cookedPlanned('COOKED_PLANNED', 'Planlı Yemek Pişirildi'),
  ateFromPantry('ATE_FROM_PANTRY', 'Kilerden Tüketildi'),
  skippedOutside('SKIPPED_OUTSIDE', 'Dışarıda / Tüketilmedi'),
  snoozedMissingAlert('SNOOZED_MISSING_ALERT', 'Sonraya Bırakıldı');

  final String dbCode;
  final String label;
  const SlotResolutionType(this.dbCode, this.label);

  static SlotResolutionType fromDb(String? code) {
    for (final val in SlotResolutionType.values) {
      if (val.dbCode == code || val.name == code) return val;
    }
    return SlotResolutionType.skippedOutside;
  }
}

/// Persistence record of user responses to planned or empty meal slot prompts.
class SlotCheckInRecord {
  final int? id;
  final String planDate;
  final MealSlot mealSlot;
  final SlotResolutionType resolutionType;
  final String? note;
  final int resolvedAt;

  const SlotCheckInRecord({
    this.id,
    required this.planDate,
    required this.mealSlot,
    required this.resolutionType,
    this.note,
    required this.resolvedAt,
  });

  String get slotKey => '$planDate|${mealSlot.dbCode}';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_date': planDate,
        'meal_slot': mealSlot.dbCode,
        'resolution_type': resolutionType.dbCode,
        'note': note,
        'resolved_at': resolvedAt,
      };

  factory SlotCheckInRecord.fromMap(Map<String, dynamic> map) {
    return SlotCheckInRecord(
      id: map['id'] as int?,
      planDate: (map['plan_date'] as String?) ?? '',
      mealSlot: MealSlot.fromDb(map['meal_slot'] as String?),
      resolutionType:
          SlotResolutionType.fromDb(map['resolution_type'] as String?),
      note: map['note'] as String?,
      resolvedAt: (map['resolved_at'] as int?) ?? 0,
    );
  }
}

/// Custom user-captured real food photo linked to a catalog/custom recipe.
class RecipePhotoOverride {
  final String recipeId;
  final String localPath;
  final int updatedAt;

  const RecipePhotoOverride({
    required this.recipeId,
    required this.localPath,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'recipe_id': recipeId,
        'local_path': localPath,
        'updated_at': updatedAt,
      };

  factory RecipePhotoOverride.fromMap(Map<String, dynamic> map) {
    return RecipePhotoOverride(
      recipeId: (map['recipe_id'] as String?) ?? '',
      localPath: (map['local_path'] as String?) ?? '',
      updatedAt: (map['updated_at'] as int?) ?? 0,
    );
  }
}

enum KitchenPromptType {
  todayMissingIngredients,
  plannedMealCookCheck,
  unplannedSlotPantryCheck,
}

/// Actionable daily assistant prompt keeping meal calendar and pantry synchronized.
class KitchenDailyPrompt {
  final String id;
  final KitchenPromptType type;
  final String planDate;
  final MealSlot mealSlot;
  final String title;
  final String subtitle;
  final MealPlanEntry? plannedEntry;
  final KilerRecipe? recipe;
  final List<String> missingTags;
  final List<String> lowStockTags;
  final List<PantryItem> suggestedPantryItems;
  final bool isTomorrowPreview;

  const KitchenDailyPrompt({
    required this.id,
    required this.type,
    required this.planDate,
    required this.mealSlot,
    required this.title,
    required this.subtitle,
    this.plannedEntry,
    this.recipe,
    this.missingTags = const [],
    this.lowStockTags = const [],
    this.suggestedPantryItems = const [],
    this.isTomorrowPreview = false,
  });
}

class MealModuleState {
  final YemekModuleMode mode;
  final RecipeFilterTab selectedFilter;
  final String? selectedCategory;
  final String? selectedRegion;
  final String searchQuery;
  final FamilyProfile? activeProfile;
  final Set<String> favoriteIds;
  final List<KilerRecipe> customRecipes;
  final Map<String, int> cookCounts;
  final String currentWeekMondayIso;
  final String selectedDateIso;
  final List<MealPlanEntry> weekEntries;
  final MealPlanPreset selectedPreset;
  final int planServings;
  final bool showFullWeekOverview;
  final List<EvaluatedRecipeMatch> evaluatedMatches;
  final Map<String, KilerRecipe> recipeById;
  final List<PlannedShoppingGap> weeklyShoppingGaps;
  final Map<String, SlotCheckInRecord> slotCheckIns;
  final Map<String, String> recipePhotoOverrides;
  final List<KitchenDailyPrompt> activePrompts;
  final List<EvaluatedRecipeMatch> wasteRescueMatches;
  final bool isLoading;
  final String? errorMessage;

  const MealModuleState({
    this.mode = YemekModuleMode.explore,
    this.selectedFilter = RecipeFilterTab.all,
    this.selectedCategory,
    this.selectedRegion,
    this.searchQuery = '',
    this.activeProfile,
    this.favoriteIds = const {},
    this.customRecipes = const [],
    this.cookCounts = const {},
    required this.currentWeekMondayIso,
    required this.selectedDateIso,
    this.weekEntries = const [],
    this.selectedPreset = MealPlanPreset.zeroWasteSmart,
    this.planServings = 2,
    this.showFullWeekOverview = false,
    this.evaluatedMatches = const [],
    this.recipeById = const {},
    this.weeklyShoppingGaps = const [],
    this.slotCheckIns = const {},
    this.recipePhotoOverrides = const {},
    this.activePrompts = const [],
    this.wasteRescueMatches = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  factory MealModuleState.initial({DateTime? now}) {
    final current = now ?? DateTime.now();
    final monday = MealDateUtils.startOfWeekMonday(current);
    return MealModuleState(
      currentWeekMondayIso: MealDateUtils.toIsoDate(monday),
      selectedDateIso: MealDateUtils.toIsoDate(current),
    );
  }

  MealModuleState copyWith({
    YemekModuleMode? mode,
    RecipeFilterTab? selectedFilter,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    String? selectedRegion,
    bool clearSelectedRegion = false,
    String? searchQuery,
    FamilyProfile? activeProfile,
    bool clearActiveProfile = false,
    Set<String>? favoriteIds,
    List<KilerRecipe>? customRecipes,
    Map<String, int>? cookCounts,
    String? currentWeekMondayIso,
    String? selectedDateIso,
    List<MealPlanEntry>? weekEntries,
    MealPlanPreset? selectedPreset,
    int? planServings,
    bool? showFullWeekOverview,
    List<EvaluatedRecipeMatch>? evaluatedMatches,
    Map<String, KilerRecipe>? recipeById,
    List<PlannedShoppingGap>? weeklyShoppingGaps,
    Map<String, SlotCheckInRecord>? slotCheckIns,
    Map<String, String>? recipePhotoOverrides,
    List<KitchenDailyPrompt>? activePrompts,
    List<EvaluatedRecipeMatch>? wasteRescueMatches,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return MealModuleState(
      mode: mode ?? this.mode,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedRegion: clearSelectedRegion
          ? null
          : (selectedRegion ?? this.selectedRegion),
      searchQuery: searchQuery ?? this.searchQuery,
      activeProfile:
          clearActiveProfile ? null : (activeProfile ?? this.activeProfile),
      favoriteIds: favoriteIds ?? this.favoriteIds,
      customRecipes: customRecipes ?? this.customRecipes,
      cookCounts: cookCounts ?? this.cookCounts,
      currentWeekMondayIso: currentWeekMondayIso ?? this.currentWeekMondayIso,
      selectedDateIso: selectedDateIso ?? this.selectedDateIso,
      weekEntries: weekEntries ?? this.weekEntries,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      planServings: planServings ?? this.planServings,
      showFullWeekOverview: showFullWeekOverview ?? this.showFullWeekOverview,
      evaluatedMatches: evaluatedMatches ?? this.evaluatedMatches,
      recipeById: recipeById ?? this.recipeById,
      weeklyShoppingGaps: weeklyShoppingGaps ?? this.weeklyShoppingGaps,
      slotCheckIns: slotCheckIns ?? this.slotCheckIns,
      recipePhotoOverrides: recipePhotoOverrides ?? this.recipePhotoOverrides,
      activePrompts: activePrompts ?? this.activePrompts,
      wasteRescueMatches: wasteRescueMatches ?? this.wasteRescueMatches,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<MealPlanEntry> entriesForDateAndSlot(String dateIso, MealSlot slot) {
    return weekEntries
        .where((e) => e.planDate == dateIso && e.mealSlot == slot)
        .toList();
  }

  int entriesCountForDate(String dateIso) =>
      weekEntries.where((e) => e.planDate == dateIso).length;

  DailyNutritionSummary dailySummaryFor(
    String dateIso,
    Set<String> pantryTags,
  ) {
    final dayEntries =
        weekEntries.where((e) => e.planDate == dateIso).toList();
    if (dayEntries.isEmpty) return DailyNutritionSummary.empty;

    int cal = 0;
    int prot = 0;
    int fiber = 0;
    int scoreSum = 0;
    int scoreCount = 0;
    int cooked = 0;
    int readyCount = 0;

    for (final entry in dayEntries) {
      if (entry.isCooked) cooked++;
      final recipe = recipeById[entry.recipeId];
      if (recipe == null) continue;
      cal += recipe.calories;
      prot += recipe.proteinGrams;
      fiber += recipe.fiberGrams;
      scoreSum += recipe.baseHealthScore;
      scoreCount++;
      final allReqInPantry =
          recipe.requiredTags.every((t) => pantryTags.contains(t));
      if (allReqInPantry) readyCount++;
    }

    return DailyNutritionSummary(
      totalCalories: cal,
      totalProtein: prot,
      totalFiber: fiber,
      averageCleanScore: scoreCount == 0 ? 0 : (scoreSum / scoreCount).round(),
      plannedCount: dayEntries.length,
      cookedCount: cooked,
      readyInPantryRatio: readyCount / dayEntries.length,
    );
  }

  int get readyNowCount =>
      evaluatedMatches.where((m) => m.isReadyToCook).length;

  int get wasteSaverCount =>
      evaluatedMatches.where((m) => m.preventsFoodWaste).length;
}
