import '../domain/irfan_models.dart';

/// 33 Authentic Bilingual (TR/EN) Questions for Kur'ân & Sûreler (Surahs, Verses, Stories & Tajweed).
const List<IrfanQuestion> kIrfanQuestionsQuran = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'qur_b_01',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de toplam kaç sûre ve kaç cüz bulunmaktadır?',
      en: 'How many Surahs (chapters) and Juz\' (parts) does the Noble Qur\'an contain?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: '99 sûre — 20 cüz', en: '99 Surahs — 20 Juz\''),
        LocalizedText(tr: '114 sûre — 30 cüz', en: '114 Surahs — 30 Juz\''),
        LocalizedText(tr: '120 sûre — 30 cüz', en: '120 Surahs — 30 Juz\''),
        LocalizedText(tr: '114 sûre — 40 cüz', en: '114 Surahs — 40 Juz\''),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Fâtiha ile başlayıp Nâs ile biten 114 sûre, hatim kolaylığı için 20\'şer sayfalık 30 cüze ayrılmıştır.',
      en: 'From Al-Fatihah to An-Nas there are 114 Surahs divided into 30 Juz\' for monthly recitation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân-ı Kerîm 114 sûreden oluşur; 1. sûre Fâtiha, 114. sûre Nâs\'tır. Her biri yaklaşık 20 sayfadan oluşan 30 cüze (toplam ~604 sayfa) taksim edilmiştir.',
        en: 'The Qur\'an comprises 114 Surahs—opening with Al-Fatihah and closing with An-Nas—and is organized into 30 Juz\'.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İşleri Başkanlığı, Kur\'ân Yolu Tefsiri, Giriş',
        en: 'Presidency of Religious Affairs (Diyanet), Qur\'an Yolu Introduction',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_02',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: '"Ümmü\'l-Kitâb" (Kitabın Anası) ve "es-Seb\'u\'l-Mesânî" (Tekrarlanan Yedi Âyet) isimleriyle de anılan açılış sûresi hangisidir?',
      en: 'Which opening Surah is also called "Umm al-Kitab" (Mother of the Book) and "as-Sab\' al-Mathani" (the Seven Oft-Repeated Verses)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Fâtiha Sûresi', en: 'Surah Al-Fatihah'),
        LocalizedText(tr: 'Bakara Sûresi', en: 'Surah Al-Baqarah'),
        LocalizedText(tr: 'İhlâs Sûresi', en: 'Surah Al-Ikhlas'),
        LocalizedText(tr: 'Kevser Sûresi', en: 'Surah Al-Kawthar'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Her namaz rekâtında okunan 7 âyetlik ilk sûredir.',
      en: 'Recited in every rak\'ah of Salah, consisting of 7 verses.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hicr Sûresi 87. âyette ve sahih hadislerde Fâtiha Sûresi\'nin "es-Seb\'u\'l-Mesânî" ve "el-Kur\'ânü\'l-Azîm" olduğu; hamd, tevhid, kulluk ve hidayet duasını cem ettiği bildirilmiştir.',
        en: 'Mentioned in Surah Al-Hijr 15:87 and authentic hadiths, Surah Al-Fatihah gathers praise, Tawhid, worship, and the supplication for guidance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hicr Sûresi, 15/87; Buhârî, Tefsîr 1/1',
        en: 'Surah Al-Hijr, 15:87; Bukhari, Tafsir 1/1',
      ),
      linkedZikirKey: 'Elhamdülillah',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_03',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sahih hadislerde tevhid akidesini özlü biçimde anlattığı için "Kur\'ân\'ın üçte birine denk" olduğu müjdelenen sûre hangisidir?',
      en: 'Which Surah is praised in authentic Hadiths as equivalent to "one-third of the Qur\'an" because it purely encapsulates Tawhid?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Fil Sûresi', en: 'Surah Al-Fil'),
        LocalizedText(tr: 'Asr Sûresi', en: 'Surah Al-\'Asr'),
        LocalizedText(tr: 'İhlâs Sûresi', en: 'Surah Al-Ikhlas'),
        LocalizedText(tr: 'Kureyş Sûresi', en: 'Surah Quraysh'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Kul hüvallâhü ehad..." diye başlayan 112. sûredir.',
      en: 'Surah 112, beginning with "Qul Huwallahu Ahad...".',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân\'ın ana konuları tevhid, ahkâm ve kıssalar olarak üçe ayrıldığında İhlâs Sûresi halis tevhid ilmini eksiksiz özetlediği için Kur\'ân\'ın üçte birine denk sayılmıştır.',
        en: 'Because the Qur\'an\'s themes span Tawhid, rulings, and stories, Surah Al-Ikhlas purely summarizes divine Oneness and equals one-third of the Qur\'an in merit.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Fezâilü\'l-Kur\'ân 13; Müslim, Müsâfirîn 259',
        en: 'Bukhari, Fada\'il al-Qur\'an 13; Muslim, Musafirin 259',
      ),
      linkedZikirKey: 'İhlas-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_04',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'in en uzun sûresi Kevser Sûresi, en kısa sûresi ise Bakara Sûresi\'dir.',
      en: 'The longest Surah of the Qur\'an is Al-Kawthar, and the shortest Surah is Al-Baqarah.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Tam tersi! Bakara 286 âyetle en uzun, Kevser 3 âyetle en kısa sûredir.',
      en: 'Reversed! Al-Baqarah (286 verses) is the longest, while Al-Kawthar (3 verses) is the shortest.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân-ı Kerîm\'in en uzun sûresi 286 âyetlik Bakara Sûresi, en kısa sûresi ise 3 âyetlik Kevser Sûresi\'dir.',
        en: 'Surah Al-Baqarah (286 verses) is the longest chapter of the Qur\'an, whereas Surah Al-Kawthar (3 verses) is the shortest.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi (2); Kevser Sûresi (108)',
        en: 'Surah Al-Baqarah (2); Surah Al-Kawthar (108)',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_05',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'İçinde "El-Hayyü\'l-Kayyûm" ism-i âzamının geçtiği ve hadiste Kur\'ân\'ın en yüce âyeti olarak bildirilen "Âyetü\'l-Kürsî" hangi sûrenin kaçıncı âyetidir?',
      en: 'In which Surah and verse number is "Ayat al-Kursi"—the greatest verse of the Qur\'an containing "Al-Hayy al-Qayyum"—located?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Âl-i İmrân Sûresi, 18. âyet', en: 'Surah Ali \'Imran, verse 18'),
        LocalizedText(tr: 'Haşr Sûresi, 22. âyet', en: 'Surah Al-Hashr, verse 22'),
        LocalizedText(tr: 'Yâsîn Sûresi, 82. âyet', en: 'Surah Ya-Sin, verse 82'),
        LocalizedText(tr: 'Bakara Sûresi, 255. âyet', en: 'Surah Al-Baqarah, verse 255'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '2. sûrenin 255. âyetidir; her farz namazın ardından okunması sünnettir.',
      en: 'Verse 255 of the 2nd Surah, recommended after every obligatory prayer.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Übey b. Ka\'b hadisinde bildirildiği üzere Bakara 255 (Âyetü\'l-Kürsî) Allah\'ın mutlak hayat, kayyûmiyet, ilim ve hükümranlığını eşsiz bir belâgatle beyan eder.',
        en: 'As taught in the hadith of Ubayy ibn Ka\'b, Al-Baqarah 2:255 proclaims Allah\'s eternal Life, Self-Subsistence, all-encompassing Knowledge, and Sovereignty.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/255; Müslim, Müsâfirîn 258',
        en: 'Surah Al-Baqarah, 2:255; Muslim, Musafirin 258',
      ),
      linkedZikirKey: 'El-Hayy',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_06',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Cuma günleri okunması Peygamberimiz (s.a.v.) tarafından özellikle tavsiye edilen ve iki Cuma arasını nurla aydınlatacağı müjdelenen sûre hangisidir?',
      en: 'Which Surah was specially recommended by the Prophet (ﷺ) to be recited on Fridays, illuminating the believer between two Fridays?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kehf Sûresi', en: 'Surah Al-Kahf'),
        LocalizedText(tr: 'Duhâ Sûresi', en: 'Surah Ad-Duha'),
        LocalizedText(tr: 'Tîn Sûresi', en: 'Surah At-Tin'),
        LocalizedText(tr: 'Zilzâl Sûresi', en: 'Surah Az-Zalzalah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Ashâb-ı Kehf, Hz. Mûsâ-Hızır ve Zülkarneyn kıssalarını içeren 18. sûredir.',
      en: 'Surah 18, containing the stories of the Companions of the Cave, Musa & Khidr, and Dhul-Qarnayn.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahih rivayetlerde Cuma günü Kehf Sûresi\'ni okuyanın iki Cuma arasının nurla aydınlanacağı ve ilk on âyetini ezberleyenin ahir zaman fitnelerinden korunacağı bildirilmiştir.',
        en: 'Authentic narrations state that reciting Surah Al-Kahf on Friday illuminates the week with spiritual light, and memorizing its opening ten verses shields against trials.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Müsâfirîn 257; Hâkim, el-Müstedrek, II/399',
        en: 'Muslim, Musafirin 257; Al-Hakim, Al-Mustadrak, II/399',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_07',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    specialDayTags: ['kadir', 'ramazan', 'kandil'],
    stem: LocalizedText(
      tr: 'Kadir Sûresi\'nde Kur\'ân-ı Kerîm\'in indirildiği Kadir Gecesi\'nin kaç aydan daha hayırlı olduğu bildirilmektedir?',
      en: 'According to Surah Al-Qadr, Laylat al-Qadr (the Night of Power) is better than how many months?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Yüz aydan', en: 'A hundred months'),
        LocalizedText(tr: 'Üç yüz aydan', en: 'Three hundred months'),
        LocalizedText(tr: 'Bin aydan', en: 'A thousand months'),
        LocalizedText(tr: 'Kırk aydan', en: 'Forty months'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Leyletü\'l-Kadri hayrun min elfi şehr" (Kadir Gecesi bin aydan hayırlıdır).',
      en: '"Laylatul-Qadri khayrun min alfi shahr" (approximately 83 years).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Bin ay yaklaşık 83 yıllık bir ömre tekabül eder; Kur\'ân\'ın inmeye başladığı bu mübarek gece esenlik tan yeri ağarıncaya dek sürer.',
        en: 'One thousand months exceeds eighty-three years; on this blessed night of revelation, angels descend with peace until dawn.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kadir Sûresi, 97/1-5; Buhârî, Îmân 25',
        en: 'Surah Al-Qadr, 97:1-5; Bukhari, Iman 25',
      ),
      linkedZikirKey: 'El-Afuvv',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_08',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Meşhur sûreleri hadis ve tefsir kaynaklarındaki fazilet ve temalarıyla eşleştiriniz.',
      en: 'Match these beloved Surahs with their renowned themes and virtues.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Yâsîn Sûresi (36)', en: 'Surah Ya-Sin (36)'),
          right: LocalizedText(tr: 'Kur\'ân\'ın kalbi; tevhid ve haşir hakikati', en: 'Heart of the Qur\'an; Tawhid & Resurrection'),
        ),
        (
          left: LocalizedText(tr: 'Mülk / Tebâreke Sûresi (67)', en: 'Surah Al-Mulk (67)'),
          right: LocalizedText(tr: 'İlahî kudret tefekkürü ve kabir azabına karşı şefaatçi', en: 'Reflection on Divine Sovereignty & intercessor in the grave'),
        ),
        (
          left: LocalizedText(tr: 'Felak ve Nâs Sûreleri (113-114)', en: 'Surahs Al-Falaq & An-Nas (113-114)'),
          right: LocalizedText(tr: 'Muavvizeteyn; her türlü şerden Allah\'a sığınma', en: 'Al-Mu\'awwidhatayn; seeking refuge in Allah from all harm'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Felak ve Nâs sûrelerine "iki koruyucu/sığındırıcı" anlamında Muavvizeteyn denir.',
      en: 'Al-Falaq and An-Nas are called Al-Mu\'awwidhatayn ("the two Surahs of seeking refuge").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber (s.a.v.) her gece uyumadan önce İhlâs, Felak ve Nâs sûrelerini ayrıca 30 âyetlik Mülk Sûresi\'ni okumayı sünnet edinmiştir.',
        en: 'Every night before sleep, the Prophet (ﷺ) habitually recited Al-Ikhlas, Al-Falaq, An-Nas, and the 30 verses of Surah Al-Mulk.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Fezâilü\'l-Kur\'ân 14; Tirmizî, Fezâilü\'l-Kur\'ân 7, 9',
        en: 'Bukhari, Fada\'il al-Qur\'an 14; Tirmidhi, Fada\'il al-Qur\'an 7, 9',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_09',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'İnşirâh Sûresi\'nde (94/5-6) üst üste iki defa tekrar edilerek müminlere ümit aşılayan ilahî müjde hangisidir?',
      en: 'Which divine glad tiding is repeated twice consecutively in Surah Ash-Sharh (94:5-6) to instill hope in believers?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Elbette zorlukla beraber bir kolaylık vardır', en: 'Indeed, with hardship comes ease'),
        LocalizedText(tr: 'Her nefis ölümü tadacaktır', en: 'Every soul shall taste death'),
        LocalizedText(tr: 'Yeryüzünde bulunan her canlı fânidir', en: 'Everyone upon the earth will perish'),
        LocalizedText(tr: 'İnsan için ancak çalıştığının karşılığı vardır', en: 'Man shall have only what he strives for'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Fe inne mea\'l-usri yüsrâ. İnne mea\'l-usri yüsrâ."',
      en: '"Fa inna ma\'al-\'usri yusra. Inna ma\'al-\'usri yusra."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Arap dili belâgatine göre "el-usr" (zorluk) belirli, "yüsr" (kolaylık) belirsiz geldiği için Hz. Peygamber "Bir zorluk iki kolaylığa asla galip gelemez" buyurmuştur.',
        en: 'Because "the hardship" (al-\'usr) is definite while "an ease" (yusra) is repeated indefinitely, the Prophet (ﷺ) taught that one hardship can never overcome two eases.',
      ),
      sourceRef: LocalizedText(
        tr: 'İnşirâh Sûresi, 94/5-6; Muvatta\', Cihâd 6',
        en: 'Surah Ash-Sharh, 94:5-6; Muwatta\', Jihad 6',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_10',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Asr Sûresi\'ne göre insanın ziyandan (hüsrandan) kurtulması için iman ve sâlih amelin yanında birbirine tavsiye etmesi gereken iki temel fazilet "Hakkı tavsiye" ve "Sabrı tavsiye"dir.',
      en: 'According to Surah Al-\'Asr, alongside faith and righteous deeds, humans are saved from loss by mutually enjoining Truth (al-Haqq) and Patience (as-Sabr).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: '"...ve tevâsav bi\'l-hakkı ve tevâsav bi\'s-sabr" (Asr, 103/3).',
      en: '"...wa tawasaw bil-haqqi wa tawasaw bis-sabr" (Al-\'Asr, 103:3).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmam Şâfiî (rh.a.), "Şayet insanlar yalnız Asr Sûresi üzerinde hakkıyla düşünselerdi, onlara yeterdi" diyerek bu 3 âyetlik sûrenin kurtuluş reçetesini özetlemiştir.',
        en: 'Imam ash-Shafi\'i remarked, "Were people to ponder deeply upon this Surah alone, it would suffice them," highlighting its complete roadmap to salvation.',
      ),
      sourceRef: LocalizedText(
        tr: 'Asr Sûresi, 103/1-3; İbn Kesîr, Tefsîr, VIII/479',
        en: 'Surah Al-\'Asr, 103:1-3; Ibn Kathir, Tafsir, VIII/479',
      ),
      linkedZikirKey: 'Es-Sabûr',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_11',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: '"O hâlde Rabbinizin hangi nimetlerini yalanlayabilirsiniz?" (Fe-bi eyyi âlâi Rabbikümâ tükezzibân) âyetinin 31 defa tekrarlandığı ve "Kur\'ân\'ın gelini" diye nitelendirilen sûre hangisidir?',
      en: 'Which Surah—adorned with the refrain "So which of the favors of your Lord would you deny?" repeated 31 times—is called the Bride of the Qur\'an?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Vâkıa Sûresi', en: 'Surah Al-Waqi\'ah'),
        LocalizedText(tr: 'Rahmân Sûresi', en: 'Surah Ar-Rahman'),
        LocalizedText(tr: 'Nebe\' Sûresi', en: 'Surah An-Naba\''),
        LocalizedText(tr: 'Fecr Sûresi', en: 'Surah Al-Fajr'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Er-Rahmân. Alleme\'l-Kur\'ân..." âyetleriyle başlayan 55. sûredir.',
      en: 'Surah 55, opening directly with the Divine Name "Ar-Rahman."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Rahmân Sûresi, Kur\'ân\'ın öğretilmesini tüm maddî nimetlerin önüne koyarak başlar ve kâinattaki ilahî ölçü ile âhiret nimetlerini şükür bilinciyle hatırlatır.',
        en: 'Surah Ar-Rahman places the teaching of the Qur\'an first among all blessings, awakening gratitude through cosmic balance and eternal rewards.',
      ),
      sourceRef: LocalizedText(
        tr: 'Rahmân Sûresi, 55/1-78; Beyhakî, Şuabü\'l-Îmân, II/490',
        en: 'Surah Ar-Rahman, 55:1-78; Al-Bayhaqi, Shu\'ab al-Iman, II/490',
      ),
      linkedZikirKey: 'Er-Rahmân',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'qur_o_01',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de başında Besmele bulunmayan tek sûre ile içinde iki Besmele bulunan sûre hangi seçenekte doğru eşleştirilmiştir?',
      en: 'Which option correctly pairs the only Surah without a Basmalah at its start and the Surah containing two Basmalahs?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Enfâl Sûresi — Sebe\' Sûresi', en: 'Al-Anfal — Saba\''),
        LocalizedText(tr: 'Tevbe Sûresi — Neml Sûresi', en: 'At-Tawbah — An-Naml'),
        LocalizedText(tr: 'Hûd Sûresi — Kasas Sûresi', en: 'Hud — Al-Qasas'),
        LocalizedText(tr: 'Yûnus Sûresi — Şuarâ Sûresi', en: 'Yunus — Ash-Shu\'ara\''),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '9. sûre Besmelesiz başlar; 27. sûrede ise Hz. Süleyman\'ın Belkıs\'a gönderdiği mektupta (30. âyet) ikinci bir Besmele yer alır.',
      en: 'Surah 9 has no opening Basmalah; Surah 27 includes a second Basmalah in Prophet Sulayman\'s letter (27:30).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tevbe (Berâe) Sûresi başında Besmele bulunmaz; buna mukabil Neml Sûresi 30. âyette Hz. Süleyman\'ın mektubu "İnnehû min Süleymâne ve innehû Bismillâhirrahmânirrahîm" şeklinde Besmele\'yi ihtiva eder.',
        en: 'Surah At-Tawbah (9) opens without Basmalah, whereas Surah An-Naml (27:30) contains a Basmalah within Prophet Sulayman\'s letter, keeping total Basmalahs in the Mushaf at 114.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe, 9/1; Neml, 27/30; Tirmizî, Tefsîr 9/1',
        en: 'At-Tawbah 9:1; An-Naml 27:30; Tirmidhi, Tafsir 9/1',
      ),
      linkedZikirKey: 'Besmele',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_02',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'in tam bir sayfayı kaplayan en uzun âyeti "Müdâyene Âyeti" (Bakara 282) hangi konuyu düzenlemektedir?',
      en: 'What subject is regulated by the longest single verse in the Qur\'an, "Ayat al-Mudayanah" (Surah Al-Baqarah 2:282)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Vadeli borçların yazılması, şahitlik ve kul hakkı emniyeti', en: 'Recording fixed-term debts in writing with witnesses to safeguard rights'),
        LocalizedText(tr: 'Hac menâsiki ve ihram hükümleri', en: 'Rites of Hajj and rules of Ihram'),
        LocalizedText(tr: 'Miras paylaşım oranları', en: 'Shares of inheritance'),
        LocalizedText(tr: 'Ganimetlerin taksimi', en: 'Distribution of spoils'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Müdâyene", "deyn" (borç) kökünden gelir; alacak-verecek işlemlerinin kayıt altına alınmasını emreder.',
      en: '"Mudayanah" comes from "dayn" (debt), commanding written contracts for deferred financial obligations.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'En uzun âyetin ticari ve malî borçların adaletle yazılıp şahitlendirilmesine ayrılmış olması, İslâm\'ın hukuk güvenliğine ve kul hakkına verdiği önemin en açık delilidir.',
        en: 'That the longest verse of the Qur\'an is dedicated to documenting financial obligations with witnesses demonstrates Islam\'s rigor in legal transparency and protecting human rights.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/282; Diyanet Kur\'ân Yolu, I/441',
        en: 'Surah Al-Baqarah, 2:282; Diyanet Qur\'an Yolu, I/441',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_03',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Cum\'a Sûresi 9. âyette Cuma günü namaza çağrıldığında (ezan okunduğunda) müminlere hangi işlerini bırakıp Allah\'ın zikrine (namaza) koşmaları emredilir?',
      en: 'In Surah Al-Jumu\'ah 62:9, what worldly activity are believers specifically commanded to leave behind when called to Friday prayer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Yolculuğu', en: 'All travel'),
        LocalizedText(tr: 'Alışverişi (ticareti)', en: 'Buying and selling (trade)'),
        LocalizedText(tr: 'Ziraati', en: 'Planting crops'),
        LocalizedText(tr: 'İlim meclisini', en: 'Study circles'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Fes\'av ilâ zikrillâhi ve zeru\'l-bey\'" — buradaki "el-bey\'" alışveriş demektir.',
      en: '"Fas\'aw ila dhikrillahi wa dharul-bay\'" — "al-bay\'" means trade/commerce.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cum\'a Sûresi 9-10. âyetler İslâm\'ın dünya-âhiret dengesini kurar: Ezan okunduğunda alışveriş bırakılıp namaza koşulur; namaz kılınınca da yeryüzüne dağılıp Allah\'ın helâl lütfundan rızık aranır.',
        en: 'Surah Al-Jumu\'ah 62:9-10 models Islam\'s balance: suspend commerce when called to Friday prayer, then disperse afterward seeking Allah\'s lawful bounty while remembering Him much.',
      ),
      sourceRef: LocalizedText(
        tr: 'Cum\'a Sûresi, 62/9-10',
        en: 'Surah Al-Jumu\'ah, 62:9-10',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_04',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de okunduğunda veya dinlendiğinde "Tilâvet Secdesi" yapılmasını gerektiren 14 secde âyeti bulunmaktadır.',
      en: 'There are 14 prostration verses (Ayat as-Sajdah) in the Mushaf that call for Sujud at-Tilawah upon reciting or hearing them.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'İlki A\'râf 206, sonuncusu ise Alak 19. âyettir.',
      en: 'Beginning with Al-A\'raf 7:206 and concluding with Al-\'Alaq 96:19 in standard Mushafs.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tilâvet secdesi âyetleri kâinattaki varlıkların Allah\'a boyun eğişini hatırlatır. Hanefîlerde tilâvet secdesi vacip, Şâfiîlerde ise müekked sünnettir.',
        en: 'Verses of prostration invite the believer to mirror creation\'s submission to Allah; Sujud at-Tilawah is wajib in Hanafi fiqh and emphasized Sunnah in Shafi\'i fiqh.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Sücûdü\'l-Kur\'ân 1; Diyanet İlmihali Cilt 1, s. 290',
        en: 'Bukhari, Sujud al-Qur\'an 1; Diyanet Catechism Vol. 1, p. 290',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_05',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hicretten önce inen sûre ve âyetlere "Mekkî", hicretten sonra inenlere ise (Mekke\'nin fethinde inse dahi) "Medenî" denir.',
      en: 'In Qur\'anic sciences, revelations before the Hijrah are termed "Makki" and those after the Hijrah are termed "Madani," even if revealed while visiting Makkah.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Tefsir usulünde en yaygın ve yerleşik ölçü zaman (Hicret öncesi / sonrası) ölçüsüdür.',
      en: 'Classical \'Ulum al-Qur\'an defines Makki and Madani chronologically around the watershed of the Hijrah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mekkî sûreler ağırlıklı olarak tevhid, nübüvvet, haşir ve ahlâk esaslarını inşa ederken; Medenî sûreler ibadet, aile, toplum ve hukuk nizamını detaylandırır.',
        en: 'Makki Surahs primarily anchor Tawhid, prophethood, resurrection, and moral character, whereas Madani Surahs elaborate worship, family law, and social justice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Zerkeşî, el-Burhân, I/187; Süyûtî, el-İtkân, I/23',
        en: 'Az-Zarkashi, Al-Burhan, I/187; As-Suyuti, Al-Itqan, I/23',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_06',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de adlarını peygamber ve sâlih şahsiyetlerden alan sûreleri içerdikleri temel kıssalarla eşleştiriniz.',
      en: 'Match these Surahs with the central narratives they present.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Lokmân Sûresi (31)', en: 'Surah Luqman (31)'),
          right: LocalizedText(tr: 'Bir babanın oğluna şirkten sakınma, anne-babaya iyilik ve tevazu öğütleri', en: 'A wise father\'s counsel to his son against shirk, honoring parents, and humility'),
        ),
        (
          left: LocalizedText(tr: 'Meryem Sûresi (19)', en: 'Surah Maryam (19)'),
          right: LocalizedText(tr: 'Hz. Zekeriyyâ, Hz. Yahyâ ve Hz. Meryem ile Hz. Îsâ\'nın mucizevî doğumu', en: 'Zakariyya, Yahya, and Maryam with the miraculous birth of \'Isa'),
        ),
        (
          left: LocalizedText(tr: 'Kasas Sûresi (28)', en: 'Surah Al-Qasas (28)'),
          right: LocalizedText(tr: 'Hz. Mûsâ\'nın bebeklikten Medyen\'e uzanan hayatı ve Kârûn ibreti', en: 'Prophet Musa\'s early life through Madyan and the lesson of Qarun'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: '"Yâ büneyye lâ tüşrik billâh..." öğüdü Lokmân Sûresi 13. âyette yer alır.',
      en: '"O my son, do not associate anything with Allah..." appears in Surah Luqman 31:13.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Lokmân Sûresi aile içi terbiyeyi, Meryem Sûresi ilahî kudret ve iffeti, Kasas Sûresi ise mazlumlara yardım vaadini ve mal gururunun âkıbetini gözler önüne serer.',
        en: 'Surah Luqman illuminates moral parenting, Surah Maryam honors purity and divine power, and Surah Al-Qasas contrasts prophetic humility with Qarun\'s arrogance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Lokmân, 31/12-19; Meryem, 19/16-34; Kasas, 28/7-82',
        en: 'Luqman 31:12-19; Maryam 19:16-34; Al-Qasas 28:7-82',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_07',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm sayfalarının Hz. Ebû Bekir devrinde tek bir kitap hâlinde bir araya getirilmesine (Cem\') ve Hz. Osman devrinde çoğaltılıp merkezlere gönderilmesine (İstinsah) öncülük eden halifeler hangisinde doğru sıralanmıştır?',
      en: 'Under which two Caliphs was the Qur\'an first compiled into a single master volume (Jam\') and later copied into standard Mushafs for major cities (Istinsakh)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Cem\': Hz. Ömer — Çoğaltma: Hz. Ali', en: 'Compilation: \'Umar — Copying: \'Ali'),
        LocalizedText(tr: 'Cem\': Hz. Ebû Bekir — Çoğaltma: Hz. Osman', en: 'Compilation: Abu Bakr — Copying: \'Uthman'),
        LocalizedText(tr: 'Cem\': Hz. Osman — Çoğaltma: Hz. Ebû Bekir', en: 'Compilation: \'Uthman — Copying: Abu Bakr'),
        LocalizedText(tr: 'Cem\': Hz. Ali — Çoğaltma: Hz. Ömer', en: 'Compilation: \'Ali — Copying: \'Umar'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Yemâme\'de hâfızların şehid düşmesi üzerine Hz. Ömer\'in teklifiyle Hz. Ebû Bekir cem\' ettirmiş; Hz. Osman ise çoğaltmıştır.',
      en: 'Prompted by \'Umar after Yamamah, Abu Bakr commissioned the master Suhuf, and \'Uthman later commissioned standard copies.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân hem ezber (hıfz) hem yazılı belgelerle çifte şahit şartıyla Zeyd b. Sâbit başkanlığındaki heyetçe Hz. Ebû Bekir döneminde Mushaf hâline getirilmiş, Hz. Osman devrinde çoğaltılarak kıyamete dek muhafaza edilmiştir.',
        en: 'Verified through both oral memorization and two-witness written parchments under Zayd ibn Thabit, the Mushaf was compiled under Abu Bakr and standardized across provinces under \'Uthman.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Fedâilü\'l-Kur\'ân 3-4',
        en: 'Bukhari, Fada\'il al-Qur\'an 3-4',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_08',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    specialDayTags: ['mirac', 'kandil'],
    stem: LocalizedText(
      tr: '"Âmenerrasûlü" olarak bilinen ve yatsı namazlarından sonra okunması gelenekleşen iman ve dua âyetleri hangi sûrenin son iki âyetidir?',
      en: 'Known as "Amanar-Rasulu" and cherished in nightly recitation, these verses of faith and supplication form the final two verses of which Surah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Âl-i İmrân Sûresi (199-200)', en: 'Surah Ali \'Imran (199-200)'),
        LocalizedText(tr: 'Nisâ Sûresi (175-176)', en: 'Surah An-Nisa\' (175-176)'),
        LocalizedText(tr: 'Bakara Sûresi (285-286)', en: 'Surah Al-Baqarah (285-286)'),
        LocalizedText(tr: 'Mâide Sûresi (119-120)', en: 'Surah Al-Ma\'idah (119-120)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Mi\'râc gecesi vasıtasız hediye edilen ve "Lâ yükellifullâhü nefsen illâ vüs\'ahâ..." müjdesiyle biten 285-286. âyetlerdir.',
      en: 'Gifted on Mi\'raj Night, concluding with "Allah does not burden a soul beyond its capacity..." (2:285-286).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahih hadiste "Kim geceleyin Bakara Sûresi\'nin son iki âyetini okursa bu iki âyet ona yeter" buyrulmuş; Cenâb-ı Hak bu âyetlerdeki "Rabbenâ" dualarına "Kabul ettim!" buyurmuştur.',
        en: 'The Prophet (ﷺ) said, "Whoever recites the last two verses of Surah Al-Baqarah at night, they will suffice him," and Sahih Muslim records Allah answering each "Rabbana" plea with "I have granted it."',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/285-286; Buhârî, Fezâilü\'l-Kur\'ân 10; Müslim, Îmân 199',
        en: 'Al-Baqarah 2:285-286; Bukhari, Fada\'il al-Qur\'an 10; Muslim, Iman 199',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_09',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: '"Hüvallâhüllezî lâ ilâhe illâ hû..." diye başlayıp Esmaü\'l-Hüsna\'dan pek çok ilahî ismi peş peşe zikreden "Lev enzelnâ" âyetleri hangi sûrenin son üç âyetidir?',
      en: 'Beginning with "Law anzalna..." and "Huwallahulladhi la ilaha illa Huwa..." while reciting over a dozen Divine Names, these closing three verses belong to which Surah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Fetih Sûresi', en: 'Surah Al-Fath'),
        LocalizedText(tr: 'Hadîd Sûresi', en: 'Surah Al-Hadid'),
        LocalizedText(tr: 'Haşr Sûresi', en: 'Surah Al-Hashr'),
        LocalizedText(tr: 'Tahrîm Sûresi', en: 'Surah At-Tahrim'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '59. sûrenin 22-24. âyetleridir; sabah namazlarından sonra okunması âdet olmuştur.',
      en: 'Verses 22–24 of Surah 59, traditionally recited after Fajr prayer.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Haşr Sûresi 21-24. âyetler Kur\'ân\'ın bir dağa indirilse onu dahi haşyetten parçalayacak azametini anlatır ve Rahmân, Rahîm, Melik, Kuddûs, Selâm, Mü\'min, Müheymin, Azîz, Cebbâr, Mütekebbir, Hâlık, Bârî, Musavvir isimlerini cem eder.',
        en: 'Surah Al-Hashr 59:21-24 portrays the awe-inspiring majesty of the Qur\'an and gathers thirteen of Allah\'s Most Beautiful Names in sublime harmony.',
      ),
      sourceRef: LocalizedText(
        tr: 'Haşr Sûresi, 59/21-24; Tirmizî, Fezâilü\'l-Kur\'ân 22',
        en: 'Surah Al-Hashr, 59:21-24; Tirmidhi, Fada\'il al-Qur\'an 22',
      ),
      linkedZikirKey: 'Es-Selâm',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_10',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de bizzat kendi ismi "Ahsenü\'l-Kasas" (Kıssaların En Güzeli) olarak nitelendirilen ve baştan sona tek bir sûrede bütünüyle anlatılan peygamber kıssası hangisidir?',
      en: 'Which prophetic story is titled "Ahsan al-Qasas" (the Best of Stories) by the Qur\'an itself and narrated continuously within a single Surah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hz. Nûh Kıssası', en: 'Story of Prophet Nuh'),
        LocalizedText(tr: 'Hz. İbrâhim Kıssası', en: 'Story of Prophet Ibrahim'),
        LocalizedText(tr: 'Hz. Süleyman Kıssası', en: 'Story of Prophet Sulayman'),
        LocalizedText(tr: 'Hz. Yûsuf Kıssası', en: 'Story of Prophet Yusuf'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '12. sûrenin 3. âyetinde "Nahnu nakussu aleyke ahsene\'l-kasas..." buyrulur.',
      en: 'Surah 12:3 states: "We relate to you the best of stories..."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Yûsuf Sûresi, haset, ayrılık, iftira ve zindan imtihanlarının sabır, iffet ve tevekkülle nasıl izzet ve affa dönüştüğünü Hüzün Yılı\'nda Peygamberimiz\'e teselli olarak indirmiştir.',
        en: 'Revealed as solace during Makkan hardship, Surah Yusuf traces how envy, separation, and prison give way to honor and forgiveness through patience and chastity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Yûsuf Sûresi, 12/3, 90-92',
        en: 'Surah Yusuf, 12:3, 90-92',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_11',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Veda Haccı\'nda Arafat\'ta inen "Bugün sizin için dininizi kemâle erdirdim, üzerinizdeki nimetimi tamamladım ve sizin için din olarak İslâm\'a razı oldum" âyeti hangi sûrededir?',
      en: 'In which Surah appears the verse revealed at \'Arafat during the Farewell Pilgrimage: "This day I have perfected for you your religion and completed My favor upon you..."?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Mâide Sûresi, 3. âyet', en: 'Surah Al-Ma\'idah, verse 3'),
        LocalizedText(tr: 'Nasr Sûresi, 1. âyet', en: 'Surah An-Nasr, verse 1'),
        LocalizedText(tr: 'Hucurât Sûresi, 13. âyet', en: 'Surah Al-Hujurat, verse 13'),
        LocalizedText(tr: 'Nûr Sûresi, 35. âyet', en: 'Surah An-Nur, verse 35'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân\'ın 5. sûresinin 3. âyeti içinde yer alan "El-yevme ekmeltü leküm dîneküm..." beyanıdır.',
      en: '"Al-yawma akmaltu lakum dinakum..." within verse 3 of the 5th Surah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Ömer\'in (r.a.) bildirdiğine göre Mâide Sûresi 3. âyetin bu bölümü Cuma günü ve Arife günü birleştiğinde Arafat\'ta nazil olmuş ve teşrî\'in kemâlini ilan etmiştir.',
        en: 'As narrated by \'Umar (r.a.) in Bukhari and Muslim, this proclamation in Al-Ma\'idah 5:3 descended on Friday afternoon at \'Arafat, sealing the perfection of divine law.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/3; Buhârî, Îmân 33; Müslim, Tefsîr 3',
        en: 'Surah Al-Ma\'idah, 5:3; Bukhari, Iman 33; Muslim, Tafsir 3',
      ),
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'qur_i_01',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Tecvid ilminde Sâkin Nûn (نْ) veya Tenvîn\'den sonra gelen harflere göre uygulanan dört temel hükmü tanımlarıyla eşleştiriniz.',
      en: 'In the science of Tajweed, match the four rules of Noon Sakinah and Tanween with their definitions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'İzhâr', en: 'Izhar (Clear pronunciation)'),
          right: LocalizedText(tr: 'Boğaz harflerinden (ء ه ع ح غ خ) biri gelince nûn sesini açık okumak', en: 'Pronouncing Noon clearly without nasalization before the 6 throat letters'),
        ),
        (
          left: LocalizedText(tr: 'İklâb', en: 'Iqlab (Conversion)'),
          right: LocalizedText(tr: 'Bâ (ب) harfi gelince nûn sesini gunneli mîm\'e çevirmek', en: 'Converting Noon into a nasalized Meem sound before the letter Ba\' (ب)'),
        ),
        (
          left: LocalizedText(tr: 'İdğâm', en: 'Idgham (Merging)'),
          right: LocalizedText(tr: '"Yermelûn" (يرملون) harflerinden biri gelince katarak okumak', en: 'Merging Noon into a following letter from "Yarmaloon" (يرملون)'),
        ),
        (
          left: LocalizedText(tr: 'İhfâ', en: 'Ikhfa\' (Concealment)'),
          right: LocalizedText(tr: 'Kalan 15 harften biri gelince izhâr ile idğâm arası gunneli gizlemek', en: 'Concealing Noon with nasalization (ghunnah) before the remaining 15 letters'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İzhâr "açık etmek", İklâb "çevirmek" (tek harfi ب\'dir), İdğâm "katmak", İhfâ ise "gizlemek" demektir.',
      en: 'Izhar = clarify, Iqlab = convert (only before ب), Idgham = merge, Ikhfa\' = conceal.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Müzzemmil Sûresi 4. âyetteki "Kur\'ân\'ı tertîl ile (tane tane ve hakkını vererek) oku!" emri, tecvid ilminin temel dayanağıdır.',
        en: 'Surah Al-Muzzammil 73:4 ("And recite the Qur\'an with measured, distinct recitation [tartil]") forms the foundation of Tajweed.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müzzemmil, 73/4; İbnü\'l-Cezerî, el-Mukaddime; Karabaş Tecvidi',
        en: 'Al-Muzzammil 73:4; Ibn al-Jazari, Al-Muqaddimah',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_02',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Tecvidde "Kutbü Ceddin" (قطب جد) kelimelerinde toplanan beş harf cezimli (sükûnlu) geldiğinde mahrecin kuvvetle sarsılarak okunmasına ne ad verilir?',
      en: 'In Tajweed, what is the rule of echoing/bouncing articulation when one of the five letters of "Qutbu Jaddin" (ق ط ب ج د) carries sukoon?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kalkale', en: 'Qalqalah'),
        LocalizedText(tr: 'Medd-i Lâzım', en: 'Madd Lazim'),
        LocalizedText(tr: 'Sekte', en: 'Saktah'),
        LocalizedText(tr: 'İmâle', en: 'Imalah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'İhlâs Sûresi sonlarındaki "ehad, samed, yelid, yûled" kelimelerinin son harfinde duyulan sarsıntılı sestir.',
      en: 'Heard vividly on the final Dal of "Ahad, Samad, yalid, yulad" in Surah Al-Ikhlas.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kâf, Tâ, Bâ, Cîm ve Dâl harfleri sâkin olduklarında sesin hapsolmaması için mahreçte hafifçe yankılanır; buna "Kalkale" denir.',
        en: 'When Qaf, Ta\', Ba\', Jeem, or Dal are vowelless, their point of articulation releases with a crisp echo called Qalqalah.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbnü\'l-Cezerî, el-Mukaddimetü\'l-Cezeriyye, Beyit 20',
        en: 'Ibn al-Jazari, Al-Muqaddimah al-Jazariyyah, v. 20',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_03',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Tecvidde harf-i medden (ا و ي) sonra sebebi med olan hemze (ء) aynı kelimede bulunursa (örneğin جَٓاءَ / السَّمَٓاءِ) hangi med oluşur ve hükmü nedir?',
      en: 'When a Madd letter is followed by a Hamzah within the very same word (such as جَٓاءَ or السَّمَٓاءِ), which Madd occurs and what is its ruling?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Medd-i Munfasıl — Câizdir', en: 'Madd Munfasil — Permissible'),
        LocalizedText(tr: 'Medd-i Muttasıl — Vaciptir', en: 'Madd Muttasil — Obligatory (Wajib)'),
        LocalizedText(tr: 'Medd-i Ârız — Câizdir', en: 'Madd \'Arid — Permissible'),
        LocalizedText(tr: 'Medd-i Tabiî — Bir elif uzatılır', en: 'Madd Tabi\'i — Two counts'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Muttasıl" bitişik (aynı kelimede), "Munfasıl" ise ayrı (iki ayrı kelimede) demektir.',
      en: '"Muttasil" means connected (within one word), whereas "Munfasil" means separated across two words.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Medd-i Muttasıl\'da harf-i med ile hemze tek kelimede bitişiktir; bütün kıraat imamlarının ittifakıyla aslî medden fazla uzatılması vaciptir (Hafs rivayetinde 4-5 hareke).',
        en: 'In Madd Muttasil, the Madd letter and Hamzah share a single word; all canonical reciters agree on prolonging it beyond natural Madd (4–5 counts in Hafs \'an \'Asim).',
      ),
      sourceRef: LocalizedText(
        tr: 'İbnü\'l-Cezerî, en-Neşr fi\'l-Kırââti\'l-Aşr, I/315',
        en: 'Ibn al-Jazari, An-Nashr fi\'l-Qira\'at al-\'Ashr, I/315',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_04',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Âl-i İmrân Sûresi 7. âyete göre Kur\'ân\'ın anası/temeli olan, manası apaçık âyetlere "Muhkem"; birden fazla manaya ihtimali olup muhkem âyetler ışığında anlaşılan âyetlere ise "Müteşâbih" denir.',
      en: 'According to Surah Ali \'Imran 3:7, clear foundational verses are called "Muhkam," while multi-layered allegorical verses understood in light of the Muhkam are called "Mutashabih."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'İlimde derinleşenler (râsihûn) her ikisi için de "Âmennâ bihî, küllün min indi Rabbinâ" (İnandık, hepsi Rabbimiz katındandır) derler.',
      en: 'Those firmly grounded in knowledge say of both: "We believe in it; all of it is from our Lord" (3:7).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Âl-i İmrân 7. âyet tefsir usulünün temel taşıdır: Muhkem âyetler dinin değişmez ana direkleridir; müteşâbih âyetler ise tefekkür ufkunu açar ve muhkem esaslara irca edilerek anlaşılır.',
        en: 'Surah Ali \'Imran 3:7 anchors Qur\'anic hermeneutics: Muhkam verses form the unambiguous core of faith and law, guiding proper understanding of Mutashabih expressions.',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân Sûresi, 3/7',
        en: 'Surah Ali \'Imran, 3:7',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_05',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Nûr Sûresi 35. âyette geçen ve Allah\'ın gökleri ve yeri aydınlatan hidayet nurunu "içinde kandil bulunan bir hücre, inci gibi parlayan bir yıldız ve doğuya-batıya nispet edilmeyen mübarek zeytin ağacı" temsiliyle anlatan meşhur âyet hangisidir?',
      en: 'What is the classical name of Surah An-Nur 24:35, which illustrates Divine Light through the parable of a niche, a lamp in crystal, and a blessed olive tree?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Âyetü\'l-Birr', en: 'Ayat al-Birr'),
        LocalizedText(tr: 'Âyetü\'s-Seyf', en: 'Ayat as-Sayf'),
        LocalizedText(tr: 'Nûr Âyeti (Âyetü\'n-Nûr)', en: 'Ayat an-Nur (The Verse of Light)'),
        LocalizedText(tr: 'İfk Âyeti', en: 'Verses of Al-Ifk'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Allâhü nûru\'s-semâvâti ve\'l-ard..." lafzıyla başlayan ve "Nûrun alâ nûr" ifadesini içeren âyettir.',
      en: 'Opens with "Allahu nurus-samawati wal-ard..." and contains the phrase "Light upon Light" (Nurun \'ala Nur).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Nûr Âyeti (24/35), müminin kalbindeki fıtrî iman istidadının vahiy nuruyla birleştiğinde "nur üstüne nur" (nûrun alâ nûr) olarak parladığını eşsiz bir temsille anlatır.',
        en: 'Ayat an-Nur (24:35) portrays how pure innate disposition (fitrah) illuminated by revelation shines forth as "Light upon Light."',
      ),
      sourceRef: LocalizedText(
        tr: 'Nûr Sûresi, 24/35; Gazzâlî, Mişkâtü\'l-Envâr',
        en: 'Surah An-Nur, 24:35; Al-Ghazali, Mishkat al-Anwar',
      ),
      linkedZikirKey: 'En-Nûr',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_06',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: '29 sûrenin başında yer alan "Elif-Lâm-Mîm, Yâ-Sîn, Hâ-Mîm, Kâf, Nûn" gibi kesik harflere tefsir ilminde ne ad verilir?',
      en: 'What is the technical term in Qur\'anic sciences for the disjointed opening letters (such as Alif-Lam-Mim, Ya-Sin, Ha-Mim) at the start of 29 Surahs?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hurûf-ı Mukattaa', en: 'Al-Huruf al-Muqatta\'ah'),
        LocalizedText(tr: 'Esbâb-ı Nüzûl', en: 'Asbab an-Nuzul'),
        LocalizedText(tr: 'Nâsih ve Mensûh', en: 'An-Nasikh wal-Mansukh'),
        LocalizedText(tr: 'Garîbü\'l-Kur\'ân', en: 'Gharib al-Qur\'an'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Harflerin isimleriyle tek tek (kesik kesik) okunduğu için "Mukattaa" (ayrılmış/kesik harfler) denilmiştir.',
      en: 'Read letter-by-letter by their names rather than as a joined word.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hurûf-ı Mukattaa, Kur\'ân\'ın muhatapların bildiği aynı harflerden oluşmasına rağmen bir benzerinin getirilemeyeceğini (i\'câz) gösterir; hakiki muradını en iyi Allah bilir.',
        en: 'Al-Huruf al-Muqatta\'ah highlight the miraculous inimitability (i\'jaz) of the Qur\'an—composed of the very letters humans know yet beyond human replication.',
      ),
      sourceRef: LocalizedText(
        tr: 'Süyûtî, el-İtkân, II/16; TDV İslâm Ansiklopedisi, "Hurûf-ı Mukattaa"',
        en: 'As-Suyuti, Al-Itqan, II/16; TDV Encyclopedia of Islam',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_07',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hucurât Sûresi\'nde (49. sûre) toplumsal ahlâk ve kardeşliği korumak için vazedilen ilahî ilkeleri ilgili âyet mesajlarıyla eşleştiriniz.',
      en: 'Match the social-ethical principles revealed in Surah Al-Hujurat (Surah 49) with their Qur\'anic injunctions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hucurât, 49/6 (Tebeyyün)', en: 'Al-Hujurat 49:6 (Verification)'),
          right: LocalizedText(tr: 'Şüpheli bir haber geldiğinde doğruluğunu iyice araştırmak', en: 'Carefully verifying news before acting lest you harm people in ignorance'),
        ),
        (
          left: LocalizedText(tr: 'Hucurât, 49/12 (Tecessüs ve Gıybet)', en: 'Al-Hujurat 49:12 (Suspicion & Backbiting)'),
          right: LocalizedText(tr: 'Kötü zandan, gizli kusur aramaktan ve arkadan çekiştirmekten sakınmak', en: 'Avoiding ill suspicion, spying on faults, and backbiting'),
        ),
        (
          left: LocalizedText(tr: 'Hucurât, 49/13 (Takvâ Ölçüsü)', en: 'Al-Hujurat 49:13 (Measure of Honor)'),
          right: LocalizedText(tr: 'Kavim ve kabilelerin tanışma hikmeti; üstünlüğün yalnız takvâda oluşu', en: 'Nations created to know one another; the noblest with Allah is the most pious'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Tebeyyün haberi tahkik etmek, tecessüs gizli kusur araştırmak, takvâ ise Allah katındaki yegâne üstünlük ölçüsüdür.',
      en: 'Tabayyun = verifying reports; Tajassus = prying; Taqwa = sole criterion of nobility.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hucurât Sûresi "Ahlâk ve Edep Sûresi" olarak anılır; bilgi kirliliğine karşı tahkiki (tebeyyün), mümin kardeşliğini (49/10) ve gıybetten sakınmayı emreder.',
        en: 'Known as the Surah of Manners and Ethics, Al-Hujurat establishes information verification, brotherhood (49:10), dignity, and racial equality under Allah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hucurât Sûresi, 49/6-13',
        en: 'Surah Al-Hujurat, 49:6-13',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_08',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Türkiye\'de ve İslâm dünyasının büyük çoğunluğunda yaygın olarak okunan Mushaf kıraati "Âsım Kıraati\'nin Hafs Rivâyeti"dir.',
      en: 'The canonical Qur\'anic recitation overwhelmingly practiced in Türkiye and across most of the Muslim world today is the narration of Hafs from Imam \'Asim.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Kûfeli kıraat imamı Âsım b. Behdele\'nin talebesi Hafs b. Süleyman\'ın naklettiği mütevâtir rivayettir.',
      en: 'Transmitted by Hafs ibn Sulayman from the Kufan master reciter \'Asim ibn Abi an-Najud.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mütevâtir yedi/on kıraat imamından İmam Âsım\'ın senedi Hz. Ali ve Abdullah b. Mes\'ûd üzerinden bizzat Hz. Peygamber\'e (s.a.v.) ulaşır; Kuzey ve Batı Afrika\'da ise Nâfi\' kıraatinin Verş ve Kâlûn rivayetleri de yaygındır.',
        en: 'Hafs \'an \'Asim traces an unbroken mutawatir chain through \'Ali and Ibn Mas\'ud to the Prophet (ﷺ), while Warsh and Qalun \'an Nafi\' flourish in North and West Africa.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbnü\'l-Cezerî, en-Neşr, I/155; TDV İslâm Ansiklopedisi, "Hafs b. Süleyman"',
        en: 'Ibn al-Jazari, An-Nashr, I/155; TDV Encyclopedia of Islam',
      ),
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_09',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'İsrâ Sûresi 23-24. âyetlerde Allah\'tan başkasına kulluk etmemekle (tevhid) hemen yan yana zikredilen ve "Öf bile demeyin!" emriyle korunan temel vazife hangisidir?',
      en: 'In Surah Al-Isra\' 17:23-24, which moral duty is paired immediately after worshipping Allah alone and guarded by the command "Say not even \'uff\' to them"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Vasiyet yazmak', en: 'Writing a bequest'),
        LocalizedText(tr: 'Ganimetleri bölüştürmek', en: 'Dividing spoils'),
        LocalizedText(tr: 'Anne ve babaya ihsan (iyilik ve hürmet)', en: 'Dutifulness and kindness to parents (Birr al-Walidayn)'),
        LocalizedText(tr: 'Kefâret orucu tutmak', en: 'Fasting in expiation'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Ve kadâ Rabbüke ellâ ta\'büdû illâ iyyâhü ve bi\'l-vâlideyni ihsânâ..."',
      en: '"And your Lord has decreed that you worship none but Him, and to parents, good treatment..." (17:23).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İsrâ 23-24. âyetler anne-babaya güzel söz söylemeyi, merhamet kanatlarını indirmeyi ve "Rabbim! Küçüklüğümde beni yetiştirdikleri gibi Sen de onlara merhamet et" diye dua etmeyi emreder.',
        en: 'Surah Al-Isra\' 17:23-24 commands gentle speech, lowering the wing of humility out of mercy to parents, and praying: "My Lord, have mercy upon them as they brought me up when I was small."',
      ),
      sourceRef: LocalizedText(
        tr: 'İsrâ Sûresi, 17/23-24',
        en: 'Surah Al-Isra\', 17:23-24',
      ),
      linkedZikirKey: 'Er-Rahîm',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_10',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    specialDayTags: ['berat', 'regaip', 'ramazan', 'kandil'],
    stem: LocalizedText(
      tr: 'Tefsir âlimlerinin "Kur\'ân\'daki en ümit verici âyet" (ercâ âyet) olarak nitelendirdiği, "Ey kendi nefisleri aleyhine haddi aşan kullarım! Allah\'ın rahmetinden ümidinizi kesmeyin. Şüphesiz Allah bütün günahları bağışlar" ilahî çağrısı hangi sûrededir?',
      en: 'Celebrated by scholars as the most hope-inspiring verse in the Qur\'an—"O My servants who have transgressed against themselves, do not despair of the mercy of Allah"—in which Surah does it appear?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kehf Sûresi, 110. âyet', en: 'Surah Al-Kahf, verse 110'),
        LocalizedText(tr: 'Fâtır Sûresi, 32. âyet', en: 'Surah Fatir, verse 32'),
        LocalizedText(tr: ' Ankebût Sûresi, 69. âyet', en: 'Surah Al-\'Ankabut, verse 69'),
        LocalizedText(tr: 'Zümer Sûresi, 53. âyet', en: 'Surah Az-Zumar, verse 53'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '39. sûrenin 53. âyetidir: "Kul yâ ıbâdiyellezîne esrafû alâ enfüsihim lâ taknetû min rahmetillâh..."',
      en: 'Verse 53 of Surah 39: "Qul ya \'ibadiyalladhina asrafu \'ala anfusihim la taqnatu min rahmatillah..."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Zümer 53. âyet, samimi tevbe ve istiğfarla Allah\'a yönelen hiçbir kul için ümitsizlik (ye\'s) kapısı olmadığını "Ey kullarım!" şefkat hitabıyla müjdeler.',
        en: 'Addressing erring humans tenderly as "O My servants," Az-Zumar 39:53 closes the door to despair for everyone who turns back to Allah in sincere repentance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Zümer Sûresi, 39/53; Buhârî, Tefsîr 39/1',
        en: 'Surah Az-Zumar, 39:53; Bukhari, Tafsir 39/1',
      ),
      linkedZikirKey: 'İstiğfar',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_11',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Bakara Sûresi 177. âyette gerçek iyilik ve takvânın (el-Birr) yalnız şeklî yönelişten ibaret olmadığını; iman, infak, namaz, zekât, ahde vefa ve zorlukta sabır bütünlüğü olduğunu bildiren âyete ne ad verilir?',
      en: 'What is the name of Surah Al-Baqarah 2:177, which defines true righteousness (al-Birr) as uniting faith, charity to kin and the needy, prayer, Zakat, keeping covenants, and patience?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Birr Âyeti (Âyetü\'l-Birr)', en: 'Ayat al-Birr (The Verse of Righteousness)'),
        LocalizedText(tr: 'Kürsî Âyeti', en: 'Ayat al-Kursi'),
        LocalizedText(tr: 'Tathîr Âyeti', en: 'Ayat at-Tathir'),
        LocalizedText(tr: ' Kalâle Âyeti', en: 'Ayat al-Kalalah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Leyse\'l-birra en tüvellû vücûheküm..." diye başladığı için bu isimle meşhurdur.',
      en: 'Famous by its opening word: "Laysal-birra an tuwallu wujuhakum..."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Birr Âyeti (Bakara 177), İslâm\'ın inanç (akaid), ibadet (namaz-zekât), sosyal dayanışma (infak) ve ahlâk (sözünde durma ve sabır) boyutlarını tek âyette mezceden şaheser bir özettir.',
        en: 'Ayat al-Birr (Al-Baqarah 2:177) masterfully integrates creed, worship, generous care for the vulnerable, faithfulness to promises, and steadfast patience into a single holistic definition of piety.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/177; Taberî, Câmiu\'l-Beyân, III/335',
        en: 'Surah Al-Baqarah, 2:177; At-Tabari, Jami\' al-Bayan, III/335',
      ),
    ),
  ),
];
