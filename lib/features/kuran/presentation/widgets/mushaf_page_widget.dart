import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import 'tafseer_bottom_sheet.dart';
import 'zikirce_ayah_stop_marker.dart';

class MushafPageWidget extends ConsumerStatefulWidget {
  final QuranPageData pageData;

  const MushafPageWidget({
    super.key,
    required this.pageData,
  });

  @override
  ConsumerState<MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends ConsumerState<MushafPageWidget> {
  final List<TapGestureRecognizer> _recognizers = [];

  static const Set<String> _stopSigns = {
    '\u0615', // Small High Tah (Tı - ط)
    '\u0617', // Small High Zain (Ze - ز)
    '\u06D6', // Small High Sad (Sâd - ص)
    '\u06D7', // Small High Qaf (Qaf - ق)
    '\u06D8', // Small High Meem (Mîm - م / Lâzım)
    '\u06D9', // Small High Lam Alef (Lâ - لا)
    '\u06DA', // Small High Jeem (Cim - ج)
    '\u06DB', // Small High Three Dots (Mu'anaqa 3 nokta - ۛ)
    '\u06DC', // Small High Seen (Tı / Sin - ۜ)
    '\u06DF', // Small High Rounded Zero (Ayn - ۟)
    '\u06E2', // Small High Meem Isolated (Mîm - ۢ)
    '\u06E3', // Small Low Seen (Sin - ۣ)
    '\u06E7', // Small High Qaf / Kef (Kef - ۧ)
    '\u08D5', // Arabic Small High Sad (Sâd - ࣕ)
    '\u08D6', // Arabic Small High Ain (Ayn / Rükû - ࣖ)
    '\u08D7', // Arabic Small High Qaf (Qaf - ࣗ)
    '\u08DE', // Arabic Small High Word Kaph (Kef - ࣞ)
  };

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

  static String mapStopCharacter(String char, String fontFamily) {
    if (fontFamily == 'AmasyaAbay' || fontFamily == 'mushaf') {
      switch (char) {
        case '\u0615': return '\u06DC'; // Tı stop -> U+06DC (hightah in AmasyaAbay/mushaf)
        case '\u0617': return '\u0617'; // Ze stop -> U+0617
        case '\u06D6':
        case '\u08D5': return '\u06D6'; // Sâd stop -> U+06D6
        case '\u06D7':
        case '\u08D7': return '\u06D7'; // Qaf stop -> U+06D7
        case '\u06D8':
        case '\u06E2': return '\u06E2'; // Mîm stop -> U+06E2
        case '\u06D9': return '\u06D9'; // Lâ stop -> U+06D9
        case '\u06DA': return '\u06DA'; // Cim stop -> U+06DA
        case '\u06DB': return '\u06DB'; // Mu'anaqa 3 dots -> U+06DB
        case '\u06DC': return '\u06DC'; // Tı stop -> U+06DC
        case '\u06DF':
        case '\u08D6': return '\u06DF'; // Ayn stop -> U+06DF (highain in AmasyaAbay/mushaf)
        case '\u06E3': return '\u06E3'; // Sin stop -> U+06E3 (lowseen)
        case '\u06E7':
        case '\u08DE': return '\u06E7'; // Kef stop -> U+06E7 (highkaf)
        default: return char;
      }
    } else if (fontFamily == 'mushaf_bold') {
      switch (char) {
        case '\u0615':
        case '\u06DC': return '\u0615';
        case '\u0617': return '\u0617';
        case '\u06D6':
        case '\u08D5': return '\u06D6';
        case '\u06D7':
        case '\u08D7': return '\u06D7';
        case '\u06D8':
        case '\u06E2': return '\u06D8';
        case '\u06D9': return '\u06D9';
        case '\u06DA': return '\u06DA';
        case '\u06DB': return '\u06DB';
        case '\u06DF':
        case '\u08D6': return '\u08D6';
        case '\u06E3': return '\u06E3';
        case '\u06E7':
        case '\u08DE': return '\u06E7';
        default: return char;
      }
    }
    return char;
  }

  List<InlineSpan> _buildAyahWordSpans({
    required String rawText,
    required TextStyle baseStyle,
    required Color waqfColor,
    required String fontFamily,
    required GestureRecognizer? recognizer,
    required VoidCallback? onAyahTap,
    required bool highlightDivineWords,
    required bool isDark,
    required bool isAyahPlaying,
    int? activeWordOrder,
  }) {
    final words = rawText.split(' ');
    final spans = <InlineSpan>[];
    final divineColor = QuranWordHighlighter.getDivineWordColor(isDark);
    final emeraldBg = isDark ? const Color(0xFF059669) : const Color(0xFF10B981);

    for (int wIdx = 0; wIdx < words.length; wIdx++) {
      final word = words[wIdx];
      if (word.isEmpty) continue;

      // 1. Strip hidden control characters, annotations (kasr, med, etc.), surrogates and typos
      // 2. Normalize Farsi Yeh (U+06CC) to standard Arabic Yeh (U+064A) so ligatures with sukun don't break!
      final cleanWord = word
          .replaceAll(String.fromCharCode(0x10EFD), '')
          .replaceAll(String.fromCharCode(0x10EFE), '')
          .replaceAll(String.fromCharCode(0x10EFF), '')
          .replaceAll('\uD803\uDEFD', '')
          .replaceAll('\uD803\uDEFE', '')
          .replaceAll('\uD803\uDEFF', '')
          .replaceAll('\uEE00', '')
          .replaceAll('\uEE01', '')
          .replaceAll('\u08CF', '')
          .replaceAll('\u08D9', '')
          .replaceAll('\u06EA', '')
          .replaceAll('\u06EB', '')
          .replaceAll('\u06EC', '')
          .replaceAll('\u200C', '')
          .replaceAll('\u200D', '')
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ')
          .replaceAll('ی', 'ي')
          .replaceAll('D', 'ْد');

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
      final bool isWordActive = isAyahPlaying && (activeWordOrder != null && activeWordOrder == wordOrder);
      final bool isDivine = highlightDivineWords && !isWordActive && QuranWordHighlighter.isDivineWord(pureWord);

      TextStyle wordStyle;
      if (isWordActive) {
        wordStyle = baseStyle.copyWith(
          color: Colors.white,
          backgroundColor: emeraldBg,
        );
      } else if (isDivine) {
        wordStyle = baseStyle.copyWith(
          color: divineColor,
        );
      } else {
        wordStyle = baseStyle;
      }

      if (pureWord.isNotEmpty) {
        spans.add(TextSpan(
          text: pureWord,
          style: wordStyle,
          recognizer: recognizer,
        ));
      }

      // Add stop characters in RED (waqfColor)
      for (int sIdx = 0; sIdx < stops.length; sIdx++) {
        final stop = stops[sIdx];
        final mappedStop = mapStopCharacter(stop, fontFamily);
        final prefix = sIdx == 0 ? '\u200B' : '\u200A';
        spans.add(TextSpan(
          text: '$prefix$mappedStop',
          style: baseStyle.copyWith(
            color: waqfColor,
            fontWeight: FontWeight.normal,
          ),
          recognizer: recognizer,
        ));
      }

      if (wIdx < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioState = ref.watch(kuranAudioNotifierProvider);
    final audioNotifier = ref.read(kuranAudioNotifierProvider.notifier);
    final fontFamily = ref.watch(quranFontFamilyProvider);
    final baseFontSize = ref.watch(quranFontSizeProvider);
    final lineHeight = ref.watch(quranLineHeightProvider);
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);

    // Warm Saman Kağıdı (Parchment) Book Palette
    final pageBg = isDark ? const Color(0xFF101216) : const Color(0xFFFBF8F1);
    final tezhipGold = isDark ? const Color(0xFFC5A358) : const Color(0xFFB58D3D);
    final tezhipBg = isDark ? const Color(0xFF171B20) : const Color(0xFFF3ECE0);
    final primaryTextColor = isDark ? const Color(0xFFF6F2EA) : const Color(0xFF1E1A16);
    final headerFooterTextColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFF83590E);
    final waqfColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);

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

    final isShortPage = widget.pageData.pageNo <= 2 || widget.pageData.quranAyats.length <= 7;

    final allAyats = widget.pageData.quranAyats;
    String topSurahVerseInfo = '${widget.pageData.mealSureLabel} Sûresi';
    if (allAyats.isNotEmpty) {
      final firstA = allAyats.first;
      final lastA = allAyats.last;
      if (firstA.sureId == lastA.sureId) {
        if (firstA.ayetId == lastA.ayetId) {
          topSurahVerseInfo = '${widget.pageData.mealSureLabel} (${firstA.ayetId}. Âyet)';
        } else {
          topSurahVerseInfo = '${widget.pageData.mealSureLabel} (${firstA.ayetId}-${lastA.ayetId}. Âyetler)';
        }
      } else {
        final startName = firstA.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel;
        final endName = lastA.sure?.sureNameTurkish ?? widget.pageData.mealSureLabel;
        topSurahVerseInfo = '$startName (${firstA.ayetId}) - $endName (${lastA.ayetId})';
      }
    }

    return Container(
      color: pageBg,
      child: Column(
        children: [
          // ==========================================
          // TOP TEZHIP HEADER BAND (Full-width Book Header)
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tezhipBg,
              border: Border(
                top: BorderSide(color: tezhipGold.withOpacity(0.4), width: 1.0),
                bottom: BorderSide(color: tezhipGold.withOpacity(0.7), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 14, color: tezhipGold),
                    const SizedBox(width: 6),
                    Text(
                      topSurahVerseInfo,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: headerFooterTextColor,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  '۞',
                  style: TextStyle(
                    color: tezhipGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.pageData.cuzNo}. Cüz',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: headerFooterTextColor,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.bookmark_outline_rounded, size: 14, color: tezhipGold),
                  ],
                ),
              ],
            ),
          ),

          // ==========================================
          // QURAN PAGE CONTENT (Full Horizontal Flowing Text)
          // ==========================================
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  ...surahGroups.map((group) {
                    final firstAyat = group.first;
                    final sureMeta = firstAyat.sure;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Surah Header ONLY if surah actually starts on this page (firstAyat.ayetId == 1)
                        if (firstAyat.ayetId == 1 && sureMeta != null) ...[
                          _buildSurahBanner(sureMeta, isDark, fontFamily),
                          if (sureMeta.besmeleVisible && sureMeta.sureId != 1 && sureMeta.sureId != 9)
                            _buildBesmele(isDark, fontFamily),
                          const SizedBox(height: 8),
                        ],

                        // Continuous Verse Spans for this Surah
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          child: Text.rich(
                            TextSpan(
                              children: group.expand((ayat) {
                                final isCurrentAyahPlaying = audioState.isPlaying &&
                                    audioState.currentSurahId == ayat.sureId &&
                                    audioState.currentAyahId == ayat.ayetId;

                                final meal = widget.pageData.mealAyats.cast<MealAyatModel?>().firstWhere(
                                      (m) => m?.sureId == ayat.sureId && m?.ayetId == ayat.ayetId,
                                      orElse: () => null,
                                    );

                                final voidCallback = () => _showAyahActionMenu(context, ayat, meal, audioNotifier);
                                final recognizer = _createRecognizer(voidCallback);

                                final effectiveFontSize = isShortPage ? (baseFontSize + 2.0) : baseFontSize;

                                final baseAyatStyle = TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: effectiveFontSize,
                                  fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrentAyahPlaying
                                      ? (isDark ? const Color(0xFFF6F2EA) : const Color(0xFF1E1A16))
                                      : primaryTextColor,
                                  backgroundColor: isCurrentAyahPlaying
                                      ? (isDark ? const Color(0xFF059669).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.10))
                                      : Colors.transparent,
                                  height: lineHeight,
                                  letterSpacing: -0.1,
                                );

                                final textSpans = _buildAyahWordSpans(
                                  rawText: ayat.ayetText,
                                  baseStyle: baseAyatStyle,
                                  waqfColor: isCurrentAyahPlaying ? AppColors.gold400 : waqfColor,
                                  fontFamily: fontFamily,
                                  recognizer: recognizer,
                                  onAyahTap: voidCallback,
                                  highlightDivineWords: highlightDivineWords,
                                  isDark: isDark,
                                  isAyahPlaying: isCurrentAyahPlaying,
                                  activeWordOrder: isCurrentAyahPlaying ? audioState.currentWordOrder : null,
                                );

                                return [
                                  ...textSpans,
                                  const TextSpan(text: '\u200F '),
                                  // Zikirce 8-Ring Islamic Rosette Stop Marker
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: voidCallback,
                                      child: ZikirceAyahStopMarker(
                                        number: ayat.ayetNumber,
                                        isDark: isDark,
                                        isHighlight: isCurrentAyahPlaying,
                                        fontFamily: fontFamily,
                                        size: (effectiveFontSize * 1.15).clamp(24.0, 42.0),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' \u200F'),
                                ];
                              }).toList(),
                            ),
                            textAlign: isShortPage ? TextAlign.center : TextAlign.justify,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),

                  // Safe bottom clearance so text and footer are NEVER covered by floating buttons
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),

          // ==========================================
          // BOTTOM TEZHIP FOOTER BAND (Page Number & Medallion)
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: tezhipBg,
              border: Border(
                top: BorderSide(color: tezhipGold.withOpacity(0.7), width: 1.2),
                bottom: BorderSide(color: tezhipGold.withOpacity(0.4), width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  width: 40,
                  color: tezhipGold.withOpacity(0.5),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '—  ${widget.pageData.pageNo}  —',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: headerFooterTextColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  width: 40,
                  color: tezhipGold.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SURAH HEADER BANNER (ILLUMINATED LEVHA)
  // ==========================================
  Widget _buildSurahBanner(SureMeta sure, bool isDark, String fontFamily) {
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
        ? const Color(0xFFC5A358).withOpacity(0.65)
        : const Color(0xFFB58D3D).withOpacity(0.65);

    final innerBorderColor = isDark
        ? const Color(0xFFC5A358).withOpacity(0.25)
        : const Color(0xFFB58D3D).withOpacity(0.3);

    final titleColor = isDark ? const Color(0xFFF3ECE0) : const Color(0xFF4A3410);
    final subtitleColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8C6928);
    final arabicTitleColor = isDark ? const Color(0xFFFFD54F) : const Color(0xFF6B4808);
    final goldAccent = isDark ? const Color(0xFFC5A358) : const Color(0xFFB58D3D);

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
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF83590E)).withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            Column(
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
                    Text(
                      '${sure.sureNameTurkish} Sûresi',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '${sure.ayetCount} Âyet • Cüz ${sure.cuz}',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sure.sureNameArabic,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: arabicTitleColor,
                    fontSize: 23,
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

  // ==========================================
  // BESMELE-I SERIF
  // ==========================================
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


  // ==========================================
  // AYAH ACTION SHEET (DINLE / TEFSIR & MEAL)
  // ==========================================
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
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Text(
                '${ayat.sure?.sureNameTurkish ?? 'Sûre'} - ${ayat.ayetId}. Âyet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.play_arrow_rounded, color: AppColors.gold500, size: 30),
                      title: Text(
                        'Âyeti Dinle (Ses Senkronu)',
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        audioNotifier.playVerse(ayat.sureId, ayat.ayetId, pageId: widget.pageData.pageNo);
                      },
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      leading: const Icon(Icons.menu_book_rounded, color: AppColors.emerald500, size: 26),
                      title: Text(
                        'Meâl ve Tefsirini Oku',
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        TafseerBottomSheet.show(context, ayat: ayat, mealText: meal?.ayetText);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
