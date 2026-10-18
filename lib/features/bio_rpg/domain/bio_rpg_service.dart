import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../profile/domain/user_profile_service.dart';
import 'bio_rpg_models.dart';

class EncounterSpawnResult {
  final bool isBossEncounter;
  final ToxicBoss? spawnedBoss;
  final BioCharacter? discoveredGuardian;
  final String headline;
  final String subtitle;

  const EncounterSpawnResult({
    required this.isBossEncounter,
    this.spawnedBoss,
    this.discoveredGuardian,
    required this.headline,
    required this.subtitle,
  });
}

class DuelTurnResult {
  final int playerDamageDealt;
  final int bossDamageDealt;
  final int playerHealed;
  final bool isSuperEffective;
  final bool isCriticalWillpower;
  final bool bossDefeated;
  final bool playerDefeated;
  final String combatLog;
  final ToxicBoss updatedBoss;
  final BioCharacter updatedGuardian;

  const DuelTurnResult({
    required this.playerDamageDealt,
    required this.bossDamageDealt,
    required this.playerHealed,
    required this.isSuperEffective,
    required this.isCriticalWillpower,
    required this.bossDefeated,
    required this.playerDefeated,
    required this.combatLog,
    required this.updatedBoss,
    required this.updatedGuardian,
  });
}

class PersonalOrganicScoreState {
  final int personalOrganicScore;
  final int willpowerStreak;
  final int bioCrystals;
  final int bioEnergy;
  final int maxBioEnergy;
  final int dailySteps;
  final int dailyStepGoal;
  final int lastConvertedStepMilestone;
  final double heightCm;
  final double weightKg;
  final bool smartwatchConnected;
  final String smartwatchName;
  final int activeDetoxTargetSteps;
  final int detoxCurrentSteps;
  final String selectedGuardianId;
  final List<BioCharacter> guardians;
  final List<ToxicBoss> bossQueue;
  final List<MetabolicScanRecord> scanHistory;
  final PixarAvatarConfig avatarConfig;
  final bool hasOrganicPass;
  final int seasonPassXp;

  const PersonalOrganicScoreState({
    required this.personalOrganicScore,
    required this.willpowerStreak,
    required this.bioCrystals,
    required this.bioEnergy,
    required this.maxBioEnergy,
    required this.dailySteps,
    required this.dailyStepGoal,
    required this.lastConvertedStepMilestone,
    required this.heightCm,
    required this.weightKg,
    required this.smartwatchConnected,
    required this.smartwatchName,
    required this.activeDetoxTargetSteps,
    required this.detoxCurrentSteps,
    required this.selectedGuardianId,
    required this.guardians,
    required this.bossQueue,
    required this.scanHistory,
    required this.avatarConfig,
    required this.hasOrganicPass,
    required this.seasonPassXp,
  });

  bool get hasActiveDetoxQuest => activeDetoxTargetSteps > 0 && detoxCurrentSteps < activeDetoxTargetSteps;

  double get detoxProgress => activeDetoxTargetSteps > 0
      ? (detoxCurrentSteps / activeDetoxTargetSteps).clamp(0.0, 1.0)
      : 1.0;

  double get bmi {
    final double heightM = (heightCm / 100.0).clamp(1.0, 2.5);
    return weightKg / (heightM * heightM);
  }

  String get bmiCategory {
    final double val = bmi;
    if (val < 18.5) return 'Hafif / Çevik Biyo-Form';
    if (val < 25.0) return 'Optimal Biyo-Denge';
    if (val < 30.0) return 'Güç Odaklı Metabolizma';
    return 'Direnç & Detoks Modu';
  }

  int get activeCaloriesBurned => (dailySteps * 0.042 * (weightKg / 70.0)).round();

  int get seasonPassLevel => (seasonPassXp ~/ 200) + 1;

  BioCharacter get activeGuardian {
    return guardians.firstWhere(
      (g) => g.id == selectedGuardianId,
      orElse: () => guardians.first,
    );
  }

  List<ToxicBoss> get activeBosses => bossQueue.where((b) => !b.isDefeated).toList();

  PersonalOrganicScoreState copyWith({
    int? personalOrganicScore,
    int? willpowerStreak,
    int? bioCrystals,
    int? bioEnergy,
    int? maxBioEnergy,
    int? dailySteps,
    int? dailyStepGoal,
    int? lastConvertedStepMilestone,
    double? heightCm,
    double? weightKg,
    bool? smartwatchConnected,
    String? smartwatchName,
    int? activeDetoxTargetSteps,
    int? detoxCurrentSteps,
    String? selectedGuardianId,
    List<BioCharacter>? guardians,
    List<ToxicBoss>? bossQueue,
    List<MetabolicScanRecord>? scanHistory,
    PixarAvatarConfig? avatarConfig,
    bool? hasOrganicPass,
    int? seasonPassXp,
  }) {
    return PersonalOrganicScoreState(
      personalOrganicScore: personalOrganicScore ?? this.personalOrganicScore,
      willpowerStreak: willpowerStreak ?? this.willpowerStreak,
      bioCrystals: bioCrystals ?? this.bioCrystals,
      bioEnergy: bioEnergy ?? this.bioEnergy,
      maxBioEnergy: maxBioEnergy ?? this.maxBioEnergy,
      dailySteps: dailySteps ?? this.dailySteps,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      lastConvertedStepMilestone: lastConvertedStepMilestone ?? this.lastConvertedStepMilestone,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      smartwatchConnected: smartwatchConnected ?? this.smartwatchConnected,
      smartwatchName: smartwatchName ?? this.smartwatchName,
      activeDetoxTargetSteps: activeDetoxTargetSteps ?? this.activeDetoxTargetSteps,
      detoxCurrentSteps: detoxCurrentSteps ?? this.detoxCurrentSteps,
      selectedGuardianId: selectedGuardianId ?? this.selectedGuardianId,
      guardians: guardians ?? this.guardians,
      bossQueue: bossQueue ?? this.bossQueue,
      scanHistory: scanHistory ?? this.scanHistory,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      hasOrganicPass: hasOrganicPass ?? this.hasOrganicPass,
      seasonPassXp: seasonPassXp ?? this.seasonPassXp,
    );
  }
}

class BioRpgService extends ValueNotifier<PersonalOrganicScoreState> {
  static final BioRpgService instance = BioRpgService._internal();

  static const String _storageKey = 'organicscore_bio_rpg_state_v1';

  BioRpgService._internal() : super(_createDefaultState());

  static List<BioCharacter> defaultGuardians() => const [
        BioCharacter(
          id: 'guardian_kefir',
          name: 'Kefirion',
          title: 'Probiyotik Su Muhafızı',
          element: BioElement.probiotic,
          rarity: BioRarity.rare,
          archetype: GuardianArchetype.kefirSprite,
          level: 3,
          xp: 80,
          maxHp: 260,
          currentHp: 260,
          attack: 38,
          defense: 24,
          primaryColor: Color(0xFF06B6D4),
          secondaryColor: Color(0xFF10B981),
          accentColor: Color(0xFFECFEFF),
          isUnlocked: true,
          lore: 'Fermente kefir ve canlı probiyotik kültürlerinden doğdu. Emülgatör (E471) ve bağırsak bozucu toksinlere karşı 2x kritik hasar vurur.',
        ),
        BioCharacter(
          id: 'guardian_olive',
          name: 'Olea Prime',
          title: 'Polifenol Zırh Şövalyesi',
          element: BioElement.antioxidant,
          rarity: BioRarity.epic,
          archetype: GuardianArchetype.oliveKnight,
          level: 4,
          xp: 120,
          maxHp: 310,
          currentHp: 310,
          attack: 44,
          defense: 32,
          primaryColor: Color(0xFF10B981),
          secondaryColor: Color(0xFFF59E0B),
          accentColor: Color(0xFFD1FAE5),
          isUnlocked: true,
          lore: 'Soğuk sıkım sızma zeytinyağı polifenolleriyle dövülmüş zırhı, sentetik boya ve MSG (E621) hayaletlerini tek darbede dağıtır.',
        ),
        BioCharacter(
          id: 'guardian_oat',
          name: 'Beta-Glukan Titanı',
          title: 'Lif & Protein Kalkanı',
          element: BioElement.proteinFiber,
          rarity: BioRarity.rare,
          archetype: GuardianArchetype.oatTitan,
          level: 2,
          xp: 40,
          maxHp: 340,
          currentHp: 340,
          attack: 34,
          defense: 38,
          primaryColor: Color(0xFFF59E0B),
          secondaryColor: Color(0xFF10B981),
          accentColor: Color(0xFFFEF3C7),
          isUnlocked: true,
          lore: 'Yüksek lif ağlarıyla Fruktoz Şurubu ve Şeker İblislerinin kana karışma hızını keser, glisemik kalkan açar.',
        ),
        BioCharacter(
          id: 'guardian_chia',
          name: 'Omega-Draco',
          title: 'Chia & Omega-3 Ejderi',
          element: BioElement.antioxidant,
          rarity: BioRarity.legendary,
          archetype: GuardianArchetype.chiaDragon,
          level: 5,
          xp: 0,
          maxHp: 420,
          currentHp: 420,
          attack: 58,
          defense: 40,
          primaryColor: Color(0xFF8B5CF6),
          secondaryColor: Color(0xFF06B6D4),
          accentColor: Color(0xFFEDE9FE),
          isUnlocked: false,
          lore: 'Yalnızca 85+ OrganicScore değerine sahip süper-gıdaların barkodunu tarayanların uyandırabildiği efsanevi hücresel muhafız.',
        ),
        BioCharacter(
          id: 'guardian_honey',
          name: 'Propolis Paladin',
          title: 'Saf Enzim Muhafızı',
          element: BioElement.probiotic,
          rarity: BioRarity.epic,
          archetype: GuardianArchetype.honeyPaladin,
          level: 3,
          xp: 0,
          maxHp: 295,
          currentHp: 295,
          attack: 46,
          defense: 28,
          primaryColor: Color(0xFFD97706),
          secondaryColor: Color(0xFFFBBF24),
          accentColor: Color(0xFFFFFBEB),
          isUnlocked: false,
          lore: 'Tağşişsiz gerçek ham bal ve propolis kristallerinden güç alır; taklit ve glikoz şuruplu sahte ürünleri anında buharlaştırır.',
        ),
        BioCharacter(
          id: 'guardian_avocado',
          name: 'Avokado Bilgesi',
          title: 'Mitokondri Şifacısı',
          element: BioElement.proteinFiber,
          rarity: BioRarity.legendary,
          archetype: GuardianArchetype.avocadoSage,
          level: 4,
          xp: 0,
          maxHp: 380,
          currentHp: 380,
          attack: 50,
          defense: 45,
          primaryColor: Color(0xFF059669),
          secondaryColor: Color(0xFF84CC16),
          accentColor: Color(0xFFECFDF5),
          isUnlocked: false,
          lore: 'Palm yağı ve trans yağ magmalarına karşı sağlıklı tekli doymamış yağ kalkanı kuran kadim şifacı.',
        ),
      ];

  static List<ToxicBoss> defaultStarterBosses() => const [
        ToxicBoss(
          id: 'boss_starter_e471',
          name: 'Emülgo-Slime E471',
          chemicalCode: 'E471 Mono ve Digliseritler',
          element: BioElement.emulsifierSlime,
          archetype: BossArchetype.emulgoSlime,
          level: 2,
          maxHp: 220,
          currentHp: 220,
          attack: 24,
          threatDescription: 'Paketli dondurma ve keklerde bulunan sentetik emülgatör. Bağırsak mukozasını incelterek inflamasyon tetikler!',
          sourceProductName: 'Endüstriyel Krema & Kek',
          sourceBarcode: '8690504011200',
          primaryColor: Color(0xFF7C3AED),
          secondaryColor: Color(0xFFEC4899),
          rewardXp: 75,
          rewardCrystals: 35,
        ),
        ToxicBoss(
          id: 'boss_starter_gluten',
          name: 'Rafine Glüten Golemi',
          chemicalCode: 'Profil İhlali: Gluten / Rafine Un',
          element: BioElement.glutenGolem,
          archetype: BossArchetype.glutenGolem,
          level: 3,
          maxHp: 280,
          currentHp: 280,
          attack: 28,
          threatDescription: 'Hassas sindirim profillerinde şişkinlik, beyin sisi ve otoimmün yorgunluk oluşturan ağır glüten duvarı!',
          sourceProductName: 'Ultra-İşlenmiş Kraker',
          sourceBarcode: '8690526090115',
          primaryColor: Color(0xFFD97706),
          secondaryColor: Color(0xFFDC2626),
          rewardXp: 90,
          rewardCrystals: 45,
        ),
        ToxicBoss(
          id: 'boss_starter_msg',
          name: 'Nöro-Gölge E621',
          chemicalCode: 'E621 Monosodyum Glutamat (MSG)',
          element: BioElement.syntheticToxin,
          archetype: BossArchetype.msgPhantom,
          level: 4,
          maxHp: 320,
          currentHp: 320,
          attack: 34,
          threatDescription: 'Tat alma reseptörlerini hipnotize ederek tokluk hissini kapatan ve aşırı tüketim bağımlılığı yaratan nörotoksik boss!',
          sourceProductName: 'Aromalı Süper Cips',
          sourceBarcode: '8690624001426',
          primaryColor: Color(0xFFDC2626),
          secondaryColor: Color(0xFF7C3AED),
          rewardXp: 115,
          rewardCrystals: 60,
        ),
      ];

  static PersonalOrganicScoreState _createDefaultState() {
    return PersonalOrganicScoreState(
      personalOrganicScore: 82,
      willpowerStreak: 3,
      bioCrystals: 140,
      bioEnergy: 6,
      maxBioEnergy: 10,
      dailySteps: 4650,
      dailyStepGoal: 8000,
      lastConvertedStepMilestone: 4000,
      heightCm: 175.0,
      weightKg: 72.0,
      smartwatchConnected: false,
      smartwatchName: 'Cihaz Adımsayar Sensörü',
      activeDetoxTargetSteps: 0,
      detoxCurrentSteps: 0,
      selectedGuardianId: 'guardian_kefir',
      guardians: defaultGuardians(),
      bossQueue: defaultStarterBosses(),
      scanHistory: const [],
      avatarConfig: const PixarAvatarConfig(
        skinToneIndex: 1,
        hairStyleIndex: 0,
        hairColorIndex: 0,
        eyeColorIndex: 1,
        armorStyleIndex: 0,
        companionVisorIndex: 0,
        expressionMood: 'heroic',
      ),
      hasOrganicPass: false,
      seasonPassXp: 240,
    );
  }

  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final Map<String, dynamic> map = jsonDecode(raw);
      final List<BioCharacter> baseGuardians = defaultGuardians();

      final List<dynamic> savedGuardiansJson = map['guardians'] as List<dynamic>? ?? [];
      final List<BioCharacter> mergedGuardians = baseGuardians.map((base) {
        for (final item in savedGuardiansJson) {
          if (item is Map<String, dynamic> && item['id'] == base.id) {
            return base.copyWith(
              level: item['level'] as int? ?? base.level,
              xp: item['xp'] as int? ?? base.xp,
              maxHp: item['maxHp'] as int? ?? base.maxHp,
              currentHp: item['currentHp'] as int? ?? base.currentHp,
              attack: item['attack'] as int? ?? base.attack,
              defense: item['defense'] as int? ?? base.defense,
              isUnlocked: item['isUnlocked'] as bool? ?? base.isUnlocked,
              discoveredFromBarcode: item['discoveredFromBarcode'] as String?,
            );
          }
        }
        return base;
      }).toList();

      final List<dynamic> bossesJson = map['bossQueue'] as List<dynamic>? ?? [];
      final List<ToxicBoss> loadedBosses = bossesJson.isNotEmpty
          ? bossesJson.map((b) => ToxicBoss.fromJson(b as Map<String, dynamic>)).toList()
          : defaultStarterBosses();

      final List<dynamic> historyJson = map['scanHistory'] as List<dynamic>? ?? [];
      final List<MetabolicScanRecord> loadedHistory = historyJson
          .map((h) => MetabolicScanRecord.fromJson(h as Map<String, dynamic>))
          .toList();

      final PixarAvatarConfig avatar = map['avatarConfig'] != null
          ? PixarAvatarConfig.fromJson(map['avatarConfig'] as Map<String, dynamic>)
          : const PixarAvatarConfig();

      value = PersonalOrganicScoreState(
        personalOrganicScore: (map['personalOrganicScore'] as int? ?? 82).clamp(0, 100),
        willpowerStreak: map['willpowerStreak'] as int? ?? 3,
        bioCrystals: map['bioCrystals'] as int? ?? 140,
        bioEnergy: map['bioEnergy'] as int? ?? 6,
        maxBioEnergy: map['maxBioEnergy'] as int? ?? 10,
        dailySteps: map['dailySteps'] as int? ?? 4650,
        dailyStepGoal: map['dailyStepGoal'] as int? ?? 8000,
        lastConvertedStepMilestone: map['lastConvertedStepMilestone'] as int? ?? 4000,
        heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
        weightKg: (map['weightKg'] as num?)?.toDouble() ?? 72.0,
        smartwatchConnected: map['smartwatchConnected'] as bool? ?? false,
        smartwatchName: map['smartwatchName'] as String? ?? 'Cihaz Adımsayar Sensörü',
        activeDetoxTargetSteps: map['activeDetoxTargetSteps'] as int? ?? 0,
        detoxCurrentSteps: map['detoxCurrentSteps'] as int? ?? 0,
        selectedGuardianId: map['selectedGuardianId'] as String? ?? 'guardian_kefir',
        guardians: mergedGuardians,
        bossQueue: loadedBosses,
        scanHistory: loadedHistory,
        avatarConfig: avatar,
        hasOrganicPass: map['hasOrganicPass'] as bool? ?? false,
        seasonPassXp: map['seasonPassXp'] as int? ?? 240,
      );
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> payload = {
        'personalOrganicScore': value.personalOrganicScore,
        'willpowerStreak': value.willpowerStreak,
        'bioCrystals': value.bioCrystals,
        'bioEnergy': value.bioEnergy,
        'maxBioEnergy': value.maxBioEnergy,
        'dailySteps': value.dailySteps,
        'dailyStepGoal': value.dailyStepGoal,
        'lastConvertedStepMilestone': value.lastConvertedStepMilestone,
        'heightCm': value.heightCm,
        'weightKg': value.weightKg,
        'smartwatchConnected': value.smartwatchConnected,
        'smartwatchName': value.smartwatchName,
        'activeDetoxTargetSteps': value.activeDetoxTargetSteps,
        'detoxCurrentSteps': value.detoxCurrentSteps,
        'selectedGuardianId': value.selectedGuardianId,
        'guardians': value.guardians.map((g) => g.toJson()).toList(),
        'bossQueue': value.bossQueue.map((b) => b.toJson()).toList(),
        'scanHistory': value.scanHistory.take(30).map((s) => s.toJson()).toList(),
        'avatarConfig': value.avatarConfig.toJson(),
        'hasOrganicPass': value.hasOrganicPass,
        'seasonPassXp': value.seasonPassXp,
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }

  /// Deterministically generates either a ToxicBoss (if product has additives/violations or score < 65)
  /// or discovers/buffs a BioCharacter (if clean product >= 65).
  EncounterSpawnResult evaluateProductEncounter({
    required String barcode,
    required String productName,
    required int productScore,
    required String ingredientsText,
    required List<String> violationTitles,
    required List<String> additiveNames,
  }) {
    final String lower = '${productName.toLowerCase()} ${ingredientsText.toLowerCase()} ${violationTitles.join(' ').toLowerCase()} ${additiveNames.join(' ').toLowerCase()}';
    final bool hasViolations = violationTitles.isNotEmpty;
    final bool isToxicOrLowScore = productScore < 65 || hasViolations || additiveNames.isNotEmpty;

    if (isToxicOrLowScore) {
      BossArchetype archetype = BossArchetype.emulgoSlime;
      BioElement element = BioElement.emulsifierSlime;
      String bossName = 'Emülgo-Slime E471';
      String chemCode = additiveNames.isNotEmpty ? additiveNames.first : 'Sentetik Emülgatör / Katkı';
      String desc = 'Bağırsak bariyerini zayıflatan endüstriyel katkı maddesi tespit edildi!';
      Color primary = const Color(0xFF7C3AED);
      Color secondary = const Color(0xFFEC4899);

      if (lower.contains('gluten') || lower.contains('buğday') || lower.contains('çölyak')) {
        archetype = BossArchetype.glutenGolem;
        element = BioElement.glutenGolem;
        bossName = 'Glüten Golemi';
        chemCode = 'Profil İhlali: Gluten & Rafine Tahıl';
        desc = 'Profilinizde yasaklı/hassas olan Gluten proteini tespit edildi! Sindirim kalkanına saldırıyor.';
        primary = const Color(0xFFD97706);
        secondary = const Color(0xFFDC2626);
      } else if (lower.contains('e621') || lower.contains('glutamat') || lower.contains('msg') || lower.contains('aroma')) {
        archetype = BossArchetype.msgPhantom;
        element = BioElement.syntheticToxin;
        bossName = 'Nöro-Gölge E621';
        chemCode = 'E621 MSG / Sentetik Aroma';
        desc = 'Sinir uçlarını aşırı uyaran lezzet taklitçisi! Polifenol Muhafızı ile etkisiz hale getir.';
        primary = const Color(0xFFDC2626);
        secondary = const Color(0xFF7C3AED);
      } else if (lower.contains('palm') || lower.contains('margarin') || lower.contains('trans')) {
        archetype = BossArchetype.palmMagma;
        element = BioElement.emulsifierSlime;
        bossName = 'Palm Magması';
        chemCode = 'Rafine Palm Yağı & Doymuş Yağ';
        desc = 'Damar elastikiyetini hedef alan ağır endüstriyel yağ kütlesi!';
        primary = const Color(0xFFEA580C);
        secondary = const Color(0xFF991B1B);
      } else if (lower.contains('fruktoz') || lower.contains('glikoz') || lower.contains('şeker') || lower.contains('şurup')) {
        archetype = BossArchetype.fructoseFiend;
        element = BioElement.sugarCrystal;
        bossName = 'Fruktoz Kristal İblisi';
        chemCode = 'Yüksek Glisemik Şeker / Şurup';
        desc = 'İnsülin dalgalanması yaratan kristalize şeker canavarı! Lif Titanı ile kalkan aç.';
        primary = const Color(0xFFEC4899);
        secondary = const Color(0xFFF43F5E);
      } else if (lower.contains('e250') || lower.contains('nitrit') || lower.contains('koruyucu')) {
        archetype = BossArchetype.nitriteViper;
        element = BioElement.syntheticToxin;
        bossName = 'Nitrit Engereği E250';
        chemCode = 'E250 Sodyum Nitrit / Koruyucu';
        desc = 'Hücresel oksidasyonu artıran sentetik koruyucu engerek!';
        primary = const Color(0xFF9333EA);
        secondary = const Color(0xFFEF4444);
      }

      final int bossLevel = ((100 - productScore) ~/ 15).clamp(1, 7);
      final int maxHp = 180 + (bossLevel * 45);
      final ToxicBoss boss = ToxicBoss(
        id: 'boss_${barcode}_${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: bossName,
        chemicalCode: chemCode,
        element: element,
        archetype: archetype,
        level: bossLevel,
        maxHp: maxHp,
        currentHp: maxHp,
        attack: 18 + (bossLevel * 5),
        threatDescription: desc,
        sourceProductName: productName,
        sourceBarcode: barcode,
        primaryColor: primary,
        secondaryColor: secondary,
        rewardXp: 55 + (bossLevel * 20),
        rewardCrystals: 25 + (bossLevel * 10),
      );

      return EncounterSpawnResult(
        isBossEncounter: true,
        spawnedBoss: boss,
        headline: '⚠️ Toksik Boss Uyanışı: $bossName (Sv. $bossLevel)',
        subtitle: '$chemCode tespit edildi! Ürünü rafa bırakarak Boss\'a %50 İrade Hasarı vurabilirsin.',
      );
    } else {
      // Healthy / Clean product -> Unlock or buff a Bio-Guardian!
      final int hash = barcode.codeUnits.fold(0, (prev, elem) => prev + elem);
      final BioCharacter candidate = value.guardians[hash % value.guardians.length];
      return EncounterSpawnResult(
        isBossEncounter: false,
        discoveredGuardian: candidate,
        headline: '✨ Biyo-Muhafız Sinerjisi: ${candidate.name}',
        subtitle: 'Bu temiz ürün ($productScore/100) ${candidate.name} karakterine +HP, +Saldırı Gücü ve Evrim XP\'si kazandırır!',
      );
    }
  }

  /// Processes user's "Aldım (Consumed)" vs "Almadım / Rafa Bıraktım (Rejected)" feedback.
  Future<MetabolicScanRecord> recordProductDecision({
    required String barcode,
    required String productName,
    required int productScore,
    required ScanDecisionType decision,
    required EncounterSpawnResult encounter,
  }) async {
    int scoreDelta = 0;
    int newStreak = value.willpowerStreak;
    int addedCrystals = 0;
    int addedSeasonXp = 35;
    int detoxTarget = value.activeDetoxTargetSteps;
    int detoxCurrent = value.detoxCurrentSteps;
    List<BioCharacter> updatedGuardians = List<BioCharacter>.from(value.guardians);
    List<ToxicBoss> updatedBosses = List<ToxicBoss>.from(value.bossQueue);
    String mood = value.avatarConfig.expressionMood;

    if (encounter.isBossEncounter && encounter.spawnedBoss != null) {
      ToxicBoss boss = encounter.spawnedBoss!;
      if (decision == ScanDecisionType.rejected) {
        // User rejected the unhealthy/forbidden product! Willpower Victory!
        scoreDelta = 6;
        newStreak += 1;
        addedCrystals = 35;
        addedSeasonXp = 65;
        mood = 'heroic';
        // Pre-damage the boss by 50% with Willpower Shield!
        boss = boss.copyWith(
          currentHp: (boss.maxHp * 0.5).round(),
          willpowerBonusApplied: true,
        );
        await UserProfileService.instance.recordScan(isHealthy: true);
      } else {
        // User consumed the unhealthy product -> Honest metabolic penalty + Detox Quest!
        scoreDelta = -8;
        newStreak = 0;
        addedCrystals = 5;
        detoxTarget = 3000;
        detoxCurrent = 0;
        mood = 'detox_fog';
        await UserProfileService.instance.recordScan(isHealthy: false);
      }

      // Add or replace boss at the top of the Arena queue
      updatedBosses.removeWhere((b) => b.sourceBarcode == barcode && !b.isDefeated);
      updatedBosses.insert(0, boss);
    } else {
      // Clean / Organic product!
      final BioCharacter target = encounter.discoveredGuardian ?? value.activeGuardian;
      if (decision == ScanDecisionType.consumed) {
        scoreDelta = 7;
        newStreak += 1;
        addedCrystals = 40;
        addedSeasonXp = 70;
        mood = 'energized';
        if (detoxTarget > 0) {
          // Consuming organic product helps detox by 1000 steps!
          detoxCurrent = (detoxCurrent + 1000).clamp(0, detoxTarget);
          if (detoxCurrent >= detoxTarget) {
            detoxTarget = 0;
            detoxCurrent = 0;
          }
        }
        // Unlock & buff the guardian
        updatedGuardians = updatedGuardians.map((g) {
          if (g.id == target.id) {
            final int newXp = g.xp + 65;
            final bool leveledUp = newXp >= g.nextLevelXp;
            return g.copyWith(
              isUnlocked: true,
              level: leveledUp ? g.level + 1 : g.level,
              xp: leveledUp ? newXp - g.nextLevelXp : newXp,
              maxHp: leveledUp ? g.maxHp + 30 : g.maxHp,
              currentHp: leveledUp ? g.maxHp + 30 : min(g.maxHp, g.currentHp + 50),
              attack: leveledUp ? g.attack + 6 : g.attack + 2,
              discoveredFromBarcode: barcode,
            );
          }
          return g;
        }).toList();
        await UserProfileService.instance.recordScan(isHealthy: true);
      } else {
        // Passed on a healthy product (neutral)
        scoreDelta = 1;
        addedCrystals = 10;
        await UserProfileService.instance.recordScan(isHealthy: false);
      }
    }

    final record = MetabolicScanRecord(
      barcode: barcode,
      productName: productName,
      productScore: productScore,
      decision: decision,
      personalScoreDelta: scoreDelta,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      spawnedEntityName: encounter.isBossEncounter
          ? (encounter.spawnedBoss?.name ?? 'Toksik Boss')
          : (encounter.discoveredGuardian?.name ?? 'Bio-Muhafız'),
      isBossEncounter: encounter.isBossEncounter,
    );

    final List<MetabolicScanRecord> updatedHistory = [record, ...value.scanHistory].take(30).toList();

    value = value.copyWith(
      personalOrganicScore: (value.personalOrganicScore + scoreDelta).clamp(0, 100),
      willpowerStreak: newStreak,
      bioCrystals: value.bioCrystals + addedCrystals,
      activeDetoxTargetSteps: detoxTarget,
      detoxCurrentSteps: detoxCurrent,
      guardians: updatedGuardians,
      bossQueue: updatedBosses,
      scanHistory: updatedHistory,
      avatarConfig: value.avatarConfig.copyWith(expressionMood: mood),
      seasonPassXp: value.seasonPassXp + addedSeasonXp,
    );

    await _saveState();
    return record;
  }

  /// Checks elemental superiority between Guardian and Toxic Boss
  bool isElementSuperEffective(BioElement guardianElement, BioElement bossElement) {
    if (guardianElement == BioElement.probiotic &&
        (bossElement == BioElement.emulsifierSlime || bossElement == BioElement.glutenGolem)) {
      return true;
    }
    if (guardianElement == BioElement.antioxidant &&
        (bossElement == BioElement.syntheticToxin || bossElement == BioElement.emulsifierSlime)) {
      return true;
    }
    if (guardianElement == BioElement.proteinFiber &&
        (bossElement == BioElement.sugarCrystal || bossElement == BioElement.glutenGolem)) {
      return true;
    }
    return false;
  }

  /// Executes an interactive 3D Arena duel turn
  /// [moveType]: 'strike', 'bio_burst', 'willpower_shield'
  Future<DuelTurnResult> executeDuelTurn({
    required String bossId,
    required String moveType,
  }) async {
    final BioCharacter guardian = value.activeGuardian;
    final int bossIdx = value.bossQueue.indexWhere((b) => b.id == bossId);
    if (bossIdx == -1) {
      throw StateError('Boss not found');
    }
    ToxicBoss boss = value.bossQueue[bossIdx];

    final bool superEffective = isElementSuperEffective(guardian.element, boss.element);
    double multiplier = superEffective ? 1.75 : 1.0;
    if (boss.willpowerBonusApplied) {
      multiplier *= 1.25;
    }

    int playerDamage = 0;
    int playerHealed = 0;
    double defenseMitigation = 1.0;
    String logMessage = '';

    if (moveType == 'strike') {
      playerDamage = (guardian.attack * multiplier).round();
      logMessage = '${guardian.name} Biyo-Darbe vurdu ($playerDamage Hasar)!';
    } else if (moveType == 'bio_burst') {
      playerDamage = (guardian.attack * 1.55 * multiplier).round();
      logMessage = superEffective
          ? '⚡ SÜPER ETKİLİ! ${guardian.name} Elementel Biyo-Patlama ile $playerDamage Kritik Hasar vurdu!'
          : '${guardian.name} Elementel Biyo-Patlama kullandı ($playerDamage Hasar)!';
    } else if (moveType == 'willpower_shield') {
      playerDamage = (guardian.attack * 0.85 * multiplier).round();
      playerHealed = (guardian.maxHp * 0.25).round();
      defenseMitigation = 0.35;
      logMessage = '🛡️ İrade Kalkanı & Probiyotik Onarım! +$playerHealed HP yenilendi ve $playerDamage karşı hasar verildi!';
    }

    final int newBossHp = max(0, boss.currentHp - playerDamage);
    final bool bossDefeated = newBossHp == 0;

    int bossDamage = 0;
    if (!bossDefeated) {
      final int rawBossDmg = max(6, boss.attack - (guardian.defense ~/ 3));
      bossDamage = (rawBossDmg * defenseMitigation).round();
    }

    final int newGuardianHp = (guardian.currentHp + playerHealed - bossDamage).clamp(1, guardian.maxHp);

    boss = boss.copyWith(
      currentHp: newBossHp,
      isDefeated: bossDefeated,
    );

    int gainedXp = bossDefeated ? boss.rewardXp : 15;
    int newXp = guardian.xp + gainedXp;
    int newLevel = guardian.level;
    int newMaxHp = guardian.maxHp;
    int newAtk = guardian.attack;
    int newDef = guardian.defense;

    if (newXp >= guardian.nextLevelXp) {
      newXp -= guardian.nextLevelXp;
      newLevel += 1;
      newMaxHp += 28;
      newAtk += 5;
      newDef += 4;
      logMessage = '$logMessage 🎉 ${guardian.name} Seviye $newLevel oldu!';
    }

    final BioCharacter updatedGuardian = guardian.copyWith(
      level: newLevel,
      xp: newXp,
      maxHp: newMaxHp,
      currentHp: bossDefeated ? newMaxHp : newGuardianHp,
      attack: newAtk,
      defense: newDef,
    );

    final List<BioCharacter> newGuardians = value.guardians
        .map((g) => g.id == updatedGuardian.id ? updatedGuardian : g)
        .toList();

    final List<ToxicBoss> newBossQueue = List<ToxicBoss>.from(value.bossQueue);
    newBossQueue[bossIdx] = boss;

    int newPersonalScore = value.personalOrganicScore;
    int newCrystals = value.bioCrystals;
    int newSeasonXp = value.seasonPassXp;

    if (bossDefeated) {
      newPersonalScore = (newPersonalScore + 3).clamp(0, 100);
      newCrystals += boss.rewardCrystals;
      newSeasonXp += boss.rewardXp;
      logMessage = '🏆 ZAFER! ${boss.name} (${boss.chemicalCode}) tamamen temizlendi! +${boss.rewardCrystals} Biyo-Kristal kazandın!';
    }

    value = value.copyWith(
      personalOrganicScore: newPersonalScore,
      bioCrystals: newCrystals,
      seasonPassXp: newSeasonXp,
      guardians: newGuardians,
      bossQueue: newBossQueue,
    );

    await _saveState();

    return DuelTurnResult(
      playerDamageDealt: playerDamage,
      bossDamageDealt: bossDamage,
      playerHealed: playerHealed,
      isSuperEffective: superEffective,
      isCriticalWillpower: boss.willpowerBonusApplied,
      bossDefeated: bossDefeated,
      playerDefeated: false,
      combatLog: logMessage,
      updatedBoss: boss,
      updatedGuardian: updatedGuardian,
    );
  }

  Future<void> selectGuardian(String guardianId) async {
    final target = value.guardians.firstWhere(
      (g) => g.id == guardianId,
      orElse: () => value.activeGuardian,
    );
    if (!target.isUnlocked) return;
    value = value.copyWith(selectedGuardianId: guardianId);
    await _saveState();
  }

  Future<bool> unlockGuardianWithCrystals(String guardianId, int cost) async {
    if (value.bioCrystals < cost && !value.hasOrganicPass) return false;
    final List<BioCharacter> updated = value.guardians.map((g) {
      if (g.id == guardianId) {
        return g.copyWith(isUnlocked: true);
      }
      return g;
    }).toList();

    value = value.copyWith(
      bioCrystals: value.hasOrganicPass ? value.bioCrystals : value.bioCrystals - cost,
      guardians: updated,
      selectedGuardianId: guardianId,
    );
    await _saveState();
    return true;
  }

  /// Step counter & smartwatch telemetry synchronization.
  /// Converts steps into Bio-Energy (+1 Energy per 1,000 steps) and progresses Detox Quests.
  Future<void> addSteps(int additionalSteps, {String? sourceDeviceName, bool? watchConnected}) async {
    if (additionalSteps <= 0 && watchConnected == null) return;

    final int updatedSteps = (value.dailySteps + additionalSteps).clamp(0, 100000);
    final int milestoneDelta = (updatedSteps ~/ 1000) - (value.lastConvertedStepMilestone ~/ 1000);
    final int gainedEnergy = max(0, milestoneDelta);

    int detoxTarget = value.activeDetoxTargetSteps;
    int detoxCurrent = value.detoxCurrentSteps;
    int scoreBonus = 0;
    String mood = value.avatarConfig.expressionMood;

    if (detoxTarget > 0) {
      detoxCurrent = (detoxCurrent + additionalSteps).clamp(0, detoxTarget);
      if (detoxCurrent >= detoxTarget) {
        detoxTarget = 0;
        detoxCurrent = 0;
        scoreBonus = 5;
        mood = 'energized';
      }
    }

    value = value.copyWith(
      dailySteps: updatedSteps,
      lastConvertedStepMilestone: (updatedSteps ~/ 1000) * 1000,
      bioEnergy: (value.bioEnergy + gainedEnergy).clamp(0, value.maxBioEnergy),
      bioCrystals: value.bioCrystals + (gainedEnergy * 10),
      personalOrganicScore: (value.personalOrganicScore + scoreBonus).clamp(0, 100),
      activeDetoxTargetSteps: detoxTarget,
      detoxCurrentSteps: detoxCurrent,
      smartwatchConnected: watchConnected ?? value.smartwatchConnected,
      smartwatchName: sourceDeviceName ?? value.smartwatchName,
      avatarConfig: value.avatarConfig.copyWith(expressionMood: mood),
      seasonPassXp: value.seasonPassXp + (additionalSteps ~/ 50),
    );
    await _saveState();
  }

  Future<void> updateBodyMetrics({
    required double heightCm,
    required double weightKg,
    int? dailyStepGoal,
  }) async {
    value = value.copyWith(
      heightCm: heightCm.clamp(100.0, 230.0),
      weightKg: weightKg.clamp(30.0, 220.0),
      dailyStepGoal: dailyStepGoal ?? value.dailyStepGoal,
    );
    await _saveState();
  }

  Future<void> updateAvatarConfig(PixarAvatarConfig config) async {
    value = value.copyWith(avatarConfig: config);
    await _saveState();
  }

  Future<void> activateOrganicPass() async {
    // Unlocks legendary guardians and boosts max energy
    final List<BioCharacter> unlockedAll = value.guardians
        .map((g) => g.copyWith(isUnlocked: true))
        .toList();
    value = value.copyWith(
      hasOrganicPass: true,
      maxBioEnergy: 20,
      bioEnergy: 20,
      bioCrystals: value.bioCrystals + 300,
      guardians: unlockedAll,
    );
    await _saveState();
  }

  Future<void> grantRewardedAdBonus({int crystals = 50, int energy = 3}) async {
    value = value.copyWith(
      bioCrystals: value.bioCrystals + crystals,
      bioEnergy: (value.bioEnergy + energy).clamp(0, value.maxBioEnergy),
      seasonPassXp: value.seasonPassXp + 50,
    );
    await _saveState();
  }

  Future<void> spawnPracticeBossIfEmpty() async {
    if (value.activeBosses.isNotEmpty) return;
    value = value.copyWith(
      bossQueue: [...defaultStarterBosses(), ...value.bossQueue.take(10)],
    );
    await _saveState();
  }
}
