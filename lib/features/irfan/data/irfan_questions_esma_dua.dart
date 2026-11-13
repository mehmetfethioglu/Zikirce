import '../domain/irfan_models.dart';

/// 33 Authentic Bilingual (TR/EN) Questions for Esmaü'l-Hüsna, Prophetic Duas & Daily Adhkar.
const List<IrfanQuestion> kIrfanQuestionsEsmaDua = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'esm_b_01',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Besmele\'de peş peşe zikredilen "Er-Rahmân" ve "Er-Rahîm" isimlerinin ince anlam farkı hangi seçenekte doğru açıklanmıştır?',
      en: 'Which option accurately explains the classical distinction between the Divine Names "Ar-Rahman" and "Ar-Rahim" in the Basmalah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Er-Rahmân rızkı daraltan, Er-Rahîm ise hesaba çekendir',
          en: 'Ar-Rahman restricts provision, while Ar-Rahim calls to account',
        ),
        LocalizedText(
          tr: 'Er-Rahmân dünyada inanan-inanmayan herkese merhamet eden; Er-Rahîm âhirette müminlere hususî rahmet ihsan edendir',
          en: 'Ar-Rahman encompasses all creation in this world; Ar-Rahim bestows special eternal mercy upon believers in the Hereafter',
        ),
        LocalizedText(
          tr: 'Her ikisi de yalnızca meleklerin zikridir',
          en: 'Both refer exclusively to angels',
        ),
        LocalizedText(
          tr: 'Er-Rahmân geçmişi, Er-Rahîm ise yalnız rüyaları ifade eder',
          en: 'Ar-Rahman refers only to the past and Ar-Rahim to dreams',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Rahmân ismi dünyada bütün mahlûkatı kuşatır; Rahîm ismi ise âhirette müminlere mahsus şefkati tecelli ettirir.',
      en: 'Ar-Rahman embraces all beings in this life; Ar-Rahim manifests special mercy to believers in the Hereafter.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Besmele ile hayırlı bir işe başlayan mümin, Allah\'ın hem bütün varlığı kuşatan engin Rahmân tecellisine hem de müminleri ebedî saadete ulaştıran Rahîm şefkatine sığınır.',
        en: 'Beginning every good deed with Bismillah connects the heart to Allah\'s universal mercy (Ar-Rahman) and His special saving grace (Ar-Rahim).',
      ),
      sourceRef: LocalizedText(
        tr: 'Fâtiha, 1/1-3; Ahzâb, 33/43; Gazzâlî, el-Maksadü\'l-Esnâ, s. 62',
        en: 'Al-Fatihah 1:1-3; Al-Ahzab 33:43; Al-Ghazali, Al-Maqsad al-Asna, p. 62',
      ),
      linkedZikirKey: 'Er-Rahmân',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_02',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Bütün mahlûkatın maddî ve mânevî rızkını kefil olup kesintisiz ihsan eden Allah\'ın güzel ismi hangisidir?',
      en: 'Which Beautiful Name of Allah signifies the All-Provider who sustains every living creature physically and spiritually?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Kâbıd', en: 'Al-Qabid'),
        LocalizedText(tr: 'El-Mâni\'', en: 'Al-Mani\''),
        LocalizedText(tr: 'Er-Rezzâk', en: 'Ar-Razzaq'),
        LocalizedText(tr: 'El-Müntekım', en: 'Al-Muntaqim'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Zâriyât Sûresi 58. âyette "Şüphesiz Allah Rezzâk\'tır..." şeklinde geçer.',
      en: 'Revealed in Surah Adh-Dhariyat 51:58 ("Indeed, it is Allah who is Ar-Razzaq...").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Er-Rezzâk, rızkı ve rızık sebeplerini yaratan, bedenleri helâl nimetlerle, kalpleri ise ilim ve imanla besleyendir.',
        en: 'Ar-Razzaq creates both sustenance and its means, nourishing bodies with lawful provision and hearts with faith and wisdom.',
      ),
      sourceRef: LocalizedText(
        tr: 'Zâriyât Sûresi, 51/58; Hûd Sûresi, 11/6',
        en: 'Surah Adh-Dhariyat, 51:58; Surah Hud, 11:6',
      ),
      linkedZikirKey: 'Er-Rezzâk',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_03',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Her farz namazın ardından okunan "Namaz Tesbihatı"nda 33\'er defa söylenen üç mübarek zikir "Sübhânallâh, Elhamdülillâh ve Allâhüekber"dir.',
      en: 'In the Sunnah post-prayer Tasbihat, the three phrases recited 33 times each are "Subhanallah, Alhamdulillah, and Allahu Akbar."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Doksan dokuz tesbihin ardından yüzüncüsü "Lâ ilâhe illallâhü vahdehû lâ şerîke leh..." ile tamamlanır.',
      en: 'Completed to 100 with "La ilaha illallahu wahdahu la sharika lah...", as taught in Sahih Muslim.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahih-i Müslim\'de bildirildiği üzere her farz namazın ardından 33 Sübhânallâh, 33 Elhamdülillâh, 33 Allâhüekber deyip yüzüncüyü tevhidle tamamlayanın küçük günahları deniz köpüğü kadar dahi olsa bağışlanır.',
        en: 'Sahih Muslim narrates that whoever glorifies Allah 33 times, praises Him 33 times, magnifies Him 33 times after each prayer, and completes 100 with Tawhid will have sins forgiven even if like sea foam.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Mesâcid 146; Buhârî, Ezân 155',
        en: 'Muslim, Masajid 146; Bukhari, Adhan 155',
      ),
      linkedZikirKey: 'Subhanallah',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_04',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Allah\'ın güzel isimlerini (Esmaü\'l-Hüsna) sahih anlamlarıyla eşleştiriniz.',
      en: 'Match these Beautiful Names of Allah with their authentic meanings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Es-Selâm', en: 'As-Salam'),
          right: LocalizedText(tr: 'Her türlü eksiklikten uzak, kullarına esenlik ve güven veren', en: 'The Flawless Source of Peace and Safety'),
        ),
        (
          left: LocalizedText(tr: 'El-Alîm', en: 'Al-\'Alim'),
          right: LocalizedText(tr: 'Gizli ve açık, geçmiş ve gelecek her şeyi hakkıyla bilen', en: 'The All-Knowing of the unseen and the manifest'),
        ),
        (
          left: LocalizedText(tr: 'El-Hâfız', en: 'Al-Hafiz'),
          right: LocalizedText(tr: 'Kâinatı ve kullarını koruyup gözeten, amelleri eksiksiz muhafaza eden', en: 'The All-Preserving Guardian and Protector'),
        ),
        (
          left: LocalizedText(tr: 'Eş-Şekûr', en: 'Ash-Shakur'),
          right: LocalizedText(tr: 'Az amele kat kat mükâfat ihsan eden', en: 'The Most Appreciative who multiplies rewards for small deeds'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Selâm esenlik, Alîm ilim, Hâfız muhafaza, Şekûr ise az şükre bol karşılık verendir.',
      en: 'Salam = peace, \'Alim = knowledge, Hafiz = preservation, Shakur = abundant reward.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'A\'râf Sûresi 180. âyette "En güzel isimler (el-Esmâü\'l-Hüsnâ) Allah\'ındır; O\'na o güzel isimlerle dua edin" buyrulmaktadır.',
        en: 'Surah Al-A\'raf 7:180 commands: "To Allah belong the Most Beautiful Names, so invoke Him by them."',
      ),
      sourceRef: LocalizedText(
        tr: 'A\'râf, 7/180; Buhârî, Daavât 68; Müslim, Zikir 5',
        en: 'Al-A\'raf 7:180; Bukhari, Da\'awat 68; Muslim, Dhikr 5',
      ),
      linkedZikirKey: 'Es-Selâm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_05',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Hadis-i şerifte "Zikrin en faziletlisi" ve "Duanın en faziletlisi" olarak bildirilen iki mübarek söz hangi seçenekte doğru verilmiştir?',
      en: 'In Prophetic Hadith, which two blessed expressions are named "the best of remembrance (dhikr)" and "the best of supplication (du\'a)"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Zikir: Lâ ilâhe illallâh — Dua: Elhamdülillâh',
          en: 'Best Dhikr: La ilaha illallah — Best Du\'a: Alhamdulillah',
        ),
        LocalizedText(
          tr: 'Zikir: Bismillâh — Dua: İnşâallâh',
          en: 'Best Dhikr: Bismillah — Best Du\'a: Insha\'Allah',
        ),
        LocalizedText(
          tr: 'Zikir: Bârekallâh — Dua: Mâşâallâh',
          en: 'Best Dhikr: Barakallah — Best Du\'a: Masha\'Allah',
        ),
        LocalizedText(
          tr: 'Zikir: Sadakallâh — Dua: Âmîn',
          en: 'Best Dhikr: Sadaqallah — Best Du\'a: Amin',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Câbir b. Abdullah\'tan (r.a.) rivayet edilen Tirmizî hadisinde Kelime-i Tevhid ve Hamd yan yana zikredilir.',
      en: 'Narrated by Jabir ibn \'Abdullah (r.a.) in Jami\' at-Tirmidhi, pairing Tawhid with Hamd.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tevhid kalbi Allah\'tan gayrısından arındırdığı için en üstün zikir; Elhamdülillâh ise nimetin sahibini tanıyıp ziyade lütuf celbettiği için en lâtif duadır.',
        en: 'Tawhid purifies the heart as the supreme remembrance, while praising Allah (Alhamdulillah) acknowledges the Giver of every blessing and invites increase.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Daavât 9; İbn Mâce, Edeb 55',
        en: 'Tirmidhi, Da\'awat 9; Ibn Majah, Adab 55',
      ),
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_06',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    specialDayTags: ['cuma', 'mevlid', 'kandil'],
    stem: LocalizedText(
      tr: '"Kim bana bir defa salât ü selâm getirirse, Allah Teâlâ ona on rahmet ihsan eder" hadisi hangi zikrin faziletini bildirmektedir?',
      en: 'To which devotion does the hadith "Whoever sends blessings upon me once, Allah sends blessings upon him tenfold" refer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Tekbir getirmek', en: 'Saying Takbir'),
        LocalizedText(tr: 'Telbiye getirmek', en: 'Reciting Talbiyah'),
        LocalizedText(tr: 'Hamd etmek', en: 'Saying Tahmid'),
        LocalizedText(tr: 'Salavât-ı Şerîfe getirmek', en: 'Sending Salawat upon the Prophet (ﷺ)'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Ahzâb Sûresi 56. âyette bizzat Allah ve meleklerin yaptığı bildirilerek müminlere emredilen nebevî selâmdır.',
      en: 'Commanded in Surah Al-Ahzab 33:56 ("Allâhumma salli \'alâ Muhammad...").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Salavât-ı Şerîfe, özellikle Cuma gecesi ve gününde çoğaltılması sünnet olan, duaların kabulüne vesile ve Peygamberimiz\'e (s.a.v.) vefa nişanesidir.',
        en: 'Sending Salawat—especially abundant on Fridays—is a bridge for accepted supplication and a token of love and loyalty to the Messenger of Allah (ﷺ).',
      ),
      sourceRef: LocalizedText(
        tr: 'Ahzâb, 33/56; Müslim, Salât 70; Ebû Dâvûd, Salât 201',
        en: 'Al-Ahzab 33:56; Muslim, Salah 70; Abu Dawud, Salah 201',
      ),
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_07',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) Ebû Mûsâ el-Eş\'arî\'ye (r.a.) "Cennet hazinelerinden bir hazine" diye öğrettiği teslimiyet zikri hangisidir?',
      en: 'Which phrase of reliance did the Prophet (ﷺ) teach Abu Musa al-Ash\'ari (r.a.) as "a treasure from the treasures of Paradise"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Sübhâneke Allâhümme', en: 'Subhanaka Allahumma'),
        LocalizedText(tr: 'Lâ havle ve lâ kuvvete illâ billâh', en: 'La hawla wa la quwwata illa billah'),
        LocalizedText(tr: 'Semiallâhü limen hamideh', en: 'Sami\'allahu liman hamidah'),
        LocalizedText(tr: 'Lebbeyk Allâhümme lebbeyk', en: 'Labbayk Allahumma labbayk'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Güç ve kuvvet ancak Allah\'ın yardımıyladır" anlamındaki "Havkale" zikridir.',
      en: 'Known as "Hawqalah": "There is no power and no strength except through Allah."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Lâ havle ve lâ kuvvete illâ billâh" (Havkale), kulun kendi acziyetini itiraf edip günahlardan korunma ve ibadete güç bulma kuvvetini yalnız Allah\'tan bilmesidir.',
        en: 'Reciting the Hawqalah expresses humble surrender, recognizing that neither turning away from harm nor strength for obedience happens except by Allah\'s aid.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Daavât 50; Müslim, Zikir 44',
        en: 'Bukhari, Da\'awat 50; Muslim, Dhikr 44',
      ),
      linkedZikirKey: 'Lâ havle ve lâ kuvvete illâ billâh',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_08',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    specialDayTags: ['kadir', 'ramazan', 'kandil'],
    stem: LocalizedText(
      tr: 'Hz. Âişe vâlidemiz "Kadir Gecesi\'ne erişirsem nasıl dua edeyim?" diye sorduğunda Peygamberimiz\'in (s.a.v.) öğrettiği duada öne çıkan ilahî isim hangisidir?',
      en: 'When \'A\'ishah (r.a.) asked what to pray on Laylat al-Qadr, which Divine Name stood at the center of the supplication taught by the Prophet (ﷺ)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Kahhâr', en: 'Al-Qahhar'),
        LocalizedText(tr: 'El-Afuvv', en: 'Al-\'Afuww'),
        LocalizedText(tr: 'El-Muahhir', en: 'Al-Mu\'akhkhir'),
        LocalizedText(tr: 'El-Kâbıd', en: 'Al-Qabid'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Allâhümme inneke afüvvün tuhibbü\'l-afve fa\'fü annî" (Allah\'ım! Sen çok affedicisin, affetmeyi seversin, beni de affet).',
      en: '"Allahumma innaka \'Afuwwun tuhibbul-\'afwa fa\'fu \'anni."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"El-Afuvv", günahları yalnız örtmekle kalmayıp izini dahi tamamen silen ve kulunu mahcup etmeyen sonsuz af sahibidir.',
        en: 'Al-\'Afuww signifies the One who not only conceals sins (Maghfirah) but effaces their very trace out of boundless grace.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Daavât 84; İbn Mâce, Duâ 5',
        en: 'Tirmidhi, Da\'awat 84; Ibn Majah, Du\'a\' 5',
      ),
      linkedZikirKey: 'El-Afuvv',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_09',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Tâhâ Sûresi 114. âyette bizzat Peygamber Efendimiz\'e (s.a.v.) öğretilen "Rabbi zidnî ilmâ" duasının anlamı "Rabbim, ilmimi artır!" demektir.',
      en: 'The Qur\'anic supplication taught to the Prophet (ﷺ) in Surah Ta-Ha 20:114, "Rabbi zidni \'ilma," means "My Lord, increase me in knowledge!"',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Kur\'ân\'da Hz. Peygamber\'den "ziyadesini (artırılmasını)" istemesi emredilen yegâne nimet ilimdir.',
      en: 'Knowledge (\'ilm) is the one blessing of which the Prophet (ﷺ) was explicitly commanded in the Qur\'an to ask for more.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İbn Hacer el-Askalânî\'nin işaret ettiği üzere Kur\'ân\'da Resûlullah\'a dünyevî malın değil, yalnız faydalı ilmin artırılmasını dilemesi ("Rabbi zidnî ilmâ") emredilmiştir.',
        en: 'As Ibn Hajar noted, Allah did not command His Messenger to ask for an increase in anything except beneficial knowledge ("Rabbi zidni \'ilma").',
      ),
      sourceRef: LocalizedText(
        tr: 'Tâhâ Sûresi, 20/114; İbn Hacer, Fethu\'l-Bârî, I/141',
        en: 'Surah Ta-Ha, 20:114; Ibn Hajar, Fath al-Bari, I/141',
      ),
      linkedZikirKey: 'Hz. Muhammed (s.a.v.) Duası 7',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_10',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Hiçbir şeye muhtaç olmayan, aksine bütün varlıkların her an kendisine muhtaç olduğu ve hacetlerin yöneltildiği Samedâniyet sahibi ismi hangisidir?',
      en: 'Which Divine Name denotes the Eternal Refuge upon whom all creation depends while He needs nothing whatsoever?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Müzill', en: 'Al-Mudhill'),
        LocalizedText(tr: 'El-Hâfıd', en: 'Al-Khafid'),
        LocalizedText(tr: 'Es-Samed', en: 'As-Samad'),
        LocalizedText(tr: 'El-Mümît', en: 'Al-Mumit'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'İhlâs Sûresi\'nin 2. âyeti olan "Allâhü\'s-Samed" ifadesindeki isimdir.',
      en: 'Verse 2 of Surah Al-Ikhlas: "Allahu\'s-Samad."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Es-Samed; zeval bulmayan bâkî, hiçbir eksiği ve ihtiyacı olmayan, bütün dilek ve ihtiyaçların biricik mercii olan Yüce Yaratıcı\'dır.',
        en: 'As-Samad is the Self-Sufficient Master to whom every creature turns in need while He transcends all need and imperfection.',
      ),
      sourceRef: LocalizedText(
        tr: 'İhlâs Sûresi, 112/2; Taberî, Câmiu\'l-Beyân, XXIV/689',
        en: 'Surah Al-Ikhlas, 112:2; At-Tabari, Jami\' al-Bayan, XXIV/689',
      ),
      linkedZikirKey: 'Es-Samed',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_11',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    specialDayTags: ['berat', 'regaip', 'kandil'],
    stem: LocalizedText(
      tr: 'Peygamber Efendimiz\'in (s.a.v.) "Vallâhi ben günde yetmiş defadan (bir rivayette yüz defadan) fazla Allah\'tan bağışlanma dilerim" buyurarak teşvik ettiği zikir hangisidir?',
      en: 'Which daily devotion did the Prophet (ﷺ) encourage by saying, "By Allah, I seek Allah\'s forgiveness and turn to Him in repentance more than seventy (or a hundred) times a day"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İstiğfâr (Estağfirullâh)', en: 'Istighfar (Astaghfirullah)'),
        LocalizedText(tr: 'Telbiye', en: 'Talbiyah'),
        LocalizedText(tr: 'Kunut', en: 'Qunut'),
        LocalizedText(tr: 'Teşrik Tekbiri', en: 'Tashriq Takbir'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kalpteki pası silen ve darlıktan kurtuluş kapısı açan "Estağfirullâh" zikridir.',
      en: 'Saying "Astaghfirullah" to cleanse the heart and invite relief.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İstiğfar yalnız günah sonrası değil, kulluktaki kusur bilinci ve mânevî terakki için müminin daimî virdidir.',
        en: 'Istighfar is not only sought after slips; even the sinless Messenger (ﷺ) practiced it constantly to elevate spiritual station and teach humility.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Daavât 3; Müslim, Zikir 41',
        en: 'Bukhari, Da\'awat 3; Muslim, Dhikr 41',
      ),
      linkedZikirKey: 'İstiğfar',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'esm_o_01',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de yer alan peygamber dualarını (Rabbenâ / Rabbi niyazlarını) sahipleriyle eşleştiriniz.',
      en: 'Match these Qur\'anic prophetic supplications with the Prophets who voiced them.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Âdem ve Hz. Havvâ (A\'râf, 23)', en: 'Adam & Hawwa (Al-A\'raf 7:23)'),
          right: LocalizedText(tr: 'Ey Rabbimiz! Biz kendimize zulmettik; bizi bağışlamazsan ziyan edenlerden oluruz', en: 'Our Lord, we have wronged ourselves; if You forgive us not, we will be among the losers'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Yûnus (Enbiyâ, 87)', en: 'Prophet Yunus (Al-Anbiya\' 21:87)'),
          right: LocalizedText(tr: 'Senden başka ilâh yoktur, Seni tenzih ederim; ben zalimlerden oldum', en: 'There is no deity except You; exalted are You! Indeed, I have been of the wrongdoers'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Süleyman (Neml, 19)', en: 'Prophet Sulayman (An-Naml 27:19)'),
          right: LocalizedText(tr: 'Rabbim! Bana ve anne-babama verdiğin nimetlere şükretmeye beni sevk et', en: 'My Lord, enable me to be grateful for Your favor upon me and upon my parents'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: '"Rabbenâ zalemnâ enfüsenâ..." Hz. Âdem\'in, "Lâ ilâhe illâ ente sübhâneke..." ise Hz. Yûnus\'un niyazıdır.',
      en: '"Rabbana zalamna anfusana..." is Adam\'s plea; "La ilaha illa Anta subhanaka..." is Yunus\'s plea.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Peygamber duaları Kur\'ân\'ın öğrettiği en sahih dua adabını yansıtır: Kusuru nefsinden bilmek, Allah\'ı tenzih etmek ve nimeti şükre bağlamak.',
        en: 'Qur\'anic prophetic prayers teach optimal etiquette before Allah: owning one\'s shortcoming, glorifying Allah, and anchoring blessings in gratitude.',
      ),
      sourceRef: LocalizedText(
        tr: 'A\'râf, 7/23; Enbiyâ, 21/87; Neml, 27/19',
        en: 'Al-A\'raf 7:23; Al-Anbiya\' 21:87; An-Naml 27:19',
      ),
      linkedZikirKey: 'Âdem (a.s.) Duası',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_02',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hz. İbrâhim\'in (a.s.) ateşe atılırken ve Peygamberimiz\'in (s.a.v.) Uhud sonrasında düşman tehdidine karşı sahâbîleriyle birlikte söylediği "Allah bize yeter, O ne güzel vekildir!" zikri hangisidir?',
      en: 'Which Qur\'anic declaration—"Sufficient for us is Allah, and He is the best Disposer of affairs"—was spoken by Prophet Ibrahim in the fire and by the Prophet (ﷺ) and his Companions after Uhud?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İnnâ lillâhi ve innâ ileyhi râciûn', en: 'Inna lillahi wa inna ilayhi raji\'un'),
        LocalizedText(tr: 'Hasbünallâhü ve ni\'me\'l-vekîl', en: 'Hasbunallahu wa ni\'mal-Wakil'),
        LocalizedText(tr: 'Tebârekallâhü ahsenü\'l-hâlikîn', en: 'Tabarakallahu ahsanul-khaliqin'),
        LocalizedText(tr: 'Ğufrâneke Rabbenâ ve ileyke\'l-masîr', en: 'Ghufranaka Rabbana wa ilaykal-masir'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Âl-i İmrân Sûresi 173. âyette geçen ve El-Vekîl ismine dayanan tevekkül cümlesidir.',
      en: 'Revealed in Surah Ali \'Imran 3:173, anchored in Allah\'s Name Al-Wakil.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Buhârî\'de İbn Abbâs\'tan (r.a.) nakledildiğine göre "Hasbünallâhü ve ni\'me\'l-vekîl" sözünü Hz. İbrâhim ateşe atıldığında, Hz. Muhammed (s.a.v.) ise korkutmalara karşı söylemiştir.',
        en: 'Ibn \'Abbas (r.a.) narrated in Sahih al-Bukhari that Ibrahim (a.s.) uttered "Hasbunallahu wa ni\'mal-Wakil" when cast into the fire, as did Muhammad (ﷺ) when threatened.',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân, 3/173; Buhârî, Tefsîr 3/13',
        en: 'Surah Ali \'Imran, 3:173; Bukhari, Tafsir 3/13',
      ),
      linkedZikirKey: 'Hasbünallahu ve ni\'mel vekil',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_03',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Buhârî\'de Şeddâd b. Evs\'ten (r.a.) rivayet edilen ve "Allâhümme ente Rabbî lâ ilâhe illâ ente halaktenî ve ene abdüke..." lafzıyla başlayan duaya Hz. Peygamber (s.a.v.) ne isim vermiştir?',
      en: 'What title did the Prophet (ﷺ) give to the supplication narrated by Shaddad ibn Aws in Bukhari beginning with "Allahumma Anta Rabbi la ilaha illa Anta, khalaqtani wa ana \'abduka..."?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İstihâre Duası', en: 'Supplication of Istikharah'),
        LocalizedText(tr: 'Sefer Duası', en: 'Supplication of Travel'),
        LocalizedText(tr: 'Seyyidü\'l-İstiğfâr (İstiğfârların Efendisi)', en: 'Sayyid al-Istighfar (The Master Supplication for Forgiveness)'),
        LocalizedText(tr: 'İftitah Duası', en: 'Opening Supplication of Salah'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Sabah ve akşam inanarak okuyan kimseye büyük müjde verilen "İstiğfârların Reisi/Efendisi"dir.',
      en: 'Literally "The Chief/Master of Seeking Forgiveness," recommended morning and evening.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Seyyidü\'l-İstiğfâr; tevhid, kulluk ikrarı, nimetlere şükür ve günahların itirafını en beliğ şekilde birleştirdiği için istiğfar dualarının tacı sayılmıştır.',
        en: 'Sayyid al-Istighfar unites affirmation of Tawhid, servitude, gratitude for blessings, and humble confession of shortcomings in unmatched eloquence.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Daavât 2',
        en: 'Bukhari, Da\'awat 2',
      ),
      linkedZikirKey: 'İstiğfar',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_04',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kullarının hayır kapılarını hikmetle açan, darlıkları gideren ve hak ile bâtıl arasında en âdil hükmü veren Allah\'ın güzel ismi hangisidir?',
      en: 'Which Beautiful Name of Allah means the Supreme Opener who unlocks doors of mercy, relief, and victorious judgment?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Fettâh', en: 'Al-Fattah'),
        LocalizedText(tr: 'El-Kâbıd', en: 'Al-Qabid'),
        LocalizedText(tr: 'El-Muahhir', en: 'Al-Mu\'akhkhir'),
        LocalizedText(tr: 'Ed-Dârr', en: 'Ad-Darr'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Sebe\' Sûresi 26. âyette "Ve hüve\'l-Fettâhu\'l-Alîm" olarak geçer; camiye girerken "Allâhümmeftah lî ebvâbe rahmetik" duasıyla da hatırlanır.',
      en: 'Appears in Surah Saba\' 34:26 ("He is Al-Fattah, Al-\'Alim") and shares the root of Fath (opening).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Fettâh; kapalı görünen rızık, ilim ve gönül kapılarını lütfuyla açan, mazlumlara çıkış yolu ihsan edendir.',
        en: 'Al-Fattah graciously opens closed doors of sustenance, comprehension, and spiritual solace for His servants.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sebe\' Sûresi, 34/26; Fâtır Sûresi, 35/2',
        en: 'Surah Saba\', 34:26; Surah Fatir, 35:2',
      ),
      linkedZikirKey: 'El-Fettâh',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_05',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Mümin bir kulun mubah olan önemli bir iş hakkında iki rekât nâfile namaz kılıp işin kendisi için hayırlı olup olmadığını Allah\'a danışarak dua etmesine "İstihâre" denir.',
      en: 'Praying two voluntary rak\'ahs and reciting the Prophetic supplication seeking Allah\'s guidance in a permissible decision is called "Istikharah."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Câbir b. Abdullah\'tan (r.a.) rivayetle Hz. Peygamber ashâbına Kur\'ân\'dan bir sûre öğretir gibi İstihâre duasını öğretmiştir.',
      en: 'Jabir (r.a.) reported in Sahih al-Bukhari that the Prophet (ﷺ) taught them Istikharah in all matters.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İstihârede rüya görmek şart değildir; istişare (danışma) ile birlikte dua edildikten sonra kalbin ferahlayıp işin kolaylaşması hayır işaretidir. Farz veya haram konularda ise istihâre yapılmaz.',
        en: 'Seeing a dream is not required in Istikharah; pairing consultation (istisharah) with the Prophetic du\'a brings clarity and ease toward what is best.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Teheccüd 25, Daavât 48; Diyanet İlmihali Cilt 1, s. 305',
        en: 'Bukhari, Tahajjud 25, Da\'awat 48; Diyanet Catechism Vol. 1, p. 305',
      ),
      linkedZikirKey: 'El-Alim',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_06',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sâlih kullarını çok seven ve sevilmeye en lâyık olan, gönüllerde muhabbet ve ülfet yaratan Allah\'ın güzel ismi hangisidir?',
      en: 'Which Beautiful Name of Allah means the Most Loving—who loves His righteous servants and is most worthy of pure love?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Hasîb', en: 'Al-Hasib'),
        LocalizedText(tr: 'Er-Rakîb', en: 'Ar-Raqib'),
        LocalizedText(tr: 'El-Vedûd', en: 'Al-Wadud'),
        LocalizedText(tr: 'El-Mukît', en: 'Al-Muqit'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Hûd Sûresi 90 ("İnne Rabbî Rahîmün Vedûd") ve Bürûc Sûresi 14 ("Ve hüve\'l-Gafûru\'l-Vedûd") âyetlerinde geçer.',
      en: 'Mentioned in Hud 11:90 and Al-Buruj 85:14 ("And He is the Forgiving, the Most Loving").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Bürûc 14. âyette "El-Gafûr" ile "El-Vedûd" isminin yan yana gelmesi müthiş bir müjdedir: Allah tevbe eden kulunu hem bağışlar hem de sevgiyle bağrına basar.',
        en: 'Pairing Al-Ghafur with Al-Wadud in Al-Buruj 85:14 reveals sublime grace: Allah not only forgives the repentant servant, He also loves them.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bürûc, 85/14; Hûd, 11/90; Meryem, 19/96',
        en: 'Al-Buruj 85:14; Hud 11:90; Maryam 19:96',
      ),
      linkedZikirKey: 'El-Vedûd',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_07',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'En ince ve gizli işleri bütün incelikleriyle bilen, kullarına sezdirmeden en nazik ve lütufkâr yollarla iyilik ulaştıran Esmaü\'l-Hüsna hangisidir?',
      en: 'Which Divine Name signifies the Subtle and All-Gentle One who knows the finest intricacies and brings relief in unseen, delicate ways?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Cebbâr', en: 'Al-Jabbar'),
        LocalizedText(tr: 'El-Latîf', en: 'Al-Latif'),
        LocalizedText(tr: 'El-Kahhâr', en: 'Al-Qahhar'),
        LocalizedText(tr: 'El-Mütekebbir', en: 'Al-Mutakabbir'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Yûsuf Sûresi 100. âyette Hz. Yûsuf tüm imtihanların hayra çıkışını "Şüphesiz Rabbim dilediğine Latîf\'tir" diyerek özetlemiştir.',
      en: 'In Surah Yusuf 12:100, Prophet Yusuf praised Allah saying: "Indeed, my Lord is Subtle (Latif) in fulfilling what He wills."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Latîf; gözlerin idrak edemediği fakat bütün gözleri idrak eden (En\'âm 6/103), kullarına ummadıkları ince sebeplerle lütuf eriştirendir.',
        en: 'Al-Latif perceives the subtlest secrets (Al-An\'am 6:103) and weaves gentle kindness for His servants through unforeseen avenues.',
      ),
      sourceRef: LocalizedText(
        tr: 'En\'âm, 6/103; Yûsuf, 12/100; Mülk, 67/14',
        en: 'Al-An\'am 6:103; Yusuf 12:100; Al-Mulk 67:14',
      ),
      linkedZikirKey: 'El-Latîf',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_08',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Günlük sünnet duaları okundukları durumlarla doğru şekilde eşleştiriniz.',
      en: 'Match these Prophetic daily supplications with their occasions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Elhamdülillâhillezî ahyânâ ba\'de mâ emâtenâ ve ileyhi\'n-nüşûr', en: 'Alhamdulillahilladhi ahyana ba\'da ma amatana wa ilayhin-nushur'),
          right: LocalizedText(tr: 'Uykudan uyanınca okunan şükür duası', en: 'Upon waking up from sleep'),
        ),
        (
          left: LocalizedText(tr: 'Rabbenâ âtinâ fi\'d-dünyâ haseneten ve fi\'l-âhirati haseneh...', en: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanah...'),
          right: LocalizedText(tr: 'Hz. Peygamber\'in en çok okuduğu dünya-âhiret iyiliği duası (Bakara 201)', en: 'The Prophet\'s most frequent comprehensive prayer (Al-Baqarah 2:201)'),
        ),
        (
          left: LocalizedText(tr: 'İnnâ lillâhi ve innâ ileyhi râciûn (İstircâ)', en: 'Inna lillahi wa inna ilayhi raji\'un (Istirja\')'),
          right: LocalizedText(tr: 'Musibet ve vefat haberi anında sabır ve teslimiyet zikri (Bakara 156)', en: 'At moments of loss or calamity (Al-Baqarah 2:156)'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: '"Ahyânâ ba\'de mâ emâtenâ" uyku sonrası dirilişe şükrü, "Rabbenâ âtinâ" ise dünya ve âhiret hasenesini ifade eder.',
      en: '"Ahyana..." gives thanks for waking; "Rabbana atina..." asks for good in both worlds.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Enes b. Mâlik\'in (r.a.) bildirdiğine göre Peygamber Efendimiz\'in dilinden en çok dökülen dua Bakara 201\'deki "Rabbenâ âtinâ..." duasıydı.',
        en: 'Anas ibn Malik (r.a.) reported in Bukhari and Muslim that the supplication most frequently made by the Prophet (ﷺ) was Al-Baqarah 2:201 ("Rabbana atina...").',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/156, 201; Buhârî, Daavât 5, 27',
        en: 'Al-Baqarah 2:156, 201; Bukhari, Da\'awat 5, 27',
      ),
      linkedZikirKey: 'Elhamdülillah',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_09',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kullarının tevbelerini tekrar tekrar kabul buyuran ve onları tevbeye muvaffak kılan "Et-Tevvâb" ismi ile kendisinden isteyenin duasına icabet eden "El-Mücîb" ismi Kur\'ân\'da açıkça zikredilmiştir.',
      en: 'Both "At-Tawwab" (the Acceptor of Repentance) and "Al-Mujib" (the Responsive One who answers supplications) are explicitly mentioned in the Qur\'an.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Bakara 128\'de "Et-Tevvâbü\'r-Rahîm", Hûd 61\'de ise "Karîbün Mücîb" (çok yakın ve dualara icabet eden) buyrulmaktadır.',
      en: 'Al-Baqarah 2:128 mentions At-Tawwab, and Hud 11:61 mentions Qaribun Mujib.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Et-Tevvâb kulunun kalbine pişmanlık ilham edip dönüşünü kabul edendir; El-Mücîb ise el açıp yalvaran kulunu boş çevirmeyip hikmetiyle karşılık verendir.',
        en: 'At-Tawwab inspires sincere return and accepts it repeatedly; Al-Mujib hears every earnest call and responds with perfect wisdom.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/37, 128; Hûd, 11/61; Mü\'min, 40/60',
        en: 'Al-Baqarah 2:37, 128; Hud 11:61; Ghafir 40:60',
      ),
      linkedZikirKey: 'Et-Tevvâb',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_10',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Gücü her şeye yettiği hâlde günahkârları cezalandırmakta acele etmeyen, mühlet verip yumuşaklıkla muamele buyuran Allah\'ın güzel ismi hangisidir?',
      en: 'Which Beautiful Name of Allah describes the Most Forbearing who does not hasten punishment despite absolute power, granting time to repent?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Bâis', en: 'Al-Ba\'ith'),
        LocalizedText(tr: 'El-Muhsî', en: 'Al-Muhsi'),
        LocalizedText(tr: 'El-Mukaddim', en: 'Al-Muqaddim'),
        LocalizedText(tr: 'El-Halîm', en: 'Al-Halim'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '"Hilm" (yumuşaklık, teenni ve hoşgörü) kökünden gelir; Bakara 225 ve Fâtır 41. âyetlerde geçer.',
      en: 'Derived from "hilm" (forbearance and clemency), appearing in Al-Baqarah 2:225 and Fatir 35:41.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Fâtır Sûresi 45. âyette bildirildiği üzere şayet Allah insanları işledikleri yüzünden derhâl cezalandırsaydı yeryüzünde canlı kalmazdı; O\'nun El-Halîm ismi kullarına tevbe fırsatı tanır.',
        en: 'As Surah Fatir 35:45 teaches, Allah\'s Forbearance (Al-Halim) grants humanity respite to awaken, mend wrongs, and return to Him.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/225, 263; Fâtır, 35/41-45',
        en: 'Al-Baqarah 2:225, 263; Fatir 35:41-45',
      ),
      linkedZikirKey: 'El-Halîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_11',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Âl-i İmrân Sûresi 38. âyette Hz. Zekeriyyâ\'nın (a.s.) mihrapta ellerini açarak hayırlı evlât için yaptığı dua hangi lafızla başlar?',
      en: 'With which words did Prophet Zakariyya (a.s.) pray in the sanctuary for righteous offspring in Surah Ali \'Imran 3:38?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Rabbi heb lî min ledünke zürriyyeten tayyibeten inneke semîu\'d-duâ\'',
          en: 'Rabbi hab li min ladunka dhurriyyatan tayyibatan innaka Sami\'ud-du\'a\'',
        ),
        LocalizedText(
          tr: 'Rabbi\'şrah lî sadrî ve yessir lî emrî',
          en: 'Rabbishrah li sadri wa yassir li amri',
        ),
        LocalizedText(
          tr: 'Rabbi enzilnî münzelen mübâreken',
          en: 'Rabbi anzilni munzalan mubarakan',
        ),
        LocalizedText(
          tr: 'Rabbi eûzü bike min hemezâti\'ş-şeyâtîn',
          en: 'Rabbi a\'udhu bika min hamazatish-shayatin',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Ey Rabbim! Bana katından temiz (hayırlı) bir nesil ihsan eyle; şüphesiz Sen duayı işitensin" anlamındadır.',
      en: 'Meaning: "My Lord, grant me from Yourself pure offspring; indeed, You are the Hearer of supplication."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İlerlemiş yaşına rağmen Allah\'ın kudretinden ümit kesmeyen Hz. Zekeriyyâ\'nın bu samimi niyazına Cenâb-ı Hak Hz. Yahyâ (a.s.) müjdesiyle icabet etmiştir.',
        en: 'Never doubting Allah\'s power despite advanced age, Prophet Zakariyya\'s heartfelt prayer was answered with the glad tidings of Prophet Yahya (a.s.).',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân Sûresi, 3/38-39',
        en: 'Surah Ali \'Imran, 3:38-39',
      ),
      linkedZikirKey: 'Zekeriyyâ (a.s.) Duası 2',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 11 QUESTIONS
  // =========================================================================
  IrfanQuestion(
    id: 'esm_i_01',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahih hadislerde kendisiyle dua edildiğinde kabul olunduğu bildirilen "İsm-i Âzam" (En Yüce İsim) rivayetlerinde, Bakara 255, Âl-i İmrân 1-2 ve Tâhâ 111. âyetlerin üçünde birden ortak geçen ikili ilahî isim hangisidir?',
      en: 'In authentic Hadith traditions on "al-Ism al-A\'zam" (Allah\'s Greatest Name), which pair of Divine Names appears across all three cited verses: Al-Baqarah 2:255, Ali \'Imran 3:1-2, and Ta-Ha 20:111?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Kâbıd — El-Bâsıt', en: 'Al-Qabid — Al-Basit'),
        LocalizedText(tr: 'El-Evvel — El-Âhir', en: 'Al-Awwal — Al-Akhir'),
        LocalizedText(tr: 'El-Hayy — El-Kayyûm', en: 'Al-Hayy — Al-Qayyum'),
        LocalizedText(tr: 'El-Muizz — El-Müzill', en: 'Al-Mu\'izz — Al-Mudhill'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Ezeli ve ebedi diri olan (Hayy) ve her şeyin varlığını ayakta tutan (Kayyûm) isimleridir.',
      en: 'The Ever-Living (Al-Hayy) and the Self-Subsisting Sustainer of all existence (Al-Qayyum).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ebû Ümâme hadisinde İsm-i Âzam\'ın Bakara, Âl-i İmrân ve Tâhâ sûrelerinde olduğu bildirilmiş; İslâm âlimleri bu üç yerdeki ortak lafzın "El-Hayyü\'l-Kayyûm" olduğuna dikkat çekmiştir.',
        en: 'Based on the narration of Abu Umamah pointing to Al-Baqarah, Ali \'Imran, and Ta-Ha, scholars highlighted "Al-Hayy al-Qayyum" as a supreme axis of al-Ism al-A\'zam.',
      ),
      sourceRef: LocalizedText(
        tr: 'İbn Mâce, Duâ 9; Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 100',
        en: 'Ibn Majah, Du\'a\' 9; Abu Dawud, Witr 23; Tirmidhi, Da\'awat 100',
      ),
      linkedZikirKey: 'El-Kayyûm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_02',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) "Yâ Ze\'l-Celâli ve\'l-İkrâm! sözüne devam ediniz (onu dilinizden düşürmeyiniz)" tavsiyesinde birleşen iki ilahî tecelli neyi ifade eder?',
      en: 'What two complementary divine manifestations unite in "Dhu\'l-Jalali wa\'l-Ikram," which the Prophet (ﷺ) urged believers to invoke constantly?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sonsuz azamet ve yücelik (Celâl) ile sınırsız lütuf ve cömertlik (İkrâm)',
          en: 'Infinite Majesty and Awe (Jalal) united with boundless Grace and Generosity (Ikram)',
        ),
        LocalizedText(
          tr: 'Yalnızca kış ve yaz mevsimlerinin döngüsü',
          en: 'Merely the alternation of winter and summer',
        ),
        LocalizedText(
          tr: 'Sadece rüzgârların ve bulutların sevk edilmesi',
          en: 'Only the steering of winds and clouds',
        ),
        LocalizedText(
          tr: 'Yalnızca geçmiş ümmetlerin tarihçesi',
          en: 'Only the chronicle of bygone nations',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Rahmân Sûresi 27 ve 78. âyetlerde geçen, hem mehâbeti (Celâl) hem ikram ve keremi (Cemâl) cem eden isimdir.',
      en: 'Appearing in Surah Ar-Rahman 55:27 & 78, harmonizing reverent awe (Jalal) and generous honor (Ikram).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Her farz namazdan sonra selâm verince "Allâhümme ente\'s-Selâm ve minke\'s-selâm, tebârekte yâ Ze\'l-Celâli ve\'l-İkrâm" okumak sahih sünnettir.',
        en: 'Immediately after concluding obligatory prayer with Salam, the Prophet (ﷺ) would say: "Allahumma Antas-Salam wa minkas-salam, tabarakta ya Dhal-Jalali wal-Ikram."',
      ),
      sourceRef: LocalizedText(
        tr: 'Rahmân, 55/27, 78; Müslim, Mesâcid 135; Tirmizî, Daavât 91',
        en: 'Ar-Rahman 55:27, 78; Muslim, Masajid 135; Tirmidhi, Da\'awat 91',
      ),
      linkedZikirKey: 'Zü\'l-Celâli ve\'l-İkrâm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_03',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Esmaü\'l-Hüsna\'da birbirini bütünleyen (tekâbül eden) ikili isim çiftlerini tecelli hikmetleriyle eşleştiriniz.',
      en: 'Match these complementary pairs of Divine Names with their balanced manifestations.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'El-Kâbıd — El-Bâsıt', en: 'Al-Qabid — Al-Basit'),
          right: LocalizedText(tr: 'Hikmetiyle daraltıp ölçülü kılan — lütfuyla genişletip ferahlık veren', en: 'The Withholder by wisdom — The Expander who grants spaciousness'),
        ),
        (
          left: LocalizedText(tr: 'El-Muhyî — El-Mümît', en: 'Al-Muhyi — Al-Mumit'),
          right: LocalizedText(tr: 'Hayat bahşedip dirilten — eceli geldiğinde ölümü yaratan', en: 'The Giver of Life — The Creator of Death'),
        ),
        (
          left: LocalizedText(tr: 'El-Evvel — El-Âhir', en: 'Al-Awwal — Al-Akhir'),
          right: LocalizedText(tr: 'Başlangıcı olmayan ezelî — sonu olmayan ebedî', en: 'The First without beginning — The Last without end'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Bakara 245\'te "yakbidu ve yebsutu", Hadîd 3\'te ise "Hüve\'l-Evvelü ve\'l-Âhiru..." buyrulur.',
      en: 'Al-Baqarah 2:245 pairs Qabd and Bast; Al-Hadid 57:3 proclaims Al-Awwal and Al-Akhir.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm akaidinde karşılıklı tecelli eden isimleri birlikte tefekkür etmek kemâl edebidir; mümin darlıkta sabır, genişlikte şükürle her iki hâlde de Rabbini tanır.',
        en: 'Contemplating complementary Divine Names together nurtures spiritual equilibrium—steadfastness in constriction and humble gratitude in expansion.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/245; Hadîd, 57/2-3; Gazzâlî, el-Maksadü\'l-Esnâ',
        en: 'Al-Baqarah 2:245; Al-Hadid 57:2-3; Al-Ghazali, Al-Maqsad al-Asna',
      ),
      linkedZikirKey: 'El-Bâsit',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_04',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Namazda okunan "Kunut Duaları" (Allâhümme innâ nesteînüke... / Allâhümmehdînâ...) konusunda Hanefî ve Şâfiî mezheplerinin sünnet/vacip uygulaması hangi seçenekte doğru verilmiştir?',
      en: 'Which option accurately states the regular practice of the Qunut supplication in Hanafi and Shafi\'i jurisprudence?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hanefîlerde yalnız bayram namazında, Şâfiîlerde ise ikindi namazında okunur',
          en: 'Only in Eid prayer for Hanafis, and in \'Asr prayer for Shafi\'is',
        ),
        LocalizedText(
          tr: 'Hanefîlerde Vitir namazının 3. rekâtında vacip olarak; Şâfiîlerde Sabah namazının 2. rekâtında rükûdan sonra (ve Ramazan\'ın ikinci yarısında Vitir\'de) sünnet olarak okunur',
          en: 'In Hanafi fiqh as wajib in the 3rd rak\'ah of Witr; in Shafi\'i fiqh as Sunnah after Ruku\' in the 2nd rak\'ah of Fajr (and Witr in late Ramadan)',
        ),
        LocalizedText(
          tr: 'Her iki mezhepte de yalnız cenaze namazında okunur',
          en: 'Only in funeral prayer in both schools',
        ),
        LocalizedText(
          tr: 'Hiçbir farz veya vacip namazda Kunut okunmaz',
          en: 'Never recited in any regular prayer',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Hanefîler Vitir\'in 3. rekâtında rükûdan önce; Şâfiîler ise Sabah namazının 2. rekâtında rükûdan doğrulunca (i\'tidâlde) Kunut okurlar.',
      en: 'Hanafis recite Qunut in Witr before Ruku\'; Shafi\'is recite Qunut in Fajr after rising from Ruku\'.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Kunut", Allah\'a huşû ile itaat ve niyaz demektir. Ayrıca ümmetin ağır musibet zamanlarında farz namazlarda "Nâzile Kunutu" yapılması da sünnette mevcuttur.',
        en: '"Qunut" signifies humble devotion and earnest supplication. Both schools preserve authentic Prophetic narrations of Qunut.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Vitir 5; Nesâî, Tatbîk 28; Diyanet İlmihali Cilt 1, s. 274',
        en: 'Abu Dawud, Witr 5; An-Nasa\'i, Tatbiq 28; Diyanet Catechism Vol. 1, p. 274',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde Vitir namazının 3. rekâtında Fâtiha ve sûreden sonra tekbir alınıp rükûdan önce Kunut okumak vaciptir.',
        en: 'In Hanafi fiqh, reciting Qunut before Ruku\' in the 3rd rak\'ah of Witr is wajib.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde Sabah namazının 2. rekâtında rükûdan doğrulunca Kunut okumak eb\'âz sünnettir; unutulursa sehiv secdesi yapılır.',
        en: 'In Shafi\'i fiqh, reciting Qunut after rising from Ruku\' in the 2nd rak\'ah of Fajr is an emphasized (ab\'ad) Sunnah.',
      ),
      linkedZikirKey: 'El-Hâdî',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_05',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'İslâm âlimlerinin ittifakına göre duanın kabulüne en elverişli edep; helâl lokma yemek, kalbi gafletten uyandırmak, duaya Allah\'a hamd ve Resûlü\'ne salavât ile başlamaktır.',
      en: 'By scholarly consensus, key etiquettes for accepted supplication include lawful sustenance, presence of heart, and opening with praise of Allah and Salawat upon His Messenger (ﷺ).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Fedâle b. Ubeyd hadisinde Peygamberimiz (s.a.v.) duaya hamd ve salavâtla başlayıp öylece dua etmeyi bizzat öğretmiştir.',
      en: 'In the hadith of Fadalah ibn \'Ubayd, the Prophet (ﷺ) taught beginning du\'a with praise of Allah and Salawat.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Müslim\'de geçen hadiste haram kazançtan sakınmanın duanın kabulünde temel şart olduğu; Tirmizî\'de ise hamd ve salavâtın duanın kanatları olduğu vurgulanmıştır.',
        en: 'Sahih Muslim underscores lawful nourishment as vital to accepted prayer, while Jami\' at-Tirmidhi highlights opening with praise and Salawat with an attentive heart.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Zekât 65; Tirmizî, Daavât 64-65',
        en: 'Muslim, Zakat 65; Tirmidhi, Da\'awat 64-65',
      ),
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_06',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Her sözünü ve fiilini yerli yerince, tam bir ölçü ve şaşmaz hikmetle yaratan; hiçbir şeyi boşuna yaratmayan Allah\'ın güzel ismi hangisidir?',
      en: 'Which Beautiful Name of Allah signifies the All-Wise whose decrees, laws, and creations are placed with flawless purpose and wisdom?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'El-Hakîm', en: 'Al-Hakim'),
        LocalizedText(tr: 'El-Vâcid', en: 'Al-Wajid'),
        LocalizedText(tr: 'El-Câmi\'', en: 'Al-Jami\''),
        LocalizedText(tr: 'El-Muğnî', en: 'Al-Mughni'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de doksandan fazla yerde (çoğunlukla El-Azîz ve El-Alîm isimleriyle birlikte) zikredilen "Hikmet Sahibi" ismidir.',
      en: 'Mentioned over ninety times in the Qur\'an, often paired with Al-\'Aziz or Al-\'Alim.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Hakîm; hem kâinattaki tekvînî kanunlarında hem de Kur\'ân\'daki teşriî hükümlerinde abesten (boş ve anlamsızlıktan) münezzeh mutlak hikmet sahibidir.',
        en: 'Al-Hakim possesses consummate wisdom in both cosmic creation and revealed guidance; nothing He decrees is ever in vain.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/32, 129; Lokmân, 31/27; Mü\'minûn, 23/115',
        en: 'Al-Baqarah 2:32, 129; Luqman 31:27; Al-Mu\'minun 23:115',
      ),
      linkedZikirKey: 'El-Hakîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_07',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hiçbir karşılık beklemeksizin üst üste ve bolca bağışta bulunan, nimetlerini karşılıksız hibe eden Allah\'ın ismi hangisidir ve Âl-i İmrân 8. âyette hangi dua içinde geçer?',
      en: 'Which Divine Name means the Ever-Bestowing Giver of gifts without measure, invoked at the close of Surah Ali \'Imran 3:8?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'El-Hasîb — "Kefâ billâhi hasîbâ"',
          en: 'Al-Hasib — "Kafa billahi Hasiba"',
        ),
        LocalizedText(
          tr: 'Er-Rakîb — "İnnallâhe kâne aleyküm rakîbâ"',
          en: 'Ar-Raqib — "Innallaha kana \'alaykum Raqiba"',
        ),
        LocalizedText(
          tr: 'El-Vehhâb — "Rabbenâ lâ tüziğ kulûbenâ... inneke ente\'l-Vehhâb"',
          en: 'Al-Wahhab — "Rabbana la tuzigh qulubana... innaka Antal-Wahhab"',
        ),
        LocalizedText(
          tr: 'Eş-Şehîd — "Vallâhü alâ külli şey\'in şehîd"',
          en: 'Ash-Shahid — "Wallahu \'ala kulli shay\'in Shahid"',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Hibe" (karşılıksız bağış) kelimesiyle aynı kökten gelir: "Heb lenâ min ledünke rahmeten inneke ente\'l-Vehhâb."',
      en: 'Shares the root of "hibah" (pure gift): "...grant us mercy from Yourself; indeed, You are Al-Wahhab."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Âl-i İmrân 8. âyetteki "Rabbimiz! Bizi hidayete erdirdikten sonra kalplerimizi eğriltme, bize katından rahmet bağışla; şüphesiz Sen çok bağışlayansın (el-Vehhâb)" duası Peygamberimiz\'in dilinden düşürmediği sebat niyazıdır.',
        en: 'Surah Ali \'Imran 3:8 asks Allah to keep our hearts steadfast after guidance and bestow mercy through His Name Al-Wahhab.',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân, 3/8; Sâd, 38/9, 35; Tirmizî, Kader 7',
        en: 'Ali \'Imran 3:8; Sad 38:9, 35; Tirmidhi, Qadar 7',
      ),
      linkedZikirKey: 'El-Vehhâb',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_08',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Buhârî ve Müslim\'de Cuma günü içerisinde bulunduğu müjdelenen ve Müslüman bir kulun o vakte denk gelip Allah\'tan hayır istediğinde duasının geri çevrilmeyeceği bildirilen özel zaman dilimine ne ad verilir?',
      en: 'What is the blessed window on Fridays mentioned in Bukhari and Muslim during which no Muslim asks Allah for good except that He grants it?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İstivâ Vakti', en: 'Time of Istiwa\''),
        LocalizedText(tr: 'Sâat-i İcâbe (İcâbet Saati)', en: 'Sa\'at al-Ijabah (The Hour of Acceptance)'),
        LocalizedText(tr: 'Kerâhet Vakti', en: 'Time of Karahah'),
        LocalizedText(tr: 'İsfâr Vakti', en: 'Time of Isfar'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Âlimlerin kuvvetli görüşlerine göre hatibin minbere çıkışıyla namazın bitimi arasında veya ikindi sonrasından güneş batışına kadarki dilimde aranır.',
      en: 'Sought especially while the imam sits on the minbar through prayer, or in the final hour after \'Asr before Friday sunset.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kadir Gecesi\'nin Ramazan içinde gizlenmesi gibi Sâat-i İcâbe de Cuma günü içine gizlenmiştir ki mümin tüm Cuma gününü zikir, salavât ve dua uyanıklığıyla ihya etsin.',
        en: 'Just as Laylat al-Qadr is concealed in Ramadan, Sa\'at al-Ijabah is concealed within Friday so believers enliven the entire day with remembrance and prayer.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Cum\'a 37; Müslim, Cum\'a 13-15',
        en: 'Bukhari, Jumu\'ah 37; Muslim, Jumu\'ah 13-15',
      ),
      linkedZikirKey: 'El-Mücîb',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_09',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hüzün, gam ve keder anında Peygamber Efendimiz\'in (s.a.v.) okuduğu "Lâ ilâhe illallâhü\'l-Azîmü\'l-Halîm, lâ ilâhe illallâhü Rabbü\'l-Arşi\'l-Azîm..." zikrine hadis kaynaklarında "Kerbi (Sıkıntıyı) Gideren Dua" denilmiştir.',
      en: 'The Prophetic remembrance in moments of deep distress—"La ilaha illallahul-\'Azimul-Halim, la ilaha illallahu Rabbul-\'Arshil-\'Azim..."—is known in Hadith collections as Du\'a\' al-Karb.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Buhârî ve Müslim\'de İbn Abbâs\'tan (r.a.) rivayet edilen sahih sıkıntı duasıdır.',
      en: 'Narrated by Ibn \'Abbas (r.a.) in both Sahih al-Bukhari and Sahih Muslim.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Dikkat edilirse bu duada doğrudan bir istek cümlesi bile olmadan Allah\'ın Azîm, Halîm ve Arş\'ın Rabbi oluşu tesbih edilir; tevhid senâsı kalpteki darlığı ferahlığa kavuşturur.',
        en: 'Remarkably, Du\'a\' al-Karb consists purely of glorifying Allah\'s Majesty, Forbearance, and Lordship over the Heavens, Earth, and Mighty Throne—melting anxiety through awe and trust.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Daavât 27; Müslim, Zikir 83',
        en: 'Bukhari, Da\'awat 27; Muslim, Dhikr 83',
      ),
      linkedZikirKey: 'El-Halîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_10',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Esmaü\'l-Hüsna\'daki yakın anlamlı ilahî isimlerin ince nüanslarını doğru açıklamalarıyla eşleştiriniz.',
      en: 'Match these closely related Divine Names with their distinct classical nuances.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'El-Gaffâr', en: 'Al-Ghaffar'),
          right: LocalizedText(tr: 'Günahları tekrar tekrar örten, kulunu dünyada ve âhirette rezil etmeyen', en: 'The Oft-Forgiving who repeatedly veils faults from exposure'),
        ),
        (
          left: LocalizedText(tr: 'El-Kuddûs', en: 'Al-Quddus'),
          right: LocalizedText(tr: 'Her türlü beşerî tasavvur, kusur ve noksanlıktan mutlak münezzeh ve tertemiz olan', en: 'The All-Holy, transcendent above every imperfection'),
        ),
        (
          left: LocalizedText(tr: 'El-Adl', en: 'Al-\'Adl'),
          right: LocalizedText(tr: 'Zerre kadar zulmetmeyen, her hak sahibine hakkını eksiksiz veren mutlak adalet sahibi', en: 'The Utterly Just who never wrongs even by an atom\'s weight'),
        ),
        (
          left: LocalizedText(tr: 'El-Bâkî', en: 'Al-Baqi'),
          right: LocalizedText(tr: 'Her fânî yok olduktan sonra varlığı ebediyyen devam eden', en: 'The Everlasting whose existence endures eternally'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Mağfiret "örtmek", takdîs "arındırıp tenzih etmek", adl "adalet", bekâ ise "ebedî kalıcılık" demektir.',
      en: 'Ghafr = veiling sins; Quds = holiness; \'Adl = justice; Baqa\' = everlastingness.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmam Gazzâlî\'nin "el-Maksadü\'l-Esnâ"da belirttiği üzere kulun Esmaü\'l-Hüsna\'dan nasibi; affedici olmak, kalbini arındırmak, adaletten ayrılmamak ve fânî dünyaya aldanmamaktır.',
        en: 'As Imam al-Ghazali explains in Al-Maqsad al-Asna, knowing Allah\'s Names adorns the believer\'s character with forgiveness, purity, justice, and detachment from fleeting vanity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tâhâ, 20/82; Haşr, 59/23; Rahmân, 55/27; Gazzâlî, el-Maksadü\'l-Esnâ',
        en: 'Ta-Ha 20:82; Al-Hashr 59:23; Ar-Rahman 55:27; Al-Ghazali, Al-Maqsad al-Asna',
      ),
      linkedZikirKey: 'El-Gaffâr',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_11',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Buhârî ve Müslim\'de geçen Esmâü\'l-Hüsnâ hadisinde "Allah\'ın doksan dokuz ismi vardır; kim bunları ihsâ ederse cennete girer" buyrulmaktadır. Âlimler buradaki "ihsâ" kelimesini en kâmil manada nasıl açıklamışlardır?',
      en: 'In the famous Bukhari & Muslim Hadith—"Allah has ninety-nine Names; whoever performs \'ihsa\'\' of them enters Paradise"—how did classical scholars explain the fullest meaning of "ihsa\'"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sadece duvara asıp hiç okumamak',
          en: 'Merely hanging them on a wall without reading',
        ),
        LocalizedText(
          tr: 'Yalnızca sayılarını rakam olarak bilmek',
          en: 'Knowing only the numeral 99 without the names',
        ),
        LocalizedText(
          tr: 'Yalnızca tartışma meclislerinde kullanmak',
          en: 'Using them only in debates',
        ),
        LocalizedText(
          tr: 'Lafızlarını bellemek, sahih manalarını kavramak, onlarla dua edip ahlâkına yansıtmak',
          en: 'Learning them by heart, understanding their meanings, invoking Allah by them, and living by their moral implications',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Hattâbî ve Nevevî\'ye göre ihsâ; ezberleme, manasını idrak etme ve gereğiyle amel edip kullukta tahakkuk etmeyi kapsar.',
      en: 'Al-Khattabi and An-Nawawi explain ihsa\' as memorizing, comprehending, supplicating with, and embodying reverence for them.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İlimden amele uzanan İrfan yolculuğunun özü budur: Esmaü\'l-Hüsna\'yı tanımak (marifet), dil ile zikretmek (vird) ve kalp-ahlâk güzelliğine dönüştürmektir (ihsan).',
        en: 'This embodies the heart of Irfan: knowing Allah through His Most Beautiful Names, remembering Him on the tongue, and letting that reverence beautify one\'s character.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Şurût 18, Daavât 68; Müslim, Zikir 5; Nevevî, Şerhu Müslim, XVII/5',
        en: 'Bukhari, Shurut 18, Da\'awat 68; Muslim, Dhikr 5; An-Nawawi, Sharh Muslim, XVII/5',
      ),
      linkedZikirKey: 'Es-Semi\'',
    ),
  ),
];
