import 'package:flutter/material.dart';

enum StorageZone {
  fridge('FRIDGE', 'Buzdolabı', '❄️', Icons.kitchen_rounded),
  pantry('PANTRY', 'Kiler & Erzak', '🏺', Icons.inventory_2_rounded),
  freezer('FREEZER', 'Dondurucu', '🧊', Icons.ac_unit_rounded);

  final String dbCode;
  final String label;
  final String emoji;
  final IconData icon;

  const StorageZone(this.dbCode, this.label, this.emoji, this.icon);

  static StorageZone fromDb(String? code) {
    for (final z in StorageZone.values) {
      if (z.dbCode == code) return z;
    }
    return StorageZone.fridge;
  }
}

enum QuantityLevel {
  full('FULL', 'Tam Dolu', 1.0),
  half('HALF', 'Yarım', 0.55),
  low('LOW', 'Az Kaldı', 0.22);

  final String dbCode;
  final String label;
  final double fillRatio;

  const QuantityLevel(this.dbCode, this.label, this.fillRatio);

  static QuantityLevel fromDb(String? code) {
    for (final q in QuantityLevel.values) {
      if (q.dbCode == code) return q;
    }
    return QuantityLevel.full;
  }

  QuantityLevel get nextStepDown {
    switch (this) {
      case QuantityLevel.full:
        return QuantityLevel.half;
      case QuantityLevel.half:
        return QuantityLevel.low;
      case QuantityLevel.low:
        return QuantityLevel.low;
    }
  }
}

class PantryItem {
  final int? id;
  final String? barcode;
  final String name;
  final String normalizedTag;
  final String brand;
  final String category;
  final StorageZone storageZone;
  final QuantityLevel quantityLevel;
  final String unitLabel;
  final int healthScore;
  final int addedAt;
  final int expiresAt;

  const PantryItem({
    this.id,
    this.barcode,
    required this.name,
    required this.normalizedTag,
    required this.brand,
    required this.category,
    required this.storageZone,
    required this.quantityLevel,
    required this.unitLabel,
    required this.healthScore,
    required this.addedAt,
    required this.expiresAt,
  });

  int get daysRemaining {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = expiresAt - nowMs;
    return (diffMs / 86400000).ceil();
  }

  int get daysInPantry {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = nowMs - addedAt;
    if (diffMs <= 0) return 0;
    return diffMs ~/ 86400000;
  }

  double get shelfLifeElapsedRatio {
    final totalSpan = expiresAt - addedAt;
    if (totalSpan <= 0) return 1.0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - addedAt;
    if (elapsed <= 0) return 0.0;
    return (elapsed / totalSpan).clamp(0.0, 2.0);
  }

  bool get isExpired => daysRemaining < 0;
  bool get isExpiringSoon => daysRemaining >= 0 && daysRemaining <= 3;

  /// Detects stagnant products waiting long enough to risk spoilage or clutter.
  bool get isLongWaiting {
    if (isExpired || isExpiringSoon) return false;
    final inDays = daysInPantry;
    if (storageZone == StorageZone.fridge) {
      return inDays >= 5;
    }
    return (inDays >= 14 && shelfLifeElapsedRatio >= 0.55) || inDays >= 21;
  }

  bool get needsWasteRescue => isExpired || isExpiringSoon || isLongWaiting;

  int get rescuePriorityScore {
    if (isExpired) return 100;
    if (isExpiringSoon) {
      return (95 - (daysRemaining * 5)).clamp(80, 95);
    }
    if (isLongWaiting) {
      return 50 + daysInPantry.clamp(0, 30);
    }
    return 0;
  }

  String get waitingReasonLabel {
    if (isExpired) {
      return 'Tüketim süresi geçti (${daysRemaining.abs()}g) — hemen kontrol';
    }
    if (daysRemaining == 0) return 'Bugün tüketilmeli';
    if (isExpiringSoon) return 'Son $daysRemaining gün — bozulma riski';
    if (isLongWaiting) {
      return '$daysInPantry gündür dolapta bekliyor — değerlendirin';
    }
    return freshnessLabel;
  }

  String get freshnessLabel {
    final days = daysRemaining;
    if (days < 0) return 'Süresi Geçti (${days.abs()}g)';
    if (days == 0) return 'Bugün Tüketilmeli!';
    if (days <= 3) return 'Son $days Gün (Öncelikli)';
    if (days > 45) return '${(days / 30).round()} Ay Taze';
    return '$days Gün Taze';
  }

  PantryItem copyWith({
    int? id,
    String? barcode,
    String? name,
    String? normalizedTag,
    String? brand,
    String? category,
    StorageZone? storageZone,
    QuantityLevel? quantityLevel,
    String? unitLabel,
    int? healthScore,
    int? addedAt,
    int? expiresAt,
  }) {
    return PantryItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      normalizedTag: normalizedTag ?? this.normalizedTag,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      storageZone: storageZone ?? this.storageZone,
      quantityLevel: quantityLevel ?? this.quantityLevel,
      unitLabel: unitLabel ?? this.unitLabel,
      healthScore: healthScore ?? this.healthScore,
      addedAt: addedAt ?? this.addedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'barcode': barcode,
        'name': name,
        'normalized_tag': normalizedTag,
        'brand': brand,
        'category': category,
        'storage_zone': storageZone.dbCode,
        'quantity_level': quantityLevel.dbCode,
        'unit_label': unitLabel,
        'health_score': healthScore,
        'added_at': addedAt,
        'expires_at': expiresAt,
      };

  factory PantryItem.fromMap(Map<String, dynamic> map) {
    return PantryItem(
      id: map['id'] as int?,
      barcode: map['barcode'] as String?,
      name: (map['name'] as String?) ?? 'Ürün',
      normalizedTag: (map['normalized_tag'] as String?) ?? 'genel',
      brand: (map['brand'] as String?) ?? 'Mutfak',
      category: (map['category'] as String?) ?? 'Genel Gıda',
      storageZone: StorageZone.fromDb(map['storage_zone'] as String?),
      quantityLevel: QuantityLevel.fromDb(map['quantity_level'] as String?),
      unitLabel: (map['unit_label'] as String?) ?? '1 Paket',
      healthScore: (map['health_score'] as int?) ?? 85,
      addedAt: (map['added_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      expiresAt: (map['expires_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class ShoppingListItem {
  final int? id;
  final String name;
  final String normalizedTag;
  final String category;
  final bool isChecked;
  final String sourceNote;
  final int addedAt;

  const ShoppingListItem({
    this.id,
    required this.name,
    required this.normalizedTag,
    required this.category,
    this.isChecked = false,
    this.sourceNote = 'Manuel eklendi',
    required this.addedAt,
  });

  ShoppingListItem copyWith({
    int? id,
    String? name,
    String? normalizedTag,
    String? category,
    bool? isChecked,
    String? sourceNote,
    int? addedAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedTag: normalizedTag ?? this.normalizedTag,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      sourceNote: sourceNote ?? this.sourceNote,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'normalized_tag': normalizedTag,
        'category': category,
        'is_checked': isChecked ? 1 : 0,
        'source_note': sourceNote,
        'added_at': addedAt,
      };

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Ürün',
      normalizedTag: (map['normalized_tag'] as String?) ?? 'genel',
      category: (map['category'] as String?) ?? 'Genel Gıda',
      isChecked: ((map['is_checked'] as int?) ?? 0) == 1,
      sourceNote: (map['source_note'] as String?) ?? '',
      addedAt: (map['added_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class QuickIngredientTemplate {
  final String tag;
  final String name;
  final String emoji;
  final String category;
  final StorageZone defaultZone;
  final int defaultShelfDays;
  final String defaultUnit;
  final int defaultHealthScore;
  final List<String> keywords;

  const QuickIngredientTemplate({
    required this.tag,
    required this.name,
    required this.emoji,
    required this.category,
    required this.defaultZone,
    required this.defaultShelfDays,
    required this.defaultUnit,
    this.defaultHealthScore = 95,
    this.keywords = const [],
  });
}

class QuickIngredientCatalog {
  static const List<String> categories = [
    'Sebze & Meyve',
    'Et, Tavuk & Yumurta',
    'Süt & Kahvaltılık',
    'Bakliyat & Tahıl',
    'Sos, Yağ & Baharat',
  ];

  static const List<QuickIngredientTemplate> templates = [
    // Sebze & Meyve
    QuickIngredientTemplate(
      tag: 'domates',
      name: 'Domates',
      emoji: '🍅',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 6,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['domates', 'salkim domates', 'cherry domates', 'pembe domates'],
    ),
    QuickIngredientTemplate(
      tag: 'biber',
      name: 'Sivri / Çarliston Biber',
      emoji: '🌶️',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 6,
      defaultUnit: '500 gr',
      defaultHealthScore: 97,
      keywords: ['biber', 'sivri biber', 'carliston', 'kapya biber', 'kirmizi biber', 'yesil biber'],
    ),
    QuickIngredientTemplate(
      tag: 'sogan',
      name: 'Kuru Soğan',
      emoji: '🧅',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 30,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['sogan', 'kuru sogan', 'mor sogan'],
    ),
    QuickIngredientTemplate(
      tag: 'sarimsak',
      name: 'Sarımsak',
      emoji: '🧄',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 45,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['sarimsak', 'taşköprü'],
    ),
    QuickIngredientTemplate(
      tag: 'patates',
      name: 'Patates',
      emoji: '🥔',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 25,
      defaultUnit: '2 Kg',
      defaultHealthScore: 92,
      keywords: ['patates', 'taze patates'],
    ),
    QuickIngredientTemplate(
      tag: 'patlican',
      name: 'Patlıcan',
      emoji: '🍆',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['patlican', 'kemer patlican', 'bostan patlican'],
    ),
    QuickIngredientTemplate(
      tag: 'kabak',
      name: 'Kabak',
      emoji: '🥒',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 6,
      defaultUnit: '1 Kg',
      defaultHealthScore: 97,
      keywords: ['kabak', 'sakiz kabak'],
    ),
    QuickIngredientTemplate(
      tag: 'havuc',
      name: 'Havuç',
      emoji: '🥕',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 12,
      defaultUnit: '500 gr',
      defaultHealthScore: 98,
      keywords: ['havuc', 'beypazari havuc'],
    ),
    QuickIngredientTemplate(
      tag: 'ispanak',
      name: 'Ispanak',
      emoji: '🥬',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 4,
      defaultUnit: '500 gr',
      defaultHealthScore: 99,
      keywords: ['ispanak', 'kuzu ispanak'],
    ),
    QuickIngredientTemplate(
      tag: 'mantar',
      name: 'Kültür Mantarı',
      emoji: '🍄',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 4,
      defaultUnit: '400 gr',
      defaultHealthScore: 96,
      keywords: ['mantar', 'kultur mantari', 'istiridye mantar'],
    ),
    QuickIngredientTemplate(
      tag: 'salatalik',
      name: 'Salatalık',
      emoji: '🥒',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Kg',
      defaultHealthScore: 97,
      keywords: ['salatalik', 'hiyar', 'cengelkoy'],
    ),
    QuickIngredientTemplate(
      tag: 'limon',
      name: 'Limon',
      emoji: '🍋',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '4 Adet',
      defaultHealthScore: 99,
      keywords: ['limon', 'yatak limon'],
    ),
    QuickIngredientTemplate(
      tag: 'maydanoz',
      name: 'Maydanoz & Dereotu',
      emoji: '🌿',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 4,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['maydanoz', 'dereotu', 'yesillik'],
    ),

    // Et, Tavuk & Yumurta
    QuickIngredientTemplate(
      tag: 'yumurta',
      name: 'Yumurta',
      emoji: '🥚',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 18,
      defaultUnit: '10 Adet',
      defaultHealthScore: 96,
      keywords: ['yumurta', 'gezen tavuk yumurta', 'organik yumurta'],
    ),
    QuickIngredientTemplate(
      tag: 'tavuk',
      name: 'Tavuk Göğsü / But',
      emoji: '🍗',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 3,
      defaultUnit: '500 gr',
      defaultHealthScore: 92,
      keywords: ['tavuk', 'pilic', 'bonfile', 'tavuk gogsu', 'baget', 'incik'],
    ),
    QuickIngredientTemplate(
      tag: 'kiyma',
      name: 'Dana Kıyma',
      emoji: '🥩',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 3,
      defaultUnit: '500 gr',
      defaultHealthScore: 92,
      keywords: ['kiyma', 'dana kiyma', 'kuzu kiyma'],
    ),
    QuickIngredientTemplate(
      tag: 'kusbasi_et',
      name: 'Dana Kuşbaşı Et',
      emoji: '🥩',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 3,
      defaultUnit: '500 gr',
      defaultHealthScore: 94,
      keywords: ['kusbasi', 'dana et', 'antrikot', 'biftek'],
    ),
    QuickIngredientTemplate(
      tag: 'sucuk',
      name: 'Fermente Sucuk',
      emoji: '🌭',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '1 Kangal',
      defaultHealthScore: 68,
      keywords: ['sucuk', 'dana sucuk', 'kangal sucuk'],
    ),
    QuickIngredientTemplate(
      tag: 'balik',
      name: 'Taze Balık / Somon',
      emoji: '🐟',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 2,
      defaultUnit: '2 Porsiyon',
      defaultHealthScore: 98,
      keywords: ['balik', 'somon', 'cipura', 'levrek', 'hamsi', 'ton baligi'],
    ),

    // Süt & Kahvaltılık
    QuickIngredientTemplate(
      tag: 'sut',
      name: 'Süt',
      emoji: '🥛',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 7,
      defaultUnit: '1 Litre',
      defaultHealthScore: 90,
      keywords: ['sut', 'gunluk sut', 'tam yagli sut', 'laktozsuz sut'],
    ),
    QuickIngredientTemplate(
      tag: 'yogurt',
      name: 'Yoğurt',
      emoji: '🥣',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 10,
      defaultUnit: '1 Kg',
      defaultHealthScore: 94,
      keywords: ['yogurt', 'suzme yogurt', 'ev yogurdu', 'tava yogurt'],
    ),
    QuickIngredientTemplate(
      tag: 'peynir',
      name: 'Beyaz Peynir / Ezine',
      emoji: '🧀',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '500 gr',
      defaultHealthScore: 91,
      keywords: ['peynir', 'beyaz peynir', 'ezine', 'lor peyniri', 'tulum'],
    ),
    QuickIngredientTemplate(
      tag: 'kasar',
      name: 'Kaşar Peyniri',
      emoji: '🧀',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 20,
      defaultUnit: '400 gr',
      defaultHealthScore: 88,
      keywords: ['kasar', 'taze kasar', 'eski kasar', 'mozzarella'],
    ),
    QuickIngredientTemplate(
      tag: 'tereyagi',
      name: 'Tereyağı',
      emoji: '🧈',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 30,
      defaultUnit: '250 gr',
      defaultHealthScore: 92,
      keywords: ['tereyagi', 'tereyag', 'yayik tereyagi'],
    ),
    QuickIngredientTemplate(
      tag: 'krema',
      name: 'Sıvı Krema',
      emoji: '🥛',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 10,
      defaultUnit: '200 ml',
      defaultHealthScore: 82,
      keywords: ['krema', 'yemek kremasi', 'sivi krema'],
    ),

    // Bakliyat & Tahıl
    QuickIngredientTemplate(
      tag: 'makarna',
      name: 'Makarna',
      emoji: '🍝',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Paket',
      defaultHealthScore: 86,
      keywords: ['makarna', 'spagetti', 'burgu', 'penne', 'eriste'],
    ),
    QuickIngredientTemplate(
      tag: 'pirinc',
      name: 'Pirinç (Baldo/Osmancık)',
      emoji: '🍚',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 88,
      keywords: ['pirinc', 'baldo', 'osmancik', 'basmati'],
    ),
    QuickIngredientTemplate(
      tag: 'bulgur',
      name: 'Pilavlık Bulgur',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 95,
      keywords: ['bulgur', 'pilavlik bulgur', 'koftelik bulgur', 'siyez bulgur'],
    ),
    QuickIngredientTemplate(
      tag: 'kirmizi_mercimek',
      name: 'Kırmızı Mercimek',
      emoji: '🫘',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['kirmizi mercimek', 'mercimek'],
    ),
    QuickIngredientTemplate(
      tag: 'yesil_mercimek',
      name: 'Yeşil Mercimek',
      emoji: '🫘',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 97,
      keywords: ['yesil mercimek'],
    ),
    QuickIngredientTemplate(
      tag: 'nohut',
      name: 'Nohut',
      emoji: '🫘',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['nohut', 'haslanmis nohut', 'kocbasi nohut'],
    ),
    QuickIngredientTemplate(
      tag: 'kuru_fasulye',
      name: 'Kuru Fasulye',
      emoji: '🫘',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['kuru fasulye', 'fasulye', 'dermason', 'ispir fasulye'],
    ),
    QuickIngredientTemplate(
      tag: 'un',
      name: 'Buğday / Tam Buğday Unu',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 120,
      defaultUnit: '1 Kg',
      defaultHealthScore: 86,
      keywords: ['un', 'bugday unu', 'tam bugday unu', 'siyez unu'],
    ),
    QuickIngredientTemplate(
      tag: 'yulaf',
      name: 'Yulaf Ezmesi',
      emoji: '🥣',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 150,
      defaultUnit: '500 gr',
      defaultHealthScore: 95,
      keywords: ['yulaf', 'yulaf ezmesi', 'granola'],
    ),

    // Sos, Yağ & Baharat
    QuickIngredientTemplate(
      tag: 'zeytinyagi',
      name: 'Sızma Zeytinyağı',
      emoji: '🫒',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '1 Litre',
      defaultHealthScore: 99,
      keywords: ['zeytinyagi', 'sizma zeytinyagi', 'riviera'],
    ),
    QuickIngredientTemplate(
      tag: 'aycicek_yagi',
      name: 'Ayçiçek Yağı',
      emoji: '🌻',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Litre',
      defaultHealthScore: 78,
      keywords: ['aycicek yagi', 'sivi yag'],
    ),
    QuickIngredientTemplate(
      tag: 'salca',
      name: 'Domates / Biber Salçası',
      emoji: '🥫',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 60,
      defaultUnit: '700 gr',
      defaultHealthScore: 91,
      keywords: ['salca', 'domates salcasi', 'biber salcasi'],
    ),
    QuickIngredientTemplate(
      tag: 'taze_fasulye',
      name: 'Taze Fasulye',
      emoji: '🫛',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '500 gr',
      defaultHealthScore: 98,
      keywords: ['taze fasulye', 'calı fasulye', 'ayse kadin'],
    ),
    QuickIngredientTemplate(
      tag: 'bezelye',
      name: 'Bezelye',
      emoji: '🫛',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.freezer,
      defaultShelfDays: 90,
      defaultUnit: '500 gr',
      defaultHealthScore: 95,
      keywords: ['bezelye', 'ic bezelye', 'garnitur'],
    ),
    QuickIngredientTemplate(
      tag: 'brokoli',
      name: 'Brokoli & Karnabahar',
      emoji: '🥦',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '500 gr',
      defaultHealthScore: 99,
      keywords: ['brokoli', 'karnabahar'],
    ),
    QuickIngredientTemplate(
      tag: 'elma',
      name: 'Elma',
      emoji: '🍎',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['elma', 'amasya elma', 'yesil elma'],
    ),
    QuickIngredientTemplate(
      tag: 'muz',
      name: 'Muz',
      emoji: '🍌',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 5,
      defaultUnit: '4 Adet',
      defaultHealthScore: 96,
      keywords: ['muz', 'anamur muz'],
    ),
    QuickIngredientTemplate(
      tag: 'zeytin',
      name: 'Siyah / Yeşil Zeytin',
      emoji: '🫒',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 45,
      defaultUnit: '500 gr',
      defaultHealthScore: 93,
      keywords: ['zeytin', 'siyah zeytin', 'yesil zeytin', 'gemlik'],
    ),
    QuickIngredientTemplate(
      tag: 'bal',
      name: 'Doğal Süzme Bal',
      emoji: '🍯',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 365,
      defaultUnit: '450 gr',
      defaultHealthScore: 92,
      keywords: ['bal', 'suzme bal', 'cicek bali', 'cam bali'],
    ),
    QuickIngredientTemplate(
      tag: 'ceviz',
      name: 'Ceviz İçi / Badem',
      emoji: '🌰',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 120,
      defaultUnit: '250 gr',
      defaultHealthScore: 98,
      keywords: ['ceviz', 'badem', 'findik', 'kuruyemis'],
    ),
    QuickIngredientTemplate(
      tag: 'ton_baligi',
      name: 'Zeytinyağlı Ton Balığı',
      emoji: '🥫',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '2 Kutu',
      defaultHealthScore: 89,
      keywords: ['ton baligi', 'konserve balik'],
    ),
    QuickIngredientTemplate(
      tag: 'dereotu',
      name: 'Taze Dereotu',
      emoji: '🌿',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['dereotu', 'taze dereotu'],
    ),
    QuickIngredientTemplate(
      tag: 'taze_nane',
      name: 'Taze Nane',
      emoji: '🌿',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['taze nane', 'nane'],
    ),
    QuickIngredientTemplate(
      tag: 'marul',
      name: 'Marul / Yeşillik',
      emoji: '🥬',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Adet',
      defaultHealthScore: 98,
      keywords: ['marul', 'kivircik', 'gobek marul', 'yedikule'],
    ),
    QuickIngredientTemplate(
      tag: 'semizotu',
      name: 'Semizotu',
      emoji: '🥬',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 4,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['semizotu', 'pirpirim'],
    ),
    QuickIngredientTemplate(
      tag: 'pirasa',
      name: 'Pırasa',
      emoji: '🥬',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 10,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['pirasa', 'taze pirasa'],
    ),
    QuickIngredientTemplate(
      tag: 'karnabahar',
      name: 'Karnabahar',
      emoji: '🥦',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 7,
      defaultUnit: '1 Orta Boy',
      defaultHealthScore: 98,
      keywords: ['karnabahar', 'taze karnabahar'],
    ),
    QuickIngredientTemplate(
      tag: 'kereviz',
      name: 'Kereviz',
      emoji: '🥗',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '2 Adet',
      defaultHealthScore: 98,
      keywords: ['kereviz', 'kok kereviz', 'sap kereviz'],
    ),
    QuickIngredientTemplate(
      tag: 'balkabagi',
      name: 'Bal Kabağı',
      emoji: '🎃',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 21,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['balkabagi', 'bal kabagi', 'kabak tatlisi'],
    ),
    QuickIngredientTemplate(
      tag: 'avokado',
      name: 'Avokado',
      emoji: '🥑',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 5,
      defaultUnit: '2 Adet',
      defaultHealthScore: 99,
      keywords: ['avokado', 'alanya avokado'],
    ),
    QuickIngredientTemplate(
      tag: 'portakal',
      name: 'Portakal',
      emoji: '🍊',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 14,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['portakal', 'finike portakal', 'sikmalik portakal'],
    ),
    QuickIngredientTemplate(
      tag: 'hindi',
      name: 'Hindi Göğüs / Kuşbaşı',
      emoji: '🦃',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 3,
      defaultUnit: '500 gr',
      defaultHealthScore: 95,
      keywords: ['hindi', 'hindi gogus', 'hindi bonfile', 'hindi kusbasi'],
    ),
    QuickIngredientTemplate(
      tag: 'lor_peyniri',
      name: 'Lor Peyniri',
      emoji: '🧀',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 7,
      defaultUnit: '400 gr',
      defaultHealthScore: 95,
      keywords: ['lor peyniri', 'lor', 'tuzsuz lor', 'cokelek'],
    ),
    QuickIngredientTemplate(
      tag: 'kefir',
      name: 'Doğal Kefir',
      emoji: '🥛',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 10,
      defaultUnit: '1 Litre',
      defaultHealthScore: 97,
      keywords: ['kefir', 'sade kefir', 'probiyotik kefir'],
    ),
    QuickIngredientTemplate(
      tag: 'tahin',
      name: 'Doğal Susam Tahini',
      emoji: '🫙',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '300 gr',
      defaultHealthScore: 96,
      keywords: ['tahin', 'susam tahini', 'cifte kavrulmus tahin'],
    ),
    QuickIngredientTemplate(
      tag: 'pekmez',
      name: 'Doğal Üzüm / Keçiboynuzu Pekmezi',
      emoji: '🍯',
      category: 'Süt & Kahvaltılık',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '400 gr',
      defaultHealthScore: 94,
      keywords: ['pekmez', 'uzum pekmezi', 'keciboynuzu pekmezi', 'dut pekmezi'],
    ),
    QuickIngredientTemplate(
      tag: 'hurma',
      name: 'Doğal Hurma',
      emoji: '🌴',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 120,
      defaultUnit: '300 gr',
      defaultHealthScore: 96,
      keywords: ['hurma', 'medine hurma', 'kudus hurma', 'yas hurma'],
    ),
    QuickIngredientTemplate(
      tag: 'kakao',
      name: 'Ham Kakao',
      emoji: '🍫',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 365,
      defaultUnit: '100 gr',
      defaultHealthScore: 95,
      keywords: ['kakao', 'ham kakao', 'sekersiz kakao'],
    ),
    QuickIngredientTemplate(
      tag: 'chia',
      name: 'Chia Tohumu',
      emoji: '🌱',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '200 gr',
      defaultHealthScore: 98,
      keywords: ['chia', 'chia tohumu'],
    ),
    QuickIngredientTemplate(
      tag: 'karabugday',
      name: 'Karabuğday (Greçka)',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '500 gr',
      defaultHealthScore: 97,
      keywords: ['karabugday', 'grecka', 'kara bugday'],
    ),
    QuickIngredientTemplate(
      tag: 'tam_bugday_unu',
      name: 'Tam Buğday / Siyez Unu',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 120,
      defaultUnit: '1 Kg',
      defaultHealthScore: 93,
      keywords: ['tam bugday unu', 'siyez unu', 'kepekli un'],
    ),
    QuickIngredientTemplate(
      tag: 'eriste',
      name: 'Ev Yapımı Erişte',
      emoji: '🍝',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '500 gr',
      defaultHealthScore: 91,
      keywords: ['eriste', 'ev eristesi', 'kesme eriste', 'yumurtali eriste'],
    ),
    QuickIngredientTemplate(
      tag: 'nar_eksisi',
      name: 'Doğal Nar Ekşisi (%100)',
      emoji: '🫐',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '250 ml',
      defaultHealthScore: 95,
      keywords: ['nar eksisi', 'gercek nar eksisi', 'dogal nar eksisi'],
    ),
    QuickIngredientTemplate(
      tag: 'enginar',
      name: 'Çanak Enginar',
      emoji: '🌿',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '4 Adet',
      defaultHealthScore: 99,
      keywords: ['enginar', 'canak enginar', 'urla enginar'],
    ),
    QuickIngredientTemplate(
      tag: 'karalahana',
      name: 'Karalahana & Pazı',
      emoji: '🥬',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Bağ',
      defaultHealthScore: 99,
      keywords: ['karalahana', 'kara lahana', 'pazi'],
    ),
    QuickIngredientTemplate(
      tag: 'bamya',
      name: 'Bamya',
      emoji: '🫛',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '500 gr',
      defaultHealthScore: 98,
      keywords: ['bamya', 'kuru bamya', 'taze bamya'],
    ),
    QuickIngredientTemplate(
      tag: 'asmalik_yaprak',
      name: 'Asma Yaprağı',
      emoji: '🍃',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '500 gr',
      defaultHealthScore: 95,
      keywords: ['asma yapragi', 'salamura yaprak', 'uzum yapragi'],
    ),
    QuickIngredientTemplate(
      tag: 'incir_kayisi',
      name: 'Kuru İncir & Gün Kurusu Kayısı',
      emoji: '🍑',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '300 gr',
      defaultHealthScore: 97,
      keywords: ['kuru incir', 'incir', 'kuru kayisi', 'gun kurusu', 'kayisi'],
    ),
    QuickIngredientTemplate(
      tag: 'misir_unu',
      name: 'Karadeniz Mısır Unu & Yarma',
      emoji: '🌽',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 150,
      defaultUnit: '500 gr',
      defaultHealthScore: 93,
      keywords: ['misir unu', 'misir yarmasi', 'kavrulmus misir unu'],
    ),
    QuickIngredientTemplate(
      tag: 'asurelik_bugday',
      name: 'Aşurelik / Keşkeklik Buğday',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['asurelik bugday', 'keskeklik bugday', 'dovme bugday', 'yarma bugday'],
    ),
    QuickIngredientTemplate(
      tag: 'ince_bulgur',
      name: 'Köftelik İnce Bulgur',
      emoji: '🌾',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 96,
      keywords: ['ince bulgur', 'simit bulgur', 'kisir bulguru'],
    ),
    QuickIngredientTemplate(
      tag: 'barbunya',
      name: 'Barbunya',
      emoji: '🫘',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 180,
      defaultUnit: '1 Kg',
      defaultHealthScore: 97,
      keywords: ['barbunya', 'taze barbunya', 'kuru barbunya'],
    ),
    QuickIngredientTemplate(
      tag: 'hamsi',
      name: 'Taze Karadeniz Hamsisi',
      emoji: '🐟',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 2,
      defaultUnit: '1 Kg',
      defaultHealthScore: 98,
      keywords: ['karadeniz hamsisi', 'taze hamsi', 'hamsi'],
    ),
    QuickIngredientTemplate(
      tag: 'kuzu_eti',
      name: 'Kuzu Kuşbaşı / Gerdan',
      emoji: '🥩',
      category: 'Et, Tavuk & Yumurta',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 3,
      defaultUnit: '500 gr',
      defaultHealthScore: 93,
      keywords: ['kuzu eti', 'kuzu kusbasi', 'kuzu gerdan', 'kuzu incik'],
    ),
    QuickIngredientTemplate(
      tag: 'sumak_isot',
      name: 'Sumak, İsot & Doğal Baharatlar',
      emoji: '🌶️',
      category: 'Sos, Yağ & Baharat',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 365,
      defaultUnit: '150 gr',
      defaultHealthScore: 98,
      keywords: ['sumak', 'isot', 'pul biber', 'kimyon', 'karabiber'],
    ),
    QuickIngredientTemplate(
      tag: 'tarhana',
      name: 'Ev Tarhanası',
      emoji: '🥣',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 240,
      defaultUnit: '500 gr',
      defaultHealthScore: 96,
      keywords: ['tarhana', 'ev tarhanasi', 'koy tarhanasi', 'toz tarhana'],
    ),
    QuickIngredientTemplate(
      tag: 'yufka',
      name: 'Günlük Yufka & Lavaş',
      emoji: '🫓',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '3 Adet',
      defaultHealthScore: 86,
      keywords: ['yufka', 'lavas', 'gunluk yufka', 'bazlama', 'sac yufkasi'],
    ),
    QuickIngredientTemplate(
      tag: 'yesil_sogan',
      name: 'Taze Yeşil Soğan',
      emoji: '🌱',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 5,
      defaultUnit: '1 Demet',
      defaultHealthScore: 98,
      keywords: ['yesil sogan', 'taze sogan'],
    ),
    QuickIngredientTemplate(
      tag: 'roka_tere',
      name: 'Roka, Tere & Reyhan',
      emoji: '🌿',
      category: 'Sebze & Meyve',
      defaultZone: StorageZone.fridge,
      defaultShelfDays: 4,
      defaultUnit: '1 Demet',
      defaultHealthScore: 99,
      keywords: ['taze roka', 'mor reyhan', 'feslegen', 'roka', 'tere'],
    ),
  ];

  static QuickIngredientTemplate? findByTag(String tag) {
    for (final tpl in templates) {
      if (tpl.tag == tag) return tpl;
    }
    return null;
  }

  static String displayNameForTag(String tag) {
    final tpl = findByTag(tag);
    if (tpl != null) return tpl.name;
    return tag.replaceAll('_', ' ');
  }
}

class IngredientNormalizer {
  /// Public ASCII-folded Turkish lowercase helper (zero cross-feature imports).
  static String asciiLower(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('\u0307', '')
        .trim();
  }

  /// Resolves a raw product name into a matched QuickIngredientTemplate or inferred metadata.
  static QuickIngredientTemplate resolveMetadata(String rawName, {int? healthScore}) {
    final clean = asciiLower(rawName);

    QuickIngredientTemplate? bestMatch;
    int bestScore = -1;

    for (final tpl in QuickIngredientCatalog.templates) {
      if (clean == tpl.tag) {
        return tpl;
      }
      for (final kw in tpl.keywords) {
        if (clean.contains(kw)) {
          final normalizedKw = kw.replaceAll(' ', '_');
          final int score = (kw.length * 10) +
              (normalizedKw == tpl.tag ? 5 : 0) +
              (clean == kw ? 100 : 0);
          if (score > bestScore) {
            bestScore = score;
            bestMatch = tpl;
          }
        }
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // Fallback inference by keywords
    if (clean.contains('dondurulmus') || clean.contains('buzluk')) {
      return QuickIngredientTemplate(
        tag: clean.replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        name: rawName.trim(),
        emoji: '🧊',
        category: 'Bakliyat & Tahıl',
        defaultZone: StorageZone.freezer,
        defaultShelfDays: 90,
        defaultUnit: '1 Paket',
        defaultHealthScore: healthScore ?? 85,
      );
    }

    if (clean.contains('peynir') || clean.contains('sut') || clean.contains('yogurt') || clean.contains('ayran')) {
      return QuickIngredientTemplate(
        tag: clean.replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        name: rawName.trim(),
        emoji: '🥛',
        category: 'Süt & Kahvaltılık',
        defaultZone: StorageZone.fridge,
        defaultShelfDays: 10,
        defaultUnit: '1 Paket',
        defaultHealthScore: healthScore ?? 88,
      );
    }

    return QuickIngredientTemplate(
      tag: clean.replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      name: rawName.trim(),
      emoji: '📦',
      category: 'Bakliyat & Tahıl',
      defaultZone: StorageZone.pantry,
      defaultShelfDays: 60,
      defaultUnit: '1 Paket',
      defaultHealthScore: healthScore ?? 85,
    );
  }
}

/// Unbarcoded shopping source channels common in Türkiye's daily grocery flow.
enum UnbarcodedSourceChannel {
  manavPazar('Manav & Pazar', '🥬', 'Taze sebze, meyve ve yeşillik', 'Manav / Pazar'),
  kasapKoy('Kasap & Köy', '🥩', 'Kıyma, kuşbaşı, kuzu, tavuk, köy yumurtası', 'Kasap / Köy'),
  balikci('Balıkçı', '🐟', 'Hamsi, somon, levrek ve taze deniz balıkları', 'Balıkçı'),
  aktarEvYapimi('Aktar & Ev Yapımı', '🌶️', 'Ev salçası, isot, tarhana, erişte ve bakliyat', 'Aktar / Ev Yapımı'),
  mandiraKahvalti('Mandıra & Süt', '🧀', 'Köy peyniri, yoğurt, tereyağı, zeytin, bal', 'Mandıra'),
  temelEvPaketi('Her Evde Olanlar', '🏡', 'Ev kilerindeki temel demirbaşları hızlıca seçin', 'Ev Kileri');

  final String label;
  final String emoji;
  final String subtitle;
  final String defaultBrand;

  const UnbarcodedSourceChannel(
    this.label,
    this.emoji,
    this.subtitle,
    this.defaultBrand,
  );
}

/// OCP registry mapping unbarcoded source channels to curated ingredient templates.
class MarketSourceRegistry {
  static const List<String> starterHomeTags = [
    'sogan',
    'sarimsak',
    'patates',
    'domates',
    'biber',
    'yumurta',
    'yogurt',
    'peynir',
    'tereyagi',
    'zeytinyagi',
    'salca',
    'sumak_isot',
    'un',
    'pirinc',
    'bulgur',
    'kirmizi_mercimek',
  ];

  static const Map<UnbarcodedSourceChannel, List<String>> _channelTagMap = {
    UnbarcodedSourceChannel.manavPazar: [
      'domates',
      'biber',
      'sogan',
      'yesil_sogan',
      'sarimsak',
      'patates',
      'patlican',
      'kabak',
      'havuc',
      'ispanak',
      'mantar',
      'salatalik',
      'limon',
      'maydanoz',
      'dereotu',
      'taze_nane',
      'roka_tere',
      'marul',
      'semizotu',
      'pirasa',
      'karnabahar',
      'kereviz',
      'balkabagi',
      'taze_fasulye',
      'bezelye',
      'brokoli',
      'enginar',
      'karalahana',
      'bamya',
      'elma',
      'muz',
      'avokado',
      'portakal',
      'hurma',
    ],
    UnbarcodedSourceChannel.kasapKoy: [
      'kiyma',
      'kusbasi_et',
      'kuzu_eti',
      'tavuk',
      'hindi',
      'yumurta',
      'sucuk',
    ],
    UnbarcodedSourceChannel.balikci: [
      'hamsi',
      'balik',
      'ton_baligi',
      'limon',
      'yesil_sogan',
      'roka_tere',
    ],
    UnbarcodedSourceChannel.aktarEvYapimi: [
      'salca',
      'sumak_isot',
      'tarhana',
      'eriste',
      'kirmizi_mercimek',
      'yesil_mercimek',
      'nohut',
      'kuru_fasulye',
      'barbunya',
      'bulgur',
      'ince_bulgur',
      'pirinc',
      'asurelik_bugday',
      'karabugday',
      'un',
      'tam_bugday_unu',
      'misir_unu',
      'yulaf',
      'makarna',
      'chia',
      'tahin',
      'pekmez',
      'bal',
      'ceviz',
      'incir_kayisi',
      'nar_eksisi',
      'zeytinyagi',
      'aycicek_yagi',
      'asmalik_yaprak',
      'kakao',
    ],
    UnbarcodedSourceChannel.mandiraKahvalti: [
      'peynir',
      'kasar',
      'lor_peyniri',
      'yogurt',
      'sut',
      'kefir',
      'tereyagi',
      'krema',
      'zeytin',
      'bal',
      'pekmez',
      'tahin',
      'yufka',
      'yumurta',
    ],
    UnbarcodedSourceChannel.temelEvPaketi: starterHomeTags,
  };

  static List<QuickIngredientTemplate> templatesForChannel(
    UnbarcodedSourceChannel channel,
  ) {
    final tags = _channelTagMap[channel] ?? const [];
    final List<QuickIngredientTemplate> list = [];
    for (final tag in tags) {
      final tpl = QuickIngredientCatalog.findByTag(tag);
      if (tpl != null) list.add(tpl);
    }
    return list;
  }

  static List<QuickIngredientTemplate> starterHomeTemplates() =>
      templatesForChannel(UnbarcodedSourceChannel.temelEvPaketi);
}

enum QuantityConsumptionAction {
  stepDown('Azaldı'),
  finished('Bitti (Alışverişe)');

  final String label;
  const QuantityConsumptionAction(this.label);
}

/// Editable draft entry before batch insertion into pantry_items.
class DraftPantryAddition {
  final String tag;
  final String name;
  final String emoji;
  final String category;
  final String brand;
  final String unitLabel;
  final StorageZone storageZone;
  final QuantityLevel quantityLevel;
  final int shelfDays;
  final int healthScore;
  final UnbarcodedSourceChannel? sourceChannel;

  const DraftPantryAddition({
    required this.tag,
    required this.name,
    required this.emoji,
    required this.category,
    required this.brand,
    required this.unitLabel,
    required this.storageZone,
    this.quantityLevel = QuantityLevel.full,
    required this.shelfDays,
    this.healthScore = 94,
    this.sourceChannel,
  });

  factory DraftPantryAddition.fromTemplate(
    QuickIngredientTemplate tpl, {
    StorageZone? overrideZone,
    UnbarcodedSourceChannel? sourceChannel,
    int? overrideShelfDays,
    QuantityLevel quantityLevel = QuantityLevel.full,
    String? customName,
    String? customUnit,
  }) {
    final zone = overrideZone ?? tpl.defaultZone;
    final days = overrideShelfDays ??
        (zone == StorageZone.freezer ? 90 : tpl.defaultShelfDays);
    return DraftPantryAddition(
      tag: tpl.tag,
      name: (customName == null || customName.trim().isEmpty)
          ? tpl.name
          : customName.trim(),
      emoji: tpl.emoji,
      category: tpl.category,
      brand: sourceChannel?.defaultBrand ?? 'Mutfak',
      unitLabel: (customUnit == null || customUnit.trim().isEmpty)
          ? tpl.defaultUnit
          : customUnit.trim(),
      storageZone: zone,
      quantityLevel: quantityLevel,
      shelfDays: days,
      healthScore: tpl.defaultHealthScore,
      sourceChannel: sourceChannel,
    );
  }

  DraftPantryAddition copyWith({
    String? tag,
    String? name,
    String? emoji,
    String? category,
    String? brand,
    String? unitLabel,
    StorageZone? storageZone,
    QuantityLevel? quantityLevel,
    int? shelfDays,
    int? healthScore,
    UnbarcodedSourceChannel? sourceChannel,
  }) {
    return DraftPantryAddition(
      tag: tag ?? this.tag,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      unitLabel: unitLabel ?? this.unitLabel,
      storageZone: storageZone ?? this.storageZone,
      quantityLevel: quantityLevel ?? this.quantityLevel,
      shelfDays: shelfDays ?? this.shelfDays,
      healthScore: healthScore ?? this.healthScore,
      sourceChannel: sourceChannel ?? this.sourceChannel,
    );
  }

  PantryItem toPantryItem({int? nowMs}) {
    final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final int safeDays = shelfDays <= 0 ? 3 : shelfDays;
    return PantryItem(
      barcode: null,
      name: name,
      normalizedTag: tag,
      brand: brand,
      category: category,
      storageZone: storageZone,
      quantityLevel: quantityLevel,
      unitLabel: unitLabel,
      healthScore: healthScore,
      addedAt: now,
      expiresAt: now + (safeDays * 86400000),
    );
  }
}

/// Parses free-text unbarcoded market/butcher/home entries into batch drafts.
class NaturalPantryInputParser {
  static final RegExp _splitRegex = RegExp(
    r'[\n,;]+|\s+ve\s+',
    caseSensitive: false,
  );
  static final RegExp _leadingHalfKiloRegex = RegExp(
    r'^yar[iı]m\s*(kilo(?:gram)?|kg|demet|ba[gğ]|paket|kavanoz)\s+',
    caseSensitive: false,
  );
  static final RegExp _leadingNumericUnitRegex = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*(kilo(?:gram)?|kg|gram|gr|g|litre|lt|l|ml|adet|tane|demet|ba[gğ]|paket|kutu|kavanoz|şişe|sise)\b\s*',
    caseSensitive: false,
  );
  static final RegExp _leadingCountOnlyRegex = RegExp(r'^(\d+)\s+');

  static List<DraftPantryAddition> parseBatch(
    String rawInput, {
    UnbarcodedSourceChannel? fallbackChannel,
    StorageZone? overrideZone,
  }) {
    if (rawInput.trim().isEmpty) return const [];

    final segments = rawInput
        .split(_splitRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final List<DraftPantryAddition> drafts = [];
    for (final segment in segments) {
      final parsed = _parseSingleSegment(
        segment,
        fallbackChannel: fallbackChannel,
        overrideZone: overrideZone,
      );
      if (parsed != null) drafts.add(parsed);
    }
    return drafts;
  }

  static DraftPantryAddition? _parseSingleSegment(
    String segment, {
    UnbarcodedSourceChannel? fallbackChannel,
    StorageZone? overrideZone,
  }) {
    String working = segment.trim();
    if (working.isEmpty) return null;

    String? extractedUnit;
    final halfMatch = _leadingHalfKiloRegex.firstMatch(working);
    if (halfMatch != null) {
      final rawU = IngredientNormalizer.asciiLower(halfMatch.group(1) ?? '');
      extractedUnit = (rawU == 'kg' || rawU.startsWith('kilo'))
          ? '500 gr'
          : 'Yarım ${_normalizeUnitTitle(rawU)}';
      working = working.substring(halfMatch.end).trim();
    } else {
      final numUnitMatch = _leadingNumericUnitRegex.firstMatch(working);
      if (numUnitMatch != null) {
        final qty = numUnitMatch.group(1) ?? '1';
        final rawU = IngredientNormalizer.asciiLower(numUnitMatch.group(2) ?? '');
        extractedUnit = '$qty ${_normalizeUnitTitle(rawU)}';
        working = working.substring(numUnitMatch.end).trim();
      } else {
        final countMatch = _leadingCountOnlyRegex.firstMatch(working);
        if (countMatch != null) {
          extractedUnit = '${countMatch.group(1)} Adet';
          working = working.substring(countMatch.end).trim();
        }
      }
    }

    if (working.isEmpty) return null;

    final clean = IngredientNormalizer.asciiLower(working);
    final resolved = IngredientNormalizer.resolveMetadata(working);

    final bool isHomemadeLongShelf = clean.contains('ev salca') ||
        clean.contains('ev biber') ||
        clean.contains('kavanoz') ||
        clean.contains('kislik') ||
        clean.contains('ev yapimi') ||
        clean.contains('salamura') ||
        clean.contains('tarhana') ||
        clean.contains('kurutulmus');

    final bool isFreshPerishable = resolved.tag == 'kiyma' ||
        resolved.tag == 'kusbasi_et' ||
        resolved.tag == 'kuzu_eti' ||
        resolved.tag == 'tavuk' ||
        resolved.tag == 'balik' ||
        resolved.tag == 'hamsi';

    final StorageZone effectiveZone = overrideZone ??
        (isHomemadeLongShelf && !isFreshPerishable
            ? StorageZone.pantry
            : resolved.defaultZone);

    final int effectiveShelfDays = effectiveZone == StorageZone.freezer
        ? 90
        : (isHomemadeLongShelf && !isFreshPerishable
            ? 180
            : resolved.defaultShelfDays);

    final UnbarcodedSourceChannel channel = fallbackChannel ??
        _inferChannel(clean, resolved.tag, isHomemadeLongShelf);

    final String formattedName = _formatDisplayName(working, resolved.name);

    return DraftPantryAddition.fromTemplate(
      resolved,
      overrideZone: effectiveZone,
      overrideShelfDays: effectiveShelfDays,
      sourceChannel: channel,
      customName: formattedName,
      customUnit: extractedUnit ?? resolved.defaultUnit,
    );
  }

  static UnbarcodedSourceChannel _inferChannel(
    String clean,
    String tag,
    bool isHomemade,
  ) {
    if (clean.contains('koy') ||
        clean.contains('kasap') ||
        tag == 'kiyma' ||
        tag == 'kusbasi_et' ||
        tag == 'kuzu_eti' ||
        tag == 'tavuk' ||
        tag == 'hindi') {
      return UnbarcodedSourceChannel.kasapKoy;
    }
    if (tag == 'hamsi' || tag == 'balik' || clean.contains('balikci')) {
      return UnbarcodedSourceChannel.balikci;
    }
    if (isHomemade ||
        tag == 'salca' ||
        tag == 'sumak_isot' ||
        tag == 'tarhana' ||
        tag == 'eriste') {
      return UnbarcodedSourceChannel.aktarEvYapimi;
    }
    if (tag == 'peynir' ||
        tag == 'kasar' ||
        tag == 'lor_peyniri' ||
        tag == 'yogurt' ||
        tag == 'sut' ||
        tag == 'tereyagi') {
      return UnbarcodedSourceChannel.mandiraKahvalti;
    }
    return UnbarcodedSourceChannel.manavPazar;
  }

  static String _normalizeUnitTitle(String asciiUnit) {
    if (asciiUnit == 'kg' || asciiUnit.startsWith('kilo')) return 'Kg';
    if (asciiUnit == 'gr' || asciiUnit == 'g' || asciiUnit == 'gram') return 'gr';
    if (asciiUnit == 'lt' || asciiUnit == 'l' || asciiUnit == 'litre') return 'Litre';
    if (asciiUnit == 'ml') return 'ml';
    if (asciiUnit == 'bag') return 'Bağ';
    if (asciiUnit == 'sise') return 'Şişe';
    if (asciiUnit == 'tane' || asciiUnit == 'adet') return 'Adet';
    return asciiUnit[0].toUpperCase() + asciiUnit.substring(1);
  }

  static String _formatDisplayName(String userPhrase, String fallback) {
    final cleaned = userPhrase.trim();
    if (cleaned.isEmpty) return fallback;
    if (cleaned.length <= 2) return fallback;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
