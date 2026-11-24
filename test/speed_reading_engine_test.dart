import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/speed_reading/data/speed_reading_curriculum_corpus.dart';
import 'package:tahrir/features/speed_reading/domain/speed_reading_models.dart';
import 'package:tahrir/features/speed_reading/engine/speed_reading_engine.dart';

void main() {
  group('SpeedReadingEngine Unit Tests', () {
    test('computeOrpIndex & splitForOrp Türkçe eklemeli kelimelerde doğru odak harfi seçer', () {
      expect(SpeedReadingEngine.computeOrpIndex('ve'), 0);
      expect(SpeedReadingEngine.computeOrpIndex('ilim'), 1);
      expect(SpeedReadingEngine.computeOrpIndex('hakikat'), 2);
      expect(SpeedReadingEngine.computeOrpIndex('medeniyetimiz'), 3);
      expect(SpeedReadingEngine.computeOrpIndex('gerçekleştirilebilmesi'), 4);

      final parts = SpeedReadingEngine.splitForOrp('Mukaddime');
      expect(parts.leftPart + parts.pivotChar + parts.rightPart, 'Mukaddime');
      expect(parts.pivotIndex, 2);
      expect(parts.pivotChar, 'k');
    });

    test('calculateChunkDelayMs noktalama ve uzun kelimelerde süreyi dinamik artırır', () {
      final plainDelay = SpeedReadingEngine.calculateChunkDelayMs(
        chunk: 'kitap',
        targetWpm: 300,
        wordsInChunk: 1,
      );
      final commaDelay = SpeedReadingEngine.calculateChunkDelayMs(
        chunk: 'kitap,',
        targetWpm: 300,
        wordsInChunk: 1,
      );
      final periodDelay = SpeedReadingEngine.calculateChunkDelayMs(
        chunk: 'kitap.',
        targetWpm: 300,
        wordsInChunk: 1,
      );
      final longTurkishWordDelay = SpeedReadingEngine.calculateChunkDelayMs(
        chunk: 'müesseseleşme',
        targetWpm: 300,
        wordsInChunk: 1,
      );

      expect(plainDelay, 200);
      expect(commaDelay, greaterThan(plainDelay));
      expect(periodDelay, greaterThan(commaDelay));
      expect(longTurkishWordDelay, greaterThan(plainDelay));
    });

    test('calculateOverSpeedPhase 4 fazda (1.0x -> 1.5x -> 2.0x -> 1.35x) doğru WPM ve çarpan üretir', () {
      final phase1 = SpeedReadingEngine.calculateOverSpeedPhase(
        baseWpm: 300,
        progressRatio: 0.10,
      );
      expect(phase1.phaseNumber, 1);
      expect(phase1.multiplier, 1.0);
      expect(phase1.activeWpm, 300);

      final phase2 = SpeedReadingEngine.calculateOverSpeedPhase(
        baseWpm: 300,
        progressRatio: 0.40,
      );
      expect(phase2.phaseNumber, 2);
      expect(phase2.multiplier, 1.5);
      expect(phase2.activeWpm, 450);

      final phase3 = SpeedReadingEngine.calculateOverSpeedPhase(
        baseWpm: 300,
        progressRatio: 0.65,
      );
      expect(phase3.phaseNumber, 3);
      expect(phase3.multiplier, 2.0);
      expect(phase3.activeWpm, 600);

      final phase4 = SpeedReadingEngine.calculateOverSpeedPhase(
        baseWpm: 300,
        progressRatio: 0.90,
      );
      expect(phase4.phaseNumber, 4);
      expect(phase4.multiplier, 1.35);
      expect(phase4.activeWpm, 405);
    });

    test('generatePyramidSpanRows genişleyen yatay kanat açıklıklarıyla piramit satırları üretir', () {
      const text =
          'Tarih ilmi milletlerin ve devletlerin devirlerini geçmiş asırlardaki hallerini bildiren şerefli bir ilimdir.';
      final rows = SpeedReadingEngine.generatePyramidSpanRows(text, maxRows: 12);
      expect(rows.length, 12);
      expect(rows.first.centerAnchor, '1');
      expect(rows[1].horizontalGap, greaterThan(rows[0].horizontalGap));
      expect(rows[7].horizontalGap, greaterThan(rows[2].horizontalGap));

      final fallbackRows = SpeedReadingEngine.generatePyramidSpanRows('kısa');
      expect(fallbackRows.length, 3);
    });

    test('tokenizeIntoChunks kelime gruplarını ve cümle sonlarını doğru ayırır', () {
      const sample = 'Tarih ilmi milletlerin devirlerini inceler. Hakikat araştırılır.';
      final singleWords = SpeedReadingEngine.tokenizeIntoChunks(sample, chunkSize: 1);
      expect(singleWords.length, 7);

      final threeWordChunks = SpeedReadingEngine.tokenizeIntoChunks(sample, chunkSize: 3);
      expect(threeWordChunks.first, 'Tarih ilmi milletlerin');
      expect(threeWordChunks[1], 'devirlerini inceler.');
      expect(threeWordChunks[2], 'Hakikat araştırılır.');
    });

    test('generateSchulteGrid 3x3, 5x5 ve 6x6 boyutlarında eksiksiz hedef üretir', () {
      final grid5x5 = SpeedReadingEngine.generateSchulteGrid(
        dimension: 5,
        useLetters: false,
      );
      expect(grid5x5.orderedTargets.length, 25);
      expect(grid5x5.shuffledGrid.length, 25);
      expect(grid5x5.orderedTargets.first, '1');
      expect(grid5x5.orderedTargets.last, '25');
      expect(grid5x5.shuffledGrid.toSet(), grid5x5.orderedTargets.toSet());

      final letterGrid4x4 = SpeedReadingEngine.generateSchulteGrid(
        dimension: 4,
        useLetters: true,
      );
      expect(letterGrid4x4.orderedTargets.length, 16);
      expect(letterGrid4x4.orderedTargets.first, 'A');
    });

    test('generateTachistoscopeRound sabit havuzdan ve canlı sourceText içinden doğru hedef üretir', () {
      for (final span in [1, 2, 3]) {
        final round = SpeedReadingEngine.generateTachistoscopeRound(wordSpan: span);
        expect(round.options.length, 4);
        expect(round.options[round.correctOptionIndex], round.targetText);
      }

      const sampleSource =
          'Semerkand Rasathanesinde yıldızların konumlarını dakika ve saniye hassasiyetiyle ölçen astronomlar binlerce gece boyunca gökyüzünü dikkatle takip etmişlerdir.';
      final liveRound = SpeedReadingEngine.generateTachistoscopeRound(
        wordSpan: 2,
        sourceText: sampleSource,
      );
      expect(liveRound.options.length, 4);
      expect(liveRound.options[liveRound.correctOptionIndex], liveRound.targetText);
      expect(sampleSource.contains(liveRound.targetText.split(' ').first), isTrue);
    });

    test('selectFreshPassage ardışık tekrarı önler ve kullanıcı kitabı kesitine öncelik verir', () {
      const userPassage = SpeedReadingPassage(
        id: 'user_book_1',
        title: 'Kutadgu Bilig • S. 42',
        author: 'Yusuf Has Hacib',
        category: 'Okuduğunuz Kitaptan Canlı',
        difficulty: 'Canlı Kitap',
        content: 'Bilgi ve akıl insanın iki büyük hazinesidir.',
        questions: [],
        isFromUserBook: true,
      );

      // Kullanıcı kitabı henüz okunmadıysa öncelikle o seçilir
      final pickedUser = SpeedReadingCurriculumCorpus.selectFreshPassage(
        recentPassageIds: const [],
        userBookPassages: const [userPassage],
        preferredStage: 1,
      );
      expect(pickedUser.id, 'user_book_1');
      expect(pickedUser.isFromUserBook, isTrue);

      // Kullanıcı kitabı son okunanlardaysa müfredattan farklı bir metin seçilir
      final pickedNext = SpeedReadingCurriculumCorpus.selectFreshPassage(
        recentPassageIds: const ['user_book_1', 'ibn_haldun_umran'],
        userBookPassages: const [userPassage],
        preferredStage: 2,
      );
      expect(pickedNext.id, isNot('user_book_1'));
      expect(pickedNext.id, isNot('ibn_haldun_umran'));
    });

    test('generateQuestionsFromBookExcerpt sahte bilim çeldiricileri olmadan benzersiz seçenekler üretir', () {
      const excerpt =
          'Büyük bir mabedin kubbesi yalnızca taş ve harçtan ibaret bir örtü değil, sesi ve ışığı mekanın her köşesine eşit dağıtan canlı bir geometri harikasıdır. Mimar Sinan her ayrıntıyı hesaplamıştır.';
      final questions = SpeedReadingEngine.generateQuestionsFromBookExcerpt(
        bookTitle: 'Tezkiretü’l-Bünyân',
        excerptText: excerpt,
      );
      expect(questions.length, 3);
      for (final q in questions) {
        expect(q.options.length, 4);
        expect(q.options.toSet().length, 4);
        final joined = q.options.join(' ');
        expect(joined, isNot(contains('Radyoaktif')));
        expect(joined, isNot(contains('Termodinamik')));
        expect(joined, isNot(contains('havacılık')));
      }
      expect(questions.first.correctIndex, 0);
      expect(questions[1].correctIndex, 1);
    });

    test('buildParagraphSemanticChunks Türkçe noktalama ve uzun kelimelerde offsetleri doğru hizalar', () {
      const p0 = 'Göz kasları, satır üzerinde akarken gerçekleştirebildiğimiz ritmi korur.';
      const p1 = 'İkinci paragraf başlar. Anlam burada derinleşir.';
      final chunks = SpeedReadingEngine.buildParagraphSemanticChunks(
        paragraphs: const [(0, p0), (1, p1)],
        preferredChunkWords: 3,
      );

      expect(chunks, isNotEmpty);
      expect(chunks.first.paragraphIndex, 0);
      expect(chunks.first.text, 'Göz kasları,');
      expect(p0.substring(chunks.first.startOffset, chunks.first.endOffset), chunks.first.text);
      for (final span in chunks) {
        final source = span.paragraphIndex == 0 ? p0 : p1;
        expect(source.substring(span.startOffset, span.endOffset), span.text);
      }
    });

    test('buildWarmupLexicalPack yoğunluk derecesi, kavramlar ve ısınma öbekleri üretir', () {
      const raw =
          'İbn Haldun mukaddime eserinde umran ilminin esaslarını ve cemiyet nizamını derinlemesine tetkik etmiştir.';
      final pack = SpeedReadingEngine.buildWarmupLexicalPack(
        title: 'Mukaddime',
        author: 'İbn Haldun',
        targetPage: 12,
        rawUpcomingText: raw,
        extractedConcepts: const ['Umran', 'Cemiyet', 'Nizam'],
        complexityLabel: 'Akademik / Yoğun (Ağır Metin)',
        isFromUserBook: true,
        suggestedWpm: 250,
      );

      expect(pack.densityTier, TextDensityTier.academic);
      expect(pack.densityTier.chunkWords, 2);
      expect(pack.keyConcepts, containsAll(['Umran', 'Cemiyet', 'Nizam']));
      expect(pack.pyramidRows, isNotEmpty);
      expect(pack.overdriveChunks, isNotEmpty);
      expect(pack.isFromUserBook, isTrue);
      expect(pack.targetPage, 12);
    });

    test('GuidedFlowPhase ve TextDensityTier stratejileri doğru faz/çarpan döndürür', () {
      expect(
        GuidedFlowPhase.forProgress(0.10, scaffoldingEnabled: true),
        GuidedFlowPhase.overdrive,
      );
      expect(
        GuidedFlowPhase.forProgress(0.50, scaffoldingEnabled: true),
        GuidedFlowPhase.cruise,
      );
      expect(
        GuidedFlowPhase.forProgress(0.80, scaffoldingEnabled: true),
        GuidedFlowPhase.scaffoldingFade,
      );
      expect(
        GuidedFlowPhase.forProgress(0.95, scaffoldingEnabled: true),
        GuidedFlowPhase.unassistedFlow,
      );
      expect(
        GuidedFlowPhase.forProgress(0.95, scaffoldingEnabled: false),
        GuidedFlowPhase.cruise,
      );
      expect(
        TextDensityTier.fromComplexityLabel('Edebi & Düşünsel'),
        TextDensityTier.literary,
      );
      expect(
        TextDensityTier.fromComplexityLabel('Akıcı & Rahat'),
        TextDensityTier.fluent,
      );
    });

    test('calculateWpmMetrics Ham WPM ve Etkili WPM (E-WPM) değerlerini doğru hesaplar', () {
      final metrics = SpeedReadingEngine.calculateWpmMetrics(
        wordCount: 150,
        elapsedSeconds: 30.0,
        comprehensionPercent: 80,
      );
      expect(metrics.rawWpm, 300);
      expect(metrics.effectiveWpm, 240);
    });

    test('coordinatedTargetWpm, yoğunluk kalibrasyonu, ücretsiz fasıl ve gerilemeyen rankInfo doğru çalışır', () {
      expect(SpeedReadingExerciseType.values.length, 8);
      expect(SpeedReadingCurriculumCorpus.curriculumDays.length, 21);
      expect(SpeedReadingCurriculumCorpus.techniqueGuides.length, 7);
      expect(SpeedReadingCurriculumCorpus.passages.length, greaterThanOrEqualTo(8));

      final today = DateTime.now();
      final todayIso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final state = SpeedReadingProgressState(
        baselineWpm: 200,
        currentWpm: 300,
        bestEffectiveWpm: 270,
        averageComprehension: 88,
        bestSchulte5x5Seconds: 24.5,
        bestTachistoscopeMs: 65,
        activeStage: 1,
        completedCourseDays: const {1, 2, 3, 4},
        totalDrillsCompleted: 8,
        totalXp: 750,
        dailyStreak: 4,
        todayDrillsCount: 2,
        dailyGoalDrills: 3,
        lastBookReadingWpm: 250,
        previousBookReadingWpm: 250,
        regressionReason: 'Kitap okuma hızınız düştüğü için Kademe 6 ➔ Kademe 5 durağına çekildi.',
        recentPassageIds: const ['ibn_haldun_umran'],
        totalFasilsCompleted: 3,
        longestFasilMinutes: 12,
        todayFasilsCount: 1,
        lastFasilDateIso: todayIso,
        welcomeBackMessage: 'Tekrar hoş geldin!',
        lastDetectedDensityId: 'academic',
      );

      // Rank aktif kademeden bağımsız yalnızca XP ile korunur (750 XP -> seviye 3)
      expect(state.rankInfo.level, 3);
      expect(state.canStartFreeFasilToday(isPro: false), isFalse);
      expect(state.canStartFreeFasilToday(isPro: true), isTrue);
      expect(state.staminaMasteryMinutes, 12);
      expect(
        state.targetWpmForDensity(TextDensityTier.academic),
        lessThan(state.targetWpmForDensity(TextDensityTier.fluent)),
      );

      // (250 * 1.18).round() + (1 - 1) * 10 = 295 WPM
      expect(state.coordinatedTargetWpm, 295);
      expect(state.nextCourseDay, 1);
      expect(state.regressionReason, isNotNull);

      final cleared = state.copyWith(
        clearRegressionReason: true,
        clearWelcomeBackMessage: true,
      );
      expect(cleared.regressionReason, isNull);
      expect(cleared.welcomeBackMessage, isNull);

      final encoded = state.toJsonString();
      final decoded = SpeedReadingProgressState.fromJsonString(encoded);
      expect(decoded.lastBookReadingWpm, 250);
      expect(decoded.totalFasilsCompleted, 3);
      expect(decoded.longestFasilMinutes, 12);
      expect(decoded.todayFasilsCount, 1);
      expect(decoded.lastDetectedDensityId, 'academic');
      expect(decoded.recentPassageIds, contains('ibn_haldun_umran'));
    });
  });
}
