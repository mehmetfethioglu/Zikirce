import '../domain/irfan_models.dart';

/// 24 Authentic Bilingual (TR/EN) Questions sourced from Külliyat books for Siyer-i Nebî.
const List<IrfanQuestion> kIrfanQuestionsKulliyatSiyer = [
  // =========================================================================
  // BAŞLANGIÇ (BEGINNER) — 8 QUESTIONS (siy_b_12..siy_b_19)
  // =========================================================================
  IrfanQuestion(
    id: 'siy_b_12',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['mevlid'],
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'nin "Bed\'ü\'l-Vahy" bölümünde anlatıldığı üzere, ilk vahyin ardından Hz. Hatice (r.anhâ) Efendimizi (s.a.v.) hangi bilge akrabasının yanına götürmüştür?',
      en: 'In the "Beginning of Revelation" chapter of Sahih al-Bukhari, to which knowledgeable relative did Khadijah (r.a.) take the Prophet (ﷺ) after the first revelation?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Varaka b. Nevfel', en: 'Waraqah ibn Nawfal'),
        LocalizedText(tr: 'Ebû Cehil', en: 'Abu Jahl'),
        LocalizedText(tr: 'Ümeyye b. Halef', en: 'Umayyah ibn Khalaf'),
        LocalizedText(tr: 'Nadr b. Hâris', en: 'An-Nadr ibn al-Harith'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Önceki semavî kitapları bilen yaşlı bir hanîf/âlimdi ve "Sana gelen, Hz. Mûsâ\'ya gelen Nâmûs\'tur (Cebrâil\'dir)" demişti.',
      en: 'He was an elderly scholar of earlier scriptures who recognized Jibril ("An-Namus") who had come to Moses.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Varaka b. Nevfel, Hz. Peygamber\'in (s.a.v.) anlattıklarını dinleyince onun son peygamber olduğunu tasdik etmiş ve kavminin kendisini yurdundan çıkaracağı günleri haber vermiştir.',
        en: 'Upon hearing the Prophet\'s (ﷺ) experience, Waraqah affirmed his prophethood and foretold the opposition he would face from his people.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Bed\'ü\'l-vahy 3 (Hadis No: 3)',
        en: 'Sahih al-Bukhari, Bad\' al-Wahy 3 (Hadith 3)',
      ),
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_13',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['hicret'],
    stem: LocalizedText(
      tr: 'Mekke\'de müşriklerin baskısı artınca Hz. Peygamber\'in (s.a.v.) izniyle bir grup sahâbî ilk hicreti nereye yapmıştır?',
      en: 'When persecution intensified in Makkah, to which land did the Prophet (ﷺ) permit the first group of Companions to migrate?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Habeşistan', en: 'Abyssinia (Habasha)'),
        LocalizedText(tr: 'Şam', en: 'Damascus'),
        LocalizedText(tr: 'Yemen', en: 'Yemen'),
        LocalizedText(tr: 'Mısır', en: 'Egypt'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Adaletli hükümdar Necâşî\'nin yönettiği Kızıldeniz\'in karşısındaki ülkedir.',
      en: 'Across the Red Sea, ruled by the just King Negus (Najashi).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Habeşistan\'da Ca\'fer b. Ebû Tâlib (r.a.) Necâşî\'nin huzurunda Meryem Sûresi\'ni okumuş; Necâşî gözyaşları içinde müslümanları himaye altına almıştır.',
        en: 'In Abyssinia, Ja\'far ibn Abi Talib recited Surah Maryam before King Negus, who wept and granted the Muslims full protection.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Menâkıbü\'l-Ensâr 37; Riyâzü\'s-Sâlihîn',
        en: 'Sahih al-Bukhari, Manaqib al-Ansar 37; Riyad as-Salihin',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_14',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Sünen-i Tirmizî\'nin Şemâil ve Menâkıb bölümlerinde Hz. Enes b. Mâlik\'in (r.a.) rivayetine göre, on yıl boyunca Resûlullah\'a (s.a.v.) hizmet ettiği hâlde Efendimiz ona bir kez bile "öf!" dememiş ve yaptığı bir iş için azarlamamıştır.',
      en: 'According to Anas ibn Malik (r.a.) in Sunan at-Tirmidhi, during ten years of serving the Prophet (ﷺ), the Prophet never once said "uff" to him or scolded him.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Kur\'ân\'da da "Sen elbette yüce bir ahlâk üzeresin" (Kalem 68/4) buyrulmuştur.',
      en: 'The Qur\'an affirms: "Indeed, you are of a great moral character" (68:4).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Peygamber Efendimiz (s.a.v.) aile fertlerine, hizmetkârlarına ve çocuklara karşı eşsiz bir şefkat, sabır ve nezaket timsali idi.',
        en: 'The Messenger of Allah (ﷺ) embodied unmatched gentleness, patience, and courtesy toward his household, helpers, and children.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Birr 69; Sahîh-i Müslim, Fezâil 51',
        en: 'Sunan at-Tirmidhi, Birr 69; Sahih Muslim, Fada\'il 51',
      ),
      linkedBookId: 'book_hadith_tirmizi',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_15',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['hicret'],
    stem: LocalizedText(
      tr: 'Hicret yolculuğunda Sevr Mağarası\'nda müşrikler mağara ağzına kadar geldiklerinde endişelenen Hz. Ebû Bekir\'e (r.a.) Resûlullah (s.a.v.) nasıl teselli vermiştir?',
      en: 'In the Cave of Thawr during the Hijrah, how did the Prophet (ﷺ) console Abu Bakr (r.a.) when pursuers reached the cave entrance?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: '"Üzülme, şüphesiz Allah bizimle beraberdir!"',
          en: '"Do not grieve; indeed Allah is with us!"',
        ),
        LocalizedText(
          tr: '"Hemen buradan başka bir şehre kaçalım"',
          en: '"Let us flee to another city immediately"',
        ),
        LocalizedText(
          tr: '"Kimseye bir şey söyleme, uyuyalım"',
          en: '"Say nothing and let us sleep"',
        ),
        LocalizedText(
          tr: '"Silahlarımızı kuşanıp saldıralım"',
          en: '"Draw swords and charge out"',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Bu ilâhî teselli Tevbe Sûresi 40. âyette ("Lâ tahzen innallâhe me\'anâ") ebedîleştirilmiştir.',
      en: 'Immortalized in Surah At-Tawbah 9:40 ("La tahzan innallaha ma\'ana").',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: '"Üçüncüleri Allah olan iki kişiyi ne zannedersin!" buyuran Efendimiz (s.a.v.) en dar anda bile tam bir tevekkül örneği göstermiştir.',
        en: 'Asking "What do you think of two whose third is Allah?", the Prophet (ﷺ) displayed supreme trust in Allah at the most perilous hour.',
      ),
      sourceRef: LocalizedText(
        tr: 'Tevbe Sûresi, 9/40; Sahîh-i Buhârî, Fezâilü Ashâbi\'n-Nebî 2',
        en: 'Surah At-Tawbah, 9:40; Sahih al-Bukhari, Fada\'il 2',
      ),
      linkedBookId: 'book_hadith_buhari',
      linkedZikirKey: 'Hasbünallahu ve ni\'mel vekil',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_16',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Siyer-i Nebî\'de öne çıkan önemli mekânları ve olayları doğru şekilde eşleştiriniz.',
      en: 'Match these pivotal landmarks in Prophetic history with the events associated with them.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hira Mağarası', en: 'Cave of Hira'),
          right: LocalizedText(tr: 'İlk vahyin gelişi', en: 'First revelation'),
        ),
        (
          left: LocalizedText(tr: 'Kubâ Mescidi', en: 'Masjid Quba'),
          right: LocalizedText(
            tr: 'İslâm tarihindeki ilk mescid',
            en: 'First mosque built in Islam',
          ),
        ),
        (
          left: LocalizedText(tr: 'Dârü\'l-Erkam', en: 'Dar al-Arqam'),
          right: LocalizedText(
            tr: 'Mekke\'de ilk irşad merkezi',
            en: 'Early teaching house in Makkah',
          ),
        ),
        (
          left: LocalizedText(tr: 'Suffe', en: 'As-Suffah'),
          right: LocalizedText(
            tr: 'Mescid-i Nebevî\'de ilim mektebi',
            en: 'Learning porch in Madinah',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Kubâ Mescidi takva üzere kurulan ilk mescid, Suffe ise Ebû Hüreyre gibi âlim sahâbîlerin yetiştiği yerdir.',
      en: 'Masjid Quba was founded upon piety upon reaching Madinah; As-Suffah trained scholars like Abu Hurayrah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Peygamber Efendimiz (s.a.v.) Medine\'ye ulaştığında ilk iş olarak mescid ve ilim yuvası inşa ederek toplumun kalbini ibadet ve irfan üzerine kurmuştur.',
        en: 'Upon arriving in Madinah, the Prophet (ﷺ) prioritized building mosques and learning circles, centering the community on worship and knowledge.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Menâkıbü\'l-Ensâr 45; Kur\'ân Yolu Tefsiri, Tevbe 9/108',
        en: 'Sahih al-Bukhari, Manaqib al-Ansar 45; Qur\'an Yolu, 9:108',
      ),
      linkedBookId: 'book_tafseer_kuran_yolu',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_17',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn\'de rivayet edilen hadislere göre, Hz. Peygamber (s.a.v.) Medine\'ye hicret ettiğinde halka ilk olarak hangi dört şeyi tavsiye etmiştir?',
      en: 'According to Riyad as-Salihin, what were among the very first greetings and counsels the Prophet (ﷺ) gave upon entering Madinah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Selâmı yayın, yemek yedirin, akrabalığı gözetin ve gece insanlar uyurken namaz kılın',
          en: 'Spread peace (salam), feed people, uphold family ties, and pray at night while people sleep',
        ),
        LocalizedText(
          tr: 'Sadece ticaret vergisi toplayın',
          en: 'Collect market tolls only',
        ),
        LocalizedText(
          tr: 'Komşularla konuşmayı kesin',
          en: 'Stop speaking with neighbors',
        ),
        LocalizedText(
          tr: 'Şehir surlarını yıkın',
          en: 'Demolish city walls',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Abdullah b. Selâm\'ın (r.a.) rivayet ettiği bu sözler "selâmetle cennete girersiniz" müjdesiyle biter.',
      en: 'Narrated by Abdullah ibn Salam (r.a.), ending with "you will enter Paradise in peace."',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Medine toplumunun temeli selâm (barış ve güven), cömertlik, sıla-i rahim ve gece teheccüdüyle atılmıştır.',
        en: 'Madinah\'s social harmony was built on spreading peace, feeding others, nurturing kinship, and sincere night devotion.',
      ),
      sourceRef: LocalizedText(
        tr: 'Riyâzü\'s-Sâlihîn, Selâm Babı; Sünen-i Tirmizî, Sıfatü\'l-Kıyâme 42',
        en: 'Riyad as-Salihin, Chapter on Salam; Sunan at-Tirmidhi, 2485',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_18',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    stem: LocalizedText(
      tr: 'Medine\'ye hicret eden Mekkeli Muhâcirler ile onlara kucak açan Medineli yerli müminler (Ensâr) arasında Peygamber Efendimiz (s.a.v.) nasıl bir bağ kurmuştur?',
      en: 'What bond did the Prophet (ﷺ) establish between the Makkan Migrants (Muhajirun) and the Madinan Helpers (Ansar)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Muâhât (Tarihte eşi görülmemiş İslâm kardeşliği)',
          en: 'Mu\'akhat (Unparalleled brotherhood pairing each migrant with a helper)',
        ),
        LocalizedText(
          tr: 'Sadece kira sözleşmesi',
          en: 'Merely a rental lease',
        ),
        LocalizedText(
          tr: 'Ayrı mahallelere zorunlu sürgün',
          en: 'Segregation into isolated districts',
        ),
        LocalizedText(
          tr: 'Yalnızca askerî nöbet çizelgesi',
          en: 'Only a guard roster',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Haşr Sûresi 9. âyet Ensâr\'ın bu fedakârlığını (îsâr) ebediyen över.',
      en: 'Surah Al-Hashr 59:9 eternally praises the Ansar\'s selflessness (ithar).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Ensâr, evlerini, bahçelerini ve rızıklarını Muhâcir kardeşleriyle bölüşerek İslâm ümmetinde fedakârlığın en yüksek örneğini sergilemiştir.',
        en: 'The Ansar shared homes and livelihoods with their Makkan brothers, setting an immortal example of altruism (ithar).',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Menâkıbü\'l-Ensâr 3; Haşr Sûresi, 59/9',
        en: 'Sahih al-Bukhari, Manaqib al-Ansar 3; Surah Al-Hashr, 59:9',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'siy_b_19',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.baslangic,
    specialDayTags: ['mirac', 'kandil'],
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim\'de bildirildiği üzere İsrâ ve Mi\'râc gecesinde Hz. Peygamber\'e (s.a.v.) ümmeti için üç büyük hediye verilmiştir; bunların başında günde beş vakit namaz ile Bakara Sûresi\'nin son iki âyeti ("Âmenerresûlü") gelir.',
      en: 'As narrated in Sahih Muslim, during the Night Journey and Ascension (Isra and Mi\'raj), the Prophet (ﷺ) was gifted the five daily prayers and the final two verses of Surah Al-Baqarah.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Üçüncü hediye ise Allah\'a şirk koşmayanların büyük günahlarının affedilme ümididir.',
      en: 'The third gift was hope of forgiveness for major sins for those who do not associate partners with Allah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Beş vakit namaz, müminin günde beş defa Rabbine yükseldiği mânevî bir mi\'râctır; Bakara\'nın son iki âyeti ise her gece okunması tavsiye edilen büyük bir sığınaktır.',
        en: 'The five daily prayers serve as a believer\'s spiritual ascension, while the closing verses of Al-Baqarah are a nightly shield of faith and supplication.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Îmân 279 (Hadis No: 173)',
        en: 'Sahih Muslim, Kitab al-Iman 279 (Hadith 173)',
      ),
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),

  // =========================================================================
  // ORTA (INTERMEDIATE) — 8 QUESTIONS (siy_o_12..siy_o_19)
  // =========================================================================
  IrfanQuestion(
    id: 'siy_o_12',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hendek (Ahzâb) Gazvesi öncesinde Medine\'nin etrafına savunma hendeği kazılması fikrini Peygamber Efendimiz\'e (s.a.v.) hangi sahâbî teklif etmiştir?',
      en: 'Before the Battle of the Trench (Khandaq), which Companion proposed digging a defensive trench around Madinah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Selmân-ı Fârisî (r.a.)', en: 'Salman al-Farisi (r.a.)'),
        LocalizedText(tr: 'Hâlid b. Velîd (r.a.)', en: 'Khalid ibn al-Walid (r.a.)'),
        LocalizedText(tr: 'Amr b. Âs (r.a.)', en: 'Amr ibn al-As (r.a.)'),
        LocalizedText(tr: 'Muâz b. Cebel (r.a.)', en: 'Mu\'adh ibn Jabal (r.a.)'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hakikati arayış yolculuğuyla meşhur İran asıllı sahâbîdir; Efendimiz "Selmân bizdendir, Ehl-i Beyt\'tendir" buyurmuştur.',
      en: 'The Persian seeker of truth whom the Prophet (ﷺ) honored as part of his household.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Resûlullah (s.a.v.) istişare sünnetiyle Selmân-ı Fârisî\'nin (r.a.) tecrübesine değer vermiş, kendisi de bizzat kazı çalışmasında ashâbıyla omuz omuza çalışmıştır.',
        en: 'Practicing mutual consultation (shura), the Prophet (ﷺ) adopted Salman\'s strategy and personally labored alongside the Companions digging the trench.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Megâzî 29; Kur\'ân Yolu Tefsiri, Ahzâb 33/9-25',
        en: 'Sahih al-Bukhari, Maghazi 29; Qur\'an Yolu, Al-Ahzab 33:9-25',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_13',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Mektubat\'taki On Dokuzuncu Mektup (Mu\'cizât-ı Ahmediye Risalesi), Hz. Peygamber\'in (s.a.v.) maddî mucizelerinin yanında bütün asırlara hitap eden en büyük ve bâki mucizesi olarak neyi gösterir?',
      en: 'In the Nineteenth Letter (Miracles of Muhammad) of Mektubat, what is presented as the Prophet\'s greatest, living miracle addressing all centuries?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Kur\'ân-ı Hakîm', en: 'The Noble Qur\'an'),
        LocalizedText(tr: 'Yalnızca şahsî mektupları', en: 'Private letters alone'),
        LocalizedText(tr: 'Sadece kervan yolları', en: 'Caravan routes only'),
        LocalizedText(tr: 'Eski şairlerin kasideleri', en: 'Pre-Islamic odes'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Hem Sahîh-i Buhârî\'de hem de 19. Mektup\'ta her asırda okunan ebedî vahiy mucizesi olarak anılır.',
      en: 'Confirmed in Sahih al-Bukhari and the 19th Letter as the everlasting miracle of revelation.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Geçmiş peygamberlerin mucizeleri kendi zamanlarına mahsus iken, Resûl-i Ekrem\'in (s.a.v.) en büyük mucizesi olan Kur\'ân-ı Kerîm kıyamete kadar her asra doğrudan hitap eden daimî bir bürhandır.',
        en: 'While earlier prophets\' physical miracles were bound to their eras, the Qur\'an remains a living miracle speaking directly to every generation.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Mektubat, 19. Mektup; Sahîh-i Buhârî, Fedâilü\'l-Kur\'ân 1',
        en: 'Risale-i Nur Collection, The Letters (Mektubat), 19th Letter; Bukhari',
      ),
      linkedBookId: 'book_rn_mektubat',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_14',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hicretin 6. yılında imzalanan ve görünürde ağır maddeler taşısa da Kur\'ân tarafından "Feth-i Mübîn" (apaçık fetih) olarak müjdelenen antlaşma hangisidir?',
      en: 'Which treaty signed in the 6th year of Hijrah appeared demanding in its clauses yet was heralded by the Qur\'an as a "Clear Victory" (Fath Mubin)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(tr: 'Hudeybiye Antlaşması', en: 'Treaty of Hudaybiyyah'),
        LocalizedText(tr: 'Akabe Biatı', en: 'Pledge of Aqabah'),
        LocalizedText(tr: 'Medine Vesikası', en: 'Charter of Madinah'),
        LocalizedText(tr: 'Hilfü\'l-Fudûl', en: 'Hilf al-Fudul'),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Dönüş yolunda Fetih Sûresi nâzil olmuş ve sonraki iki yılda İslâm\'a girenlerin sayısı katlanmıştır.',
      en: 'Surah Al-Fath was revealed on the return journey, and peace opened the hearts of thousands to Islam.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hudeybiye barış ortamı sayesinde kabileler İslâm\'ı serbestçe tanıma imkânı bulmuş, Mekke\'nin kansız fethine giden yol açılmıştır.',
        en: 'The peace of Hudaybiyyah allowed tribes across Arabia to examine Islam freely, paving the way for the peaceful opening of Makkah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Şürût 15; Kur\'ân Yolu Tefsiri, Fetih 48/1',
        en: 'Sahih al-Bukhari, Shurut 15; Qur\'an Yolu, Al-Fath 48:1',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_15',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Buhârî\'de anlatıldığına göre, Mekke\'nin Fethi günü Kâbe avlusunda toplanan eski düşmanlarına Hz. Peygamber (s.a.v.) "Size bugün kınama yok, gidin hepiniz serbestsiniz!" diyerek genel af ilan etmiştir.',
      en: 'As narrated in Sahih al-Bukhari and Muslim, on the day Makkah opened, the Prophet (ﷺ) forgave his former persecutors, declaring: "No blame upon you today; go, for you are free!"',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'Hz. Yûsuf\'un (a.s.) kardeşlerine söylediği "Lâ tesrîbe aleykümü\'l-yevm" (Yûsuf 12/92) sözünü tekrarlamıştır.',
      en: 'He echoed the words of Prophet Yusuf (a.s.) to his brothers in Surah Yusuf 12:92.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Güç ve zafer zirvesindeyken intikam yerine merhameti tercih etmesi, bütün Mekke halkının gönlünü İslâm\'a açmıştır.',
        en: 'Choosing clemency at the pinnacle of victory rather than retaliation transformed former foes into devoted believers.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Cihâd 84; Kur\'ân Yolu Tefsiri, Nasr 110/1-3',
        en: 'Sahih Muslim, Jihad 84; Qur\'an Yolu, An-Nasr 110:1-3',
      ),
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'El-Afuvv',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_16',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Aşere-i Mübeşşere ve öne çıkan sahâbîlerin meşhur unvanlarını doğru şekilde eşleştiriniz.',
      en: 'Match these eminent Companions with their well-known titles in Prophetic history.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Hz. Ebû Bekir (r.a.)', en: 'Abu Bakr (r.a.)'),
          right: LocalizedText(tr: 'Es-Sıddîk', en: 'As-Siddiq (The Truthful)'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Ömer (r.a.)', en: 'Umar (r.a.)'),
          right: LocalizedText(tr: 'El-Fârûk', en: 'Al-Faruq (Distinguisher)'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Osman (r.a.)', en: 'Uthman (r.a.)'),
          right: LocalizedText(tr: 'Zinnûreyn', en: 'Dhun-Nurayn (Two Lights)'),
        ),
        (
          left: LocalizedText(tr: 'Hz. Ali (r.a.)', en: 'Ali (r.a.)'),
          right: LocalizedText(
            tr: 'Esedullâh / Haydar-ı Kerrâr',
            en: 'Asadullah (Lion of Allah)',
          ),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Dört Râşid Halife\'nin sırasıyla sahip oldukları meşhur unvanlardır.',
      en: 'These are the classic titles of the Four Rightly Guided Caliphs.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Her bir sahâbî sıdk, adalet, hayâ ve ilim-şecaat gibi yüksek vasıflarıyla ümmete canlı birer örnek olmuştur.',
        en: 'Each Companion exemplified a distinct virtue—truthfulness, justice, modesty, and wisdom-courage—for generations to follow.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Menâkıb 16-20; Sahîh-i Buhârî, Fezâilü Ashâbi\'n-Nebî',
        en: 'Sunan at-Tirmidhi, Manaqib 16-20; Sahih al-Bukhari',
      ),
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_17',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Hüzün Yılı\'nın ardından Tâif yolculuğunda taşlanıp yaralandığı hâlde Peygamber Efendimiz (s.a.v.) dağlar meleğinin helâk teklifini neden reddetmiştir?',
      en: 'After being pelted and wounded at Ta\'if during the Year of Sorrow, why did the Prophet (ﷺ) decline the Angel of the Mountains\' offer to crush the town?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Onların neslinden yalnız Allah\'a kulluk edecek müminlerin çıkmasını umduğu için',
          en: 'Hoping Allah would bring forth from their descendants people who worship Allah alone',
        ),
        LocalizedText(
          tr: 'Mekke\'ye daha hızlı dönmek istediği için',
          en: 'To hurry back to Makkah',
        ),
        LocalizedText(
          tr: 'Tâif bahçelerini satın almak için',
          en: 'To purchase orchards in Ta\'if',
        ),
        LocalizedText(
          tr: 'Hiçbir melek görmediği için',
          en: 'Because no angel spoke to him',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Enbiya Sûresi 107. âyette bildirildiği gibi o "âlemlere rahmet" olarak gönderilmiştir.',
      en: 'He was sent strictly as a mercy to all worlds (Surah Al-Anbiya 21:107).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Sahîh-i Buhârî ve Müslim\'de anlatılan Tâif hâdisesi, Efendimizin (s.a.v.) şahsî eziyeti affedip hidayet duası eden engin rahmet kalbini gösterir.',
        en: 'Narrated in Sahih al-Bukhari and Muslim, the Ta\'if incident reveals the Prophet\'s boundless compassion, praying for guidance even under injury.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Bed\'ü\'l-halk 7; Sahîh-i Müslim, Cihâd 111',
        en: 'Sahih al-Bukhari, Bad\' al-Khalq 7; Sahih Muslim, Jihad 111',
      ),
      linkedBookId: 'book_hadith_muslim',
      linkedZikirKey: 'Er-Raûf',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_18',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Sünen-i Ebû Dâvûd ve Müslim\'de geçen Veda Hutbesi\'nde Peygamber Efendimiz (s.a.v.) insanların can, mal ve ırzlarının hangi gün ve mekân gibi dokunulmaz (haram) olduğunu ilan etmiştir?',
      en: 'In the Farewell Sermon (reported in Sahih Muslim and Abu Dawud), to what did the Prophet (ﷺ) compare the sanctity of every person\'s life, property, and honor?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Arefe günü, Zilhicce ayı ve Mekke (Harem) beldesinin kutsallığı gibi',
          en: 'The sanctity of the Day of Arafah, the sacred month of Dhul-Hijjah, and the sanctuary of Makkah',
        ),
        LocalizedText(
          tr: 'Yalnızca ticaret kervanlarının sözleşmesi gibi',
          en: 'Only commercial caravan contracts',
        ),
        LocalizedText(
          tr: 'Sadece savaş ganimetleri gibi',
          en: 'Only war spoils',
        ),
        LocalizedText(
          tr: 'Geçici bir kabile ateşkesi gibi',
          en: 'A temporary tribal truce',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Aynı hutbede üstünlüğün ırk veya renkte değil yalnız takvada olduğu vurgulanmıştır.',
      en: 'The same sermon proclaimed that superiority lies not in race or lineage, but solely in God-consciousness (taqwa).',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Veda Hutbesi, insan haklarını, kan davalarının ve faizin kaldırılışını, kadınların haklarını ve ümmete Kur\'ân ile Sünnet emanetini ilan eden evrensel bir beyannamedir.',
        en: 'The Farewell Sermon stands as a timeless charter upholding human dignity, women\'s rights, social justice, and adherence to the Qur\'an and Sunnah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Müslim, Hac 147; Sünen-i Ebû Dâvûd, Menâsik 56',
        en: 'Sahih Muslim, Hajj 147; Sunan Abi Dawud, Manasik 56',
      ),
      linkedBookId: 'book_hadith_ebu_davud',
    ),
  ),
  IrfanQuestion(
    id: 'siy_o_19',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.orta,
    stem: LocalizedText(
      tr: 'Gençlik Rehberi ve Hanımlar Rehberi\'ne göre Asr-ı Saadet\'ten günümüze gençliğin en büyük sermayesini koruyan temel erdem nedir?',
      en: 'According to Gençlik Rehberi and Hanımlar Rehberi, what core virtue preserves the priceless capital of youth following the Prophetic model?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İffet, istikamet, meşru dairede hayat ve namazla Rabbine bağlılık',
          en: 'Chastity, uprightness, living within lawful bounds, and steadfastness in prayer',
        ),
        LocalizedText(
          tr: 'Sorumsuzluk içinde vakit geçirmek',
          en: 'Spending youth heedlessly',
        ),
        LocalizedText(
          tr: 'İlim ve sanattan tamamen uzaklaşmak',
          en: 'Abandoning all learning',
        ),
        LocalizedText(
          tr: 'Dünya nimetlerini bütünüyle inkâr etmek',
          en: 'Denying lawful blessings',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Gençlik Rehberi\'nde meşru dairedeki lezzetin keyfe kâfi geldiği, haram dairede ise elemlerin gizli olduğu vurgulanır.',
      en: 'Gençlik Rehberi teaches that lawful joy suffices while unlawful excess breeds hidden sorrow.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Gençlik nimetini istikamette ve hayırlı hizmetlerde değerlendiren mümin, fânî gençliği ebedî bir saadet vesilesine dönüştürür.',
        en: 'Directing the energy of youth toward integrity, chastity, and good deeds turns a fleeting season into eternal gain.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Gençlik Rehberi',
        en: 'Risale-i Nur Collection, Guide for Youth (Gençlik Rehberi)',
      ),
      linkedBookId: 'book_rn_genclik_rehberi',
    ),
  ),

  // =========================================================================
  // İRFAN (MASTERY) — 8 QUESTIONS (siy_i_12..siy_i_19)
  // =========================================================================
  IrfanQuestion(
    id: 'siy_i_12',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'İhlâs ve Uhuvvet Risaleleri içinde yer alan On Birinci Lem\'a\'ya (Mirkatü\'s-Sünne) göre Sünnet-i Seniyye\'ye uymanın en yüksek ve ehemmiyetli mertebeleri nelerdir?',
      en: 'According to the Eleventh Flash (Mirqat as-Sunnah) in İhlâs ve Uhuvvet Risaleleri, what are the essential realms of following the Prophetic Sunnah?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'İtikadî, ibadet (farz/nâfile) ve ahlâkî/muamelât meselelerinde Resûlullah\'ın (s.a.v.) sünnetini hayat ölçüsü edinmek',
          en: 'Adopting the Prophet\'s (ﷺ) pattern across creed, worship, noble character, and daily etiquette',
        ),
        LocalizedText(
          tr: 'Yalnızca Arapça hutbe dinlemekle yetinmek',
          en: 'Limiting Sunnah solely to listening to sermons',
        ),
        LocalizedText(
          tr: 'Sadece savaş tarihini ezberlemek',
          en: 'Memorizing battle dates alone',
        ),
        LocalizedText(
          tr: 'Sünneti yalnızca kıyafete indirgemek',
          en: 'Reducing Sunnah solely to outer dress',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: '11. Lem\'a "Bütün âdâtını ibadete çevirmek" sırrının Sünnet-i Seniyye\'ye ittibada olduğunu açıklar.',
      en: 'The 11th Flash explains how following the Sunnah elevates daily habits into conscious worship.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Yeme-içmeden selâm vermeye kadar sıradan âdetlerini bile Sünnet niyetiyle yapan mümin, ömrünün her dakikasını şuurlu bir ibadete çevirir.',
        en: 'Observing even everyday habits with intention to follow the Prophet (ﷺ) transforms ordinary moments into worship.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, İhlâs ve Uhuvvet Risaleleri (11. Lem\'a)',
        en: 'Risale-i Nur Collection, Treatise on Sincerity & Brotherhood (11th Flash)',
      ),
      linkedBookId: 'book_rn_ihlas_uhuvvet',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_13',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    specialDayTags: ['mirac', 'kandil'],
    stem: LocalizedText(
      tr: 'Mi\'rac ve Kader Risalesi\'nde (31. Söz) Mi\'râc-ı Nebevî\'nin hikmeti açıklanırken, Hz. Peygamber\'in (s.a.v.) bütün mahlûkat nâmına Cenâb-ı Hakk\'ın huzuruna çıkması hangi iki sıfatın (velâyet ve risâlet) buluşmasıdır?',
      en: 'In the Treatise on Mi\'raj (31st Word), the Prophet\'s (ﷺ) ascension to the divine presence on behalf of all creation unites which two prophetic dimensions?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Külli ubûdiyetle Hak\'ka gidiş (velâyet-i kübrâ) ve kullara ilâhî ahkâmı getiriş (risâlet)',
          en: 'Universal servitude ascending to Allah (supreme sainthood) and descending with divine revelation for humanity (messengership)',
        ),
        LocalizedText(
          tr: 'Yalnızca siyaset ve ticaret',
          en: 'Only politics and trade',
        ),
        LocalizedText(
          tr: 'Şiir ve astronomi',
          en: 'Poetry and astronomy',
        ),
        LocalizedText(
          tr: 'Sadece sefer ve ikamet hukuku',
          en: 'Only travel law',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Birinci Esas ve İkinci Esas\'ta gidiş (seyr-i urûcî) ubûdiyet, dönüş (seyr-i nüzûlî) ise risâlet vazifesi olarak izah edilir.',
      en: 'The ascent reflects pure servitude; the return manifests messengership bringing prayer and wisdom.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Mi\'râc, kâinatın meyvesi olan Resûlullah\'ın (s.a.v.) tüm varlık adına yaratıcısına şükran ve tesbihatını arz edip, ümmetine namaz ve iman hakikatlerini armağan getirmesidir.',
        en: 'Mi\'raj represents the pinnacle of creation offering universal worship to Allah and returning with the gifts of Salah and certainty.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Mi\'rac ve Kader Risalesi (31. Söz)',
        en: 'Risale-i Nur Collection, Treatise on Mi\'raj & Destiny (31st Word)',
      ),
      linkedBookId: 'book_rn_mirac_kader',
      linkedZikirKey: 'Subhanallah',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_14',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî ve Müslim\'de geçen "El-Mü\'minü\'l-Kavî" ve "Şefkat-i Nebeviyye" ilkeleri ışığında, Peygamber Efendimiz\'in (s.a.v.) ümmeti arasındaki ihtilafları ve küskünlükleri gidermek için kurduğu temel kural nedir?',
      en: 'In Sahih al-Bukhari and Sahih Muslim, what strict rule did the Prophet (ﷺ) set to heal estrangement and disputes among believers?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Bir Müslümanın din kardeşiyle üç günden fazla küs kalması helâl değildir; ilk selâm veren en hayırlıdır',
          en: 'It is unlawful for a Muslim to shun a fellow believer for more than three days; the better of the two initiates salam first',
        ),
        LocalizedText(
          tr: 'Haklı olan taraf ömür boyu konuşmamalıdır',
          en: 'The wronged party should never speak again',
        ),
        LocalizedText(
          tr: 'Kardeşlik sadece aynı kabileden olanlar içindir',
          en: 'Brotherhood applies only within one tribe',
        ),
        LocalizedText(
          tr: 'Barışmak için bir yıl beklenmelidir',
          en: 'Reconciliation must wait one full year',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Riyâzü\'s-Sâlihîn\'de de "Hicran / Küsmenin Yasaklanması" babında müstakil başlık taşır.',
      en: 'Featured prominently in Riyad as-Salihin\'s chapter forbidding prolonged estrangement.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Üç günlük sınır insan fıtratındaki öfke kabarmasının dinmesine tanınan makul süredir; ardından barış kapısını ilk aralayan en faziletli kul olur.',
        en: 'The three-day limit allows initial anger to cool, after which taking the first step toward reconciliation is a mark of spiritual nobility.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Edeb 62; Riyâzü\'s-Sâlihîn, Hadis No: 1591',
        en: 'Sahih al-Bukhari, Adab 62; Riyad as-Salihin, Hadith 1591',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_15',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Hutbe-i Şâmiye\'de Bediüzzaman Said Nursî\'nin 1911 yılında Şam Emeviye Camii\'nde İslâm dünyasının terakkîsi için sunduğu altı ilacı (kelimeyi) karşılıklarıyla eşleştiriniz.',
      en: 'Match the spiritual remedies presented in the Damascus Sermon (Hutbe-i Şâmiye) for the revival of the Muslim community.',
    ),
    payload: MatchingPayload(
      pairs: [
        (
          left: LocalizedText(tr: 'Ye\'se karşı', en: 'Against Despair'),
          right: LocalizedText(tr: 'Emel ve ümit', en: 'Hope in Allah\'s mercy'),
        ),
        (
          left: LocalizedText(tr: 'Kizbe karşı', en: 'Against Falsehood'),
          right: LocalizedText(tr: 'Sıdk (doğruluk)', en: 'Truthfulness (Sidq)'),
        ),
        (
          left: LocalizedText(tr: 'Adâvete karşı', en: 'Against Enmity'),
          right: LocalizedText(tr: 'Muhabbet', en: 'Brotherly Love'),
        ),
        (
          left: LocalizedText(tr: 'İstibdada karşı', en: 'Against Despotism'),
          right: LocalizedText(tr: 'Meşveret ve şûrâ', en: 'Consultation (Shura)'),
        ),
      ],
    ),
    hint: LocalizedText(
      tr: 'Hutbe-i Şâmiye\'de ümitsizlik, yalan, düşmanlık, tefrika ve istibdada karşı altı Kur\'ânî çare sayılır.',
      en: 'The Damascus Sermon diagnoses six social maladies and pairs each with a Qur\'anic remedy.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Doğruluk, ümit, muhabbet ve meşveret Asr-ı Saadet\'in toplumsal diriliş şifreleridir; her asırda ümmetin birliğini bu değerler inşa eder.',
        en: 'Truthfulness, hope, love, and consultation formed the social backbone of the Era of Bliss and remain timeless pillars of unity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Hutbe-i Şâmiye',
        en: 'Risale-i Nur Collection, The Damascus Sermon (Hutbe-i Şâmiye)',
      ),
      linkedBookId: 'book_rn_hutbe_munazarat',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_16',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahîh-i Müslim ve Tirmizî\'de "Ashâbım hakkında Allah\'tan korkun; onları benden sonra hedef edinmeyin" uyarısı hangi temel Ehl-i Sünnet edebinı öğretir?',
      en: 'In Sunan at-Tirmidhi and Sahih Muslim, the Prophet\'s (ﷺ) warning "Fear Allah regarding my Companions; do not make them targets after me" teaches what foundational Islamic etiquette?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Sahâbenin tamamına hürmet ve hayırla yâd etmek, içtihat ihtilaflarında hüsn-i zan ve edep korumak',
          en: 'Honoring all Companions with respect, remembering them well, and keeping dignified restraint regarding historical trials',
        ),
        LocalizedText(
          tr: 'Sadece iki sahâbî dışındakileri reddetmek',
          en: 'Rejecting all except two Companions',
        ),
        LocalizedText(
          tr: 'Hadis rivayetlerini tamamen bırakmak',
          en: 'Abandoning hadith narration entirely',
        ),
        LocalizedText(
          tr: 'Tarih kitaplarını okumayı yasaklamak',
          en: 'Forbidding historical study',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Tevbe 100 ve Haşr 10 âyetleri de Muhâcir ve Ensâr\'a rahmet ve mağfiret duası etmeyi öğretir.',
      en: 'Surah At-Tawbah 9:100 and Al-Hashr 59:10 instruct praying for forgiveness and mercy for earlier believers.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Kur\'ân ve Sünnet\'i bize ulaştıran ilk nesil Ashâb-ı Kirâm\'dır; onlara hürmet ve dua, müminin kalbî selâmetinin gereğidir.',
        en: 'The Companions carried the Qur\'an and Sunnah to us; respecting and supplicating for them safeguards spiritual integrity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sünen-i Tirmizî, Menâkıb 58; Haşr Sûresi, 59/10',
        en: 'Sunan at-Tirmidhi, Manaqib 58; Surah Al-Hashr, 59:10',
      ),
      linkedBookId: 'book_hadith_tirmizi',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_17',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sahîh-i Buhârî\'de "Peygamber Efendimiz (s.a.v.) insanların en cömerdi idi; özellikle Ramazan ayında Cebrâil (a.s.) ile buluşup Kur\'ân\'ı mukabele ettiklerinde esen bereket rüzgârından daha cömert olurdu" diye anlatılır.',
      en: 'Sahih al-Bukhari describes that the Prophet (ﷺ) was the most generous of people, and became even more generous during Ramadan when meeting Jibril (a.s.) to review the Qur\'an.',
    ),
    payload: TrueFalsePayload(correctAnswer: true),
    hint: LocalizedText(
      tr: 'İbn Abbâs\'ın (r.a.) rivayet ettiği bu hadis hem cömertliğin hem de mukabele sünnetinin temel delilidir.',
      en: 'Narrated by Ibn Abbas (r.a.), this is the classical proof for both Ramadan generosity and Mukabalah.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Vahiy ile temas arttıkça kalpteki cömertlik ve infak şevki de çoğalır; Ramazan mukabeleleri bu nebevî sünnetin yaşayan hatırasıdır.',
        en: 'Intimacy with the Qur\'an nurtures generosity; Ramadan Qur\'an recitations (Mukabalah) preserve this living Prophetic tradition.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Bed\'ü\'l-vahy 5 & Savm 7',
        en: 'Sahih al-Bukhari, Bad\' al-Wahy 5 & Sawm 7',
      ),
      linkedBookId: 'book_hadith_buhari',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_18',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'Sünen-i Nesâî ve Buhârî\'de geçen "Ben ve yetimi himaye eden kimse cennette şöyle yan yana olacağız" hadisinde Resûlullah (s.a.v.) hangi iki parmağını birbirine yaklaştırarak işaret etmiştir?',
      en: 'In Sahih al-Bukhari and Sunan an-Nasa\'i, while declaring "I and the guardian of an orphan will be in Paradise like these two," which fingers did the Prophet (ﷺ) hold close together?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Şahadet (işaret) parmağı ile orta parmağını',
          en: 'His index finger and middle finger',
        ),
        LocalizedText(
          tr: 'İki elinin başparmaklarını',
          en: 'Both thumbs only',
        ),
        LocalizedText(
          tr: 'Serçe parmağı ile başparmağını',
          en: 'Pinky and thumb',
        ),
        LocalizedText(
          tr: 'Beş parmağını yumruk yaparak',
          en: 'Closing all five fingers into a fist',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Sehl b. Sa\'d (r.a.) rivayetinde aralarını hafifçe açarak bu iki parmağı göstermiştir.',
      en: 'Narrated by Sahl ibn Sa\'d (r.a.), signaling close companionship in Paradise.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Yetim olarak büyüyen Peygamber Efendimiz (s.a.v.), kimsesiz ve muhtaçlara sahip çıkmanın cennette kendine komşuluk kazandıran bir iyilik olduğunu müjdelemiştir.',
        en: 'Having grown up as an orphan himself, the Prophet (ﷺ) promised close companionship in Paradise to those who care for orphans with dignity.',
      ),
      sourceRef: LocalizedText(
        tr: 'Sahîh-i Buhârî, Talâk 25 & Edeb 24; Riyâzü\'s-Sâlihîn',
        en: 'Sahih al-Bukhari, Talaq 25 & Adab 24; Riyad as-Salihin',
      ),
      linkedBookId: 'book_hadith_riyazus_salihin',
    ),
  ),
  IrfanQuestion(
    id: 'siy_i_19',
    topic: IrfanTopic.siyer,
    tier: IrfanTier.irfan,
    stem: LocalizedText(
      tr: 'İhtiyarlar Risalesi (26. Lem\'a) ve Mektubat\'ta Hz. Peygamber\'in (s.a.v.) "el-Habîbullâh" unvanıyla vasıflandırılmasının en derin hikmeti olarak ne vurgulanır?',
      en: 'In Mektubat and İhtiyarlar Risalesi, what is highlighted as the deepest wisdom behind the Prophet\'s (ﷺ) title "Habibullah" (Beloved of Allah)?',
    ),
    payload: MultipleChoicePayload(
      options: [
        LocalizedText(
          tr: 'Hem Hâlık\'ın en mükemmel sanatı ve rahmet elçisi olması hem de bütün mahlûkatın sevgisini ve tesbihini Rabbine takdim etmesi',
          en: 'Both serving as the supreme messenger of Allah\'s mercy and representing all creation in love, praise, and servitude to the Creator',
        ),
        LocalizedText(
          tr: 'Yalnızca dünya saltanatı kurması',
          en: 'Establishing an earthly empire alone',
        ),
        LocalizedText(
          tr: 'Sadece Mekke\'de yaşamış olması',
          en: 'Residing only in Makkah',
        ),
        LocalizedText(
          tr: 'Hiçbir imtihan görmemesi',
          en: 'Facing no trials at all',
        ),
      ],
      correctIndex: 0,
    ),
    hint: LocalizedText(
      tr: 'Kâinatın yaratılış gayesi ve Allah\'ın esmâsına en câmi ayna olma hakikati 19. Mektup\'ta işlenir.',
      en: 'Explored in the 19th Letter on how the Prophet (ﷺ) mirrors Allah\'s Names and unites creation in praise.',
    ),
    hikmet: IrfanHikmetCard(
      explanation: LocalizedText(
        tr: 'Hz. Muhammed (s.a.v.), kâinattaki ilâhî hikmet ve rahmeti insanlığa tercüme eden en yüksek rehber ve kulluğun zirvesidir.',
        en: 'Prophet Muhammad (ﷺ) is the supreme guide translating cosmic wisdom to humanity and exemplifying loving servitude to Allah.',
      ),
      sourceRef: LocalizedText(
        tr: 'Risale-i Nur Külliyatı, Mektubat, 19. Mektup; 26. Lem\'a',
        en: 'Risale-i Nur Collection, Mektubat (19th Letter); 26th Flash',
      ),
      linkedBookId: 'book_rn_mektubat',
      linkedZikirKey: 'Salavat-ı Şerif',
    ),
  ),
];
