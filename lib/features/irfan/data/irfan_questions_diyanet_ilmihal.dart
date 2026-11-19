import '../domain/irfan_models.dart';

/// 75 Authentic Bilingual (TR/EN) Questions sourced from Diyanet İşleri Başkanlığı İslâm İlmihali (Vols. 1 & 2).
const List<IrfanQuestion> kIrfanQuestionsDiyanetIlmihal = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 25 QUESTIONS (dilm_b_01..dilm_b_25)
  // =========================================================================
  IrfanQuestion(
    id: 'dilm_b_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Diyanet İlmihali\'ne göre, yükümlü olan her Müslümanın bizzat yerine getirmesi gereken "farz-ı ayın" ile bazı Müslümanların yapmasıyla diğerlerinden sorumluluğun düştüğü "farz-ı kifâye" arasındaki ayrımı hangi örnek doğru gösterir?',
      en: 'According to the Diyanet Catechism, which pair accurately illustrates an individual obligation (Fard al-\'Ayn) versus a communal obligation (Fard al-Kifayah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Cenaze namazı kılmak farz-ı ayın; beş vakit namaz kılmak farz-ı kifâyedir',
          en: 'Funeral prayer is Fard al-\'Ayn; the five daily prayers are Fard al-Kifayah',
        ),
        LocalizedText(
          tr: 'Beş vakit namaz kılmak farz-ı ayın; cenaze namazı kılmak farz-ı kifâyedir',
          en: 'The five daily prayers are Fard al-\'Ayn; funeral prayer is Fard al-Kifayah',
        ),
        LocalizedText(
          tr: 'Verilen selâmı almak farz-ı ayın; Ramazan orucu tutmak farz-ı kifâyedir',
          en: 'Returning greetings is Fard al-\'Ayn; fasting Ramadan is Fard al-Kifayah',
        ),
        LocalizedText(
          tr: 'Bayram namazı kılmak farz-ı ayın; gusül abdesti almak farz-ı kifâyedir',
          en: 'Eid prayer is Fard al-\'Ayn; performing Ghusl is Fard al-Kifayah',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Hiç kimse cenaze namazını kılmazsa bütün belde sorumlu olur; bir grup kılarsa diğerlerinden sorumluluk düşer.',
      en: 'If no one performs a funeral prayer the entire community bears sin, whereas a group suffices for others.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Farz-ı ayın her mükellefe şahsen gereken ibadetlerdir (beş vakit namaz, Ramazan orucu). Farz-ı kifâye ise toplum adına yeterli sayıda Müslümanın yapmasıyla yerine gelen görevlerdir (cenaze namazı, İslâmî ilimlerde ihtisas).',
        en: 'Fard al-\'Ayn binds every accountable Muslim personally (five daily prayers, Ramadan fast). Fard al-Kifayah is fulfilled for the community once sufficient Muslims perform it (funeral prayer, scholarly specialization).',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 24-25',
        en: 'Diyanet Catechism Vol. 1, pp. 24-25',
      ),
      linkedFarzId: 8,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Mükellefin fiillerine ait temel dinî hükümleri (Ef\'âl-i Mükellefîn) doğru tanımlarıyla eşleştiriniz.',
      en: 'Match the core legal classifications of human acts (Af\'al al-Mukallafin) with their accurate definitions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Farz', en: 'Fard (Obligatory)'),
          right: LocalizedText(
            tr: 'Kesin delille sabit, inkârı imanı zedeleyen emir',
            en: 'Command established by definitive proof',
          ),
        ),
        (
          left: LocalizedText(tr: 'Vacip', en: 'Wajib (Required)'),
          right: LocalizedText(
            tr: 'Zannî delille sabit olup amelî bağlayıcılığı güçlü emir',
            en: 'Practically binding duty based on probable proof',
          ),
        ),
        (
          left: LocalizedText(tr: 'Sünnet-i Müekkede', en: 'Sunnah Mu\'akkadah'),
          right: LocalizedText(
            tr: 'Hz. Peygamber\'in devamlı yaptığı, nadiren terk ettiği ibadet',
            en: 'Practice consistently performed by the Prophet (ﷺ)',
          ),
        ),
        (
          left: LocalizedText(tr: 'Mübah', en: 'Mubah (Permissible)'),
          right: LocalizedText(
            tr: 'Yapılıp yapılmaması mükellefin tercihine bırakılan fiil',
            en: 'Neutral act left to the believer\'s lawful discretion',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Hanefî usûlünde kesin ve zannî delil ayrımı Farz ile Vacip kavramlarını birbirinden ayırır.',
      en: 'Hanafi jurisprudence distinguishes definitive proof (Fard) from probable proof (Wajib).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ef\'âl-i mükellefîni doğru bilmek, bir ibadetin veya günlük davranışın dinî ağırlığını (terki namazı bozar mı, sehiv secdesi mi gerektirir, yoksa edep midir) kavramanın anahtarıdır.',
        en: 'Understanding these legal categories reveals the weight of each act—distinguishing integral obligations from required duties, prophetic traditions, and permissible choices.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 24-29',
        en: 'Diyanet Catechism Vol. 1, pp. 24-29',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîler kesin (kat\'î) delille sabit emre farz, zannî delille sabit emre vacip adını verirler.',
        en: 'Hanafis distinguish Fard (definitive proof) from Wajib (strong probable proof), such as Witr prayer.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Cumhur (Şâfiî, Mâlikî, Hanbelî) fukahâya göre Farz ve Vacip kavramları temelde eş anlamlıdır.',
        en: 'The majority of jurists (including Shafi\'is) treat Fard and Wajib as essentially synonymous.',
      ),
      linkedFarzId: 7,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî fıkıh usûlünde, harama yakın derecede olup zannî bir delille yasaklanmış çirkin fiilleri (örneğin güneş doğarken nafile namaz kılmayı) ifade eden hüküm hangisidir?',
      en: 'In Hanafi jurisprudence, which classification describes an act prohibited on the basis of probable evidence that borders on being strictly unlawful (e.g., voluntary prayer exactly at sunrise)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Tenzîhen mekruh',
          en: 'Tanzihan Makruh (Slightly Disliked)',
        ),
        LocalizedText(
          tr: 'Mendup (Müstehap)',
          en: 'Mandub (Recommended)',
        ),
        LocalizedText(
          tr: 'Tahrîmen mekruh',
          en: 'Tahriman Makruh (Prohibitively Disliked)',
        ),
        LocalizedText(
          tr: 'Ruhsat-ı şer\'iyye',
          en: 'Rukhsah (Legal Concession)',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Adı Arapça "haram kılma" kökünden gelir ve Hanefî\'de vacibin karşıtı sayılır.',
      en: 'Its name derives from the root of "prohibiting" and serves as the opposite of Wajib.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîler yasakları kesin delile dayanan "Haram", zannî delille harama yakın yasaklanan "Tahrîmen Mekruh" ve helâle yakın olup terk edilmesi evlâ olan "Tenzîhen Mekruh" şeklinde üç kademede inceler.',
        en: 'Hanafi scholars classify prohibitions into Haram (definitive proof), Tahriman Makruh (probable proof close to Haram), and Tanzihan Makruh (closer to permissible, better avoided).',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 27-28',
        en: 'Diyanet Catechism Vol. 1, pp. 27-28',
      ),
      linkedFarzId: 7,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Allah Teâlâ\'nın var olmak ve varlığını sürdürmek için hiçbir mekâna, zamana veya başka bir sebebe muhtaç olmamasını ifade eden Zâtî sıfat hangisidir?',
      en: 'Which Divine Attribute of Essence signifies that Allah Almighty exists independently without needing any place, time, or external cause?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kıdem', en: 'Qidam (Beginninglessness)'),
        LocalizedText(tr: 'Bekâ', en: 'Baqa\' (Everlastingness)'),
        LocalizedText(
          tr: 'Muhâlefetün li\'l-havâdis',
          en: 'Mukhalafatun lil-Hawadith (Dissimilarity)',
        ),
        LocalizedText(
          tr: 'Kıyâm bi-nefsihî',
          en: 'Qiyam bi-Nafsihi (Self-Subsistence)',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Fâtır Sûresi 15. âyette "Allah hiçbir şeye muhtaç değildir (Ganîdir)" hakikatiyle bağlantılıdır.',
      en: 'Connected to Allah being Al-Ghani (Absolutely Self-Sufficient) in Surah Fatir 35:15.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Allah\'ın altı Zâtî sıfatı şunlardır: Vücûd (varlığı zorunlu olmak), Kıdem (ezelî olmak), Bekâ (ebedî olmak), Vahdâniyyet (bir olmak), Muhâlefetün li\'l-havâdis (yaratılmışlara benzememek) ve Kıyâm bi-nefsihî (hiçbir şeye muhtaç olmadan zâtıyla kâim olmak).',
        en: 'The six Personal Attributes of Allah are Wujud (necessary existence), Qidam (without beginning), Baqa\' (eternal), Wahdaniyyah (Oneness), Mukhalafatun lil-Hawadith (utterly distinct from creation), and Qiyam bi-Nafsihi (Self-Subsistence).',
      ),
      sourceRef: LocalizedText(
        tr: 'İhlâs, 112/2; Fâtır, 35/15; Diyanet İlmihali Cilt 1, s. 68-71',
        en: 'Al-Ikhlas 112:2; Fatir 35:15; Diyanet Catechism Vol. 1, pp. 68-71',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_maturidi',
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Dört büyük kitabın dışında bazı peygamberlere indirilen toplam yüz sayfalık ilahî bildirileri (Suhuf) peygamberleriyle eşleştiriniz.',
      en: 'Match the prophets with the number of Divine Scrolls (Suhuf, totaling 100) revealed to each of them.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Âdem (a.s.)', en: 'Prophet Adam (a.s.)'),
          right: LocalizedText(tr: '10 Suhuf', en: '10 Scrolls'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Şît (a.s.)', en: 'Prophet Shith (a.s.)'),
          right: LocalizedText(tr: '50 Suhuf', en: '50 Scrolls'),
        ),
        (
          left: LocalizedText(tr: 'Hz. İdrîs (a.s.)', en: 'Prophet Idris (a.s.)'),
          right: LocalizedText(tr: '30 Suhuf', en: '30 Scrolls'),
        ),
        (
          left: LocalizedText(
            tr: 'Hz. İbrâhim (a.s.)',
            en: 'Prophet Ibrahim (a.s.)',
          ),
          right: LocalizedText(tr: '10 Suhuf', en: '10 Scrolls'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'En fazla suhuf (elli sayfa) Hz. Şît\'e, otuz sayfa ise Hz. İdrîs\'e verilmiştir.',
      en: 'The largest collection (50 scrolls) was given to Shith, and 30 scrolls to Idris.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Vahiy tarihi Hz. Âdem\'le başlar. Kur\'ân\'da Hz. İbrâhim ve Hz. Mûsâ\'nın sahifelerine özellikle atıf yapılır (A\'lâ 87/19); bütün ilahî kitap ve suhufların aslına inanmak imanın şartlarındandır.',
        en: 'Revelation begins with Prophet Adam. The Qur\'an explicitly mentions the Scrolls of Ibrahim and Musa (87:19); affirming all original divine revelations is part of Iman.',
      ),
      sourceRef: LocalizedText(
        tr: 'A\'lâ Sûresi, 87/18-19; Diyanet İlmihali Cilt 1, s. 99-100',
        en: 'Surah Al-A\'la, 87:18-19; Diyanet Catechism Vol. 1, pp. 99-100',
      ),
      linkedFarzId: 3,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İnfitâr Sûresi 10-12. âyetlerde bildirilen ve her insanın iyilik ve kötülüklerini yazmakla görevli meleklere ne ad verilir?',
      en: 'What are the honorable angels mentioned in Surah Al-Infitar (82:10-12) who record every person\'s good and evil deeds?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kirâmen Kâtibîn (Yazıcı Melekler)',
          en: 'Kiraman Katibin (Noble Recorders)',
        ),
        LocalizedText(
          tr: 'Münker ve Nekir (Kabir Melekleri)',
          en: 'Munkar and Nakir (Angels of the Grave)',
        ),
        LocalizedText(
          tr: 'Hamele-i Arş (Arş\'ı Taşıyanlar)',
          en: 'Hamalat al-\'Arsh (Bearers of the Throne)',
        ),
        LocalizedText(
          tr: 'Hâzin (Cennet ve Cehennem Muhafızları)',
          en: 'Khazin (Keepers of Paradise and Hell)',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Anlamı "Değerli yazıcılar" demek olup sağdaki hayırları, soldaki ise şerleri kaydeder.',
      en: 'Literally meaning "Noble Scribes," positioned to record good and bad deeds.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Melekler nurdan yaratılmış, yemeyen, içmeyen ve Allah\'a asla isyan etmeyen şerefli varlıklardır. Kirâmen Kâtibîn meleklerine iman, mümin kulda her an gözetilme ve sorumluluk bilinci (murâkabe) uyandırır.',
        en: 'Angels are created from light, free of sin, and wholly obedient to Allah. Belief in the Kiraman Katibin cultivates mindfulness and moral accountability in daily life.',
      ),
      sourceRef: LocalizedText(
        tr: 'İnfitâr, 82/10-12; Kâf, 50/17-18; Diyanet İlmihali Cilt 1, s. 95-97',
        en: 'Al-Infitar 82:10-12; Qaf 50:17-18; Diyanet Catechism Vol. 1, pp. 95-97',
      ),
      linkedFarzId: 2,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Henüz peygamberlik görevi verilmeden önce ileride peygamber olacak zâtın elinde Allah\'ın izniyle meydana gelen olağanüstü hâllere (örneğin Hz. Îsâ\'nın beşikte iken konuşmasına) ne ad verilir?',
      en: 'What Islamic term denotes an extraordinary sign occurring through a future prophet prior to receiving prophethood (such as Prophet \'Isa speaking in the cradle)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kerâmet', en: 'Karamah (Saintly Wonder)'),
        LocalizedText(tr: 'İstidrâc', en: 'Istidraj (Gradual Delusion)'),
        LocalizedText(tr: 'İrhâs', en: 'Irhas (Prophetic Foresign)'),
        LocalizedText(tr: 'Meûnet', en: 'Ma\'unah (Divine Aid)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Peygamberlik sonrasında "Mucize", peygamberlik öncesinde ise bu terim kullanılır.',
      en: 'After prophethood it is called Mu\'jizah; beforehand, this specific term applies.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mucize peygamberlik iddiasıyla beraber ortaya çıkar; İrhâs peygamberliği müjdeleyen ön işarettir; Kerâmet velî kullarda, Meûnet ise darda kalan müminlerde görülür.',
        en: 'Mu\'jizah accompanies a prophetic mission; Irhas precedes it as preparation; Karamah honors righteous saints; Ma\'unah aids sincere believers in distress.',
      ),
      sourceRef: LocalizedText(
        tr: 'Meryem Sûresi, 19/29-33; Diyanet İlmihali Cilt 1, s. 109-112',
        en: 'Surah Maryam, 19:29-33; Diyanet Catechism Vol. 1, pp. 109-112',
      ),
      linkedFarzId: 4,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Âhiret hayatının temel merhalelerini tanımlarıyla doğru şekilde eşleştiriniz.',
      en: 'Match the principal stages of the Hereafter with their accurate meanings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Ba\'s', en: 'Ba\'th (Resurrection)'),
          right: LocalizedText(
            tr: 'İkinci Sûr ile bütün insanların yeniden diriltilmesi',
            en: 'Bodily resurrection at the second Trumpet blast',
          ),
        ),
        (
          left: LocalizedText(tr: 'Haşir', en: 'Hashr (Gathering)'),
          right: LocalizedText(
            tr: 'Diriltilenlerin hesap için Mahşer\'de toplanması',
            en: 'Assembling of all souls for judgment',
          ),
        ),
        (
          left: LocalizedText(tr: 'Mîzan', en: 'Mizan (The Scale)'),
          right: LocalizedText(
            tr: 'Kulların amellerinin tartılacağı ilâhî adalet terazisi',
            en: 'Divine scale weighing all human deeds',
          ),
        ),
        (
          left: LocalizedText(tr: 'Sırat', en: 'Sirat (The Bridge)'),
          right: LocalizedText(
            tr: 'Cehennem üzerine kurulup herkesin geçeceği köprü',
            en: 'Bridge spanning Hellfire crossed by all humanity',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Ba\'s diriliş, Haşir toplanma, Mîzan ise amellerin ölçüleceği terazidir.',
      en: 'Ba\'th is rising from graves, Hashr is assembly, and Mizan is the scale of justice.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Âhiret safhalarına iman, dünyada işlenen her iyiliğin ve haksızlığın mutlaka adil bir karşılığı bulunacağını öğretir.',
        en: 'Belief in the stages of the Hereafter instills certainty that every good deed and injustice will meet absolute divine justice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Enbiyâ, 21/47; Meryem, 19/71; Diyanet İlmihali Cilt 1, s. 119-125',
        en: 'Al-Anbiya 21:47; Maryam 19:71; Diyanet Catechism Vol. 1, pp. 119-125',
      ),
      linkedFarzId: 5,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Mâtürîdî âlimleri ve Diyanet İlmihali\'ne göre, imanın altıncı şartını oluşturan "Kader" ile "Kazâ" arasındaki kavram farkı hangisinde doğru ifade edilmiştir?',
      en: 'According to Maturidi theology and the Diyanet Catechism, which statement accurately distinguishes Destiny (Qadar) from Decree (Qada)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kader yalnız geçmiş olayların tarihi, Kazâ ise yalnız kıyametin saatidir',
          en: 'Qadar refers to past history alone, while Qada means only the Hour of Resurrection',
        ),
        LocalizedText(
          tr: 'Kader Allah\'ın her şeyi ezelde bilip ölçüsünü takdir etmesi; Kazâ ise vakti gelince o şeyi yaratmasıdır',
          en: 'Qadar is Allah\'s eternal foreknowledge and measured plan; Qada is bringing it into existence at its appointed time',
        ),
        LocalizedText(
          tr: 'Kader yalnız hayırlı işler için geçerlidir; Kazâ ise yalnız kulun ibadeti vaktinden sonra yapmasıdır',
          en: 'Qadar pertains only to good events, whereas Qada strictly denotes making up missed prayers',
        ),
        LocalizedText(
          tr: 'Kader insanın kendi tercihlerini zorla belirler; Kazâ ise kulun iradesinden tamamen bağımsız tesadüftür',
          en: 'Qadar coerces human choices, whereas Qada represents random events outside divine knowledge',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Kader "ölçü ve planlama", Kazâ ise takdir edilenin "hükmünün icra edilip yaratılması"dır.',
      en: 'Qadar carries the meaning of measure and proportion, while Qada means execution and realization.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kader Allah\'ın ilim ve irade sıfatıyla ezelî planlamasına; Kazâ ise Tekvîn sıfatıyla zamanı geldiğinde varlık sahasına çıkarmasına işaret eder.',
        en: 'Qadar relates to Allah\'s eternal Knowledge and Will, whereas Qada relates to His creative power manifesting those realities in time.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kamer Sûresi, 54/49; Diyanet İlmihali Cilt 1, s. 132-135',
        en: 'Surah Al-Qamar, 54:49; Diyanet Catechism Vol. 1, pp. 132-135',
      ),
      linkedFarzId: 6,
      linkedBookId: 'book_tafseer_maturidi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İslâm inancına göre gerçek tevekkül, hiçbir maddî sebep ve tedbire başvurmadan sonucu yalnızca Allah\'tan beklemektir.',
      en: 'According to Islamic teachings, genuine trust in Allah (tawakkul) means taking no practical precautions or effort and merely waiting for the outcome.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Sünen-i Tirmizî\'de "Deveni bağla mı, salıverip tevekkül mü edeyim?" diye soran sahâbîye Peygamberimizin cevabını hatırlayınız.',
      en: 'Recall the Prophetic counsel to the Bedouin asking whether to tie his camel or leave it untied and trust Allah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sebeplere sarılmadan beklemek tevekkül değil "tevakül"dür (tembellik). Sahih tevekkül, kulun kendi üzerine düşen tüm çalışmayı ve tedbiri yerine getirdikten sonra kalbini Allah\'a dayamasıdır.',
        en: 'Neglecting effort is not tawakkul but laziness. Authentic tawakkul pairs conscientious diligence and precaution with calm reliance on Allah for the outcome.',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân, 3/159; Sünen-i Tirmizî, Kıyâmet 60; Diyanet İlmihali Cilt 1, s. 142-145',
        en: 'Ali \'Imran 3:159; Tirmidhi, Qiyamah 60; Diyanet Catechism Vol. 1, pp. 142-145',
      ),
      linkedFarzId: 6,
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İslâm fıkhına göre bir kimsenin dinî emir ve yasaklardan sorumlu (mükellef) sayılabilmesi için kendisinde bulunması gereken iki temel şart hangisidir?',
      en: 'In Islamic jurisprudence, what are the two foundational prerequisites for a person to be morally and legally accountable (mukallaf) for worship?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Zekât nisabına ulaşmak ve evlenmiş olmak',
          en: 'Reaching the Zakat threshold and being married',
        ),
        LocalizedText(
          tr: 'Hac ibadetini yapmış olmak ve kırk yaşına girmek',
          en: 'Completing Hajj pilgrimage and reaching age forty',
        ),
        LocalizedText(
          tr: 'İslâmî ilimlerde icazet almak ve mukim bulunmak',
          en: 'Holding scholarly certification and being a resident',
        ),
        LocalizedText(
          tr: 'Akıl sahibi olmak ve ergenlik (bulûğ) çağına ulaşmak',
          en: 'Possessing sound intellect and reaching puberty (bulugh)',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '"Üç kimseden kalem kaldırılmıştır: Uyanıncaya kadar uyuyandan, bulûğa erinceye kadar çocuktan ve..." hadisi temeldir.',
      en: 'Grounded in the hadith that accountability is lifted from the sleeping, the child until puberty, and one lacking sanity.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm dininde sorumluluk bilgi ve idrake dayanır; akıl ve bulûğ şartları oluşmadıkça namaz ve oruç farz olmaz. Çocuklar yedi yaşından itibaren alıştırılır, bulûğ ile yükümlülük başlar.',
        en: 'Islamic accountability rests upon comprehension and maturity: without sound intellect and puberty, ritual duties are not binding, though children are gently encouraged beforehand.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Hudûd 17; Diyanet İlmihali Cilt 1, s. 22-23',
        en: 'Abu Dawud, Hudud 17; Diyanet Catechism Vol. 1, pp. 22-23',
      ),
      linkedFarzId: 7,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Necâsetten tahâret kapsamında, kan, şarap ve idrar gibi bizzat dinen pis sayılan maddelerin Hanefî fıkhındaki ağırlık derecesine göre sınıflandırılması nasıldır?',
      en: 'Under purification from physical impurity (Najasah), how does Hanafi fiqh classify impurities by severity regarding excusable trace amounts?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Necâset-i Galîza (kaba) ve Necâset-i Hafîfe (hafif) olarak ikiye ayrılır',
          en: 'Divided into Najasah Ghalizah (heavy) and Najasah Khafifah (light)',
        ),
        LocalizedText(
          tr: 'Yalnızca necâset-i bâtıniyye ve necâset-i ilmiyye olarak ayrılır',
          en: 'Divided only into spiritual impurity and intellectual impurity',
        ),
        LocalizedText(
          tr: 'Miktarı ne kadar küçük olursa olsun iğne ucu kadar leke daima namazı bozar',
          en: 'Even a microscopic pinpoint speck invariably invalidates Salah',
        ),
        LocalizedText(
          tr: 'Kuru oldukları sürece elbise üzerindeki hiçbir maddî kirlilik namaza engel olmaz',
          en: 'No physical impurity on clothes ever impedes prayer once dried',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hanefîlerde dirhem miktarı (avucun çukuru) kaba pislikte, uzvun dörtte biri ise hafif pislikte ölçü alınır.',
      en: 'Hanafis specify the palm-hollow size (dirham) for heavy impurity and one-fourth of a garment limb for light impurity.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mümin necâsetin en ufak eserinden dahi kaçınır; bununla birlikte Hanefî mezhebi kazaen bulaşan çok küçük eserlerde kullara kolaylık olmak üzere dirhem ve çeyrek uzuv sınırını belirlemiştir.',
        en: 'Believers strive to avoid all physical impurity, while Hanafi fiqh specifies careful tolerance thresholds for unintentional trace amounts so worship never becomes unbearable.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müddessir, 74/4; Diyanet İlmihali Cilt 1, s. 221-225',
        en: 'Al-Muddaththir 74:4; Diyanet Catechism Vol. 1, pp. 221-225',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de katı necâset-i galîzada ~3 gram (sıvıda el ayası genişliği), necâset-i hafîfede bulaştığı uzvun/parçanın dörtte birinden azı affedilmiştir; fazlası yıkanır.',
        en: 'In Hanafi fiqh, under one dirham of heavy impurity or under one-fourth of a surface in light impurity is excused.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde gözle görülen veya affedilmeyen her türlü necâset miktarına bakılmaksızın yıkanır (yalnız sokak çamuru vb. zorunlu serpintiler istisnadır).',
        en: 'In Shafi\'i fiqh, unexcused impurities must be washed regardless of quantity (aside from unavoidable street splashes).',
      ),
      linkedFarzId: 22,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre abdestte başın en az dörtte birini meshetmek farz iken; başın tamamını kaplayacak şekilde (isti\'ab ile) meshetmek, kulakları ve boynu meshetmek ile azaları üçer kez yıkamak hangi hükme girer?',
      en: 'While wiping at least one-fourth of the head is fard in Hanafi Wudu, what is the legal status of wiping the entire head, wiping the ears/neck, and washing limbs three times?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Farz-ı kifâye', en: 'Communal obligation (Fard al-Kifayah)'),
        LocalizedText(tr: 'Namaz şartı', en: 'External condition of prayer'),
        LocalizedText(tr: 'Abdestin sünnetleri', en: 'Prophetic Sunnahs of Wudu'),
        LocalizedText(tr: 'Tenzîhen mekruh', en: 'Slightly disliked (Tanzihan Makruh)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Peygamber Efendimizin (s.a.v.) abdest alırken düzenli olarak uygulayıp ümmetine öğrettiği faziletli davranışlardır.',
      en: 'Consistent practices taught by the Prophet (ﷺ) perfecting the four obligatory acts of Wudu.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Besmele çekmek, elleri bileklere kadar yıkamak, ağız ve burna üçer kez su vermek, uzuvları üçer defa yıkamak ve başın tamamını kaplayarak kulaklarla beraber meshetmek abdesti kemâle erdiren sünnetlerdendir.',
        en: 'Starting with Bismillah, rinsing mouth and nostrils, washing limbs thrice, and wiping the entire head and ears fulfill the Sunnah perfection of Wudu.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Tahâret 50-54; Diyanet İlmihali Cilt 1, s. 195-197',
        en: 'Abu Dawud, Taharah 50-54; Diyanet Catechism Vol. 1, pp. 195-197',
      ),
      linkedFarzId: 14,
      linkedZikirKey: 'Besmele',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Namaz dışında ağlamak, tebessüm etmek veya saç ve tırnak kesmek Hanefî mezhebine göre abdesti bozar.',
      en: 'Crying, smiling, or clipping hair and nails outside of Salah breaks Wudu according to the Hanafi school.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Yalnızca namaz içindeyken komşuların işiteceği sesle kahkaha atmak Hanefî\'de abdesti ve namazı birlikte bozar.',
      en: 'Only audible laughter *during* prayer invalidates both Salah and Wudu in Hanafi fiqh.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tırnak veya saç kesmek, yara kabuğu düşmesi (kan çıkmadıkça), ağlamak ve namaz dışında gülmek abdesti bozmaz. Kesilen saç veya tırnağın bulunduğu yeri yıkamak temizlik açısından yeterlidir.',
        en: 'Cutting nails or hair, weeping, or laughing outside prayer does not nullify Wudu; only normal nullifiers (like bodily discharges, bleeding in Hanafi fiqh, deep sleep, or audible laughter inside prayer) break it.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 200-203',
        en: 'Diyanet Catechism Vol. 1, pp. 200-203',
      ),
      linkedFarzId: 21,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Gusül abdesti alırken aşağıdakilerden hangisinin yapılması Hanefî mezhebine göre farz değil sünnettir?',
      en: 'When performing Ghusl, which of the following practices is Sunnah rather than fard in the Hanafi school?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Ağzın içini iyice çalkalayarak dolu dolu su vermek (mazmaza)',
          en: 'Rinsing the entire inside of the mouth thoroughly (madmadah)',
        ),
        LocalizedText(
          tr: 'Besmele ve niyetle başlayıp önce elleri yıkamak ve namaz abdesti almak',
          en: 'Beginning with Bismillah and intention, washing hands first, and making Wudu',
        ),
        LocalizedText(
          tr: 'Burun yumuşağına kadar su çekip temizlemek (istinşak)',
          en: 'Drawing water into the nostrils up to the soft cartilage (istinshaq)',
        ),
        LocalizedText(
          tr: 'Bedenin her noktasına kuru yer kalmayacak şekilde su ulaştırmak',
          en: 'Ensuring water reaches every exterior spot of the body without leaving dry areas',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Gusle başlarken sırasıyla besmele, niyet, el ve avret temizliği, ardından namaz abdesti almak Sünnet-i Seniyyedendir.',
      en: 'Starting with Bismillah, intention, private hygiene, and a preliminary Wudu follows the Prophetic sequence.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Buhârî ve Müslim\'de anlatıldığı üzere Hz. Peygamber (s.a.v.) guslederken önce ellerini yıkar, sonra namaz abdesti alır, ardından üç kez başına ve bütün vücuduna su dökerdi.',
        en: 'As narrated in Bukhari and Muslim, the Prophet (ﷺ) began Ghusl by washing his hands and performing Wudu before pouring water thoroughly over his head and entire body.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Gusül 1; Müslim, Hayız 35; Diyanet İlmihali Cilt 1, s. 206-207',
        en: 'Bukhari, Ghusl 1; Muslim, Hayd 35; Diyanet Catechism Vol. 1, pp. 206-207',
      ),
      linkedFarzId: 18,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Beş vakit namaz ve Cuma namazı için okunan ezan ve kametin fıkhî hükmü ve kapsamı hakkında hangisi doğrudur?',
      en: 'Which statement accurately describes the juristic ruling and scope of the Adhan and Iqamah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Beş vakit farzın yanında teravih, vitir ve bayram namazları için de kamet getirilir',
          en: 'Iqamah is called for Tarawih, Witr, and Eid prayers just as for the five daily fard prayers',
        ),
        LocalizedText(
          tr: 'Kamet yalnız cemaatle kılınan namazlara mahsustur; tek başına kılan erkeğin okuması mekruhtur',
          en: 'Iqamah belongs solely to congregations and is disliked for a man praying alone',
        ),
        LocalizedText(
          tr: 'Kaza namazları kılınırken hiçbir vakit ezan veya kamet okunması caiz görülmez',
          en: 'Neither Adhan nor Iqamah may ever be recited when performing missed prayers',
        ),
        LocalizedText(
          tr: 'Erkekler için beş vakit farz, Cuma ve kaza namazlarında sünnet-i müekkededir; kadınlar muaftır',
          en: 'Both are emphasized Sunnah for men in the five daily, Friday, and make-up fard prayers; women are exempt',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Ezan İslâm\'ın şeâirindendir (temel sembollerindendir); nafile, vitir ve cenaze namazlarında ezan ve kamet okunmaz.',
      en: 'Adhan is an emblem of Islam; neither Adhan nor Iqamah is called for Sunnah, Eid, Witr, or funeral prayers.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Vakit girdiğinde erkeklerin beş vakit farz ve Cuma için ezan ve kamet okuması kuvvetli sünnettir; cemaatle kılınan kaza namazlarında da okunur. Tek başına kılan erkek için kamet getirmek sünnet, ezanı da yavaşça okumak faziletlidir.',
        en: 'Calling Adhan and Iqamah is an emphasized Sunnah for men for daily obligatory, Jumu\'ah, and make-up fard prayers; voluntary, Witr, and Eid prayers have neither.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Ezân 1-6; Diyanet İlmihali Cilt 1, s. 253-256',
        en: 'Bukhari, Adhan 1-6; Diyanet Catechism Vol. 1, pp. 253-256',
      ),
      linkedFarzId: 25,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['mirac'],
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre bir günde kılınan beş vakit namazın yalnız farz rekâtları toplamı ile sünnetler ve vitir dâhil toplam rekât sayısı kaçtır?',
      en: 'According to the Hanafi school, what is the daily total of obligatory (fard) rak\'ahs across the five prayers and the overall total including Sunnahs and Witr?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: '15 farz rekât; sünnetler ve vitir dâhil toplam 36 rekât',
          en: '15 fard rak\'ahs; 36 total including Sunnahs and Witr',
        ),
        LocalizedText(
          tr: '19 farz rekât; sünnetler ve vitir dâhil toplam 42 rekât',
          en: '19 fard rak\'ahs; 42 total including Sunnahs and Witr',
        ),
        LocalizedText(
          tr: '17 farz rekât; sünnetler ve vitir dâhil toplam 40 rekât',
          en: '17 fard rak\'ahs; 40 total including Sunnahs and Witr',
        ),
        LocalizedText(
          tr: '20 farz rekât; sünnetler ve vitir dâhil toplam 44 rekât',
          en: '20 fard rak\'ahs; 44 total including Sunnahs and Witr',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Sabah (2+2), Öğle (4+4+2), İkindi (4+4), Akşam (3+2) ve Yatsı (4+4+2+3) olarak hesaplayınız.',
      en: 'Sum Fajr (2+2), Dhuhr (4+4+2), Asr (4+4), Maghrib (3+2), and Isha (4+4+2+3).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Farzlar: Sabah 2, Öğle 4, İkindi 4, Akşam 3, Yatsı 4 = 17 rekât. Revâtib sünnetler (20 rekât) ve 3 rekât Vacip Vitir namazıyla günlük toplam 40 rekâta ulaşır.',
        en: 'Obligatory rak\'ahs: Fajr 2 + Dhuhr 4 + Asr 4 + Maghrib 3 + Isha 4 = 17. Adding 20 Sunnah rak\'ahs and 3 wajib Witr rak\'ahs brings the daily total to 40.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 270',
        en: 'Diyanet Catechism Vol. 1, p. 270',
      ),
      linkedFarzId: 8,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namazın rükünlerinde ve oturuşlarında okunan başlıca dua ve tesbihleri doğru yerleriyle eşleştiriniz.',
      en: 'Match the principal prayers and glorifications recited in Salah with their proper positions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'İftitah Tekbiri Sonrası', en: 'After Opening Takbir'),
          right: LocalizedText(
            tr: 'Sübhâneke duası okunur',
            en: 'Subhanaka (opening praise) is recited',
          ),
        ),
        (
          left: LocalizedText(tr: 'Rükû Hâlinde', en: 'During Bowing (Ruku\')'),
          right: LocalizedText(
            tr: 'Sübhâne Rabbiye\'l-Azîm denir',
            en: 'Subhana Rabbiyal-\'Azim is said',
          ),
        ),
        (
          left: LocalizedText(tr: 'Secde Hâlinde', en: 'During Prostration (Sujud)'),
          right: LocalizedText(
            tr: 'Sübhâne Rabbiye\'l-A\'lâ denir',
            en: 'Subhana Rabbiyal-A\'la is said',
          ),
        ),
        (
          left: LocalizedText(tr: 'Oturuşlarda (Ka\'de)', en: 'In Sitting (Qa\'dah)'),
          right: LocalizedText(
            tr: 'Ettehiyyâtü (Teşehhüd) okunur',
            en: 'At-Tahiyyat (Tashahhud) is recited',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Rükûda Yüce (Azîm), secdede En Yüce (A\'lâ) sıfatıyla Rabbimiz tesbih edilir.',
      en: 'Allah is glorified as Al-\'Azim in Ruku\' and as Al-A\'la in Sujud.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Namazın her hareketi zikirle bütünleşir. Rükû ve secdede tesbihlerin kalp huzuruyla en az üçer defa söylenmesi Sünnet-i Seniyyedendir.',
        en: 'Every posture in prayer pairs bodily humility with remembrance; repeating the glorifications thrice with serenity fulfills the Prophetic Sunnah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Salât 262; Ebû Dâvûd, Salât 148; Diyanet İlmihali Cilt 1, s. 262-267',
        en: 'Muslim, Salah 262; Abu Dawud, Salah 148; Diyanet Catechism Vol. 1, pp. 262-267',
      ),
      linkedFarzId: 31,
      linkedZikirKey: 'Subhanallah',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Namazın geçerli olabilmesi için hazırlık şartlarının namaz sonuna dek devam etmesi esastır. Buna göre aşağıdakilerden hangisi namazı bozan hâllerden biridir?',
      en: 'Prerequisite conditions must remain intact throughout prayer. Which of the following situations invalidates Salah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Namaz içinde bilerek veya unutarak konuşmak ya da bir rükün süresi avret yerinin açık kalması',
          en: 'Speaking during prayer intentionally or accidentally, or an uncovered \'awrah for the duration of a pillar',
        ),
        LocalizedText(
          tr: 'Namaz sırasında istem dışı gelen hafif öksürüğü veya esnemeyi bastırmaya çalışmak',
          en: 'Suppressing an involuntary slight cough or yawn while standing in prayer',
        ),
        LocalizedText(
          tr: 'İlk oturuşta sehven Ettehiyyâtü\'den sonra Salli-Bârik duasına geçip üçüncü rekâta kalkmak',
          en: 'Inadvertently starting Salawat after At-Tahiyyat in the first sitting before rising',
        ),
        LocalizedText(
          tr: 'İçinden geçtiği hâlde dil ile ses çıkarmadan yalnızca kalben hatıra gelen düşünceler',
          en: 'Passing involuntary mental thoughts occurring silently without moving the tongue',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Dünya kelâmı konuşmak, yemek-içmek ve namazın şartlarından biri olan Setr-i Avret\'in bir rükün kadar bozulması namazı geçersiz kılar.',
      en: 'Worldly speech, eating/drinking, and prolonged violation of covering \'awrah break the prayer.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Setr-i avret (erkeklerde göbek altından diz kapağı altına kadar; kadınlarda yüz, eller ve Hanefî\'de ayaklar hariç tüm beden) yalnız başlangıçta değil tüm namaz boyunca korunmalıdır. İlk oturuşta sehven Salli-Bârik okumak ise namazı bozmaz, yalnız sehiv secdesi gerektirir.',
        en: 'Covering the \'awrah (navel to below the knees for men; entire body except face, hands, and in Hanafi fiqh feet for women) must hold throughout Salah. Unintentionally starting Salawat in the first sitting does not break prayer—only Sujud as-Sahw.',
      ),
      sourceRef: LocalizedText(
        tr: 'A\'râf, 7/31; Diyanet İlmihali Cilt 1, s. 225-228, 279-284',
        en: 'Al-A\'raf 7:31; Diyanet Catechism Vol. 1, pp. 225-228, 279-284',
      ),
      linkedFarzId: 23,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_20',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Ramazan orucunda sahura kalkmak ve güneşin battığı kesinleştiğinde vakit geçirmeden iftar etmek (ta\'cîl-i fıtr) fıkıhta ne hüküm taşır?',
      en: 'In Islamic law, what is the ruling on waking for the pre-dawn meal (Suhoor) and hastening to break the fast once sunset is certain?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Orucun sıhhat ve geçerliliği için her ikisi de farz şartlardandır',
          en: 'Both are obligatory prerequisites without which fasting is invalid',
        ),
        LocalizedText(
          tr: 'Yalnızca yolcu ve hastalara tanınmış geçici bir ruhsat hükmündedir',
          en: 'Merely temporary concessions granted exclusively to travelers and the ill',
        ),
        LocalizedText(
          tr: 'Sadece nafile oruçlara mahsus olup Ramazan\'da uygulanması mekruhtur',
          en: 'Restricted to voluntary fasts and disliked during Ramadan',
        ),
        LocalizedText(
          tr: 'Bereket vesilesi kuvvetli birer sünnet (müstehap) ibadet âdâbıdır',
          en: 'Both are blessed and strongly recommended Prophetic Sunnah practices',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '"Sahur yiyiniz, çünkü sahurda bereket vardır" ve "İftar etmekte acele ettikçe hayır üzeredirler" hadislerini hatırlayınız.',
      en: 'Recall: "Take Suhoor, for indeed in Suhoor there is blessing" (Bukhari).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahur müminlere gün boyu ibadet kuvveti ve seher vakti dua/istiğfar fırsatı kazandırır. Güneş battıktan sonra ise vakti geciktirmeden iftar açmak sünnete uygun olan güzel edeptir.',
        en: 'Suhoor grants physical endurance and pre-dawn spiritual intimacy, while hastening Iftar once sunset is established honors Prophetic Sunnah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Savm 20, 45; Müslim, Sıyâm 45, 48; Diyanet İlmihali Cilt 1, s. 411-412',
        en: 'Bukhari, Sawm 20, 45; Muslim, Siyam 45, 48; Diyanet Catechism Vol. 1, pp. 411-412',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_21',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Hastalık veya yolculuk gibi meşru bir mazeretten dolayı o gün Ramazan orucunu tutamayan bir Müslümanın akşamında Teravih namazını kılması caiz değildir.',
      en: 'A Muslim excused from fasting during a day of Ramadan due to illness or travel is prohibited from praying Tarawih that night.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Teravih namazının sebebi oruç değil, Ramazan ayının geceleridir.',
      en: 'Tarawih is a Sunnah of the nights of Ramadan itself, independent of whether one was excused from fasting that day.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Teravih namazı Ramazan vaktinin sünnet-i müekkedesidir. Yolculuk veya hastalık gibi şer\'î mazeretle gündüz oruç tutamayan kimse gece ibadete güç yetirebiliyorsa teravih namazını kılabilir.',
        en: 'Tarawih is an emphasized Sunnah tied to the month of Ramadan; those validly excused from fasting may still pray Tarawih if physically able.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Terâvîh 1; Diyanet İlmihali Cilt 1, s. 299',
        en: 'Bukhari, Tarawih 1; Diyanet Catechism Vol. 1, p. 299',
      ),
      linkedFarzId: 10,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_22',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Bir Müslümana malının zekâtını vermenin farz olması için o malda bulunması gereken temel vasıf ve süre şartı nedir?',
      en: 'What core property conditions and duration are required for Zakat to become obligatory upon a Muslim\'s savings or trade wealth?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Yalnızca kişinin oturduğu ev ve kullandığı bineğin değerinden hesaplanması',
          en: 'Calculated directly from the owner\'s primary residence and personal vehicle',
        ),
        LocalizedText(
          tr: 'Borçlardan ve aslî ihtiyaçlardan fazla nisap miktarı artıcı (nâmî) malın üzerinden 1 kamerî yıl geçmesi',
          en: 'Productive wealth above basic needs and debts reaching the nisab threshold and held for one lunar year',
        ),
        LocalizedText(
          tr: 'Nisap miktarına bakılmaksızın eline geçen her maaşın aynı gün kırkta birinin verilmesi',
          en: 'Giving 2.5% immediately on the day of any income regardless of threshold or debts',
        ),
        LocalizedText(
          tr: 'Sadece ticaret şirketlerine mahsus olup bireysel altın birikimlerinde farz olmaması',
          en: 'Applicable only to commercial enterprises, never personal gold savings',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Mesken, ev eşyası, giyim ve meslek aletleri "hâvâic-i asliyye" (aslî ihtiyaç) sayıldığından zekâta tâbi değildir.',
      en: 'Primary housing, household essentials, and tools of trade are exempt basic needs (hawa\'ij asliyyah).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Zekât sorumluluğu akıl-bulûğ ve Müslüman olmanın yanı sıra aslî ihtiyaçlar ve borçlar düşüldükten sonra nisap miktarı (80,18 gr altın veya karşılığı) artıcı mala tam mâlik olup bir kamerî yıl (havelânü\'l-havl) elde bulundurmakla tahakkuk eder.',
        en: 'Zakat becomes binding when productive wealth exceeding debts and basic necessities meets the nisab threshold (~80.18g gold) and completes one lunar year (hawl).',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/219; Ebû Dâvûd, Zekât 5; Diyanet İlmihali Cilt 1, s. 429-431',
        en: 'Al-Baqarah 2:219; Abu Dawud, Zakat 5; Diyanet Catechism Vol. 1, pp. 429-431',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_23',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.comparative,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Hac ile Umre ibadetleri arasındaki en belirgin fıkhî fark hangi seçenekte doğru açıklanmıştır?',
      en: 'Which option accurately explains the primary juristic difference between Hajj and Umrah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hacda Kâbe tavafı yapılmaz; Umre\'de ise yalnız Arafat vakfesi yapılır',
          en: 'Hajj omits Tawaf around the Ka\'bah, whereas Umrah consists solely of standing at Arafat',
        ),
        LocalizedText(
          tr: 'Hac da Umre de yalnızca Zilhicce ayının ilk on gününde edâ edilebilir',
          en: 'Both Hajj and Umrah can only be performed during the first ten days of Dhul-Hijjah',
        ),
        LocalizedText(
          tr: 'Hac belirli vakitte Arafat vakfesiyle farzdır; Umre\'de vakit sınırı, Arafat/Müzdelife vakfesi ve taşlama yoktur',
          en: 'Hajj is fard at set months with Arafat standing; Umrah has no fixed season, no Arafat/Muzdalifah standing, and no stoning',
        ),
        LocalizedText(
          tr: 'Umre yalnız kadınlara mahsustur; erkeklerin umre yerine ikinci kez hac yapması gerekir',
          en: 'Umrah is prescribed only for women, while men perform a second Hajj instead',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Umre ihram, Kâbe tavafı, Safâ-Merve sa\'yi ve tıraş ile Zilhicce\'nin teşrik günleri dışında yıl boyu yapılabilir.',
      en: 'Umrah consists of Ihram, Tawaf, Sa\'y, and shaving/trimming, performed throughout the year (outside Eid/Arafat days).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hac İslâm\'ın beş şartından biri olup Zilhicce ayında Arafat, Müzdelife ve Mina menâsikiyle edâ edilir. Umre ise ihram, tavaf, sa\'y ve tıraştan ibaret olup Haccın diğer menâsikini içermez.',
        en: 'Hajj is one of the Five Pillars anchored in Dhul-Hijjah and Arafat; Umrah comprises Ihram, Tawaf, Sa\'y, and hair trimming without Arafat, Muzdalifah, or Mina rites.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/196-197; Diyanet İlmihali Cilt 1, s. 512, 549-550',
        en: 'Al-Baqarah 2:196-197; Diyanet Catechism Vol. 1, pp. 512, 549-550',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî ve Mâlikî mezheplerine göre gücü yetenler için Umre ömürde bir kez müekked sünnettir.',
        en: 'In Hanafi and Maliki fiqh, performing Umrah once in a lifetime is an emphasized Sunnah.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî ve Hanbelî mezheplerine göre gücü yeten mükellef için Umre de tıpkı Hac gibi ömürde bir kez farzdır.',
        en: 'In Shafi\'i and Hanbali fiqh, performing Umrah once in a lifetime is obligatory (fard) for those able.',
      ),
      linkedFarzId: 11,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_24',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Bayram namazı kılınan şehir ve yerleşim yerlerinde Udhiyye (Kurban Bayramı) kurbanının kesim vakti ne zaman başlar?',
      en: 'In towns and cities where the Eid prayer is held, when does the valid time for slaughtering the Udhiyyah sacrifice begin?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bayramın birinci günü bayram namazı kılındıktan sonra başlar; namazdan önce kesilen kurban sayılmaz',
          en: 'After the Eid prayer on the first day; an animal slaughtered prior to the prayer does not count as Udhiyyah',
        ),
        LocalizedText(
          tr: 'Arefe günü akşam ezanı okunur okunmaz gece vaktinde kesilebilir',
          en: 'Immediately after the Maghrib call on the evening of \'Arafah',
        ),
        LocalizedText(
          tr: 'Bayramın birinci günü imsak vaktinden hemen sonra bayram namazı beklenmeden kesilir',
          en: 'Right after true dawn (Fajr) on the first morning before Eid prayer',
        ),
        LocalizedText(
          tr: 'Yalnızca bayramın ikinci günü öğle namazından sonra kesim vakti açılır',
          en: 'Only after Dhuhr prayer on the second day of Eid',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "Kim bayram namazından önce keserse kendi adına et için kesmiş olur; ibadete isabet etmemiştir" buyrulur.',
      en: 'In Sahih al-Bukhari, the Prophet (ﷺ) explained that slaughtering before Eid prayer is ordinary meat, not the ritual sacrifice.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebine göre kurban kesim vakti bayramın 1. günü bayram namazından sonra başlar ve 3. günün güneş batışına kadar devam eder. Bayram namazı kılınmayan köylerde ise 1. gün fecrin doğuşuyla başlar.',
        en: 'In Hanafi fiqh, the sacrifice window runs from after the Eid prayer on Day 1 until sunset of Day 3 (and in Shafi\'i fiqh until sunset of Day 4).',
      ),
      sourceRef: LocalizedText(
        tr: 'Kevser, 108/2; Buhârî, Edâhî 8; Diyanet İlmihali Cilt 2 (Kurban)',
        en: 'Al-Kawthar 108:2; Bukhari, Adahi 8; Diyanet Catechism Vol. 2 (Sacrifice)',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_b_25',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Diyanet İlmihali\'nin ahlâkî görevler bölümünde anne-baba başta olmak üzere yakın akrabalarla ilgiyi sürdürmeyi, ziyaret ve yardımlaşmayla bağı canlı tutmayı ifade eden kavram hangisidir?',
      en: 'In the ethics section of the Diyanet Catechism, which Islamic concept refers to maintaining warm ties, visits, and mutual care with close relatives?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Îsâr (başkasını tercih)', en: 'Ithar (selfless altruism)'),
        LocalizedText(tr: 'Tevâzu (alçak gönüllülük)', en: 'Tawadu\' (humility)'),
        LocalizedText(tr: 'Gıpta (hayırlı imrenme)', en: 'Ghibtah (admirable emulation)'),
        LocalizedText(tr: 'Sıla-i rahim', en: 'Silat ar-Rahim (kinship ties)'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Buhârî ve Müslim\'de rızkın ve ömrün bereketlenmesine vesile kılınan akrabalık bağıdır.',
      en: 'In Bukhari and Muslim, nurturing this tie is promised to bring blessing in provision and lifespan.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sıla-i rahim İslâm\'ın aile ve toplumsal dayanışmaya verdiği önemin göstergesidir; akrabayı tamamen terk etmek (kat\'-ı rahim) ise büyük günahlardan sayılmıştır.',
        en: 'Maintaining kinship ties (Silat ar-Rahim) sustains social mercy and family solidarity, while severing them without just cause is gravely condemned.',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ, 4/1; Buhârî, Edeb 12; Riyâzü\'s-Sâlihîn; Diyanet İlmihali Cilt 2',
        en: 'An-Nisa 4:1; Bukhari, Adab 12; Diyanet Catechism Vol. 2 (Ethics)',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 25 QUESTIONS (dilm_o_01..dilm_o_25)
  // =========================================================================
  IrfanQuestion(
    id: 'dilm_o_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Suların fıkhî tasnifinde yağmur, kar, pınar, ırmak, kuyu ve deniz gibi tabii vasfını koruyan sulara ne ad verilir ve bunlarla temizlik hükmü nedir?',
      en: 'In Islamic purification law, how are natural waters like rain, spring, river, well, and sea water classified and ruled?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Mukayyed su denir; yalnız içmeye uygundur fakat abdest ve gusül alınmaz',
          en: 'Called restricted water (Muqayyad); fit to drink yet invalid for Wudu or Ghusl',
        ),
        LocalizedText(
          tr: 'Mutlak su denir; hem kendisi temizdir hem de maddî ve hükmî temizlikte kullanılır',
          en: 'Called absolute water (Mutlaq); both pure in itself and purifying for Wudu and Ghusl',
        ),
        LocalizedText(
          tr: 'Müsta\'mel su denir; yalnız hadesten tahârette kullanılıp necâset gideremez',
          en: 'Called used water (Musta\'mal); valid for ritual purity yet unable to wash filth',
        ),
        LocalizedText(
          tr: 'Meşkûk su denir; ancak su bulunmadığında teyemmümle birlikte ihtiyatla kullanılır',
          en: 'Called doubtful water (Mashkuk); used cautiously alongside Tayammum only',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Gül suyu veya meyve suyu gibi içine başka madde karışıp vasfı değişmiş sular "mukayyed su" adını alır ve abdestte kullanılmaz.',
      en: 'Rosewater or juices are "restricted water" (Muqayyad); pure natural water without qualifiers is "absolute."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İbadet temizliği (abdest ve gusül) yalnızca yaratılış özelliğini yitirmemiş "mutlak su" ile geçerlidir. Çay, sirke ve meyve suları gibi "mukayyed sular" maddî kirleri yıkamada kullanılabilse de abdest ve guslü sağlamaz.',
        en: 'Ritual purification (Wudu/Ghusl) requires pure natural water (Ma\' Mutlaq). Restricted liquids like juices or rosewater may clean physical stains yet do not lift ritual impurity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Enfâl, 8/11; Furkân, 25/48; Diyanet İlmihali Cilt 1, s. 189-191',
        en: 'Al-Anfal 8:11; Al-Furqan 25:48; Diyanet Catechism Vol. 1, pp. 189-191',
      ),
      linkedFarzId: 21,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Tam abdest alındıktan sonra ayağa giyilen mestler üzerine mesh süresi mukim için 24 saat, yolcu (seferî) için 72 saattir. Bu mesh süresi tam olarak hangi andan itibaren işlemeye başlar?',
      en: 'Wiping over leather socks (khuffayn) put on after full Wudu lasts 24 hours for residents and 72 hours for travelers. Exactly when does that clock begin?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Mestlerin ayaklara giyildiği dakikadan itibaren hemen işlemeye başlar',
          en: 'Immediately from the exact moment the leather socks are put on',
        ),
        LocalizedText(
          tr: 'Mestler üzerine ilk kez ıslak elle mesh çekildiği andan itibaren başlar',
          en: 'Only from the moment one first wipes wet hands over the leather socks',
        ),
        LocalizedText(
          tr: 'Mestler giyildikten sonra kılınan ilk farz namazın vaktinin girmesiyle başlar',
          en: 'From the entrance of the first obligatory prayer time after wearing them',
        ),
        LocalizedText(
          tr: 'Tam abdestli olarak mest giyildikten sonra abdestin ilk bozulduğu andan itibaren başlar',
          en: 'From the moment one\'s Wudu first breaks after putting on the socks in purity',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Kişi sabah namazı için tam abdest alıp mestlerini giyer ve öğle vaktine dek abdestini korursa, mesh süresi henüz başlamamış olur.',
      en: 'If worn after Fajr Wudu and Wudu remains intact until Dhuhr, the countdown starts at Dhuhr.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cümhur ulemâya ve Hanefî fıkhına göre mesh müddeti, abdestin bozulduğu andan itibaren 24/72 saattir. Süre dolduğunda yalnız mestler çıkarılıp ayaklar yıkanır, abdest bozulmadıysa baştan abdest almak gerekmez (Hanefî).',
        en: 'The 24h/72h period starts when Wudu first breaks after wearing the khuffayn. When the time expires, if Wudu is otherwise intact, Hanafi fiqh only requires removing the socks and washing the feet.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Tahâret 85; Ebû Dâvûd, Tahâret 60; Diyanet İlmihali Cilt 1, s. 207-208',
        en: 'Muslim, Taharah 85; Abu Dawud, Taharah 60; Diyanet Catechism Vol. 1, pp. 207-208',
      ),
      linkedFarzId: 15,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Kırık, çıkık veya açık yara üzerine sarılan sargının (cebîrenin) abdestsizken sarılmış olması durumunda dahi üzerine mesh edilmesi caizdir ve 24/72 saatlik bir süre sınırı yoktur.',
      en: 'Even if a bandage or cast (jabirah) over a fracture or wound was applied without Wudu, wiping over it is valid and is not limited to a 24 or 72-hour period.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Cebîre meshi zarurete ve tedavi ihtiyacına bağlı olduğundan mest meshindeki şartlara tâbi değildir.',
      en: 'Wiping over a medical dressing is governed by necessity until healing, unlike leather socks.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm fıkhı hastaya zorluk çıkarmaz. Yara üzerine konulan sargı yıkanamıyorsa üzerinden meshedilir; şayet mesh dahi yaraya zarar verecekse sargı meshi de düşer ve kalan sağlam yerler yıkanır.',
        en: 'Islamic law spares patients hardship: if washing harms a bandaged wound, wiping the dressing suffices, continuing until healing is complete.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hac, 22/78; Diyanet İlmihali Cilt 1, s. 209-210',
        en: 'Al-Hajj 22:78; Diyanet Catechism Vol. 1, pp. 209-210',
      ),
      linkedFarzId: 12,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre sürekli burun kanaması, idrar kaçırma veya kapanmayan yara akıntısı bulunan kimsenin fıkhen "özür sahibi (sâhib-i özür)" sayılabilmesi için ilk şart nedir?',
      en: 'According to the Hanafi school, what is the initial threshold for someone with chronic bleeding or leakage to be legally classified as excused (Sahib al-\'Udhr)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Mazeretin tam bir farz namaz vakti boyunca abdest alıp o namazı kılacak kadar bile kesilmeden sürmesi',
          en: 'The condition persists throughout an entire prayer window without pausing long enough to make Wudu and pray',
        ),
        LocalizedText(
          tr: 'Rahatsızlığın yalnızca bir ay boyunca hiç durmaksızın günde beş vakit devam etmesi',
          en: 'The condition continues uninterruptedly for one full lunar month across all prayers',
        ),
        LocalizedText(
          tr: 'Kişinin tek bir vakitte beş dakikalığına bile akıntı görmesinin hemen özür hükmünü doğurması',
          en: 'A brief five-minute occurrence during one prayer window immediately conferring excused status',
        ),
        LocalizedText(
          tr: 'Özür sahibinin abdest yerine her namaz vaktinde yalnızca teyemmüm yapmasının farz olması',
          en: 'Requiring the excused person to replace Wudu permanently with Tayammum at every prayer',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Bir kez tam namaz vakti boyunca kesintisiz sürüp özür sabit olduktan sonra, sonraki vakitlerde bir defa bile görünmesi özür hâlinin devamı için yeterlidir.',
      en: 'Once established across one full prayer time, a single occurrence in subsequent times sustains the status.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Özür sahibi kabul edilen kimse her farz namaz vaktinin başında bir abdest alır ve vakit çıkıncaya kadar aynı özürden dolayı abdesti bozulmuş sayılmayarak dilediği kadar farz ve nâfile namaz kılabilir.',
        en: 'An excused person performs Wudu once per prayer time window and may pray fard, make-up, and voluntary prayers throughout that window despite the ongoing condition.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 203-204',
        en: 'Diyanet Catechism Vol. 1, pp. 203-204',
      ),
      linkedFarzId: 21,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Kütüb-i Sitte rivayetleri ışığında, kadınların hayız ve nifas (lohusalık) günlerinde yerine getiremedikleri namaz ve Ramazan oruçlarının kaza hükmü nedir?',
      en: 'Based on Sahih Muslim and consensus fiqh, what is the make-up (qada) ruling regarding missed daily prayers and Ramadan fasts during menstruation (hayd) and post-natal bleeding (nifas)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hem namazlar hem de Ramazan oruçları temizlendikten sonra tek tek kaza edilir',
          en: 'Both missed prayers and missed Ramadan fasts must be made up afterward',
        ),
        LocalizedText(
          tr: 'Hem namazlar hem de oruçlar tamamen düşer, hiçbirinin kazası veya fidyesi gerekmez',
          en: 'Both prayers and fasts are waived completely without make-up or ransom',
        ),
        LocalizedText(
          tr: 'Bu günlerde kılınamayan namazlar kaza edilmez; tutulamayan Ramazan oruçları ise temizlenince kaza edilir',
          en: 'Missed daily prayers are completely excused without make-up, whereas missed Ramadan fasts are made up afterward',
        ),
        LocalizedText(
          tr: 'Yalnızca son iki günün namazları kaza edilir; oruçların ise her günü için yalnız fidye verilir',
          en: 'Only the last two days of prayer are made up, while fasts are settled by feeding the poor',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Hz. Âişe (r.anhâ): "Bize orucu kaza etmemiz emrolunur, namazı kaza etmemiz emrolunmazdı" buyurmuştur (Müslim, Hayız 69).',
      en: '\'Aishah (r.a.) reported: "We were commanded to make up the fasts, and not commanded to make up the prayers" (Muslim).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Günde beş vakit namazın biriken günlerinin sonradan kazası kadınlara büyük meşakkat yükleyeceği için tamamen affedilmiştir; yılda bir aya mahsus olan oruç ise kolaylıkla kaza edilir.',
        en: 'Excusing accumulated prayers spares women overwhelming hardship, while Ramadan fasts occurring once a year are readily made up after purifying.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Hayız 69; Diyanet İlmihali Cilt 1, s. 217-220, 405',
        en: 'Sahih Muslim, Hayd 69; Diyanet Catechism Vol. 1, pp. 217-220, 405',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Güneşin doğuşundan yükselmesine kadar (~45 dk), tam tepe noktasında (istivâda) iken ve batmak üzere sarardığı üç kerâhet vaktinde hiçbir namaz kılınmaz; ancak bu kuralın tek bir istisnası vardır. Hangisidir?',
      en: 'Prayer is prohibitively disliked during sunrise, solar zenith, and sunset, except for one obligatory prayer. Which exception may be prayed as the sun begins to set?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kaza borcu bulunan önceki günlere ait öğle ve yatsı namazlarının kazası',
          en: 'Make-up prayers for previously missed Dhuhr and Isha prayers',
        ),
        LocalizedText(
          tr: 'Güneş batmaya yüz tuttuğunda o günün henüz kılınmamış ikindi namazının farzı',
          en: 'That same day\'s unprayed \'Asr obligatory prayer right before sunset',
        ),
        LocalizedText(
          tr: 'Güneş doğarken gecikmiş olan sabah namazının iki rekâtlık sünneti',
          en: 'The two Sunnah rak\'ahs of Fajr right as the sun is rising',
        ),
        LocalizedText(
          tr: 'İstivâ vaktinde (tam öğle sıcağında) kılınan Cuma veya bayram namazı',
          en: 'Friday or Eid prayer performed precisely at solar zenith',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: '"Her kim güneş batmadan ikindiden bir rekâta yetişirse o ikindiye yetişmiştir" hadisi uyarınca edâ vakti içinde kılınması gerekir.',
      en: 'Grounded in the hadith granting validity to catching the day\'s \'Asr prayer before complete sunset.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İkindiyi güneşin gözleri kamaştırmayacak kadar sararmasından sonraya bırakmak tahrîmen mekruhtur; fakat o ana kadar kılınmamışsa vakit tamamen çıkmadan güneş batarken kılınır (yalnız ikindi sünneti veya başka kaza kılınmaz).',
        en: 'Delaying \'Asr until sunset yellowing is disliked; yet if missed until then, its fard must still be prayed before sunset rather than letting the time expire completely.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Mevâkît 28; Müslim, Mesâcid 163; Diyanet İlmihali Cilt 1, s. 233-236',
        en: 'Bukhari, Mawaqit 28; Muslim, Masajid 163; Diyanet Catechism Vol. 1, pp. 233-236',
      ),
      linkedFarzId: 25,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre aşağıdakilerden hangisi namazın içindeki altı rükünden (farzlardan) biri değil, namazın vaciplerindendir?',
      en: 'According to the Hanafi school, which of the following is NOT one of the six internal fards (pillars) of Salah, but rather one of its wajibs?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Namaza İftitah tekbiri ile başlayıp kıyamda Kur\'ân\'dan en az farz miktarı okumak',
          en: 'Entering with the opening Takbir and reciting the minimum Qur\'an while standing',
        ),
        LocalizedText(
          tr: 'Her rekâtta bir defa rükû ve iki defa secde yapmak',
          en: 'Performing one bowing (ruku\') and two prostrations (sujud) in each rak\'ah',
        ),
        LocalizedText(
          tr: 'Namazın sonunda teşehhüd miktarı son oturuşta (Ka\'de-i Ahîre) bulunmak',
          en: 'Performing the final sitting (Qa\'dah al-Akhirah) for the duration of Tashahhud',
        ),
        LocalizedText(
          tr: 'Fâtiha Sûresini okuyup yanına zamm-ı sûre eklemek ve dört rekâtlıda ilk oturuşu yapmak',
          en: 'Reciting Surah Al-Fatihah with an added passage and making the first sitting in 3/4-rak\'ah prayers',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Bunların yanılarak (sehven) terk edilmesi namazı bozmaz; sonunda Sehiv Secdesi ile telâfi edilir.',
      en: 'Inadvertently omitting a wajib does not nullify prayer; it is repaired by Sujud as-Sahw.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde farz namazların ilk iki rekâtında ve nafile/vitrin bütün rekâtlarında Fâtiha okuyup zamm-ı sûre eklemek, üç-dört rekâtlılarda ilk oturuşu (ka\'de-i ûlâ) yapmak ve teşehhüd okumak vaciptir.',
        en: 'In Hanafi fiqh, reciting Al-Fatihah plus an added Surah, performing the first sitting in 3/4-rak\'ah prayers, and reading At-Tahiyyat are wajib duties whose accidental omission requires Sujud as-Sahw.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 251-252',
        en: 'Diyanet Catechism Vol. 1, pp. 251-252',
      ),
      linkedFarzId: 29,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Namazda rükûdan doğrulduktan sonra bütün uzuvlar yerli yerine oturuncaya dek kısa süre beklemeye (Kavme) ve iki secde arasındaki kısa oturuşa (Celse) dair hüküm nasıldır?',
      en: 'What is the ruling on pausing upright after Ruku\' (Qawmah) and sitting calmly between the two prostrations (Jalsah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Ta\'dîl-i erkân gereğince sükûnetle yapılmaları Şâfiî\'de ve Ebû Yûsuf\'ta farz, Ebû Hanîfe ile İmam Muhammed\'de vaciptir',
          en: 'Both require calm composure: obligatory (fard) in Shafi\'i fiqh and per Abu Yusuf, and wajib per Abu Hanifah and Muhammad',
        ),
        LocalizedText(
          tr: 'Yalnızca teravih ve gece namazlarında uygulanması tavsiye edilen nâfile sünnetlerdendir',
          en: 'Voluntary etiquettes recommended exclusively for Tarawih and late-night prayers',
        ),
        LocalizedText(
          tr: 'İmamın vakti uzatmaması için cemaatle kılınan farz namazlarda tamamen terk edilebilir',
          en: 'May be omitted entirely during congregational prayers to shorten the service',
        ),
        LocalizedText(
          tr: 'Kavme rükûdan sayıldığı için yalnızca kadınların celse hâlinde beklemesi gerekir',
          en: 'Only Jalsah applies universally, while Qawmah is restricted to women praying alone',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Secdeyle rükû arası ve iki secde arası tam doğrulup en az "Sübhânallâh" diyecek kadar beklemek ta\'dîl-i erkânın esasıdır.',
      en: 'Straightening fully for at least the duration of one "Subhanallah" preserves Ta\'dil al-Arkan.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ebû Dâvûd ve Buhârî\'de "namazını tavuk yemler gibi hızlı kılan" sahâbîye Peygamber Efendimizin (s.a.v.) rükû, kavme, secde ve celsede sükûneti emrettiği sabit olduğundan fetva, ta\'dîl-i erkânın vacip (Şâfiî\'de farz) olduğu yönündedir.',
        en: 'Following the Prophetic correction of hasty prayer, calm pauses in Qawmah and Jalsah are essential (wajib in relied-upon Hanafi fatwa, fard in Shafi\'i fiqh).',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Ezân 95; Ebû Dâvûd, Salât 144; Diyanet İlmihali Cilt 1, s. 247-252',
        en: 'Bukhari, Adhan 95; Abu Dawud, Salah 144; Diyanet Catechism Vol. 1, pp. 247-252',
      ),
      hanafiNote: LocalizedText(
        tr: 'Ebû Hanîfe ve İmam Muhammed\'e göre kavme ve celse sünnet (ta\'dîl-i erkân vacip); Ebû Yûsuf ve Şâfiî\'de ise farzdır. Diyanet fetvası vacip olup sehivde secde gerektiği yönündedir.',
        en: 'In relied-upon Hanafi fatwa, pausing calmly in Qawmah and Jalsah is wajib (requiring Sujud as-Sahw if inadvertently skipped).',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde i\'tidâl (rükûdan tam doğrulma) ve iki secde arasındaki celse tuma\'nîne ile birlikte rükün/farzdır.',
        en: 'In Shafi\'i fiqh, rising upright (i\'tidal) and sitting between prostrations with stillness (tuma\'ninah) are fard pillars.',
      ),
      linkedFarzId: 30,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Cemaatle kılınan namazda imama uyma (iktidâ) durumlarını fıkhî kavramlarıyla eşleştiriniz.',
      en: 'Match the juristic classifications of followers joining congregational prayer behind an imam.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Müdrik', en: 'Mudrik'),
          right: LocalizedText(
            tr: 'İftitah tekbirinden itibaren tüm rekâtları imamla kılan',
            en: 'Catches all rak\'ahs with the imam from opening Takbir',
          ),
        ),
        (
          left: LocalizedText(tr: 'Mesbûk', en: 'Masbuq (Latecomer)'),
          right: LocalizedText(
            tr: 'Bir veya birkaç rekâtı kaçırıp namaza sonradan yetişen',
            en: 'Misses one or more rak\'ahs and joins mid-prayer',
          ),
        ),
        (
          left: LocalizedText(tr: 'Lâhık', en: 'Lahiq'),
          right: LocalizedText(
            tr: 'İmama uyduktan sonra abdest bozulması vb. sebeple geri kalan',
            en: 'Starts with imam then falls behind due to a valid break',
          ),
        ),
        (
          left: LocalizedText(tr: 'Münferid', en: 'Munfarid (Solitary)'),
          right: LocalizedText(
            tr: 'Bir imama tabi olmadan namazını tek başına kılan',
            en: 'Performs prayer individually without an imam',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Mesbûk "geçilmiş" anlamında olup imam selâm verdikten sonra kalkıp kaçırdığı rekâtları tamamlar.',
      en: 'A Masbuq completes the missed rak\'ahs after the imam concludes with Salam.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmamla rükûya yetişen kimse o rekâta yetişmiş sayılır. Mesbûk olan kişi imam sağa-sola selâm verdikten sonra selâm vermeyip kalkar ve yetişemediği rekâtları kıraat sırasıyla ikmal eder.',
        en: 'Catching the imam in Ruku\' counts as catching that rak\'ah; a latecomer stands up after the imam\'s Salam without giving Salam to complete the missed rak\'ahs.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 276-277',
        en: 'Diyanet Catechism Vol. 1, pp. 276-277',
      ),
      linkedFarzId: 27,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Cuma namazının geçerli (sahih) olabilmesi için hutbenin vakti ve namazla sırası hakkında aşağıdakilerden hangisi şarttır?',
      en: 'For the Friday prayer (Jumu\'ah) to be valid, what condition governs the timing and sequence of the sermon (Khutbah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Tıpkı Bayram namazında olduğu gibi hutbenin iki rekât farzdan sonra okunması',
          en: 'Delivering the Khutbah after the two fard rak\'ahs, just like Eid prayers',
        ),
        LocalizedText(
          tr: 'Öğle vakti girmeden önce camide okunmasının yeterli sayılması',
          en: 'Delivering it inside the mosque prior to the entrance of Dhuhr time',
        ),
        LocalizedText(
          tr: 'Öğle vaktinin girmesinden sonra ve Cuma\'nın iki rekât farzından önce okunması',
          en: 'Delivering it after Dhuhr time enters and strictly before the two fard rak\'ahs',
        ),
        LocalizedText(
          tr: 'İmamın yalnızca iki rekâtı cemaatle kıldırmasının yeterli olup hutbenin mendup olması',
          en: 'Leading the two rak\'ahs suffices, while delivering the Khutbah is merely recommended',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Bayram hutbesi namazdan sonra sünnettir; Cuma hutbesi ise namazdan önce okunan sıhhat şartıdır (farz).',
      en: 'Eid Khutbah follows the prayer as Sunnah; Friday Khutbah precedes the prayer as an obligatory condition.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cuma Sûresi 9. âyetteki "Allah\'ın zikrine (hutbeye ve namaza) koşun" emri uyarınca Cuma hutbesi namazın sıhhat şartıdır ve mutlaka öğle vakti girdikten sonra, iki rekâtlık Cuma farzından önce okunur.',
        en: 'Following Surah Al-Jumu\'ah 62:9, the Khutbah is a validity condition of Friday prayer delivered after noon enters and before the two obligatory rak\'ahs.',
      ),
      sourceRef: LocalizedText(
        tr: 'Cuma Sûresi, 62/9; Diyanet İlmihali Cilt 1, s. 308-311',
        en: 'Surah Al-Jumu\'ah, 62:9; Diyanet Catechism Vol. 1, pp. 308-311',
      ),
      linkedFarzId: 8,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Hanefî mezhebinde İmâmeyn\'in (Ebû Yûsuf ve İmam Muhammed) fetvaya esas görüşüne göre, Kurban Bayramı günlerinde farz namazların hemen ardından okunan Teşrik Tekbirleri hangi vakitler arasında toplam kaç vakittir?',
      en: 'According to the relied-upon Hanafi position (Abu Yusuf and Muhammad), between which prayers are the Takbirat at-Tashriq recited during Eid al-Adha?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bayramın 1. günü sabahından 3. gün akşamına kadar toplam 15 vakit sünnettir',
          en: 'From Eid Day 1 Fajr to Day 3 Maghrib, totaling 15 prayers (Sunnah)',
        ),
        LocalizedText(
          tr: 'Arefe günü sabah namazından bayramın 4. günü ikindi namazına kadar toplam 23 vakit vaciptir',
          en: 'From \'Arafah Day Fajr through Eid Day 4 \'Asr, totaling 23 prayers (Wajib)',
        ),
        LocalizedText(
          tr: 'Yalnızca Kurban Bayramı\'nın 1. günü beş vakit farzın ardından okunur',
          en: 'Recited solely after the five obligatory prayers on the first day of Eid',
        ),
        LocalizedText(
          tr: 'Ramazan Bayramı arefesinden başlayarak bayram sabahına kadar toplam 8 vakit vaciptir',
          en: 'From the eve of Eid al-Fitr through Eid morning, totaling 8 prayers (Wajib)',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Zilhicce\'nin 9. günü (Arefe) sabahıyla başlar, 13. günü (bayramın 4. günü) ikindiyle sona erer; tek başına kılanlar ve kadınlar da okur.',
      en: 'Starts at Fajr on 9 Dhul-Hijjah (\'Arafah) and ends at \'Asr on 13 Dhul-Hijjah for both congregations and individuals.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Allâhü ekber Allâhü ekber lâ ilâhe illallâhü vallâhü ekber Allâhü ekber ve lillâhi\'l-hamd" şeklindeki teşrik tekbirleri, fetva verilen görüşe göre her mükellef Müslümana 23 vakit boyunca vaciptir.',
        en: 'Saying the Takbir at-Tashriq immediately after fard prayers for 23 prayers is wajib in the relied-upon Hanafi fatwa for men and women alike.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/203; Diyanet İlmihali Cilt 1, s. 316-317',
        en: 'Al-Baqarah 2:203; Diyanet Catechism Vol. 1, pp. 316-317',
      ),
      hanafiNote: LocalizedText(
        tr: 'Ebû Yûsuf ve İmam Muhammed\'e göre 23 vakit her mükellef için vaciptir; cemaatle de tek başına da kılınsa getirilir.',
        en: 'Per Abu Yusuf and Muhammad (relied-upon fatwa), it is wajib for 23 prayers whether praying in congregation or alone.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde Kurban Bayramı teşrik tekbirleri Arefe sabahından 4. gün ikindiye kadar sünnet-i müekkededir.',
        en: 'In Shafi\'i fiqh, Takbir at-Tashriq from \'Arafah Fajr through the 4th day \'Asr is an emphasized Sunnah.',
      ),
      linkedZikirKey: 'Allahuekber',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Vefat eden bir Müslümana karşı son vazife olan Cenaze Namazının hükmü ve aslî rükünleri hangi seçenekte doğru verilmiştir?',
      en: 'What is the legal ruling and what are the core pillars of the Funeral Prayer (Salat al-Janazah) for a deceased Muslim?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sünnet-i müekkededir; rükûsuz olmakla birlikte her rekâtta bir secde yapılır',
          en: 'Emphasized Sunnah; omits bowing while performing one prostration per round',
        ),
        LocalizedText(
          tr: 'Farz-ı ayındır; tıpkı iki rekâtlı bayram namazı gibi rükû ve secdelerle kılınır',
          en: 'Individual obligation; performed with two rak\'ahs including bowing and prostration',
        ),
        LocalizedText(
          tr: 'Vaciptir; yalnız kabir başında oturularak üç tekbir ve Fâtiha ile edâ edilir',
          en: 'Wajib; performed seated beside the grave with three takbirs and Al-Fatihah',
        ),
        LocalizedText(
          tr: 'Farz-ı kifâyedir; rükû ve secdesi bulunmayıp rükünleri kıyam ve dört tekbirden oluşur',
          en: 'Communal obligation (Fard al-Kifayah); consists strictly of standing (qiyam) and four takbirs without bowing or prostration',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'İlk tekbirden sonra Sübhâneke (ve celle senâük), ikinci tekbirden sonra Salli-Bârik, üçüncü tekbirden sonra cenaze duası okunur, dördüncü tekbirden sonra selâm verilir.',
      en: 'Four standing takbirs: Subhanaka, Salawat, funeral supplication, then Taslim.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cenaze namazı vefat eden mümin kardeşimiz için ayakta edilen toplu bir dua ve şefaattir. Bir grup Müslüman tarafından kılındığında diğer belde halkından sorumluluk düşer (farz-ı kifâye).',
        en: 'Salat al-Janazah is a standing communal intercessory prayer for the deceased believer; once a group performs it, the communal duty is discharged.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Cenâiz 65; Diyanet İlmihali Cilt 1, s. 327-331',
        en: 'Bukhari, Jana\'iz 65; Diyanet Catechism Vol. 1, pp. 327-331',
      ),
      linkedFarzId: 28,
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre ikamet yerinden en az ~90 km uzaklığa gidip orada 15 günden az kalmaya niyet eden yolcu (seferî), günlük namazların rekâtlarını nasıl kılar?',
      en: 'In Hanafi fiqh, when traveling at least ~90 km and intending to stay less than 15 days at a destination, how does a traveler perform daily prayers?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Öğle, ikindi ve yatsının 4 rekâtlı farzlarını 2 rekât kılar; sabah farzı, akşam farzı ve vitir değişmez',
          en: 'Shortens the 4-rak\'ah fards of Dhuhr, \'Asr, and \'Isha to 2; Fajr, Maghrib, and Witr remain unchanged',
        ),
        LocalizedText(
          tr: 'Beş vakit namazın farzlarının tamamını (akşam dâhil) yarı yarıya kısaltarak kılar',
          en: 'Shortens all five daily fard prayers (including Maghrib) by half',
        ),
        LocalizedText(
          tr: 'Yalnızca öğle ve ikindiyi birleştirir, fakat seferde dört rekâtlı farzları kısaltması caiz değildir',
          en: 'Combines Dhuhr and \'Asr while keeping every four-rak\'ah prayer full length',
        ),
        LocalizedText(
          tr: 'Seferde vitir namazını ve sabah namazının farzını birer rekât olarak kılar',
          en: 'Reduces both Witr and Fajr fard to a single rak\'ah during travel',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Yalnızca tek başına kılınan veya seferî imama uyulan dört rekâtlı farzlar ikiye indirilir; mukim imama uyulursa imamla dört rekât kılınır.',
      en: 'Only 4-rak\'ah fard prayers are shortened to 2 (unless praying behind a resident imam, whom the traveler follows for all 4).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Seferde kolaylık (kasr-ı salât) dört rekâtlı farzlara mahsustur; 2 rekâtlı sabah, 3 rekâtlı akşam ve 3 rekâtlı vitir kısaltılmaz. Sünnetler ise imkân varsa tam kılınır, acele ve meşakkat hâlinde terk edilebilir.',
        en: 'Shortening (Qasr) applies solely to 4-rak\'ah fards; Fajr (2), Maghrib (3), and Witr (3) remain unchanged. Travelers may skip Sunnahs when pressed or pray them in full when settled.',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ, 4/101; Müslim, Müsâfirîn 1-5; Diyanet İlmihali Cilt 1, s. 318-323',
        en: 'An-Nisa 4:101; Muslim, Musafirin 1-5; Diyanet Catechism Vol. 1, pp. 318-323',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de sefer ikamet sınırı 15 günden azdır (~90 km); kasr ise ruhsat değil azîmet/vaciptir (kasten 4 kılsa mekruh olur).',
        en: 'Hanafi stay threshold is under 15 days (~90 km), and shortening 4-rak\'ah fards is wajib rather than optional.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de giriş-çıkış günleri hariç 4 günden az kalışlarda seferî sayılır; kasr ise yolcuya tanınmış bir ruhsattır (tam da kılabilir).',
        en: 'Shafi\'i stay threshold is under 4 days (excluding arrival/departure days), and shortening is an optional concession (rukhsah).',
      ),
      linkedFarzId: 28,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'deki on dört secde âyetinden birini okuyan veya dinleyen mükellef için gereken Tilâvet Secdesinin hükmü ve yapılış şekli hangisinde doğru verilmiştir?',
      en: 'What is the ruling and proper procedure for the Prostration of Recitation (Sujud at-Tilawah) upon reading or hearing one of the 14 Qur\'anic prostration verses?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bütün mezheplerde yalnız namaz içinde farzdır; namaz dışında secde gerekmez',
          en: 'Obligatory in all schools only during Salah, never outside prayer',
        ),
        LocalizedText(
          tr: 'Kıbleye dönme şartı aranmaksızın oturulan yerde yalnız iki kez başı eğerek yapılır',
          en: 'Performed where seated by nodding twice without facing Qiblah or purifying',
        ),
        LocalizedText(
          tr: 'Hanefî\'de vacip, Şâfiî\'de sünnet-i müekkededir; abdestli ve kıbleye dönük olarak rükûsuz tek secde yapılır',
          en: 'Wajib in Hanafi fiqh and emphasized Sunnah in Shafi\'i fiqh; one prostration in purity facing Qiblah without Ruku\'',
        ),
        LocalizedText(
          tr: 'Tilâvet secdesi yapılmadan önce mutlaka iki rekât nafile namaz kılmak şarttır',
          en: 'Requires performing two voluntary rak\'ahs beforehand before prostrating',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Namazın şartları (abdest, setr-i avret, istikbâl-i kıble, niyet) burada da geçerlidir; "Allâhü ekber" diyerek tek secdeye gidilir ve kalkılır.',
      en: 'Prayer prerequisites (Wudu, \'awrah cover, facing Qiblah, intention) apply; one prostration with Takbir without Tashahhud.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Secde âyetini okuyan veya dinleyen kişi abdestli, örtülü ve kıbleye yönelmiş (İstikbâl-i Kıble) hâlde ayağa kalkıp el kaldırmadan "Allâhü ekber" diyerek bir secde yapar ve doğrulur; selâm veya teşehhüd yoktur.',
        en: 'Facing Qiblah in ritual purity and modest dress, the believer says "Allahu Akbar" without raising the hands, makes one prostration saying "Subhana Rabbiyal-A\'la," and rises—with no sitting or Taslim.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Sücûdü\'l-Kur\'ân 1-12; Diyanet İlmihali Cilt 1, s. 304-307',
        en: 'Bukhari, Sujud al-Qur\'an 1-12; Diyanet Catechism Vol. 1, pp. 304-307',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî mezhebine göre secde âyetini okumak veya dinlemekle tilâvet secdesi vacip olur.',
        en: 'In Hanafi fiqh, Sujud at-Tilawah is wajib upon both reciting and hearing a prostration verse.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebine göre tilâvet secdesi sünnet-i müekkededir ve namaz dışında niyet, iftitah tekbiri, tek secde ve selâm ile yapılır.',
        en: 'In Shafi\'i fiqh, it is an emphasized Sunnah performed outside prayer with intention, opening Takbir, one prostration, and Salam.',
      ),
      linkedFarzId: 24,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre Ramazan orucu esnasında meydana gelen aşağıdaki durumlardan hangisi yalnız kaza değil, hem kaza hem de kesintisiz 60 gün oruç kefâreti gerektirir?',
      en: 'In Hanafi fiqh, which occurrence during a Ramadan fast requires BOTH making up the day AND a 60-day consecutive expiation (kaffarah), rather than make-up alone?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Abdest alırken hataen (istemeden) boğazına su kaçması sonucu orucun bozulması',
          en: 'Water accidentally slipping down the throat while rinsing the mouth during Wudu',
        ),
        LocalizedText(
          tr: 'Meşru mazeret yokken bilerek ve isteyerek gıda/içecek almak veya cinsel ilişkide bulunmak',
          en: 'Deliberately and willingly eating, drinking, or having marital relations with no valid excuse',
        ),
        LocalizedText(
          tr: 'Unutarak yiyip içtikten sonra "orucum bozuldu" zannıyla bilmeyerek yemeye devam etmek',
          en: 'Continuing to eat after eating forgetfully under the mistaken impression the fast had broken',
        ),
        LocalizedText(
          tr: 'İmsak vaktinin henüz girmediğini sanarak sahur yapıp sonra fecrin doğduğunun anlaşılması',
          en: 'Eating Suhoor believing dawn had not broken yet, only to discover later that Fajr had entered',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Kefâret yalnız Ramazan edâ orucunu hiçbir mazeret olmadan kasten bozma durumunda gerekir; hata veya şüphe hallerinde ise sadece gününe gün kaza vardır.',
      en: 'Kaffarah applies only to intentional, unexcused violation of Ramadan\'s fast; mistakes or misunderstandings require only 1-for-1 make-up.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî fıkhında hataen su kaçması, imsak/iftar vaktinde yanılma ve unutarak yedikten sonra bozuldu sanıp yeme durumlarında gününe gün yalnız kaza gerekir. Kasten gıda/içecek veya cimâ ile bozmada ise 60 gün peş peşe kefâret ve 1 gün kaza gerekir.',
        en: 'Accidental water ingestion, mistaking dawn/sunset, or eating after mistakenly thinking one\'s fast ended only require making up the day. Deliberate food, drink, or marital intimacy triggers kaffarah plus qada in Hanafi fiqh.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Savm 30; Müslim, Sıyâm 81; Diyanet İlmihali Cilt 1, s. 397-402',
        en: 'Bukhari, Sawm 30; Muslim, Siyam 81; Diyanet Catechism Vol. 1, pp. 397-402',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Oruçlu olduğunu tamamen unutarak yiyip içen kimsenin orucu — yediği veya içtiği şey ne kadar çok olursa olsun — bozulmaz; hatırladığı anda yemeyi bırakıp orucuna devam eder.',
      en: 'If a fasting person eats or drinks completely out of forgetfulness—regardless of the amount—the fast remains valid as long as they stop immediately upon remembering.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Sahîh-i Buhârî ve Müslim\'de Peygamberimiz (s.a.v.) "Onu Allah yedirmiş ve içirmiştir" buyurmuştur.',
      en: 'The Prophet (ﷺ) explicitly comforted believers: "It is Allah who fed him and gave him drink."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Unutarak yiyip içmek orucu bozmaz; hatırladığı saniye ağzındakini çıkarıp ağzını çalkalar ve orucuna devam eder. Ancak unutarak yerken yanında bulunan ve oruçlu olduğunu bilen birinin onu gücü yetiyorsa hatırlatması gerekir (unutmayı sürdürmesi haram olur).',
        en: 'Forgetful eating does not invalidate fasting in Hanafi or Shafi\'i fiqh: the person spits out what is in their mouth upon realizing and completes the fast.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Savm 26; Müslim, Sıyâm 171; Diyanet İlmihali Cilt 1, s. 394',
        en: 'Bukhari, Sawm 26; Muslim, Siyam 171; Diyanet Catechism Vol. 1, p. 394',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Bakara Sûresi 184. âyet gereği tutulamayan her oruç günü için bir fakiri doyurmak üzere verilen "oruç fidyesi" kimler için meşrudur ve iyileşme olursa hükmü nedir?',
      en: 'According to Surah Al-Baqarah 2:184, who qualifies to pay daily fasting ransom (fidyah), and what happens if health later recovers?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Yalnızca yolculuğa çıkan sağlıklı kişilere mahsustur; seferî olanlar oruç tutmak yerine fidye verebilir',
          en: 'Intended for healthy travelers, who may pay ransom instead of making up missed days',
        ),
        LocalizedText(
          tr: 'Kasten orucunu bozan kimse 60 gün kefâret yerine doğrudan bir günlük fidye ödeyebilir',
          en: 'Allows one who deliberately broke a fast to replace kaffarah with a single meal',
        ),
        LocalizedText(
          tr: 'Geçici ateşli hastalığa yakalananlar fidye verince iyileştikten sonra dahi kaza borcundan kurtulur',
          en: 'Patients with temporary acute illnesses pay ransom and owe no make-up even after recovery',
        ),
        LocalizedText(
          tr: 'İyileşme ümidi olmayan hastalar ile çok yaşlılar içindir; şayet ileride iyileşirlerse tutamadıklarını kaza ederler',
          en: 'Prescribed for the chronically ill without hope of recovery and the frail elderly; if health returns, missed days must be fasted',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Geçici hastalığı veya sefer hâli olan kimse fidye değil, iyileşince/dönünce orucunu kaza eder.',
      en: 'Temporary illness or travel always calls for later make-up (qada), never substituting fidyah while healthy.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Fidye gücü yetmeyen düşkün yaşlılar (şeyh-i fânî) ile tıbben iyileşme ümidi bulunmayan ağır kronik hastalar içindir. Şayet bir hasta ümitsiz sanılıp fidye verdikten sonra umulmadık biçimde sağlığına kavuşursa fidyenin hükmü düşer ve o günleri kaza eder.',
        en: 'Fidyah applies only when permanent inability exists; if a chronic patient unexpectedly regains the ability to fast, making up those days becomes obligatory.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/184; Diyanet İlmihali Cilt 1, s. 406-408',
        en: 'Surah Al-Baqarah, 2:184; Diyanet Catechism Vol. 1, pp. 406-408',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    specialDayTags: ['ramazan', 'bayram'],
    stem: LocalizedText(
      tr: 'Ramazan\'a kavuşmanın şükrü olarak verilen Sadaka-i Fıtır (Fitre) ibadetinin fıkhî hükmü ve vacip olma vakti hakkında hangisi doğrudur?',
      en: 'Which statement accurately describes the ruling and obligation time for Sadaqat al-Fitr (Fitrah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hanefî\'de vacip, Şâfiî\'de farzdır; Ramazan Bayramı 1. günü fecirde vacip olup bayram namazından önce verilmesi müstehaptır',
          en: 'Wajib in Hanafi and fard in Shafi\'i; becomes binding at dawn on Eid Day 1 and is best given before the Eid prayer',
        ),
        LocalizedText(
          tr: 'Sadece zekât veren zenginlerin vermesi şart olup küçük çocuklar adına ödenmesi gerekmez',
          en: 'Obligatory only upon Zakah-paying individuals with no obligation on behalf of minor dependents',
        ),
        LocalizedText(
          tr: 'Yalnızca teravih namazı kılanlara sünnet olup oruç tutamayan hastalar ve yaşlılar fitreden muaftır',
          en: 'Sunnah solely for those praying Tarawih; ill and elderly people are exempt even if wealthy',
        ),
        LocalizedText(
          tr: 'Havaî bir borç sayıldığından Ramazan ayı içinde önceden verilmesi kesinlikle caiz değildir',
          en: 'Paying it ahead of Eid during the month of Ramadan is strictly invalid',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'İhtiyaç sahiplerinin bayram hazırlığı yapabilmesi için Ramazan içinde bayramdan önce de verilebilir; bayramdan sonraya bırakılsa da borç olarak kalır.',
      en: 'May be paid earlier in Ramadan so the poor can prepare for Eid; delaying past Eid leaves the duty pending.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Fitre aslî ihtiyaçları dışında nisap miktarı mala sahip her Müslümanın kendisi ve bakmakla yükümlü olduğu küçük çocukları için verdiği malî ibadettir (bir kişinin bir günlük normal gıda ihtiyacı ölçüsünde).',
        en: 'Sadaqat al-Fitr purifies the fast and enables the poor to share Eid joy, calculated as the equivalent of one person\'s two daily meals.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Zekât 17-20; Buhârî, Zekât 70; Diyanet İlmihali Cilt 1, s. 467-470',
        en: 'Abu Dawud, Zakat 17-20; Bukhari, Zakat 70; Diyanet Catechism Vol. 1, pp. 467-470',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de nisap şartı (80,18 gr altın veya karşılığı, 1 yıl bekleme şartı aranmaksızın) gerekir ve vaciptir; nakit bedeliyle ödenmesi de caizdir.',
        en: 'Hanafi fiqh requires nisab ownership (without needing a full lunar year) and permits giving monetary cash value.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de bayram günü ve gecesinin temel nafakasından fazla imkânı olan herkese farzdır; aslen bölgenin temel gıda maddesinden 1 sâ\' verilir.',
        en: 'Shafi\'i fiqh obligates it on anyone holding surplus above Eid day/night needs, primarily measured in staple food.',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['ramazan', 'kadir'],
    stem: LocalizedText(
      tr: 'Peygamber Efendimizin (s.a.v.) özellikle Ramazan\'ın son on gününde Kadir Gecesi\'ni aramak için devam ettiği İtikâf ibadeti hakkında hangisi doğrudur?',
      en: 'Which statement accurately characterizes I\'tikaf (spiritual retreat), practiced consistently by the Prophet (ﷺ) in the final ten days of Ramadan?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Farz-ı ayın olup her Müslümanın her yıl en az üç gün camide itikâfa girmesi gerekir',
          en: 'An individual obligation requiring every adult Muslim to retreat for three days annually',
        ),
        LocalizedText(
          tr: 'Kadınların hiçbir surette evlerinde mescit edindikleri odada itikâfa girmeleri caiz değildir',
          en: 'Women are strictly prohibited from observing I\'tikaf even in a designated prayer room at home',
        ),
        LocalizedText(
          tr: 'Sünnet-i müekkede ale\'l-kifâyedir; erkekler camide, kadınlar (Hanefî\'de) evlerinin namaz odasında yapabilir',
          en: 'Communal emphasized Sunnah; men observe it in a mosque while Hanafi women may observe it in a home prayer corner',
        ),
        LocalizedText(
          tr: 'İtikâfa giren kimsenin oruçlu olması yasaktır; gece-gündüz dışarı çıkıp çalışması sünnettir',
          en: 'Fasting during Ramadan I\'tikaf is forbidden, and leaving to conduct business daily is recommended',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Sünnet olan itikâf Ramazan\'ın son on gününde niyet ve oruçla birlikte camide (kadınlar için evdeki namaz odasında) ibadetle meşgul olmaktır.',
      en: 'In Hanafi fiqh, the Sunnah Ramadan retreat requires intention and fasting inside a congregational mosque (or designated room at home for women).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İtikâf, dünyevî meşguliyetlerden geçici olarak uzaklaşıp kalbi zikir, Kur\'ân, tefekkür ve duaya bağlamaktır. Bir mahallede bir Müslümanın itikâfa girmesiyle diğerlerinden bu kifâî sünnet sorumluluğu yerine gelmiş olur.',
        en: 'I\'tikaf detaches the heart from worldly distractions for focused prayer, Qur\'an, and remembrance; when even one believer observes it locally, the communal Sunnah is upheld.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/187; Buhârî, İ\'tikâf 1; Diyanet İlmihali Cilt 1, s. 414-416',
        en: 'Al-Baqarah 2:187; Bukhari, I\'tikaf 1; Diyanet Catechism Vol. 1, pp. 414-416',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_20',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Zekât ve toprak ürünleri (Öşür) ibadetinde mal cinslerini geçerli zekât/öşür nisap ve oranlarıyla doğru eşleştiriniz.',
      en: 'Match each category of zakatable wealth or agricultural produce with its corresponding rate or threshold.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(
            tr: 'Altın (80,18 gr) ve Ticaret Malları',
            en: 'Gold (~80.18g) & Trade Inventory',
          ),
          right: LocalizedText(
            tr: 'Kırkta bir (%2,5)',
            en: 'One-fortieth (2.5%)',
          ),
        ),
        (
          left: LocalizedText(
            tr: 'Yağmur ve Nehirle Sulanan Toprak Ürünü',
            en: 'Rain or River-Irrigated Crops (\'Ushr)',
          ),
          right: LocalizedText(
            tr: 'Onda bir (%10)',
            en: 'One-tenth (10%)',
          ),
        ),
        (
          left: LocalizedText(
            tr: 'Masraf ve Motorla Sulanan Toprak Ürünü',
            en: 'Artificially Irrigated Crops (with Cost)',
          ),
          right: LocalizedText(
            tr: 'Yirmide bir (%5)',
            en: 'One-twentieth (5%)',
          ),
        ),
        (
          left: LocalizedText(
            tr: '40 ile 120 Arası Sâime Koyun/Keçi',
            en: '40 to 120 Pasture Sheep/Goats',
          ),
          right: LocalizedText(
            tr: '1 adet koyun veya keçi',
            en: '1 sheep or goat',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İslâm, emek ve sulama maliyeti artınca öşür oranını %10\'dan %5\'e indirerek üreticiyi korur.',
      en: 'Islamic law reduces crop Zakat from 10% to 5% whenever artificial irrigation incurs labor and expenses.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Toprak ürünlerinde (öşür) bir yıl geçme şartı aranmaz; hasat yapıldığı anda sulama masrafına göre 1/10 veya 1/20 oranında verilir. Küçükbaşta ise 40-120 arası 1, 121-200 arası 2, 201-399 arası 3 koyun zekât vardır.',
        en: 'Agricultural \'Ushr has no one-year waiting rule and is due at harvest (10% rain-fed, 5% costly irrigation). Pasture-fed sheep/goats begin at 40 (1 animal) up to 120.',
      ),
      sourceRef: LocalizedText(
        tr: 'En\'âm, 6/141; Buhârî, Zekât 38, 55; Diyanet İlmihali Cilt 1, s. 436-455',
        en: 'Al-An\'am 6:141; Bukhari, Zakat 38, 55; Diyanet Catechism Vol. 1, pp. 436-455',
      ),
      linkedFarzId: 9,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_21',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Tevbe Sûresi 60. âyette sayılan sekiz sınıfa dâhil olsalar bile, bir Müslümanın zekâtını kesinlikle veremeyeceği aile yakınları hangi seçenekte doğru sayılmıştır?',
      en: 'Even if financially needy, which close family members may a Muslim NOT pay their obligatory Zakat to?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Fakir olan öz kardeş, amca, hala, dayı, teyze ve bunların çocukları',
          en: 'Needy siblings, paternal/maternal uncles and aunts, and cousins',
        ),
        LocalizedText(
          tr: 'Usûl (anne, baba, dede, nine), fürû (çocuklar, torunlar) ve eşler',
          en: 'Ascendants (parents, grandparents), descendants (children, grandchildren), and spouses',
        ),
        LocalizedText(
          tr: 'Aynı şehirde yaşamayan uzak akrabalar ve ilim talebeleri',
          en: 'Distant relatives residing elsewhere and full-time religious students',
        ),
        LocalizedText(
          tr: 'Geliri borçlarını karşılamayan komşular ile gelin ve damatlar',
          en: 'Indebted neighbors, sons-in-law, and daughters-in-law in need',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Kişinin doğrudan alt-üst soyu ile kendi eşine bakmak zaten aslî görevi sayıldığından zekât verilmez; kardeş/amca/dayı/halaya verilebilir.',
      en: 'Direct lineage (parents/children) and spouses cannot receive Zakat; siblings, aunts, uncles, and in-laws can if eligible.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İhtiyaç sahibi kardeş, yeğen, amca, hala, dayı ve teyzeye zekât vermek hem geçerlidir hem de iki kat sevap (zekât + sıla-i rahim) kazandırır. Anne-baba, dede-nine, çocuk-torun ve eşe ise zekât verilmez.',
        en: 'Giving Zakat to needy siblings, aunts, uncles, or in-laws earns a dual reward of charity and kinship care; direct ascendants, descendants, and spouses are excluded.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe, 9/60; Tirmizî, Zekât 26; Diyanet İlmihali Cilt 1, s. 463-465',
        en: 'At-Tawbah 9:60; Tirmidhi, Zakat 26; Diyanet Catechism Vol. 1, pp. 463-465',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_22',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Haccın temel şart ve rükünleri (İhram, Arafat Vakfesi, Ziyaret Tavafı) dışında kalan aşağıdaki uygulamalardan hangileri Hanefî mezhebine göre haccın vaciplerindendir?',
      en: 'Beyond the core pillars of Hajj (Ihram, Arafat, Tawaf al-Ziyarah), which rites constitute the wajib duties of Hajj in the Hanafi school?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Medine\'de Mescid-i Nebevî ziyareti, Zemzem içmek ve Kudüm tavafı yapmak',
          en: 'Visiting Al-Masjid an-Nabawi in Madinah, drinking Zamzam, and Arrival Tawaf',
        ),
        LocalizedText(
          tr: 'Hira ve Sevr mağaralarını ziyaret etmek ve Mescid-i Cin\'de iki rekât kılmak',
          en: 'Ascending Caves of Hira and Thawr and praying two rak\'ahs at Masjid al-Jinn',
        ),
        LocalizedText(
          tr: 'Yalnızca terviye gününde (8 Zilhicce) Kâbe\'nin etrafında yedi şavt nâfile tavaf yapmak',
          en: 'Performing a seven-round voluntary Tawaf strictly on the 8th of Dhul-Hijjah',
        ),
        LocalizedText(
          tr: 'Müzdelife vakfesi, Safâ-Merve sa\'yi, şeytan taşlama, tıraş/kısaltma ve âfâkîlere veda tavafı',
          en: 'Standing at Muzdalifah, Sa\'y at Safa-Marwa, stoning Jamarat, shaving/trimming, and Farewell Tawaf',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Vaciplerden birinin mazeretsiz terki haccı bozmaz; ancak ceza kurbanı (dem) gerektirir.',
      en: 'Omitting a wajib rite does not invalidate Hajj itself, though an expiatory sacrifice (dam) becomes required.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde Müzdelife vakfesi, Safâ-Merve arasında sa\'y, Mina\'da şeytan taşlamak (remy-i cimâr), saç tıraşı/kısaltmak (halk/taksîr) ve dışarıdan gelenler için Veda (Sader) Tavafı haccın vacipleridir.',
        en: 'In Hanafi fiqh, Muzdalifah standing, Sa\'y, stoning at Mina, shaving/trimming hair, and Farewell Tawaf for non-residents of Makkah are wajib.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/158, 198; Diyanet İlmihali Cilt 1, s. 517-518',
        en: 'Al-Baqarah 2:158, 198; Diyanet Catechism Vol. 1, pp. 517-518',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de Safâ-Merve sa\'yi ve veda tavafı haccın vacibidir.',
        en: 'In Hanafi fiqh, Sa\'y between Safa and Marwa and Farewell Tawaf are wajib.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde Safâ-Merve sa\'yi (ve saç tıraşı/kısaltma) bizzat haccın rükünlerindendir; veda tavafı ise vaciptir.',
        en: 'In Shafi\'i fiqh, Sa\'y (and hair shaving/trimming) are integral pillars (rukn) of Hajj, while Farewell Tawaf is wajib.',
      ),
      linkedFarzId: 11,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_23',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İhramlı iken hastalık veya zorunlu bir mazeret sebebiyle vakti gelmeden başını tıraş etmek ya da dikişli elbise giymek zorunda kalan hacı adayı, Bakara Sûresi 196. âyete göre hangi muhayyer fidyeyi (ezâ fidyesi) öder?',
      en: 'Under Surah Al-Baqarah 2:196, if illness or necessity forces a pilgrim in Ihram to shave or wear stitched clothing, which optional penalty (fidyah) may be chosen?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bir koyun/keçi kesmek (dem), altı fakiri doyurmak veya üç gün oruç tutmak seçeneklerinden birini',
          en: 'Sacrificing one sheep/goat, feeding six needy people, or fasting three days (any one option)',
        ),
        LocalizedText(
          tr: 'İhramı tamamen bozulmuş sayıldığından haccı terk edip memleketine geri dönmek ve ertesi yıl kaza etmek',
          en: 'Canceling the pilgrimage entirely, returning home, and repeating Hajj the following year',
        ),
        LocalizedText(
          tr: 'Peş peşe altmış gün kefâret orucu tutmak ve ardından bir deve kurban etmek',
          en: 'Fasting sixty consecutive days alongside sacrificing one camel inside the Haram',
        ),
        LocalizedText(
          tr: 'Yalnızca yüz kez istiğfar okuyup iki rekât tevbe namazı kılmakla yetinmek',
          en: 'Merely reciting Istighfar a hundred times and praying two rak\'ahs of repentance',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Âyet-i kerîmede "...orucu, yahut sadakayı, yahut kurbanı fidye olarak versin" buyrularak mazeretliye üç seçenekli kolaylık tanınmıştır.',
      en: 'The verse grants three flexible options: fasting, charity (feeding six poor), or sacrifice (nusuk).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İhram yasaklarının mazeret veya zorunlulukla ihlalinde kişi günahkâr olmaz ve muhayyerlik hakkına sahiptir: Harem\'de bir koyun/keçi kurban keser, yahut altı fakiri sabah-akşam doyurur (6 fitre miktarı), yahut üç gün oruç tutar.',
        en: 'When necessity compels breaking an Ihram restriction (shaving, stitched dress, covering head), no sin is incurred and the pilgrim freely selects one of the three Qur\'anic remedies.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/196; Buhârî, Muhsar 5; Diyanet İlmihali Cilt 1, s. 542-543',
        en: 'Surah Al-Baqarah, 2:196; Bukhari, Muhsar 5; Diyanet Catechism Vol. 1, pp. 542-543',
      ),
      linkedFarzId: 11,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_24',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Udhiyye olarak kesilecek kurbanlık hayvanların cinsi, kamerî asgarî yaş şartı ve en fazla hisse (ortaklık) sınırı hangi seçenekte doğru verilmiştir?',
      en: 'Which option accurately states the species, minimum lunar age, and maximum shared ownership limits for sacrificial animals (Udhiyyah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Koyun 2 yaş (7 ortak); sığır/manda 3 yaş (10 ortak); deve 6 yaş (10 ortak)',
          en: 'Sheep 2 yrs (7 shares); cattle 3 yrs (10 shares); camel 6 yrs (10 shares)',
        ),
        LocalizedText(
          tr: 'Koyun ve keçi 1 yaş (2 ortak); sığır ve manda 1 yaş (5 ortak); deve 4 yaş (5 ortak)',
          en: 'Sheep/goat 1 yr (2 shares); cattle 1 yr (5 shares); camel 4 yrs (5 shares)',
        ),
        LocalizedText(
          tr: 'Koyun/keçi 1 yaş (6 aylık gösterişli kuzu hariç) 1 kişi; sığır/manda 2 yaş (1-7 kişi); deve 5 yaş (1-7 kişi)',
          en: 'Sheep/goat 1 yr (or plump 6-mo lamb) 1 person; cattle 2 yrs (1-7 shares); camel 5 yrs (1-7 shares)',
        ),
        LocalizedText(
          tr: 'Yalnızca koyun ve sığır kurban edilebilir; ortaklık en çok 3 kardeşle sınırlıdır',
          en: 'Only sheep and cattle are valid for Udhiyyah, with sharing limited to three brothers',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Küçükbaş (koyun/keçi) yalnız 1 kişi adına kesilir; büyükbaş (sığır/manda/deve) ise 1\'den 7\'ye kadar kişiyle ortak kesilebilir.',
      en: 'Sheep and goats cover a single individual, while cattle and camels allow 1 to 7 partners.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Koyun ve keçi kamerî 1 yaşını doldurmalıdır (ancak 6 ayını tamamlamış kuzu bir yaşındakiler gibi iri ve gösterişli ise kurban olur; keçide bu istisna yoktur). Büyükbaş hayvanlarda tüm ortakların kurban/ibadet niyeti taşıması şarttır.',
        en: 'Sheep/goats must be one lunar year old (a 6-month lamb as large as a yearling is valid in Hanafi fiqh, unlike goats). Cattle (2 yrs) and camels (5 yrs) may be shared by up to 7 believers each intending worship.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Edâhî 13; Diyanet İlmihali Cilt 2 (Kurban)',
        en: 'Muslim, Adahi 13; Diyanet Catechism Vol. 2 (Sacrifice)',
      ),
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_o_25',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Kesilen kurbanın derisi, başı veya etinden bir parçası kesim işçiliği karşılığı olarak kasaba ücret yerine verilebilir.',
      en: 'The hide, head, or a portion of the sacrificial meat may be given to the butcher as payment for slaughtering.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Hz. Ali (r.a.), Peygamber Efendimizin (s.a.v.) kurbandan hiçbir parçayı kasap ücreti olarak vermeyi yasakladığını bildirmiştir (Müslim, Hac 348).',
      en: '\'Ali (r.a.) narrated that the Prophet (ﷺ) strictly forbade giving any part of the sacrifice to the butcher as wages.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kurban Allah\'a adanmış bir ibadet olduğundan hiçbir parçası ticarî takas veya işçilik ücretine konu edilemez. Kasap ücreti ayrıca ödenir; kurban derisi ya ev eşyası gibi kullanılır ya da yoksullara ve hayır kurumlarına bağışlanır.',
        en: 'Because the sacrificed animal is dedicated to Allah, no part of it may serve as commercial wages. The butcher is paid separately, and the hide is donated or utilized personally without selling for personal gain.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Hac 120; Müslim, Hac 348; Diyanet İlmihali Cilt 2 (Kurban)',
        en: 'Bukhari, Hajj 120; Muslim, Hajj 348; Diyanet Catechism Vol. 2 (Sacrifice)',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 25 QUESTIONS (dilm_i_01..dilm_i_25)
  // =========================================================================
  IrfanQuestion(
    id: 'dilm_i_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Ehl-i Sünnet kelâmının iki ana ekolü olan Mâtürîdiyye ile Eş\'ariyye arasındaki temel sıfat farklılıklarından biri "Tekvîn" (yaratma) sıfatıdır. Mâtürîdî âlimleri Tekvîn\'i nasıl temellendirir?',
      en: 'How do Maturidi theologians conceptualize the attribute of Originating/Creating (Takwin) compared to the Ash\'ari school?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kudret ve İrâde\'nin hâdis bir neticesi olup Allah\'ın ezelî sıfatları arasında yer almadığını savunurlar',
          en: 'They hold it is a temporal outcome rather than an eternal attribute of Allah',
        ),
        LocalizedText(
          tr: 'Kudret ve İrâde\'den ayrı, müstakil ve ezelî sekizinci sübûtî sıfat olarak kabul ederler',
          en: 'They affirm it as an eighth distinct, eternal affirmative attribute separate from Power and Will',
        ),
        LocalizedText(
          tr: 'Tekvîn sıfatını yalnızca Vahdâniyyet ve Kıdem gibi Zâtî (Selbî) sıfatlar arasında sayarlar',
          en: 'They classify Takwin exclusively among the six Negating Personal attributes',
        ),
        LocalizedText(
          tr: 'Eş\'arîler gibi bağımsız bir sıfat olmadığını söyleyip yalnızca Kelâm sıfatının şubesi sayarlar',
          en: 'Like Ash\'aris, they treat it as non-distinct, viewing it merely as a branch of Divine Speech',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Eş\'ariyye Tekvîn\'i Kudret sıfatının yaratmaya taalluku olarak izah ederken, Mâtürîdiyye bunu "Kün fe-yekûn" (Ol der ve olur) hakikatiyle müstakil ezelî sıfat sayar.',
      en: 'While Ash\'aris explain it via the relation of Power (Qudrah), Maturidis establish Takwin as the eighth eternal attribute.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmam Mâtürîdî ve takipçileri, Allah\'ın yaratma kudretine sahip olmasının yanı sıra fiilî yaratmayı gerçekleştiren ezelî "Tekvîn" sıfatına da sahip olduğunu belirtir; sıfatın ezelî olması yaratılan âlemin ezelî olmasını gerektirmez.',
        en: 'Maturidis affirm Takwin as an eternal attribute alongside Power and Will, distinguishing eternal divine creativity from the temporal created cosmos; both Sunni schools uphold Allah as sole Creator.',
      ),
      sourceRef: LocalizedText(
        tr: 'Yâsîn, 36/82; Mâtürîdî, Kitâbü\'t-Tevhîd; Diyanet İlmihali Cilt 1, s. 72-73',
        en: 'Ya-Sin 36:82; Al-Maturidi, Kitab at-Tawhid; Diyanet Catechism Vol. 1, pp. 72-73',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_maturidi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Ehl-i Sünnet akaidine göre, helâl saymadığı (istihlâl etmediği) hâlde büyük günah (kebîre) işleyen ve tövbe etmeden vefat eden bir müminin durumu hakkında hangisi doğrudur?',
      en: 'According to Sunni creed (Ahl as-Sunnah), what is the ruling on a believer who commits a major sin without considering it lawful and dies without repentance?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hâricîlere benzer biçimde büyük günahla birlikte derhâl imandan çıkıp kâfir olur',
          en: 'As held by the Kharijites, major sin immediately expels the believer into disbelief',
        ),
        LocalizedText(
          tr: 'Mu\'tezile görüşü gereği ne mümin ne kâfir sayılır; "el-menzile beyne\'l-menzileteyn"dedir',
          en: 'Enters the Mu\'tazili intermediate station, neither believer nor disbeliever',
        ),
        LocalizedText(
          tr: 'İman var oldukça işlenen günahların dünyada ve âhirette kula hiçbir zarar vermeyeceği kabul edilir',
          en: 'As long as faith exists, sins incur no moral harm or punishment whatsoever',
        ),
        LocalizedText(
          tr: 'İman dairesinden çıkmaz, günahkâr (fâsık) mümin sayılır; âhirette Allah\'ın meşîeti altındadır',
          en: 'Remains a sinful believer (fasiq) without exiting faith; ultimately under Allah\'s will and mercy',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Amel, imanın varlık/sıhhat şartı değil kemâl şartıdır; tövbe kapısı ise son nefese kadar açıktır.',
      en: 'Deeds are conditions for perfection of faith, not its minimal existence; Allah forgives whatever He wills short of unrepentant shirk.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hâricîler büyük günah işleyeni tekfir etmiş, Mu\'tezile ise ebedî cehennemlik görmüştür. Ehl-i Sünnet ise Kur\'ân ve Sünnet\'e dayanarak kalbinde iman olanın günahla kâfir olmayacağını, Allah\'ın isterse affedeceğini yahut günahı kadar azap sonrası cennete koyacağını öğretir.',
        en: 'Sunni orthodoxy rejects both Kharijite excommunication and Mu\'tazili eternal damnation of sinful believers: a sinful Muslim stays within Iman and rests under Allah\'s forgiveness or finite justice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ, 4/48; Hucurât, 49/9; Diyanet İlmihali Cilt 1, s. 87-90',
        en: 'An-Nisa 4:48; Al-Hujurat 49:9; Diyanet Catechism Vol. 1, pp. 87-90',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_maturidi',
      linkedZikirKey: 'İstiğfar',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Kelâm ilminde "Hüsün ve Kubuh" (iyilik ve kötülüğün mahiyeti ile akılla bilinmesi) meselesinde Mâtürîdiyye ekolünün temel yaklaşımı hangisidir?',
      en: 'In Islamic theology, what is the Maturidi school\'s position on "Husn and Qubh" (whether good and evil can be grasped by human reason)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Akıl, peygamber tebliği öncesinde dahi Allah\'ın varlığını ve temel ahlâkî iyi-kötüleri idrak edebilir; ibadet şekilleri ise yalnız vahiyle bilinir',
          en: 'Reason can perceive Allah\'s existence and foundational moral truths even before revelation; worship details require revelation',
        ),
        LocalizedText(
          tr: 'İyilik ve kötülük sadece örf ve geleneklerden doğar; akıl ve vahyin bu konuda hiçbir ölçüsü yoktur',
          en: 'Good and evil arise purely from social custom, with neither intellect nor revelation providing objective standards',
        ),
        LocalizedText(
          tr: 'Vahiy gelmeden önce aklın Allah\'ın varlığına ve zulmün çirkinliğine ulaşması imkânsızdır',
          en: 'Human intellect is wholly incapable of recognizing the Creator or the evil of injustice prior to revelation',
        ),
        LocalizedText(
          tr: 'İnsan aklı ibadet vakitlerini ve rekât sayılarını bile peygamber gönderilmeden kendi başına belirleyebilir',
          en: 'Human reason can independently deduce exact prayer times and rak\'ah counts without needing prophets',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Mâtürîdî\'ye göre akıl Allah\'a inanmayı ve nimetine şükrün gerekliliğini bilebilir; ancak namazın, orucun şekil ve miktarını yalnız vahiy bildirir.',
      en: 'Reason knows gratitude to the Creator and justice are good; only revelation teaches how to pray and fast.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Eş\'arîler dinî sorumluluk (teklif) için mutlaka peygamber davetinin ulaşmasını şart koşarken; Mâtürîdîler akıl sahibi bir kimsenin peygamber tebliğine muhatap olmasa bile kâinata bakarak Yaradan\'ı tanımakla yükümlü olduğunu ifade eder.',
        en: 'Unlike Ash\'aris who tie all accountability strictly to prophetic message arrival, Maturidis hold that sound intellect can grasp tawhid and basic morality, while religious rites remain strictly revealed.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 65-67',
        en: 'Diyanet Catechism Vol. 1, pp. 65-67',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_maturidi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Fıkıh usûlünde normal şartlarda bütün mükellefler için konulan aslî hükme "Azîmet" denirken; su bulunmadığında niyetle Teyemmüm yapmak veya seferde namazı kısaltmak gibi arızî mazeretlere bağlı kolaylaştırıcı hükme ne ad verilir?',
      en: 'In Usul al-Fiqh, while general rules binding under normal conditions are "Azimah," what are exceptional eases linked to valid excuses—like performing Tayammum with intention or shortening travel prayers?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Taabbüd (hikmeti akılla kavranamayan hüküm)',
          en: 'Ta\'abbud (purely devotional decree)',
        ),
        LocalizedText(
          tr: 'İhtiyat (şüphe hâlinde en ağır olanı tercih)',
          en: 'Ihtiyat (precautionary strictness)',
        ),
        LocalizedText(
          tr: 'Ruhsat (mazerete bağlı kolaylaştırıcı hüküm)',
          en: 'Rukhsah (excuse-based legal concession)',
        ),
        LocalizedText(
          tr: 'Takrîr (sükûtla onaylanan Sünnet hükmü)',
          en: 'Taqrir (tacit Prophetic approval)',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Peygamber Efendimiz (s.a.v.) "Allah azîmetlerinin yapılmasını sevdiği gibi ruhsatlarının işlenmesini de sever" buyurmuştur.',
      en: 'The Prophet (ﷺ) taught that Allah loves His concessions (rukhsah) to be accepted just as His regular laws.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Abdestte su kullanmak azîmet, suyun yokluğunda veya sağlığa zararlı olduğu yerde niyet ederek temiz toprakla Teyemmüm (#19) yapmak ise rahmete dayalı ruhsattır. Zaruret ve hastalık hâlinde ruhsatla amel etmek hem meşru hem edebe uygundur.',
        en: 'Using water for Wudu is Azimah; turning with sincere intention to clean earth (Tayammum) when water is missing or harmful is a divine Rukhsah protecting life and ease in worship.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide, 5/6; Bakara, 2/185; Diyanet İlmihali Cilt 1, s. 29-30, 210-212',
        en: 'Al-Ma\'idah 5:6; Al-Baqarah 2:185; Diyanet Catechism Vol. 1, pp. 29-30, 210-212',
      ),
      linkedFarzId: 19,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî fıkıh usûlünde ibadetlerde "fâsid" ile "bâtıl" aynı sonucu (geçersizliği) doğurduğu hâlde, satım ve borçlar hukuku (muâmelât) akitlerinde nasıl bir ayrım yapılır?',
      en: 'While Hanafi fiqh treats "fasid" and "batil" identically in acts of worship (invalid), what distinction does it draw between them in financial contracts?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Fâsid akit tam ve bağlayıcı sayılırken, bâtıl akit ise yalnızca hakimin onayından sonra düzeltilir',
          en: 'A fasid contract is fully binding as valid, whereas a batil one awaits judicial approval',
        ),
        LocalizedText(
          tr: 'Rüknü/kuruluş şartı eksik olan akit "bâtıl", rüknü tam olup ayrılmaz vasfında (faiz şartı vb.) aykırılık bulunan akit "fâsid"dir',
          en: 'A contract lacking an essential pillar is "batil" (void); one with valid pillars yet a flawed attached term is "fasid" (defective)',
        ),
        LocalizedText(
          tr: 'Muâmelâtta yalnız şahit eksikliğine bâtıl, yazılı sözleşme olmamasına ise fâsid adı verilir',
          en: 'Missing witnesses renders a sale batil, while unwritten agreements are solely fasid',
        ),
        LocalizedText(
          tr: 'Hanefî mezhebinde satım akdinin rüknü ve vasfı ayrılmaz olduğundan yalnızca bâtıl kavramı kullanılır',
          en: 'Hanafi jurisprudence rejects any difference between pillar and attribute in sales, using only batil',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Fâsid akit fesat sebebi (örneğin meçhul vade veya fasit şart) taraflarca giderildiğinde sahih hâle dönüşebilir; bâtıl akit ise baştan yok hükmündedir.',
      en: 'A fasid contract can become sound once the defect is removed, whereas a batil contract produces no legal effect at all.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîlerin bu ince ayrımı ticaret hayatını korur: Bir akdin esası (taraflar, îcap-kabul ve helâl mal) sağlam olup eklenen faiz veya belirsizlik gibi bir vasfında bozukluk varsa fâsid sayılır ve o şart kaldırılınca akit kurtarılabilir.',
        en: 'This subtle Hanafi distinction balances legal integrity with commercial continuity: if core pillars hold and a defective clause is purged, the contract becomes valid.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 31-32 & Cilt 2 (Muâmelât)',
        en: 'Diyanet Catechism Vol. 1, pp. 31-32 & Vol. 2 (Transactions)',
      ),
      linkedFarzId: 26,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Mâide Sûresi 6. âyet ışığında abdestin rükünleri (farzları) tespit edilirken Hanefî ve Şâfiî mezhepleri arasında çıkan 4 farz – 6 farz farkı hangi iki esastan kaynaklanır?',
      en: 'From Surah Al-Ma\'idah 5:6, what two additional elements account for the Shafi\'i school counting 6 fards in Wudu compared to the Hanafi school\'s 4 fards?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şâfiî mezhebinde dört uzvun yıkanması yanında başlangıçta "niyet" ve uzuvları âyet sırasıyla yıkamak olan "tertip" de farzdır',
          en: 'Shafi\'i fiqh adds "niyyah" (intention) at the start and "tartib" (Qur\'anic sequence) of limbs as fards alongside the four limbs',
        ),
        LocalizedText(
          tr: 'Şâfiî mezhebinde mazmaza (ağza su verme) ve istinşak (burna su çekme) abdestin beşinci ve altıncı farzlarıdır',
          en: 'Shafi\'i fiqh counts rinsing the mouth and nose as the fifth and sixth fards of Wudu',
        ),
        LocalizedText(
          tr: 'Şâfiî mezhebinde kulakları yıkamak ve ayak parmaklarını hilâllemek abdestin müstakil iki farzı kabul edilir',
          en: 'Shafi\'i fiqh elevates washing the ears and interlacing toes to independent fard pillars',
        ),
        LocalizedText(
          tr: 'Hanefîlerde abdesti her vakit yenilemek farz iken, Şâfiîlerde uzuvları üçer defa yıkamak farzdır',
          en: 'Hanafis require renewing Wudu every prayer time, while Shafi\'is mandate washing every limb thrice as fard',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hanefîler Mâide 6\'daki dört fiil (yüz, kollar, başın meshi, ayaklar) ile yetinip niyet ve sırayı sünnet görür; Şâfiîler ise hadis ve âyet tertibinden dolayı bunları farz sayar.',
      en: 'Hanafis treat intention and limb order as Sunnah in Wudu; Shafi\'is obligate both.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde yağmur altında veya suya dalarak abdest azalarını yıkayan kimse niyet etmese bile hükmen abdestli olur (ancak sevap için niyet sünnettir). Şâfiî\'de ise başlarken niyet ve yüz-kol-baş-ayak sırası (tertip) olmazsa abdest sahih olmaz.',
        en: 'In Hanafi fiqh, washing the four parts lifts minor impurity even without prior intention (though Sunnah for reward), whereas Shafi\'i fiqh invalidates Wudu if intention or proper sequence is skipped.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide, 5/6; Diyanet İlmihali Cilt 1, s. 193-196',
        en: 'Al-Ma\'idah 5:6; Diyanet Catechism Vol. 1, pp. 193-196',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de abdestin 4 farzı vardır; niyet ve tertip (sıraya uymak) müekked sünnettir.',
        en: 'Hanafi Wudu has 4 fards; intention and limb order are emphasized Sunnahs.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de abdestin 6 farzı vardır: 1) Niyet, 2) Yüzü yıkamak, 3) Kolları dirseklerle yıkamak, 4) Başı (bir kısmını) meshetmek, 5) Ayakları topuklarla yıkamak, 6) Tertip.',
        en: 'Shafi\'i Wudu has 6 fards: 1) Intention, 2) Face, 3) Arms with elbows, 4) Wiping part of head, 5) Feet with ankles, 6) Sequence (Tartib).',
      ),
      linkedFarzId: 12,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Hanefî mezhebinde guslün farzları 3 (mazmaza, istinşak ve bütün bedeni yıkamak) iken, Şâfiî mezhebinde istinşak ile mazmazanın hükmü nedir ve guslün iki farzı hangileridir?',
      en: 'While Hanafi fiqh counts 3 fards in Ghusl (mouth, nose, whole body), what is the Shafi\'i ruling on rinsing mouth and nose, and what are Shafi\'i Ghusl\'s 2 fards?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şâfiî\'de de mazmaza ve istinşak farz olup gusülde ayrıca tertip (sıra) dördüncü farz kabul edilir',
          en: 'Shafi\'i also obligates mouth and nose rinsing and adds sequence as a fourth fard',
        ),
        LocalizedText(
          tr: 'Şâfiî\'de guslün farzı yalnızca bütün bedeni yıkamaktır; niyet, mazmaza ve istinşakın tamamı sünnettir',
          en: 'Shafi\'i counts only one fard (washing the body), classifying intention, mouth, and nose all as Sunnah',
        ),
        LocalizedText(
          tr: 'Her iki mezhepte de yalnız cünüplük guslünde istinşak farzdır; hayız guslünde ise niyetle beraber sünnettir',
          en: 'Both schools require nasal rinsing exclusively in Janabah Ghusl while waiving it in post-hayd Ghusl',
        ),
        LocalizedText(
          tr: 'Şâfiî\'de mazmaza ve istinşak sünnettir; guslün iki farzı ise niyet etmek ve bütün bedeni yıkamaktır',
          en: 'In Shafi\'i fiqh mouth and nose rinsing are Sunnah; its two fards are intention and washing the entire exterior body',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Hanefî\'ye göre ağız ve burun içi temizlenebilir dış organ sayılırken; Şâfiî\'ye göre vücudun içi hükmündedir ve gusülde niyet şartı öne çıkar.',
      en: 'Hanafis treat mouth/nostrils as exterior surfaces requiring washing in Ghusl, while Shafi\'is treat them as interior and prioritize intention.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İki büyük mezhebin bu farkına rağmen her Müslümanın gusle niyetle başlaması, mazmaza ve istinşak yapıp bütün bedenini yıkaması her iki mezhebe göre de hem sahih hem kâmil guslü garanti eder.',
        en: 'Beginning Ghusl with clear intention, rinsing the mouth and nostrils thoroughly, and washing the entire exterior body satisfies both Hanafi and Shafi\'i requirements seamlessly.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 205-206',
        en: 'Diyanet Catechism Vol. 1, pp. 205-206',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de guslün farzları: Mazmaza, istinşak ve bütün bedeni kuru yer kalmadan yıkamak (niyet sünnettir).',
        en: 'Hanafi fards: rinsing mouth, rinsing nose, washing entire body (intention is Sunnah).',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de guslün farzları: Niyet etmek ve bütün dış bedeni yıkamak (mazmaza ve istinşak sünnettir).',
        en: 'Shafi\'i fards: intention and washing the entire outer body (mouth and nose rinsing are Sunnah).',
      ),
      linkedFarzId: 17,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî fıkhında üzerinde vitir hariç 5 vakitten (vitirle 6 vakitten) az kazaya kalmış namazı bulunan "Sâhib-i Tertîp" bir kimse, vaktin namazını kılmadan önce ne yapmakla yükümlüdür?',
      en: 'In Hanafi fiqh, what must a "Sahib at-Tartib" (a person owing fewer than 6 missed obligatory prayers including Witr) observe before praying the current time\'s prayer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kazaya kalan namazları yalnız sabah ve yatsı arasında dilediği sırayla kılabilir, vakit önceliği gerekmez',
          en: 'May perform missed prayers in any sequence solely between Isha and Fajr with no time-order rule',
        ),
        LocalizedText(
          tr: 'Kaza namazı borcu olan kimsenin vaktin namazlarını tek başına kılması caiz olmayıp cemaate yetişmesi şarttır',
          en: 'One who owes any missed prayer cannot pray current prayers alone and must attend congregation',
        ),
        LocalizedText(
          tr: 'Unutma veya vaktin daralması gibi mazereti yoksa önce kazaya kalan namazını, ardından vaktin namazını kılmalıdır',
          en: 'Unless forgetful or pressed by closing time, must make up the missed prayer before praying the current one',
        ),
        LocalizedText(
          tr: 'Kazaya kalan her vakit namazı için ayrıca ikişer rekât nafile kefâret namazı kılmak zorundadır',
          en: 'Must add two voluntary expiatory rak\'ahs before making up each missed fard prayer',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Üzerindeki kazalar vitir hariç 6 vakte ulaşırsa, kazasını hatırlamadan kılarsa veya vaktin çıkmasından korkarsa tertip yükümlülüğü düşer.',
      en: 'Strict sequence lapses if missed prayers reach 6, if one forgets during prayer, or if time is about to expire.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde sâhib-i tertîp olan kimse (örneğin yalnız dünkü ikindiyi kaçırmış biri) bugünkü namazları kılmadan önce kazasını kılmalıdır; unutarak vaktin namazını kılarsa namazı sahih kalır, hatırlayınca kazayı kılar. Kaza sayısı 6\'ya ulaşınca tertip sâkıt olur.',
        en: 'For a Sahib at-Tartib, order between a few missed prayers and current ones preserves discipline; yet three excuses—forgetting, narrow time, or 6+ accumulated prayers—relieve that strict order.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 291-292',
        en: 'Diyanet Catechism Vol. 1, pp. 291-292',
      ),
      linkedFarzId: 25,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre ikindi ve yatsı namazlarının dört rekâtlı gayr-i müekked ilk sünnetleri kılınırken, öğle ilk sünneti (müekked) gibi olan namazlardan ayrılan başlıca kıraat/dua farkı nedir?',
      en: 'In Hanafi fiqh, how do the four-rak\'ah non-emphasized (ghayr mu\'akkadah) Sunnahs of \'Asr and \'Isha differ internally from the emphasized Sunnah before Dhuhr?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İlk oturuşta yalnız Ettehiyyâtü okunur; 3. ve 4. rekâtlarda ise Fâtiha\'dan sonra zamm-ı sûre okunmaz',
          en: 'Only At-Tahiyyat is recited in the first sitting, and no additional passage follows Fatihah in rak\'ahs 3 and 4',
        ),
        LocalizedText(
          tr: 'İlk oturuşta Ettehiyyâtü\'den sonra Salli-Bârik okunur; 3. rekâta kalkınca Sübhâneke ve Eûzü-Besmele okunur',
          en: 'In the first sitting Salawat follow At-Tahiyyat, and upon rising to the 3rd rak\'ah Subhanaka and Ta\'awwudh are recited',
        ),
        LocalizedText(
          tr: 'İki rekâtta bir mutlaka selâm verilerek iki ayrı namaz şeklinde kılınması vaciptir',
          en: 'They must obligatorily be broken into two separate 2-rak\'ah prayers with Taslim in between',
        ),
        LocalizedText(
          tr: 'Yalnızca ilk iki rekâtta ayakta kıraat yapılır, son iki rekâtta ise oturarak rükû ve secde edilir',
          en: 'Standing recitation occurs only in the first two rak\'ahs, while the final two are prayed seated',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Gayr-i müekked dörtlü sünnetlerde her iki rekâtı müstakil bir iki rekâtlı namaz gibi başa alarak Sübhâneke/Salli-Bârik okunur.',
      en: 'Each pair of rak\'ahs in a non-emphasized 4-rak\'ah Sunnah begins and sits like a self-contained 2-rak\'ah unit.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İkindi ve yatsının ilk sünnetleri gayr-i müekkede olup her iki rekâtı bağımsız nafile hükmünde görülür: İlk oturuşta Ettehiyyâtü + Allahümme salli + Allahümme bârik okunur; 3. rekâta kalkınca tıpkı 1. rekât gibi Sübhâneke, Eûzü-Besmele, Fâtiha ve sûre ile başlanır.',
        en: 'Because Hanafis treat each pair in non-emphasized 4-rak\'ah Sunnahs (\'Asr & \'Isha pre-fard) as independent units, Salawat are recited in the middle sitting and Subhanaka opens the 3rd rak\'ah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet İlmihali Cilt 1, s. 295',
        en: 'Diyanet Catechism Vol. 1, p. 295',
      ),
      linkedFarzId: 32,
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre vakti çıktıktan sonra kaza edilebilen tek sünnet namaz ve bunun geçerli olduğu vakit aralığı hangisidir?',
      en: 'According to the Hanafi school, which Sunnah prayer is uniquely eligible to be made up after its time expires, and within what time window?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Öğlenin ilk dört rekât sünneti ikindi namazından sonra kaza edilebilir',
          en: 'The four-rak\'ah Sunnah before Dhuhr may be made up after \'Asr prayer',
        ),
        LocalizedText(
          tr: 'Akşamın iki rekât son sünneti ertesi günün öğle vaktinde kaza edilebilir',
          en: 'The two-rak\'ah Sunnah after Maghrib may be made up at Dhuhr next day',
        ),
        LocalizedText(
          tr: 'Yatsının dört rekâtlık ilk sünneti sabah namazı kılındıktan sonra kaza edilebilir',
          en: 'The four-rak\'ah Sunnah before \'Isha may be made up after Fajr prayer',
        ),
        LocalizedText(
          tr: 'Sabah namazı güneş doğup kerâhet çıktıktan sonra zevale kadar kaza edilirken sünneti de farzıyla kaza edilir',
          en: 'Fajr Sunnah is made up together with Fajr fard after sunrise kerahah ends until before Dhuhr zenith',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Sabah sünneti bütün sünnetler içinde en kuvvetli olanıdır; güneş doğduktan ~45 dk sonra başlar ve öğle kerâhetine (zevalden ~45 dk önce) kadar farzla beraber kılınır.',
      en: 'Fajr\'s two Sunnahs hold exceptional Prophetic emphasis and accompany the Fajr make-up before noon.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîlerde sünnet namazlar vaktinde kılınmadığında sonradan kaza edilmez. Bunun tek istisnası sabah namazının sünnetidir: Aynı gün zevalden önce kaza edilen sabah farzıyla birlikte sabah sünneti de kaza edilir (yalnız sünnet kaçmışsa farzdan sonra kerâhet çıkınca da kılınabileceği İmam Muhammed\'den rivayet edilir).',
        en: 'While Hanafis generally do not make up missed Sunnahs, Fajr\'s two Sunnahs are made up alongside Fajr fard before noon zenith. Shafi\'is permit making up all missed daily Sunnahs.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Mesâcid 315; Diyanet İlmihali Cilt 1, s. 293, 297',
        en: 'Muslim, Masajid 315; Diyanet Catechism Vol. 1, pp. 293, 297',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de sabah namazı aynı gün zevalden önce farzıyla beraber sünneti de kaza edilir; öğleden sonraya kalırsa yalnız farzı kaza edilir.',
        en: 'In Hanafi fiqh, Fajr Sunnah accompanies the missed Fajr fard only before solar zenith on that same day.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde sabah dâhil bütün düzenli (revâtib) sünnetler vakitleri çıktıktan sonra da kaza edilebilir.',
        en: 'In Shafi\'i fiqh, all regular daily Sunnah (rawatib) prayers may be made up after their time expires.',
      ),
      linkedFarzId: 25,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Yatsı namazından sonra kılınan Vitir namazının fıkhî hükmü, rekât sayısı ve Kunut duasının yeri konusunda Hanefî ve Şâfiî mezhepleri arasındaki fark hangisinde doğru verilmiştir?',
      en: 'Which option accurately compares the Hanafi and Shafi\'i positions on the ruling, rak\'ah count, and Qunut timing of Witr prayer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hanefî\'de 3 rekât vacip ve kunut yıl boyu 3. rekâtta rükûdan önce okunur; Şâfiî\'de 1-11 rekât sünnet olup kunut Ramazan\'ın ikinci yarısında rükûdan sonradır',
          en: 'Hanafi: 3 wajib rak\'ahs with Qunut year-round before Ruku\'; Shafi\'i: 1-11 Sunnah rak\'ahs with Qunut after Ruku\' in late Ramadan',
        ),
        LocalizedText(
          tr: 'Her iki mezhepte de Vitir namazı yatsının 4 rekâtlık farzının ayrılmaz parçasıdır ve yalnız Ramazan\'da cemaatle kılınır',
          en: 'Both schools require 3 rak\'ahs strictly in Ramadan congregations with no Qunut prayer',
        ),
        LocalizedText(
          tr: 'Şâfiî\'de Vitir 3 rekât vaciptir ve kunut her gece ilk rekâtta okunur; Hanefî\'de ise tek rekâtlı sünnet-i gayr-i müekkededir',
          en: 'Shafi\'i makes Witr 3 wajib rak\'ahs with Qunut in the first rak\'ah, while Hanafi treats it as a single non-emphasized rak\'ah',
        ),
        LocalizedText(
          tr: 'Hanefî\'de Vitir kılınmazsa kazası gerekmez; Şâfiî\'de ise her kaçan vitir için iki rekât kaza farzdır',
          en: 'Hanafis never make up missed Witr, whereas Shafi\'is mandate two make-up rak\'ahs for every missed Witr',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hanefîler "Allah size vitir namazını ziyade etti..." hadisine binaen vitri vacip ve tek selâmla 3 rekât sayar.',
      en: 'Hanafis hold Witr as a connected 3-rak\'ah Wajib with Qunut in the 3rd rak\'ah before Ruku\'.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde Vitir namazı 3 rekât olup vaciptir; kılınamadığında kazası gerekir ve 3. rekâtta kıraatten sonra eller kaldırılıp tekbir alınarak Kunut okunur. Şâfiî\'de ise en az 1, normalde 3 (2+1 selâmla), en çok 11 rekât müekked sünnettir.',
        en: 'Hanafis perform Witr as 3 connected wajib rak\'ahs with Qunut before bowing year-round (and make it up if missed); Shafi\'is pray 1 to 11 Sunnah rak\'ahs, reciting Qunut after bowing in Ramadan\'s second half.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Vitir 1; Tirmizî, Vitir 1-10; Diyanet İlmihali Cilt 1, s. 298-299',
        en: 'Abu Dawud, Witr 1; Tirmidhi, Witr 1-10; Diyanet Catechism Vol. 1, pp. 298-299',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de tek selâmla 3 rekât kılınır, 3. rekâtta Fâtiha ve sûreden sonra "Allâhü ekber" denip eller bağlanarak Kunut duaları okunur; vacip olduğundan kazası gerekir.',
        en: 'Hanafi Witr is 3 connected wajib rak\'ahs; Qunut is recited before Ruku\' in the 3rd rak\'ah and missed Witr must be made up.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de ikişer rekâtta selâm verip sonunda 1 tek rekât kılmak efdaldir; Ramazan\'ın 16. gecesinden itibaren 3. rekât rükûundan kalkınca kunut okunur.',
        en: 'Shafi\'i Witr is an emphasized Sunnah (best prayed as pairs plus one odd rak\'ah), with Qunut after Ruku\' from 16 Ramadan.',
      ),
      linkedFarzId: 28,
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Şâfiî mezhebinde seferde iki namazı ilk vaktinde birleştirerek kılma (Cem\'-i Takdîm) ruhsatı uygulanırken aşağıdakilerden hangisi geçerlilik şartlarındandır?',
      en: 'In Shafi\'i jurisprudence, when combining two prayers early during travel (Jam\' at-Taqdim), which condition is required for validity?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İkinci namazı (örneğin ikindiyi) önce kılıp ardından ilk vaktin namazını (öğleyi) kılmak',
          en: 'Performing the later prayer (\'Asr) first, followed by the earlier one (Dhuhr)',
        ),
        LocalizedText(
          tr: 'İki namaz arasında dünya işleriyle yarım saat meşgul olduktan sonra ikinci namaza başlamak',
          en: 'Inserting a thirty-minute break for worldly chores between the two combined prayers',
        ),
        LocalizedText(
          tr: 'Önce ilk vaktin namazını kılmak, o namaz bitmeden cem\'e niyet etmek ve iki namazı peş peşe kılmak',
          en: 'Praying the first prayer first, intending the combination before finishing it, and performing the second immediately after',
        ),
        LocalizedText(
          tr: 'Cem\' yapılan vakitte öğle ile akşam namazlarını dörder rekât olarak tek kamette birleştirmek',
          en: 'Combining Dhuhr and Maghrib together within a single Iqamah for four rak\'ahs total',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Hanefî mezhebi ise hakikî cem\'i yalnız hacda Arafat (öğle-ikindi takdîm) ve Müzdelife (akşam-yatsı te\'hîr) ile sınırlar.',
      en: 'In Shafi\'i fiqh Jam\' at-Taqdim requires chronological sequence, timely intention, and continuity; Hanafis limit real combining to Hajj.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Şâfiî mezhebinde seferî kimse öğle-ikindi ile akşam-yatsıyı cem\'-i takdîm (ilk vakitte) veya cem\'-i te\'hîr (ikinci vakitte) ile kılabilir; cem\'-i takdîmde tertip, niyet ve iki namaz arası ara vermeme (muvâlât) şarttır.',
        en: 'In Shafi\'i fiqh, early combining requires keeping proper sequence, making intention before ending the first prayer, and continuous progression into the second; delayed combining requires intending delay during the first prayer\'s time.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Sefer 5; Diyanet İlmihali Cilt 1, s. 324-326',
        en: 'Abu Dawud, Safar 5; Diyanet Catechism Vol. 1, pp. 324-326',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de seferîlikte her namaz kendi vaktinde kılınır; ancak zor durumda ilk namazı vaktinin en sonuna, ikincisini vaktinin en başına alarak "sûrî cem\'" yapılabilir.',
        en: 'Hanafis do not combine outside Arafat/Muzdalifah, though "apparent combining" (praying the first near its end and the second at its start) eases travel.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de geçerli seferde öğle ile ikindi, akşam ile yatsı hakikî olarak tek vakitte (takdîm veya te\'hîrle) birleştirilebilir.',
        en: 'Shafi\'is allow actual combining of Dhuhr-\'Asr and Maghrib-\'Isha on qualifying journeys.',
      ),
      linkedFarzId: 25,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Oruçta niyet vakti inceliği: Hanefî mezhebinde imsaktan sonra da yiyip içmemişse "dahve-i kübrâ"ya (kuşluk sonuna) kadar niyet edilebilen oruçlar ile mutlaka geceden (imsaktan önce) niyet şart olan oruçlar nasıl ayrılır?',
      en: 'In Hanafi fiqh, which fasts allow forming intention up to mid-morning (dahwah al-kubra) if nothing broke the fast, versus fasts strictly requiring intention before Fajr?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Ramazan kazasına öğleye kadar niyet caizdir; Ramazan edâsına ise mutlaka imsaktan önce niyet şarttır',
          en: 'Ramadan make-up fasts allow midday intention, whereas daily Ramadan fasts strictly forbid daylight intention',
        ),
        LocalizedText(
          tr: 'Ramazan edâsı, muayyen adak ve nafilelere dahve-i kübrâya kadar niyet caizdir; kaza, kefâret ve mutlak adağa imsaktan önce şarttır',
          en: 'Current Ramadan, dated vows, and voluntary fasts accept pre-noon intention; make-up, kaffarah, and open vows require pre-Fajr intention',
        ),
        LocalizedText(
          tr: 'Kefâret oruçlarına ikindi vaktine kadar niyet edilebilir; nafile oruçlarda ise niyet mutlaka bir gün önceden yapılır',
          en: 'Kaffarah fasts accept intention until afternoon, while voluntary fasts require intention the previous night',
        ),
        LocalizedText(
          tr: 'Şâfiî mezhebinde farz ve kaza dâhil bütün oruçlar için öğle ezanına kadar niyet geçerli sayılır',
          en: 'In Shafi\'i fiqh, all fasts including obligatory and make-up accept intention up to Dhuhr call',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Dahve-i kübrâ, şer\'î gündüzün (imsak ile iftar arasının) tam yarısıdır (öğleden ~45-60 dk önce); geceden niyet ise en faziletli ve ihtiyatlı yoldur.',
      en: 'Dahwah al-Kubra is the midpoint between imsak and sunset (shortly before Dhuhr); pre-dawn intention remains ideal.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîlerde vakti belirli oruçlar (Ramazan edâ, muayyen adak, nafile) imsaktan sonra hiçbir şey yenilip içilmemişse dahve-i kübrâya kadar niyet edilebilir. Zimmette borç olan (kaza, kefâret, bozulan nafile kazası, mutlak adak) oruçlar için ise mutlaka imsaktan önce tayin ve niyet şarttır.',
        en: 'Time-fixed fasts in Hanafi fiqh permit daylight intention before dahwah if nothing invalidated the fast; non-time-bound debt fasts (qada, kaffarah) require intention before true dawn.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Savm 33; Diyanet İlmihali Cilt 1, s. 387-388',
        en: 'Tirmidhi, Sawm 33; Diyanet Catechism Vol. 1, pp. 387-388',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de Ramazan edâsı için geceden niyet sünnet/evlâ olmakla birlikte uyuyakalıp imsaktan sonra yiyip içmeyen kimse dahve-i kübrâya kadar niyet edebilir.',
        en: 'Hanafis permit forming intention before mid-morning for that day\'s Ramadan fast if nothing was consumed since dawn.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde yalnız nafile oruçlara zevale kadar niyet edilebilir; Ramazan edâsı dâhil tüm farz ve kaza oruçlarında geceden (tebyît) niyet şarttır.',
        en: 'In Shafi\'i fiqh, every obligatory and make-up fast (including daily Ramadan) requires intention made at night before Fajr.',
      ),
      linkedFarzId: 10,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Başlanan nafile bir orucun mazeretsiz olarak bozulması hâlinde, Hanefî mezhebine göre bu orucun kaza edilmesi vacip iken Şâfiî mezhebine göre kaza gerekmez.',
      en: 'If a voluntary (nafilah) fast is deliberately broken after starting without a valid excuse, making it up is wajib in Hanafi fiqh whereas no make-up is required in Shafi\'i fiqh.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Hanefîler "Amellerinizi boşa çıkarmayın" (Muhammed 47/33) âyetine dayanarak başlanan nafile ibadeti tamamlamayı vacip görür; Şâfiî ise kişinin nafilede emîr olduğunu kabul eder.',
      en: 'Hanafis cite "And do not nullify your deeds" (47:33), while Shafi\'is grant leeway in voluntary fasts.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebinde nafile namaza veya oruca başlandığında tamamlanması vacip hâle gelir; bozulursa mutlaka kaza edilir. Ancak misafirlik ve ikram gibi güzel bir mazeretle bozmak da Hanefî\'de sonra kaza etmek şartıyla caizdir.',
        en: 'In Hanafi fiqh, once a voluntary fast or prayer is begun, completing it becomes binding—so breaking it requires make-up, whereas Shafi\'i fiqh regards voluntary acts as non-binding throughout.',
      ),
      sourceRef: LocalizedText(
        tr: 'Muhammed, 47/33; Diyanet İlmihali Cilt 1, s. 390, 405',
        en: 'Muhammad 47:33; Diyanet Catechism Vol. 1, pp. 390, 405',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de başlanıp bozulan nafile orucun (ve başlanan nafile namazın) kazası vaciptir.',
        en: 'Hanafi fiqh requires making up a broken voluntary fast or interrupted voluntary prayer.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de yalnız hac ve umre nafileleri başlandıktan sonra tamamlanması gerekir; nafile namaz ve orucu bozana kaza düşmez.',
        en: 'Shafi\'i fiqh obligates completing voluntary Hajj/Umrah only, not broken voluntary fasts or prayers.',
      ),
      linkedFarzId: 10,
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Kadınların mutad süslenme amacıyla zâtî kullanımında bulunan altın ve gümüş ziynet eşyalarının zekâtı konusunda Hanefî mezhebi ile diğer üç mezhep arasındaki hüküm nasıldır?',
      en: 'How does the Hanafi ruling on Zakat for a woman\'s personal gold and silver jewelry compare to that of the Shafi\'i, Maliki, and Hanbali schools?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Dört mezhebin tamamında kadının taktığı hiçbir altın veya gümüş ziynet eşyasına zekât düşmez',
          en: 'All four Sunni schools exempt a woman\'s gold and silver jewelry completely regardless of amount',
        ),
        LocalizedText(
          tr: 'Hanefî\'de ziynet zekâttan muaftır; Şâfiî\'de ise ağırlığına bakılmaksızın her yıl zekât verilmesi farzdır',
          en: 'Hanafis exempt jewelry completely, whereas Shafi\'is require Zakat regardless of threshold',
        ),
        LocalizedText(
          tr: 'Yalnızca evlilik sırasında takılan mehir altınlarına zekât gerekir; sonra alınanlar daima muaftır',
          en: 'Only wedding Mahr gold is zakatable, while later personal jewelry is exempt in all schools',
        ),
        LocalizedText(
          tr: 'Hanefî\'de nisaba (80,18 gr) ulaşıp 1 yıl geçince zekâtı farzdır; Şâfiî, Mâlikî ve Hanbelî\'de mutad kullanımdaki ziynetten zekât gerekmez',
          en: 'Hanafi obligates Zakat once jewelry reaches nisab (~80.18g) for a lunar year; the other three schools exempt customary personal jewelry',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Hanefîler "Altın ve gümüşü yığıp Allah yolunda harcamayanlar..." (Tevbe 9/34) ve altın bilezik hadislerini umumî alarak ziynete zekâtı farz sayar.',
      en: 'Hanafis apply gold/silver Zakat rules universally to all holdings above nisab regardless of form.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî mezhebine göre altın ve gümüşün aslı kıymet saklama ve artıcı zenginlik aracı olduğundan, kadının ziynet eşyası da nisaba (80,18 gr altın) ulaşıp üzerinden bir yıl geçince %2,5 zekâta tâbidir. Şâfiî, Mâlikî ve Hanbelî\'de ise israf sınırını aşmayan mutad ziynetten zekât düşmez.',
        en: 'Hanafi fiqh treats all gold and silver above 80.18g as zakatable wealth; Shafi\'i, Maliki, and Hanbali schools treat customary personal jewelry like non-zakatable personal items.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Zekât 4; Tirmizî, Zekât 12; Diyanet İlmihali Cilt 1, s. 438-440',
        en: 'Abu Dawud, Zakat 4; Tirmidhi, Zakat 12; Diyanet Catechism Vol. 1, pp. 438-440',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de 80,18 gram ve üzeri altın ziynet eşyasından (ve taşsız net altın ağırlığından) yılda %2,5 zekât verilir.',
        en: 'Hanafi fiqh obligates 2.5% annual Zakat on personal gold jewelry reaching 80.18g pure gold equivalent.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de kadının meşru ölçüler içinde normal süslenme amacıyla kullandığı altın/gümüş takılarından zekât gerekmez; biriktirme/yatırım amaçlıysa zekât düşer.',
        en: 'Shafi\'i fiqh exempts customary, non-extravagant personal jewelry from Zakat unless stored purely as investment/hoarding.',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Haccın edâ şekillerini ve şükür kurbanı (Hedy) hükümlerini doğru biçimde eşleştiriniz.',
      en: 'Match the three forms of performing Hajj and Hedy sacrifice with their juristic rulings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'İfrad Haccı', en: 'Hajj al-Ifrad'),
          right: LocalizedText(
            tr: 'Yalnız hacca niyet edilir; şükür kurbanı vacip değildir',
            en: 'Intend Hajj alone; Hedy sacrifice is not wajib',
          ),
        ),
        (
          left: LocalizedText(tr: 'Temettu\' Haccı', en: 'Hajj at-Tamattu\''),
          right: LocalizedText(
            tr: 'Önce umre yapılıp ihramdan çıkılır, sonra aynı yıl hacca girilir',
            en: 'Perform Umrah, exit Ihram, then re-enter Ihram for Hajj',
          ),
        ),
        (
          left: LocalizedText(tr: 'Kıran Haccı', en: 'Hajj al-Qiran'),
          right: LocalizedText(
            tr: 'Tek ihramla hem umre hem hacca birlikte niyet edilir',
            en: 'Enter a single Ihram intending both Umrah and Hajj',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hedy Kurbanı', en: 'Hady Sacrifice'),
          right: LocalizedText(
            tr: 'Temettu\' ve Kıran\'da Harem\'de kesilmesi vacip şükür kurbanı',
            en: 'Wajib gratitude sacrifice in the Haram for Tamattu\'/Qiran',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Aynı hac mevsiminde hem umre hem hac ihramına kavuşma nimetinden dolayı Temettu\' ve Kıran\'da hedy (veya gücü yetmiyorsa 3+7 gün oruç) vardır.',
      en: 'Uniting Umrah and Hajj in one journey (Tamattu\'/Qiran) carries the gratitude Hady obligation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İfrad haccı Mekke yerlileri dâhil herkesçe yapılabilir ve kurbanı müstehaptır. Türkiye gibi uzak beldelerden (âfâkî) gidenler çoğunlukla Temettu\' haccını seçip önce umrelerini tamamlar, Terviye günü yeniden hac ihramına girerler.',
        en: 'Hajj at-Tamattu\' lets distant pilgrims exit Ihram between Umrah and the days of Hajj, whereas Hajj al-Qiran keeps a single Ihram across both rites.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/196; Buhârî, Hac 34; Diyanet İlmihali Cilt 1, s. 521-524',
        en: 'Al-Baqarah 2:196; Bukhari, Hajj 34; Diyanet Catechism Vol. 1, pp. 521-524',
      ),
      linkedFarzId: 11,
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hac veya umre kastıyla dış bölgeden (Âfâkî olarak) Harem\'e gelen bir Müslümanın, belirlenen Mîkât sınırını ihramsız olarak geçmesi hâlinde fıkhî hükmü nedir?',
      en: 'What is the ruling if a pilgrim arriving from outside the Miqat boundaries (Afaqi) with the intention of Hajj or Umrah crosses the Miqat line without entering Ihram?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Geri dönüp mîkâtta ihrama girmezse Harem bölgesinde bir koyun veya keçi kesmesi (dem cezası) vacip olur',
          en: 'Unless returning to a Miqat boundary to enter Ihram before rites, sacrificing a sheep/goat (dam) in the Haram is wajib',
        ),
        LocalizedText(
          tr: 'Haccı veya umresi kökten geçersiz kalır ve o yıl Kâbe\'ye girmesi kesinlikle yasaklanır',
          en: 'Their pilgrimage becomes permanently null and void, barring them from entering the Haram that year',
        ),
        LocalizedText(
          tr: 'Mekke\'de doğrudan Kâbe avlusuna ulaşınca ihrama girmesi sünnet olduğundan hiçbir ceza gerekmez',
          en: 'No penalty applies since entering Ihram upon first seeing the Ka\'bah inside the Mosque is Sunnah',
        ),
        LocalizedText(
          tr: 'Yalnızca iki rekât ihram namazı kılıp bir fitre miktarı sadaka vermesi her durumda yeterlidir',
          en: 'Simply praying two rak\'ahs of Ihram and giving one Fitrah amount in charity always suffices',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Mîkât sınırlarından (Zülhuleyfe, Cuhfe, Karnü\'l-menâzil, Yelemlem, Zâtüırk) birini ihrama girmeden geçip Cidde veya Mekke\'de ihrama giren kişi dem borçlanır.',
      en: 'Crossing any of the five Prophetic Miqat stations without Ihram triggers an expiatory sacrifice unless corrected by returning beforehand.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Uçakla Medine üzerinden gidenler Zülhuleyfe\'den, doğrudan Cidde\'ye inenler ise havada iken mîkât hizasından önce (veya havaalanından binmeden) niyet ve telbiye ile ihrama girerler. İhramsız geçen kişi henüz tavafa başlamadan mîkâta geri dönüp ihrama girerse dem cezası düşer.',
        en: 'Pilgrims flying toward Makkah enter Ihram before crossing the Miqat airspace boundary; if one accidentally crosses un-ihramed, returning to a Miqat before starting rites lifts the penalty sacrifice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Hac 7-13; Diyanet İlmihali Cilt 1, s. 518-520, 543',
        en: 'Bukhari, Hajj 7-13; Diyanet Catechism Vol. 1, pp. 518-520, 543',
      ),
      linkedFarzId: 11,
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    specialDayTags: ['kurban'],
    stem: LocalizedText(
      tr: 'Udhiyye (Kurban Bayramı kurbanı), Akîka ve Adak (Nezir) kurbanlarının etinden kurban sahibinin ve ailesinin yiyebilmesi hususundaki fıkhî fark hangisinde doğru belirtilmiştir?',
      en: 'Which option accurately states who may eat from the meat of Udhiyyah, \'Aqiqah, and Vowed (Nadhr) sacrifices?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bütün kurban çeşitlerinin tamamından kurban kesenin yemesi haram olup hepsi fakirlere dağıtılır',
          en: 'Owners may never eat from any type of sacrifice; every sacrifice must go entirely to the poor',
        ),
        LocalizedText(
          tr: 'Yalnızca Akîka etinden sahibi yiyemez; Adak ve Udhiyye kurbanlarının üçte biri ise daima evde tüketilir',
          en: 'Only \'Aqiqah meat is forbidden to the parents, while Vowed and Udhiyyah sacrifices allow one-third at home',
        ),
        LocalizedText(
          tr: 'Udhiyye ve akîka etinden sahibi ve ailesi yiyebilir; adak kurbanından ise adayan, eşi, usûlü ve fürûu yiyemez',
          en: 'Owner and family may eat from Udhiyyah and \'Aqiqah; neither the vower, spouse, ascendants, nor descendants may eat from a Vowed sacrifice',
        ),
        LocalizedText(
          tr: 'Adak kurbanı sahibi dilerse etin yarısını zengin akrabalarına ikram edip yarısını kendisi tüketebilir',
          en: 'The vower may host wealthy friends with half the vowed sacrifice and keep the remaining half',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Adak Allah\'a şartsız fakirler adına adanmış bir borç hükmünde olduğundan fakirlerin hakkı sayılır; yense bedeli sadaka olarak verilir.',
      en: 'A vowed sacrifice belongs wholly to the needy; the owner and immediate dependents/parents may not partake of it.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hac Sûresi 28 ve 36. âyetler uyarınca Udhiyye (ve çocuğun şükrü olan Akîka) etinden kurban sahibi yiyip ikram edebilir, fakirlere de dağıtır (üçe taksim müstehaptır). Adak kurbanının eti ise tamamen yoksullara verilir; şayet sahibi veya eşi-çocuğu-anne babası yerse yenen miktarın bedeli yoksula sadaka edilir.',
        en: 'Following Al-Hajj 22:28 & 36, owners eat and share from Udhiyyah and \'Aqiqah; by contrast, a Vowed (Nadhr) sacrifice belongs strictly to the poor, excluding the vower, spouse, ascendants, and descendants.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hac, 22/28, 36; Diyanet İlmihali Cilt 2 (Kurban)',
        en: 'Al-Hajj 22:28, 36; Diyanet Catechism Vol. 2 (Sacrifice)',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Fıkıh ilminde sonuçları ve kefâret gerektirip gerektirmemesi bakımından yemin çeşitlerini tanımlarıyla eşleştiriniz.',
      en: 'Match the Islamic juristic categories of oaths (Yamin) with their respective consequences.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Yemîn-i Lağv', en: 'Yamin al-Laghw'),
          right: LocalizedText(
            tr: 'Doğru sanarak yanılgıyla edilen yemin; kefâret gerekmez',
            en: 'Inadvertent oath spoken thinking it true; no expiation',
          ),
        ),
        (
          left: LocalizedText(tr: 'Yemîn-i Gamûs', en: 'Yamin al-Ghamus'),
          right: LocalizedText(
            tr: 'Geçmişe dair bile bile yalan yemin; büyük günah ve tövbe gerekir',
            en: 'Deliberate false oath on a past matter; grave sin requiring repentance',
          ),
        ),
        (
          left: LocalizedText(tr: 'Yemîn-i Mün\'akide', en: 'Yamin al-Mun\'aqidah'),
          right: LocalizedText(
            tr: 'Gelecekte bir işi yapma/yapmama yemini; bozulursa kefâret gerekir',
            en: 'Binding oath regarding a future act; expiation required if broken',
          ),
        ),
        (
          left: LocalizedText(tr: 'Kasem Lâfızları', en: 'Valid Oath Phrases'),
          right: LocalizedText(
            tr: 'Vallâhi, Billâhi, Tallâhi gibi Allah\'ın isim ve sıfatları',
            en: 'Swearing by Allah\'s Names or Attributes (Wallahi, Billahi)',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Hanefî mezhebinde Yemîn-i Gamûs kefâretle örtülemeyecek kadar ağır kabul edilir (tövbe ve hak iadesi gerekir); kefâret bozulan Mün\'akide yemindedir.',
      en: 'Al-Ghamus cannot be bought off with routine kaffarah in Hanafi fiqh—it requires deep repentance and restoring any wronged rights.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân-ı Kerîm "Allah, boş bulunarak ettiğiniz yeminlerden dolayı sizi sorumlu tutmaz; fakat bilerek yaptığınız yeminlerden dolayı sorumlu tutar" (Mâide 5/89) buyurarak yemin ciddiyetini öğretir.',
        en: 'Surah Al-Ma\'idah 5:89 distinguishes unintentional slips of the tongue (al-Laghw) from binding future oaths (al-Mun\'aqidah), instilling reverence for Allah\'s Name.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/225; Mâide, 5/89; Diyanet İlmihali Cilt 2 (Yeminler)',
        en: 'Al-Baqarah 2:225; Al-Ma\'idah 5:89; Diyanet Catechism Vol. 2 (Oaths)',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_20',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Mâide Sûresi 89. âyet gereği yemîn-i mün\'akide kefâreti ödemek durumunda olan maddî imkânı yerinde bir kimse, on fakiri doyurmak veya giydirmek yerine doğrudan üç gün oruç tutarak kefâretini ödeyebilir.',
      en: 'Under Surah Al-Ma\'idah 5:89, a financially capable person paying expiation for a broken oath may directly fast three days instead of feeding or clothing ten needy people.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Âyetteki "Kim bunları bulamazsa üç gün oruç tutar" ifadesi, orucun yalnız maddî gücü yetmeyenler için ikinci kademe olduğunu gösterir.',
      en: 'The verse states: "Whoever cannot find [the means]—then a fast of three days," making fasting strictly secondary.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Yemin kefâreti sırasıyla: 1) On fakiri sabahlı-akşamlı doyurmak (10 fitre miktarı), ya da on fakiri giydirmek, ya da bir köle azat etmek. Yalnızca bunlara maddî gücü yetmeyen kimse 3 gün oruç tutar (Hanefî mezhebinde bu 3 günün ara verilmeden peş peşe tutulması gerekir).',
        en: 'Oath expiation first requires feeding ten poor people two meals (or equivalent aid) or clothing ten poor people; only one genuinely unable financially fasts three days (consecutive in Hanafi fiqh).',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/89; Diyanet İlmihali Cilt 2 (Yeminler)',
        en: 'Surah Al-Ma\'idah, 5:89; Diyanet Catechism Vol. 2 (Oaths)',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_21',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'İslâm aile hukukunda nikâh akdinin rükünleri ve gizli evlilikleri önlemek için konulan şahitlik şartı hakkında Hanefî ve Şâfiî mezheplerinin hükmü hangisinde doğru verilmiştir?',
      en: 'In Islamic family law, which statement accurately captures the Hanafi and Shafi\'i requirements regarding the pillars and witnesses of a marriage contract?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şahit bulunmadan yalnız kadın ile erkeğin kendi aralarında gizlice söz vermesiyle nikâh sahih olur',
          en: 'Private mutual consent between the bride and groom alone forms a valid marriage without witnesses',
        ),
        LocalizedText(
          tr: 'Nikâhta yalnızca erkek şahitler geçerlidir; hiçbir mezhepte kadınların şahitliği kabul edilmez',
          en: 'Only male witnesses are ever accepted; no Sunni school recognizes women among marriage witnesses',
        ),
        LocalizedText(
          tr: 'Hanefî\'de velînin mutlaka hazır bulunması şarttır; Şâfiî\'de ise velî izni olmadan evlilik geçerlidir',
          en: 'Hanafi mandates a guardian\'s presence unconditionally, while Shafi\'i validates marriage without a guardian',
        ),
        LocalizedText(
          tr: 'Îcap ve kabul rükündür; Hanefî\'de 2 erkek (veya 1 erkek + 2 kadın) şahit, Şâfiî\'de ise ayrıca velî ve 2 âdil erkek şahit şarttır',
          en: 'Offer and acceptance are pillars; Hanafi requires 2 men (or 1 man + 2 women) witnesses, while Shafi\'i requires a guardian and 2 upright men',
        ),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Tirmizî ve Dârekutnî\'de rivayet edilen hadisler ışığında şahitsiz gizli nikâh bütün Ehl-i Sünnet mezheplerinde geçersizdir.',
      en: 'Secret marriage without witnesses is invalid across all four Sunni schools.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Nikâh toplum nezdinde nesebi, kadın ve erkeğin haklarını güvence altına alan alenî bir akittir. Bu sebeple şahitlerin akıllı, ergen ve Müslüman (ve Şâfiî\'de âdil erkek) olması, nikâhın duyurulması esas alınmıştır.',
        en: 'Marriage is a sacred public covenant protecting lineage and mutual rights; all schools forbid secret marriages by mandating qualified witnesses and clear mutual consent.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Nikâh 14-17; Diyanet İlmihali Cilt 2 (Aile ve Evlilik)',
        en: 'Tirmidhi, Nikah 14-17; Diyanet Catechism Vol. 2 (Marriage & Family)',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî\'de ergen ve akıllı kadın kendi rızasıyla nikâh yapabilir; şahit olarak 2 erkek veya 1 erkekle 2 kadın bulunmalıdır (velî izni küfüv ve istikrar için teşvik edilir).',
        en: 'In Hanafi fiqh, 2 male witnesses (or 1 man and 2 women) are required, and a mature woman\'s own consent completes offer/acceptance.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî\'de kadının rızasının yanında mutlaka velîsinin akdi yapması/izni ve en az iki âdil Müslüman erkek şahit şarttır.',
        en: 'In Shafi\'i fiqh, alongside the bride\'s consent, the guardian\'s (wali) role and 2 upright Muslim male witnesses are strict conditions.',
      ),
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_22',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Nisâ Sûresi 4. âyetle kadının şahsî malî hakkı olarak güvenceye alınan Mehir kavramında, nikâh anında miktarı açıkça belirlenen mehir ile miktarı hiç konuşulmamışsa emsallerine göre belirlenen mehre sırasıyla ne ad verilir?',
      en: 'In Islamic marital law (Surah An-Nisa 4:4), what are the terms for Mahr specified at the wedding versus Mahr determined later according to peers if left unstated?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Mehr-i Muaccel ve Mehr-i Müeccel',
          en: 'Mahr Mu\'ajjal (Prompt) and Mahr Mu\'ejjel (Deferred)',
        ),
        LocalizedText(
          tr: 'Mehr-i Müsemmâ ve Mehr-i Misil',
          en: 'Mahr Musamma and Mahr al-Mithl',
        ),
        LocalizedText(
          tr: 'Nafaka-i İddet ve Nafaka-i Sükna',
          en: 'Nafaqat al-\'Iddah and Nafaqat as-Sukna',
        ),
        LocalizedText(
          tr: 'Hibe-i Sahîha ve Zevciyet Bedeli',
          en: 'Hibah Sahihah and Marital Dowry Return',
        ),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Muaccel-Müeccel ödeme zamanına (peşin-vadeli) göre; "Müsemmâ" (ismi/miktarı konmuş) ve "Misil" (emsaline göre) ise miktarın belirlenip belirlenmemesine göre ayrımdır.',
      en: 'Mu\'ajjal/Mu\'ejjel classify payment timing (prompt/deferred), while Musamma/Mithl classify whether the amount was fixed.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Kadınlara mehirlerini gönül hoşnutluğuyla verin" (Nisâ 4/4) emri uyarınca mehir bizzat kadının şahsî mülküdür; anne-babaya veya kocaya ait değildir. Akit sırasında belirlenmemişse nikâh geçerlidir ve kadın emsalleri ölçüsünde mehr-i misil hakkı kazanır.',
        en: 'As a Qur\'anic financial safeguard exclusively for the wife, even if Mahr goes unmentioned during the contract, the marriage remains valid and she is entitled to standard peer-equivalent Mahr (Mahr al-Mithl).',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ, 4/4, 24; Diyanet İlmihali Cilt 2 (Aile ve Evlilik)',
        en: 'An-Nisa 4:4, 24; Diyanet Catechism Vol. 2 (Marriage & Family)',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_23',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: '"Nesep (kan) yoluyla evlenmesi haram olanlar süt emme (radâ\') sebebiyle de haram olur" hadisi gereği süt hısımlığı doğması için cumhur fukahâya, Ebû Yûsuf ve İmam Muhammed\'e ve DİB Din İşleri Yüksek Kurulu tercihine göre emzirmenin hangi yaş sınırı içinde olması şarttır?',
      en: 'For milk kinship (rada\'ah) to establish marital prohibition, within what infancy period must nursing occur according to the majority of jurists, Abu Yusuf, Muhammad, and the Diyanet High Council?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kamerî ilk iki yıl (24 ay) içinde gerçekleşen emzirme ile sabit olur',
          en: 'Within the first two lunar years (24 months) of infancy',
        ),
        LocalizedText(
          tr: 'Çocuk yedi yaşına girip temyiz çağına ulaşıncaya kadar süt hısımlığı oluşabilir',
          en: 'Milk kinship arises at any time up to the age of seven (discernment)',
        ),
        LocalizedText(
          tr: 'Yalnızca doğumdan sonraki ilk kırk gün içinde emzirilirse süt kardeşlik doğar',
          en: 'Milk kinship arises solely during the first forty days after birth',
        ),
        LocalizedText(
          tr: 'Yaş sınırı olmaksızın hayatın herhangi bir döneminde süt içmek hısımlık doğurur',
          en: 'Regardless of age, consuming breast milk at any point in life establishes kinship',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Bakara Sûresi 233. âyetteki "Tam iki yıl emzirirler..." ölçüsü esas alınmıştır.',
      en: 'Anchored in Surah Al-Baqarah 2:233 stating two full years of nursing.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İki yaşını (24 ay) aşan çocuğun süt emmesi cumhur ulemâya, İmâmeyn\'e ve Diyanet fetvasına göre evlenme engeli doğurmaz. Ayrıca süt kardeşliği yalnız süt emen çocuk (ve onun alt soyu) ile süt anne-baba ve diğer çocukları arasında oluşur; süt emen çocuğun kendi öz kardeşlerine sirayet etmez.',
        en: 'Nursing beyond two lunar years establishes no marital bar per the majority and Diyanet fatwa. Milk kinship binds the nursed child and their descendants to the wet-nurse\'s family—not extending to the nursed child\'s biological siblings who were not nursed there.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/233; Buhârî, Nikâh 20; Diyanet İlmihali Cilt 2 (Aile ve Evlilik)',
        en: 'Al-Baqarah 2:233; Bukhari, Nikah 20; Diyanet Catechism Vol. 2 (Marriage & Family)',
      ),
      hanafiNote: LocalizedText(
        tr: 'Ebû Hanîfe süreyi 30 ay, Ebû Yûsuf ve İmam Muhammed ise 24 ay (2 yıl) kabul etmiştir; DİB fetvası İmâmeyn ve cumhurun 24 ay görüşü doğrultusundadır. Az da olsa süt yutulması yeterlidir.',
        en: 'While Abu Hanifah gave 30 months, Abu Yusuf and Muhammad held 24 months (used in Diyanet fatwa), and even one confirmed feeding suffices.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde süt hısımlığı ilk 2 yaş (24 ay) içinde ayrı zamanlarda en az 5 doyurucu emme ile sabit olur.',
        en: 'In Shafi\'i fiqh, nursing within 24 months requires five distinct satisfying feeds to establish milk kinship.',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_24',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Diyanet İlmihali Cilt 2\'de yer alan İslâm iktisat ve ticaret hukukunun temel kavramlarını anlamlarıyla eşleştiriniz.',
      en: 'Match the core Islamic economic and commercial ethics terms from Volume 2 of the Diyanet Catechism with their meanings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Ribâ (Faiz)', en: 'Riba (Usury/Interest)'),
          right: LocalizedText(
            tr: 'Borç veya vadeli mübadelede şart koşulan karşılıksız fazlalık',
            en: 'Unjustified stipulated excess in loans or deferred exchange',
          ),
        ),
        (
          left: LocalizedText(tr: 'Garar', en: 'Gharar (Excessive Uncertainty)'),
          right: LocalizedText(
            tr: 'Akdin konusunda veya bedelinde aldanmaya yol açan belirsizlik',
            en: 'Major contractual ambiguity inviting dispute or exploitation',
          ),
        ),
        (
          left: LocalizedText(tr: 'İhtikâr', en: 'Ihtikar (Hoarding/Monopoly)'),
          right: LocalizedText(
            tr: 'Temel ihtiyaç mallarını piyasadan çekip pahalanmasını beklemek',
            en: 'Withholding essential goods to artificially inflate market prices',
          ),
        ),
        (
          left: LocalizedText(tr: 'Karz-ı Hasen', en: 'Qard Hasan (Benevolent Loan)'),
          right: LocalizedText(
            tr: 'Allah rızası için fazlalık ve menfaat beklemeksizin verilen ödünç',
            en: 'Interest-free charitable loan extended purely for Allah\'s sake',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İslâm ticareti meşru kılar; ancak haksız kazanç, aşırı belirsizlik (garar) ve halkı zora sokan karaborsacılığı (ihtikâr) yasaklar.',
      en: 'Islam encourages honest trade while forbidding interest, deceptive ambiguity, and hoarding essentials.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm iktisat ahlâkı karşılıklı rıza, şeffaflık, emek ve adalet üzerine kuruludur; zenginin darda kalana faizle değil karz-ı hasen ile destek olmasını teşvik eder.',
        en: 'Islamic commercial ethics rests on mutual consent, transparency, genuine risk-sharing, and social compassion—promoting benevolent loans over exploitative interest.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/275-279; Müslim, Fiten 129; Diyanet İlmihali Cilt 2 (İktisadî Hayat)',
        en: 'Al-Baqarah 2:275-279; Muslim, Fitan 129; Diyanet Catechism Vol. 2 (Economic Life)',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'dilm_i_25',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İşlediği günah veya haksızlık sebebiyle kul hakkına (Hukûku\'l-İbâd) girmiş bir müminin tövbesinin tam ve makbul olabilmesi için pişmanlık, günahı terk ve bir daha dönmemeye azim şartlarına ek olarak hangi dördüncü şartı yerine getirmesi gerekir?',
      en: 'When a sin violates another human being\'s rights (Huquq al-\'Ibad), what fourth requirement must accompany remorse, stopping the sin, and resolving never to repeat it for full repentance?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Yalnızca gece teheccüd namazı kılıp gizlice istiğfar etmesi hâlinde kul hakkı kendiliğinden düşer',
          en: 'Human rights obligations lapse automatically through private late-night prayer and seeking forgiveness alone',
        ),
        LocalizedText(
          tr: 'Yaptığı haksızlıktan dolayı yalnız kırk gün üst üste nafile oruç tutması kafîdir',
          en: 'Fasting forty consecutive voluntary days by itself suffices to erase all interpersonal wrongs',
        ),
        LocalizedText(
          tr: 'Hak sahibine hakkını iade veya tazmin etmek ya da ondan gönül rızasıyla helâllik almak',
          en: 'Restoring or compensating the right to its owner, or sincerely seeking their pardon and release (halal)',
        ),
        LocalizedText(
          tr: 'Umre ziyareti yapıp Zemzem içtiğinde başkalarına ait borç ve gıybet hakları da bağışlanır',
          en: 'Performing Umrah automatically cancels all unpaid financial debts and slander against others',
        ),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn Tevbe Babı\'nda İmam Nevevî, yalnız Allah ile kul arasındaki günahların üç, kul hakkı içerenlerin ise dört şartla tövbeye kavuşacağını belirtir.',
      en: 'Imam an-Nawawi explains that sins against Allah take three conditions of tawbah, while those violating human rights require a fourth: restitution or pardon.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Malî bir hak gasp edilmişse geri ödenir (hak sahibi vefat etmişse mirasçılarına verilir, mirasçısı da bilinmiyorsa sahibi adına tasadduk edilir). Gıybet gibi mânevî haklarda ise fitneye yol açmayacaksa helâllik alınır, arkasından hayırla yâd edilip istiğfar ve dua edilir.',
        en: 'Material wrongs require restitution (or charity on the owner\'s behalf if heirs cannot be found); moral wrongs require seeking pardon when wise and praying fervently for the wronged person\'s good.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Mezâlim 10; Riyâzü\'s-Sâlihîn, Tevbe 1; Diyanet İlmihali Cilt 2 (Ahlâk)',
        en: 'Bukhari, Mazalim 10; Riyad as-Salihin, Tawbah 1; Diyanet Catechism Vol. 2 (Ethics)',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
      linkedZikirKey: 'İstiğfar',
    ),
  ),
];
