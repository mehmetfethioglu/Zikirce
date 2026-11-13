import 'package:flutter/foundation.dart';

/// Bilingual immutable text container for Turkish and English content.
@immutable
class LocalizedText {
  final String tr;
  final String en;

  const LocalizedText({
    required this.tr,
    required this.en,
  });

  String resolve(bool isTr) => isTr ? tr : en;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          runtimeType == other.runtimeType &&
          tr == other.tr &&
          en == other.en;

  @override
  int get hashCode => Object.hash(tr, en);

  @override
  String toString() => tr;
}

/// Core knowledge pillars in İrfan Meydanı.
enum IrfanTopic {
  ilmihal32Farz,
  siyer,
  quran,
  esmaDua;

  String label(bool isTr) {
    return switch (this) {
      IrfanTopic.ilmihal32Farz =>
        isTr ? '32 Farz & İlmihal' : '32 Farz & Catechism',
      IrfanTopic.siyer => isTr ? 'Siyer-i Nebî' : 'Prophetic Biography',
      IrfanTopic.quran => isTr ? 'Kur\'ân & Sûreler' : 'Qur\'an & Surahs',
      IrfanTopic.esmaDua =>
        isTr ? 'Esmaü\'l-Hüsna & Dua' : 'Asma-ul Husna & Dua',
    };
  }

  String subtitle(bool isTr) {
    return switch (this) {
      IrfanTopic.ilmihal32Farz => isTr
          ? 'İman, İslam, Abdest, Gusül, Teyemmüm ve Namaz'
          : 'Faith, Islam, Wudu, Ghusl, Tayammum & Prayer',
      IrfanTopic.siyer => isTr
          ? 'Asr-ı Saadet, Hicret, Ashâb ve Peygamberler Tarihi'
          : 'Era of Bliss, Hijrah, Companions & Prophets',
      IrfanTopic.quran => isTr
          ? 'Sûre Faziletleri, Kıssalar, Âyetler ve Tecvid'
          : 'Surah Virtues, Parables, Verses & Tajweed',
      IrfanTopic.esmaDua => isTr
          ? '99 Güzel İsim, Nebevî Dualar ve Günlük Zikirler'
          : '99 Beautiful Names, Prophetic Duas & Daily Dhikr',
    };
  }

  String get emoji {
    return switch (this) {
      IrfanTopic.ilmihal32Farz => '🕌',
      IrfanTopic.siyer => '🌙',
      IrfanTopic.quran => '📖',
      IrfanTopic.esmaDua => '📿',
    };
  }
}

/// Progressive mastery levels per topic.
enum IrfanTier {
  baslangic,
  orta,
  irfan;

  String label(bool isTr) {
    return switch (this) {
      IrfanTier.baslangic => isTr ? 'Başlangıç' : 'Beginner',
      IrfanTier.orta => isTr ? 'Orta' : 'Intermediate',
      IrfanTier.irfan => isTr ? 'İrfan' : 'Mastery',
    };
  }
}

/// Madhhab scope indicator to uphold zero-controversy fiqh clarity.
enum IrfanMadhhabScope {
  common,
  hanafi,
  shafii,
  comparative;

  String? badgeLabel(bool isTr) {
    return switch (this) {
      IrfanMadhhabScope.common => null,
      IrfanMadhhabScope.hanafi => isTr ? 'Hanefî Fıkhı' : 'Hanafi Fiqh',
      IrfanMadhhabScope.shafii => isTr ? 'Şâfiî Fıkhı' : 'Shafi\'i Fiqh',
      IrfanMadhhabScope.comparative =>
        isTr ? 'Mukayeseli Fıkıh' : 'Comparative Fiqh',
    };
  }
}

/// Quiz execution modes in İrfan Meydanı.
enum IrfanSessionMode {
  dailyFive,
  topicTier,
  sm2Review;

  String label(bool isTr) {
    return switch (this) {
      IrfanSessionMode.dailyFive =>
        isTr ? 'Günün 5 İrfan Sorusu' : 'Daily 5 Wisdom Quiz',
      IrfanSessionMode.topicTier =>
        isTr ? 'İlim Halkası' : 'Circle of Knowledge',
      IrfanSessionMode.sm2Review =>
        isTr ? 'Hafıza Tekrarı (SM-2)' : 'Spaced Review (SM-2)',
    };
  }
}

/// Sealed question interaction payload supporting 3 pedagogical formats.
@immutable
sealed class IrfanQuestionPayload {
  const IrfanQuestionPayload();
}

/// 4-option (or N-option) multiple choice question payload.
final class MultipleChoicePayload extends IrfanQuestionPayload {
  final List<LocalizedText> options;
  final int correctIndex;

  const MultipleChoicePayload({
    required this.options,
    required this.correctIndex,
  });
}

/// True / False verification payload.
final class TrueFalsePayload extends IrfanQuestionPayload {
  final bool correctAnswer;

  const TrueFalsePayload({
    required this.correctAnswer,
  });
}

/// Concept-pair matching payload.
final class MatchingPayload extends IrfanQuestionPayload {
  final List<({LocalizedText left, LocalizedText right})> pairs;

  const MatchingPayload({
    required this.pairs,
  });
}

/// Post-answer wisdom card linking authentic sources, madhhab notes, and practice bridges.
@immutable
class IrfanHikmetCard {
  final LocalizedText explanation;
  final LocalizedText sourceRef;
  final LocalizedText? hanafiNote;
  final LocalizedText? shafiiNote;
  final String? linkedZikirKey;
  final int? linkedFarzId;
  final String? linkedBookId;

  const IrfanHikmetCard({
    required this.explanation,
    required this.sourceRef,
    this.hanafiNote,
    this.shafiiNote,
    this.linkedZikirKey,
    this.linkedFarzId,
    this.linkedBookId,
  });
}

/// Immutable domain entity representing a single verified İrfan question.
@immutable
class IrfanQuestion {
  final String id;
  final IrfanTopic topic;
  final IrfanTier tier;
  final IrfanMadhhabScope madhhabScope;
  final List<String> specialDayTags;
  final LocalizedText stem;
  final IrfanQuestionPayload payload;
  final LocalizedText hint;
  final IrfanHikmetCard hikmet;

  const IrfanQuestion({
    required this.id,
    required this.topic,
    required this.tier,
    this.madhhabScope = IrfanMadhhabScope.common,
    this.specialDayTags = const [],
    required this.stem,
    required this.payload,
    required this.hint,
    required this.hikmet,
  });
}

/// Balanced economy constants for hybrid entry fees, smart hourglass, jokers & rewards (Seçenek 1).
abstract final class IrfanEconomyConfig {
  /// İlim Halkaları giriş harçları (OCP Registry).
  static const Map<IrfanTier, int> tierGoldEntryCosts = {
    IrfanTier.baslangic: 40,
    IrfanTier.orta: 75,
    IrfanTier.irfan: 120,
  };
  static const int irfanTierDiamondEntryCost = 15;
  static const int extraDailyOrSm2DiamondCost = 5;

  /// Akıllı Kum Saati (Süre Paketi).
  static const int initialSessionSeconds = 90;
  static const int timeExtensionSeconds = 30;
  static const int timeExtensionGoldCost = 30;
  static const int timeExtensionDiamondCost = 5;

  /// Joker & Elmas İmtiyazları.
  static const int fiftyFiftyGoldCost = 40;
  static const int fiftyFiftyDiamondCost = 5;
  static const int hintGoldCost = 25;
  static const int hintDiamondCost = 3;
  static const int swapOrShieldDiamondCost = 5;

  /// Ödüller (soru başı altın kaldırıldı; günlük ilk tamamlama bonusu korundu).
  static const int correctGoldReward = 0;
  static const int dailyCompleteGoldBonus = 30;
  static const int dailyCompleteDiamondBonus = 1;

  static int goldEntryCostForTier(IrfanTier tier) =>
      tierGoldEntryCosts[tier] ?? 40;

  static String tierCostBadgeLabel(IrfanTier tier) {
    return switch (tier) {
      IrfanTier.baslangic => '40 🪙',
      IrfanTier.orta => '75 🪙',
      IrfanTier.irfan => '120🪙 / 15💎',
    };
  }
}

/// Aggregated overview model for the İrfan Meydanı hub & Bismillah shortcut card.
@immutable
class IrfanDashboardSummary {
  final bool isDailyCompleted;
  final bool isSm2FreeUsedToday;
  final int dailyCorrectCount;
  final String? activeThemeTag;
  final String? activeThemeLabelTr;
  final String? activeThemeLabelEn;
  final int dueSm2Count;
  final int totalSm2PoolCount;
  final int totalSolved;
  final int irfanStreakDays;
  final Map<(IrfanTopic, IrfanTier), double> masteryByNode;

  const IrfanDashboardSummary({
    required this.isDailyCompleted,
    this.isSm2FreeUsedToday = false,
    required this.dailyCorrectCount,
    this.activeThemeTag,
    this.activeThemeLabelTr,
    this.activeThemeLabelEn,
    required this.dueSm2Count,
    this.totalSm2PoolCount = 0,
    required this.totalSolved,
    this.irfanStreakDays = 0,
    required this.masteryByNode,
  });

  String? activeThemeLabel(bool isTr) =>
      isTr ? activeThemeLabelTr : activeThemeLabelEn;

  double masteryFor(IrfanTopic topic, IrfanTier tier) =>
      masteryByNode[(topic, tier)] ?? 0.0;
}

/// Immutable state of an active or completed İrfan quiz session.
@immutable
class IrfanQuizSessionState {
  final IrfanSessionMode mode;
  final IrfanTopic? activeTopic;
  final IrfanTier? activeTier;
  final List<IrfanQuestion> questions;
  final int currentIndex;
  final bool isAnswered;
  final bool? isCurrentCorrect;
  final int? selectedChoiceIndex;
  final bool? selectedBoolAnswer;
  final Set<int> eliminatedOptionIndices;
  final bool isHintRevealed;
  final int correctCount;
  final int earnedGold;
  final int earnedDiamonds;
  final int spentGold;
  final int spentDiamonds;
  final int remainingSeconds;
  final bool isQuestionSwapped;
  final bool isShieldUsedOnCurrent;
  final bool isFinished;

  const IrfanQuizSessionState({
    required this.mode,
    this.activeTopic,
    this.activeTier,
    required this.questions,
    required this.currentIndex,
    required this.isAnswered,
    this.isCurrentCorrect,
    this.selectedChoiceIndex,
    this.selectedBoolAnswer,
    required this.eliminatedOptionIndices,
    required this.isHintRevealed,
    required this.correctCount,
    required this.earnedGold,
    required this.earnedDiamonds,
    this.spentGold = 0,
    this.spentDiamonds = 0,
    this.remainingSeconds = IrfanEconomyConfig.initialSessionSeconds,
    this.isQuestionSwapped = false,
    this.isShieldUsedOnCurrent = false,
    required this.isFinished,
  });

  factory IrfanQuizSessionState.initial() {
    return const IrfanQuizSessionState(
      mode: IrfanSessionMode.dailyFive,
      questions: [],
      currentIndex: 0,
      isAnswered: false,
      eliminatedOptionIndices: {},
      isHintRevealed: false,
      correctCount: 0,
      earnedGold: 0,
      earnedDiamonds: 0,
      spentGold: 0,
      spentDiamonds: 0,
      remainingSeconds: IrfanEconomyConfig.initialSessionSeconds,
      isQuestionSwapped: false,
      isShieldUsedOnCurrent: false,
      isFinished: false,
    );
  }

  IrfanQuestion? get currentQuestion =>
      (currentIndex >= 0 && currentIndex < questions.length)
          ? questions[currentIndex]
          : null;

  bool get isTimeUp =>
      !isFinished &&
      !isAnswered &&
      questions.isNotEmpty &&
      remainingSeconds <= 0;

  String get formattedRemainingTime {
    final clamped = remainingSeconds.clamp(0, 3599);
    final mins = clamped ~/ 60;
    final secs = clamped % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (questions.isEmpty) return 0.0;
    if (isFinished) return 1.0;
    final completedSteps = currentIndex + (isAnswered ? 1 : 0);
    return (completedSteps / questions.length).clamp(0.0, 1.0);
  }

  List<String> get sessionLinkedZikirs {
    final seen = <String>{};
    final result = <String>[];
    for (final q in questions) {
      final raw = q.hikmet.linkedZikirKey?.trim();
      if (raw == null || raw.isEmpty) continue;
      final norm = raw
          .replaceAll('İ', 'i')
          .replaceAll('I', 'i')
          .toLowerCase()
          .replaceAll('\u0307', '')
          .replaceAll('â', 'a')
          .replaceAll('î', 'i')
          .replaceAll('û', 'u')
          .replaceAll('ı', 'i')
          .replaceAll('\'', '')
          .replaceAll('’', '')
          .replaceAll('‘', '')
          .trim();
      if (seen.add(norm)) {
        result.add(raw);
      }
    }
    return List.unmodifiable(result);
  }

  IrfanQuizSessionState copyWith({
    IrfanSessionMode? mode,
    Object? activeTopic = _unset,
    Object? activeTier = _unset,
    List<IrfanQuestion>? questions,
    int? currentIndex,
    bool? isAnswered,
    Object? isCurrentCorrect = _unset,
    Object? selectedChoiceIndex = _unset,
    Object? selectedBoolAnswer = _unset,
    Set<int>? eliminatedOptionIndices,
    bool? isHintRevealed,
    int? correctCount,
    int? earnedGold,
    int? earnedDiamonds,
    int? spentGold,
    int? spentDiamonds,
    int? remainingSeconds,
    bool? isQuestionSwapped,
    bool? isShieldUsedOnCurrent,
    bool? isFinished,
  }) {
    return IrfanQuizSessionState(
      mode: mode ?? this.mode,
      activeTopic: identical(activeTopic, _unset)
          ? this.activeTopic
          : activeTopic as IrfanTopic?,
      activeTier: identical(activeTier, _unset)
          ? this.activeTier
          : activeTier as IrfanTier?,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswered: isAnswered ?? this.isAnswered,
      isCurrentCorrect: identical(isCurrentCorrect, _unset)
          ? this.isCurrentCorrect
          : isCurrentCorrect as bool?,
      selectedChoiceIndex: identical(selectedChoiceIndex, _unset)
          ? this.selectedChoiceIndex
          : selectedChoiceIndex as int?,
      selectedBoolAnswer: identical(selectedBoolAnswer, _unset)
          ? this.selectedBoolAnswer
          : selectedBoolAnswer as bool?,
      eliminatedOptionIndices:
          eliminatedOptionIndices ?? this.eliminatedOptionIndices,
      isHintRevealed: isHintRevealed ?? this.isHintRevealed,
      correctCount: correctCount ?? this.correctCount,
      earnedGold: earnedGold ?? this.earnedGold,
      earnedDiamonds: earnedDiamonds ?? this.earnedDiamonds,
      spentGold: spentGold ?? this.spentGold,
      spentDiamonds: spentDiamonds ?? this.spentDiamonds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isQuestionSwapped: isQuestionSwapped ?? this.isQuestionSwapped,
      isShieldUsedOnCurrent:
          isShieldUsedOnCurrent ?? this.isShieldUsedOnCurrent,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  static const Object _unset = Object();
}

/// Persisted SM-2 spaced repetition state for an individual question.
@immutable
class IrfanSm2CardRecord {
  final String questionId;
  final int repetitions;
  final int intervalDays;
  final double easeFactor;
  final DateTime nextReviewDate;
  final DateTime lastReviewedAt;

  const IrfanSm2CardRecord({
    required this.questionId,
    required this.repetitions,
    required this.intervalDays,
    required this.easeFactor,
    required this.nextReviewDate,
    required this.lastReviewedAt,
  });

  bool isDue([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return !nextReviewDate.isAfter(now);
  }

  Map<String, dynamic> toJson() => {
        'q': questionId,
        'r': repetitions,
        'i': intervalDays,
        'e': easeFactor,
        'n': nextReviewDate.toIso8601String(),
        'l': lastReviewedAt.toIso8601String(),
      };

  static IrfanSm2CardRecord? tryFromJson(Map<String, dynamic> json) {
    final qId = json['q'] as String?;
    final nextStr = json['n'] as String?;
    final lastStr = json['l'] as String?;
    if (qId == null || nextStr == null || lastStr == null) return null;
    final nextDt = DateTime.tryParse(nextStr);
    final lastDt = DateTime.tryParse(lastStr);
    if (nextDt == null || lastDt == null) return null;
    return IrfanSm2CardRecord(
      questionId: qId,
      repetitions: (json['r'] as num?)?.toInt() ?? 0,
      intervalDays: (json['i'] as num?)?.toInt() ?? 1,
      easeFactor: (json['e'] as num?)?.toDouble() ?? 2.5,
      nextReviewDate: nextDt,
      lastReviewedAt: lastDt,
    );
  }
}
