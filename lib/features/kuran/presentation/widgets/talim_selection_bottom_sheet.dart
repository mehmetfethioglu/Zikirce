import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../ezber/presentation/screens/kelime_takipli_dinleme_screen.dart';
import '../../providers/kuran_providers.dart';

class AshrPreset {
  final String title;
  final String arabicTitle;
  final String subtitle;
  final int surahId;
  final int startAyah;
  final int endAyah;
  final String icon;
  final String benefit;

  const AshrPreset({
    required this.title,
    required this.arabicTitle,
    required this.subtitle,
    required this.surahId,
    required this.startAyah,
    required this.endAyah,
    required this.icon,
    required this.benefit,
  });
}

class TalimSelectionBottomSheet extends ConsumerStatefulWidget {
  final String modeKey;
  final String modeTitle;
  final String modeIcon;
  final Color modeColor;
  final int initialPage;
  final bool isAudioSyncListening;

  const TalimSelectionBottomSheet({
    super.key,
    required this.modeKey,
    required this.modeTitle,
    required this.modeIcon,
    required this.modeColor,
    this.initialPage = 1,
    this.isAudioSyncListening = false,
  });

  static Future<TalimSelectionResult?> show(
    BuildContext context, {
    required String modeKey,
    required String modeTitle,
    required String modeIcon,
    required Color modeColor,
    int initialPage = 1,
    bool isAudioSyncListening = false,
  }) {
    return showModalBottomSheet<TalimSelectionResult>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TalimSelectionBottomSheet(
        modeKey: modeKey,
        modeTitle: modeTitle,
        modeIcon: modeIcon,
        modeColor: modeColor,
        initialPage: initialPage,
        isAudioSyncListening: isAudioSyncListening,
      ),
    );
  }

  @override
  ConsumerState<TalimSelectionBottomSheet> createState() =>
      _TalimSelectionBottomSheetState();
}

class _TalimSelectionBottomSheetState
    extends ConsumerState<TalimSelectionBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  String _surahSearchQuery = '';
  final TextEditingController _surahSearchController = TextEditingController();

  // Aşr-ı Şerif State
  int _ashrSelectedSurahId = 2; // Bakara
  int _ashrStartAyah = 285;
  int _ashrEndAyah = 286;

  static const List<AshrPreset> famousAshrs = [
    AshrPreset(
      title: 'Âmenerrasûlü',
      arabicTitle: 'آمَنَ الرَّسُولُ',
      subtitle: 'Bakara Sûresi (285-286. Âyetler)',
      surahId: 2,
      startAyah: 285,
      endAyah: 286,
      icon: '🛡️',
      benefit: 'Gece okuyana kâfidir, her türlü şerden muhafaza eder.',
    ),
    AshrPreset(
      title: 'Hüvallâhüllezi (Lev Enzelnâ)',
      arabicTitle: 'لَوْ أَنْزَلْنَا هَٰذَا الْقُرْآنَ',
      subtitle: 'Haşr Sûresi (21-24. Âyetler)',
      surahId: 59,
      startAyah: 21,
      endAyah: 24,
      icon: '✨',
      benefit: 'Sabah-akşam okuyana 70 bin melek akşama kadar istiğfar eder.',
    ),
    AshrPreset(
      title: 'Âyetü\'l-Kürsî',
      arabicTitle: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
      subtitle: 'Bakara Sûresi (255. Âyet)',
      surahId: 2,
      startAyah: 255,
      endAyah: 255,
      icon: '👑',
      benefit: 'Kur\'ân-ı Kerîm\'in en faziletli ve en yüce âyetidir.',
    ),
    AshrPreset(
      title: 'Fetih Sûresi Sonu',
      arabicTitle: 'مُحَمَّدٌ رَسُولُ اللَّهِ',
      subtitle: 'Fetih Sûresi (27-29. Âyetler)',
      surahId: 48,
      startAyah: 27,
      endAyah: 29,
      icon: '🏆',
      benefit: 'Manevi fetih, zafer ve Peygamber ﷺ sevgisi vesilesidir.',
    ),
    AshrPreset(
      title: 'Yâsîn-i Şerif Başı',
      arabicTitle: 'يس ¤ وَالْقُرْآنِ الْحَكِيمِ',
      subtitle: 'Yâsîn Sûresi (1-12. Âyetler)',
      surahId: 36,
      startAyah: 1,
      endAyah: 12,
      icon: '🌿',
      benefit: 'Kur\'ân\'ın kalbidir; hacetlerin kabulüne ve kalbe sürurdur.',
    ),
    AshrPreset(
      title: 'Mülk (Tebâreke) Başı',
      arabicTitle: 'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ',
      subtitle: 'Mülk Sûresi (1-14. Âyetler)',
      surahId: 67,
      startAyah: 1,
      endAyah: 14,
      icon: '🌌',
      benefit: 'Kabir azabından muhafaza edici ve nurlu bir kalkandır.',
    ),
    AshrPreset(
      title: 'Rahmân Sûresi Başı',
      arabicTitle: 'الرَّحْمَٰنُ ¤ عَلَّمَ الْقُرْآنَ',
      subtitle: 'Rahmân Sûresi (1-27. Âyetler)',
      surahId: 55,
      startAyah: 1,
      endAyah: 27,
      icon: '💎',
      benefit: 'Kur\'ân\'ın zîneti; ilâhî nimetlerin tefekkürü ve şükrüdür.',
    ),
    AshrPreset(
      title: 'Vâkıa Sûresi Başı',
      arabicTitle: 'إِذَا وَقَعَتِ الْوَاقِعَةُ',
      subtitle: 'Vâkıa Sûresi (1-26. Âyetler)',
      surahId: 56,
      startAyah: 1,
      endAyah: 26,
      icon: '🌾',
      benefit: 'Manevi zenginlik, bereket ve rızık darlığından necattır.',
    ),
    AshrPreset(
      title: 'Nebe (Amme) Başı',
      arabicTitle: 'عَمَّ يَتَسَاءَلُونَ',
      subtitle: 'Nebe Sûresi (1-16. Âyetler)',
      surahId: 78,
      startAyah: 1,
      endAyah: 16,
      icon: '⚡',
      benefit: 'Ahiret tefekkürü ve hıfz taliminin en mühim temelidir.',
    ),
    AshrPreset(
      title: 'İnşirah Sûresi',
      arabicTitle: 'أَلَمْ نَشْرَحْ لَكَ صَدْرَكَ',
      subtitle: 'İnşirah Sûresi (1-8. Âyetler)',
      surahId: 94,
      startAyah: 1,
      endAyah: 8,
      icon: '🤍',
      benefit: 'Gönül darlığını giderir, zorlukları suhuletle kolaylaştırır.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentPage = widget.initialPage.clamp(1, 605);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _surahSearchController.dispose();
    super.dispose();
  }

  void _setPage(int p) {
    setState(() {
      _currentPage = p.clamp(1, 605);
    });
  }

  String _getPageInfo(int page) {
    final juz = SurahDataProvider.getJuzForPage(page);
    SureItem? currentSurah;
    for (final s in SurahDataProvider.surahs) {
      if (s.startPage <= page) {
        currentSurah = s;
      } else {
        break;
      }
    }
    final surahName = currentSurah?.name ?? 'Fâtiha';
    return '$juz. Cüz · $surahName Sûresi';
  }

  void _submitPage(int page) {
    Navigator.of(context).pop(
      TalimSelectionResult(
        type: TalimTargetType.page,
        id: page,
        title: 'Sayfa $page',
      ),
    );
  }

  void _submitSurah(SureItem surah) {
    Navigator.of(context).pop(
      TalimSelectionResult(
        type: TalimTargetType.surah,
        id: surah.id,
        title: '${surah.name} Sûresi',
      ),
    );
  }

  void _submitJuz(int juzNumber) {
    Navigator.of(context).pop(
      TalimSelectionResult(
        type: TalimTargetType.juz,
        id: juzNumber,
        title: '$juzNumber. Cüz',
      ),
    );
  }

  void _submitAshr({
    required int surahId,
    required int startAyah,
    required int endAyah,
    required String title,
  }) {
    Navigator.of(context).pop(
      TalimSelectionResult(
        type: TalimTargetType.ashr,
        id: surahId,
        title: title,
        startAyah: startAyah,
        endAyah: endAyah,
        customTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final primaryTextColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB);
    final borderStroke = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header with Icon, Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.modeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.modeIcon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.modeTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sayfa, Sûre, Cüz veya Aşr seçerek başlayın',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: secondaryTextColor, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar (Sayfa / Sûre / Cüz / Aşr)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderStroke),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: widget.modeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: secondaryTextColor,
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '📄 Sayfa'),
                  Tab(text: '📖 Sûre'),
                  Tab(text: '✨ Cüz'),
                  Tab(text: '📿 Aşr'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: SAYFA SEÇİMİ
                _buildPageTab(
                  cardBg: cardBg,
                  borderStroke: borderStroke,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                // TAB 2: SÛRE SEÇİMİ
                _buildSurahTab(
                  cardBg: cardBg,
                  borderStroke: borderStroke,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                // TAB 3: CÜZ SEÇİMİ
                _buildJuzTab(
                  cardBg: cardBg,
                  borderStroke: borderStroke,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                // TAB 4: AŞR-I ŞERİF SEÇİMİ
                _buildAshrTab(
                  cardBg: cardBg,
                  borderStroke: borderStroke,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ----------------------------------------------------
  // TAB 1: SAYFA SEÇİMİ
  // ----------------------------------------------------
  Widget _buildPageTab({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final infoText = _getPageInfo(_currentPage);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Shortcut Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('📌', 'Fâtiha (1)', 1, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('🌿', 'Yâsîn (440)', 440, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('👑', 'Mülk (562)', 562, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('✨', 'Nebe (582)', 582, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('🎯', 'İhlâs (605)', 605, cardBg, borderStroke, primaryTextColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Page Selector Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderStroke),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decrement Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _setPage(_currentPage - 1),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: borderStroke.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.remove_rounded, color: primaryTextColor, size: 22),
                        ),
                      ),
                    ),

                    // Number & Info
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Sayfa ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                            Text(
                              '$_currentPage',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: widget.modeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          infoText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Increment Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _setPage(_currentPage + 1),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: borderStroke.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.add_rounded, color: primaryTextColor, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.modeColor,
                    inactiveTrackColor: widget.modeColor.withValues(alpha: 0.2),
                    thumbColor: widget.modeColor,
                    overlayColor: widget.modeColor.withValues(alpha: 0.15),
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                  ),
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 1,
                    max: 605,
                    onChanged: (val) {
                      _setPage(val.round());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Start Practice CTA Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.modeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: widget.modeColor.withValues(alpha: 0.4),
            ),
            onPressed: () => _submitPage(_currentPage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sayfa $_currentPage Dinle & Başla',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.play_arrow_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: SÛRE SEÇİMİ
  // ----------------------------------------------------
  Widget _buildSurahTab({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final filteredSurahs = SurahDataProvider.surahs.where((s) {
      if (_surahSearchQuery.isEmpty) return true;
      final q = _surahSearchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.id.toString().contains(q) ||
          s.nameArabic.contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _surahSearchController,
            style: TextStyle(fontSize: 13.5, color: primaryTextColor),
            decoration: InputDecoration(
              hintText: 'Sûre ara (Örn: Yasin, Fatiha, 36)...',
              hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
              suffixIcon: _surahSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _surahSearchController.clear();
                        setState(() => _surahSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderStroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderStroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.modeColor, width: 1.5),
              ),
            ),
            onChanged: (val) => setState(() => _surahSearchQuery = val),
          ),
        ),

        // Surahs List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: filteredSurahs.length,
            itemBuilder: (context, idx) {
              final surah = filteredSurahs[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderStroke),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.modeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${surah.id}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.modeColor,
                      ),
                    ),
                  ),
                  title: Text(
                    '${surah.name} Sûresi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  subtitle: Text(
                    '${surah.ayetSayisi} Âyet • ${surah.type} • Sayfa ${surah.startPage}',
                    style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        surah.nameArabic,
                        style: TextStyle(
                          fontFamily: ref.watch(arabicFontFamilyProvider),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.play_circle_fill_rounded, color: widget.modeColor, size: 26),
                    ],
                  ),
                  onTap: () => _submitSurah(surah),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 3: CÜZ SEÇİMİ
  // ----------------------------------------------------
  Widget _buildJuzTab({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: 30,
      itemBuilder: (context, idx) {
        final juzNumber = idx + 1;
        final (startPage, endPage) = AudioSyncService.getJuzPageRange(juzNumber);
        final startSurah = SurahDataProvider.getSurahForPage(startPage);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _submitJuz(juzNumber),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$juzNumber. Cüz',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.modeColor,
                        ),
                      ),
                      Icon(Icons.play_circle_fill_rounded, color: widget.modeColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sayfa $startPage - $endPage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    startSurah?.name ?? 'Fâtiha',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: secondaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickChip(
    String emoji,
    String label,
    int page,
    Color bg,
    Color stroke,
    Color textColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setPage(page),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSurahPickerForAshr() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = SurahDataProvider.surahs.where((s) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.id.toString().contains(q) ||
                  s.nameArabic.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aşr İçin Sûre Seçin',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Sûre ara (Örn: Haşr, 59)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setSheetState(() => query = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final s = filtered[idx];
                        final isSelected = s.id == _ashrSelectedSurahId;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: widget.modeColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            backgroundColor: widget.modeColor.withValues(alpha: 0.15),
                            child: Text('${s.id}', style: TextStyle(color: widget.modeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          title: Text('${s.name} Sûresi', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s.ayetSayisi} Âyet • ${s.type}'),
                          trailing: Text(s.nameArabic, style: const TextStyle(fontSize: 16)),
                          onTap: () {
                            setState(() {
                              _ashrSelectedSurahId = s.id;
                              _ashrStartAyah = 1;
                              _ashrEndAyah = s.ayetSayisi > 10 ? 10 : s.ayetSayisi;
                            });
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // TAB 4: AŞR-I ŞERİF SEÇİMİ
  // ----------------------------------------------------
  Widget _buildAshrTab({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final currentSurah = SurahDataProvider.getSurahById(_ashrSelectedSurahId) ??
        SurahDataProvider.surahs.first;
    final totalAyahs = currentSurah.ayetSayisi;
    final selectedCount = (_ashrEndAyah - _ashrStartAyah + 1).clamp(1, totalAyahs);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // 1. ÖZEL ÂYET ARALIĞI SEÇİM KARTI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Özel Âyet Aralığı Belirle',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.modeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$selectedCount Âyet',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.modeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sûre Seçici Butonu
              InkWell(
                onTap: _openSurahPickerForAshr,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: borderStroke.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderStroke),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.modeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${currentSurah.id}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.modeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${currentSurah.name} Sûresi',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              '${currentSurah.ayetSayisi} Âyet • ${currentSurah.type}',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currentSurah.nameArabic,
                        style: TextStyle(
                          fontFamily: ref.watch(arabicFontFamilyProvider),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down_rounded, color: secondaryTextColor, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Başlangıç ve Bitiş Âyet Seçicileri
              Row(
                children: [
                  // Başlangıç Âyeti
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: borderStroke.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderStroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Başlangıç Âyeti',
                            style: TextStyle(fontSize: 10.5, color: secondaryTextColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: _ashrStartAyah > 1
                                    ? () => setState(() => _ashrStartAyah--)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderStroke.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.remove, size: 16, color: primaryTextColor),
                                ),
                              ),
                              Text(
                                '$_ashrStartAyah',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: widget.modeColor,
                                ),
                              ),
                              InkWell(
                                onTap: _ashrStartAyah < _ashrEndAyah
                                    ? () => setState(() => _ashrStartAyah++)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderStroke.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.add, size: 16, color: primaryTextColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Bitiş Âyeti
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: borderStroke.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderStroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitiş Âyeti',
                            style: TextStyle(fontSize: 10.5, color: secondaryTextColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: _ashrEndAyah > _ashrStartAyah
                                    ? () => setState(() => _ashrEndAyah--)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderStroke.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.remove, size: 16, color: primaryTextColor),
                                ),
                              ),
                              Text(
                                '$_ashrEndAyah',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: widget.modeColor,
                                ),
                              ),
                              InkWell(
                                onTap: _ashrEndAyah < totalAyahs
                                    ? () => setState(() => _ashrEndAyah++)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderStroke.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.add, size: 16, color: primaryTextColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Start Custom Ashr Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.modeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: () => _submitAshr(
                  surahId: currentSurah.id,
                  startAyah: _ashrStartAyah,
                  endAyah: _ashrEndAyah,
                  title: '${currentSurah.name} Sûresi ($_ashrStartAyah-$_ashrEndAyah. Âyetler)',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${currentSurah.name} ($_ashrStartAyah-$_ashrEndAyah) Başla',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.play_arrow_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. MEŞHUR AŞR-I ŞERİFLER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meşhur Aşr-ı Şerifler',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            Text(
              'Tek tıkla dinle',
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        for (final ashr in famousAshrs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderStroke),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _submitAshr(
                  surahId: ashr.surahId,
                  startAyah: ashr.startAyah,
                  endAyah: ashr.endAyah,
                  title: '${ashr.title} • ${ashr.subtitle}',
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(ashr.icon, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ashr.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  ashr.arabicTitle,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: ref.watch(arabicFontFamilyProvider),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: widget.modeColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ashr.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.modeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ashr.benefit,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.play_circle_fill_rounded, color: widget.modeColor, size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
