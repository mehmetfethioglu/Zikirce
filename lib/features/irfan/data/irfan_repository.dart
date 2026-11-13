import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/islamic_special_days_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/spaced_repetition_sm2.dart';
import '../domain/irfan_models.dart';
import 'irfan_question_bank.dart';

/// Storage abstraction (DIP) decoupling domain persistence from concrete SharedPreferences.
abstract interface class IrfanStoragePort {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

/// Concrete SharedPreferences adapter implementing [IrfanStoragePort].
class SharedPrefsIrfanStorage implements IrfanStoragePort {
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> _prefs() =>
      _prefsFuture ??= SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs()).getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await (await _prefs()).setString(key, value);
  }

  @override
  Future<int?> getInt(String key) async => (await _prefs()).getInt(key);

  @override
  Future<void> setInt(String key, int value) async {
    await (await _prefs()).setInt(key, value);
  }

  @override
  Future<bool?> getBool(String key) async => (await _prefs()).getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await (await _prefs()).setBool(key, value);
  }
}

/// Question corpus port (DIP) enabling deterministic testing and clean layering.
abstract interface class IrfanQuestionSource {
  List<IrfanQuestion> get allQuestions;
  IrfanQuestion? byId(String id);
  List<IrfanQuestion> byNode(IrfanTopic topic, IrfanTier tier);
  List<IrfanQuestion> byFarzId(int farzId);
  List<IrfanQuestion> byThemeTags(Set<String> tags);
}

/// Default corpus adapter backed by [IrfanQuestionBank].
class DefaultIrfanQuestionSource implements IrfanQuestionSource {
  const DefaultIrfanQuestionSource();

  @override
  List<IrfanQuestion> get allQuestions => IrfanQuestionBank.allQuestions;

  @override
  IrfanQuestion? byId(String id) => IrfanQuestionBank.byId(id);

  @override
  List<IrfanQuestion> byNode(IrfanTopic topic, IrfanTier tier) =>
      IrfanQuestionBank.byNode(topic, tier);

  @override
  List<IrfanQuestion> byFarzId(int farzId) => IrfanQuestionBank.byFarzId(farzId);

  @override
  List<IrfanQuestion> byThemeTags(Set<String> tags) =>
      IrfanQuestionBank.byThemeTags(tags);
}

/// Result returned when recording a single question attempt.
@immutable
class IrfanAnswerOutcome {
  final Set<String> newlyEligibleBadgeIds;

  const IrfanAnswerOutcome({
    this.newlyEligibleBadgeIds = const {},
  });
}

/// Result returned when completing the Daily 5 session.
@immutable
class IrfanDailyCompletionOutcome {
  final bool bonusAwardedNow;
  final int updatedStreakDays;
  final Set<String> newlyEligibleBadgeIds;

  const IrfanDailyCompletionOutcome({
    required this.bonusAwardedNow,
    required this.updatedStreakDays,
    this.newlyEligibleBadgeIds = const {},
  });
}

/// Session-isolated repository orchestrating Daily 5 themes, SM-2 schedules, and mastery.
class IrfanRepository {
  static const int _maxBoundedEntries = 512;
  static const int _dailyQuestionTarget = 5;
  static const int _topicSessionTarget = 10;
  static const int _sm2SessionTarget = 10;

  /// OCP Registry mapping [IslamicSpecialDay.id] to corpus [IrfanQuestion.specialDayTags].
  static const Map<String, List<String>> _specialDayTagRegistry = {
    'cuma': ['cuma'],
    'ramazan': ['ramazan'],
    'ramazan_bayrami': ['ramazan', 'bayram'],
    'kurban_bayrami': ['kurban', 'bayram'],
    'kadir': ['kadir', 'ramazan', 'kandil'],
    'mirac': ['mirac', 'kandil'],
    'mevlid': ['mevlid', 'kandil'],
    'berat': ['berat', 'kandil'],
    'regaip': ['regaip', 'kandil'],
    'kandil_genel': ['kandil'],
    'uc_aylar': ['regaip', 'kandil', 'ramazan'],
    'asure': ['asure'],
    'hicri_yilbasi': ['hicret', 'asure'],
  };

  final IrfanStoragePort _storage;
  final IrfanQuestionSource _source;

  IrfanRepository({
    IrfanStoragePort? storage,
    IrfanQuestionSource? source,
  })  : _storage = storage ?? SharedPrefsIrfanStorage(),
        _source = source ?? const DefaultIrfanQuestionSource();

  bool _isDefaultSession(String sessionId) =>
      sessionId.isEmpty || sessionId == UserSession.defaultSessionId;

  String _key(String base, String sessionId) =>
      _isDefaultSession(sessionId) ? base : '${base}_$sessionId';

  static String formatDateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<String?> _readSessionString(String base, String sessionId) async {
    final primary = await _storage.getString(_key(base, sessionId));
    if (primary != null || !_isDefaultSession(sessionId)) return primary;
    return _storage.getString(base);
  }

  Future<void> _writeSessionString(
    String base,
    String sessionId,
    String value,
  ) async {
    await _storage.setString(_key(base, sessionId), value);
    if (_isDefaultSession(sessionId)) {
      await _storage.setString(base, value);
    }
  }

  Future<int> _readSessionInt(String base, String sessionId) async {
    final primary = await _storage.getInt(_key(base, sessionId));
    if (primary != null) return primary;
    if (_isDefaultSession(sessionId)) {
      return (await _storage.getInt(base)) ?? 0;
    }
    return 0;
  }

  Future<void> _writeSessionInt(String base, String sessionId, int value) async {
    await _storage.setInt(_key(base, sessionId), value);
    if (_isDefaultSession(sessionId)) {
      await _storage.setInt(base, value);
    }
  }

  Future<bool> _readSessionBool(String base, String sessionId) async {
    final primary = await _storage.getBool(_key(base, sessionId));
    if (primary != null) return primary;
    if (_isDefaultSession(sessionId)) {
      return (await _storage.getBool(base)) ?? false;
    }
    return false;
  }

  Future<void> _writeSessionBool(
    String base,
    String sessionId,
    bool value,
  ) async {
    await _storage.setBool(_key(base, sessionId), value);
    if (_isDefaultSession(sessionId)) {
      await _storage.setBool(base, value);
    }
  }

  /// Builds the full dashboard summary for the active user session.
  Future<IrfanDashboardSummary> loadDashboardSummary({
    required String sessionId,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final todayStr = formatDateKey(clock);

    final solvedSet = await _loadStringSet('Irfan_SolvedIds', sessionId);
    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final sm2Map = await _loadSm2Cards(sessionId);

    final specialDay = IslamicSpecialDaysService.getSpecialDay(clock);
    final savedDailyDate = await _readSessionString('Irfan_DailyDate', sessionId);
    final isTodaySaved = savedDailyDate == todayStr;
    final isDailyCompleted = isTodaySaved &&
        await _readSessionBool('Irfan_DailyCompleted', sessionId);
    final dailyCorrectCount = isTodaySaved
        ? await _readSessionInt('Irfan_DailyCorrect', sessionId)
        : 0;

    int dueSm2Count = 0;
    for (final card in sm2Map.values) {
      if (card.isDue(clock) && _source.byId(card.questionId) != null) {
        dueSm2Count++;
      }
    }

    final validPoolCount = sm2Map.keys
        .where((id) => _source.byId(id) != null)
        .length;

    final masteryByNode = <(IrfanTopic, IrfanTier), double>{};
    for (final topic in IrfanTopic.values) {
      for (final tier in IrfanTier.values) {
        final nodeQuestions = _source.byNode(topic, tier);
        if (nodeQuestions.isEmpty) {
          masteryByNode[(topic, tier)] = 0.0;
          continue;
        }
        int masteredInNode = 0;
        for (final q in nodeQuestions) {
          if (masteredSet.contains(q.id)) {
            masteredInNode++;
          }
        }
        masteryByNode[(topic, tier)] =
            (masteredInNode / nodeQuestions.length).clamp(0.0, 1.0);
      }
    }

    final activeStreak = await _resolveActiveStreak(sessionId, clock);
    final persistedSolved = await _readSessionInt('Irfan_TotalSolved', sessionId);
    final totalSolved = max(solvedSet.length, persistedSolved);
    final sm2UsedToday = await isSm2FreeUsedToday(sessionId: sessionId, now: clock);

    return IrfanDashboardSummary(
      isDailyCompleted: isDailyCompleted,
      isSm2FreeUsedToday: sm2UsedToday,
      dailyCorrectCount: dailyCorrectCount,
      activeThemeTag: specialDay?.id,
      activeThemeLabelTr: specialDay != null
          ? '${specialDay.emoji} ${specialDay.titleTr} Özel'
          : null,
      activeThemeLabelEn: specialDay != null
          ? '${specialDay.emoji} ${specialDay.titleEn} Special'
          : null,
      dueSm2Count: dueSm2Count,
      totalSm2PoolCount: validPoolCount,
      totalSolved: totalSolved,
      irfanStreakDays: activeStreak,
      masteryByNode: masteryByNode,
    );
  }

  /// Returns true if today's free Daily 5 Wisdom Circle has already been completed.
  Future<bool> isDailyCompletedToday({
    required String sessionId,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final todayStr = formatDateKey(clock);
    final savedDailyDate = await _readSessionString('Irfan_DailyDate', sessionId);
    if (savedDailyDate != todayStr) return false;
    return _readSessionBool('Irfan_DailyCompleted', sessionId);
  }

  /// Returns true if today's free SM-2 Spaced Repetition session has already been used.
  Future<bool> isSm2FreeUsedToday({
    required String sessionId,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final todayStr = formatDateKey(clock);
    final usedDate = await _readSessionString('Irfan_Sm2FreeUsedDate', sessionId);
    return usedDate == todayStr;
  }

  /// Selects the 5 Daily Wisdom questions (cached for the first daily run; fresh when [forceFresh] is true).
  Future<List<IrfanQuestion>> selectDailyFive({
    required String sessionId,
    DateTime? now,
    bool forceFresh = false,
  }) async {
    final clock = now ?? DateTime.now();
    final todayStr = formatDateKey(clock);

    final savedDate = await _readSessionString('Irfan_DailyDate', sessionId);
    if (!forceFresh && savedDate == todayStr) {
      final cachedIds = await _loadStringList('Irfan_DailyQuestionIds', sessionId);
      final resolved = cachedIds
          .map(_source.byId)
          .whereType<IrfanQuestion>()
          .toList();
      if (resolved.length == _dailyQuestionTarget) {
        return resolved;
      }
    }

    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final rng = forceFresh ? Random() : Random(_seedForDay(todayStr, sessionId));
    final picked = <IrfanQuestion>[];
    final pickedIds = <String>{};

    void tryAddFromPool(List<IrfanQuestion> pool, int maxCount) {
      if (pool.isEmpty || maxCount <= 0) return;
      final unseen = pool
          .where((q) => !pickedIds.contains(q.id) && !masteredSet.contains(q.id))
          .toList()
        ..shuffle(rng);
      final seen = pool
          .where((q) => !pickedIds.contains(q.id) && masteredSet.contains(q.id))
          .toList()
        ..shuffle(rng);
      final ordered = [...unseen, ...seen];
      for (final q in ordered) {
        if (picked.length >= _dailyQuestionTarget || maxCount <= 0) break;
        picked.add(q);
        pickedIds.add(q.id);
        maxCount--;
      }
    }

    // 1. Special day thematic priority (up to 3 questions)
    final specialDay = IslamicSpecialDaysService.getSpecialDay(clock);
    if (specialDay != null) {
      final tags = (_specialDayTagRegistry[specialDay.id] ?? [specialDay.id]).toSet();
      final themedPool = _source.byThemeTags(tags);
      tryAddFromPool(themedPool, 3);
    }

    // 2. Balanced coverage across all 4 topics
    final topicsShuffled = List<IrfanTopic>.from(IrfanTopic.values)..shuffle(rng);
    for (final topic in topicsShuffled) {
      if (picked.length >= _dailyQuestionTarget) break;
      final topicPool = _source.allQuestions
          .where((q) => q.topic == topic)
          .toList();
      tryAddFromPool(topicPool, 1);
    }

    // 3. Fill any remaining slots from entire bank
    if (picked.length < _dailyQuestionTarget) {
      tryAddFromPool(_source.allQuestions, _dailyQuestionTarget - picked.length);
    }

    if (!forceFresh) {
      await _writeSessionString('Irfan_DailyDate', sessionId, todayStr);
      await _saveStringList(
        'Irfan_DailyQuestionIds',
        sessionId,
        picked.map((q) => q.id).toList(),
      );
      if (savedDate != todayStr) {
        await _writeSessionBool('Irfan_DailyCompleted', sessionId, false);
        await _writeSessionInt('Irfan_DailyCorrect', sessionId, 0);
      }
    }

    return picked;
  }

  /// Selects questions for a specific [topic] and [tier], optionally anchored to [farzId].
  Future<List<IrfanQuestion>> selectTopicQuiz({
    required String sessionId,
    required IrfanTopic topic,
    required IrfanTier tier,
    int? farzId,
  }) async {
    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final rng = Random();
    final picked = <IrfanQuestion>[];
    final pickedIds = <String>{};

    void appendPrioritized(List<IrfanQuestion> candidates, int limit) {
      final unmastered = candidates
          .where((q) => !pickedIds.contains(q.id) && !masteredSet.contains(q.id))
          .toList()
        ..shuffle(rng);
      final mastered = candidates
          .where((q) => !pickedIds.contains(q.id) && masteredSet.contains(q.id))
          .toList()
        ..shuffle(rng);
      for (final q in [...unmastered, ...mastered]) {
        if (picked.length >= limit) break;
        picked.add(q);
        pickedIds.add(q.id);
      }
    }

    if (farzId != null) {
      final farzQuestions = _source.byFarzId(farzId);
      appendPrioritized(farzQuestions, _topicSessionTarget);
      if (picked.length < 5) {
        appendPrioritized(_source.byNode(topic, tier), 5);
      }
      return picked;
    }

    appendPrioritized(_source.byNode(topic, tier), _topicSessionTarget);
    return picked;
  }

  /// Selects due SM-2 spaced repetition questions, falling back gracefully if none are overdue.
  Future<List<IrfanQuestion>> selectSm2Review({
    required String sessionId,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final sm2Map = await _loadSm2Cards(sessionId);

    final validCards = sm2Map.values
        .where((c) => _source.byId(c.questionId) != null)
        .toList()
      ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));

    final dueCards = validCards.where((c) => c.isDue(clock)).toList();
    final targetCards = dueCards.isNotEmpty ? dueCards : validCards;

    if (targetCards.isNotEmpty) {
      return targetCards
          .take(_sm2SessionTarget)
          .map((c) => _source.byId(c.questionId)!)
          .toList();
    }

    // Fallback when SM-2 pool is completely empty: pick 5 unmastered questions
    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final rng = Random();
    final fallback = _source.allQuestions
        .where((q) => !masteredSet.contains(q.id))
        .toList()
      ..shuffle(rng);
    if (fallback.isNotEmpty) {
      return fallback.take(_dailyQuestionTarget).toList();
    }
    final allShuffled = List<IrfanQuestion>.from(_source.allQuestions)..shuffle(rng);
    return allShuffled.take(_dailyQuestionTarget).toList();
  }

  /// Records a question answer, updating mastery, SM-2 interval, and badge counters.
  Future<IrfanAnswerOutcome> recordQuestionAttempt({
    required String sessionId,
    required IrfanQuestion question,
    required IrfanSessionMode mode,
    required bool isCorrect,
    required bool usedHint,
    int mistakesCount = 0,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final solvedSet = await _loadStringSet('Irfan_SolvedIds', sessionId);
    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final sm2Map = await _loadSm2Cards(sessionId);

    solvedSet.add(question.id);
    await _saveBoundedStringSet('Irfan_SolvedIds', sessionId, solvedSet);

    final prevSolvedCount = await _readSessionInt('Irfan_TotalSolved', sessionId);
    final newTotalSolved = max(solvedSet.length, prevSolvedCount + 1);
    await _writeSessionInt('Irfan_TotalSolved', sessionId, newTotalSolved);

    int totalCorrect = await _readSessionInt('Irfan_TotalCorrect', sessionId);
    int ilmihalCorrect = await _readSessionInt('Irfan_IlmihalCorrect', sessionId);
    int sm2Reviews = await _readSessionInt('Irfan_Sm2Reviews', sessionId);

    if (isCorrect) {
      masteredSet.add(question.id);
      await _saveBoundedStringSet('Irfan_MasteredIds', sessionId, masteredSet);
      totalCorrect += 1;
      await _writeSessionInt('Irfan_TotalCorrect', sessionId, totalCorrect);

      if (question.topic == IrfanTopic.ilmihal32Farz) {
        ilmihalCorrect += 1;
        await _writeSessionInt('Irfan_IlmihalCorrect', sessionId, ilmihalCorrect);
      }
    }

    // Update SM-2 schedule using SuperMemo SM-2 engine
    final existingCard = sm2Map[question.id];
    final shouldTrackInSm2 =
        !isCorrect || usedHint || mistakesCount > 0 || existingCard != null || mode == IrfanSessionMode.sm2Review;

    if (shouldTrackInSm2) {
      final quality = _computeSm2Quality(
        isCorrect: isCorrect,
        usedHint: usedHint,
        mistakesCount: mistakesCount,
      );
      final sm2Res = SpacedRepetitionSm2.calculate(
        quality: quality,
        previousRepetitions: existingCard?.repetitions ?? 0,
        previousIntervalDays: existingCard?.intervalDays ?? 0,
        previousEaseFactor: existingCard?.easeFactor ?? 2.5,
      );

      // First-time mistake outside sm2Review becomes immediately reviewable today;
      // inside sm2Review (or on pass), follow SM-2 future interval schedule.
      final nextReviewDt = (!isCorrect && mode != IrfanSessionMode.sm2Review)
          ? clock
          : clock.add(Duration(days: sm2Res.intervalDays));

      sm2Map[question.id] = IrfanSm2CardRecord(
        questionId: question.id,
        repetitions: sm2Res.repetitions,
        intervalDays: sm2Res.intervalDays,
        easeFactor: sm2Res.easeFactor,
        nextReviewDate: nextReviewDt,
        lastReviewedAt: clock,
      );
      await _saveSm2Cards(sessionId, sm2Map);
    }

    if (mode == IrfanSessionMode.sm2Review) {
      await _writeSessionString('Irfan_Sm2FreeUsedDate', sessionId, formatDateKey(clock));
      if (isCorrect) {
        sm2Reviews += 1;
        await _writeSessionInt('Irfan_Sm2Reviews', sessionId, sm2Reviews);
      }
    }

    final badges = await _evaluateEligibleBadges(
      sessionId: sessionId,
      totalSolved: newTotalSolved,
      totalCorrect: totalCorrect,
      ilmihalCorrect: ilmihalCorrect,
      sm2Reviews: sm2Reviews,
      masteredSet: masteredSet,
      clock: clock,
    );

    return IrfanAnswerOutcome(newlyEligibleBadgeIds: badges);
  }

  /// Picks an unseen replacement question in the same topic/tier (or fallback pool) excluding [excludedIds].
  IrfanQuestion? pickReplacementQuestion({
    required IrfanQuestion current,
    required Set<String> excludedIds,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final pools = <List<IrfanQuestion>>[
      _source.byNode(current.topic, current.tier),
      _source.allQuestions.where((q) => q.topic == current.topic).toList(),
      _source.allQuestions,
    ];
    for (final pool in pools) {
      final candidates =
          pool.where((q) => !excludedIds.contains(q.id)).toList();
      if (candidates.isNotEmpty) {
        candidates.shuffle(random);
        return candidates.first;
      }
    }
    return null;
  }

  /// Applies the İrfan Shield redemption on a wrongly answered question, updating mastery & SM-2.
  Future<IrfanAnswerOutcome> applyMistakeShield({
    required String sessionId,
    required IrfanQuestion question,
    required IrfanSessionMode mode,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final sm2Map = await _loadSm2Cards(sessionId);

    masteredSet.add(question.id);
    await _saveBoundedStringSet('Irfan_MasteredIds', sessionId, masteredSet);

    final totalSolved = await _readSessionInt('Irfan_TotalSolved', sessionId);
    final totalCorrect =
        (await _readSessionInt('Irfan_TotalCorrect', sessionId)) + 1;
    await _writeSessionInt('Irfan_TotalCorrect', sessionId, totalCorrect);

    int ilmihalCorrect =
        await _readSessionInt('Irfan_IlmihalCorrect', sessionId);
    if (question.topic == IrfanTopic.ilmihal32Farz) {
      ilmihalCorrect += 1;
      await _writeSessionInt('Irfan_IlmihalCorrect', sessionId, ilmihalCorrect);
    }

    int sm2Reviews = await _readSessionInt('Irfan_Sm2Reviews', sessionId);
    if (mode == IrfanSessionMode.sm2Review) {
      sm2Reviews += 1;
      await _writeSessionInt('Irfan_Sm2Reviews', sessionId, sm2Reviews);
    }

    final existingCard = sm2Map[question.id];
    final sm2Res = SpacedRepetitionSm2.calculate(
      quality: 4,
      previousRepetitions: 0,
      previousIntervalDays: 0,
      previousEaseFactor: existingCard?.easeFactor ?? 2.5,
    );
    sm2Map[question.id] = IrfanSm2CardRecord(
      questionId: question.id,
      repetitions: sm2Res.repetitions,
      intervalDays: sm2Res.intervalDays,
      easeFactor: sm2Res.easeFactor,
      nextReviewDate: clock.add(Duration(days: sm2Res.intervalDays)),
      lastReviewedAt: clock,
    );
    await _saveSm2Cards(sessionId, sm2Map);

    final badges = await _evaluateEligibleBadges(
      sessionId: sessionId,
      totalSolved: totalSolved,
      totalCorrect: totalCorrect,
      ilmihalCorrect: ilmihalCorrect,
      sm2Reviews: sm2Reviews,
      masteredSet: masteredSet,
      clock: clock,
    );
    return IrfanAnswerOutcome(newlyEligibleBadgeIds: badges);
  }

  /// Marks today's Daily 5 as completed once per day, advancing the İrfan streak.
  Future<IrfanDailyCompletionOutcome> completeDailyFive({
    required String sessionId,
    required int correctCount,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final todayStr = formatDateKey(clock);
    final yesterdayStr = formatDateKey(clock.subtract(const Duration(days: 1)));

    final savedDate = await _readSessionString('Irfan_DailyDate', sessionId);
    final alreadyDone = savedDate == todayStr &&
        await _readSessionBool('Irfan_DailyCompleted', sessionId);

    final prevDailyCorrect = savedDate == todayStr
        ? await _readSessionInt('Irfan_DailyCorrect', sessionId)
        : 0;
    await _writeSessionString('Irfan_DailyDate', sessionId, todayStr);
    await _writeSessionBool('Irfan_DailyCompleted', sessionId, true);
    await _writeSessionInt(
      'Irfan_DailyCorrect',
      sessionId,
      max(prevDailyCorrect, correctCount),
    );

    final lastStreakDate =
        await _readSessionString('Irfan_LastStreakDate', sessionId);
    int curStreak = await _readSessionInt('Irfan_CurrentStreak', sessionId);
    int bestStreak = await _readSessionInt('Irfan_BestStreak', sessionId);

    if (lastStreakDate != todayStr) {
      curStreak = (lastStreakDate == yesterdayStr) ? curStreak + 1 : 1;
      bestStreak = max(bestStreak, curStreak);
      await _writeSessionString('Irfan_LastStreakDate', sessionId, todayStr);
      await _writeSessionInt('Irfan_CurrentStreak', sessionId, curStreak);
      await _writeSessionInt('Irfan_BestStreak', sessionId, bestStreak);
    }

    final masteredSet = await _loadStringSet('Irfan_MasteredIds', sessionId);
    final badges = await _evaluateEligibleBadges(
      sessionId: sessionId,
      totalSolved: await _readSessionInt('Irfan_TotalSolved', sessionId),
      totalCorrect: await _readSessionInt('Irfan_TotalCorrect', sessionId),
      ilmihalCorrect: await _readSessionInt('Irfan_IlmihalCorrect', sessionId),
      sm2Reviews: await _readSessionInt('Irfan_Sm2Reviews', sessionId),
      masteredSet: masteredSet,
      clock: clock,
    );

    return IrfanDailyCompletionOutcome(
      bonusAwardedNow: !alreadyDone,
      updatedStreakDays: curStreak,
      newlyEligibleBadgeIds: badges,
    );
  }

  int _computeSm2Quality({
    required bool isCorrect,
    required bool usedHint,
    required int mistakesCount,
  }) {
    if (!isCorrect) return 1;
    if (usedHint || mistakesCount > 0) return 3;
    return 5;
  }

  Future<int> _resolveActiveStreak(String sessionId, DateTime clock) async {
    final todayStr = formatDateKey(clock);
    final yesterdayStr = formatDateKey(clock.subtract(const Duration(days: 1)));
    final lastDate = await _readSessionString('Irfan_LastStreakDate', sessionId);
    if (lastDate == todayStr || lastDate == yesterdayStr) {
      return _readSessionInt('Irfan_CurrentStreak', sessionId);
    }
    return 0;
  }

  Future<Set<String>> _evaluateEligibleBadges({
    required String sessionId,
    required int totalSolved,
    required int totalCorrect,
    required int ilmihalCorrect,
    required int sm2Reviews,
    required Set<String> masteredSet,
    required DateTime clock,
  }) async {
    final bestStreak = await _readSessionInt('Irfan_BestStreak', sessionId);
    final activeStreak = await _resolveActiveStreak(sessionId, clock);
    final effectiveStreak = max(bestStreak, activeStreak);

    final ilmihalAll = _source.allQuestions
        .where((q) => q.topic == IrfanTopic.ilmihal32Farz)
        .toList();
    final masteredIlmihalCount =
        ilmihalAll.where((q) => masteredSet.contains(q.id)).length;

    final eligible = <String>{};
    if (totalSolved >= 1) {
      eligible.add('irfan_first_step');
    }
    if (effectiveStreak >= 7) {
      eligible.add('irfan_daily_7');
    }
    if (ilmihalCorrect >= 25 ||
        (ilmihalAll.isNotEmpty && masteredIlmihalCount >= (ilmihalAll.length * 0.75).ceil())) {
      eligible.add('irfan_farz_32');
    }
    if (totalCorrect >= 50) {
      eligible.add('irfan_scholar_50');
    }
    if (sm2Reviews >= 10 || totalCorrect >= 100) {
      eligible.add('irfan_sm2_master');
    }
    return eligible;
  }

  int _seedForDay(String dateStr, String sessionId) {
    int hash = 17;
    final input = '$dateStr::$sessionId';
    for (int i = 0; i < input.length; i++) {
      hash = 37 * hash + input.codeUnitAt(i);
    }
    return hash & 0x7fffffff;
  }

  Future<List<String>> _loadStringList(String base, String sessionId) async {
    final raw = await _readSessionString(base, sessionId);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (e) {
      debugPrint('[IrfanRepository] Failed decoding list $base: $e');
    }
    return <String>[];
  }

  Future<Set<String>> _loadStringSet(String base, String sessionId) async =>
      (await _loadStringList(base, sessionId)).toSet();

  Future<void> _saveStringList(
    String base,
    String sessionId,
    List<String> items,
  ) async {
    final bounded = items.length > _maxBoundedEntries
        ? items.sublist(items.length - _maxBoundedEntries)
        : items;
    await _writeSessionString(base, sessionId, jsonEncode(bounded));
  }

  Future<void> _saveBoundedStringSet(
    String base,
    String sessionId,
    Set<String> items,
  ) async {
    await _saveStringList(base, sessionId, items.toList());
  }

  Future<Map<String, IrfanSm2CardRecord>> _loadSm2Cards(String sessionId) async {
    final raw = await _readSessionString('Irfan_Sm2Cards', sessionId);
    if (raw == null || raw.isEmpty) return <String, IrfanSm2CardRecord>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final result = <String, IrfanSm2CardRecord>{};
        for (final entry in decoded.entries) {
          final val = entry.value;
          if (val is Map<String, dynamic>) {
            final record = IrfanSm2CardRecord.tryFromJson(val);
            if (record != null) {
              result[entry.key] = record;
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('[IrfanRepository] Failed decoding SM-2 cards: $e');
    }
    return <String, IrfanSm2CardRecord>{};
  }

  Future<void> _saveSm2Cards(
    String sessionId,
    Map<String, IrfanSm2CardRecord> cards,
  ) async {
    var entries = cards.entries.toList();
    if (entries.length > _maxBoundedEntries) {
      entries.sort(
        (a, b) => a.value.lastReviewedAt.compareTo(b.value.lastReviewedAt),
      );
      entries = entries.sublist(entries.length - _maxBoundedEntries);
    }
    final serializable = <String, dynamic>{
      for (final entry in entries) entry.key: entry.value.toJson(),
    };
    await _writeSessionString(
      'Irfan_Sm2Cards',
      sessionId,
      jsonEncode(serializable),
    );
  }
}
