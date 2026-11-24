import 'dart:convert';
import 'guided_flow_models.dart';

export 'guided_flow_models.dart';

/// Superead Pro tarzı 8 bilişsel hızlı okuma egzersiz ve antrenman türü
enum SpeedReadingExerciseType {
  rsvpOrp(
    id: 'rsvp_orp',
    title: 'ORP Odaklı Seri Okuma (RSVP)',
    shortTitle: 'RSVP + ORP',
    subtitle: 'Kırmızı odak harfi ve otomatik ivmelenme ile sakkadsız akış',
    cognitiveGoal: 'Sakkad süresini sıfırlama & içsesi susturma',
    xpReward: 55,
  ),
  overSpeedSprint(
    id: 'over_speed_sprint',
    title: '2x Aşırı Hız Sprinti (Otoyol Etkisi)',
    shortTitle: '2x Hız Sprinti',
    subtitle: '1x → 1.5x → 2x turbo fazlarıyla beyni yeni konfor hızına kalibre et',
    cognitiveGoal: 'Fonolojik içses duvarını kırma & nöral hız adaptasyonu',
    xpReward: 75,
  ),
  peripheralPyramid(
    id: 'peripheral_pyramid',
    title: 'Çevresel Görüş Piramidi',
    shortTitle: 'Görüş Piramidi',
    subtitle: 'Merkez çizgiye bakarak iki yana açılan kelime kanatlarını yakala',
    cognitiveGoal: 'Yatay parafoveal görme açısını 2.5 kat genişletme',
    xpReward: 65,
  ),
  schulteGrid(
    id: 'schulte_grid',
    title: 'Schulte Tablosu (Parafoveal Matris)',
    shortTitle: 'Schulte Tablosu',
    subtitle: 'Merkez odaktan ayrılmadan çevresel görüşle hedefleri sırayla bul',
    cognitiveGoal: 'Çevresel görüş & bilişsel tarama çevikliği',
    xpReward: 60,
  ),
  chunkPacer(
    id: 'chunk_pacer',
    title: 'Blok Okuma & Gölgeleme (Pacer)',
    shortTitle: 'Blok & Pacer',
    subtitle: 'Kelime öbeklerini spot ışığıyla takip et, geriye dönüşü engelle',
    cognitiveGoal: 'Fiksasyon sayısını azaltma & regresyonu sıfırlama',
    xpReward: 55,
  ),
  tachistoscope(
    id: 'tachistoscope',
    title: 'Takistoskop (Milisaniyelik Flaş Algı)',
    shortTitle: 'Takistoskop',
    subtitle: 'Kombo yaptıkça hızlanan flaş kelimelerle fotoğrafik algı refleksi',
    cognitiveGoal: 'Fiksasyon duraksamasını 35 ms altına indirme',
    xpReward: 65,
  ),
  saccadicEye(
    id: 'saccadic_eye',
    title: 'Sakkadik Göz Kasları Antrenörü',
    shortTitle: 'Göz Kasları',
    subtitle: '5 geometrik rotada 60 FPS akıcı hedef ve ritmik sıçrama takibi',
    cognitiveGoal: 'Ekstraoküler kas çevikliği & satır dönüş hızı',
    xpReward: 45,
  ),
  wpmComprehensionTest(
    id: 'wpm_comprehension',
    title: 'Hız & Anlama Seviye Tespit (E-WPM)',
    shortTitle: 'E-WPM Sınavı',
    subtitle: 'Kronometreli metin okuma ve 4 soruluk anlama doğruluğu karnesi',
    cognitiveGoal: 'Ham WPM × Anlama % = Gerçek Etkili Hız (E-WPM)',
    xpReward: 90,
  );

  final String id;
  final String title;
  final String shortTitle;
  final String subtitle;
  final String cognitiveGoal;
  final int xpReward;

  const SpeedReadingExerciseType({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.cognitiveGoal,
    required this.xpReward,
  });
}

/// Sakkadik göz egzersizi geometrik rotaları
enum SaccadicPattern {
  horizontal('Yatay Sıçrama (Sol–Sağ)', 'Satır içi hızlı sakkadik sıçrama'),
  vertical('Dikey Sütun (Üst–Alt)', 'Dar sütun tarama ve dikey esneklik'),
  zigzag('Zikzak (Satır Dönüşü)', 'Satır sonundan alt satır başına kayıpsız geçiş'),
  infinity('Sonsuzluk (∞ Lemniskat)', 'Altı göz kasını senkronize çalıştıran akış'),
  circular('Çevresel Daire', 'Periferik görme sınırlarını genişletme');

  final String label;
  final String description;
  const SaccadicPattern(this.label, this.description);
}

/// Schulte Tablosu modları
enum SchulteMode {
  classicNumbers('Klasik Sayılar (1→N)', 'Merkeze bakarak sayıları sırayla bul'),
  letters('Harf Dizisi (A→Z)', 'Alfabetik sırayla çevresel tarama'),
  dynamicShuffle('Dinamik Karışan', 'Her doğru dokunuşta tablo yeniden dizilir');

  final String label;
  final String description;
  const SchulteMode(this.label, this.description);
}

/// Hızlı okuma tekniklerini öğreten mikro-ders rehber modeli
class SpeedReadingTechniqueGuide {
  final String id;
  final String title;
  final String badge;
  final String bottleneckProblem;
  final String scientificSolution;
  final List<String> actionableSteps;
  final SpeedReadingExerciseType recommendedExercise;

  const SpeedReadingTechniqueGuide({
    required this.id,
    required this.title,
    required this.badge,
    required this.bottleneckProblem,
    required this.scientificSolution,
    required this.actionableSteps,
    required this.recommendedExercise,
  });
}

/// 21 Kademeli Serüven Durağı modeli
class SpeedReadingCourseDay {
  final int dayNumber;
  final int weekNumber;
  final String title;
  final String focusTopic;
  final int targetWpm;
  final int estimatedMinutes;
  final List<SpeedReadingExerciseType> drills;
  final String tipOfTheDay;

  const SpeedReadingCourseDay({
    required this.dayNumber,
    required this.weekNumber,
    required this.title,
    required this.focusTopic,
    required this.targetWpm,
    this.estimatedMinutes = 5,
    required this.drills,
    required this.tipOfTheDay,
  });
}

/// Okuma ve anlama testi sorusu
class ComprehensionQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const ComprehensionQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

/// Eğitim, serüven ve seviye tespit metni (Canlı kitap kesiti veya dinamik havuz)
class SpeedReadingPassage {
  final String id;
  final String title;
  final String author;
  final String category;
  final String difficulty;
  final String content;
  final List<ComprehensionQuestion> questions;
  final bool isFromUserBook;

  const SpeedReadingPassage({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.difficulty,
    required this.content,
    required this.questions,
    this.isFromUserBook = false,
  });

  int get wordCount => content
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
}

/// Tamamlanan antrenman kaydı
class SpeedDrillRecord {
  final SpeedReadingExerciseType type;
  final DateTime timestamp;
  final int achievedWpm;
  final int comprehensionPercent;
  final double durationSeconds;
  final String summaryLabel;
  final int earnedXp;

  const SpeedDrillRecord({
    required this.type,
    required this.timestamp,
    required this.achievedWpm,
    required this.comprehensionPercent,
    required this.durationSeconds,
    required this.summaryLabel,
    this.earnedXp = 50,
  });

  int get effectiveWpm =>
      ((achievedWpm * comprehensionPercent) / 100.0).round();

  Map<String, dynamic> toJson() => {
        'type': type.id,
        'timestamp': timestamp.toIso8601String(),
        'achievedWpm': achievedWpm,
        'comprehensionPercent': comprehensionPercent,
        'durationSeconds': durationSeconds,
        'summaryLabel': summaryLabel,
        'earnedXp': earnedXp,
      };

  factory SpeedDrillRecord.fromJson(Map<String, dynamic> json) {
    final typeId = json['type'] as String? ?? 'rsvp_orp';
    final matchedType = SpeedReadingExerciseType.values.firstWhere(
      (e) => e.id == typeId,
      orElse: () => SpeedReadingExerciseType.rsvpOrp,
    );
    return SpeedDrillRecord(
      type: matchedType,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      achievedWpm:
          ((json['achievedWpm'] as num?)?.toInt() ?? 220).clamp(60, 2000),
      comprehensionPercent:
          ((json['comprehensionPercent'] as num?)?.toInt() ?? 100)
              .clamp(0, 100),
      durationSeconds: ((json['durationSeconds'] as num?)?.toDouble() ?? 60.0)
          .clamp(1.0, 7200.0),
      summaryLabel: json['summaryLabel'] as String? ?? '',
      earnedXp: ((json['earnedXp'] as num?)?.toInt() ?? matchedType.xpReward)
          .clamp(10, 500),
    );
  }
}

/// Kıraat Mertebesi (Rütbe / Lig) bilgisi
class SpeedReadingRankInfo {
  final int level;
  final String title;
  final String subtitle;
  final String badgeEmoji;
  final int currentLevelMinXp;
  final int nextLevelXp;
  final double progressToNext;

  const SpeedReadingRankInfo({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.badgeEmoji,
    required this.currentLevelMinXp,
    required this.nextLevelXp,
    required this.progressToNext,
  });
}

/// Kullanıcının Hızlı Okuma Serüveni kalıcı ilerleme, kitap koordinasyonu ve kademe durumu
class SpeedReadingProgressState {
  final int baselineWpm;
  final int currentWpm;
  final int bestEffectiveWpm;
  final int averageComprehension;
  final double? bestSchulte5x5Seconds;
  final int bestTachistoscopeMs;
  final int activeStage; // 1..21 arası dinamik serüven kademesi (ilerler veya geriler)
  final Set<int> completedCourseDays;
  final int totalDrillsCompleted;
  final int totalTrainingMinutes;
  final int totalXp;
  final int dailyStreak;
  final String lastTrainingDateIso;
  final int todayDrillsCount;
  final int dailyGoalDrills;
  final int lastBookReadingWpm; // Kitap okurken ölçülen gerçek WPM
  final int previousBookReadingWpm; // Önceki kitap okuma hızı (düşüş tespiti için)
  final String? regressionReason; // Seri bozulması veya kitap hızı düşüşü açıklaması (geriye dönük uyum)
  final List<String> recentPassageIds; // Bayatlamayı önleyen son okunan metin ID'leri
  final List<SpeedDrillRecord> recentRecords;
  final int totalFasilsCompleted;
  final int longestFasilMinutes;
  final int todayFasilsCount;
  final String lastFasilDateIso;
  final String? welcomeBackMessage;
  final String lastDetectedDensityId;

  const SpeedReadingProgressState({
    this.baselineWpm = 210,
    this.currentWpm = 240,
    this.bestEffectiveWpm = 240,
    this.averageComprehension = 85,
    this.bestSchulte5x5Seconds,
    this.bestTachistoscopeMs = 150,
    this.activeStage = 1,
    this.completedCourseDays = const {},
    this.totalDrillsCompleted = 0,
    this.totalTrainingMinutes = 0,
    this.totalXp = 120,
    this.dailyStreak = 1,
    this.lastTrainingDateIso = '',
    this.todayDrillsCount = 0,
    this.dailyGoalDrills = 3,
    this.lastBookReadingWpm = 215,
    this.previousBookReadingWpm = 215,
    this.regressionReason,
    this.recentPassageIds = const [],
    this.recentRecords = const [],
    this.totalFasilsCompleted = 0,
    this.longestFasilMinutes = 0,
    this.todayFasilsCount = 0,
    this.lastFasilDateIso = '',
    this.welcomeBackMessage,
    this.lastDetectedDensityId = 'literary',
  });

  int get speedGrowthPercent {
    if (baselineWpm <= 0) return 0;
    final diff = currentWpm - baselineWpm;
    return ((diff / baselineWpm) * 100).round().clamp(0, 999);
  }

  /// Aktif serüven durağı (1..21)
  int get nextCourseDay => activeStage.clamp(1, 21);

  /// Kullanıcının kitap okuma hızından ve aktif kademesinden koordine edilen hedef antrenman hızı
  int get coordinatedTargetWpm {
    final bookBase = lastBookReadingWpm > 80 ? lastBookReadingWpm : currentWpm;
    final stageOffset = (nextCourseDay - 1) * 10;
    return ((bookBase * 1.18).round() + stageOffset).clamp(150, 750);
  }

  /// Metin yoğunluğuna ve kazanılan odak dayanıklılığına göre kalibre edilen hedef akış hızı
  int targetWpmForDensity(TextDensityTier tier) {
    final bookBase = lastBookReadingWpm > 80 ? lastBookReadingWpm : currentWpm;
    final staminaBonus = (longestFasilMinutes ~/ 5) * 6;
    return ((bookBase * 1.15 * tier.speedMultiplier) + staminaBonus)
        .round()
        .clamp(140, 750);
  }

  /// Günlük 1 kısa fasıl herkese açıktır; Pro kullanıcılar sınırsız fasıl başlatabilir
  bool canStartFreeFasilToday({required bool isPro}) =>
      isPro || todayFasilsCount < 1;

  /// Kazanılan en uzun kesintisiz odak dayanıklılığı (dk)
  int get staminaMasteryMinutes => longestFasilMinutes.clamp(0, 60);

  double get dailyGoalProgress => dailyGoalDrills <= 0
      ? 1.0
      : (todayDrillsCount / dailyGoalDrills).clamp(0.0, 1.0);

  bool get isDailyGoalCompleted => todayDrillsCount >= dailyGoalDrills;

  /// Yalnızca XP ile ilerleyen, asla gerilemeyen Kıraat Mertebesi
  SpeedReadingRankInfo get rankInfo {
    const tiers = [
      (1, 'Müptedi-i Kıraat', 'Odak ve ritim başlangıcı', '🌱', 0, 250),
      (2, 'Sâlik-i Nazar', 'Sabit bakış ve akıcı takip', '🔥', 250, 600),
      (3, 'Ehl-i Basiret', 'Genişleyen çevresel görüş', '⚡', 600, 1200),
      (4, 'Hâfız-ı Sürat', 'İçsessiz görsel-semantik okuma', '🦅', 1200, 2200),
      (5, 'Üstad-ı Mütalaa', 'Yüksek hızda derin kavrayış', '👑', 2200, 3600),
      (6, 'Kutb-u Kıraat', 'Bilişsel kıraat zirvesi', '🌌', 3600, 6000),
    ];

    for (final t in tiers) {
      final (lvl, title, sub, emoji, minXp, maxXp) = t;
      if (totalXp < maxXp || lvl == 6) {
        final span = (maxXp - minXp).clamp(1, 100000);
        final prog = ((totalXp - minXp) / span).clamp(0.0, 1.0);
        return SpeedReadingRankInfo(
          level: lvl,
          title: title,
          subtitle: sub,
          badgeEmoji: emoji,
          currentLevelMinXp: minXp,
          nextLevelXp: maxXp,
          progressToNext: prog,
        );
      }
    }

    return const SpeedReadingRankInfo(
      level: 1,
      title: 'Müptedi-i Kıraat',
      subtitle: 'Odak ve ritim başlangıcı',
      badgeEmoji: '🌱',
      currentLevelMinXp: 0,
      nextLevelXp: 250,
      progressToNext: 0.4,
    );
  }

  /// 5 Boyutlu Bilişsel Yetenek Endeksi (0..100)
  ({
    int focus,
    int peripheral,
    int reflex,
    int ocular,
    int comprehension,
  }) get cognitiveSkillScores {
    final focus = ((currentWpm / 550.0) * 100).round().clamp(35, 100);
    final peripheral = bestSchulte5x5Seconds != null
        ? ((45.0 / bestSchulte5x5Seconds!.clamp(12.0, 90.0)) * 75)
            .round()
            .clamp(40, 100)
        : (45 + completedCourseDays.length * 2).clamp(45, 95);
    final reflex =
        ((180 - bestTachistoscopeMs.clamp(20, 160)) * 0.62).round().clamp(38, 100);
    final ocular =
        (48 + (totalDrillsCompleted * 3) + (dailyStreak * 2)).clamp(42, 100);
    final comprehension = averageComprehension.clamp(40, 100);

    return (
      focus: focus,
      peripheral: peripheral,
      reflex: reflex,
      ocular: ocular,
      comprehension: comprehension,
    );
  }

  SpeedReadingProgressState copyWith({
    int? baselineWpm,
    int? currentWpm,
    int? bestEffectiveWpm,
    int? averageComprehension,
    double? bestSchulte5x5Seconds,
    int? bestTachistoscopeMs,
    int? activeStage,
    Set<int>? completedCourseDays,
    int? totalDrillsCompleted,
    int? totalTrainingMinutes,
    int? totalXp,
    int? dailyStreak,
    String? lastTrainingDateIso,
    int? todayDrillsCount,
    int? dailyGoalDrills,
    int? lastBookReadingWpm,
    int? previousBookReadingWpm,
    String? regressionReason,
    bool clearRegressionReason = false,
    List<String>? recentPassageIds,
    List<SpeedDrillRecord>? recentRecords,
    int? totalFasilsCompleted,
    int? longestFasilMinutes,
    int? todayFasilsCount,
    String? lastFasilDateIso,
    String? welcomeBackMessage,
    bool clearWelcomeBackMessage = false,
    String? lastDetectedDensityId,
  }) {
    return SpeedReadingProgressState(
      baselineWpm: baselineWpm ?? this.baselineWpm,
      currentWpm: currentWpm ?? this.currentWpm,
      bestEffectiveWpm: bestEffectiveWpm ?? this.bestEffectiveWpm,
      averageComprehension: averageComprehension ?? this.averageComprehension,
      bestSchulte5x5Seconds:
          bestSchulte5x5Seconds ?? this.bestSchulte5x5Seconds,
      bestTachistoscopeMs: bestTachistoscopeMs ?? this.bestTachistoscopeMs,
      activeStage: activeStage ?? this.activeStage,
      completedCourseDays: completedCourseDays ?? this.completedCourseDays,
      totalDrillsCompleted: totalDrillsCompleted ?? this.totalDrillsCompleted,
      totalTrainingMinutes: totalTrainingMinutes ?? this.totalTrainingMinutes,
      totalXp: totalXp ?? this.totalXp,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      lastTrainingDateIso: lastTrainingDateIso ?? this.lastTrainingDateIso,
      todayDrillsCount: todayDrillsCount ?? this.todayDrillsCount,
      dailyGoalDrills: dailyGoalDrills ?? this.dailyGoalDrills,
      lastBookReadingWpm: lastBookReadingWpm ?? this.lastBookReadingWpm,
      previousBookReadingWpm:
          previousBookReadingWpm ?? this.previousBookReadingWpm,
      regressionReason: clearRegressionReason
          ? null
          : (regressionReason ?? this.regressionReason),
      recentPassageIds: recentPassageIds ?? this.recentPassageIds,
      recentRecords: recentRecords ?? this.recentRecords,
      totalFasilsCompleted: totalFasilsCompleted ?? this.totalFasilsCompleted,
      longestFasilMinutes: longestFasilMinutes ?? this.longestFasilMinutes,
      todayFasilsCount: todayFasilsCount ?? this.todayFasilsCount,
      lastFasilDateIso: lastFasilDateIso ?? this.lastFasilDateIso,
      welcomeBackMessage: clearWelcomeBackMessage
          ? null
          : (welcomeBackMessage ?? this.welcomeBackMessage),
      lastDetectedDensityId:
          lastDetectedDensityId ?? this.lastDetectedDensityId,
    );
  }

  String toJsonString() {
    return jsonEncode({
      'baselineWpm': baselineWpm,
      'currentWpm': currentWpm,
      'bestEffectiveWpm': bestEffectiveWpm,
      'averageComprehension': averageComprehension,
      'bestSchulte5x5Seconds': bestSchulte5x5Seconds,
      'bestTachistoscopeMs': bestTachistoscopeMs,
      'activeStage': activeStage,
      'completedCourseDays': completedCourseDays.toList(),
      'totalDrillsCompleted': totalDrillsCompleted,
      'totalTrainingMinutes': totalTrainingMinutes,
      'totalXp': totalXp,
      'dailyStreak': dailyStreak,
      'lastTrainingDateIso': lastTrainingDateIso,
      'todayDrillsCount': todayDrillsCount,
      'dailyGoalDrills': dailyGoalDrills,
      'lastBookReadingWpm': lastBookReadingWpm,
      'previousBookReadingWpm': previousBookReadingWpm,
      'regressionReason': regressionReason,
      'recentPassageIds': recentPassageIds.take(15).toList(),
      'recentRecords': recentRecords.take(30).map((r) => r.toJson()).toList(),
      'totalFasilsCompleted': totalFasilsCompleted,
      'longestFasilMinutes': longestFasilMinutes,
      'todayFasilsCount': todayFasilsCount,
      'lastFasilDateIso': lastFasilDateIso,
      'welcomeBackMessage': welcomeBackMessage,
      'lastDetectedDensityId': lastDetectedDensityId,
    });
  }

  factory SpeedReadingProgressState.fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final daysList = (map['completedCourseDays'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((d) => d >= 1 && d <= 21)
          .toSet();
      final recordsList = (map['recentRecords'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .take(30)
          .map(SpeedDrillRecord.fromJson)
          .toList();
      final recentIds = (map['recentPassageIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .take(15)
          .toList();
      final rawSchulte = (map['bestSchulte5x5Seconds'] as num?)?.toDouble();

      final lastDateStr = map['lastTrainingDateIso'] as String? ?? '';
      final now = DateTime.now();
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final savedTodayCount =
          ((map['todayDrillsCount'] as num?)?.toInt() ?? 0).clamp(0, 500);
      final effectiveTodayCount =
          lastDateStr == todayKey ? savedTodayCount : 0;

      final lastFasilDateStr = map['lastFasilDateIso'] as String? ?? '';
      final savedTodayFasils =
          ((map['todayFasilsCount'] as num?)?.toInt() ?? 0).clamp(0, 500);
      final effectiveTodayFasils =
          lastFasilDateStr == todayKey ? savedTodayFasils : 0;

      int computedStage = 1;
      for (int d = 1; d <= 21; d++) {
        if (!daysList.contains(d)) {
          computedStage = d;
          break;
        }
      }
      final savedStage =
          ((map['activeStage'] as num?)?.toInt() ?? computedStage).clamp(1, 21);

      return SpeedReadingProgressState(
        baselineWpm:
            ((map['baselineWpm'] as num?)?.toInt() ?? 210).clamp(60, 1500),
        currentWpm:
            ((map['currentWpm'] as num?)?.toInt() ?? 240).clamp(60, 2000),
        bestEffectiveWpm: ((map['bestEffectiveWpm'] as num?)?.toInt() ?? 240)
            .clamp(60, 2000),
        averageComprehension:
            ((map['averageComprehension'] as num?)?.toInt() ?? 85)
                .clamp(0, 100),
        bestSchulte5x5Seconds: rawSchulte?.clamp(2.0, 600.0),
        bestTachistoscopeMs:
            ((map['bestTachistoscopeMs'] as num?)?.toInt() ?? 150)
                .clamp(15, 1000),
        activeStage: savedStage,
        completedCourseDays: daysList,
        totalDrillsCompleted:
            ((map['totalDrillsCompleted'] as num?)?.toInt() ?? 0)
                .clamp(0, 100000),
        totalTrainingMinutes:
            ((map['totalTrainingMinutes'] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000),
        totalXp:
            ((map['totalXp'] as num?)?.toInt() ?? 120).clamp(0, 10000000),
        dailyStreak:
            ((map['dailyStreak'] as num?)?.toInt() ?? 1).clamp(1, 3650),
        lastTrainingDateIso: lastDateStr,
        todayDrillsCount: effectiveTodayCount,
        dailyGoalDrills:
            ((map['dailyGoalDrills'] as num?)?.toInt() ?? 3).clamp(1, 20),
        lastBookReadingWpm:
            ((map['lastBookReadingWpm'] as num?)?.toInt() ?? 215)
                .clamp(60, 1200),
        previousBookReadingWpm:
            ((map['previousBookReadingWpm'] as num?)?.toInt() ?? 215)
                .clamp(60, 1200),
        regressionReason: map['regressionReason'] as String?,
        recentPassageIds: recentIds,
        recentRecords: recordsList,
        totalFasilsCompleted:
            ((map['totalFasilsCompleted'] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000),
        longestFasilMinutes:
            ((map['longestFasilMinutes'] as num?)?.toInt() ?? 0).clamp(0, 600),
        todayFasilsCount: effectiveTodayFasils,
        lastFasilDateIso: lastFasilDateStr,
        welcomeBackMessage: map['welcomeBackMessage'] as String?,
        lastDetectedDensityId:
            map['lastDetectedDensityId'] as String? ?? 'literary',
      );
    } catch (_) {
      return const SpeedReadingProgressState();
    }
  }
}
