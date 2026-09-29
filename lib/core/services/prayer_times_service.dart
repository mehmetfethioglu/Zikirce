import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/hijri_calendar.dart';
import 'widget_sync_service.dart';

class PrayerTimings {
  final String fajr; // İmsak
  final String sunrise; // Güneş
  final String dhuhr; // Öğle
  final String asr; // İkindi
  final String maghrib; // Akşam
  final String isha; // Yatsı
  final String date;
  final String? hijriDay;
  final String? hijriMonth;
  final String? hijriYear;

  PrayerTimings({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    this.hijriDay,
    this.hijriMonth,
    this.hijriYear,
  });

  factory PrayerTimings.fromJson(Map<String, dynamic> json, String dateStr, [Map<String, dynamic>? hijriJson]) {
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final calcHijri = HijriDate.fromGregorian(parsedDate);

    String? hDay = json['hijriDay']?.toString() ?? json['HijriDay']?.toString() ?? hijriJson?['day']?.toString();
    String? hMonth = json['hijriMonth']?.toString() ?? json['HijriMonth']?.toString();
    String? hYear = json['hijriYear']?.toString() ?? json['HijriYear']?.toString() ?? hijriJson?['year']?.toString();

    if (hMonth == null && hijriJson != null) {
      final monthNum = int.tryParse(hijriJson['month']?['number']?.toString() ?? '');
      if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
        hMonth = HijriDate.monthNamesTr[monthNum - 1];
      } else {
        final enName = hijriJson['month']?['en']?.toString();
        if (enName != null && enName.isNotEmpty) {
          hMonth = HijriDate.translateMonth(enName);
        }
      }
    } else if (hMonth != null) {
      hMonth = HijriDate.translateMonth(hMonth);
    }

    hDay ??= calcHijri.day.toString();
    hMonth ??= calcHijri.monthName;
    hYear ??= calcHijri.year.toString();

    return PrayerTimings(
      fajr: _cleanTime(json['Fajr']?.toString() ?? json['Imsak']?.toString() ?? json['fajr']?.toString() ?? '04:04'),
      sunrise: _cleanTime(json['Sunrise']?.toString() ?? json['Gunes']?.toString() ?? json['sunrise']?.toString() ?? '05:41'),
      dhuhr: _cleanTime(json['Dhuhr']?.toString() ?? json['Ogle']?.toString() ?? json['dhuhr']?.toString() ?? '12:33'),
      asr: _cleanTime(json['Asr']?.toString() ?? json['Ikindi']?.toString() ?? json['asr']?.toString() ?? '16:15'),
      maghrib: _cleanTime(json['Maghrib']?.toString() ?? json['Aksam']?.toString() ?? json['maghrib']?.toString() ?? '19:14'),
      isha: _cleanTime(json['Isha']?.toString() ?? json['Yatsi']?.toString() ?? json['isha']?.toString() ?? '20:34'),
      date: dateStr,
      hijriDay: hDay,
      hijriMonth: hMonth,
      hijriYear: hYear,
    );
  }

  Map<String, dynamic> toJson() => {
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
    'date': date,
    'hijriDay': hijriDay,
    'hijriMonth': hijriMonth,
    'hijriYear': hijriYear,
  };

  static String _cleanTime(String raw) {
    final match = RegExp(r'\d{2}:\d{2}').firstMatch(raw);
    return match?.group(0) ?? raw;
  }
}

class NextPrayerInfo {
  final String name; // e.g. "İkindi"
  final String nextPrayerNameWithSuffix; // e.g. "İkindi vaktine kalan süre"
  final String time; // e.g. "16:15"
  final Duration remaining;
  final String formattedRemaining; // "00:26:47"
  final double progress; // 0.0 to 1.0 between current and next prayer
  final int activePrayerIndex; // 0: İmsak, 1: Güneş, 2: Öğle, 3: İkindi, 4: Akşam, 5: Yatsı

  NextPrayerInfo({
    required this.name,
    required this.nextPrayerNameWithSuffix,
    required this.time,
    required this.remaining,
    required this.formattedRemaining,
    required this.progress,
    required this.activePrayerIndex,
  });
}

class PrayerTimesService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// All 81 Provinces of Turkey in alphabetical order
  static const List<String> turkishCities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara', 'Antalya', 'Ardahan', 'Artvin',
    'Aydın', 'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul',
    'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale', 'Kırklareli', 'Kırşehir',
    'Kilis', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Şanlıurfa', 'Siirt', 'Sinop',
    'Şırnak', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
  ];

  /// City name mappings for Aladhan API
  static const Map<String, String> cityMappings = {
    'Adana': 'Adana', 'Adıyaman': 'Adiyaman', 'Afyonkarahisar': 'Afyonkarahisar', 'Ağrı': 'Agri',
    'Aksaray': 'Aksaray', 'Amasya': 'Amasya', 'Ankara': 'Ankara', 'Antalya': 'Antalya',
    'Ardahan': 'Ardahan', 'Artvin': 'Artvin', 'Aydın': 'Aydin', 'Balıkesir': 'Balikesir',
    'Bartın': 'Bartin', 'Batman': 'Batman', 'Bayburt': 'Bayburt', 'Bilecik': 'Bilecik',
    'Bingöl': 'Bingol', 'Bitlis': 'Bitlis', 'Bolu': 'Bolu', 'Burdur': 'Burdur',
    'Bursa': 'Bursa', 'Çanakkale': 'Canakkale', 'Çankırı': 'Cankiri', 'Çorum': 'Corum',
    'Denizli': 'Denizli', 'Diyarbakır': 'Diyarbakir', 'Düzce': 'Duzce', 'Edirne': 'Edirne',
    'Elazığ': 'Elazig', 'Erzincan': 'Erzincan', 'Erzurum': 'Erzurum', 'Eskişehir': 'Eskisehir',
    'Gaziantep': 'Gaziantep', 'Giresun': 'Giresun', 'Gümüşhane': 'Gumushane', 'Hakkari': 'Hakkari',
    'Hatay': 'Hatay', 'Iğdır': 'Igdir', 'Isparta': 'Isparta', 'İstanbul': 'Istanbul',
    'İzmir': 'Izmir', 'Kahramanmaraş': 'Kahramanmaras', 'Karabük': 'Karabuk', 'Karaman': 'Karaman',
    'Kars': 'Kars', 'Kastamonu': 'Kastamonu', 'Kayseri': 'Kayseri', 'Kırıkkale': 'Kirikkale',
    'Kırklareli': 'Kirklareli', 'Kırşehir': 'Kirsehir', 'Kilis': 'Kilis', 'Kocaeli': 'Kocaeli',
    'Konya': 'Konya', 'Kütahya': 'Kutahya', 'Malatya': 'Malatya', 'Manisa': 'Manisa',
    'Mardin': 'Mardin', 'Mersin': 'Mersin', 'Muğla': 'Mugla', 'Muş': 'Mus',
    'Nevşehir': 'Nevsehir', 'Niğde': 'Nigde', 'Ordu': 'Ordu', 'Osmaniye': 'Osmaniye',
    'Rize': 'Rize', 'Sakarya': 'Sakarya', 'Samsun': 'Samsun', 'Şanlıurfa': 'Sanliurfa',
    'Siirt': 'Siirt', 'Sinop': 'Sinop', 'Şırnak': 'Sirnak', 'Sivas': 'Sivas',
    'Tekirdağ': 'Tekirdag', 'Tokat': 'Tokat', 'Trabzon': 'Trabzon', 'Tunceli': 'Tunceli',
    'Uşak': 'Usak', 'Van': 'Van', 'Yalova': 'Yalova', 'Yozgat': 'Yozgat', 'Zonguldak': 'Zonguldak'
  };

  /// Geographical Coordinates for precise offline astronomical calculation (Lat, Lng)
  static const Map<String, (double, double)> cityCoordinates = {
    'Adana': (37.0000, 35.3213),
    'Adıyaman': (37.7648, 38.2786),
    'Afyonkarahisar': (38.7507, 30.5567),
    'Ağrı': (39.7191, 43.0503),
    'Aksaray': (38.3687, 34.0370),
    'Amasya': (40.6501, 35.8353),
    'Ankara': (39.9334, 32.8597),
    'Antalya': (36.8848, 30.7056),
    'Ardahan': (41.1105, 42.7022),
    'Artvin': (41.1828, 41.8183),
    'Aydın': (37.8560, 27.8416),
    'Balıkesir': (39.6484, 27.8826),
    'Bartın': (41.6344, 32.3375),
    'Batman': (37.8812, 41.1293),
    'Bayburt': (40.2552, 40.2249),
    'Bilecik': (40.1451, 29.9799),
    'Bingöl': (38.8853, 40.4983),
    'Bitlis': (38.4006, 42.1095),
    'Bolu': (40.7358, 31.6061),
    'Burdur': (37.7203, 30.2908),
    'Bursa': (40.1885, 29.0610),
    'Çanakkale': (40.1553, 26.4142),
    'Çankırı': (40.6013, 33.6134),
    'Çorum': (40.5506, 34.9556),
    'Denizli': (37.7765, 29.0864),
    'Diyarbakır': (37.9144, 40.2110),
    'Düzce': (40.8438, 31.1565),
    'Edirne': (41.6768, 26.5603),
    'Elazığ': (38.6810, 39.2264),
    'Erzincan': (39.7500, 39.5000),
    'Erzurum': (39.9056, 41.2658),
    'Eskişehir': (39.7767, 30.5206),
    'Gaziantep': (37.0662, 37.3833),
    'Giresun': (40.9128, 38.3895),
    'Gümüşhane': (40.4600, 39.4700),
    'Hakkari': (37.5833, 43.7333),
    'Hatay': (36.2023, 36.1613),
    'Iğdır': (39.9200, 44.0400),
    'Isparta': (37.7648, 30.5566),
    'İstanbul': (41.0082, 28.9784),
    'İzmir': (38.4192, 27.1287),
    'Kahramanmaraş': (37.5858, 36.9371),
    'Karabük': (41.2061, 32.6204),
    'Karaman': (37.1759, 33.2287),
    'Kars': (40.6013, 43.0975),
    'Kastamonu': (41.3887, 33.7827),
    'Kayseri': (38.7205, 35.4826),
    'Kırıkkale': (39.8468, 33.5153),
    'Kırklareli': (41.7355, 27.2252),
    'Kırşehir': (39.1425, 34.1709),
    'Kilis': (36.7184, 37.1212),
    'Kocaeli': (40.8533, 29.8815),
    'Konya': (37.8714, 32.4847),
    'Kütahya': (39.4167, 29.9833),
    'Malatya': (38.3552, 38.3095),
    'Manisa': (38.6191, 27.4289),
    'Mardin': (37.3212, 40.7245),
    'Mersin': (36.8121, 34.6415),
    'Muğla': (37.2153, 28.3636),
    'Muş': (38.7432, 41.5064),
    'Nevşehir': (38.6244, 34.7144),
    'Niğde': (37.9667, 34.6833),
    'Ordu': (40.9839, 37.8764),
    'Osmaniye': (37.0742, 36.2478),
    'Rize': (41.0201, 40.5234),
    'Sakarya': (40.7569, 30.3783),
    'Samsun': (41.2867, 36.3300),
    'Şanlıurfa': (37.1674, 38.7955),
    'Siirt': (37.9333, 41.9500),
    'Sinop': (42.0231, 35.1531),
    'Şırnak': (37.5164, 42.4594),
    'Sivas': (39.7477, 36.9934),
    'Tekirdağ': (40.9833, 27.5167),
    'Tokat': (40.3167, 36.5500),
    'Trabzon': (41.0027, 39.7168),
    'Tunceli': (39.1079, 39.5401),
    'Uşak': (38.6823, 29.4082),
    'Van': (38.5012, 43.3730),
    'Yalova': (40.6500, 29.2667),
    'Yozgat': (39.8181, 34.8147),
    'Zonguldak': (41.4564, 31.7987)
  };

  /// Fetches prayer times from Aladhan API (Diyanet Method 13) with cache and offline calculator fallback
  static Future<PrayerTimings> getPrayerTimes({String city = 'İstanbul'}) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = 'prayer_times_${city}_$todayStr';

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);

    PrayerTimings result;
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        result = PrayerTimings.fromJson(map, todayStr);
        return result;
      } catch (_) {}
    }

    try {
      final apiCity = cityMappings[city] ?? city;
      final url = 'https://api.aladhan.com/v1/timingsByCity?city=${Uri.encodeComponent(apiCity)}&country=Turkey&method=13';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data['data'] != null) {
        final timingsMap = response.data['data']['timings'] as Map<String, dynamic>;
        final hijriMap = response.data['data']['date']?['hijri'] as Map<String, dynamic>?;
        result = PrayerTimings.fromJson(timingsMap, todayStr, hijriMap);
        await prefs.setString(cacheKey, jsonEncode(result.toJson()));
        return result;
      }
    } catch (e) {
      // API fetch failed, fallback to offline calculation
    }

    // Offline astronomical calculation for Turkey
    result = calculateOfflinePrayerTimes(city, now);
    return result;
  }

  /// Calculates astronomical prayer times using solar declination & equation of time
  static PrayerTimings calculateOfflinePrayerTimes(String city, DateTime date) {
    final coords = cityCoordinates[city] ?? const (39.9334, 32.8597); // Ankara fallback
    final lat = coords.$1;
    final lng = coords.$2;

    final dayOfYear = int.parse(
      DateTime(date.year, date.month, date.day)
          .difference(DateTime(date.year, 1, 1))
          .inDays
          .toString(),
    ) + 1;

    final fractionalYear = (2 * math.pi / 365.0) * (dayOfYear - 1 + (date.hour - 12) / 24.0);

    // Equation of Time (minutes)
    final eqt = 229.18 * (0.000075 + 0.001868 * math.cos(fractionalYear) 
               - 0.032077 * math.sin(fractionalYear) 
               - 0.014615 * math.cos(2 * fractionalYear) 
               - 0.040849 * math.sin(2 * fractionalYear));

    // Solar Declination (radians)
    final declination = 0.006918 - 0.399912 * math.cos(fractionalYear) 
                        + 0.070257 * math.sin(fractionalYear) 
                        - 0.006758 * math.cos(2 * fractionalYear) 
                        + 0.000907 * math.sin(2 * fractionalYear) 
                        - 0.002697 * math.cos(3 * fractionalYear) 
                        + 0.00148 * math.sin(3 * fractionalYear);

    final latRad = lat * math.pi / 180.0;
    const zoneOffset = 3.0; // Turkey UTC+3

    // Solar Noon (Öğle) in hours
    final solarNoon = 12.0 + zoneOffset - (lng / 15.0) - (eqt / 60.0);

    // Sunrise & Sunset (90.833° zenith)
    const zenithSunrise = 90.833 * math.pi / 180.0;
    var cosH = (math.cos(zenithSunrise) - math.sin(latRad) * math.sin(declination)) / (math.cos(latRad) * math.cos(declination));
    cosH = cosH.clamp(-1.0, 1.0);
    final hSunrise = math.acos(cosH) * 180.0 / math.pi;

    final sunrise = solarNoon - (hSunrise / 15.0);
    final sunset = solarNoon + (hSunrise / 15.0);

    // Fajr / İmsak (18° below horizon -> 108°)
    const zenithFajr = 108.0 * math.pi / 180.0;
    var cosHFajr = (math.cos(zenithFajr) - math.sin(latRad) * math.sin(declination)) / (math.cos(latRad) * math.cos(declination));
    cosHFajr = cosHFajr.clamp(-1.0, 1.0);
    final hFajr = math.acos(cosHFajr) * 180.0 / math.pi;
    final fajr = solarNoon - (hFajr / 15.0);

    // Isha / Yatsı (17° below horizon -> 107°)
    const zenithIsha = 107.0 * math.pi / 180.0;
    var cosHIsha = (math.cos(zenithIsha) - math.sin(latRad) * math.sin(declination)) / (math.cos(latRad) * math.cos(declination));
    cosHIsha = cosHIsha.clamp(-1.0, 1.0);
    final hIsha = math.acos(cosHIsha) * 180.0 / math.pi;
    final isha = solarNoon + (hIsha / 15.0);

    // Asr / İkindi (Shafi'i shadow length = 1)
    final asrAngle = math.atan(1.0 + math.tan((latRad - declination).abs()));
    var cosHAsr = (math.sin(asrAngle) - math.sin(latRad) * math.sin(declination)) / (math.cos(latRad) * math.cos(declination));
    cosHAsr = cosHAsr.clamp(-1.0, 1.0);
    final hAsr = math.acos(cosHAsr) * 180.0 / math.pi;
    final asr = solarNoon + (hAsr / 15.0);

    String formatHour(double decimalHour) {
      var h = decimalHour.floor();
      var m = ((decimalHour - h) * 60).round();
      if (m >= 60) {
        h += 1;
        m -= 60;
      }
      h = h % 24;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final todayStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final hijri = HijriDate.fromGregorian(date);

    return PrayerTimings(
      fajr: formatHour(fajr),
      sunrise: formatHour(sunrise),
      dhuhr: formatHour(solarNoon),
      asr: formatHour(asr),
      maghrib: formatHour(sunset),
      isha: formatHour(isha),
      date: todayStr,
      hijriDay: hijri.day.toString(),
      hijriMonth: hijri.monthName,
      hijriYear: hijri.year.toString(),
    );
  }

  /// Calculates the next prayer, remaining duration, formatted timer (00:26:47), and progress fraction
  static NextPrayerInfo getNextPrayerInfo(PrayerTimings timings) {
    final now = DateTime.now();

    DateTime parseTime(String hhmm, [bool nextDay = false]) {
      final parts = hhmm.split(':');
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      var d = DateTime(now.year, now.month, now.day, h, m, 0, 0);
      if (nextDay) d = d.add(const Duration(days: 1));
      return d;
    }

    final tFajr = parseTime(timings.fajr);
    final tSunrise = parseTime(timings.sunrise);
    final tDhuhr = parseTime(timings.dhuhr);
    final tAsr = parseTime(timings.asr);
    final tMaghrib = parseTime(timings.maghrib);
    final tIsha = parseTime(timings.isha);
    final tNextFajr = parseTime(timings.fajr, true);

    String nextName;
    String nextSuffix;
    String nextTime;
    Duration remaining;
    DateTime prevPrayerTime;
    DateTime targetPrayerTime;
    int activeIdx;

    if (now.isBefore(tFajr)) {
      nextName = 'İmsak';
      nextSuffix = 'İmsak vaktine kalan süre';
      nextTime = timings.fajr;
      remaining = tFajr.difference(now);
      prevPrayerTime = parseTime(timings.isha).subtract(const Duration(days: 1));
      targetPrayerTime = tFajr;
      activeIdx = 5; // Yatsı period
    } else if (now.isBefore(tSunrise)) {
      nextName = 'Güneş';
      nextSuffix = 'Güneş vaktine kalan süre';
      nextTime = timings.sunrise;
      remaining = tSunrise.difference(now);
      prevPrayerTime = tFajr;
      targetPrayerTime = tSunrise;
      activeIdx = 0; // İmsak period
    } else if (now.isBefore(tDhuhr)) {
      nextName = 'Öğle';
      nextSuffix = 'Öğle vaktine kalan süre';
      nextTime = timings.dhuhr;
      remaining = tDhuhr.difference(now);
      prevPrayerTime = tSunrise;
      targetPrayerTime = tDhuhr;
      activeIdx = 1; // Güneş period
    } else if (now.isBefore(tAsr)) {
      nextName = 'İkindi';
      nextSuffix = 'İkindi vaktine kalan süre';
      nextTime = timings.asr;
      remaining = tAsr.difference(now);
      prevPrayerTime = tDhuhr;
      targetPrayerTime = tAsr;
      activeIdx = 2; // Öğle period
    } else if (now.isBefore(tMaghrib)) {
      nextName = 'Akşam';
      nextSuffix = 'Akşam vaktine kalan süre';
      nextTime = timings.maghrib;
      remaining = tMaghrib.difference(now);
      prevPrayerTime = tAsr;
      targetPrayerTime = tMaghrib;
      activeIdx = 3; // İkindi period
    } else if (now.isBefore(tIsha)) {
      nextName = 'Yatsı';
      nextSuffix = 'Yatsı vaktine kalan süre';
      nextTime = timings.isha;
      remaining = tIsha.difference(now);
      prevPrayerTime = tMaghrib;
      targetPrayerTime = tIsha;
      activeIdx = 4; // Akşam period
    } else {
      nextName = 'İmsak';
      nextSuffix = 'İmsak vaktine kalan süre';
      nextTime = timings.fajr;
      remaining = tNextFajr.difference(now);
      prevPrayerTime = tIsha;
      targetPrayerTime = tNextFajr;
      activeIdx = 5; // Yatsı period
    }

    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final totalIntervalMs = targetPrayerTime.difference(prevPrayerTime).inMilliseconds;
    final elapsedMs = now.difference(prevPrayerTime).inMilliseconds;
    final progress = totalIntervalMs > 0 ? (elapsedMs / totalIntervalMs).clamp(0.0, 1.0) : 0.0;

    final totalSec = safeRemaining.inSeconds;
    final hours = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSec % 60).toString().padLeft(2, '0');
    final formattedTimer = '$hours:$minutes:$seconds';

    return NextPrayerInfo(
      name: nextName,
      nextPrayerNameWithSuffix: nextSuffix,
      time: nextTime,
      remaining: safeRemaining,
      formattedRemaining: formattedTimer,
      progress: progress,
      activePrayerIndex: activeIdx,
    );
  }

  /// Calculates Qibla direction in degrees (0 - 360) from user latitude & longitude to Mecca
  static double calculateQiblaDirection(double lat, double lng) {
    const kaabaLat = 21.4225 * math.pi / 180.0;
    const kaabaLng = 39.8262 * math.pi / 180.0;
    final userLat = lat * math.pi / 180.0;
    final userLng = lng * math.pi / 180.0;

    final y = math.sin(kaabaLng - userLng);
    final x = math.cos(userLat) * math.tan(kaabaLat) - math.sin(userLat) * math.cos(kaabaLng - userLng);
    var qibla = math.atan2(y, x) * 180.0 / math.pi;
    return (qibla + 360) % 360;
  }
}
