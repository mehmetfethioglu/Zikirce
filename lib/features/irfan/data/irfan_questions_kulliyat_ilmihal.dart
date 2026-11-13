import '../domain/irfan_models.dart';

/// 24 Authentic Bilingual (TR/EN) Questions sourced from Külliyat books for 32 Farz & İlmihal.
const List<IrfanQuestion> kIrfanQuestionsKulliyatIlmihal = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 8 QUESTIONS (ilm_b_12..ilm_b_19)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_b_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim\'in Kitâbü\'t-Tahâret bölümünde rivayet edilen hadis-i şerifte Peygamber Efendimiz (s.a.v.) "Temizlik (et-tuhûr) ...... yarısıdır" buyurmuştur. Boşluğa hangisi gelir?',
      en: 'In the hadith narrated in Sahih Muslim (Book of Purification), the Prophet (ﷺ) stated: "Purification (at-tuhur) is half of ......" Which word completes it?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'İmanın', en: 'Faith (Iman)'),
        LocalizedText(tr: 'İlim tahsilinin', en: 'Seeking knowledge'),
        LocalizedText(tr: 'Hac ibadetinin', en: 'The pilgrimage'),
        LocalizedText(tr: 'Kardeşliğin', en: 'Brotherhood'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Aynı hadisin devamında "Elhamdülillâh mîzânı doldurur" buyrulur.',
      en: 'The same hadith continues: "Alhamdulillah fills the scale."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ebû Mâlik el-Eş\'arî\'den (r.a.) rivayetle maddî ve mânevî temizlik imanın yarısı olarak nitelendirilmiştir; zira namazın anahtarı abdest ve tahârettir.',
        en: 'Narrated from Abu Malik al-Ash\'ari (r.a.), both physical and spiritual purity are described as half of faith, for purification is the key to Salah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Tahâret 1 (Hadis No: 223)',
        en: 'Sahih Muslim, Kitab at-Taharah 1 (Hadith 223)',
      ),
      linkedFarzId: 13,
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'Elhamdülillah',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Küçük Sözler\'deki Dördüncü Söz\'e göre namaz, insanın ruhuna, kalbine ve aklına büyük bir rahat ve gıda sağladığı gibi beden ve azalar için de zahmetli değil kolay bir ibadettir.',
      en: 'According to the Fourth Word in Küçük Sözler, Salah is a vital nourishment and comfort for the spirit, heart, and mind while remaining light on the body.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Dördüncü Söz "Namaz ne kadar kıymetdar ve mühim..." cümlesiyle başlar ve iki kardeş temsiliyle anlatılır.',
      en: 'The Fourth Word illustrates the value of daily prayer through the parable of two travelers.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Dördüncü Söz\'de günde bir saatlik vaktin beş vakit namaza ayrılmasının, ebedî hayat yolculuğunda tükenmez bir azık ve kalbî huzur vesilesi olduğu beyan edilir.',
        en: 'The Fourth Word explains that dedicating about one hour across five daily prayers serves as inexhaustible provision and serenity for the eternal journey.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Küçük Sözler, Dördüncü Söz',
        en: 'Risale-i Nur Collection, Short Words (Küçük Sözler), Fourth Word',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_rn_kucuk_sozler',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "İman" bölümünün başında geçen meşhur hadise göre İslâm\'ın beş temel esasını (şartını) doğru şekilde eşleştiriniz.',
      en: 'Match the core duties from the famous Hadith on the Five Pillars of Islam narrated at the opening of Sahih al-Bukhari.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Kelime-i Şehâdet', en: 'Testimony of Faith'),
          right: LocalizedText(
            tr: 'Tevhid ve nübüvveti ikrar',
            en: 'Affirming Tawhid and Prophethood',
          ),
        ),
        (
          left: LocalizedText(tr: 'Namaz (Salât)', en: 'Salah (Prayer)'),
          right: LocalizedText(
            tr: 'Günde beş vakit dosdoğru kılmak',
            en: 'Establishing five daily prayers',
          ),
        ),
        (
          left: LocalizedText(tr: 'Zekât', en: 'Zakah'),
          right: LocalizedText(
            tr: 'Nisap miktarı maldan pay vermek',
            en: 'Giving prescribed share from wealth',
          ),
        ),
        (
          left: LocalizedText(tr: 'Oruç & Hac', en: 'Fasting & Hajj'),
          right: LocalizedText(
            tr: 'Ramazan orucu ve Kâbe ziyareti',
            en: 'Ramadan fast and pilgrimage',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İbn Ömer (r.a.) rivayetinde İslâm\'ın beş temel direk üzerine bina edildiği bildirilir.',
      en: 'Narrated by Ibn Umar (r.a.), Islam is built upon five pillars.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm\'ın beş şartı ferdî ve içtimaî ibadet hayatını ayakta tutan ana sütunlardır; kalpteki iman bu amellerle kemale erer.',
        en: 'The five pillars of Islam sustain individual and communal devotion, manifesting inner faith through outward action.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Îmân 2 (Hadis No: 8)',
        en: 'Sahih al-Bukhari, Kitab al-Iman 2 (Hadith 8)',
      ),
      linkedFarzId: 7,
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Ramazan, İktisat ve Şükür Risalesi\'ne göre Ramazan orucu nefsin sahte rubûbiyet ve başıboşluk iddiasını kırarak insana neyi en parlak biçimde gösterir?',
      en: 'According to the Treatise on Ramadan, Frugality, and Gratitude, breaking the ego\'s illusion of self-sufficiency through fasting most clearly reveals what truth to a believer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kulluğunu, aczini ve nimetlerin gerçek sahibine şükür borcunu',
          en: 'One\'s servitude, dependence, and duty of gratitude to the True Provider',
        ),
        LocalizedText(
          tr: 'Sadece bedensel spor kurallarını',
          en: 'Only athletic conditioning rules',
        ),
        LocalizedText(
          tr: 'Dünya ticaretinde kâr oranlarını',
          en: 'Commercial profit margins',
        ),
        LocalizedText(
          tr: 'Yalnızca tarihî takvim hesabını',
          en: 'Merely historical calendar calculation',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Birinci ve İkinci Nüktelerde rubûbiyet-i ilâhiye ve şükür hakikatleri işlenir.',
      en: 'The first two points focus on divine Lordship and gratitude for blessings.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Açlık ve perhizle insan kendi başına bir lokmaya bile mâlik olmadığını idrak eder; iftar vaktinde bir hurma veya suyun dahi büyük bir ilâhî ihsan olduğunu tadarak hakikî şükre erer.',
        en: 'Through fasting, a person realizes they do not truly own even a morsel of food and tastes genuine gratitude at sunset for Allah\'s provision.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Ramazan Risalesi (29. Mektup, 2. Kısım)',
        en: 'Risale-i Nur Collection, Treatise on Ramadan (29th Letter, Part 2)',
      ),
      linkedFarzId: 11,
      linkedBookId: 'book_rn_ramazan_iktisat_sukur',
      linkedZikirKey: 'Eş-Şekûr',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sünen-i Tirmizî ve Ebû Dâvûd\'da rivayet edilen "Abdest ve diş temizliği" hadislerinde Peygamber Efendimiz (s.a.v.) ümmetine zorluk vermemek için her namazda neyi emretmekten çekindiğini ancak çok teşvik ettiğini bildirmiştir?',
      en: 'In narrations of Sunan at-Tirmidhi and Abu Dawud, what purifying practice did the Prophet (ﷺ) refrain from making obligatory before every prayer only to avoid hardship, while strongly encouraging it?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Misvak (diş temizliği)', en: 'Using the Siwak (tooth-stick)'),
        LocalizedText(tr: 'Gusül almak', en: 'Taking Ghusl'),
        LocalizedText(tr: 'Teyemmüm etmek', en: 'Performing Tayammum'),
        LocalizedText(tr: 'İtikâfa girmek', en: 'Entering I\'tikaf'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Ümmetime meşakkat vermeyecek olsaydım her namaz vaktinde ... emrederdim." hadisi meşhurdur.',
      en: 'Famous hadith: "Had it not been a burden on my Ummah, I would have commanded them to use ... before every prayer."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ağız ve diş temizliği hem beden sıhhatine hem de Kur\'ân tilâveti ve münâcat edebine yakışan kuvvetli bir sünnettir.',
        en: 'Oral hygiene with the siwak or toothbrush is an emphasized Sunnah honoring both health and standing before Allah in prayer.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Tahâret 18; Sünen-i Ebû Dâvûd, Tahâret 25',
        en: 'Sunan at-Tirmidhi, Taharah 18; Sunan Abi Dawud, Taharah 25',
      ),
      linkedFarzId: 13,
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sünen-i Nesâî ve Buhârî\'de bildirildiği üzere cemaatle kılınan namaz, tek başına kılınan namazdan yirmi beş veya yirmi yedi derece daha faziletlidir.',
      en: 'As reported in Sunan an-Nasa\'i and Sahih al-Bukhari, prayer performed in congregation excels solitary prayer by twenty-five or twenty-seven degrees.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Buhârî ve Nesâî\'deki "Salâtü\'l-Cemâa" bablarında bu müjde yer alır.',
      en: 'Both collections record 25 and 27 degrees in their chapters on congregational prayer.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cemaatle namaz müminler arasında kardeşliği, eşitliği ve saf düzenini pekiştirirken mânevî sevabı da kat kat artırır.',
        en: 'Congregational prayer strengthens unity and humility among believers while multiplying spiritual reward.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Nesâî, İmâmet 42; Sahîh-i Buhârî, Ezân 30',
        en: 'Sunan an-Nasa\'i, Imamah 42; Sahih al-Bukhari, Adhan 30',
      ),
      linkedFarzId: 9,
      linkedBookId: 'book_hadith_nesai',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn\'de İmam Nevevî\'nin "Niyet ve İhlâs" babının ilk hadisi olarak yer verdiği temel ilke hangisidir?',
      en: 'What foundational principle opens Imam an-Nawawi\'s Riyad as-Salihin in the Chapter on Sincerity and Intention?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Ameller ancak niyetlere göredir; herkese ancak niyet ettiği vardır',
          en: 'Actions are judged solely by intentions, and every person has what they intended',
        ),
        LocalizedText(
          tr: 'Sadece gece namazı kılanlar kurtulur',
          en: 'Only those who pray at night succeed',
        ),
        LocalizedText(
          tr: 'İbadetlerde sesli okumak şarttır',
          en: 'Reciting aloud is mandatory in all worship',
        ),
        LocalizedText(
          tr: 'Seferde hiçbir namaz kılınmaz',
          en: 'No prayers are performed while traveling',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hz. Ömer (r.a.) tarafından rivayet edilen "İnneme\'l-a\'mâlü bi\'n-niyyât" hadisidir.',
      en: 'Narrated by Umar ibn al-Khattab (r.a.): "Innama al-a\'malu bin-niyyat."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Halîs niyet, mübah günlük işleri dahi ibadete dönüştürür; niyetsiz ve gösterişli amel ise ruhunu kaybeder.',
        en: 'Pure intention transforms lawful daily acts into worship, whereas ostentation drains deeds of spiritual value.',
      ),
      sourceRef: LocalizedText(
        tr: 'Riyâzü\'s-Sâlihîn, Hadis No: 1; Buhârî, Bed\'ü\'l-vahy 1',
        en: 'Riyad as-Salihin, Hadith 1; Sahih al-Bukhari, Bad\' al-Wahy 1',
      ),
      linkedFarzId: 27,
      linkedBookId: 'book_hadith_riyazus_salihin',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_b_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.baslangic,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sünen-i İbn Mâce\'de "İlim öğrenmek her Müslüman üzerine farzdır" hadisi hangi konuda temel ölçü koyar?',
      en: 'In Sunan Ibn Majah, the hadith "Seeking knowledge is an obligation upon every Muslim" establishes what foundational duty?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İman ve ibadetlerini sahih şekilde öğrenecek kadar ilmihal bilmek',
          en: 'Learning essential creed and worship knowledge (Fard al-\'Ayn)',
        ),
        LocalizedText(
          tr: 'Yalnızca yabancı dillerde şiir ezberlemek',
          en: 'Memorizing foreign poetry alone',
        ),
        LocalizedText(
          tr: 'Hiç çalışmadan inzivaya çekilmek',
          en: 'Retreating from all livelihood',
        ),
        LocalizedText(
          tr: 'Sadece yolculuk haritaları çizmek',
          en: 'Only drawing travel maps',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kişinin günlük iman, namaz, oruç ve helâl-haram bilgisini öğrenmesi "farz-ı ayın"dır.',
      en: 'Personal knowledge of faith, prayer, fasting, and lawful conduct is an individual obligation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm\'da ilim, ibadetin nuru ve istikametin rehberidir. Bilinçli kulluk için her müminin kendi hâline gereken farzları öğrenmesi şarttır.',
        en: 'Knowledge illuminates worship and guards uprightness; every believer must learn what is necessary for sound faith and practice.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i İbn Mâce, Mukaddime 17 (Hadis No: 224)',
        en: 'Sunan Ibn Majah, Muqaddimah 17 (Hadith 224)',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_hadith_ibn_mace',
      linkedZikirKey: 'Hz. Muhammed (s.a.v.) Duası 7',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 8 QUESTIONS (ilm_o_12..ilm_o_19)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_o_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sözler\'deki Dokuzuncu Söz\'e göre beş vakit namazın özellikle fecir, öğle, ikindi, akşam ve yatsı vakitlerine tahsis edilmesinin temel hikmetlerinden biri nedir?',
      en: 'According to the Ninth Word in Sözler, what is a central wisdom behind assigning the five daily prayers specifically to dawn, noon, afternoon, sunset, and night?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Her vaktin kâinatta önemli bir inkılâp ve insan ömrünün/senenin devirlerine işaret eden azametli bir tasarruf anı olması',
          en: 'Each time marks a major cosmic transition reflecting the stages of human life and divine Majesty',
        ),
        LocalizedText(
          tr: 'Güneş saatlerini süslemek için rastgele seçilmesi',
          en: 'Being chosen arbitrarily to decorate sundials',
        ),
        LocalizedText(
          tr: 'Sadece kış mevsimine uyarlanması',
          en: 'Being tailored only for winter months',
        ),
        LocalizedText(
          tr: 'İnsanların uykusunu tamamen yasaklamak için konulması',
          en: 'Intending to forbid sleep completely',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Dokuzuncu Söz\'de her namaz vakti, ilâhî kudretin büyük bir devir ve tecellî başlangıcı olarak açıklanır.',
      en: 'The Ninth Word links each prayer window to a distinct renewal of divine power in the cosmos and human life.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sabah uyandığımız an gençlik ve bahar başlangıcını; öğle kemali; ikindi zevali; akşam dünyadan ayrılışı; yatsı ise kabir ve berzah gecesini hatırlatarak kulda daimî bir uyanıklık meydana getirir.',
        en: 'Dawn recalls spring and youth, noon maturity, afternoon decline, sunset departure from the world, and night the veil of eternity, keeping the heart awake.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Sözler, Dokuzuncu Söz',
        en: 'Risale-i Nur Collection, The Words (Sözler), Ninth Word',
      ),
      linkedFarzId: 23,
      linkedBookId: 'book_rn_sozler',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Tirmizî\'de geçen rivayetler ışığında, rükû ve secdelerde itidal üzere beklemeye (ta\'dîl-i erkâna) dair fıkhî çerçeve hangi seçenekte doğru verilmiştir?',
      en: 'In light of Sunan Abi Dawud and at-Tirmidhi, which statement accurately summarizes the juristic view on calmness and composure in bowing and prostration (Ta\'dil al-Arkan)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Rükû, kavme, secde ve celsede azaların en az bir tesbih miktarı sükûnet bulması gerekir; Şâfiî\'de farz, Hanefî\'de sahih görüşe göre vaciptir',
          en: 'Pausing calmly in ruku, standing, sujud, and sitting is essential—obligatory (fard) in the Shafi\'i school and wajib in the Hanafi school',
        ),
        LocalizedText(
          tr: 'Namazı olabildiğince hızlı bitirmek sünnettir',
          en: 'Rushing through movements is recommended',
        ),
        LocalizedText(
          tr: 'Sadece Cuma namazında geçerlidir',
          en: 'It applies only to Friday prayer',
        ),
        LocalizedText(
          tr: 'Yalnızca imamın uyması yeterlidir',
          en: 'Only the imam needs to observe it',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Musî-i Salâh" (namazını hızlı kılan sahâbî) hadisinde Peygamberimiz üç defa "Dön, namazını yeniden kıl" buyurmuştur.',
      en: 'In the hadith of the man who prayed hastily, the Prophet (ﷺ) told him to repeat his prayer calmly.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ta\'dîl-i erkân namazın ruhunu ve huşûunu muhafaza eder. Azalar yerine oturmadan aceleyle kalkmak namazın kemalini zedeler.',
        en: 'Ta\'dil al-Arkan preserves serenity and reverence (khushu) in prayer; rushing compromises its validity or perfection.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Ebû Dâvûd, Salât 144; Sahîh-i Buhârî, Ezân 95',
        en: 'Sunan Abi Dawud, Salah 144; Sahih al-Bukhari, Adhan 95',
      ),
      hanafiNote: LocalizedText(
        tr: 'Ebû Yûsuf ve tercih edilen fetvaya göre vaciptir; sehven terkinde sehiv secdesi gerekir.',
        en: 'According to Abu Yusuf and the relied-upon Hanafi position, it is wajib; omitting it inadvertently requires prostration of forgetfulness.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Tuma\'nîne (azaların sükûneti) rükû, i\'tidâl, secde ve iki secde arası oturuşta rükün/farzdır.',
        en: 'Calmness (tuma\'ninah) is an integral pillar (fard) in ruku, rising, sujud, and sitting between prostrations.',
      ),
      linkedFarzId: 29,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Haşir Risalesi\'nde (Onuncu Söz) âhiret ve yeniden diriliş hakikatini ispat için en sık başvurulan kâinat delili hangisidir?',
      en: 'In the Treatise on Resurrection (Tenth Word / Haşir Risalesi), which recurring cosmic sign is presented as a vivid proof of bodily resurrection?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Her baharda yüz binlerce bitki ve hayvan türünün kışın ölümünden sonra yeniden diriltilmesi',
          en: 'The annual revival of hundreds of thousands of plant and animal species every spring after winter',
        ),
        LocalizedText(
          tr: 'Sadece antik taş yazıtların okunması',
          en: 'Reading ancient stone inscriptions alone',
        ),
        LocalizedText(
          tr: 'Yalnızca rüya tabirleri',
          en: 'Dream interpretations exclusively',
        ),
        LocalizedText(
          tr: 'Sadece göktaşı büyüklükleri',
          en: 'Meteorite sizes only',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Rûm Sûresi 50. âyetteki "Şimdi Allah\'ın rahmet eserlerine bak, yeryüzünü ölümünün ardından nasıl diriltiyor!" âyetiyle paraleldir.',
      en: 'Parallels Surah Ar-Rum 30:50 on how Allah revives the dead earth.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kışın ölen tabiatı baharda bir anda dirilten Kâdir-i Zülcelâl için insanları kıyamet gününde yeniden haşretmek son derece kolay ve hikmetinin gereğidir.',
        en: 'The Almighty who revives dead nature effortlessly every spring demonstrates both His power and wisdom to resurrect humanity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Haşir Risalesi (Onuncu Söz); Rûm Sûresi, 30/50',
        en: 'Risale-i Nur Collection, Treatise on Resurrection (10th Word); Ar-Rum 30:50',
      ),
      linkedFarzId: 5,
      linkedBookId: 'book_rn_hasir_risalesi',
      linkedZikirKey: 'El-Bâkî',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Nesâî\'deki "Seferde Namaz" rivayetlerine göre, namazların iki vakitte birleştirilerek (cem\') kılınması Hanefî ve Şâfiî mezheplerinde nasıl uygulanır?',
      en: 'Based on narrations in Sunan Abi Dawud and an-Nasa\'i regarding Prayer on a Journey, how do the Hanafi and Shafi\'i schools approach combining two prayers (Jam\')?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şâfiî\'de yolculukta cem\'-i takdîm ve cem\'-i te\'hîr caizdir; Hanefî\'de ise cem\' yalnız Hac\'da Arafat ve Müzdelife\'ye mahsustur',
          en: 'Shafi\'i permits combining prayers while traveling; Hanafi limits actual combining to Arafat and Muzdalifah during Hajj',
        ),
        LocalizedText(
          tr: 'Yolculukta namaz tamamen terk edilir',
          en: 'Prayers are completely dropped while traveling',
        ),
        LocalizedText(
          tr: 'Yalnızca sabah ile öğle birleştirilir',
          en: 'Only Fajr and Dhuhr may be combined',
        ),
        LocalizedText(
          tr: 'Akşam namazı 1 rekâta indirilir',
          en: 'Maghrib is shortened to 1 rak\'ah',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Her iki mezhep de seferde dört rekâtlı farzların iki rekât (kasr) kılındığında müttefiktir; farklılık cem\' ruhsatındadır.',
      en: 'Both schools agree on shortening 4-rak\'ah prayers to 2 during travel; they differ on combining times.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm fıkhı yolcuya kolaylık tanır; Hanefî mezhebi Arafat/Müzdelife dışında vakit sınırlarını koruyup "sûrî cem\'" yolunu açık tutarken, Şâfiî mezhebi hakikî cem\' ruhsatını seferde de uygular.',
        en: 'Islamic jurisprudence accommodates travelers: Hanafis preserve strict time boundaries outside Hajj (allowing apparent jam\'), while Shafi\'is permit full combining on journey.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Ebû Dâvûd, Sefer 5; Sünen-i Nesâî, Mevâkît 42',
        en: 'Sunan Abi Dawud, Safar 5; Sunan an-Nasa\'i, Mawaqit 42',
      ),
      hanafiNote: LocalizedText(
        tr: 'Arafat\'ta öğle-ikindi (cem\'-i takdîm) ve Müzdelife\'de akşam-yatsı (cem\'-i te\'hîr) dışında her namaz kendi vaktinde kılınır.',
        en: 'Outside Arafat and Muzdalifah during Hajj, each prayer is performed in its own time.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Meşru sefer şartları oluştuğunda öğle-ikindi ve akşam-yatsı takdîm veya te\'hîr ile cem\' edilebilir.',
        en: 'When valid travel conditions are met, Dhuhr-Asr and Maghrib-Isha may be combined either early or delayed.',
      ),
      linkedFarzId: 23,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sözler\'deki Yirmi Birinci Söz\'ün İkinci Makamına göre, abdest veya namazda gelen şüphe ve vesveseye karşı en etkili ilâç nedir?',
      en: 'According to the Second Station of the Twenty-First Word in Sözler, what is the most effective cure for recurring doubts (waswasah) during wudu or prayer?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Ehemmiyet vermemek ve üzerinde durmamaktır; zira vesvese önem verildikçe büyür, verilmedikçe söner',
          en: 'Giving it no importance and not dwelling on it—for waswasah grows with attention and fades when ignored',
        ),
        LocalizedText(
          tr: 'Her şüphede abdesti on defa tekrarlamaktır',
          en: 'Repeating wudu ten times at every doubt',
        ),
        LocalizedText(
          tr: 'Namazı tamamen bırakmaktır',
          en: 'Abandoning prayer altogether',
        ),
        LocalizedText(
          tr: 'Hiçbir zaman niyet etmemektir',
          en: 'Never forming an intention',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Birinci Vecih\'te "Hayaldeki şeytanın attığı şüpheye ehemmiyet vermezsen küçülür, kaybolur" prensibi öğretilir.',
      en: 'It teaches that ignoring imaginary doubts makes them shrink and vanish.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Vesvese hastası olan kimsenin, kalbinden geçirdiği küfür veya şüphe hayallerini kendi tasdiki sanmaması ve fıkhen yakin ile amel edip vesveseyi ciddiye almaması esastır.',
        en: 'Involuntary passing thoughts are not beliefs; acting upon certainty and ignoring intrusive doubts dissolves the burden of waswasah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Sözler, 21. Söz, 2. Makam',
        en: 'Risale-i Nur Collection, The Words (Sözler), 21st Word, Station 2',
      ),
      linkedFarzId: 13,
      linkedBookId: 'book_rn_sozler',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Mi\'rac ve Kader Risalesi\'ne (26. Söz) göre kaderin varlığı insanın iradesini (cüz\'-i ihtiyarîsini) tamamen ortadan kaldırır ve sorumluluğu düşürür.',
      en: 'According to the Treatise on Ascension and Destiny (26th Word), divine decree (Qadar) completely abolishes human free choice and removes moral responsibility.',
    ),
    payload: TrueFalsePayload(correctAnswer: false),
    hint: LocalizedText(
      tr: 'Kader bir ilim nev\'indendir; Allah\'ın ezelî ilmiyle bizim seçeceğimizi bilmesi bizi zorlaması demek değildir.',
      en: 'Qadar belongs to divine Knowledge; Allah\'s foreknowledge of our free choice does not coerce it.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İlim malûma tâbidir; Allah Teâlâ kulun kendi cüz\'-i ihtiyarîsiyle neyi seçeceğini ezelden bilir ve takdir eder. Dolayısıyla kul hayır veya şer tercihinden sorumludur.',
        en: 'Divine foreknowledge encompasses what the servant freely chooses; thus human moral responsibility remains intact alongside Qadar.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Mi\'rac ve Kader Risalesi (26. Söz)',
        en: 'Risale-i Nur Collection, Treatise on Mi\'raj and Destiny (26th Word)',
      ),
      linkedFarzId: 6,
      linkedBookId: 'book_rn_mirac_kader',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Sünen-i Tirmizî\'de bildirilen sehiv secdesi (yanılma secdesi) uygulamasıyla ilgili kavramları doğru şekilde eşleştiriniz.',
      en: 'Match the concepts related to the Prostration of Forgetfulness (Sujud as-Sahw) as taught in Sahih Muslim and Sunan at-Tirmidhi.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Sehiv Secdesi Adedi', en: 'Number of Prostrations'),
          right: LocalizedText(
            tr: 'İki secde ve ardından tahiyyat/selâm',
            en: 'Two prostrations with final sitting',
          ),
        ),
        (
          left: LocalizedText(tr: 'Sebebi', en: 'Primary Trigger'),
          right: LocalizedText(
            tr: 'Unutarak ziyade, noksan veya şek',
            en: 'Unintentional omission, addition, or doubt',
          ),
        ),
        (
          left: LocalizedText(tr: 'İmama Uyan (Muktedî)', en: 'Follower Behind Imam'),
          right: LocalizedText(
            tr: 'İmam yanılırsa ona uyar',
            en: 'Follows the imam if the imam errs',
          ),
        ),
        (
          left: LocalizedText(tr: 'Rükün (Farz) Terki', en: 'Omitting an Integral Pillar'),
          right: LocalizedText(
            tr: 'Yalnız sehivle telâfi edilmez, iade gerekir',
            en: 'Cannot be fixed by sahw alone; must be performed',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Sehiv secdesi unutma sebebiyle yapılan iki secdedir; kasten terk edilen veya rükün olan bir şeyi tek başına karşılamaz.',
      en: 'Sujud as-Sahw comprises two prostrations for inadvertence; missing a core pillar still requires performing that pillar.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sehiv secdesi namazdaki unutkanlık kaynaklı eksiklikleri onaran bir rahmet hükmüdür.',
        en: 'Sujud as-Sahw is a merciful remedy repairing inadvertent errors without forcing unnecessary repetition of the whole prayer.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Mesâcid 85-98; Sünen-i Tirmizî, Salât 173',
        en: 'Sahih Muslim, Masajid 85-98; Sunan at-Tirmidhi, Salah 173',
      ),
      linkedFarzId: 30,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_o_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.orta,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim\'de geçen "Zekât verilen mal asla eksilmez" hadis-i şerifinin bildirdiği üç hakikatten biri de zekât ve sadakanın malda neyi artırmasıdır?',
      en: 'In the Sahih Muslim hadith "Charity never decreases wealth," what does giving Zakah and charity increase in a believer\'s life alongside forgiveness?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bereketi, arınmayı ve affetmekle gelen izzeti',
          en: 'Blessing (barakah), purification, and honor through forgiveness',
        ),
        LocalizedText(
          tr: 'Borçlanma mecburiyetini',
          en: 'Mandatory debt',
        ),
        LocalizedText(
          tr: 'İbadet yükümlülüğünün kalkmasını',
          en: 'Exemption from prayer',
        ),
        LocalizedText(
          tr: 'Dünya sevgisinin artmasını',
          en: 'Attachment to hoarding',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Tevbe 103. âyette de sadakanın malı ve gönlü temizleyip arındırdığı bildirilir.',
      en: 'Surah At-Tawbah 9:103 likewise states that charity purifies and cleanses wealth and soul.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ebû Hüreyre (r.a.) rivayetinde Peygamber Efendimiz (s.a.v.): "Sadaka maldan hiçbir şey eksiltmez; affeden kulun Allah izzetini artırır" buyurmuştur.',
        en: 'The Prophet (ﷺ) assured that charity never reduces wealth, and Allah increases in honor the servant who forgives.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Birr 69 (Hadis No: 2588)',
        en: 'Sahih Muslim, Kitab al-Birr 69 (Hadith 2588)',
      ),
      linkedFarzId: 10,
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'Er-Rezzâk',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 8 QUESTIONS (ilm_i_12..ilm_i_19)
  // =========================================================================
  IrfanQuestion(
    id: 'ilm_i_12',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İmam Mâtürîdî\'nin Te\'vîlâtü\'l-Kur\'ân tefsirinde ve Mâtürîdiyye kelâmında "imanda ikrar ve tasdik" ilişkisi nasıl temellendirilir?',
      en: 'In Imam al-Maturidi\'s Ta\'wilat al-Qur\'an and Maturidi theology, how is the relationship between inner affirmation (tasdiq) and verbal confession (iqrar) in faith grounded?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İmanın asıl rüknü kalp ile tasdiktir; dil ile ikrar dünyevî ahkâmın icrası için şarttır, iman edip inkâra zorlanan kalbi mutmain ise mümin kalır',
          en: 'Heartfelt affirmation (tasdiq) is the core pillar of faith; verbal declaration (iqrar) establishes worldly legal status, while one coerced retains faith if the heart is serene',
        ),
        LocalizedText(
          tr: 'İman yalnızca dille söylemekten ibarettir, kalp tasdiki gerekmez',
          en: 'Faith is purely verbal with no need for heart conviction',
        ),
        LocalizedText(
          tr: 'Kalpten inanan kişi günah işlerse hemen kâfir olur',
          en: 'Any sin immediately negates inner faith',
        ),
        LocalizedText(
          tr: 'İman akıl ve bilgiden tamamen kopuk bir tahmindir',
          en: 'Faith is a blind guess severed from reason',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Nahl 106 (kalbi imanla mutmain iken zorlananlar) ve Hucurât 14 âyetleri Mâtürîdî\'nin temel delilleridir.',
      en: 'Surah An-Nahl 16:106 and Al-Hujurat 49:14 are key Qur\'anic proofs cited by al-Maturidi.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmam Mâtürîdî, imanın aslının kalpteki tasdik olduğunu ve büyük günah işleyen müminin dinden çıkmadığını, amelî sorumluluğunun ise devam ettiğini savunur.',
        en: 'Imam al-Maturidi distinguishes inner conviction from deeds: major sins are grave moral violations requiring repentance, yet they do not expel a believer from faith.',
      ),
      sourceRef: LocalizedText(
        tr: 'İmam Mâtürîdî, Te\'vîlâtü\'l-Kur\'ân, Nahl 16/106 & Hucurât 49/14',
        en: 'Al-Maturidi, Ta\'wilat al-Qur\'an, 16:106 & 49:14',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_maturidi',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_13',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sözler\'deki Yirmi Üçüncü Söz\'de imanın insana kazandırdığı nûr ve itminan ile küfür/gaflet arasındaki farkı özetleyen "İman hem nurdur hem kuvvettir" cümlesinin devamı nedir?',
      en: 'In the Twenty-Third Word of Sözler, what completes the famous maxim "Faith is both light and strength..."?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hakikî imanı elde eden adam kâinata meydan okuyabilir',
          en: 'One who attains true faith can challenge the entire universe',
        ),
        LocalizedText(
          tr: 'İman sadece yaşlılıkta gereken bir tesellidir',
          en: 'Faith is merely a consolation for old age',
        ),
        LocalizedText(
          tr: 'Kuvvet yalnız bedenî sporla kazanılır',
          en: 'Strength is gained only through athletics',
        ),
        LocalizedText(
          tr: 'İlim olmadan dünya işleri yürütülemez',
          en: 'Worldly trades cease without philosophy',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'İkinci Mebhas\'ın Birinci Noktasında müminin tevekkül ve istinad noktası anlatılır.',
      en: 'The First Point of Section Two describes the believer\'s point of reliance (tawakkul).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hakikî iman, insanı bütün kâinatın Sâni\'-i Hakîm\'ine intisap ettirdiği için hadisat karşısında kalbe sarsılmaz bir güven ve şahsiyet kazandırır.',
        en: 'True faith connects the believer to the Creator of the cosmos, granting unshakeable courage and inner dignity before all trials.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Sözler, 23. Söz, 1. Mebhas',
        en: 'Risale-i Nur Collection, The Words (Sözler), 23rd Word',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_rn_sozler',
      linkedZikirKey: 'Hasbünallahu ve ni\'mel vekil',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_14',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.comparative,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Şâfiî/Hanefî usulünde "su bulunamadığında veya kullanılması zarar verdiğinde" başvurulan teyemmümün niyeti ve uzuvları hakkında hangisi doğrudur?',
      en: 'In Sunan Abi Dawud and comparative jurisprudence, which statement is accurate regarding the intention and limbs wiped in Tayammum (dry ablution)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Niyetle birlikte eller temiz toprağa vurulup yüz ve kollar dirseklere kadar mesh edilir; Hanefî\'de iki vuruş sünnet, Şâfiî\'de iki vuruş rükündür',
          en: 'With intention, hands strike pure earth to wipe face and arms up to elbows; two strikes are Sunnah in Hanafi and obligatory in Shafi\'i',
        ),
        LocalizedText(
          tr: 'Teyemmümde ayaklar da mutlaka toprakla mesh edilir',
          en: 'The feet must also be wiped with earth in Tayammum',
        ),
        LocalizedText(
          tr: 'Teyemmüm yalnız cünüplük hâlinde geçerlidir, abdest yerine geçmez',
          en: 'Tayammum replaces Ghusl only, never Wudu',
        ),
        LocalizedText(
          tr: 'Niyet etmeden tozlu rüzgârda yürümek teyemmüm sayılır',
          en: 'Walking in dust without intention counts as Tayammum',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Mâide Sûresi 6. âyette teyemmümde yüz ve ellerin mesh edileceği bildirilir; niyet her iki mezhepte de şarttır.',
      en: 'Surah Al-Ma\'idah 5:6 prescribes wiping face and hands; intention is mandatory in both schools.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Teyemmüm, İslâm\'ın kolaylık prensibinin ("Allah size güçlük dilemez, temizlemek ister") açık tezahürüdür; hem hadesten hem cenâbetten tahâret sağlar.',
        en: 'Tayammum embodies Islamic ease ("Allah does not intend to make difficulty for you"), providing valid ritual purity when water is unavailable or harmful.',
      ),
      sourceRef: LocalizedText(
        tr: 'Mâide Sûresi, 5/6; Sünen-i Ebû Dâvûd, Tahâret 122',
        en: 'Surah Al-Ma\'idah, 5:6; Sunan Abi Dawud, Taharah 122',
      ),
      hanafiNote: LocalizedText(
        tr: 'Teyemmümde niyet farzdır; tek bir vuruş farzı düşürse de iki vuruşla yüzü ve dirseklere kadar kolları mesh etmek sünnettir.',
        en: 'Intention is fard; two strikes wiping face and arms to elbows is the established Sunnah.',
      ),
      shafiiNote: LocalizedText(
        tr: 'Niyet, tertip ve iki ayrı vuruşla yüzün ve dirseklerle birlikte kolların mesh edilmesi rükündür.',
        en: 'Intention, sequence, and two separate strikes for face and arms including elbows are obligatory pillars.',
      ),
      linkedFarzId: 20,
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_15',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'İhlâs ve Uhuvvet Risaleleri\'ndeki (21. Lem\'a) Dört Düsturdan ilkinde ihlası korumanın ve riyâdan kurtulmanın temel ölçüsü nedir?',
      en: 'In the Treatise on Sincerity (21st Flash / İhlâs Risalesi), what is the very first maxim for preserving sincerity and escaping ostentation?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Amelinizde rızâ-yı İlâhî olmalı; eğer O razı olsa bütün dünya küsse ehemmiyeti yok',
          en: 'Your sole aim in deeds must be Allah\'s pleasure; if He is pleased, the whole world\'s displeasure matters nothing',
        ),
        LocalizedText(
          tr: 'Yalnızca kalabalıkların takdirini kazanmaya çalışmak',
          en: 'Seeking applause from crowds first',
        ),
        LocalizedText(
          tr: 'Kardeşlerinin hizmetini tenkit ederek öne geçmek',
          en: 'Advancing by criticizing fellow believers',
        ),
        LocalizedText(
          tr: 'İbadetleri başkalarına göstererek teşvik etmekle yetinmek',
          en: 'Performing deeds primarily for public display',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"O razı olduktan ve kabul ettikten sonra, isterse bütün halk..." diye devam eden meşhur düsturdur.',
      en: 'Famous maxim: "Once He is pleased and accepts, even if all people..."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İhlâs, ibadet ve hizmetin tek gayesini Allah rızasına hasretmektir. Halkın teveccühünü beklemek amelin manevî bereketini yok eder.',
        en: 'Sincerity (Ikhlas) purifies intention exclusively for Allah\'s pleasure; seeking human acclaim strips worship of its spiritual fruit.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, İhlâs ve Uhuvvet Risaleleri (21. Lem\'a)',
        en: 'Risale-i Nur Collection, Treatise on Sincerity (21st Flash)',
      ),
      linkedFarzId: 27,
      linkedBookId: 'book_rn_ihlas_uhuvvet',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_16',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim\'de geçen meşhur "Cibrîl Hadisi"nde İslâm, Îmân ve İhsân mertebelerini doğru şekilde eşleştiriniz.',
      en: 'Match the three spiritual stations—Islam, Iman, and Ihsan—as defined in the Hadith of Jibril in Sahih Muslim.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'İslâm', en: 'Islam'),
          right: LocalizedText(
            tr: 'Şehâdet, namaz, zekât, oruç ve hac',
            en: 'Testimony, prayer, zakah, fasting, hajj',
          ),
        ),
        (
          left: LocalizedText(tr: 'Îmân', en: 'Iman'),
          right: LocalizedText(
            tr: 'Âmentü\'deki altı rükne kalben inanmak',
            en: 'Conviction in the six articles of faith',
          ),
        ),
        (
          left: LocalizedText(tr: 'İhsân', en: 'Ihsan'),
          right: LocalizedText(
            tr: 'Allah\'ı görüyormuş gibi kulluk etmek',
            en: 'Worshipping Allah as though you see Him',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İhsân mertebesi "Sen O\'nu görmesen de O seni görmektedir" şuuruyla ibadet etmektir.',
      en: 'Ihsan is worshipping with awareness that even if you do not see Him, He surely sees you.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Cibrîl hadisi dinin bütününü üç katmanlı bir kemal yolculuğu olarak özetler: zahirî teslimiyet (İslâm), kalbî yakîn (Îmân) ve daimî huzur şuuru (İhsân).',
        en: 'The Hadith of Jibril maps the totality of religion in three integrated dimensions: outward submission, inward conviction, and vigilant excellence.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Îmân 1 (Hadis No: 8)',
        en: 'Sahih Muslim, Kitab al-Iman 1 (Hadith 8)',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_17',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Tabiat Risalesi\'ne (23. Lem\'a) göre kâinattaki varlıkların teşekkülünü "tabiat"a veya "sebeplere" ya da "tesadüfe" vermek aklen üç muhali (imkânsızlığı) doğurur ve bütün eserler ancak Vâhid-i Ehad olan Allah\'ın kudretiyle izah edilebilir.',
      en: 'According to the Treatise on Nature (23rd Flash), attributing creation to nature, causes, or chance entails rational impossibilities, proving all beings stem from the One Creator.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: '23. Lem\'a\'da tabiatın bir matbaa değil ancak ilâhî bir kânun-u fıtrî mecmuası olduğu ispatlanır.',
      en: 'The 23rd Flash shows nature is a passive law-book, never an independent creator.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İlim, irade ve kudretten yoksun maddî sebepler bir araya gelerek şuurlu bir sanatı icat edemez; sebepler yalnızca hikmet perdesidir, hakikî fâil Allah Teâlâ\'dır.',
        en: 'Unconscious material causes lack knowledge, will, and power; they serve as veils of wisdom while Allah alone is the True Maker.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Tabiat Risalesi (23. Lem\'a)',
        en: 'Risale-i Nur Collection, Treatise on Nature (23rd Flash)',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_rn_tabiat_risalesi',
      linkedZikirKey: 'El-Hakîm',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_18',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Fahreddîn er-Râzî\'nin Mefâtîhu\'l-Gayb tefsirinde "Allah\'a ortak koşma dışında bütün günahları dilediği kimse için bağışlar" (Nisâ 4/48) âyeti nasıl yorumlanır?',
      en: 'In Fakhr ad-Din ar-Razi\'s Mafatih al-Ghayb, how is Surah An-Nisa 4:48 ("Allah does not forgive associating partners with Him, but forgives what is less than that for whom He wills") interpreted?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şirkten tövbe etmeden ölen bağışlanmaz; büyük günah ehli mümin ise Allah\'ın meşîet ve rahmeti altındadır, ebedî cehennemlik değildir',
          en: 'Dying unrepentant upon shirk is unforgivable, whereas sinful believers remain under Allah\'s mercy and will not abide eternally in Hell',
        ),
        LocalizedText(
          tr: 'Tövbe eden müşriklerin de asla affedilmeyeceği anlamına gelir',
          en: 'It means even repentant polytheists can never be forgiven',
        ),
        LocalizedText(
          tr: 'Yalnızca malî borçları ifade eder',
          en: 'It applies only to financial debts',
        ),
        LocalizedText(
          tr: 'İmanın amele hiçbir ihtiyacı olmadığını söyler',
          en: 'It declares deeds completely meaningless',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Ehl-i Sünnet kelâmında Zümer 53 tövbe eden herkesi kapsar; Nisâ 48 ise tövbesiz ölüm hâli içindir.',
      en: 'Az-Zumar 39:53 covers all who repent before death, whereas An-Nisa 4:48 concerns dying without repentance.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Râzî, bu âyetin Ehl-i Sünnet\'in "kebâir işleyen mümin kâfir olmaz ve Allah dilerse onu affeder" akidesinin en açık Kur\'ânî temeli olduğunu vurgular.',
        en: 'Ar-Razi highlights this verse as a core Qur\'anic proof that grave sins do not nullify a believer\'s faith or place them beyond divine mercy.',
      ),
      sourceRef: LocalizedText(
        tr: 'Fahreddîn er-Râzî, Mefâtîhu\'l-Gayb, Nisâ 4/48',
        en: 'Fakhr ad-Din ar-Razi, Mafatih al-Ghayb, An-Nisa 4:48',
      ),
      linkedFarzId: 1,
      linkedBookId: 'book_tafseer_razi',
      linkedZikirKey: 'El-Gaffâr',
    ),
  ),
  IrfanQuestion(
    id: 'ilm_i_19',
    topic: IrfanTopic.ilmihal32Farz,
    tier: IrfanTier.irfan,
    madhhabScope: IrfanMadhhabScope.common,
    stem: LocalizedText(
      tr: 'Sünen-i İbn Mâce ve Tirmizî\'deki cenaze ve kabir ziyareti bablarına göre Peygamber Efendimiz (s.a.v.) "Size kabirleri ziyaret etmeyi yasaklamıştım; artık ziyaret ediniz, çünkü kabir ziyareti ......" buyurmuştur. Cümle nasıl tamamlanır?',
      en: 'In Sunan Ibn Majah and at-Tirmidhi, the Prophet (ﷺ) said: "I had forbidden you from visiting graves; now visit them, for indeed they ......" How does the hadith end?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kalbi yumuşatır, gözü yaşartır ve âhireti hatırlatır',
          en: 'Soften the heart, bring tears to the eyes, and remind of the Hereafter',
        ),
        LocalizedText(
          tr: 'Yalnızca soy kütüğü yazmak içindir',
          en: 'Are only for recording family trees',
        ),
        LocalizedText(
          tr: 'Sadece bayram sabahları yapılabilir',
          en: 'Can only be done on Eid mornings',
        ),
        LocalizedText(
          tr: 'Dünya hırsını artırır',
          en: 'Increase worldly greed',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Tefekkür-i mevt (ölümü tefekkür) insanı dünya gafletinden uyandırıp ibadete sevk eder.',
      en: 'Remembering mortality awakens the heart from heedlessness.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kabir ziyareti sünnettir; müminlere dua etme ve kendi fâniliğini tefekkür ederek ömrünü hayırla değerlendirme şuuru kazandırır.',
        en: 'Visiting graves is an established Sunnah encouraging supplication for the deceased and mindful reflection on our own return to Allah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i İbn Mâce, Cenâiz 47; Sünen-i Tirmizî, Cenâiz 60',
        en: 'Sunan Ibn Majah, Jana\'iz 47; Sunan at-Tirmidhi, Jana\'iz 60',
      ),
      linkedFarzId: 5,
      linkedBookId: 'book_hadith_ibn_mace',
    ),
  ),
];
