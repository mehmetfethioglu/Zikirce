import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/utils/arabic_normalizer.dart';
import 'package:zikirce/core/utils/hijri_calendar.dart';
import 'package:zikirce/core/utils/spaced_repetition_sm2.dart';
import 'package:zikirce/core/services/prayer_times_service.dart';

void main() {
  group('Core Unit & Domain Tests', () {
    test('Arabic Normalizer removes tashkeel and normalizes alefs', () {
      const rawText = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ';
      final clean = ArabicNormalizer.removeTashkeel(rawText);
      expect(clean, contains('بسم'));
      expect(clean, contains('الله'));

      const searchTarget = 'إِيَّاكَ نَعْبُدُ';
      expect(ArabicNormalizer.containsMatch(searchTarget, 'اياك'), isTrue);
    });

    test('Hijri Calendar conversion generates valid dates', () {
      final date = DateTime(2026, 8, 21);
      final hijri = HijriDate.fromGregorian(date);
      expect(hijri.year, greaterThan(1440));
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.day, inInclusiveRange(1, 30));
      expect(hijri.monthName.isNotEmpty, isTrue);
    });

    test('SM-2 Spaced Repetition calculates correct next interval', () {
      // First review with perfect quality (5)
      final step1 = SpacedRepetitionSm2.calculate(
        quality: 5,
        previousRepetitions: 0,
        previousIntervalDays: 0,
      );
      expect(step1.repetitions, equals(1));
      expect(step1.intervalDays, equals(1));

      // Second review with good quality (4)
      final step2 = SpacedRepetitionSm2.calculate(
        quality: 4,
        previousRepetitions: step1.repetitions,
        previousIntervalDays: step1.intervalDays,
        previousEaseFactor: step1.easeFactor,
      );
      expect(step2.repetitions, equals(2));
      expect(step2.intervalDays, equals(6));
    });

    test('Qibla angle calculation computes correct azimuth for Istanbul', () {
      // Istanbul: ~41.0° N, 28.97° E -> Qibla is roughly 150° - 155°
      final qibla = PrayerTimesService.calculateQiblaDirection(41.0082, 28.9784);
      expect(qibla, inInclusiveRange(145.0, 160.0));
    });
  });
}
