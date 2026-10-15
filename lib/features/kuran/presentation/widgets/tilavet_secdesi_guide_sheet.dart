import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../data/tilavet_secdesi_data.dart';
import '../../providers/tilavet_secdesi_provider.dart';
import '../../providers/kuran_providers.dart';

class TilavetSecdesiGuideSheet extends ConsumerStatefulWidget {
  final TilavetSecdeItem? initialSecdeItem;
  final void Function(int page)? onNavigateToPage;

  const TilavetSecdesiGuideSheet({
    super.key,
    this.initialSecdeItem,
    this.onNavigateToPage,
  });

  static Future<void> show(
    BuildContext context, {
    TilavetSecdeItem? initialSecdeItem,
    void Function(int page)? onNavigateToPage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TilavetSecdesiGuideSheet(
        initialSecdeItem: initialSecdeItem,
        onNavigateToPage: onNavigateToPage,
      ),
    );
  }

  @override
  ConsumerState<TilavetSecdesiGuideSheet> createState() =>
      _TilavetSecdesiGuideSheetState();
}

class _TilavetSecdesiGuideSheetState
    extends ConsumerState<TilavetSecdesiGuideSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialSecdeItem != null) {
      // If opened for a specific secde item, default to first tab (how to do)
      _tabController.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debt = ref.watch(tilavetSecdesiDebtProvider);

    final sheetBg = isDark ? const Color(0xFF181B20) : const Color(0xFFF9FBF9);
    final cardBg = isDark ? const Color(0xFF22262E) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor =
        isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final goldAccent =
        isDark ? const Color(0xFFFFD56B) : const Color(0xFFB57D15);
    final emeraldGreen =
        isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: emeraldGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🕌', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tilâvet Secdesi Rehberi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        if (widget.initialSecdeItem != null)
                          Text(
                            '${widget.initialSecdeItem!.no}. Secde Âyeti: ${widget.initialSecdeItem!.sureName} ${widget.initialSecdeItem!.ayetId}',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: goldAccent,
                                fontWeight: FontWeight.w600),
                          )
                        else
                          Text(
                            'Hükmü, Yapılışı & 14 Secde Âyeti',
                            style: TextStyle(
                                fontSize: 12.5, color: secondaryTextColor),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Active Secde Verse Alert (If opened from a verse)
            if (widget.initialSecdeItem != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A332B)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: emeraldGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: emeraldGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Okuduğunuz sayfada (${widget.initialSecdeItem!.page}. Sayfa) tilâvet secdesi âyeti yer almaktadır.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? const Color(0xFFD6F5E3)
                                : const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF22262E)
                      : const Color(0xFFE7ECE8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: emeraldGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: secondaryTextColor,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Nasıl Yapılır?'),
                    Tab(text: 'Nedir & Hükmü?'),
                    Tab(text: '14 Secde Âyeti'),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHowToTab(isDark, cardBg, primaryTextColor,
                      secondaryTextColor, goldAccent, emeraldGreen),
                  _buildWhatIsTab(isDark, cardBg, primaryTextColor,
                      secondaryTextColor, goldAccent, emeraldGreen),
                  _buildVersesListTab(isDark, cardBg, primaryTextColor,
                      secondaryTextColor, goldAccent, emeraldGreen),
                ],
              ),
            ),

            // Interactive Bottom Bar (Debt Counter & Quick Action)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Debt Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: debt > 0
                          ? (isDark
                              ? const Color(0xFF382312)
                              : const Color(0xFFFFF3E0))
                          : (isDark
                              ? const Color(0xFF152A22)
                              : const Color(0xFFE8F5E9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            debt > 0 ? const Color(0xFFE65100) : emeraldGreen,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$debt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: debt > 0
                                ? const Color(0xFFFF9800)
                                : emeraldGreen,
                          ),
                        ),
                        Text(
                          'Secde Borcu',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Actions
                  Expanded(
                    child: Row(
                      children: [
                        // Decrement / Eda Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: emeraldGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded,
                                size: 18),
                            label: const Text(
                              'Secdeyi Eda Ettim (-1)',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              HapticService.targetReached();
                              ref
                                  .read(tilavetSecdesiDebtProvider.notifier)
                                  .decrementDebt(1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Text('✨ ',
                                          style: TextStyle(fontSize: 16)),
                                      Expanded(
                                        child: Text(
                                          'Tilâvet secdesi eda edildi olarak güncellendi. Allah kabul etsin.',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: emeraldGreen,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Increment / Borca Ekle Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          onPressed: () {
                            HapticService.selectionClick();
                            ref
                                .read(tilavetSecdesiDebtProvider.notifier)
                                .incrementDebt(1);
                          },
                          child: const Text(
                            '+1 Borç',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToTab(
    bool isDark,
    Color cardBg,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color goldAccent,
    Color emeraldGreen,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Highlight Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: emeraldGreen.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: emeraldGreen.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tilâvet secdesinde rükû ve selâm yoktur; doğrudan secdeye varılır ve bir kez secde yapılır.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFB5EAD7)
                        : const Color(0xFF0F5132),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Steps List
        ...TilavetSecdesiData.guideSteps.map((step) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emeraldGreen.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            step.icon,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${step.stepNumber}. Adım: ${step.title}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: secondaryTextColor,
                      height: 1.4,
                    ),
                  ),

                  // Arabic snippet if available
                  if (step.arabicText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF13161C)
                            : const Color(0xFFF1F5F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A313D)
                              : const Color(0xFFD6E2D9),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            QuranWordHighlighter.formatArabicTextForFont(
                              step.arabicText!,
                              ref.watch(arabicFontFamilyProvider),
                            ),
                            style: TextStyle(
                              fontFamily: ref.watch(arabicFontFamilyProvider),
                              fontSize: 22,
                              height: 1.5,
                              letterSpacing: -0.1,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                          if (step.transliteration != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              step.transliteration!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                color: goldAccent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWhatIsTab(
    bool isDark,
    Color cardBg,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color goldAccent,
    Color emeraldGreen,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Definition Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📖 ', style: TextStyle(fontSize: 20)),
                  Text(
                    'Tilâvet Secdesi Nedir?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tilâvet secdesi; Kur’ân-ı Kerîm’de secde emri veya secde edenlerden övgüyle bahsedilen 14 âyetten birinin okunması veya işitilmesi hâlinde yapılan secdedir.',
                style: TextStyle(
                    fontSize: 14, color: secondaryTextColor, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Fıkhı Hükmü Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚖️ ', style: TextStyle(fontSize: 20)),
                  Text(
                    'Fıkhî Hükmü',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                TilavetSecdesiData.fikhInfo,
                style: TextStyle(
                    fontSize: 13.5, color: secondaryTextColor, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Fazileti (Hadis) Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: goldAccent.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🌟 ', style: TextStyle(fontSize: 20)),
                  Text(
                    'Tilâvet Secdesinin Fazîleti',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: goldAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Resûlullâh (s.a.v.) şöyle buyurmuştur:\n\n'
                '«Âdemoğlu secde âyetini okuyup secde ettiği zaman şeytan ağlayarak uzaklaşır ve şöyle der: '
                '“Yazıklar olsun bana! Âdemoğluna secde etmesi emredildi, o secde etti ve cenneti kazandı. '
                'Bana da secde emredilmişti fakat ben isyan ettim ve ateşi hak ettim!”»',
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: primaryTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '(Müslim, Îmân 133)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: goldAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersesListTab(
    bool isDark,
    Color cardBg,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color goldAccent,
    Color emeraldGreen,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: TilavetSecdesiData.allSecdeVerses.length,
      itemBuilder: (context, index) {
        final item = TilavetSecdesiData.allSecdeVerses[index];
        final isSelected = widget.initialSecdeItem?.no == item.no;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? emeraldGreen.withValues(alpha: isDark ? 0.2 : 0.1)
                  : cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? emeraldGreen
                    : (isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: goldAccent.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Text(
                              '${item.no}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: goldAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${item.sureName} Sûresi, ${item.ayetId}. Âyet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onNavigateToPage?.call(item.page);
                      },
                      child: Text(
                        'Sayfa ${item.page} →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: emeraldGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  QuranWordHighlighter.formatArabicTextForFont(
                    item.arabicSnippet,
                    ref.watch(arabicFontFamilyProvider),
                  ),
                  style: TextStyle(
                    fontFamily: ref.watch(arabicFontFamilyProvider),
                    fontSize: 18,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 6),
                Text(
                  '“${item.mealSnippet}”',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
