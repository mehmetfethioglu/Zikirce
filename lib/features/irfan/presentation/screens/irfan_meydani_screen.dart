import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import '../../domain/irfan_models.dart';
import '../../providers/irfan_providers.dart';
import '../widgets/irfan_daily_hero_card.dart';
import '../widgets/irfan_seljuk_star_painter.dart';
import '../widgets/irfan_session_entry_sheet.dart';
import '../widgets/irfan_sm2_review_banner.dart';
import '../widgets/irfan_topic_map_grid.dart';

/// İrfan Meydanı Ana Ekranı: Akademi (Günün 5 Sorusu + SM-2 + Konu Haritası) & 32 Farz İlmihal.
class IrfanMeydaniScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  final int? initialFarzId;

  const IrfanMeydaniScreen({
    super.key,
    this.initialTab,
    this.initialFarzId,
  });

  @override
  ConsumerState<IrfanMeydaniScreen> createState() => _IrfanMeydaniScreenState();
}

class _IrfanMeydaniScreenState extends ConsumerState<IrfanMeydaniScreen> {
  late int _selectedTabIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = _resolveInitialTab(
      widget.initialTab,
      widget.initialFarzId,
    );
  }

  @override
  void didUpdateWidget(covariant IrfanMeydaniScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialFarzId != widget.initialFarzId) {
      setState(() {
        _selectedTabIndex = _resolveInitialTab(
          widget.initialTab,
          widget.initialFarzId,
        );
      });
    }
  }

  int _resolveInitialTab(String? tab, int? farzId) {
    if (tab == 'library' || farzId != null) {
      return 1;
    }
    return 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchDailyFive() async {
    final sessionId = ref.read(activeSessionProvider).id;
    final repo = ref.read(irfanRepositoryProvider);
    final isDailyCompleted =
        await repo.isDailyCompletedToday(sessionId: sessionId);
    if (!mounted) return;

    if (isDailyCompleted) {
      final isTr = context.l10n.isTurkish;
      final choice = await IrfanSessionEntrySheet.show(
        context,
        title: isTr ? 'Ekstra Günlük Halka' : 'Extra Daily Round',
        subtitle: isTr
            ? 'Bugünkü ücretsiz hak kullanıldı • Yeni 5 soru'
            : 'Free daily round completed • 5 fresh questions',
        diamondCost: IrfanEconomyConfig.extraDailyOrSm2DiamondCost,
      );
      if (choice == null || !mounted) return;
    }

    final started =
        await ref.read(irfanQuizNotifierProvider.notifier).startDailyFive();
    if (!mounted) return;
    if (!started) {
      _showInsufficientBalanceSnackBar();
      return;
    }
    context.push('/irfan/quiz');
  }

  Future<void> _launchSm2Review() async {
    final sessionId = ref.read(activeSessionProvider).id;
    final repo = ref.read(irfanRepositoryProvider);
    final freeUsedToday =
        await repo.isSm2FreeUsedToday(sessionId: sessionId);
    if (!mounted) return;

    if (freeUsedToday) {
      final isTr = context.l10n.isTurkish;
      final choice = await IrfanSessionEntrySheet.show(
        context,
        title: isTr ? 'Ekstra Hafıza Tekrarı' : 'Extra Memory Review',
        subtitle: isTr
            ? 'Bugünkü ücretsiz SM-2 tekrar hakkı kullanıldı'
            : 'Free daily SM-2 review used today',
        diamondCost: IrfanEconomyConfig.extraDailyOrSm2DiamondCost,
      );
      if (choice == null || !mounted) return;
    }

    final started =
        await ref.read(irfanQuizNotifierProvider.notifier).startSm2Review();
    if (!mounted) return;
    if (!started) {
      _showInsufficientBalanceSnackBar();
      return;
    }
    context.push('/irfan/quiz');
  }

  Future<void> _launchTopicTier(
    IrfanTopic topic,
    IrfanTier tier, {
    int? farzId,
  }) async {
    final isTr = context.l10n.isTurkish;
    final goldCost = IrfanEconomyConfig.goldEntryCostForTier(tier);
    final diamondCost = tier == IrfanTier.irfan
        ? IrfanEconomyConfig.irfanTierDiamondEntryCost
        : null;

    final choice = await IrfanSessionEntrySheet.show(
      context,
      title: topic.label(isTr),
      subtitle: farzId != null
          ? (isTr
              ? '${tier.label(isTr)} • Farz #$farzId Odaklı'
              : '${tier.label(isTr)} • Farz #$farzId Focus')
          : (isTr
              ? '${tier.label(isTr)} Kademesi İlim Halkası'
              : '${tier.label(isTr)} Tier Study Circle'),
      goldCost: goldCost,
      diamondCost: diamondCost,
    );
    if (choice == null || !mounted) return;

    final started =
        await ref.read(irfanQuizNotifierProvider.notifier).startTopicQuiz(
              topic,
              tier,
              farzId: farzId,
              useDiamonds: choice == IrfanEntryPaymentChoice.diamonds,
            );
    if (!mounted) return;
    if (!started) {
      _showInsufficientBalanceSnackBar();
      return;
    }
    context.push('/irfan/quiz');
  }

  Future<void> _launchFarzQuiz(int farzId) async {
    await _launchTopicTier(
      IrfanTopic.ilmihal32Farz,
      IrfanTier.baslangic,
      farzId: farzId,
    );
  }

  void _showInsufficientBalanceSnackBar() {
    HapticService.error();
    final isTr = context.l10n.isTurkish;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTr
              ? 'Bu oturum için yeterli Altın veya Elmas bakiyesi yok.'
              : 'Insufficient Gold or Diamond balance for this session.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedTabIndex == index) return;
    HapticService.selectionClick();
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
          children: [
            const _IrfanHeaderBar(),
            const SizedBox(height: 16),
            _IrfanSegmentedTabs(
              selectedIndex: _selectedTabIndex,
              onSelectTab: _selectTab,
            ),
            const SizedBox(height: 18),
            if (_selectedTabIndex == 0)
              _IrfanAcademySection(
                onStartDaily: _launchDailyFive,
                onStartSm2: _launchSm2Review,
                onSelectTopicTier: _launchTopicTier,
                onOpenLibraryTab: () => _selectTab(1),
              )
            else
              _IrfanLibrarySection(
                initialFarzId: widget.initialFarzId,
                onStartQuizForFarz: _launchFarzQuiz,
              ),
          ],
        ),
      ),
    );
  }
}

class _IrfanHeaderBar extends StatelessWidget {
  const _IrfanHeaderBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Row(
      children: [
        IrfanSeljukStarBadge(
          size: 34,
          color: colors.accent,
          accentColor: const Color(0xFFD4A574),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.irfanTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _IrfanCurrencySummaryBar(),
      ],
    );
  }
}

class _IrfanCurrencySummaryBar extends ConsumerWidget {
  const _IrfanCurrencySummaryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = ref.watch(goldCountProvider.select((v) => v.valueOrNull ?? 0));
    final diamonds =
        ref.watch(diamondCountProvider.select((v) => v.valueOrNull ?? 0));
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          GoldDiamondExchangeSheet.show(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                '$gold',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 1,
                height: 12,
                color: colors.borderStroke,
              ),
              const Text('💎', style: TextStyle(fontSize: 12.5)),
              const SizedBox(width: 4),
              Text(
                '$diamonds',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IrfanSegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  const _IrfanSegmentedTabs({
    required this.selectedIndex,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentPill(
              label: l10n.irfanAcademyTab,
              icon: Icons.auto_awesome_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onSelectTab(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentPill(
              label: l10n.irfanLibraryTab,
              icon: Icons.menu_book_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onSelectTab(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.icon,
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
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : colors.secondaryTextAlt,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : colors.secondaryTextAlt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IrfanAcademySection extends ConsumerWidget {
  final VoidCallback onStartDaily;
  final VoidCallback onStartSm2;
  final void Function(IrfanTopic topic, IrfanTier tier) onSelectTopicTier;
  final VoidCallback onOpenLibraryTab;

  const _IrfanAcademySection({
    required this.onStartDaily,
    required this.onStartSm2,
    required this.onSelectTopicTier,
    required this.onOpenLibraryTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(irfanDashboardProvider);
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    return summaryAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
      ),
      error: (_, __) => IrfanDailyHeroCard(
        isDailyCompleted: false,
        dailyCorrectCount: 0,
        activeThemeLabel: null,
        irfanStreakDays: 0,
        totalSolved: 0,
        onStartDaily: onStartDaily,
      ),
      data: (summary) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IrfanDailyHeroCard(
              isDailyCompleted: summary.isDailyCompleted,
              dailyCorrectCount: summary.dailyCorrectCount,
              activeThemeLabel: summary.activeThemeLabel(isTr),
              irfanStreakDays: summary.irfanStreakDays,
              totalSolved: summary.totalSolved,
              onStartDaily: onStartDaily,
            ),
            const SizedBox(height: 14),
            IrfanSm2ReviewBanner(
              dueSm2Count: summary.dueSm2Count,
              totalSm2PoolCount: summary.totalSm2PoolCount,
              isFreeUsedToday: summary.isSm2FreeUsedToday,
              onStartReview: onStartSm2,
            ),
            const SizedBox(height: 20),
            IrfanTopicMapGrid(
              masteryByNode: summary.masteryByNode,
              onSelectTopicTier: onSelectTopicTier,
              onOpenLibraryTab: onOpenLibraryTab,
            ),
          ],
        );
      },
    );
  }
}

class _IrfanLibrarySection extends StatelessWidget {
  final int? initialFarzId;
  final ValueChanged<int> onStartQuizForFarz;

  const _IrfanLibrarySection({
    required this.initialFarzId,
    required this.onStartQuizForFarz,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 19,
                color: colors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isTr
                      ? 'Önce Oku, Sonra Kendini Sına: Herhangi bir farz maddesini okuyup anında ilgili sorularla pekiştirebilirsiniz.'
                      : 'Read First, Then Test Yourself: Study any of the 32 Farz entries and launch a targeted quiz right away.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.38,
                    fontWeight: FontWeight.w500,
                    color: colors.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FiqhLibraryView(
          isEmbedded: true,
          initialFarzId: initialFarzId,
          onStartQuizForFarz: onStartQuizForFarz,
        ),
      ],
    );
  }
}
