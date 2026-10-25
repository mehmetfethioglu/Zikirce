class HatimDuasiSection {
  final int order;
  final String title;
  final String subtitle;
  final String arabic;
  final String transliteration;
  final String meaning;

  const HatimDuasiSection({
    required this.order,
    required this.title,
    required this.subtitle,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
  });

  /// Bölümü durak işaretlerine (`۝`) göre cümle/füsûl listesine ayırır.
  List<String> get arabicClauses => arabic
      .split('۝')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Matbû Kur'ân-ı Kerîmlerin sonunda yer alan geleneksel
/// "Duâü Hatmi'l-Kur'âni'l-Azîm" (دُعَٓاءُ خَتْمِ الْقُرْاٰنِ الْعَظٖيمِ) tam metni.
/// Diyanet Matbû Mushaf (`AmasyaAbay` & `mushaf`) hattı ve hareke/çeker/med
/// dizilimiyle birebir uyumlu olarak kodlanmıştır.
class HatimDuasiData {
  HatimDuasiData._();

  static const String arabicTitle = 'دُعَٓاءُ خَتْمِ الْقُرْاٰنِ الْعَظٖيمِ';
  static const String besmele = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ';
  static const String turkishTitle = 'Matbû Kur’ân-ı Kerîm Hatim Duası';
  static const String turkishSubtitle =
      'Mushafların sonunda yer alan tam metin hatm-i şerif ve bağışlama duası';

  static const List<HatimDuasiSection> sections = [
    HatimDuasiSection(
      order: 1,
      title: '1. Tasdik, Hamd ve Kabul Niyazı',
      subtitle: 'Sadakallâhü’l-Azîm ve Hatm-i Şerifin Kabulü',
      arabic:
          'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحٖيمِ ۝ صَدَقَ اللّٰهُ الْعَظٖيمُ ۝ وَبَلَّغَ رَسُولُهُ النَّبِيُّ الْكَرٖيمُ ۝ وَنَحْنُ عَلٰى ذٰلِكَ مِنَ الشَّاهِدٖينَ وَالشَّاكِرٖينَ ۝ وَالْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ ۝ رَبَّنَا تَقَبَّلْ مِنَّا اِنَّكَ اَنْتَ السَّمٖيعُ الْعَلٖيمُ ۝ وَتُبْ عَلَيْنَا يَا مَوْلَانَا اِنَّكَ اَنْتَ التَّوَّابُ الرَّحٖيمُ ۝ وَاهْدِنَا وَوَفِّقْنَا اِلَى الْحَقِّ وَاِلٰى طَرٖيقٍ مُسْتَقٖيمٍ بِبَرَكَةِ الْقُرْاٰنِ الْعَظٖيمِ ۝ وَبِحُرْمَةِ مَنْ اَرْسَلْتَهُ رَحْمَةً لِلْعَالَمٖينَ ۝ وَاعْفُ عَنَّا يَا كَرٖيمُ وَاعْفُ عَنَّا يَا رَحٖيمُ ۝ وَاغْفِرْ لَنَا ذُنُوبَنَا بِفَضْلِكَ وَكَرَمِكَ يَا اَكْرَمَ الْاَكْرَمٖينَ وَيَا اَرْحَمَ الرَّاحِمٖينَ ۝',
      transliteration:
          'Bismillâhirrahmânirrahîm. Sadakallâhü’l-Azîm. Ve belleğa Rasûlühü’n-Nebiyyü’l-Kerîm. Ve nahnü alâ zâlike mine’ş-şâhidîne ve’ş-şâkirîn. Ve’l-hamdü lillâhi Rabbi’l-âlemîn. Rabbenâ tekabbel minnâ inneke ente’s-Semîu’l-Alîm. Ve tüb aleynâ yâ Mevlânâ inneke ente’t-Tevvâbü’r-Rahîm. Vehdinâ ve veffiknâ ile’l-hakkı ve ilâ tarîkın müstakîmin bi-bereketi’l-Kur’âni’l-Azîm. Ve bi-hürmeti men erseltehû rahmeten li’l-âlemîn. Va’fü annâ yâ Kerîm, va’fü annâ yâ Rahîm. Vağfir lenâ zünûbenâ bi-fadlike ve keremike yâ Ekreme’l-ekremîne ve yâ Erhame’r-râhimîn.',
      meaning:
          'Rahmân ve Rahîm olan Allah’ın adıyla. Azîm olan Allah doğru söyledi. O’nun Kerîm Peygamberi ve Rasûlü de tebliğ etti. Bizler de bu hakikate şâhitlik edenlerden ve şükredenlerdeniz. Hamd, âlemlerin Rabbi olan Allah’a mahsustur. Ey Rabbimiz! Bizden bu hatmi kabul buyur; şüphesiz Sen hakkıyla işiten ve her şeyi bilensin. Ey Mevlâmız! Tevbelerimizi kabul eyle; şüphesiz Sen tevbeleri çokça kabul eden ve çok merhamet edensin. Kur’ân-ı Azîm’in bereketiyle ve âlemlere rahmet olarak gönderdiğin Peygamberin hürmetine bizi hakka ve dosdoğru yola ilet ve muvaffak kıl. Bizi affeyle ey Kerîm, bizi affeyle ey Rahîm! Fazlın ve kereminle günahlarımızı bağışla, ey keremlilerin en keremlisi ve ey merhametlilerin en merhametlisi!',
    ),
    HatimDuasiSection(
      order: 2,
      title: '2. Kur’ân’ın Ziyneti, Şefaati ve Yoldaşlığı',
      subtitle: 'Dünya, Kabir ve Ahirette Kur’ân Nûru',
      arabic:
          'اَللّٰهُمَّ زَيِّنَّا بِزٖينَةِ خَتْمِ الْقُرْاٰنِ ۝ وَاَكْرِمْنَا بِكَرَامَةِ الْقُرْاٰنِ ۝ وَشَرِّفْنَا بِشَرَافَةِ الْقُرْاٰنِ ۝ وَاَلْبِسْنَا بِخِلْعَةِ الْقُرْاٰنِ ۝ وَاَدْخِلْنَا الْجَنَّةَ بِشَفَاعَةِ الْقُرْاٰنِ ۝ وَعَافِنَا مِنْ كُلِّ بَلَٓاءِ الدُّنْيَا وَعَذَابِ الْاٰخِرَةِ بِحُرْمَةِ الْقُرْاٰنِ ۝ وَارْحَمْ جَمٖيعَ اُمَّةِ مُحَمَّدٍ يَا رَحْمٰنُ يَا رَحٖيمُ ۝ اَللّٰهُمَّ اجْعَلِ الْقُرْاٰنَ لَنَا فِی الدُّنْيَا قَرٖينًا ۝ وَفِی الْقَبْرِ مُؤْنِسًا ۝ وَفِی الْقِيَامَةِ شَفٖيعًا ۝ وَعَلَى الصِّرَاطِ نُورًا ۝ وَاِلَى الْجَنَّةِ رَفٖيقًا ۝ وَمِنَ النَّارِ سِتْرًا وَحِجَابًا ۝ وَاِلَى الْخَيْرَاتِ كُلِّهَا دَلٖيلًا وَاِمَامًا ۝ بِفَضْلِكَ وَجُودِكَ وَكَرَمِكَ يَا كَرٖيمُ ۝',
      transliteration:
          'Allâhümme zeyyinnâ bi-zîneti hatmi’l-Kur’ân, ve ekrimnâ bi-kerâmeti’l-Kur’ân, ve şerrifnâ bi-şerâfeti’l-Kur’ân, ve elbisnâ bi-hil’ati’l-Kur’ân, ve edhılne’l-cennete bi-şefâati’l-Kur’ân, ve âfinâ min külli belâi’d-dünyâ ve azâbi’l-âhirati bi-hürmeti’l-Kur’ân, verham cemîa ümmeti Muhammedin yâ Rahmânü yâ Rahîm. Allâhümmec’ali’l-Kur’âne lenâ fi’d-dünyâ karînen, ve fi’l-kabri mûnisen, ve fi’l-kıyâmeti şefîan, ve ale’s-sırâtı nûran, ve ile’l-cenneti refîkan, ve mine’n-nâri sitran ve hicâben, ve ile’l-hayrâti küllihâ delîlen ve imâmen, bi-fadlike ve cûdike ve keremike yâ Kerîm.',
      meaning:
          'Allah’ım! Bizi Kur’ân hatminin ziynetiyle süsle, Kur’ân’ın ikramıyla bize ikram eyle, Kur’ân’ın şerefiyle bizi şereflendir, Kur’ân’ın manevi hil’atini bize giydir, Kur’ân’ın şefaatiyle bizi cennete dahil eyle, Kur’ân hürmetine bizi dünyanın her türlü belasından ve ahiret azabından muhafaza buyur; ey Rahmân, ey Rahîm olan Allah’ım, ümmet-i Muhammed’in tamamına merhamet eyle! Allah’ım! Kur’ân’ı bize dünyada can yoldaşı, kabirde munis bir dost, kıyamet gününde şefaatçi, sırat üzerinde nûr, cennete giderken refik, cehennem ateşine karşı perde ve siper, bütün hayırlara ulaşmada delil ve önder eyle; fazlınla, cömertliğinle ve kereminle ey Kerîm!',
    ),
    HatimDuasiSection(
      order: 3,
      title: '3. Hıfz, Tilâvet ve İstikamet Duası',
      subtitle: 'Kur’ân’ı Anlama, Yaşama ve Unutmama Niyazı',
      arabic:
          'اَللّٰهُمَّ ارْحَمْنَا بِالْقُرْاٰنِ الْعَظٖيمِ ۝ وَاجْعَلْهُ لَنَا اِمَامًا وَنُورًا وَهُدًى وَرَحْمَةً ۝ اَللّٰهُمَّ ذَكِّرْنَا مِنْهُ مَا نَسٖينَا ۝ وَعَلِّمْنَا مِنْهُ مَا جَهِلْنَا ۝ وَارْزُقْنَا تِلَاوَتَهُ اٰنَٓاءَ اللَّيْلِ وَاَطْرَافَ النَّهَارِ ۝ وَاجْعَلْهُ لَنَا حُجَّةً يَا رَبَّ الْعَالَمٖينَ ۝ اَللّٰهُمَّ اهْدِنَا بِهِدَايَةِ الْقُرْاٰنِ ۝ وَنَجِّنَا مِنَ النّٖيرَانِ بِكَرَامَةِ الْقُرْاٰنِ ۝ وَارْفَعْ دَرَجَاتِنَا بِفَضٖيلَةِ الْقُرْاٰنِ ۝ وَكَفِّرْ عَنَّا سَيِّئَاتِنَا بِتِلَاوَةِ الْقُرْاٰنِ ۝ يَا ذَا الْفَضْلِ وَالْاِحْسَانِ ۝',
      transliteration:
          'Allâhümme’rhamnâ bi’l-Kur’âni’l-Azîm, vec’alhü lenâ imâmen ve nûran ve hüden ve rahmeh. Allâhümme zekkirnâ minhü mâ nesînâ, ve allimnâ minhü mâ cehilnâ, verzuknâ tilâvetehû ânâe’l-leyli ve etrâfe’n-nehâr, vec’alhü lenâ hucceten yâ Rabbe’l-âlemîn. Allâhümmehdinâ bi-hidâyeti’l-Kur’ân, ve neccinâ mine’n-nîrâni bi-kerâmeti’l-Kur’ân, verfa’ deracâtinâ bi-fazîleti’l-Kur’ân, ve keffir annâ seyyiâtinâ bi-tilâveti’l-Kur’ân, yâ Ze’l-fadli ve’l-ihsân.',
      meaning:
          'Allah’ım! Kur’ân-ı Azîm ile bize merhamet eyle; onu bizim için bir önder, bir nûr, bir hidayet ve bir rahmet kıl. Allah’ım! Ondan unuttuklarımızı bize hatırlat, bilmediklerimizi bize öğret. Gece saatlerinde ve gündüzün vakitlerinde onu okumayı bize nasip eyle. Onu bizim lehimize bir hüccet (delil) kıl, ey âlemlerin Rabbi! Allah’ım! Kur’ân’ın hidayetiyle bizi doğru yola ilet, Kur’ân’ın ikramıyla bizi ateşten kurtar, Kur’ân’ın faziletiyle derecelerimizi yükselt ve Kur’ân tilâvetiyle kötülüklerimizi örtüp bağışla, ey fazl ve ihsan sahibi!',
    ),
    HatimDuasiSection(
      order: 4,
      title: '4. Kalp Şifası ve Hüsn-i Hâtime Duası',
      subtitle: 'Din, Dünya ve Ahiret Selâmeti',
      arabic:
          'اَللّٰهُمَّ اَصْلِحْ لَنَا دٖينَنَا الَّذٖي هُوَ عِصْمَةُ اَمْرِنَا ۝ وَاَصْلِحْ لَنَا دُنْيَانَا الَّتٖي فٖيهَا مَعَاشُنَا ۝ وَاَصْلِحْ لَنَا اٰخِرَتَنَا الَّتٖي فٖيهَا مَعَادُنَا ۝ وَاجْعَلِ الْحَيَاةَ زِيَادَةً لَنَا فٖي كُلِّ خَيْرٍ ۝ وَاجْعَلِ الْمَوْتَ رَاحَةً لَنَا مِنْ كُلِّ شَرٍّ ۝ اَللّٰهُمَّ اجْعَلْ خَيْرَ اَعْمَارِنَا اٰخِرَهُ ۝ وَخَيْرَ اَعْمَالِنَا خَوَاتٖيمَهُ ۝ وَخَيْرَ اَيَّامِنَا يَوْمَ نَلْقَاكَ فٖيهِ ۝ اَللّٰهُمَّ طَهِّرْ قُلُوبَنَا وَاَزِلْ عُيُوبَنَا ۝ وَاشْفِ مَرْضَانَا وَاقْضِ دُيُونَنَا ۝ وَفَرِّجْ هُمُومَنَا وَاسْتُرْ عُيُوبَنَا بِحُرْمَةِ الْقُرْاٰنِ الْعَظٖيمِ ۝',
      transliteration:
          'Allâhümme aslih lenâ dînene’llezî hüve ısmetü emrinâ, ve aslih lenâ dünyâne’lletî fîhâ meâşünâ, ve aslih lenâ âhiratene’lletî fîhâ meâdünâ, vec’ali’l-hayâte ziyâdeten lenâ fî külli hayrin, vec’ali’l-mevte râhaten lenâ min külli şerrin. Allâhümmec’al hayra a’mârinâ âhirahû, ve hayra a’mâlinâ havâtîmehû, ve hayra eyyâminâ yevme nelkâke fîh. Allâhümme tahhir kulûbenâ ve ezil uyûbenâ, veşfi merdânâ vakdı düyûnenâ, ve ferric hümûmenâ vestür uyûbenâ bi-hürmeti’l-Kur’âni’l-Azîm.',
      meaning:
          'Allah’ım! İşlerimizin güvencesi olan dinimizi bizim için ıslah eyle, geçimimiz içinde olan dünyamızı ıslah eyle, dönüş yerimiz olan ahiretimizi ıslah eyle! Hayatı bizim için her türlü hayırda artış vesilesi kıl; ölümü de her türlü şerden kurtuluş ve rahata kavuşma vesilesi eyle! Allah’ım! Ömrümüzün en hayırlısını sonu, amellerimizin en hayırlısını son amellerimiz ve günlerimizin en hayırlısını Sana kavuşacağımız gün eyle! Allah’ım! Kur’ân-ı Azîm hürmetine kalplerimizi temizle, kusurlarımızı gider, hastalarımıza şifa ver, borçlarımızı eda eyle, sıkıntılarımızı feraha çıkar ve ayıplarımızı ört!',
    ),
    HatimDuasiSection(
      order: 5,
      title: '5. Sevap Bağışlama (İthaf) ve El-Fâtiha',
      subtitle: 'Okunan Hatm-i Şerifin Ruhlara Hediye Edilmesi',
      arabic:
          'اَللّٰهُمَّ بَلِّغْ وَاَوْصِلْ ثَوَابَ مَا قَرَاْنَاهُ وَنُورَ مَا تَلَوْنَاهُ بَعْدَ الْقَبُولِ مِنَّا بِفَضْلِكَ وَاِحْسَانِكَ هَدِيَّةً وَاصِلَةً وَرَحْمَةً نَازِلَةً اِلٰى رُوحِ سَيِّدِنَا وَنَبِيِّنَا مُحَمَّدٍ الْمُصْطَفٰى صَلَّى اللّٰهُ تَعَالٰى عَلَيْهِ وَسَلَّمَ ۝ وَاِلٰى اَرْوَاحِ جَمٖيعِ الْاَنْبِيَٓاءِ وَالْمُرْسَلٖينَ وَاٰلِهِمْ وَاَصْحَابِهِمُ الطَّيِّبٖينَ الطَّاهِرٖينَ ۝ وَاِلٰى اَرْوَاحِ اٰبَٓائِنَا وَاُمَّهَاتِنَا وَاِخْوَانِنَا وَاَقْرِبَٓائِنَا وَاَسَاتِذَتِنَا وَجَمٖيعِ الْمُؤْمِنٖينَ وَالْمُؤْمِنَاتِ ۝ سُبْحَانَ رَبِّكَ رَبِّ الْعِزَّةِ عَمَّا يَصِفُونَ ۝ وَسَلَامٌ عَلَى الْمُرْسَلٖينَ ۝ وَالْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ ۝ اَلْفَاتِحَةُ ۝',
      transliteration:
          'Allâhümme belliğ ve evsıl sevâbe mâ kara’nâhü ve nûra mâ televnâhü ba’de’l-kabûli minnâ bi-fadlike ve ihsânike hediyyeten vâsıleten ve rahmeten nâzileten ilâ rûhı Seyyidinâ ve Nebiyyinâ Muhammedini’l-Mustafâ sallallâhü teâlâ aleyhi ve sellem, ve ilâ ervâhı cemîi’l-enbiyâi ve’l-mürselîn ve âlihim ve ashâbihimü’t-tayyibîne’t-tâhirîn, ve ilâ ervâhı âbâinâ ve ümmehâtinâ ve ihvâninâ ve akribâinâ ve esâtizetinâ ve cemîi’l-mü’minîne ve’l-mü’minât. Sübhâne Rabbike Rabbi’l-izzeti ammâ yesıfûn, ve selâmün ale’l-mürselîn, ve’l-hamdü lillâhi Rabbi’l-âlemîn. El-Fâtiha.',
      meaning:
          'Allah’ım! Okuduğumuz Kur’ân-ı Kerîm’in sevabını ve tilâvet ettiğimiz âyetlerin nûrunu, fazlın ve ihsanınla bizden kabul buyurduktan sonra, ulaşan bir hediye ve inen bir rahmet olarak başta Efendimiz ve Peygamberimiz Hz. Muhammed Mustafâ (s.a.v.)’in mübarek ruhuna; bütün peygamberlerin, rasûllerin, onların tertemiz âl ve ashabının ruhlarına; anne-babalarımızın, kardeşlerimizin, akrabalarımızın, hocalarımızın ve ahirete irtihal etmiş bütün mümin erkek ve mümin kadınların ruhlarına ulaştır! İzzet sahibi Rabbin, onların yakıştırdığı vasıflardan münezzehtir. Peygamberlere selâm olsun. Hamd, âlemlerin Rabbi olan Allah’a mahsustur. El-Fâtiha!',
    ),
  ];

  /// Tüm bölümlerin (ilk bölümün başındaki Besmele hariç) sıralı Arapça cümle listesi.
  /// Matbû Mushaf görünümünde Besmele üst serlevhada müstakil gösterildiği için
  /// gövde metninde tekrarsız ve durak güllü akış sağlar.
  static List<String> get allMatbuBodyClauses {
    final result = <String>[];
    for (final section in sections) {
      for (final clause in section.arabicClauses) {
        if (section.order == 1 && result.isEmpty && clause == besmele) {
          continue;
        }
        result.add(clause);
      }
    }
    return result;
  }

  static String buildFullShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🤲 $turkishTitle ($arabicTitle)\n');
    for (final s in sections) {
      buffer.writeln('━━━ ${s.title} ━━━');
      buffer.writeln(s.arabic);
      buffer.writeln();
      buffer.writeln('Okunuşu: ${s.transliteration}');
      buffer.writeln();
      buffer.writeln('Anlamı: ${s.meaning}\n');
    }
    buffer.write('— Zikirce Manevi Asistan');
    return buffer.toString();
  }
}
