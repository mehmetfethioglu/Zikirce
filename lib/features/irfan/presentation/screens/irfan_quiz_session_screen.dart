import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../kuran/data/islamic_bookshelf_models.dart';
import '../../domain/irfan_models.dart';
import '../../providers/irfan_providers.dart';
import '../widgets/irfan_poll_confetti_overlay.dart';
import '../widgets/irfan_question_views.dart';
import '../widgets/irfan_seljuk_star_painter.dart';
import '../widgets/irfan_share_preview_modal.dart';

/// İrfan Meydanı Oturum Ekranı (Akıllı Kum Saati, Altın/Elmas jokerleri, Elmas Kalkanı, Hikmet Kartı).
class IrfanQuizSessionScreen extends ConsumerStatefulWidget {
  const IrfanQuizSessionScreen({super.key});

  @override
  ConsumerState<IrfanQuizSessionScreen> createState() =>
      _IrfanQuizSessionScreenState();
}

class _IrfanQuizSessionScreenState extends ConsumerState<IrfanQuizSessionScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _confettiTrigger = ValueNotifier<int>(0);
  Timer? _sessionTimer;
  bool _isAppResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onTimerTick,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final session = ref.read(irfanQuizNotifierProvider);
      if (session.questions.isEmpty) {
        final started =
            await ref.read(irfanQuizNotifierProvider.notifier).startDailyFive();
        if (!started && mounted) {
          _closeSession();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
  }

  void _onTimerTick(Timer timer) {
    if (!mounted || !_isAppResumed) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    ref.read(irfanQuizNotifierProvider.notifier).tickSecond();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _confettiTrigger.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _closeSession() {
    HapticService.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/irfan');
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToHikmet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = (_scrollController.position.maxScrollExtent * 0.72)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      irfanQuizNotifierProvider.select((s) => s.isAnswered),
      (prev, next) {
        if (prev == false && next == true) {
          final isCorrect = ref.read(irfanQuizNotifierProvider).isCurrentCorrect;
          if (isCorrect == true) {
            HapticService.roundCompleted();
            _confettiTrigger.value++;
          } else {
            HapticService.lightImpact();
          }
          _scrollToHikmet();
        } else if (prev == true && next == false) {
          _scrollToTop();
        }
      },
    );

    ref.listen<bool>(
      irfanQuizNotifierProvider.select((s) => s.isShieldUsedOnCurrent),
      (prev, next) {
        if (prev == false && next == true) {
          HapticService.roundCompleted();
          _confettiTrigger.value++;
        }
      },
    );

    final colors = context.colors;
    final isFinished = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isFinished),
    );
    final isEmpty = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.questions.isEmpty),
    );
    final isTimeUp = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isTimeUp),
    );

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isEmpty)
              Center(
                child: CircularProgressIndicator(color: colors.accent),
              )
            else if (isFinished)
              _QuizCelebrationView(onReturnToHub: _closeSession)
            else
              Column(
                children: [
                  _QuizTopHeader(onClose: _closeSession),
                  Expanded(
                    child: _QuizActiveQuestionBody(
                      scrollController: _scrollController,
                    ),
                  ),
                  const _QuizBottomAdvanceBar(),
                ],
              ),
            if (!isEmpty && !isFinished && isTimeUp) const _QuizTimeUpOverlay(),
            IrfanPollConfettiOverlay(trigger: _confettiTrigger),
          ],
        ),
      ),
    );
  }
}

class _QuizTopHeader extends ConsumerWidget {
  final VoidCallback onClose;

  const _QuizTopHeader({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    final mode = ref.watch(irfanQuizNotifierProvider.select((s) => s.mode));
    final topic =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.activeTopic));
    final currentIndex =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.currentIndex));
    final total =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.questions.length));
    final progress =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.progress));
    final isAnswered =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.isAnswered));

    final gold = ref.watch(goldCountProvider.select((v) => v.valueOrNull ?? 0));
    final diamonds =
        ref.watch(diamondCountProvider.select((v) => v.valueOrNull ?? 0));

    final title = topic != null ? topic.label(isTr) : mode.label(isTr);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: colors.primaryText),
                tooltip: isTr ? 'Kapat' : 'Close',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      isAnswered
                          ? (isTr
                              ? 'Soru ${currentIndex + 1} / $total • ⏸ Hikmet Okuması'
                              : 'Question ${currentIndex + 1} / $total • ⏸ Paused')
                          : (isTr
                              ? 'Soru ${currentIndex + 1} / $total'
                              : 'Question ${currentIndex + 1} / $total'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const _QuizHourglassPill(),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderStroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🪙 $gold',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '💎 $diamonds',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: colors.borderStroke,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizHourglassPill extends ConsumerWidget {
  const _QuizHourglassPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final remainingSeconds = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.remainingSeconds),
    );
    final formatted = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.formattedRemainingTime),
    );
    final isAnswered = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isAnswered),
    );
    final isFinished = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isFinished),
    );

    final bool isCritical = !isAnswered && remainingSeconds <= 10;
    final bool isWarning = !isAnswered && remainingSeconds <= 25;
    final Color tint = isAnswered
        ? colors.secondaryTextAlt
        : isCritical
            ? const Color(0xFFDC2626)
            : isWarning
                ? const Color(0xFFD97706)
                : colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isFinished
            ? null
            : () => _openTimeExtensionSheet(context, ref),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withValues(alpha: 0.45)),
          ),
          child: Text(
            '${isAnswered ? '⏸' : '⏳'} $formatted',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tint,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openTimeExtensionSheet(BuildContext context, WidgetRef ref) async {
  HapticService.selectionClick();
  final isTr = context.l10n.isTurkish;
  final gold = ref.read(goldCountProvider).valueOrNull ?? 0;
  final diamonds = ref.read(diamondCountProvider).valueOrNull ?? 0;

  final choice = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _JokerCurrencySheet(
      title: isTr
          ? '+${IrfanEconomyConfig.timeExtensionSeconds} sn Süre Uzatma'
          : '+${IrfanEconomyConfig.timeExtensionSeconds}s Time Extension',
      goldCost: IrfanEconomyConfig.timeExtensionGoldCost,
      diamondCost: IrfanEconomyConfig.timeExtensionDiamondCost,
      currentGold: gold,
      currentDiamonds: diamonds,
    ),
  );

  if (choice == null || !context.mounted) return;
  final ok = await ref
      .read(irfanQuizNotifierProvider.notifier)
      .extendSessionTime(useDiamonds: choice);
  if (!context.mounted) return;
  if (ok) {
    HapticService.lightImpact();
  } else {
    _showInsufficientBalanceNotice(context, isTr);
  }
}

void _showInsufficientBalanceNotice(BuildContext context, bool isTr) {
  HapticService.error();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isTr
            ? 'Yeterli Altın veya Elmas bakiyesi bulunmuyor.'
            : 'Insufficient Gold or Diamond balance.',
      ),
      action: SnackBarAction(
        label: isTr ? 'Dönüştür' : 'Convert',
        onPressed: () => GoldDiamondExchangeSheet.show(context),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class _QuizActiveQuestionBody extends ConsumerWidget {
  final ScrollController scrollController;

  const _QuizActiveQuestionBody({required this.scrollController});

  static final Map<String, String> _bookShortTitles = {
    for (final b in IslamicBookshelfCatalog.defaultBooks()) b.id: b.shortTitle,
  };

  void _handleReadFarz(BuildContext context, int farzId) {
    context.push('/fiqh?farzId=$farzId');
  }

  void _handleReadBook(BuildContext context, String bookId) {
    context.push('/kulliyat?bookId=$bookId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.currentQuestion),
    );
    if (question == null) {
      return const SizedBox.shrink();
    }

    final isAnswered = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isAnswered),
    );
    final isCurrentCorrect = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isCurrentCorrect),
    );
    final selectedChoiceIndex = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.selectedChoiceIndex),
    );
    final selectedBoolAnswer = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.selectedBoolAnswer),
    );
    final eliminatedIndices = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.eliminatedOptionIndices),
    );
    final isHintRevealed = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isHintRevealed),
    );
    final isQuestionSwapped = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isQuestionSwapped),
    );
    final isShieldUsedOnCurrent = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isShieldUsedOnCurrent),
    );

    final notifier = ref.read(irfanQuizNotifierProvider.notifier);
    final isTr = context.l10n.isTurkish;
    final colors = context.colors;
    final madhhabBadge = question.madhhabScope.badgeLabel(isTr);

    Future<void> handleMistakeShield() async {
      final ok = await notifier.useMistakeShield();
      if (!context.mounted) return;
      if (!ok) {
        _showInsufficientBalanceNotice(context, isTr);
      }
    }

    return ListView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Soru Kökü Kartı
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _QuestionMetaChip(
                    label: '${question.topic.emoji} ${question.topic.label(isTr)}',
                    color: colors.accent,
                  ),
                  _QuestionMetaChip(
                    label: question.tier.label(isTr),
                    color: colors.secondaryText,
                  ),
                  if (madhhabBadge != null)
                    _QuestionMetaChip(
                      label: madhhabBadge,
                      color: const Color(0xFF9C6B30),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                question.stem.resolve(isTr),
                style: TextStyle(
                  fontSize: 16.5,
                  height: 1.46,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Joker Çubuğu (Henüz cevaplanmadıysa)
        if (!isAnswered) ...[
          _QuizJokerToolbar(
            canUseFiftyFifty: question.payload is MultipleChoicePayload &&
                eliminatedIndices.isEmpty,
            canUseHint: !isHintRevealed,
            canUseSwap: !isQuestionSwapped,
          ),
          const SizedBox(height: 12),
        ],

        // Açılan İpucu Kutusu
        if (isHintRevealed) ...[
          _RevealedHintBanner(hintText: question.hint.resolve(isTr)),
          const SizedBox(height: 12),
        ],

        // Pedagojik Etkileşim Görünümü (Çoktan Seçmeli / D-Y / Eşleştirme)
        switch (question.payload) {
          final MultipleChoicePayload mc => IrfanMultipleChoiceView(
              payload: mc,
              eliminatedOptionIndices: eliminatedIndices,
              isAnswered: isAnswered,
              selectedChoiceIndex: selectedChoiceIndex,
              onSelectOption: (idx) {
                HapticService.selectionClick();
                notifier.submitChoice(idx);
              },
            ),
          final TrueFalsePayload tf => IrfanTrueFalseView(
              payload: tf,
              isAnswered: isAnswered,
              selectedBoolAnswer: selectedBoolAnswer,
              onSelectAnswer: (val) {
                HapticService.selectionClick();
                notifier.submitTrueFalse(val);
              },
            ),
          final MatchingPayload mp => IrfanMatchingView(
              questionId: question.id,
              payload: mp,
              isAnswered: isAnswered,
              onCompleted: (mistakes) {
                notifier.submitMatching(mistakesCount: mistakes);
              },
            ),
        },

        // Cevap Sonrası Hikmet & Sahih Kaynak Kartı
        if (isAnswered) ...[
          const SizedBox(height: 18),
          IrfanHikmetCardView(
            hikmet: question.hikmet,
            isCorrect: isCurrentCorrect ?? false,
            onPracticeZikir: null,
            onReadFarz: (farzId) => _handleReadFarz(context, farzId),
            onReadBook: (bookId) => _handleReadBook(context, bookId),
            linkedBookTitle: question.hikmet.linkedBookId != null
                ? _bookShortTitles[question.hikmet.linkedBookId!]
                : null,
            isShieldUsed: isShieldUsedOnCurrent,
            onUseMistakeShield: (!isShieldUsedOnCurrent && isCurrentCorrect == false)
                ? handleMistakeShield
                : null,
          ),
        ],
      ],
    );
  }
}

class _QuestionMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _QuestionMetaChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _RevealedHintBanner extends StatelessWidget {
  final String hintText;

  const _RevealedHintBanner({required this.hintText});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const Color gold = Color(0xFFD4A574);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: colors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizJokerToolbar extends ConsumerWidget {
  final bool canUseFiftyFifty;
  final bool canUseHint;
  final bool canUseSwap;

  const _QuizJokerToolbar({
    required this.canUseFiftyFifty,
    required this.canUseHint,
    required this.canUseSwap,
  });

  Future<void> _openJokerPaymentSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required int goldCost,
    required int diamondCost,
    required Future<bool> Function(bool useDiamonds) onRedeem,
  }) async {
    HapticService.selectionClick();
    final isTr = context.l10n.isTurkish;
    final gold = ref.read(goldCountProvider).valueOrNull ?? 0;
    final diamonds = ref.read(diamondCountProvider).valueOrNull ?? 0;

    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JokerCurrencySheet(
        title: title,
        goldCost: goldCost,
        diamondCost: diamondCost,
        currentGold: gold,
        currentDiamonds: diamonds,
      ),
    );

    if (choice == null || !context.mounted) return;
    final ok = await onRedeem(choice);
    if (!context.mounted) return;
    if (ok) {
      HapticService.lightImpact();
    } else {
      _showInsufficientBalanceNotice(context, isTr);
    }
  }

  Future<void> _useSwapJoker(
    BuildContext context,
    WidgetRef ref,
    bool isTr,
  ) async {
    HapticService.selectionClick();
    final ok =
        await ref.read(irfanQuizNotifierProvider.notifier).useSwapQuestionJoker();
    if (!context.mounted) return;
    if (ok) {
      HapticService.lightImpact();
    } else {
      _showInsufficientBalanceNotice(context, isTr);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canUseFiftyFifty && !canUseHint && !canUseSwap) {
      return const SizedBox.shrink();
    }
    final isTr = context.l10n.isTurkish;
    final notifier = ref.read(irfanQuizNotifierProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canUseFiftyFifty)
          _JokerActionChip(
            icon: Icons.filter_2_rounded,
            label: isTr ? '%50 Eleme' : '50/50',
            costLabel:
                '${IrfanEconomyConfig.fiftyFiftyGoldCost}🪙 / ${IrfanEconomyConfig.fiftyFiftyDiamondCost}💎',
            onTap: () => _openJokerPaymentSheet(
              context: context,
              ref: ref,
              title: isTr ? '%50 Şık Eleme Jokeri' : '50/50 Elimination Joker',
              goldCost: IrfanEconomyConfig.fiftyFiftyGoldCost,
              diamondCost: IrfanEconomyConfig.fiftyFiftyDiamondCost,
              onRedeem: (useDiamonds) =>
                  notifier.useFiftyFiftyJoker(useDiamonds: useDiamonds),
            ),
          ),
        if (canUseHint)
          _JokerActionChip(
            icon: Icons.lightbulb_outline_rounded,
            label: isTr ? 'İpucu Aç' : 'Hint',
            costLabel:
                '${IrfanEconomyConfig.hintGoldCost}🪙 / ${IrfanEconomyConfig.hintDiamondCost}💎',
            onTap: () => _openJokerPaymentSheet(
              context: context,
              ref: ref,
              title: isTr ? 'İrfan İpucu Jokeri' : 'Wisdom Hint Joker',
              goldCost: IrfanEconomyConfig.hintGoldCost,
              diamondCost: IrfanEconomyConfig.hintDiamondCost,
              onRedeem: (useDiamonds) =>
                  notifier.useHintJoker(useDiamonds: useDiamonds),
            ),
          ),
        if (canUseSwap)
          _JokerActionChip(
            icon: Icons.autorenew_rounded,
            label: isTr ? 'Soru Değiştir' : 'Swap',
            costLabel: '${IrfanEconomyConfig.swapOrShieldDiamondCost}💎',
            onTap: () => _useSwapJoker(context, ref, isTr),
          ),
      ],
    );
  }
}

class _JokerActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String costLabel;
  final VoidCallback onTap;

  const _JokerActionChip({
    required this.icon,
    required this.label,
    required this.costLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colors.accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                costLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryTextAlt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JokerCurrencySheet extends StatelessWidget {
  final String title;
  final int goldCost;
  final int diamondCost;
  final int currentGold;
  final int currentDiamonds;

  const _JokerCurrencySheet({
    required this.title,
    required this.goldCost,
    required this.diamondCost,
    required this.currentGold,
    required this.currentDiamonds,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final canPayGold = currentGold >= goldCost;
    final canPayDiamond = currentDiamonds >= diamondCost;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.secondaryTextAlt.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canPayGold
                        ? () => Navigator.of(context).pop(false)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: canPayGold ? colors.accent : colors.borderStroke,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isTr
                          ? '🪙 $goldCost Altın Kullan'
                          : '🪙 Spend $goldCost Gold',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canPayGold
                            ? colors.primaryText
                            : colors.secondaryTextAlt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canPayDiamond
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color:
                            canPayDiamond ? colors.accent : colors.borderStroke,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isTr
                          ? '💎 $diamondCost Elmas Kullan'
                          : '💎 Spend $diamondCost Diamond',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canPayDiamond
                            ? colors.primaryText
                            : colors.secondaryTextAlt,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizBottomAdvanceBar extends ConsumerWidget {
  const _QuizBottomAdvanceBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnswered = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.isAnswered),
    );
    if (!isAnswered) {
      return const SizedBox.shrink();
    }

    final currentIndex = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.currentIndex),
    );
    final total = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.questions.length),
    );
    final isLast = currentIndex + 1 >= total;
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(top: BorderSide(color: colors.borderStroke)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            HapticService.selectionClick();
            ref.read(irfanQuizNotifierProvider.notifier).nextQuestion();
          },
          icon: Icon(
            isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
            size: 19,
            color: Colors.white,
          ),
          label: Text(
            isLast
                ? (isTr ? 'Halkayı Tamamla' : 'Complete Session')
                : (isTr ? 'Sonraki Soru' : 'Next Question'),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizTimeUpOverlay extends ConsumerWidget {
  const _QuizTimeUpOverlay();

  Future<void> _extend(
    BuildContext context,
    WidgetRef ref, {
    required bool useDiamonds,
  }) async {
    HapticService.selectionClick();
    final ok = await ref
        .read(irfanQuizNotifierProvider.notifier)
        .extendSessionTime(useDiamonds: useDiamonds);
    if (!context.mounted) return;
    if (ok) {
      HapticService.lightImpact();
    } else {
      _showInsufficientBalanceNotice(context, context.l10n.isTurkish);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final gold = ref.watch(goldCountProvider.select((v) => v.valueOrNull ?? 0));
    final diamonds =
        ref.watch(diamondCountProvider.select((v) => v.valueOrNull ?? 0));

    final bool canPayGold = gold >= IrfanEconomyConfig.timeExtensionGoldCost;
    final bool canPayDiamond =
        diamonds >= IrfanEconomyConfig.timeExtensionDiamondCost;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.56),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.borderStroke),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏳', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 10),
                Text(
                  isTr ? 'Kum Saati Doldu' : 'Hourglass Expired',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTr
                      ? 'İlerlemeniz güvende. Oturuma +${IrfanEconomyConfig.timeExtensionSeconds} saniye ekleyerek devam edebilir veya mevcut sonuçla halkayı tamamlayabilirsiniz.'
                      : 'Your progress is saved. Add +${IrfanEconomyConfig.timeExtensionSeconds}s to continue, or conclude with your current score.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.42,
                    color: colors.secondaryTextAlt,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '🪙 $gold   •   💎 $diamonds',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canPayGold
                            ? () => _extend(context, ref, useDiamonds: false)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          disabledBackgroundColor: colors.borderStroke,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '+${IrfanEconomyConfig.timeExtensionSeconds} sn • ${IrfanEconomyConfig.timeExtensionGoldCost} 🪙',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: canPayDiamond
                            ? () => _extend(context, ref, useDiamonds: true)
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: canPayDiamond
                                ? colors.accent
                                : colors.borderStroke,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          '+${IrfanEconomyConfig.timeExtensionSeconds} sn • ${IrfanEconomyConfig.timeExtensionDiamondCost} 💎',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: canPayDiamond
                                ? colors.primaryText
                                : colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => GoldDiamondExchangeSheet.show(context),
                  child: Text(
                    isTr
                        ? 'Altın ➔ Elmas Dönüştür'
                        : 'Convert Gold ➔ Diamond',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticService.selectionClick();
                      ref
                          .read(irfanQuizNotifierProvider.notifier)
                          .finishSessionEarly();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colors.borderStroke),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isTr
                          ? 'Halkayı Mevcut Sonuçla Bitir'
                          : 'Finish Session Now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizCelebrationView extends ConsumerWidget {
  final VoidCallback onReturnToHub;

  const _QuizCelebrationView({required this.onReturnToHub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    final mode = ref.watch(irfanQuizNotifierProvider.select((s) => s.mode));
    final topic =
        ref.watch(irfanQuizNotifierProvider.select((s) => s.activeTopic));
    final correctCount = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.correctCount),
    );
    final questions = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.questions),
    );
    final earnedGold = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.earnedGold),
    );
    final earnedDiamonds = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.earnedDiamonds),
    );
    final spentGold = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.spentGold),
    );
    final spentDiamonds = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.spentDiamonds),
    );
    final streakDays = ref.watch(
      irfanDashboardProvider.select((v) => v.valueOrNull?.irfanStreakDays ?? 0),
    );
    final sessionZikirs = ref.watch(
      irfanQuizNotifierProvider.select((s) => s.sessionLinkedZikirs),
    );

    final sessionTitle = topic != null ? topic.label(isTr) : mode.label(isTr);
    final featuredQuestion = questions.firstOrNull;
    final featuredQuote = featuredQuestion != null
        ? featuredQuestion.hikmet.explanation.resolve(isTr)
        : (isTr
            ? 'İlim öğrenmek her Müslüman üzerine farzdır.'
            : 'Seeking knowledge is an obligation upon every Muslim.');
    final featuredSource = featuredQuestion != null
        ? featuredQuestion.hikmet.sourceRef.resolve(isTr)
        : (isTr ? 'İbn Mâce, Mukaddime, 17' : 'Ibn Majah, Muqaddimah, 17');

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.72, end: 1.0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: IrfanSeljukStarBadge(
                  size: 62,
                  color: colors.accent,
                  accentColor: const Color(0xFFD4A574),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTr ? 'İrfan Halkası Tamamlandı!' : 'Wisdom Circle Complete!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sessionTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.secondaryTextAlt,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _RewardSummaryChip(
                  emoji: '🎯',
                  label: isTr
                      ? '$correctCount / ${questions.length} Doğru'
                      : '$correctCount / ${questions.length} Correct',
                ),
                if (earnedGold > 0)
                  _RewardSummaryChip(
                    emoji: '🪙',
                    label: '+$earnedGold ${isTr ? 'Altın' : 'Gold'}',
                  ),
                if (earnedDiamonds > 0)
                  _RewardSummaryChip(
                    emoji: '💎',
                    label: '+$earnedDiamonds ${isTr ? 'Elmas' : 'Diamond'}',
                  ),
                if (spentGold > 0)
                  _RewardSummaryChip(
                    emoji: '🪙',
                    label: '-$spentGold ${isTr ? 'Harcandı' : 'Spent'}',
                  ),
                if (spentDiamonds > 0)
                  _RewardSummaryChip(
                    emoji: '💎',
                    label: '-$spentDiamonds ${isTr ? 'Harcandı' : 'Spent'}',
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Column(
                children: [
                  Text(
                    '“$featuredQuote”',
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.48,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    featuredSource,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
            if (sessionZikirs.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SessionZikirPromptCard(zikirKeys: sessionZikirs),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticService.selectionClick();
                  IrfanSharePreviewModal.show(
                    context: context,
                    sessionTitle: sessionTitle,
                    correctCount: correctCount,
                    totalQuestions: questions.length,
                    streakDays: streakDays,
                    hikmetQuote: featuredQuote,
                    sourceRef: featuredSource,
                  );
                },
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 19,
                ),
                label: Text(
                  isTr
                      ? 'Hikmet Kartını Paylaş (Story / Kare)'
                      : 'Share Wisdom Card (Story / Square)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReturnToHub,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: colors.borderStroke),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isTr ? 'İrfan Meydanı\'na Dön' : 'Return to Wisdom Plaza',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionZikirPromptCard extends ConsumerStatefulWidget {
  final List<String> zikirKeys;

  const _SessionZikirPromptCard({required this.zikirKeys});

  @override
  ConsumerState<_SessionZikirPromptCard> createState() =>
      _SessionZikirPromptCardState();
}

class _SessionZikirPromptCardState
    extends ConsumerState<_SessionZikirPromptCard> {
  String? _selectedZikirKey;
  bool _isActivating = false;

  Future<void> _startSelectedZikir() async {
    final selected = _selectedZikirKey;
    if (selected == null || _isActivating) return;
    HapticService.selectionClick();
    setState(() => _isActivating = true);
    try {
      await ref
          .read(irfanQuizNotifierProvider.notifier)
          .activateLinkedZikir(selected);
      if (mounted) {
        context.go('/zikir');
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final selected = _selectedZikirKey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fingerprint_rounded,
                size: 19,
                color: colors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTr
                      ? 'Bu oturumdaki ilgili zikirlerden çekmek ister misiniz?'
                      : 'Would you like to practice a dhikr from this session?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isTr
                ? 'İstediğiniz zikri seçip hemen tesbihata başlayabilirsiniz:'
                : 'Select any related dhikr below to open the counter right away:',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.38,
              color: colors.secondaryTextAlt,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in widget.zikirKeys)
                _SelectableZikirChip(
                  label: key,
                  isSelected: selected == key,
                  onTap: () {
                    HapticService.selectionClick();
                    setState(() {
                      _selectedZikirKey = selected == key ? null : key;
                    });
                  },
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActivating ? null : _startSelectedZikir,
                icon: _isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                label: Text(
                  isTr
                      ? '📿 $selected Çekmeye Başla'
                      : '📿 Start Practicing $selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectableZikirChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableZikirChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.14)
                : colors.pageBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.accent : colors.borderStroke,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: colors.accent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? colors.accent : colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardSummaryChip extends StatelessWidget {
  final String emoji;
  final String label;

  const _RewardSummaryChip({
    required this.emoji,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
