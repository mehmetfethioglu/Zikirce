import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';

class TafseerBottomSheet extends ConsumerWidget {
  final QuranAyatModel ayat;
  final String? mealText;

  const TafseerBottomSheet({
    super.key,
    required this.ayat,
    this.mealText,
  });

  static void show(
    BuildContext context, {
    required QuranAyatModel ayat,
    String? mealText,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TafseerBottomSheet(ayat: ayat, mealText: mealText),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahName = ayat.sure?.sureNameTurkish ?? 'Sûre';
    final tafseer = TafseerService.getTafseer(ayat.sureId, ayat.ayetId, surahName);
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);

    final sheetBg = isDark ? const Color(0xFF14171C) : const Color(0xFFFAF7F0);
    final cardBg = isDark ? const Color(0xFF1E222A) : const Color(0xFFFFFFFF);
    final primaryTextColor = isDark ? const Color(0xFFF3ECE0) : const Color(0xFF1B1917);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF706050);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);

    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final fontFamily = ref.watch(arabicFontFamilyProvider);

    final baseArabicStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
      color: isDark ? AppColors.gold300 : const Color(0xFF1B1917),
      height: 2.2,
      letterSpacing: -0.1,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: borderColor, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
          children: [
            // Drag Handle
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 14, bottom: 8),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${ayat.sure?.sureNameTurkish ?? 'Sûre'} - ${ayat.ayetId}. Âyet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2518) : const Color(0xFFFBF4E8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF70561E) : const Color(0xFFC5A358)),
                        ),
                        child: Text(
                          'Cüz ${ayat.sure?.cuz ?? 1}',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Arabic Verse Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFDF7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF70561E) : const Color(0xFFC5A358)),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: QuranWordHighlighter.buildHighlightedSpans(
                          rawText: ayat.ayetText,
                          baseStyle: baseArabicStyle,
                          isDark: isDark,
                          enabled: highlightDivineWords,
                          fontFamily: fontFamily,
                          ayahNumber: ayat.ayetNumber.isNotEmpty ? ayat.ayetNumber : '${ayat.ayetId}',
                          showAyahStopMarker: true,
                          isBold: isBoldArabic,
                        ),
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Turkish Meal Card
                  if (mealText != null && mealText!.isNotEmpty) ...[
                    Text(
                      'Türkçe Meali',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        mealText!,
                        style: AppTypography.bodyMedium(
                          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Tafseer Section
                  Text(
                    'Te’vîlâtü’l-Kur’ân Tefsiri',
                    style: TextStyle(
                      color: isDark ? AppColors.gold400 : const Color(0xFFB57D15),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      tafseer?.tefsirText ?? 'Bu âyet-i kerîme için tefsir açıklaması hazırlanmaktadır.',
                      style: AppTypography.bodyMedium(
                        color: isDark ? const Color(0xFFD4E2EE) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
