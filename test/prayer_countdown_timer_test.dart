import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/services/prayer_times_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prayer Countdown Timer & Stability Tests', () {
    final timings = PrayerTimings(
      fajr: '04:12',
      sunrise: '05:48',
      dhuhr: '13:08',
      asr: '16:54',
      maghrib: '20:18',
      isha: '21:46',
      date: '2026-08-31',
    );

    test('getNextPrayerInfo produces valid non-negative formatted remaining time', () {
      final info = PrayerTimesService.getNextPrayerInfo(timings);

      expect(info.name, isNotEmpty);
      expect(info.time, isNotEmpty);
      expect(info.remaining.isNegative, isFalse);
      expect(info.formattedRemaining.contains('-'), isFalse, reason: 'Countdown timer must never contain negative minus signs');
      expect(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(info.formattedRemaining), isTrue);
      expect(info.progress, greaterThanOrEqualTo(0.0));
      expect(info.progress, lessThanOrEqualTo(1.0));
      expect(info.activePrayerIndex, inInclusiveRange(0, 5));
    });

    test('calculateOfflinePrayerTimes produces valid timings for all Turkish cities', () {
      final now = DateTime.now();
      for (final city in ['İstanbul', 'Ankara', 'İzmir', 'Şanlıurfa', 'Bursa']) {
        final offline = PrayerTimesService.calculateOfflinePrayerTimes(city, now);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.fajr), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.sunrise), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.dhuhr), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.asr), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.maghrib), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(offline.isha), isTrue);

        final nextInfo = PrayerTimesService.getNextPrayerInfo(offline);
        expect(nextInfo.remaining.isNegative, isFalse);
        expect(nextInfo.formattedRemaining.contains('-'), isFalse);
        expect(nextInfo.progress, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Zero and sub-zero remaining duration is clamped safely to Duration.zero', () {
      final info = PrayerTimesService.getNextPrayerInfo(timings);
      expect(info.remaining >= Duration.zero, isTrue);
      final hours = int.parse(info.formattedRemaining.split(':')[0]);
      final minutes = int.parse(info.formattedRemaining.split(':')[1]);
      final seconds = int.parse(info.formattedRemaining.split(':')[2]);
      expect(hours >= 0, isTrue);
      expect(minutes, inInclusiveRange(0, 59));
      expect(seconds, inInclusiveRange(0, 59));
    });
  });
}
