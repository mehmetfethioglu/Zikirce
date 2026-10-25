import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/kuran_providers.dart';

/// Sure başlarında Besmele okunurken ayetlerin üstünü kapatmadan,
/// üst barda zarifçe beliren ve Besmele biter bitmez (4.9 sn) anında kapanan şerit.
class BesmelePlaybackBanner extends ConsumerWidget {
  static const Color _goldColor = Color(0xFFD4AF37);
  final bool isVisible;
  final String? surahName;

  const BesmelePlaybackBanner({
    super.key,
    this.isVisible = true,
    this.surahName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicFont = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final highlightDivine = ref.watch(highlightDivineWordsProvider);
    final baseColor =
        isDark ? const Color(0xFFFDF8EE) : const Color(0xFF1B3B2B);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !isVisible
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1A2822),
                            const Color(0xFF121C18),
                          ]
                        : [
                            const Color(0xFFFDF8EE),
                            const Color(0xFFF5EBD6),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _goldColor.withValues(alpha: 0.55),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _goldColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: _goldColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            surahName != null && surahName!.isNotEmpty
                                ? '$surahName • Besmele'
                                : 'Besmele-i Şerîf',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _goldColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: QuranWordHighlighter.buildHighlightedSpans(
                            rawText: 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّح۪يمِ',
                            baseStyle: TextStyle(
                              fontFamily: arabicFont,
                              fontSize: 20,
                              height: 1.5,
                              fontWeight: isBoldArabic
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: baseColor,
                            ),
                            isDark: isDark,
                            enabled: highlightDivine,
                            fontFamily: arabicFont,
                            isBold: isBoldArabic,
                          ),
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
