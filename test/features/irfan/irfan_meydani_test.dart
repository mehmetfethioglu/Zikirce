import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/database/zikir_seed_data.dart';
import 'package:zikirce/core/localization/app_localizations.dart';
import 'package:zikirce/core/theme/app_theme_colors.dart';
import 'package:zikirce/features/irfan/data/irfan_question_bank.dart';
import 'package:zikirce/features/irfan/data/irfan_repository.dart';
import 'package:zikirce/features/irfan/domain/irfan_models.dart';
import 'package:zikirce/features/irfan/presentation/widgets/irfan_poll_confetti_overlay.dart';
import 'package:zikirce/features/irfan/presentation/widgets/irfan_question_views.dart';
import 'package:zikirce/features/irfan/providers/irfan_providers.dart';
import 'package:zikirce/features/kuran/data/islamic_bookshelf_models.dart';

String _normalizeZikirLookup(String raw) {
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

Widget _wrapTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('tr'),
    theme: ThemeData(
      extensions: const [AppThemeColors.greenLight],
    ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

class _InMemoryIrfanStorage implements IrfanStoragePort {
  final Map<String, Object> _map = {};

  @override
  Future<bool?> getBool(String key) async => _map[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _map[key] as int?;

  @override
  Future<String?> getString(String key) async => _map[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => _map[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _map[key] = value;

  @override
  Future<void> setString(String key, String value) async => _map[key] = value;
}

class _FakeIrfanWallet implements IrfanWalletPort {
  int gold;
  int diamonds;
  final List<String> unlockedBadges = [];
  int streakActivityCalls = 0;

  _FakeIrfanWallet({this.gold = 0, this.diamonds = 0});

  @override
  Future<bool> spendGold(int amount) async {
    if (gold < amount) return false;
    gold -= amount;
    return true;
  }

  @override
  Future<bool> spendDiamonds(int amount) async {
    if (diamonds < amount) return false;
    diamonds -= amount;
    return true;
  }

  @override
  Future<void> addGold(int amount) async {
    gold += amount;
  }

  @override
  Future<void> addDiamonds(int amount) async {
    diamonds += amount;
  }

  @override
  Future<void> unlockBadgeById(String badgeId, String category) async {
    unlockedBadges.add(badgeId);
  }

  @override
  Future<void> recordDailyStreakActivity() async {
    streakActivityCalls++;
  }
}

void main() {
  group('İrfan Meydanı Külliyat & Sözleşme Doğrulaması', () {
    test('228+ sahih soru, Külliyat bağlantıları, benzersiz ID, TR/EN çift dil ve geçerli payload yapısına sahiptir', () {
      const source = DefaultIrfanQuestionSource();
      final all = source.allQuestions;
      expect(all.length, greaterThanOrEqualTo(228));

      final validBookIds = {
        for (final book in IslamicBookshelfCatalog.defaultBooks()) book.id,
      };
      final normalizedSeedZikirs = [
        for (final item in ZikirSeedData.defaultZikirs)
          _normalizeZikirLookup(item.name),
      ];

      final ids = <String>{};
      int multipleChoiceCount = 0;
      int trueFalseCount = 0;
      int matchingCount = 0;
      int linkedZikirCount = 0;
      int linkedBookCount = 0;
      int madhhabNotedCount = 0;

      for (final q in all) {
        expect(ids.add(q.id), isTrue, reason: 'Mükerrer soru ID: ${q.id}');
        expect(q.stem.tr.trim(), isNotEmpty);
        expect(q.stem.en.trim(), isNotEmpty);
        expect(q.hint.tr.trim(), isNotEmpty);
        expect(q.hint.en.trim(), isNotEmpty);
        expect(q.hikmet.explanation.tr.trim(), isNotEmpty);
        expect(q.hikmet.explanation.en.trim(), isNotEmpty);
        expect(q.hikmet.sourceRef.tr.trim(), isNotEmpty);
        expect(q.hikmet.sourceRef.en.trim(), isNotEmpty);

        final zikirKey = q.hikmet.linkedZikirKey?.trim();
        if (zikirKey != null && zikirKey.isNotEmpty) {
          linkedZikirCount++;
          final normKey = _normalizeZikirLookup(zikirKey);
          final hasSeedMatch = normalizedSeedZikirs.any(
            (seed) =>
                seed == normKey ||
                seed.contains(normKey) ||
                normKey.contains(seed),
          );
          expect(
            hasSeedMatch,
            isTrue,
            reason: 'ZikirSeedData eşleşmesi bulunamadı (${q.id}): $zikirKey',
          );
        }

        final bookId = q.hikmet.linkedBookId?.trim();
        if (bookId != null && bookId.isNotEmpty) {
          linkedBookCount++;
          expect(
            validBookIds.contains(bookId),
            isTrue,
            reason: 'Geçersiz Külliyat kitap ID (${q.id}): $bookId',
          );
        }

        if (q.hikmet.hanafiNote != null || q.hikmet.shafiiNote != null) {
          madhhabNotedCount++;
        }

        switch (q.payload) {
          case MultipleChoicePayload(:final options, :final correctIndex):
            multipleChoiceCount++;
            expect(options.length, greaterThanOrEqualTo(4));
            expect(correctIndex, inInclusiveRange(0, options.length - 1));
            for (final opt in options) {
              expect(opt.tr.trim(), isNotEmpty);
              expect(opt.en.trim(), isNotEmpty);
            }
          case TrueFalsePayload():
            trueFalseCount++;
          case MatchingPayload(:final pairs):
            matchingCount++;
            expect(pairs.length, greaterThanOrEqualTo(3));
            for (final pair in pairs) {
              expect(pair.left.tr.trim(), isNotEmpty);
              expect(pair.left.en.trim(), isNotEmpty);
              expect(pair.right.tr.trim(), isNotEmpty);
              expect(pair.right.en.trim(), isNotEmpty);
            }
        }
      }

      expect(multipleChoiceCount, greaterThan(0));
      expect(trueFalseCount, greaterThan(0));
      expect(matchingCount, greaterThan(0));
      expect(linkedZikirCount, greaterThanOrEqualTo(10));
      expect(linkedBookCount, greaterThanOrEqualTo(96));
      expect(madhhabNotedCount, greaterThan(0));

      for (final topic in IrfanTopic.values) {
        for (final tier in IrfanTier.values) {
          expect(
            IrfanQuestionBank.byNode(topic, tier).length,
            greaterThanOrEqualTo(19),
            reason: 'Eksik düğüm: $topic / $tier',
          );
        }
      }

      for (int farzId = 1; farzId <= 32; farzId++) {
        expect(
          IrfanQuestionBank.byFarzId(farzId),
          isNotEmpty,
          reason: '32 Farz bağlantısı eksik: Farz #$farzId',
        );
      }
    });
  });

  group('IrfanRepository — Günün 5 Sorusu, SM-2 Tekrar ve Oturum İzolasyonu', () {
    test('Cuma gününde temalı Günün 5 Sorusunu seçer, önbelleğe alır ve seriyi tekil ilerletir', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      // 2026-11-13 Cuma günüdür
      final friday = DateTime(2026, 11, 13, 14, 0);

      final daily1 = await repo.selectDailyFive(sessionId: 'default_user', now: friday);
      final daily2 = await repo.selectDailyFive(sessionId: 'default_user', now: friday);

      expect(daily1.length, 5);
      expect(daily2.map((q) => q.id).toList(), equals(daily1.map((q) => q.id).toList()));

      final summaryBefore = await repo.loadDashboardSummary(
        sessionId: 'default_user',
        now: friday,
      );
      expect(summaryBefore.isDailyCompleted, isFalse);
      expect(summaryBefore.activeThemeTag, equals('cuma'));

      final firstComplete = await repo.completeDailyFive(
        sessionId: 'default_user',
        correctCount: 4,
        now: friday,
      );
      expect(firstComplete.bonusAwardedNow, isTrue);
      expect(firstComplete.updatedStreakDays, 1);

      final duplicateComplete = await repo.completeDailyFive(
        sessionId: 'default_user',
        correctCount: 5,
        now: friday,
      );
      expect(duplicateComplete.bonusAwardedNow, isFalse);

      final saturday = DateTime(2026, 11, 14, 14, 0);
      final nextDayComplete = await repo.completeDailyFive(
        sessionId: 'default_user',
        correctCount: 5,
        now: saturday,
      );
      expect(nextDayComplete.bonusAwardedNow, isTrue);
      expect(nextDayComplete.updatedStreakDays, 2);
    });

    test('Yanlış cevap soruyu SM-2 kuyruğuna alır, doğru tekrarda ileri tarihe erteler ve profilleri izole tutar', () async {
      final storage = _InMemoryIrfanStorage();
      final repo = IrfanRepository(storage: storage);
      final now = DateTime(2026, 11, 12, 20, 0);
      final sampleQuestion = const DefaultIrfanQuestionSource().allQuestions.first;

      await repo.recordQuestionAttempt(
        sessionId: 'parent_session',
        question: sampleQuestion,
        mode: IrfanSessionMode.topicTier,
        isCorrect: false,
        usedHint: false,
        now: now,
      );

      final parentSummaryAfterMiss = await repo.loadDashboardSummary(
        sessionId: 'parent_session',
        now: now,
      );
      final childSummary = await repo.loadDashboardSummary(
        sessionId: 'child_session',
        now: now,
      );

      expect(parentSummaryAfterMiss.dueSm2Count, 1);
      expect(parentSummaryAfterMiss.totalSolved, 1);
      expect(childSummary.dueSm2Count, 0);
      expect(childSummary.totalSolved, 0);

      final dueList = await repo.selectSm2Review(
        sessionId: 'parent_session',
        now: now,
      );
      expect(dueList.first.id, equals(sampleQuestion.id));

      await repo.recordQuestionAttempt(
        sessionId: 'parent_session',
        question: sampleQuestion,
        mode: IrfanSessionMode.sm2Review,
        isCorrect: true,
        usedHint: false,
        now: now,
      );

      final parentSummaryAfterReview = await repo.loadDashboardSummary(
        sessionId: 'parent_session',
        now: now,
      );
      expect(parentSummaryAfterReview.dueSm2Count, 0);
      expect(parentSummaryAfterReview.totalSm2PoolCount, 1);
    });
  });

  group('İrfan Meydanı UX Davranışları (Okuma Tavsiyesi, Oturum Sonu Zikir, Konfeti)', () {
    testWidgets('Okuma tavsiyesi yalnız yanlış cevaplarda gösterilir, doğru cevaplarda gizlenir', (tester) async {
      const sampleHikmet = IrfanHikmetCard(
        explanation: LocalizedText(tr: 'Açıklama', en: 'Explanation'),
        sourceRef: LocalizedText(tr: 'Sahîh-i Buhârî', en: 'Sahih al-Bukhari'),
        linkedFarzId: 1,
        linkedBookId: 'book_hadith_buhari',
        linkedZikirKey: 'Kelime-i Tevhid',
      );

      await tester.pumpWidget(
        _wrapTestApp(
          SingleChildScrollView(
            child: IrfanHikmetCardView(
              hikmet: sampleHikmet,
              isCorrect: true,
              onPracticeZikir: null,
              onReadFarz: (_) {},
              onReadBook: (_) {},
              linkedBookTitle: 'Sahîh-i Buhârî',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Farz #1 İlmihal Maddesini Oku'), findsNothing);
      expect(find.textContaining('Külliyat\'ta Oku'), findsNothing);
      expect(find.textContaining('Bu Zikri Çek'), findsNothing);

      await tester.pumpWidget(
        _wrapTestApp(
          SingleChildScrollView(
            child: IrfanHikmetCardView(
              hikmet: sampleHikmet,
              isCorrect: false,
              onPracticeZikir: null,
              onReadFarz: (_) {},
              onReadBook: (_) {},
              linkedBookTitle: 'Sahîh-i Buhârî',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Farz #1 İlmihal Maddesini Oku'), findsOneWidget);
      expect(find.text('Külliyat\'ta Oku: Sahîh-i Buhârî'), findsOneWidget);
      expect(find.textContaining('Bu Zikri Çek'), findsNothing);
    });

    test('IrfanQuizSessionState.sessionLinkedZikirs oturumdaki zikirleri sırayla ve tekrarsız döndürür', () {
      const q1 = IrfanQuestion(
        id: 't1',
        topic: IrfanTopic.esmaDua,
        tier: IrfanTier.baslangic,
        stem: LocalizedText(tr: 'S1', en: 'Q1'),
        payload: TrueFalsePayload(correctAnswer: true),
        hint: LocalizedText(tr: 'İpucu', en: 'Hint'),
        hikmet: IrfanHikmetCard(
          explanation: LocalizedText(tr: 'A', en: 'A'),
          sourceRef: LocalizedText(tr: 'K', en: 'S'),
          linkedZikirKey: 'İstiğfar',
        ),
      );
      const q2 = IrfanQuestion(
        id: 't2',
        topic: IrfanTopic.siyer,
        tier: IrfanTier.baslangic,
        stem: LocalizedText(tr: 'S2', en: 'Q2'),
        payload: TrueFalsePayload(correctAnswer: true),
        hint: LocalizedText(tr: 'İpucu', en: 'Hint'),
        hikmet: IrfanHikmetCard(
          explanation: LocalizedText(tr: 'A', en: 'A'),
          sourceRef: LocalizedText(tr: 'K', en: 'S'),
          linkedZikirKey: 'Salavat-ı Şerif',
        ),
      );
      const q3 = IrfanQuestion(
        id: 't3',
        topic: IrfanTopic.esmaDua,
        tier: IrfanTier.orta,
        stem: LocalizedText(tr: 'S3', en: 'Q3'),
        payload: TrueFalsePayload(correctAnswer: true),
        hint: LocalizedText(tr: 'İpucu', en: 'Hint'),
        hikmet: IrfanHikmetCard(
          explanation: LocalizedText(tr: 'A', en: 'A'),
          sourceRef: LocalizedText(tr: 'K', en: 'S'),
          linkedZikirKey: 'istiğfar',
        ),
      );

      final session = IrfanQuizSessionState.initial().copyWith(
        questions: const [q1, q2, q3],
      );
      expect(session.sessionLinkedZikirs, equals(['İstiğfar', 'Salavat-ı Şerif']));
    });

    testWidgets('IrfanPollConfettiOverlay yalnız tetiklendiğinde animasyon çalıştırır ve temiz şekilde dispose edilir', (tester) async {
      final trigger = ValueNotifier<int>(0);
      addTearDown(trigger.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                IrfanPollConfettiOverlay(trigger: trigger),
              ],
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(IrfanPollConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      trigger.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.descendant(
          of: find.byType(IrfanPollConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.descendant(
          of: find.byType(IrfanPollConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('IrfanHikmetCardView doğru cevapta +0 altın göstermez, yanlışta İrfan Kalkanı butonunu sunar', (tester) async {
      const sampleHikmet = IrfanHikmetCard(
        explanation: LocalizedText(tr: 'Açıklama', en: 'Explanation'),
        sourceRef: LocalizedText(tr: 'Sahîh-i Buhârî', en: 'Sahih al-Bukhari'),
        linkedFarzId: 1,
        linkedBookId: 'book_hadith_buhari',
      );
      int shieldTapped = 0;

      await tester.pumpWidget(
        _wrapTestApp(
          const SingleChildScrollView(
            child: IrfanHikmetCardView(
              hikmet: sampleHikmet,
              isCorrect: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('+0 🪙'), findsNothing);
      expect(find.textContaining('İrfan Kalkanı'), findsNothing);

      await tester.pumpWidget(
        _wrapTestApp(
          SingleChildScrollView(
            child: IrfanHikmetCardView(
              hikmet: sampleHikmet,
              isCorrect: false,
              onUseMistakeShield: () => shieldTapped++,
            ),
          ),
        ),
      );
      await tester.pump();
      final shieldBtn = find.text('🛡️ İrfan Kalkanı ile Telafi Et (5 💎)');
      expect(shieldBtn, findsOneWidget);
      await tester.tap(shieldBtn);
      await tester.pump();
      expect(shieldTapped, 1);
    });
  });

  group('İrfan Meydanı Seçenek 1 Ekonomi, Kum Saati ve Elmas İmtiyazları', () {
    test('IrfanEconomyConfig beklenen hibrit ekonomi sabitlerini korur', () {
      expect(IrfanEconomyConfig.goldEntryCostForTier(IrfanTier.baslangic), 40);
      expect(IrfanEconomyConfig.goldEntryCostForTier(IrfanTier.orta), 75);
      expect(IrfanEconomyConfig.goldEntryCostForTier(IrfanTier.irfan), 120);
      expect(IrfanEconomyConfig.irfanTierDiamondEntryCost, 15);
      expect(IrfanEconomyConfig.extraDailyOrSm2DiamondCost, 5);
      expect(IrfanEconomyConfig.correctGoldReward, 0);
      expect(IrfanEconomyConfig.initialSessionSeconds, 90);
      expect(IrfanEconomyConfig.timeExtensionSeconds, 30);
      expect(IrfanEconomyConfig.timeExtensionGoldCost, 30);
      expect(IrfanEconomyConfig.timeExtensionDiamondCost, 5);
      expect(IrfanEconomyConfig.fiftyFiftyGoldCost, 40);
      expect(IrfanEconomyConfig.fiftyFiftyDiamondCost, 5);
      expect(IrfanEconomyConfig.hintGoldCost, 25);
      expect(IrfanEconomyConfig.hintDiamondCost, 3);
      expect(IrfanEconomyConfig.swapOrShieldDiamondCost, 5);
    });

    test('Günün 5 Sorusu ilk turda ücretsizdir ve ödül verir; aynı gün ekstra tur 5 elmas ister', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      final wallet = _FakeIrfanWallet(gold: 0, diamonds: 6);
      final notifier = IrfanQuizNotifier.forTesting(
        repository: repo,
        wallet: wallet,
      );
      addTearDown(notifier.dispose);
      final day = DateTime(2026, 11, 13, 19, 30);

      final firstStarted = await notifier.startDailyFive(now: day);
      expect(firstStarted, isTrue);
      expect(notifier.state.spentGold, 0);
      expect(notifier.state.spentDiamonds, 0);
      expect(notifier.state.remainingSeconds, 90);

      for (int i = 0; i < notifier.state.questions.length; i++) {
        final q = notifier.state.currentQuestion!;
        switch (q.payload) {
          case MultipleChoicePayload(:final correctIndex):
            await notifier.submitChoice(correctIndex);
          case TrueFalsePayload(:final correctAnswer):
            await notifier.submitTrueFalse(correctAnswer);
          case MatchingPayload():
            await notifier.submitMatching(mistakesCount: 0);
        }
        await notifier.nextQuestion();
      }

      expect(notifier.state.isFinished, isTrue);
      expect(notifier.state.earnedGold, 30);
      expect(notifier.state.earnedDiamonds, 1);
      expect(wallet.gold, 30);
      expect(wallet.diamonds, 7);

      // Extra round same day costs 5 diamonds -> succeeds when diamonds == 7 -> 2 remaining
      final secondStarted = await notifier.startDailyFive(now: day);
      expect(secondStarted, isTrue);
      expect(notifier.state.spentDiamonds, 5);
      expect(wallet.diamonds, 2);

      // Third round requires another 5 diamonds -> blocked because diamonds == 2
      final thirdStarted = await notifier.startDailyFive(now: day);
      expect(thirdStarted, isFalse);
      expect(wallet.diamonds, 2);
    });

    test('SM-2 ilk günlük tekrar ücretsizdir, cevap sonrası aynı gün ikinci tekrar 5 elmas harcar', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      final wallet = _FakeIrfanWallet(gold: 0, diamonds: 4);
      final notifier = IrfanQuizNotifier.forTesting(
        repository: repo,
        wallet: wallet,
      );
      addTearDown(notifier.dispose);
      final day = DateTime(2026, 11, 13, 20, 0);

      expect(await notifier.startSm2Review(now: day), isTrue);
      expect(wallet.diamonds, 4);

      final q = notifier.state.currentQuestion!;
      switch (q.payload) {
        case MultipleChoicePayload(:final correctIndex):
          await notifier.submitChoice(correctIndex);
        case TrueFalsePayload(:final correctAnswer):
          await notifier.submitTrueFalse(correctAnswer);
        case MatchingPayload():
          await notifier.submitMatching(mistakesCount: 0);
      }

      // Now free daily right was used and diamonds == 4 < 5
      expect(await notifier.startSm2Review(now: day), isFalse);

      wallet.diamonds = 5;
      expect(await notifier.startSm2Review(now: day), isTrue);
      expect(wallet.diamonds, 0);
      expect(notifier.state.spentDiamonds, 5);
    });

    test('İlim Halkaları kademeleri Altın/Elmas harcı alır ve bakiye yetersizse başlatmaz', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      final wallet = _FakeIrfanWallet(gold: 100, diamonds: 20);
      final notifier = IrfanQuizNotifier.forTesting(
        repository: repo,
        wallet: wallet,
      );
      addTearDown(notifier.dispose);

      // İrfan tier costs 120 Gold -> fails with 100 Gold
      expect(
        await notifier.startTopicQuiz(
          IrfanTopic.quran,
          IrfanTier.irfan,
          useDiamonds: false,
        ),
        isFalse,
      );
      expect(wallet.gold, 100);

      // Başlangıç costs 40 Gold -> succeeds (60 remaining)
      expect(
        await notifier.startTopicQuiz(
          IrfanTopic.ilmihal32Farz,
          IrfanTier.baslangic,
        ),
        isTrue,
      );
      expect(wallet.gold, 60);
      expect(notifier.state.spentGold, 40);

      // Orta costs 75 Gold -> fails with 60 Gold
      expect(
        await notifier.startTopicQuiz(IrfanTopic.siyer, IrfanTier.orta),
        isFalse,
      );

      // İrfan tier with 15 Diamonds -> succeeds (5 remaining)
      expect(
        await notifier.startTopicQuiz(
          IrfanTopic.esmaDua,
          IrfanTier.irfan,
          useDiamonds: true,
        ),
        isTrue,
      );
      expect(wallet.diamonds, 5);
      expect(notifier.state.spentDiamonds, 15);
    });

    test('Akıllı Kum Saati cevaptan sonra durur, süre bitince cevaplamayı kilitler ve +30 sn ile açılır', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      final wallet = _FakeIrfanWallet(gold: 100, diamonds: 10);
      final notifier = IrfanQuizNotifier.forTesting(
        repository: repo,
        wallet: wallet,
      );
      addTearDown(notifier.dispose);

      await notifier.startTopicQuiz(
        IrfanTopic.ilmihal32Farz,
        IrfanTier.baslangic,
      );
      expect(notifier.state.remainingSeconds, 90);

      // Drain hourglass to 0
      for (int i = 0; i < 95; i++) {
        notifier.tickSecond();
      }
      expect(notifier.state.remainingSeconds, 0);
      expect(notifier.state.isTimeUp, isTrue);

      // Submitting while time is up must be blocked
      final q = notifier.state.currentQuestion!;
      if (q.payload is MultipleChoicePayload) {
        await notifier.submitChoice(0);
      } else if (q.payload is TrueFalsePayload) {
        await notifier.submitTrueFalse(true);
      } else {
        await notifier.submitMatching(mistakesCount: 0);
      }
      expect(notifier.state.isAnswered, isFalse);

      // Extend time +30s with 30 Gold (60 -> 30 remaining)
      expect(await notifier.extendSessionTime(useDiamonds: false), isTrue);
      expect(notifier.state.remainingSeconds, 30);
      expect(notifier.state.isTimeUp, isFalse);
      expect(wallet.gold, 30);

      // Submit an answer -> hourglass pauses on Hikmet reading
      if (q.payload is MultipleChoicePayload) {
        await notifier.submitChoice(0);
      } else if (q.payload is TrueFalsePayload) {
        await notifier.submitTrueFalse(true);
      } else {
        await notifier.submitMatching(mistakesCount: 0);
      }
      expect(notifier.state.isAnswered, isTrue);
      final pausedSeconds = notifier.state.remainingSeconds;
      notifier.tickSecond();
      notifier.tickSecond();
      expect(notifier.state.remainingSeconds, pausedSeconds);
    });

    test('Soru Değiştir (5 💎) ve İrfan Kalkanı (5 💎) doğru çalışır ve bakiyeden düşer', () async {
      final repo = IrfanRepository(storage: _InMemoryIrfanStorage());
      final wallet = _FakeIrfanWallet(gold: 200, diamonds: 12);
      final notifier = IrfanQuizNotifier.forTesting(
        repository: repo,
        wallet: wallet,
      );
      addTearDown(notifier.dispose);

      await notifier.startTopicQuiz(IrfanTopic.ilmihal32Farz, IrfanTier.baslangic);
      final originalId = notifier.state.currentQuestion!.id;

      // Swap question once for 5 Diamonds
      expect(await notifier.useSwapQuestionJoker(), isTrue);
      expect(wallet.diamonds, 7);
      expect(notifier.state.isQuestionSwapped, isTrue);
      expect(notifier.state.currentQuestion!.id, isNot(equals(originalId)));
      // Second swap on same question slot is prevented
      expect(await notifier.useSwapQuestionJoker(), isFalse);

      // Deliberately submit wrong answer
      final q = notifier.state.currentQuestion!;
      switch (q.payload) {
        case MultipleChoicePayload(:final options, :final correctIndex):
          final wrongIdx = (correctIndex + 1) % options.length;
          await notifier.submitChoice(wrongIdx);
        case TrueFalsePayload(:final correctAnswer):
          await notifier.submitTrueFalse(!correctAnswer);
        case MatchingPayload():
          await notifier.submitMatching(mistakesCount: 3);
      }
      expect(notifier.state.isAnswered, isTrue);
      expect(notifier.state.isCurrentCorrect, isFalse);
      expect(notifier.state.correctCount, 0);

      // Redeem wrong answer with İrfan Kalkanı (5 Diamonds -> 2 remaining)
      expect(await notifier.useMistakeShield(), isTrue);
      expect(wallet.diamonds, 2);
      expect(notifier.state.isCurrentCorrect, isTrue);
      expect(notifier.state.isShieldUsedOnCurrent, isTrue);
      expect(notifier.state.correctCount, 1);
      // Cannot use shield twice on same question
      expect(await notifier.useMistakeShield(), isFalse);
    });
  });
}
