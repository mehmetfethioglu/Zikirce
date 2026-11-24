import '../domain/speed_reading_models.dart';

/// Superead tarzı 21 Günlük Müfredat, 5 Bilişsel Teknik Rehberi ve Zengin Metin + Anlama Soruları Havuzu
class SpeedReadingCurriculumCorpus {
  const SpeedReadingCurriculumCorpus._();

  /// Hızlı Okuma Tekniklerini Öğreten 5 Temel Mikro-Ders Rehberi
  static const List<SpeedReadingTechniqueGuide> techniqueGuides = [
    SpeedReadingTechniqueGuide(
      id: 'subvocalization',
      title: '1. İçsesi (Subvocalization) Susturma',
      badge: 'Darboğaz: 150–220 WPM',
      bottleneckProblem:
          'Ortalama bir okur, okuduğu her kelimeyi zihninde içinden seslendirir (fonolojik döngü). İnsan konuşma hızı dakikada 150–220 kelime ile sınırlı olduğundan, içses sürdüğü müddetçe okuma hızı bu barajı aşamaz.',
      scientificSolution:
          'Göz ve görsel korteks, kelimeleri sese dönüştürmeden doğrudan semantik (anlamsal) kavram olarak işleyebilir. Akış hızını 320+ WPM üzerine çıkarmak ve kelime öbeklerine odaklanmak fonolojik döngüyü devre dışı bırakır.',
      actionableSteps: [
        'RSVP + ORP modunda hızı normal okuma hızınızın %35 üzerine (örn. 350 WPM) ayarlayın.',
        'Dil ve dudak kıpırdatmayı tamamen bırakın; kelimeleri duymaya değil, "görmeye" odaklanın.',
        'Uzun cümlelerde bağlaç ve edatları seslendirmeden anahtar isim ve fiil köklerini yakalayın.',
      ],
      recommendedExercise: SpeedReadingExerciseType.rsvpOrp,
    ),
    SpeedReadingTechniqueGuide(
      id: 'peripheral_span',
      title: '2. Parafoveal (Çevresel) Görüşü Genişletme',
      badge: 'Hedef: Tek Bakışta 3–4 Kelime',
      bottleneckProblem:
          'Dar odakla (tünel görüşü) okuyan bir göz, satır boyunca her kelimede ayrı ayrı duraksar (8–10 fiksasyon/satır). Her sıçrama ve duraksama yaklaşık 250 milisaniye kaybettirir.',
      scientificSolution:
          'Merkezî (foveal) odak sabitken çevresel (parafoveal) görüş açısını yatay ve dikey genişleterek, bir satırı yalnızca 2 veya 3 odak noktasında fotoğraflamak mümkündür.',
      actionableSteps: [
        'Schulte Tablosunda gözünüzü yalnızca merkezdeki kırmızı noktaya sabitleyin.',
        'Göz bebeğinizi gezdirmeden, kenar görüşünüzle 1’den 25’e kadar tüm sayıları sırayla bulun.',
        'Kitap okurken satırın ilk ve son kelimesine değil, içeriden 2. kelimeye odaklanarak başlayın.',
      ],
      recommendedExercise: SpeedReadingExerciseType.schulteGrid,
    ),
    SpeedReadingTechniqueGuide(
      id: 'anti_regression',
      title: '3. Regresyonu (Geriye Dönüşü) Önleme',
      badge: 'Zaman Kaybı: %30',
      bottleneckProblem:
          'Okurların %80’i farkında olmadan okudukları kelimeye veya bir üst satıra geri döner (regresyon). Bu alışkanlık okuma süresinin %30’unu boşa harcar ve anlam bütünlüğünü parçalar.',
      scientificSolution:
          'Sabit tempolu bir görsel kılavuz (Pacer / Spotlight) ve okunmuş satırları karartan maskeleme kullanmak, beyni geriye dönmek yerine ileriye odaklanmaya mecbur bırakır.',
      actionableSteps: [
        'Blok & Gölgeleme (Pacer) modunda "Okunan Satırları Karart" seçeneğini aktif tutun.',
        'Kaçırdığınızı düşündüğünüz tek bir kelime için asla durmayın; cümlenin devamı anlamı tamamlar.',
        'Tahrir Okuyucu ekranında "Odak Cetveli" veya "Canlı Pacer" ile sabit ritim koruyun.',
      ],
      recommendedExercise: SpeedReadingExerciseType.chunkPacer,
    ),
    SpeedReadingTechniqueGuide(
      id: 'fixation_speed',
      title: '4. Fiksasyon Süresini Kısaltma (Takistoskop)',
      badge: 'Hedef: < 100 ms Algı',
      bottleneckProblem:
          'Eğitimsiz bir göz bir kelime üzerinde ortalama 240–300 ms duraksar. Oysa insan retinası ve görsel korteksi bir kelime öbeğini 50 ms (saniyenin yirmide biri) içinde tanıyabilir.',
      scientificSolution:
          'Takistoskop (milisaniyelik flaş gösterim) antrenmanı, gözün "tembel duraksama" alışkanlığını kırar ve beynin anlık görüntü işleme hızını kalıcı olarak yükseltir.',
      actionableSteps: [
        'Takistoskop modunda 150 ms ve tek kelime ile başlayıp 50 ms ve 3’lü kelime öbeğine inin.',
        'Kelime flaşlandığı anda harfleri tek tek okumaya çalışmayın; kelimenin bütünsel silüetini yakalayın.',
        'Her gün 3 dakika flaş algı antrenmanı yaparak görsel refleks eşiğinizi düşürün.',
      ],
      recommendedExercise: SpeedReadingExerciseType.tachistoscope,
    ),
    SpeedReadingTechniqueGuide(
      id: 'saccadic_return_sweep',
      title: '5. Sakkadik Çeviklik & Satır Dönüşü (Return Sweep)',
      badge: '60 FPS Göz Kasları',
      bottleneckProblem:
          'Satır sonundan alt satırın başına geçerken (return sweep) gözlerin hedefi şaşırması veya aynı satırı tekrar okuması, uzun metinlerde ciddi göz yorgunluğu ve hız düşüşü yaratır.',
      scientificSolution:
          'Altı ekstraoküler göz kasını yatay, dikey, çapraz (zikzak) ve sonsuzluk (∞) rotalarında ısıtmak, sakkadik sıçrama doğruluğunu ve okuma dayanıklılığını artırır.',
      actionableSteps: [
        'Okuma seansından önce 2 dakika Sakkadik Göz Kasları Antrenöründe Zikzak ve Sonsuzluk rotalarını çalıştırın.',
        'Başınızı hiç hareket ettirmeden yalnızca göz kürelerinizle hedefi takip edin.',
        'Seviye hızını kademeli olarak 3’ten 8’e çıkararak göz kası esnekliğini pekiştirin.',
      ],
      recommendedExercise: SpeedReadingExerciseType.saccadicEye,
    ),
    SpeedReadingTechniqueGuide(
      id: 'overspeed_adaptation',
      title: '6. 2x Otoyol Etkisi & Aşırı Hız Adaptasyonu',
      badge: 'Nöral Kalibrasyon: 1.5x–2.0x',
      bottleneckProblem:
          'Beyin her zaman alıştığı konfor hızında (ör. 220 WPM) kalma eğilimindedir; sabit hızla yapılan egzersizlerde zihin kısa sürede eski temposuna geri döner.',
      scientificSolution:
          'Otoyolda 140 km/s hızla gittikten sonra 90 km/s hızın çok yavaş hissedilmesi gibi, 40 saniye boyunca 1.5x ve 2.0x aşırı hızda (Over-Speed) görsel akışa maruz kalan görsel korteks, sonrasında 1.35x hızı yeni "rahat konfor hızı" olarak benimser.',
      actionableSteps: [
        '2x Aşırı Hız Sprinti modunda baz hızınızı mevcut okuma hızınıza ayarlayın.',
        'Turbo (1.5x) ve Hiper (2.0x) fazlarında her kelimeyi anlamaya çalışmayın; gözünüzü akışta tutun.',
        '4. fazda hız 1.35x seviyesine indiğinde metnin ne kadar berrak ve yavaş aktığını deneyimleyin.',
      ],
      recommendedExercise: SpeedReadingExerciseType.overSpeedSprint,
    ),
    SpeedReadingTechniqueGuide(
      id: 'peripheral_pyramid_span',
      title: '7. Çevresel Görüş Piramidi & Kanat Okuma',
      badge: 'Yatay Açıklık: 2.5x Genişleme',
      bottleneckProblem:
          'Göz sadece baktığı noktadaki tek kelimeyi okuyup sağ ve sol kanattaki kelimeleri göremediğinde, her satırda 8–10 kez duraksamak zorunda kalır.',
      scientificSolution:
          'Merkezdeki dikey odak çizgisinden gözü hiç ayırmadan, aşağı indikçe iki yana piramit şeklinde açılan kelime çiftlerini okumak, retinanın parafoveal (kenar) reseptörlerini doğrudan aktive eder.',
      actionableSteps: [
        'Çevresel Görüş Piramidi modunda bakışınızı yalnızca ortadaki altın/kırmızı sütun numarasına kilitleyin.',
        'Satır aşağı indikçe sol ve sağ kanattaki kelimeleri gözünüzü kaydırmadan aynı anda okuyun.',
        'Geniş kanat açıklığında kelimeleri net görmeye başladığınızda kitap satırlarını ortadan dikey inerek okuyabilirsiniz.',
      ],
      recommendedExercise: SpeedReadingExerciseType.peripheralPyramid,
    ),
  ];

  /// 21 Günlük Superead Tarzı Kademeli Hızlı Okuma Akademisi Müfredatı
  static const List<SpeedReadingCourseDay> curriculumDays = [
    // 1. HAFTA: Göz Kasları, Fiksasyon & Regresyon Kırma
    SpeedReadingCourseDay(
      dayNumber: 1,
      weekNumber: 1,
      title: 'Başlangıç Ölçümü & Göz Isınması',
      focusTopic: 'Mevcut E-WPM tespiti ve yatay sakkadik esneklik',
      targetWpm: 220,
      drills: [
        SpeedReadingExerciseType.wpmComprehensionTest,
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.schulteGrid,
      ],
      tipOfTheDay: 'Başınızı sabit tutun; yalnızca göz kaslarınızı hareket ettirin.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 2,
      weekNumber: 1,
      title: 'ORP Odak Noktasıyla Tanışma',
      focusTopic: 'Kelimelerin sol-merkez kırmızı odak harfine kilitlenme',
      targetWpm: 250,
      drills: [
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.schulteGrid,
      ],
      tipOfTheDay: 'Kırmızı harfe odaklandığınızda kelimenin tamamı kendiliğinden okunur.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 3,
      weekNumber: 1,
      title: 'Regresyonu (Geriye Dönüşü) Kesme',
      focusTopic: 'Gölgeleme (Pacer) ile ileri yönlü kesintisiz satır takibi',
      targetWpm: 270,
      drills: [
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: 'Okunan satır karardığında geriye bakma dürtüsünü bırakın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 4,
      weekNumber: 1,
      title: 'Çevresel Görüş Temelleri (5x5 Schulte & Piramit)',
      focusTopic: 'Merkez noktadan ayrılmadan kenar kanatları yakalama',
      targetWpm: 285,
      drills: [
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.peripheralPyramid,
        SpeedReadingExerciseType.chunkPacer,
      ],
      tipOfTheDay: '5x5 Schulte tablosunu 35 saniyenin altında tamamlamayı hedefleyin.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 5,
      weekNumber: 1,
      title: 'Satır Dönüş (Return Sweep) Çevikliği',
      focusTopic: 'Zikzak göz rotası ve 2’li kelime gruplama',
      targetWpm: 300,
      drills: [
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: 'Satır sonundan alt satır başına çapraz sıçramayı tek hamlede yapın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 6,
      weekNumber: 1,
      title: '100 ms Anlık Kelime Fotoğraflama',
      focusTopic: 'Takistoskop ile fiksasyon duraksamasını yarıya indirme',
      targetWpm: 315,
      drills: [
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: 'Kelimeyi harf harf değil, tek bir resim karesi gibi algılayın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 7,
      weekNumber: 1,
      title: '1. Hafta Seviye Değerlendirme Sınavı',
      focusTopic: '320 WPM hedef hızda anlama doğruluğu kontrolü',
      targetWpm: 325,
      drills: [
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.wpmComprehensionTest,
      ],
      tipOfTheDay: '%75 ve üzeri anlama oranı, gerçek hız artışının kanıtıdır.',
    ),

    // 2. HAFTA: İçsesi Susturma & Kelime Gruplama (Chunking)
    SpeedReadingCourseDay(
      dayNumber: 8,
      weekNumber: 2,
      title: 'İçses (Subvocalization) Barajını Aşma',
      focusTopic: '2x Hız Sprinti ve 350 WPM akışla fonolojik döngüyü kırma',
      targetWpm: 350,
      drills: [
        SpeedReadingExerciseType.overSpeedSprint,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.chunkPacer,
      ],
      tipOfTheDay: '350 WPM üzerinde diliniz kelimeleri seslendiremez; gözünüzle kavrayın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 9,
      weekNumber: 2,
      title: '2’li ve 3’lü Kelime Blokları (Chunking)',
      focusTopic: 'Sıfat ve isim tamlamalarını tek bakışta okuma',
      targetWpm: 365,
      drills: [
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.tachistoscope,
      ],
      tipOfTheDay: 'Her duraksamada tek kelime yerine 2-3 kelimelik anlam öbeği alın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 10,
      weekNumber: 2,
      title: 'Sonsuzluk (∞) Rotası & Harf Schulte',
      focusTopic: 'Altı ekstraoküler kas senkronizasyonu ve harf tarama',
      targetWpm: 380,
      drills: [
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: 'Harf modlu Schulte tablosu, kelime kökü tanıma hızını doğrudan artırır.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 11,
      weekNumber: 2,
      title: '65 ms Takistoskop & İkili Öbek Flaşlama',
      focusTopic: 'İki kelimelik öbekleri saniyenin on beşinde algılama',
      targetWpm: 395,
      drills: [
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: 'İki kelimenin tam ortasındaki boşluğa bakarak her ikisini de görün.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 12,
      weekNumber: 2,
      title: 'Görüş Piramidi & Dikey Göz Akışı',
      focusTopic: 'Yatay göz gezdirmeyi azaltıp dikey piramit inişi yapma',
      targetWpm: 410,
      drills: [
        SpeedReadingExerciseType.peripheralPyramid,
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.schulteGrid,
      ],
      tipOfTheDay: 'Sayfanın ortasından aşağı doğru kayarken kenarları çevresel görüşle okuyun.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 13,
      weekNumber: 2,
      title: '425 WPM Yüksek Tempolu Kavrama',
      focusTopic: 'Yüksek hızda anahtar kavramları (isim/fiil) yakalama',
      targetWpm: 425,
      drills: [
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.chunkPacer,
      ],
      tipOfTheDay: 'Cümlenin yüklemini ve öznesini yakaladığınızda detaylar zihinde birleşir.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 14,
      weekNumber: 2,
      title: '2. Hafta Seviye Değerlendirme Sınavı',
      focusTopic: 'Başlangıç hızının 2 katında E-WPM doğrulaması',
      targetWpm: 440,
      drills: [
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.wpmComprehensionTest,
      ],
      tipOfTheDay: 'Okuma hızınız ikiye katlanırken anlama oranınızı %80 üzerinde tutun.',
    ),

    // 3. HAFTA: Bilişsel Sentez, Klasik Metin & 500+ WPM Ustalığı
    SpeedReadingCourseDay(
      dayNumber: 15,
      weekNumber: 3,
      title: 'Dinamik Karışan Schulte & Bilişsel Esneklik',
      focusTopic: 'Sürekli değişen görsel matriste anlık hedef bulma',
      targetWpm: 455,
      drills: [
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.saccadicEye,
        SpeedReadingExerciseType.chunkPacer,
      ],
      tipOfTheDay: 'Dinamik Schulte, okurken dikkat dağılmasını sıfıra indirir.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 16,
      weekNumber: 3,
      title: '50 ms Flaş & 3’lü Kelime Öbeği Algısı',
      focusTopic: 'Üç kelimelik ifadeleri tek fiksasyonda çözümleme',
      targetWpm: 470,
      drills: [
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.chunkPacer,
      ],
      tipOfTheDay: 'Üçlü kelime öbeğinin ortasındaki kelimeye odaklanın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 17,
      weekNumber: 3,
      title: 'Klasik ve Felsefi Metinlerde Hızlı Mütalaa',
      focusTopic: 'Ağır kavramlı metinlerde noktalama gecikmeli akış',
      targetWpm: 485,
      drills: [
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.wpmComprehensionTest,
      ],
      tipOfTheDay: 'Felsefi metinlerde cümle sonu duraklaması, kavramın yerleşmesini sağlar.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 18,
      weekNumber: 3,
      title: '6x6 Geniş Matris & Çevresel Hakimiyet',
      focusTopic: '1’den 36’ya geniş alanda parafoveal tarama',
      targetWpm: 500,
      drills: [
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.rsvpOrp,
      ],
      tipOfTheDay: '6x6 matriste bile gözünüzü merkez kareden ayırmamaya özen gösterin.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 19,
      weekNumber: 3,
      title: 'Aşırı Hız Adaptasyonu (2x Over-Speed Sprint)',
      focusTopic: '2x Otoyol Sprinti sonrası 480 WPM konfor hızına dönüş',
      targetWpm: 530,
      drills: [
        SpeedReadingExerciseType.overSpeedSprint,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.peripheralPyramid,
      ],
      tipOfTheDay: '1 dakika 600 WPM okuduktan sonra 450 WPM size çok rahat gelecektir.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 20,
      weekNumber: 3,
      title: 'Tam Konsantrasyon & Blok Sentez',
      focusTopic: '4’lü kelime bloklarıyla tam sayfa gölgeleme akışı',
      targetWpm: 550,
      drills: [
        SpeedReadingExerciseType.chunkPacer,
        SpeedReadingExerciseType.tachistoscope,
        SpeedReadingExerciseType.schulteGrid,
      ],
      tipOfTheDay: 'Zihninizde paragrafın ana fikrini görsel bir şema olarak canlandırın.',
    ),
    SpeedReadingCourseDay(
      dayNumber: 21,
      weekNumber: 3,
      title: 'Mezuniyet & Üstad-ı Kıraat Seviye Sınavı',
      focusTopic: '550+ WPM hız ve %85+ anlama ile akademi beratı',
      targetWpm: 560,
      drills: [
        SpeedReadingExerciseType.schulteGrid,
        SpeedReadingExerciseType.rsvpOrp,
        SpeedReadingExerciseType.wpmComprehensionTest,
      ],
      tipOfTheDay: 'Kazandığınız bu görsel ritmi Tahrir’deki tüm kitaplarınızda uygulayın!',
    ),
  ];

  /// Hız & Anlama Seviye Tespit ve Antrenman Metin Havuzu
  static const List<SpeedReadingPassage> passages = [
    SpeedReadingPassage(
      id: 'ibn_haldun_umran',
      title: 'Umran İlmi ve Tarihin Hakikati',
      author: 'İbn Haldun — Mukaddime',
      category: 'Klasik Düşünce',
      difficulty: 'Orta',
      content:
          'Tarih ilmi, milletlerin ve devletlerin devirlerini, geçmiş asırlardaki hallerini bildiren şerefli bir ilimdir. Zahirde geçmiş günlerin ve devletlerin haberlerinden ibaret görünse de, hakikatte ince bir nazar, derin bir tahkik ve varlıkların sebeplerini dikkatle araştırma ilmidir. Haberleri yalnızca nakletmekle yetinip, bu haberlerin toplumsal tabiat kanunlarına uygun olup olmadığını tartmayan kimse hakikatten uzaklaşır. Zira insan cemiyeti dediğimiz umranın kendine mahsus tabii halleri vardır. Şehirlerin kurulması, sanatların gelişmesi, ilimlerin çoğalması ve devletlerin kudret kazanması hep bu umran kanunlarına tabidir. Bir müellif veya okur, okuduğu haberi cemiyetin tabiatıyla kıyasladığında doğruyu yanlıştan kolayca ayırır.',
      questions: [
        ComprehensionQuestion(
          question: 'İbn Haldun’a göre tarih ilminin hakikati (iç yüzü) nedir?',
          options: [
            'Yalnızca hükümdarların savaşlarını kronolojik sıralamak',
            'İnce bir nazar, tahkik ve varlıkların sebeplerini araştırmak',
            'Eski kavimlerin efsanelerini olduğu gibi ezberlemek',
            'Şiir ve edebiyat sanatlarını derlemek',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metinde "insan cemiyeti ve toplumsal yaşam" hangi kavramla ifade edilmiştir?',
          options: [
            'Umran',
            'Belağat',
            'Fesahat',
            'Heyet',
          ],
          correctIndex: 0,
        ),
        ComprehensionQuestion(
          question: 'Haberlerin doğruyu yanlıştan ayrılması için ne yapılmalıdır?',
          options: [
            'Yalnızca en eski nüshaya bakılmalıdır',
            'Cemiyetin tabiat kanunlarına uygunluğu tartılmalıdır',
            'Haberler kısaltılarak yazılmalıdır',
            'Yalnızca sözlü rivayetlere güvenilmelidir',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Aşağıdakilerden hangisi metinde umran kanunlarına bağlı sayılan unsurlardan biridir?',
          options: [
            'İklimlerin aniden değişmesi',
            'Şehirlerin kurulması, sanatların ve ilimlerin gelişmesi',
            'Yıldızların hareketleri',
            'Deniz ticaretinin tamamen durması',
          ],
          correctIndex: 1,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'bilissel_okuma_bilimi',
      title: 'Gözün Sakkadik Ritmi ve Beynin Görsel Algısı',
      author: 'Tahrir Bilişsel Kıraat Araştırmaları',
      category: 'Bilişsel Bilim',
      difficulty: 'Başlangıç',
      content:
          'İnsan gözü bir metni okurken satır üzerinde kesintisiz ve düz bir çizgide kaymaz. Aksine, sakkad adı verilen çok hızlı sıçramalar yapar ve kelimeler üzerinde fiksasyon denilen kısa duraksamalar gerçekleştirir. Görme işlemi sıçrama esnasında değil, yalnızca bu fiksasyon duraksamalarında gerçekleşir. Eğitimsiz bir okuyucu her kelimede ortalama iki yüz elli milisaniye duraksar ve sık sık okuduğu kelimeye geri döner. Oysa insan beyninin görsel korteksi, kelimeleri tek tek harfler olarak değil, bütüncül anlam kalıpları olarak tanıma kapasitesine sahiptir. Çevresel görüş açısı genişletildiğinde ve içses susturulduğunda, göz bir satırı sadece iki veya üç duraksamada tarayabilir. Böylece okuma hızı artarken, zihin kelimeler arasındaki kopukluktan kurtulduğu için anlama oranı da yükselir.',
      questions: [
        ComprehensionQuestion(
          question: 'Gözün satır üzerinde yaptığı hızlı sıçramalara ve kısa duraksamalara ne ad verilir?',
          options: [
            'Refleks ve Rezonans',
            'Sakkad ve Fiksasyon',
            'Korteks ve Sinaps',
            'Fonoloji ve Morfoloji',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metne göre görme (algılama) işlemi hangi anda gerçekleşir?',
          options: [
            'Göz bir satırdan alt satıra atlarken',
            'Yalnızca fiksasyon (duraksama) anlarında',
            'Göz kırpma esnasında',
            'Kelimeler yüksek sesle telaffuz edildiğinde',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Çevresel görüş genişletildiğinde bir satır kaç duraksamada taranabilir?',
          options: [
            'En az on iki duraksamada',
            'Sadece iki veya üç duraksamada',
            'Her harfte bir duraksamada',
            'Hiç duraksama yapmadan',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Hızlı okumada anlama oranının da yükselmesinin temel sebebi nedir?',
          options: [
            'Metindeki zor kelimelerin atlanması',
            'Zihnin kelimeler arasındaki kopukluktan kurtulup bütüncül algılaması',
            'Sadece başlıkların okunması',
            'Okuma süresinin uzaması',
          ],
          correctIndex: 1,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'katip_celebi_cihannuma',
      title: 'İlimlerin Tasnifi ve Coğrafyanın Ufku',
      author: 'Kâtip Çelebi — Cihannüma & Keşfü’z-Zünûn',
      category: 'Bilim Tarihi',
      difficulty: 'İleri',
      content:
          'İlim, insan ruhunun hakikati kuşatma gayretidir ve tek bir dal ile sınırlandırılamaz. Kâtip Çelebi, ömrü boyunca binlerce cilt eseri bizzat inceleyerek Keşfü’z-Zünûn adlı muazzam bibliyografik ansiklopediyi kaleme almıştır. Ona göre naklî ilimler ile aklî ve matematiksel ilimler bir kuşun iki kanadı gibidir; biri ihmal edildiğinde düşünce yükselemez. Cihannüma adlı eserinde ise doğu ve batı kaynaklarını sentezleyerek coğrafya ve astronomi bilgisini yenilemiştir. Harita ve küre üzerinde çalışmanın, zihne mücerret kavramları somutlaştırma gücü verdiğini vurgulamıştır. Geniş bir kütüphaneyi verimli mütalaa edebilmek için eserin önce fihristini, mukaddimesini ve temel kavram örgüsünü kavramak, ardından metnin derinliklerine inmek gerekir.',
      questions: [
        ComprehensionQuestion(
          question: 'Kâtip Çelebi’nin binlerce eseri inceleyerek yazdığı bibliyografik eserin adı nedir?',
          options: [
            'Mukaddime',
            'Keşfü’z-Zünûn',
            'Kutadgu Bilig',
            'Divan-ı Hikmet',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Kâtip Çelebi naklî ve aklî ilimleri neye benzetmektedir?',
          options: [
            'Birbirine zıt iki kutba',
            'Bir kuşun iki kanadına',
            'Mevsimlerin döngüsüne',
            'Deniz ile karaya',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Cihannüma eserinin temel özelliği nedir?',
          options: [
            'Yalnızca şiir antolojisi olması',
            'Doğu ve batı kaynaklarını sentezleyerek coğrafya ve astronomiyi yenilemesi',
            'Sadece tıp reçetelerini içermesi',
            'Hiçbir harita kullanılmadan yazılması',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metne göre bir eseri verimli mütalaa etmek için önce nereye bakılmalıdır?',
          options: [
            'En son sayfasındaki dipnotlara',
            'Fihristine, mukaddimesine ve temel kavram örgüsüne',
            'Yalnızca cilt kapağının süslemesine',
            'Rastgele açılan orta sayfalara',
          ],
          correctIndex: 1,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'ali_kuscu_astronomi',
      title: 'Semerkand’dan İstanbul’a Gökyüzü Rasadı',
      author: 'Ali Kuşçu — Risâle fi’l-Hey’e',
      category: 'Astronomi & Matematik',
      difficulty: 'Orta',
      content:
          'Gökyüzü cisimlerinin hareketlerini anlamak, yalnızca gözleme değil, kusursuz bir geometrik ve matematiksel muhakemeye dayanır. Semerkand Rasathanesinde yıldızların konumlarını dakika ve saniye hassasiyetiyle ölçen astronomlar, Zîc-i Uluğ Bey tablolarını hazırlarken binlerce gece boyunca gökyüzünü takip etmişlerdir. Ali Kuşçu, astronomi ilmini soyut felsefi varsayımlardan arındırarak doğrudan gözlem ve hesaplama temeline oturtmuştur. İstanbul’a geldiğinde Ayasofya Medresesinde kurduğu ders halkasıyla matematik ve hey’et ilmine yeni bir ivme kazandırmış, güneş saatleri ve meridyen ölçümleriyle zamanın akışını hassas cetvellere bağlamıştır. Doğru bilgiye ulaşmak, sabit önyargıları bırakıp bizzat rasat ve tecrübe etmeye bağlıdır.',
      questions: [
        ComprehensionQuestion(
          question: 'Ali Kuşçu astronomi ilmini hangi temele oturtmuştur?',
          options: [
            'Soyut efsanelere ve rüya yorumlarına',
            'Doğrudan gözlem ve matematiksel hesaplama temeline',
            'Yalnızca eski Yunan şiirlerine',
            'Rüzgâr yönlerinin tahminine',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Semerkand Rasathanesinde hazırlanan ünlü yıldız kataloğunun adı nedir?',
          options: [
            'Kitâb-ı Bahriye',
            'Zîc-i Uluğ Bey',
            'Kanun fi’t-Tıb',
            'Mesnevî',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Ali Kuşçu İstanbul’da hangi medresede ders halkası kurmuştur?',
          options: [
            'Ayasofya Medresesi',
            'Bursa Yeşil Medrese',
            'Konya Karatay Medresesi',
            'Edirne Saatli Medrese',
          ],
          correctIndex: 0,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'mimar_sinan_akustik',
      title: 'Kubbenin Sesi ve Taşın Mühendisliği',
      author: 'Mimar Sinan — Tezkiretü’l-Bünyân',
      category: 'Mimari & Estetik',
      difficulty: 'Orta',
      content:
          'Büyük bir mabedin kubbesi yalnızca taş ve harçtan ibaret bir örtü değil, sesi ve ışığı mekanın her köşesine eşit dağıtan canlı bir geometri harikasıdır. Mimar Sinan, Süleymaniye ve Selimiye külliyelerini inşa ederken zeminin sağlamlığından kubbe kasnağındaki içi boş küplerin akustik rezonansına kadar her ayrıntıyı hesaplamıştır. Mihraptan yükselen en hafif bir kıraat sesi, kubbe içindeki hava akımı ve küplerin yansıtma açısı sayesinde en arka saflara bile berrak bir şekilde ulaşır. Kandillerden çıkan isin tek bir odada toplanıp en kaliteli hat mürekkebine dönüştürülmesi ise hiçbir kaynağın israf edilmediği döngüsel bir mühendislik dehasıdır.',
      questions: [
        ComprehensionQuestion(
          question: 'Mimar Sinan kubbede sesin berrak yayılması (akustik) için ne kullanmıştır?',
          options: [
            'Kalın ahşap perdeler',
            'Kubbe kasnağına yerleştirilen içi boş akustik küpler',
            'Bakır boru hatları',
            'Mermer sütun başlıkları',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Kandillerden çıkan is, külliye içinde neye dönüştürülmüştür?',
          options: [
            'Cam boyasına',
            'En kaliteli hat mürekkebine',
            'Seramik sırrına',
            'Temizlik sabununa',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metinde Mimar Sinan’ın hangi iki büyük eseri özellikle anılmaktadır?',
          options: [
            'Süleymaniye ve Selimiye',
            'Bursa Ulu Cami ve Yeşil Türbe',
            'Topkapı ve Çırağan',
            'Mostar ve Drina Köprüleri',
          ],
          correctIndex: 0,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'piri_reis_bahriye',
      title: 'Açık Denizlerde Pusula ve Haritanın Sırrı',
      author: 'Piri Reis — Kitâb-ı Bahriye',
      category: 'Denizcilik & Coğrafya',
      difficulty: 'Başlangıç',
      content:
          'Deniz üzerinde yol alan bir kaptan için en büyük hazine, rüzgârların dilini ve kıyıların girintilerini doğru okuyan bir haritadır. Piri Reis, Akdeniz’in bütün limanlarını, sığlıklarını, tatlı su kaynaklarını ve fırtına mevsimlerini tek tek gezerek Kitâb-ı Bahriye eserinde kayıt altına almıştır. Bir parşömen üzerine çizilen rüzgâr gülü ve kerteriz çizgileri, karanlık gecelerde yıldızların yüksekliğiyle birleştiğinde gemiyi emniyetli limana ulaştırır. Okuma eylemi de tıpkı açık denizde seyir yapmak gibidir; göz pusulayı kaybettiğinde satırlar arasında sürüklenir, hedefini bildiğinde ise anlam limanına hızla varır.',
      questions: [
        ComprehensionQuestion(
          question: 'Piri Reis’in Akdeniz limanlarını ve sığlıklarını anlattığı eseri hangisidir?',
          options: [
            'Seyahatname',
            'Kitâb-ı Bahriye',
            'Mir’âtü’l-Memâlik',
            'Cihannüma',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metinde okuma eylemi neye benzetilmiştir?',
          options: [
            'Dağ zirvesine tırmanmaya',
            'Açık denizde pusula ve haritayla seyir yapmaya',
            'Toprağı sürmeye',
            'Maden cevheri işlemeye',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Kitâb-ı Bahriye’de limanların yanı sıra hangi hayati bilgi kayıt altına alınmıştır?',
          options: [
            'Sığlıklar, tatlı su kaynakları ve fırtına mevsimleri',
            'Kara ordularının konaklama yerleri',
            'Saray merasim kuralları',
            'İpek dokuma tezgâhları',
          ],
          correctIndex: 0,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'cezeri_sibernetik',
      title: 'Su Saatleri ve Otomatların Dengesi',
      author: 'El-Cezerî — Kitâbü’l-Hıyel',
      category: 'Mühendislik & Sibernetik',
      difficulty: 'İleri',
      content:
          'Mekanik bir düzeneğin kendi kendine çalışabilmesi, suyun kaldırma kuvveti ile ağırlık merkezinin kusursuz bir geri besleme döngüsü içinde dengelenmesine bağlıdır. Diyarbakır’da çalışmalarını sürdüren El-Cezerî, Filli Su Saati ve otomatik abdest alma makinelerinde şamandıra, valf ve krank mili sistemlerini tarihte ilk kez bütünlüklü olarak kullanmıştır. Ona göre teorik olarak tasarlanan fakat pratikte imal edilip sınanmayan her mühendislik fikri, doğru ile yanlış arasında asılı kalır. Zihinsel becerilerimiz de böyledir; yalnızca teorik hızlı okuma kurallarını bilmek yetmez, göz kaslarını ve odak refleksini her gün düzenli pratikle işletmek gerekir.',
      questions: [
        ComprehensionQuestion(
          question: 'El-Cezerî’nin otomatlar ve mekanik düzenekleri anlattığı ünlü eseri nedir?',
          options: [
            'Kitâbü’l-Menâzır',
            'Kitâbü’l-Hıyel',
            'El-Cebr ve’l-Mukabele',
            'Tehâfütü’l-Felâsife',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'El-Cezerî’ye göre pratikte sınanmayan teorik bir tasarımın durumu nedir?',
          options: [
            'Doğrudan kusursuz kabul edilir',
            'Doğru ile yanlış arasında asılı kalır',
            'Uygulamadan daha değerlidir',
            'Hiçbir zaman yazıya geçirilemez',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Metinde El-Cezerî’nin hangi ünlü mekanik tasarımından söz edilmiştir?',
          options: [
            'Buharlı lokomotif',
            'Filli Su Saati ve krank mili düzenekleri',
            'Güneş enerjili fırın',
            'Manyetik telgraf',
          ],
          correctIndex: 1,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'farabi_musiki_zihin',
      title: 'Ritim, Ahenk ve Zihnin Odaklanma Gücü',
      author: 'Fârâbî — Kitâbü’l-Mûsîka’l-Kebîr',
      category: 'Felsefe & Ahenk',
      difficulty: 'Orta',
      content:
          'İnsan zihni, düzensiz ve kopuk uyaranlar karşısında çabuk yorulurken, belirli bir ritim ve matematiksel orana sahip akışlar içinde sükûnet ve berraklık bulur. Fârâbî, seslerin uyumunu ve zaman aralıklarını incelerken ritmin insan ruhu ve dikkati üzerindeki derin etkisini ortaya koymuştur. Okuma sırasında gözün satırlar üzerinde kesik kesik duraksaması zihinsel ritmi bozar ve dikkatin dağılmasına yol açar. Buna karşılık, sabit ve akıcı bir tempoyla kelimeleri öbekler halinde taramak, zihinde adeta bir musiki ahengi oluşturur. Ritim korunduğunda içses susar, dikkat tek bir noktada toplanır ve anlam zihne zahmetsizce nakşolur.',
      questions: [
        ComprehensionQuestion(
          question: 'Metne göre insan zihni hangi durumda çabuk yorulur?',
          options: [
            'Düzenli ve ritmik akışlar karşısında',
            'Düzensiz ve kopuk uyaranlar karşısında',
            'Kısa cümleleri okurken',
            'Sabah saatlerinde çalışırken',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Okuma sırasında dikkatin dağılmasına yol açan temel etken nedir?',
          options: [
            'Gözün satırlar üzerinde kesik kesik duraksayarak ritmi bozması',
            'Sayfa kenar boşluklarının geniş olması',
            'Metnin paragraflara ayrılması',
            'Kitabın basılı olması',
          ],
          correctIndex: 0,
        ),
        ComprehensionQuestion(
          question: 'Sabit ve akıcı bir okuma ritmi korunduğunda zihinde ne gerçekleşir?',
          options: [
            'İçses artar ve hız düşer',
            'İçses susar, dikkat toplanır ve anlam zahmetsizce kavranır',
            'Kelimeler tamamen unutulur',
            'Göz kasları kilitlenir',
          ],
          correctIndex: 1,
        ),
      ],
    ),
    SpeedReadingPassage(
      id: 'ibn_heysem_optik',
      title: 'Işığın Doğrusal Yayılımı ve Görme Kuramı',
      author: 'İbnü’l-Heysem — Kitâbü’l-Menâzır',
      category: 'Optik & Algı Bilimi',
      difficulty: 'İleri',
      content:
          'Antik çağlardan beri tartışılan görme hadisesi, gözden çıkan ışınların nesnelere çarpmasıyla değil, nesnelerden yansıyan ışığın göze ulaşmasıyla gerçekleşir. İbnü’l-Heysem, karanlık oda deneyleriyle ışığın doğrusal yayıldığını kanıtlamış ve mercek kırılmalarını ayrıntılı biçimde açıklamıştır. Ancak göz merceğine düşen görüntü, tek başına görme için yeterli değildir; beyin bu görsel izlenimi önceki hafıza kayıtlarıyla karşılaştırarak anlamlandırır. Hızlı okumada da göz sadece kelimenin genel silüetini ve kök harflerini yakalar; kelimenin tam anlamını ise beynin görsel hafıza merkezi milisaniyeler içinde tamamlar.',
      questions: [
        ComprehensionQuestion(
          question: 'İbnü’l-Heysem görme olayını nasıl açıklamıştır?',
          options: [
            'Gözden çıkan ateş ışınlarının nesneyi aydınlatmasıyla',
            'Nesnelerden yansıyan ışığın göze ulaşması ve beyinde anlamlandırılmasıyla',
            'Ses dalgalarının havada kırılmasıyla',
            'Nesnelerin ağırlık merkezinin değişmesiyle',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'İbnü’l-Heysem ışığın doğrusal yayıldığını hangi deneyle kanıtlamıştır?',
          options: [
            'Serbest düşme deneyi',
            'Karanlık oda (Camera Obscura) deneyi',
            'Sarkaç salınım deneyi',
            'Su kaldırma deneyi',
          ],
          correctIndex: 1,
        ),
        ComprehensionQuestion(
          question: 'Hızlı okumada kelimenin tam anlamını milisaniyeler içinde tamamlayan merkez neresidir?',
          options: [
            'Ses telleri ve gırtlak kasları',
            'Beynin görsel hafıza ve anlamlandırma merkezi',
            'Göz kapağı refleksi',
            'Omurilik soğanı',
          ],
          correctIndex: 1,
        ),
      ],
    ),
  ];

  /// Kullanıcının son okuduğu metinleri tekrar etmeyen, varsa kendi kitabından canlı kesit seçen akıllı seçici
  static SpeedReadingPassage selectFreshPassage({
    required List<String> recentPassageIds,
    List<SpeedReadingPassage> userBookPassages = const [],
    int? preferredStage,
  }) {
    final allCandidates = <SpeedReadingPassage>[
      ...userBookPassages,
      ...passages,
    ];

    // Son kullanılanlarda olmayan taze metinleri filtrele
    final freshList = allCandidates
        .where((p) => !recentPassageIds.contains(p.id))
        .toList();

    final pool = freshList.isNotEmpty ? freshList : allCandidates;

    // Eğer kullanıcının kendi kitabından taze kesit varsa ona öncelik ver
    final freshUserBook =
        pool.where((p) => p.isFromUserBook).toList();
    if (freshUserBook.isNotEmpty) {
      return freshUserBook.first;
    }

    if (preferredStage != null && pool.isNotEmpty) {
      final safeStage = preferredStage.clamp(1, 21);
      final idx = (safeStage + recentPassageIds.length) % pool.length;
      return pool[idx];
    }

    return pool.first;
  }
}
