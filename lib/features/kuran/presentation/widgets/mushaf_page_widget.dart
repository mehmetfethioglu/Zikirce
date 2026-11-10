import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/tv_mode_provider.dart';
import '../../../../core/services/meal_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../data/tilavet_secdesi_data.dart';
import 'tafseer_bottom_sheet.dart';
import 'tilavet_secdesi_guide_sheet.dart';
import 'zikirce_ayah_stop_marker.dart';
import '../../../../core/widgets/tv_focusable.dart';

enum MushafReadingMode {
  mushaf, // Klasik Arapça Mushaf Sayfası
  ayatAndMeal, // Âyet + Meâl (Satır Altı & Karşılaştırmalı)
  mealOnly, // Meâl (Akıcı Kitap Modu veya Kart Modu)
  tafseer, // Tefsir Okuma Modu (Sayfadaki Âyetlerin Gerçek Tefsiri)
}

class MushafPageWidget extends ConsumerStatefulWidget {
  final QuranPageData pageData;
  final bool isMealOnlyMode;
  final MushafReadingMode? readingMode;
  final bool? isActivePage;
  final void Function(int surahId, int ayahId, int wordOrder)? onWordTap;
  final void Function(int surahId, int ayahId)? onAyahTapOverride;

  const MushafPageWidget({
    super.key,
    required this.pageData,
    this.isMealOnlyMode = false,
    this.readingMode,
    this.isActivePage,
    this.onWordTap,
    this.onAyahTapOverride,
  });

  MushafReadingMode get effectiveMode =>
      readingMode ??
      (isMealOnlyMode ? MushafReadingMode.mealOnly : MushafReadingMode.mushaf);

  @override
  ConsumerState<MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends ConsumerState<MushafPageWidget> {
  final List<TapGestureRecognizer> _recognizers = [];
  final GlobalKey _activeMushafWordKey = GlobalKey();
  static const Set<String> _stopSigns = QuranWordHighlighter.stopSigns;

  void _scrollToActiveMushafWord() {
    final isActivePage = widget.isActivePage ??
        (widget.pageData.pageNo == ref.read(currentMushafPageProvider));
    if (!isActivePage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _activeMushafWordKey.currentContext;
      if (ctx == null) return;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final wordOffset = renderBox.localToGlobal(Offset.zero);
      final wordHeight = renderBox.size.height;
      final screenHeight = MediaQuery.of(context).size.height;
      const topSafeZone = 85.0;
      final bottomSafeZone = screenHeight - 95.0;

      if (wordOffset.dy < topSafeZone ||
          (wordOffset.dy + wordHeight) > bottomSafeZone) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.35,
        );
      }
    });
  }

  /// Cache of loaded custom/comparative meals for this page
  Map<String, String> _customMealsByKey = {};
  Map<String, List<MealComparisonEntry>> _comparativeMealsByKey = {};
  Map<String, String> _translitByKey = {};
  final Set<int> _expandedSurahInfoIds = {};

  /// Page-level Tafseer state when in MushafReadingMode.tafseer
  List<TafseerEntryResult> _pageTafseerEntries = [];
  Set<String> _downloadedTafseerIds = {};
  bool _isLoadingPageTafseer = false;
  bool _isCurrentTafseerDownloaded = false;
  bool _isDownloadingPageTafseer = false;
  double _pageTafseerDownloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExtendedMealData();
    _loadPageTafseerData();
  }

  @override
  void didUpdateWidget(covariant MushafPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageData.pageNo != widget.pageData.pageNo ||
        oldWidget.effectiveMode != widget.effectiveMode) {
      _loadExtendedMealData();
      _loadPageTafseerData();
    }
  }

  Future<void> _loadPageTafseerData() async {
    if (widget.effectiveMode != MushafReadingMode.tafseer) return;
    if (!mounted) return;
    setState(() => _isLoadingPageTafseer = true);

    final service = ref.read(tafseerServiceProvider);
    final activeId = ref.read(activeTafseerSourceProvider);
    final downloaded = await service.getDownloadedSourceIds();
    final isDown = downloaded.contains(activeId);

    List<TafseerEntryResult> entries = [];
    if (isDown) {
      final verseRefs = widget.pageData.quranAyats
          .map((a) => (
                surahId: a.sureId,
                verseId: a.ayetId,
                surahName:
                    a.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel,
              ))
          .toList();
      entries = await service.getUniqueEntriesForVerses(
        verseRefs,
        sourceId: activeId,
      );
    }

    if (!mounted) return;
    setState(() {
      _downloadedTafseerIds = downloaded.toSet();
      _isCurrentTafseerDownloaded = isDown;
      _pageTafseerEntries = entries;
      _isLoadingPageTafseer = false;
    });

    // İlk kez Tefsir moduna girildiğinde aktif tefsir henüz indirilmemişse otomatik indir
    if (!isDown && !_isDownloadingPageTafseer) {
      _downloadPageTafseer(activeId);
    }
  }

  Future<void> _downloadPageTafseer(String sourceId) async {
    if (_isDownloadingPageTafseer) return;
    setState(() {
      _isDownloadingPageTafseer = true;
      _pageTafseerDownloadProgress = 0.03;
    });

    final service = ref.read(tafseerServiceProvider);
    final ok = await service.downloadSource(
      sourceId,
      onProgress: (p) {
        if (mounted) {
          setState(() => _pageTafseerDownloadProgress = p);
        }
      },
    );

    if (!mounted) return;
    setState(() => _isDownloadingPageTafseer = false);
    if (ok) {
      await _loadPageTafseerData();
    }
  }

  Future<void> _loadExtendedMealData() async {
    if (widget.effectiveMode == MushafReadingMode.mushaf) return;

    final mealService = ref.read(mealServiceProvider);
    final activeMealId = ref.read(activeMealSourceProvider);
    final isComparing = ref.read(isMealComparisonEnabledProvider);
    final compareIds = ref.read(comparisonMealSourcesProvider);
    final showTranslit = ref.read(showTransliterationProvider);

    final Map<String, String> nextCustomMeals = {};
    final Map<String, List<MealComparisonEntry>> nextComparative = {};
    final Map<String, String> nextTranslit = {};

    for (final ayat in widget.pageData.quranAyats) {
      final key = '${ayat.sureId}:${ayat.ayetId}';
      final builtInMeal = widget.pageData.mealAyats
          .cast<MealAyatModel?>()
          .firstWhere(
            (m) => m?.sureId == ayat.sureId && m?.ayetId == ayat.ayetId,
            orElse: () => null,
          )
          ?.ayetText;

      if (activeMealId != 'diyanet_vakfi_offline') {
        final txt = await mealService.getVerseMeal(
          ayat.sureId,
          ayat.ayetId,
          sourceId: activeMealId,
          fallbackDiyanetText: builtInMeal,
        );
        nextCustomMeals[key] = txt;
      } else if (builtInMeal != null) {
        nextCustomMeals[key] = builtInMeal;
      }

      if (isComparing) {
        final comp = await mealService.getComparativeMeals(
          ayat.sureId,
          ayat.ayetId,
          sourceIds: compareIds,
          defaultDiyanetText: builtInMeal,
        );
        nextComparative[key] = comp;
      }

      if (showTranslit) {
        final tr = await mealService.getTransliteration(
          ayat.sureId,
          ayat.ayetId,
        );
        if (tr != null && tr.isNotEmpty) {
          nextTranslit[key] = tr;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _customMealsByKey = nextCustomMeals;
      _comparativeMealsByKey = nextComparative;
      _translitByKey = nextTranslit;
    });
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _createRecognizer(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  static String mapStopCharacter(String char, String fontFamily) =>
      QuranWordHighlighter.mapStopCharacter(char, fontFamily);

  List<InlineSpan> _buildAyahWordSpans({
    required String rawText,
    required TextStyle baseStyle,
    required Color waqfColor,
    required String fontFamily,
    required GestureRecognizer? recognizer,
    required VoidCallback? onAyahTap,
    void Function(int wordOrder)? onWordTap,
    required bool highlightDivineWords,
    required bool isDark,
    required bool isAyahPlaying,
    int? activeWordOrder,
    int activeWordDurationMs = 500,
    double playbackSpeed = 1.0,
    int surahId = 0,
    int ayahId = 0,
  }) {
    final cleanedText = QuranWordHighlighter.cleanArabicText(rawText).trim();
    final words = cleanedText.isEmpty
        ? const <String>[]
        : cleanedText.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];
    final divineColor = QuranWordHighlighter.getDivineWordColor(isDark);
    final emeraldBg =
        isDark ? const Color(0xFF059669) : const Color(0xFF10B981);
    final isArrowTracking = ref.watch(
      settingsProvider.select((s) => s.wordTrackingMode == 'arrow'),
    );
    final isTvMode = ref.watch(isTvModeProvider);

    for (int wIdx = 0; wIdx < words.length; wIdx++) {
      final cleanWord = words[wIdx];
      if (cleanWord.isEmpty) continue;

      final cleanWordBuf = StringBuffer();
      final stops = <String>[];

      for (int cIdx = 0; cIdx < cleanWord.length; cIdx++) {
        final char = cleanWord[cIdx];
        if (_stopSigns.contains(char)) {
          stops.add(char);
        } else {
          cleanWordBuf.write(char);
        }
      }

      final pureWord = cleanWordBuf.toString();
      final wordOrder = wIdx + 1;
      final bool isWordActive = isAyahPlaying &&
          (activeWordOrder != null && activeWordOrder == wordOrder);
      final bool isDivine = highlightDivineWords &&
          QuranWordHighlighter.isDivineWord(pureWord);

      final VoidCallback? effectiveTap =
          onWordTap != null ? () => onWordTap(wordOrder) : onAyahTap;
      final GestureRecognizer? effectiveRecognizer = onWordTap != null
          ? _createRecognizer(() => onWordTap(wordOrder))
          : recognizer;

      TextStyle wordStyle;
      if (isWordActive) {
        if (isArrowTracking) {
          wordStyle = baseStyle.copyWith(
            color: QuranWordHighlighter.getDiyanetTrackingWordColor(isDark),
            shadows: QuranWordHighlighter.getDiyanetTrackingShadows(isDark),
            backgroundColor: Colors.transparent,
          );
        } else {
          wordStyle = baseStyle.copyWith(
            color: Colors.white,
            backgroundColor: emeraldBg,
          );
        }
      } else if (isDivine) {
        wordStyle = baseStyle.copyWith(
          color: divineColor,
        );
      } else {
        wordStyle = baseStyle;
      }

      if (pureWord.isNotEmpty) {
        if (isWordActive) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                key: _activeMushafWordKey,
                onTap: effectiveTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Text(
                      pureWord,
                      textDirection: TextDirection.rtl,
                      style: wordStyle.copyWith(
                        height: 1.0,
                        backgroundColor: isArrowTracking
                            ? Colors.transparent
                            : emeraldBg,
                      ),
                    ),
                    if (isArrowTracking)
                      Positioned(
                        bottom: isTvMode ? -13 : -8,
                        left: 0,
                        right: 0,
                        child: QuranWordTrackingPointer(
                          isDark: isDark,
                          height: isTvMode ? 12.5 : 8.0,
                          durationMs: activeWordDurationMs,
                          playbackSpeed: playbackSpeed,
                          isPlaying: isAyahPlaying,
                          wordIdentity: '${surahId}_${ayahId}_$wordOrder',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: pureWord,
              style: wordStyle,
              recognizer: effectiveRecognizer,
            ),
          );
        }
      }

      for (int sIdx = 0; sIdx < stops.length; sIdx++) {
        final stop = stops[sIdx];
        final mappedStop = mapStopCharacter(stop, fontFamily);
        final prefix = sIdx == 0 ? '\u200B' : '\u200A';
        spans.add(
          TextSpan(
            text: '$prefix$mappedStop',
            style: baseStyle.copyWith(
              color: waqfColor,
              fontWeight: FontWeight.normal,
            ),
            recognizer: effectiveRecognizer,
          ),
        );
      }

      if (wIdx < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return spans;
  }

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    // Listen to meal/comparison setting changes so page updates live
    ref.listen<String>(activeMealSourceProvider, (_, __) {
      _loadExtendedMealData();
    });
    ref.listen<bool>(isMealComparisonEnabledProvider, (_, __) {
      _loadExtendedMealData();
    });
    ref.listen<List<String>>(comparisonMealSourcesProvider, (_, __) {
      _loadExtendedMealData();
    });
    ref.listen<bool>(showTransliterationProvider, (_, __) {
      _loadExtendedMealData();
    });
    ref.listen<String>(activeTafseerSourceProvider, (_, __) {
      _loadPageTafseerData();
    });
    ref.listen<KuranAudioState>(kuranAudioNotifierProvider, (prev, next) {
      if (!next.isPlaying && !next.isLoading && next.currentWordOrder <= 0) {
        return;
      }
      if (prev?.currentWordOrder != next.currentWordOrder ||
          prev?.currentAyahId != next.currentAyahId ||
          prev?.currentSurahId != next.currentSurahId) {
        _scrollToActiveMushafWord();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTvMode = ref.watch(isTvModeProvider);
    final audioState = ref.watch(kuranAudioNotifierProvider);
    final audioNotifier = ref.read(kuranAudioNotifierProvider.notifier);
    final fontFamily = ref.watch(quranFontFamilyProvider);
    final rawBaseFontSize = ref.watch(quranFontSizeProvider);
    final rawLineHeight = ref.watch(quranLineHeightProvider);
    final totalArabicChars = widget.pageData.quranAyats.fold<int>(
      0,
      (sum, a) => sum + a.ayetText.length,
    );
    final double userFontScale = (rawBaseFontSize / 34.0).clamp(0.55, 2.2);
    final double tvOptimalBase = widget.pageData.pageNo <= 2
        ? 44.0
        : (totalArabicChars < 380
            ? 40.0
            : (totalArabicChars < 480
                ? 37.0
                : (totalArabicChars <= 610 ? 34.5 : 32.5)));
    final double baseFontSize = isTvMode
        ? (tvOptimalBase * userFontScale).clamp(20.0, 72.0)
        : rawBaseFontSize;
    final double userLineScale = (rawLineHeight / 2.0).clamp(0.65, 1.45);
    final double tvOptimalLineHeight = widget.pageData.pageNo <= 2
        ? 1.85
        : (totalArabicChars < 480 ? 1.72 : 1.66);
    final double lineHeight = isTvMode
        ? (tvOptimalLineHeight * userLineScale).clamp(1.25, 2.50)
        : rawLineHeight;
    final isActivePage = widget.isActivePage ??
        (widget.pageData.pageNo == ref.watch(currentMushafPageProvider));
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final activeMealId = ref.watch(activeMealSourceProvider);
    final activeMealInfo = MealService.getSourceInfo(activeMealId);
    final isComparing = ref.watch(isMealComparisonEnabledProvider);
    final mealLayoutStyle = ref.watch(mealLayoutStyleProvider);
    final kuranFonts = ref.watch(kuranFontSettingsProvider);

    final mode = widget.effectiveMode;

    // Warm Saman Kağıdı / Tahrir Parşömeni Palette
    final pageBg = isDark ? const Color(0xFF101317) : const Color(0xFFFBF7EE);
    final innerSheetBg =
        isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF6);
    final tezhipGold =
        isDark ? const Color(0xFFC5A358) : const Color(0xFFA67C2E);
    final primaryTextColor =
        isDark ? const Color(0xFFF4EFE6) : const Color(0xFF261E17);
    final secondaryTextColor =
        isDark ? const Color(0xFFA59E92) : const Color(0xFF6B5848);
    final headerFooterTextColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF8C5828);
    final waqfColor =
        isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);

    // Group ayats by Surah
    final List<List<QuranAyatModel>> surahGroups = [];
    int currentSureId = -1;
    List<QuranAyatModel> currentGroup = [];

    for (final ayat in widget.pageData.quranAyats) {
      if (ayat.sureId != currentSureId) {
        if (currentGroup.isNotEmpty) {
          surahGroups.add(currentGroup);
          currentGroup = [];
        }
        currentSureId = ayat.sureId;
      }
      currentGroup.add(ayat);
    }
    if (currentGroup.isNotEmpty) {
      surahGroups.add(currentGroup);
    }

    final isShortPage =
        widget.pageData.pageNo <= 2 || widget.pageData.quranAyats.length <= 7;

    final allAyats = widget.pageData.quranAyats;
    String topSurahVerseInfo = '${widget.pageData.mealSureLabel} Sûresi';
    if (allAyats.isNotEmpty) {
      final firstA = allAyats.first;
      final lastA = allAyats.last;
      if (firstA.sureId == lastA.sureId) {
        if (firstA.ayetId == lastA.ayetId) {
          topSurahVerseInfo =
              '${widget.pageData.mealSureLabel} • ${firstA.ayetId}. Âyet';
        } else {
          topSurahVerseInfo =
              '${widget.pageData.mealSureLabel} • ${firstA.ayetId}-${lastA.ayetId}. Âyetler';
        }
      } else {
        final startName =
            firstA.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel;
        final endName =
            lastA.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel;
        topSurahVerseInfo =
            '$startName (${firstA.ayetId}) – $endName (${lastA.ayetId})';
      }
    }

    return Container(
      color: pageBg,
      child: Column(
        children: [
          // Meâl veya Âyet+Meâl modundaysa üstte hızlı Meâl Seçici, Karşılaştırma ve Görünüm Çubuğu
          if (mode == MushafReadingMode.ayatAndMeal ||
              mode == MushafReadingMode.mealOnly)
            _buildMealControlToolbar(
              context: context,
              mode: mode,
              activeMealInfo: activeMealInfo,
              isComparing: isComparing,
              mealLayoutStyle: mealLayoutStyle,
              isDark: isDark,
              tezhipGold: tezhipGold,
              headerFooterTextColor: headerFooterTextColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            )
          else if (mode == MushafReadingMode.tafseer)
            _buildTafseerControlToolbar(
              context: context,
              isDark: isDark,
              tezhipGold: tezhipGold,
              headerFooterTextColor: headerFooterTextColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            ),

          // Ana Sayfa Gövdesi
          Expanded(
            child: mode == MushafReadingMode.tafseer
                ? _buildPageTafseerBody(
                    context: context,
                    isDark: isDark,
                    fontFamily: fontFamily,
                    arabicFontSize: baseFontSize,
                    mealFontSize: kuranFonts.mealFontSize,
                    tezhipGold: tezhipGold,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    headerFooterTextColor: headerFooterTextColor,
                  )
                : LayoutBuilder(
                    builder: (context, viewportConstraints) {
                      final isTvMushafFullFit =
                          isTvMode && mode == MushafReadingMode.mushaf;
                      final pageGroupsWidgets = surahGroups.map((group) {
                        final firstAyat = group.first;
                        final sureMeta = firstAyat.sure;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sûre Başlığı + Sûre Tanıtımı (mealInfo) + Besmele
                            if (firstAyat.ayetId == 1 && sureMeta != null) ...[
                              _buildSurahBanner(
                                sureMeta,
                                isDark,
                                fontFamily,
                                showMealInfoToggle:
                                    mode != MushafReadingMode.mushaf,
                              ),
                              if (mode != MushafReadingMode.mushaf &&
                                  (sureMeta.mealInfo ?? '').trim().isNotEmpty &&
                                  _expandedSurahInfoIds
                                      .contains(sureMeta.sureId))
                                _buildSurahIntroCard(
                                  sureMeta: sureMeta,
                                  isDark: isDark,
                                  tezhipGold: tezhipGold,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                              if (sureMeta.besmeleVisible &&
                                  sureMeta.sureId != 1 &&
                                  sureMeta.sureId != 9)
                                mode == MushafReadingMode.mealOnly
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Text(
                                          'Rahmân ve Rahîm olan Allah’ın adıyla',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                            color: headerFooterTextColor,
                                          ),
                                        ),
                                      )
                                    : _buildBesmele(isDark, fontFamily),
                              const SizedBox(height: 8),
                            ],

                            // 1) SADECE MEÂL MODU: Akıcı Kitap Görünümü (Tahrir Stili)
                            if (mode == MushafReadingMode.mealOnly &&
                                mealLayoutStyle == 'book' &&
                                !isComparing)
                              _buildFlowingBookMealGroup(
                                context: context,
                                group: group,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                headerFooterTextColor: headerFooterTextColor,
                                tezhipGold: tezhipGold,
                                mealFontSize: kuranFonts.mealFontSize,
                                audioNotifier: audioNotifier,
                              )
                            // 2) ÂYET + MEÂL VEYA DETAYLI MEÂL KART MODU
                            else if (mode != MushafReadingMode.mushaf)
                              ...group.map((ayat) {
                                return _buildVerseCardItem(
                                  context: context,
                                  ayat: ayat,
                                  showArabicVerse:
                                      mode == MushafReadingMode.ayatAndMeal,
                                  isDark: isDark,
                                  fontFamily: fontFamily,
                                  arabicFontSize: baseFontSize,
                                  mealFontSize: kuranFonts.mealFontSize,
                                  lineHeight: lineHeight,
                                  isBoldArabic: isBoldArabic,
                                  highlightDivineWords: highlightDivineWords,
                                  waqfColor: waqfColor,
                                  tezhipGold: tezhipGold,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  headerFooterTextColor:
                                      headerFooterTextColor,
                                  activeMealInfo: activeMealInfo,
                                  isComparing: isComparing,
                                  audioState: audioState,
                                  audioNotifier: audioNotifier,
                                );
                              })
                            // 3) KLASİK ARAPÇA MUSHAF MODU
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 4),
                                child: Text.rich(
                                  TextSpan(
                                    children: group.expand((ayat) {
                                      final isCurrentAyahPlaying =
                                          (audioState.isPlaying ||
                                                  audioState.isLoading ||
                                                  audioState.currentWordOrder >
                                                      0) &&
                                              audioState.currentSurahId ==
                                                  ayat.sureId &&
                                              audioState.currentAyahId ==
                                                  ayat.ayetId;

                                      final meal = widget.pageData.mealAyats
                                          .cast<MealAyatModel?>()
                                          .firstWhere(
                                            (m) =>
                                                m?.sureId == ayat.sureId &&
                                                m?.ayetId == ayat.ayetId,
                                            orElse: () => null,
                                          );

                                      void voidCallback() {
                                        if (widget.onAyahTapOverride != null) {
                                          widget.onAyahTapOverride!(
                                            ayat.sureId,
                                            ayat.ayetId,
                                          );
                                          return;
                                        }
                                        _showAyahActionMenu(
                                          context,
                                          ayat,
                                          meal,
                                          audioNotifier,
                                        );
                                      }
                                      final recognizer =
                                          _createRecognizer(voidCallback);

                                      final effectiveFontSize = isTvMode
                                          ? baseFontSize
                                          : (isShortPage
                                              ? (baseFontSize + 2.0)
                                              : baseFontSize);

                                      final secdeItem =
                                          TilavetSecdesiData.getSecdeForVerse(
                                        ayat.sureId,
                                        ayat.ayetId,
                                      );
                                      final isSecdeAyah = secdeItem != null;

                                      final isArrowTrackingMode = ref.watch(
                                        settingsProvider.select((s) =>
                                            s.wordTrackingMode == 'arrow'),
                                      );

                                      final baseAyatStyle = TextStyle(
                                        fontFamily: fontFamily,
                                        fontSize: effectiveFontSize,
                                        fontWeight: isBoldArabic
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isCurrentAyahPlaying
                                            ? (isDark
                                                ? const Color(0xFFF6F2EA)
                                                : const Color(0xFF1E1A16))
                                            : primaryTextColor,
                                        backgroundColor: (isCurrentAyahPlaying &&
                                                !isArrowTrackingMode)
                                            ? (isDark
                                                ? const Color(0xFF059669)
                                                    .withValues(alpha: 0.14)
                                                : const Color(0xFF10B981)
                                                    .withValues(alpha: 0.12))
                                            : (isSecdeAyah
                                                ? (isDark
                                                    ? const Color(0xFFB45309)
                                                        .withValues(alpha: 0.16)
                                                    : const Color(0xFFF59E0B)
                                                        .withValues(alpha: 0.12))
                                                : Colors.transparent),
                                        height: lineHeight,
                                        letterSpacing: -0.1,
                                      );

                                      final textSpans = _buildAyahWordSpans(
                                        rawText: ayat.ayetText,
                                        baseStyle: baseAyatStyle,
                                        waqfColor: isCurrentAyahPlaying
                                            ? AppColors.gold400
                                            : waqfColor,
                                        fontFamily: fontFamily,
                                        recognizer: recognizer,
                                        onAyahTap: voidCallback,
                                        onWordTap: widget.onWordTap != null
                                            ? (wordOrder) => widget.onWordTap!(
                                                  ayat.sureId,
                                                  ayat.ayetId,
                                                  wordOrder,
                                                )
                                            : null,
                                        highlightDivineWords:
                                            highlightDivineWords,
                                        isDark: isDark,
                                        isAyahPlaying: isCurrentAyahPlaying,
                                        activeWordOrder: isCurrentAyahPlaying
                                            ? audioState.currentWordOrder
                                            : null,
                                        activeWordDurationMs:
                                            audioState.activeWordDurationMs,
                                        playbackSpeed:
                                            audioState.playbackSpeed,
                                        surahId: ayat.sureId,
                                        ayahId: ayat.ayetId,
                                      );

                                      return [
                                        ...textSpans,
                                        const TextSpan(text: '\u200F '),
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: GestureDetector(
                                            onTap: voidCallback,
                                            child: ZikirceAyahStopMarker(
                                              number: ayat.ayetNumber,
                                              isDark: isDark,
                                              isHighlight:
                                                  isCurrentAyahPlaying,
                                              isSecde: isSecdeAyah,
                                              fontFamily: fontFamily,
                                              size: isTvMode
                                                  ? (effectiveFontSize * 1.05)
                                                      .clamp(24.0, 48.0)
                                                  : (effectiveFontSize * 1.15)
                                                      .clamp(24.0, 48.0),
                                            ),
                                          ),
                                        ),
                                        if (isSecdeAyah)
                                          WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: ZikirceSecdeInlineBadge(
                                              isDark: isDark,
                                              compact: true,
                                              label: 'سَجْدَة • Secde',
                                              onTap: () =>
                                                  TilavetSecdesiGuideSheet
                                                      .show(
                                                context,
                                                initialSecdeItem: secdeItem,
                                              ),
                                            ),
                                          ),
                                        const TextSpan(text: ' \u200F'),
                                      ];
                                    }).toList(),
                                  ),
                                  textAlign: isShortPage
                                      ? TextAlign.center
                                      : TextAlign.justify,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            const SizedBox(height: 6),
                          ],
                        );
                      }).toList();

                      final secdeOnPage = TilavetSecdesiData.getSecdeForPage(
                        widget.pageData.pageNo,
                      );
                      final mushafHeaderBar = Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isTvMode ? 5 : 7,
                        ),
                        margin: EdgeInsets.only(bottom: isTvMode ? 6 : 10),
                        decoration: BoxDecoration(
                          color: tezhipGold.withValues(
                            alpha: isDark ? 0.10 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: secdeOnPage != null
                                ? const Color(0xFFD97706)
                                    .withValues(alpha: 0.55)
                                : tezhipGold.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                topSurahVerseInfo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  color: headerFooterTextColor,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (secdeOnPage != null) ...[
                              const SizedBox(width: 6),
                              ZikirceSecdeInlineBadge(
                                isDark: isDark,
                                compact: true,
                                label:
                                    'Secde (${secdeOnPage.sureName} ${secdeOnPage.ayetId})',
                                onTap: () => TilavetSecdesiGuideSheet.show(
                                  context,
                                  initialSecdeItem: secdeOnPage,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              '${widget.pageData.cuzNo}. Cüz • S. ${widget.pageData.pageNo}',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color: headerFooterTextColor,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );

                      final minSheetHeight = (viewportConstraints.maxHeight -
                              (isTvMode ? 10.0 : 24.0))
                          .clamp(180.0, double.infinity);
                      final minInnerContentHeight =
                          (minSheetHeight - (isTvMode ? 54.0 : 68.0))
                              .clamp(120.0, double.infinity);

                      return SingleChildScrollView(
                        primary: isActivePage,
                        physics: const BouncingScrollPhysics(),
                        padding: isTvMushafFullFit
                            ? const EdgeInsets.fromLTRB(12, 4, 12, 6)
                            : const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              constraints: mode == MushafReadingMode.mushaf
                                  ? BoxConstraints(minHeight: minSheetHeight)
                                  : null,
                              decoration: mode == MushafReadingMode.mushaf
                                  ? BoxDecoration(
                                      color: innerSheetBg,
                                      borderRadius: BorderRadius.circular(
                                          isTvMode ? 18 : 20),
                                      border: Border.all(
                                        color:
                                            tezhipGold.withValues(alpha: 0.48),
                                        width: isTvMode ? 1.6 : 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: isDark ? 0.25 : 0.05),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    )
                                  : null,
                              padding: mode == MushafReadingMode.mushaf
                                  ? EdgeInsets.fromLTRB(
                                      isTvMode ? 22 : 14,
                                      isTvMode ? 10 : 12,
                                      isTvMode ? 22 : 14,
                                      isTvMode ? 12 : 16,
                                    )
                                  : EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (mode == MushafReadingMode.mushaf)
                                    mushafHeaderBar,
                                  if (mode == MushafReadingMode.mushaf)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: minInnerContentHeight,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: pageGroupsWidgets,
                                        ),
                                      ),
                                    )
                                  else
                                    ...pageGroupsWidgets,
                                ],
                              ),
                            ),
                            if (!isTvMode) const SizedBox(height: 86),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Alt Sayfa Numarası Şeridi (TV'de üst başlık ve Mushaf başlığı zaten sayfa bilgisini gösterir)
          if (!isTvMode)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15191F) : const Color(0xFFF3ECE0),
              border: Border(
                top: BorderSide(
                  color: tezhipGold.withValues(alpha: 0.45),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  width: 36,
                  color: tezhipGold.withValues(alpha: 0.45),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Sayfa ${widget.pageData.pageNo}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: headerFooterTextColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  width: 36,
                  color: tezhipGold.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Meâl & Âyet+Meâl modlarında üstteki kontrol çubuğu
  Widget _buildMealControlToolbar({
    required BuildContext context,
    required MushafReadingMode mode,
    required MealSourceInfo activeMealInfo,
    required bool isComparing,
    required String mealLayoutStyle,
    required bool isDark,
    required Color tezhipGold,
    required Color headerFooterTextColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final barBg = isDark ? const Color(0xFF161A20) : const Color(0xFFF4EDE0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          bottom: BorderSide(
            color: tezhipGold.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Aktif Meâl Seçici Butonu
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showQuickMealPickerSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tezhipGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: tezhipGold.withValues(alpha: 0.38)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 14,
                      color: headerFooterTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeMealInfo.shortTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: headerFooterTextColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Meâl Karşılaştırma Aç/Kapat
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(isMealComparisonEnabledProvider.notifier).state =
                    !isComparing;
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isComparing
                      ? headerFooterTextColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isComparing
                        ? headerFooterTextColor
                        : tezhipGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.compare_arrows_rounded,
                      size: 14,
                      color: isComparing ? Colors.white : secondaryTextColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isComparing ? 'Karşılaştırma Açık' : 'Meâl Karşılaştır',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isComparing ? Colors.white : secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sadece Meâl modundaysa: Kitap Modu vs Kart Modu seçici
            if (mode == MushafReadingMode.mealOnly && !isComparing) ...[
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.selectionClick();
                  final next = mealLayoutStyle == 'book' ? 'card' : 'book';
                  ref.read(mealLayoutStyleProvider.notifier).setStyle(next);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: mealLayoutStyle == 'book'
                        ? tezhipGold.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tezhipGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mealLayoutStyle == 'book'
                            ? Icons.auto_stories_rounded
                            : Icons.view_agenda_outlined,
                        size: 14,
                        color: headerFooterTextColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        mealLayoutStyle == 'book'
                            ? 'Akıcı Kitap Modu'
                            : 'Detaylı Kart Modu',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(width: 8),
            // İlk Âyetin Tefsirini Aç Butonu
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (widget.pageData.quranAyats.isNotEmpty) {
                  final firstAyat = widget.pageData.quranAyats.first;
                  final key = '${firstAyat.sureId}:${firstAyat.ayetId}';
                  final meal = _customMealsByKey[key] ??
                      widget.pageData.mealAyats
                          .cast<MealAyatModel?>()
                          .firstWhere(
                            (m) =>
                                m?.sureId == firstAyat.sureId &&
                                m?.ayetId == firstAyat.ayetId,
                            orElse: () => null,
                          )
                          ?.ayetText ??
                      '';
                  TafseerBottomSheet.show(
                    context,
                    ayat: firstAyat,
                    mealText: meal,
                    initialTab: 0,
                  );
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tezhipGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 14,
                      color: headerFooterTextColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tefsir Oku',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tefsir Okuma Modunda üstteki Tefsir Kaynağı Seçici Çubuğu
  Widget _buildTafseerControlToolbar({
    required BuildContext context,
    required bool isDark,
    required Color tezhipGold,
    required Color headerFooterTextColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final activeTafseerId = ref.watch(activeTafseerSourceProvider);
    final barBg = isDark ? const Color(0xFF161A20) : const Color(0xFFF4EDE0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          bottom: BorderSide(
            color: tezhipGold.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...TafseerService.availableSources.map((src) {
              final isSelected = src.id == activeTafseerId;
              final isDown = _downloadedTafseerIds.contains(src.id);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await ref
                        .read(activeTafseerSourceProvider.notifier)
                        .setSource(src.id);
                    await _loadPageTafseerData();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? headerFooterTextColor
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? headerFooterTextColor
                            : tezhipGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDown
                              ? Icons.check_circle_rounded
                              : Icons.cloud_download_outlined,
                          size: 13.5,
                          color: isSelected
                              ? Colors.white
                              : (isDown
                                  ? headerFooterTextColor
                                  : secondaryTextColor),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          src.shortTitle,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await TafseerLibraryManagerSheet.show(context);
                await _loadPageTafseerData();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tezhipGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: headerFooterTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Yönet',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sayfa Bazlı Gerçek Tefsir Okuma Gövdesi (MushafReadingMode.tafseer)
  Widget _buildPageTafseerBody({
    required BuildContext context,
    required bool isDark,
    required String fontFamily,
    required double arabicFontSize,
    required double mealFontSize,
    required Color tezhipGold,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color headerFooterTextColor,
  }) {
    final activeId = ref.watch(activeTafseerSourceProvider);
    final activeSource = TafseerService.getSourceInfo(activeId);
    final cardBg = isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF6);

    if (_isLoadingPageTafseer || _isDownloadingPageTafseer) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tezhipGold.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: _isDownloadingPageTafseer &&
                          _pageTafseerDownloadProgress > 0
                      ? _pageTafseerDownloadProgress
                      : null,
                  color: headerFooterTextColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _isDownloadingPageTafseer
                      ? '${activeSource.title} İndiriliyor... %${(_pageTafseerDownloadProgress * 100).toInt()}'
                      : '${activeSource.shortTitle} Yükleniyor...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${activeSource.author} • Bir kez indirildiğinde tamamen çevrimdışı çalışır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCurrentTafseerDownloaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tezhipGold.withValues(alpha: 0.38)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 36,
                  color: headerFooterTextColor,
                ),
                const SizedBox(height: 12),
                Text(
                  activeSource.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activeSource.author} • ${activeSource.sizeLabel}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: headerFooterTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  activeSource.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerFooterTextColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _downloadPageTafseer(activeSource.id),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      '${activeSource.shortTitle} Paketini İndir ve Oku (${activeSource.sizeLabel})',
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
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
      itemCount: _pageTafseerEntries.length,
      itemBuilder: (context, index) {
        final entry = _pageTafseerEntries[index];
        final paragraphs = entry.tefsirText
            .split(RegExp(r'\n+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        // Find matching Arabic verses on this page for this tafseer entry
        final matchingAyats = widget.pageData.quranAyats
            .where((a) =>
                a.sureId == entry.surahId &&
                a.ayetId >= entry.startVerse &&
                a.ayetId <= entry.endVerse)
            .toList();
        TilavetSecdeItem? tafseerSecdeItem;
        for (final a in matchingAyats) {
          final found = TilavetSecdesiData.getSecdeForVerse(a.sureId, a.ayetId);
          if (found != null) {
            tafseerSecdeItem = found;
            break;
          }
        }
        final combinedArabic = matchingAyats
            .map((a) =>
                '${QuranWordHighlighter.cleanArabicText(a.ayetText)} ﴿${a.ayetId}﴾')
            .join(' ');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tafseerSecdeItem != null
                  ? const Color(0xFFD97706).withValues(alpha: 0.65)
                  : tezhipGold.withValues(alpha: 0.32),
              width: tafseerSecdeItem != null ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık Şeridi
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tezhipGold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: headerFooterTextColor,
                      ),
                    ),
                  ),
                  if (tafseerSecdeItem != null) ...[
                    const SizedBox(width: 6),
                    ZikirceSecdeInlineBadge(
                      isDark: isDark,
                      compact: true,
                      label: '${tafseerSecdeItem.no}. Secde Âyeti',
                      onTap: () => TilavetSecdesiGuideSheet.show(
                        context,
                        initialSecdeItem: tafseerSecdeItem,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.source.shortTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
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
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 17,
                      color: headerFooterTextColor,
                    ),
                  ),
                ],
              ),

              if (combinedArabic.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  combinedArabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: arabicFontSize,
                    height: 1.82,
                    color: primaryTextColor,
                  ),
                ),
              ],

              if (entry.mealText.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tezhipGold.withValues(alpha: isDark ? 0.08 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.mealText.trim(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: mealFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: tezhipGold.withValues(alpha: 0.22),
              ),
              const SizedBox(height: 14),

              for (final para in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText(
                    para,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: mealFontSize + 0.5,
                      height: 1.72,
                      color: primaryTextColor.withValues(alpha: 0.93),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Tahrir Stili Akıcı Kitap Okuma Modu (Her âyeti kutuya almadan, samimi kitap sayfası akışı)
  Widget _buildFlowingBookMealGroup({
    required BuildContext context,
    required List<QuranAyatModel> group,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color headerFooterTextColor,
    required Color tezhipGold,
    required double mealFontSize,
    required KuranAudioNotifier audioNotifier,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tezhipGold.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: group.expand((ayat) {
                final key = '${ayat.sureId}:${ayat.ayetId}';
                final builtIn = widget.pageData.mealAyats
                    .cast<MealAyatModel?>()
                    .firstWhere(
                      (m) =>
                          m?.sureId == ayat.sureId && m?.ayetId == ayat.ayetId,
                      orElse: () => null,
                    );
                final mealText =
                    _customMealsByKey[key] ?? builtIn?.ayetText ?? '';

                void onVerseTap() {
                  _showAyahActionMenu(context, ayat, builtIn, audioNotifier);
                }

                final recognizer = _createRecognizer(onVerseTap);
                final secdeItem = TilavetSecdesiData.getSecdeForVerse(
                  ayat.sureId,
                  ayat.ayetId,
                );
                final isSecdeAyah = secdeItem != null;
                final secdeBg = isSecdeAyah
                    ? (isDark
                        ? const Color(0xFFB45309).withValues(alpha: 0.18)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.14))
                    : null;

                return [
                  TextSpan(
                    text: '(${ayat.ayetId}) ',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: mealFontSize - 2.0,
                      fontWeight: FontWeight.w800,
                      color: isSecdeAyah
                          ? (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFB45309))
                          : headerFooterTextColor,
                      backgroundColor: secdeBg,
                    ),
                    recognizer: recognizer,
                  ),
                  TextSpan(
                    text: '$mealText ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: mealFontSize + 0.5,
                      height: 1.78,
                      color: primaryTextColor,
                      backgroundColor: secdeBg,
                    ),
                    recognizer: recognizer,
                  ),
                  if (isSecdeAyah)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: ZikirceSecdeInlineBadge(
                        isDark: isDark,
                        compact: true,
                        label: '${secdeItem.no}. Secde Âyeti',
                        onTap: () => TilavetSecdesiGuideSheet.show(
                          context,
                          initialSecdeItem: secdeItem,
                        ),
                      ),
                    ),
                  const TextSpan(text: ' '),
                ];
              }).toList(),
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 10),
          Text(
            'İpucu: Herhangi bir âyetin tefsirini, meâl karşılaştırmasını veya paylaşım kartını açmak için âyet metnine dokunun.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: secondaryTextColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  /// Âyet + Meâl veya Detaylı Meâl Kartı
  Widget _buildVerseCardItem({
    required BuildContext context,
    required QuranAyatModel ayat,
    required bool showArabicVerse,
    required bool isDark,
    required String fontFamily,
    required double arabicFontSize,
    required double mealFontSize,
    required double lineHeight,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required Color waqfColor,
    required Color tezhipGold,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color headerFooterTextColor,
    required MealSourceInfo activeMealInfo,
    required bool isComparing,
    required KuranAudioState audioState,
    required KuranAudioNotifier audioNotifier,
  }) {
    final isCurrentAyahPlaying = audioState.isPlaying &&
        audioState.currentSurahId == ayat.sureId &&
        audioState.currentAyahId == ayat.ayetId;

    final builtInMeal = widget.pageData.mealAyats
        .cast<MealAyatModel?>()
        .firstWhere(
          (m) => m?.sureId == ayat.sureId && m?.ayetId == ayat.ayetId,
          orElse: () => null,
        );
    final key = '${ayat.sureId}:${ayat.ayetId}';
    final mealText = _customMealsByKey[key] ?? builtInMeal?.ayetText ?? '';
    final translitText = _translitByKey[key];
    final compEntries = _comparativeMealsByKey[key] ?? const [];
    final surahTitle =
        ayat.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel;
    final secdeItem = TilavetSecdesiData.getSecdeForVerse(
      ayat.sureId,
      ayat.ayetId,
    );
    final isSecdeAyah = secdeItem != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isCurrentAyahPlaying
            ? (isDark ? const Color(0xFF1A2823) : const Color(0xFFEAF5F0))
            : (isSecdeAyah
                ? (isDark ? const Color(0xFF1F1914) : const Color(0xFFFFFBEB))
                : (isDark ? const Color(0xFF15191F) : const Color(0xFFFFFDF8))),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentAyahPlaying
              ? AppColors.emerald500
              : (isSecdeAyah
                  ? const Color(0xFFD97706).withValues(alpha: 0.65)
                  : tezhipGold.withValues(alpha: 0.25)),
          width: isCurrentAyahPlaying || isSecdeAyah ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst satır: Sûre & Âyet etiketi + Hızlı Aksiyonlar (Dinle, Tefsir, Karşılaştır, Paylaş)
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tezhipGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$surahTitle • ${ayat.ayetId}. Âyet',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: headerFooterTextColor,
                  ),
                ),
              ),
              if (isSecdeAyah) ...[
                const SizedBox(width: 6),
                ZikirceSecdeInlineBadge(
                  isDark: isDark,
                  compact: true,
                  label: '${secdeItem.no}. Secde Âyeti',
                  onTap: () => TilavetSecdesiGuideSheet.show(
                    context,
                    initialSecdeItem: secdeItem,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(
                  isCurrentAyahPlaying
                      ? Icons.volume_up_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 20,
                  color: isCurrentAyahPlaying
                      ? AppColors.emerald500
                      : headerFooterTextColor,
                ),
                tooltip: 'Âyeti Dinle',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  audioNotifier.playVerse(
                    ayat.sureId,
                    ayat.ayetId,
                    pageId: widget.pageData.pageNo,
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.compare_arrows_rounded,
                  size: 19,
                  color: headerFooterTextColor,
                ),
                tooltip: 'Meâlleri Karşılaştır',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  TafseerBottomSheet.show(
                    context,
                    ayat: ayat,
                    mealText: mealText,
                    initialTab: 1,
                  );
                },
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  TafseerBottomSheet.show(
                    context,
                    ayat: ayat,
                    mealText: mealText,
                    initialTab: 0,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tezhipGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: headerFooterTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tefsir',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: headerFooterTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: headerFooterTextColor,
                ),
                tooltip: 'Paylaşım Kartı Oluştur',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  ZikirSharePreviewModal.show(
                    context: context,
                    zikirName: '$surahTitle Sûresi, ${ayat.ayetId}. Âyet',
                    arabicText:
                        QuranWordHighlighter.cleanArabicText(ayat.ayetText),
                    virtue: mealText.isNotEmpty ? mealText : ayat.ayetText,
                    customSource: '$surahTitle Sûresi, ${ayat.ayetId}. Âyet',
                    category: 'Kur’an',
                    currentCount: widget.pageData.pageNo,
                    targetCount: 604,
                    totalCount: widget.pageData.pageNo,
                    initialTheme: ZikirShareCardTheme.fajrDawn,
                    initialShowCounterStats: false,
                  );
                },
              ),
            ],
          ),

          // Arapça Âyet Metni (Âyet + Meâl modundaysa)
          if (showArabicVerse) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  ..._buildAyahWordSpans(
                    rawText: ayat.ayetText,
                    baseStyle: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: arabicFontSize,
                      fontWeight:
                          isBoldArabic ? FontWeight.bold : FontWeight.normal,
                      color: primaryTextColor,
                      height: lineHeight,
                    ),
                    waqfColor: waqfColor,
                    fontFamily: fontFamily,
                    recognizer: null,
                    onAyahTap: null,
                    highlightDivineWords: highlightDivineWords,
                    isDark: isDark,
                    isAyahPlaying: isCurrentAyahPlaying,
                    activeWordOrder:
                        isCurrentAyahPlaying ? audioState.currentWordOrder : null,
                    activeWordDurationMs: audioState.activeWordDurationMs,
                    playbackSpeed: audioState.playbackSpeed,
                    surahId: ayat.sureId,
                    ayahId: ayat.ayetId,
                  ),
                  const TextSpan(text: '\u200F '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: ZikirceAyahStopMarker(
                      number: ayat.ayetNumber,
                      isDark: isDark,
                      isHighlight: isCurrentAyahPlaying,
                      isSecde: isSecdeAyah,
                      fontFamily: fontFamily,
                      size: (arabicFontSize * 1.1).clamp(24.0, 38.0),
                    ),
                  ),
                  if (isSecdeAyah)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: ZikirceSecdeInlineBadge(
                        isDark: isDark,
                        compact: true,
                        label: 'سَجْدَة',
                        onTap: () => TilavetSecdesiGuideSheet.show(
                          context,
                          initialSecdeItem: secdeItem,
                        ),
                      ),
                    ),
                ],
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: tezhipGold.withValues(alpha: 0.18),
            ),
          ],

          // Türkçe Okunuş (Transkripsiyon) açıksa
          if (translitText != null && translitText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              translitText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: mealFontSize - 1.0,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: headerFooterTextColor,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Karşılaştırma Modu Açıksa Tüm Seçili Meâlleri Alt Alta Göster
          if (isComparing && compEntries.isNotEmpty)
            ...compEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.source.shortTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: headerFooterTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: mealFontSize,
                        height: 1.58,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
              );
            })
          else ...[
            if (activeMealInfo.id != 'diyanet_vakfi_offline')
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  activeMealInfo.shortTitle,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            Text(
              mealText.isNotEmpty
                  ? mealText
                  : 'Bu âyet için meâl metni yükleniyor...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: mealFontSize,
                height: 1.62,
                color: primaryTextColor,
                fontWeight:
                    isCurrentAyahPlaying ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Sûre Tanıtımı / Özeti (SureMeta.mealInfo) Kartı
  Widget _buildSurahIntroCard({
    required SureMeta sureMeta,
    required bool isDark,
    required Color tezhipGold,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final cleanInfo = _stripHtmlTags(sureMeta.mealInfo ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181D24) : const Color(0xFFF6EFE0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tezhipGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: tezhipGold),
              const SizedBox(width: 6),
              Text(
                '${sureMeta.sureNameTurkish} Sûresi Hakkında Bilgi',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cleanInfo,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.58,
              color: primaryTextColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickMealPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF15191C) : const Color(0xFFFDFBF7);
    final textColor =
        isDark ? const Color(0xFFF1ECE1) : const Color(0xFF2B2118);
    final subColor =
        isDark ? const Color(0xFFA59E92) : const Color(0xFF6B5848);
    final accentColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFFA64B2A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, sheetRef, _) {
            final activeId = sheetRef.watch(activeMealSourceProvider);
            final showTranslit = sheetRef.watch(showTransliterationProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.translate_rounded, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Meâl Kaynağı ve Okunuş Seçimi',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: accentColor,
                      title: Text(
                        'Türkçe Okunuş (Latin Transkripsiyon)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        'Âyetlerin altında Latin harfli okunuşunu göster',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: subColor,
                        ),
                      ),
                      value: showTranslit,
                      onChanged: (val) {
                        sheetRef
                            .read(showTransliterationProvider.notifier)
                            .toggle(val);
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: MealService.availableSources.map((src) {
                          final selected = src.id == activeId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: selected ? accentColor : subColor,
                            ),
                            title: Text(
                              src.title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              src.author,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                            trailing: Text(
                              src.sizeLabel,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await ref
                                  .read(activeMealSourceProvider.notifier)
                                  .setSource(src.id);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // SURAH HEADER BANNER (ILLUMINATED LEVHA)
  // ==========================================
  Widget _buildSurahBanner(
    SureMeta sure,
    bool isDark,
    String fontFamily, {
    bool showMealInfoToggle = false,
  }) {
    final bannerBg = isDark
        ? const LinearGradient(
            colors: [Color(0xFF15191E), Color(0xFF1F2630), Color(0xFF15191E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFAF5EC), Color(0xFFF1E7D8), Color(0xFFFAF5EC)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

    final borderColor = isDark
        ? const Color(0xFFC5A358).withValues(alpha: 0.65)
        : const Color(0xFFB58D3D).withValues(alpha: 0.65);

    final innerBorderColor = isDark
        ? const Color(0xFFC5A358).withValues(alpha: 0.25)
        : const Color(0xFFB58D3D).withValues(alpha: 0.3);

    final titleColor =
        isDark ? const Color(0xFFF3ECE0) : const Color(0xFF4A3410);
    final subtitleColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF8C6928);
    final arabicTitleColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFF6B4808);
    final goldAccent =
        isDark ? const Color(0xFFC5A358) : const Color(0xFFB58D3D);
    final hasIntro =
        showMealInfoToggle && (sure.mealInfo ?? '').trim().isNotEmpty;
    final isExpanded = _expandedSurahInfoIds.contains(sure.sureId);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        gradient: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: innerBorderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '۞',
                        style: TextStyle(
                          color: goldAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${sure.sureNameTurkish} Sûresi',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Text(
                          '${sure.ayetCount} Âyet • Cüz ${sure.cuz}',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasIntro) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedSurahInfoIds.remove(sure.sureId);
                                } else {
                                  _expandedSurahInfoIds.add(sure.sureId);
                                }
                              });
                            },
                            child: Text(
                              isExpanded ? 'Özeti Gizle ▲' : 'Sûre Özeti ▼',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sure.sureNameArabic,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: arabicTitleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '۞',
                  style: TextStyle(
                    color: goldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBesmele(bool isDark, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 22,
            color: isDark ? AppColors.gold400 : const Color(0xFF83590E),
            height: 1.8,
          ),
        ),
      ),
    );
  }

  void _showAyahActionMenu(
    BuildContext context,
    QuranAyatModel ayat,
    MealAyatModel? meal,
    KuranAudioNotifier audioNotifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF14171C) : const Color(0xFFFAF7F0);
    final cardBg = isDark ? const Color(0xFF0F1216) : const Color(0xFFFFFFFF);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B1917);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);
    final surahTitle = ayat.sure?.sureNameTurkish ?? 'Sûre';
    final key = '${ayat.sureId}:${ayat.ayetId}';
    final resolvedMeal = _customMealsByKey[key] ?? meal?.ayetText ?? '';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: borderColor, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Text(
                '$surahTitle Sûresi • ${ayat.ayetId}. Âyet',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              if (resolvedMeal.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  resolvedMeal,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    height: 1.45,
                    color: titleColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    if (TilavetSecdesiData.isSecdeVerse(
                        ayat.sureId, ayat.ayetId)) ...[
                      Builder(
                        builder: (_) {
                          final secdeItem =
                              TilavetSecdesiData.getSecdeForVerse(
                                  ayat.sureId, ayat.ayetId)!;
                          return ListTile(
                            leading: const Text(
                              '🕌',
                              style: TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              'Tilâvet Secdesi Rehberi (${secdeItem.no}. Secde Âyeti)',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFB45309),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Bu âyet tilâvet secdesi âyetidir (Vâcip). Secde rehberini ve takibini aç.',
                              style: TextStyle(
                                color: titleColor.withValues(alpha: 0.65),
                                fontSize: 11.5,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              TilavetSecdesiGuideSheet.show(
                                context,
                                initialSecdeItem: secdeItem,
                              );
                            },
                          );
                        },
                      ),
                      Divider(height: 1, color: borderColor),
                    ],
                    ListTile(
                      leading: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.gold500,
                        size: 28,
                      ),
                      title: Text(
                        'Âyeti Dinle (Kelime Takipli Ses)',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        audioNotifier.playVerse(
                          ayat.sureId,
                          ayat.ayetId,
                          pageId: widget.pageData.pageNo,
                        );
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      leading: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.emerald500,
                        size: 25,
                      ),
                      title: Text(
                        'Tefsir Kütüphanesinden Oku',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Diyanet Kur’ân Yolu, Beyzâvî, Mâtürîdî, Keşşâf, Râzî, İbn Kesîr',
                        style: TextStyle(
                          color: titleColor.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        TafseerBottomSheet.show(
                          context,
                          ayat: ayat,
                          mealText: resolvedMeal,
                          initialTab: 0,
                        );
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      leading: const Icon(
                        Icons.compare_arrows_rounded,
                        color: AppColors.gold500,
                        size: 25,
                      ),
                      title: Text(
                        'Farklı Meâllerle Karşılaştır',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Diyanet, Elmalılı, Çantay, Diyanet Vakfı, Ali Fikri Yavuz + Okunuş',
                        style: TextStyle(
                          color: titleColor.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        TafseerBottomSheet.show(
                          context,
                          ayat: ayat,
                          mealText: resolvedMeal,
                          initialTab: 1,
                        );
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      leading: const Icon(
                        Icons.ios_share_rounded,
                        color: AppColors.emerald500,
                        size: 24,
                      ),
                      title: Text(
                        'Paylaşım Kartı Oluştur',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Tahrir parşömen estetiğinde minimalist âyet kartı paylaş',
                        style: TextStyle(
                          color: titleColor.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ZikirSharePreviewModal.show(
                          context: context,
                          zikirName: '$surahTitle Sûresi, ${ayat.ayetId}. Âyet',
                          arabicText: QuranWordHighlighter.cleanArabicText(
                              ayat.ayetText),
                          virtue: resolvedMeal.isNotEmpty
                              ? resolvedMeal
                              : ayat.ayetText,
                          customSource:
                              '$surahTitle Sûresi, ${ayat.ayetId}. Âyet',
                          category: 'Kur’an',
                          currentCount: widget.pageData.pageNo,
                          targetCount: 604,
                          totalCount: widget.pageData.pageNo,
                          initialTheme: ZikirShareCardTheme.fajrDawn,
                          initialShowCounterStats: false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// TV Kumandası (D-Pad) ve Dokunmatik Uyumlu Gelişmiş Hat, Boyut ve Okuma Ayarları Modalı
class QuranReadingSettingsModal {
  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    VoidCallback? onOpenTafseerReader,
  }) async {
    final bgColor = isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF7);
    final cardBg = isDark ? const Color(0xFF1E242C) : const Color(0xFFF5EFE2);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final subColor = isDark ? const Color(0xFF9EA6B2) : const Color(0xFF6B5848);
    final accentColor = isDark ? AppColors.gold400 : const Color(0xFF1E6F5C);
    final goldBorder = isDark ? const Color(0xFFC5A358) : const Color(0xFFA67C2E);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, sheetRef, _) {
            final isTv = sheetRef.watch(isTvModeProvider);
            final arSize = sheetRef.watch(quranFontSizeProvider);
            final fontFamily = sheetRef.watch(quranFontFamilyProvider);
            final lineHeight = sheetRef.watch(quranLineHeightProvider);
            final isBoldArabic = sheetRef.watch(isBoldArabicProvider);
            final highlightDivine = sheetRef.watch(highlightDivineWordsProvider);
            final kuranFonts = sheetRef.watch(kuranFontSettingsProvider);
            final activeMealId = sheetRef.watch(activeMealSourceProvider);
            final activeMealInfo = MealService.getSourceInfo(activeMealId);
            final isComparing = sheetRef.watch(isMealComparisonEnabledProvider);
            final showTranslit = sheetRef.watch(showTransliterationProvider);

            void setArabicSize(double newSize) {
              final clamped = newSize.clamp(20.0, 64.0);
              sheetRef.read(quranFontSizeProvider.notifier).setFontSize(clamped);
              sheetRef
                  .read(kuranFontSettingsProvider.notifier)
                  .setArabicFontSize(clamped);
            }

            void setArabicLineHeight(double newLh) {
              final clamped = newLh.clamp(1.3, 2.5);
              sheetRef
                  .read(quranLineHeightProvider.notifier)
                  .setLineHeight(clamped);
              sheetRef
                  .read(kuranFontSettingsProvider.notifier)
                  .setLineHeight(clamped);
            }

            const presets = <({String label, double size, String subtitle})>[
              (label: 'Tam Ekran', size: 34.0, subtitle: '34 pt • Dengeli'),
              (label: 'Büyük Hat', size: 40.0, subtitle: '40 pt • Rahat'),
              (label: 'Çok Büyük', size: 48.0, subtitle: '48 pt • Geniş'),
              (label: 'Dev TV', size: 56.0, subtitle: '56 pt • Uzak Mesafe'),
            ];

            const fontFamilies = <({String id, String title, String subtitle})>[
              (
                id: 'AmasyaAbay',
                title: 'Amasya Abay',
                subtitle: 'Diyanet Nesih Hattı'
              ),
              (
                id: 'mushaf',
                title: 'Klasik Mushaf',
                subtitle: 'Medine Mushaf Hattı'
              ),
              (
                id: 'mushaf_bold',
                title: 'Kalın Mushaf',
                subtitle: 'TV İçin Tok Hat'
              ),
            ];

            return Dialog(
              backgroundColor: bgColor,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isTv ? 56 : 16,
                vertical: isTv ? 22 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: goldBorder.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst Başlık & Sıfırla / Kapat Butonları
                      Row(
                        children: [
                          Icon(Icons.text_fields_rounded,
                              color: accentColor, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kur’ân-ı Kerîm Hat, Boyut & Görünüm Ayarları',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: isTv ? 19 : 17,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                          ),
                          TvFocusable(
                            borderRadius: 12,
                            onPressed: () {
                              setArabicSize(34.0);
                              setArabicLineHeight(2.0);
                              sheetRef
                                  .read(quranFontFamilyProvider.notifier)
                                  .setFont('AmasyaAbay');
                              sheetRef
                                  .read(kuranFontSettingsProvider.notifier)
                                  .setMealFontSize(18.0);
                              if (isBoldArabic) {
                                sheetRef
                                    .read(userSettingsProvider.notifier)
                                    .toggleBoldArabic(false);
                              }
                            },
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Text(
                              '↺ Varsayılan',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TvFocusable(
                            borderRadius: 12,
                            onPressed: () => Navigator.of(ctx).pop(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Text(
                              '✕ Kapat',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: subColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Canlı Önizleme Kutusu (Arapça Hat + Türkçe Meâl)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101317)
                              : const Color(0xFFFBF7EE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: goldBorder.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ﴿١﴾',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: arSize.clamp(22.0, 48.0),
                                fontWeight: isBoldArabic
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                height: (lineHeight * 0.75).clamp(1.2, 1.8),
                                color: highlightDivine
                                    ? (isDark
                                        ? const Color(0xFFFFD56B)
                                        : const Color(0xFF1E2B27))
                                    : textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rahmân ve Rahîm olan Allah’ın adıyla. (${arSize.toInt()} pt • $fontFamily)',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    kuranFonts.mealFontSize.clamp(13.0, 22.0),
                                color: subColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Kaydırılabilir Ayar Gövdesi
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Hızlı Boyut Şablonları (Kumanda ile Tek Tuşla Seçim)
                              Text(
                                'Hızlı Hat Boyutu Seçimi',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: subColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (int i = 0; i < presets.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: TvFocusable(
                                        autofocus: i == 0,
                                        borderRadius: 14,
                                        onPressed: () =>
                                            setArabicSize(presets[i].size),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: (arSize - presets[i].size)
                                                        .abs() <
                                                    1.5
                                                ? accentColor
                                                : cardBg,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: (arSize - presets[i].size)
                                                          .abs() <
                                                      1.5
                                                  ? goldBorder
                                                  : Colors.transparent,
                                              width: 1.4,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                presets[i].label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: (arSize -
                                                                  presets[i]
                                                                      .size)
                                                              .abs() <
                                                          1.5
                                                      ? (isDark
                                                          ? Colors.black
                                                          : Colors.white)
                                                      : textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                presets[i].subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: (arSize -
                                                                  presets[i]
                                                                      .size)
                                                              .abs() <
                                                          1.5
                                                      ? (isDark
                                                          ? Colors.black87
                                                          : Colors.white70)
                                                      : subColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 2. Hassas Arapça Hat Boyutu (- / + Kumanda Butonları & Slider)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Arapça Hat Boyutu: ${arSize.toInt()} pt',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () =>
                                              setArabicSize(arSize - 2.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: goldBorder.withValues(
                                                      alpha: 0.45)),
                                            ),
                                            child: Text(
                                              '− Küçült',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () =>
                                              setArabicSize(arSize + 2.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '+ Büyüt',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!isTv)
                                      Slider(
                                        value: arSize.clamp(20.0, 64.0),
                                        min: 20.0,
                                        max: 64.0,
                                        activeColor: accentColor,
                                        onChanged: setArabicSize,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 3. Arapça Yazı Tipi (Font Family) Seçimi
                              Text(
                                'Arapça Hat Yazı Tipi (Kaligrafi)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: subColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (int i = 0;
                                      i < fontFamilies.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: TvFocusable(
                                        borderRadius: 14,
                                        onPressed: () {
                                          sheetRef
                                              .read(quranFontFamilyProvider
                                                  .notifier)
                                              .setFont(
                                                  fontFamilies[i].id);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: fontFamily ==
                                                    fontFamilies[i].id
                                                ? accentColor
                                                : cardBg,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: fontFamily ==
                                                      fontFamilies[i].id
                                                  ? goldBorder
                                                  : Colors.transparent,
                                              width: 1.4,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                fontFamilies[i].title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: fontFamily ==
                                                          fontFamilies[i].id
                                                      ? (isDark
                                                          ? Colors.black
                                                          : Colors.white)
                                                      : textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                fontFamilies[i].subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: fontFamily ==
                                                          fontFamilies[i].id
                                                      ? (isDark
                                                          ? Colors.black87
                                                          : Colors.white70)
                                                      : subColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 4. Satır Aralığı, Kalın Hat & Türkçe Meâl Boyutu
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    // Satır Aralığı
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Satır Aralığı: ${lineHeight.toStringAsFixed(1)}x',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () => setArabicLineHeight(
                                              lineHeight - 0.1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: goldBorder.withValues(
                                                      alpha: 0.45)),
                                            ),
                                            child: Text(
                                              '− Daralt',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () => setArabicLineHeight(
                                              lineHeight + 0.1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: goldBorder.withValues(
                                                      alpha: 0.45)),
                                            ),
                                            child: Text(
                                              '+ Genişlet',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Türkçe Meâl Boyutu
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Türkçe Meâl Yazı Boyutu: ${kuranFonts.mealFontSize.toInt()} pt',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () {
                                            sheetRef
                                                .read(kuranFontSettingsProvider
                                                    .notifier)
                                                .setMealFontSize(
                                                    kuranFonts.mealFontSize -
                                                        1.0);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: goldBorder.withValues(
                                                      alpha: 0.45)),
                                            ),
                                            child: Text(
                                              '− Küçült',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TvFocusable(
                                          borderRadius: 10,
                                          onPressed: () {
                                            sheetRef
                                                .read(kuranFontSettingsProvider
                                                    .notifier)
                                                .setMealFontSize(
                                                    kuranFonts.mealFontSize +
                                                        1.0);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: goldBorder.withValues(
                                                      alpha: 0.45)),
                                            ),
                                            child: Text(
                                              '+ Büyüt',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 5. Kalın Hat, Lafzatullah, Meâl Karşılaştırma ve Okunuş Anahtarları
                              Row(
                                children: [
                                  Expanded(
                                    child: TvFocusable(
                                      borderRadius: 14,
                                      onPressed: () {
                                        sheetRef
                                            .read(userSettingsProvider.notifier)
                                            .toggleBoldArabic(!isBoldArabic);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isBoldArabic
                                              ? accentColor
                                              : cardBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          isBoldArabic
                                              ? '✓ Kalın Arapça Hat: Açık'
                                              : 'Kalın Arapça Hat: Kapalı',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: isBoldArabic
                                                ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TvFocusable(
                                      borderRadius: 14,
                                      onPressed: () {
                                        sheetRef
                                            .read(highlightDivineWordsProvider
                                                .notifier)
                                            .toggle();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: highlightDivine
                                              ? accentColor
                                              : cardBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          highlightDivine
                                              ? '✓ Lafzatullah Vurgusu: Açık'
                                              : 'Lafzatullah Vurgusu: Kapalı',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: highlightDivine
                                                ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TvFocusable(
                                      borderRadius: 14,
                                      onPressed: () {
                                        sheetRef
                                            .read(
                                                isMealComparisonEnabledProvider
                                                    .notifier)
                                            .state = !isComparing;
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color:
                                              isComparing ? accentColor : cardBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          isComparing
                                              ? '✓ Meâl Karşılaştırma: Açık'
                                              : 'Meâl Karşılaştırma: Kapalı',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: isComparing
                                                ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TvFocusable(
                                      borderRadius: 14,
                                      onPressed: () {
                                        sheetRef
                                            .read(showTransliterationProvider
                                                .notifier)
                                            .toggle(!showTranslit);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: showTranslit
                                              ? accentColor
                                              : cardBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          showTranslit
                                              ? '✓ Türkçe Okunuş: Açık'
                                              : 'Türkçe Okunuş: Kapalı',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: showTranslit
                                                ? (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isTv && onOpenTafseerReader != null) ...[
                                const SizedBox(height: 10),
                                ListTile(
                                  tileColor: cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  leading: Icon(Icons.auto_stories_rounded,
                                      color: accentColor),
                                  title: Text(
                                    'Varsayılan Meâl: ${activeMealInfo.title}',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Değiştirmek veya tefsir indirmek için dokunun',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      color: subColor,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: subColor,
                                  ),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    TafseerLibraryManagerSheet.show(
                                      context,
                                      onOpenTafseerReader: onOpenTafseerReader,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
