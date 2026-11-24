import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../../domain/entities/reading_session_entity.dart';
import '../../../reader/engine/epub_parser_engine.dart';
import '../../../reader/engine/pdf_reflow_engine.dart';
import '../../../reader/services/offline_ai_service.dart';
import '../../data/speed_reading_curriculum_corpus.dart';
import '../../domain/speed_reading_models.dart';
import '../../engine/speed_reading_engine.dart';

class SpeedReadingNotifier extends StateNotifier<SpeedReadingProgressState> {
  static const String _storageKey = 'tahrir_speed_reading_progress_v1';
  final Ref? _ref;
  final List<SpeedReadingPassage> _liveBookPassages = [];

  SpeedReadingNotifier([this._ref]) : super(const SpeedReadingProgressState()) {
    _loadAndCoordinate();
  }

  List<SpeedReadingPassage> get liveBookPassages =>
      List.unmodifiable(_liveBookPassages);

  String _todayIsoDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayIsoDate() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAndCoordinate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        state = SpeedReadingProgressState.fromJsonString(raw);
      }
      await _evaluateWarmReturn();
      await _syncBookSessionsAndExcerpts();
    } catch (e) {
      debugPrint('SpeedReadingNotifier loadAndCoordinate error: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, state.toJsonString());
    } catch (e) {
      debugPrint('SpeedReadingNotifier saveToPrefs error: $e');
    }
  }

  /// Ara verildiğinde ceza veya kademe düşüşü uygulamadan sıcak karşılama mesajı hazırlar
  Future<void> _evaluateWarmReturn() async {
    final trainingDate = DateTime.tryParse(state.lastTrainingDateIso.trim());
    final fasilDate = DateTime.tryParse(state.lastFasilDateIso.trim());

    DateTime? latestActivity;
    if (trainingDate != null && fasilDate != null) {
      latestActivity = trainingDate.isAfter(fasilDate) ? trainingDate : fasilDate;
    } else {
      latestActivity = trainingDate ?? fasilDate;
    }

    if (latestActivity == null) return;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final parsedLast = DateTime(
      latestActivity.year,
      latestActivity.month,
      latestActivity.day,
    );
    final daysMissed = todayDate.difference(parsedLast).inDays;

    if (daysMissed >= 3) {
      final warmMessage =
          'Hoş geldin! $daysMissed günlük aradan sonra kaldığın yerden yumuşak bir ritimle devam edelim.';
      if (state.welcomeBackMessage != warmMessage) {
        state = state.copyWith(welcomeBackMessage: warmMessage);
        await _saveToPrefs();
      }
    }
  }

  Future<void> dismissWelcomeBackMessage() async {
    if (state.welcomeBackMessage == null) return;
    state = state.copyWith(clearWelcomeBackMessage: true);
    await _saveToPrefs();
  }

  /// Kütüphanedeki kitap okuma oturumlarından gerçek WPM hızını ve canlı kitap metinlerini senkronize eder
  Future<void> _syncBookSessionsAndExcerpts() async {
    final ref = _ref;
    if (ref == null) return;

    try {
      final bookRepo = ref.read(bookRepositoryProvider);
      final highlightRepo = ref.read(highlightRepositoryProvider);

      final sessionsRes = await bookRepo.getReadingSessions();
      final sessions = sessionsRes.dataOrNull ?? const [];
      if (sessions.isNotEmpty) {
        final validSessions =
            sessions.where((s) => s.calculatedWpm >= 80).toList();
        if (validSessions.isNotEmpty) {
          final latestWpm = validSessions.first.calculatedWpm.round().clamp(90, 900);
          await syncFromBookReading(measuredBookWpm: latestWpm);
        }
      }

      // Kullanıcının kendi notlarından/kitaplarından canlı antrenman pasajları üret
      final booksRes = await bookRepo.getAllBooks();
      final books = booksRes.dataOrNull ?? const [];
      final highRes = await highlightRepo.getAllHighlights();
      final highlights = highRes.dataOrNull ?? const [];

      for (final h in highlights.take(6)) {
        final rawHText = h.selectedText.trim();
        final text = rawHText.length > 3500
            ? rawHText.substring(0, 3500)
            : rawHText;
        if (text.split(RegExp(r'\s+')).length >= 18) {
          final matchedBook = books
              .where((b) => b.id == h.bookId)
              .firstOrNull;
          final bookTitle = matchedBook?.title ?? 'Kütüphane Eseri';
          final bookAuthor = matchedBook?.author ?? 'Tahrir Kitaplığı';
          final passageId = 'user_high_${h.id ?? text.hashCode}';

          if (!_liveBookPassages.any((p) => p.id == passageId)) {
            _liveBookPassages.add(
              SpeedReadingPassage(
                id: passageId,
                title: '$bookTitle (Sayfa ${h.pageNumber})',
                author: bookAuthor,
                category: 'Kütüphanemden Canlı Kesit',
                difficulty: 'Kişisel',
                content: text,
                questions: SpeedReadingEngine.generateQuestionsFromBookExcerpt(
                  bookTitle: bookTitle,
                  excerptText: text,
                ),
                isFromUserBook: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('SpeedReadingNotifier syncBookSessions error: $e');
    }
  }

  /// Kullanıcı kitap okurken ölçülen gerçek okuma hızını yumuşak ağırlıklı ortalama ile koordine eder
  Future<void> syncFromBookReading({
    required int measuredBookWpm,
    String? bookTitle,
    String? bookAuthor,
    int? pageNumber,
    String? pageExcerpt,
    String? complexityLabel,
  }) async {
    final safeWpm = measuredBookWpm.clamp(80, 1000);
    final prevBookWpm = state.lastBookReadingWpm;

    // Eğer kitap sayfasından anlamlı uzunlukta canlı metin geldiyse antrenman havuzuna ekle
    if (pageExcerpt != null && pageExcerpt.trim().isNotEmpty) {
      final boundedExcerpt = pageExcerpt.length > 3500
          ? pageExcerpt.substring(0, 3500)
          : pageExcerpt;
      final cleaned = boundedExcerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
      final wordList = cleaned.split(' ');
      if (wordList.length >= 35) {
        final snippet = wordList.take(115).join(' ');
        final title = bookTitle ?? 'Okunan Eser';
        final author = bookAuthor ?? 'Kütüphanem';
        final pg = pageNumber ?? 1;
        final passageId = 'live_book_${title.hashCode}_p$pg';

        _liveBookPassages.removeWhere((p) => p.id == passageId);
        _liveBookPassages.insert(
          0,
          SpeedReadingPassage(
            id: passageId,
            title: '$title • S. $pg',
            author: author,
            category: 'Okuduğunuz Kitaptan Canlı',
            difficulty: 'Canlı Kitap',
            content: snippet,
            questions: SpeedReadingEngine.generateQuestionsFromBookExcerpt(
              bookTitle: title,
              excerptText: snippet,
            ),
            isFromUserBook: true,
          ),
        );
        if (_liveBookPassages.length > 10) {
          _liveBookPassages.removeLast();
        }
      }
    }

    final smoothedBookWpm = prevBookWpm > 0
        ? ((prevBookWpm * 0.4) + (safeWpm * 0.6)).round()
        : safeWpm;

    final coordinatedWpm =
        ((smoothedBookWpm * 1.18).round() + ((state.activeStage - 1) * 10))
            .clamp(150, 750);

    final trimmedComplexity = complexityLabel?.trim();
    final String? nextDensityId = (trimmedComplexity != null &&
            trimmedComplexity.isNotEmpty &&
            trimmedComplexity.toLowerCase() != 'belirsiz')
        ? TextDensityTier.fromComplexityLabel(trimmedComplexity).id
        : null;

    state = state.copyWith(
      previousBookReadingWpm: prevBookWpm,
      lastBookReadingWpm: smoothedBookWpm,
      currentWpm: math.max(state.currentWpm, coordinatedWpm),
      clearRegressionReason: true,
      lastDetectedDensityId: nextDensityId,
    );

    await _saveToPrefs();
  }

  /// Aktif kitaptan veya kütüphane kesitinden 60 saniyelik lexical ısınma paketi üretir
  Future<WarmupLexicalPack> prepareBookWarmupPack({
    BookEntity? book,
    String? fallbackPageText,
  }) async {
    String extractedText = (fallbackPageText ?? '').trim();
    bool isFromUserBook = extractedText.isNotEmpty;

    if (extractedText.isEmpty && book != null) {
      final lowerPath = book.filePath.toLowerCase();
      final isEpub = book.format == BookFormat.epub || lowerPath.endsWith('.epub');
      final isTextChapter = book.format == BookFormat.markdown ||
          book.format == BookFormat.txt ||
          lowerPath.endsWith('.md') ||
          lowerPath.endsWith('.txt');

      if (isEpub || isTextChapter) {
        try {
          const epubEngine = EpubParserEngine();
          final chapters = isEpub
              ? await epubEngine.parseEpub(book.filePath)
              : await epubEngine.parseMarkdownOrTxt(book.filePath);
          if (chapters.isNotEmpty &&
              chapters.first.title != 'EPUB Okuma Uyarısı') {
            final idx = (book.currentPage - 1).clamp(0, chapters.length - 1);
            final chapterText = chapters[idx].content.trim();
            if (chapterText.isNotEmpty) {
              extractedText = chapterText;
              isFromUserBook = true;
            }
          }
        } catch (e) {
          debugPrint('SpeedReadingNotifier prepareBookWarmupPack epub error: $e');
        }
      } else if (book.currentPage <= 15 ||
          book.filePath.startsWith('sample://')) {
        try {
          final pageIndex = (book.currentPage - 1).clamp(0, 10000);
          final pageData = await const PdfReflowEngine().extractPage(
            book.filePath,
            pageIndex,
          );
          if (pageData.hasTextContent && pageData.rawText.trim().isNotEmpty) {
            extractedText = pageData.rawText.trim();
            isFromUserBook = true;
          }
        } catch (e) {
          debugPrint('SpeedReadingNotifier prepareBookWarmupPack pdf error: $e');
        }
      }
    }

    String resolvedTitle = book?.title ?? 'Mütalaa Isınması';
    String resolvedAuthor = book?.author ?? 'Tahrir Kitaplığı';
    final int resolvedPage =
        book != null && book.currentPage > 0 ? book.currentPage : 1;

    if (extractedText.length < 24) {
      SpeedReadingPassage? matchedLive;
      if (_liveBookPassages.isNotEmpty) {
        if (book != null) {
          matchedLive = _liveBookPassages
              .where((p) => p.title.contains(book.title))
              .firstOrNull;
        }
        matchedLive ??= _liveBookPassages.first;
      }

      if (matchedLive != null && matchedLive.content.trim().length >= 24) {
        extractedText = matchedLive.content.trim();
        if (book == null) {
          resolvedTitle = matchedLive.title;
          resolvedAuthor = matchedLive.author;
        }
        isFromUserBook = matchedLive.isFromUserBook;
      } else {
        final fresh = consumeFreshPassage();
        extractedText = fresh.content.trim();
        if (book == null) {
          resolvedTitle = fresh.title;
          resolvedAuthor = fresh.author;
        }
        isFromUserBook = fresh.isFromUserBook;
      }
    }

    final boundedText = extractedText.length > 3500
        ? extractedText.substring(0, 3500)
        : extractedText;
    final insights = const OfflineAiService().analyzeText(boundedText);
    final density = TextDensityTier.fromComplexityLabel(insights.complexityLevel);

    return SpeedReadingEngine.buildWarmupLexicalPack(
      title: resolvedTitle,
      author: resolvedAuthor,
      targetPage: resolvedPage,
      rawUpcomingText: boundedText,
      extractedConcepts: insights.keyConcepts,
      complexityLabel: insights.complexityLevel,
      isFromUserBook: isFromUserBook,
      suggestedWpm: state.targetWpmForDensity(density),
    );
  }

  /// Akıcı fasıl tamamlandığında WPM, dayanıklılık, XP, mühürler ve isteğe bağlı Haşiye notunu kaydeder
  Future<FasilReflectionSummary> recordGuidedFasilCompleted({
    required int? bookId,
    required String bookTitle,
    required int startPage,
    required int endPage,
    required int pagesRead,
    required int wordsRead,
    required int durationSeconds,
    required int averageWpm,
    required TempoCalibrationFeedback tempoFeedback,
    required TextDensityTier densityTier,
    required List<String> keyConcepts,
    required String centralRecallSentence,
    String? hasiyeNoteText,
    List<String> insightSnippets = const [],
  }) async {
    final safeDurationSeconds = durationSeconds.clamp(1, 86400);
    final durationMinutes = (safeDurationSeconds / 60.0).ceil().clamp(1, 240);
    final safePagesRead = pagesRead.clamp(0, 10000);
    final safeWordsRead = wordsRead.clamp(0, 1000000);
    final safeAverageWpm = averageWpm.clamp(60, 1200);
    final nextCurrentWpm =
        (state.currentWpm + tempoFeedback.wpmDelta).clamp(140, 800);

    final todayIso = _todayIsoDate();
    final nextTodayFasilsCount = state.lastFasilDateIso == todayIso
        ? (state.todayFasilsCount + 1).clamp(1, 500)
        : 1;
    final nextLongestFasil = math.max(state.longestFasilMinutes, durationMinutes);

    final hasNote = hasiyeNoteText != null && hasiyeNoteText.trim().isNotEmpty;
    final earnedXp =
        (35 + (durationMinutes * 5) + (safePagesRead * 4) + (hasNote ? 15 : 0))
            .clamp(40, 260);

    state = state.copyWith(
      currentWpm: nextCurrentWpm,
      todayFasilsCount: nextTodayFasilsCount,
      lastFasilDateIso: todayIso,
      totalFasilsCompleted: state.totalFasilsCompleted + 1,
      longestFasilMinutes: nextLongestFasil,
      totalTrainingMinutes: state.totalTrainingMinutes + durationMinutes,
      totalXp: state.totalXp + earnedXp,
      clearWelcomeBackMessage: true,
      clearRegressionReason: true,
      lastDetectedDensityId: densityTier.id,
    );

    await _saveToPrefs();

    final ref = _ref;
    if (ref != null) {
      try {
        final habitRepo = ref.read(habitRepositoryProvider);
        await habitRepo.updateStreak(durationMinutes);
        await habitRepo.addEarnedSeal('seal_fasil_first');
        if (durationMinutes >= 12) {
          await habitRepo.addEarnedSeal('seal_stamina_12m');
        }
        if (durationMinutes >= 20) {
          await habitRepo.addEarnedSeal('seal_stamina_20m');
        }
        if (durationMinutes >= 30) {
          await habitRepo.addEarnedSeal('seal_stamina_30m');
        }

        if (bookId != null) {
          final bookRepo = ref.read(bookRepositoryProvider);
          await bookRepo.recordReadingSession(
            ReadingSessionEntity(
              bookId: bookId,
              sessionDate: DateTime.now(),
              durationSeconds: safeDurationSeconds,
              pagesRead: safePagesRead,
              wordsRead: safeWordsRead,
              calculatedWpm: safeAverageWpm.toDouble(),
            ),
          );

          if (hasNote) {
            final highlightRepo = ref.read(highlightRepositoryProvider);
            final trimmedRecall = centralRecallSentence.trim();
            await highlightRepo.insertHighlight(
              HighlightEntity(
                bookId: bookId,
                pageNumber: endPage,
                selectedText: trimmedRecall.isNotEmpty
                    ? trimmedRecall
                    : '$bookTitle • S. $endPage',
                userNote: hasiyeNoteText.trim(),
                category: HighlightCategory.thought,
                createdAt: DateTime.now(),
              ),
            );
            ref.read(highlightsRevisionProvider.notifier).state++;
          }
        }
      } catch (e) {
        debugPrint(
          'SpeedReadingNotifier recordGuidedFasilCompleted repo error: $e',
        );
      }
    }

    return FasilReflectionSummary(
      bookTitle: bookTitle,
      bookId: bookId,
      startPage: startPage,
      endPage: endPage,
      pagesRead: safePagesRead,
      wordsRead: safeWordsRead,
      durationSeconds: safeDurationSeconds,
      averageWpm: safeAverageWpm,
      keyConcepts: List<String>.unmodifiable(keyConcepts),
      centralRecallSentence: centralRecallSentence.trim(),
      densityTier: densityTier,
      insightSnippets: List<String>.unmodifiable(insightSnippets),
    );
  }

  /// Bayatlamayı önleyen, her çağrıda farklı bir metin döndüren ve geçmişe kaydeden seçici
  SpeedReadingPassage consumeFreshPassage({int? preferredStage}) {
    final chosen = SpeedReadingCurriculumCorpus.selectFreshPassage(
      recentPassageIds: state.recentPassageIds,
      userBookPassages: _liveBookPassages,
      preferredStage: preferredStage ?? state.activeStage,
    );

    final updatedRecent = <String>[
      chosen.id,
      ...state.recentPassageIds.where((id) => id != chosen.id),
    ].take(10).toList();

    state = state.copyWith(recentPassageIds: updatedRecent);
    unawaited(_saveToPrefs());
    return chosen;
  }

  /// Herhangi bir hızlı okuma egzersizi tamamlandığında XP, Seri (Streak), Kademe ve WPM istatistiklerini günceller
  Future<void> recordDrillCompletion({
    required SpeedReadingExerciseType type,
    required int achievedWpm,
    required int comprehensionPercent,
    required double durationSeconds,
    required String summaryLabel,
    int? completedCourseDay,
    double? schulte5x5Seconds,
    int? tachistoscopeMs,
  }) async {
    final baseXp = type.xpReward;
    final speedBonus = achievedWpm >= 400 ? 20 : (achievedWpm >= 300 ? 10 : 0);
    final accuracyBonus = comprehensionPercent >= 90 ? 15 : 0;
    final earnedXp = (baseXp + speedBonus + accuracyBonus).clamp(25, 250);

    final record = SpeedDrillRecord(
      type: type,
      timestamp: DateTime.now(),
      achievedWpm: achievedWpm.clamp(60, 2000),
      comprehensionPercent: comprehensionPercent.clamp(0, 100),
      durationSeconds: durationSeconds.clamp(1.0, 7200.0),
      summaryLabel: summaryLabel,
      earnedXp: earnedXp,
    );

    final updatedRecords = [record, ...state.recentRecords].take(30).toList();
    final addedMinutes = (durationSeconds / 60.0).ceil().clamp(1, 60);

    final newBaseline = state.totalDrillsCompleted == 0 &&
            type == SpeedReadingExerciseType.wpmComprehensionTest
        ? record.effectiveWpm.clamp(100, 800)
        : state.baselineWpm;

    final newCurrentWpm = achievedWpm > 0 ? achievedWpm : state.currentWpm;
    final newBestEffective = record.effectiveWpm > state.bestEffectiveWpm
        ? record.effectiveWpm
        : state.bestEffectiveWpm;

    final compRecords = updatedRecords
        .where(
          (r) =>
              r.type == SpeedReadingExerciseType.wpmComprehensionTest ||
              r.type == SpeedReadingExerciseType.tachistoscope,
        )
        .toList();
    final avgComp = compRecords.isNotEmpty
        ? (compRecords.fold<int>(0, (acc, r) => acc + r.comprehensionPercent) /
                compRecords.length)
            .round()
        : state.averageComprehension;

    double? bestSchulte = state.bestSchulte5x5Seconds;
    if (schulte5x5Seconds != null && schulte5x5Seconds > 2.0) {
      if (bestSchulte == null || schulte5x5Seconds < bestSchulte) {
        bestSchulte = schulte5x5Seconds;
      }
    }

    int bestTachMs = state.bestTachistoscopeMs;
    if (tachistoscopeMs != null &&
        tachistoscopeMs > 0 &&
        tachistoscopeMs < bestTachMs) {
      bestTachMs = tachistoscopeMs;
    }

    final updatedDays = Set<int>.from(state.completedCourseDays);
    int nextActiveStage = state.activeStage;
    bool clearRegression = false;

    // Eğer antrenmanda anlama %50 altında kaldıysa kademe geriler, başarılıysa ilerler
    if (type == SpeedReadingExerciseType.wpmComprehensionTest &&
        comprehensionPercent < 50 &&
        state.activeStage > 1) {
      final oldStage = state.activeStage;
      nextActiveStage = (oldStage - 1).clamp(1, 21);
      updatedDays.remove(oldStage);
    } else if (completedCourseDay != null &&
        completedCourseDay >= 1 &&
        completedCourseDay <= 21) {
      updatedDays.add(completedCourseDay);
      if (completedCourseDay >= state.activeStage) {
        nextActiveStage = (completedCourseDay + 1).clamp(1, 21);
      }
      clearRegression = true;
    }

    final todayIso = _todayIsoDate();
    final yesterdayIso = _yesterdayIsoDate();
    int newStreak = state.dailyStreak;
    int newTodayCount = state.todayDrillsCount;

    if (state.lastTrainingDateIso == todayIso) {
      newTodayCount = (state.todayDrillsCount + 1).clamp(1, 500);
    } else if (state.lastTrainingDateIso == yesterdayIso) {
      newStreak = (state.dailyStreak + 1).clamp(1, 3650);
      newTodayCount = 1;
    } else {
      newStreak = state.lastTrainingDateIso.isEmpty ? state.dailyStreak : 1;
      newTodayCount = 1;
    }

    final goalJustCompletedBonus =
        (state.todayDrillsCount < state.dailyGoalDrills &&
                newTodayCount >= state.dailyGoalDrills)
            ? 35
            : 0;

    state = state.copyWith(
      baselineWpm: newBaseline,
      currentWpm: newCurrentWpm,
      bestEffectiveWpm: newBestEffective,
      averageComprehension: avgComp.clamp(0, 100),
      bestSchulte5x5Seconds: bestSchulte,
      bestTachistoscopeMs: bestTachMs,
      activeStage: nextActiveStage,
      completedCourseDays: updatedDays,
      totalDrillsCompleted: state.totalDrillsCompleted + 1,
      totalTrainingMinutes: state.totalTrainingMinutes + addedMinutes,
      totalXp: state.totalXp + earnedXp + goalJustCompletedBonus,
      dailyStreak: newStreak,
      lastTrainingDateIso: todayIso,
      todayDrillsCount: newTodayCount,
      clearRegressionReason: clearRegression,
      recentRecords: updatedRecords,
    );

    await _saveToPrefs();
  }

  /// Serüven durağını (kademeyi) tamamlandı olarak işaretler ve bir sonraki durağı açar
  Future<void> markCourseDayCompleted(int dayNumber, {int? targetWpm}) async {
    if (dayNumber < 1 || dayNumber > 21) return;
    final alreadyDone = state.completedCourseDays.contains(dayNumber);
    final updatedDays = Set<int>.from(state.completedCourseDays)..add(dayNumber);
    final nextStage = dayNumber >= state.activeStage
        ? (dayNumber + 1).clamp(1, 21)
        : state.activeStage;

    state = state.copyWith(
      activeStage: nextStage,
      completedCourseDays: updatedDays,
      totalXp: alreadyDone ? state.totalXp : state.totalXp + 80,
      currentWpm: targetWpm != null && targetWpm > state.currentWpm
          ? targetWpm
          : state.currentWpm,
      clearRegressionReason: true,
    );
    await _saveToPrefs();
  }
}

final speedReadingProvider =
    StateNotifierProvider<SpeedReadingNotifier, SpeedReadingProgressState>(
  (ref) => SpeedReadingNotifier(ref),
);
