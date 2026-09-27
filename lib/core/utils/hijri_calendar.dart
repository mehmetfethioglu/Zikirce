class HijriDate {
  final int year;
  final int month;
  final int day;
  final String monthName;

  HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
  });

  static const List<String> monthNamesTr = [
    'Muharrem',
    'Safer',
    'Rebiülevvel',
    'Rebiülahir',
    'Cemaziyelevvel',
    'Cemaziyelahir',
    'Recep',
    'Şaban',
    'Ramazan',
    'Şevval',
    'Zilkade',
    'Zilhicce',
  ];

  static const List<String> monthNamesEn = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];

  /// Translates API English Hijri month names or numeric indices to standard Turkish month names
  static String translateMonth(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('muharram') || lower.contains('muharrem')) return 'Muharrem';
    if (lower.contains('safar') || lower.contains('safer')) return 'Safer';
    if (lower.contains('rabi')) {
      if (lower.contains('thani') || lower.contains('ahir') || lower.contains('sani') || lower.contains('2') || lower.contains('ii')) {
        return 'Rebiülahir';
      }
      return 'Rebiülevvel';
    }
    if (lower.contains('jumada') || lower.contains('cemazi')) {
      if (lower.contains('thani') || lower.contains('ahir') || lower.contains('sani') || lower.contains('2') || lower.contains('ii')) {
        return 'Cemaziyelahir';
      }
      return 'Cemaziyelevvel';
    }
    if (lower.contains('rajab') || lower.contains('recep')) return 'Recep';
    if (lower.contains('sha\'ban') || lower.contains('shaban') || lower.contains('saban') || lower.contains('şaban') || lower.contains('sha’ban') || lower.contains('shaaban')) return 'Şaban';
    if (lower.contains('ramad') || lower.contains('ramazan')) return 'Ramazan';
    if (lower.contains('shawwal') || lower.contains('sevval') || lower.contains('şevval')) return 'Şevval';
    if (lower.contains('qad') || lower.contains('kade') || lower.contains('qi\'dah') || lower.contains('qidah') || lower.contains('zilkade')) return 'Zilkade';
    if (lower.contains('hij') || lower.contains('hicce') || lower.contains('hijjah') || lower.contains('zilhicce')) return 'Zilhicce';
    return raw;
  }

  /// Convert Gregorian DateTime to Hijri Date using astronomical Umm al-Qura approximation
  static HijriDate fromGregorian(DateTime date) {
    double jd = _gregorianToJulian(date.year, date.month, date.day);
    return _julianToHijri(jd);
  }

  static double _gregorianToJulian(int year, int month, int day) {
    if (month < 3) {
      year -= 1;
      month += 12;
    }
    double a = (year / 100).floorToDouble();
    double b = 2 - a + (a / 4).floorToDouble();
    return (365.25 * (year + 4716)).floorToDouble() +
        (30.6001 * (month + 1)).floorToDouble() +
        day +
        b -
        1524.5;
  }

  static HijriDate _julianToHijri(double jd) {
    jd = jd.floorToDouble() + 0.5;
    double l = jd - 1948440 + 10632;
    double n = ((l - 1) / 10631).floorToDouble();
    l = l - 10631 * n + 354;
    double j = ((10985 - l) / 5316).floorToDouble() * ((50 * l) / 17719).floorToDouble() +
        (l / 5670).floorToDouble() * ((43 * l) / 15238).floorToDouble();
    l = l - ((30 - j) / 15).floorToDouble() * ((17719 * j) / 50).floorToDouble() -
        (j / 16).floorToDouble() * ((15238 * j) / 43).floorToDouble() +
        29;
    int m = ((24 * l) / 709).floor();
    int d = (l - ((709 * m) / 24).floor()).floor();
    int y = (30 * n + j - 30).floor();

    // Bound check
    int safeMonth = m.clamp(1, 12);
    String mName = monthNamesTr[safeMonth - 1];

    return HijriDate(
      year: y,
      month: safeMonth,
      day: d.clamp(1, 30),
      monthName: mName,
    );
  }

  String format({bool includeYear = true}) {
    if (includeYear) {
      return '$day $monthName $year';
    }
    return '$day $monthName';
  }
}
