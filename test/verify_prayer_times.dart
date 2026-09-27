import 'package:zikirce/core/services/prayer_times_service.dart';

void main() {
  print('=== PRAYER TIMES & 81 CITIES VERIFICATION ===');

  // 1. Verify 81 Turkish cities count
  print('Turkish Cities Count: ${PrayerTimesService.turkishCities.length}');
  assert(PrayerTimesService.turkishCities.length == 81, 'Must have exactly 81 Turkish cities');
  print('✅ 81 Cities verified in list.');

  // 2. Verify all 81 cities have coordinates and API mappings
  for (final city in PrayerTimesService.turkishCities) {
    assert(PrayerTimesService.cityCoordinates.containsKey(city), 'Missing coordinates for $city');
    assert(PrayerTimesService.cityMappings.containsKey(city), 'Missing API mapping for $city');
  }
  print('✅ All 81 cities have valid coordinates and API mappings.');

  // 3. Test Offline Prayer Calculation for 'Şanlıurfa'
  final sanliurfaTimes = PrayerTimesService.calculateOfflinePrayerTimes('Şanlıurfa', DateTime(2026, 8, 23, 15, 48));
  print('Şanlıurfa Times -> İmsak: ${sanliurfaTimes.fajr}, Güneş: ${sanliurfaTimes.sunrise}, Öğle: ${sanliurfaTimes.dhuhr}, İkindi: ${sanliurfaTimes.asr}, Akşam: ${sanliurfaTimes.maghrib}, Yatsı: ${sanliurfaTimes.isha}');
  assert(sanliurfaTimes.fajr.contains(':'), 'Fajr must be formatted');
  assert(sanliurfaTimes.dhuhr.contains(':'), 'Dhuhr must be formatted');
  assert(sanliurfaTimes.asr.contains(':'), 'Asr must be formatted');
  print('✅ Şanlıurfa calculation verified.');

  // 4. Test NextPrayerInfo computation
  final nextInfo = PrayerTimesService.getNextPrayerInfo(sanliurfaTimes);
  print('Next Prayer: ${nextInfo.name}, Suffix: ${nextInfo.nextPrayerNameWithSuffix}, Time: ${nextInfo.time}, Formatted: ${nextInfo.formattedRemaining}, Progress: ${(nextInfo.progress * 100).toStringAsFixed(1)}%');
  assert(nextInfo.formattedRemaining.split(':').length == 3, 'Formatted timer must be HH:mm:ss');
  print('✅ Countdown and Progress calculation verified.');

  // 5. Test Qibla Calculation for Istanbul & Sanliurfa
  final istanbulQibla = PrayerTimesService.calculateQiblaDirection(41.0082, 28.9784);
  final urfaQibla = PrayerTimesService.calculateQiblaDirection(37.1674, 38.7955);
  print('Istanbul Qibla: ${istanbulQibla.toStringAsFixed(1)}°, Sanliurfa Qibla: ${urfaQibla.toStringAsFixed(1)}°');
  assert(istanbulQibla > 140 && istanbulQibla < 165, 'Istanbul Qibla angle out of expected range');
  assert(urfaQibla > 170 && urfaQibla < 205, 'Sanliurfa Qibla angle out of expected range');
  print('✅ Qibla angles verified.');

  print('=== ALL PRAYER TIMES TESTS PASSED SUCCESSFULLY! ===');
}
