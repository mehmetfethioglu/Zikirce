import 'package:flutter/material.dart';

enum BioElement {
  probiotic,
  antioxidant,
  proteinFiber,
  emulsifierSlime,
  sugarCrystal,
  glutenGolem,
  syntheticToxin,
}

enum BioRarity {
  common,
  rare,
  epic,
  legendary,
}

enum GuardianArchetype {
  kefirSprite,
  oliveKnight,
  oatTitan,
  chiaDragon,
  honeyPaladin,
  avocadoSage,
}

enum BossArchetype {
  emulgoSlime,
  fructoseFiend,
  glutenGolem,
  palmMagma,
  msgPhantom,
  nitriteViper,
}

enum ScanDecisionType {
  consumed,
  rejected,
}

class BioCharacter {
  final String id;
  final String name;
  final String title;
  final BioElement element;
  final BioRarity rarity;
  final GuardianArchetype archetype;
  final int level;
  final int xp;
  final int maxHp;
  final int currentHp;
  final int attack;
  final int defense;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final bool isUnlocked;
  final String? discoveredFromBarcode;
  final String lore;

  const BioCharacter({
    required this.id,
    required this.name,
    required this.title,
    required this.element,
    required this.rarity,
    required this.archetype,
    required this.level,
    required this.xp,
    required this.maxHp,
    required this.currentHp,
    required this.attack,
    required this.defense,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.isUnlocked,
    this.discoveredFromBarcode,
    required this.lore,
  });

  int get nextLevelXp => level * 120;
  double get hpRatio => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  BioCharacter copyWith({
    int? level,
    int? xp,
    int? maxHp,
    int? currentHp,
    int? attack,
    int? defense,
    bool? isUnlocked,
    String? discoveredFromBarcode,
  }) {
    return BioCharacter(
      id: id,
      name: name,
      title: title,
      element: element,
      rarity: rarity,
      archetype: archetype,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      discoveredFromBarcode: discoveredFromBarcode ?? this.discoveredFromBarcode,
      lore: lore,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'xp': xp,
        'maxHp': maxHp,
        'currentHp': currentHp,
        'attack': attack,
        'defense': defense,
        'isUnlocked': isUnlocked,
        'discoveredFromBarcode': discoveredFromBarcode,
      };
}

class ToxicBoss {
  final String id;
  final String name;
  final String chemicalCode;
  final BioElement element;
  final BossArchetype archetype;
  final int level;
  final int maxHp;
  final int currentHp;
  final int attack;
  final String threatDescription;
  final String sourceProductName;
  final String sourceBarcode;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDefeated;
  final bool willpowerBonusApplied;
  final int rewardXp;
  final int rewardCrystals;

  const ToxicBoss({
    required this.id,
    required this.name,
    required this.chemicalCode,
    required this.element,
    required this.archetype,
    required this.level,
    required this.maxHp,
    required this.currentHp,
    required this.attack,
    required this.threatDescription,
    required this.sourceProductName,
    required this.sourceBarcode,
    required this.primaryColor,
    required this.secondaryColor,
    this.isDefeated = false,
    this.willpowerBonusApplied = false,
    required this.rewardXp,
    required this.rewardCrystals,
  });

  double get hpRatio => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  ToxicBoss copyWith({
    int? currentHp,
    bool? isDefeated,
    bool? willpowerBonusApplied,
  }) {
    return ToxicBoss(
      id: id,
      name: name,
      chemicalCode: chemicalCode,
      element: element,
      archetype: archetype,
      level: level,
      maxHp: maxHp,
      currentHp: currentHp ?? this.currentHp,
      attack: attack,
      threatDescription: threatDescription,
      sourceProductName: sourceProductName,
      sourceBarcode: sourceBarcode,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      isDefeated: isDefeated ?? this.isDefeated,
      willpowerBonusApplied: willpowerBonusApplied ?? this.willpowerBonusApplied,
      rewardXp: rewardXp,
      rewardCrystals: rewardCrystals,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chemicalCode': chemicalCode,
        'element': element.name,
        'archetype': archetype.name,
        'level': level,
        'maxHp': maxHp,
        'currentHp': currentHp,
        'attack': attack,
        'threatDescription': threatDescription,
        'sourceProductName': sourceProductName,
        'sourceBarcode': sourceBarcode,
        'primaryColor': primaryColor.toARGB32(),
        'secondaryColor': secondaryColor.toARGB32(),
        'isDefeated': isDefeated,
        'willpowerBonusApplied': willpowerBonusApplied,
        'rewardXp': rewardXp,
        'rewardCrystals': rewardCrystals,
      };

  factory ToxicBoss.fromJson(Map<String, dynamic> json) {
    return ToxicBoss(
      id: json['id'] as String? ?? 'boss_default',
      name: json['name'] as String? ?? 'Emülgo-Slime',
      chemicalCode: json['chemicalCode'] as String? ?? 'E471',
      element: BioElement.values.firstWhere(
        (e) => e.name == json['element'],
        orElse: () => BioElement.emulsifierSlime,
      ),
      archetype: BossArchetype.values.firstWhere(
        (a) => a.name == json['archetype'],
        orElse: () => BossArchetype.emulgoSlime,
      ),
      level: json['level'] as int? ?? 1,
      maxHp: json['maxHp'] as int? ?? 200,
      currentHp: json['currentHp'] as int? ?? 200,
      attack: json['attack'] as int? ?? 22,
      threatDescription: json['threatDescription'] as String? ?? 'Bağırsak florasını zayıflatan sentetik emülgatör.',
      sourceProductName: json['sourceProductName'] as String? ?? 'İşlenmiş Gıda',
      sourceBarcode: json['sourceBarcode'] as String? ?? '000000',
      primaryColor: Color(json['primaryColor'] as int? ?? 0xFF7C3AED),
      secondaryColor: Color(json['secondaryColor'] as int? ?? 0xFFDC2626),
      isDefeated: json['isDefeated'] as bool? ?? false,
      willpowerBonusApplied: json['willpowerBonusApplied'] as bool? ?? false,
      rewardXp: json['rewardXp'] as int? ?? 65,
      rewardCrystals: json['rewardCrystals'] as int? ?? 30,
    );
  }
}

class MetabolicScanRecord {
  final String barcode;
  final String productName;
  final int productScore;
  final ScanDecisionType decision;
  final int personalScoreDelta;
  final int timestamp;
  final String spawnedEntityName;
  final bool isBossEncounter;

  const MetabolicScanRecord({
    required this.barcode,
    required this.productName,
    required this.productScore,
    required this.decision,
    required this.personalScoreDelta,
    required this.timestamp,
    required this.spawnedEntityName,
    required this.isBossEncounter,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'productName': productName,
        'productScore': productScore,
        'decision': decision.name,
        'personalScoreDelta': personalScoreDelta,
        'timestamp': timestamp,
        'spawnedEntityName': spawnedEntityName,
        'isBossEncounter': isBossEncounter,
      };

  factory MetabolicScanRecord.fromJson(Map<String, dynamic> json) {
    return MetabolicScanRecord(
      barcode: json['barcode'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Ürün',
      productScore: json['productScore'] as int? ?? 50,
      decision: json['decision'] == 'rejected'
          ? ScanDecisionType.rejected
          : ScanDecisionType.consumed,
      personalScoreDelta: json['personalScoreDelta'] as int? ?? 0,
      timestamp: json['timestamp'] as int? ?? 0,
      spawnedEntityName: json['spawnedEntityName'] as String? ?? '',
      isBossEncounter: json['isBossEncounter'] as bool? ?? false,
    );
  }
}

class PixarAvatarConfig {
  final int skinToneIndex;
  final int hairStyleIndex;
  final int hairColorIndex;
  final int eyeColorIndex;
  final int armorStyleIndex;
  final int companionVisorIndex;
  final String expressionMood; // 'heroic', 'energized', 'zen', 'detox_fog'

  const PixarAvatarConfig({
    this.skinToneIndex = 1,
    this.hairStyleIndex = 0,
    this.hairColorIndex = 0,
    this.eyeColorIndex = 0,
    this.armorStyleIndex = 0,
    this.companionVisorIndex = 0,
    this.expressionMood = 'heroic',
  });

  PixarAvatarConfig copyWith({
    int? skinToneIndex,
    int? hairStyleIndex,
    int? hairColorIndex,
    int? eyeColorIndex,
    int? armorStyleIndex,
    int? companionVisorIndex,
    String? expressionMood,
  }) {
    return PixarAvatarConfig(
      skinToneIndex: skinToneIndex ?? this.skinToneIndex,
      hairStyleIndex: hairStyleIndex ?? this.hairStyleIndex,
      hairColorIndex: hairColorIndex ?? this.hairColorIndex,
      eyeColorIndex: eyeColorIndex ?? this.eyeColorIndex,
      armorStyleIndex: armorStyleIndex ?? this.armorStyleIndex,
      companionVisorIndex: companionVisorIndex ?? this.companionVisorIndex,
      expressionMood: expressionMood ?? this.expressionMood,
    );
  }

  Map<String, dynamic> toJson() => {
        'skinToneIndex': skinToneIndex,
        'hairStyleIndex': hairStyleIndex,
        'hairColorIndex': hairColorIndex,
        'eyeColorIndex': eyeColorIndex,
        'armorStyleIndex': armorStyleIndex,
        'companionVisorIndex': companionVisorIndex,
        'expressionMood': expressionMood,
      };

  factory PixarAvatarConfig.fromJson(Map<String, dynamic> json) {
    return PixarAvatarConfig(
      skinToneIndex: json['skinToneIndex'] as int? ?? 1,
      hairStyleIndex: json['hairStyleIndex'] as int? ?? 0,
      hairColorIndex: json['hairColorIndex'] as int? ?? 0,
      eyeColorIndex: json['eyeColorIndex'] as int? ?? 0,
      armorStyleIndex: json['armorStyleIndex'] as int? ?? 0,
      companionVisorIndex: json['companionVisorIndex'] as int? ?? 0,
      expressionMood: json['expressionMood'] as String? ?? 'heroic',
    );
  }
}
