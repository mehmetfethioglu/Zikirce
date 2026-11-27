import 'package:flutter/material.dart';
import 'kiler_catalog.dart';
export 'kiler_catalog.dart';

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
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

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
    final nowMs = clock().millisecondsSinceEpoch;
    final diffMs = expiresAt - nowMs;
    return (diffMs / 86400000).ceil();
  }

  int get daysInPantry {
    final nowMs = clock().millisecondsSinceEpoch;
    final diffMs = nowMs - addedAt;
    if (diffMs <= 0) return 0;
    return diffMs ~/ 86400000;
  }

  double get shelfLifeElapsedRatio {
    final totalSpan = expiresAt - addedAt;
    if (totalSpan <= 0) return 1.0;
    final elapsed = clock().millisecondsSinceEpoch - addedAt;
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
