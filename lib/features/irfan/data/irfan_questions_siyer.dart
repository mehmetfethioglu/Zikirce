import '../domain/irfan_models.dart';

/// 33 Authentic Bilingual (TR/EN) Questions for Siyer-i Nebî & Prophetic History.
const List<IrfanQuestion> kIrfanQuestionsSiyer = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'siy_b_01',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['mevlid', 'kandil'],
    stem: LocalizedText(
      tr: 'Sevgili Peygamberimiz Hz. Muhammed (s.a.v.) kamerî aylardan hangisinde Mekke\'de dünyaya teşrif etmiştir?',
      en: 'In which lunar (Hijri) month was Prophet Muhammad (ﷺ) born in Makkah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Muharrem', en: 'Muharram'),
        LocalizedText(tr: 'Rebîülevvel', en: 'Rabi\' al-Awwal'),
        LocalizedText(tr: 'Recep', en: 'Rajab'),
        LocalizedText(tr: 'Şevvâl', en: 'Shawwal'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Mevlid Kandili\'nin idrak edildiği üçüncü kamerî aydır.',
      en: 'It is the third month of the Islamic calendar, in which Mawlid Night is observed.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber (s.a.v.) Fil Vak\'ası\'ndan kısa süre sonra, milâdî 571 yılı Rebîülevvel ayının 12. Pazartesi gecesi/sabahı Mekke\'de dünyaya gelmiştir.',
        en: 'Prophet Muhammad (ﷺ) was born in Makkah on Monday in the month of Rabi\' al-Awwal in the Year of the Elephant (571 CE).',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Sıyâm 197; İbn Hişâm, es-Sîre, I/158',
        en: 'Muslim, Siyam 197; Ibn Hisham, As-Sirah, I/158',
      ),
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_02',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Peygamber Efendimiz\'e (s.a.v.) nübüvvetten önce de dürüstlüğü ve güvenilirliği sebebiyle Mekke halkının verdiği unvan hangisidir?',
      en: 'What title did the people of Makkah bestow upon Prophet Muhammad (ﷺ) even before prophethood due to his honesty and trustworthiness?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Fârûk', en: 'Al-Faruq'),
        LocalizedText(tr: 'Es-Sıddîk', en: 'As-Siddiq'),
        LocalizedText(tr: 'Muhammedü\'l-Emîn', en: 'Muhammad al-Amin'),
        LocalizedText(tr: 'Zinnûreyn', en: 'Dhun-Nurayn'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Peygamberlerin "Emânet" sıfatıyla aynı kökten gelen "Güvenilir Muhammed" tabiridir.',
      en: 'Meaning "Muhammad the Trustworthy," sharing the root of Amanah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber (s.a.v.) hayatı boyunca asla yalan söylememiş ve emanete ihanet etmemiş; müşrikler dahi en kıymetli emanetlerini ona teslim ederek "el-Emîn" demişlerdir.',
        en: 'Throughout his life, the Prophet (ﷺ) never uttered falsehood or betrayed a trust; even opponents entrusted their valuables to him, calling him Al-Amin.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbn Sa\'d, et-Tabakât, I/121; TDV İslâm Ansiklopedisi, "Muhammed"',
        en: 'Ibn Sa\'d, At-Tabaqat, I/121; TDV Encyclopedia of Islam',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_03',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['ramazan', 'kadir'],
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'e (s.a.v.) ilk vahiy 610 yılı Ramazan ayında Cebel-i Nûr\'daki Hira Mağarası\'nda gelmiştir.',
      en: 'The first revelation came to Prophet Muhammad (ﷺ) in the Cave of Hira on Jabal an-Nur during Ramadan in 610 CE.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Cebrâil (a.s.) Hira\'da Alak Sûresi\'nin ilk beş âyetini ("İkra\'...") tebliğ etmiştir.',
      en: 'Angel Jibril conveyed the first five verses of Surah Al-\'Alaq ("Iqra\'...") in Hira.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber 40 yaşında iken Hira Mağarası\'nda tefekkür hâlindeyken Cebrâil (a.s.) gelerek Alak Sûresi\'nin ilk beş âyetini vahyetmiştir.',
        en: 'At age forty while in spiritual retreat at Cave Hira, Angel Jibril brought the opening five verses of Surah Al-\'Alaq.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Bed\'ü\'l-vahy 3; Müslim, Îmân 252',
        en: 'Bukhari, Bad\' al-Wahy 3; Muslim, Iman 252',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_04',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'İslâm\'ın ilk yıllarında iman ederek Peygamberimiz\'e (s.a.v.) ilk destek olan öncü şahsiyetleri eşleştiriniz.',
      en: 'Match the earliest pioneers who embraced Islam and supported the Prophet (ﷺ).',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Hatîce (r.anhâ)', en: 'Khadijah bint Khuwaylid (r.a.)'),
          right: LocalizedText(tr: 'İlk iman eden insan ve müminlerin annesi', en: 'First person to believe & Mother of Believers'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Ebû Bekir (r.a.)', en: 'Abu Bakr as-Siddiq (r.a.)'),
          right: LocalizedText(tr: 'Hür erkeklerden ilk Müslümanlardan, Sıddîk dost', en: 'Among first adult men to believe, As-Siddiq'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Ali (r.a.)', en: '\'Ali ibn Abi Talib (r.a.)'),
          right: LocalizedText(tr: 'Genç/çocuk yaşta ilk iman eden sahâbî', en: 'First youth to embrace Islam'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Zeyd b. Hârise (r.a.)', en: 'Zayd ibn Harithah (r.a.)'),
          right: LocalizedText(tr: 'Azatlılardan ilk iman eden sahâbî', en: 'First freedman to embrace Islam'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İlk vahiy heyecanında Peygamberimiz\'i ilk teselli edip tasdik eden eşi Hz. Hatîce\'dir.',
      en: 'Khadijah (r.a.) was the very first to comfort and believe in the Messenger of Allah (ﷺ).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"es-Sâbikûne\'l-Evvelûn" olarak anılan bu ilk müminler, en zorlu Mekke yıllarında tevhid sancağını sadakatle taşımışlardır.',
        en: 'Known as As-Sabiqun al-Awwalun (the Foremost Pioneers), they upheld the banner of Tawhid during the hardest Makkan years.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/100; İbn Hişâm, es-Sîre, I/245-250',
        en: 'Surah At-Tawbah, 9:100; Ibn Hisham, As-Sirah, I/245-250',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_05',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['hicret', 'asure'],
    stem: LocalizedText(
      tr: 'Milâdî 622 yılında gerçekleşen ve İslâm (Hicrî) takviminin başlangıcı kabul edilen Hicret hangi iki şehir arasında yapılmıştır?',
      en: 'Between which two cities did the Hijrah of 622 CE—marking the start of the Islamic calendar—take place?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Mekke\'den Kudüs\'e', en: 'From Makkah to Jerusalem'),
        LocalizedText(tr: 'Tâif\'ten Habeşistan\'a', en: 'From Ta\'if to Abyssinia'),
        LocalizedText(tr: 'Medine\'den Şam\'a', en: 'From Madinah to Damascus'),
        LocalizedText(tr: 'Mekke\'den Medine\'ye (Yesrib\'e)', en: 'From Makkah to Madinah (Yathrib)'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Yesrib şehri bu kutlu göçten sonra "Medînetü\'n-Nebî" (Peygamber Şehri) adını almıştır.',
      en: 'After welcoming the Prophet (ﷺ), Yathrib became known as Madinat an-Nabi (Madinah).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '622 yılındaki Hicret ile İslâm\'ın Medine dönemi başlamış; Hz. Ömer\'in hilâfetinde Hicret olayı İslâm takviminin başlangıç yılı ilan edilmiştir.',
        en: 'The Hijrah in 622 CE inaugurated the Madinan era of Islam and was adopted during Caliph \'Umar\'s reign as Year 1 of the Hijri calendar.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Menâkıbü\'l-ensâr 45; TDV İslâm Ansiklopedisi, "Hicret"',
        en: 'Bukhari, Manaqib al-Ansar 45; TDV Encyclopedia of Islam, "Hijrah"',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_06',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Mekke\'den Medine\'ye göç eden Müslümanlara "Ensâr", onları Medine\'de karşılayıp evlerini paylaşanlara ise "Muhâcir" denir.',
      en: 'Muslims who migrated from Makkah were called "Ansar," while the hosts in Madinah were called "Muhajirun."',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Kavramların yeri ters verilmiştir: Göç edenlere Muhâcir, yardım eden Medinelilere Ensâr denir.',
      en: 'The terms are swapped: emigrants are Muhajirun, and the helpers of Madinah are Ansar.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Allah rızası için yurtlarını bırakıp göç edenlere "Muhâcirûn", onlara kucak açıp yardım eden Medineli müminlere ise "Ensâr" denilmiştir.',
        en: 'Those who emigrated for Allah\'s sake are the Muhajirun, while the Madinan believers who aided them are the Ansar.',
      ),
      sourceRef: LocalizedText(
        tr: 'Haşr Sûresi, 59/8-9; Buhârî, Menâkıbü\'l-ensâr 1',
        en: 'Surah Al-Hashr, 59:8-9; Bukhari, Manaqib al-Ansar 1',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_07',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'İslâm tarihinde ilk ezanı gür ve güzel sesiyle okuyan, Peygamberimiz\'in (s.a.v.) müezzini sahâbî kimdir?',
      en: 'Who was the beloved Companion and muezzin of the Prophet (ﷺ) who called the very first Adhan in Islam?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Selmân-ı Fârisî (r.a.)', en: 'Salman al-Farisi (r.a.)'),
        LocalizedText(tr: 'Bilâl-i Habeşî (r.a.)', en: 'Bilal ibn Rabah (r.a.)'),
        LocalizedText(tr: 'Ammâr b. Yâsir (r.a.)', en: '\'Ammar ibn Yasir (r.a.)'),
        LocalizedText(tr: 'Mus\'ab b. Umeyr (r.a.)', en: 'Mus\'ab ibn \'Umayr (r.a.)'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Mekke\'de kızgın kumlar altında bile "Ehad, Ehad!" diyerek tevhide bağlılığını haykıran Habeşli sahâbîdir.',
      en: 'The Abyssinian Companion who proclaimed "Ahad, Ahad!" under persecution in Makkah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Abdullah b. Zeyd\'in (r.a.) gördüğü ve Hz. Ömer\'in (r.a.) de teyit ettiği ezan lafızlarını Hz. Peygamber\'in emriyle ilk kez Hz. Bilâl-i Habeşî okumuştur.',
        en: 'At the command of the Prophet (ﷺ), Bilal ibn Rabah (r.a.) called the first Adhan in Madinah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Salât 28; Tirmizî, Salât 25',
        en: 'Abu Dawud, Salah 28; Tirmidhi, Salah 25',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_08',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['mirac', 'kandil'],
    stem: LocalizedText(
      tr: 'İsrâ ve Mi\'râc mucizesinde Hz. Peygamber\'in (s.a.v.) Mekke\'deki Mescid-i Harâm\'dan geceleyin götürüldüğü kutsal mabed hangisidir?',
      en: 'During the night journey of Isra\', to which sacred sanctuary was the Prophet (ﷺ) taken from Masjid al-Haram?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kuba Mescidi', en: 'Masjid Quba'),
        LocalizedText(tr: 'Mescid-i Kıbleteyn', en: 'Masjid al-Qiblatayn'),
        LocalizedText(tr: 'Mescid-i Aksâ', en: 'Masjid al-Aqsa'),
        LocalizedText(tr: 'Mescid-i Hayf', en: 'Masjid al-Khayf'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'İsrâ Sûresi 1. âyette "çevresini mübarek kıldığımız..." şeklinde övülen Kudüs\'teki ilk kıblemizdir.',
      en: 'Praised in Surah Al-Isra\' 17:1, located in Jerusalem and the first Qiblah of Muslims.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İsrâ, Mescid-i Harâm\'dan Mescid-i Aksâ\'ya gece yürüyüşünü; Mi\'râc ise oradan ilahî huzura yükselişi ifade eder. Beş vakit namaz ve Bakara\'nın son iki âyeti (Âmenerrasûlü) bu gecenin hediyesidir.',
        en: 'Isra\' is the night journey from Makkah to Masjid al-Aqsa, and Mi\'raj is the ascension beyond. Five daily prayers and the closing verses of Al-Baqarah were gifted that night.',
      ),
      sourceRef: LocalizedText(
        tr: 'İsrâ Sûresi, 17/1; Müslim, Îmân 279',
        en: 'Surah Al-Isra\', 17:1; Muslim, Iman 279',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_09',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Hicretin 2. yılı Ramazan ayında gerçekleşen ve Kur\'ân\'da "Yevmü\'l-Furkân" (hak ile bâtılın ayrıldığı gün) olarak anılan ilk büyük gazve hangisidir?',
      en: 'Which first major battle in Ramadan 2 AH is called "Yawm al-Furqan" (the Day of Criterion) in the Qur\'an?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Bedir Gazvesi', en: 'Battle of Badr'),
        LocalizedText(tr: 'Uhud Gazvesi', en: 'Battle of Uhud'),
        LocalizedText(tr: 'Hendek Gazvesi', en: 'Battle of the Trench'),
        LocalizedText(tr: 'Tebük Seferi', en: 'Expedition of Tabuk'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Ramazan\'ın 17. günü Medine yakınlarındaki Bedir kuyuları mevkiinde vuku bulmuştur.',
      en: 'Took place on 17 Ramadan 2 AH near the wells of Badr.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Bedir Gazvesi\'nde sayıca az olan müminler Allah\'a tevekkül ve sabırla zafere ulaşmış; esirlere on Müslümana okuma-yazma öğretme karşılığında hürriyet verilerek ilme verilen değer gösterilmiştir.',
        en: 'At Badr, believers prevailed through steadfast faith; literate captives were freed upon teaching ten Muslims to read and write, highlighting Islam\'s esteem for knowledge.',
      ),
      sourceRef: LocalizedText(
        tr: 'Enfâl Sûresi, 8/41; Âl-i İmrân, 3/123; İbn Sa\'d, II/22',
        en: 'Surah Al-Anfal, 8:41; Ali \'Imran, 3:123; Ibn Sa\'d, II/22',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_10',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Hicretin 8. yılı Ramazan ayında (Milâdî 630) Mekke fethedildiğinde Peygamberimiz (s.a.v.) Kâbe\'yi putlardan temizlemiş ve genel af ilan etmiştir.',
      en: 'Upon the Conquest of Makkah in Ramadan 8 AH (630 CE), the Prophet (ﷺ) cleansed the Ka\'bah of idols and declared a general amnesty.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: '"Bugün size kınama yoktur, hepiniz serbestsiniz!" buyurarak Hz. Yûsuf\'un kardeşlerine söylediği af sözünü hatırlatmıştır.',
      en: 'Echoing Prophet Yusuf\'s forgiveness, he proclaimed: "No blame upon you today; go, for you are free."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mekke\'nin Fethi intikamla değil tevazu ve merhametle gerçekleşmiş; Hz. Peygamber devesinin üzerinde başını secde edercesine eğerek şehre girmiş ve Kâbe\'de tevhidi ihya etmiştir.',
        en: 'Makkah was opened not with vengeance but with humility and mercy; the Prophet (ﷺ) entered bowing his head in gratitude to Allah and restored Tawhid at the Ka\'bah.',
      ),
      sourceRef: LocalizedText(
        tr: 'İsrâ Sûresi, 17/81; İbn Hişâm, es-Sîre, IV/54-55',
        en: 'Surah Al-Isra\', 17:81; Ibn Hisham, As-Sirah, IV/54-55',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_11',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) 632 yılında yüz bini aşkın sahâbîye insan hakları, can-mal emniyeti, kadın hakları ve faiz yasağını ilan ettiği tarihi konuşma hangisidir?',
      en: 'What is the historic address delivered by the Prophet (ﷺ) in 632 CE before over 100,000 Companions affirming human dignity, women\'s rights, and the ban on riba?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Akabe Biatı', en: 'Pledge of \'Aqabah'),
        LocalizedText(tr: 'Medine Vesikası', en: 'Charter of Madinah'),
        LocalizedText(tr: 'Safa Tepesi Çağrısı', en: 'Call on Mount Safa'),
        LocalizedText(tr: 'Veda Hutbesi', en: 'The Farewell Sermon (Khutbat al-Wada\')'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Veda Haccı esnasında Arafat\'ta irad edilen evrensel hitabedir.',
      en: 'Delivered at \'Arafat during his Farewell Pilgrimage.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Veda Hutbesi\'nde ırkçılık ayak altına alınmış, üstünlüğün ancak takvâda olduğu, emanetlerin korunması, kan davalarının ve faizin kaldırıldığı tüm insanlığa ilan edilmiştir.',
        en: 'In the Farewell Sermon, racism, blood feuds, and usury were abolished, affirming that superiority lies solely in piety (taqwa) and upholding trusts.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Hac 147; Ebû Dâvûd, Menâsik 56',
        en: 'Muslim, Hajj 147; Abu Dawud, Manasik 56',
      ),
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'siy_o_01',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Peygamberimiz\'in (s.a.v.) gençliğinde Mekke\'de haksızlığa uğrayan yerli ve yabancı mazlumları korumak amacıyla katıldığı ve nübüvvetten sonra da övgüyle andığı erdemliler cemiyeti hangisidir?',
      en: 'Which pact of chivalry formed in Makkah to defend the wronged did the young Muhammad (ﷺ) join and praise even after prophethood?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Dârü\'n-Nedve', en: 'Dar an-Nadwah'),
        LocalizedText(tr: 'Hilfü\'l-Fudûl', en: 'Hilf al-Fudul (League of the Virtuous)'),
        LocalizedText(tr: 'Dârü\'l-Erkam', en: 'Dar al-Arqam'),
        LocalizedText(tr: 'Ashâb-ı Suffe', en: 'Ashab as-Suffah'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Erdemlilerin Yemini" anlamına gelir; Abdullah b. Cüd\'ân\'ın evinde kurulmuştur.',
      en: 'Meaning "Alliance of the Virtuous," convened at the house of \'Abdullah ibn Jud\'an.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Resûl-i Ekrem (s.a.v.), "İslâm\'da da böyle bir antlaşmaya çağrılsam yine icabet ederdim" buyurarak adaleti ve mazlumun hakkını korumanın evrensel kıymetini vurgulamıştır.',
        en: 'The Prophet (ﷺ) later said, "Had I been invited to it in Islam, I would gladly respond," underscoring the universal duty of defending justice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müsned-i Ahmed, I/190; İbn Hişâm, es-Sîre, I/133',
        en: 'Musnad Ahmad, I/190; Ibn Hisham, As-Sirah, I/133',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_02',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Mekke\'de Müslümanlara yönelik baskıların arttığı dönemde Peygamberimiz\'in (s.a.v.) "Orada kimseye zulmedilmeyen âdil bir hükümdar vardır" diyerek sahâbeyi ilk hicrete yönlendirdiği ülke neresidir?',
      en: 'To which land did the Prophet (ﷺ) direct persecuted Companions for the first migration, saying "Therein is a just king under whom none is wronged"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Yemen', en: 'Yemen'),
        LocalizedText(tr: 'Habeşistan', en: 'Abyssinia (Habashah)'),
        LocalizedText(tr: 'Mısır', en: 'Egypt'),
        LocalizedText(tr: 'Bahreyn', en: 'Bahrain'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Necâşî Ashame\'nin hüküm sürdüğü ve Ca\'fer-i Tayyâr\'ın Meryem Sûresi\'ni okuduğu beldedir.',
      en: 'Ruled by Negus Ashamah, before whom Ja\'far ibn Abi Talib recited Surah Maryam.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Nübüvvetin 5. ve 6. yıllarında gerçekleşen Habeşistan hicretlerinde Necâşî Ashame Müslümanları korumuş; daha sonra iman eden Necâşî vefat ettiğinde Hz. Peygamber onun için gıyâbî cenaze namazı kıldırmıştır.',
        en: 'In the 5th and 6th years of prophethood, Negus Ashamah sheltered the Muslim emigrants; when he later passed away as a believer, the Prophet (ﷺ) led funeral prayer in absentia for him.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Cenâiz 55; İbn Hişâm, es-Sîre, I/321-336',
        en: 'Bukhari, Jana\'iz 55; Ibn Hisham, As-Sirah, I/321-336',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_03',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Birinci Akabe Biatı\'ndan sonra Medinelilere Kur\'ân ve İslâm\'ı öğretmek üzere Hz. Peygamber (s.a.v.) tarafından gönderilen "İslâm\'ın İlk Muallimi" sahâbî kimdir?',
      en: 'Which Companion was sent by the Prophet (ﷺ) to Madinah after the First Pledge of \'Aqabah as "the First Teacher of Islam"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Muâz b. Cebel (r.a.)', en: 'Mu\'adh ibn Jabal (r.a.)'),
        LocalizedText(tr: 'Ebû Ubeyde b. Cerrâh (r.a.)', en: 'Abu \'Ubaydah ibn al-Jarrah (r.a.)'),
        LocalizedText(tr: 'Mus\'ab b. Umeyr (r.a.)', en: 'Mus\'ab ibn \'Umayr (r.a.)'),
        LocalizedText(tr: 'Zübeyr b. Avvâm (r.a.)', en: 'Az-Zubayr ibn al-\'Awwam (r.a.)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Mekke\'nin en varlıklı gençlerinden iken tüm servetini İslâm uğruna bırakıp Uhud\'da sancaktar olarak şehid düşen sahâbîdir.',
      en: 'A refined Makkan youth who gave up worldly luxury for faith and fell as standard-bearer at Uhud.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mus\'ab b. Umeyr\'in (r.a.) hikmetli, tatlı dilli tebliği sayesinde bir yıl içinde Medine\'de İslâm\'ın konuşulmadığı ev kalmamış ve Hicret zemini hazırlanmıştır.',
        en: 'Through Mus\'ab ibn \'Umayr\'s gentle wisdom and Qur\'an teaching, Islam entered nearly every household of Madinah before the Hijrah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Megâzî 17; İbn Sa\'d, et-Tabakât, III/118',
        en: 'Bukhari, Maghazi 17; Ibn Sa\'d, At-Tabaqat, III/118',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_04',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hicret yolculuğu esnasında Hz. Peygamber (s.a.v.) ve yol arkadaşı Hz. Ebû Bekir\'in (r.a.) üç gün gizlendikleri ve Tevbe Sûresi 40. âyette "Üzülme, Allah bizimle beraberdir!" tesellisinin yankılandığı mağara hangisidir?',
      en: 'In which cave did the Prophet (ﷺ) and Abu Bakr (r.a.) take refuge for three nights during the Hijrah, immortalized in Surah At-Tawbah 9:40?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hira Mağarası', en: 'Cave of Hira'),
        LocalizedText(tr: 'Sevr Mağarası', en: 'Cave of Thawr'),
        LocalizedText(tr: 'Ashâb-ı Kehf Mağarası', en: 'Cave of Al-Kahf'),
        LocalizedText(tr: 'Uhud Kaya Sığınağı', en: 'Cleft of Mount Uhud'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Hira ilk vahyin geldiği mağaradır; Hicret\'te Mekke\'nin güney yönünde sığınılan mağara farklıdır.',
      en: 'Hira was the site of first revelation; during Hijrah they headed south first to another mountain cave.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber önce tüm tedbirleri alarak güneydeki Sevr Mağarası\'na yönelmiş, ardından "Lâ tahzen innallâhe meanâ" (Üzülme, şüphesiz Allah bizimle beraberdir) diyerek tam tevekkülü öğretmiştir.',
        en: 'Taking wise precaution by heading south to Cave Thawr, the Prophet (ﷺ) reassured Abu Bakr with "La tahzan innallaha ma\'ana" (Do not grieve; indeed Allah is with us).',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/40; Buhârî, Tefsîr 9/9',
        en: 'Surah At-Tawbah, 9:40; Bukhari, Tafsir 9/9',
      ),
      linkedZikirKey: 'Hasbünallahu ve ni\'mel vekil',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_05',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Mescid-i Nebevî\'nin bitişiğinde kurulan, kimsesiz ve ilim âşığı sahâbîlerin barınıp bizzat Peygamberimiz\'den ders aldığı İslâm\'ın ilk yatılı eğitim halkasına ne ad verilir?',
      en: 'What was the name of the shaded platform adjoining Masjid an-Nabawi that served as Islam\'s first residential academy of knowledge?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Beytü\'l-Hikme', en: 'Bayt al-Hikmah'),
        LocalizedText(tr: 'Suffe (Ashâb-ı Suffe)', en: 'As-Suffah (Ashab as-Suffah)'),
        LocalizedText(tr: 'Nizâmiye Medresesi', en: 'Nizamiyyah Madrasah'),
        LocalizedText(tr: 'Dârü\'l-Kurrâ', en: 'Dar al-Qurra\''),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Ebû Hüreyre (r.a.) gibi çok hadis rivayet eden sahâbîlerin yetiştiği gölgelik mekândır.',
      en: 'Where prolific Hadith transmitters like Abu Hurayrah (r.a.) dedicated themselves to learning.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ashâb-ı Suffe gündüzleri ilim, Kur\'ân ve hadis tahsil etmiş; ihtiyaç duyulan bölgelere muallim olarak gönderilmiştir.',
        en: 'The Companions of the Suffah devoted their lives to studying the Qur\'an and Sunnah directly from the Prophet (ﷺ) and teaching distant tribes.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/273; Buhârî, Rikâk 17',
        en: 'Surah Al-Baqarah, 2:273; Bukhari, Riqaq 17',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_06',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Asr-ı Saadet\'teki önemli gazve ve hadiseleri öne çıkan özellikleriyle eşleştiriniz.',
      en: 'Match these key events of the Prophetic era with their defining features.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Uhud Gazvesi (H. 3)', en: 'Battle of Uhud (3 AH)'),
          right: LocalizedText(tr: 'Aynen Tepesi okçularının imtihanı ve Hz. Hamza\'nın şehâdeti', en: 'Archers\' test on Mount \'Aynayn & martyrdom of Hamzah'),
        ),
        (
          left: LocalizedText(tr: 'Hendek / Ahzâb Gazvesi (H. 5)', en: 'Battle of the Trench (5 AH)'),
          right: LocalizedText(tr: 'Selmân-ı Fârisî\'nin istişaresiyle Medine önüne hendek kazılması', en: 'Digging a defensive trench on Salman al-Farisi\'s counsel'),
        ),
        (
          left: LocalizedText(tr: 'Hudeybiye Antlaşması (H. 6)', en: 'Treaty of Hudaybiyyah (6 AH)'),
          right: LocalizedText(tr: 'Fetih Sûresi\'nde "Apaçık Fetih" (Feth-i Mübîn) diye müjdelenen barış', en: 'Peace treaty heralded as a "Clear Victory" in Surah Al-Fath'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Hendek fikri Selmân-ı Fârisî\'ye (r.a.) aittir; Hudeybiye ise barış ortamıyla İslâm\'ın hızla yayılmasını sağlamıştır.',
      en: 'Salman al-Farisi proposed the trench; Hudaybiyyah\'s peace enabled rapid voluntary entry into Islam.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Uhud emre itaatin önemini, Hendek istişare ve sabrı, Hudeybiye ise sulh ve basiretin en büyük fetih olduğunu ümmete öğretmiştir.',
        en: 'Uhud taught obedience to Prophetic command, the Trench taught consultation (shura), and Hudaybiyyah proved strategic peace to be a manifest victory.',
      ),
      sourceRef: LocalizedText(
        tr: 'Fetih Sûresi, 48/1; Buhârî, Megâzî 17, 29, 35',
        en: 'Surah Al-Fath, 48:1; Bukhari, Maghazi 17, 29, 35',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_07',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) amcası Ebû Tâlib ile vefakâr eşi Hz. Hatîce vâlidemizin peş peşe vefat ettiği nübüvvetin 10. yılı Siyer kaynaklarında "Senetü\'l-Hüzn" (Hüzün Yılı) olarak anılır.',
      en: 'The tenth year of prophethood, in which both Abu Talib and Khadijah (r.a.) passed away, is known in Sirah literature as "Sanat al-Huzn" (the Year of Sorrow).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Bu ağır imtihanların ardından Cenâb-ı Hak Resûlü\'nü İsrâ ve Mi\'râc mucizesiyle teselli etmiştir.',
      en: 'Following this deep grief and the trial at Ta\'if, Allah honored His Messenger with Isra\' and Mi\'raj.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Hatîce içeride en büyük mânevî dayanak, Ebû Tâlib dışarıda kabile himayesiydi; vefatlarının ardından yaşanan Tâif yolculuğu sabır ve dua zirvesi olmuştur.',
        en: 'Khadijah was the Prophet\'s greatest inner support and Abu Talib his external clan protector; their passing ushered in a season of profound patience and prayer.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbn Sa\'d, et-Tabakât, I/210; TDV İslâm Ansiklopedisi, "Senetü\'l-Hüzn"',
        en: 'Ibn Sa\'d, At-Tabaqat, I/210; TDV Encyclopedia of Islam',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_08',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Dört Halife (Hulefâ-yi Râşidîn) döneminin kronolojik sırası hangi seçenekte doğru verilmiştir?',
      en: 'Which option gives the correct chronological order of the Four Rightly Guided Caliphs (Khulafa\' ar-Rashidun)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hz. Ebû Bekir → Hz. Ömer → Hz. Osman → Hz. Ali',
          en: 'Abu Bakr → \'Umar → \'Uthman → \'Ali',
        ),
        LocalizedText(
          tr: 'Hz. Ömer → Hz. Ebû Bekir → Hz. Ali → Hz. Osman',
          en: '\'Umar → Abu Bakr → \'Ali → \'Uthman',
        ),
        LocalizedText(
          tr: 'Hz. Ebû Bekir → Hz. Ali → Hz. Ömer → Hz. Osman',
          en: 'Abu Bakr → \'Ali → \'Umar → \'Uthman',
        ),
        LocalizedText(
          tr: 'Hz. Osman → Hz. Ebû Bekir → Hz. Ömer → Hz. Ali',
          en: '\'Uthman → Abu Bakr → \'Umar → \'Ali',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '632-634 Hz. Ebû Bekir, 634-644 Hz. Ömer, 644-656 Hz. Osman ve 656-661 Hz. Ali (r.anhüm).',
      en: '632–634 Abu Bakr, 634–644 \'Umar, 644–656 \'Uthman, and 656–661 \'Ali (r.a.).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hulefâ-yi Râşidîn devri (632-661), adalet, şûrâ, Kur\'ân\'ın cem ve istinsahı ile İslâm medeniyetinin temellerinin atıldığı otuz yıllık örnek dönemdir.',
        en: 'The thirty-year era of the Rightly Guided Caliphs (632–661 CE) exemplified justice, consultation, and the preservation of the Qur\'anic Mushaf.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Sünnet 8; Tirmizî, Fiten 48',
        en: 'Abu Dawud, Sunnah 8; Tirmidhi, Fitan 48',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_09',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    specialDayTags: ['asure'],
    stem: LocalizedText(
      tr: 'Muharrem ayının 10. günü (Âşûrâ günü), Hz. Mûsâ (a.s.) ve İsrâiloğulları\'nın Firavun\'un zulmünden kurtulduğu gün olarak hadislerde zikredilmiş ve şükür orucu tavsiye edilmiştir.',
      en: 'The 10th of Muharram (Day of \'Ashura) is mentioned in authentic Hadiths as the day Allah saved Prophet Musa (a.s.) from Pharaoh, for which fasting in gratitude is recommended.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Hz. Peygamber (s.a.v.) Âşûrâ orucunu tutmuş ve Muharrem\'in 9-10 veya 10-11. günleriyle birlikte tutulmasını tavsiye buyurmuştur.',
      en: 'The Prophet (ﷺ) fasted \'Ashura in gratitude and advised adding the 9th or 11th of Muharram.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İbn Abbâs\'tan (r.a.) rivayet edildiğine göre Resûlullah (s.a.v.) Medine\'de Âşûrâ günü Hz. Mûsâ\'nın kurtuluşuna şükür olarak oruç tutmuş, "Biz Mûsâ\'ya sizden daha yakınız" buyurmuştur.',
        en: 'As narrated by Ibn \'Abbas (r.a.), the Prophet (ﷺ) fasted on \'Ashura in gratitude for Prophet Musa\'s deliverance, saying "We have closer claim to Musa."',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Savm 69; Müslim, Sıyâm 127',
        en: 'Bukhari, Sawm 69; Muslim, Siyam 127',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_10',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Mekke\'de Kâbe-i Muazzama\'nın temellerini Allah\'ın emriyle yükselten baba-oğul iki peygamber kimlerdir?',
      en: 'Which father-and-son pair of prophets raised the foundations of the Ka\'bah in Makkah by Allah\'s command?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hz. Yâkûb ve Hz. Yûsuf (a.s.)', en: 'Prophets Ya\'qub and Yusuf (a.s.)'),
        LocalizedText(tr: 'Hz. Dâvûd ve Hz. Süleyman (a.s.)', en: 'Prophets Dawud and Sulayman (a.s.)'),
        LocalizedText(tr: 'Hz. İbrâhim ve Hz. İsmâil (a.s.)', en: 'Prophets Ibrahim and Isma\'il (a.s.)'),
        LocalizedText(tr: 'Hz. Zekeriyyâ ve Hz. Yahyâ (a.s.)', en: 'Prophets Zakariyya and Yahya (a.s.)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Bakara Sûresi 127. âyette "Rabbenâ tekabbel minnâ..." diyerek dua ederek Beytullah\'ı inşa eden peygamberlerdir.',
      en: 'Mentioned in Surah Al-Baqarah 2:127 supplicating "Rabbana taqabbal minna..." while building the Sacred House.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. İbrâhim ve oğlu Hz. İsmâil (a.s.), yeryüzünde tevhid mabedi olan Kâbe\'nin duvarlarını yükseltirken amellerinin kabulü ve nesillerinden teslim olmuş bir ümmet çıkması için dua etmişlerdir.',
        en: 'Prophets Ibrahim and Isma\'il (a.s.) raised the foundations of the Ka\'bah while praying for acceptance and a devoted Ummah from their descendants.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/127-128; İbrâhim Sûresi, 14/37',
        en: 'Surah Al-Baqarah, 2:127-128; Surah Ibrahim, 14:37',
      ),
      linkedZikirKey: 'İbrâhim (a.s.) Duası 1',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_11',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Medine\'ye hicretten hemen sonra Müslümanlar ve şehirdeki diğer topluluklar arasında ortak savunma, din hürriyeti ve adalet esaslarını kayda geçiren tarihi metin hangisidir?',
      en: 'Which historic document drafted shortly after the Hijrah established mutual defense, religious freedom, and legal order among Madinah\'s communities?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Rıdvân Biatı', en: 'Pledge of Ridwan'),
        LocalizedText(tr: 'Medine Vesikası (Sahîfesi)', en: 'The Charter of Madinah (Sahifat al-Madinah)'),
        LocalizedText(tr: 'Necran Ahidnâmesi', en: 'Covenant of Najran'),
        LocalizedText(tr: 'Veda Hutbesi', en: 'The Farewell Sermon'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Hukuk tarihçilerince dünyadaki ilk yazılı anayasal metinlerden biri kabul edilen sözleşmedir.',
      en: 'Recognized by legal historians as one of the earliest written constitutional charters in world history.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '47 maddelik Medine Vesikası, farklı inanç ve kabileleri hukuk devleti ilkeleri etrafında birleştirmiş ve anlaşmazlıklarda Hz. Peygamber\'in hakemliğini esas almıştır.',
        en: 'Comprising 47 clauses, the Charter of Madinah bound diverse tribes and faiths under rule of law, mutual security, and Prophetic arbitration.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbn Hişâm, es-Sîre, II/147-150; Hamidullah, el-Vesâiku\'s-Siyâsiyye',
        en: 'Ibn Hisham, As-Sirah, II/147-150; Hamidullah, Al-Watha\'iq as-Siyasiyyah',
      ),
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'siy_i_01',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de "Ülü\'l-Azm" (en büyük sabır ve azim sahibi) olarak öne çıkan beş büyük peygamber hangi seçenekte eksiksiz verilmiştir?',
      en: 'Which option correctly lists the five "Ulu\'l-\'Azm" (Arch-Prophets of Greatest Resolve) highlighted in the Qur\'an?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hz. Âdem, Hz. İdrîs, Hz. Sâlih, Hz. Hûd, Hz. Şuayb',
          en: 'Adam, Idris, Salih, Hud, Shu\'ayb',
        ),
        LocalizedText(
          tr: 'Hz. Nûh, Hz. İbrâhim, Hz. Mûsâ, Hz. Îsâ, Hz. Muhammed (s.a.v.)',
          en: 'Nuh, Ibrahim, Musa, \'Isa, and Muhammad (ﷺ)',
        ),
        LocalizedText(
          tr: 'Hz. Yûsuf, Hz. Dâvûd, Hz. Süleyman, Hz. Yûnus, Hz. Eyyûb',
          en: 'Yusuf, Dawud, Sulayman, Yunus, Ayyub',
        ),
        LocalizedText(
          tr: 'Hz. İsmâil, Hz. İshak, Hz. Yâkûb, Hz. Hârûn, Hz. Yahyâ',
          en: 'Isma\'il, Ishaq, Ya\'qub, Harun, Yahya',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Ahzâb Sûresi 7. ve Şûrâ Sûresi 13. âyetlerde isimleri bir arada zikredilen beş peygamberdir.',
      en: 'Named together explicitly in Surah Al-Ahzab 33:7 and Surah Ash-Shura 42:13.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ahzâb 7 ve Şûrâ 13. âyetlerde özel ahid alınan ve en çetin tebliğ imtihanlarına göğüs geren Hz. Nûh, Hz. İbrâhim, Hz. Mûsâ, Hz. Îsâ ve Hz. Muhammed (s.a.v.) Ülü\'l-Azm peygamberlerdir.',
        en: 'Mentioned together in Al-Ahzab 33:7 and Ash-Shura 42:13, Nuh, Ibrahim, Musa, \'Isa, and Muhammad (ﷺ) bore the heaviest covenants and trials of prophethood.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ahzâb, 33/7; Şûrâ, 42/13; Ahkâf, 46/35',
        en: 'Al-Ahzab 33:7; Ash-Shura 42:13; Al-Ahqaf 46:35',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_02',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Güzide sahâbîleri Peygamber Efendimiz\'in (s.a.v.) onlara verdiği unvan ve vazifelerle eşleştiriniz.',
      en: 'Match these distinguished Companions with their Prophetic titles and roles.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Zeyd b. Sâbit (r.a.)', en: 'Zayd ibn Thabit (r.a.)'),
          right: LocalizedText(tr: 'Vahiy kâtibi ve Mushaf\'ı cem eden heyet başkanı', en: 'Chief revelation scribe & head of Mushaf compilation'),
        ),
        (
          left: LocalizedText(tr: 'Ebû Ubeyde b. Cerrâh (r.a.)', en: 'Abu \'Ubaydah ibn al-Jarrah (r.a.)'),
          right: LocalizedText(tr: 'Ümmetin Emîni (Emînü hâzihi\'l-ümme)', en: 'The Trustworthy One of this Ummah'),
        ),
        (
          left: LocalizedText(tr: 'Muâz b. Cebel (r.a.)', en: 'Mu\'adh ibn Jabal (r.a.)'),
          right: LocalizedText(tr: 'Helâl ve haramı en iyi bilen Yemen elçisi/kadısı', en: 'Foremost scholar of halal/haram & envoy to Yemen'),
        ),
        (
          left: LocalizedText(tr: 'Hassân b. Sâbit (r.a.)', en: 'Hassan ibn Thabit (r.a.)'),
          right: LocalizedText(tr: 'Şâirü\'n-Nebî (Peygamber Şairi)', en: 'Sha\'ir an-Nabi (Poet of the Prophet)'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân\'ın iki kapak arasına toplanmasında (cem\') baş görevli Zeyd b. Sâbit\'tir; "Ümmetin Emîni" ise Ebû Ubeyde\'dir.',
      en: 'Zayd ibn Thabit led the compilation of the Qur\'an, while Abu \'Ubaydah was titled Amin al-Ummah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber (s.a.v.) sahâbîlerinin kabiliyetlerini en hikmetli biçimde keşfedip yönlendirmiş; ilim, hukuk, diplomasi ve edebiyat sahalarında öncü nesil yetiştirmiştir.',
        en: 'The Prophet (ﷺ) recognized and cultivated each Companion\'s unique gifts across scholarship, jurisprudence, governance, and eloquence.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Fedâilü\'s-sahâbe 21, Fedâilü\'l-Kur\'ân 3; Tirmizî, Menâkıb 32',
        en: 'Bukhari, Fada\'il as-Sahabah 21, Fada\'il al-Qur\'an 3; Tirmidhi, Manaqib 32',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_03',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Mekke\'de İslâm\'ın ilk yıllarında Safâ Tepesi eteğinde bulunan ve Peygamberimiz\'in (s.a.v.) sahâbîlere gizlice tebliğ ve eğitim yaptığı ev kime aitti?',
      en: 'Whose house near Mount Safa served as the center of teaching and gathering for early Muslims during the Makkan period?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Ebû Eyyûb el-Ensârî (r.a.)', en: 'Abu Ayyub al-Ansari (r.a.)'),
        LocalizedText(tr: 'Erkam b. Ebü\'l-Erkam (r.a.)', en: 'Al-Arqam ibn Abi\'l-Arqam (r.a.)'),
        LocalizedText(tr: 'Sa\'d b. Muâz (r.a.)', en: 'Sa\'d ibn Mu\'adh (r.a.)'),
        LocalizedText(tr: 'Es\'ad b. Zürâre (r.a.)', en: 'As\'ad ibn Zurarah (r.a.)'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'İslâm tarihinde "Dârü\'l-Erkam" adıyla meşhur olan ve Hz. Ömer\'in de burada Müslüman olduğu mekândır.',
      en: 'Known in Islamic history as Dar al-Arqam, where \'Umar ibn al-Khattab also embraced Islam.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Henüz 17-18 yaşlarında genç bir sahâbî olan Erkam b. Ebü\'l-Erkam\'ın evi (Dârü\'l-Erkam), Mekke döneminde tevhid mektebi olmuş, Hz. Hamza ve Hz. Ömer burada İslâm\'la müşerref olmuştur.',
        en: 'The home of the young Companion Al-Arqam near Safa served as the sanctuary where early Muslims learned the Qur\'an and where Hamzah and \'Umar accepted Islam.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbn Sa\'d, et-Tabakât, III/242; TDV İslâm Ansiklopedisi, "Dârülerkam"',
        en: 'Ibn Sa\'d, At-Tabaqat, III/242; TDV Encyclopedia of Islam, "Dar al-Arqam"',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_04',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hicretin 6. yılında Hudeybiye\'de Mekke\'ye elçi gönderilen Hz. Osman\'ın şehid edildiği şâyiası yayılınca 1400 civarında sahâbînin ağaç altında Peygamberimiz\'e verdiği ve Kur\'ân\'da Allah\'ın hoşnutluğuyla müjdelenen biat hangisidir?',
      en: 'What was the pledge taken under a tree by ~1,400 Companions at Hudaybiyyah, praised in Surah Al-Fath with Allah\'s pleasure?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Birinci Akabe Biatı', en: 'First Pledge of \'Aqabah'),
        LocalizedText(tr: 'İkinci Akabe Biatı', en: 'Second Pledge of \'Aqabah'),
        LocalizedText(tr: 'Bey\'atü\'r-Rıdvân (Rıdvân Biatı)', en: 'Bay\'at ar-Ridwan (Pledge of Pleasure)'),
        LocalizedText(tr: 'Kadîsiyye Ahdi', en: 'Covenant of Qadisiyyah'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Fetih Sûresi 18. âyetteki "Lekad radıyallâhü ani\'l-mü\'minîne..." (Andolsun Allah o müminlerden razı oldu) ifadesinden adını alır.',
      en: 'Named after Surah Al-Fath 48:18 ("Certainly was Allah pleased [radiya] with the believers when they pledged allegiance to you under the tree").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Semüre ağacı altında yapılan Bey\'atü\'r-Rıdvân\'da Hz. Peygamber bir elini diğer elinin üzerine koyarak orada bulunamayan Hz. Osman adına da biat almış; bu birlik Mekkelileri barışa razı etmiştir.',
        en: 'Under the acacia tree at Hudaybiyyah, the Prophet (ﷺ) clasped his own hand on behalf of the absent \'Uthman; this resolve led directly to the Hudaybiyyah peace treaty.',
      ),
      sourceRef: LocalizedText(
        tr: 'Fetih Sûresi, 48/10, 18; Buhârî, Megâzî 35',
        en: 'Surah Al-Fath, 48:10, 18; Bukhari, Maghazi 35',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_05',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Medine\'ye hicret eden Hz. Peygamber\'i (s.a.v.) Mescid-i Nebevî ve hâne-i saadet inşa edilinceye kadar yaklaşık yedi ay evinde misafir etme şerefine nail olan sahâbî Ebû Eyyûb el-Ensârî\'dir (Hâlid b. Zeyd).',
      en: 'Abu Ayyub al-Ansari (Khalid ibn Zayd, r.a.) had the honor of hosting the Prophet (ﷺ) in his home in Madinah until Masjid an-Nabawi and its quarters were built.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Kabri İstanbul Eyüpsultan\'da bulunan ve "Mihmândâr-ı Nebî" unvanıyla anılan büyük sahâbîdir.',
      en: 'Known as "Mihmandar-i Nabi" (Host of the Prophet), whose resting place is in Eyüpsultan, Istanbul.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Deve Kusvâ\'nın çöktüğü arsa satın alınıp Mescid-i Nebevî tamamlanana dek Hz. Peygamber\'i büyük edeple ağırlayan Ebû Eyyûb el-Ensârî (r.a.), ilerlemiş yaşında İstanbul kuşatmasına katılarak vefat etmiştir.',
        en: 'Abu Ayyub al-Ansari (r.a.) hosted the Messenger of Allah (ﷺ) with utmost reverence in Madinah and decades later joined the expedition to Constantinople in advanced age.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Eşribe 170; İbn Hişâm, es-Sîre, II/141',
        en: 'Muslim, Ashribah 170; Ibn Hisham, As-Sirah, II/141',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_06',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'den (s.a.v.) en çok hadis rivayet eden (Müksirûn) yedi sahâbî arasında kadınların fıkıh ve hadis muallimi olarak yer alan müminlerin annesi kimdir?',
      en: 'Which Mother of the Believers ranks among the seven most prolific narrators of Hadith (al-Mukthirun) and served as a foremost jurist among the Companions?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hz. Sevde bint Zem\'a (r.anhâ)', en: 'Sawdah bint Zam\'ah (r.a.)'),
        LocalizedText(tr: 'Hz. Âişe bint Ebî Bekr (r.anhâ)', en: '\'A\'ishah bint Abi Bakr (r.a.)'),
        LocalizedText(tr: 'Hz. Zeyneb bint Cahş (r.anhâ)', en: 'Zaynab bint Jahsh (r.a.)'),
        LocalizedText(tr: 'Hz. Mariye (r.anhâ)', en: 'Mariyah al-Qibtiyyah (r.a.)'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '2210 hadis rivayet etmiş ve büyük sahâbîlerin dahi fıkhî meselelerde görüşüne başvurduğu âlime sahâbîdir.',
      en: 'She narrated over 2,200 hadiths and was consulted by senior Companions on complex legal and textual matters.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Âişe (r.anhâ), tefsir, hadis, fıkıh ve Arap edebiyatındaki derin ilmiyle İslâm medeniyetinde kadın âlim geleneğinin en parlak öncüsü olmuştur.',
        en: '\'A\'ishah (r.a.), through her mastery of Qur\'anic exegesis, Hadith, jurisprudence, and poetry, became the luminous cornerstone of female scholarship in Islam.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Menâkıb 63; Zehebî, Siyeru A\'lâmi\'n-Nübelâ, II/135',
        en: 'Tirmidhi, Manaqib 63; Adh-Dhahabi, Siyar A\'lam an-Nubala\', II/135',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_07',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Tevbe Sûresi 108. âyette "İlk günden takvâ temeli üzerine kurulan mescid" diye övülen ve İslâm tarihinde inşa edilen ilk mescid hangisidir?',
      en: 'Which mosque—praised in Surah At-Tawbah 9:108 as "a mosque founded upon righteousness (taqwa) from the first day"—was the first mosque built in Islamic history?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Cüvâsâ Mescidi', en: 'Masjid Juwatha'),
        LocalizedText(tr: 'Gâmâme Mescidi', en: 'Masjid al-Ghamamah'),
        LocalizedText(tr: 'Kuba Mescidi', en: 'Masjid Quba'),
        LocalizedText(tr: ' Amr b. Âs Camii', en: 'Mosque of \'Amr ibn al-\'As'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Hicret esnasında Medine\'ye varmadan hemen önce Kuba köyünde bizzat Peygamberimiz\'in taş taşıyarak temelini attığı mesciddir.',
      en: 'Built on the outskirts of Madinah at Quba upon the Prophet\'s arrival during the Hijrah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahih hadiste "Kim evinde güzelce abdest alır, Kuba Mescidi\'ne gelip namaz kılarsa kendisine bir umre sevabı verilir" müjdesi yer almaktadır.',
        en: 'In an authentic hadith, the Prophet (ﷺ) taught that purifying oneself at home and praying in Masjid Quba carries the reward of an \'Umrah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/108; İbn Mâce, İkâmet 197; Buhârî, Fazlü\'s-salât 2',
        en: 'Surah At-Tawbah, 9:108; Ibn Majah, Iqamah 197; Bukhari, Fadl as-Salah 2',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_08',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Dünyada iken tek bir hadis metninde ismen cennetle müjdelenen on büyük sahâbîye "Aşere-i Mübeşşere" denir.',
      en: 'The ten Companions promised Paradise together by name in a single Prophetic narration during their lifetimes are known as "al-\'Asharah al-Mubashsharah."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Dört Halife ile Talha, Zübeyr, Abdurrahman b. Avf, Sa\'d b. Ebî Vakkâs, Saîd b. Zeyd ve Ebû Ubeyde b. Cerrâh\'tan (r.anhüm) oluşur.',
      en: 'Comprising the Four Caliphs along with Talhah, Az-Zubayr, \'Abdurrahman ibn \'Awf, Sa\'d ibn Abi Waqqas, Sa\'id ibn Zayd, and Abu \'Ubaydah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Aşere-i Mübeşşere\'nin tamamı İslâm\'ın ilk günlerinde iman etmiş, Habeşistan ve Medine hicretlerinde, Bedir ve Rıdvân\'da en ön safta fedakârlık göstermiş sahâbîlerdir.',
        en: 'All ten embraced Islam in its earliest days, enduring persecution and standing steadfast through Hijrah, Badr, and Ridwan.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Menâkıb 25; Ebû Dâvûd, Sünnet 8',
        en: 'Tirmidhi, Manaqib 25; Abu Dawud, Sunnah 8',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_09',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Tevbe Sûresi\'nde "Ceyşü\'l-Usre" (Zorluk Ordusu) olarak nitelendirilen, kavurucu sıcak ve kıtlıkta Hicretin 9. yılında Bizans sınırına düzenlenen ve Hz. Osman\'ın büyük infakıyla donatılan sefer hangisidir?',
      en: 'Which expedition of 9 AH—called "Jaysh al-\'Usrah" (the Army of Hardship) in Surah At-Tawbah and generously outfitted by \'Uthman (r.a.)—marched in scorching heat toward the northern frontier?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hayber Gazvesi', en: 'Expedition of Khaybar'),
        LocalizedText(tr: 'Huneyn Gazvesi', en: 'Battle of Hunayn'),
        LocalizedText(tr: 'Mûte Seriyyesi', en: 'Battle of Mu\'tah'),
        LocalizedText(tr: 'Tebük Gazvesi', en: 'Expedition of Tabuk'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) bizzat katıldığı son gazvedir.',
      en: 'It was the final military expedition personally led by the Prophet (ﷺ).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tebük Seferi ihlas ile nifakın ayrıştığı çetin bir imtihan olmuş; çarpışma olmaksızın kuzey kabileleriyle barış ve güvenlik antlaşmaları imzalanarak dönülmüştür.',
        en: 'Tabuk tested sincere devotion under extreme heat and scarcity, concluding peacefully with northern treaties without battle.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/117; Buhârî, Megâzî 78',
        en: 'Surah At-Tawbah, 9:117; Bukhari, Maghazi 78',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_10',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Peygamberler tarihindeki nebevî mucize ve imtihanları ilgili peygamberlerle eşleştiriniz.',
      en: 'Match these Qur\'anic prophetic trials and miracles with the respective Prophets.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Eyyûb (a.s.)', en: 'Prophet Ayyub (Job)'),
          right: LocalizedText(tr: 'Uzun hastalık imtihanında sabır ve şükür timsali', en: 'Exemplar of patience and gratitude through prolonged illness'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Yûsuf (a.s.)', en: 'Prophet Yusuf (Joseph)'),
          right: LocalizedText(tr: 'Kuyudan ve zindandan Mısır hazinedarlığına uzanan iffet ve af', en: 'Chastity and forgiveness from the well and prison to stewardship of Egypt'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Yûnus (a.s.)', en: 'Prophet Yunus (Jonah)'),
          right: LocalizedText(tr: 'Balığın karnında karanlıklar içinde tesbih ve istiğfar', en: 'Glorification and repentance from the depths within the whale'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: '"Eyyûb sabrı", "Yûsuf kıssası" (Ahsenü\'l-kasas) ve "Yûnus duası" (Enbiyâ 87) Kur\'ân\'ın en derin ibret tablolarıdır.',
      en: 'Ayyub\'s patience, Yusuf\'s story, and Yunus\'s plea in Al-Anbiya\' 21:87 are timeless Qur\'anic lessons.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân\'daki peygamber kıssaları geçmişin hikâyesi değil, müminin darlıkta sabır, bollukta iffet ve hatada tevbe rehberidir.',
        en: 'Prophetic narratives in the Qur\'an guide the believer\'s heart toward patience in trial, chastity in ease, and swift repentance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Enbiyâ, 21/83-88; Yûsuf, 12/3, 92',
        en: 'Surah Al-Anbiya\', 21:83-88; Surah Yusuf, 12:3, 92',
      ),
      linkedZikirKey: 'Yûnus (a.s.) Duası',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_11',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hicretin 7. yılında komşu hükümdarlara İslâm\'a davet mektupları gönderilirken mühürsüz mektupların okunmadığı bildirilince Hz. Peygamber\'in (s.a.v.) yaptırdığı gümüş yüzük mühürde aşağıdan yukarıya hangi ibare kazılıydı?',
      en: 'When diplomatic letters were sent to neighboring rulers in 7 AH, what three-line inscription (read bottom-to-top) was engraved on the Prophet\'s (ﷺ) silver signet ring?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Muhammed Resûlullâh', en: 'Muhammad Rasul Allah'),
        LocalizedText(tr: 'El-Mülkü Lillâh', en: 'Al-Mulku Lillah'),
        LocalizedText(tr: 'Nasrun Minallâh', en: 'Nasrun Min Allah'),
        LocalizedText(tr: 'El-Hükmü Lillâh', en: 'Al-Hukmu Lillah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'En üst satırda "Allah" lafz-ı celâli bulunacak şekilde alttan üste "Muhammed - Resûl - Allah" olarak istiflenmişti.',
      en: 'Arranged across three lines so "Allah" stood at the very top: bottom "Muhammad," middle "Rasul," top "Allah."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Buhârî\'de Enes b. Mâlik\'ten (r.a.) nakledildiği üzere mühürde edeben en üst satıra "Allah", ortasına "Resûl", en altına "Muhammed" yazılmış ve Bizans, İran, Mısır, Habeşistan hükümdarlarına gönderilen mektuplar bununla mühürlenmiştir.',
        en: 'Out of reverence, "Allah" was placed on the top line, "Rasul" in the middle, and "Muhammad" at the bottom, sealing the diplomatic epistles of 7 AH.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Libâs 55; Müslim, Libâs 56',
        en: 'Bukhari, Libas 55; Muslim, Libas 56',
      ),
    ),
  ),
];
