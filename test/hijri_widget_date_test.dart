import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/utils/hijri_calendar.dart';
import 'package:zikirce/core/services/prayer_times_service.dart';
import 'package:zikirce/core/services/widget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hijri Date & Widget Sync Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('August 2026 converts to Rebiülevvel 1448', () {
      final date = DateTime(2026, 8, 26);
      final hijri = HijriDate.fromGregorian(date);

      expect(hijri.year, equals(1448));
      expect(hijri.month, equals(3));
      expect(hijri.monthName, equals('Rebiülevvel'));
      expect(hijri.day, inInclusiveRange(1, 30));
    });

    test('HijriDate.translateMonth correctly maps Aladhan API month names to Turkish', () {
      expect(HijriDate.translateMonth('Muharram'), equals('Muharrem'));
      expect(HijriDate.translateMonth('Safar'), equals('Safer'));
      expect(HijriDate.translateMonth("Rabi' al-awwal"), equals('Rebiülevvel'));
      expect(HijriDate.translateMonth('Rabiul Awwal'), equals('Rebiülevvel'));
      expect(HijriDate.translateMonth("Rabi' al-thani"), equals('Rebiülahir'));
      expect(HijriDate.translateMonth('Jumada al-awwal'), equals('Cemaziyelevvel'));
      expect(HijriDate.translateMonth('Jumada al-thani'), equals('Cemaziyelahir'));
      expect(HijriDate.translateMonth('Rajab'), equals('Recep'));
      expect(HijriDate.translateMonth("Sha'ban"), equals('Şaban'));
      expect(HijriDate.translateMonth('Ramadan'), equals('Ramazan'));
      expect(HijriDate.translateMonth('Shawwal'), equals('Şevval'));
      expect(HijriDate.translateMonth("Dhu al-Qi'dah"), equals('Zilkade'));
      expect(HijriDate.translateMonth('Dhu al-Hijjah'), equals('Zilhicce'));
    });

    test('PrayerTimings.fromJson dynamically populates Hijri date without hardcoded fallback', () {
      final timingsMap = {
        'Fajr': '04:12',
        'Sunrise': '05:48',
        'Dhuhr': '13:08',
        'Asr': '16:54',
        'Maghrib': '20:18',
        'Isha': '21:46',
      };

      // 1. Without hijriJson (uses astronomical calculation from dateStr)
      final timing1 = PrayerTimings.fromJson(timingsMap, '2026-08-26');
      expect(timing1.hijriMonth, equals('Rebiülevvel'));
      expect(timing1.hijriYear, equals('1448'));

      // 2. With English hijriJson from Aladhan API
      final hijriJson = {
        'day': '13',
        'month': {'number': 3, 'en': "Rabi' al-awwal"},
        'year': '1448',
      };
      final timing2 = PrayerTimings.fromJson(timingsMap, '2026-08-26', hijriJson);
      expect(timing2.hijriDay, equals('13'));
      expect(timing2.hijriMonth, equals('Rebiülevvel'));
      expect(timing2.hijriYear, equals('1448'));
    });

    test('WidgetSyncService.syncPrayerTimes synchronizes dynamic Hijri date to SharedPreferences', () async {
      final timings = PrayerTimesService.calculateOfflinePrayerTimes('İstanbul', DateTime(2026, 8, 26));
      expect(timings.hijriMonth, equals('Rebiülevvel'));

      await WidgetSyncService.syncPrayerTimes(city: 'İstanbul', timings: timings);

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('CachedPrayerTimes_İstanbul');
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('Rebiülevvel'));
      expect(cachedJson, isNot(contains('Zilhicce')));
    });
  });
}
