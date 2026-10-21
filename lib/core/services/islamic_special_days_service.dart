import 'package:flutter/foundation.dart';
import '../utils/hijri_calendar.dart';

/// Representation of an Islamic Special Occasion / Day
@immutable
class IslamicSpecialDay {
  final String id;
  final String titleTr;
  final String titleEn;
  final String greetingTr;
  final String greetingEn;
  final String emoji;
  final String descriptionTr;

  const IslamicSpecialDay({
    required this.id,
    required this.titleTr,
    required this.titleEn,
    required this.greetingTr,
    required this.greetingEn,
    required this.emoji,
    required this.descriptionTr,
  });

  static const IslamicSpecialDay cuma = IslamicSpecialDay(
    id: 'cuma',
    titleTr: 'Cuma Günü',
    titleEn: 'Friday (Jumu\'ah)',
    greetingTr: 'Hayırlı Cumalar',
    greetingEn: 'Blessed Friday',
    emoji: '🕌',
    descriptionTr: 'Müminlerin bayramı, duaların kabul olduğu mübarek Cuma günü.',
  );

  static const IslamicSpecialDay regaip = IslamicSpecialDay(
    id: 'regaip',
    titleTr: 'Regaip Kandili',
    titleEn: 'Laylat al-Raghaib',
    greetingTr: 'Regaip Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Regaip Night',
    emoji: '✨',
    descriptionTr: 'Üç ayların ilk müjdecisi, rahmet ve mağfiret gecesi.',
  );

  static const IslamicSpecialDay mirac = IslamicSpecialDay(
    id: 'mirac',
    titleTr: 'Miraç Kandili',
    titleEn: 'Laylat al-Mi\'raj',
    greetingTr: 'Miraç Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Mi\'raj Night',
    emoji: '🌌',
    descriptionTr: 'Peygamber Efendimiz\'in (s.a.v.) ilahi huzura yükseldiği mübarek gece.',
  );

  static const IslamicSpecialDay berat = IslamicSpecialDay(
    id: 'berat',
    titleTr: 'Berat Kandili',
    titleEn: 'Laylat al-Bara\'at',
    greetingTr: 'Berat Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Berat Night',
    emoji: '🕊️',
    descriptionTr: 'Günahlardan arınma, af ve beraat gecesi.',
  );

  static const IslamicSpecialDay kadir = IslamicSpecialDay(
    id: 'kadir',
    titleTr: 'Kadir Gecesi',
    titleEn: 'Laylat al-Qadr',
    greetingTr: 'Kadir Geceniz Mübarek Olsun',
    greetingEn: 'Blessed Night of Power',
    emoji: '🌟',
    descriptionTr: 'Bin aydan daha hayırlı olan, Kur\'an-ı Kerim\'in indirildiği kutlu gece.',
  );

  static const IslamicSpecialDay mevlid = IslamicSpecialDay(
    id: 'mevlid',
    titleTr: 'Mevlid Kandili',
    titleEn: 'Mawlid al-Nabi',
    greetingTr: 'Mevlid Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Mawlid Night',
    emoji: '🌸',
    descriptionTr: 'Alemlere rahmet olarak gönderilen Efendimiz\'in (s.a.v.) dünyayı teşrifi.',
  );

  static const IslamicSpecialDay ramazan = IslamicSpecialDay(
    id: 'ramazan',
    titleTr: 'Ramazan-ı Şerif',
    titleEn: 'Holy Ramadan',
    greetingTr: 'Hayırlı Ramazanlar',
    greetingEn: 'Ramadan Mubarak',
    emoji: '🌙',
    descriptionTr: 'On bir ayın sultanı, oruç, Kur\'an ve rahmet ayı.',
  );

  static const IslamicSpecialDay ramazanBayrami = IslamicSpecialDay(
    id: 'ramazan_bayrami',
    titleTr: 'Ramazan Bayramı',
    titleEn: 'Eid al-Fitr',
    greetingTr: 'Ramazan Bayramınız Mübarek Olsun',
    greetingEn: 'Eid Mubarak',
    emoji: '🎉',
    descriptionTr: 'Ramazan-ı Şerif\'in mükâfatı, sevinç ve kardeşlik bayramı.',
  );

  static const IslamicSpecialDay kurbanBayrami = IslamicSpecialDay(
    id: 'kurban_bayrami',
    titleTr: 'Kurban Bayramı',
    titleEn: 'Eid al-Adha',
    greetingTr: 'Kurban Bayramınız Mübarek Olsun',
    greetingEn: 'Eid al-Adha Mubarak',
    emoji: '🐑',
    descriptionTr: 'Allah\'a yakınlaşma, fedakarlık ve hac günleri.',
  );

  static const IslamicSpecialDay asure = IslamicSpecialDay(
    id: 'asure',
    titleTr: 'Aşure Günü',
    titleEn: 'Day of Ashura',
    greetingTr: 'Aşure Gününüz Mübarek Olsun',
    greetingEn: 'Blessed Day of Ashura',
    emoji: '🥣',
    descriptionTr: 'Muharrem ayının 10. günü, birçok peygamberin kurtuluşa erdiği gün.',
  );

  static const IslamicSpecialDay hicriYilbasi = IslamicSpecialDay(
    id: 'hicri_yilbasi',
    titleTr: 'Hicri Yılbaşı',
    titleEn: 'Islamic New Year',
    greetingTr: 'Hicri Yılbaşınız Mübarek Olsun',
    greetingEn: 'Happy Islamic New Year',
    emoji: '🗓️',
    descriptionTr: '1 Muharrem, Peygamberimiz\'in kutlu hicreti ve yeni hicri yıl başlangıcı.',
  );

  static const IslamicSpecialDay kandil = IslamicSpecialDay(
    id: 'kandil_genel',
    titleTr: 'Kandil Gecesi',
    titleEn: 'Blessed Kandil Night',
    greetingTr: 'Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Kandil Night',
    emoji: '✨',
    descriptionTr: 'Mübarek kandil gecesi tebriği.',
  );

  static const IslamicSpecialDay ucAylar = IslamicSpecialDay(
    id: 'uc_aylar',
    titleTr: 'Üç Aylar',
    titleEn: 'The Three Sacred Months',
    greetingTr: 'Üç Aylarınız Mübarek Olsun',
    greetingEn: 'Blessed Three Sacred Months',
    emoji: '💫',
    descriptionTr: 'Recep, Şaban ve Ramazan ayları; manevi bereket mevsimi.',
  );
}

/// Service that automatically detects Islamic occasions based on current or selected dates
class IslamicSpecialDaysService {
  IslamicSpecialDaysService._();

  static const List<IslamicSpecialDay> allOccasions = [
    IslamicSpecialDay.cuma,
    IslamicSpecialDay.kandil,
    IslamicSpecialDay.ramazan,
    IslamicSpecialDay.ramazanBayrami,
    IslamicSpecialDay.kurbanBayrami,
    IslamicSpecialDay.regaip,
    IslamicSpecialDay.mirac,
    IslamicSpecialDay.berat,
    IslamicSpecialDay.mevlid,
    IslamicSpecialDay.ucAylar,
    IslamicSpecialDay.asure,
    IslamicSpecialDay.hicriYilbasi,
  ];

  static const IslamicSpecialDay kandil = IslamicSpecialDay(
    id: 'kandil_genel',
    titleTr: 'Kandil Gecesi',
    titleEn: 'Blessed Kandil Night',
    greetingTr: 'Kandiliniz Mübarek Olsun',
    greetingEn: 'Blessed Kandil Night',
    emoji: '✨',
    descriptionTr: 'Mübarek kandil gecesi tebriği.',
  );

  /// Returns active Islamic special day for the given date, or null if none
  static IslamicSpecialDay? getSpecialDay([DateTime? date]) {
    final now = date ?? DateTime.now();
    final hijri = HijriDate.fromGregorian(now);

    final isFriday = now.weekday == DateTime.friday;
    final isThursdayNight = now.weekday == DateTime.thursday && now.hour >= 18;

    final hMonth = hijri.month;
    final hDay = hijri.day;

    if (hMonth == 1 && hDay == 1) {
      return IslamicSpecialDay.hicriYilbasi;
    }
    if (hMonth == 1 && (hDay >= 9 && hDay <= 10)) {
      return IslamicSpecialDay.asure;
    }
    if (hMonth == 3 && (hDay == 11 || hDay == 12)) {
      return IslamicSpecialDay.mevlid;
    }
    if (hMonth == 7) {
      if (hDay >= 26 && hDay <= 27) {
        return IslamicSpecialDay.mirac;
      }
      if (hDay <= 7 && (isFriday || isThursdayNight)) {
        return IslamicSpecialDay.regaip;
      }
    }
    if (hMonth == 8) {
      if (hDay >= 14 && hDay <= 15) {
        return IslamicSpecialDay.berat;
      }
    }
    if (hMonth == 9) {
      if (hDay >= 26 && hDay <= 27) {
        return IslamicSpecialDay.kadir;
      }
      return IslamicSpecialDay.ramazan;
    }
    if (hMonth == 10) {
      if (hDay >= 1 && hDay <= 3) {
        return IslamicSpecialDay.ramazanBayrami;
      }
    }
    if (hMonth == 12) {
      if (hDay >= 9 && hDay <= 13) {
        return IslamicSpecialDay.kurbanBayrami;
      }
    }
    if (isFriday || isThursdayNight) {
      return IslamicSpecialDay.cuma;
    }
    if ((hMonth == 7 || hMonth == 8) && hDay <= 3) {
      return IslamicSpecialDay.ucAylar;
    }

    return null;
  }

  /// Alias for getSpecialDay
  static IslamicSpecialDay? detectSpecialDay([DateTime? date]) => getSpecialDay(date);

  /// Quick preset greetings for the Share Studio selector
  static List<({String label, String? greeting})> presetGreetings({bool isTurkish = true}) {
    final autoDay = getSpecialDay();
    final autoGreeting = isTurkish ? autoDay?.greetingTr : autoDay?.greetingEn;
    return [
      if (autoDay != null)
        (
          label: isTurkish ? '${autoDay.emoji} Otomatik (${autoDay.titleTr})' : '${autoDay.emoji} Auto (${autoDay.titleEn})',
          greeting: autoGreeting,
        ),
      (
        label: isTurkish ? '🕌 Cuma' : '🕌 Friday',
        greeting: isTurkish ? IslamicSpecialDay.cuma.greetingTr : IslamicSpecialDay.cuma.greetingEn,
      ),
      (
        label: isTurkish ? '✨ Kandil' : '✨ Kandil',
        greeting: isTurkish ? IslamicSpecialDay.kandil.greetingTr : IslamicSpecialDay.kandil.greetingEn,
      ),
      (
        label: isTurkish ? '🌙 Ramazan' : '🌙 Ramadan',
        greeting: isTurkish ? IslamicSpecialDay.ramazan.greetingTr : IslamicSpecialDay.ramazan.greetingEn,
      ),
      (
        label: isTurkish ? '🎉 Bayram' : '🎉 Eid',
        greeting: isTurkish ? IslamicSpecialDay.ramazanBayrami.greetingTr : IslamicSpecialDay.ramazanBayrami.greetingEn,
      ),
      (
        label: isTurkish ? 'Tebriksiz' : 'No Greeting',
        greeting: null,
      ),
    ];
  }
}
