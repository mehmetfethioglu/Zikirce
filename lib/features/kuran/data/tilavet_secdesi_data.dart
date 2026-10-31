class TilavetSecdeItem {
  final int no;
  final int sureId;
  final String sureName;
  final int ayetId;
  final int page;
  final String arabicSnippet;
  final String mealSnippet;

  const TilavetSecdeItem({
    required this.no,
    required this.sureId,
    required this.sureName,
    required this.ayetId,
    required this.page,
    required this.arabicSnippet,
    required this.mealSnippet,
  });
}

class TilavetStep {
  final int stepNumber;
  final String title;
  final String description;
  final String? arabicText;
  final String? transliteration;
  final String icon;

  const TilavetStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.arabicText,
    this.transliteration,
    required this.icon,
  });
}

class TilavetSecdesiData {
  /// Kur'ân-ı Kerîm'deki 14 Tilâvet Secdesi Âyetinin Diyanet Mushafı sayfa ve âyet fihristi
  static const List<TilavetSecdeItem> allSecdeVerses = [
    TilavetSecdeItem(
      no: 1,
      sureId: 7,
      sureName: "A'râf",
      ayetId: 206,
      page: 176,
      arabicSnippet:
          "اِنَّ الَّذٖينَ عِنْدَ رَبِّكَ لَا يَسْتَكْبِرُونَ عَنْ عِبَادَتِهٖ وَيُسَبِّحُونَهُ وَلَهُ يَسْجُدُونَ",
      mealSnippet:
          "Kuşkusuz Rabbinin katındakiler O'na kulluk etmekten kibirlenmezler, O'nu tesbih eder ve yalnız O'na secde ederler.",
    ),
    TilavetSecdeItem(
      no: 2,
      sureId: 13,
      sureName: "Ra'd",
      ayetId: 15,
      page: 251,
      arabicSnippet:
          "وَلِلّٰهِ يَسْجُدُ مَنْ فِي السَّمٰوَاتِ وَالْاَرْضِ طَوْعًا وَكَرْهًا وَظِلَالُهُمْ بِالْغُدُوِّ وَالْاٰصَالِ",
      mealSnippet:
          "Göklerde ve yerde bulunanlar da onların gölgeleri de sabah akşam ister istemez yalnızca Allah'a secde ederler.",
    ),
    TilavetSecdeItem(
      no: 3,
      sureId: 16,
      sureName: "Nahl",
      ayetId: 49,
      page: 272,
      arabicSnippet:
          "وَلِلّٰهِ يَسْجُدُ مَا فِي السَّمٰوَاتِ وَمَا فِي الْاَرْضِ مِنْ دَٓابَّةٍ وَالْمَلٰٓئِكَةُ وَهُمْ لَا يَسْتَكْبِرُونَ",
      mealSnippet:
          "Göklerde ve yerde bulunan canlılar ve melekler büyüklük taslamadan Allah'a secde ederler.",
    ),
    TilavetSecdeItem(
      no: 4,
      sureId: 17,
      sureName: "İsrâ",
      ayetId: 107,
      page: 293,
      arabicSnippet:
          "قُلْ اٰمِنُوا بِهٖٓ اَوْ لَا تُؤْمِنُواؕ اِنَّ الَّذٖينَ اُو۫تُوا الْعِلْمَ مِنْ قَبْلِهٖٓ اِذَا يُتْلٰى عَلَيْهِمْ يَخِرُّونَ لِلْاَذْقَانِ سُجَّدًا",
      mealSnippet:
          "De ki: 'İster inanın ona, ister inanmayın. O daha önce kendilerine ilim verilenlere okunduğu zaman derhal çeneleri üstüne secdeye kapanırlar.'",
    ),
    TilavetSecdeItem(
      no: 5,
      sureId: 19,
      sureName: "Meryem",
      ayetId: 58,
      page: 309,
      arabicSnippet:
          "اِذَا تُتْلٰى عَلَيْهِمْ اٰيَاتُ الرَّحْمٰنِ خَرُّوا سُجَّدًا وَبُكِيًّا",
      mealSnippet:
          "Kendilerine Rahmân'ın âyetleri okunduğunda ağlayarak secdeye kapanırlardı.",
    ),
    TilavetSecdeItem(
      no: 6,
      sureId: 22,
      sureName: "Hac",
      ayetId: 18,
      page: 334,
      arabicSnippet:
          "اَلَمْ تَرَ اَنَّ اللّٰهَ يَسْجُدُ لَهُ مَنْ فِي السَّمٰوَاتِ وَمَنْ فِي الْاَرْضِ وَالشَّمْسُ وَالْقَمَرُ وَالنُّجُومُ وَالْجِبَالُ وَالشَّجَرُ وَالدَّوَٓابُّ وَكَثٖيرٌ مِنَ النَّاسِ",
      mealSnippet:
          "Görmez misin ki göklerde olanlar ve yerde olanlar, güneş, ay, yıldızlar, dağlar, ağaçlar, hayvanlar ve insanların birçoğu Allah'a secde etmektedir.",
    ),
    TilavetSecdeItem(
      no: 7,
      sureId: 25,
      sureName: "Furkân",
      ayetId: 60,
      page: 365,
      arabicSnippet:
          "وَاِذَا قٖيلَ لَهُمُ اسْجُدُوا لِلرَّحْمٰنِ قَالُوا وَمَا الرَّحْمٰنُ اَنَسْجُدُ لِمَا تَأْمُرُنَا وَزَادَهُمْ نُفُورًا",
      mealSnippet:
          "Onlara 'Rahmân'a secde edin' denildiğinde, 'Rahmân da neymiş? Senin emrettiğine secde eder miyiz hiç?' derler ve bu onların nefretini artırır.",
    ),
    TilavetSecdeItem(
      no: 8,
      sureId: 27,
      sureName: "Neml",
      ayetId: 25,
      page: 379,
      arabicSnippet:
          "اَلَّا يَسْجُدُوا لِلّٰهِ الَّذٖي يُخْرِجُ الْخَبْءَ فِي السَّمٰوَاتِ وَالْاَرْضِ وَيَعْلَمُ مَا تُخْفُونَ وَمَا تُعْلِنُونَ",
      mealSnippet:
          "Göklerde ve yerde gizleneni açığa çıkaran, gizlediğinizi de açıkladığınızı da bilen Allah'a secde etmesinler diye (şeytan onları saptırmış).",
    ),
    TilavetSecdeItem(
      no: 9,
      sureId: 32,
      sureName: "Secde",
      ayetId: 15,
      page: 416,
      arabicSnippet:
          "اِنَّمَا يُؤْمِنُ بِاٰيَاتِنَا الَّذٖينَ اِذَا ذُكِّرُوا بِهَا خَرُّوا سُجَّدًا وَسَبَّحُوا بِحَمْدِ رَبِّهِمْ وَهُمْ لَا يَسْتَكْبِرُونَ",
      mealSnippet:
          "Âyetlerimize ancak o kimseler inanırlar ki, kendilerine bu âyetlerle öğüt verildiği zaman kibirlenmeksizin secdeye kapanırlar ve Rablerini hamd ile tesbih ederler.",
    ),
    TilavetSecdeItem(
      no: 10,
      sureId: 38,
      sureName: "Sâd",
      ayetId: 24,
      page: 454,
      arabicSnippet: "فَاسْتَغْفَرَ رَبَّهُ وَخَرَّ رَاكِعًا وَاَنَابَ",
      mealSnippet:
          "Dâvûd Rabbinden bağışlanma diledi, rükû ederek secdeye kapandı ve tevbe ile O'na yöneldi.",
    ),
    TilavetSecdeItem(
      no: 11,
      sureId: 41,
      sureName: "Fussilet",
      ayetId: 37,
      page: 480,
      arabicSnippet:
          "لَا تَسْجُدُوا لِلشَّمْسِ وَلَا لِلْقَمَرِ وَاسْجُدُوا لِلّٰهِ الَّذٖي خَلَقَهُنَّ اِنْ كُنْتُمْ اِيَّاهُ تَعْبُدُونَ",
      mealSnippet:
          "Güneşe ve aya secde etmeyin; eğer yalnız O'na kulluk ediyorsanız, onları yaratan Allah'a secde edin.",
    ),
    TilavetSecdeItem(
      no: 12,
      sureId: 53,
      sureName: "Necm",
      ayetId: 62,
      page: 528,
      arabicSnippet: "فَاسْجُدُوا لِلّٰهِ وَاعْبُدُوا",
      mealSnippet:
          "Haydi Allah'a secde edin ve yalnızca O'na kullukta bulunun!",
    ),
    TilavetSecdeItem(
      no: 13,
      sureId: 84,
      sureName: "İnşikâk",
      ayetId: 21,
      page: 590,
      arabicSnippet: "وَاِذَا قُرِئَ عَلَيْهِمُ الْقُرْاٰنُ لَا يَسْجُدُونَ",
      mealSnippet: "Kendilerine Kur'an okunduğu zaman neden secde etmezler?",
    ),
    TilavetSecdeItem(
      no: 14,
      sureId: 96,
      sureName: "Alak",
      ayetId: 19,
      page: 598,
      arabicSnippet: "كَلَّاؕ لَا تُطِعْهُ وَاسْجُدْ وَاقْتَرِبْ",
      mealSnippet: "Hayır! Asla ona uyma; secde et ve Rabbine yaklaş!",
    ),
  ];

  static final Map<int, TilavetSecdeItem> _pageMap = {
    for (final item in allSecdeVerses) item.page: item,
  };

  static final Map<String, TilavetSecdeItem> _verseMap = {
    for (final item in allSecdeVerses) '${item.sureId}:${item.ayetId}': item,
  };

  /// Belirtilen sayfada secde âyeti var mı?
  static bool isSecdePage(int page) => _pageMap.containsKey(page);

  /// Belirtilen sayfanın secde âyeti bilgisini döner (yoksa null).
  static TilavetSecdeItem? getSecdeForPage(int page) => _pageMap[page];

  /// Belirtilen sûre ve âyet numarası bir tilâvet secdesi âyeti mi?
  static bool isSecdeVerse(int sureId, int ayetId) =>
      _verseMap.containsKey('$sureId:$ayetId');

  /// Belirtilen sûre ve âyetin tilâvet secdesi bilgisini döner (yoksa null).
  static TilavetSecdeItem? getSecdeForVerse(int sureId, int ayetId) =>
      _verseMap['$sureId:$ayetId'];

  /// Tilâvet secdesinin adım adım yapılış rehberi
  static const List<TilavetStep> guideSteps = [
    TilavetStep(
      stepNumber: 1,
      title: "Abdest & Kıbleye Yöneliş",
      description:
          "Namaz abdesti alınır, avret yerleri örtülü ve kıbleye karşı hürmetle ayakta (kıyamda) durulur.",
      icon: "💧",
    ),
    TilavetStep(
      stepNumber: 2,
      title: "Niyet",
      description:
          "Kalben niyet edilir: 'Niyet ettim Allah rızası için tilâvet secdesi yapmaya.'",
      icon: "🤲",
    ),
    TilavetStep(
      stepNumber: 3,
      title: "Tekbir ile Secdeye İniş",
      description:
          "Eller kulaklara kaldırılmadan 'Allâhu Ekber' denilerek doğrudan secdeye varılır.",
      arabicText: "اللهُ اَكْبَرُ",
      transliteration: "Allâhu Ekber",
      icon: "🙇‍♂️",
    ),
    TilavetStep(
      stepNumber: 4,
      title: "Secdede Tesbih",
      description: "Secdede üç defa namaz secdesindeki tesbih söylenir.",
      arabicText: "سُبْحَانَ رَبِّيَ الْاَعْلٰى",
      transliteration: "Sübhâne Rabbiye'l-A'lâ (3 defa)",
      icon: "✨",
    ),
    TilavetStep(
      stepNumber: 5,
      title: "Kalkış & Âyet Duası",
      description:
          "Tekrar 'Allâhu Ekber' denilerek ayağa kalkılır ve ayaktayken Bakara sûresi 285. âyetin şu kısmı okunur:",
      arabicText:
          "سَمِعْنَا وَاَطَعْنَا غُفْرَانَكَ رَبَّنَا وَاِلَيْكَ الْمَصٖيرُ",
      transliteration: "Semi'nâ ve eta'nâ gufrâneke Rabbenâ ve ileyke'l-masîr",
      icon: "🕊️",
    ),
  ];

  static const String fikhInfo =
      "Kur'ân-ı Kerîm'deki 14 secde âyetinden birini okuyan veya işiten kimsenin tilâvet secdesi yapması Hanefî mezhebinde vâcip, diğer üç mezhepte (Şâfiî, Mâlikî, Hanbelî) ise müekked sünnettir. "
      "Secdenin hemen âyet okunduktan sonra yapılması müstehaptır; geciktirilirse borç olarak zimmette kalır ve ilk fırsatta kaza/eda edilmesi gerekir.";
}
