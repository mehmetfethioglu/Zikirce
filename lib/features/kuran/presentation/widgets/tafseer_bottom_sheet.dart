import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/meal_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../providers/kuran_providers.dart';

class TafseerBottomSheet extends ConsumerStatefulWidget {
  final int surahId;
  final int verseId;
  final String surahName;
  final String arabicText;
  final String mealText;
  final int initialTab; // 0: Tefsir, 1: Meâl Karşılaştırma

  const TafseerBottomSheet({
    super.key,
    required this.surahId,
    required this.verseId,
    required this.surahName,
    required this.arabicText,
    required this.mealText,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    QuranAyatModel? ayat,
    int? surahId,
    int? verseId,
    String? surahName,
    String? arabicText,
    String? mealText,
    int initialTab = 0,
  }) {
    final resolvedSurahId = ayat?.sureId ?? surahId ?? 1;
    final resolvedVerseId = ayat?.ayetId ?? verseId ?? 1;
    final resolvedSurahName =
        ayat?.sure?.sureNameTurkish ?? surahName ?? 'Fâtiha';
    final resolvedArabic = arabicText ??
        (ayat != null
            ? QuranWordHighlighter.cleanArabicText(ayat.ayetText)
            : '');
    final resolvedMeal = mealText ?? '';

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TafseerBottomSheet(
        surahId: resolvedSurahId,
        verseId: resolvedVerseId,
        surahName: resolvedSurahName,
        arabicText: resolvedArabic,
        mealText: resolvedMeal,
        initialTab: initialTab,
      ),
    );
  }

  @override
  ConsumerState<TafseerBottomSheet> createState() => _TafseerBottomSheetState();
}

class _TafseerBottomSheetState extends ConsumerState<TafseerBottomSheet> {
  late int _selectedTab;
  bool _isLoadingTafseer = true;
  bool _isCurrentSourceDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  TafseerEntryResult? _tafseerEntry;
  Set<String> _downloadedTafseerIds = {};

  bool _isLoadingComparative = false;
  List<MealComparisonEntry> _comparativeMeals = [];
  String? _transliterationText;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _refreshTafseerState();
    _loadComparativeMeals();
  }

  Future<void> _refreshTafseerState() async {
    if (!mounted) return;
    setState(() => _isLoadingTafseer = true);

    final service = ref.read(tafseerServiceProvider);
    final activeId = ref.read(activeTafseerSourceProvider);
    final downloadedIds = await service.getDownloadedSourceIds();
    final isDownloaded = downloadedIds.contains(activeId);

    TafseerEntryResult? entry;
    if (isDownloaded) {
      entry = await service.getTafseerEntry(
        widget.surahId,
        widget.verseId,
        widget.surahName,
        sourceId: activeId,
      );
    }

    if (!mounted) return;
    setState(() {
      _downloadedTafseerIds = downloadedIds.toSet();
      _isCurrentSourceDownloaded = isDownloaded;
      _tafseerEntry = entry;
      _isLoadingTafseer = false;
    });

    // İlk açılışta hiçbir tefsir indirilmemişse varsayılan Kur'ân Yolu tefsirini otomatik indir
    if (!isDownloaded && downloadedIds.isEmpty && !_isDownloading) {
      _downloadSelectedTafseer(activeId);
    }
  }

  Future<void> _loadComparativeMeals() async {
    if (!mounted) return;
    setState(() => _isLoadingComparative = true);

    final mealService = ref.read(mealServiceProvider);
    final selectedSources = ref.read(comparisonMealSourcesProvider);
    final showTranslit = ref.read(showTransliterationProvider);

    final entries = await mealService.getComparativeMeals(
      widget.surahId,
      widget.verseId,
      sourceIds: selectedSources,
      defaultDiyanetText: widget.mealText,
    );

    String? translit;
    if (showTranslit) {
      translit = await mealService.getTransliteration(
        widget.surahId,
        widget.verseId,
      );
    }

    if (!mounted) return;
    setState(() {
      _comparativeMeals = entries;
      _transliterationText = translit;
      _isLoadingComparative = false;
    });
  }

  Future<void> _downloadSelectedTafseer(String sourceId) async {
    if (_isDownloading) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.02;
    });

    final service = ref.read(tafseerServiceProvider);
    final ok = await service.downloadSource(
      sourceId,
      onProgress: (p) {
        if (mounted) {
          setState(() => _downloadProgress = p);
        }
      },
    );

    if (!mounted) return;
    setState(() => _isDownloading = false);

    if (ok) {
      await _refreshTafseerState();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tefsir paketi indirilemedi. Lütfen internet bağlantınızı kontrol edin.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareVerseCard({String? customMealText, String? customAuthor}) {
    HapticFeedback.lightImpact();
    final refLabel = customAuthor != null
        ? '${widget.surahName} Sûresi, ${widget.verseId}. Âyet • $customAuthor'
        : '${widget.surahName} Sûresi, ${widget.verseId}. Âyet';
    ZikirSharePreviewModal.show(
      context: context,
      zikirName: refLabel,
      arabicText: widget.arabicText,
      virtue: customMealText ?? widget.mealText,
      customSource: refLabel,
      category: 'Kur\'an Tilaveti',
      currentCount: 0,
      targetCount: 1,
      totalCount: 0,
      initialShowCounterStats: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF15191C) : const Color(0xFFFDFBF7);
    final cardBg = isDark ? const Color(0xFF1E2428) : const Color(0xFFF5EFE2);
    final textColor = isDark ? const Color(0xFFF1ECE1) : const Color(0xFF2B2118);
    final subTextColor =
        isDark ? const Color(0xFFA59E92) : const Color(0xFF6B5848);
    final accentColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFFA64B2A);
    final activeTafseerId = ref.watch(activeTafseerSourceProvider);
    final activeSourceInfo = TafseerService.getSourceInfo(activeTafseerId);
    final fontSettings = ref.watch(kuranFontSettingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Top bar: Surah & Verse badge + actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '${widget.surahName} Sûresi • ${widget.verseId}. Âyet',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Font size controls
                    IconButton(
                      tooltip: 'Yazıyı Küçült',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref
                            .read(kuranFontSettingsProvider.notifier)
                            .setMealFontSize(fontSettings.mealFontSize - 1.5);
                      },
                      icon: Icon(
                        Icons.text_decrease_rounded,
                        size: 19,
                        color: subTextColor,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yazıyı Büyüt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref
                            .read(kuranFontSettingsProvider.notifier)
                            .setMealFontSize(fontSettings.mealFontSize + 1.5);
                      },
                      icon: Icon(
                        Icons.text_increase_rounded,
                        size: 19,
                        color: subTextColor,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Paylaşım Kartı Oluştur',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _shareVerseCard(),
                      icon: Icon(
                        Icons.ios_share_rounded,
                        size: 20,
                        color: accentColor,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented mode switcher: Tefsir vs Meâl Karşılaştırma
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTabButton(
                          index: 0,
                          icon: Icons.menu_book_rounded,
                          label: 'Tefsir Kütüphanesi',
                          accentColor: accentColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildModeTabButton(
                          index: 1,
                          icon: Icons.compare_arrows_rounded,
                          label: 'Meâl Karşılaştırma',
                          accentColor: accentColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  children: [
                    // Verse Arabic & Primary Meal Card (Uncluttered Tahrir-style)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.arabicText.isNotEmpty) ...[
                            Builder(
                              builder: (context) {
                                final arabicFont =
                                    ref.watch(arabicFontFamilyProvider);
                                final isBoldArabic =
                                    ref.watch(isBoldArabicProvider);
                                final highlightDivine =
                                    ref.watch(highlightDivineWordsProvider);
                                return Text.rich(
                                  TextSpan(
                                    children: QuranWordHighlighter
                                        .buildHighlightedSpans(
                                      rawText: widget.arabicText,
                                      baseStyle: TextStyle(
                                        fontFamily: arabicFont,
                                        fontSize: fontSettings.arabicFontSize,
                                        fontWeight: isBoldArabic
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        height: 1.95,
                                        color: textColor,
                                      ),
                                      isDark: isDark,
                                      enabled: highlightDivine,
                                      fontFamily: arabicFont,
                                      isBold: isBoldArabic,
                                      ayahNumber: widget.verseId.toString(),
                                      showAyahStopMarker: true,
                                    ),
                                  ),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: subTextColor.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            widget.mealText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: fontSettings.mealFontSize,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (_selectedTab == 0)
                      _buildTafseerSection(
                        context: context,
                        activeSourceInfo: activeSourceInfo,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        accentColor: accentColor,
                        cardBg: cardBg,
                        fontSize: fontSettings.mealFontSize,
                        isDark: isDark,
                      )
                    else
                      _buildMealComparisonSection(
                        context: context,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        accentColor: accentColor,
                        cardBg: cardBg,
                        fontSize: fontSettings.mealFontSize,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeTabButton({
    required int index,
    required IconData icon,
    required String label,
    required Color accentColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2B3338) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : subTextColor,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? textColor : subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTafseerSection({
    required BuildContext context,
    required TafseerSourceInfo activeSourceInfo,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardBg,
    required double fontSize,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: Kaynak Seçimi + İndirilenleri Yönet
        Row(
          children: [
            Text(
              'TEFSİR KAYNAĞI SEÇİN',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: subTextColor,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () async {
                await TafseerLibraryManagerSheet.show(context);
                await _refreshTafseerState();
              },
              icon: Icon(
                Icons.cloud_download_outlined,
                size: 16,
                color: accentColor,
              ),
              label: Text(
                'Kütüphaneyi Yönet',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Horizontal source selector chips
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: TafseerService.availableSources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final src = TafseerService.availableSources[index];
              final isSelected = src.id == activeSourceInfo.id;
              final isDownloaded = _downloadedTafseerIds.contains(src.id);

              return ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                selectedColor: accentColor,
                backgroundColor: cardBg,
                side: BorderSide(
                  color: isSelected
                      ? accentColor
                      : subTextColor.withValues(alpha: 0.22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDownloaded
                          ? Icons.check_circle_rounded
                          : Icons.download_for_offline_outlined,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : (isDownloaded ? accentColor : subTextColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      src.shortTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                    if (!isDownloaded) ...[
                      const SizedBox(width: 5),
                      Text(
                        '(${src.sizeLabel})',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : subTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
                onSelected: (_) async {
                  HapticFeedback.selectionClick();
                  await ref
                      .read(activeTafseerSourceProvider.notifier)
                      .setSource(src.id);
                  await _refreshTafseerState();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoadingTafseer)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_isCurrentSourceDownloaded)
          _buildOnDemandDownloadPrompt(
            source: activeSourceInfo,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: accentColor,
            cardBg: cardBg,
          )
        else if (_tafseerEntry == null || _tafseerEntry!.tefsirText.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Bu âyet-i kerîme önceki veya sonraki âyet grubuyla birlikte tefsir edilmiştir.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                color: subTextColor,
              ),
            ),
          )
        else
          _buildLoadedTafseerContent(
            entry: _tafseerEntry!,
            textColor: textColor,
            subTextColor: subTextColor,
            accentColor: accentColor,
            cardBg: cardBg,
            fontSize: fontSize,
          ),
      ],
    );
  }

  Widget _buildOnDemandDownloadPrompt({
    required TafseerSourceInfo source,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.author,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${source.eraBadge} • İndirme Boyutu: ${source.sizeLabel}',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            source.description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.5,
              color: textColor.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Uygulamanın ilk kurulum boyutunu şişirmemek için tefsir veritabanları isteğe bağlı indirilir. Bir kez indirildiğinde tamamen çevrimdışı (internetsiz) çalışır.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.45,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 18),
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 8,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'İndiriliyor ve indeksleniyor... %${(_downloadProgress * 100).toInt()}',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _downloadSelectedTafseer(source.id),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  '${source.shortTitle} Paketini İndir (${source.sizeLabel})',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadedTafseerContent({
    required TafseerEntryResult entry,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardBg,
    required double fontSize,
  }) {
    final paragraphs = entry.tefsirText
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source & Verse range info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.source.title} • ${entry.rangeLabel}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      entry.source.author,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tefsiri Kopyala',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${entry.title} (${entry.source.title})\n\n${entry.tefsirText}',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tefsir metni panoya kopyalandı.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(Icons.copy_rounded, size: 18, color: accentColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (entry.mealText.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Müfessirin Âyet Meâli (${entry.rangeLabel})',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  entry.mealText.trim(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.58,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],

        for (final para in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(
              para,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize + 0.5,
                height: 1.72,
                color: textColor.withValues(alpha: 0.92),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMealComparisonSection({
    required BuildContext context,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardBg,
    required double fontSize,
  }) {
    final selectedSources = ref.watch(comparisonMealSourcesProvider);
    final showTranslit = ref.watch(showTransliterationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'KARŞILAŞTIRILACAK MEÂLLER',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: subTextColor,
              ),
            ),
            const Spacer(),
            FilterChip(
              selected: showTranslit,
              showCheckmark: false,
              selectedColor: accentColor.withValues(alpha: 0.18),
              backgroundColor: cardBg,
              label: Text(
                'Türkçe Okunuş',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: showTranslit ? accentColor : subTextColor,
                ),
              ),
              onSelected: (val) async {
                await ref
                    .read(showTransliterationProvider.notifier)
                    .toggle(val);
                await _loadComparativeMeals();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Multi-select filter chips for all 7 reliable Turkish Meals
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealService.availableSources.map((src) {
            final isSelected = selectedSources.contains(src.id);
            return FilterChip(
              selected: isSelected,
              selectedColor: accentColor,
              checkmarkColor: Colors.white,
              backgroundColor: cardBg,
              side: BorderSide(
                color: isSelected
                    ? accentColor
                    : subTextColor.withValues(alpha: 0.22),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              label: Text(
                src.shortTitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
              onSelected: (_) async {
                HapticFeedback.selectionClick();
                await ref
                    .read(comparisonMealSourcesProvider.notifier)
                    .toggleSource(src.id);
                await _loadComparativeMeals();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        if (showTranslit &&
            _transliterationText != null &&
            _transliterationText!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TÜRKÇE OKUNUŞ (TRANSKRİPSİYON)',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _transliterationText!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: fontSize - 0.5,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (_isLoadingComparative)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ..._comparativeMeals.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: subTextColor.withValues(alpha: 0.14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.source.title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bu Meâli Kart Olarak Paylaş',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _shareVerseCard(
                          customMealText: entry.text,
                          customAuthor: entry.source.shortTitle,
                        ),
                        icon: Icon(
                          Icons.ios_share_rounded,
                          size: 17,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    entry.text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      height: 1.58,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// İsteğe Bağlı Tefsir & Meâl Kütüphanesi Yönetim Penceresi
class TafseerLibraryManagerSheet extends ConsumerStatefulWidget {
  final VoidCallback? onOpenTafseerReader;

  const TafseerLibraryManagerSheet({
    super.key,
    this.onOpenTafseerReader,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenTafseerReader,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TafseerLibraryManagerSheet(
        onOpenTafseerReader: onOpenTafseerReader,
      ),
    );
  }

  @override
  ConsumerState<TafseerLibraryManagerSheet> createState() =>
      _TafseerLibraryManagerSheetState();
}

class _TafseerLibraryManagerSheetState
    extends ConsumerState<TafseerLibraryManagerSheet> {
  Set<String> _downloadedTafseers = {};
  Set<String> _downloadedMeals = {};
  final Map<String, double> _progressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final tafseerService = ref.read(tafseerServiceProvider);
    final mealService = ref.read(mealServiceProvider);
    final tIds = await tafseerService.getDownloadedSourceIds();
    final Set<String> mIds = {};
    for (final m in MealService.availableSources) {
      if (await mealService.isDownloaded(m.id)) {
        mIds.add(m.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _downloadedTafseers = tIds.toSet();
      _downloadedMeals = mIds;
      _isLoading = false;
    });
  }

  Future<void> _downloadTafseer(TafseerSourceInfo src) async {
    setState(() => _progressMap[src.id] = 0.02);
    final ok = await ref.read(tafseerServiceProvider).downloadSource(
      src.id,
      onProgress: (p) {
        if (mounted) setState(() => _progressMap[src.id] = p);
      },
    );
    if (!mounted) return;
    setState(() => _progressMap.remove(src.id));
    if (ok) {
      await ref.read(activeTafseerSourceProvider.notifier).setSource(src.id);
      await _refreshStatus();
    }
  }

  Future<void> _deleteTafseer(TafseerSourceInfo src) async {
    await ref.read(tafseerServiceProvider).deleteSource(src.id);
    await _refreshStatus();
  }

  Future<void> _downloadMeal(MealSourceInfo src) async {
    setState(() => _progressMap[src.id] = 0.1);
    await ref.read(mealServiceProvider).downloadSource(
      src.id,
      onProgress: (p) {
        if (mounted) setState(() => _progressMap[src.id] = p);
      },
    );
    if (!mounted) return;
    setState(() => _progressMap.remove(src.id));
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF15191C) : const Color(0xFFFDFBF7);
    final cardBg = isDark ? const Color(0xFF1E2428) : const Color(0xFFF5EFE2);
    final textColor = isDark ? const Color(0xFFF1ECE1) : const Color(0xFF2B2118);
    final subTextColor =
        isDark ? const Color(0xFFA59E92) : const Color(0xFF6B5848);
    final accentColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFFA64B2A);
    final activeMealId = ref.watch(activeMealSourceProvider);
    final activeTafseerId = ref.watch(activeTafseerSourceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.library_books_rounded, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meâl & Tefsir Kütüphanesi',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'İsteğe bağlı indirilebilir, telifsiz güvenilir kaynaklar',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: subTextColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          Text(
                            'TEFSİR KÜLLİYATI (İSTEĞE BAĞLI ÇEVRİMDIŞI PAKETLER)',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...TafseerService.availableSources.map((src) {
                            final isDown = _downloadedTafseers.contains(src.id);
                            final isSelected = activeTafseerId == src.id;
                            final prog = _progressMap[src.id];
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await ref
                                    .read(activeTafseerSourceProvider.notifier)
                                    .setSource(src.id);
                                if (!isDown) {
                                  await _downloadTafseer(src);
                                }
                                if (context.mounted &&
                                    widget.onOpenTafseerReader != null) {
                                  Navigator.of(context).pop();
                                  widget.onOpenTafseerReader!();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? accentColor
                                        : (isDown
                                            ? accentColor.withValues(alpha: 0.35)
                                            : subTextColor.withValues(alpha: 0.14)),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  src.title,
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                              if (isDown)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: accentColor
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isSelected
                                                        ? 'Aktif Tefsir'
                                                        : 'İndirildi',
                                                    style: TextStyle(
                                                      fontFamily: 'Outfit',
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: accentColor,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${src.author} • ${src.sizeLabel}',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: accentColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            src.description,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              height: 1.4,
                                              color: subTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (prog != null)
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(
                                          value: prog,
                                          strokeWidth: 3,
                                          color: accentColor,
                                        ),
                                      )
                                    else if (isDown)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: accentColor,
                                              foregroundColor: Colors.white,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                            ),
                                            onPressed: () async {
                                              await ref
                                                  .read(
                                                      activeTafseerSourceProvider
                                                          .notifier)
                                                  .setSource(src.id);
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                widget.onOpenTafseerReader
                                                    ?.call();
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.menu_book_rounded,
                                              size: 15,
                                            ),
                                            label: const Text(
                                              'Oku',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Cihazdan Sil',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () =>
                                                _deleteTafseer(src),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: accentColor
                                              .withValues(alpha: 0.15),
                                          foregroundColor: accentColor,
                                        ),
                                        onPressed: () async {
                                          await _downloadTafseer(src);
                                          if (context.mounted &&
                                              widget.onOpenTafseerReader !=
                                                  null) {
                                            Navigator.of(context).pop();
                                            widget.onOpenTafseerReader!();
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'İndir (${src.sizeLabel})',
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 18),
                          Text(
                            'TÜRKÇE MEÂL KAYNAKLARI (VARSAYILAN MEÂL SEÇİMİ)',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...MealService.availableSources.map((src) {
                            final isDown = _downloadedMeals.contains(src.id);
                            final isActive = activeMealId == src.id;
                            final prog = _progressMap[src.id];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive
                                      ? accentColor
                                      : subTextColor.withValues(alpha: 0.14),
                                  width: isActive ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      await ref
                                          .read(
                                              activeMealSourceProvider.notifier)
                                          .setSource(src.id);
                                      await _refreshStatus();
                                    },
                                    icon: Icon(
                                      isActive
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isActive
                                          ? accentColor
                                          : subTextColor.withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        await ref
                                            .read(
                                                activeMealSourceProvider.notifier)
                                            .setSource(src.id);
                                        await _refreshStatus();
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            src.title,
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            src.description,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11.5,
                                              color: subTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (prog != null)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  else if (!isDown)
                                    IconButton(
                                      tooltip: 'İndir (${src.sizeLabel})',
                                      onPressed: () => _downloadMeal(src),
                                      icon: Icon(
                                        Icons.download_rounded,
                                        color: accentColor,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
