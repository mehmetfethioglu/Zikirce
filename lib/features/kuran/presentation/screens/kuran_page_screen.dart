import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../hatim/presentation/screens/mukabele_hatim_screen.dart';
import '../../../hatim/presentation/widgets/hatim_sync_gate.dart';
import '../../../hatim/providers/hatim_providers.dart';
import '../../../ezber/providers/ezber_providers.dart';
import '../widgets/quick_surah_bottom_sheet.dart';
import '../widgets/talim_page_selection_bottom_sheet.dart';
import '../widgets/talim_selection_bottom_sheet.dart';
import '../widgets/quran_quick_access_bottom_sheets.dart';
import '../widgets/quran_talim_detail_bottom_sheet.dart';
import '../widgets/quran_top_icon_ribbon.dart';
import '../widgets/quick_access_card_wrapper.dart';
import '../widgets/quick_access_management_sheet.dart';
import '../../providers/quick_access_cards_provider.dart';
import 'mushaf_screen.dart';
import '../../../ezber/presentation/screens/memorization_screen.dart';
import '../../../ezber/presentation/screens/interactive_talim_screen.dart';
import '../../../ezber/presentation/screens/kelime_takipli_dinleme_screen.dart';

class KuranPageScreen extends ConsumerStatefulWidget {
  const KuranPageScreen({super.key});

  @override
  ConsumerState<KuranPageScreen> createState() => _KuranPageScreenState();
}

class _KuranPageScreenState extends ConsumerState<KuranPageScreen> {
  late DynamicSurahInfo _dynamicSurah;

  @override
  void initState() {
    super.initState();
    _dynamicSurah = SurahDataProvider.getDynamicSurah();
  }

  void _openMushafPage(
    int page, {
    Hatim? activeHatim,
    SureItem? targetSurah,
    String? streakKey,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => MushafScreen(
          initialPage: page.clamp(1, 604),
          activeHatim: activeHatim,
          targetSurah: targetSurah,
          streakKey: streakKey,
        ),
      ),
    );
  }

  void _openMukabeleScreen({
    Hatim? activeHatim,
    int initialPage = 1,
    int? initialJuz,
  }) {
    HatimSyncGate.checkAndProceed(
      context: context,
      ref: ref,
      onProceed: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => MukabeleHatimScreen(
              activeHatim: activeHatim,
              initialPage: initialPage.clamp(1, 604),
              initialJuz: initialJuz,
            ),
          ),
        );
      },
    );
  }

  void _showQuickSurahSheet() async {
    final selectedSurah = await showModalBottomSheet<SureItem>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickSurahBottomSheet(),
    );

    if (selectedSurah != null) {
      _openMushafPage(selectedSurah.startPage, targetSurah: selectedSurah);
    }
  }

  void _showTalimSelection(
    String modeKey,
    String modeTitle,
    String modeIcon,
    Color modeColor,
  ) async {
    final selectedPage = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TalimPageSelectionBottomSheet(
        modeKey: modeKey,
        modeTitle: modeTitle,
        modeIcon: modeIcon,
        modeColor: modeColor,
        initialPage: 1,
      ),
    );

    if (selectedPage != null && selectedPage >= 1 && selectedPage <= 604) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => InteractiveTalimScreen(
              modeKey: modeKey,
              pageNumber: selectedPage,
            ),
          ),
        );
      }
    }
  }

  void _showKelimeTakipliSelection() async {
    final result = await TalimSelectionBottomSheet.show(
      context,
      modeKey: 'KelimeTakip',
      modeTitle: 'Kelime Takipli Dinleme',
      modeIcon: '🎧',
      modeColor: const Color(0xFF0D9488),
      initialPage: 1,
      isAudioSyncListening: true,
    );

    if (result != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => KelimeTakipliDinlemeScreen(
            targetType: result.type,
            targetId: result.id,
            startAyah: result.startAyah,
            endAyah: result.endAyah,
            customTitle: result.customTitle,
          ),
        ),
      );
    }
  }

  void _showCreateHatimDialog() {
    final l10n = context.l10n;
    final titleController = TextEditingController(
        text: l10n.isTurkish ? 'Şahsi Hatim' : 'Personal Hatim');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Text('🕌 ', style: TextStyle(fontSize: 22)),
            Text(l10n.translate('Quran_NewHatimDialogTitle'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: l10n.translate('Quran_HatimTitleLabel'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7D76),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ref.read(hatimNotifierProvider).createHatim(
                      title: title,
                      isGroup: false,
                    );
                Navigator.of(ctx).pop();
                _openMushafPage(1);
              }
            },
            child: Text(l10n.quranPageStart),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pageBg = isDark ? const Color(0xFF141416) : const Color(0xFFECF3F0);
    final primaryTextColor =
        isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor =
        isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final accentGreen =
        isDark ? const Color(0xFF3EA388) : const Color(0xFF2D7D76);
    final cardBg = isDark ? const Color(0xFF23262F) : const Color(0xFFFFFFFF);
    final borderStroke =
        isDark ? const Color(0xFF33343A) : const Color(0xFFD8E5E1);

    final hatimsAsync = ref.watch(hatimListStreamProvider);
    final activeMukabeleAsync = ref.watch(activeMukabeleHatimProvider);
    final hatimStatsAsync = ref.watch(hatimStatsProvider);
    final hatimStats = hatimStatsAsync.valueOrNull;
    final plansAsync = ref.watch(memorizationPlansStreamProvider);
    final streaksAsync = ref.watch(surahStreaksProvider);
    final streaks = streaksAsync.valueOrNull ?? const SurahStreaksData();
    final todayHafizLog = ref.watch(todayHafizlikLogProvider).valueOrNull;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ==========================================
                  // 0. EN ÜST İKON ROZETLERİ & TİLÂVET SECDESİ ŞERİDİ
                  // ==========================================
                  QuranTopIconRibbon(
                    onNavigateToPage: (page) => _openMushafPage(page),
                    onOpenCompletedHatim: (h) => _showCompletedHatimModal(h),
                    onOpenBadgeDetail: ({
                      required title,
                      required icon,
                      required description,
                      required category,
                    }) =>
                        _showBadgeDetailModal(
                      title: title,
                      icon: icon,
                      description: description,
                      category: category,
                    ),
                    onOpenStreakDetail: (title, curr, target, blessing) =>
                        _showStreakDetailModal(title, curr, target, blessing),
                    onOpenMukabeleScreen: () => _openMukabeleScreen(),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 1. HIZLI ERİŞİM & HATİMLER YATAY KARTLARI
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.quranPageQuickAccessAndHatims,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => QuickAccessManagementSheet.show(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Yönet',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: accentGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.tune_rounded, size: 14, color: accentGreen),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _buildQuickAccessCardsRow(
                    context: context,
                    activeMukabeleAsync: activeMukabeleAsync,
                    hatimsAsync: hatimsAsync,
                    hatimStats: hatimStats,
                    streaks: streaks,
                    accentGreen: accentGreen,
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 2. CÜZLER BÖLÜMÜ
                  // ==========================================
                  Text(
                    context.l10n.quranPageJuzs,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 30,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final juzNo = index + 1;
                        final startPage =
                            SurahDataProvider.getJuzStartPage(juzNo);
                        return _buildJuzCard(
                          juzNo: juzNo,
                          startPage: startPage,
                          cardBg: cardBg,
                          borderStroke: borderStroke,
                          accentColor: accentGreen,
                          secondaryTextColor: secondaryTextColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. SURELER BÖLÜMÜ (Sure Ara Sağda)
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.quranPageSurahs,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      InkWell(
                        onTap: _showQuickSurahSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                context.l10n.quranPageSearchSurah,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: accentGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('🔍', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: SurahDataProvider.surahs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final surah = SurahDataProvider.surahs[index];
                        return _buildSurahCard(
                          surah: surah,
                          cardBg: cardBg,
                          borderStroke: borderStroke,
                          accentColor: accentGreen,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ==========================================
                  // 4. HAFIZLIK TALİM MODLARI (Kaydırın Sağda)
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.translate('Quran_MemorizationDrills'),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            context.l10n.translate('Quran_ScrollHint'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentGreen,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded,
                              size: 13, color: accentGreen),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 165,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Card 1: Hafızlık Takibi
                        _buildTalimCard(
                          iconEmoji: '📜',
                          tag: 'Hafızlık',
                          title: 'Hafızlık Takibi',
                          subtitle: plansAsync.when(
                            data: (plans) => '${plans.length} Sayfa Ezberlenen',
                            loading: () => '0 Sayfa Ezberlenen',
                            error: (_, __) => '0 Sayfa Ezberlenen',
                          ),
                          buttonText: 'Detay ➔',
                          cardBg: isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEEF2FF),
                          borderColor: isDark
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF6366F1),
                          accentColor: isDark
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF4F46E5),
                          buttonColor: const Color(0xFF6366F1),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.hafizlikTakip,
                            plansCount: plansAsync.valueOrNull?.length ?? 0,
                            todayLog: todayHafizLog,
                            onStart: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const MemorizationScreen()),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const MemorizationScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 14),

                        // Card: Kelime Takipli Dinleme
                        _buildTalimCard(
                          iconEmoji: '🎧',
                          tag: 'Kelime Takip',
                          title: 'Kelime Takipli Dinleme',
                          subtitle: 'Sayfa, sûre, cüz veya aşr dinle',
                          buttonText: 'Başla ➔',
                          cardBg: isDark
                              ? const Color(0xFF0F3E3A)
                              : const Color(0xFFE6F4F1),
                          borderColor: isDark
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF14B8A6),
                          accentColor: isDark
                              ? const Color(0xFF2DD4BF)
                              : const Color(0xFF0F766E),
                          buttonColor: const Color(0xFF0D9488),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.kelimeTakip,
                            onStart: () => _showKelimeTakipliSelection(),
                          ),
                          onTap: () => _showKelimeTakipliSelection(),
                        ),
                        const SizedBox(width: 14),

                        // Card 2: Kelime Bulmaca
                        _buildTalimCard(
                          iconEmoji: '⊞',
                          tag: 'Bulmaca',
                          title: 'Kelime Bulmaca',
                          subtitle: 'Kelimeleri sırasıyla dizin',
                          buttonText: 'Başla ➔',
                          cardBg: isDark
                              ? const Color(0xFF064E3B)
                              : const Color(0xFFE6F4EA),
                          borderColor: isDark
                              ? const Color(0xFF059669)
                              : const Color(0xFF10B981),
                          accentColor: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF065F46),
                          buttonColor: const Color(0xFF10B981),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.bulmaca,
                            onStart: () => _showTalimSelection(
                              'Bulmaca',
                              'Kelime Bulmaca',
                              '🧩',
                              const Color(0xFF10B981),
                            ),
                          ),
                          onTap: () => _showTalimSelection(
                            'Bulmaca',
                            'Kelime Bulmaca',
                            '🧩',
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Card 3: Boşluk Doldurma
                        _buildTalimCard(
                          iconEmoji: '✍️',
                          tag: 'Boşluk',
                          title: 'Boşluk Doldurma',
                          subtitle: 'Eksik kelimeleri bulun',
                          buttonText: 'Başla ➔',
                          cardBg: isDark
                              ? const Color(0xFF78350F)
                              : const Color(0xFFFEF3C7),
                          borderColor: isDark
                              ? const Color(0xFFD97706)
                              : const Color(0xFFF59E0B),
                          accentColor: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF92400E),
                          buttonColor: const Color(0xFFF59E0B),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.bosluk,
                            onStart: () => _showTalimSelection(
                              'Bosluk',
                              'Boşluk Doldurma',
                              '✍️',
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          onTap: () => _showTalimSelection(
                            'Bosluk',
                            'Boşluk Doldurma',
                            '✍️',
                            const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Card 4: Ayet Bağlama
                        _buildTalimCard(
                          iconEmoji: '🔗',
                          tag: 'Sonraki Ayet',
                          title: 'Ayet Bağlama',
                          subtitle: 'Ayet bağlama pratiği',
                          buttonText: 'Başla ➔',
                          cardBg: isDark
                              ? const Color(0xFF075985)
                              : const Color(0xFFE0F2FE),
                          borderColor: isDark
                              ? const Color(0xFF0369A1)
                              : const Color(0xFF0284C7),
                          accentColor: isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0369A1),
                          buttonColor: const Color(0xFF0284C7),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.baglama,
                            onStart: () => _showTalimSelection(
                              'Baglama',
                              'Ayet Bağlama',
                              '🔗',
                              const Color(0xFF0284C7),
                            ),
                          ),
                          onTap: () => _showTalimSelection(
                            'Baglama',
                            'Ayet Bağlama',
                            '🔗',
                            const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Card 5: Sesli Tilavet / Ses Tanıma
                        _buildTalimCard(
                          iconEmoji: '🎙️',
                          tag: 'Sesli Talim',
                          title: 'Ses Tanıma',
                          subtitle: 'Mikrofonla tilavet oku',
                          buttonText: 'Başla ➔',
                          cardBg: isDark
                              ? const Color(0xFF581C87)
                              : const Color(0xFFF3E8FF),
                          borderColor: isDark
                              ? const Color(0xFF7E22CE)
                              : const Color(0xFFA855F7),
                          accentColor: isDark
                              ? const Color(0xFFC084FC)
                              : const Color(0xFF6B21A8),
                          buttonColor: const Color(0xFFA855F7),
                          onCardTap: () => TalimModeDetailBottomSheet.show(
                            context: context,
                            modeType: TalimModeType.sesli,
                            onStart: () => _showTalimSelection(
                              'Talim',
                              'Ses Tanıma',
                              '🎙️',
                              const Color(0xFFA855F7),
                            ),
                          ),
                          onTap: () => _showTalimSelection(
                            'Talim',
                            'Ses Tanıma',
                            '🎙️',
                            const Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HIZLI ERİŞİM & HATİMLER YATAY KART ŞERİDİ
  // ==========================================

  Widget _buildQuickAccessCardsRow({
    required BuildContext context,
    required AsyncValue<Hatim?> activeMukabeleAsync,
    required AsyncValue<List<Hatim>> hatimsAsync,
    required HatimStats? hatimStats,
    required SurahStreaksData streaks,
    required Color accentGreen,
  }) {
    final cardState = ref.watch(quickAccessCardsProvider);

    // List of card entries: (id, title, icon, isHatim, hatimId, widget)
    final List<({String id, String title, String icon, bool isHatim, String? hatimId, Widget widget})> allEntries = [];

    // 1. Mukabele Card
    final mukabele = activeMukabeleAsync.valueOrNull;
    if (mukabele != null && !mukabele.isCompleted) {
      final currentPage = mukabele.completedPages < 604 ? mukabele.completedPages + 1 : 604;
      final progressPercent = ((mukabele.completedPages / 604.0) * 100).clamp(0, 100).toInt();
      final todayPages = hatimStats?.todayPagesByHatim[mukabele.id] ?? 0;
      final lastRead = hatimStats?.lastReadByHatim[mukabele.id];

      allEntries.add((
        id: 'mukabele_hatim',
        title: 'Mukabele: ${mukabele.title}',
        icon: '🕌',
        isHatim: true,
        hatimId: mukabele.id,
        widget: _buildActiveMukabeleCard(
          hatim: mukabele,
          title: mukabele.title,
          currentPage: currentPage,
          progressPercent: progressPercent,
          todayPages: todayPages,
          lastReadDate: lastRead,
        ),
      ));
    } else {
      allEntries.add((
        id: 'mukabele_hatim',
        title: 'Mukabele Başlat',
        icon: '🕌',
        isHatim: false,
        hatimId: null,
        widget: _buildEmptyMukabeleCard(),
      ));
    }

    // 2. Active Personal Hatims
    final hatims = hatimsAsync.valueOrNull ?? [];
    final activeHatims = hatims.where((h) => !h.isCompleted && h.completedPages < 604).toList();

    if (activeHatims.isNotEmpty) {
      for (final h in activeHatims) {
        final currentPage = h.completedPages < 604 ? h.completedPages + 1 : 604;
        final progressPercent = ((h.completedPages / 604.0) * 100).clamp(0, 100).toInt();
        final todayPages = hatimStats?.todayPagesByHatim[h.id] ?? 0;
        final lastRead = hatimStats?.lastReadByHatim[h.id];

        allEntries.add((
          id: 'hatim_${h.id}',
          title: h.title,
          icon: '👤',
          isHatim: true,
          hatimId: h.id,
          widget: _buildActiveHatimCard(
            hatim: h,
            title: h.title,
            currentPage: currentPage,
            progressPercent: progressPercent,
            todayPages: todayPages,
            lastReadDate: lastRead,
            accentColor: accentGreen,
          ),
        ));
      }
    } else {
      allEntries.add((
        id: 'hatim_empty',
        title: 'Yeni Hatim Başlat',
        icon: '👤',
        isHatim: false,
        hatimId: null,
        widget: _buildEmptyHatimCard(accentGreen),
      ));
    }

    // 3. Dynamic Surah Card
    allEntries.add((
      id: 'card_dynamic_surah',
      title: _dynamicSurah.title,
      icon: _dynamicSurah.icon,
      isHatim: false,
      hatimId: null,
      widget: _buildDynamicSurahCard(_dynamicSurah),
    ));

    // 4. Shortcut Card (Yeni Hatim / Kısayol)
    allEntries.add((
      id: 'card_shortcut',
      title: 'Hızlı Kısayol Kartı',
      icon: '✨',
      isHatim: false,
      hatimId: null,
      widget: _buildShortcutCard(),
    ));

    // 5. Streak Cards
    allEntries.add((
      id: 'card_streak_waqiah',
      title: 'Vâkıa 40 Okuma',
      icon: '🌿',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Vâkıa',
        subtitle: streaks.waqiahStreak > 1 ? '🔥 ${streaks.waqiahStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '🌿',
        badgeText: 'Rızık ve Bereket',
        bgGradient: const [Color(0xFF0F766E), Color(0xFF064E3B)],
        readCount: streaks.waqiahReadCount,
        streakDays: streaks.waqiahStreak,
        startPage: 534,
        surahId: 56,
        streakKey: 'waqiah',
      ),
    ));

    allEntries.add((
      id: 'card_streak_mulk',
      title: 'Mülk 40 Okuma',
      icon: '🌌',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Mülk',
        subtitle: streaks.mulkStreak > 1 ? '🔥 ${streaks.mulkStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '🌌',
        badgeText: 'Kabir Aydınlığı',
        bgGradient: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
        readCount: streaks.mulkReadCount,
        streakDays: streaks.mulkStreak,
        startPage: 562,
        surahId: 67,
        streakKey: 'mulk',
      ),
    ));

    allEntries.add((
      id: 'card_streak_naba',
      title: 'Nebe 40 Okuma',
      icon: '🌅',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Nebe',
        subtitle: streaks.nabaStreak > 1 ? '🔥 ${streaks.nabaStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '🌅',
        badgeText: 'Kıyamet Haberi',
        bgGradient: const [Color(0xFF7C2D12), Color(0xFF451A03)],
        readCount: streaks.nabaReadCount,
        streakDays: streaks.nabaStreak,
        startPage: 582,
        surahId: 78,
        streakKey: 'naba',
      ),
    ));

    allEntries.add((
      id: 'card_streak_yasin',
      title: 'Yâsîn 40 Okuma',
      icon: '💚',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Yâsîn',
        subtitle: streaks.yasinStreak > 1 ? '🔥 ${streaks.yasinStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '💚',
        badgeText: 'Kalbin Nuru',
        bgGradient: const [Color(0xFF047857), Color(0xFF064E3B)],
        readCount: streaks.yasinReadCount,
        streakDays: streaks.yasinStreak,
        startPage: 440,
        surahId: 36,
        streakKey: 'yasin',
      ),
    ));

    allEntries.add((
      id: 'card_streak_fetih',
      title: 'Fetih 40 Okuma',
      icon: '🗡️',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Fetih',
        subtitle: streaks.fetihStreak > 1 ? '🔥 ${streaks.fetihStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '🗡️',
        badgeText: 'Manevi Zafer',
        bgGradient: const [Color(0xFFBE185D), Color(0xFF831843)],
        readCount: streaks.fetihReadCount,
        streakDays: streaks.fetihStreak,
        startPage: 511,
        surahId: 48,
        streakKey: 'fetih',
      ),
    ));

    allEntries.add((
      id: 'card_streak_rahman',
      title: 'Rahmân 40 Okuma',
      icon: '🌸',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Rahmân',
        subtitle: streaks.rahmanStreak > 1 ? '🔥 ${streaks.rahmanStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '🌸',
        badgeText: 'Nimet Şükrü',
        bgGradient: const [Color(0xFF7E22CE), Color(0xFF581C87)],
        readCount: streaks.rahmanReadCount,
        streakDays: streaks.rahmanStreak,
        startPage: 531,
        surahId: 55,
        streakKey: 'rahman',
      ),
    ));

    allEntries.add((
      id: 'card_streak_kehf',
      title: 'Kehf 40 Okuma',
      icon: '⛰️',
      isHatim: false,
      hatimId: null,
      widget: _buildStreakCard(
        title: 'Kehf',
        subtitle: streaks.kehfStreak > 1 ? '🔥 ${streaks.kehfStreak} Günlük Seri' : '40 Okuma Hedefi',
        icon: '⛰️',
        badgeText: 'Cuma Nuru',
        bgGradient: const [Color(0xFF78350F), Color(0xFF451A03)],
        readCount: streaks.kehfReadCount,
        streakDays: streaks.kehfStreak,
        startPage: 293,
        surahId: 18,
        streakKey: 'kehf',
      ),
    ));

    // Filter out hidden cards
    final visibleEntries = allEntries.where((e) => !cardState.isHidden(e.id)).toList();

    // Sort: Pinned first (preserving relative order), then unpinned
    final pinnedEntries = visibleEntries.where((e) => cardState.isPinned(e.id)).toList();
    final unpinnedEntries = visibleEntries.where((e) => !cardState.isPinned(e.id)).toList();
    final sortedEntries = [...pinnedEntries, ...unpinnedEntries];

    return SizedBox(
      height: 165,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedEntries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == sortedEntries.length) {
            return QuickAccessCardWrapper.buildEndManageTile(context);
          }
          final entry = sortedEntries[index];
          return QuickAccessCardWrapper(
            cardId: entry.id,
            cardTitle: entry.title,
            cardIcon: entry.icon,
            isHatim: entry.isHatim,
            hatimId: entry.hatimId,
            child: entry.widget,
          );
        },
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS (MATCHING EXACT MAUI UI)
  // ==========================================

  Widget _buildActiveHatimCard({
    required Hatim hatim,
    required String title,
    required int currentPage,
    required int progressPercent,
    required int todayPages,
    required DateTime? lastReadDate,
    required Color accentColor,
  }) {
    final l10n = context.l10n;
    final now = DateTime.now();
    String lastReadText;
    if (lastReadDate == null) {
      lastReadText = l10n.isTurkish ? 'Son okuma: Bugün' : 'Last read: Today';
    } else {
      final isToday = lastReadDate.year == now.year &&
          lastReadDate.month == now.month &&
          lastReadDate.day == now.day;
      final yesterday = now.subtract(const Duration(days: 1));
      final isYesterday = lastReadDate.year == yesterday.year &&
          lastReadDate.month == yesterday.month &&
          lastReadDate.day == yesterday.day;

      if (isToday) {
        lastReadText = l10n.isTurkish ? 'Son okuma: Bugün' : 'Last read: Today';
      } else if (isYesterday) {
        lastReadText =
            l10n.isTurkish ? 'Son okuma: Dün' : 'Last read: Yesterday';
      } else {
        lastReadText = l10n.isTurkish
            ? 'Son okuma: ${lastReadDate.day}.${lastReadDate.month.toString().padLeft(2, '0')}'
            : 'Last read: ${lastReadDate.month}/${lastReadDate.day}';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => HatimDetailBottomSheet.show(
          context: context,
          hatim: hatim,
          currentPage: currentPage,
          progressPercent: progressPercent,
          todayPages: todayPages,
          lastReadDate: lastReadDate,
          isMukabele: false,
          accentColor: accentColor,
          onContinue: () => _openMushafPage(currentPage, activeHatim: hatim),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon + Hatim Takip
              Row(
                children: [
                  const Text('👤', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    context.l10n.quranPageHatimTracking,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE0EBE7),
                    ),
                  ),
                ],
              ),

              // Center: Title, Page, Today, Last Read
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.isTurkish
                        ? '$currentPage. Sayfa'
                        : 'Page $currentPage',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFFE0EBE7)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.l10n.isTurkish
                        ? 'Bugün: $todayPages sayfa'
                        : 'Today: $todayPages pages',
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    lastReadText,
                    style: const TextStyle(
                        fontSize: 8.5, color: Color(0xFFE0EBE7)),
                  ),
                ],
              ),

              // Mini Progress Bar with %
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (progressPercent / 100.0).clamp(0.01, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '%$progressPercent',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // Bottom CTA Button
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _openMushafPage(currentPage, activeHatim: hatim),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.quranPageContinue,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: accentColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHatimCard(Color accentColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCreateHatimDialog,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D7D76),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D7D76).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🕌', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.quranPageHatimTracking,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0EBE7)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.quranPageNoActiveHatim,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.quranPageStartNew,
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFFE0EBE7)),
                  ),
                ],
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showCreateHatimDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.quranPageStart,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D7D76)),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 11, color: Color(0xFF2D7D76)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MUKABELE HATİM KARTLARI & DİYALOGLARI
  // ==========================================

  Widget _buildActiveMukabeleCard({
    required Hatim hatim,
    required String title,
    required int currentPage,
    required int progressPercent,
    required int todayPages,
    required DateTime? lastReadDate,
  }) {
    final now = DateTime.now();
    String lastReadText;
    if (lastReadDate == null) {
      lastReadText = 'Son dinleme: Bugün';
    } else {
      final isToday = lastReadDate.year == now.year &&
          lastReadDate.month == now.month &&
          lastReadDate.day == now.day;
      if (isToday) {
        lastReadText = 'Son dinleme: Bugün';
      } else {
        lastReadText =
            'Son: ${lastReadDate.day}.${lastReadDate.month.toString().padLeft(2, '0')}';
      }
    }

    final juzNo = (currentPage / 20).ceil().clamp(1, 30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => HatimDetailBottomSheet.show(
          context: context,
          hatim: hatim,
          currentPage: currentPage,
          progressPercent: progressPercent,
          todayPages: todayPages,
          lastReadDate: lastReadDate,
          isMukabele: true,
          accentColor: const Color(0xFFD4AF37),
          onContinue: () =>
              _openMukabeleScreen(activeHatim: hatim, initialPage: currentPage),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 165,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E4334), Color(0xFF082B21)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E4334).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Mosque Icon + Mukabele
              Row(
                children: const [
                  Text('🕌', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 5),
                  Text(
                    'Mukabele',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD54F),
                    ),
                  ),
                ],
              ),

              // Center: Title, Juz & Page Info, Today
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$juzNo. Cüz • $currentPage. Sayfa',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE0EBE7)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Bugün: $todayPages sayfa',
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD54F)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    lastReadText,
                    style: const TextStyle(
                        fontSize: 8.5, color: Color(0xFFB2DFDB)),
                  ),
                ],
              ),

              // Mini Progress Bar with %
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (progressPercent / 100.0).clamp(0.01, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '%$progressPercent',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFE082),
                    ),
                  ),
                ],
              ),

              // Bottom CTA Button: Mukabeleye Devam Et
              Material(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _openMukabeleScreen(
                      activeHatim: hatim, initialPage: currentPage),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Mukabeleye Devam',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14241E),
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.play_arrow_rounded,
                            size: 13, color: Color(0xFF14241E)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMukabeleCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showStartMukabeleDialog,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 165,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E4334), Color(0xFF082B21)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E4334).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('🕌', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 6),
                  Text(
                    'Mukabele Hatmi',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD54F)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Mukabele Başlat',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kelime takipli dinleme',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFFE0EBE7)),
                  ),
                ],
              ),
              Material(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showStartMukabeleDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Mukabele Başlat',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14241E)),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: Color(0xFF14241E)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartMukabeleDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1C2026) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF1E2B27);
        final subColor =
            isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
        final gold = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('🕌 ', style: TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      context.l10n.mukabeleStartNewPrompt,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kelime kelime senkron takip ve kesintisiz tilavet ile hatim yapın.',
                style: TextStyle(fontSize: 13, color: subColor),
              ),
              const SizedBox(height: 20),

              // Option 1: 30-Day Ramadan Mukabele
              _buildMukabeleOptionTile(
                iconEmoji: '🌙',
                title: context.l10n.mukabeleTypeRamadan30Days,
                subtitle: context.l10n.mukabeleDescRamadan,
                badge: '30 Gün',
                accentColor: const Color(0xFF10B981),
                isDark: isDark,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final hatimId =
                      await ref.read(hatimNotifierProvider).createMukabeleHatim(
                            title: '30 Günlük Ramazan Mukabelesi',
                            startPage: 1,
                            targetDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                  final db = ref.read(databaseProvider);
                  final hatim = await (db.select(db.hatims)
                        ..where((t) => t.id.equals(hatimId)))
                      .getSingleOrNull();
                  _openMukabeleScreen(activeHatim: hatim, initialPage: 1);
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Personal Full Mukabele (1-604)
              _buildMukabeleOptionTile(
                iconEmoji: '📖',
                title: context.l10n.mukabeleTypePersonalFull,
                subtitle: context.l10n.mukabeleDescPersonal,
                badge: '1-604 Sayfa',
                accentColor: gold,
                isDark: isDark,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final hatimId =
                      await ref.read(hatimNotifierProvider).createMukabeleHatim(
                            title: 'Bireysel Mukabele Hatmi',
                            startPage: 1,
                          );
                  final db = ref.read(databaseProvider);
                  final hatim = await (db.select(db.hatims)
                        ..where((t) => t.id.equals(hatimId)))
                      .getSingleOrNull();
                  _openMukabeleScreen(activeHatim: hatim, initialPage: 1);
                },
              ),
              const SizedBox(height: 12),

              // Option 3: Start from a specific Juz
              _buildMukabeleOptionTile(
                iconEmoji: '🎯',
                title: context.l10n.mukabeleTypeCustomJuz,
                subtitle: context.l10n.mukabeleDescCustom,
                badge: 'Cüz Seç',
                accentColor: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final selectedJuz = await _pickJuzNumberDialog();
                  if (selectedJuz != null) {
                    final startPage =
                        SurahDataProvider.getJuzStartPage(selectedJuz);
                    final hatimId = await ref
                        .read(hatimNotifierProvider)
                        .createMukabeleHatim(
                          title: '$selectedJuz. Cüz Mukabelesi',
                          startPage: startPage,
                        );
                    final db = ref.read(databaseProvider);
                    final hatim = await (db.select(db.hatims)
                          ..where((t) => t.id.equals(hatimId)))
                        .getSingleOrNull();
                    _openMukabeleScreen(
                        activeHatim: hatim,
                        initialPage: startPage,
                        initialJuz: selectedJuz);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMukabeleOptionTile({
    required String iconEmoji,
    required String title,
    required String subtitle,
    required String badge,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242932) : const Color(0xFFF6F8F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF353C48) : const Color(0xFFE2DDD2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E2B27),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF8A9BAE)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accentColor),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickJuzNumberDialog() async {
    return showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1E24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Text(
                'Başlamak İstediğiniz Cüzü Seçin',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: 30,
                  itemBuilder: (context, idx) {
                    final juz = idx + 1;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(juz),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF23262F)
                              : const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFD4AF37).withOpacity(0.5)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$juz. Cüz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E2B27),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicSurahCard(DynamicSurahInfo info) {
    const coralBg = Color(0xFFEF7C65);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => DynamicSurahDetailBottomSheet.show(
          context: context,
          info: info,
          onRead: () => _openMushafPage(
            info.startPage,
            targetSurah: SurahDataProvider.getSurahById(info.surahId),
          ),
          onListen: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => KelimeTakipliDinlemeScreen(
                  targetType: TalimTargetType.surah,
                  targetId: info.surahId,
                  customTitle: info.title,
                ),
              ),
            );
          },
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: coralBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: coralBg.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon + Subtitle
              Row(
                children: [
                  Text(info.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      info.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDE1DB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),

              // Center: Title, SizeInfo, Virtue
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    info.sizeInfo,
                    style: const TextStyle(
                        fontSize: 9.5, color: Color(0xFFFAD0C6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.virtue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFFFE3DC),
                      height: 1.15,
                    ),
                  ),
                ],
              ),

              // Bottom: "Oku ↗" button + "Tümü ➔" link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _openMushafPage(
                        info.startPage,
                        targetSurah:
                            SurahDataProvider.getSurahById(info.surahId),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Oku ↗',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: coralBg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _showQuickSurahSheet,
                    child: const Text(
                      'Tümü ➔',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDE1DB),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutCard() {
    const goldBg = Color(0xFFF5B853);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCreateHatimDialog,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: goldBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: goldBg.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('✨', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 5),
                  Text(
                    'Kısayollar',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFEF1DC)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Yeni Hatim',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Yeni Hedef Oluştur',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFDE1BF)),
                  ),
                ],
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showCreateHatimDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Başla',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: goldBg),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: goldBg),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard({
    required String title,
    required String subtitle,
    required String icon,
    required String badgeText,
    required List<Color> bgGradient,
    int readCount = 0,
    required int streakDays,
    required int startPage,
    int? surahId,
    String? streakKey,
  }) {
    final displayCount = readCount > 0 ? readCount : streakDays;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => SurahStreakDetailBottomSheet.show(
          context: context,
          title: title,
          subtitle: subtitle,
          icon: icon,
          badgeText: badgeText,
          bgGradient: bgGradient,
          readCount: displayCount,
          streakDays: streakDays,
          onStartReading: () => _openMushafPage(
            startPage,
            targetSurah: surahId != null
                ? SurahDataProvider.getSurahById(surahId)
                : null,
            streakKey: streakKey,
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: bgGradient.first.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title • $displayCount/40 Okuma',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
              Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _openMushafPage(
                        startPage,
                        targetSurah: surahId != null
                            ? SurahDataProvider.getSurahById(surahId)
                            : null,
                        streakKey: streakKey,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          'Oku ↗',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: bgGradient.first,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (displayCount / 40.0).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJuzCard({
    required int juzNo,
    required int startPage,
    required Color cardBg,
    required Color borderStroke,
    required Color accentColor,
    required Color secondaryTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMushafPage(startPage),
        onLongPress: () {
          HapticService.selectionClick();
          _showJuzActionSheet(juzNo, startPage);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$juzNo.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.isTurkish ? 'Cüz' : 'Juz',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJuzActionSheet(int juzNo, int startPage) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2026) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$juzNo. Cüz ($startPage. Sayfa)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E2B27),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded,
                    color: Color(0xFF2D7D76)),
                title: const Text('Mushaf Sayfasını Aç (Oku)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openMushafPage(startPage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.headset_mic_rounded,
                    color: Color(0xFFD4AF37)),
                title: const Text('Mukabele ile Dinle / Takip Et',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Kelime takipli ve sesli tilavet'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openMukabeleScreen(
                      initialPage: startPage, initialJuz: juzNo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSurahCard({
    required SureItem surah,
    required Color cardBg,
    required Color borderStroke,
    required Color accentColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMushafPage(surah.startPage, targetSurah: surah),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 154,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: borderStroke.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${surah.id}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Name & Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      surah.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          surah.type,
                          style: TextStyle(
                              fontSize: 9.5, color: secondaryTextColor),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                              fontSize: 9.5, color: secondaryTextColor),
                        ),
                        Text(
                          '${surah.ayetSayisi} Ayet',
                          style: TextStyle(
                              fontSize: 9.5, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTalimCard({
    required String iconEmoji,
    required String tag,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color cardBg,
    required Color borderColor,
    required Color accentColor,
    required Color buttonColor,
    required VoidCallback onTap,
    VoidCallback? onCardTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap ?? onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(iconEmoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: accentColor.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
              Material(
                color: buttonColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP QURAN BADGE DETAIL DIALOGS
  // ==========================================

  void _showCompletedHatimModal(Hatim hatim) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
        final primaryTextColor =
            isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
        final secondaryTextColor =
            isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
        final accent =
            isDark ? const Color(0xFF3EA388) : const Color(0xFF2D7D76);

        final isMukabele = hatim.id.startsWith('mukabele_') ||
            hatim.title.toLowerCase().contains('mukabele');

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isMukabele ? '👑' : '🏆',
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hatim.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '✅ Hatm-i Şerif Başarıyla Tamamlandı (604 Sayfa)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryTextColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🤲 ', style: TextStyle(fontSize: 18)),
                            Text(
                              'Kuran-ı Kerim Hatim Duası',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'اللَّهُمَّ ارْحَمْنَا بِالقُرْآنِ، وَاجْعَلْهُ لَنَا إِمَاماً وَنُوراً وَهُدًى وَرَحْمَةً، اللَّهُمَّ ذَكِّرْنَا مِنْهُ مَا نَسِينَا، وَعَلِّمْنَا مِنْهُ مَا جَهِلْنَا، وَارْزُقْنَا تِلاَوَتَهُ آنَاءَ اللَّيْلِ وَأَطْرَافَ النَّهَارِ، وَاجْعَلْهُ لَنَا حُجَّةً يَا رَبَّ العَالَمِينَ.',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 16,
                            height: 1.8,
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '\"Allah\'ım! Bize Kur\'ân ile merhamet eyle. Onu bizim için bir rehber, bir nûr, bir hidâyet ve bir rahmet kıl. Allah\'ım! Ondan unuttuklarımızı bize hatırlat, bilmediklerimizi bize öğret. Gece vakitlerinde ve gündüzün taraflarında onu okumayı bize nasip eyle. Onu lehimize hüccet kıl, ey Âlemlerin Rabbi!\"',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: secondaryTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryTextColor,
                            side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Kapat'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openMushafPage(1, activeHatim: hatim);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Yeniden Oku',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBadgeDetailModal({
    required String title,
    required String icon,
    required String description,
    required String category,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
        final primaryTextColor =
            isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
        final secondaryTextColor =
            isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2D7D76).withValues(alpha: 0.15),
                    border:
                        Border.all(color: const Color(0xFF2D7D76), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D7D76),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7D76),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Tamam',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStreakDetailModal(
      String surahTitle, int currentStreak, int targetDays, String blessing) {
    _showBadgeDetailModal(
      title: '$surahTitle Virdi',
      icon: '🌿',
      description:
          'Mevcut İlerleme: $currentStreak/$targetDays Gün.\n$blessing için her gün düzenli olarak devam edin.',
      category: '40 Günlük Sure Virdi',
    );
  }
}
