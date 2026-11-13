import '../domain/irfan_models.dart';

/// 33 Authentic Bilingual (TR/EN) Questions for 32 Farz & İlmihal (covering all 32 Farz IDs 1..32).
const List<IrfanQuestion> kIrfanQuestionsIlmihal = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 11 QUESTIONS (Farz IDs 1..11)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_b_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İslâm inancında Allah\'ın bir ve tek olması, eşi ve benzeri bulunmaması hangi sıfatla ifade edilir?',
      en: 'In Islamic creed, which attribute expresses that Allah is One and Unique with no partner or equal?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Vahdâniyyet', en: 'Wahdaniyyah (Oneness)'),
        LocalizedText(tr: 'Tekvîn', en: 'Takwin (Creating)'),
        LocalizedText(tr: 'Kelâm', en: 'Kalam (Speech)'),
        LocalizedText(tr: 'İrâde', en: 'Iradah (Will)'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Arapçada "vâhid" (bir) kökünden türeyen Zâtî sıfattır.',
      en: 'It is the Personal attribute derived from the Arabic root "wahid" (one).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Vahdâniyyet, Allah Teâlâ\'nın zâtında, sıfatlarında ve fiillerinde bir ve tek olması, hiçbir ortağının bulunmamasıdır.',
        en: 'Wahdaniyyah means that Allah Almighty is One and Unique in His Essence, Attributes, and Actions, having no partner whatsoever.',
      ),
      sourceRef: LocalizedText(
        tr: 'İhlâs Sûresi, 112/1-4; Diyanet İlmihali Cilt 1, s. 68-74',
        en: 'Surah Al-Ikhlas, 112:1-4; Diyanet Catechism Vol. 1, pp. 68-74',
      ),
      linkedFarzId: 1,
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Dört büyük meleği ve asli vazifelerini doğru şekilde eşleştiriniz.',
      en: 'Match the four archangels with their primary duties.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Cebrâil (a.s.)', en: 'Jibril (Gabriel)'),
          right: LocalizedText(tr: 'Vahiy getirmek', en: 'Conveying revelation'),
        ),
        (
          left: LocalizedText(tr: 'Mîkâil (a.s.)', en: 'Mika\'il (Michael)'),
          right: LocalizedText(tr: 'Tabiat ve rızık olayları', en: 'Nature and sustenance'),
        ),
        (
          left: LocalizedText(tr: 'İsrâfil (a.s.)', en: 'Israfil (Raphael)'),
          right: LocalizedText(tr: 'Sûr\'a üflemek', en: 'Blowing the Trumpet'),
        ),
        (
          left: LocalizedText(tr: 'Azrâil (a.s.)', en: 'Azra\'il (Angel of Death)'),
          right: LocalizedText(tr: 'Eceli gelenlerin ruhunu almak', en: 'Taking souls at death'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Vahiy meleği Cebrâil (a.s.), kıyamet Sûr\'unu üfleyecek melek İsrâfil\'dir (a.s.).',
      en: 'Jibril brings revelation, while Israfil will blow the Trumpet on the Last Day.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Meleklere iman, Âmentü esaslarının ikincisidir. Melekler nurdan yaratılmış olup Allah\'ın emirlerine tam itaat ederler.',
        en: 'Belief in angels is the second pillar of faith. Created from light, angels obey Allah\'s commands unfailingly.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/285; Diyanet İlmihali Cilt 1, s. 92-98',
        en: 'Surah Al-Baqarah, 2:285; Diyanet Catechism Vol. 1, pp. 92-98',
      ),
      linkedFarzId: 2,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan', 'kadir'],
    stem: LocalizedText(
      tr: 'İlahî kitapları indirildikleri peygamberlerle eşleştiriniz.',
      en: 'Match the four major divine scriptures with the prophets to whom they were revealed.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Tevrat', en: 'Torah (Tawrat)'),
          right: LocalizedText(tr: 'Hz. Mûsâ (a.s.)', en: 'Prophet Musa (Moses)'),
        ),
        (
          left: LocalizedText(tr: 'Zebûr', en: 'Psalms (Zabur)'),
          right: LocalizedText(tr: 'Hz. Dâvûd (a.s.)', en: 'Prophet Dawud (David)'),
        ),
        (
          left: LocalizedText(tr: 'İncil', en: 'Gospel (Injil)'),
          right: LocalizedText(tr: 'Hz. Îsâ (a.s.)', en: 'Prophet Isa (Jesus)'),
        ),
        (
          left: LocalizedText(tr: 'Kur\'ân-ı Kerîm', en: 'The Noble Qur\'an'),
          right: LocalizedText(tr: 'Hz. Muhammed (s.a.v.)', en: 'Prophet Muhammad (ﷺ)'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Zebûr Hz. Dâvûd\'a, Tevrat ise Hz. Mûsâ\'ya indirilmiştir.',
      en: 'Zabur was revealed to Prophet Dawud and Tawrat to Prophet Musa.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kitaplara iman, ilahî kitapların vahyedildikleri asıllarına inanmayı; Kur\'ân-ı Kerîm\'in ise tahriften korunmuş son ilahî rehber olduğunu tasdik etmeyi kapsar.',
        en: 'Belief in scriptures affirms the original revelations of divine books and testifies that the Qur\'an is the final, preserved word of Allah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hicr Sûresi, 15/9; Diyanet İlmihali Cilt 1, s. 99-105',
        en: 'Surah Al-Hijr, 15:9; Diyanet Catechism Vol. 1, pp. 99-105',
      ),
      linkedFarzId: 3,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Peygamberlerin günah işlemekten Allah tarafından korunmuş olmalarını ifade eden sıfat hangisidir?',
      en: 'Which prophetic attribute signifies divinely granted protection from committing sins?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Sıdk', en: 'Sidq (Truthfulness)'),
        LocalizedText(tr: 'Fetânet', en: 'Fatanah (Wisdom)'),
        LocalizedText(tr: 'İsmet', en: 'Ismah (Infallibility)'),
        LocalizedText(tr: 'Tebliğ', en: 'Tabligh (Conveyance)'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Masum" kelimesiyle aynı kökten gelir; korunmuşluk demektir.',
      en: 'It shares the same Arabic root as "ma\'sum" (protected/innocent).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Peygamberlerin beş vacip sıfatı Sıdk (doğruluk), Emânet (güvenilirlik), Tebliğ (mesajı ulaştırma), Fetânet (üstün zekâ) ve İsmet\'tir (günahtan korunmuşluk).',
        en: 'The five essential attributes of prophets are Sidq, Amanah, Tabligh, Fatanah, and Ismah (protection from sin).',
      ),
      sourceRef: LocalizedText(
        tr: 'Ahzâb Sûresi, 33/40; Diyanet İlmihali Cilt 1, s. 106-116',
        en: 'Surah Al-Ahzab, 33:40; Diyanet Catechism Vol. 1, pp. 106-116',
      ),
      linkedFarzId: 4,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Ölümle başlayıp kıyametin kopmasına (yeniden dirilişe) kadar süren kabir âlemine İslâm literatüründe ne ad verilir?',
      en: 'What is the Islamic term for the intermediate realm between death and resurrection?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Mahşer', en: 'Mahshar'),
        LocalizedText(tr: 'Berzah', en: 'Barzakh'),
        LocalizedText(tr: 'Mîzan', en: 'Mizan'),
        LocalizedText(tr: 'A\'râf', en: 'A\'raf'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'İki âlem arasındaki "perde / geçit" anlamına gelir.',
      en: 'It literally means a "barrier" or "isthmus" between two worlds.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Berzah, dünya hayatı ile âhiret hayatı arasındaki kabir dönemidir. Yeniden diriliş (ba\'s) ile mahşer safhası başlar.',
        en: 'Barzakh is the intermediate state after death until Resurrection (Ba\'th), after which humanity gathers at Mahshar.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mü\'minûn Sûresi, 23/100; Diyanet İlmihali Cilt 1, s. 117-122',
        en: 'Surah Al-Mu\'minun, 23:100; Diyanet Catechism Vol. 1, pp. 117-122',
      ),
      linkedFarzId: 5,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İslâm inancında kadere iman, insanın cüz\'î iradesini ve kendi tercihlerinden doğan sorumluluğunu ortadan kaldırmaz.',
      en: 'In Islam, belief in divine decree (Qadar) does not negate human free choice (juz\'i iradah) and moral accountability.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'İnsan, hayrı veya şerri kendi cüz\'î iradesiyle seçtiği için imtihan olunur.',
      en: 'Humans are tested precisely because they choose good or evil through their granted partial will.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kader Allah\'ın ezelî ilmi ve takdiridir; ancak Cenâb-ı Hak insana akıl ve cüz\'î irade vermiş, kulunu kendi hür seçimlerinden sorumlu tutmuştur.',
        en: 'Qadar is Allah\'s eternal knowledge and measure; yet Allah granted humans intellect and choice, holding them accountable for their deeds.',
      ),
      sourceRef: LocalizedText(
        tr: 'İnsan Sûresi, 76/3; Diyanet İlmihali Cilt 1, s. 132-146',
        en: 'Surah Al-Insan, 76:3; Diyanet Catechism Vol. 1, pp. 132-146',
      ),
      linkedFarzId: 6,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İslâm\'ın beş temel şartından birincisi olup kalpteki imanın dille ikrarını ifade eden esas hangisidir?',
      en: 'Which is the first of the five pillars of Islam, expressing verbal testimony of faith in the heart?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kelime-i Şehâdet getirmek', en: 'Declaring the Shahadah'),
        LocalizedText(tr: 'Hacca gitmek', en: 'Performing Hajj'),
        LocalizedText(tr: 'Zekât vermek', en: 'Giving Zakat'),
        LocalizedText(tr: 'Teyemmüm almak', en: 'Performing Tayammum'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Eşhedü en lâ ilâhe illallâh..." lafzıyla şahitlik etmektir.',
      en: 'It is bearing witness beginning with "Ashhadu an la ilaha illallah...".',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cibrîl hadisinde bildirildiği üzere İslâm\'ın ilk şartı Allah\'tan başka ilâh olmadığına ve Hz. Muhammed\'in O\'nun kulu ve elçisi olduğuna şehâdet etmektir.',
        en: 'As taught in the Hadith of Jibril, the first pillar of Islam is testifying that there is no deity but Allah and Muhammad (ﷺ) is His servant and Messenger.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Îmân 1; Müslim, Îmân 1',
        en: 'Bukhari, Iman 1; Muslim, Iman 1',
      ),
      linkedFarzId: 7,
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['mirac', 'kandil'],
    stem: LocalizedText(
      tr: 'Akıllı ve ergenlik çağına ulaşmış her Müslümana günde beş vakit farz kılınan ve "dinin direği" olarak nitelendirilen ibadet hangisidir?',
      en: 'Which worship is obligatory five times daily upon every sane adult Muslim and is described as "the pillar of religion"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İtikâfa girmek', en: 'Observing I\'tikaf'),
        LocalizedText(tr: 'Umre yapmak', en: 'Performing Umrah'),
        LocalizedText(tr: 'Namaz kılmak', en: 'Performing Salah (Prayer)'),
        LocalizedText(tr: 'Sadaka-i fıtır vermek', en: 'Giving Sadaqat al-Fitr'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Mi\'râc gecesinde beş vakit olarak farz kılınmıştır.',
      en: 'It was enjoined as five daily times on the Night of Mi\'raj.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Beş vakit namaz, Kelime-i Şehâdet\'ten sonra İslâm\'ın en mühim rüknüdür ve Mi\'râc gecesi müminlere hediye edilmiştir.',
        en: 'The five daily prayers are the most vital pillar of Islam after the Shahadah and were gifted on the Night of Mi\'raj.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ankebût Sûresi, 29/45; Tirmizî, Îmân 8',
        en: 'Surah Al-\'Ankabut, 29:45; Tirmidhi, Iman 8',
      ),
      linkedFarzId: 8,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Temel ihtiyaçları ve borçları dışında nisap miktarı mala sahip olup üzerinden bir kamerî yıl (havelân-ı havl) geçen Müslümanın altın ve nakit birikiminde zekât oranı kaçtır?',
      en: 'What is the obligatory Zakat rate on gold and cash savings held above the nisab threshold for one lunar year?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Onda bir (%10)', en: 'One-tenth (10%)'),
        LocalizedText(tr: 'Beşte bir (%20)', en: 'One-fifth (20%)'),
        LocalizedText(tr: 'Yirmide bir (%5)', en: 'One-twentieth (5%)'),
        LocalizedText(tr: 'Kırkta bir (%2,5)', en: 'One-fortieth (2.5%)'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '80,18 gram altın ölçüsüne ulaşıldığında kırkta bir oranında verilir.',
      en: 'Once wealth reaches the equivalent of ~80.18g of gold, one-fortieth is given.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Altın, gümüş, nakit para ve ticaret mallarında zekât oranı kırkta bir (%2,5) olup Tevbe Sûresi 60. âyette belirtilen sekiz sınıfa verilir.',
        en: 'For gold, silver, cash, and trade goods, Zakat is 2.5% (1/40) and is distributed to the eligible categories defined in Surah At-Tawbah 9:60.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/60; Ebû Dâvûd, Zekât 4; Diyanet İlmihali Cilt 1, s. 432',
        en: 'Surah At-Tawbah, 9:60; Abu Dawud, Zakat 4; Diyanet Catechism Vol. 1, p. 432',
      ),
      linkedFarzId: 9,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Ramazan orucunun vakti, tan yerinin ağarmasıyla (imsak / fecr-i sâdık) başlar ve güneşin batmasıyla (iftar) sona erer.',
      en: 'The daily fast of Ramadan begins at true dawn (imsak / fajr) and ends at sunset (maghrib / iftar).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Bakara Sûresi 187. âyette fecre kadar yiyip içilip geceye (akşama) kadar orucun tamamlanması emredilir.',
      en: 'Surah Al-Baqarah 2:187 instructs fasting from dawn until nightfall (sunset).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Oruç, imsak vaktinden güneş batıncaya kadar ibadet niyetiyle yeme, içme ve orucu bozan hallerden uzak durmaktır.',
        en: 'Fasting (Sawm) is abstaining from food, drink, and marital relations with the intention of worship from true dawn until sunset.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/183-187; Diyanet İlmihali Cilt 1, s. 383',
        en: 'Surah Al-Baqarah, 2:183-187; Diyanet Catechism Vol. 1, p. 383',
      ),
      linkedFarzId: 10,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['kurban', 'bayram'],
    stem: LocalizedText(
      tr: 'Sağlık ve malî imkâna sahip Müslümana ömründe bir kez farz olan Hac ibadetinin üç temel rüknü (farzı) hangisinde bir arada verilmiştir?',
      en: 'Which option lists the three essential pillars (fard) of Hajj, obligatory once in a lifetime for those able?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İhram, Arafat vakfesi, Ziyaret tavafı',
          en: 'Ihram, Standing at Arafat, Tawaf al-Ziyarah',
        ),
        LocalizedText(
          tr: 'Umre, Kudüm tavafı, Veda tavafı',
          en: 'Umrah, Arrival Tawaf, Farewell Tawaf',
        ),
        LocalizedText(
          tr: 'Zemzem içmek, Ravza ziyareti, Kurban',
          en: 'Drinking Zamzam, Visiting Rawdah, Sacrifice',
        ),
        LocalizedText(
          tr: 'Medine ziyareti, Terviye günü, İtikâf',
          en: 'Visiting Madinah, Day of Tarwiyah, I\'tikaf',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Peygamberimiz (s.a.v.) "Hac Arafat\'tır" buyurmuştur; ihram şart, ziyaret tavafı ve vakfe rükündür.',
      en: 'The Prophet (ﷺ) said "Hajj is Arafat"; Ihram, Arafat, and Tawaf al-Ziyarah form its core.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Haccın farzları ihrama girmek (şart), Arafat\'ta vakfe yapmak ve Kâbe\'yi ziyaret tavafı etmektir.',
        en: 'The obligatory pillars of Hajj are entering Ihram, standing at Arafat, and performing Tawaf al-Ziyarah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Âl-i İmrân Sûresi, 3/97; Tirmizî, Hac 57; Diyanet İlmihali Cilt 1, s. 517',
        en: 'Surah Ali \'Imran, 3:97; Tirmidhi, Hajj 57; Diyanet Catechism Vol. 1, p. 517',
      ),
      linkedFarzId: 11,
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 11 QUESTIONS (Farz IDs 12..22)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_o_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Mâide Sûresi 6. âyete göre abdestte yüzü yıkamanın (gasl-i vech) sınırları neresidir?',
      en: 'According to Surah Al-Ma\'idah 5:6, what are the boundaries of washing the face in Wudu?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Alındaki saç bitiminden çene altına ve iki kulak yumuşağı arasına kadar',
          en: 'From hairline to beneath the chin, and from earlobe to earlobe',
        ),
        LocalizedText(
          tr: 'Yalnızca yanaklar, burun ucu ve dudak çevresi',
          en: 'Only the cheeks, tip of the nose, and around the lips',
        ),
        LocalizedText(
          tr: 'Kaş hizasından üst dudağa kadar olan bölge',
          en: 'From the eyebrows down to the upper lip',
        ),
        LocalizedText(
          tr: 'Ense kökünden omuz başlarına kadar tüm baş',
          en: 'From the nape of the neck to the shoulders',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Saç kesim sınırından çene altına, sağ kulak yumuşağından sol kulak yumuşağına kadardır.',
      en: 'Vertical boundary: hairline to under the chin; horizontal: ear to ear.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Abdestin ilk farzı yüzü bir kez yıkamaktır; yüz sınırı saç bitiminden çene altına ve iki kulak yumuşağı arasıdır.',
        en: 'Washing the face once is the first fard of Wudu, spanning from the normal hairline to under the chin and between the earlobes.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Diyanet İlmihali Cilt 1, s. 193',
        en: 'Surah Al-Ma\'idah, 5:6; Diyanet Catechism Vol. 1, p. 193',
      ),
      linkedFarzId: 12,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Abdest alırken kolları yıkama farzında dirseklerin (mirfakayn) de yıkanmaya dâhil edilmesi farzdır.',
      en: 'When washing the arms in Wudu, including the elbows themselves in the wash is obligatory (fard).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Mâide 6. âyette "dirseklerle beraber ellerinizi yıkayın" buyrulmaktadır.',
      en: 'Surah Al-Ma\'idah 5:6 explicitly states "and your hands/forearms up to and including the elbows".',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cumhur ulemâsına (dört mezhebe) göre abdestte elleri dirseklerle birlikte kuru yer kalmayacak şekilde bir kez yıkamak farzdır.',
        en: 'According to all four Sunni schools, washing both hands and forearms including the elbows once is obligatory.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Müslim, Tahâret 31; Diyanet İlmihali Cilt 1, s. 194',
        en: 'Surah Al-Ma\'idah, 5:6; Muslim, Taharah 31; Diyanet Catechism Vol. 1, p. 194',
      ),
      linkedFarzId: 13,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre abdestte başın en az ne kadarlık kısmını meshetmek farzdır?',
      en: 'According to the Hanafi school, what minimum portion of the head must be wiped (mash) as a fard in Wudu?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Sadece ense kısmını', en: 'Only the nape of the neck'),
        LocalizedText(tr: 'Başın dörtte birini (nâsiye miktarı)', en: 'One-fourth of the head (forelock area)'),
        LocalizedText(tr: 'Kulakların dış yüzeyini', en: 'Only the outer ears'),
        LocalizedText(tr: 'Kaşların üzerini', en: 'Only above the eyebrows'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Peygamberimizin (s.a.v.) başının ön kısmını (nâsiyesini) meshettiğini bildiren hadisle açıklanmıştır.',
      en: 'Explained by the hadith in which the Prophet (ﷺ) wiped his forelock (roughly a quarter of the head).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mâide 6. âyetteki "başınızı meshedin" emri, sünnetteki uygulama ışığında Hanefîlerde başın dörtte biri olarak belirlenmiştir; tamamını kaplama mesh ise sünnettir.',
        en: 'Based on Prophetic practice explaining Surah Al-Ma\'idah 5:6, Hanafis stipulate wiping one-fourth of the head as fard, while wiping the whole head is Sunnah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Müslim, Tahâret 81; Diyanet İlmihali Cilt 1, s. 194',
        en: 'Surah Al-Ma\'idah, 5:6; Muslim, Taharah 81; Diyanet Catechism Vol. 1, p. 194',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî mezhebine göre abdestin farzı 4\'tür; başın en az dörtte birini meshetmek farzdır.',
        en: 'In Hanafi fiqh, Wudu has 4 fards, and wiping at least one-fourth of the head is required.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebine göre abdestin farzı 6\'dır (niyet ve tertip de farzdır); başın az bir kısmını meshetmek farz için yeterli olur.',
        en: 'In Shafi\'i fiqh, Wudu has 6 fards (including intention and order), and wiping even a small portion of the head suffices for the fard.',
      ),
      linkedFarzId: 14,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Abdestin dördüncü âyet rüknü olarak ayakları yıkarken topuk kemiklerini (ka\'beyn) de yıkamak farzdır; kuru kalan topuklar hakkında hadiste ciddi uyarı vardır.',
      en: 'Washing the feet including the anklebones (ka\'bayn) is fard in Wudu, with Prophetic warnings against leaving heels dry.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Hz. Peygamber (s.a.v.) topukları kuru kalan sahâbîleri görünce "Ateşten vay o kuru topukların hâline!" buyurarak dikkat çekmiştir.',
      en: 'Seeing dry heels during Wudu, the Prophet (ﷺ) cautioned to wash ankles and heels thoroughly.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ayakları her iki yandaki aşık/topuk kemikleriyle beraber parmak aralarını da ıslatarak bir kez yıkamak farzdır.',
        en: 'Washing both feet up to and including the anklebones once, ensuring water reaches between the toes, is fard.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Buhârî, İlim 3; Müslim, Tahâret 28',
        en: 'Surah Al-Ma\'idah, 5:6; Bukhari, \'Ilm 3; Muslim, Taharah 28',
      ),
      linkedFarzId: 15,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre guslün (boy abdestinin) üç farzını terimleriyle doğru eşleştiriniz.',
      en: 'Match the three obligatory acts (fard) of Ghusl in the Hanafi school with their classical terms.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Mazmaza', en: 'Madmadah'),
          right: LocalizedText(tr: 'Ağza dolu dolu su vermek', en: 'Rinsing the mouth thoroughly'),
        ),
        (
          left: LocalizedText(tr: 'İstinşak', en: 'Istinshaq'),
          right: LocalizedText(tr: 'Burna genze kadar su çekmek', en: 'Rinsing the nose up to the softbone'),
        ),
        (
          left: LocalizedText(tr: 'Gasl-i Beden', en: 'Washing the Body'),
          right: LocalizedText(tr: 'İğne ucu kadar kuru yer kalmadan yıkanmak', en: 'Washing the entire body leaving no dry spot'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Mazmaza ağız, istinşak ise burun temizliğidir.',
      en: 'Madmadah refers to the mouth; Istinshaq refers to the nose.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîlerde ağız ve burun içi bedenin dış hükmünde sayıldığından gusülde yıkanması farzdır, abdestte ise sünnettir.',
        en: 'In the Hanafi school, rinsing the mouth and nose is fard during Ghusl and emphasized Sunnah during Wudu.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Ebû Dâvûd, Tahâret 97; Diyanet İlmihali Cilt 1, s. 205',
        en: 'Surah Al-Ma\'idah, 5:6; Abu Dawud, Taharah 97; Diyanet Catechism Vol. 1, p. 205',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî mezhebine göre gusülde niyet sünnet; mazmaza, istinşak ve tüm bedeni yıkamak farzdır.',
        en: 'In Hanafi fiqh, intention in Ghusl is Sunnah, while rinsing mouth, rinsing nose, and washing the whole body are fard.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebine göre guslün farzı ikidir: Niyet etmek ve bütün bedeni yıkamak (mazmaza ve istinşak sünnettir).',
        en: 'In Shafi\'i fiqh, Ghusl has two fards: intention (niyyah) and washing the entire outer body (mouth and nose rinsing are Sunnah).',
      ),
      linkedFarzId: 16,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre gusülde oruçlu olmayan kimsenin burnuna genzine ulaşacak şekilde su çekmesi (istinşak) farzdır.',
      en: 'According to the Hanafi school, drawing water into the nostrils during Ghusl (Istinshaq) is fard (performed gently if fasting).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Guslün 3 farzından ikincisi burna su çekip yıkamaktır.',
      en: 'Rinsing the nostrils is the second of the three fards of Ghusl in Hanafi fiqh.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefî fıkhında burun içerisindeki yumuşak kısma kadar su ulaştırmak guslün farzlarındandır; oruçlu kimse suyu boğazına kaçırmamaya dikkat eder.',
        en: 'Reaching the soft inner cartilage of the nose with water is fard in Hanafi Ghusl; a fasting person does so without over-inhaling.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tirmizî, Savm 69; Diyanet İlmihali Cilt 1, s. 205-206',
        en: 'Tirmidhi, Sawm 69; Diyanet Catechism Vol. 1, pp. 205-206',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde istinşak gusülde farzdır.',
        en: 'Istinshaq is fard in Ghusl according to the Hanafi school.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde istinşak gusülde sünnettir; niyet ise farzdır.',
        en: 'Istinshaq is Sunnah in Ghusl according to the Shafi\'i school, while intention is fard.',
      ),
      linkedFarzId: 17,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Gusül abdesti alırken tırnak üzerinde suyun deriye ulaşmasını engelleyen kalıcı bir tabaka bulunması guslün sıhhatine mâni olur mu?',
      en: 'Does an impermeable layer on the nails or skin that prevents water from reaching beneath invalidate Ghusl?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Evet, suyun bedenin her noktasına ulaşması şart olduğundan mâni olur',
          en: 'Yes, because water must reach every part of the skin and nails',
        ),
        LocalizedText(
          tr: 'Hayır, üstünden su geçmesi yeterlidir',
          en: 'No, passing water over the barrier suffices',
        ),
        LocalizedText(
          tr: 'Sadece Cuma guslünde mâni olur',
          en: 'Only during Friday Ghusl',
        ),
        LocalizedText(
          tr: 'Yalnızca kış aylarında muaf tutulur',
          en: 'Exempted during winter months',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Guslün bütün mezheplerde ittifak edilen farzı, bedende iğne ucu kadar kuru yer kalmamasıdır.',
      en: 'All schools agree that no dry spot may remain on the skin, hair, or nails in Ghusl.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Bütün bedeni kuru yer kalmayacak şekilde yıkamak guslün temel rüknüdür. Boya, oje, mum veya hamur gibi su geçirmeyen maddeler gusülden önce giderilmelidir.',
        en: 'Washing the entire body with no dry spot is the foundational pillar of Ghusl; water-impermeable substances must be removed beforehand.',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Tahâret 97; Diyanet İlmihali Cilt 1, s. 206',
        en: 'Abu Dawud, Taharah 97; Diyanet Catechism Vol. 1, p. 206',
      ),
      linkedFarzId: 18,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Su bulunmadığında veya suyu kullanmaya sağlık engeli olduğunda başvurulan "Teyemmüm" ibadetinde niyet etmenin hükmü nedir?',
      en: 'What is the ruling on making intention (niyyah) when performing Tayammum in the absence or inability to use water?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Bütün mezheplerde farzdır', en: 'Obligatory (fard) in all schools'),
        LocalizedText(tr: 'Menduptur', en: 'Merely recommended (mandub)'),
        LocalizedText(tr: 'Mübahtır', en: 'Permissible (mubah)'),
        LocalizedText(tr: 'Sadece yolculara vaciptir', en: 'Required only for travelers'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Toprak aslen temizleyici değil hükmen temizleyici olduğundan ibadete tahsisi niyetle gerçekleşir.',
      en: 'Because clean earth serves as ritual purification by divine concession, intention is universally fard.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Teyemmümün birinci farzı niyettir. Abdestte Hanefîler niyeti sünnet görse de teyemmümde bütün mezhepler niyetin farz olduğunda ittifak etmiştir.',
        en: 'Intention is the first fard of Tayammum by unanimous consensus across all four Sunni schools.',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ Sûresi, 4/43; Mâide Sûresi, 5/6; Diyanet İlmihali Cilt 1, s. 212',
        en: 'Surah An-Nisa, 4:43; Surah Al-Ma\'idah, 5:6; Diyanet Catechism Vol. 1, p. 212',
      ),
      linkedFarzId: 19,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Teyemmümde niyetten sonra temiz toprak cinsinden bir şeye elleri vurup hangi iki uzvu meshetmek farzdır?',
      en: 'After intention in Tayammum, which two body parts are obligatorily wiped after striking clean earth?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Yüzü ve ayakları', en: 'The face and the feet'),
        LocalizedText(tr: 'Başı ve kulakları', en: 'The head and the ears'),
        LocalizedText(tr: 'Yüzü ve kolları (dirseklerle beraber)', en: 'The face and the arms (with elbows)'),
        LocalizedText(tr: 'Ellerin içini ve ayak bileklerini', en: 'The palms and the ankles'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: 'Mâide Sûresi 6. âyette "yüzlerinizi ve ellerinizi (kollarınızı) meshedin" buyrulur.',
      en: 'Surah Al-Ma\'idah 5:6 specifies wiping your faces and your hands/forearms.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Teyemmüm hem abdestsizlik hem cünüplük için aynı şekilde alınır: Niyet edilip temiz toprağa ilk vuruşta yüz, ikinci vuruşta kollar meshedilir.',
        en: 'Tayammum replaces both Wudu and Ghusl identically: intention, followed by wiping the face and wiping the forearms with clean earth.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Diyanet İlmihali Cilt 1, s. 213-215',
        en: 'Surah Al-Ma\'idah, 5:6; Diyanet Catechism Vol. 1, pp. 213-215',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefî ve Şâfiîlerde iki darp (vuruş) ile yüz ve dirseklerle beraber kollar meshedilir.',
        en: 'In both Hanafi and Shafi\'i fiqh, two strikes wipe the face and the forearms including the elbows.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiî mezhebinde teyemmüm vakit girdikten sonra alınır ve her farz namaz için yenilenir.',
        en: 'In the Shafi\'i school, Tayammum is performed after prayer time enters and renewed for each fard prayer.',
      ),
      linkedFarzId: 20,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Namazın dışındaki farzlardan "Hadesten Tahâret" bağlamında, vücuttan kan akması ve karşı cinsle ten teması konusunda Hanefî ve Şâfiî hükümlerini eşleştiriniz.',
      en: 'Regarding "Purification from Ritual Impurity" (Hadath), match the Hanafi and Shafi\'i rulings on bleeding vs. skin contact.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Vücuttan kan çıkıp dağılması (Hanefî)', en: 'Flowing blood from a wound (Hanafi)'),
          right: LocalizedText(tr: 'Abdesti bozar', en: 'Nullifies Wudu'),
        ),
        (
          left: LocalizedText(tr: 'Vücuttan kan çıkması (Şâfiî)', en: 'Blood from a non-private wound (Shafi\'i)'),
          right: LocalizedText(tr: 'Abdesti bozmaz', en: 'Does not nullify Wudu'),
        ),
        (
          left: LocalizedText(tr: 'Eşlerin çıplak ten teması (Şâfiî)', en: 'Bare skin contact between spouses (Shafi\'i)'),
          right: LocalizedText(tr: 'Abdesti bozar', en: 'Nullifies Wudu'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Hanefîlerde akan kan abdesti bozarken Şâfiîlerde bozmaz; Şâfiîlerde ise nikâh düşen karşı cinsle engelsiz ten teması abdesti bozar.',
      en: 'Flowing blood breaks Wudu in Hanafi fiqh; bare skin contact with a marriageable person breaks Wudu in Shafi\'i fiqh.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hadesten tahâret, abdestsizlik veya cünüplük gibi hükmî kirlilikten temizlenmektir. Mezhep imamlarının âyet ve hadisleri yorumlama usulü ümmet için rahmet ve kolaylık vesilesidir.',
        en: 'Taharah min al-Hadath means ritual purity before prayer. Methodological nuances between Hanafi and Shafi\'i jurists reflect scholarly precision within Sunni orthodoxy.',
      ),
      sourceRef: LocalizedText(
        tr: 'Nisâ Sûresi, 4/43; Diyanet İlmihali Cilt 1, s. 198-203',
        en: 'Surah An-Nisa, 4:43; Diyanet Catechism Vol. 1, pp. 198-203',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde yaradan çıkıp etrafına taşan kan ve irin abdesti bozar; sade ten teması abdesti bozmaz.',
        en: 'In Hanafi fiqh, blood flowing beyond the wound exit nullifies Wudu, while simple skin contact does not.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde ön ve arka yol dışından çıkan kan abdesti bozmaz; aralarında mahremiyet bulunmayan kadın-erkek ten teması bozar.',
        en: 'In Shafi\'i fiqh, bleeding from wounds does not break Wudu, whereas direct skin-to-skin contact with a non-mahram/spouse does.',
      ),
      linkedFarzId: 21,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namaz kılacak kimsenin bedeninde, elbisesinde ve namaz kılacağı yerde namaza engel miktarda maddî pislik bulunmamasına ne ad verilir?',
      en: 'What is the fiqh term for ensuring one\'s body, garments, and place of prayer are free from physical impurity?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İstikbâl-i Kıble', en: 'Istiqbal al-Qiblah'),
        LocalizedText(tr: 'Ka\'de-i Ahîre', en: 'Qa\'dah al-Akhirah'),
        LocalizedText(tr: 'İftitah Tekbiri', en: 'Takbirat al-Ihram'),
        LocalizedText(tr: 'Necâsetten Tahâret', en: 'Taharah min an-Najasah'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: 'Müddessir Sûresi 4. âyette "Elbiseni tertemiz tut!" emriyle bildirilen şarttır.',
      en: 'Commanded in Surah Al-Muddaththir 74:4 ("And purify your garments").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Necâsetten tahâret namazın dışındaki (hazırlık) şartlarının ikincisidir; beden, elbise ve secde mahallinin temiz olmasını ifade eder.',
        en: 'Purification from physical impurity (Najasah) on body, clothing, and prayer spot is the second prerequisite condition of Salah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müddessir Sûresi, 74/4; Diyanet İlmihali Cilt 1, s. 221-225',
        en: 'Surah Al-Muddaththir, 74:4; Diyanet Catechism Vol. 1, pp. 221-225',
      ),
      linkedFarzId: 22,
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 11 QUESTIONS (Farz IDs 23..32 + Comparative Fiqh)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_i_01',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namazın dışındaki şartları (şurûtü\'s-salât) anlamlarıyla doğru eşleştiriniz.',
      en: 'Match the prerequisite conditions of Salah with their meanings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Setr-i Avret', en: 'Satr al-\'Awrah'),
          right: LocalizedText(tr: 'Örtülmesi gereken yerleri örtmek', en: 'Covering the required parts of the body'),
        ),
        (
          left: LocalizedText(tr: 'İstikbâl-i Kıble', en: 'Istiqbal al-Qiblah'),
          right: LocalizedText(tr: 'Kâbe yönüne yönelmek', en: 'Facing the direction of the Ka\'bah'),
        ),
        (
          left: LocalizedText(tr: 'Vakit', en: 'Waqt (Time)'),
          right: LocalizedText(tr: 'Namazın vaktinin girmiş olması', en: 'Entrance of the prescribed prayer time'),
        ),
        (
          left: LocalizedText(tr: 'Niyet', en: 'Niyyah (Intention)'),
          right: LocalizedText(tr: 'Hangi namazı kılacağını kalben bilmek', en: 'Conscious heart intention for the specific prayer'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Setr örtmek, istikbâl ise yönelmek demektir.',
      en: 'Satr means covering; Istiqbal means facing toward.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Namazın dışındaki 6 farza "namazın şartları" denir: Hadesten tahâret, necâsetten tahâret, setr-i avret, istikbâl-i kıble, vakit ve niyet.',
        en: 'The 6 external fards of Salah are called its conditions (shurut): ritual purity, physical cleanliness, covering \'awrah, facing Qiblah, time, and intention.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara, 2/144; Nisâ, 4/103; A\'râf, 7/31; Diyanet İlmihali Cilt 1, s. 225-239',
        en: 'Al-Baqarah 2:144; An-Nisa 4:103; Al-A\'raf 7:31; Diyanet Catechism Vol. 1, pp. 225-239',
      ),
      linkedFarzId: 23,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_02',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Mescid-i Aksâ\'dan Mescid-i Harâm\'a (Kâbe\'ye) yönelmeyi emrederek "İstikbâl-i Kıble" farzını kesinleştiren âyet hangi sûrededir?',
      en: 'In which Surah was the verse commanding believers to turn from Masjid al-Aqsa toward Masjid al-Haram (Qiblah) revealed?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kehf Sûresi, 10. âyet', en: 'Surah Al-Kahf, verse 10'),
        LocalizedText(tr: 'Bakara Sûresi, 144. âyet', en: 'Surah Al-Baqarah, verse 144'),
        LocalizedText(tr: 'Yâsîn Sûresi, 58. âyet', en: 'Surah Ya-Sin, verse 58'),
        LocalizedText(tr: 'Mülk Sûresi, 15. âyet', en: 'Surah Al-Mulk, verse 15'),
      ],
      correctIndex: 1,
    ),
    hint: LocalizedText(
      tr: 'Hicretin 2. yılında Medine\'de inen ve Kur\'ân\'ın en uzun sûresinde yer alan âyettir.',
      en: 'Revealed in Madinah in 2 AH within the longest Surah of the Qur\'an.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Yüzünü Mescid-i Harâm tarafına çevir. Nerede olursanız olun yüzünüzü o yöne çevirin" (Bakara 2/144) âyetiyle kıble Kâbe olarak tayin edilmiştir.',
        en: 'Surah Al-Baqarah 2:144 ("Turn your face toward al-Masjid al-Haram...") established facing the Ka\'bah as a universal condition of Salah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/144; Buhârî, Salât 31',
        en: 'Surah Al-Baqarah, 2:144; Bukhari, Salah 31',
      ),
      linkedFarzId: 24,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_03',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Güneş tam doğarken, tam tepede (istivâ vaktinde) iken ve batmak üzere sarardığında (o günün ikindi farzı hariç) namaz kılmak mekruhtur (kerâhet vakti).',
      en: 'Performing prayer exactly at sunrise, at solar zenith (istiwa), and right as the sun sets (except that day\'s \'Asr fard) is disliked/prohibited (karahah time).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Ukbe b. Âmir (r.a.) hadisinde Hz. Peygamber\'in (s.a.v.) bu üç vakitte namaz kılmayı yasakladığı bildirilir.',
      en: 'Reported by \'Uqbah ibn \'Amir (r.a.) in Sahih Muslim regarding the three prohibited moments.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Namazın sıhhati için vaktin girmesi şart olduğu gibi, kerâhet vakitlerine de riayet edilir: Güneşin doğuşu, tam tepe noktası ve batışı esnasında nâfile veya kaza namazı kılınmaz.',
        en: 'Entering the valid prayer window is fard, and three brief solar transitions (sunrise, zenith, sunset) are avoided for voluntary and make-up prayers.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müslim, Müsâfirîn 293; Diyanet İlmihali Cilt 1, s. 233-236',
        en: 'Muslim, Musafirin 293; Diyanet Catechism Vol. 1, pp. 233-236',
      ),
      linkedFarzId: 25,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_04',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namazda niyetin asıl yeri neresidir ve hangi vakitte yapılması gerekir?',
      en: 'Where is the essential seat of intention (niyyah) for Salah, and when must it be present?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Asıl yeri kalptir; iftitah tekbirine bitişik olarak vakit girdikten sonra yapılır',
          en: 'Its seat is the heart; made after time enters, connected to the opening Takbir',
        ),
        LocalizedText(
          tr: 'Yalnızca dille yüksek sesle söylenmesi şarttır, kalp gerekmez',
          en: 'Only loud verbal utterance counts, without heart awareness',
        ),
        LocalizedText(
          tr: 'Selâm verdikten sonra yapılır',
          en: 'Made after concluding with Taslim',
        ),
        LocalizedText(
          tr: 'Bir gün önceden yapılması bütün farzlar için zorunludur',
          en: 'Must be made the night before for all prayers',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Ameller niyetlere göredir" hadisi uyarınca niyet kalbin azmidir; dille söylemek kalbe yardımcı olmak içindir.',
      en: 'By the hadith "Actions are judged by intentions," niyyah resides in the heart while verbalizing is merely an aid.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Niyet, hangi namazın kılındığını kalben bilmek ve Allah rızası için namaza yönelmektir; iftitah tekbiriyle ara vermeden birleşmesi esastır.',
        en: 'Niyyah is the conscious resolve of the heart specifying the prayer for Allah\'s sake, joined directly to Takbirat al-Ihram.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Bed\'ü\'l-vahy 1; Diyanet İlmihali Cilt 1, s. 237-239',
        en: 'Bukhari, Bad\' al-Wahy 1; Diyanet Catechism Vol. 1, pp. 237-239',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde niyet namazın dışından bir şarttır ve iftitah tekbirinden hemen önce kalben bulunmalıdır.',
        en: 'In Hanafi fiqh, intention is a prerequisite condition immediately preceding the opening Takbir.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde niyet namazın içindeki rükünlerin ilkidir ve tam iftitah tekbiri alınırken kalpte hazır tutulur.',
        en: 'In Shafi\'i fiqh, intention is the first internal pillar, held in the heart simultaneously with the opening Takbir.',
      ),
      linkedFarzId: 26,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_05',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namaza başlarken dünya kelâmını ve namaz dışı işleri haram kılıp kulun namaza girmesini sağlayan "Allâhü Ekber" sözüne ne ad verilir?',
      en: 'What is the classical name of the opening "Allahu Akbar" that enters one into the sacred state of Salah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Teşrik Tekbiri', en: 'Takbir at-Tashriq'),
        LocalizedText(tr: 'İntikal Tekbiri', en: 'Transition Takbir'),
        LocalizedText(tr: 'İftitah Tekbiri (Tahrîme)', en: 'Takbirat al-Ihram (Iftitah)'),
        LocalizedText(tr: 'Kunut Tekbiri', en: 'Qunut Takbir'),
      ],
      correctIndex: 2,
    ),
    hint: LocalizedText(
      tr: '"Açılış tekbiri" anlamına gelen ve namazın içindeki ilk farz sayılan tekbirdir.',
      en: 'Literally "the Opening/Consecrating Takbir," the first internal fard of Salah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Peygamber (s.a.v.): "Namazın anahtarı temizlik, başlangıcı (tahrîmesi) tekbir, bitimi ise selâmdır" buyurmuştur.',
        en: 'The Prophet (ﷺ) said: "The key to prayer is purification, its consecration is the Takbir, and its conclusion is the Taslim."',
      ),
      sourceRef: LocalizedText(
        tr: 'Ebû Dâvûd, Tahâret 31; Tirmizî, Tahâret 3; Diyanet İlmihali Cilt 1, s. 240',
        en: 'Abu Dawud, Taharah 31; Tirmidhi, Taharah 3; Diyanet Catechism Vol. 1, p. 240',
      ),
      linkedFarzId: 27,
      linkedZikirKey: 'Allahuekber',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_06',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Farz ve vacip namazlarda gücü yeten kimsenin ayakta durması (Kıyam) farzdır; ayakta durmaya gücü yetmeyen hasta oturarak namazını eda edebilir.',
      en: 'Standing upright (Qiyam) in fard and wajib prayers is obligatory for whoever is physically able; one unable to stand may pray sitting.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'İmrân b. Husayn (r.a.) hadisinde "Ayakta kıl; gücün yetmezse oturarak kıl" buyrulmuştur.',
      en: 'In the hadith of \'Imran ibn Husayn (r.a.): "Pray standing; if you cannot, then sitting."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kıyam, Allah\'ın huzurunda edep ve kullukla ayakta durmaktır. Sağlık engeli olan kimse ise ruhsat gereği oturarak veya îmâ ile namazını kılar.',
        en: 'Qiyam embodies humble standing before Allah; Islamic law mercifully grants sitting or gesturing (ima\') to the sick and infirm.',
      ),
      sourceRef: LocalizedText(
        tr: 'Bakara Sûresi, 2/238; Buhârî, Taksîru\'s-salât 19',
        en: 'Surah Al-Baqarah, 2:238; Bukhari, Taqsir as-Salah 19',
      ),
      linkedFarzId: 28,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_07',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Namazda "Kıraat" rüknü ve Fâtiha Sûresi\'nin okunması konusunda Hanefî ve Şâfiî mezheplerinin hükmü hangi seçenekte doğru karşılaştırılmıştır?',
      en: 'Which option accurately compares the Hanafi and Shafi\'i rulings on Qur\'anic recitation (Qira\'ah) and Surah Al-Fatihah in Salah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hanefîlerde Kur\'ân\'dan kolay gelen miktar farz, Fâtiha vaciptir; Şâfiîlerde her rekâtta Fâtiha okumak farzdır (rükündür)',
          en: 'In Hanafi fiqh reciting some Qur\'an is fard and Fatihah is wajib; in Shafi\'i fiqh reciting Fatihah in every rak\'ah is fard',
        ),
        LocalizedText(
          tr: 'Her iki mezhepte de Fâtiha okumak sadece nâfile namazlarda sünnettir',
          en: 'In both schools Fatihah is merely Sunnah in voluntary prayers',
        ),
        LocalizedText(
          tr: 'Hanefîlerde imama uyan cemaatin yüksek sesle sûre okuması farzdır',
          en: 'In Hanafi fiqh followers behind an imam must recite aloud',
        ),
        LocalizedText(
          tr: 'Şâfiîlerde yalnız ilk rekâtta bir âyet okumak yeterlidir, Fâtiha okunmaz',
          en: 'In Shafi\'i fiqh only one verse in the first rak\'ah suffices without Fatihah',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hanefîler Müzzemmil 20. âyeti mutlak delil alıp Fâtiha hadisini vacip sayar; Şâfiîler "Fâtiha\'sız namaz olmaz" hadisiyle Fâtiha\'yı bizzat rükün kabul eder.',
      en: 'Hanafis ground the fard in Al-Muzzammil 73:20 and make Fatihah wajib; Shafi\'is establish Fatihah itself as the fard pillar.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tek başına namaz kılan bir Müslüman her iki mezhebe göre de Fâtiha\'yı mutlaka okur; cemaatle namazda ise mezhebine uygun edebi gözetir.',
        en: 'Praying individually, a Muslim always recites Al-Fatihah; in congregation, each school follows its established Sunnah proof.',
      ),
      sourceRef: LocalizedText(
        tr: 'Müzzemmil, 73/20; Buhârî, Ezân 95; Diyanet İlmihali Cilt 1, s. 243-246',
        en: 'Al-Muzzammil 73:20; Bukhari, Adhan 95; Diyanet Catechism Vol. 1, pp. 243-246',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde Fâtiha ve zamm-ı sûre vaciptir; cemaatle namazda imamın kıraati cemaate kâfidir, cemaat susup dinler.',
        en: 'In Hanafi fiqh, Fatihah is wajib, and behind an imam the congregation listens silently as the imam\'s recitation suffices.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde Fâtiha okumak her rekâtta (imama uyan dâhil) rükündür; cehrî namazda imam Fâtiha\'yı bitirince sessizce okunur.',
        en: 'In Shafi\'i fiqh, reciting Al-Fatihah is a fard pillar in every rak\'ah for both imam and follower.',
      ),
      linkedFarzId: 29,
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_08',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Namazın rükünlerinden "Rükû"da sünnete uygun tesbih ve duruş ölçüsü hangisidir?',
      en: 'In the pillar of bowing (Ruku\'), what is the Sunnah posture and glorification?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Eller dizleri kavrayıp sırt düz olacak şekilde eğilmek ve "Sübhâne Rabbiye\'l-Azîm" demek',
          en: 'Grasping the knees with a level back and saying "Subhana Rabbiyal-\'Azim"',
        ),
        LocalizedText(
          tr: 'Alnı yere koyup "Sübhâne Rabbiye\'l-A\'lâ" demek',
          en: 'Placing the forehead on the ground and saying "Subhana Rabbiyal-A\'la"',
        ),
        LocalizedText(
          tr: 'Diz üstü oturup Ettehiyyâtü okumak',
          en: 'Sitting on the knees and reciting At-Tahiyyat',
        ),
        LocalizedText(
          tr: 'Elleri kulak hizasına kaldırıp Kunut okumak',
          en: 'Raising hands to the ears and reciting Qunut',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Azîm (Yüce/Büyük) ismi rükûda, A\'lâ (En Yüce) ismi ise secdede tesbih edilir.',
      en: 'Al-\'Azim is glorified in Ruku\', whereas Al-A\'la is glorified in Sujud.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Her rekâtta bir defa rükû yapmak farzdır. Rükûda sırt ve başın düz tutulması, uzuvların sakinleşmesi (ta\'dîl-i erkân) ve üç kez "Sübhâne Rabbiye\'l-Azîm" denmesi kâmil sünnettir.',
        en: 'Bowing in Ruku\' once per rak\'ah is fard; keeping the back level with composure (ta\'dil al-arkan) and saying "Subhana Rabbiyal-\'Azim" thrice fulfills the Sunnah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hac Sûresi, 22/77; Müslim, Salât 262; Diyanet İlmihali Cilt 1, s. 247',
        en: 'Surah Al-Hajj, 22:77; Muslim, Salah 262; Diyanet Catechism Vol. 1, p. 247',
      ),
      linkedFarzId: 30,
      linkedZikirKey: 'El-Azîm',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_09',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Hz. Peygamber\'in (s.a.v.) "Kulun Rabbine en yakın olduğu an" diye müjdelediği ve her rekâtta iki defa yapılması farz olan Secde, sünnet üzere kaç uzuv üzerine yapılır?',
      en: 'Described by the Prophet (ﷺ) as "the moment a servant is closest to his Lord" and fard twice per rak\'ah, upon how many body parts is complete Sujud performed?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Yedi uzuv (alın-burun, iki el, iki diz, iki ayak parmakları)',
          en: 'Seven bones/parts (forehead with nose, two palms, two knees, toes of both feet)',
        ),
        LocalizedText(
          tr: 'Üç uzuv (yalnız alın ve iki el)',
          en: 'Three parts (only forehead and two hands)',
        ),
        LocalizedText(
          tr: 'Dört uzuv (iki dirsek ve iki topuk)',
          en: 'Four parts (two elbows and two heels)',
        ),
        LocalizedText(
          tr: 'Beş uzuv (çene, iki omuz ve iki diz)',
          en: 'Five parts (chin, two shoulders, and two knees)',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Buhârî ve Müslim\'de geçen İbn Abbâs hadisinde "Yedi kemik (uzuv) üzerine secde etmekle emrolundum" buyrulur.',
      en: 'In the hadith of Ibn \'Abbas (Bukhari & Muslim): "I have been commanded to prostrate on seven bones."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Secde kulluğun zirvesidir. Her rekâtta iki defa secde etmek farzdır; secdede "Sübhâne Rabbiye\'l-A\'lâ" denir ve bolca dua edilmesi tavsiye olunur.',
        en: 'Sujud is the pinnacle of servitude. Performing two prostrations per rak\'ah on seven points while glorifying Allah Most High is central to Salah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Alak, 96/19; Buhârî, Ezân 133; Müslim, Salât 215',
        en: 'Surah Al-\'Alaq, 96:19; Bukhari, Adhan 133; Muslim, Salah 215',
      ),
      linkedFarzId: 31,
      linkedZikirKey: 'Subhanallah',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_10',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Namazın son rekâtının sonunda selâmdan önce "Ettehiyyâtü" okuyacak kadar oturmaya (Ka\'de-i Ahîre) Hanefî ve Şâfiî mezheplerinde ne hüküm verilir?',
      en: 'What is the ruling on the final sitting (Qa\'dah al-Akhirah) at the end of Salah before Taslim?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Namazın içindeki son farzdır (rükündür)',
          en: 'It is the final obligatory pillar (fard/rukn) of Salah',
        ),
        LocalizedText(
          tr: 'Yalnızca sabah namazında müstehaptır',
          en: 'Merely recommended only in Fajr prayer',
        ),
        LocalizedText(
          tr: 'Terk edilirse namaz bozulmaz, sehiv de gerekmez',
          en: 'Omitting it neither invalidates Salah nor requires prostration',
        ),
        LocalizedText(
          tr: 'Sadece Cuma namazına mahsustur',
          en: 'Specific only to Jumu\'ah prayer',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '32 Farz\'ın 32\'ncisi, yani namazın içindeki 6 farzın sonuncusudur.',
      en: 'It is the 32nd of the 32 Farz—the sixth and concluding internal pillar of Salah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ka\'de-i Ahîre (son oturuş) namazın rüknüdür. Bu oturuşta Tahiyyât, Salli-Bârik ve Rabbenâ duaları okunarak selâmla namaz tamamlanır.',
        en: 'Qa\'dah al-Akhirah is an essential pillar of Salah, during which At-Tahiyyat, Salawat, and supplications are recited before concluding with Salam.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Ezân 148; Diyanet İlmihali Cilt 1, s. 249-250',
        en: 'Bukhari, Adhan 148; Diyanet Catechism Vol. 1, pp. 249-250',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde teşehhüd miktarı oturmak farz, Ettehiyyâtü\'yü okumak vacip, Salli-Bârik okumak sünnettir.',
        en: 'In Hanafi fiqh, sitting the duration of Tashahhud is fard, reciting At-Tahiyyat is wajib, and Salawat is Sunnah.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde son oturuşla birlikte Tahiyyât\'ı ve Peygamberimize salavâtı okumak ile birinci selâm da rükündür (farzdır).',
        en: 'In Shafi\'i fiqh, the final sitting, reciting Tashahhud, sending Salawat upon the Prophet (ﷺ), and the first Salam are all fard pillars.',
      ),
      linkedFarzId: 32,
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_11',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.hanafi,
    stem: LocalizedText(
      tr: 'Hanefî mezhebine göre namazın vaciplerinden biri yanılarak (sehven) terk edildiğinde veya geciktirildiğinde namazı telafi etmek için ne yapılır?',
      en: 'According to the Hanafi school, what rectifies a prayer when one of its wajib acts is unintentionally omitted or delayed?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Tilâvet Secdesi yapılır', en: 'Sujud at-Tilawah is performed'),
        LocalizedText(tr: 'Şükür Secdesi yapılır', en: 'Sujud ash-Shukr is performed'),
        LocalizedText(tr: 'Gusül abdesti yenilenir', en: 'Ghusl must be renewed'),
        LocalizedText(tr: 'Namazın sonunda Sehiv Secdesi yapılır', en: 'Sujud as-Sahw (Prostration of Forgetfulness) is performed'),
      ],
      correctIndex: 3,
    ),
    hint: LocalizedText(
      tr: '"Unutma / yanılma secdesi" anlamına gelir; farzın terki namazı bozarken vacibin sehven terki bununla telafi edilir.',
      en: 'Literally "Prostration of Forgetfulness"; omitting a fard invalidates Salah, whereas unintentionally omitting a wajib is mended by it.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hanefîlerde Fâtiha\'yı unutmak veya ilk oturuşu atlamak gibi bir vacibin yanılarak terki halinde son oturuşta Tahiyyât\'tan sonra sağa selâm verilip iki secde yapılır (Sehiv Secdesi).',
        en: 'In Hanafi fiqh, forgetting a wajib (such as Fatihah or the first sitting) requires Sujud as-Sahw: giving Salam to the right after Tashahhud, prostrating twice, then completing Tashahhud and Salawat.',
      ),
      sourceRef: LocalizedText(
        tr: 'Buhârî, Sehv 1-5; Müslim, Mesâcid 85; Diyanet İlmihali Cilt 1, s. 285-289',
        en: 'Bukhari, Sahw 1-5; Muslim, Masajid 85; Diyanet Catechism Vol. 1, pp. 285-289',
      ),
      hanafiNote: LocalizedText(
        tr: 'Hanefîlerde vacibin sehven terki veya geciktirilmesi sebebiyle sağa selâm verildikten sonra iki secde yapılır.',
        en: 'In Hanafi fiqh, Sujud as-Sahw is done after a single Salam to the right due to omitting or delaying a wajib.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Şâfiîlerde sehiv secdesi sünnettir; eb\'âz sünnetlerin (ilk teşehhüd, sabah kunutu vb.) terki halinde selâmdan hemen önce iki secde yapılır.',
        en: 'In Shafi\'i fiqh, Sujud as-Sahw is Sunnah, performed immediately before Salam when an ab\'ad Sunnah (like first Tashahhud or Fajr Qunut) is omitted.',
      ),
      linkedFarzId: 32,
    ),
  ),
];
