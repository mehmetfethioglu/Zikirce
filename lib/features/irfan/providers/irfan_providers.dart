import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/zikir_seed_data.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/session/session_providers.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../gamification/services/daily_streak_service.dart';
import '../../zikir/providers/zikir_providers.dart';
import '../data/irfan_question_bank.dart';
import '../data/irfan_repository.dart';
import '../domain/irfan_models.dart';

/// Internal trigger to refresh [irfanDashboardProvider] whenever quiz state mutates.
final irfanRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Provides the full static question corpus.
final irfanQuestionBankProvider = Provider<List<IrfanQuestion>>((ref) {
  return IrfanQuestionBank.allQuestions;
});

/// Provides the session-aware [IrfanRepository].
final irfanRepositoryProvider = Provider<IrfanRepository>((ref) {
  return IrfanRepository();
});

/// Reactive summary provider powering the İrfan Meydanı Hub & Bismillah shortcut card.
final irfanDashboardProvider = FutureProvider<IrfanDashboardSummary>((ref) async {
  ref.watch(irfanRefreshTriggerProvider);
  final session = ref.watch(activeSessionProvider);
  final repo = ref.watch(irfanRepositoryProvider);
  return repo.loadDashboardSummary(sessionId: session.id);
});

/// Wallet & reward port (DIP) decoupling İrfan quiz logic from concrete Gamification providers.
abstract interface class IrfanWalletPort {
  Future<bool> spendGold(int amount);
  Future<bool> spendDiamonds(int amount);
  Future<void> addGold(int amount);
  Future<void> addDiamonds(int amount);
  Future<void> unlockBadgeById(String badgeId, String category);
  Future<void> recordDailyStreakActivity();
}

class _RiverpodIrfanWalletAdapter implements IrfanWalletPort {
  final Ref _ref;

  const _RiverpodIrfanWalletAdapter(this._ref);

  GamificationNotifier get _gamification =>
      _ref.read(gamificationNotifierProvider);

  @override
  Future<bool> spendGold(int amount) => _gamification.spendGold(amount);

  @override
  Future<bool> spendDiamonds(int amount) => _gamification.spendDiamonds(amount);

  @override
  Future<void> addGold(int amount) => _gamification.addGold(amount);

  @override
  Future<void> addDiamonds(int amount) => _gamification.addDiamonds(amount);

  @override
  Future<void> unlockBadgeById(String badgeId, String category) =>
      _gamification.unlockBadgeById(badgeId, category);

  @override
  Future<void> recordDailyStreakActivity() async {
    try {
      final db = _ref.read(databaseProvider);
      await DailyStreakService.recordDailyActivity(db);
    } catch (e) {
      debugPrint('[IrfanWalletAdapter] recordDailyStreakActivity error: $e');
    }
  }
}

/// Active quiz session controller managing entry fees, smart hourglass, jokers, rewards, and SM-2 updates.
final irfanQuizNotifierProvider =
    StateNotifierProvider<IrfanQuizNotifier, IrfanQuizSessionState>((ref) {
  return IrfanQuizNotifier(ref);
});

class IrfanQuizNotifier extends StateNotifier<IrfanQuizSessionState> {
  final Ref? _ref;
  final IrfanRepository? _overrideRepo;
  final IrfanWalletPort? _overrideWallet;
  final String Function()? _sessionIdResolver;
  final VoidCallback? _onDashboardChanged;
  final Random _rng;

  IrfanQuizNotifier(
    Ref ref, {
    Random? rng,
  })  : _ref = ref,
        _overrideRepo = null,
        _overrideWallet = null,
        _sessionIdResolver = null,
        _onDashboardChanged = null,
        _rng = rng ?? Random(),
        super(IrfanQuizSessionState.initial());

  /// Deterministic constructor for unit tests without a Riverpod container.
  IrfanQuizNotifier.forTesting({
    required IrfanRepository repository,
    required IrfanWalletPort wallet,
    String sessionId = 'test_session',
    VoidCallback? onDashboardChanged,
    Random? rng,
  })  : _ref = null,
        _overrideRepo = repository,
        _overrideWallet = wallet,
        _sessionIdResolver = (() => sessionId),
        _onDashboardChanged = onDashboardChanged,
        _rng = rng ?? Random(),
        super(IrfanQuizSessionState.initial());

  String get _sessionId =>
      _sessionIdResolver?.call() ?? _ref!.read(activeSessionProvider).id;

  IrfanRepository get _repo =>
      _overrideRepo ?? _ref!.read(irfanRepositoryProvider);

  IrfanWalletPort get _wallet =>
      _overrideWallet ?? _RiverpodIrfanWalletAdapter(_ref!);

  /// Starts today's 5-question Daily Wisdom session.
  /// First daily completion is free; subsequent rounds same day cost [IrfanEconomyConfig.extraDailyOrSm2DiamondCost].
  Future<bool> startDailyFive({DateTime? now}) async {
    final alreadyCompleted = await _repo.isDailyCompletedToday(
      sessionId: _sessionId,
      now: now,
    );
    int spentDiamonds = 0;
    if (alreadyCompleted) {
      const fee = IrfanEconomyConfig.extraDailyOrSm2DiamondCost;
      final paid = await _wallet.spendDiamonds(fee);
      if (!paid) return false;
      spentDiamonds = fee;
    }

    final questions = await _repo.selectDailyFive(
      sessionId: _sessionId,
      now: now,
      forceFresh: alreadyCompleted,
    );
    if (questions.isEmpty) {
      if (spentDiamonds > 0) {
        await _wallet.addDiamonds(spentDiamonds);
      }
      return false;
    }

    state = IrfanQuizSessionState(
      mode: IrfanSessionMode.dailyFive,
      activeTopic: null,
      activeTier: null,
      questions: questions,
      currentIndex: 0,
      isAnswered: false,
      eliminatedOptionIndices: const {},
      isHintRevealed: false,
      correctCount: 0,
      earnedGold: 0,
      earnedDiamonds: 0,
      spentGold: 0,
      spentDiamonds: spentDiamonds,
      remainingSeconds: IrfanEconomyConfig.initialSessionSeconds,
      isQuestionSwapped: false,
      isShieldUsedOnCurrent: false,
      isFinished: false,
    );
    return true;
  }

  /// Starts a topic & tier quiz session, charging the tier's Gold or Diamond entry fee.
  Future<bool> startTopicQuiz(
    IrfanTopic topic,
    IrfanTier tier, {
    int? farzId,
    bool useDiamonds = false,
  }) async {
    int spentGold = 0;
    int spentDiamonds = 0;

    if (useDiamonds && tier == IrfanTier.irfan) {
      const fee = IrfanEconomyConfig.irfanTierDiamondEntryCost;
      final paid = await _wallet.spendDiamonds(fee);
      if (!paid) return false;
      spentDiamonds = fee;
    } else {
      final fee = IrfanEconomyConfig.goldEntryCostForTier(tier);
      final paid = await _wallet.spendGold(fee);
      if (!paid) return false;
      spentGold = fee;
    }

    final questions = await _repo.selectTopicQuiz(
      sessionId: _sessionId,
      topic: topic,
      tier: tier,
      farzId: farzId,
    );
    if (questions.isEmpty) {
      if (spentGold > 0) await _wallet.addGold(spentGold);
      if (spentDiamonds > 0) await _wallet.addDiamonds(spentDiamonds);
      return false;
    }

    state = IrfanQuizSessionState(
      mode: IrfanSessionMode.topicTier,
      activeTopic: topic,
      activeTier: tier,
      questions: questions,
      currentIndex: 0,
      isAnswered: false,
      eliminatedOptionIndices: const {},
      isHintRevealed: false,
      correctCount: 0,
      earnedGold: 0,
      earnedDiamonds: 0,
      spentGold: spentGold,
      spentDiamonds: spentDiamonds,
      remainingSeconds: IrfanEconomyConfig.initialSessionSeconds,
      isQuestionSwapped: false,
      isShieldUsedOnCurrent: false,
      isFinished: false,
    );
    return true;
  }

  /// Starts an SM-2 spaced repetition review session.
  /// First SM-2 session each day is free; extra rounds same day cost [IrfanEconomyConfig.extraDailyOrSm2DiamondCost].
  Future<bool> startSm2Review({DateTime? now}) async {
    final freeUsedToday = await _repo.isSm2FreeUsedToday(
      sessionId: _sessionId,
      now: now,
    );
    int spentDiamonds = 0;
    if (freeUsedToday) {
      const fee = IrfanEconomyConfig.extraDailyOrSm2DiamondCost;
      final paid = await _wallet.spendDiamonds(fee);
      if (!paid) return false;
      spentDiamonds = fee;
    }

    final questions = await _repo.selectSm2Review(
      sessionId: _sessionId,
      now: now,
    );
    if (questions.isEmpty) {
      if (spentDiamonds > 0) {
        await _wallet.addDiamonds(spentDiamonds);
      }
      return false;
    }

    state = IrfanQuizSessionState(
      mode: IrfanSessionMode.sm2Review,
      activeTopic: null,
      activeTier: null,
      questions: questions,
      currentIndex: 0,
      isAnswered: false,
      eliminatedOptionIndices: const {},
      isHintRevealed: false,
      correctCount: 0,
      earnedGold: 0,
      earnedDiamonds: 0,
      spentGold: 0,
      spentDiamonds: spentDiamonds,
      remainingSeconds: IrfanEconomyConfig.initialSessionSeconds,
      isQuestionSwapped: false,
      isShieldUsedOnCurrent: false,
      isFinished: false,
    );
    return true;
  }

  /// Advances the Smart Hourglass by 1 second ONLY while actively thinking on an unanswered question.
  void tickSecond() {
    if (state.isFinished ||
        state.isAnswered ||
        state.questions.isEmpty ||
        state.remainingSeconds <= 0) {
      return;
    }
    state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
  }

  /// Purchases +30 seconds on the Smart Hourglass using Gold or Diamonds.
  Future<bool> extendSessionTime({bool useDiamonds = false}) async {
    if (state.isFinished || state.questions.isEmpty) return false;

    final int goldCost = useDiamonds ? 0 : IrfanEconomyConfig.timeExtensionGoldCost;
    final int diamondCost =
        useDiamonds ? IrfanEconomyConfig.timeExtensionDiamondCost : 0;

    final paid = useDiamonds
        ? await _wallet.spendDiamonds(diamondCost)
        : await _wallet.spendGold(goldCost);
    if (!paid) return false;

    state = state.copyWith(
      remainingSeconds:
          state.remainingSeconds + IrfanEconomyConfig.timeExtensionSeconds,
      spentGold: state.spentGold + goldCost,
      spentDiamonds: state.spentDiamonds + diamondCost,
    );
    return true;
  }

  /// Concludes the current session gracefully (e.g., if hourglass expires and user chooses to finish).
  Future<void> finishSessionEarly() async {
    if (state.isFinished) return;
    if (state.correctCount > 0 || state.currentIndex > 0) {
      await _wallet.recordDailyStreakActivity();
    }
    state = state.copyWith(isFinished: true);
    _notifyDashboardRefresh();
  }

  /// Submits a multiple-choice option index for the current question.
  Future<void> submitChoice(int index) async {
    if (state.isAnswered || state.isFinished || state.isTimeUp) return;
    final question = state.currentQuestion;
    if (question == null) return;
    final payload = question.payload;
    if (payload is! MultipleChoicePayload) return;
    if (index < 0 || index >= payload.options.length) return;
    if (state.eliminatedOptionIndices.contains(index)) return;

    final isCorrect = index == payload.correctIndex;
    await _finalizeQuestionSubmission(
      question: question,
      isCorrect: isCorrect,
      selectedChoiceIndex: index,
      selectedBoolAnswer: null,
      mistakesCount: isCorrect ? 0 : 1,
    );
  }

  /// Submits a True/False answer for the current question.
  Future<void> submitTrueFalse(bool val) async {
    if (state.isAnswered || state.isFinished || state.isTimeUp) return;
    final question = state.currentQuestion;
    if (question == null) return;
    final payload = question.payload;
    if (payload is! TrueFalsePayload) return;

    final isCorrect = val == payload.correctAnswer;
    await _finalizeQuestionSubmission(
      question: question,
      isCorrect: isCorrect,
      selectedChoiceIndex: null,
      selectedBoolAnswer: val,
      mistakesCount: isCorrect ? 0 : 1,
    );
  }

  /// Submits completion of a Matching question with the number of wrong pair attempts.
  Future<void> submitMatching({required int mistakesCount}) async {
    if (state.isAnswered || state.isFinished || state.isTimeUp) return;
    final question = state.currentQuestion;
    if (question == null) return;
    if (question.payload is! MatchingPayload) return;

    final safeMistakes = max(0, mistakesCount);
    final isCorrect = safeMistakes <= 1;
    await _finalizeQuestionSubmission(
      question: question,
      isCorrect: isCorrect,
      selectedChoiceIndex: null,
      selectedBoolAnswer: null,
      mistakesCount: safeMistakes,
    );
  }

  /// Eliminates two wrong options on a multiple-choice question in exchange for Gold or Diamonds.
  Future<bool> useFiftyFiftyJoker({bool useDiamonds = false}) async {
    if (state.isAnswered || state.isFinished || state.isTimeUp) return false;
    if (state.eliminatedOptionIndices.isNotEmpty) return false;
    final question = state.currentQuestion;
    if (question == null) return false;
    final payload = question.payload;
    if (payload is! MultipleChoicePayload || payload.options.length < 3) {
      return false;
    }

    final int goldCost =
        useDiamonds ? 0 : IrfanEconomyConfig.fiftyFiftyGoldCost;
    final int diamondCost =
        useDiamonds ? IrfanEconomyConfig.fiftyFiftyDiamondCost : 0;

    final paid = useDiamonds
        ? await _wallet.spendDiamonds(diamondCost)
        : await _wallet.spendGold(goldCost);
    if (!paid) return false;

    final wrongIndices = <int>[
      for (int i = 0; i < payload.options.length; i++)
        if (i != payload.correctIndex) i,
    ]..shuffle(_rng);

    final toEliminate = wrongIndices.take(min(2, wrongIndices.length)).toSet();
    state = state.copyWith(
      eliminatedOptionIndices: toEliminate,
      spentGold: state.spentGold + goldCost,
      spentDiamonds: state.spentDiamonds + diamondCost,
    );
    return true;
  }

  /// Reveals the pedagogical hint for the current question in exchange for Gold or Diamonds.
  Future<bool> useHintJoker({bool useDiamonds = false}) async {
    if (state.isAnswered ||
        state.isFinished ||
        state.isTimeUp ||
        state.isHintRevealed) {
      return false;
    }
    if (state.currentQuestion == null) return false;

    final int goldCost = useDiamonds ? 0 : IrfanEconomyConfig.hintGoldCost;
    final int diamondCost =
        useDiamonds ? IrfanEconomyConfig.hintDiamondCost : 0;

    final paid = useDiamonds
        ? await _wallet.spendDiamonds(diamondCost)
        : await _wallet.spendGold(goldCost);
    if (!paid) return false;

    state = state.copyWith(
      isHintRevealed: true,
      spentGold: state.spentGold + goldCost,
      spentDiamonds: state.spentDiamonds + diamondCost,
    );
    return true;
  }

  /// Replaces the current unanswered question with a fresh one in exchange for Diamonds.
  Future<bool> useSwapQuestionJoker() async {
    if (state.isAnswered ||
        state.isFinished ||
        state.isTimeUp ||
        state.isQuestionSwapped) {
      return false;
    }
    final current = state.currentQuestion;
    if (current == null) return false;

    final excludedIds = {for (final q in state.questions) q.id};
    final replacement = _repo.pickReplacementQuestion(
      current: current,
      excludedIds: excludedIds,
      rng: _rng,
    );
    if (replacement == null) return false;

    const diamondCost = IrfanEconomyConfig.swapOrShieldDiamondCost;
    final paid = await _wallet.spendDiamonds(diamondCost);
    if (!paid) return false;

    final updated = List<IrfanQuestion>.from(state.questions);
    updated[state.currentIndex] = replacement;
    state = state.copyWith(
      questions: updated,
      eliminatedOptionIndices: const {},
      isHintRevealed: false,
      isQuestionSwapped: true,
      spentDiamonds: state.spentDiamonds + diamondCost,
    );
    return true;
  }

  /// Uses the İrfan Shield (Diamonds) to redeem a wrong answer on the current question.
  Future<bool> useMistakeShield({DateTime? now}) async {
    if (!state.isAnswered ||
        state.isCurrentCorrect != false ||
        state.isFinished ||
        state.isShieldUsedOnCurrent) {
      return false;
    }
    final question = state.currentQuestion;
    if (question == null) return false;

    const diamondCost = IrfanEconomyConfig.swapOrShieldDiamondCost;
    final paid = await _wallet.spendDiamonds(diamondCost);
    if (!paid) return false;

    state = state.copyWith(
      isCurrentCorrect: true,
      correctCount: state.correctCount + 1,
      isShieldUsedOnCurrent: true,
      spentDiamonds: state.spentDiamonds + diamondCost,
    );

    final outcome = await _repo.applyMistakeShield(
      sessionId: _sessionId,
      question: question,
      mode: state.mode,
      now: now,
    );
    await _unlockEligibleBadges(outcome.newlyEligibleBadgeIds);
    _notifyDashboardRefresh();
    return true;
  }

  /// Advances to the next question or finalizes the session (granting daily bonus if eligible).
  Future<void> nextQuestion() async {
    if (!state.isAnswered || state.isFinished) return;

    final nextIdx = state.currentIndex + 1;
    if (nextIdx < state.questions.length) {
      state = state.copyWith(
        currentIndex: nextIdx,
        isAnswered: false,
        isCurrentCorrect: null,
        selectedChoiceIndex: null,
        selectedBoolAnswer: null,
        eliminatedOptionIndices: const {},
        isHintRevealed: false,
        isQuestionSwapped: false,
        isShieldUsedOnCurrent: false,
      );
      return;
    }

    int bonusGold = 0;
    int bonusDiamonds = 0;

    if (state.mode == IrfanSessionMode.dailyFive) {
      final dailyOutcome = await _repo.completeDailyFive(
        sessionId: _sessionId,
        correctCount: state.correctCount,
      );
      if (dailyOutcome.bonusAwardedNow) {
        bonusGold = IrfanEconomyConfig.dailyCompleteGoldBonus;
        bonusDiamonds = IrfanEconomyConfig.dailyCompleteDiamondBonus;
        await _wallet.addGold(bonusGold);
        await _wallet.addDiamonds(bonusDiamonds);
      }
      await _unlockEligibleBadges(dailyOutcome.newlyEligibleBadgeIds);
    }

    await _wallet.recordDailyStreakActivity();

    state = state.copyWith(
      isFinished: true,
      earnedGold: state.earnedGold + bonusGold,
      earnedDiamonds: state.earnedDiamonds + bonusDiamonds,
    );
    _notifyDashboardRefresh();
  }

  /// Activates a dhikr/esma/dua in the Zikir counter by matching [linkedZikirKey].
  Future<bool> activateLinkedZikir(String linkedZikirKey) async {
    final trimmed = linkedZikirKey.trim();
    if (trimmed.isEmpty || _ref == null) return false;

    try {
      final db = _ref.read(databaseProvider);
      final allZikirs = await db.select(db.zikirs).get();
      final normTarget = _normalizeLookup(trimmed);

      Zikir? match = allZikirs
          .where((z) => _normalizeLookup(z.name) == normTarget)
          .firstOrNull;
      match ??= allZikirs
          .where((z) =>
              _normalizeLookup(z.name).contains(normTarget) ||
              normTarget.contains(_normalizeLookup(z.name)))
          .firstOrNull;

      if (match != null) {
        await _ref.read(selectedZikirIdProvider.notifier).select(match.id);
        return true;
      }

      // Restore from seed data if deleted from user DB
      final seedMatch = ZikirSeedData.defaultZikirs
              .where((s) => _normalizeLookup(s.name) == normTarget)
              .firstOrNull ??
          ZikirSeedData.defaultZikirs
              .where((s) =>
                  _normalizeLookup(s.name).contains(normTarget) ||
                  normTarget.contains(_normalizeLookup(s.name)))
              .firstOrNull;
      if (seedMatch != null) {
        final insertedId = await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                name: seedMatch.name,
                arabic: Value(seedMatch.arabic),
                target: Value(seedMatch.target),
                category: Value(seedMatch.category),
                isFavorite: Value(seedMatch.isFavorite),
              ),
            );
        await _ref.read(selectedZikirIdProvider.notifier).select(insertedId);
        return true;
      }
    } catch (e) {
      debugPrint('[IrfanQuizNotifier] activateLinkedZikir error: $e');
    }
    return false;
  }

  Future<void> _finalizeQuestionSubmission({
    required IrfanQuestion question,
    required bool isCorrect,
    required int? selectedChoiceIndex,
    required bool? selectedBoolAnswer,
    required int mistakesCount,
  }) async {
    final rewardGold = isCorrect ? IrfanEconomyConfig.correctGoldReward : 0;
    if (rewardGold > 0) {
      await _wallet.addGold(rewardGold);
    }

    state = state.copyWith(
      isAnswered: true,
      isCurrentCorrect: isCorrect,
      selectedChoiceIndex: selectedChoiceIndex,
      selectedBoolAnswer: selectedBoolAnswer,
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      earnedGold: state.earnedGold + rewardGold,
    );

    final outcome = await _repo.recordQuestionAttempt(
      sessionId: _sessionId,
      question: question,
      mode: state.mode,
      isCorrect: isCorrect,
      usedHint: state.isHintRevealed,
      mistakesCount: mistakesCount,
    );
    await _unlockEligibleBadges(outcome.newlyEligibleBadgeIds);
    _notifyDashboardRefresh();
  }

  Future<void> _unlockEligibleBadges(Set<String> badgeIds) async {
    for (final badgeId in badgeIds) {
      await _wallet.unlockBadgeById(badgeId, 'Irfan');
    }
  }

  void _notifyDashboardRefresh() {
    if (_onDashboardChanged != null) {
      _onDashboardChanged();
      return;
    }
    _ref?.read(irfanRefreshTriggerProvider.notifier).state++;
  }

  static String _normalizeLookup(String raw) {
    return raw
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
  }
}
