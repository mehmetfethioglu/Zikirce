/// Islamic Hadith & Ayet Corpus Engine for Tahrir PDF Reflow Reader
/// Maps extracted textual context, narrator names, citations and translation keywords
/// to authentic, fully vocalized (harekeli) Arabic Unicode texts.

class HadithCorpusEntry {
  final String id;
  final String title;
  final String arabicText;
  final List<String> narrators;
  final List<String> sources;
  final List<String> hadithNumbers;
  final List<String> keywords;

  const HadithCorpusEntry({
    required this.id,
    required this.title,
    required this.arabicText,
    this.narrators = const [],
    this.sources = const [],
    this.hadithNumbers = const [],
    this.keywords = const [],
  });
}

class IslamicHadithCorpus {
  static const List<HadithCorpusEntry> entries = [
    // 1. Eve Giriş ve Aileye Selam (Sayfa 26 - Tirmizî 2698)
    HadithCorpusEntry(
      id: 'selam_eve_giris_enes',
      title: 'Eve Girip Çıkarken Selam Vermenin Önemi',
      arabicText: 'يَا بُنَيَّ ، إِذَا دَخَلْتَ عَلَى أَهْلِكَ فَسَلِّمْ ، يَكُنْ بَرَكَةً عَلَيْكَ ، وَعَلَى أَهْلِكَ',
      narrators: ['enes', 'enes b. malik', 'enes (radıyallahu'],
      sources: ['tirmizi', 'tirmizî', 'isti\'zan', 'isti’zan'],
      hadithNumbers: ['2698'],
      keywords: ['evine girdiğin zaman', 'oğulcağızım', 'ailene selam ver', 'bereket getirir'],
    ),

    // 2. Meclise Giriş ve Çıkışta Selam (Sayfa 27 - Tirmizî 2706 / Ebû Dâvûd 5208)
    HadithCorpusEntry(
      id: 'selam_meclis_giris_cikis',
      title: 'Meclise Girip Çıkarken Selam Verme',
      arabicText: 'إِذَا انْتَهَى أَحَدُكُمْ إِلَى الْمَجْلِسِ فَلْيُسَلِّمْ ، فَإِذَا أَرَادَ أَنْ يَقُومَ فَلْيُسَلِّمْ ، فَلَيْسَتِ الْأُولَى بِأَحَقَّ مِنَ الْآخِرَةِ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['tirmizi', 'tirmizî', 'ebu davud', 'ebû dâvûd', 'isti\'zan'],
      hadithNumbers: ['2706', '5208'],
      keywords: ['meclise girdiğiniz vakit', 'oradan çıkacağınız vakit', 'çıkacağmız vakit', 'çıkarken verilen selam', 'üstün değildir'],
    ),

    // 3. Eve Geldiğini Evdekilere Bildirme (Sayfa 28 - Buhârî 1801 / Müslim 715)
    HadithCorpusEntry(
      id: 'evdekilere_gelisini_bildirme_cabir',
      title: 'Eve Geldiğini Evdekilere Bildirmenin Önemi',
      arabicText: 'إِذَا أَطَالَ أَحَدُكُمُ الْغَيْبَةَ فَلَا يَطْرُقَنَّ أَهْلَهُ لَيْلًا',
      narrators: ['cabir', 'câbir', 'ibn mesud', 'abdullah b. mes\'ud', 'ebu ubeyde'],
      sources: ['buhari', 'buhârî', 'müslim'],
      hadithNumbers: ['1801', '715', '5244'],
      keywords: ['baskın yapan biri durumuna düşmemek', 'yanlarına girmeden önce geldiğini onlara bildir', 'ayaklarını yere vurarak', 'öksürerek geldiğini', 'geceleyin ailesinin yanına'],
    ),

    // 4. Kapı Açıp Kapatma / Yumuşaklık ve Kibarlık (Sayfa 25 - Müslim 2594)
    HadithCorpusEntry(
      id: 'rifk_yumusaklik_kapi',
      title: 'Kapıyı Yavaşça Açıp Kapatmanın Önemi / Rıfk',
      arabicText: 'إِنَّ الرِّفْقَ لَا يَكُونُ فِي شَيْءٍ إِلَّا زَانَهُ، وَلَا يُنْزَعُ مِنْ شَيْءٍ إِلَّا شَانَهُ',
      narrators: ['ayşe', 'âişe', 'hz. aişe'],
      sources: ['müslim', 'birr'],
      hadithNumbers: ['2594'],
      keywords: ['yumuşaklık', 'kibarlık', 'çirkinleştirir', 'güzelleştirir', 'bulunduğu şeyi'],
    ),

    // 5. Kılık Kıyafet ve Giyim Edebi / Ben Hadisi (Sayfa 19 - Ebû Dâvûd 4089)
    HadithCorpusEntry(
      id: 'giyim_kusama_ozen_ben_hadisi',
      title: 'Giyim ve Kuşama Özen Gösterme / Ben Hadisi',
      arabicText: 'إِنَّكُمْ قَادِمُونَ عَلَىٰ إِخْوَانِكُمْ، فَأَحْسِنُوا لِبَاسَكُمْ، وَأَصْلِحُوا رِحَالَكُمْ، حَتَّىٰ تَكُونُوا كَأَنَّكُمْ شَامَةٌ فِي النَّاسِ',
      narrators: ['ebu\'d-derda', 'sehl b. hanzaliyye'],
      sources: ['ebu davud', 'ebû dâvûd', 'libas'],
      hadithNumbers: ['4089'],
      keywords: ['develerinizi', 'yanına gelmeyi murad', 'ben nasıl fark ediliyorsa', 'kardeşlerinizin yanına', 'elbisenizi'],
    ),

    // 6. Selamı Yayınız (Tirmizî 2485 / Müslim 54 / İbn Mâce 3251)
    HadithCorpusEntry(
      id: 'selami_yayiniz_efsus_selam',
      title: 'Selâmı Aranızda Yayınız',
      arabicText: 'أَفْشُوا السَّلَامَ ، وَأَطْعِمُوا الطَّعَامَ ، وَصِلُوا الْأَرْحَامَ ، وَصَلُّوا بِاللَّيْلِ وَالنَّاسُ نِيَامٌ ، تَدْخُلُوا الْجَنَّةَ بِسَلَامٍ',
      narrators: ['abdullah b. selam', 'ebu hureyre'],
      sources: ['tirmizi', 'tirmizî', 'müslim', 'ibn mace', 'kıyamet'],
      hadithNumbers: ['2485', '54', '3251'],
      keywords: ['selamı yayınız', 'selâmı yayınız', 'selamı aranızda', 'efşü\'s-selâm', 'efşüs-selam', 'yemek yedirin', 'cennete selametle'],
    ),

    // 7. İsti'zân / İzin İsteme Üç Defadır (Buhârî 6245 / Müslim 2153)
    HadithCorpusEntry(
      id: 'istizan_uc_defadir',
      title: 'İzin İstemenin Üç Defa Olması',
      arabicText: 'الِاسْتِئْذَانُ ثَلَاثٌ ، فَإِنْ أُذِنَ لَكَ وَإِلَّا فَارْجِعْ',
      narrators: ['ebu musa', 'ebû mûsâ', 'ömer b. hattab'],
      sources: ['buhari', 'buhârî', 'müslim', 'isti\'zan'],
      hadithNumbers: ['6245', '2153'],
      keywords: ['üç defadır', 'üç keredir', 'izin verilirse gir', 'yoksa geri dön', 'isti\'zan', 'kapıyı üç defa'],
    ),

    // 8. Eve Girerken Besmele ve Zikir (Müslim 2018)
    HadithCorpusEntry(
      id: 'eve_giriste_zikir_seytan',
      title: 'Eve Girerken ve Yemekte Zikir',
      arabicText: 'إِذَا دَخَلَ الرَّجُلُ بَيْتَهُ فَذَكَرَ اللَّهَ عِنْدَ دُخُولِهِ وَعِنْدَ طَعَامِهِ ، قَالَ الشَّيْطَانُ : لَا مَبِيتَ لَكُمْ وَلَا عَشَاءَ',
      narrators: ['cabir', 'câbir'],
      sources: ['müslim', 'eşribe'],
      hadithNumbers: ['2018'],
      keywords: ['evine girdiği zaman allah', 'zikrederse', 'ne geceleyecek yer', 'ne de akşam yemeği', 'şeytan avanesine', 'lâ mebîte'],
    ),

    // 9. Yeme-İçme ve Sağ El Edebi (Buhârî 5376 / Müslim 2022)
    HadithCorpusEntry(
      id: 'yeme_icme_sag_el_besmele',
      title: 'Yeme İçme Edebi ve Sağ Elle Yeme',
      arabicText: 'يَا غُلَامُ ، سَمِّ اللَّهَ ، وَكُلْ بِيَمِينِكَ ، وَكُلْ مِمَّا يَلِيكَ',
      narrators: ['ömer b. ebi seleme', 'ömer b. ebî seleme'],
      sources: ['buhari', 'buhârî', 'müslim', 'et\'ime'],
      hadithNumbers: ['5376', '2022'],
      keywords: ['sağ elinle ye', 'önünden ye', 'besmele çek', 'ey çocuk', 'ey delikanlı', 'allah\'ın ismini an'],
    ),

    // 10. Selamlaşma Dereceleri (Buhârî 6231 / Müslim 2160)
    HadithCorpusEntry(
      id: 'selamlasma_dereceleri',
      title: 'Kim Kime Selam Verir',
      arabicText: 'يُسَلِّمُ الرَّاكِبُ عَلَى الْمَاشِي ، وَالْمَاشِي عَلَى الْقَاعِدِ ، وَالْقَلِيلُ عَلَى الْكَثِيرِ ، وَالصَّغِيرُ عَلَى الْكَبِيرِ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['buhari', 'buhârî', 'müslim', 'isti\'zan'],
      hadithNumbers: ['6231', '2160'],
      keywords: ['binen yürüyene', 'yürüyen oturana', 'küçük büyüğe', 'az olan çok olana', 'selam verir'],
    ),

    // 11. Aksırma ve Dua (Buhârî 6224)
    HadithCorpusEntry(
      id: 'aksirma_tesmit_duasi',
      title: 'Aksırma Edebi ve Teşmît',
      arabicText: 'إِذَا عَطَسَ أَحَدُكُمْ فَلْيَقُلِ : الْحَمْدُ لِلَّهِ ، وَلْيَقُلْ لَهُ أَخُوهُ : يَرْحَمُكَ اللَّهُ ، فَإِذَا قَالَ لَهُ : يَرْحَمُكَ اللَّهُ ، فَلْيَقُلْ : يَهْدِيكُمُ اللَّهُ وَيُصْلِحُ بَالَكُمْ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['buhari', 'buhârî', 'edeb'],
      hadithNumbers: ['6224'],
      keywords: ['aksırdığı zaman', 'elhamdülillah', 'yerhamükellah', 'yehdîkümullâh', 'hâlinizi düzeltsin', 'tesmit'],
    ),

    // 12. Esneme Edebi (Buhârî 6226 / Müslim 2994)
    HadithCorpusEntry(
      id: 'esneme_edebi_seytan',
      title: 'Esneme Edebi',
      arabicText: 'التَّثَاؤُبُ مِنَ الشَّيْطَانِ ، فَإِذَا تَثَاءَبَ أَحَدُكُمْ فَلْيَرُدَّهُ مَا اسْتَطَاعَ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['buhari', 'müslim'],
      hadithNumbers: ['6226', '2994'],
      keywords: ['esneme şeytandandır', 'gücü yettiği ölçüde engellesin', 'elini ağzına koysun'],
    ),

    // 13. Mecliste Yer Açma (Buhârî 6269 / Müslim 2177)
    HadithCorpusEntry(
      id: 'mecliste_yer_acma_edebi',
      title: 'Mecliste Yer Açma ve Kimseyi Yerinden Kaldırmama',
      arabicText: 'لَا يُقِيمَنَّ أَحَدُكُمْ رَجُلًا مِنْ مَجْلِسِهِ ثُمَّ يَجْلِسُ فِيهِ ، وَلَكِنْ تَوَسَّعُوا وَتَفَسَّحُوا',
      narrators: ['ibn ömer', 'abdullah b. ömer'],
      sources: ['buhari', 'buhârî', 'müslim', 'isti\'zan'],
      hadithNumbers: ['6269', '2177'],
      keywords: ['yerinden kaldırıp', 'kalkmasını isteyip', 'mecliste yer açın', 'genişleyiniz', 'oturduğu yerden'],
    ),

    // 14. İki Kişinin Fısıldaşması (Buhârî 6290 / Müslim 2184)
    HadithCorpusEntry(
      id: 'uc_kisi_fisildasma_edebi',
      title: 'Üç Kişi Varken İkisinin Fısıldaşması',
      arabicText: 'إِذَا كُنْتُمْ ثَلَاثَةً فَلَا يَتَنَاجَى اثْنَانِ دُونَ الْآخَرِ حَتَّى تَخْتَلِطُوا بِالنَّاسِ ، مِنْ أَجْلِ أَنْ يُحْزِنَهُ',
      narrators: ['ibn mesud', 'abdullah b. mes\'ud'],
      sources: ['buhari', 'buhârî', 'müslim', 'isti\'zan'],
      hadithNumbers: ['6290', '2184'],
      keywords: ['üç kişi olduğunuzda', 'üçüncüyü bırakıp fısıldaşmasın', 'üzer onu', 'fısıldaşma', 'gizli konuşma'],
    ),

    // 15. Tebessüm ve Tatlı Söz (Tirmizî 1956 / Buhârî 2989)
    HadithCorpusEntry(
      id: 'tebessum_ve_tatli_soz',
      title: 'Tebessüm ve Tatlı Söz Sadakadır',
      arabicText: 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ لَكَ صَدَقَةٌ',
      narrators: ['ebu zer', 'ebû zerr'],
      sources: ['tirmizi', 'tirmizî', 'birr'],
      hadithNumbers: ['1956'],
      keywords: ['tebessüm etmen sadakadır', 'tebessümün bir sadakadır', 'kardeşinin yüzüne tebessüm', 'güzel söz sadakadır'],
    ),

    // 16. Hediyeleşme (Buhârî el-Edebü'l-Müfred 594)
    HadithCorpusEntry(
      id: 'hediyelesme_tehadew_tehabbu',
      title: 'Hediyeleşiniz ki Birbirinizi Sevesiniz',
      arabicText: 'تَهَادَوْا تَحَابُّوا',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['edebul mufred', 'edebü\'l-müfred', 'beyhaki'],
      hadithNumbers: ['594'],
      keywords: ['hediyeleşiniz', 'hediyeleşin ki', 'birbirinizi seversiniz', 'sevgi artar'],
    ),

    // 17. Kolaylaştırınız, Zorlaştırmayınız (Buhârî 69 / Müslim 1734)
    HadithCorpusEntry(
      id: 'yessiru_vela_tuassiru',
      title: 'Kolaylaştırınız, Zorlaştırmayınız',
      arabicText: 'يَسِّرُوا وَلَا تُعَسِّرُوا ، وَبَشِّرُوا وَلَا تُنَفِّرُوا',
      narrators: ['enes', 'enes b. malik'],
      sources: ['buhari', 'buhârî', 'müslim', 'ilim'],
      hadithNumbers: ['69', '1734'],
      keywords: ['kolaylaştırınız', 'zorlaştırmayınız', 'müjdeleyiniz', 'nefret ettirmeyiniz'],
    ),

    // 18. Ameller Niyetlere Göredir (Buhârî 1 / Müslim 1907)
    HadithCorpusEntry(
      id: 'ameller_niyetlere_goredir',
      title: 'Ameller Niyetlere Göredir',
      arabicText: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
      narrators: ['ömer', 'ömer b. hattab'],
      sources: ['buhari', 'buhârî', 'müslim', 'bed\'ul vahy'],
      hadithNumbers: ['1', '1907'],
      keywords: ['ameller niyetlere göredir', 'herkes için ancak niyet ettiği vardır', 'innemel a\'mâlu'],
    ),

    // 19. Komşuluk Hakkı (Buhârî 6014 / Müslim 2624)
    HadithCorpusEntry(
      id: 'komsu_hakki_cebrail',
      title: 'Komşu Hakkı ve Cebrail\'in Tavsiyesi',
      arabicText: 'مَا زَالَ جِبْرِيلُ يُوصِينِي بِالْجَارِ حَتَّى ظَنَنْتُ أَنَّهُ سَيُوَرِّثُهُ',
      narrators: ['ayşe', 'âişe', 'ibn ömer'],
      sources: ['buhari', 'buhârî', 'müslim', 'edeb'],
      hadithNumbers: ['6014', '2624'],
      keywords: ['komşu hakkı', 'mirasçı kılacak zannettim', 'cebrail bana komşuyu', 'komşuya iyilik'],
    ),

    // 20. Güzel Ahlak ve Aile Edebi (Tirmizî 2003)
    HadithCorpusEntry(
      id: 'guzel_ahlak_kadinlara_muamele',
      title: 'Ahlakı En Güzel Olan ve Kadınlara İyilik',
      arabicText: 'أَكْمَلُ الْمُؤْمِنِينَ إِيمَانًا أَحْسَنُهُمْ خُلُقًا ، وَخِيَارُكُمْ خِيَارُكُمْ لِنِسَائِهِمْ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['tirmizi', 'tirmizî', 'rıda'],
      hadithNumbers: ['2003', '3895'],
      keywords: ['müminlerin iman bakımından en olgunu', 'ahlakı en güzel olanıdır', 'kadınlarına en hayırlı', 'hanımına en iyi'],
    ),

    // 21. Yoldan Eziyeti Kaldırma (Müslim 1914)
    HadithCorpusEntry(
      id: 'yoldan_eziyeti_kadirma_sadaka',
      title: 'Yoldan Eziyet Verici Şeyi Kaldırmak Sadakadır',
      arabicText: 'إِمَاطَةُ الْأَذَى عَنِ الطَّرِيقِ صَدَقَةٌ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['müslim', 'iman'],
      hadithNumbers: ['1914'],
      keywords: ['yoldan eziyet veren', 'eziyet verici bir şeyi kaldırmak sadakadır', 'yol hakkı'],
    ),

    // 22. Dilin Muhafazası ve Gıybet (Buhârî 6018 / Müslim 47)
    HadithCorpusEntry(
      id: 'dilin_muhafazasi_hayir_soyle_veya_sus',
      title: 'Ya Hayır Söyle Ya Sus',
      arabicText: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['buhari', 'buhârî', 'müslim', 'edeb'],
      hadithNumbers: ['6018', '47'],
      keywords: ['ya hayır söylesin', 'ya da sussun', 'allah\'a ve ahiret gününe iman eden', 'dilini tutsun'],
    ),

    // 23. Müslümanın Müslüman Üzerindeki 6 Hakkı (Müslim 2162)
    HadithCorpusEntry(
      id: 'muslumanin_musluman_uzerindeki_alti_hakki',
      title: 'Müslümanın Müslüman Üzerindeki Altı Hakkı',
      arabicText: 'حَقُّ الْمُسْلِمِ عَلَى الْمُسْلِمِ سِتٌّ : إِذَا لَقِيتَهُ فَسَلِّمْ عَلَيْهِ ، وَإِذَا دَعَاكَ فَأَجِبْهُ ، وَإِذَا اسْتَنْصَحَكَ فَانْصَحْ لَهُ ، وَإِذَا عَطَسَ فَحَمِدَ اللَّهَ فَشَمِّتْهُ ، وَإِذَا مَرِضَ فَعُدْهُ ، وَإِذَا مَاتَ فَاتَّبِعْهُ',
      narrators: ['ebu hureyre', 'ebû hüreyre'],
      sources: ['müslim', 'selam'],
      hadithNumbers: ['2162'],
      keywords: ['müslümanın müslüman üzerindeki hakkı altıdır', 'karşılaştığında selam ver', 'davet ettiğinde icabet et', 'nasihat istediğinde', 'hastalandığında ziyaret et'],
    ),

    // 24. Hayra Vesile Olma (Müslim 1893)
    HadithCorpusEntry(
      id: 'hayra_vesile_olan_yapan_gibidir',
      title: 'Hayra Vesile Olan Yapan Gibidir',
      arabicText: 'مَنْ دَلَّ عَلَى خَيْرٍ فَلَهُ مِثْلُ أَجْرِ فَاعِلِهِ',
      narrators: ['ebu mesud', 'ebû mes\'ûd'],
      sources: ['müslim', 'imare'],
      hadithNumbers: ['1893'],
      keywords: ['hayra vesile olan', 'yapan gibidir', 'yapan kimse gibi ecir', 'yol gösteren'],
    ),

    // 25. Nur Suresi 27. Ayet (İsti'zân)
    HadithCorpusEntry(
      id: 'ayet_nur_27_istizan',
      title: 'Nur Sûresi 27. Âyet-i Kerîme',
      arabicText: 'يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَدْخُلُوا بُيُوتًا غَيْرَ بُيُوتِكُمْ حَتَّىٰ تَسْتَأْنِسُوا وَتُسَلِّمُوا عَلَىٰ أَهْلِهَا ۚ ذَٰلِكُمْ خَيْرٌ لَّكُمْ لَعَلَّكُمْ تَذَكَّرُونَ',
      sources: ['nur suresi', 'nûr sûresi'],
      hadithNumbers: ['27'],
      keywords: ['kendi evlerinizden başka evlere', 'izin alıp halkına selam vermedikçe', 'nur suresi', '27. ayet', 'isti\'zan ayeti'],
    ),

    // 26. Nur Suresi 28. Ayet (Geri Dön Denildiğinde Dönme)
    HadithCorpusEntry(
      id: 'ayet_nur_28_geri_don',
      title: 'Nur Sûresi 28. Âyet-i Kerîme',
      arabicText: 'فَإِن لَّمْ تَجِدُوا فِيهَا أَحَدًا فَلَا تَدْخُلُوهَا حَتَّىٰ يُؤْذَنَ لَكُمْ ۖ وَإِن قِيلَ لَكُمُ ارْجِعُوا فَارْجِعُوا ۖ هُوَ أَزْكَىٰ لَكُمْ',
      sources: ['nur suresi', 'nûr sûresi'],
      hadithNumbers: ['28'],
      keywords: ['eğer orada kimseyi bulamazsanız', 'size geri dönün denirse', 'hemen dönün', 'bu sizin için daha temizdir'],
    ),

    // 27. Hucurât Suresi 12. Ayet (Gıybet ve Tecessüs Yasağı)
    HadithCorpusEntry(
      id: 'ayet_hucurat_12_giybet_tecessus',
      title: 'Hucurât Sûresi 12. Âyet-i Kerîme',
      arabicText: 'يَا أَيُّهَا الَّذِينَ آمَنُوا اجْتَنِبُوا كَثِيرًا مِّنَ الظَّنِّ إِنَّ بَعْضَ الظَّنِّ إِثْمٌ ۖ وَلَا تَجَسَّسُوا وَلَا يَغْتَب بَّعْضُكُم بَعْضًا',
      sources: ['hucurat suresi', 'hucurât sûresi'],
      hadithNumbers: ['12'],
      keywords: ['zannın çoğundan sakının', 'birbirinizin kusurunu araştırmayın', 'gıybetini yapmayın', 'ölü kardeşinizin eti'],
    ),

    // 28. Mukaddime Hamdele ve Salvele
    HadithCorpusEntry(
      id: 'mukaddime_hamdele_salvele',
      title: 'Mukaddime Dua ve Salavat',
      arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ، وَالصَّلَاةُ وَالسَّلَامُ عَلَى سَيِّدِنَا مُحَمَّدٍ وَعَلَى آلِهِ وَصَحْبِهِ أَجْمَعِينَ',
      keywords: ['mukaddime', 'alemlerin rabbi', 'hamdü senalar olsun', 'salat ve selam olsun', 'salât ve selâm olsun'],
    ),
  ];
}

/// Intelligent Multi-Factor Fuzzy Matcher for Adab Hadiths & Ayats
class IslamicTextResolver {
  const IslamicTextResolver();

  /// Resolves authentic Arabic Unicode text from the context of an extracted PDF page
  static String? resolve(String pageBodyText) {
    if (pageBodyText.trim().isEmpty) return null;
    final lower = pageBodyText.toLowerCase();

    HadithCorpusEntry? bestMatch;
    int highestScore = 0;

    for (final entry in IslamicHadithCorpus.entries) {
      int score = 0;

      // 1. Hadith number match (+40 points)
      for (final num in entry.hadithNumbers) {
        if (RegExp('\\b(?:hadis\\s*(?:no)?\\s*[:\\-]?\\s*|ayet\\s*[:\\-]?\\s*|s\\.\\s*\\d+\\s*,\\s*|no\\s*[:\\-]?\\s*)$num\\b', caseSensitive: false).hasMatch(lower) ||
            lower.contains('hadis no:$num') ||
            lower.contains('hadis no: $num') ||
            lower.contains('hadis no : $num') ||
            lower.contains('no:$num')) {
          score += 45;
          break;
        }
      }

      // 2. Keyword matches (+15 points each)
      for (final kw in entry.keywords) {
        if (lower.contains(kw.toLowerCase())) {
          score += 20;
        }
      }

      // 3. Narrator matches (+15 points)
      for (final narrator in entry.narrators) {
        if (lower.contains(narrator.toLowerCase())) {
          score += 15;
          break;
        }
      }

      // 4. Source book match (+10 points)
      for (final src in entry.sources) {
        if (lower.contains(src.toLowerCase())) {
          score += 10;
          break;
        }
      }

      // Threshold: at least 20 points (e.g. key translation phrase matched)
      if (score >= 20 && score > highestScore) {
        highestScore = score;
        bestMatch = entry;
      }
    }

    return bestMatch?.arabicText;
  }
}
