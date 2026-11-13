import '../domain/irfan_models.dart';

/// 24 Authentic Bilingual (TR/EN) Questions sourced from Külliyat books for Kur'ân & Sûreler.
const List<IrfanQuestion> kIrfanQuestionsKulliyatQuran = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 8 QUESTIONS (qur_b_12..qur_b_19)
  // =========================================================================
  IrfanQuestion(
    id: 'qur_b_12',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    specialDayTags: ['ramazan'],
    stem: LocalizedText(
      tr: 'Kur\'ân Yolu Tefsiri\'nin girişinde belirtildiği üzere Mekkî ve Medenî sûrelerin tespitinde âlimlerin benimsediği en yaygın (tercih edilen) ölçü hangisidir?',
      en: 'As explained in the introduction of Qur\'an Yolu Tafsir, what is the primary criterion used by classical scholars to classify Surahs as Makkan or Madinan?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hicret\'ten önce inenler Mekkî, Hicret\'ten sonra inenler (mekândan bağımsız olarak) Medenîdir',
          en: 'Verses revealed before the Hijrah are Makkan; those revealed after the Hijrah are Madinan (regardless of location)',
        ),
        LocalizedText(
          tr: 'Sadece sûre uzunluğuna göre ayrılır',
          en: 'Classified strictly by Surah length',
        ),
        LocalizedText(
          tr: 'Alfabetik sıraya göre ayrılır',
          en: 'Classified alphabetically',
        ),
        LocalizedText(
          tr: 'Yalnızca kıssa içerip içermemesine göre ayrılır',
          en: 'Classified solely by whether they contain parables',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Örneğin Veda Haccı sırasında Arafat\'ta inen âyetler Hicret\'ten sonra olduğu için Medenî sayılır.',
      en: 'For example, verses revealed during the Farewell Pilgrimage are classified as Madinan because they occurred after Hijrah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mekkî sûreler ağırlıklı olarak tevhid, nübüvvet, âhiret ve ahlâkı inşa ederken; Medenî sûreler ibadet, aile, toplum ve hukuk düzenini tafsil eder.',
        en: 'Makkan revelations anchor faith in Tawhid, prophethood, and the Hereafter, while Madinan revelations detail worship, family, and communal ethics.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kur\'ân Yolu Türkçe Meâl ve Tefsir, Giriş Bölümü',
        en: 'Qur\'an Yolu Turkish Translation & Tafsir, Introduction',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_13',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Elmalılı Hamdi Yazır Meâli\'nde de yer alan Bakara Sûresi 255. âyeti ("Allâhü lâ ilâhe illâ hüve\'l-Hayyü\'l-Kayyûm...") hangi mübarek isimle anılır?',
      en: 'What celebrated name is given to Surah Al-Baqarah 2:255 ("Allahu la ilaha illa Huwal-Hayyul-Qayyum..."), translated in Elmalılı Hamdi Yazır\'s Meâl?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Âyetü\'l-Kürsî', en: 'Ayat al-Kursi (Verse of the Throne)'),
        LocalizedText(tr: 'Âmenerresûlü', en: 'Amana ar-Rasul'),
        LocalizedText(tr: 'Âyetü\'n-Nûr', en: 'Verse of Light'),
        LocalizedText(tr: 'Mübahale Âyeti', en: 'Verse of Mubahalah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Sahîh-i Müslim\'de "Allah\'ın Kitabındaki en büyük âyet" olarak övülmüştür.',
      en: 'Praised in Sahih Muslim as "the greatest verse in the Book of Allah."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Âyetü\'l-Kürsî, Allah Teâlâ\'nın ezelî diriliğini (Hayy), her şeyi ayakta tutuşunu (Kayyûm), mutlak ilmini ve yüce kudretini on cümlede toplar.',
        en: 'Ayat al-Kursi summarizes Allah\'s eternal life, self-subsistence, all-encompassing knowledge, and absolute sovereignty.',
      ),
      sourceRef: LocalizedText(
        tr: 'Elmalılı Hamdi Yazır Meâli, Bakara 2/255; Sahîh-i Müslim, Müsâfirîn 258',
        en: 'Elmalılı Meâl, Al-Baqarah 2:255; Sahih Muslim, Musafirin 258',
      ),
      linkedBookId: 'book_meal_elmalili_sade',
      linkedZikirKey: 'El-Hayy',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_14',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Diyanet Vakfı Kur\'ân-ı Kerîm Meâli\'ne ve mushaf tertibine göre Kur\'ân-ı Kerîm\'de okunduğunda veya dinlendiğinde tilâvet secdesi yapılmasını gerektiren 14 secde âyeti vardır.',
      en: 'According to standard Mushaf notation and the Diyanet Vakfı Meâl, there are 14 verses of prostration (Sajdah Tilawah) in the Qur\'an.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Hanefî mezhebine göre 14 tilâvet secdesi âyeti vardır; Şâfiî\'de ise Sâd Sûresi\'ndeki secde şükür secdesi sayıldığı için Hac Sûresi\'nin ikinci secdesiyle birlikte 14\'tür.',
      en: 'Fourteen prostration verses are marked across the Mushaf (with minor school distinction on Surah Sad vs the second verse in Surah Al-Hajj).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tilâvet secdesi âyetleri okunduğunda veya duyulduğunda secde etmek, kulun Kur\'ân\'ın emrine anında teslimiyetinin sembolüdür.',
        en: 'Performing prostration upon reciting or hearing a verse of Sajdah expresses immediate humility before Allah\'s Word.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet Vakfı Meâli, Secde Âyetleri Fihristi; Kur\'ân Yolu Tefsiri',
        en: 'Diyanet Vakfı Meâl, Index of Sajdah Verses; Qur\'an Yolu',
      ),
      linkedBookId: 'book_meal_diyanet',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_15',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Kur\'ân Yolu Tefsiri\'nde Hucurât Sûresi 11-12. âyetler hangi büyük içtimaî ahlâk hastalıklarını kesin bir dille yasaklar?',
      en: 'In Qur\'an Yolu Tafsir, which grave social vices are strictly prohibited in Surah Al-Hujurat 49:11-12?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Alay etmek, kötü lakap takmak, sû-i zan, tecessüs (kusur araştırmak) ve gıybet',
          en: 'Mockery, offensive nicknames, suspicion, spying on faults, and backbiting',
        ),
        LocalizedText(
          tr: 'Yalnızca deniz ticareti yapmak',
          en: 'Maritime trade alone',
        ),
        LocalizedText(
          tr: 'Farklı dilleri öğrenmek',
          en: 'Learning foreign languages',
        ),
        LocalizedText(
          tr: 'Yolculukta dua etmek',
          en: 'Supplicating while traveling',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Âyetin sonunda gıybet etmek "ölmüş kardeşinin etini yemek" benzetmesiyle çirkin görülür.',
      en: 'Verse 12 likens backbiting to eating the flesh of one\'s deceased brother.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hucurât Sûresi, mümin toplumun onurunu, mahremiyetini ve kardeşlik hukukunu koruyan İslâm ahlâk anayasası niteliğindedir.',
        en: 'Surah Al-Hujurat serves as an ethical charter protecting dignity, privacy, and mutual trust among believers.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kur\'ân Yolu Tefsiri, Hucurât Sûresi, 49/11-12',
        en: 'Qur\'an Yolu Tafsir, Surah Al-Hujurat, 49:11-12',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_16',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de sûrelerin faziletlerini ve öne çıkan konularını doğru şekilde eşleştiriniz.',
      en: 'Match these well-known Surahs of the Qur\'an with their prominent themes or virtues.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Yâsîn Sûresi', en: 'Surah Ya-Sin'),
          right: LocalizedText(
            tr: 'Tevhid, nübüvvet ve haşir; "Kur\'ân\'ın kalbi"',
            en: 'Tawhid & resurrection; "Heart of the Qur\'an"',
          ),
        ),
        (
          left: LocalizedText(tr: 'Rahmân Sûresi', en: 'Surah Ar-Rahman'),
          right: LocalizedText(
            tr: '"Rabbinizin hangi nimetlerini yalanlıyorsunuz?"',
            en: 'Refrain recalling countless divine blessings',
          ),
        ),
        (
          left: LocalizedText(tr: 'Mülk Sûresi', en: 'Surah Al-Mulk'),
          right: LocalizedText(
            tr: 'Her gece okunması tavsiye edilen 30 âyet',
            en: '30 verses recommended nightly for protection',
          ),
        ),
        (
          left: LocalizedText(tr: 'Asr Sûresi', en: 'Surah Al-\'Asr'),
          right: LocalizedText(
            tr: 'İman, salih amel, hak ve sabır tavsiyesi',
            en: 'Faith, righteous deeds, truth, and patience',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'İmam Şâfiî "İnsanlar sadece Asr Sûresi\'ni tefekkür etselerdi onlara yeterdi" buyurmuştur.',
      en: 'Imam ash-Shafi\'i remarked that reflecting deeply on Surah Al-\'Asr alone would suffice humanity for guidance.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Her sûre iman, şükür, ibadet ve sabır ufkumuzu başka bir pencereden aydınlatır.',
        en: 'Each Surah illuminates faith, gratitude, accountability, and perseverance from a distinct angle.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Fedâilü\'l-Kur\'ân 7-9; Kur\'ân Yolu Tefsiri',
        en: 'Sunan at-Tirmidhi, Fada\'il al-Qur\'an 7-9; Qur\'an Yolu',
      ),
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_17',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "Fedâilü\'l-Kur\'ân" bölümünde geçen "Sizin en hayırlınız ......" hadis-i şerifi nasıl tamamlanır?',
      en: 'In the Virtues of the Qur\'an chapter of Sahih al-Bukhari, how does the Prophet\'s (ﷺ) statement "The best of you are those who ......" conclude?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kur\'ân\'ı öğrenen ve öğreteninizdir',
          en: 'Learn the Qur\'an and teach it',
        ),
        LocalizedText(
          tr: 'En yüksek binayı yapanınızdır',
          en: 'Build the tallest structures',
        ),
        LocalizedText(
          tr: 'En çok altın biriktireninizdir',
          en: 'Accumulate the most gold',
        ),
        LocalizedText(
          tr: 'Hiç kimseyle görüşmeyeninizdir',
          en: 'Live in total isolation',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hz. Osman (r.a.) bu hadisi rivayet etmiş ve ömrünü Kur\'ân öğretmeye adamıştır.',
      en: 'Narrated by Uthman ibn Affan (r.a.), inspiring lifelong Qur\'anic literacy.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân\'ı hem sahih şekilde okumayı ve anlamayı öğrenmek hem de başkalarına ulaştırmak ümmet içindeki en şerefli meşguliyettir.',
        en: 'Learning the Qur\'an with care and passing it on to others is praised as the noblest pursuit in the community.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Fedâilü\'l-Kur\'ân 21 (Hadis No: 5027)',
        en: 'Sahih al-Bukhari, Fada\'il al-Qur\'an 21 (Hadith 5027)',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_18',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Hasan Basri Çantay Meâli ve Kur\'ân Yolu Tefsiri\'nde Duhâ Sûresi\'nde Peygamber Efendimiz\'e (s.a.v.) verilen Rabbanî teselli ve ardından gelen üç ahlâkî emir arasında hangisi vardır?',
      en: 'In Hasan Basri Çantay\'s Meâl and Surah Ad-Duha (93:9-11), following Allah\'s consolation to the Prophet (ﷺ), which three directives conclude the Surah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Yetimi ezme, el açıp isteyeni azarlama ve Rabbinin nimetini minnetle anlat',
          en: 'Do not oppress the orphan, do not repulse the petitioner, and proclaim the favor of your Lord',
        ),
        LocalizedText(
          tr: 'Sadece gece seyahat et',
          en: 'Travel only at night',
        ),
        LocalizedText(
          tr: 'Kendi evinden hiç çıkma',
          en: 'Never leave your home',
        ),
        LocalizedText(
          tr: 'Dünyalık kazancı gizle',
          en: 'Conceal all lawful blessings',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Rabbin seni terk etmedi ve sana darılmadı" müjdesiyle başlayan sûredir.',
      en: 'Opens with "Your Lord has not forsaken you, nor has He detested you."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Duhâ Sûresi darlık ve hüzün anlarında mümin kalbe "Sonrası senin için öncekilerden daha hayırlı olacaktır" ümidini ve merhamet sorumluluğunu verir.',
        en: 'Surah Ad-Duha heals sorrow with the assurance that the future holds greater good, linking gratitude with kindness to orphans and the needy.',
      ),
      sourceRef: LocalizedText(
        tr: 'Hasan Basri Çantay Meâli, Duhâ 93/1-11',
        en: 'Hasan Basri Çantay Meâl, Surah Ad-Duha 93:1-11',
      ),
      linkedBookId: 'book_meal_cantay',
      linkedZikirKey: 'Elhamdülillah',
    ),
  ),
  IrfanQuestion(
    id: 'qur_b_19',
    topic: IrfanTopic.quran,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Kur\'ân-ı Kerîm\'de bizzat sûre ismi olarak geçen "Lokmân Sûresi"nde Hz. Lokmân\'ın (a.s.) oğluna verdiği ilk ve en büyük nasihat Allah\'a şirk koşmamaktır; çünkü şirk en büyük zulümdür.',
      en: 'In Surah Luqman (31:13), the very first counsel Luqman gives his son is not to associate partners with Allah, calling shirk a tremendous wrong.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Devamında anne-babaya iyilik, namazı kılma, iyiliği emretme ve yürüyüşte/seste vakarlı olma öğütlenir.',
      en: 'Followed by honoring parents, establishing prayer, enjoining good, and modesty in speech and gait.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Lokmân\'ın (a.s.) nasihatleri akîdeden ibadete, aile edebi ve toplumsal nezakete uzanan dengeli bir terbiye programıdır.',
        en: 'Luqman\'s counsels weave creed, prayer, filial respect, and humble manners into a timeless framework for moral education.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kur\'ân Yolu Tefsiri, Lokmân Sûresi, 31/13-19',
        en: 'Qur\'an Yolu Tafsir, Surah Luqman, 31:13-19',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 8 QUESTIONS (qur_o_12..qur_o_19)
  // =========================================================================
  IrfanQuestion(
    id: 'qur_o_12',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Klasik Tefsir Külliyatındaki meşhur tefsir eserlerini müellifleriyle doğru şekilde eşleştiriniz.',
      en: 'Match these landmark Qur\'anic commentaries (tafsirs) from the Library with their renowned authors.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Te\'vîlâtü\'l-Kur\'ân', en: 'Ta\'wilat al-Qur\'an'),
          right: LocalizedText(tr: 'İmam Ebû Mansûr el-Mâtürîdî', en: 'Imam al-Maturidi'),
        ),
        (
          left: LocalizedText(tr: 'Envârü\'t-Tenzîl', en: 'Anwar at-Tanzil'),
          right: LocalizedText(tr: 'Kâdî Beyzâvî', en: 'Qadi al-Baydawi'),
        ),
        (
          left: LocalizedText(tr: 'Mefâtîhu\'l-Gayb', en: 'Mafatih al-Ghayb'),
          right: LocalizedText(tr: 'Fahreddîn er-Râzî', en: 'Fakhr ad-Din ar-Razi'),
        ),
        (
          left: LocalizedText(tr: 'el-Keşşâf', en: 'Al-Kashshaf'),
          right: LocalizedText(tr: 'Cârullah ez-Zemahşerî', en: 'Az-Zamakhshari'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Mâtürîdî kelâm, Zemahşerî belâgat, Râzî hikmet ve Beyzâvî medrese muhtasar tefsiriyle meşhurdur.',
      en: 'Maturidi focuses on creed, Zamakhshari on rhetoric, Razi on philosophy/theology, and Baydawi on concise synthesis.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İslâm tefsir geleneği dil, belâgat, fıkıh ve kelâm ilimlerini Kur\'ân\'ı anlama yolunda birleştirerek zengin bir ilim mirası bırakmıştır.',
        en: 'The classical tafsir tradition unites Arabic linguistics, rhetoric, jurisprudence, and theology to illuminate Qur\'anic depth.',
      ),
      sourceRef: LocalizedText(
        tr: 'Zikirce Külliyat Tefsirleri Kataloğu',
        en: 'Zikirce Library Classical Tafsir Catalog',
      ),
      linkedBookId: 'book_tafseer_beyzavi',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_13',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim\'de Peygamber Efendimiz\'in (s.a.v.) "Zehrâveyn" (iki parlak nur) diye adlandırıp "Kıyamet günü iki bulut veya iki kuş sürüsü gibi gelip okuyucularını savunacaklar" buyurduğu iki sûre hangileridir?',
      en: 'In Sahih Muslim, which two Surahs did the Prophet (ﷺ) name "az-Zahrawayn" (the two radiant ones), saying they will intercede like two clouds for their reciters on Judgment Day?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bakara ve Âl-i İmrân Sûreleri',
          en: 'Surah Al-Baqarah and Surah Al \'Imran',
        ),
        LocalizedText(
          tr: 'Kevser ve Kâfirûn Sûreleri',
          en: 'Surah Al-Kawthar and Surah Al-Kafirun',
        ),
        LocalizedText(
          tr: 'Fil ve Kureyş Sûreleri',
          en: 'Surah Al-Fil and Surah Quraysh',
        ),
        LocalizedText(
          tr: 'Tebbet ve Nasr Sûreleri',
          en: 'Surah Al-Masad and Surah An-Nasr',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân\'ın en uzun sûresi ile hemen peşinden gelen 3. sûredir.',
      en: 'They are the 2nd and 3rd Surahs of the Qur\'an.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ebû Ümâme (r.a.) rivayetindeki bu hadis, Kur\'ân okuyup ahkâmıyla amel edenlerin kıyamet gününde vahyin şefaatine nail olacağını müjdeler.',
        en: 'Narrated by Abu Umamah (r.a.), this hadith promises that consistent recitation and living by the Qur\'an brings intercession on the Last Day.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Müsâfirîn 252 (Hadis No: 804)',
        en: 'Sahih Muslim, Musafirin 252 (Hadith 804)',
      ),
      linkedBookId: 'book_hadith_muslim',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_14',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    specialDayTags: ['cuma'],
    stem: LocalizedText(
      tr: 'Sünen-i Nesâî ve Buhârî/Müslim şerhlerinde aktarılan rivayetlere göre, Cuma günü okunduğunda iki Cuma arasını nurla aydınlattığı bildirilen sûre hangisidir?',
      en: 'According to Prophetic narrations cited in hadith compilations, reciting which Surah on Friday illuminates the believer with spiritual light until the next Friday?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kehf Sûresi', en: 'Surah Al-Kahf'),
        LocalizedText(tr: 'Tâhâ Sûresi', en: 'Surah Ta-Ha'),
        LocalizedText(tr: 'İnfitâr Sûresi', en: 'Surah Al-Infitar'),
        LocalizedText(tr: 'Hümeze Sûresi', en: 'Surah Al-Humazah'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Ashâb-ı Kehf, Hz. Mûsâ ile Hızır ve Zülkarneyn kıssalarını içeren 18. sûredir.',
      en: 'Surah 18, containing the stories of the Companions of the Cave, Musa & Khidr, and Dhul-Qarnayn.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kehf Sûresi, iman fitnesine karşı Ashâb-ı Kehf\'in sebatını, mal fitnesine karşı iki bahçe sahibini ve ilim-kudret fitnelerine karşı tevazuyu öğreterek kalbi korur.',
        en: 'Surah Al-Kahf guards the believer against trials of faith, wealth, knowledge, and power through four profound parables.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Nesâî, es-Sünenü\'l-Kübrâ; Kur\'ân Yolu Tefsiri, Kehf 18',
        en: 'An-Nasa\'i, As-Sunan al-Kubra; Qur\'an Yolu Tafsir, Al-Kahf 18',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
      linkedZikirKey: 'En-Nûr',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_15',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân Yolu Tefsiri ve Elmalılı Meâli\'nde Furkân Sûresi\'nin 63-74. âyetlerinde övülen "İbâdü\'r-Rahmân" (Rahmân\'ın has kulları) vasıflarından ilki "yeryüzünde vakar ve tevazu ile yürümeleri, cahiller kendilerine laf attığında \'Selâm!\' deyip geçmeleridir".',
      en: 'In Furqan 25:63-74 (Kur\'an Yolu & Elmalılı Meâl), the first trait of "Ibad ar-Rahman" (Servants of the Most Merciful) is walking humbly on earth and responding with peace when addressed by the ignorant.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Ardından gece kıyamı, harcamada itidal, şirk-katil-zinadan uzak durma ve eş-evlat için göz aydınlığı duası sayılır.',
      en: 'Followed by night prayer, balanced spending, avoiding major sins, and praying for righteous families.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Rahmân\'ın kulları ne kibirle böbürlenir ne de provokasyona öfkeyle karşılık verir; vakarlı nezaketle hak yolunda yürürler.',
        en: 'True servants of the Most Merciful combine inward humility with dignified composure, refusing to stoop to foolish provocation.',
      ),
      sourceRef: LocalizedText(
        tr: 'Elmalılı Hamdi Yazır Meâli, Furkân 25/63-74',
        en: 'Elmalılı Meâl, Surah Al-Furqan 25:63-74',
      ),
      linkedBookId: 'book_meal_elmalili_sade',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_16',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sözler\'deki Yirmi Beşinci Söz\'de (Mu\'cizât-ı Kur\'âniye) Kur\'ân-ı Kerîm\'in bütün sûre ve âyetlerinde işlenen dört temel maksadı hangisidir?',
      en: 'In the Twenty-Fifth Word (Miraculousness of the Qur\'an) of Sözler, what are the four primary universal aims of the Qur\'an?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Tevhid, Nübüvvet, Haşir (Âhiret) ve Adâlet ile İbâdet',
          en: 'Tawhid (Oneness), Prophethood, Resurrection, and Justice with Worship',
        ),
        LocalizedText(
          tr: 'Sadece savaş taktikleri ve astroloji',
          en: 'Only military tactics and astrology',
        ),
        LocalizedText(
          tr: 'Yalnızca şiir vezinleri',
          en: 'Poetic meters alone',
        ),
        LocalizedText(
          tr: 'Coğrafya ve maden isimleri',
          en: 'Geography and mineral catalogs',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Fâtiha Sûresi dahi bu dört maksadın çekirdeğini içinde barındırır.',
      en: 'Even Surah Al-Fatihah encapsulates all four pillars in seven verses.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '25. Söz\'e göre Kur\'ân\'ın her meselesi insanı Yaratıcı\'sını tanımaya (Tevhid), rehberine uymaya (Nübüvvet), ebedî hesap gününe hazırlanmaya (Haşir) ve adaletle kulluk etmeye (Adâlet-İbâdet) çağırır.',
        en: 'The 25th Word shows that every passage of the Qur\'an guides humanity toward knowing Allah, following His Messenger, preparing for eternity, and upholding justice and worship.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Sözler, 25. Söz, 1. Şu\'le',
        en: 'Risale-i Nur Collection, The Words (Sözler), 25th Word',
      ),
      linkedBookId: 'book_rn_sozler',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_17',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Kur\'ân Yolu Tefsiri\'nde "sebeb-i nüzul" (iniş sebebi) ilmini bilmenin tefsirdeki en önemli faydası olarak ne belirtilir?',
      en: 'In Qur\'an Yolu Tafsir, what is cited as the foremost benefit of knowing the occasions of revelation (Asbab an-Nuzul)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Âyetin hangi tarihî bağlamda ve hangi maksatla indiğini doğru kavrayıp yanlış yorumları önlemek',
          en: 'Grasping the historical context and precise intent of a verse to prevent misinterpretation',
        ),
        LocalizedText(
          tr: 'Âyetin hükmünü sadece o bir kişiye hapsetmek',
          en: 'Restricting the verse\'s guidance to a single person forever',
        ),
        LocalizedText(
          tr: 'Arapça gramer kurallarını değiştirmek',
          en: 'Altering Arabic grammar rules',
        ),
        LocalizedText(
          tr: 'Sûre sıralamasını yeniden yazmak',
          en: 'Reordering the Surahs',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Usûl kaidesi şudur: "Sebebin hususî olması hükmün umumî olmasına mâni değildir."',
      en: 'Classical maxim: "Specificity of the occasion does not restrict the universality of the ruling."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İniş sebebini bilmek, âyetin ruhunu ve hedefini berraklaştırırken mesajın bütün çağlara yönelik evrensel hükmünü muhafaza eder.',
        en: 'Knowing the occasion of revelation clarifies a verse\'s purpose while preserving its timeless universal application.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kur\'ân Yolu Tefsiri, Giriş: Tefsir Usûlü',
        en: 'Qur\'an Yolu Tafsir, Introduction on Exegetical Methodology',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_18',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Müslim\'de bildirildiğine göre, Peygamber Efendimiz (s.a.v.) Kur\'ân\'ın nasıl okunmasını teşvik etmiştir?',
      en: 'As taught in Sunan Abi Dawud and Sahih Muslim, how did the Prophet (ﷺ) encourage believers to recite the Qur\'an?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Güzel sesle, tecvid kurallarına uyarak, ağır ağır ve tefekkür ederek (tertîl ile)',
          en: 'With a pleasant voice, proper Tajweed, measured pace, and reflection (tartil)',
        ),
        LocalizedText(
          tr: 'Anlamını düşünmeden mümkün olduğunca hızlı bitirerek',
          en: 'As fast as possible without pause or thought',
        ),
        LocalizedText(
          tr: 'Sadece yılda bir kez açarak',
          en: 'Only opening it once a year',
        ),
        LocalizedText(
          tr: 'Yalnızca sessizce dudak kıpırdatmadan',
          en: 'Never moving the lips at all',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Müzzemmil 4. âyette "Ve rettili\'l-Kur\'âne tertîlâ" (Kur\'ân\'ı tane tane, hakkını vererek oku) buyrulur.',
      en: 'Surah Al-Muzzammil 73:4 commands: "And recite the Qur\'an with measured recitation (tartil)."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Kur\'ân\'ı seslerinizle süsleyiniz" hadisi, mahreç ve tecvidi bozmadan huşû içinde güzel okumanın kalpleri yumuşattığını bildirir.',
        en: '"Beautify the Qur\'an with your voices" invites measured, melodious, and reverent recitation faithful to Tajweed.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Ebû Dâvûd, Vitir 20; Müzzemmil Sûresi, 73/4',
        en: 'Sunan Abi Dawud, Witr 20; Surah Al-Muzzammil, 73:4',
      ),
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'qur_o_19',
    topic: IrfanTopic.quran,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Tirmizî\'de "İhlâs, Felak ve Nâs" sûrelerinin her farz namazdan sonra ve yatmadan önce okunması tavsiye edilir; Felak ve Nâs sûrelerine "koruyucu iki sûre" anlamında ne ad verilir?',
      en: 'In Sahih Muslim and at-Tirmidhi, Surahs Al-Falaq and An-Nas are recommended after prayers and before sleep; what collective title means "the two chapters of refuge"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Muavvizeteyn', en: 'Al-Mu\'awwidhatayn'),
        LocalizedText(tr: 'Zehrâveyn', en: 'Az-Zahrawayn'),
        LocalizedText(tr: 'Hamîmler', en: 'Al-Hawamim'),
        LocalizedText(tr: 'Mufassalât', en: 'Al-Mufassalat'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '"Eûzü" (sığınırım) kelimesiyle aynı kökten gelir.',
      en: 'Shares the Arabic root with "A\'udhu" (I seek refuge).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Muavvizeteyn, müminin hem görünür şerlerden (Felak) hem de kalbe fısıldanan gizli vesveselerden (Nâs) yalnız Allah\'a sığınma duasıdır.',
        en: 'Al-Mu\'awwidhatayn teach the believer to seek refuge in Allah alone from both outward harms and inward whispers.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Daavât 21; Sahîh-i Buhârî, Fedâilü\'l-Kur\'ân 14',
        en: 'Sunan at-Tirmidhi, Da\'awat 21; Sahih al-Bukhari, 5017',
      ),
      linkedBookId: 'book_hadith_tirmizi',
      linkedZikirKey: 'İhlas-ı Şerif',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 8 QUESTIONS (qur_i_12..qur_i_19)
  // =========================================================================
  IrfanQuestion(
    id: 'qur_i_12',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Bediüzzaman\'ın İşârâtü\'l-İ\'câz tefsirinde Kur\'ân\'ın eşsiz i\'câz (aciz bırakıcı üstünlük) yönlerinden özellikle hangisi cümle-kelime-harf düzeyinde incelenir?',
      en: 'In Isharat al-I\'jaz (Signs of Miraculousness), which dimension of the Qur\'an\'s inimitability is analyzed in detail down to clauses, words, and syntax?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Nazım ve belâgatındaki ince münasebet ve îcâzlı (özlü) ifade düzeni',
          en: 'The intricate harmony of word-order (nazm), eloquence, and concise precision',
        ),
        LocalizedText(
          tr: 'Yalnızca hat sanatındaki mürekkep türleri',
          en: 'Only calligraphy ink formulas',
        ),
        LocalizedText(
          tr: 'Sadece peygamberlerin soy ağaçları',
          en: 'Genealogical tables alone',
        ),
        LocalizedText(
          tr: 'Modern matbaa dizgisi',
          en: 'Modern printing layout',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Eserin tam adı "İşârâtü\'l-İ\'câz fî Mazânni\'l-Îcâz" olup Fâtiha ve Bakara\'nın başını nazım belâgatı açısından şerh eder.',
      en: 'It comments on Al-Fatihah and early Al-Baqarah from the standpoint of syntactic harmony and conciseness.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İşârâtü\'l-İ\'câz, Kur\'ân\'daki her bir edatın, sıranın ve kelimenin tesadüfî olmayıp derin bir belâgat ve mana ağı kurduğunu ispat eder.',
        en: 'Isharat al-I\'jaz demonstrates that every particle, sequence, and word choice in the Qur\'an weaves an intentional, inimitable web of meaning.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, İşârâtü\'l-İ\'câz, Mukaddime',
        en: 'Risale-i Nur Collection, Isharat al-I\'jaz, Introduction',
      ),
      linkedBookId: 'book_rn_isaratul_icaz',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_13',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Cârullah ez-Zemahşerî\'nin el-Keşşâf tefsiri, özellikle hangi ilim dalındaki derin tahlilleriyle asırlarca bütün müfessirlerin başvurduğu temel kaynak olmuştur?',
      en: 'Az-Zamakhshari\'s Al-Kashshaf became an indispensable reference for subsequent commentators primarily due to its mastery of which discipline?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Arap dili, belâgat (meânî ve beyân) ve üslup incelikleri',
          en: 'Arabic linguistics, rhetoric (balaghah), and stylistic subtlety',
        ),
        LocalizedText(
          tr: 'Sadece tıbbî reçeteler',
          en: 'Medical prescriptions alone',
        ),
        LocalizedText(
          tr: 'Yalnızca kıraat farkları olmadan tasavvufî rüyalar',
          en: 'Sufi dreams detached from grammar',
        ),
        LocalizedText(
          tr: 'Yalnızca askerî lojistik',
          en: 'Military logistics only',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kâdî Beyzâvî dahi Envârü\'t-Tenzîl\'i yazarken el-Keşşâf\'ın belâgat mirasını Ehl-i Sünnet akidesiyle süzerek özetlemiştir.',
      en: 'Even al-Baydawi drew heavily upon Al-Kashshaf\'s rhetorical insights while filtering its theological views.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'el-Keşşâf, itikadî konularda Ehl-i Sünnet dışı Mu\'tezilî yorumlar barındırsa da belâgat ve dil tahlilleri bakımından ilim tarihinde çığır açmıştır.',
        en: 'Though scholars critique its Mu\'tazili theological stances, Al-Kashshaf remains celebrated for uncovering the Qur\'an\'s linguistic elegance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Zemahşerî, el-Keşşâf an Hakâikı\'t-Tenzîl, Mukaddime',
        en: 'Az-Zamakhshari, Al-Kashshaf, Introduction',
      ),
      linkedBookId: 'book_tafseer_kessaf',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_14',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'İmam Mâtürîdî\'nin Te\'vîlâtü\'l-Kur\'ân\'ında ve Âl-i İmrân Sûresi 7. âyette yer alan "Muhkem" ve "Müteşâbih" âyet ayrımı için hangisi doğrudur?',
      en: 'In Imam al-Maturidi\'s Ta\'wilat al-Qur\'an on Surah Al \'Imran 3:7, which accurately explains the distinction between Muhkam (decisive) and Mutashabih (allegorical/open to multiple meanings) verses?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Muhkem âyetler mânâsı açık olup kitabın temelidir; müteşâbih âyetler muhkem âyetlerin ışığında ve te\'vîl usulüyle anlaşılır',
          en: 'Muhkam verses have clear, foundational meanings, while Mutashabih verses are understood in light of Muhkam verses through sound scholarship',
        ),
        LocalizedText(
          tr: 'Müteşâbih âyetler Kur\'ân\'dan çıkarılmalıdır',
          en: 'Mutashabih verses are excluded from the Qur\'an',
        ),
        LocalizedText(
          tr: 'Hiçbir muhkem âyet anlaşılamaz',
          en: 'No Muhkam verse can be understood',
        ),
        LocalizedText(
          tr: 'Yalnızca sûre başındaki isimler muhkemdir',
          en: 'Only Surah titles are Muhkam',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Âl-i İmrân 7\'de muhkem âyetler için "Ümmü\'l-Kitâb" (Kitabın anası) tabiri kullanılır.',
      en: 'Al \'Imran 3:7 describes Muhkam verses as "Umm al-Kitab" (the foundation of the Book).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Müteşâbih âyetlerin varlığı hem aklı ve ilmi derin tefekküre teşvik eder hem de insan idrakinin sınırlarını hatırlatarak tevazua sevk eder.',
        en: 'Mutashabih verses invite deep scholarly reflection while reminding human intellect of humility before divine transcendence.',
      ),
      sourceRef: LocalizedText(
        tr: 'İmam Mâtürîdî, Te\'vîlâtü\'l-Kur\'ân, Âl-i İmrân 3/7',
        en: 'Imam al-Maturidi, Ta\'wilat al-Qur\'an, Al \'Imran 3:7',
      ),
      linkedBookId: 'book_tafseer_maturidi',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_15',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Kâdî Beyzâvî\'nin Envârü\'t-Tenzîl ve Esrârü\'t-Te\'vîl adlı tefsiri, Osmanlı medreselerinde yüzyıllarca temel ders ve başucu kitabı olarak okutulmuştur.',
      en: 'Qadi al-Baydawi\'s commentary Anwar at-Tanzil was taught for centuries as a core textbook across classical Ottoman madrasas.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Külliyattaki "Medrese Başucu Tefsiri" tavsifinin asıl kaynağı bu tarihî ilim geleneğidir.',
      en: 'Its conciseness, Sunni orthodoxy, and rhetorical depth earned it premier status in Ottoman scholarship.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Beyzâvî; lügat, kırâat, belâgat ve Ehl-i Sünnet kelâm-fıkıh birikimini veciz bir üslupla birleştirerek üzerine onlarca hâşiye yazılan bir şaheser ortaya koymuştur.',
        en: 'Al-Baydawi synthesized grammar, variant readings, rhetoric, and Sunni theology so concisely that dozens of super-commentaries were written upon his work.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kâdî Beyzâvî, Envârü\'t-Tenzîl, Giriş',
        en: 'Qadi al-Baydawi, Anwar at-Tanzil, Introduction',
      ),
      linkedBookId: 'book_tafseer_beyzavi',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_16',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Muhâkemat adlı eserde Bediüzzaman Said Nursî, Kur\'ân tefsirinde hataya düşmemek için "hakikati" üç ana sütunda inceler; bunların ilki "Unsurü\'l-Hakikat" (tefsirde İslâmiyatın akıl ve fenne uygunluğu), diğer ikisi ise "Unsurü\'l-Belâgat" ve "Unsurü\'l-Akîde"dir.',
      en: 'In Muhakemat, Bediuzzaman examines sound Qur\'anic interpretation under three elements: Truth (harmony with reason and science), Rhetoric (Belagat), and Creed (Aqidah).',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Muhâkemat\'ın alt başlığı "Reçetetü\'l-Ulemâ"dır ve tefsire sağlam bir usûl mukaddimesi sunar.',
      en: 'Subtitled "Prescription for Scholars," Muhakemat lays down hermeneutic principles.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân\'ı isabetle anlamak için sağlam bir Arapça belâgat bilgisi, sahih akîde ve kâinat kitabını okuyan hikmetli bir nazar birlikte bulunmalıdır.',
        en: 'Sound Qur\'anic exegesis unites Arabic rhetoric, authentic creed, and discerning observation of creation.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Muhâkemat, Mukaddime',
        en: 'Risale-i Nur Collection, Muhakemat, Introduction',
      ),
      linkedBookId: 'book_rn_muhakemat',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_17',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Fahreddîn er-Râzî\'nin Mefâtîhu\'l-Gayb tefsirinde Fâtiha Sûresi\'nden hareketle "Hamdin Şükürden farkı" nasıl açıklanır?',
      en: 'In Fakhr ad-Din ar-Razi\'s Mafatih al-Ghayb on Surah Al-Fatihah, how is Praise (Hamd) distinguished from Gratitude (Shukr)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hamd, Allah\'ın hem nimetleri hem de zâtî kemal sıfatları için dille yapılan övgüdür; şükür ise nimete karşılık kalp, dil ve azalarla yapılır',
          en: 'Hamd praises Allah both for His inherent perfection and blessings; Shukr responds specifically to blessings through heart, tongue, and deeds',
        ),
        LocalizedText(
          tr: 'İkisi arasında hiçbir fark yoktur',
          en: 'There is no difference whatsoever',
        ),
        LocalizedText(
          tr: 'Hamd yalnız meleklerin, şükür yalnız bitkilerin fiilidir',
          en: 'Hamd belongs only to angels and Shukr to plants',
        ),
        LocalizedText(
          tr: 'Şükür sadece sözlüdür, amel gerektirmez',
          en: 'Shukr is purely verbal with no action',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Râzî "Hamd mevzu itibarıyla daha genel, şükür ise vasıta itibarıyla (kalp-dil-beden) daha kapsamlıdır" der.',
      en: 'Ar-Razi notes Hamd is broader in object (perfection + favors), while Shukr spans heart, speech, and bodily deeds.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Elhamdülillâhi Rabbi\'l-âlemîn" demekle mümin, hem kendi üzerindeki nimetleri hem de bütün âlemlerde tecelli eden İlâhî kemali hamd ile yâd eder.',
        en: 'Saying "Alhamdulillahi Rabbil-Alamin" honors both Allah\'s perfection and His care over every realm.',
      ),
      sourceRef: LocalizedText(
        tr: 'Fahreddîn er-Râzî, Mefâtîhu\'l-Gayb, Fâtiha 1/2',
        en: 'Fakhr ad-Din ar-Razi, Mafatih al-Ghayb, Al-Fatihah 1:2',
      ),
      linkedBookId: 'book_tafseer_razi',
      linkedZikirKey: 'Elhamdülillah',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_18',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Kur\'ân ilimlerindeki temel kavramları ve müstakil özelliklerini doğru şekilde eşleştiriniz.',
      en: 'Match these key Qur\'anic sciences terms with their accurate definitions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Kıraat-ı Seb\'a', en: 'Seven Readings (Qira\'at)'),
          right: LocalizedText(
            tr: 'Mütevâtir yedi sahih okuyuş rivayeti',
            en: 'Seven mass-transmitted recitation modes',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hurûf-ı Mukattaa', en: 'Disjointed Letters'),
          right: LocalizedText(
            tr: 'Elif-Lâm-Mîm gibi 29 sûre başındaki harfler',
            en: 'Opening letters like Alif-Lam-Mim in 29 Surahs',
          ),
        ),
        (
          left: LocalizedText(tr: 'Tefsir-i Dirâyet', en: 'Tafsir bi\'r-Ra\'y / Dirayah'),
          right: LocalizedText(
            tr: 'Rivayetle birlikte dil, akıl ve usûl tahlili',
            en: 'Exegesis uniting tradition, language, and sound reason',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hafız Osman Tertibi', en: 'Hafiz Osman Mushaf'),
          right: LocalizedText(
            tr: '15 satırlık, âyet-sonlu (âyet ber-kenar) 604 sayfa düzeni',
            en: 'Classic 15-line 604-page Mushaf layout',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Uygulamamızdaki Mushaf-ı Şerîf de her sayfası âyetle biten klasik 604 sayfalık tertibe dayanır.',
      en: 'Our Mushaf preserves the classic 15-line 604-page layout ending each page on a complete verse.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hem sözlü kıraat tevatürü hem de klasik hat düzeni Kur\'ân\'ın asırlardır tek bir harfi değişmeden muhafaza edilmesini sağlamıştır.',
        en: 'Oral mass-transmission and meticulous scribal standards preserved every letter of the Qur\'an unchanged across centuries.',
      ),
      sourceRef: LocalizedText(
        tr: 'Kur\'ân Yolu Tefsiri, Giriş; Diyanet Mushafları İnceleme Kurulu',
        en: 'Qur\'an Yolu Tafsir, Introduction; Mushaf Compilation Standards',
      ),
      linkedBookId: 'book_mushaf',
    ),
  ),
  IrfanQuestion(
    id: 'qur_i_19',
    topic: IrfanTopic.quran,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "İbn Mes\'ûd\'dan, Übey b. Ka\'b\'dan, Muâz b. Cebel\'den ve Sâlim\'den Kur\'ân öğreniniz" buyrularak neyin önemi vurgulanmıştır?',
      en: 'In Sahih al-Bukhari, by advising "Learn the Qur\'an from four: Ibn Mas\'ud, Salim, Mu\'adh, and Ubayy ibn Ka\'b," what did the Prophet (ﷺ) emphasize?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kur\'ân\'ı ehil ve güvenilir hocalardan (fem-i muhsinden / isnad zinciriyle) bizzat dinleyip okuyarak almanın gereği',
          en: 'Learning the Qur\'an orally from qualified, trustworthy teachers through authentic transmission',
        ),
        LocalizedText(
          tr: 'Yalnızca dört sûrenin ezberlenmesi',
          en: 'Memorizing only four Surahs',
        ),
        LocalizedText(
          tr: 'Kur\'ân\'ın yalnızca Kureyş dışındakilere yasaklanması',
          en: 'Restricting recitation to one tribe',
        ),
        LocalizedText(
          tr: 'Yazılı mushafın tamamen kaldırılması',
          en: 'Discarding written manuscripts',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân eğitimi tarih boyunca "tashih-i hurûf" ve "icâzet" silsilesiyle hoca-talebe usulüyle aktarılmıştır.',
      en: 'Qur\'anic recitation has historically been transmitted through teacher-student mastery (ijazah).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân tilâveti yalnız kitaptan okunan bir metin değil, Hz. Peygamber\'e (s.a.v.) ulaşan canlı bir ses ve edep silsilesidir.',
        en: 'Reciting the Qur\'an is a living oral heritage linking each student back through authentic chains to the Messenger of Allah (ﷺ).',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Menâkıbü\'l-Ensâr 17 & Fedâilü\'l-Kur\'ân 8',
        en: 'Sahih al-Bukhari, Manaqib al-Ansar 17 & Fada\'il al-Qur\'an 8',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
];
