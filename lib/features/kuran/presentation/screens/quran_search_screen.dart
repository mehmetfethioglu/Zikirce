import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/arabic_normalizer.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';

class SearchResult {
  final int pageNumber;
  final int surahId;
  final int ayahId;
  final String surahName;
  final String arabicText;
  final String turkishMeal;

  SearchResult({
    required this.pageNumber,
    required this.surahId,
    required this.ayahId,
    required this.surahName,
    required this.arabicText,
    required this.turkishMeal,
  });
}

class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isSearching = false;
  String _lastSearched = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _lastSearched = q;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastSearched = q;
    });

    final normalizedQuery = ArabicNormalizer.normalize(q.toLowerCase());
    final isArabicInput = ArabicNormalizer.isArabic(q);
    final List<SearchResult> found = [];

    for (int p = 1; p <= 605; p++) {
      try {
        final pageData = await QuranPageRepository.getPage(p);

        if (isArabicInput) {
          for (final ayat in pageData.quranAyats) {
            final normAyat = ArabicNormalizer.normalize(ayat.ayetText);
            if (normAyat.contains(normalizedQuery)) {
              final meal = pageData.mealAyats.cast<MealAyatModel?>().firstWhere(
                    (m) => m?.sureId == ayat.sureId && m?.ayetId == ayat.ayetId,
                    orElse: () => null,
                  );
              found.add(
                SearchResult(
                  pageNumber: p,
                  surahId: ayat.sureId,
                  ayahId: ayat.ayetId,
                  surahName: ayat.sure?.sureNameTurkish ?? pageData.mealSureLabel,
                  arabicText: ayat.ayetText,
                  turkishMeal: meal?.ayetText ?? '',
                ),
              );
            }
          }
        } else {
          for (final meal in pageData.mealAyats) {
            if (meal.ayetText.toLowerCase().contains(q.toLowerCase())) {
              final ayat = pageData.quranAyats.cast<QuranAyatModel?>().firstWhere(
                    (a) => a?.sureId == meal.sureId && a?.ayetId == meal.ayetId,
                    orElse: () => null,
                  );
              found.add(
                SearchResult(
                  pageNumber: p,
                  surahId: meal.sureId,
                  ayahId: meal.ayetId,
                  surahName: meal.sure?.sureNameTurkish ?? pageData.mealSureLabel,
                  arabicText: ayat?.ayetText ?? '',
                  turkishMeal: meal.ayetText,
                ),
              );
            }
          }
        }
      } catch (_) {}

      if (found.length >= 50) break;
    }

    if (mounted) {
      setState(() {
        _results = found;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D10) : const Color(0xFFF4EFE6);
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);
    final goldAccent = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);
    final fontFamily = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        title: Text('Kur’ân-ı Kerîm’de Ara', style: AppTypography.headingSmall(color: primaryTextColor)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Arapça kelime veya Türkçe meal ara...',
                hintStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: goldAccent),
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_forward_rounded, color: goldAccent),
                  onPressed: () => _performSearch(_searchController.text),
                ),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(color: goldAccent),
            )
          else if (_results.isEmpty && _lastSearched.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Eşleşen âyet bulunamadı.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final res = _results[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      onTap: () {
                        ref.read(currentMushafPageProvider.notifier).state = res.pageNumber;
                        Navigator.of(context).pop();
                      },
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${res.surahName} - ${res.ayahId}. Âyet',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : const Color(0xFFF0EBE0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sayfa ${res.pageNumber}',
                              style: TextStyle(color: secondaryTextColor, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              children: QuranWordHighlighter.buildHighlightedSpans(
                                rawText: res.arabicText,
                                baseStyle: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: 20,
                                  fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                                  color: primaryTextColor,
                                  height: 2.0,
                                  letterSpacing: -0.1,
                                ),
                                isDark: isDark,
                                enabled: highlightDivineWords,
                                fontFamily: fontFamily,
                                isBold: isBoldArabic,
                              ),
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                          if (res.turkishMeal.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              res.turkishMeal,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
