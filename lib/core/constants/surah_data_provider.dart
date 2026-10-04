class SureItem {
  final int id;
  final String name;
  final int ayetSayisi;
  final String nameArabic;
  final int startPage;
  final int juzNumber;
  final String type; // Mekkî / Medenî

  const SureItem({
    required this.id,
    required this.name,
    required this.ayetSayisi,
    required this.nameArabic,
    required this.startPage,
    required this.juzNumber,
    required this.type,
  });
}

class DynamicSurahInfo {
  final int surahId;
  final String title;
  final String subtitle;
  final String icon;
  final String virtue;
  final String sizeInfo;
  final int startPage;

  const DynamicSurahInfo({
    required this.surahId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.virtue,
    required this.sizeInfo,
    required this.startPage,
  });
}

class SurahDataProvider {
  static const List<SureItem> surahs = [
    SureItem(id: 1, name: 'Fâtiha', ayetSayisi: 7, nameArabic: 'الفَاتِحَة', startPage: 1, juzNumber: 1, type: 'Mekkî'),
    SureItem(id: 2, name: 'Bakara', ayetSayisi: 286, nameArabic: 'البَقَرَة', startPage: 2, juzNumber: 1, type: 'Medenî'),
    SureItem(id: 3, name: 'Âl-i İmrân', ayetSayisi: 200, nameArabic: 'آلِ عِمْرَان', startPage: 50, juzNumber: 3, type: 'Medenî'),
    SureItem(id: 4, name: 'Nisâ', ayetSayisi: 176, nameArabic: 'النِّسَاء', startPage: 77, juzNumber: 4, type: 'Medenî'),
    SureItem(id: 5, name: 'Mâide', ayetSayisi: 120, nameArabic: 'المَائِدَة', startPage: 106, juzNumber: 6, type: 'Medenî'),
    SureItem(id: 6, name: 'En\'âm', ayetSayisi: 165, nameArabic: 'الأَنْعَام', startPage: 128, juzNumber: 7, type: 'Mekkî'),
    SureItem(id: 7, name: 'A\'râf', ayetSayisi: 206, nameArabic: 'الأَعْرَاف', startPage: 151, juzNumber: 8, type: 'Mekkî'),
    SureItem(id: 8, name: 'Enfâl', ayetSayisi: 75, nameArabic: 'الأَنْفَال', startPage: 177, juzNumber: 9, type: 'Medenî'),
    SureItem(id: 9, name: 'Tevbe', ayetSayisi: 129, nameArabic: 'التَّوْبَة', startPage: 187, juzNumber: 10, type: 'Medenî'),
    SureItem(id: 10, name: 'Yûnus', ayetSayisi: 109, nameArabic: 'يُونُس', startPage: 208, juzNumber: 11, type: 'Mekkî'),
    SureItem(id: 11, name: 'Hûd', ayetSayisi: 123, nameArabic: 'هُود', startPage: 221, juzNumber: 11, type: 'Mekkî'),
    SureItem(id: 12, name: 'Yûsuf', ayetSayisi: 111, nameArabic: 'يُوسُف', startPage: 235, juzNumber: 12, type: 'Mekkî'),
    SureItem(id: 13, name: 'Ra\'d', ayetSayisi: 43, nameArabic: 'الرَّعْد', startPage: 249, juzNumber: 13, type: 'Medenî'),
    SureItem(id: 14, name: 'İbrâhîm', ayetSayisi: 52, nameArabic: 'إِبْرَاهِيم', startPage: 255, juzNumber: 13, type: 'Mekkî'),
    SureItem(id: 15, name: 'Hicr', ayetSayisi: 99, nameArabic: 'الحِجْر', startPage: 262, juzNumber: 14, type: 'Mekkî'),
    SureItem(id: 16, name: 'Nahl', ayetSayisi: 128, nameArabic: 'النَّحْل', startPage: 267, juzNumber: 14, type: 'Mekkî'),
    SureItem(id: 17, name: 'İsrâ', ayetSayisi: 111, nameArabic: 'الإِسْرَاء', startPage: 282, juzNumber: 15, type: 'Mekkî'),
    SureItem(id: 18, name: 'Kehf', ayetSayisi: 110, nameArabic: 'الكَهْف', startPage: 293, juzNumber: 15, type: 'Mekkî'),
    SureItem(id: 19, name: 'Meryem', ayetSayisi: 98, nameArabic: 'مَرْيَم', startPage: 305, juzNumber: 16, type: 'Mekkî'),
    SureItem(id: 20, name: 'Tâhâ', ayetSayisi: 135, nameArabic: 'طه', startPage: 312, juzNumber: 16, type: 'Mekkî'),
    SureItem(id: 21, name: 'Enbiyâ', ayetSayisi: 112, nameArabic: 'الأَنْبِيَاء', startPage: 322, juzNumber: 17, type: 'Mekkî'),
    SureItem(id: 22, name: 'Hac', ayetSayisi: 78, nameArabic: 'الحَجّ', startPage: 332, juzNumber: 17, type: 'Medenî'),
    SureItem(id: 23, name: 'Mü\'minûn', ayetSayisi: 118, nameArabic: 'المُؤْمِنُون', startPage: 342, juzNumber: 18, type: 'Mekkî'),
    SureItem(id: 24, name: 'Nûr', ayetSayisi: 64, nameArabic: 'النُّور', startPage: 350, juzNumber: 18, type: 'Medenî'),
    SureItem(id: 25, name: 'Furkân', ayetSayisi: 77, nameArabic: 'الفُرْقَان', startPage: 359, juzNumber: 18, type: 'Mekkî'),
    SureItem(id: 26, name: 'Şuarâ', ayetSayisi: 227, nameArabic: 'الشُّعَرَاء', startPage: 367, juzNumber: 19, type: 'Mekkî'),
    SureItem(id: 27, name: 'Neml', ayetSayisi: 93, nameArabic: 'النَّمْل', startPage: 377, juzNumber: 19, type: 'Mekkî'),
    SureItem(id: 28, name: 'Kasas', ayetSayisi: 88, nameArabic: 'القَصَص', startPage: 385, juzNumber: 20, type: 'Mekkî'),
    SureItem(id: 29, name: 'Ankebût', ayetSayisi: 69, nameArabic: 'العَنْكَبُوت', startPage: 396, juzNumber: 20, type: 'Mekkî'),
    SureItem(id: 30, name: 'Rûm', ayetSayisi: 60, nameArabic: 'الرُّوم', startPage: 404, juzNumber: 21, type: 'Mekkî'),
    SureItem(id: 31, name: 'Lokmân', ayetSayisi: 34, nameArabic: 'لُقْمَان', startPage: 411, juzNumber: 21, type: 'Mekkî'),
    SureItem(id: 32, name: 'Secde', ayetSayisi: 30, nameArabic: 'السَّجْدَة', startPage: 415, juzNumber: 21, type: 'Mekkî'),
    SureItem(id: 33, name: 'Ahzâb', ayetSayisi: 73, nameArabic: 'الأَحْزَاب', startPage: 418, juzNumber: 21, type: 'Medenî'),
    SureItem(id: 34, name: 'Sebe', ayetSayisi: 54, nameArabic: 'سَبَأ', startPage: 428, juzNumber: 22, type: 'Mekkî'),
    SureItem(id: 35, name: 'Fâtır', ayetSayisi: 45, nameArabic: 'فَاطِر', startPage: 434, juzNumber: 22, type: 'Mekkî'),
    SureItem(id: 36, name: 'Yâsîn', ayetSayisi: 83, nameArabic: 'يس', startPage: 440, juzNumber: 22, type: 'Mekkî'),
    SureItem(id: 37, name: 'Sâffât', ayetSayisi: 182, nameArabic: 'الصَّافَّات', startPage: 446, juzNumber: 23, type: 'Mekkî'),
    SureItem(id: 38, name: 'Sâd', ayetSayisi: 88, nameArabic: 'ص', startPage: 453, juzNumber: 23, type: 'Mekkî'),
    SureItem(id: 39, name: 'Zümer', ayetSayisi: 75, nameArabic: 'الزُّمَر', startPage: 458, juzNumber: 23, type: 'Mekkî'),
    SureItem(id: 40, name: 'Mü\'min', ayetSayisi: 85, nameArabic: 'غَافِر', startPage: 467, juzNumber: 24, type: 'Mekkî'),
    SureItem(id: 41, name: 'Fussilet', ayetSayisi: 54, nameArabic: 'فُصِّلَت', startPage: 477, juzNumber: 24, type: 'Mekkî'),
    SureItem(id: 42, name: 'Şûrâ', ayetSayisi: 53, nameArabic: 'الشُّورَى', startPage: 483, juzNumber: 25, type: 'Mekkî'),
    SureItem(id: 43, name: 'Zuhruf', ayetSayisi: 89, nameArabic: 'الزُّخْرُف', startPage: 489, juzNumber: 25, type: 'Mekkî'),
    SureItem(id: 44, name: 'Duhân', ayetSayisi: 59, nameArabic: 'الدُّخَان', startPage: 496, juzNumber: 25, type: 'Mekkî'),
    SureItem(id: 45, name: 'Câsiye', ayetSayisi: 37, nameArabic: 'الجَاثِيَة', startPage: 499, juzNumber: 25, type: 'Mekkî'),
    SureItem(id: 46, name: 'Ahkâf', ayetSayisi: 35, nameArabic: 'الأَحْقَاف', startPage: 502, juzNumber: 26, type: 'Mekkî'),
    SureItem(id: 47, name: 'Muhammed', ayetSayisi: 38, nameArabic: 'مُحَمَّد', startPage: 507, juzNumber: 26, type: 'Medenî'),
    SureItem(id: 48, name: 'Fetih', ayetSayisi: 29, nameArabic: 'الفَتْح', startPage: 511, juzNumber: 26, type: 'Medenî'),
    SureItem(id: 49, name: 'Hucurât', ayetSayisi: 18, nameArabic: 'الحُجُرَات', startPage: 515, juzNumber: 26, type: 'Medenî'),
    SureItem(id: 50, name: 'Kaf', ayetSayisi: 45, nameArabic: 'ق', startPage: 518, juzNumber: 26, type: 'Mekkî'),
    SureItem(id: 51, name: 'Zâriyât', ayetSayisi: 60, nameArabic: 'الذَّارِيَات', startPage: 520, juzNumber: 26, type: 'Mekkî'),
    SureItem(id: 52, name: 'Tûr', ayetSayisi: 49, nameArabic: 'الطُّور', startPage: 523, juzNumber: 27, type: 'Mekkî'),
    SureItem(id: 53, name: 'Necm', ayetSayisi: 62, nameArabic: 'النَّجْم', startPage: 526, juzNumber: 27, type: 'Mekkî'),
    SureItem(id: 54, name: 'Kamer', ayetSayisi: 55, nameArabic: 'القَمَر', startPage: 528, juzNumber: 27, type: 'Mekkî'),
    SureItem(id: 55, name: 'Rahmân', ayetSayisi: 78, nameArabic: 'الرَّحْمَن', startPage: 531, juzNumber: 27, type: 'Medenî'),
    SureItem(id: 56, name: 'Vâkıa', ayetSayisi: 96, nameArabic: 'الوَاقِعَة', startPage: 534, juzNumber: 27, type: 'Mekkî'),
    SureItem(id: 57, name: 'Hadîd', ayetSayisi: 29, nameArabic: 'الحَدِيد', startPage: 537, juzNumber: 27, type: 'Medenî'),
    SureItem(id: 58, name: 'Mücâdele', ayetSayisi: 22, nameArabic: 'المُجَادِلَة', startPage: 542, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 59, name: 'Haşr', ayetSayisi: 24, nameArabic: 'الحَشْر', startPage: 545, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 60, name: 'Mümtehine', ayetSayisi: 13, nameArabic: 'المُمْتَحَنَة', startPage: 549, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 61, name: 'Saff', ayetSayisi: 14, nameArabic: 'الصَّفّ', startPage: 551, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 62, name: 'Cuma', ayetSayisi: 11, nameArabic: 'الجُمُعَة', startPage: 553, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 63, name: 'Münâfikûn', ayetSayisi: 11, nameArabic: 'المُنَافِقُون', startPage: 554, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 64, name: 'Teğâbün', ayetSayisi: 18, nameArabic: 'التَّغَابُن', startPage: 556, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 65, name: 'Talâk', ayetSayisi: 12, nameArabic: 'الطَّلَاق', startPage: 558, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 66, name: 'Tahrîm', ayetSayisi: 12, nameArabic: 'التَّحْرِيم', startPage: 560, juzNumber: 28, type: 'Medenî'),
    SureItem(id: 67, name: 'Mülk', ayetSayisi: 30, nameArabic: 'المُلْك', startPage: 562, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 68, name: 'Kalem', ayetSayisi: 52, nameArabic: 'القَلَم', startPage: 564, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 69, name: 'Hâkka', ayetSayisi: 52, nameArabic: 'الحَاقَّة', startPage: 566, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 70, name: 'Meâric', ayetSayisi: 44, nameArabic: 'المَعَارِج', startPage: 568, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 71, name: 'Nûh', ayetSayisi: 28, nameArabic: 'نُوح', startPage: 570, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 72, name: 'Cin', ayetSayisi: 28, nameArabic: 'الجِنّ', startPage: 572, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 73, name: 'Müzzemmil', ayetSayisi: 20, nameArabic: 'المُزَّمِّل', startPage: 574, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 74, name: 'Müddessir', ayetSayisi: 56, nameArabic: 'المُدَّثِّر', startPage: 575, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 75, name: 'Kıyâme', ayetSayisi: 40, nameArabic: 'القِيَامَة', startPage: 577, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 76, name: 'İnsan', ayetSayisi: 31, nameArabic: 'الإِنْسَان', startPage: 578, juzNumber: 29, type: 'Medenî'),
    SureItem(id: 77, name: 'Mürselât', ayetSayisi: 50, nameArabic: 'المُرْسَلَات', startPage: 580, juzNumber: 29, type: 'Mekkî'),
    SureItem(id: 78, name: 'Nebe', ayetSayisi: 40, nameArabic: 'النَّبَأ', startPage: 582, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 79, name: 'Nâziât', ayetSayisi: 46, nameArabic: 'النَّازِعَات', startPage: 583, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 80, name: 'Abese', ayetSayisi: 42, nameArabic: 'عَبَسَ', startPage: 585, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 81, name: 'Tekvîr', ayetSayisi: 29, nameArabic: 'التَّكْوِير', startPage: 586, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 82, name: 'İnfitâr', ayetSayisi: 19, nameArabic: 'الإِنْفِطَار', startPage: 587, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 83, name: 'Mutaffifîn', ayetSayisi: 36, nameArabic: 'المُطَفِّفِين', startPage: 588, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 84, name: 'İnşikâk', ayetSayisi: 25, nameArabic: 'الإِنْشِقَاق', startPage: 589, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 85, name: 'Burûc', ayetSayisi: 22, nameArabic: 'البُرُوج', startPage: 590, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 86, name: 'Târık', ayetSayisi: 17, nameArabic: 'الطَّارِق', startPage: 591, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 87, name: 'A\'lâ', ayetSayisi: 19, nameArabic: 'الأَعْلَى', startPage: 592, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 88, name: 'Gâşiye', ayetSayisi: 26, nameArabic: 'الغَاشِيَة', startPage: 592, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 89, name: 'Fecr', ayetSayisi: 30, nameArabic: 'الفَجْر', startPage: 593, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 90, name: 'Beled', ayetSayisi: 20, nameArabic: 'البَلَد', startPage: 594, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 91, name: 'Şems', ayetSayisi: 15, nameArabic: 'الشَّمْس', startPage: 595, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 92, name: 'Leyl', ayetSayisi: 21, nameArabic: 'اللَّيْل', startPage: 596, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 93, name: 'Duhâ', ayetSayisi: 11, nameArabic: 'الضُّحَى', startPage: 596, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 94, name: 'İnşirah', ayetSayisi: 8, nameArabic: 'الشَّرْح', startPage: 597, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 95, name: 'Tîn', ayetSayisi: 8, nameArabic: 'التِّين', startPage: 597, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 96, name: 'Alak', ayetSayisi: 19, nameArabic: 'العَلَق', startPage: 598, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 97, name: 'Kadr', ayetSayisi: 5, nameArabic: 'القَدْر', startPage: 599, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 98, name: 'Beyyine', ayetSayisi: 8, nameArabic: 'البَيِّنَة', startPage: 599, juzNumber: 30, type: 'Medenî'),
    SureItem(id: 99, name: 'Zilzâl', ayetSayisi: 8, nameArabic: 'الزَّلْزَلَة', startPage: 600, juzNumber: 30, type: 'Medenî'),
    SureItem(id: 100, name: 'Âdiyât', ayetSayisi: 11, nameArabic: 'العَادِيَات', startPage: 600, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 101, name: 'Kâria', ayetSayisi: 11, nameArabic: 'القَارِعَة', startPage: 601, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 102, name: 'Tekâsür', ayetSayisi: 8, nameArabic: 'التَّكَاثُر', startPage: 601, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 103, name: 'Asr', ayetSayisi: 3, nameArabic: 'العَصْر', startPage: 602, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 104, name: 'Hümeze', ayetSayisi: 9, nameArabic: 'الهُمَزَة', startPage: 602, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 105, name: 'Fil', ayetSayisi: 5, nameArabic: 'الفِيل', startPage: 602, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 106, name: 'Kureyş', ayetSayisi: 4, nameArabic: 'قُرَيْش', startPage: 603, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 107, name: 'Maûn', ayetSayisi: 7, nameArabic: 'المَاعُون', startPage: 603, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 108, name: 'Kevser', ayetSayisi: 3, nameArabic: 'الكَوْثَر', startPage: 603, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 109, name: 'Kâfirûn', ayetSayisi: 6, nameArabic: 'الكٰفِرُون', startPage: 604, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 110, name: 'Nasr', ayetSayisi: 3, nameArabic: 'النَّصْر', startPage: 604, juzNumber: 30, type: 'Medenî'),
    SureItem(id: 111, name: 'Tebbet', ayetSayisi: 5, nameArabic: 'المَسَد', startPage: 604, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 112, name: 'İhlâs', ayetSayisi: 4, nameArabic: 'الإِخْلَاص', startPage: 605, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 113, name: 'Felak', ayetSayisi: 5, nameArabic: 'الفَلَق', startPage: 605, juzNumber: 30, type: 'Mekkî'),
    SureItem(id: 114, name: 'Nâs', ayetSayisi: 6, nameArabic: 'النَّاس', startPage: 605, juzNumber: 30, type: 'Mekkî'),
  ];

  static const List<int> juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  static int getJuzStartPage(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) return 1;
    return juzStartPages[juzNumber - 1];
  }

  static SureItem? getSurahById(int id) {
    if (id < 1 || id > 114) return null;
    return surahs[id - 1];
  }

  static SureItem? getSurahForPage(int page) {
    for (final s in surahs) {
      final range = diyanetSurahPageRanges[s.id];
      if (range != null && page >= range.$1 && page <= range.$2) {
        return s;
      }
    }
    return surahs.first;
  }

  static String getSurahNameForPage(int page) {
    return getSurahForPage(page)?.name ?? 'Fâtiha';
  }

  static const Map<int, (int, int)> diyanetSurahPageRanges = {
    1: (1, 1),
    2: (2, 49),
    3: (50, 76),
    4: (77, 106),
    5: (106, 127),
    6: (128, 150),
    7: (151, 176),
    8: (177, 186),
    9: (187, 207),
    10: (208, 221),
    11: (221, 235),
    12: (235, 248),
    13: (249, 255),
    14: (255, 261),
    15: (262, 267),
    16: (267, 281),
    17: (282, 293),
    18: (293, 304),
    19: (305, 312),
    20: (312, 321),
    21: (322, 331),
    22: (332, 341),
    23: (342, 349),
    24: (350, 359),
    25: (359, 366),
    26: (367, 376),
    27: (377, 385),
    28: (385, 396),
    29: (396, 404),
    30: (404, 410),
    31: (411, 414),
    32: (415, 417),
    33: (418, 427),
    34: (428, 434),
    35: (434, 440),
    36: (440, 445),
    37: (446, 452),
    38: (453, 458),
    39: (458, 467),
    40: (467, 476),
    41: (477, 482),
    42: (483, 489),
    43: (489, 495),
    44: (496, 498),
    45: (499, 502),
    46: (502, 506),
    47: (507, 510),
    48: (511, 515),
    49: (515, 517),
    50: (518, 520),
    51: (520, 523),
    52: (523, 525),
    53: (526, 528),
    54: (528, 531),
    55: (531, 534),
    56: (534, 537),
    57: (537, 541),
    58: (542, 545),
    59: (545, 548),
    60: (549, 551),
    61: (551, 552),
    62: (553, 554),
    63: (554, 555),
    64: (556, 557),
    65: (558, 559),
    66: (560, 561),
    67: (562, 564),
    68: (564, 566),
    69: (566, 568),
    70: (568, 570),
    71: (570, 571),
    72: (572, 573),
    73: (574, 575),
    74: (575, 577),
    75: (577, 578),
    76: (578, 580),
    77: (580, 581),
    78: (582, 583),
    79: (583, 584),
    80: (585, 586),
    81: (586, 587),
    82: (587, 587),
    83: (588, 589),
    84: (589, 590),
    85: (590, 591),
    86: (591, 591),
    87: (592, 592),
    88: (592, 593),
    89: (593, 594),
    90: (594, 595),
    91: (595, 595),
    92: (596, 596),
    93: (596, 597),
    94: (597, 597),
    95: (597, 598),
    96: (598, 598),
    97: (599, 599),
    98: (599, 599),
    99: (600, 600),
    100: (600, 600),
    101: (601, 601),
    102: (601, 601),
    103: (602, 602),
    104: (602, 602),
    105: (602, 602),
    106: (603, 603),
    107: (603, 603),
    108: (603, 603),
    109: (604, 604),
    110: (604, 604),
    111: (604, 604),
    112: (605, 605),
    113: (605, 605),
    114: (605, 605),
  };

  /// Returns the exact (startPage, endPage) for a surah in Diyanet JSONs (1..605)
  static (int, int) getSurahDiyanetPageRange(int surahId) {
    if (diyanetSurahPageRanges.containsKey(surahId)) {
      return diyanetSurahPageRanges[surahId]!;
    }
    return (1, 1);
  }

  static int getSurahEndPage(int surahId) {
    if (diyanetSurahPageRanges.containsKey(surahId)) {
      return diyanetSurahPageRanges[surahId]!.$2;
    }
    if (surahId >= 114) return 605;
    final nextSurah = getSurahById(surahId + 1);
    if (nextSurah == null) return 605;
    return nextSurah.startPage;
  }

  static int getJuzForPage(int page) {
    for (int i = 29; i >= 0; i--) {
      if (page >= juzStartPages[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  static DynamicSurahInfo getDynamicSurah() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 5 = Friday in Dart
    final hour = now.hour;

    if (dayOfWeek == DateTime.friday && hour >= 5 && hour < 18) {
      return const DynamicSurahInfo(
        surahId: 18,
        title: 'Kehf Sûresi',
        subtitle: 'Cuma Bereketi',
        icon: '🕌',
        virtue: 'Cuma günü Kehf okuyanın iki Cuma arası nurlanır.',
        sizeInfo: '12 Sayfa · 110 Ayet',
        startPage: 293,
      );
    } else if (hour >= 5 && hour < 12) {
      return const DynamicSurahInfo(
        surahId: 36,
        title: 'Yâsîn Sûresi',
        subtitle: 'Sabah Nuru',
        icon: '☀️',
        virtue: 'Yâsîn, Kur\'ân\'ın kalbidir. Sabah okuyanın hacetleri giderilir.',
        sizeInfo: '6 Sayfa · 83 Ayet',
        startPage: 440,
      );
    } else if (hour >= 12 && hour < 17) {
      return const DynamicSurahInfo(
        surahId: 48,
        title: 'Fetih Sûresi',
        subtitle: 'Zafer ve Müjde',
        icon: '⛅',
        virtue: 'Fetih sûresini okuyan, Mekke fethinde Peygamberimizle bulunmuş gibidir.',
        sizeInfo: '5 Sayfa · 29 Ayet',
        startPage: 511,
      );
    } else if (hour >= 17 && hour < 22) {
      return const DynamicSurahInfo(
        surahId: 56,
        title: 'Vâkıa Sûresi',
        subtitle: 'Rızık ve Bereket',
        icon: '🌅',
        virtue: 'Her gece Vakıa okuyanı fakirlik ve darlık vurmaz.',
        sizeInfo: '3 Sayfa · 96 Ayet',
        startPage: 534,
      );
    } else {
      return const DynamicSurahInfo(
        surahId: 67,
        title: 'Mülk Sûresi',
        subtitle: 'Kabir Nuru',
        icon: '🌙',
        virtue: 'Tebâreke sûresi kabir azabından korur ve şefaatçidir.',
        sizeInfo: '2.5 Sayfa · 30 Ayet',
        startPage: 562,
      );
    }
  }
}
