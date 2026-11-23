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

class PixarCharacterSkin {
  final String id;
  final String name;
  final String roleTitle;
  final String perkBadge;
  final String assetPath;
  final String model3dPath;
  final int crystalCost;
  final String storePriceLabel;
  final Color accentColor;
  final bool isDefaultUnlocked;

  const PixarCharacterSkin({
    required this.id,
    required this.name,
    required this.roleTitle,
    required this.perkBadge,
    required this.assetPath,
    required this.model3dPath,
    required this.crystalCost,
    required this.storePriceLabel,
    required this.accentColor,
    this.isDefaultUnlocked = false,
  });

  static const List<PixarCharacterSkin> catalog = [
    PixarCharacterSkin(
      id: 'char_atlas',
      name: 'Atlas',
      roleTitle: 'Doğa Koşucusu',
      perkBadge: 'Başlangıç Karakteri',
      assetPath: 'assets/images/characters/char_atlas_runner.png',
      model3dPath: 'assets/models/char_atlas.glb',
      crystalCost: 0,
      storePriceLabel: 'Ücretsiz',
      accentColor: Color(0xFFF59E0B),
      isDefaultUnlocked: true,
    ),
    PixarCharacterSkin(
      id: 'char_nova',
      name: 'Nova',
      roleTitle: 'Zümrüt Sprinter',
      perkBadge: '+%15 Adım Enerjisi',
      assetPath: 'assets/images/characters/char_nova_sprinter.png',
      model3dPath: 'assets/models/char_nova.glb',
      crystalCost: 250,
      storePriceLabel: '₺29,99',
      accentColor: Color(0xFF10B981),
    ),
    PixarCharacterSkin(
      id: 'char_kaan',
      name: 'Kaan',
      roleTitle: 'Biyo-Atlet',
      perkBadge: '+%15 Barkod XP',
      assetPath: 'assets/images/characters/char_kaan_guardian.png',
      model3dPath: 'assets/models/char_kaan.glb',
      crystalCost: 500,
      storePriceLabel: '₺49,99',
      accentColor: Color(0xFF22C55E),
    ),
    PixarCharacterSkin(
      id: 'char_lina',
      name: 'Lina',
      roleTitle: 'Ritim & Zen Ustası',
      perkBadge: '+%20 Detoks Hızı',
      assetPath: 'assets/images/characters/char_lina_zen.png',
      model3dPath: 'assets/models/char_lina.glb',
      crystalCost: 750,
      storePriceLabel: '₺69,99',
      accentColor: Color(0xFFF43F5E),
    ),
    PixarCharacterSkin(
      id: 'char_demir',
      name: 'Dr. Demir',
      roleTitle: 'Biyo-Alkemist',
      perkBadge: '+%25 Katkı Kalkanı',
      assetPath: 'assets/images/characters/char_demir_alchemist.png',
      model3dPath: 'assets/models/char_demir.glb',
      crystalCost: 1200,
      storePriceLabel: '₺89,99',
      accentColor: Color(0xFF06B6D4),
    ),
    PixarCharacterSkin(
      id: 'char_zefir',
      name: 'Zefir',
      roleTitle: 'Kuantum Şampiyon',
      perkBadge: '+%35 Efsanevi Aura',
      assetPath: 'assets/images/characters/char_zefir_legend.png',
      model3dPath: 'assets/models/char_zefir.glb',
      crystalCost: 2000,
      storePriceLabel: '₺129,99',
      accentColor: Color(0xFF8B5CF6),
    ),
  ];

  static PixarCharacterSkin byId(String id) {
    return catalog.firstWhere(
      (c) => c.id == id,
      orElse: () => catalog.first,
    );
  }
}

class PixarAvatarConfig {
  final String selectedCharacterId;
  final List<String> unlockedCharacterIds;
  final int skinToneIndex;
  final int hairStyleIndex;
  final int hairColorIndex;
  final int eyeColorIndex;
  final int armorStyleIndex;
  final int companionVisorIndex;
  final String expressionMood; // 'heroic', 'energized', 'zen', 'detox_fog'

  const PixarAvatarConfig({
    this.selectedCharacterId = 'char_atlas',
    this.unlockedCharacterIds = const ['char_atlas'],
    this.skinToneIndex = 1,
    this.hairStyleIndex = 0,
    this.hairColorIndex = 0,
    this.eyeColorIndex = 0,
    this.armorStyleIndex = 0,
    this.companionVisorIndex = 0,
    this.expressionMood = 'heroic',
  });

  bool isCharacterUnlocked(String id) =>
      id == 'char_atlas' || unlockedCharacterIds.contains(id);

  PixarCharacterSkin get activeCharacter =>
      PixarCharacterSkin.byId(selectedCharacterId);

  PixarAvatarConfig copyWith({
    String? selectedCharacterId,
    List<String>? unlockedCharacterIds,
    int? skinToneIndex,
    int? hairStyleIndex,
    int? hairColorIndex,
    int? eyeColorIndex,
    int? armorStyleIndex,
    int? companionVisorIndex,
    String? expressionMood,
  }) {
    return PixarAvatarConfig(
      selectedCharacterId: selectedCharacterId ?? this.selectedCharacterId,
      unlockedCharacterIds: unlockedCharacterIds ?? this.unlockedCharacterIds,
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
        'selectedCharacterId': selectedCharacterId,
        'unlockedCharacterIds': unlockedCharacterIds,
        'skinToneIndex': skinToneIndex,
        'hairStyleIndex': hairStyleIndex,
        'hairColorIndex': hairColorIndex,
        'eyeColorIndex': eyeColorIndex,
        'armorStyleIndex': armorStyleIndex,
        'companionVisorIndex': companionVisorIndex,
        'expressionMood': expressionMood,
      };

  factory PixarAvatarConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawUnlocked =
        json['unlockedCharacterIds'] as List<dynamic>?;
    final List<String> unlocked = rawUnlocked != null
        ? rawUnlocked.map((e) => e.toString()).toList()
        : const ['char_atlas'];
    if (!unlocked.contains('char_atlas')) {
      unlocked.insert(0, 'char_atlas');
    }
    return PixarAvatarConfig(
      selectedCharacterId:
          json['selectedCharacterId'] as String? ?? 'char_atlas',
      unlockedCharacterIds: unlocked,
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
