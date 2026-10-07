import 'dart:math';

enum ScoreFactorCategory {
  additive,
  nutri,
  nova,
  personal,
}

class ScoreFactor {
  final String title;
  final int impact; // e.g. -25, -12, +15
  final ScoreFactorCategory category;
  final bool isPositive;
  final String description;
  final String? standardRef; // e.g. "WHO", "EFSA", "NOVA"

  const ScoreFactor({
    required this.title,
    required this.impact,
    required this.category,
    required this.isPositive,
    required this.description,
    this.standardRef,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'impact': impact,
        'category': category.name,
        'isPositive': isPositive,
        'description': description,
        'standardRef': standardRef,
      };
}

class NutrientProfile {
  final double sugarGrams;
  final double satFatGrams;
  final double sodiumGrams;
  final double fiberGrams;
  final double proteinGrams;

  const NutrientProfile({
    required this.sugarGrams,
    required this.satFatGrams,
    required this.sodiumGrams,
    required this.fiberGrams,
    required this.proteinGrams,
  });

  Map<String, dynamic> toMap() => {
        'sugar': sugarGrams,
        'satFat': satFatGrams,
        'sodium': sodiumGrams,
        'fiber': fiberGrams,
        'protein': proteinGrams,
      };
}

class PersonalSensitivityConfig {
  final String presetId; // 'custom', 'diabetes', 'clean_eating', 'heart_health', 'child_safe'
  final String sugarStrictness; // 'normal', 'moderate', 'strict'
  final String additiveStrictness; // 'normal', 'strict', 'zero_tolerance'
  final bool avoidPalmOil;
  final bool avoidNova4;
  final String sodiumStrictness; // 'normal', 'strict'

  const PersonalSensitivityConfig({
    this.presetId = 'custom',
    this.sugarStrictness = 'normal',
    this.additiveStrictness = 'normal',
    this.avoidPalmOil = false,
    this.avoidNova4 = false,
    this.sodiumStrictness = 'normal',
  });

  static const PersonalSensitivityConfig standard = PersonalSensitivityConfig();

  static const PersonalSensitivityConfig diabetes = PersonalSensitivityConfig(
    presetId: 'diabetes',
    sugarStrictness: 'strict',
    additiveStrictness: 'normal',
    avoidPalmOil: false,
    avoidNova4: true,
    sodiumStrictness: 'normal',
  );

  static const PersonalSensitivityConfig cleanEating = PersonalSensitivityConfig(
    presetId: 'clean_eating',
    sugarStrictness: 'moderate',
    additiveStrictness: 'zero_tolerance',
    avoidPalmOil: true,
    avoidNova4: true,
    sodiumStrictness: 'normal',
  );

  static const PersonalSensitivityConfig heartHealth = PersonalSensitivityConfig(
    presetId: 'heart_health',
    sugarStrictness: 'normal',
    additiveStrictness: 'normal',
    avoidPalmOil: true,
    avoidNova4: false,
    sodiumStrictness: 'strict',
  );

  static const PersonalSensitivityConfig childSafe = PersonalSensitivityConfig(
    presetId: 'child_safe',
    sugarStrictness: 'strict',
    additiveStrictness: 'strict',
    avoidPalmOil: true,
    avoidNova4: true,
    sodiumStrictness: 'normal',
  );

  Map<String, dynamic> toMap() => {
        'presetId': presetId,
        'sugarStrictness': sugarStrictness,
        'additiveStrictness': additiveStrictness,
        'avoidPalmOil': avoidPalmOil,
        'avoidNova4': avoidNova4,
        'sodiumStrictness': sodiumStrictness,
      };

  factory PersonalSensitivityConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PersonalSensitivityConfig();
    return PersonalSensitivityConfig(
      presetId: map['presetId'] as String? ?? 'custom',
      sugarStrictness: map['sugarStrictness'] as String? ?? 'normal',
      additiveStrictness: map['additiveStrictness'] as String? ?? 'normal',
      avoidPalmOil: map['avoidPalmOil'] == true || map['avoidPalmOil'] == 1,
      avoidNova4: map['avoidNova4'] == true || map['avoidNova4'] == 1,
      sodiumStrictness: map['sodiumStrictness'] as String? ?? 'normal',
    );
  }

  PersonalSensitivityConfig copyWith({
    String? presetId,
    String? sugarStrictness,
    String? additiveStrictness,
    bool? avoidPalmOil,
    bool? avoidNova4,
    String? sodiumStrictness,
  }) {
    return PersonalSensitivityConfig(
      presetId: presetId ?? this.presetId,
      sugarStrictness: sugarStrictness ?? this.sugarStrictness,
      additiveStrictness: additiveStrictness ?? this.additiveStrictness,
      avoidPalmOil: avoidPalmOil ?? this.avoidPalmOil,
      avoidNova4: avoidNova4 ?? this.avoidNova4,
      sodiumStrictness: sodiumStrictness ?? this.sodiumStrictness,
    );
  }
}

class PersonalMatchResult {
  final int matchPercentage; // 0 - 100
  final String statusLabel; // e.g. "Sağlık Profilinize Çok Uygun"
  final String profileName;
  final List<ScoreFactor> personalFactors;
  final bool hasCriticalViolation;

  const PersonalMatchResult({
    required this.matchPercentage,
    required this.statusLabel,
    required this.profileName,
    required this.personalFactors,
    this.hasCriticalViolation = false,
  });
}

class OrganicScoreResult {
  final int overallScore; // 0 - 100, or -1 for incomplete
  final double additiveScore;
  final double nutriScore;
  final double novaScore;
  final String ratingCategory; // Mükemmel, İyi, Orta Düzey, Düşük Kalite, Aşırı Zararlı, Doğrulanmadı
  final String novaVerdict;
  final bool isDataIncomplete;
  final List<ScoreFactor> factors;
  final NutrientProfile? nutrients;

  OrganicScoreResult({
    required this.overallScore,
    required this.additiveScore,
    required this.nutriScore,
    required this.novaScore,
    required this.ratingCategory,
    required this.novaVerdict,
    this.isDataIncomplete = false,
    this.factors = const [],
    this.nutrients,
  });

  static OrganicScoreResult incomplete({String? reason}) {
    return OrganicScoreResult(
      overallScore: -1,
      additiveScore: 0.0,
      nutriScore: 0.0,
      novaScore: 0.0,
      ratingCategory: 'İçerik Doğrulanmadı',
      novaVerdict: reason ?? 'İçindekiler Bilgisi Eksik',
      isDataIncomplete: true,
      factors: const [],
    );
  }
}

class OrganicScoreCalculator {
  static const double wAdditive = 0.40;
  static const double wNutri = 0.40;
  static const double wNova = 0.20;

  static OrganicScoreResult fromDirectScore(
    int score,
    int novaGroup, {
    String? verdict,
    bool isDataIncomplete = false,
    List<String>? detectedRisks,
    String? ingredientsText,
  }) {
    if (isDataIncomplete || score < 0) {
      return OrganicScoreResult.incomplete(reason: verdict);
    }
    double sNova = 20.0;
    String novaText = "Ultra İşlenmiş Gıda (NOVA 4)";
    if (novaGroup == 1) {
      sNova = 100.0;
      novaText = "İşlenmemiş / Organik (NOVA 1)";
    } else if (novaGroup == 2) {
      sNova = 80.0;
      novaText = "İşlenmiş Mutfak Malzemesi (NOVA 2)";
    } else if (novaGroup == 3) {
      sNova = 70.0;
      novaText = "İşlenmiş Gıda (NOVA 3)";
    } else {
      sNova = 20.0;
      novaText = "Ultra İşlenmiş Gıda (NOVA 4)";
    }

    final double derivedComponentScore = (1.25 * score - 0.25 * sNova).clamp(0.0, 100.0);

    String category = "Mükemmel";
    if (score < 30) {
      category = "Aşırı Zararlı";
    } else if (score < 50) {
      category = "Düşük Kalite";
    } else if (score < 70) {
      category = "Orta Düzey";
    } else if (score < 85) {
      category = "İyi";
    }

    // Generate representative transparent factors
    final List<ScoreFactor> factors = [];

    // Additive factor
    if (derivedComponentScore >= 80) {
      factors.add(const ScoreFactor(
        title: 'Temiz Katkı Profili',
        impact: 0,
        category: ScoreFactorCategory.additive,
        isPositive: true,
        description: 'Tehlikeli E-kodu veya yüksek riskli sentetik katkı tespit edilmedi.',
        standardRef: 'EFSA Standardı',
      ));
    } else if (derivedComponentScore < 50) {
      factors.add(ScoreFactor(
        title: 'Riskli Katkı Maddeleri',
        impact: -((100 - derivedComponentScore) * 0.4).round(),
        category: ScoreFactorCategory.additive,
        isPositive: false,
        description: 'Ürün formülünde sentetik koruyucu veya renklendirici riskleri mevcut.',
        standardRef: 'EFSA Risk Listesi',
      ));
    }

    // NOVA factor
    if (novaGroup == 1) {
      factors.add(const ScoreFactor(
        title: 'Doğal & İşlenmemiş (NOVA 1)',
        impact: 10,
        category: ScoreFactorCategory.nova,
        isPositive: true,
        description: 'Endüstriyel rafine işlem görmemiş, saf gıda yapısı.',
        standardRef: 'NOVA Standardı',
      ));
    } else if (novaGroup == 4) {
      factors.add(const ScoreFactor(
        title: 'Ultra-İşlenmiş Gıda (NOVA 4)',
        impact: -15,
        category: ScoreFactorCategory.nova,
        isPositive: false,
        description: 'Yüksek endüstriyel proses ve aroma vericiler içerir.',
        standardRef: 'NOVA Standardı',
      ));
    }

    // Nutri balance factor
    if (score >= 70) {
      factors.add(const ScoreFactor(
        title: 'Dengeli Besin Dağılımı',
        impact: 10,
        category: ScoreFactorCategory.nutri,
        isPositive: true,
        description: 'Makro besin dengesi genel sağlık kriterlerine uygun.',
        standardRef: 'Nutri-Score',
      ));
    } else {
      factors.add(ScoreFactor(
        title: 'Besin Değeri Kısıtları',
        impact: -((80 - derivedComponentScore).clamp(5, 30)).round(),
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'Şeker, doymuş yağ veya sodyum dengesizliği nedeniyle kesinti yapıldı.',
        standardRef: 'Nutri-Score',
      ));
    }

    return OrganicScoreResult(
      overallScore: score,
      additiveScore: derivedComponentScore,
      nutriScore: derivedComponentScore,
      novaScore: sNova,
      ratingCategory: category,
      novaVerdict: verdict ?? novaText,
      isDataIncomplete: false,
      factors: factors,
    );
  }

  static OrganicScoreResult calculate({
    required List<String> riskLevels, // List of 'LOW', 'MODERATE', 'HIGH', 'TOXIC'
    required double sugarGramsPer100g,
    required double satFatGramsPer100g,
    required double sodiumGramsPer100g,
    required double fiberGramsPer100g,
    required double proteinGramsPer100g,
    required int novaGroup, // 1, 2, 3, or 4
  }) {
    final List<ScoreFactor> factors = [];

    // 1. Calculate Additive Score (S_Additive)
    double rawAdditiveScore = 100.0;
    int toxicCount = 0;
    int highCount = 0;
    int modCount = 0;
    int lowCount = 0;

    for (String risk in riskLevels) {
      switch (risk.toUpperCase()) {
        case 'TOXIC':
          rawAdditiveScore -= 25.0;
          toxicCount++;
          break;
        case 'HIGH':
          rawAdditiveScore -= 20.0;
          highCount++;
          break;
        case 'MODERATE':
          rawAdditiveScore -= 10.0;
          modCount++;
          break;
        case 'LOW':
          rawAdditiveScore -= 2.0;
          lowCount++;
          break;
      }
    }
    final double sAdditive = max(0.0, min(100.0, rawAdditiveScore));

    if (toxicCount > 0) {
      factors.add(ScoreFactor(
        title: 'Toksik Katkı Maddesi ($toxicCount adet)',
        impact: -(toxicCount * 25),
        category: ScoreFactorCategory.additive,
        isPositive: false,
        description: 'Sağlık otoritelerince yüksek derecede sakıncalı bulunan katkılar.',
        standardRef: 'EFSA Risk Sınıfı',
      ));
    }
    if (highCount > 0) {
      factors.add(ScoreFactor(
        title: 'Yüksek Riskli Katkı ($highCount adet)',
        impact: -(highCount * 20),
        category: ScoreFactorCategory.additive,
        isPositive: false,
        description: 'Alerji, bağırsak florası veya hiperaktivite riski oluşturan E-kodları.',
        standardRef: 'EFSA Risk Sınıfı',
      ));
    }
    if (modCount > 0) {
      factors.add(ScoreFactor(
        title: 'Orta Riskli Katkı ($modCount adet)',
        impact: -(modCount * 10),
        category: ScoreFactorCategory.additive,
        isPositive: false,
        description: 'Düzenli tüketimde sınırlandırılması önerilen sentetik katkılar.',
        standardRef: 'EFSA / Gıda Kodeksi',
      ));
    }
    if (lowCount > 0) {
      factors.add(ScoreFactor(
        title: 'Düşük Riskli Katkı ($lowCount adet)',
        impact: -(lowCount * 2),
        category: ScoreFactorCategory.additive,
        isPositive: false,
        description: 'Genel olarak güvenli kabul edilen asgari riskli katkı maddeleri.',
        standardRef: 'EFSA Standardı',
      ));
    }
    if (toxicCount == 0 && highCount == 0 && modCount == 0 && lowCount == 0) {
      factors.add(const ScoreFactor(
        title: 'Katkısız / Temiz İçerik',
        impact: 0,
        category: ScoreFactorCategory.additive,
        isPositive: true,
        description: 'Zararlı kimyasal koruyucu veya yapay renklendirici içermez.',
        standardRef: 'Clean Label',
      ));
    }

    // 2. Calculate Nutri Score (S_Nutri)
    double rawNutriScore = 80.0;

    // Sugar
    if (sugarGramsPer100g > 15.0) {
      rawNutriScore -= 25.0;
      factors.add(ScoreFactor(
        title: 'Aşırı Yüksek Şeker (${sugarGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: -25,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'WHO günlük serbest şeker sınırının üzerinde, kan şekerini hızlı yükseltir.',
        standardRef: 'WHO Beslenme Kılavuzu',
      ));
    } else if (sugarGramsPer100g > 8.0) {
      rawNutriScore -= 12.0;
      factors.add(ScoreFactor(
        title: 'Yüksek Şeker Oranı (${sugarGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: -12,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'İlave şeker miktarı orta-yüksek seviyede.',
        standardRef: 'WHO Standardı',
      ));
    } else if (sugarGramsPer100g <= 3.0) {
      factors.add(ScoreFactor(
        title: 'Düşük Şeker / Doğal Yapı (${sugarGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: 5,
        category: ScoreFactorCategory.nutri,
        isPositive: true,
        description: 'İlave şeker içermeyen veya çok düşük şekerli sağlıklı yapı.',
        standardRef: 'Düşük Glisemik Standart',
      ));
    }

    // Saturated Fat
    if (satFatGramsPer100g > 5.0) {
      rawNutriScore -= 20.0;
      factors.add(ScoreFactor(
        title: 'Yüksek Doymuş Yağ (${satFatGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: -20,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'Kardiyovasküler sağlık için önerilen tavan sınırın üzerinde.',
        standardRef: 'AHA Kalp Kılavuzu',
      ));
    } else if (satFatGramsPer100g > 2.0) {
      rawNutriScore -= 10.0;
      factors.add(ScoreFactor(
        title: 'Orta Düzey Doymuş Yağ (${satFatGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: -10,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'Doymuş yağ oranı dikkat gerektiren seviyede.',
        standardRef: 'Nutri-Score',
      ));
    }

    // Sodium
    if (sodiumGramsPer100g > 0.6) {
      rawNutriScore -= 20.0;
      factors.add(ScoreFactor(
        title: 'Aşırı Yüksek Tuz / Sodyum (${sodiumGramsPer100g.toStringAsFixed(2)}g / 100g)',
        impact: -20,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'Tansiyon ve böbrek yükünü artıran yüksek sodyum oranı.',
        standardRef: 'WHO Hipertansiyon Sınırı',
      ));
    } else if (sodiumGramsPer100g > 0.3) {
      rawNutriScore -= 10.0;
      factors.add(ScoreFactor(
        title: 'Yüksek Sodyum (${sodiumGramsPer100g.toStringAsFixed(2)}g / 100g)',
        impact: -10,
        category: ScoreFactorCategory.nutri,
        isPositive: false,
        description: 'Tuz içeriği günlük porsiyon takibi gerektirir.',
        standardRef: 'Nutri-Score',
      ));
    }

    // Fiber Bonus
    if (fiberGramsPer100g >= 3.0) {
      rawNutriScore += 15.0;
      factors.add(ScoreFactor(
        title: 'Zengin Diyet Lifi (+${fiberGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: 15,
        category: ScoreFactorCategory.nutri,
        isPositive: true,
        description: 'Bağırsak mikrobiyotasını besler, kan şekerini dengeler.',
        standardRef: 'Besin Lif Referansı',
      ));
    }

    // Protein Bonus
    if (proteinGramsPer100g >= 5.0) {
      rawNutriScore += 15.0;
      factors.add(ScoreFactor(
        title: 'Yüksek Protein Değeri (+${proteinGramsPer100g.toStringAsFixed(1)}g / 100g)',
        impact: 15,
        category: ScoreFactorCategory.nutri,
        isPositive: true,
        description: 'Hücre yenilenmesini ve kas gelişimini destekleyen besleyici içerik.',
        standardRef: 'Protein Referansı',
      ));
    }

    final double sNutri = max(0.0, min(100.0, rawNutriScore));

    // 3. Calculate NOVA Score (S_NOVA)
    double sNova = 20.0;
    String novaVerdict = "Ultra İşlenmiş Gıda (NOVA 4)";
    switch (novaGroup) {
      case 1:
        sNova = 100.0;
        novaVerdict = "İşlenmemiş / Organik (NOVA 1)";
        factors.add(const ScoreFactor(
          title: 'Doğal & İşlenmemiş Gıda (NOVA 1)',
          impact: 20,
          category: ScoreFactorCategory.nova,
          isPositive: true,
          description: 'Hücre yapısı bozulmamış, doğrudan doğadan elde edilen gıda.',
          standardRef: 'NOVA Sınıflandırması',
        ));
        break;
      case 2:
        sNova = 80.0;
        novaVerdict = "İşlenmiş Mutfak Malzemesi (NOVA 2)";
        factors.add(const ScoreFactor(
          title: 'Mutfak Malzemesi (NOVA 2)',
          impact: 10,
          category: ScoreFactorCategory.nova,
          isPositive: true,
          description: 'Zeytinyağı, un, tuz gibi temel mutfak hazırlık içeriği.',
          standardRef: 'NOVA Sınıflandırması',
        ));
        break;
      case 3:
        sNova = 70.0;
        novaVerdict = "İşlenmiş Gıda (NOVA 3)";
        factors.add(const ScoreFactor(
          title: 'Geleneksel İşlenmiş Gıda (NOVA 3)',
          impact: 0,
          category: ScoreFactorCategory.nova,
          isPositive: true,
          description: 'Peynir, konserve gibi geleneksel yöntemlerle korunmuş gıda.',
          standardRef: 'NOVA Sınıflandırması',
        ));
        break;
      case 4:
      default:
        sNova = 20.0;
        novaVerdict = "Ultra İşlenmiş Gıda (NOVA 4)";
        factors.add(const ScoreFactor(
          title: 'Ultra İşlenmiş Endüstriyel Gıda (NOVA 4)',
          impact: -20,
          category: ScoreFactorCategory.nova,
          isPositive: false,
          description: 'Endüstriyel lezzet artırıcılar ve emülgatörlerle üretilmiştir.',
          standardRef: 'NOVA Sınıflandırması',
        ));
        break;
    }

    // Overall Weighted Calculation
    final double finalScoreDouble = (wAdditive * sAdditive) + (wNutri * sNutri) + (wNova * sNova);
    final int finalScore = max(0, min(100, finalScoreDouble.round()));

    String category = "Mükemmel";
    if (finalScore < 30) {
      category = "Aşırı Zararlı";
    } else if (finalScore < 50) {
      category = "Düşük Kalite";
    } else if (finalScore < 70) {
      category = "Orta Düzey";
    } else if (finalScore < 85) {
      category = "İyi";
    }

    return OrganicScoreResult(
      overallScore: finalScore,
      additiveScore: sAdditive,
      nutriScore: sNutri,
      novaScore: sNova,
      ratingCategory: category,
      novaVerdict: novaVerdict,
      factors: factors,
      nutrients: NutrientProfile(
        sugarGrams: sugarGramsPer100g,
        satFatGrams: satFatGramsPer100g,
        sodiumGrams: sodiumGramsPer100g,
        fiberGrams: fiberGramsPer100g,
        proteinGrams: proteinGramsPer100g,
      ),
    );
  }

  /// Calculates the Personal Match Result (%0 - %100) based on the user's sensitivity profile.
  static PersonalMatchResult evaluatePersonalMatch({
    required OrganicScoreResult scoreResult,
    required PersonalSensitivityConfig sensitivity,
    String profileName = 'Profilim',
    String rawIngredients = '',
    List<String> riskLevels = const [],
    List<String> activeProfileRestrictions = const [],
  }) {
    if (scoreResult.isDataIncomplete || scoreResult.overallScore < 0) {
      return PersonalMatchResult(
        matchPercentage: 0,
        statusLabel: 'İçerik Eksik (Hesaplanamadı)',
        profileName: profileName,
        personalFactors: const [
          ScoreFactor(
            title: 'Doğrulanmamış İçerik',
            impact: 0,
            category: ScoreFactorCategory.personal,
            isPositive: false,
            description: 'Ürünün içindekiler bilgisi doğrulanmadığı için uyum hesaplanamadı.',
          ),
        ],
      );
    }

    // Base match starts from the universal score
    double matchScore = scoreResult.overallScore.toDouble();
    final List<ScoreFactor> adjustments = [];
    bool hasCritical = false;
    final String lowerIngredients = rawIngredients.toLowerCase();

    // 1. Sugar Sensitivity
    final double sugar = scoreResult.nutrients?.sugarGrams ?? 0.0;
    final bool hasGlucose = lowerIngredients.contains('glikoz') ||
        lowerIngredients.contains('fruktoz') ||
        lowerIngredients.contains('mısır şurubu');

    if (sensitivity.sugarStrictness == 'strict') {
      if (sugar > 10.0 || hasGlucose) {
        matchScore -= 30;
        adjustments.add(ScoreFactor(
          title: 'Diyabet / Katı Şeker Uyarısı',
          impact: -30,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Profilinizdeki katı şeker filtresine göre ${sugar > 0 ? '${sugar.toStringAsFixed(1)}g şeker' : 'glikoz şurubu'} uygunsuzdur.',
        ));
      } else if (sugar > 5.0) {
        matchScore -= 15;
        adjustments.add(ScoreFactor(
          title: 'Orta Şeker Kısıtı',
          impact: -15,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Hassas şeker eşiğinizin hafif üzerinde.',
        ));
      } else {
        matchScore += 5;
        adjustments.add(const ScoreFactor(
          title: 'Şeker Tercihinize Uygun',
          impact: 5,
          category: ScoreFactorCategory.personal,
          isPositive: true,
          description: 'Şeker ve glikoz toleransınıza tam uyumlu.',
        ));
      }
    } else if (sensitivity.sugarStrictness == 'moderate') {
      if (sugar > 12.0 || hasGlucose) {
        matchScore -= 18;
        adjustments.add(ScoreFactor(
          title: 'Yüksek Şeker Kısıtlaması',
          impact: -18,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Kişisel şeker hassasiyetinizi aşıyor.',
        ));
      }
    }

    // 2. Additive Strictness
    if (sensitivity.additiveStrictness == 'zero_tolerance') {
      final bool hasAnyAdditive = riskLevels.isNotEmpty ||
          lowerIngredients.contains('koruyucu') ||
          lowerIngredients.contains('renklendirici') ||
          lowerIngredients.contains('emülgatör') ||
          RegExp(r'\b[Ee][\s\-\.]?\d{3,4}\b').hasMatch(lowerIngredients);

      if (hasAnyAdditive) {
        matchScore -= 35;
        adjustments.add(const ScoreFactor(
          title: 'Sıfır Katkı Kuralı İhlali',
          impact: -35,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Temiz beslenme profilinize aykırı sentetik katkı veya E-kodu mevcut.',
        ));
      } else {
        matchScore += 8;
        adjustments.add(const ScoreFactor(
          title: 'Tam Katkısız Uyum',
          impact: 8,
          category: ScoreFactorCategory.personal,
          isPositive: true,
          description: '%100 temiz ve katkısız gıda hedefinizle örtüşüyor.',
        ));
      }
    } else if (sensitivity.additiveStrictness == 'strict') {
      if (riskLevels.contains('HIGH') || riskLevels.contains('TOXIC') || riskLevels.contains('MODERATE')) {
        matchScore -= 20;
        adjustments.add(const ScoreFactor(
          title: 'Katkı Hassasiyeti İhlali',
          impact: -20,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Profilinizde kısıtlanan riskli katkı maddeleri mevcut.',
        ));
      }
    }

    // 3. Palm Oil Avoidance
    if (sensitivity.avoidPalmOil) {
      final bool hasPalm = lowerIngredients.contains('palm') ||
          lowerIngredients.contains('palmiye') ||
          lowerIngredients.contains('bitkisel yağ (palm)');
      if (hasPalm) {
        matchScore -= 25;
        adjustments.add(const ScoreFactor(
          title: 'Palm Yağı Hassasiyeti İhlali',
          impact: -25,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Profilinizde palmiye yağı istenmiyor olarak ayarlanmış.',
        ));
      } else {
        adjustments.add(const ScoreFactor(
          title: 'Palm Yağsız İçerik',
          impact: 5,
          category: ScoreFactorCategory.personal,
          isPositive: true,
          description: 'Ürün formülünde palmiye yağı tespit edilmedi.',
        ));
      }
    }

    // 4. NOVA 4 / Ultra-Processed Avoidance
    if (sensitivity.avoidNova4) {
      if (scoreResult.novaScore <= 30) {
        matchScore -= 25;
        adjustments.add(const ScoreFactor(
          title: 'Ultra-İşlenmiş Gıda Uyarısı',
          impact: -25,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Profiliniz endüstriyel ultra-işlenmiş gıdalardan uzak durmayı hedefler.',
        ));
      } else if (scoreResult.novaScore >= 80) {
        matchScore += 5;
        adjustments.add(const ScoreFactor(
          title: 'Doğal İşlenme Seviyesi',
          impact: 5,
          category: ScoreFactorCategory.personal,
          isPositive: true,
          description: 'Hafif veya işlenmemiş yapısıyla hedeflerinize uygun.',
        ));
      }
    }

    // 5. Sodium / Hypertension Strictness
    if (sensitivity.sodiumStrictness == 'strict') {
      final double sodium = scoreResult.nutrients?.sodiumGrams ?? 0.0;
      if (sodium > 0.3) {
        matchScore -= 25;
        adjustments.add(ScoreFactor(
          title: 'Tansiyon / Düşük Tuz Uyarısı',
          impact: -25,
          category: ScoreFactorCategory.personal,
          isPositive: false,
          description: 'Sodyum oranı (${sodium.toStringAsFixed(2)}g) kalp & tansiyon eşiğini aşıyor.',
        ));
      } else {
        matchScore += 5;
        adjustments.add(const ScoreFactor(
          title: 'Düşük Sodyum Uyumu',
          impact: 5,
          category: ScoreFactorCategory.personal,
          isPositive: true,
          description: 'Kalp ve tansiyon dostu tuz miktarı.',
        ));
      }
    }

    // 6. Family Profile Lifestyle / Allergen Red Lines
    for (final restriction in activeProfileRestrictions) {
      switch (restriction) {
        case 'GLUTEN':
          if (lowerIngredients.contains('gluten') ||
              lowerIngredients.contains('buğday') ||
              lowerIngredients.contains('arpa') ||
              lowerIngredients.contains('çavdar')) {
            hasCritical = true;
            matchScore = 0;
            adjustments.insert(0, const ScoreFactor(
              title: '⛔ KRİTİK: Gluten İhlali',
              impact: -100,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde gluten alerjisi aktif; bu ürün gluten içerir.',
            ));
          }
          break;
        case 'LACTOSE':
          if (lowerIngredients.contains('laktoz') ||
              lowerIngredients.contains('süt tozu') ||
              lowerIngredients.contains('peynir altı suyu')) {
            hasCritical = true;
            matchScore = min(matchScore, 20.0);
            adjustments.insert(0, const ScoreFactor(
              title: '⚠️ Laktoz / Süt Uyarısı',
              impact: -50,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde laktoz hassasiyeti aktif.',
            ));
          }
          break;
        case 'HALAL':
          if (lowerIngredients.contains('domuz') ||
              lowerIngredients.contains('jelatin') ||
              lowerIngredients.contains('alkol') ||
              lowerIngredients.contains('e120')) {
            hasCritical = true;
            matchScore = 0;
            adjustments.insert(0, const ScoreFactor(
              title: '⛔ Helal Hassasiyeti İhlali',
              impact: -100,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Jelatin, alkol veya şüpheli E120 karmin içeriyor.',
            ));
          }
          break;
        case 'SYNTHETIC_COLORS':
          final bool hasAzo = riskLevels.contains('HIGH') ||
              riskLevels.contains('TOXIC') ||
              lowerIngredients.contains('renklendirici') ||
              lowerIngredients.contains('tartrazin') ||
              lowerIngredients.contains('e102') ||
              lowerIngredients.contains('e110') ||
              lowerIngredients.contains('e122') ||
              lowerIngredients.contains('e124') ||
              lowerIngredients.contains('e129');
          if (hasAzo) {
            matchScore = min(matchScore, 30.0);
            adjustments.insert(0, const ScoreFactor(
              title: '⚠️ Sentetik Renklendirici İhlali',
              impact: -40,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde sentetik renklendirici kısıtlaması aktif; yapay gıda boyası tespit edildi.',
            ));
          }
          break;
        case 'HIGH_SUGAR':
          final double sugar = scoreResult.nutrients?.sugarGrams ?? 0.0;
          if (sugar > 10.0 || hasGlucose) {
            matchScore = min(matchScore, 40.0);
            adjustments.insert(0, const ScoreFactor(
              title: '⚠️ Şeker & Glikoz Şurubu İhlali',
              impact: -35,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde yüksek şeker kısıtlaması aktif; glikoz şurubu veya yüksek şeker tespit edildi.',
            ));
          }
          break;
        case 'PALM_OIL':
          final bool hasPalm = lowerIngredients.contains('palm') ||
              lowerIngredients.contains('palmiye') ||
              lowerIngredients.contains('bitkisel yağ (palm)');
          if (hasPalm) {
            matchScore = min(matchScore, 40.0);
            adjustments.insert(0, const ScoreFactor(
              title: '⚠️ Palmiye (Palm) Yağı İhlali',
              impact: -30,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde palm yağı kısıtlaması aktif; ürün formülünde palm yağı tespit edildi.',
            ));
          }
          break;
        case 'HIGH_SODIUM':
          final double sodium = scoreResult.nutrients?.sodiumGrams ?? 0.0;
          if (sodium > 0.4) {
            matchScore = min(matchScore, 50.0);
            adjustments.insert(0, ScoreFactor(
              title: '⚠️ Yüksek Sodyum / Tuz Uyarısı',
              impact: -30,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde tuz kısıtlaması aktif; sodyum oranı (${sodium.toStringAsFixed(2)}g) yüksek.',
            ));
          }
          break;
        case 'VEGAN':
          if (lowerIngredients.contains(' et ') ||
              lowerIngredients.contains('et ') ||
              lowerIngredients.contains('tavuk') ||
              lowerIngredients.contains('balık') ||
              lowerIngredients.contains('jelatin') ||
              lowerIngredients.contains('süt') ||
              lowerIngredients.contains('peynir') ||
              lowerIngredients.contains('tereyağ') ||
              lowerIngredients.contains('yumurta') ||
              lowerIngredients.contains('bal')) {
            hasCritical = true;
            matchScore = 0;
            adjustments.insert(0, const ScoreFactor(
              title: '⛔ KRİTİK: Vegan / Vejetaryen İhlali',
              impact: -100,
              category: ScoreFactorCategory.personal,
              isPositive: false,
              description: 'Profilinizde vegan kuralı aktif; hayvansal kökenli bileşen tespit edildi.',
            ));
          }
          break;
      }
    }

    final int finalPercentage = hasCritical && matchScore == 0
        ? 0
        : matchScore.round().clamp(0, 100);

    String statusLabel = 'Profilinize Çok Uygun';
    if (hasCritical || finalPercentage < 30) {
      statusLabel = 'Profilinizle Uyuşmuyor';
    } else if (finalPercentage < 60) {
      statusLabel = 'Düşük Uyum / Dikkat';
    } else if (finalPercentage < 80) {
      statusLabel = 'Kısmi Uyumlu';
    }

    return PersonalMatchResult(
      matchPercentage: finalPercentage,
      statusLabel: statusLabel,
      profileName: profileName,
      personalFactors: adjustments,
      hasCriticalViolation: hasCritical,
    );
  }
}
