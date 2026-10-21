import 'package:flutter/foundation.dart';

enum SpiritualQuoteType {
  ayet,
  hadis,
}

@immutable
class SpiritualQuote {
  final String text;
  final String source;
  final String? arabic;
  final SpiritualQuoteType type;
  final String topic;

  const SpiritualQuote({
    required this.text,
    required this.source,
    this.arabic,
    required this.type,
    this.topic = 'zikir',
  });
}

/// Goal/Topic preset for the multi-goal Spiritual Share Studio
@immutable
class ShareGoalPreset {
  final String id; // 'namaz', 'zikir', 'kuran', 'ezber', 'kaza', 'devamlilik', 'salavat', 'esma'
  final String labelTr;
  final String labelEn;
  final String badgeTitleTr;
  final String badgeTitleEn;
  final String emoji;
  final String topic;

  const ShareGoalPreset({
    required this.id,
    required this.labelTr,
    required this.labelEn,
    required this.badgeTitleTr,
    required this.badgeTitleEn,
    required this.emoji,
    required this.topic,
  });
}

class ShareCardDataHelper {
  ShareCardDataHelper._();

  /// All supported goal/spiritual presets for the Share Studio
  static const List<ShareGoalPreset> goalPresets = [
    ShareGoalPreset(
      id: 'namaz',
      labelTr: 'Namaz',
      labelEn: 'Prayer',
      badgeTitleTr: '5 Vakit Namaz & Secde Huzuru',
      badgeTitleEn: '5 Daily Prayers & Prostration',
      emoji: '🕌',
      topic: 'namaz',
    ),
    ShareGoalPreset(
      id: 'zikir',
      labelTr: 'Zikir',
      labelEn: 'Dhikr',
      badgeTitleTr: 'Günlük Zikir & Kalbin Huzuru',
      badgeTitleEn: 'Daily Dhikr & Peace of Heart',
      emoji: '📿',
      topic: 'zikir',
    ),
    ShareGoalPreset(
      id: 'kuran',
      labelTr: 'Kur’an',
      labelEn: 'Quran',
      badgeTitleTr: 'Kur’an-ı Kerim Tilaveti',
      badgeTitleEn: 'Holy Quran Recitation',
      emoji: '📖',
      topic: 'kuran',
    ),
    ShareGoalPreset(
      id: 'ezber',
      labelTr: 'Ezber',
      labelEn: 'Hifz',
      badgeTitleTr: 'Ezber & Hafızlık Gayreti',
      badgeTitleEn: 'Quran Memorization & Hifz',
      emoji: '🧠',
      topic: 'ezber',
    ),
    ShareGoalPreset(
      id: 'kaza',
      labelTr: 'Kaza & Tövbe',
      labelEn: 'Make-up',
      badgeTitleTr: 'Kaza Telafisi & İstiğfar',
      badgeTitleEn: 'Missed Prayer Make-up & Repentance',
      emoji: '⚖️',
      topic: 'kaza',
    ),
    ShareGoalPreset(
      id: 'devamlilik',
      labelTr: 'Altın Gün',
      labelEn: 'Golden Day',
      badgeTitleTr: 'Altın Gün & İbadette İstikamet',
      badgeTitleEn: 'Golden Day & Steadfastness',
      emoji: '🌟',
      topic: 'devamlilik',
    ),
    ShareGoalPreset(
      id: 'salavat',
      labelTr: 'Salavat',
      labelEn: 'Salawat',
      badgeTitleTr: 'Salavat-ı Şerife & Muhabbet',
      badgeTitleEn: 'Blessings upon the Prophet ﷺ',
      emoji: '🌹',
      topic: 'salavat',
    ),
    ShareGoalPreset(
      id: 'esma',
      labelTr: 'Esma & Dua',
      labelEn: 'Esma & Dua',
      badgeTitleTr: 'Esmaü’l Hüsna & Tefekkür',
      badgeTitleEn: '99 Names of Allah & Reflection',
      emoji: '✨',
      topic: 'esma',
    ),
  ];

  /// Optional spiritual footer / prayer notes inspired by top faith apps
  static const List<String> spiritualNotesTr = [
    '', // Not Yok
    'Rabbim yapılan ibadetleri ve duaları dergâh-ı izzetinde kabul eylesin. 🤲',
    'Dualarda buluşmak dileğiyle, gönlünüz huzurla dolsun. ✨',
    'Elhamdülillâhi alâ külli hâl. 🌿',
    'Rabbim bizi namazı dosdoğru kılanlardan ve zikredenlerden eylesin. 🕌',
  ];

  static const List<String> spiritualNotesEn = [
    '',
    'May Allah accept our prayers and supplications. 🤲',
    'Keeping you in our prayers, may your heart be filled with peace. ✨',
    'Alhamdulillah for everything. 🌿',
    'May Allah make us steadfast in prayer and remembrance. 🕌',
  ];

  /// Curated authentic Ayet and Hadith library with verified sources across all goals
  static const List<SpiritualQuote> curatedQuotes = [
    // --- 1. ZİKİR & KALBİN HUZURU ---
    SpiritualQuote(
      text: 'Beni anın ki ben de sizi anayım. Bana şükredin, nankörlük etmeyin.',
      source: 'Bakara Sûresi, 152',
      arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Bilesiniz ki, kalpler ancak Allah’ı anmakla huzur bulur.',
      source: 'Ra’d Sûresi, 28',
      arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Rabbini sabah akşam, yalvararak ve korkarak, yüksek olmayan bir sesle an; gafillerden olma.',
      source: 'A’râf Sûresi, 205',
      arabic: 'وَاذْكُرْ رَبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Rabbini zikreden ile zikretmeyenin misali, diri ile ölü gibidir.',
      source: 'Buhârî, Daavât 66; Müslim, Müsâfirîn 211',
      arabic: 'مَثَلُ الَّذِي يَذْكُرُ رَبَّهُ وَالَّذِي لَا يَذْكُرُ رَبَّهُ مَثَلُ الْحَيِّ وَالْمَيِّتِ',
      type: SpiritualQuoteType.hadis,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Ey iman edenler! Allah’ı çokça zikredin ve O’nu sabah akşam tesbih edin.',
      source: 'Ahzâb Sûresi, 41-42',
      arabic: 'يَا أَيُّهَا الَّذِينَ آمَنُوا اذْكُرُوا اللَّهَ ذِكْرًا كَثِيرًا',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),

    // --- 2. 5 VAKİT NAMAZ & SECDE ---
    SpiritualQuote(
      text: 'Sana vahyedilen Kitab’ı oku ve namazı dosdoğru kıl. Şüphesiz namaz, insanı hayasızlıktan ve kötülükten alıkoyar.',
      source: 'Ankebût Sûresi, 45',
      arabic: 'إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنْكَرِ',
      type: SpiritualQuoteType.ayet,
      topic: 'namaz',
    ),
    SpiritualQuote(
      text: 'Sabır ve namazla Allah’tan yardım isteyin. Şüphesiz bu, huşû duyanlardan başkasına ağır gelir.',
      source: 'Bakara Sûresi, 45',
      arabic: 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ وَإِنَّهَا لَكَبِيرَةٌ إِلَّا عَلَى الْخَاشِعِينَ',
      type: SpiritualQuoteType.ayet,
      topic: 'namaz',
    ),
    SpiritualQuote(
      text: 'Kulun Rabbine en yakın olduğu hâl secde hâlidir. Öyleyse secdede duayı çoğaltın.',
      source: 'Müslim, Salât 215; Ebû Dâvûd, Salât 152',
      arabic: 'أَقْرَبُ مَا يَكُونُ الْعَبْدُ مِنْ رَبِّهِ وَهُوَ سَاجِدٌ فَأَكْثِرُوا الدُّعَاءَ',
      type: SpiritualQuoteType.hadis,
      topic: 'namaz',
    ),
    SpiritualQuote(
      text: 'Beş vakit namaz, birinizin kapısı önünde akan ve içinde her gün beş defa yıkandığı bol sulu bir nehir gibidir.',
      source: 'Buhârî, Mevâkît 6; Müslim, Mesâcid 283',
      type: SpiritualQuoteType.hadis,
      topic: 'namaz',
    ),
    SpiritualQuote(
      text: 'Şüphesiz namaz, müminlere belirli vakitlere bağlı olarak farz kılınmıştır.',
      source: 'Nisâ Sûresi, 103',
      arabic: 'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَوْقُوتًا',
      type: SpiritualQuoteType.ayet,
      topic: 'namaz',
    ),

    // --- 3. KUR’AN & TİLAVET ---
    SpiritualQuote(
      text: 'Sizin en hayırlınız Kur’an’ı öğrenen ve öğretendir.',
      source: 'Buhârî, Fezâilü’l-Kur’ân 21',
      arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      type: SpiritualQuoteType.hadis,
      topic: 'kuran',
    ),
    SpiritualQuote(
      text: 'Bu Kur’an, âyetlerini düşünsünler ve akıl sahipleri öğüt alsınlar diye indirdiğimiz mübarek bir kitaptır.',
      source: 'Sâd Sûresi, 29',
      arabic: 'كِتَابٌ أَنْزَلْنَاهُ إِلَيْكَ مُبَارَكٌ لِيَدَّبَّرُوا آيَاتِهِ',
      type: SpiritualQuoteType.ayet,
      topic: 'kuran',
    ),
    SpiritualQuote(
      text: 'Biz Kur’an’dan öyle bir şey indiriyoruz ki, o müminler için şifa ve rahmettir.',
      source: 'İsrâ Sûresi, 82',
      arabic: 'وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِلْمُؤْمِنِينَ',
      type: SpiritualQuoteType.ayet,
      topic: 'kuran',
    ),
    SpiritualQuote(
      text: 'Kur’an okuyunuz! Çünkü Kur’an, kıyamet gününde kendi ehline şefaatçi olarak gelecektir.',
      source: 'Müslim, Müsâfirîn 252',
      arabic: 'اقْرَءُوا الْقُرْآنَ فَإِنَّهُ يَأْتِي يَوْمَ الْقِيَامَةِ شَفِيعًا لِأَصْحَابِهِ',
      type: SpiritualQuoteType.hadis,
      topic: 'kuran',
    ),
    SpiritualQuote(
      text: 'Kim Allah’ın Kitabı’ndan bir harf okursa, onun için bir hasene (iyilik) vardır ve her hasene on misliyle yazılır.',
      source: 'Tirmizî, Fezâilü’l-Kur’ân 16',
      type: SpiritualQuoteType.hadis,
      topic: 'kuran',
    ),

    // --- 4. EZBER & HAFIZLIK ---
    SpiritualQuote(
      text: 'Andolsun biz Kur’an’ı düşünüp öğüt almak (ve hıfzetmek) için kolaylaştırdık. Var mı düşünüp öğüt alan?',
      source: 'Kamer Sûresi, 17',
      arabic: 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِنْ مُدَّكِرٍ',
      type: SpiritualQuoteType.ayet,
      topic: 'ezber',
    ),
    SpiritualQuote(
      text: 'Kur’an’da mahir olan (onu ezberleyip güzel okuyan) kimse, şerefli ve itaatkâr meleklerle beraberdir.',
      source: 'Buhârî, Tefsîr 80; Müslim, Müsâfirîn 244',
      arabic: 'الْمَاهِرُ بِالْقُرْآنِ مَعَ السَّفَرَةِ الْكِرَامِ الْبَرَرَةِ',
      type: SpiritualQuoteType.hadis,
      topic: 'ezber',
    ),
    SpiritualQuote(
      text: 'Kalbinde Kur’an’dan hiçbir şey bulunmayan kimse, harap olmuş bir ev gibidir.',
      source: 'Tirmizî, Fezâilü’l-Kur’ân 18',
      arabic: 'إِنَّ الَّذِي لَيْسَ فِي جَوْفِهِ شَيْءٌ مِنَ الْقُرْآنِ كَالْبَيْتِ الْخَرِبِ',
      type: SpiritualQuoteType.hadis,
      topic: 'ezber',
    ),
    SpiritualQuote(
      text: 'Kur’an ehli olan kimseye (cennette): «Oku ve yüksel! Dünyada tertil ile okuduğun gibi oku; makamın son âyeti okuduğun yerdir» denilir.',
      source: 'Ebû Dâvûd, Vitir 20; Tirmizî, Fezâilü’l-Kur’ân 18',
      type: SpiritualQuoteType.hadis,
      topic: 'ezber',
    ),

    // --- 5. KAZA TELAFİSİ & TÖVBE ---
    SpiritualQuote(
      text: 'Gündüzün iki طرفında ve gecenin gündüze yakın vakitlerinde namaz kıl. Şüphesiz iyilikler kötülükleri giderir.',
      source: 'Hûd Sûresi, 114',
      arabic: 'إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ ۚ ذَٰلِكَ ذِكْرَىٰ لِلذَّاكِرِينَ',
      type: SpiritualQuoteType.ayet,
      topic: 'kaza',
    ),
    SpiritualQuote(
      text: 'Kim bir namazı unutursa veya uyuyakalırsa, onun kefareti hatırladığı anda onu kılmasıdır.',
      source: 'Buhârî, Mevâkît 37; Müslim, Mesâcid 315',
      arabic: 'مَنْ نَسِيَ صَلَاةً فَلْيُصَلِّ إِذَا ذَكَرَهَا لَا كَفَّارَةَ لَهَا إِلَّا ذَلِكَ',
      type: SpiritualQuoteType.hadis,
      topic: 'kaza',
    ),
    SpiritualQuote(
      text: 'Nerede olursan ol Allah’a karşı gelmekten sakın; yaptığın bir kötülüğün/eksikliğin arkasından hemen bir iyilik yap ki onu silip süpürsün.',
      source: 'Tirmizî, Birr 55',
      arabic: 'اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا',
      type: SpiritualQuoteType.hadis,
      topic: 'kaza',
    ),
    SpiritualQuote(
      text: 'Allah’ın rahmetinden ümidinizi kesmeyin. Şüphesiz Allah bütün günahları bağışlar.',
      source: 'Zümer Sûresi, 53',
      arabic: 'لَا تَقْنَطُوا مِنْ رَحْمَةِ اللَّهِ ۚ إِنَّ اللَّهَ يَغْفِرُ الذُّنُوبَ جَمِيعًا',
      type: SpiritualQuoteType.ayet,
      topic: 'kaza',
    ),

    // --- 6. İSTİKAMET & DEVAMLILIK (STREAK / ALTIN GÜN) ---
    SpiritualQuote(
      text: 'Amellerin Allah’a en sevimli olanı, az da olsa devamlı olanıdır.',
      source: 'Buhârî, Rikâk 18; Müslim, Müsâfirîn 218',
      arabic: 'أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ',
      type: SpiritualQuoteType.hadis,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Sana ölüm gelinceye kadar Rabbine ibadet et.',
      source: 'Hicr Sûresi, 99',
      arabic: 'وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ',
      type: SpiritualQuoteType.ayet,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Emrolunduğun gibi dosdoğru ol.',
      source: 'Hûd Sûresi, 112',
      arabic: 'فَاسْتَقِمْ كَمَا أُمِرْتَ',
      type: SpiritualQuoteType.ayet,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Şüphesiz «Rabbimiz Allah’tır» deyip sonra dosdoğru olanların üzerine melekler iner: «Korkmayın, üzülmeyin, size vaad edilen cennetle sevinin!» derler.',
      source: 'Fussilet Sûresi, 30',
      arabic: 'إِنَّ الَّذِينَ قَالُوا رَبُّنَا اللَّهُ ثُمَّ اسْتَقَامُوا تَتَنَزَّلُ عَلَيْهِمُ الْمَلَائِكَةُ',
      type: SpiritualQuoteType.ayet,
      topic: 'devamlilik',
    ),

    // --- 7. SALAVAT-I ŞERİFE & MUHABBET ---
    SpiritualQuote(
      text: 'Şüphesiz Allah ve melekleri Peygamber’e salât ederler. Ey iman edenler! Siz de ona salât edin ve tam bir teslimiyetle selâm verin.',
      source: 'Ahzâb Sûresi, 56',
      arabic: 'إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ',
      type: SpiritualQuoteType.ayet,
      topic: 'salavat',
    ),
    SpiritualQuote(
      text: 'Kıyâmet gününde insanların bana en yakın olanları, bana en çok salât ü selâm getirenleridir.',
      source: 'Tirmizî, Vitir 21',
      arabic: 'أَوْلَى النَّاسِ بِي يَوْمَ الْقِيَامَةِ أَكْثَرُهُمْ عَلَيَّ صَلَاةً',
      type: SpiritualQuoteType.hadis,
      topic: 'salavat',
    ),
    SpiritualQuote(
      text: 'Kim bana bir defa salâtü selâm getirirse, Allah Teâlâ ona on defa rahmet eder.',
      source: 'Müslim, Salât 70',
      arabic: 'مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرًا',
      type: SpiritualQuoteType.hadis,
      topic: 'salavat',
    ),

    // --- 8. İSTİĞFAR & TEVBE ---
    SpiritualQuote(
      text: 'Bir kimse istiğfârı dilinden düşürmezse, Allah Teâlâ ona her darlıktan bir çıkış, her üzüntüden bir kurtuluş yolu gösterir ve ona beklemediği yerden rızık verir.',
      source: 'Ebû Dâvûd, Vitir 26; İbni Mâce, Edeb 57',
      type: SpiritualQuoteType.hadis,
      topic: 'istigfar',
    ),
    SpiritualQuote(
      text: 'Ey müminler! Hepiniz toptan Allah’a tövbe ediniz ki kurtuluşa eresiniz.',
      source: 'Nûr Sûresi, 31',
      arabic: 'وَتُوبُوا إِلَى اللَّهِ جَمِيعًا أَيُّهَ الْمُؤْمِنُونَ لَعَلَّكُمْ تُفْلِحُونَ',
      type: SpiritualQuoteType.ayet,
      topic: 'istigfar',
    ),
    SpiritualQuote(
      text: 'Şüphesiz Allah çok tövbe edenleri ve tertemiz olanları sever.',
      source: 'Bakara Sûresi, 222',
      arabic: 'إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ وَيُحِبُّ الْمُتَطَهِّرِينَ',
      type: SpiritualQuoteType.ayet,
      topic: 'istigfar',
    ),

    // --- 9. TEVHİD & ESMAÜL HÜSNA ---
    SpiritualQuote(
      text: 'En güzel isimler Allah’ındır; O’na o güzel isimlerle dua edin.',
      source: 'A’râf Sûresi, 180',
      arabic: 'وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا',
      type: SpiritualQuoteType.ayet,
      topic: 'esma',
    ),
    SpiritualQuote(
      text: 'Zikrin en faziletlisi «Lâ ilâhe illallâh», duanın en faziletlisi «Elhamdülillâh»tır.',
      source: 'Tirmizî, Daavât 9; İbni Mâce, Edeb 55',
      arabic: 'أَفْضَلُ الذِّكْرِ لَا إِلَهَ إِلَّا اللَّهُ وَأَفْضَلُ الدُّعَاءِ الْحَمْدُ لِلَّهِ',
      type: SpiritualQuoteType.hadis,
      topic: 'esma',
    ),
    SpiritualQuote(
      text: 'Allah’ın doksan dokuz ismi vardır. Kim bunları ihsâ ederse (sayar ve mânâsıyla yaşarsa) cennete girer.',
      source: 'Buhârî, Daavât 68; Müslim, Zikir 5',
      type: SpiritualQuoteType.hadis,
      topic: 'esma',
    ),

    // --- 10. ŞÜKÜR & HAMD ---
    SpiritualQuote(
      text: 'Eğer şükrederseniz, elbette size (nimetimi) artırırım.',
      source: 'İbrâhîm Sûresi, 7',
      arabic: 'لَئِنْ شَكَرْتُمْ لَأَزِيدَنَّكُمْ',
      type: SpiritualQuoteType.ayet,
      topic: 'hamd',
    ),
    SpiritualQuote(
      text: 'Her farz namazın peşinden otuz üçer defa Sübhânallâh, Elhamdülillâh, Allâhüekber deyiniz.',
      source: 'Buhârî, Ezân 155; Müslim, Mesâcid 142',
      type: SpiritualQuoteType.hadis,
      topic: 'hamd',
    ),
  ];

  /// Returns all quotes matching a topic (with fallback to all quotes if none match)
  static List<SpiritualQuote> getQuotesForTopic(String topic) {
    final normalized = resolveTopicKey(zikirName: topic, category: topic);
    final matches = curatedQuotes.where((q) => q.topic == normalized).toList();
    return matches.isNotEmpty ? matches : curatedQuotes;
  }

  /// Resolves the canonical topic key ('namaz', 'zikir', 'kuran', 'ezber', 'kaza', 'devamlilik', 'salavat', 'istigfar', 'esma', 'hamd')
  static String resolveTopicKey({
    String? zikirName,
    String? category,
  }) {
    final lower = '${zikirName ?? ''} ${category ?? ''}'.toLowerCase();

    if (lower.contains('namaz') ||
        lower.contains('prayer') ||
        lower.contains('vakit') ||
        lower.contains('sabah') ||
        lower.contains('öğle') ||
        lower.contains('ikindi') ||
        lower.contains('akşam') ||
        lower.contains('yatsı') ||
        lower.contains('secde')) {
      if (lower.contains('kaza')) return 'kaza';
      return 'namaz';
    }
    if (lower.contains('kaza') || lower.contains('telafi') || lower.contains('borç')) {
      return 'kaza';
    }
    if (lower.contains('ezber') || lower.contains('hafız') || lower.contains('hafiz') || lower.contains('hifz')) {
      return 'ezber';
    }
    if (lower.contains('kuran') ||
        lower.contains('kur\'an') ||
        lower.contains('kur’an') ||
        lower.contains('hatim') ||
        lower.contains('tilavet') ||
        lower.contains('cüz') ||
        lower.contains('sure') ||
        lower.contains('sûre') ||
        lower.contains('mushaf')) {
      return 'kuran';
    }
    if (lower.contains('altın gün') ||
        lower.contains('altin gun') ||
        lower.contains('golden') ||
        lower.contains('streak') ||
        lower.contains('seri') ||
        lower.contains('devam') ||
        lower.contains('istikrar') ||
        lower.contains('istikamet')) {
      return 'devamlilik';
    }
    if (lower.contains('salavat') || lower.contains('salât') || lower.contains('muhammed')) {
      return 'salavat';
    }
    if (lower.contains('istiğfar') || lower.contains('istigfar') || lower.contains('tevbe') || lower.contains('tövbe') || lower.contains('estağfirullah')) {
      return 'istigfar';
    }
    if (lower.contains('hamd') || lower.contains('şükür') || lower.contains('sukur') || lower.contains('elhamdülillah')) {
      return 'hamd';
    }
    if (lower.contains('esma') || lower.contains('tevhid') || lower.contains('lâ ilâhe') || lower.contains('dua')) {
      return 'esma';
    }
    return 'zikir';
  }

  /// Resolves the matching ShareGoalPreset for any goal/category string
  static ShareGoalPreset resolvePreset({
    String? zikirName,
    String? category,
  }) {
    final topic = resolveTopicKey(zikirName: zikirName, category: category);
    return goalPresets.firstWhere(
      (p) => p.topic == topic || p.id == topic,
      orElse: () => goalPresets[1], // Default: zikir
    );
  }

  /// Extracts or maps the quote and source for a given zikir/goal context or category
  static SpiritualQuote resolveQuote({
    String? zikirName,
    String? category,
    String? rawVirtue,
    int quoteIndex = 0,
  }) {
    if (rawVirtue != null && rawVirtue.trim().isNotEmpty && quoteIndex == 0) {
      final parsed = _tryParseVirtue(rawVirtue.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    final topic = resolveTopicKey(zikirName: zikirName, category: category);
    final list = curatedQuotes.where((q) => q.topic == topic).toList();
    if (list.isNotEmpty) {
      return list[quoteIndex.abs() % list.length];
    }

    return curatedQuotes.first;
  }

  static SpiritualQuote? _tryParseVirtue(String virtue) {
    final match = RegExp(r'^(.*?)\s*\(([^()]+)\)\s*$').firstMatch(virtue);
    if (match != null) {
      final quoteText = match.group(1)?.trim() ?? virtue;
      final source = match.group(2)?.trim() ?? '';
      if (source.isNotEmpty) {
        final isAyet = source.toLowerCase().contains('sure') ||
            source.toLowerCase().contains('sûre') ||
            source.toLowerCase().contains('ayet') ||
            source.toLowerCase().contains('âyet');
        return SpiritualQuote(
          text: quoteText,
          source: source,
          type: isAyet ? SpiritualQuoteType.ayet : SpiritualQuoteType.hadis,
        );
      }
    }
    if (virtue.length > 10) {
      return SpiritualQuote(
        text: virtue,
        source: 'Hadis-i Şerif / Muteber Kaynak',
        type: SpiritualQuoteType.hadis,
      );
    }
    return null;
  }
}
