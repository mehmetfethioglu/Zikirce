import '../domain/irfan_models.dart';

/// 24 Authentic Bilingual (TR/EN) Questions sourced from Külliyat books for Esmaü'l-Hüsna & Dua.
const List<IrfanQuestion> kIrfanQuestionsKulliyatEsmaDua = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 8 QUESTIONS (esm_b_12..esm_b_19)
  // =========================================================================
  IrfanQuestion(
    id: 'esm_b_12',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'nin son hadisi olarak da bilinen rivayette "Dile hafif, mîzânda (sevap terazisinde) ağır ve Rahmân\'a çok sevimli iki kelime" hangileridir?',
      en: 'In the renowned closing hadith of Sahih al-Bukhari, which two phrases are "light on the tongue, heavy on the scale, and beloved to the Most Merciful"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sübhânallâhi ve bihamdihî, Sübhânallâhi\'l-Azîm',
          en: 'Subhanallahi wa bihamdihi, Subhanallahil-Azim',
        ),
        LocalizedText(
          tr: 'Sadece şiir okumak',
          en: 'Reciting poetry',
        ),
        LocalizedText(
          tr: 'Yalnızca yolculuk duası',
          en: 'Only travel prayers',
        ),
        LocalizedText(
          tr: 'Sabah rüzgârını saymak',
          en: 'Counting morning winds',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'İçinde hem tesbih ("Subhanallah") hem hamd hem de "El-Azîm" ismi geçer.',
      en: 'Combines glorification, praise, and the Divine Name Al-Azim.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İmam Buhârî büyük hadis külliyatını bu kolay fakat terazide pek ağır olan zikirle tamamlayarak okurlarına dilini zikirle ıslatmayı vasiyet etmiştir.',
        en: 'Imam al-Bukhari closed his entire Sahih with this effortless yet weighty remembrance as a parting gift to readers.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Tevhîd 58 (Hadis No: 7563) & Daavât 65',
        en: 'Sahih al-Bukhari, Tawhid 58 (Hadith 7563) & Da\'awat 65',
      ),
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'El-Azîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_13',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn\'de İmam Nevevî\'nin "İstiğfar" babında aktardığı hadiste Peygamber Efendimiz (s.a.v.) "Vallâhi ben günde ...... defadan fazla Allah\'a istiğfar ve tövbe ederim" buyurmuştur.',
      en: 'In Riyad as-Salihin (Chapter on Istighfar), the Prophet (ﷺ) stated: "By Allah, I seek forgiveness from Allah and turn to Him in repentance more than ...... times a day."',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Yetmiş (bir rivayette yüz)', en: 'Seventy (or one hundred)'),
        LocalizedText(tr: 'Yalnızca bir', en: 'Only once'),
        LocalizedText(tr: 'Ayda üç', en: 'Three times a month'),
        LocalizedText(tr: 'Yılda beş', en: 'Five times a year'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Günahsız olduğu hâlde bize kulluk ve tevazu öğretmek için günde 70-100 defa "Estağfirullah" derdi.',
      en: 'Though sinless, he taught humility by seeking forgiveness 70 to 100 times daily.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İstiğfar yalnız günah sonrası değil, kalbin daima Rabbine yönelişinin ve derecelerin yükselmesinin anahtarıdır.',
        en: 'Istighfar is not only for faults; it keeps the heart humble, clear, and continually ascending toward Allah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Riyâzü\'s-Sâlihîn, Tövbe & İstiğfar Babı; Sahîh-i Buhârî, Daavât 3',
        en: 'Riyad as-Salihin, Chapter on Repentance; Sahih al-Bukhari, 6307',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
      linkedZikirKey: 'İstiğfar',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_14',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de Ebû Mûsâ el-Eş\'arî\'den (r.a.) rivayetle "Lâ havle ve lâ kuvvete illâ billâh" zikri cennet hazinelerinden bir hazine olarak müjdelenmiştir.',
      en: 'Narrated from Abu Musa al-Ash\'ari (r.a.) in Sahih al-Bukhari, "La hawla wa la quwwata illa billah" is described as one of the treasures of Paradise.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Anlamı: "Günahtan kaçacak güç ve ibadete yetecek kuvvet ancak Allah\'ın yardımıyladır."',
      en: 'Meaning: "There is neither might nor power except through Allah."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Bu zikir kulun kendi gücünden sıyrılıp mutlak kudret sahibi Allah\'a dayanmasının en özlü ilânıdır.',
        en: 'This dhikr expresses complete reliance upon Allah\'s power in both resisting harm and doing good.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Daavât 50; Sahîh-i Müslim, Zikir 44',
        en: 'Sahih al-Bukhari, Da\'awat 50; Sahih Muslim, Dhikr 44',
      ),
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'Lâ havle ve lâ kuvvete illâ billâh',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_15',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    specialDayTags: ['kadir', 'ramazan'],
    stem: LocalizedText(
      tr: 'Sünen-i Tirmizî\'de Hz. Âişe\'nin (r.anhâ) "Kadir Gecesi\'ne rastlarsam ne dua edeyim?" sorusuna Resûlullah (s.a.v.) hangi duayı öğretmiştir?',
      en: 'In Sunan at-Tirmidhi, when Aishah (r.a.) asked what to supplicate upon encountering Laylat al-Qadr, which supplication did the Prophet (ﷺ) teach her?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Allâhümme inneke afüvvün tuhibbü\'l-afve fa\'fü annî',
          en: 'Allahumma innaka \'Afuwwun tuhibbul-\'afwa fa\'fu \'anni (O Allah, You are Pardoning and love pardon, so pardon me)',
        ),
        LocalizedText(
          tr: 'Sadece dünya malı isteme duası',
          en: 'A prayer purely for worldly wealth',
        ),
        LocalizedText(
          tr: 'Yalnızca yolculuk selâmeti duası',
          en: 'Only a travel safety prayer',
        ),
        LocalizedText(
          tr: 'Hiç dua etmeden susmak',
          en: 'Remaining completely silent',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'İçinde "affetmeyi seven, çok bağışlayıcı" anlamındaki "El-Afüvv" ismi geçer.',
      en: 'Invokes the Divine Name Al-\'Afuww (The Pardoner).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Afuvv olan Allah günahları yalnız örtmekle kalmaz, izini dahi silerek kuluna tertemiz bir başlangıç bahşeder.',
        en: 'Al-\'Afuww not only conceals sins but erases their traces completely, granting the servant a fresh spiritual start.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Daavât 84 (Hadis No: 3513)',
        en: 'Sunan at-Tirmidhi, Da\'awat 84 (Hadith 3513)',
      ),
      linkedBookId: 'book_hadith_tirmizi',
      linkedZikirKey: 'El-Afuvv',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_16',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Esmâ-i Hüsnâ\'yı ve anlamlarını doğru şekilde eşleştiriniz.',
      en: 'Match these Beautiful Names of Allah with their accurate meanings.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Es-Selâm', en: 'As-Salam'),
          right: LocalizedText(
            tr: 'Her türlü noksandan münezzeh, esenlik kaynağı',
            en: 'The Source of Peace and Safety',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Vehhâb', en: 'Al-Wahhab'),
          right: LocalizedText(
            tr: 'Karşılıksız bolca ihsan eden',
            en: 'The Supreme Bestower without expectation',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Latîf', en: 'Al-Latif'),
          right: LocalizedText(
            tr: 'En ince işleri bilen, lütufkâr',
            en: 'The Subtle and Most Gracious',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Hafîz', en: 'Al-Hafiz'),
          right: LocalizedText(
            tr: 'Bütün varlığı koruyup gözeten',
            en: 'The Preserver and Protector',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Her bir isim Kur\'ân\'da ve günlük dualarımızda sıkça nida edilen güzel isimlerdendir.',
      en: 'Each Name frequently appears in Qur\'anic supplications and daily remembrance.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Esmâ-i Hüsnâ\'yı mânâsıyla bilip zikretmek kalbe itminan, duaya ise ihlas ve ümit katar.',
        en: 'Remembering Allah\'s Beautiful Names with understanding fills the heart with serenity and confident hope.',
      ),
      sourceRef: LocalizedText(
        tr: 'Haşr Sûresi, 59/22-24; Sahîh-i Buhârî, Şürût 18',
        en: 'Surah Al-Hashr, 59:22-24; Sahih al-Bukhari, Shurut 18',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
      linkedZikirKey: 'Es-Selâm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_17',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Küçük Sözler\'deki Birinci Söz\'de her hayırlı işin başında söylenmesi gereken "Besmele" hangi misal ile açıklanır?',
      en: 'In the First Word of Küçük Sözler, through what parable is the power of starting every act with Bismillah explained?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kendi zayıf gücüyle değil, büyük bir sultanın namıyla hareket eden yolcu misaliyle',
          en: 'A traveler relying not on personal weakness, but acting in the name of the Sovereign King',
        ),
        LocalizedText(
          tr: 'Kayıp bir pusula tamiriyle',
          en: 'Repairing a broken compass',
        ),
        LocalizedText(
          tr: 'Yalnızca deniz ticareti defteriyle',
          en: 'A maritime ledger alone',
        ),
        LocalizedText(
          tr: 'Altın madeni arama haritasıyla',
          en: 'A gold-mining map',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Birinci Söz "Bismillâh her hayrın başıdır" cümlesiyle açılır.',
      en: 'Opens with "In the Name of Allah is the beginning of all good."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Besmele çekmek, âciz ve fakir olan insanın kendi nefsine değil, bütün kâinatın Sahibinin tükenmez hazinesine ve himayesine dayanması demektir.',
        en: 'Reciting Bismillah shifts reliance from human frailty to the inexhaustible power and mercy of the Lord of all worlds.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Küçük Sözler, Birinci Söz',
        en: 'Risale-i Nur Collection, Short Words (Küçük Sözler), First Word',
      ),
      linkedBookId: 'book_rn_kucuk_sozler',
      linkedZikirKey: 'Besmele',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_18',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn\'de aktarılan hadise göre, bir kimse gıyabında (arkasından) Müslüman kardeşine dua ettiğinde yanındaki müvekkel melek ne der?',
      en: 'According to Riyad as-Salihin and Sahih Muslim, when a believer supplicates for a fellow Muslim in their absence, what does the appointed angel say?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: '"Âmin! İstediğinin bir misli de sana verilsin"',
          en: '"Amin, and may you receive the like thereof!"',
        ),
        LocalizedText(
          tr: '"Bu dua kabul olmaz"',
          en: '"This prayer is rejected"',
        ),
        LocalizedText(
          tr: '"Yalnızca kendin için dua et"',
          en: '"Pray only for yourself"',
        ),
        LocalizedText(
          tr: '"Bir daha tekrarlama"',
          en: '"Do not repeat it"',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'En çabuk kabul olunan dualardan biri, müminin din kardeşine gıyabında ettiği samimi duadır.',
      en: 'Among the most swiftly answered prayers is a sincere supplication made in absence for another.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Başkasına hayır dilemek kalpteki haset ve bencilliği eritir; hem kardeşe hem de dua edenin kendisine bereket olarak geri döner.',
        en: 'Wishing good for others cleanses the heart of envy and brings equal blessing back upon the supplicant.',
      ),
      sourceRef: LocalizedText(
        tr: 'Riyâzü\'s-Sâlihîn, Dua Babı; Sahîh-i Müslim, Zikir 87',
        en: 'Riyad as-Salihin, Chapter on Dua; Sahih Muslim, Dhikr 87',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
      linkedZikirKey: 'El-Vedûd',
    ),
  ),
  IrfanQuestion(
    id: 'esm_b_19',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sünen-i Tirmizî ve Ebû Dâvûd\'da bildirildiği üzere, Peygamber Efendimiz (s.a.v.) sık sık "Yâ Mukallibe\'l-kulûb, sebbit kalbî alâ dînik" (Ey kalpleri evirip çeviren Allah\'ım! Kalbimi dinin üzere sabit kıl) diye dua ederdi.',
      en: 'As reported in Sunan at-Tirmidhi, the Prophet (ﷺ) frequently supplicated: "O Turner of hearts, keep my heart firm upon Your religion."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Ümmü Seleme (r.anhâ) bu duanın hikmetini sorduğunda kalplerin Allah\'ın kudret elinde olduğunu bildirmiştir.',
      en: 'When Umm Salamah (r.a.) asked why, he explained that every heart rests in Allah\'s control.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İman ve hidayet üzere sebat etmek kulun kendi gücüyle değil, El-Hâdî olan Allah\'a devamlı niyaz ile korunur.',
        en: 'Steadfastness in faith is sustained by continually turning in prayer to Al-Hadi (The Guide).',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Kader 7 & Daavât 89',
        en: 'Sunan at-Tirmidhi, Qadar 7 & Da\'awat 89',
      ),
      linkedBookId: 'book_hadith_tirmizi',
      linkedZikirKey: 'El-Hâdî',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 8 QUESTIONS (esm_o_12..esm_o_19)
  // =========================================================================
  IrfanQuestion(
    id: 'esm_o_12',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Lem\'alar\'daki Birinci Lem\'a\'ya göre Hz. Yûnus\'un (a.s.) balığın karnında karanlıklar içinde yaptığı "Lâ ilâhe illâ ente sübhâneke innî küntü mine\'z-zâlimîn" münâcatı bugün mümin için hangi üç hakikati cem eder?',
      en: 'According to the First Flash in Lem\'alar, Prophet Yunus\'s (a.s.) supplication in the belly of the whale ("La ilaha illa Anta Subhanaka inni kuntu minaz-zalimin") unites which three spiritual truths?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Tevhid (Lâ ilâhe illâ ente), Tenzihten gelen Tesbih (Sübhâneke) ve Acz/İtiraf-ı Kusur (İnnî küntü mine\'z-zâlimîn)',
          en: 'Tawhid (none worthy of worship save You), Glorification (Glory be to You), and humble admission of fault',
        ),
        LocalizedText(
          tr: 'Sadece denizcilik bilgisi',
          en: 'Maritime navigation alone',
        ),
        LocalizedText(
          tr: 'Dünya zenginliği talebi',
          en: 'Requesting worldly wealth',
        ),
        LocalizedText(
          tr: 'Yalnızca geçmiş kıssa nakli',
          en: 'Pure historical narration',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Enbiyâ Sûresi 87-88. âyetlerde Allah\'ın onun duasını kabul edip "İşte müminleri de böyle kurtarırız" buyurduğu zikirdir.',
      en: 'Recorded in Surah Al-Anbiya 21:87-88 with the promise "And thus do We save the believers."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Birinci Lem\'a, gece, nefis ve dünya gafletinden oluşan karanlıklar içinde kalan insan için en büyük kurtuluş anahtarının Hz. Yûnus\'un (a.s.) bu duası olduğunu gösterir.',
        en: 'The First Flash teaches that amidst spiritual darkness and anxiety, Prophet Yunus\'s prayer remains a universal key to deliverance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Lem\'alar, Birinci Lem\'a; Enbiyâ 21/87-88',
        en: 'Risale-i Nur Collection, The Flashes (Lem\'alar), 1st Flash; 21:87-88',
      ),
      linkedBookId: 'book_rn_lemalar',
      linkedZikirKey: 'Yûnus (a.s.) Duası',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_13',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Lem\'alar\'daki İkinci Lem\'a ve Hastalar Risalesi\'ne göre Hz. Eyyûb (a.s.) yıllar süren ağır hastalığından ne zaman dua ile şifa istemiştir?',
      en: 'According to the Second Flash and Hastalar Risalesi, when did Prophet Ayyub (a.s.) finally turn in prayer for healing from his prolonged illness?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hastalık dil ile zikrine ve kalp ile tefekkürüne engel olmaya başladığında; "Bana zarar dokundu, Sen merhametlilerin en merhametlisisin" diyerek',
          en: 'Only when the affliction began hindering his tongue\'s dhikr and heart\'s contemplation, saying "Harm has touched me, and You are Most Merciful"',
        ),
        LocalizedText(
          tr: 'İlk gün sabırsızlanıp şikâyet ederek',
          en: 'Complaining impatiently on the first day',
        ),
        LocalizedText(
          tr: 'Hiç dua etmeyerek',
          en: 'Never making supplication',
        ),
        LocalizedText(
          tr: 'İnsanlara darılıp küstüğü için',
          en: 'Out of anger toward people',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Enbiyâ 83. âyette geçen bu duada Hz. Eyyûb (a.s.) şikâyet değil edep ve ubudiyet üzere niyaz etmiştir.',
      en: 'In Surah Al-Anbiya 21:83, his supplication is a model of patience and reverence without complaint.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hastalık sabırla karşılandığında günahlara kefâret ve ömrün her dakikasını ibadete çeviren bir lütfa dönüşür; şifa ise Er-Rahîm olan Allah\'tan edeple istenir.',
        en: 'Illness borne with patience atones for sins and elevates worship, while healing is sought humbly from the Most Merciful.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Lem\'alar (2. Lem\'a) & Hastalar Risalesi',
        en: 'Risale-i Nur Collection, 2nd Flash & Treatise for the Sick',
      ),
      linkedBookId: 'book_rn_hastalar_risalesi',
      linkedZikirKey: 'Eyyûb (a.s.) Duası',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_14',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "Seyyidü\'l-İstiğfar" (İstiğfarların Efendisi) olarak bildirilen duada kul ilk olarak neyi ikrar eder?',
      en: 'In the supplication named "Sayyid al-Istighfar" (Master Supplication for Forgiveness) in Sahih al-Bukhari, what does the servant affirm first?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: '"Allah\'ım, Sen benim Rabbimsin, Senden başka ilâh yoktur; beni Sen yarattın ve ben Senin kulunum"',
          en: '"O Allah, You are my Lord, none has the right to be worshipped but You; You created me and I am Your servant"',
        ),
        LocalizedText(
          tr: '"Ben hiç hata yapmam"',
          en: '"I never make mistakes"',
        ),
        LocalizedText(
          tr: '"Dünyalık rızkımı artırmanı isterim"',
          en: '"I ask only for worldly status"',
        ),
        LocalizedText(
          tr: '"Gece namazından muaf olmak dilerim"',
          en: '"Exempt me from night prayers"',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Ardından nimetleri ve günahları itiraf ederek "Beni bağışla, zira günahları ancak Sen bağışlarsın" diye bitirir.',
      en: 'Continues by acknowledging Allah\'s blessings and one\'s sins, asking forgiveness from Him alone.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Şeddâd b. Evs (r.a.) rivayetine göre, bu duayı yakînen inanarak gündüz okuyan akşama kadar, gece okuyan sabaha kadar vefat ederse cennet ehlinden olur.',
        en: 'Narrated by Shaddad ibn Aws (r.a.), reciting this prayer with conviction morning and evening brings immense promise of salvation.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Daavât 2 (Hadis No: 6306)',
        en: 'Sahih al-Bukhari, Da\'awat 2 (Hadith 6306)',
      ),
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'İstiğfar',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_15',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Tirmizî\'de "İsm-i A\'zam" (Allah\'ın en yüce ismi) ile dua edildiğinde duanın kabul edileceği bildirilirken en çok işaret edilen isimler "El-Hayy" ve "El-Kayyûm"dur.',
      en: 'In Sunan Abi Dawud and at-Tirmidhi, among the strongest narrations identifying Al-Ism al-A\'zam (Allah\'s Greatest Name) by which supplications are answered are "Al-Hayy" and "Al-Qayyum."',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Bakara 163, Âl-i İmrân 2 ve Tâhâ 111 âyetlerinde bu iki isim birlikte yer alır.',
      en: 'These two Names appear together in Al-Baqarah 2:255, Al \'Imran 3:2, and Ta-Ha 20:111.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Hayy ezelî ve ebedî hayat sahibi, El-Kayyûm ise bütün varlığı kendi kudretiyle ayakta tutandır; bu iki isimle dua eden kul kâinatın hayat kaynağına sığınmış olur.',
        en: 'Al-Hayy is the Ever-Living and Al-Qayyum the Self-Subsisting Sustainer of all; calling upon them anchors prayer in eternal life and care.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Ebû Dâvûd, Vitir 23; Sünen-i Tirmizî, Daavât 64',
        en: 'Sunan Abi Dawud, Witr 23; Sunan at-Tirmidhi, Da\'awat 64',
      ),
      linkedBookId: 'book_hadith_ebu_davud',
      linkedZikirKey: 'El-Kayyûm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_16',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Peygamber dualarını ve edildikleri durumları doğru şekilde eşleştiriniz.',
      en: 'Match these Qur\'anic prophetic supplications with their occasions.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Âdem (a.s.) Duası', en: 'Prophet Adam\'s Dua'),
          right: LocalizedText(
            tr: '"Rabbimiz! Biz kendimize zulmettik..." (A\'râf 23)',
            en: '"Our Lord, we have wronged ourselves..." (7:23)',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hz. Mûsâ (a.s.) Duası', en: 'Prophet Musa\'s Dua'),
          right: LocalizedText(
            tr: '"Rabbim! İndireceğin her hayra muhtacım" (Kasas 24)',
            en: '"My Lord, I am in need of whatever good You send" (28:24)',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hz. Süleyman (a.s.) Duası', en: 'Prophet Sulayman\'s Dua'),
          right: LocalizedText(
            tr: '"Beni nimetlerine şükretmeye sevk et" (Neml 19)',
            en: '"Inspire me to be grateful for Your favor" (27:19)',
          ),
        ),
        (
          left: LocalizedText(tr: 'Hz. İbrâhim (a.s.) Duası', en: 'Prophet Ibrahim\'s Dua'),
          right: LocalizedText(
            tr: '"Beni ve soyumu namazı kılanlardan eyle" (İbrâhim 40)',
            en: '"Make me and my offspring establish prayer" (14:40)',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân\'daki peygamber duaları her müminin hayatında kullanabileceği en bereketli münâcatlardır.',
      en: 'Qur\'anic prophetic duas are timeless templates for every stage of life.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tövbe, ihtiyaç, şükür ve nesil duası—Kur\'ân bize nasıl yakaracağımızı bizzat peygamberlerin diliyle öğretmiştir.',
        en: 'Through the words of the prophets, the Qur\'an teaches us how to seek forgiveness, sustenance, gratitude, and righteous generations.',
      ),
      sourceRef: LocalizedText(
        tr: 'Diyanet Vakfı Kur\'ân-ı Kerîm Meâli, A\'râf, İbrâhim, Neml & Kasas',
        en: 'Diyanet Vakfı Meâl, Surahs 7, 14, 27 & 28',
      ),
      linkedBookId: 'book_meal_diyanet',
      linkedZikirKey: 'Âdem (a.s.) Duası',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_17',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sünen-i Tirmizî ve Riyâzü\'s-Sâlihîn\'de meclis/toplantı sonunda okunan "Kefâretü\'l-Meclis" (Meclis kefâreti) duası hangi tesbih ve istiğfarı içerir?',
      en: 'In Sunan at-Tirmidhi and Riyad as-Salihin, what words form the "Expiation of a Gathering" (Kaffarat al-Majlis) recited upon rising from a meeting?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sübhânekellâhümme ve bihamdike eşhedü en lâ ilâhe illâ ente estağfiruke ve etûbü ileyk',
          en: 'Subhanakallahumma wa bihamdika, ashhadu an la ilaha illa Anta, astaghfiruka wa atubu ilayk',
        ),
        LocalizedText(
          tr: 'Sadece dünya haberlerini tekrarlamak',
          en: 'Repeating daily news items',
        ),
        LocalizedText(
          tr: 'Yalnızca yemek duası okumak',
          en: 'Only mealtime prayers',
        ),
        LocalizedText(
          tr: 'Hiç selâm vermeden çıkmak',
          en: 'Leaving without greeting',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Mecliste farkında olmadan söylenen boş sözlere kefâret olması için tavsiye edilmiştir.',
      en: 'Taught as an expiation for inadvertent idle talk during any gathering.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sohbet veya toplantı sonunda Allah\'ı tesbih ve istiğfar ile ayrılmak, meclisi hayır ve rahmet mührüyle kapatmaktır.',
        en: 'Closing gatherings with glorification and repentance seals human company with remembrance and mercy.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Daavât 38; Riyâzü\'s-Sâlihîn, Hadis No: 830',
        en: 'Sunan at-Tirmidhi, Da\'awat 38; Riyad as-Salihin, Hadith 830',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
      linkedZikirKey: 'Subhanallah',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_18',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sözler\'deki Yirmi Üçüncü Söz\'de "Dua bir ubûdiyettir, semereleri uhrevîdir" buyrulduktan sonra dünyevî maksatlar için yapılan duaların ne zaman kabul olmadığı değil, nasıl cevaplandığı açıklanır?',
      en: 'In the Twenty-Third Word of Sözler, how does Allah respond to sincere worldly supplications when the exact requested thing does not appear immediately?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Her duaya mutlaka cevap verilir; ya istenenin aynısı, ya daha hayırlısı ya da âhirete saklanan sevabı ihsan edilir',
          en: 'Every sincere prayer is answered—either with what was asked, something better, or stored reward in the Hereafter',
        ),
        LocalizedText(
          tr: 'İstenen hemen olmazsa dua tamamen boşa gitmiştir',
          en: 'If not granted instantly, the prayer is wasted',
        ),
        LocalizedText(
          tr: 'Dua sadece zenginlerin hakkıdır',
          en: 'Supplication belongs only to the wealthy',
        ),
        LocalizedText(
          tr: 'Yalnızca yılda bir gün kabul edilir',
          en: 'Accepted only one day per year',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hekîm misalinde hasta çocuğun istediği her ilâç yerine doktorun en faydalısını vermesi anlatılır.',
      en: 'Uses the parable of a wise physician giving a patient what truly heals rather than whatever is demanded.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Dua ibadetin özüdür. Allah El-Mücîb\'dir; kulunun elini boş çevirmez, hikmetiyle ya dünya için hayırlısını ya da âhiret için en kalıcısını verir.',
        en: 'Supplication is the essence of worship. Al-Mujib (The Responsive) never leaves a sincere call unanswered, granting what wisdom sees best.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Sözler, 23. Söz, 1. Mebhas, 5. Nükte',
        en: 'Risale-i Nur Collection, The Words (Sözler), 23rd Word',
      ),
      linkedBookId: 'book_rn_sozler',
      linkedZikirKey: 'El-Mücîb',
    ),
  ),
  IrfanQuestion(
    id: 'esm_o_19',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Müslim\'de bildirilen "Zülcelâli ve\'l-İkrâm" ismi, özellikle hangi mübarek zikirle birlikte namazın ardından okunur?',
      en: 'In Sahih Muslim and Sunan Abi Dawud, the Divine Name "Dhul-Jalali wal-Ikram" is famously recited immediately after the salam of prayer alongside which phrase?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: '"Allâhümme entesselâmü ve minkesselâm, tebârekte yâ Zel-celâli ve\'l-ikrâm"',
          en: '"Allahumma Antas-Salam wa minkas-salam, tabarakta ya Dhal-Jalali wal-Ikram"',
        ),
        LocalizedText(
          tr: 'Sadece ezandan önce okunur',
          en: 'Recited only before the Adhan',
        ),
        LocalizedText(
          tr: 'Yalnızca bayram hutbesinde okunur',
          en: 'Only in Eid sermons',
        ),
        LocalizedText(
          tr: 'Namazın rükûsunda okunur',
          en: 'During bowing in prayer',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Sevbân (r.a.) rivayetinde Efendimiz selâm verdikten hemen sonra üç defa istiğfar edip bu duayı okurdu.',
      en: 'Narrated by Thawban (r.a.), recited immediately after three istighfars upon ending prayer.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Namazdan çıkar çıkmaz üç istiğfar ile kusurları bağışlatmak ve Es-Selâm ile Zü\'l-Celâli ve\'l-İkrâm isimlerine sığınmak nebevî tesbihatın ilk adımıdır.',
        en: 'Seeking forgiveness thrice and invoking As-Salam and Dhul-Jalali wal-Ikram opens the Prophetic post-prayer remembrance.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Mesâcid 135; Sünen-i Ebû Dâvûd, Salât 361',
        en: 'Sahih Muslim, Masajid 135; Sunan Abi Dawud, Salah 361',
      ),
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'Zü\'l-Celâli ve\'l-İkrâm',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 8 QUESTIONS (esm_i_12..esm_i_19)
  // =========================================================================
  IrfanQuestion(
    id: 'esm_i_12',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Lem\'alar\'daki Otuzuncu Lem\'a\'da İsm-i A\'zam ve altı nur olarak şerh edilen altı Esmâ-i Hüsnâ hangileridir?',
      en: 'In the Thirtieth Flash of Lem\'alar, which six Beautiful Names are expounded as the Six Radiant Aspects of Al-Ism al-A\'zam?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kuddûs, Adl, Hakem, Ferd, Hayy, Kayyûm',
          en: 'Al-Quddus, Al-\'Adl, Al-Hakam, Al-Fard, Al-Hayy, Al-Qayyum',
        ),
        LocalizedText(
          tr: 'Yalnızca üç isimden oluşur',
          en: 'Consists of only three names',
        ),
        LocalizedText(
          tr: 'Kâbıd, Bâsıt, Hafîz, Mâni\'',
          en: 'Al-Qabid, Al-Basit, Al-Hafiz, Al-Mani\'',
        ),
        LocalizedText(
          tr: 'Sadece yıldız isimleridir',
          en: 'Only names of stars',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Eskişehir\'de telif edilen 30. Lem\'a "Altı Nükte" hâlinde bu altı ismi kâinat delilleriyle izah eder.',
      en: 'The 30th Flash devotes six sections to each of these six Names in creation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Otuzuncu Lem\'a, kâinattaki temizliği El-Kuddûs ile, dengeyi El-Adl ile, hikmetli düzeni El-Hakem ile, birliği El-Ferd ile, canlılığı El-Hayy ile ve kıyamı El-Kayyûm ile okutur.',
        en: 'The 30th Flash reads cosmic cleanliness through Al-Quddus, balance through Al-\'Adl, wisdom through Al-Hakam, unity through Al-Fard, life through Al-Hayy, and sustenance through Al-Qayyum.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Lem\'alar, Otuzuncu Lem\'a',
        en: 'Risale-i Nur Collection, The Flashes (Lem\'alar), 30th Flash',
      ),
      linkedBookId: 'book_rn_lemalar',
      linkedZikirKey: 'El-Kuddûs',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_13',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Şuâlar\'daki Dördüncü Şuâ\'da (Âyet-i Hasbiye) Âl-i İmrân 173. âyetteki "Hasbünallâhü ve ni\'me\'l-vekîl" zikri, insanın fânîlik ve acizlik elemlerine karşı nasıl bir sığınak olarak şerh edilir?',
      en: 'In the Fourth Ray of Şuâlar (Commentary on Hasbunallahu wa ni\'mal-Wakil, Al \'Imran 3:173), how does this dhikr heal human vulnerability and existential anxiety?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bütün hadisat ve ihtiyaçlar karşısında kâinatın Kadîr-i Zülcelâl\'ini vekil tayin ederek kalbe emniyet ve tevekkül kazandırır',
          en: 'It entrusts every trial and need to the All-Powerful Guardian, instilling unshakeable serenity and trust (tawakkul)',
        ),
        LocalizedText(
          tr: 'Sebeplere başvurmayı yasaklar',
          en: 'It forbids taking practical precautions',
        ),
        LocalizedText(
          tr: 'Sadece savaş meydanında okunur',
          en: 'Recited solely on battlefields',
        ),
        LocalizedText(
          tr: 'İnsanlardan tamamen uzaklaşmayı emreder',
          en: 'Commands abandoning all human society',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hem Hz. İbrâhim (a.s.) ateşe atılırken hem de Hz. Muhammed (s.a.v.) Uhud sonrasında bu âyetle tevekkül etmiştir.',
      en: 'Narrated in Sahih al-Bukhari as the words spoken by both Ibrahim (a.s.) and Muhammad (ﷺ) at moments of severe trial.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Dördüncü Şuâ, insanın sayısız ihtiyaçlarına ve korkularına karşı Allah\'ın tek başına kâfi (Hasbî) ve en güzel vekil olduğunu dokuz mertebede anlatır.',
        en: 'The Fourth Ray unveils across nine levels how Allah alone suffices the servant and stands as the finest Guardian.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Şuâlar, 4. Şuâ; Sahîh-i Buhârî, Tefsîr 3/13',
        en: 'Risale-i Nur Collection, The Rays (Şuâlar), 4th Ray; Bukhari',
      ),
      linkedBookId: 'book_rn_sualar',
      linkedZikirKey: 'Hasbünallahu ve ni\'mel vekil',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_14',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Otuzuncu Lem\'a\'daki Altı İsm-i A\'zam ve kâinattaki tecellîlerini doğru şekilde eşleştiriniz.',
      en: 'Match these Names of Allah with the cosmic realities through which they manifest in the 30th Flash and Ayat al-Kubra.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'El-Kuddûs', en: 'Al-Quddus'),
          right: LocalizedText(
            tr: 'Kâinatın daimî nezâfet ve arınması',
            en: 'Perpetual cleanliness and renewal of the earth',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Adl', en: 'Al-\'Adl'),
          right: LocalizedText(
            tr: 'Her varlıkta hassas ölçü ve mîzan',
            en: 'Precise measure and equilibrium in creation',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Hakem', en: 'Al-Hakam'),
          right: LocalizedText(
            tr: 'Zerrelerden yıldızlara hikmetli düzen',
            en: 'Wise order from atoms to galaxies',
          ),
        ),
        (
          left: LocalizedText(tr: 'El-Hayy', en: 'Al-Hayy'),
          right: LocalizedText(
            tr: 'Yüz binlerce canlıya hayat verilmesi',
            en: 'Bestowal of life across countless species',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Her bir varlık katmanı Cenâb-ı Hakk\'ın bir isminin parlak aynasıdır.',
      en: 'Each layer of nature mirrors a distinct Beautiful Name of Allah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Tefekkürle kâinata bakan mümin, çevresindeki temizlikte Kuddûs\'ü, dengede Adl\'i, hikmette Hakem\'i ve canlılıkta Hayy\'ı görür.',
        en: 'Contemplative faith reads Al-Quddus in nature\'s purity, Al-\'Adl in balance, Al-Hakam in order, and Al-Hayy in life.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Lem\'alar, 30. Lem\'a',
        en: 'Risale-i Nur Collection, The Flashes (Lem\'alar), 30th Flash',
      ),
      linkedBookId: 'book_rn_lemalar',
      linkedZikirKey: 'El-Adl',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_15',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Âyetü\'l-Kübrâ (Yedinci Şuâ) risalesinde kâinattan Hâlık\'ını soran seyyah; semâlardan arzın tabakalarına, rüzgârlardan bulutlara kadar her mertebeden "Vâhid-i Ehad" şehadetini dinler.',
      en: 'In Ayat al-Kubra (The Seventh Ray), the traveler asking the universe about its Creator hears a unified testimony of divine Oneness from the skies, winds, rain, and earth.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Eser "Kâinattan Hâlık\'ını soran bir seyyahın müşâhedâtıdır" cümlesiyle bilinir.',
      en: 'Famous as the observations of a traveler questioning the cosmos about its Maker.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Âyetü\'l-Kübrâ, bütün kâinatı bir zikir halkası ve Allah\'ın birliğine şahitlik eden büyük bir kitap olarak okur.',
        en: 'Ayat al-Kubra reads the entire universe as a living circle of dhikr testifying to Allah\'s Oneness and Majesty.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Âyetü\'l-Kübrâ (7. Şuâ)',
        en: 'Risale-i Nur Collection, Ayat al-Kubra (7th Ray)',
      ),
      linkedBookId: 'book_rn_ayetul_kubra',
      linkedZikirKey: 'Kelime-i Tevhid',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_16',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Münâcat Risalesi\'nde (Üçüncü Şuâ) kulun Allah\'a karşı yakarışı hangi temel şuur üzerine kurulur?',
      en: 'In the Treatise on Supplication (Münâcat Risalesi / 3rd Ray), upon what core awareness is the believer\'s prayer built?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Kendi nihayetsiz acz ve fakrını görüp Rabb\'inin nihayetsiz kudret ve rahmetine iltica etmek',
          en: 'Recognizing one\'s own boundless impotence and need, and taking refuge in Allah\'s infinite power and mercy',
        ),
        LocalizedText(
          tr: 'Yalnızca kendi başarısıyla övünmek',
          en: 'Boasting of one\'s own achievements',
        ),
        LocalizedText(
          tr: 'Kâinattaki nimetleri sıradan görmek',
          en: 'Treating blessings as mere accidents',
        ),
        LocalizedText(
          tr: 'Sadece başkasını tenkit etmek',
          en: 'Criticizing others',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Münâcat\'ta semâvat ve arzın her tabakasının Allah\'ı tesbih ettiği tefekkür edilir.',
      en: 'Reflects on how every realm of heavens and earth glorifies Allah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hakikî münâcat, kulun aczini bir şefaatçi yaparak Kadîr ve Rahîm olan Allah\'ın kapısını çalmasıdır.',
        en: 'True supplication turns human humility and need into an intercessor knocking at the door of the Almighty and Most Merciful.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Münâcat Risalesi (Üçüncü Şuâ)',
        en: 'Risale-i Nur Collection, Treatise on Supplication (3rd Ray)',
      ),
      linkedBookId: 'book_rn_munacat_risalesi',
      linkedZikirKey: 'Er-Rahîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_17',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Mesnevî-i Nûriye\'de kulun "Katre" gibi kendisini müstakil görmesi yerine acz, fakr, şefkat ve tefekkür yoluyla Hakk\'a ermesi anlatılırken "Fakr" kavramı neyi ifade eder?',
      en: 'In Mesnevî-i Nûriye, among the four steps of servitude (impotence, poverty, compassion, contemplation), what does "Faqr" (spiritual poverty) signify?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Her şeyde ve her nefeste El-Ganî ve Er-Rezzâk olan Allah\'a muhtaç olduğunu idrak etmek',
          en: 'Recognizing absolute dependence in every breath upon Al-Ghani (the All-Rich) and Ar-Razzaq',
        ),
        LocalizedText(
          tr: 'Helâl kazancı tamamen terk etmek',
          en: 'Abandoning lawful work',
        ),
        LocalizedText(
          tr: 'Maddî dilencilik yapmak',
          en: 'Physical begging',
        ),
        LocalizedText(
          tr: 'İlim öğrenmeyi bırakmak',
          en: 'Stopping all education',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Fâtır Sûresi 15. âyetteki "Ey insanlar! Siz Allah\'a muhtaçsınız (fukarâ); Allah ise Ganî ve Hamîd\'dir" hakikatidir.',
      en: 'Echoes Surah Fatir 35:15: "O mankind, you are those in need of Allah, while Allah is the Free of need."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İnsanın kendi fakirliğini bilmesi, kendisini El-Ganî olan Rabb\'in sonsuz hazinesine bağlayan en kısa ubûdiyet yoludur.',
        en: 'Realizing our spiritual poverty before Allah connects the soul directly to the boundless generosity of Al-Ghani.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Mesnevî-i Nûriye; Fâtır Sûresi, 35/15',
        en: 'Risale-i Nur Collection, Mesnevî-i Nûriye; Surah Fatir, 35:15',
      ),
      linkedBookId: 'book_rn_mesnevi',
      linkedZikirKey: 'El-Ganî',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_18',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Tirmizî\'de "Allah\'ın doksan dokuz ismi vardır; kim onları ihsâ ederse cennete girer" buyrulmuştur. İslâm âlimlerine göre "ihsâ"nın en kâmil mânâsı nedir?',
      en: 'In Sahih Muslim and at-Tirmidhi, the Prophet (ﷺ) said: "Allah has ninety-nine Names; whoever preserves (ahsa) them enters Paradise." What is the fullest scholarly meaning of "ihsa"?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İsimleri öğrenip ezberlemek, mânâlarını anlamak, onlarla dua-zikir etmek ve ahlâkî izlerini hayatına yansıtmak',
          en: 'Learning and memorizing them, understanding their meanings, supplicating by them, and embodying their moral ethos',
        ),
        LocalizedText(
          tr: 'Sadece kâğıda yazıp çekmeceye koymak',
          en: 'Merely writing them on paper and storing it away',
        ),
        LocalizedText(
          tr: 'Anlamını hiç düşünmeden tek bir sefer saymak',
          en: 'Counting them once without reflection',
        ),
        LocalizedText(
          tr: 'Sadece bir isimle yetinip diğerlerini bilmemek',
          en: 'Knowing only one Name',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kur\'ân\'da A\'râf 180: "En güzel isimler Allah\'ındır; O\'na onlarla dua edin!" buyrulur.',
      en: 'Surah Al-A\'raf 7:180 commands: "To Allah belong the best names, so invoke Him by them."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'El-Kerîm\'i bilen cömert, El-Halîm\'i bilen yumuşak huylu, Et-Tevvâb\'ı bilen bağışlayıcı ve tövbekâr olur; gerçek ihsâ budur.',
        en: 'Knowing Al-Karim inspires generosity, Al-Halim inspires forbearance, and At-Tawwab inspires repentance and mercy.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Zikir 5; A\'râf Sûresi, 7/180',
        en: 'Sahih Muslim, Dhikr 5; Surah Al-A\'raf, 7:180',
      ),
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'El-Kerîm',
    ),
  ),
  IrfanQuestion(
    id: 'esm_i_19',
    topic: IrfanTopic.esmaDua,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sünen-i İbn Mâce ve Riyâzü\'s-Sâlihîn\'de rivayet edilen hadise göre, bela ve sıkıntı anında sabreden kul "İnnâ lillâhi ve innâ ileyhi râciûn, Allâhümme\'cürnî fî musîbetî..." dediğinde Allah ona kaybettiğinden daha hayırlısını ihsan eder.',
      en: 'According to Sahih Muslim, Ibn Majah, and Riyad as-Salihin, whoever says upon calamity "Inna lillahi wa inna ilayhi raji\'un, O Allah reward me in my affliction and replace it with better" receives something better.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Ümmü Seleme (r.anhâ) eşinin vefatında bu duayı okumuş ve ardından Resûlullah (s.a.v.) ile evlenerek müminlerin annesi olmuştur.',
      en: 'Umm Salamah (r.a.) recited this very prayer and was blessed beyond her expectation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'İstircâ ("Biz Allah\'a aidiz ve O\'na döneceğiz") duası, musibet anında isyanı kesip Es-Sabûr olan Allah\'tan ecir ve yeni bir hayır kapısı dilemenin sünnet yoludur.',
        en: 'Saying Inna lillahi wa inna ilayhi raji\'un transforms grief into patient trust, opening doors of reward and renewal.',
      ),
      sourceRef: LocalizedText(
        tr: 'Riyâzü\'s-Sâlihîn, Sabır Babı; Sünen-i İbn Mâce, Cenâiz 55',
        en: 'Riyad as-Salihin, Chapter on Patience; Sunan Ibn Majah, Jana\'iz 55',
      ),
      linkedBookId: 'book_hadith_ibn_mace',
      linkedZikirKey: 'Es-Sabûr',
    ),
  ),
];
