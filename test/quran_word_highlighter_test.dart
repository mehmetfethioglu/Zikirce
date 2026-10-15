import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/utils/quran_word_highlighter.dart';

void main() {
  group('QuranWordHighlighter Tests', () {
    test('Correctly identifies Lafzatullah (Allah) variations', () {
      expect(QuranWordHighlighter.isAllahWord('اللّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('اللّٰهُ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('اللّٰهَ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('وَاللّٰهُ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('بِاللّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('لِلّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('فَلِلّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('تَاللّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('اللّٰهُمَّ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('اَللّٰهُ'), isTrue);
      expect(QuranWordHighlighter.isAllahWord('وَتَاللّٰهِ'), isTrue);

      expect(QuranWordHighlighter.isDivineWord('اللّٰهِ'), isTrue);
      expect(QuranWordHighlighter.isDivineWord('لِلّٰهِ'), isTrue);
    });

    test('Correctly identifies Lafz-ı Rab variations', () {
      expect(QuranWordHighlighter.isRabWord('رَبِّ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبَّنَا'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبِّكَ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبِّكُمَا'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبِّكُمْ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبِّهِ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبِّهِمْ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('رَبّٖي'), isTrue);
      expect(QuranWordHighlighter.isRabWord('وَرَبُّكَ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('بِرَبِّ الْفَلَقِ'), isFalse); // phrase test
      expect(QuranWordHighlighter.isRabWord('بِرَبِّ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('لِرَبِّكَ'), isTrue);
      expect(QuranWordHighlighter.isRabWord('فَوَرَبِّ'), isTrue);

      expect(QuranWordHighlighter.isDivineWord('رَبَّنَا'), isTrue);
    });

    test('Rejects non-divine words that contain letters like رب or اله (Zero False Positives)', () {
      // Usury (Riba)
      expect(QuranWordHighlighter.isDivineWord('الرِّبٰوا'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('رِبًا'), isFalse);

      // Hill (Rabwah)
      expect(QuranWordHighlighter.isDivineWord('رَبْوَةٍ'), isFalse);

      // Verbs / nouns
      expect(QuranWordHighlighter.isDivineWord('رَبَّیَانٖی'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('نُرَبِّكَ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('رَبَطْنَا'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('تَرَبَّصُوا'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('الرُّبُعُ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('رِبِّیُّونَ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('رَبَّانِیّٖنَ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('وَرَبَٓائِبُكُمُ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('اَرْبَابًا'), isFalse);

      // Words containing lah/lahw/lahab
      expect(QuranWordHighlighter.isDivineWord('اللَّهْوِ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('اللَّهَبِ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('فَاَلْهَمَهَا'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('اَلْهٰیكُمُ'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('اٰلِهَةً'), isFalse);
      expect(QuranWordHighlighter.isDivineWord('اٰلِهَتِنَا'), isFalse);
    });

    test('buildHighlightedSpans correctly assigns red color in Fatiha verse 1 & 2', () {
      const v1 = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ';
      const baseStyle = TextStyle(fontSize: 22, color: Colors.black);

      final spansV1 = QuranWordHighlighter.buildHighlightedSpans(
        rawText: v1,
        baseStyle: baseStyle,
        isDark: false,
        enabled: true,
      );

      // Word 1: بِسْمِ (normal)
      // Word 2: (space)
      // Word 3: اللّٰهِ (divine red)
      expect(spansV1.length, equals(7)); // 4 words + 3 spaces
      final allahSpan = spansV1[2] as TextSpan;
      expect(allahSpan.text, equals('اللّٰهِ'));
      expect(allahSpan.style?.color, equals(QuranWordHighlighter.lightDivineRed));

      const v2 = 'اَلْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ';
      final spansV2 = QuranWordHighlighter.buildHighlightedSpans(
        rawText: v2,
        baseStyle: baseStyle,
        isDark: true,
        enabled: true,
      );

      // Word 1: اَلْحَمْدُ (normal)
      // Word 2: (space)
      // Word 3: لِلّٰهِ (divine red)
      // Word 4: (space)
      // Word 5: رَبِّ (divine red)
      // Word 6: (space)
      // Word 7: الْعَالَمٖينَ (normal)
      final lillahSpan = spansV2[2] as TextSpan;
      expect(lillahSpan.text, equals('لِلّٰهِ'));
      expect(lillahSpan.style?.color, equals(QuranWordHighlighter.darkDivineRed));

      final rabSpan = spansV2[4] as TextSpan;
      expect(rabSpan.text, equals('رَبِّ'));
      expect(rabSpan.style?.color, equals(QuranWordHighlighter.darkDivineRed));
    });

    test('cleanArabicText normalizes Farsi Yeh, D typo, and strips invisible characters', () {
      // Farsi Yeh (06CC) in Tevbe 41
      const rawTevbe41 = 'فٖی سَبٖیلِ اللّٰهِؕ ذٰلِكُمْ خَیْرٌ';
      final clean = QuranWordHighlighter.cleanArabicText(rawTevbe41);

      // Verify no Farsi Yeh remains (0x06CC)
      expect(clean.contains('\u06CC'), isFalse);
      // Verify standard Arabic Yeh is present (0x064A)
      expect(clean.contains('\u064A'), isTrue);
      // Check D artifact
      expect(QuranWordHighlighter.cleanArabicText('D'), equals('ْد'));
    });

    test('mapStopCharacter maps stop characters for AmasyaAbay and mushaf fonts', () {
      expect(QuranWordHighlighter.mapStopCharacter('\u0615', 'AmasyaAbay'), equals('\u06DC'));
      expect(QuranWordHighlighter.mapStopCharacter('\u0615', 'mushaf'), equals('\u06DC'));
      expect(QuranWordHighlighter.mapStopCharacter('\u0615', 'mushaf_bold'), equals('\u0615'));
    });

    test('toArabicDigits correctly converts numbers to Arabic numerals', () {
      expect(QuranWordHighlighter.toArabicDigits(41), equals('٤١'));
      expect(QuranWordHighlighter.toArabicDigits('194'), equals('١٩٤'));
      expect(QuranWordHighlighter.toArabicDigits('٤١'), equals('٤١'));
    });

    test('buildHighlightedSpans correctly isolates stop signs from divine words in Tevbe 41', () {
      // Verse containing Lafzatullah with attached stop sign ؕ
      const tevbe41Snippet = 'فٖی سَبٖیلِ اللّٰهِؕ ذٰلِكُمْ';
      const baseStyle = TextStyle(fontSize: 24, color: Colors.black);

      final spans = QuranWordHighlighter.buildHighlightedSpans(
        rawText: tevbe41Snippet,
        baseStyle: baseStyle,
        isDark: false,
        fontFamily: 'AmasyaAbay',
        enabled: true,
      );

      // Find the Lafzatullah text span
      final divineSpan = spans.firstWhere(
        (s) => s is TextSpan && s.text == 'اللّٰهِ',
      ) as TextSpan;
      expect(divineSpan.style?.color, equals(QuranWordHighlighter.lightDivineRed));

      // Find the mapped stop span following Lafzatullah
      final stopSpan = spans.firstWhere(
        (s) => s is TextSpan && (s.text?.contains('\u06DC') ?? false),
      ) as TextSpan;
      expect(stopSpan.style?.color, equals(QuranWordHighlighter.lightWaqfRed));
    });

    test('buildHighlightedSpans appends ZikirceAyahStopMarker when showAyahStopMarker is true', () {
      const v = 'اِنْ كُنْتُمْ تَعْلَمُونَ';
      const baseStyle = TextStyle(fontSize: 24, color: Colors.black);

      final spans = QuranWordHighlighter.buildHighlightedSpans(
        rawText: v,
        baseStyle: baseStyle,
        isDark: false,
        ayahNumber: '41',
        showAyahStopMarker: true,
      );

      final hasWidgetSpan = spans.any((s) => s is WidgetSpan);
      expect(hasWidgetSpan, isTrue);
    });
  });
}
