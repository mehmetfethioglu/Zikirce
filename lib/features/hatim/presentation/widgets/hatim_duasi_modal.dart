import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../data/hatim_duasi_data.dart';

enum HatimDuasiDisplayMode {
  arabicOnly, // Matbû Mushaf Arapça (Varsayılan)
  all, // Arapça + Okunuş + Meâl
  readingAndMeaning, // Okunuş + Meâl
  meaningOnly, // Sadece Meâl
}

/// Matbû Kur'ân-ı Kerîmlerin sonunda bulunan Hatim Duası Popup / Modal Ekranı.
/// Hem aktif bir hatim bittiğinde otomatik kutlama + dua popup'ı olarak açılır,
/// hem de Zikirce dışında yapılan hatimler için bağımsız (sadece Hatim Duası okuma) modunda kullanılır.
class HatimDuasiModal extends ConsumerStatefulWidget {
  final Hatim? completedHatim;
  final bool isCompletionCelebration;
  final VoidCallback? onRestartHatim;

  const HatimDuasiModal({
    super.key,
    this.completedHatim,
    this.isCompletionCelebration = false,
    this.onRestartHatim,
  });

  static Future<void> show(
    BuildContext context, {
    Hatim? completedHatim,
    bool isCompletionCelebration = false,
    VoidCallback? onRestartHatim,
  }) {
    if (isCompletionCelebration) {
      HapticService.targetReached();
    } else {
      HapticService.selectionClick();
    }

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HatimDuasiModal(
        completedHatim: completedHatim,
        isCompletionCelebration: isCompletionCelebration,
        onRestartHatim: onRestartHatim,
      ),
    );
  }

  @override
  ConsumerState<HatimDuasiModal> createState() => _HatimDuasiModalState();
}

class _HatimDuasiModalState extends ConsumerState<HatimDuasiModal> {
  HatimDuasiDisplayMode _displayMode = HatimDuasiDisplayMode.arabicOnly;
  double _fontScale = 1.0;

  void _changeFontScale(double delta) {
    HapticService.selectionClick();
    setState(() {
      _fontScale = (_fontScale + delta).clamp(0.80, 1.45);
    });
  }

  Future<void> _copyDuaToClipboard() async {
    HapticService.selectionClick();
    await Clipboard.setData(
      ClipboardData(text: HatimDuasiData.buildFullShareText()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text('📋 ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                'Matbû Kur’ân Hatim Duası panoya kopyalandı.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _completePrayerWithAmin() {
    HapticService.targetReached();
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Text('🤲 ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text(
                'Allah okunan hatm-i şerifi ve yapılan duayı dergâh-ı izzetinde kabul eylesin. Âmin.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF165241),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Kur'ân okuma sayfasındaki (`MushafPageWidget`) ile birebir aynı font, punto,
  /// satır yüksekliği, Lafzatullah & Rab kırmızı vurgusu ve 8 köşeli Selçuklu durak gülü
  /// (`ZikirceAyahStopMarker`) kullanarak Arapça dua cümlelerini oluşturur.
  Widget _buildMushafRichArabicClauses({
    required List<String> clauses,
    required int startingStopNumber,
    required String arabicFont,
    required double effectiveFontSize,
    required double lineHeight,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required bool isDark,
    required Color primaryTextColor,
    required Color waqfColor,
  }) {
    final baseAyatStyle = TextStyle(
      fontFamily: arabicFont,
      fontSize: effectiveFontSize,
      fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
      color: primaryTextColor,
      height: lineHeight,
      letterSpacing: -0.1,
    );

    final spans = <InlineSpan>[];
    for (int i = 0; i < clauses.length; i++) {
      final clause = clauses[i];
      final clauseSpans = QuranWordHighlighter.buildHighlightedSpans(
        rawText: clause,
        baseStyle: baseAyatStyle,
        isDark: isDark,
        enabled: highlightDivineWords,
        fontFamily: arabicFont,
        waqfColor: waqfColor,
        isBold: isBoldArabic,
      );
      spans.addAll(clauseSpans);

      final stopNo = startingStopNumber + i;
      final formattedStopNo = QuranWordHighlighter.toArabicDigits(stopNo);
      spans.add(const TextSpan(text: '\u200F '));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ZikirceAyahStopMarker(
            number: formattedStopNo,
            isDark: isDark,
            isHighlight: false,
            fontFamily: arabicFont,
            size: (effectiveFontSize * 1.15).clamp(24.0, 42.0),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' \u200F'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  /// Kur'ân okuma sayfasındaki (`MushafPageWidget._buildSurahBanner`) tezhipli sûre
  /// serlevhası ile birebir aynı görsel dilde Matbû Hatim Duası Levhası.
  Widget _buildMushafLevhaBanner({
    required bool isDark,
    required String arabicFont,
    required int totalClauses,
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
        : const Color(0xFFB58D3D).withValues(alpha: 0.30);

    final titleColor =
        isDark ? const Color(0xFFF3ECE0) : const Color(0xFF4A3410);
    final subtitleColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF8C6928);
    final arabicTitleColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFF6B4808);
    final goldAccent =
        isDark ? const Color(0xFFC5A358) : const Color(0xFFB58D3D);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
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
                          'Matbû Hatm-i Şerîf Duası',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '$totalClauses Fasıl • Cüz 30 Sonu',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  QuranWordHighlighter.formatArabicTextForFont(
                    HatimDuasiData.arabicTitle,
                    arabicFont,
                  ),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: arabicFont,
                    color: arabicTitleColor,
                    fontSize: 21,
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

  /// Kur'ân okuma sayfasındaki (`MushafPageWidget._buildBesmele`) ile birebir aynı Besmele satırı.
  Widget _buildMushafBesmele(bool isDark, String arabicFont) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          QuranWordHighlighter.formatArabicTextForFont(
            HatimDuasiData.besmele,
            arabicFont,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: arabicFont,
            fontSize: 22 * _fontScale.clamp(0.9, 1.25),
            color: isDark ? AppColors.gold400 : const Color(0xFF83590E),
            height: 1.8,
          ),
        ),
      ),
    );
  }

  /// Varsayılan `Matbû Arapça` modunda (`HatimDuasiDisplayMode.arabicOnly`)
  /// tüm Hatim Duasını Kur'ân okuma sayfasındaki (`MushafPageWidget`) çift çizgili
  /// Mushaf sahifesi çerçevesi içinde tek parça, kesintisiz ve durak güllü olarak sunar.
  Widget _buildMatbuMushafSahifeCard({
    required bool isDark,
    required String arabicFont,
    required double effectiveFontSize,
    required double lineHeight,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required Color primaryTextColor,
    required Color waqfColor,
  }) {
    final innerSheetBg =
        isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF6);
    final tezhipGold =
        isDark ? const Color(0xFFC5A358) : const Color(0xFFA67C2E);
    final headerFooterTextColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF8C5828);

    final allClauses = HatimDuasiData.allMatbuBodyClauses;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: innerSheetBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tezhipGold.withValues(alpha: 0.48),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Mushaf Sayfası İç Üst Bilgi Şeridi (Klasik Kitap Serlevhası)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: tezhipGold.withValues(alpha: isDark ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tezhipGold.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Duâü Hatmi’l-Kur’âni’l-Azîm',
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
                const SizedBox(width: 8),
                Text(
                  '30. Cüz • S. 605',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: headerFooterTextColor,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // 2. Tezhipli Sûre Tarzı Levha Başlığı
          _buildMushafLevhaBanner(
            isDark: isDark,
            arabicFont: arabicFont,
            totalClauses: allClauses.length,
          ),

          // 3. Müstakil Besmele-i Şerîfe
          _buildMushafBesmele(isDark, arabicFont),
          const SizedBox(height: 6),

          // 4. Kesintisiz Matbû Mushaf Arapça Dua Metni (Kur'ân Sayfasıyla Aynı Font & Durak Gülleri)
          _buildMushafRichArabicClauses(
            clauses: allClauses,
            startingStopNumber: 1,
            arabicFont: arabicFont,
            effectiveFontSize: effectiveFontSize,
            lineHeight: lineHeight,
            isBoldArabic: isBoldArabic,
            highlightDivineWords: highlightDivineWords,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            waqfColor: waqfColor,
          ),

          const SizedBox(height: 12),

          // 5. Alt Sahife Numarası Şeridi
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: tezhipGold.withValues(alpha: 0.35),
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
                    'Hatm-i Şerîf Duası • Sayfa 605',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: headerFooterTextColor,
                      fontSize: 12.0,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicFont = ref.watch(quranFontFamilyProvider);
    final baseFontSize = ref.watch(quranFontSizeProvider);
    final lineHeight = ref.watch(quranLineHeightProvider);
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);

    final effectiveArabicFontSize =
        (baseFontSize * _fontScale).clamp(20.0, 56.0);

    final sheetBg = isDark ? const Color(0xFF101317) : const Color(0xFFFBF7EE);
    final cardBg = isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF6);
    final primaryTextColor =
        isDark ? const Color(0xFFF4EFE6) : const Color(0xFF261E17);
    final secondaryTextColor =
        isDark ? const Color(0xFFA59E92) : const Color(0xFF6B5848);
    final goldColor =
        isDark ? const Color(0xFFE5B84B) : const Color(0xFFB57D15);
    final emeraldColor =
        isDark ? const Color(0xFF34D399) : const Color(0xFF165241);
    final borderStroke =
        isDark ? const Color(0xFF2D3640) : const Color(0xFFE5DEC9);
    final waqfColor =
        isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);

    final hatim = widget.completedHatim;
    final isMukabele = hatim != null &&
        (hatim.id.startsWith('mukabele_') ||
            hatim.title.toLowerCase().contains('mukabele'));

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: goldColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Grab Handle & Tezhip Header Ornament
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // 2. Top Header Bar (Title + Font Controls + Close)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF165241), Color(0xFF0E382C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🤲', style: TextStyle(fontSize: 21)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HatimDuasiData.turkishTitle,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hatim != null
                              ? '${hatim.title} • Hatm-i Şerif Duası'
                              : 'Zikirce içi ve harici tüm hatimler için',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: goldColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Font Size Controls (A- / A+)
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderStroke),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _changeFontScale(-0.1),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Text(
                              'A-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 18, color: borderStroke),
                        InkWell(
                          onTap: () => _changeFontScale(0.1),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Text(
                              'A+',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: goldColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 3. View Mode Selector Chips (Matbû Arapça Varsayılan İlk Sırada)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  _buildModeChip(
                    mode: HatimDuasiDisplayMode.arabicOnly,
                    label: 'Matbû Arapça',
                    icon: '🕋',
                    isDark: isDark,
                    goldColor: goldColor,
                    emeraldColor: emeraldColor,
                    cardBg: cardBg,
                    borderStroke: borderStroke,
                    primaryTextColor: primaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    mode: HatimDuasiDisplayMode.all,
                    label: 'Tümü (Arapça + Okunuş + Meâl)',
                    icon: '📖',
                    isDark: isDark,
                    goldColor: goldColor,
                    emeraldColor: emeraldColor,
                    cardBg: cardBg,
                    borderStroke: borderStroke,
                    primaryTextColor: primaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    mode: HatimDuasiDisplayMode.readingAndMeaning,
                    label: 'Okunuş & Meâl',
                    icon: '🌿',
                    isDark: isDark,
                    goldColor: goldColor,
                    emeraldColor: emeraldColor,
                    cardBg: cardBg,
                    borderStroke: borderStroke,
                    primaryTextColor: primaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    mode: HatimDuasiDisplayMode.meaningOnly,
                    label: 'Sadece Meâl',
                    icon: '✨',
                    isDark: isDark,
                    goldColor: goldColor,
                    emeraldColor: emeraldColor,
                    cardBg: cardBg,
                    borderStroke: borderStroke,
                    primaryTextColor: primaryTextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: borderStroke),

            // 4. Scrollable Matbu Mushaf Hatim Duası Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  // Optional Active Hatim Completion Celebration Banner
                  if (hatim != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF165241), Color(0xFF0C2E24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF165241).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isMukabele ? '👑' : '🏆',
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.isCompletionCelebration
                                        ? '🎉 Elhamdülillah • Hatim Tamamlandı!'
                                        : '✅ Tamamlanan Hatm-i Şerif (604 Sayfa)',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFE082),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  hatim.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Hatminizin kabulü ve sevabının bağışlanması için matbû hatim duasını okuyabilirsiniz.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFD4EBE4),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Varsayılan Matbû Arapça Modu: Kur'ân Okuma Sayfasıyla Birebir Aynı Sahife Görünümü
                  if (_displayMode == HatimDuasiDisplayMode.arabicOnly)
                    _buildMatbuMushafSahifeCard(
                      isDark: isDark,
                      arabicFont: arabicFont,
                      effectiveFontSize: effectiveArabicFontSize,
                      lineHeight: lineHeight,
                      isBoldArabic: isBoldArabic,
                      highlightDivineWords: highlightDivineWords,
                      primaryTextColor: primaryTextColor,
                      waqfColor: waqfColor,
                    )
                  else ...[
                    // Diğer modlarda (Tümü / Okunuş & Meâl / Sadece Meâl) Serlevha + 5 Bölüm Kartı
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF231F17)
                            : const Color(0xFFFDF8EB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFFD4AF37).withValues(alpha: 0.65),
                          width: 1.3,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _HatimDuasiTezhipCornerPainter(
                          color:
                              const Color(0xFFD4AF37).withValues(alpha: 0.35),
                        ),
                        child: Column(
                          children: [
                            Text(
                              QuranWordHighlighter.formatArabicTextForFont(
                                HatimDuasiData.arabicTitle,
                                arabicFont,
                              ),
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: arabicFont,
                                fontSize: 22 * _fontScale,
                                fontWeight: FontWeight.bold,
                                color: goldColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              HatimDuasiData.turkishSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final section in HatimDuasiData.sections)
                      _buildSectionCard(
                        section: section,
                        arabicFont: arabicFont,
                        effectiveArabicFontSize: effectiveArabicFontSize,
                        lineHeight: lineHeight,
                        isBoldArabic: isBoldArabic,
                        highlightDivineWords: highlightDivineWords,
                        isDark: isDark,
                        cardBg: cardBg,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        goldColor: goldColor,
                        emeraldColor: emeraldColor,
                        borderStroke: borderStroke,
                        waqfColor: waqfColor,
                      ),
                  ],

                  // Spiritual Dedication (İthaf & Fâtiha) Footer Box
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: emeraldColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: emeraldColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🕌', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hatim Sevabını Bağışlama (İthaf) Niyeti',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Zikirce’de veya matbû Mushaf’tan okuduğunuz hatm-i şerifin sevabını bağışlamak istediğiniz geçmişlerinizin isimlerini kalbinizden geçirerek "Âmin" diyebilir, ardından 1 Fâtiha ve 3 İhlâs-ı Şerîf okuyabilirsiniz.',
                                style: TextStyle(
                                  fontSize: 12 * _fontScale.clamp(0.9, 1.15),
                                  height: 1.45,
                                  color: secondaryTextColor,
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

            // 5. Bottom Sticky Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderStroke)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderStroke),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _copyDuaToClipboard,
                    icon: Icon(Icons.copy_rounded, size: 17, color: goldColor),
                    label: const Text(
                      'Kopyala',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.onRestartHatim != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: emeraldColor,
                        side: BorderSide(
                          color: emeraldColor.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onRestartHatim?.call();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text(
                        'Yeniden Oku',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF165241),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _completePrayerWithAmin,
                      icon: const Text('🤲', style: TextStyle(fontSize: 16)),
                      label: const Text(
                        'Âmin • Duayı Tamamla',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildModeChip({
    required HatimDuasiDisplayMode mode,
    required String label,
    required String icon,
    required bool isDark,
    required Color goldColor,
    required Color emeraldColor,
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
  }) {
    final isSelected = _displayMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          setState(() {
            _displayMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF165241) : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37) : borderStroke,
              width: isSelected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : primaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required HatimDuasiSection section,
    required String arabicFont,
    required double effectiveArabicFontSize,
    required double lineHeight,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required bool isDark,
    required Color cardBg,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color goldColor,
    required Color emeraldColor,
    required Color borderStroke,
    required Color waqfColor,
  }) {
    final showArabic = _displayMode == HatimDuasiDisplayMode.all ||
        _displayMode == HatimDuasiDisplayMode.arabicOnly;
    final showTransliteration = _displayMode == HatimDuasiDisplayMode.all ||
        _displayMode == HatimDuasiDisplayMode.readingAndMeaning;
    final showMeaning = _displayMode == HatimDuasiDisplayMode.all ||
        _displayMode == HatimDuasiDisplayMode.readingAndMeaning ||
        _displayMode == HatimDuasiDisplayMode.meaningOnly;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderStroke),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: goldColor.withValues(alpha: 0.45)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${section.order}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: goldColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      section.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showArabic) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF15191F) : const Color(0xFFFDFBF6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: goldColor.withValues(alpha: 0.35),
                ),
              ),
              child: _buildMushafRichArabicClauses(
                clauses: section.arabicClauses,
                startingStopNumber: 1,
                arabicFont: arabicFont,
                effectiveFontSize: effectiveArabicFontSize,
                lineHeight: lineHeight,
                isBoldArabic: isBoldArabic,
                highlightDivineWords: highlightDivineWords,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                waqfColor: waqfColor,
              ),
            ),
          ],

          if (showTransliteration) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: emeraldColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: emeraldColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 13,
                        color: emeraldColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Türkçe Okunuşu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: emeraldColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    section.transliteration,
                    style: TextStyle(
                      fontSize: 13.5 * _fontScale,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                      color: primaryTextColor.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (showMeaning) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 13,
                        color: goldColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Anlamı (Meâli)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    section.meaning,
                    style: TextStyle(
                      fontSize: 13.5 * _fontScale,
                      height: 1.55,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Matbû Mushaf Serlevha Köşe Tezhip Deseni (`CustomPainter`)
class _HatimDuasiTezhipCornerPainter extends CustomPainter {
  final Color color;

  const _HatimDuasiTezhipCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const radius = 14.0;
    // Four ornamental corner rosettes
    final corners = [
      const Offset(8, 8),
      Offset(size.width - 8, 8),
      Offset(8, size.height - 8),
      Offset(size.width - 8, size.height - 8),
    ];

    for (final center in corners) {
      canvas.drawCircle(center, radius * 0.45, paint);
      for (int i = 0; i < 4; i++) {
        final angle = (i * math.pi) / 2;
        final dx = center.dx + math.cos(angle) * (radius * 0.35);
        final dy = center.dy + math.sin(angle) * (radius * 0.35);
        canvas.drawCircle(Offset(dx, dy), 2.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HatimDuasiTezhipCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
