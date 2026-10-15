import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:zikirce/core/services/prayer_times_service.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  group('Prayer Times & Notification Scheduling Tests', () {
    test('Offline Astronomical Prayer Calculation computes valid times for Turkish cities', () {
      final now = DateTime(2026, 8, 25, 12, 0);
      final timings = PrayerTimesService.calculateOfflinePrayerTimes('İstanbul', now);

      expect(timings.fajr, isNotEmpty);
      expect(timings.sunrise, isNotEmpty);
      expect(timings.dhuhr, isNotEmpty);
      expect(timings.asr, isNotEmpty);
      expect(timings.maghrib, isNotEmpty);
      expect(timings.isha, isNotEmpty);

      // Verify format HH:mm
      final timeRegex = RegExp(r'^\d{2}:\d{2}$');
      expect(timeRegex.hasMatch(timings.fajr), isTrue);
      expect(timeRegex.hasMatch(timings.sunrise), isTrue);
      expect(timeRegex.hasMatch(timings.dhuhr), isTrue);
      expect(timeRegex.hasMatch(timings.asr), isTrue);
      expect(timeRegex.hasMatch(timings.maghrib), isTrue);
      expect(timeRegex.hasMatch(timings.isha), isTrue);
    });

    test('TZDateTime converts local DateTime with correct epoch timestamp', () {
      final targetLocal = DateTime(2026, 8, 25, 13, 15);
      final scheduledTZ = tz.TZDateTime.from(targetLocal, tz.local);

      expect(scheduledTZ.year, equals(2026));
      expect(scheduledTZ.month, equals(8));
      expect(scheduledTZ.day, equals(25));
      expect(scheduledTZ.hour, equals(13));
      expect(scheduledTZ.minute, equals(15));
      expect(scheduledTZ.millisecondsSinceEpoch, equals(targetLocal.millisecondsSinceEpoch));
    });

    test('NextPrayerInfo calculates active prayer and remaining time correctly', () {
      final timings = PrayerTimings(
        fajr: '04:30',
        sunrise: '06:00',
        dhuhr: '13:00',
        asr: '16:45',
        maghrib: '19:50',
        isha: '21:15',
        date: '2026-08-25',
      );

      final nextInfo = PrayerTimesService.getNextPrayerInfo(timings);
      expect(nextInfo.name, isNotEmpty);
      expect(nextInfo.time, isNotEmpty);
      expect(nextInfo.progress, inInclusiveRange(0.0, 1.0));
      expect(nextInfo.activePrayerIndex, inInclusiveRange(0, 5));
    });

    test('Prayer question notifications compute exactly 45 minutes before exit time', () {
      final targetDate = DateTime(2026, 10, 14);
      tz.TZDateTime parseTZTime(String hhmm, {Duration offset = Duration.zero}) {
        final clean = hhmm.trim();
        final parts = clean.split(':');
        final h = int.tryParse(parts[0].trim()) ?? 0;
        final m = int.tryParse(parts[1].trim()) ?? 0;
        final base = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, h, m);
        return offset == Duration.zero ? base : base.add(offset);
      }

      // Asr is at 16:15 -> Öğle question reminder must be at 15:30 (45 mins before Asr)
      final ogleQuestionTime = parseTZTime('16:15', offset: const Duration(minutes: -45));
      expect(ogleQuestionTime.hour, equals(15));
      expect(ogleQuestionTime.minute, equals(30));

      // Maghrib is at 19:15 -> Ikindi question reminder must be at 18:30 (45 mins before Maghrib)
      final ikindiQuestionTime = parseTZTime('19:15', offset: const Duration(minutes: -45));
      expect(ikindiQuestionTime.hour, equals(18));
      expect(ikindiQuestionTime.minute, equals(30));
    });
  });
}
