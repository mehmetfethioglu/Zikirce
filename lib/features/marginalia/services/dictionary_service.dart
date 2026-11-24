class DictionaryEntry {
  final String word;
  final String origin;       // Köken (Arapça, Farsça, Türkçe, Fransızca, Yunanca, Latince vb.)
  final String partOfSpeech; // İsim, Sıfat, Zarf, Felsefe, Edebiyat vb.
  final String meaning;      // Tanım & Anlam
  final String? example;     // Edebi örnek cümle / beyit

  const DictionaryEntry({
    required this.word,
    required this.origin,
    required this.partOfSpeech,
    required this.meaning,
    this.example,
  });
}

class DictionaryService {
  static final Map<String, DictionaryEntry> _localDictionary = {
    // --- Kitap Sanatları, Şerh Geleneği ve El Yazması Kültürü ---
    'tahrir': const DictionaryEntry(
      word: 'Tahrir',
      origin: 'Arapça (taḥrīr)',
      partOfSpeech: 'İsim',
      meaning: '1. Yazma, kaleme alma, kompozisyon oluşturma. 2. Bir metni tashih edip temize çekme. 3. Osmanlıda vergi, arazi ve nüfus sayım defteri tutma işlemi.',
      example: '"Kitabın tahriri esnasında her kelime kuyumcu titizliğiyle tartıldı."',
    ),
    'şerh': const DictionaryEntry(
      word: 'Şerh',
      origin: 'Arapça (şarḥ)',
      partOfSpeech: 'İsim',
      meaning: '1. Açma, ayırma, genişletme. 2. Klasik bir eseri, veciz bir metni veya şiiri anlaşılır kılmak üzere kelimelerini ve mazmunlarını ayrıntılarıyla açıklayan telif tür.',
      example: '"Eski divanların kenarlarına düşülen şerhler, asırlar ötesinden gelen birer sohbet halkasıdır."',
    ),
    'haşiye': const DictionaryEntry(
      word: 'Haşiye',
      origin: 'Arapça (ḥāşiye)',
      partOfSpeech: 'İsim',
      meaning: 'Bir metnin veya şerhin sayfa kenarlarına yahut altına düşülen ek açıklama, incelikli dipnot, şerhin şerhi.',
      example: '"Müderris, zor ibareyi aydınlatmak için varak kenarına zarif bir haşiye düştü."',
    ),
    'derkenar': const DictionaryEntry(
      word: 'Derkenar',
      origin: 'Farsça (der-kenār)',
      partOfSpeech: 'İsim',
      meaning: 'Sayfa kenarına, metnin yan boşluğuna yazılan çıkma not, mütalaa veya resmi işlem kaydı.',
      example: '"Okuyucunun derkenara düştüğü tek cümlelik not, bütün bölümü özetliyordu."',
    ),
    'mukaddime': const DictionaryEntry(
      word: 'Mukaddime',
      origin: 'Arapça (muḳaddime)',
      partOfSpeech: 'İsim',
      meaning: 'Bir eserin yazılış gayesini, yöntemini ve kavramsal çerçevesini sunan önsöz, başlangıç bölümü, prolegomena.',
      example: '"İbn Haldun\'un Mukaddime\'si, tarih felsefesinin kurucu metni kabul edilir."',
    ),
    'istinsah': const DictionaryEntry(
      word: 'İstinsah',
      origin: 'Arapça (istinsāḫ)',
      partOfSpeech: 'İsim',
      meaning: 'Bir el yazması eseri aslına sadık kalarak elle kopyalama, nüshasını çoğaltma.',
      example: '"Nadir bulunan bu risale, Topkapı Sarayı Kütüphanesi nüshasından istinsah edilmiştir."',
    ),
    'müellif': const DictionaryEntry(
      word: 'Müellif',
      origin: 'Arapça (muʾellif)',
      partOfSpeech: 'İsim',
      meaning: 'Kitap yazan, dağınık bilgileri telif ve tertip ederek özgün bir eser ortaya koyan kimse, yazar.',
      example: '"Müellif nüshası, eserin bizzat yazarının kaleminden çıkmış en güvenilir nüshadır."',
    ),
    'müstensih': const DictionaryEntry(
      word: 'Müstensih',
      origin: 'Arapça (mustensiḫ)',
      partOfSpeech: 'İsim',
      meaning: 'El yazması kitapları hattıyla kopyalayıp çoğaltan katip veya hattat.',
      example: '"Müstensih, ketebe kaydında eseri hangi tarihte tamamladığını özenle belirtmişti."',
    ),
    'marjinalia': const DictionaryEntry(
      word: 'Marjinalia',
      origin: 'Latince (marginalia)',
      partOfSpeech: 'İsim',
      meaning: 'Kitap sayfalarının kenar boşluklarına okuyucu tarafından elle düşülen düşünceler, şerhler, eleştiriler ve işaretler.',
      example: '"Büyük düşünürlerin marjinaliaları çoğu zaman metnin kendisi kadar ufuk açıcıdır."',
    ),
    'sahaf': const DictionaryEntry(
      word: 'Sahaf',
      origin: 'Arapça (ṣaḥḥāf)',
      partOfSpeech: 'İsim',
      meaning: 'Eski, baskısı tükenmiş, nadir veya el yazması kitapları alıp satan, kitap kültürüne vakıf kimse.',
      example: '"Beyazıt\'taki asırlık sahaflarda kağıt ve mürekkep kokusu zamanı durdurur."',
    ),
    'varak': const DictionaryEntry(
      word: 'Varak',
      origin: 'Arapça (varaḳ)',
      partOfSpeech: 'İsim',
      meaning: '1. El yazması kitaplarda ön ve arka yüzü (a ve b yüzleri) kapsayan her bir yaprak. 2. Süslemede kullanılan çok ince dövülmüş altın veya gümüş yaprak.',
      example: '"Eserin ilk varakı, altın varakla işlenmiş muhteşem bir serlevha tezhibi taşıyordu."',
    ),
    'varaka': const DictionaryEntry(
      word: 'Varaka',
      origin: 'Arapça (varaḳa)',
      partOfSpeech: 'İsim',
      meaning: 'Tek bir yaprak kağıt, yazılı belge, pusula veya resmi evrak.',
      example: '"Arşiv tasnifinde sandıktan çıkan her bir varaka özenle numaralandırıldı."',
    ),
    'tezhip': const DictionaryEntry(
      word: 'Tezhip',
      origin: 'Arapça (teẕhīb)',
      partOfSpeech: 'İsim',
      meaning: 'Altınlama; el yazması kitapların sayfalarını ezilmiş altın varak ve toprak boyalarla bezeme sanatı.',
      example: '"Hat sanatının vakarını, etrafını saran ince tezhip motifleri tamamlar."',
    ),
    'ebru': const DictionaryEntry(
      word: 'Ebru',
      origin: 'Farsça (ebrî - bulutlu)',
      partOfSpeech: 'İsim',
      meaning: 'Kitreli su üzerine öd ile terbiye edilmiş toprak boyaların serpilip şekillendirilmesi ve kağıda aktarılmasıyla yapılan geleneksel kitap sanatı.',
      example: '"Her ebru teknesi, bir daha asla aynısı tekrarlanamayacak bir anın nakşıdır."',
    ),
    'sülüs': const DictionaryEntry(
      word: 'Sülüs',
      origin: 'Arapça (s̱ülüs̱)',
      partOfSpeech: 'İsim',
      meaning: 'İslam hat sanatında kalem ağzının üçte iki düz, üçte bir eğimli hareketiyle yazılan, "yazıların anası" kabul edilen heybetli ve estetik yazı çeşidi.',
      example: '"Cami kubbelerindeki celî sülüs kuşak yazıları mekanın ruhunu yükseltir."',
    ),
    'nesih': const DictionaryEntry(
      word: 'Nesih',
      origin: 'Arapça (nesḫ)',
      partOfSpeech: 'İsim',
      meaning: 'Okunaklılığı ve dengeli oranları sebebiyle bilhassa Kur\'an-ı Kerim ve uzun ilmi eserlerin istinsahında tercih edilen ince hat türü.',
      example: '"Şeyh Hamdullah\'ın nesih hattı, gözü yormayan berraklığın zirvesidir."',
    ),
    'talik': const DictionaryEntry(
      word: 'Talik',
      origin: 'Arapça (taʿlīḳ)',
      partOfSpeech: 'İsim',
      meaning: 'Harfleri kavisli ve akıcı hatlarla birbirine asılı gibi duran, bilhassa divan edebiyatı metinlerinde ve kitabelerde kullanılan zarif yazı türü.',
      example: '"Şairlerin divanları, şiirin musikisine en çok yakışan talik hattıyla yazılırdı."',
    ),
    'tuğra': const DictionaryEntry(
      word: 'Tuğra',
      origin: 'Eski Türkçe (tuğrağ)',
      partOfSpeech: 'İsim',
      meaning: 'Hükümdarın adını ve unvanını içeren, ferman, berat ve sikkelerin üst kısmına çekilen kaligrafik hükümdarlık alameti ve imzası.',
      example: '"Fermanın başındaki altın tuğra, devletin haşmetini ve hukuki geçerliliğini simgelerdi."',
    ),
    'ferman': const DictionaryEntry(
      word: 'Ferman',
      origin: 'Farsça (fermān)',
      partOfSpeech: 'İsim',
      meaning: 'Hükümdarın tuğrasını taşıyan, Divan-ı Hümayun\'dan çıkan yazılı kesin emir, buyruk.',
      example: '"Adaletin tesisi için vilayetlere gönderilen ferman kadı sicillerine kaydedildi."',
    ),
    'berat': const DictionaryEntry(
      word: 'Berat',
      origin: 'Arapça (berāʾet)',
      partOfSpeech: 'İsim',
      meaning: 'Bir vazife, unvan, imtiyaz veya ehliyetin verildiğini belgeleyen tuğralı resmi diploma, onay belgesi.',
      example: '"Uzun süren tahsilin ardından talebeye ilmi ehliyetini gösteren beratı takdim edildi."',
    ),
    'mühür': const DictionaryEntry(
      word: 'Mühür',
      origin: 'Farsça (muhr)',
      partOfSpeech: 'İsim',
      meaning: 'Bir belgenin veya kitabın aidiyetini ve sıhhatini tasdik etmek üzere metal veya kıymetli taşa ters kazınmış isim ve simge damgası.',
      example: '"Yazma eserin ilk sayfasındaki vakıf mührü, kitabın yüzyıllık yolculuğuna şahitlik eder."',
    ),
    'ketebe': const DictionaryEntry(
      word: 'Ketebe',
      origin: 'Arapça (ketebe - yazdı)',
      partOfSpeech: 'İsim',
      meaning: 'Hattatın veya müstensihin bir eserin ya da levhanın sonuna kendi adını, hocasını ve yazılış tarihini kaydettiği imza satırı.',
      example: '"Ketebe kaydı olmayan yazmaların tarihlendirilmesi kağıt ve mürekkep analizine dayanır."',
    ),
    'icazet': const DictionaryEntry(
      word: 'İcazet',
      origin: 'Arapça (icāzet)',
      partOfSpeech: 'İsim',
      meaning: 'Geleneksel ilim ve sanat eğitiminde üstadın, talebesinin ehliyetini onaylayarak kendi imzasını veya ders halkasını devam ettirme izni vermesi, diploma.',
      example: '"Yıllarca meşk eden hattat, nihayet hocasından ketebe koyma icazeti aldı."',
    ),
    'külliyat': const DictionaryEntry(
      word: 'Külliyat',
      origin: 'Arapça (kulliyyāt)',
      partOfSpeech: 'İsim',
      meaning: 'Bir müellifin veya şairin kaleme aldığı bütün eserlerin bir araya getirilmiş bütünü, toplu eserler.',
      example: '"Mütefekkirin külliyatı, kırk yıllık fikri mesaisinin bütün safhalarını barındırır."',
    ),
    'risale': const DictionaryEntry(
      word: 'Risale',
      origin: 'Arapça (risāle)',
      partOfSpeech: 'İsim',
      meaning: 'Belirli bir ilmi, felsefi veya edebi meseleyi özlü biçimde inceleyen küçük hacimli kitapçık, monografi, deneme.',
      example: '"Kâtib Çelebi\'nin Mîzânü\'l-Hak adlı risalesi, ilmi hoşgörünün başyapıtıdır."',
    ),
    'mecmua': const DictionaryEntry(
      word: 'Mecmua',
      origin: 'Arapça (mecmūʿa)',
      partOfSpeech: 'İsim',
      meaning: 'Seçilmiş şiirlerin, notların, risalelerin veya makalelerin bir araya toplandığı derleme defteri, seçki, dergi.',
      example: '"Şiir mecmuaları, bir dönemin edebi zevkini yansıtan en samimi tanıklardır."',
    ),
    'nüsha': const DictionaryEntry(
      word: 'Nüsha',
      origin: 'Arapça (nusḫa)',
      partOfSpeech: 'İsim',
      meaning: 'Bir eserin elle çoğaltılmış veya basılmış örneklerinden her biri, kopya.',
      example: '"Tenkitli neşir için eserin bilinen en eski üç nüshası karşılaştırıldı."',
    ),
    'kitap': const DictionaryEntry(
      word: 'Kitap',
      origin: 'Arapça (kitāb)',
      partOfSpeech: 'İsim',
      meaning: 'Bir araya getirilip ciltlenmiş yazılı yapraklar bütünü; bilginin, hafızanın ve hikmetin nesilden nesile aktarıldığı eser.',
      example: '"Kitabın yaprakları arasında dolaşan zihin, zamanın ve mekanın sınırlarını aşar."',
    ),
    'cümle': const DictionaryEntry(
      word: 'Cümle',
      origin: 'Arapça (cumle)',
      partOfSpeech: 'İsim',
      meaning: '1. Bir yargıyı, düşünceyi veya duyguyu tam olarak ifade eden kelime dizisi, tümce. 2. Bütün, hep, tamamı.',
      example: '"Hikmetli bir cümle, bazen koca bir cildin anlatamadığı hakikati tek nefeste söyler."',
    ),

    // --- Düşünce, İrfan, Psikoloji ve Ahlak Kavramları ---
    'tecessüs': const DictionaryEntry(
      word: 'Tecessüs',
      origin: 'Arapça (tecessus)',
      partOfSpeech: 'İsim',
      meaning: 'Derinlemesine öğrenme arzusu, bilinmeyeni araştırma ve hakikati yoklama merakı.',
      example: '"İlmi tecessüs, insanı malumatın kabuğundan hakikatin özüne taşır."',
    ),
    'tahayyül': const DictionaryEntry(
      word: 'Tahayyül',
      origin: 'Arapça (taḫayyul)',
      partOfSpeech: 'İsim',
      meaning: 'Zihinde canlandırma, hayal gücünü kullanarak soyut tasarımlar kurma yetisi, imgelem.',
      example: '"Okumak, tahayyül dünyasının kapılarını ardına kadar aralar."',
    ),
    'tefekkür': const DictionaryEntry(
      word: 'Tefekkür',
      origin: 'Arapça (tefekkur)',
      partOfSpeech: 'İsim',
      meaning: 'Varlık, olaylar ve kavramlar üzerinde derinlemesine, sistemli ve hikmet arayışıyla düşünme.',
      example: '"Bir saatlik samimi tefekkür, zihnin pasını silen en berrak aynadır."',
    ),
    'tedebbür': const DictionaryEntry(
      word: 'Tedebbür',
      origin: 'Arapça (tedebbur)',
      partOfSpeech: 'İsim',
      meaning: 'Bir sözün veya işin arka planını, akıbetini ve derin maksadını inceden inceye düşünerek kavrama.',
      example: '"Metni yalnızca gözle değil, tedebbür ile kalp ve akıl süzgecinden geçirerek okumalıdır."',
    ),
    'tasavvur': const DictionaryEntry(
      word: 'Tasavvur',
      origin: 'Arapça (taṣavvur)',
      partOfSpeech: 'İsim',
      meaning: 'Bir şeyin mahiyetini zihinde biçimlendirme, kavramsal tasarım, henüz hüküm verilmemiş zihni suret.',
      example: '"Mantık ilminde her tasdik ve hükümden önce doğru bir tasavvur gerekir."',
    ),
    'basiret': const DictionaryEntry(
      word: 'Basiret',
      origin: 'Arapça (baṣīret)',
      partOfSpeech: 'İsim',
      meaning: 'Gerçekleri yanılmadan görebilme yeteneği, uzağı görüş, kalp gözü ve derin sezgi.',
      example: '"Göz yalnız zahiri görür; basiret ise zahirin ardındaki manayı okur."',
    ),
    'feraset': const DictionaryEntry(
      word: 'Feraset',
      origin: 'Arapça (ferāset)',
      partOfSpeech: 'İsim',
      meaning: 'İnce işaretlerden ve belirtilerden yola çıkarak bir durumun iç yüzünü çabucak kavrayan keskin anlayış, sağduyu.',
      example: '"Feraset sahibi bir okur, yazarın satır aralarında gizlediği niyeti hemen sezer."',
    ),
    'hikmet': const DictionaryEntry(
      word: 'Hikmet',
      origin: 'Arapça (ḥikme)',
      partOfSpeech: 'İsim',
      meaning: '1. Bilgelik, ilim ile amelin birleştiği derin kavrayış. 2. Varlıkların yaratılış gayesi ve eşyanın hakikati.',
      example: '"Gönül gözü açık olan, her hadisede bir hikmet arar."',
    ),
    'nizam': const DictionaryEntry(
      word: 'Nizam',
      origin: 'Arapça (niẓām)',
      partOfSpeech: 'İsim',
      meaning: 'İnci dizisi gibi kusursuz tertip, düzen, kanun, ahenkli uyum ve kozmik denge.',
      example: '"Kainattaki nizam, aklın en büyük rehberidir."',
    ),
    'vuslat': const DictionaryEntry(
      word: 'Vuslat',
      origin: 'Arapça (vuṣlat)',
      partOfSpeech: 'İsim',
      meaning: 'Ayrılığın sona ermesi, arzulanan sevgiliye veya aranan hakikate kavuşma.',
      example: '"Uzun süren tahkik yolculuğunun sonunda hakikate vuslat nasip oldu."',
    ),
    'firkat': const DictionaryEntry(
      word: 'Firkat',
      origin: 'Arapça (firḳat)',
      partOfSpeech: 'İsim',
      meaning: 'Sevilenden ayrı düşme, ayrılık acısı, hicran.',
      example: '"Divan şiirinde firkat ateşi, aşıkı olgunlaştıran bir imtihan olarak görülür."',
    ),
    'tevekkül': const DictionaryEntry(
      word: 'Tevekkül',
      origin: 'Arapça (tevekkul)',
      partOfSpeech: 'İsim',
      meaning: 'Üzerine düşen bütün gayret ve tedbiri eksiksiz yerine getirdikten sonra kalbi huzurla sonuca razı olma.',
      example: '"Gerçek tevekkül, tembellik değil; cehd ve gayretin ardından gelen iç huzurudur."',
    ),
    'kanaat': const DictionaryEntry(
      word: 'Kanaat',
      origin: 'Arapça (ḳanāʿat)',
      partOfSpeech: 'İsim',
      meaning: '1. Elindekini yeterli görüp açgözlülükten uzak durma, gönül zenginliği. 2. Düşünce sonucu varılan sağlam kanı.',
      example: '"Kanaat, tükenmek bilmeyen bir hazinedir."',
    ),
    'rıfk': const DictionaryEntry(
      word: 'Rıfk',
      origin: 'Arapça (rifḳ)',
      partOfSpeech: 'İsim',
      meaning: 'Sözde ve davranışta nezaket, yumuşak huyluluk, sertlikten ve kabalıktan sakınma.',
      example: '"Rıfk ile yaklaşılan her müşkül, kırılmadan ve incitmeden çözülür."',
    ),
    'hilm': const DictionaryEntry(
      word: 'Hilm',
      origin: 'Arapça (ḥilm)',
      partOfSpeech: 'İsim',
      meaning: 'Öfke anında nefsine hakim olma, gücü yettiği halde bağışlayıcı ve ağırbaşlı davranma erdemi.',
      example: '"İlim insanı kibirden, hilm ise öfkenin yıkıcılığından korur."',
    ),
    'adab': const DictionaryEntry(
      word: 'Adab',
      origin: 'Arapça (ādāb)',
      partOfSpeech: 'İsim',
      meaning: 'Edepler; bir ilmi, sanatı veya toplumsal ilişkiyi icra ederken gözetilmesi gereken incelikli usul ve zarafet kuralları.',
      example: '"Eski medreselerde ilimden önce mütalaa ve münazara adabı öğretilirdi."',
    ),
    'muaşeret': const DictionaryEntry(
      word: 'Muaşeret',
      origin: 'Arapça (muʿāşeret)',
      partOfSpeech: 'İsim',
      meaning: 'İnsanlarla bir arada uyumlu, saygılı ve zarif biçimde yaşama, toplumsal görgü.',
      example: '"Adab-ı muaşeret, bir medeniyetin gündelik hayata yansıyan estetiğidir."',
    ),
    'müntesip': const DictionaryEntry(
      word: 'Müntesip',
      origin: 'Arapça (muntesib)',
      partOfSpeech: 'Sıfat / İsim',
      meaning: 'Bir ilim halkasına, ekole, mesleğe veya kuruma gönülden bağlı olan, mensup kimse.',
      example: '"Kalemiye sınıfına müntesip katipler, inşâ sanatında maharet sahibiydi."',
    ),
    'münzevi': const DictionaryEntry(
      word: 'Münzevi',
      origin: 'Arapça (munzevī)',
      partOfSpeech: 'Sıfat',
      meaning: 'Kalabalıklardan çekilip kendi iç dünyasına, okumaya ve tefekküre yönelen, inzivayı seçen.',
      example: '"Münzevi alim, ömrünü kütüphanesindeki nadir yazmaları şerh etmeye adamıştı."',
    ),
    'mütecessis': const DictionaryEntry(
      word: 'Mütecessis',
      origin: 'Arapça (mutecessis)',
      partOfSpeech: 'Sıfat',
      meaning: 'Meraklı, araştırmacı, her şeyin iç yüzünü ve sebebini öğrenmeye can atan.',
      example: '"Mütecessis bir zihin, karşılaştığı hiçbir kavramı sorgulamadan geçmez."',
    ),
    'irfan': const DictionaryEntry(
      word: 'İrfan',
      origin: 'Arapça (ʿirfān)',
      partOfSpeech: 'İsim',
      meaning: 'Bilginin içselleştirilip hale, ahlaka ve sezgiye dönüşmüş yüksek mertebesi; kültür ve sezgi bütünlüğü.',
      example: '"İlim bilmektir, irfan ise bildiğini varlığında yaşayarak tanımaktır."',
    ),
    'cehd': const DictionaryEntry(
      word: 'Cehd',
      origin: 'Arapça (cehd)',
      partOfSpeech: 'İsim',
      meaning: 'Bir gayeye ulaşmak için bütün gücünü ortaya koyarak çalışma, azimli çaba, gayret.',
      example: '"İnsan için ancak kendi cehd ve gayretinin karşılığı vardır."',
    ),
    'mefkûre': const DictionaryEntry(
      word: 'Mefkûre',
      origin: 'Arapça (mefkūre)',
      partOfSpeech: 'İsim',
      meaning: 'Bir bireyin veya toplumun uğrunda çalıştığı yüce gaye, ülkü, ideal.',
      example: '"Büyük eserler, yüksek bir mefkûre taşıyan ruhların sabırlı mesaisiyle doğar."',
    ),
    'mefkure': const DictionaryEntry(
      word: 'Mefkûre',
      origin: 'Arapça (mefkūre)',
      partOfSpeech: 'İsim',
      meaning: 'Bir bireyin veya toplumun uğrunda çalıştığı yüce gaye, ülkü, ideal.',
      example: '"Büyük eserler, yüksek bir mefkûre taşıyan ruhların sabırlı mesaisiyle doğar."',
    ),

    // --- Belagat, Klasik Edebiyat ve Şiir Estetiği ---
    'üslup': const DictionaryEntry(
      word: 'Üslup',
      origin: 'Arapça (uslūb)',
      partOfSpeech: 'İsim',
      meaning: 'Bir yazarın veya sanatçının dili, kelimeleri ve düşünceyi kendine özgü kullanış tarzı, biçem.',
      example: '"Üslubu beyan, ayniyle insandır; kişinin dili ruhunun aynasıdır."',
    ),
    'belagat': const DictionaryEntry(
      word: 'Belagat',
      origin: 'Arapça (belāġat)',
      partOfSpeech: 'İsim',
      meaning: 'Sözün fasih olmakla birlikte söylendiği makama, muhatabın haline ve bağlama tam uygun, etkili ve sanatlı söylenmesi ilmi; retorik.',
      example: '"Belagat, yalnız süslü konuşmak değil; her sözü tam yerinde ve ölçüsünde söylemektir."',
    ),
    'fesahat': const DictionaryEntry(
      word: 'Fesahat',
      origin: 'Arapça (feṣāḥat)',
      partOfSpeech: 'İsim',
      meaning: 'Sözün ve kelimelerin telaffuz kusurlarından, mana kapalılığından ve dilbilgisi hatalarından arınmış, duru ve akıcı olması.',
      example: '"Fesahat, belagat sarayının sağlam temelidir."',
    ),
    'icaz': const DictionaryEntry(
      word: 'İcaz',
      origin: 'Arapça (īcāz)',
      partOfSpeech: 'İsim',
      meaning: 'En az kelimeyle en derin ve geniş manayı eksiksiz ifade etme sanatı, veciz anlatım.',
      example: '"Atasözleri ve hikmetli beyitler, icaz sanatının en parlak örnekleridir."',
    ),
    'mecaz': const DictionaryEntry(
      word: 'Mecaz',
      origin: 'Arapça (mecāz)',
      partOfSpeech: 'İsim',
      meaning: 'Bir kelimenin veya ifadenin, aradaki ilgi veya benzerlik dolayısıyla gerçek anlamı dışında kullanılması, metaforik anlatım.',
      example: '"Hakikate giden yolda mecaz, manayı zihne yaklaştıran zarif bir köprüdür."',
    ),
    'istiare': const DictionaryEntry(
      word: 'İstiare',
      origin: 'Arapça (istiʿāre)',
      partOfSpeech: 'İsim',
      meaning: 'Edebiyatta benzeyen veya kendisine benzetilen unsurlardan yalnızca birinin söylenmesiyle yapılan üst düzey benzetme sanatı, eğretileme, metafor.',
      example: '"Şair, sevgiliyi doğrudan güneş diye anarak açık istiare sanatına başvurdu."',
    ),
    'kinaye': const DictionaryEntry(
      word: 'Kinaye',
      origin: 'Arapça (kināye)',
      partOfSpeech: 'İsim',
      meaning: 'Bir sözü gerçek anlamı da düşünülebilecek şekilde, asıl olarak mecazi anlamını kastedecek biçimde dolaylı söyleme sanatı.',
      example: '"Kapısı herkese açıktır sözü, cömertliği anlatan zarif bir kinayedir."',
    ),
    'teşbih': const DictionaryEntry(
      word: 'Teşbih',
      origin: 'Arapça (teşbīh)',
      partOfSpeech: 'İsim',
      meaning: 'Aralarında ortak nitelik bulunan iki şeyden zayıf olanı güçlü olana benzetme sanatı.',
      example: '"Bilgiyi ışığa, cehaleti karanlığa teşbih etmek bütün kültürlerin ortak mirasıdır."',
    ),
    'telmih': const DictionaryEntry(
      word: 'Telmih',
      origin: 'Arapça (telmīḥ)',
      partOfSpeech: 'İsim',
      meaning: 'Söz arasında herkesçe bilinen tarihi bir olaya, kıssaya, ayete veya atasözüne dolaylı olarak işaret etme sanatı, gönderme.',
      example: '"Beyitte geçen ayna motifi, İskender\'in sırlı aynasına ince bir telmihtir."',
    ),
    'tezat': const DictionaryEntry(
      word: 'Tezat',
      origin: 'Arapça (teżādd)',
      partOfSpeech: 'İsim',
      meaning: 'Birbirine karşıt kavramları, imgeleri veya durumları bir arada kullanarak anlamı güçlendirme sanatı, karşıtlık, antitez.',
      example: '"Gece ile gündüzün, firkat ile vuslatın tezadı şiire derin bir gerilim katar."',
    ),
    'tenasüp': const DictionaryEntry(
      word: 'Tenasüp',
      origin: 'Arapça (tenāsub)',
      partOfSpeech: 'İsim',
      meaning: 'Anlamca birbiriyle ilgili ve uyumlu kelimeleri bir beyit veya cümle içinde bir arada kullanma sanatı, uygunluk.',
      example: '"Gül, bülbül, bağ ve bahar kelimelerinin bir araya gelişi tenasüp sanatını oluşturur."',
    ),
    'seci': const DictionaryEntry(
      word: 'Seci',
      origin: 'Arapça (secʿ)',
      partOfSpeech: 'İsim',
      meaning: 'Klasik nesirde cümle veya cümlecik sonlarında yapılan ses ve uyak ahengi, iç kafiye.',
      example: '"Sinan Paşa\'nın Tazarruname\'si, seci sanatının nesre kattığı musikiyle tanınır."',
    ),
    'mazmun': const DictionaryEntry(
      word: 'Mazmun',
      origin: 'Arapça (maḍmūn)',
      partOfSpeech: 'İsim',
      meaning: 'Klasik şiirde doğrudan söylenmeyip kalıplaşmış imgeler ve çağrışımlar aracılığıyla sezdirilen gizli, ince anlam.',
      example: '"Divan şiirini anlamak, kelimelerin ardındaki mazmun dünyasının anahtarını çözmektir."',
    ),
    'divan': const DictionaryEntry(
      word: 'Divan',
      origin: 'Farsça (dīvān)',
      partOfSpeech: 'İsim',
      meaning: '1. Klasik şairlerin şiirlerini belli bir tertip ve kafiye sırasına göre topladıkları eser. 2. Devlet işlerinin görüşüldüğü yüksek meclis.',
      example: '"Fuzûlî Divanı, Türkçe ve Farsça nüshalarıyla asırlardır elden düşmeyen bir hazinedir."',
    ),
    'kaside': const DictionaryEntry(
      word: 'Kaside',
      origin: 'Arapça (ḳaṣīde)',
      partOfSpeech: 'İsim',
      meaning: 'Belli bir maksatla (tevhid, münacat, naat veya övgü) aynı vezin ve kafiyede yazılan uzun klasik nazım biçimi.',
      example: '"Su Kasidesi, edebiyatımızda naat türünün erişilmez zirvesidir."',
    ),
    'gazel': const DictionaryEntry(
      word: 'Gazel',
      origin: 'Arapça (ġazel)',
      partOfSpeech: 'İsim',
      meaning: 'Aşk, güzellik, hikmet ve rindlik temalarını işleyen, genellikle 5 ila 15 beyitten oluşan lirik divan şiiri nazım biçimi.',
      example: '"Bâkî\'nin gazelleri, İstanbul Türkçesinin ses kudretini ve ahengini yansıtır."',
    ),
    'mesnevi': const DictionaryEntry(
      word: 'Mesnevi',
      origin: 'Arapça (mes̱nevī)',
      partOfSpeech: 'İsim',
      meaning: 'Her beyti kendi arasında kafiyeli olan, uzun hikaye, felsefi ve tasavvufi konuları anlatmaya elverişli klasik nazım biçimi.',
      example: '"Mevlânâ\'nın Mesnevi\'si ile Şeyh Galib\'in Hüsn ü Aşk\'ı bu türün şaheserleridir."',
    ),
    'rubai': const DictionaryEntry(
      word: 'Rubai',
      origin: 'Arapça (rubāʿī)',
      partOfSpeech: 'İsim',
      meaning: 'Kendine özgü 24 aruz kalıbıyla yazılan, dört mısrada derin bir felsefi veya tasavvufi düşünceyi yoğunlaştıran nazım biçimi.',
      example: '"Ömer Hayyam ve Yahya Kemal, rubai türünün farklı asırlardaki büyük ustalarıdır."',
    ),
    'beyit': const DictionaryEntry(
      word: 'Beyit',
      origin: 'Arapça (beyt - ev)',
      partOfSpeech: 'İsim',
      meaning: 'Aynı ölçüde olan ve anlamca bir bütün oluşturan iki mısralık nazım birimi.',
      example: '"Klasik şair, bazen tek bir beyit içerisine koca bir insan ömrünün muhasebesini sığdırır."',
    ),
    'mısra': const DictionaryEntry(
      word: 'Mısra',
      origin: 'Arapça (miṣrāʿ - kapı kanadı)',
      partOfSpeech: 'İsim',
      meaning: 'Ölçülü ve ahenkli bir şiirin satırlarından her biri, dize.',
      example: '"Dilden dile dolaşan tek bir dizeye mısra-ı berceste denir."',
    ),
    'mahlas': const DictionaryEntry(
      word: 'Mahlas',
      origin: 'Arapça (maḫlaṣ)',
      partOfSpeech: 'İsim',
      meaning: 'Şairlerin asıl adları yerine şiirlerinin son beytinde (taç beyit) kullandıkları edebi takma ad.',
      example: '"Kanuni Sultan Süleyman, gazellerinde Muhibbî mahlasını kullanmıştır."',
    ),
    'nazire': const DictionaryEntry(
      word: 'Nazire',
      origin: 'Arapça (naẓīre)',
      partOfSpeech: 'İsim',
      meaning: 'Bir şairin beğenilen bir şiirine, başka bir şair tarafından aynı vezin ve kafiyede saygı ve sanat yarışıyla yazılan karşılık şiir.',
      example: '"Nazire geleneği, şairler arasında asırlar süren canlı bir edebi mektep oluşturmuştur."',
    ),
    'lugat': const DictionaryEntry(
      word: 'Lügat',
      origin: 'Arapça (luġat)',
      partOfSpeech: 'İsim',
      meaning: 'Bir dilin kelimelerini, kökenlerini ve anlam inceliklerini açıklayan sözlük; kelam ve dil.',
      example: '"Lügat okumak, bir milletin hafıza sarayında odadan odaya gezinmektir."',
    ),
    'lügat': const DictionaryEntry(
      word: 'Lügat',
      origin: 'Arapça (luġat)',
      partOfSpeech: 'İsim',
      meaning: 'Bir dilin kelimelerini, kökenlerini ve anlam inceliklerini açıklayan sözlük; kelam ve dil.',
      example: '"Lügat okumak, bir milletin hafıza sarayında odadan odaya gezinmektir."',
    ),
    'kamus': const DictionaryEntry(
      word: 'Kamus',
      origin: 'Arapça (ḳāmūs - okyanus)',
      partOfSpeech: 'İsim',
      meaning: 'Denizin en derin yeri, okyanus; bir dilin bütün kelime hazinesini kuşatan büyük ve kapsamlı sözlük, ansiklopedik lügat.',
      example: '"Şemseddin Sami\'nin Kamus-ı Türkî\'si modern Türk sözlükçülüğünün temel taşıdır."',
    ),
    'etimoloji': const DictionaryEntry(
      word: 'Etimoloji',
      origin: 'Fransızca / Yunanca (étymologie)',
      partOfSpeech: 'İsim',
      meaning: 'Kelimelerin tarihsel köklerini, ses ve anlam dönüşümlerini inceleyen köken bilimi, ilm-i iştikak.',
      example: '"Bir kelimenin etimolojisini bilmek, kavramın ilk doğduğu zihin dünyasına inmektir."',
    ),
    'iştikak': const DictionaryEntry(
      word: 'İştikak',
      origin: 'Arapça (iştiḳāḳ)',
      partOfSpeech: 'İsim',
      meaning: '1. Aynı kökten yeni kelimeler türetme, türeme bilimi (etimoloji). 2. Edebiyatta aynı kökten türemiş kelimeleri bir arada kullanma sanatı.',
      example: '"İlim, alim, malum ve muallim kelimeleri aynı kökten iştikak etmiştir."',
    ),

    // --- Felsefe, Mantık, Epistemoloji ve Ahlak Felsefesi ---
    'mantık': const DictionaryEntry(
      word: 'Mantık',
      origin: 'Arapça (manṭıḳ)',
      partOfSpeech: 'İsim',
      meaning: 'Zihni yanlış düşünmekten koruyan, doğru düşünmenin ve sağlam çıkarım yapmanın ilkelerini inceleyen ilim ve disiplin.',
      example: '"Gazzâlî\'ye göre mantık bilmeyenin ilmine güven olmaz."',
    ),
    'kıyas': const DictionaryEntry(
      word: 'Kıyas',
      origin: 'Arapça (ḳıyās)',
      partOfSpeech: 'İsim',
      meaning: 'Bilinen öncüllerden veya hükümlerden hareketle bilinmeyen bir sonuca zorunlu ve kurallı olarak ulaşma, tasım, analoji.',
      example: '"Kıyas, iki önermeden üçüncü ve yeni bir hüküm çıkarma sanatıdır."',
    ),
    'burhan': const DictionaryEntry(
      word: 'Burhan',
      origin: 'Arapça (burhān)',
      partOfSpeech: 'İsim',
      meaning: 'Kesin ve şüphe götürmez öncüllere dayanan, zihinde tam bir kesinlik (yakîn) sağlayan mantıksal kanıt, apodiktik delil.',
      example: '"Felsefi araştırmanın nihai hedefi zan değil, sarsılmaz burhandır."',
    ),
    'cedel': const DictionaryEntry(
      word: 'Cedel',
      origin: 'Arapça (cedel)',
      partOfSpeech: 'İsim',
      meaning: 'Genel kabul gören önermelerden hareketle muhatabı ikna etmeyi veya tezini çürütmeyi amaçlayan tartışma sanatı, diyalektik.',
      example: '"Hakikati arayan müzakere ile üstün gelmeyi arayan cedel birbirinden farklıdır."',
    ),
    'ontoloji': const DictionaryEntry(
      word: 'Ontoloji',
      origin: 'Yunanca (ontologia)',
      partOfSpeech: 'Felsefe',
      meaning: 'Varlığı varlık olması bakımından inceleyen, varoluşun temel kategorilerini ve mahiyetini sorgulayan felsefe dalı, varlık felsefesi.',
      example: '"İbn Sînâ\'nın zorunlu ve mümkün varlık ayrımı, ontoloji tarihinin dönüm noktasıdır."',
    ),
    'epistemoloji': const DictionaryEntry(
      word: 'Epistemoloji',
      origin: 'Yunanca (epistēmē + logos)',
      partOfSpeech: 'Felsefe',
      meaning: 'Bilginin kaynağını, doğasını, doğruluğunu, sınırlarını ve imkânını inceleyen felsefe disiplini, bilgi kuramı.',
      example: '"Epistemoloji, neyi nasıl bildiğimizi ve bilginin sanıdan farkını sorgular."',
    ),
    'hermeneutik': const DictionaryEntry(
      word: 'Hermeneutik',
      origin: 'Yunanca (hermēneutikē)',
      partOfSpeech: 'Felsefe',
      meaning: 'Metinlerin, sembollerin ve tarihsel-insani üretimlerin anlaşılması ve yorumlanması sanatı ve felsefi kuramı, yorumbilim.',
      example: '"Klasik şerh geleneği ile modern hermeneutik, metnin ufkuyla okurun ufkunu buluşturur."',
    ),
    'diyalektik': const DictionaryEntry(
      word: 'Diyalektik',
      origin: 'Yunanca (dialektikē)',
      partOfSpeech: 'Felsefe',
      meaning: 'Karşıt kavramların, tez ve antitezin çatışması ve uzlaşması (sentez) yoluyla düşüncenin ve gerçekliğin ilerlemesi yöntemi.',
      example: '"Sokrates\'in diyalogları, hakikati doğurtan diyalektik sorgulamanın ilk örnekleridir."',
    ),
    'paradigma': const DictionaryEntry(
      word: 'Paradigma',
      origin: 'Yunanca (paradeigma)',
      partOfSpeech: 'Felsefe',
      meaning: 'Belirli bir dönemde bilim veya düşünce topluluğunun dünyayı anlamlandırmak için paylaştığı temel kavramsal çerçeve ve değerler dizisi.',
      example: '"Kopernik ve Einstein, bilim tarihinde köklü paradigma değişimlerine yol açmıştır."',
    ),
    'dikotomi': const DictionaryEntry(
      word: 'Dikotomi',
      origin: 'Yunanca (dichotomia)',
      partOfSpeech: 'Felsefe',
      meaning: 'Bir bütünün birbirini dışlayan iki karşıt parçaya veya kategoriye bölünmesi, ikilik.',
      example: '"Ruh ve beden dikotomisi, modern felsefenin en çok tartıştığı meselelerden biridir."',
    ),
    'anakronizm': const DictionaryEntry(
      word: 'Anakronizm',
      origin: 'Yunanca (anachronismos)',
      partOfSpeech: 'Tarih / Felsefe',
      meaning: 'Tarihsel bir olayı, şahsiyeti veya metni, ait olduğu çağın şartları yerine başka bir dönemin kavram ve değerleriyle yargılama yanılgısı.',
      example: '"Eski metinleri bugünün ideolojik kalıplarıyla okumak ağır bir anakronizmdir."',
    ),
    'teleoloji': const DictionaryEntry(
      word: 'Teleoloji',
      origin: 'Yunanca (telos + logos)',
      partOfSpeech: 'Felsefe',
      meaning: 'Doğadaki ve evrendeki süreçlerin yalnızca mekanik nedenlerle değil, belirli bir gaye ve ereğe (telos) yönelmişlikle açıklanması öğretisi, erekbilim.',
      example: '"Aristoteles fiziğinde her varlık kendi doğal gayesine doğru teleolojik bir hareket içindedir."',
    ),
    'metafizik': const DictionaryEntry(
      word: 'Metafizik',
      origin: 'Yunanca (ta meta ta physika)',
      partOfSpeech: 'Felsefe',
      meaning: 'Duyularla algılanan fiziksel dünyanın ötesindeki ilk nedenleri, varlığı, ruhu ve mutlak hakikati inceleyen felsefe dalı, ilahiyat.',
      example: '"İnsanın anlam arayışı, fiziksel verilerin bittiği yerde metafizik sorularla derinleşir."',
    ),
    'estetik': const DictionaryEntry(
      word: 'Estetik',
      origin: 'Yunanca (aisthētikos)',
      partOfSpeech: 'Felsefe',
      meaning: 'Güzelliğin mahiyetini, sanat eserinin değerini ve insanın güzel karşısındaki duyuş ve yargılarını inceleyen felsefe alanı.',
      example: '"Klasik kitap sanatlarında estetik, fayda ile güzelliğin kusursuz birliğidir."',
    ),
    'etik': const DictionaryEntry(
      word: 'Etik',
      origin: 'Yunanca (ēthikē)',
      partOfSpeech: 'Felsefe',
      meaning: 'İyi, doğru, ödev ve erdem kavramlarını sorgulayan, insan eylemlerinin ahlaki temellerini araştıran ahlak felsefesi, ilm-i ahlak.',
      example: '"Kınalızâde Ali Efendi\'nin Ahlâk-ı Alâî eseri, klasik etik düşüncemizin zirvesidir."',
    ),
    'fazilet': const DictionaryEntry(
      word: 'Fazilet',
      origin: 'Arapça (faḍīlet)',
      partOfSpeech: 'İsim',
      meaning: 'İnsanı ruhen yükselten, aşırılıklardan uzak dengeli karakter olgunluğu, erdem.',
      example: '"Fârâbî\'ye göre erdemli şehrin (el-Medînetü\'l-Fâzıla) temeli yardımlaşma ve fazilettir."',
    ),
    'adalet': const DictionaryEntry(
      word: 'Adalet',
      origin: 'Arapça (ʿadālet)',
      partOfSpeech: 'İsim',
      meaning: 'Her şeye ve herkese hakkını verme, her şeyi layık olduğu yere koyma, zulmün zıddı olan en üstün erdem ve denge.',
      example: '"Adalet mülkün ve toplumsal nizamın sarsılmaz temelidir."',
    ),
    'ihsan': const DictionaryEntry(
      word: 'İhsan',
      origin: 'Arapça (iḥsān)',
      partOfSpeech: 'İsim',
      meaning: '1. Bir işi en güzel, en kusursuz ve içten biçimde yapma şuuru. 2. Karşılık beklemeden yapılan iyilik ve lütuf.',
      example: '"Adalet hakkı teslim etmektir; ihsan ise hakkından fazlasını gönülden ikram etmektir."',
    ),
    'itidal': const DictionaryEntry(
      word: 'İtidal',
      origin: 'Arapça (iʿtidāl)',
      partOfSpeech: 'İsim',
      meaning: 'İfrat (aşırılık) ile tefrit (eksiklik) arasındaki altın orta; duygu, düşünce ve eylemde ölçülülük ve soğukkanlılık.',
      example: '"Kriz anlarında itidalini koruyan akıl, en doğru çıkış yolunu bulur."',
    ),
    'şecaat': const DictionaryEntry(
      word: 'Şecaat',
      origin: 'Arapça (şecāʿat)',
      partOfSpeech: 'İsim',
      meaning: 'Korkaklık ile saldırganlık arasındaki dengeli yüreklilik, hakikat ve adalet uğrunda gösterilen medeni ve ruhi cesaret.',
      example: '"Ahlak ilminde öfke gücünün itidaliyle ortaya çıkan erdeme şecaat denir."',
    ),
    'iffet': const DictionaryEntry(
      word: 'İffet',
      origin: 'Arapça (ʿiffet)',
      partOfSpeech: 'İsim',
      meaning: 'Arzu ve tutkuları aklın ve ahlakın ölçüsüyle dizginleme, nefsi bayağılıklardan koruma, ruh ve beden temizliği.',
      example: '"Hikmet, şecaat ve iffet birleştiğinde ruhta adalet erdemi tezahür eder."',
    ),

    // --- Tarih, Medeniyet, Hukuk ve İslami İlimler ---
    'vakıf': const DictionaryEntry(
      word: 'Vakıf',
      origin: 'Arapça (vaḳf)',
      partOfSpeech: 'İsim',
      meaning: 'Bir mülkü veya geliri, alınıp satılmamak kaydıyla ebediyen kamu yararına, ilme ve hayır hizmetlerine tahsis etme kurumu.',
      example: '"Osmanlıda kütüphanelerden darüşşifalara kadar bütün ilim yuvaları vakıf ruhuyla yaşatılmıştır."',
    ),
    'medrese': const DictionaryEntry(
      word: 'Medrese',
      origin: 'Arapça (medrese)',
      partOfSpeech: 'İsim',
      meaning: 'Ders okunan yer; İslam medeniyetinde aklî ve naklî ilimlerin tahsil edildiği yükseköğretim kurumu.',
      example: '"Sahn-ı Seman ve Süleymaniye medreseleri, çağının en seçkin alimlerini yetiştirmiştir."',
    ),
    'darüşşifa': const DictionaryEntry(
      word: 'Darüşşifa',
      origin: 'Arapça (dāru’ş-şifāʾ)',
      partOfSpeech: 'İsim',
      meaning: 'Şifa evi; beden ve ruh hastalıklarının su sesi, musiki ve tıbbi yöntemlerle ücretsiz tedavi edildiği tarihi hastane.',
      example: '"Edirne Darüşşifası\'nda hastalar musiki makamlarıyla tedavi edilirdi."',
    ),
    'külliye': const DictionaryEntry(
      word: 'Külliye',
      origin: 'Arapça (kulliyye)',
      partOfSpeech: 'İsim',
      meaning: 'Merkezinde cami olmak üzere medrese, kütüphane, darüşşifa, imaret ve hamam gibi yapıların oluşturduğu sosyal ve ilmi mimari bütünlük.',
      example: '"Mimar Sinan\'ın külliyeleri, şehrin hem siluetini hem de ilim ve yardımlaşma hayatını kurar."',
    ),
    'silsile': const DictionaryEntry(
      word: 'Silsile',
      origin: 'Arapça (silsile)',
      partOfSpeech: 'İsim',
      meaning: 'Birbirine halka halka bağlı zincir; ilim, sanat veya tasavvufta bilginin hocadan talebeye kesintisiz aktarım soykütüğü.',
      example: '"İlimde silsile, bilginin sahih kaynaklardan süzülerek geldiğinin teminatıdır."',
    ),
    'rivayet': const DictionaryEntry(
      word: 'Rivayet',
      origin: 'Arapça (rivāyet)',
      partOfSpeech: 'İsim',
      meaning: 'Bir haberi, tarihi olayı veya hadisi kaynağına dayandırarak nakletme, aktarma.',
      example: '"Tarihçi, muhtelif rivayetleri bir araya getirip tenkit süzgecinden geçirir."',
    ),
    'dirayet': const DictionaryEntry(
      word: 'Dirayet',
      origin: 'Arapça (dirāyet)',
      partOfSpeech: 'İsim',
      meaning: 'Yalnızca nakille yetinmeyip akıl yürütme, derin kavrayış ve muhakeme gücüyle meseleleri çözme yeteneği.',
      example: '"Rivayet ilmi hafızayı, dirayet ilmi ise muhakeme ve terkip kudretini gerektirir."',
    ),
    'sahih': const DictionaryEntry(
      word: 'Sahih',
      origin: 'Arapça (ṣaḥīḥ)',
      partOfSpeech: 'Sıfat',
      meaning: 'Doğruluğu, güvenilirliği ve sıhhati kusursuz biçimde tespit edilmiş olan, sağlam, gerçek.',
      example: '"Metin neşrinde sahih nüshayı tespit etmek araştırmacının ilk vazifesidir."',
    ),
    'tevatür': const DictionaryEntry(
      word: 'Tevatür',
      origin: 'Arapça (tevātur)',
      partOfSpeech: 'İsim',
      meaning: 'Yalan üzerine birleşmeleri aklen imkânsız olan büyük bir topluluğun nesilden nesile aktardığı kesin haber.',
      example: '"Tarihi şehirlerin varlığı ve kurucu metinler bize tevatür yoluyla kesin olarak ulaşmıştır."',
    ),
    'icma': const DictionaryEntry(
      word: 'İcma',
      origin: 'Arapça (icmāʿ)',
      partOfSpeech: 'İsim',
      meaning: 'Bir çağdaki yetkin alimlerin ve uzmanların bir mesele veya hüküm üzerinde görüş birliğine varması, konsensüs.',
      example: '"İlim ehlinin icması, ferdi kanaatlerin ötesinde ortak bir güven zemini oluşturur."',
    ),
    'içtihat': const DictionaryEntry(
      word: 'İçtihat',
      origin: 'Arapça (ictihād)',
      partOfSpeech: 'İsim',
      meaning: 'Yetkin bir alimin veya hukukçunun, temel ilkelerden ve kaynaklardan hareketle yeni meselelere çözüm üretmek için bütün zihni gücünü harcaması.',
      example: '"Çağın değişen meseleleri, sağlam usule dayalı taze içtihatlarla çözülür."',
    ),
    'fetva': const DictionaryEntry(
      word: 'Fetva',
      origin: 'Arapça (fetvā)',
      partOfSpeech: 'İsim',
      meaning: 'Hukuki veya dini bir müşkül hakkında şeyhülislam ya da müftü tarafından usulüne uygun olarak verilen açıklayıcı hüküm ve görüş.',
      example: '"Ebussuud Efendi\'nin fetvaları, örfi hukuk ile şer\'i hukuku ustalıkla telif etmiştir."',
    ),
    'kanunname': const DictionaryEntry(
      word: 'Kanunname',
      origin: 'Arapça / Farsça (ḳānūn-nāme)',
      partOfSpeech: 'İsim',
      meaning: 'Devlet idaresi, maliye, toprak rejimi ve ceza hukukuna dair padişah fermanıyla yürürlüğe konulan kanunların toplandığı mecmua.',
      example: '"Kanuni Sultan Süleyman\'ın kanunnamesi, devlet nizamının hukuki omurgasını oluşturmuştur."',
    ),
    'adaletname': const DictionaryEntry(
      word: 'Adaletname',
      origin: 'Arapça / Farsça (ʿadālet-nāme)',
      partOfSpeech: 'İsim',
      meaning: 'Halkı yöneticilerin ve memurların olası zulmünden ve keyfi uygulamalarından korumak üzere padişahların yayınladığı adalet fermanı.',
      example: '"Adaletnameler, reayanın haklarını güvence altına alan tarihi insan hakları belgeleridir."',
    ),
    'siyasetname': const DictionaryEntry(
      word: 'Siyasetname',
      origin: 'Arapça / Farsça (siyāset-nāme)',
      partOfSpeech: 'İsim',
      meaning: 'Devlet yöneticilerine adaletli yönetim ilkelerini, hikmet-i hükümeti ve siyasi ahlakı anlatan klasik eser türü.',
      example: '"Nizamülmülk\'ün Siyasetname\'si ile Kutadgu Bilig, siyaset felsefemizin şaheserleridir."',
    ),
    'seyahatname': const DictionaryEntry(
      word: 'Seyahatname',
      origin: 'Arapça / Farsça (seyāḥat-nāme)',
      partOfSpeech: 'İsim',
      meaning: 'Bir seyyahın gezdiği şehirlerin coğrafyasını, mimarisini, insanlarını ve kültürünü gözlemleriyle anlattığı edebi ve tarihi eser.',
      example: '"Evliya Çelebi\'nin on ciltlik Seyahatname\'si, eşsiz bir kültür ve şehir ansiklopedisidir."',
    ),
    'sefaretname': const DictionaryEntry(
      word: 'Sefaretname',
      origin: 'Arapça / Farsça (sefāret-nāme)',
      partOfSpeech: 'İsim',
      meaning: 'Yabancı ülkelere gönderilen Osmanlı elçilerinin (sefirlerin) o ülkenin siyasi, ilmi ve sosyal durumuna dair kaleme aldıkları gözlem raporu.',
      example: '"Yirmisekiz Çelebi Mehmed Efendi\'nin Paris Sefaretnamesi matbaanın kuruluşuna ilham vermiştir."',
    ),
    'tezkire': const DictionaryEntry(
      word: 'Tezkire',
      origin: 'Arapça (teẕkire)',
      partOfSpeech: 'İsim',
      meaning: '1. Şairlerin, hattatların, alimlerin veya velilerin hayat hikayelerini ve eserlerinden örnekleri bir araya getiren biyografik ansiklopedi. 2. Resmi pusula.',
      example: '"Latîfî ve Âşık Çelebi tezkireleri, klasik edebiyat tarihimizin en canlı kaynaklarıdır."',
    ),
    'vakanüvis': const DictionaryEntry(
      word: 'Vakanüvis',
      origin: 'Arapça / Farsça (vaḳʿa-nüvīs)',
      partOfSpeech: 'İsim',
      meaning: 'Osmanlı Devleti\'nde dönemin tarihi olaylarını resmi belgelere dayanarak günü gününe kaydetmekle görevlendirilen resmi devlet tarihçisi.',
      example: '"Mustafa Naima Efendi\'den Ahmed Cevdet Paşa\'ya uzanan vakanüvis geleneği muazzam bir tarih mirası bırakmıştır."',
    ),
    'kronik': const DictionaryEntry(
      word: 'Kronik',
      origin: 'Fransızca / Yunanca (chronique)',
      partOfSpeech: 'İsim',
      meaning: 'Tarihi olayları meydana geliş sırasına (kronolojik düzene) göre kaydeden tarih eseri, vakayiname.',
      example: '"Erken dönem Osmanlı kronikleri, kuruluş asrının ruhunu yalın bir dille aktarır."',
    ),
    'arşiv': const DictionaryEntry(
      word: 'Arşiv',
      origin: 'Fransızca / Yunanca (archives)',
      partOfSpeech: 'İsim',
      meaning: 'Devletlerin, kurumların veya kişilerin faaliyetleri sonucu oluşan tarihi ve hukuki belgelerin muhafaza edildiği hazine-i evrak.',
      example: '"Milyonlarca belgeyi barındıran Osmanlı arşivi, üç kıtanın ortak hafızasıdır."',
    ),
    'sicil': const DictionaryEntry(
      word: 'Sicil',
      origin: 'Arapça (sicill)',
      partOfSpeech: 'İsim',
      meaning: 'Mahkeme kararlarının, vakfiyelerin, fermanların veya görevlilerin hal tercümelerinin kaydedildiği resmi kütük defteri.',
      example: '"Şer\'iyye sicilleri, bir şehrin gündelik hayatını ve hukuk kültürünü en ince ayrıntısına kadar gösterir."',
    ),
    'tımar': const DictionaryEntry(
      word: 'Tımar',
      origin: 'Farsça (tīmār)',
      partOfSpeech: 'İsim',
      meaning: '1. Özenle bakma, koruma. 2. Osmanlıda toprağın mülkiyeti devlette kalmak üzere vergi gelirinin hizmet karşılığı sipahilere tahsis edildiği toprak sistemi.',
      example: '"Tahrir defterleri, tımar sisteminin adil ve düzenli işlemesini sağlayan temel kayıtlardı."',
    ),
    'reaya': const DictionaryEntry(
      word: 'Reaya',
      origin: 'Arapça (reʿāyā)',
      partOfSpeech: 'İsim',
      meaning: 'Hükümdarın adaletle koruyup gözetmekle yükümlü olduğu, üretim yapan ve vergi veren halk tabakası, tebaa (Vedia-i İlahi).',
      example: '"Klasik devlet anlayışında reaya, yöneticiye Allah\'ın bir emaneti olarak görülürdü."',
    ),
    'ulema': const DictionaryEntry(
      word: 'Ulema',
      origin: 'Arapça (ʿulemāʾ)',
      partOfSpeech: 'İsim',
      meaning: 'Alimler; medrese tahsili görmüş, ilim, eğitim ve yargı (kadılık) hizmetlerini yürüten bilginler zümresi.',
      example: '"Ulema meclislerinde yapılan ilmi münazaralar, fikir hayatının dinamizmini korurdu."',
    ),
    'ümera': const DictionaryEntry(
      word: 'Ümera',
      origin: 'Arapça (umerāʾ)',
      partOfSpeech: 'İsim',
      meaning: 'Emirler; devlet yönetiminde ve orduda üst düzey görev ve sorumluluk taşıyan beyler, sancakbeyleri ve beylerbeyleri.',
      example: '"Devletin selameti, ulema ile ümeranın adalet ve hikmet ekseninde uyumuna bağlıydı."',
    ),
    'kalemiye': const DictionaryEntry(
      word: 'Kalemiye',
      origin: 'Arapça (ḳalemiyye)',
      partOfSpeech: 'İsim',
      meaning: 'Osmanlı devlet teşkilatında yazışma, diplomasi, maliye ve tahrir kayıtlarını yürüten sivil bürokrasi sınıfı (ehli kalem).',
      example: '"Nişancı, reisülküttap ve defterdar, kalemiye sınıfının en üst temsilcileriydi."',
    ),
    'seyfiye': const DictionaryEntry(
      word: 'Seyfiye',
      origin: 'Arapça (seyfiyye)',
      partOfSpeech: 'İsim',
      meaning: 'Kılıç ehli; devletin yürütme, savunma ve güvenlik işlerini üstlenen askeri ve idari yönetici sınıfı (ehl-i örf).',
      example: '"Seyfiye, ilmiye ve kalemiye saçayağı, klasik devlet nizamının dengesini kurmuştur."',
    ),
    'ilmiye': const DictionaryEntry(
      word: 'İlmiye',
      origin: 'Arapça (ʿilmiyye)',
      partOfSpeech: 'İsim',
      meaning: 'İlim ehli; eğitim (müderrislik), yargı (kadılık) ve fetva (müftülük) kurumlarını çatısı altında toplayan alimler teşkilatı.',
      example: '"İlmiye sınıfı, hukukun üstünlüğünü ve bilginin bağımsızlığını temsil ederdi."',
    ),

    // --- Kutadgu Bilig ve Eski Türk Düşünce Dünyası ---
    'kutadgu': const DictionaryEntry(
      word: 'Kutadgu',
      origin: 'Eski Türkçe (kut + ad + gu)',
      partOfSpeech: 'Sıfat',
      meaning: 'Kutlu kılan, iki dünyada saadet ve mutluluk veren, devlet ve baht kazandıran.',
      example: '"Yusuf Has Hâcib\'in 1069\'da tamamladığı Kutadgu Bilig, mutluluk veren bilgi demektir."',
    ),
    'bilig': const DictionaryEntry(
      word: 'Bilig',
      origin: 'Eski Türkçe (bil-ig)',
      partOfSpeech: 'İsim',
      meaning: 'Bilgi, hikmet, akıl ve kavrayış; insanı cehaletten kurtarıp erdeme ulaştıran irfan.',
      example: '"Bilig bil, kişi bol: Bilgi edin ve kâmil bir insan ol."',
    ),
    'töre': const DictionaryEntry(
      word: 'Töre',
      origin: 'Eski Türkçe (törü)',
      partOfSpeech: 'İsim',
      meaning: 'Toplumu ve devleti ayakta tutan adil kanun, nizam, ahlaki ve hukuki ilkeler bütünü.',
      example: '"İl gider töre kalır; adaletle kurulan töre devletin ruhudur."',
    ),
    'kut': const DictionaryEntry(
      word: 'Kut',
      origin: 'Eski Türkçe (kut)',
      partOfSpeech: 'İsim',
      meaning: 'İlahi lütuf, saadet, bereket, ruhsal olgunluk ve adaletle hükmetme yetkisi.',
      example: '"Kut, kibir ve zulümle elden gider; adalet, tevazu ve doğrulukla kalıcı olur."',
    ),
    'küntogdı': const DictionaryEntry(
      word: 'Küntogdı',
      origin: 'Eski Türkçe (Kün-Togdı)',
      partOfSpeech: 'Özel İsim / Sembol',
      meaning: 'Gündoğdu; Kutadgu Bilig\'de doğruluk, kanun ve adaleti (Köni Törü) temsil eden hükümdar.',
      example: '"Hükümdar Küntogdı, güneş gibi herkese eşit doğan şaşmaz adaletin timsalidir."',
    ),
    'aytoldı': const DictionaryEntry(
      word: 'Aytoldı',
      origin: 'Eski Türkçe (Ay-Toldı)',
      partOfSpeech: 'Özel İsim / Sembol',
      meaning: 'Dolunay; Kutadgu Bilig\'de kut, devlet ve saadeti temsil eden vezir.',
      example: '"Aytoldı, tıpkı ayın halleri gibi dünya saadetinin değişkenliğini ve hikmetle korunması gerektiğini simgeler."',
    ),
    'ögdülmiş': const DictionaryEntry(
      word: 'Ögdülmiş',
      origin: 'Eski Türkçe (Ögdülmiş - övülmüş)',
      partOfSpeech: 'Özel İsim / Sembol',
      meaning: 'Övülmüş; Kutadgu Bilig\'de aklı (Ukuş) ve ilmi temsil eden bilge vezir oğlu.',
      example: '"Ögdülmiş, devleti ve insanı aydınlatan selim aklın tükenmez rehberliğidir."',
    ),
    'odgurmış': const DictionaryEntry(
      word: 'Odgurmış',
      origin: 'Eski Türkçe (Odgurmış - uyanmış)',
      partOfSpeech: 'Özel İsim / Sembol',
      meaning: 'Gafletten uyanmış, kalp gözü açılmış; Kutadgu Bilig\'de kanaati, zühdü ve akıbeti (insanın nihai sorumluluğunu) temsil eden bilge zahid.',
      example: '"Ögdülmiş ile Odgurmış\'ın mektuplaşmaları, dünya imarı ile ahiret bilincinin derin muhasebesidir."',
    ),

    // --- İlmi Müzakere, Muhakeme ve Klasik Bağlaçlar / İfadeler ---
    'müstakil': const DictionaryEntry(
      word: 'Müstakil',
      origin: 'Arapça (mustaḳill)',
      partOfSpeech: 'Sıfat',
      meaning: 'Başlı başına, bağımsız, başka bir şeye tabi olmadan kendi bütünlüğüne sahip olan.',
      example: '"Müellif bu meseleyi şerhin içinde geçiştirmeyip müstakil bir risalede ele almıştır."',
    ),
    'müktesebat': const DictionaryEntry(
      word: 'Müktesebat',
      origin: 'Arapça (muktesebāt)',
      partOfSpeech: 'İsim',
      meaning: 'Yıllar süren okuma, çalışma ve tecrübe sonucunda kazanılmış bilgi ve kültür birikimi.',
      example: '"Zengin bir müktesebat, okurun yeni metinler arasındaki gizli bağları görmesini sağlar."',
    ),
    'müzakere': const DictionaryEntry(
      word: 'Müzakere',
      origin: 'Arapça (muẕākere)',
      partOfSpeech: 'İsim',
      meaning: 'Bir ilmi meseleyi veya okunan metni karşılıklı fikir alışverişiyle derinlemesine konuşup tahlil etme.',
      example: '"İlim, yalnız okumakla değil; ehliyle yapılan samimi müzakere ile zihinde kök salar."',
    ),
    'mütalaa': const DictionaryEntry(
      word: 'Mütalaa',
      origin: 'Arapça (muṭālaʿa)',
      partOfSpeech: 'İsim',
      meaning: 'Bir metni dikkatle, üzerinde düşünerek ve anlam katmanlarını yoklayarak inceleme, etüt etme.',
      example: '"Dersten önce metni mütalaa eden talebe, hocasının işaret ettiği incelikleri anında kavrar."',
    ),
    'müşahade': const DictionaryEntry(
      word: 'Müşahade',
      origin: 'Arapça (muşāhede)',
      partOfSpeech: 'İsim',
      meaning: '1. Bir olguyu bizzat gözlemleme, deney ve gözlem. 2. Tasavvufta hakikati kalp gözüyle temaşa etme.',
      example: '"Tabiat bilimleri dikkatli müşahade ile akli muhakemenin birleşiminden doğar."',
    ),
    'mukayese': const DictionaryEntry(
      word: 'Mukayese',
      origin: 'Arapça (muḳāyese)',
      partOfSpeech: 'İsim',
      meaning: 'İki veya daha fazla eseri, fikri ya da olguyu benzer ve farklı yönleriyle karşılaştırma.',
      example: '"Doğu ve Batı klasiklerini mukayese ederek okumak zihne evrensel bir ufuk kazandırır."',
    ),
    'muhakeme': const DictionaryEntry(
      word: 'Muhakeme',
      origin: 'Arapça (muḥākeme)',
      partOfSpeech: 'İsim',
      meaning: 'Aklı kullanarak delilleri tartma, fikirleri süzgeçten geçirerek sağlam bir yargıya varma, usavurma.',
      example: '"Hafıza malumatı saklar, muhakeme ise o malumattan hikmet üretir."',
    ),
    'müphemiyet': const DictionaryEntry(
      word: 'Müphemiyet',
      origin: 'Arapça (mubhemiyyet)',
      partOfSpeech: 'İsim',
      meaning: 'Kapalılık, belirsizlik, bir sözün veya durumun birden fazla yöne çekilebilecek şekilde muğlak kalması.',
      example: '"İyi bir şerh, metindeki müphemiyeti ortadan kaldırıp kavramları berraklaştırır."',
    ),
    'mündemiç': const DictionaryEntry(
      word: 'Mündemiç',
      origin: 'Arapça (mundemic)',
      partOfSpeech: 'Sıfat',
      meaning: 'Bir şeyin içinde dürülü, saklı ve içkin olarak bulunan, özünde yer alan.',
      example: '"Büyük bir ağacın bütün heybeti, küçücük bir tohumun içinde mündemiçtir."',
    ),
    'müteakip': const DictionaryEntry(
      word: 'Müteakip',
      origin: 'Arapça (muteʿāḳib)',
      partOfSpeech: 'Sıfat / Zarf',
      meaning: 'Bir şeyin hemen ardı sıra gelen, takip eden, akabinde.',
      example: '"Mukaddimeyi müteakip gelen ilk fasıl, eserin temel tezini ortaya koyar."',
    ),
    'binaenaleyh': const DictionaryEntry(
      word: 'Binaenaleyh',
      origin: 'Arapça (bināʾen ʿaleyh)',
      partOfSpeech: 'Bağlaç',
      meaning: 'Buna dayanarak, bundan dolayı, öyleyse, sonuç olarak.',
      example: '"Öncüllerimiz kesin olarak ispatlanmıştır; binaenaleyh vardığımız hüküm de zaruridir."',
    ),
    'mamafih': const DictionaryEntry(
      word: 'Mamafih',
      origin: 'Arapça (maʿa-mā-fīh)',
      partOfSpeech: 'Bağlaç',
      meaning: 'Bununla birlikte, böyle olmakla beraber, ne var ki.',
      example: '"Mesele ilk bakışta karmaşık görünür; mamafih temel kavramlar anlaşılınca düğüm çözülür."',
    ),
    'velhasıl': const DictionaryEntry(
      word: 'Velhasıl',
      origin: 'Arapça (ve’l-ḥāṣıl)',
      partOfSpeech: 'Bağlaç',
      meaning: 'Sözün kısası, özetle, uzun tartışmaların ardından ortaya çıkan netice şudur ki.',
      example: '"Velhasıl insan, okuduğu ve anladığı hakikatler nispetinde özgürleşir."',
    ),
    'hülasa': const DictionaryEntry(
      word: 'Hülasa',
      origin: 'Arapça (ḫulāṣa)',
      partOfSpeech: 'İsim / Zarf',
      meaning: 'Bir şeyin en saf özü, özeti, ana fikri; kısacası.',
      example: '"Müellif, yüz sayfalık tartışmanın hülasasını son paragrafta üç cümleyle toplamıştır."',
    ),
    'sadet': const DictionaryEntry(
      word: 'Sadet',
      origin: 'Arapça (ṣaded)',
      partOfSpeech: 'İsim',
      meaning: 'Üzerinde konuşulan asıl konu, maksat, esas mesele.',
      example: '"Tali tartışmaları geride bırakıp tekrar sadede gelelim."',
    ),
    'zinhar': const DictionaryEntry(
      word: 'Zinhar',
      origin: 'Farsça (zinhār)',
      partOfSpeech: 'Ünlem / Zarf',
      meaning: 'Sakın, asla, hiçbir surette, katiyen.',
      example: '"Bilmediğin bir hususta zinhar kesin hüküm vermeye kalkışma."',
    ),
    'behemehal': const DictionaryEntry(
      word: 'Behemehal',
      origin: 'Farsça / Arapça (be-heme-ḥāl)',
      partOfSpeech: 'Zarf',
      meaning: 'Her halükârda, ne olursa olsun, mutlaka, kesinlikle.',
      example: '"Hakikat arayışında kaynakların sıhhati behemehal tahkik edilmelidir."',
    ),
    'bilakis': const DictionaryEntry(
      word: 'Bilakis',
      origin: 'Arapça (bi’l-ʿaks)',
      partOfSpeech: 'Zarf',
      meaning: 'Tam tersine, aksine, sanılanın zıddına olarak.',
      example: '"Klasik eserler zihni geçmişe hapsetmez; bilakis geleceği kuracak derinliği kazandırır."',
    ),
    'aşikâr': const DictionaryEntry(
      word: 'Aşikâr',
      origin: 'Farsça (āşkār)',
      partOfSpeech: 'Sıfat',
      meaning: 'Apaçık, belli, gizli yanı olmayan, zahir.',
      example: '"Deliller ortaya konulunca meselenin hakikati herkes için aşikâr oldu."',
    ),
    'aşikar': const DictionaryEntry(
      word: 'Aşikâr',
      origin: 'Farsça (āşkār)',
      partOfSpeech: 'Sıfat',
      meaning: 'Apaçık, belli, gizli yanı olmayan, zahir.',
      example: '"Deliller ortaya konulunca meselenin hakikati herkes için aşikâr oldu."',
    ),
    'muamma': const DictionaryEntry(
      word: 'Muamma',
      origin: 'Arapça (muʿammā)',
      partOfSpeech: 'İsim',
      meaning: '1. Anlaşılması ve çözülmesi güç, sırlı mesele, gizem. 2. Divan edebiyatında bir ismi gizleyerek sorulan manzum bilmece.',
      example: '"İnsan ruhu, her okunuşta yeni bir katmanı açılan derin bir muammadır."',
    ),
    'sır': const DictionaryEntry(
      word: 'Sır',
      origin: 'Arapça (sirr)',
      partOfSpeech: 'İsim',
      meaning: 'Akılla ilk bakışta kavranamayan gizli hakikat, hikmetin en derin ve mahrem boyutu.',
      example: '"Her ilmin bir zahiri, bir de ehlinin vakıf olduğu ince bir sırrı vardır."',
    ),
    'tecelli': const DictionaryEntry(
      word: 'Tecelli',
      origin: 'Arapça (tecellī)',
      partOfSpeech: 'İsim',
      meaning: 'Gizli olan bir hakikatin, güzelliğin veya ilahi sıfatın görünür hale gelmesi, belirmesi, tezahür etmesi.',
      example: '"Sanat eseri, sanatçının ruhundaki güzellik idrakinin maddeye tecellisidir."',
    ),
    'tezahür': const DictionaryEntry(
      word: 'Tezahür',
      origin: 'Arapça (teẓāhur)',
      partOfSpeech: 'İsim',
      meaning: 'Ortaya çıkma, görünme, dış dünyaya yansıma, belirti.',
      example: '"Dildeki incelik, düşüncedeki berraklığın doğrudan bir tezahürüdür."',
    ),
    'tekâmül': const DictionaryEntry(
      word: 'Tekâmül',
      origin: 'Arapça (tekāmul)',
      partOfSpeech: 'İsim',
      meaning: 'Basitten mükemmele doğru aşama aşama olgunlaşma, gelişim, evrim ve kemâle erme süreci.',
      example: '"İnsanın fikri ve ahlaki tekâmülü, beşikten mezara dek süren bir yolculuktur."',
    ),
    'tekamül': const DictionaryEntry(
      word: 'Tekâmül',
      origin: 'Arapça (tekāmul)',
      partOfSpeech: 'İsim',
      meaning: 'Basitten mükemmele doğru aşama aşama olgunlaşma, gelişim, evrim ve kemâle erme süreci.',
      example: '"İnsanın fikri ve ahlaki tekâmülü, beşikten mezara dek süren bir yolculuktur."',
    ),
    'inhitat': const DictionaryEntry(
      word: 'İnhitat',
      origin: 'Arapça (inḥiṭāṭ)',
      partOfSpeech: 'İsim',
      meaning: 'Gücünü, canlılığını ve yüksek seviyesini kaybederek gerileme, çöküş, düşüş dönemi.',
      example: '"İbn Haldun, medeniyetlerin yükseliş ve inhitat sebeplerini asabiyet kavramıyla açıklar."',
    ),
    'inkılap': const DictionaryEntry(
      word: 'İnkılap',
      origin: 'Arapça (inḳilāb)',
      partOfSpeech: 'İsim',
      meaning: 'Bir halden başka bir hale köklü dönüşüm, yenilenme, devrim.',
      example: '"Matbaanın yaygınlaşması, bilginin dolaşımında büyük bir inkılap meydana getirmiştir."',
    ),
    'intibah': const DictionaryEntry(
      word: 'İntibah',
      origin: 'Arapça (intibāh)',
      partOfSpeech: 'İsim',
      meaning: 'Uykudan veya gafletten uyanma, farkındalık kazanma, fikri uyanış.',
      example: '"Namık Kemal\'in İntibah romanı, uyanış ve ibret teması üzerine kurulmuştur."',
    ),
    'rönesans': const DictionaryEntry(
      word: 'Rönesans',
      origin: 'Fransızca (renaissance - yeniden doğuş)',
      partOfSpeech: 'Tarih / Felsefe',
      meaning: 'Klasik mirasın yeniden keşfiyle bilim, sanat, felsefe ve edebiyatta yaşanan büyük kültürel uyanış ve yeniden doğuş.',
      example: '"Endülüs ve İslam dünyasından yapılan tercümeler, Avrupa Rönesans\'ının ateşleyici gücü olmuştur."',
    ),
    'hümanizma': const DictionaryEntry(
      word: 'Hümanizma',
      origin: 'Latince / Fransızca (humanisme)',
      partOfSpeech: 'Felsefe',
      meaning: 'İnsanın değerini, onurunu ve klasik edebi-felsefi metinlerin incelenmesini merkeze alan düşünce akımı, insancıllık.',
      example: '"Yunus Emre\'nin yaratılanı Yaratan\'dan ötürü seven irfanı, en derin gönül hümanizmasıdır."',
    ),
    // ---------------------------------------------------------------------------
    // KLASİK SİYASETNÂME, İSLAM HUKUKU, TARİH VE EDEBÎ METİN TERİMLERİ
    // (El-Ahkâmu's-Sultâniyye, Mukaddime, Kutadgu Bilig, Yunan Mezâlimi, Âdâb)
    // ---------------------------------------------------------------------------
    'imamet': const DictionaryEntry(
      word: 'İmâmet',
      origin: 'Arapça (imāmet - önderlik)',
      partOfSpeech: 'Kamu Hukuku / Kelâm',
      meaning: 'Din ve dünya işlerini tedbir etmek, adaleti tesis ve toplumu idare etmek üzere nübüvvete vekâleten kurulan devlet başkanlığı makamı; hilâfet.',
      example: '"İmâmet, dinin korunması ve dünya işlerinin adaletle yürütülmesi için konulmuş bir müessesedir."',
    ),
    'hilafet': const DictionaryEntry(
      word: 'Hilâfet',
      origin: 'Arapça (ḫilāfet - vekillik, halef olma)',
      partOfSpeech: 'Tarih / Kamu Hukuku',
      meaning: 'Hz. Peygamber\'den sonra İslam toplumunun dinî ve dünyevî idaresini üstlenme makamı; halifelik.',
      example: '"Hilâfet makamı, emanetin ehline tevdi edilmesi ve adaletin ikamesi esasına dayanır."',
    ),
    'halife': const DictionaryEntry(
      word: 'Halîfe',
      origin: 'Arapça (ḫalīfe)',
      partOfSpeech: 'İsim / Tarih',
      meaning: 'Birinin yerine geçen, vekâlet eden kimse; İslam devletinde kamu düzenini ve hukuku korumakla yükümlü devlet başkanı.',
      example: '"Adil halife, mazlumun hakkını zalimden alıncaya kadar kendi nefsine rahat yüzü göstermez."',
    ),
    'halef': const DictionaryEntry(
      word: 'Halef',
      origin: 'Arapça (ḫalef)',
      partOfSpeech: 'İsim',
      meaning: 'Bir makam, görev veya ilim halkasında kendisinden öncekinin (selefin) ardından gelip onun yerini alan kimse.',
      example: '"Selefin tecrübesini halefin gayretiyle birleştiren medeniyetler asırlarca ayakta kalır."',
    ),
    'selef': const DictionaryEntry(
      word: 'Selef',
      origin: 'Arapça (selef)',
      partOfSpeech: 'İsim',
      meaning: 'Bir görev, makam veya zaman diliminde kendisinden sonrakinden (haleften) önce gelip geçmiş olan kimse veya nesil.',
      example: '"Klasik âlimler, seleflerinin eserlerini şerh ve tahkik ederek ilim mirasını zenginleştirmiştir."',
    ),
    'nübüvvet': const DictionaryEntry(
      word: 'Nübüvvet',
      origin: 'Arapça (nübüvvet)',
      partOfSpeech: 'Kelâm / İsim',
      meaning: 'Peygamberlik makamı ve vazifesi; ilâhî vahyi insanlara tebliğ ve temsil etme görevi.',
      example: '"Nübüvvet, insanlığa hem ahlâkî kemâli hem de toplumsal adalet ölçülerini öğretmiştir."',
    ),
    'müessese': const DictionaryEntry(
      word: 'Müessese',
      origin: 'Arapça (müʾessese - tesis edilmiş yapı)',
      partOfSpeech: 'İsim / Sosyoloji',
      meaning: 'Toplumsal, hukuki veya idari bir ihtiyacı karşılamak üzere köklü kurallarla kurulmuş kurum, kuruluş.',
      example: '"Vakıf müessesesi, İslam medeniyetinde sosyal dayanışmanın belkemiğini oluşturmuştur."',
    ),
    'ictihad': const DictionaryEntry(
      word: 'İçtihat',
      origin: 'Arapça (ictihād - bütün gücünü sarf etme)',
      partOfSpeech: 'Hukuk / Fıkıh',
      meaning: 'Usul kurallarına dayanarak kaynaklardan hüküm çıkarma çabası; mahkemelerin ve hukuk âlimlerinin emsal teşkil eden görüşü.',
      example: '"Zamanın değişmesiyle ahkâmın tatbik keyfiyetinde yeni içtihatlara ihtiyaç duyulur."',
    ),
    'vaki': const DictionaryEntry(
      word: 'Vâki',
      origin: 'Arapça (vāḳiʿ - düşen, gerçekleşen)',
      partOfSpeech: 'Sıfat / İsim',
      meaning: 'Meydana gelen, vuku bulan, gerçekleşmiş olan, var olan hakikat.',
      example: '"Tarihte vâki olan hadiseleri kendi devrinin şartları içinde değerlendirmek gerekir."',
    ),
    'vacip': const DictionaryEntry(
      word: 'Vâcib',
      origin: 'Arapça (vācib - gerekli, bağlayıcı)',
      partOfSpeech: 'Fıkıh / Felsefe',
      meaning: 'Yapılması kesin ve bağlayıcı bir delille istenen, terk edilmesi caiz olmayan dini ve hukuki yükümlülük; zorunlu olan.',
      example: '"Toplumsal düzeni ve adaleti sağlayacak bir idarenin kurulması kamu hukuku bakımından vâcibdir."',
    ),
    'vacib': const DictionaryEntry(
      word: 'Vâcib',
      origin: 'Arapça (vācib)',
      partOfSpeech: 'Fıkıh / Felsefe',
      meaning: 'Yerine getirilmesi zorunlu ve bağlayıcı olan hüküm veya görev.',
      example: '"Emaneti ehline vermek ve adaletle hükmetmek her idareci üzerine vâcibdir."',
    ),
    'şeriat': const DictionaryEntry(
      word: 'Şerîat',
      origin: 'Arapça (şerīʿat - suya giden ana yol)',
      partOfSpeech: 'Hukuk / Din',
      meaning: 'İlahi emir, yasak ve ilkeler bütünü; İslam hukuk düzeni ve adalet yolu.',
      example: '"Şerîatın temel gayesi; canı, aklı, dini, nesli ve malı muhafaza etmektir."',
    ),
    'şeran': const DictionaryEntry(
      word: 'Şer\'an',
      origin: 'Arapça (şerʿan)',
      partOfSpeech: 'Zarf / Hukuk',
      meaning: 'İslam hukuku (şerîat) kurallarına ve dinî hükümlere göre, hukuk nazarında.',
      example: '"Bir akdin şer\'an geçerli olması için tarafların serbest irade ve rızası şarttır."',
    ),
    'aklen': const DictionaryEntry(
      word: 'Aklen',
      origin: 'Arapça (ʿaḳlen)',
      partOfSpeech: 'Zarf / Felsefe',
      meaning: 'Akıl yürütme, mantık ilkeleri ve muhakeme bakımından; aklın gereği olarak.',
      example: '"İnsanların bir arada yaşarken ortak bir düzene muhtaç olduğu aklen de sabittir."',
    ),
    'akıl': const DictionaryEntry(
      word: 'Akıl',
      origin: 'Arapça (ʿaḳl - bağlama, kavrama)',
      partOfSpeech: 'İsim / Felsefe',
      meaning: 'İnsanın eşyanın hakikatini kavrama, düşünme, doğru ile yanlışı ayırt etme ve muhakeme kurma melekesi.',
      example: '"Akıl, ilmin kandili; tecrübe ise o kandilin yağıdır."',
    ),
    'zulüm': const DictionaryEntry(
      word: 'Zulüm',
      origin: 'Arapça (ẓulm - bir şeyi yerinden başka yere koyma)',
      partOfSpeech: 'İsim / Ahlâk',
      meaning: 'Adaletten sapma, haksızlık etme, başkasının hakkını gasp etme ve sınırı aşma.',
      example: '"Mülk küfür ile belki durur; lâkin zulüm ile asla payidar olmaz."',
    ),
    'zalim': const DictionaryEntry(
      word: 'Zâlim',
      origin: 'Arapça (ẓālim)',
      partOfSpeech: 'Sıfat / İsim',
      meaning: 'Adaleti terk edip haksızlık ve baskı yapan, hak sahiplerinin hakkını çiğneyen kimse.',
      example: '"Mazlumun ahı, zalimin tahtını er ya da geç sarsar."',
    ),
    'mazlum': const DictionaryEntry(
      word: 'Mazlum',
      origin: 'Arapça (maẓlūm)',
      partOfSpeech: 'Sıfat / İsim',
      meaning: 'Zulme ve haksızlığa uğramış, hakkı elinden alınmış kimse.',
      example: '"Adalet divanının ilk vazifesi mazlumun imdadına yetişmektir."',
    ),
    'mezalim': const DictionaryEntry(
      word: 'Mezâlim',
      origin: 'Arapça (meẓālim - maẓlime\'nin çoğulu)',
      partOfSpeech: 'İsim / Tarih',
      meaning: 'Zulümler, haksızlıklar, kıyımlar; klasik İslam devletlerinde üst düzey görevlilerin haksızlıklarını denetleyen yüksek adalet divanı (Dîvân-ı Mezâlim).',
      example: '"Dîvân-ı Mezâlim, güçlülerin zayıflar üzerindeki tahakkümünü kırmak için kurulmuş en yüksek yargı merciidir."',
    ),
    'bertaraf': const DictionaryEntry(
      word: 'Bertaraf',
      origin: 'Farsça (ber-ṭaraf - bir yana bırakılmış)',
      partOfSpeech: 'İsim / Zarf',
      meaning: 'Ortadan kaldırma, giderme, savuşturma, etkisiz hale getirme.',
      example: '"Toplumdaki ihtilafları adaletle bertaraf etmek huzurun temel şartıdır."',
    ),
    'mani': const DictionaryEntry(
      word: 'Mâni',
      origin: 'Arapça (māniʿ - engelleyen)',
      partOfSpeech: 'İsim / Hukuk',
      meaning: 'Bir şeyin gerçekleşmesini önleyen engel, حائل; hukukta bir hükmün doğmasına engel olan sebep.',
      example: '"İlim yolunda sebat eden kimse için hiçbir güçlük aşılmaz bir mâni değildir."',
    ),
    'cahiliye': const DictionaryEntry(
      word: 'Câhiliye',
      origin: 'Arapça (cāhiliyyet)',
      partOfSpeech: 'Tarih / Sosyoloji',
      meaning: 'İslamiyet\'ten önce Arap yarımadasında kabile عصbiyeti, kan davaları ve hukuksuzlukla karakterize edilen dönem; bilgisizlik ve taşkınlık hali.',
      example: '"Câhiliye devrinin kabile üstünlüğü anlayışı, yerini takva ve hukuk eşitliğine bırakmıştır."',
    ),
    'cahiliyet': const DictionaryEntry(
      word: 'Câhiliyet',
      origin: 'Arapça (cāhiliyyet)',
      partOfSpeech: 'Tarih / İsim',
      meaning: 'Hakikatten, hukuk ve faziletten uzaklaşarak kaba kuvvet ve taassupla hareket etme durumu.',
      example: '"Adaletin olmadığı yerde câhiliyet adetleri yeniden baş gösterir."',
    ),
    'sefih': const DictionaryEntry(
      word: 'Sefîh',
      origin: 'Arapça (sefīh - hafif akıllı, savurgan)',
      partOfSpeech: 'Sıfat / Hukuk',
      meaning: 'Malını ve imkânlarını akıl ve hikmet ölçülerine aykırı biçimde saçıp savuran, zevk ve eğlenceye düşkün, muhakemesi zayıf kimse.',
      example: '"Klasik fıkıhta sefîhin kendi malını telef etmesini önlemek için hacir (kısıtlama) hükümleri uygulanır."',
    ),
    'sürur': const DictionaryEntry(
      word: 'Sürûr',
      origin: 'Arapça (surūr)',
      partOfSpeech: 'İsim',
      meaning: 'Kalpte duyulan derin sevinç, neşe, ferahlık ve mutluluk.',
      example: '"Hakikatin ortaya çıkması, ilim ehlinin gönlüne tarifsiz bir sürûr verir."',
    ),
    'beyat': const DictionaryEntry(
      word: 'Bey\'at (Biat)',
      origin: 'Arapça (beyʿat - el sıkışarak sözleşme)',
      partOfSpeech: 'Kamu Hukuku / Tarih',
      meaning: 'Seçiciler kurulunun (ehl-i hal ve\'l-akd) ve halkın, devlet başkanının hukuka uygun idaresine bağlılık bildirdiği karşılıklı siyasi-hukuki sözleşme.',
      example: '"Bey\'at, yöneten ile yönetilen arasında adalet ve sadakat şartına bağlı bir kamu akdidir."',
    ),
    'biat': const DictionaryEntry(
      word: 'Biat (Bey\'at)',
      origin: 'Arapça (beyʿat)',
      partOfSpeech: 'Kamu Hukuku / Tarih',
      meaning: 'Devlet başkanının seçimi ve meşruiyetinin onaylanması için yapılan karşılıklı bağlılık ve hukuk sözleşmesi.',
      example: '"Biat akdi, idareciye adaletle hükmetme mükellefiyeti yükler."',
    ),
    'velayet': const DictionaryEntry(
      word: 'Velâyet',
      origin: 'Arapça (velāyet - yakınlık, yetki)',
      partOfSpeech: 'Hukuk / Tasavvuf',
      meaning: 'Hukukta bir kimsenin veya kamunun işlerini yürütme ve karar alma yetkisi (velâyet-i âmme); tasavvufta Allah\'a dostluk makamı.',
      example: '"Kamu görevi bir imtiyaz değil, millet adına üstlenilen ağır bir velâyet emanetidir."',
    ),
    'ehliyet': const DictionaryEntry(
      word: 'Ehliyet',
      origin: 'Arapça (ehliyyet - layık ve yeterli olma)',
      partOfSpeech: 'Hukuk / İsim',
      meaning: 'Bir işi hakkıyla yapabilme yetkinliği, uzmanlık; hukukta haklara sahip olma ve borç altına girebilme yeterliliği.',
      example: '"Makamların tevdiinde akrabalık değil, ilim ve ehliyet esas alınmalıdır."',
    ),
    'liyakat': const DictionaryEntry(
      word: 'Liyâkat',
      origin: 'Arapça (liyāḳat - layık olma, uygunluk)',
      partOfSpeech: 'İsim / Kamu Yönetimi',
      meaning: 'Bir kimsenin kendisine verilen görevi başarıyla yürütebilecek bilgi, ahlak ve yeteneğe sahip olması; layık olma durumu.',
      example: '"Nizam-ı âlemin sırrı, her vazifeyi liyâkat sahibine teslim etmektir."',
    ),
    'maslahat': const DictionaryEntry(
      word: 'Maslahat',
      origin: 'Arapça (maṣlaḥat - iyilik, fayda)',
      partOfSpeech: 'Hukuk / Siyaset',
      meaning: 'Toplumun ve fertlerin hayrına, huzuruna ve yararına olan iş; kamu yararı (maslahat-ı âmme).',
      example: '"İdarecilerin tasarrufları şahsi arzulara değil, kamu maslahatına bağlıdır (Mecelle, md. 58)."',
    ),
    'müeyyide': const DictionaryEntry(
      word: 'Müeyyide',
      origin: 'Arapça (müʾeyyide - sağlamlaştıran güç)',
      partOfSpeech: 'Hukuk',
      meaning: 'Hukuk kurallarına uyulmasını temin eden ve ihlal halinde uygulanan yaptırım, kanuni zorlayıcı güç.',
      example: '"Müeyyidesiz bırakılan kaideler, zamanla sadece temenniden ibaret kalır."',
    ),
    'ahkam': const DictionaryEntry(
      word: 'Ahkâm',
      origin: 'Arapça (aḥkām - ḥükm\'ün çoğulu)',
      partOfSpeech: 'Hukuk / İsim',
      meaning: 'Hükümler, kanunlar, hukuki kaideler ve yargı kararları.',
      example: '"El-Ahkâmu\'s-Sultâniyye, İslam kamu ve anayasa hukukunun en temel klasik eseridir."',
    ),
    'hüküm': const DictionaryEntry(
      word: 'Hüküm',
      origin: 'Arapça (ḥükm)',
      partOfSpeech: 'Hukuk / Mantık',
      meaning: 'Yargı kararı, kanuni kural, buyruk; mantıkta iki kavram arasında kurulan olumlu veya olumsuz yargı.',
      example: '"Adil bir hüküm, iki tarafı da dinlemeden ve delilleri tartmadan verilemez."',
    ),
    'sultaniyye': const DictionaryEntry(
      word: 'Sultâniyye',
      origin: 'Arapça (sulṭāniyye)',
      partOfSpeech: 'Kamu Hukuku / Tarih',
      meaning: 'Devlet otoritesine, kamu yönetimine ve hükümdarlık hukukuna ait olan.',
      example: '"Ahkâm-ı Sultâniyye, devlet teşkilatı, yargı, maliye ve idare hukukunu inceler."',
    ),
    'fıkıh': const DictionaryEntry(
      word: 'Fıkıh',
      origin: 'Arapça (fiḳh - derinlemesine kavrama)',
      partOfSpeech: 'İsim / Hukuk',
      meaning: 'Bir şeyi ince bir kavrayışla derinlemesine bilme; İslam ibadet, muamelat ve kamu hukuku ilmi.',
      example: '"Fıkıh, insanın lehine ve aleyhine olan hak ve sorumlulukları bilmesidir."',
    ),
    'fakih': const DictionaryEntry(
      word: 'Fakîh',
      origin: 'Arapça (faḳīh)',
      partOfSpeech: 'İsim / Hukuk',
      meaning: 'Fıkıh ilminde derinleşmiş, delillerden hüküm çıkarma kudretine sahip İslam hukukçusu.',
      example: '"Mâverdî, hem büyük bir Şâfiî fakîhi hem de tecrübeli bir başkadılık (akda\'l-kudât) mensubudur."',
    ),
    'kaza': const DictionaryEntry(
      word: 'Kazâ',
      origin: 'Arapça (ḳaḍāʾ - hüküm verme, yerine getirme)',
      partOfSpeech: 'Hukuk / Kelâm',
      meaning: 'İnsanlar arasındaki anlaşmazlıkları hukuk kurallarına göre çözme yetkisi ve yargı teşkilatı; kelâmda ezelî takdirin gerçekleşmesi.',
      example: '"Kazâ makamının bağımsızlığı, adaletin mülke temel olmasının ilk şartıdır."',
    ),
    'kadı': const DictionaryEntry(
      word: 'Kadı',
      origin: 'Arapça (ḳāḍī)',
      partOfSpeech: 'Hukuk / Tarih',
      meaning: 'İslam ve Osmanlı hukuk düzeninde davaları dinleyip şer\'î ve örfî hukuka göre karara bağlayan hâkim, yargıç.',
      example: '"Kadı, mahkeme meclisinde sultan ile sıradan bir raiyyeti eşit tutmakla mükelleftir."',
    ),
    'vezir': const DictionaryEntry(
      word: 'Vezir',
      origin: 'Arapça (vezīr - yük taşıyan yardımcı)',
      partOfSpeech: 'Tarih / Kamu Yönetimi',
      meaning: 'Devlet yönetiminde hükümdarın veya halifenin en üst düzey yürütme yardımcısı, bakan (tefvîz veya tenfîz veziri).',
      example: '"Tefvîz veziri geniş takdir yetkisiyle icraatta bulunurken, tenfîz veziri alınan kararları uygular."',
    ),
    'vezaret': const DictionaryEntry(
      word: 'Vezâret',
      origin: 'Arapça (vezāret)',
      partOfSpeech: 'Kamu Yönetimi / Tarih',
      meaning: 'Vezirlik makamı ve kurumu; devlet yükünü omuzlayan yürütme organı.',
      example: '"Mâverdî vezâreti, yetki genişliğine göre tefvîz ve tenfîz vezirliği olarak ikiye ayırır."',
    ),
    'emaret': const DictionaryEntry(
      word: 'Emâret',
      origin: 'Arapça (emāret)',
      partOfSpeech: 'Kamu Yönetimi / Tarih',
      meaning: 'Emirlik, valilik veya ordu komutanlığı makamı; taşra eyaletlerinin ve askeri birliklerin idaresi.',
      example: '"Eyaletlerin huzuru, emâret makamına atanan valilerin adalet ve dirayetine bağlıdır."',
    ),
    'haraç': const DictionaryEntry(
      word: 'Haraç',
      origin: 'Arapça (ḫarāc)',
      partOfSpeech: 'Maliye Hukuku / Tarih',
      meaning: 'Klasik İslam maliyesinde tarım arazilerinden ve ürünlerinden devlet hazinesi (Beytülmâl) adına alınan toprak vergisi.',
      example: '"Toprağın verimliliği ve sulama imkânları, haraç miktarının adil biçimde takdirinde esas alınır."',
    ),
    'cizye': const DictionaryEntry(
      word: 'Cizye',
      origin: 'Arapça (cizye)',
      partOfSpeech: 'Maliye Hukuku / Tarih',
      meaning: 'İslam devletinde gayrimüslim vatandaşların (zimmîlerin) can/mal güvenliği ve askerlik muafiyeti karşılığında ödedikleri baş vergisi.',
      example: '"Kadınlar, çocuklar, yaşlılar ve geçim sıkıntısı çekenler cizye mükellefiyetinden muaftır."',
    ),
    'ganimet': const DictionaryEntry(
      word: 'Ganîmet',
      origin: 'Arapça (ġanīmet)',
      partOfSpeech: 'Tarih / Hukuk',
      meaning: 'Savaşta elde edilen mal ve gelirler; mecazen zahmetsizce kavuşulan değerli imkân veya fırsat.',
      example: '"Gençlik ve boş vakit, kıymetini bilen için en büyük ganîmettir."',
    ),
    'zekat': const DictionaryEntry(
      word: 'Zekât',
      origin: 'Arapça (zekāt - arınma, bereketlenme)',
      partOfSpeech: 'Din / Maliye',
      meaning: 'Belli bir zenginlik ölçüsüne (nisap) ulaşan malın, her yıl ihtiyaç sahiplerine verilmesi zorunlu olan belirli payı.',
      example: '"Zekât, servetin yalnızca belirli ellerde toplanmasını önleyen sosyal adalet köprüsüdür."',
    ),
    'beytülmal': const DictionaryEntry(
      word: 'Beytülmâl',
      origin: 'Arapça (beytu\'l-māl - mal evi)',
      partOfSpeech: 'Maliye / Tarih',
      meaning: 'İslam devletinde kamu gelirlerinin toplandığı ve kamu hizmetleri için harcandığı devlet hazinesi.',
      example: '"Beytülmâl, milletin ortak emaneti olup her kuruşu kamu yararına sarf edilir."',
    ),
    'hisbe': const DictionaryEntry(
      word: 'Hisbe',
      origin: 'Arapça (ḥisbe)',
      partOfSpeech: 'Kamu Hukuku / Tarih',
      meaning: 'Çarşı ve pazarlarda ölçü-tartı doğruluğunu, gıda sağlığını, fiyat dengesini ve kamu ahlakını denetleyen belediye ve teftiş teşkilatı.',
      example: '"Hisbe teşkilatı ve muhtesipler, esnafın tüketiciyi aldatmasını engelleyen sıkı bir denetim kurmuştur."',
    ),
    'asabiyet': const DictionaryEntry(
      word: 'Asabiyet',
      origin: 'Arapça (ʿaṣabiyyet)',
      partOfSpeech: 'Sosyoloji / Tarih',
      meaning: 'İbn Haldun\'un Mukaddime\'sinde kavramsallaştırdığı; bir topluluğu ortak gaye etrafında kenetleyen toplumsal dayanışma ve aidiyet ruhu.',
      example: '"İbn Haldun\'a göre devletlerin kuruluşu güçlü bir asabiyet ve ortak ülkü ile mümkün olur."',
    ),
    'ümran': const DictionaryEntry(
      word: 'Ümran',
      origin: 'Arapça (ʿumrān - bayındırlık, medeniyet)',
      partOfSpeech: 'Sosyoloji / Felsefe',
      meaning: 'İnsanların yeryüzünü imar ederek bir arada yaşaması, toplumsal hayat, kültür ve medeniyet birikimi.',
      example: '"İbn Haldun, insan topluluklarının doğasını inceleyen yeni bilime İlm-i Ümran adını vermiştir."',
    ),
    'bedevi': const DictionaryEntry(
      word: 'Bedevî',
      origin: 'Arapça (bedevī - kır/çöl hayatına mensup)',
      partOfSpeech: 'Sosyoloji / Sıfat',
      meaning: 'Yerleşik şehir hayatından önce kırsalda, yaylak ve çöllerde göçebe veya yarı göçebe yaşayan sade ve dayanıklı topluluk.',
      example: '"Bedevî toplumlar zorlu tabiat şartları sebebiyle cesaret ve dayanışma bakımından diri kalırlar."',
    ),
    'hadari': const DictionaryEntry(
      word: 'Hadarî',
      origin: 'Arapça (ḥaḍarī - yerleşik şehirli)',
      partOfSpeech: 'Sosyoloji / Sıfat',
      meaning: 'Yerleşik düzene geçmiş, şehirlerde bilim, sanat, zanaat ve ticaretle uğraşan medeni toplum.',
      example: '"Hadarî hayatta ilim ve sanatlar zirveye ulaşırken, konfor ve rehavet tehlikesi de artar."',
    ),
    'husus': const DictionaryEntry(
      word: 'Husus',
      origin: 'Arapça (ḫuṣūṣ)',
      partOfSpeech: 'İsim',
      meaning: 'Üzerinde durulan konu, mesele, yön, cihet, özellik.',
      example: '"Bu hususta âlimlerin ortaya koyduğu deliller meselenin her boyutunu aydınlatmaktadır."',
    ),
    'ihtilaf': const DictionaryEntry(
      word: 'İhtilâf',
      origin: 'Arapça (iḫtilāf)',
      partOfSpeech: 'İsim',
      meaning: 'Görüş ayrılığı, uyuşmazlık, farklı düşünme durumu.',
      example: '"İlmî ihtilâflar, meselelerin farklı cephelerden derinlemesine incelenmesine vesile olur."',
    ),
    'ittifak': const DictionaryEntry(
      word: 'İttifak',
      origin: 'Arapça (ittifāḳ)',
      partOfSpeech: 'İsim',
      meaning: 'Görüş ve düşünce birliği, uyuşma, oybirliği.',
      example: '"Adaletin mülkün temeli olduğu hakikatinde bütün hikmet ehli ittifak etmiştir."',
    ),
    'ümmet': const DictionaryEntry(
      word: 'Ümmet',
      origin: 'Arapça (ümmet)',
      partOfSpeech: 'İsim / Sosyoloji',
      meaning: 'Bir peygamberin tebliğ ettiği inanç ve değerler etrafında birleşen büyük insan topluluğu.',
      example: '"İlim ve adalet, ümmetin dirliğini koruyan iki sarsılmaz sütundur."',
    ),
    'cemaat': const DictionaryEntry(
      word: 'Cemaat',
      origin: 'Arapça (cemāʿat)',
      partOfSpeech: 'İsim / Sosyoloji',
      meaning: 'Ortak bir gaye veya ibadet için bir araya gelmiş insan topluluğu, cemiyet.',
      example: '"Fertlerin şahsi gayreti, cemaat şuuru ve dayanışmayla birleştiğinde kalıcı eserler doğar."',
    ),
    'dünyevi': const DictionaryEntry(
      word: 'Dünyevî',
      origin: 'Arapça (dünyevī)',
      partOfSpeech: 'Sıfat',
      meaning: 'Bu dünyaya, geçici maddi hayata ve toplum düzenine ait olan.',
      example: '"Klasik düşüncede dinî fazilet ile dünyevî nizam birbirini tamamlayan iki kanattır."',
    ),
    'uhrevi': const DictionaryEntry(
      word: 'Uhrevî',
      origin: 'Arapça (uḫrevī)',
      partOfSpeech: 'Sıfat',
      meaning: 'Ahiret hayatına, ebedî âleme ve manevi sorumluluğa ilişkin olan.',
      example: '"İnsanın vicdanındaki uhrevî hesap bilinci, kimsenin görmediği yerde dahi adaleti korur."',
    ),
    'anarşi': const DictionaryEntry(
      word: 'Anarşi',
      origin: 'Fransızca / Yunanca (anarchie - başsızlık)',
      partOfSpeech: 'Siyaset / Sosyoloji',
      meaning: 'Devlet otoritesinin, hukukun ve kamu düzeninin ortadan kalkmasıyla oluşan kargaşa ve başsızlık hali (fevzâ).',
      example: '"Hukukun üstünlüğü zedelendiğinde toplumda güven sarsılır ve anarşi tehlikesi baş gösterir."',
    ),
    'istibdat': const DictionaryEntry(
      word: 'İstibdat',
      origin: 'Arapça (istibdād)',
      partOfSpeech: 'Siyaset / Tarih',
      meaning: 'Hiçbir kanun ve danışma meclisi tanımaksızın tek başına keyfî ve baskıcı yönetim, despotizm.',
      example: '"Meşveret ve hukuk denetimi, idarenin istibdata dönüşmesini önleyen en sağlam kaledir."',
    ),
    'meşveret': const DictionaryEntry(
      word: 'Meşveret (Şûrâ)',
      origin: 'Arapça (meşveret)',
      partOfSpeech: 'Kamu Yönetimi / İsim',
      meaning: 'Önemli işlerde ehil kimselerle danışma, görüş alışverişinde bulunma, istişare meclisi.',
      example: '"İstişare ve meşveret, tek kişinin yanılma payını ortak aklın bereketiyle giderir."',
    ),
    'şura': const DictionaryEntry(
      word: 'Şûrâ',
      origin: 'Arapça (şūrā)',
      partOfSpeech: 'Kamu Yönetimi / İsim',
      meaning: 'Kamu işlerinin uzmanlar ve temsilciler arasında tartışılarak karara bağlandığı danışma kurulu.',
      example: '"Şûrâ prensibi, kamu kararlarının ortak akıl ve ehliyetle alınmasını emreder."',
    ),
    'mahiyet': const DictionaryEntry(
      word: 'Mâhiyet',
      origin: 'Arapça (māhiyyet - "o nedir?" sorusunun cevabı)',
      partOfSpeech: 'Felsefe / İsim',
      meaning: 'Bir şeyin aslı, özü, içyüzü, onu kendisi yapan temel nitelikler bütünü.',
      example: '"Bir meselenin mâhiyetini kavramadan verilen hükümler yüzeysel kalmaya mahkûmdur."',
    ),
    'keyfiyet': const DictionaryEntry(
      word: 'Keyfiyet',
      origin: 'Arapça (keyfiyyet - "nasıldır?" sorusunun cevabı)',
      partOfSpeech: 'Felsefe / İsim',
      meaning: 'Bir şeyin niteliği, nasıl olduğu, iç durumu ve vasfı (kemiyetin/niceliğin karşıtı).',
      example: '"Okunan kitapların sayısından (kemiyetinden) ziyade, okumanın derinliği ve keyfiyeti önemlidir."',
    ),
    'mülahaza': const DictionaryEntry(
      word: 'Mülâhaza',
      origin: 'Arapça (mülāḥaẓa)',
      partOfSpeech: 'İsim',
      meaning: 'Dikkatle inceleyerek üzerinde düşünme, değerlendirme, fikir ve görüş.',
      example: '"Müellif, eserin son bölümünde tarihi vakıalar hakkındaki mülâhazalarını özetlemiştir."',
    ),
    'hatime': const DictionaryEntry(
      word: 'Hâtime',
      origin: 'Arapça (ḫātime)',
      partOfSpeech: 'Edebiyat / İsim',
      meaning: 'Bir kitabın, konuşmanın veya işin sonu, bitiş ve sonuç bölümü.',
      example: '"Klasik eserler besmele ve hamdele ile başlayıp dua ve hâtime ile tamamlanır."',
    ),
    // --- Osmanlıca Terkipler (İzafet & Vasf-ı Terkibî) ---
    'âdâb-ı muaşeret': const DictionaryEntry(
      word: 'Âdâb-ı Muaşeret',
      origin: 'Arapça (ādāb) + Farsça izafet + Arapça (muʿāşeret)',
      partOfSpeech: 'Osmanlıca Terkip / Ahlâk',
      meaning: 'Toplumsal yaşayışta, insan ilişkilerinde uyulması gereken nezaket, terbiye ve görgü kuralları bütünü.',
      example: '"Klasik kültürümüzde âdâb-ı muaşeret, bireyin hem kendine hem de topluma duyduğu hürmetin tezahürüdür."',
    ),
    'ehl-i sünnet': const DictionaryEntry(
      word: 'Ehl-i Sünnet',
      origin: 'Arapça (ehl + sünnet)',
      partOfSpeech: 'Osmanlıca Terkip / Kelâm',
      meaning: 'Hz. Peygamber’in ve sahabenin dinin temel konularında takip ettiği yolu benimseyen ana İslâm topluluğu.',
      example: '"Ehl-i sünnet âlimleri, itidal ve orta yol çizgisini muhafaza etmeye özen göstermişlerdir."',
    ),
    'ehl-i beyt': const DictionaryEntry(
      word: 'Ehl-i Beyt',
      origin: 'Arapça (ehl + beyt)',
      partOfSpeech: 'Osmanlıca Terkip / İslâm Tarihi',
      meaning: 'Ev halkı; İslâm ıstılahında Hz. Muhammed’in ailesi, evlatları ve torunları.',
      example: '"Divan edebiyatında Ehl-i Beyt sevgisi sayısız kaside ve naata ilham kaynağı olmuştur."',
    ),
    'ehl-i dil': const DictionaryEntry(
      word: 'Ehl-i Dil',
      origin: 'Arapça (ehl) + Farsça (dil - gönül)',
      partOfSpeech: 'Osmanlıca Terkip / Tasavvuf',
      meaning: 'Gönül ehli; kalp gözü açık, ince ruhlu, halden anlayan ârif kimse.',
      example: '"Ehl-i dil olanlar, sözün zahirinden ziyade gönüldeki manasına kulak verirler."',
    ),
    'ehl-i irfan': const DictionaryEntry(
      word: 'Ehl-i İrfan',
      origin: 'Arapça (ehl + ʿirfān)',
      partOfSpeech: 'Osmanlıca Terkip / Tasavvuf',
      meaning: 'Sezgi, iç tecrübe ve manevi olgunlukla hakikati kavrayan bilge kimseler.',
      example: '"Meclisimizde ehl-i irfan sohbetleri gönüllere inşirah verirdi."',
    ),
    'hüsn-i zan': const DictionaryEntry(
      word: 'Hüsn-i Zan',
      origin: 'Arapça (ḥüsn - güzellik + ẓann - sanı)',
      partOfSpeech: 'Osmanlıca Terkip / Ahlâk',
      meaning: 'Bir kimse veya olay hakkında iyi niyetli düşünme, güzel kanaat besleme.',
      example: '"Mümin, kardeşine karşı daima hüsn-i zan beslemeyi esas alır."',
    ),
    'sû-i zan': const DictionaryEntry(
      word: 'Sû-i Zan',
      origin: 'Arapça (sūʾ - kötülük + ẓann - sanı)',
      partOfSpeech: 'Osmanlıca Terkip / Ahlâk',
      meaning: 'Kesin bilgiye dayanmaksızın bir kimse hakkında kötü niyetli tahminde ve kuşkuda bulunma.',
      example: '"Sû-i zandan sakınınız; zira zannın bir kısmı ağır bir vebaldir."',
    ),
    'sû-i istimal': const DictionaryEntry(
      word: 'Sû-i İstimal',
      origin: 'Arapça (sūʾ + istiʿmāl)',
      partOfSpeech: 'Osmanlıca Terkip / Hukuk',
      meaning: 'Yetkiyi, iyiliği veya güveni kötüye kullanma, suistimal.',
      example: '"Kamuemanetinin sû-i istimali, kurumsal meşruiyeti zedeleyen en büyük etkendir."',
    ),
    'ilm-i hâl': const DictionaryEntry(
      word: 'İlm-i Hâl',
      origin: 'Arapça (ʿilm + ḥāl)',
      partOfSpeech: 'Osmanlıca Terkip / Fıkıh',
      meaning: 'Her Müslümanın kendi hal ve durumunda bilmesi gereken temel inanç, ibadet ve ahlâk bilgileri.',
      example: '"Klasik ilm-i hâl eserleri, günlük hayatın fıkhî ve ahlâkî çerçevesini sade bir dille sunar."',
    ),
    'sadaka-i câriye': const DictionaryEntry(
      word: 'Sadaka-i Câriye',
      origin: 'Arapça (ṣadaḳa + cāriye - akıp giden)',
      partOfSpeech: 'Osmanlıca Terkip / İslâm Hukuku',
      meaning: 'İnsanın ölümünden sonra da sevabı kesilmeyip devam eden çeşme, köprü, okul, ilim eseri gibi hayır işleri.',
      example: '"Faydalı bir ilim eseri bırakmak, en kalıcı sadaka-i câriye nevilerindendir."',
    ),
    'erkân-ı devlet': const DictionaryEntry(
      word: 'Erkân-ı Devlet',
      origin: 'Arapça (erkān - direkler + devlet)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: 'Devletin temel direkleri sayılan sadrazam, şeyhülislâm, kazasker, defterdar ve nişancı gibi üst düzey yöneticiler.',
      example: '"Erkân-ı devlet, mühim memleket meselelerini görüşmek üzere Dîvân-ı Hümâyûn’da toplandı."',
    ),
    'nizâm-ı âlem': const DictionaryEntry(
      word: 'Nizâm-ı Âlem',
      origin: 'Arapça (niẓām + ʿālem)',
      partOfSpeech: 'Osmanlıca Terkip / Siyaset Felsefesi',
      meaning: 'Dünya düzeni; Osmanlı siyaset düşüncesinde adalet, asayiş ve toplumsal dengenin korunması ülküsü.',
      example: '"Osmanlı kanunnâmelerinde temel gaye, nizâm-ı âlemin adaletle tesis ve idamesidir."',
    ),
    'kânûn-ı kadîm': const DictionaryEntry(
      word: 'Kânûn-ı Kadîm',
      origin: 'Arapça (ḳānūn + ḳadīm)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: 'Devletin kuruluşundan beri süregelen köklü geleneksel yasalar, kurumsal teamüller ve düzen.',
      example: '"Islahat لâyihalarında sıklıkla kânûn-ı kadîme riayet edilmesi gerektiği vurgulanmıştır."',
    ),
    'kânûn-ı esâsî': const DictionaryEntry(
      word: 'Kânûn-ı Esâsî',
      origin: 'Arapça (ḳānūn + esāsī)',
      partOfSpeech: 'Osmanlıca Terkip / Anayasa Hukuku',
      meaning: 'Temel yasa, anayasa; 1876 yılında ilan edilen ilk Osmanlı anayasası.',
      example: '"1876 Kânûn-ı Esâsî’si ile Osmanlı Devleti anayasal meşrutiyet dönemine adım atmıştır."',
    ),
    'devlet-i aliyye': const DictionaryEntry(
      word: 'Devlet-i Aliyye',
      origin: 'Arapça (devlet + ʿaliyye - yüce)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: 'Yüce Devlet; Osmanlı İmparatorluğu’nun resmî belgelerde ve tarih yazımında kullanılan adı.',
      example: '"Devlet-i Aliyye, üç kıtada farklı kültür ve cemaatleri asırlarca bir arada yönetmiştir."',
    ),
    'arz-ı hâl': const DictionaryEntry(
      word: 'Arz-ı Hâl',
      origin: 'Arapça (ʿarż - sunma + ḥāl - durum)',
      partOfSpeech: 'Osmanlıca Terkip / İdare',
      meaning: 'Bir isteği veya şikâyeti üst makama bildirmek için yazılan dilekçe, istida.',
      example: '"Halkın doğrudan divana arz-ı hâl sunabilmesi, klasik adalet mekanizmasının temel taşlarındandı."',
    ),
    'tercüme-i hâl': const DictionaryEntry(
      word: 'Tercüme-i Hâl',
      origin: 'Arapça (tercüme + ḥāl)',
      partOfSpeech: 'Osmanlıca Terkip / Edebiyat',
      meaning: 'Bir kimsenin hayat hikâyesi, özgeçmiş, biyografi.',
      example: '"Şuara tezkireleri, yüzlerce şairin tercüme-i hâlini ve edebi kişiliğini günümüze taşır."',
    ),
    'nokta-i nazar': const DictionaryEntry(
      word: 'Nokta-i Nazar',
      origin: 'Arapça (noḳṭa + naẓar - bakış)',
      partOfSpeech: 'Osmanlıca Terkip / Felsefe',
      meaning: 'Bakış açısı, görüş noktası, perspektif.',
      example: '"Tarihî hadiseleri kendi devrinin nokta-i nazarından değerlendirmek metodolojik bir zorunluluktur."',
    ),
    'sarf-ı nazar': const DictionaryEntry(
      word: 'Sarf-ı Nazar',
      origin: 'Arapça (ṣarf - çevirme + naẓar - bakış)',
      partOfSpeech: 'Osmanlıca Terkip / İsim',
      meaning: 'Bir şeyden vazgeçme, üzerinde durmama, hesaba katmama.',
      example: '"Tali ayrıntılardan sarf-ı nazar edersek, eserin ana fikri son derece berraktır."',
    ),
    'efkâr-ı umûmiye': const DictionaryEntry(
      word: 'Efkâr-ı Umûmiye',
      origin: 'Arapça (efkār - fikirler + ʿumūmiyye - genel)',
      partOfSpeech: 'Osmanlıca Terkip / Siyaset',
      meaning: 'Kamuoyu, halkın genel düşüncesi ve eğilimi.',
      example: '"Matbuatın gelişmesiyle birlikte efkâr-ı umûmiye siyasal kararlarda belirleyici bir güç haline geldi."',
    ),
    'hâl-i hazır': const DictionaryEntry(
      word: 'Hâl-i Hazır',
      origin: 'Arapça (ḥāl + ḥāżır)',
      partOfSpeech: 'Osmanlıca Terkip / İsim',
      meaning: 'Şimdiki durum, mevcut vaziyet, günümüz.',
      example: '"Hâl-i hazırda elimizdeki arşiv belgeleri bu hipotezi doğrular niteliktedir."',
    ),
    'asr-ı saâdet': const DictionaryEntry(
      word: 'Asr-ı Saâdet',
      origin: 'Arapça (ʿaṣr - çağ + saʿādet - mutluluk)',
      partOfSpeech: 'Osmanlıca Terkip / İslâm Tarihi',
      meaning: 'Mutluluk çağı; Hz. Muhammed’in hayatta olduğu ve İslâm toplumunu bizzat yönettiği dönem.',
      example: '"Asr-ı Saâdet, İslâm medeniyetinin kurucu ahlâk ve hukuk ilkelerinin yaşandığı örnek dönemdir."',
    ),
    'feth-i mübîn': const DictionaryEntry(
      word: 'Feth-i Mübîn',
      origin: 'Arapça (fetḥ + mübīn - apaçık)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: 'Apaçık zafer ve fetih; özellikle Hudeybiye Antlaşması, Mekke’nin ve İstanbul’un fethi için kullanılan tabir.',
      example: '"İstanbul’un fethi, klasik tarihçiler tarafından feth-i mübîn olarak nitelendirilmiştir."',
    ),
    'kelâm-ı kibâr': const DictionaryEntry(
      word: 'Kelâm-ı Kibâr',
      origin: 'Arapça (kelām - söz + kibār - büyükler)',
      partOfSpeech: 'Osmanlıca Terkip / Edebiyat',
      meaning: 'Din ve tasavvuf büyüklerinin, bilge kişilerin söylediği hikmetli, özlü söz; vecize.',
      example: '"Eserde yer alan kelâm-ı kibârlar, asırların süzgecinden geçmiş hayat tecrübelerini özetler."',
    ),
    'kütüb-i sitte': const DictionaryEntry(
      word: 'Kütüb-i Sitte',
      origin: 'Arapça (kütüb - kitaplar + sitte - altı)',
      partOfSpeech: 'Osmanlıca Terkip / Hadis',
      meaning: 'Ehl-i sünnet dünyasında en güvenilir kabul edilen altı temel hadis kitabı (Buhârî, Müslim, Ebû Dâvûd, Tirmizî, Nesâî, İbn Mâce).',
      example: '"Hadis ilminde Kütüb-i Sitte, sahih rivayetlerin temel başvuru kaynağıdır."',
    ),
    'dârülfünûn': const DictionaryEntry(
      word: 'Dârülfünûn',
      origin: 'Arapça (dār - ev + el-fünūn - fenler, ilimler)',
      partOfSpeech: 'Osmanlıca Terkip / Eğitim Tarihi',
      meaning: 'Fenler ve ilimler evi; Osmanlı Devleti’nde modern anlamda kurulan ilk üniversite (İstanbul Üniversitesi’nin öncülü).',
      example: '"Dârülfünûn, 1933 Üniversite Reformu ile İstanbul Üniversitesi adını almıştır."',
    ),
    'şeyhülislâm': const DictionaryEntry(
      word: 'Şeyhülislâm',
      origin: 'Arapça (şeyḫ + el-islām)',
      partOfSpeech: 'Osmanlıca Terkip / Osmanlı Tarihi',
      meaning: 'Osmanlı Devleti’nde ilmiye sınıfının başı olan, dinî ve hukukî konularda en yüksek fetva makamı.',
      example: '"Şeyhülislâm, protokolde sadrazamla denk sayılan en yüksek ilmiye mercii idi."',
    ),
    'hatt-ı hümâyûn': const DictionaryEntry(
      word: 'Hatt-ı Hümâyûn',
      origin: 'Arapça (ḫaṭṭ - yazı) + Farsça (hümāyūn - kutlu, padişaha ait)',
      partOfSpeech: 'Osmanlıca Terkip / Diplomasi',
      meaning: 'Osmanlı padişahlarının bizzat kendi el yazılarıyla yazdıkları veya onayladıkları yazılı emir ve ferman.',
      example: '"Tanzimat Fermanı, Gülhane Parkı’nda okunan bir hatt-ı hümâyûn ile ilan edilmiştir."',
    ),
    'dîvân-ı hümâyûn': const DictionaryEntry(
      word: 'Dîvân-ı Hümâyûn',
      origin: 'Farsça (dīvān + hümāyūn)',
      partOfSpeech: 'Osmanlıca Terkip / Osmanlı Tarihi',
      meaning: 'Osmanlı Devleti’nde siyaset, hukuk, idare ve maliye işlerinin karara bağlandığı en yüksek devlet kurulu.',
      example: '"Dîvân-ı Hümâyûn, hem bir bakanlar kurulu hem de en üst temyiz mahkemesi işlevi görürdü."',
    ),
    'hikmet-i hükümet': const DictionaryEntry(
      word: 'Hikmet-i Hükümet',
      origin: 'Arapça (ḥikmet + ḥükūmet)',
      partOfSpeech: 'Osmanlıca Terkip / Siyaset Bilimi',
      meaning: 'Devletin bekası ve yüksek menfaatleri için alınan kararların altında yatan siyasi gerekçe (Raison d’État).',
      example: '"Siyaset teorisinde hikmet-i hükümet kavramı, devlet aklının sınırlarını tartışmaya açar."',
    ),
    'sehl-i mümtenî': const DictionaryEntry(
      word: 'Sehl-i Mümtenî',
      origin: 'Arapça (sehl - kolay + mümteniʿ - imkânsız)',
      partOfSpeech: 'Osmanlıca Terkip / Belâgat',
      meaning: 'İlk bakışta çok sade ve kolay söylenmiş gibi görünen, fakat benzerini söylemek istediğinde taklit edilmesi çok güç olan derin anlamlı söz.',
      example: '"Yunus Emre’nin ilahileri, Türk edebiyatında sehl-i mümtenî sanatının en zirve örnekleridir."',
    ),
    'tecâhül-i ârif': const DictionaryEntry(
      word: 'Tecâhül-i Ârif',
      origin: 'Arapça (tecāhül - bilmezlikten gelme + ʿārif - bilen)',
      partOfSpeech: 'Osmanlıca Terkip / Edebiyat',
      meaning: 'Çok iyi bilinen bir gerçeği, nükte ve edebi incelik amacıyla bilmiyormuş gibi ifade etme sanatı.',
      example: '"Şairin ‘Şakaklarıma kar mı yağdı ne var?’ dizesi zarif bir tecâhül-i ârif örneğidir."',
    ),
    'hüsn-i tâlil': const DictionaryEntry(
      word: 'Hüsn-i Tâlil',
      origin: 'Arapça (ḥüsn - güzellik + taʿlīl - sebep gösterme)',
      partOfSpeech: 'Osmanlıca Terkip / Edebiyat',
      meaning: 'Gerçek sebebi bilinen doğal bir olayı, şairane ve hayalî güzel bir nedene bağlama sanatı.',
      example: '"Güllerin sevgilinin yüzünü görerek utancından kızardığını söylemek klasik bir hüsn-i tâlildir."',
    ),
    'sened-i ittifak': const DictionaryEntry(
      word: 'Sened-i İttifak',
      origin: 'Arapça (sened + ittifāḳ)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: '1808 yılında II. Mahmud döneminde merkezi hükümet ile âyanlar arasında imzalanan tarihi mutabakat belgesi.',
      example: '"Sened-i İttifak, Türk anayasa tarihinde padişah otoritesinin ilk kez yazılı bir metinle sınırlandırılması açısından önemlidir."',
    ),
    'bâb-ı âlî': const DictionaryEntry(
      word: 'Bâb-ı Âlî',
      origin: 'Arapça (bāb - kapı + ʿālī - yüce)',
      partOfSpeech: 'Osmanlıca Terkip / Tarih',
      meaning: 'Yüce Kapı; Osmanlı Devleti’nde Sadrazamlık makamı ve hükümet merkezi.',
      example: '"XIX. yüzyılda devlet idaresinin ağırlık merkezi Saray’dan Bâb-ı Âlî’ye kaymıştır."',
    ),
    'gayr-i müslim': const DictionaryEntry(
      word: 'Gayr-i Müslim',
      origin: 'Arapça (ġayr - dışındaki + müslim)',
      partOfSpeech: 'Osmanlıca Terkip / Hukuk',
      meaning: 'Müslüman olmayan; İslâm devletinde yaşayan diğer din mensubu vatandaşlar.',
      example: '"Osmanlı millet sisteminde gayr-i müslim cemaatler kendi dinî ve aile hukuklarında özerkliğe sahipti."',
    ),
    'âb-ı hayât': const DictionaryEntry(
      word: 'Âb-ı Hayât',
      origin: 'Farsça (āb - su) + Arapça (ḥayāt - yaşam)',
      partOfSpeech: 'Osmanlıca Terkip / Tasavvuf',
      meaning: 'Dirilik suyu, ölümsüzlük iksiri; tasavvufta insanın gönlünü dirilten ilâhî aşk ve hakikat ilmi.',
      example: '"Âriflerin sohbeti, susamış gönüller için âb-ı hayât hükmündedir."',
    ),
    'şeb-i arûs': const DictionaryEntry(
      word: 'Şeb-i Arûs',
      origin: 'Farsça (şeb - gece) + Arapça (ʿarūs - düğün, gelin)',
      partOfSpeech: 'Osmanlıca Terkip / Tasavvuf',
      meaning: 'Düğün gecesi; Hz. Mevlânâ’nın vefat gününü sevgiliye (Allah’a) kavuşma gecesi olarak nitelendirdiği kavram.',
      example: '"Mevlânâ Celâleddîn-i Rûmî, ölüm gününü bir matem değil, Şeb-i Arûs olarak görmüştür."',
    ),
    'levh-i mahfûz': const DictionaryEntry(
      word: 'Levh-i Mahfûz',
      origin: 'Arapça (levḥ - levha + maḥfūẓ - korunmuş)',
      partOfSpeech: 'Osmanlıca Terkip / Kelâm',
      meaning: 'Korunmuş levha; kâinatta olmuş ve olacak her şeyin ilâhî ilimde yazılı olduğu kader kitabı.',
      example: '"Klasik düşüncede kâinattaki her hadise Levh-i Mahfûz’daki ilâhî takdirin bir tecellisidir."',
    ),

    // --- Modern Sosyal Bilimler, Siyaset Bilimi, İktisat ve Felsefe (Ulusların Düşüşü vb.) ---
    'yurttaş': const DictionaryEntry(
      word: 'Yurttaş',
      origin: 'Türkçe (yurt + -taş ortaklık eki)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Bir devletin egemenliği altında yaşayan, anayasal hak ve sorumluluklara eşit biçimde sahip olan özgür birey; vatandaş.',
      example: '"Kapsayıcı siyasal kurumlar, yurttaşların yönetim kararlarına etkin katılımını güvence altına alır."',
    ),
    'biçim': const DictionaryEntry(
      word: 'Biçim',
      origin: 'Türkçe (biç- fiilinden biçim)',
      partOfSpeech: 'Felsefe / İsim',
      meaning: 'Bir şeyin dış görünüşü, şekli, formu; felsefede ve sosyal bilimlerde kurumların veya düşüncenin yapısal düzeni.',
      example: '"Siyasal kurumların biçimi, bir toplumun ekonomik refah üretme kapasitesini doğrudan belirler."',
    ),
    'siyasal': const DictionaryEntry(
      word: 'Siyasal',
      origin: 'Arapça (siyāset) + Türkçe (-sal yapım eki)',
      partOfSpeech: 'Siyaset Bilimi / Sıfat',
      meaning: 'Devlet yönetimine, kamusal iktidarın paylaşımına ve toplumun yönetim ilkelerine ilişkin olan; siyasi.',
      example: '"Siyasal dönüşüm, gücün dar bir zümreden geniş toplum kesimlerine yayılmasıyla gerçekleşir."',
    ),
    'dönüşüm': const DictionaryEntry(
      word: 'Dönüşüm',
      origin: 'Türkçe (dönüş- fiilinden dönüşüm)',
      partOfSpeech: 'Sosyoloji / İsim',
      meaning: 'Bir yapının, kurumun veya toplumun olduğundan başka bir biçime, daha ileri veya farklı bir duruma evrilmesi; transformasyon.',
      example: '"Kalıcı ekonomik büyüme, sömürücü kurumların kapsayıcı kurumlara dönüşümüyle mümkündür."',
    ),
    'hakikaten': const DictionaryEntry(
      word: 'Hakikaten',
      origin: 'Arapça (ḥaḳīḳaten)',
      partOfSpeech: 'Zarf',
      meaning: 'Gerçekten, doğrusu, aslına bakılırsa, sahiden.',
      example: '"Tarihsel kırılma anlarını anlamak, bugünkü eşitsizlikleri açıklamak için hakikaten elzemdir."',
    ),
    'imkânsız': const DictionaryEntry(
      word: 'İmkânsız',
      origin: 'Arapça (imkān) + Türkçe (-sız eki)',
      partOfSpeech: 'Sıfat',
      meaning: 'Gerçekleşmesi mümkün olmayan, olanaksız, muhal.',
      example: '"Kurumsal denge ve denetleme mekanizmaları olmadan keyfî iktidarı sınırlamak neredeyse imkânsızdır."',
    ),
    'protestocu': const DictionaryEntry(
      word: 'Protestocu',
      origin: 'Latince/İtalyanca (protesto) + Türkçe (-cu eki)',
      partOfSpeech: 'Sosyoloji / İsim',
      meaning: 'Toplumsal, ekonomik veya siyasal bir uygulamaya karşı kamusal alanda itirazını dile getiren kimse.',
      example: '"Meydanlarda toplanan protestocular, yalnızca yöneticilerin değil, kurumsal düzenin değişmesini talep ediyordu."',
    ),
    'sıklıkla': const DictionaryEntry(
      word: 'Sıklıkla',
      origin: 'Türkçe (sık + -lık + -la)',
      partOfSpeech: 'Zarf',
      meaning: 'Çoğu kez, sık sık, yaygın bir biçimde, ekseriyetle.',
      example: '"Tarihte otoriter rejimlerin ekonomik krizlerle sıklıkla sarsıldığı görülür."',
    ),
    'kapsayıcı': const DictionaryEntry(
      word: 'Kapsayıcı',
      origin: 'Türkçe (kapsa- fiilinden kapsayıcı)',
      partOfSpeech: 'İktisat / Sıfat',
      meaning: 'Toplumun geniş kesimlerini sürece dahil eden, mülkiyet haklarını koruyan ve fırsat eşitliği sağlayan (kurum veya düzen).',
      example: '"Kapsayıcı ekonomik kurumlar, yetenek ve yaratıcılığın özgürce filizlenmesine olanak tanır."',
    ),
    'sömürücü': const DictionaryEntry(
      word: 'Sömürücü',
      origin: 'Türkçe (sömür- fiilinden sömürücü)',
      partOfSpeech: 'İktisat / Sıfat',
      meaning: 'Toplumun çoğunluğunun ürettiği kaynakları ve refahı dar bir seçkin zümrenin çıkarına aktaran (kurum veya rejim); dışlayıcı.',
      example: '"Sömürücü kurumlar kısa vadede büyüme sağlasa bile uzun vadede yenilikçiliği boğar."',
    ),
    'çoğulculuk': const DictionaryEntry(
      word: 'Çoğulculuk',
      origin: 'Türkçe (çoğul + -cu + -luk)',
      partOfSpeech: 'Siyaset Felsefesi / İsim',
      meaning: 'Siyasal gücün tek elde toplanmayıp toplumdaki farklı görüş, çıkar ve gruplar arasında dengeli biçimde paylaşılması ilkesi; plüralizm.',
      example: '"Çoğulculuk, kapsayıcı siyasal kurumların en temel yapı taşıdır."',
    ),
    'kurumsal': const DictionaryEntry(
      word: 'Kurumsal',
      origin: 'Türkçe (kur- fiilinden kurum + -sal)',
      partOfSpeech: 'Sosyoloji / Sıfat',
      meaning: 'Kişilere bağlı olmayan, yerleşik kurallara, yasalara ve örgütlü yapılara dayanan.',
      example: '"Ülkeler arasındaki refah farklarının temelinde coğrafyadan ziyade kurumsal farklılıklar yatar."',
    ),
    'meşruiyet': const DictionaryEntry(
      word: 'Meşruiyet',
      origin: 'Arapça (meşrūʿiyyet)',
      partOfSpeech: 'Hukuk / Siyaset Bilimi',
      meaning: 'Bir iktidarın, yasanın veya eylemin hukuka, toplumsal vicdana ve adalet ilkelerine uygun olma durumu; yasallık ve haklılık.',
      example: '"Devlet otoritesinin kalıcılığı, zor kullanımından değil toplumsal meşruiyetten beslenir."',
    ),
    'hegemonya': const DictionaryEntry(
      word: 'Hegemonya',
      origin: 'Yunanca (hēgemonía - önderlik, üstünlük)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Bir devletin, sınıfın veya düşünce biçiminin diğerleri üzerinde kurduğu siyasal, ekonomik ve kültürel üstünlük ve yönlendirme gücü.',
      example: '"Kültürel hegemonya, mevcut güç ilişkilerinin doğal ve kaçınılmaz olarak algılanmasını sağlar."',
    ),
    'toplumsal': const DictionaryEntry(
      word: 'Toplumsal',
      origin: 'Türkçe (toplum + -sal)',
      partOfSpeech: 'Sosyoloji / Sıfat',
      meaning: 'Toplumla ilgili, bireylerin bir arada yaşamasından doğan ortak yapı, değer ve ilişkilere ait; sosyal, içtimai.',
      example: '"Toplumsal hareketler, tarihin akışını değiştiren kritik dönüm noktaları yaratabilir."',
    ),
    'değerlendirmek': const DictionaryEntry(
      word: 'Değerlendirmek',
      origin: 'Türkçe (değer + -len + -dir + -mek)',
      partOfSpeech: 'Fiil',
      meaning: 'Bir olgunun, eserin veya düşüncenin niteliğini, önemini ve sonuçlarını ölçüp tartarak hükme varmak; tahlil etmek.',
      example: '"Tarihsel olayları yalnızca sonuçlarıyla değil, doğdukları kurumsal bağlamla değerlendirmek gerekir."',
    ),
    'başarısızlık': const DictionaryEntry(
      word: 'Başarısızlık',
      origin: 'Türkçe (başarı + -sız + -lık)',
      partOfSpeech: 'İsim',
      meaning: 'Amaçlanan sonuca ulaşamama, akamet, muvaffakiyetsizlik.',
      example: '"Ulusların ekonomik başarısızlıklarının arkasında çoğu zaman tercih edilen kötü siyasal kurumlar vardır."',
    ),
    'görmek': const DictionaryEntry(
      word: 'Görmek',
      origin: 'Türkçe (gör-mek)',
      partOfSpeech: 'Fiil',
      meaning: 'Göz yardımıyla algılamak; mecazen bir gerçeği kavramak, idrak etmek, müşahede etmek.',
      example: '"Kitabın ilerleyen bölümlerinde kurumsal tercihlerin ulusların kaderini nasıl belirlediğini göreceğiz."',
    ),
    'anlamak': const DictionaryEntry(
      word: 'Anlamak',
      origin: 'Türkçe (anla-mak)',
      partOfSpeech: 'Fiil / Epistemoloji',
      meaning: 'Bir sözün, olgunun veya tarihsel sürecin nedenlerini, iç bağlantısını ve manasını zihnen kavramak; idrak etmek, fehmetmek.',
      example: '"Kurumların nasıl biçimlendiğini anlarsak, zenginlik ve yoksulluğun kökenlerini de çözebiliriz."',
    ),
    'götürmek': const DictionaryEntry(
      word: 'Götürmek',
      origin: 'Türkçe (götür-mek)',
      partOfSpeech: 'Fiil',
      meaning: 'Bir şeyi veya süreci bir yerden başka bir yere, bir duruma veya sonuca ulaştırmak, sevk etmek.',
      example: '"Çoğulcu koalisyonların eksikliği, devrimlerin yeni bir diktatörlüğe götüreceğini sıkça göstermiştir."',
    ),
    'demek': const DictionaryEntry(
      word: 'Demek',
      origin: 'Türkçe (de-mek)',
      partOfSpeech: 'Fiil',
      meaning: 'Düşüncesini sözle ifade etmek, söylemek, beyan etmek; bir kavramı adlandırmak veya anlamına gelmek.',
      example: '"Düşünür, gerçek özgürlüğün ancak hukukun üstünlüğüyle mümkün olduğunu diyor."',
    ),
    'gerekmek': const DictionaryEntry(
      word: 'Gerekmek',
      origin: 'Türkçe (gerek-mek)',
      partOfSpeech: 'Fiil',
      meaning: 'Bir amaca ulaşmak için zorunlu, lazım veya uygun olmak; iktiza etmek.',
      example: '"Toplumun refahı için yapılması gereken, ayrıcalıkları değil fırsat eşitliğini kurumsallaştırmaktır."',
    ),
    'devrilmek': const DictionaryEntry(
      word: 'Devrilmek',
      origin: 'Türkçe (devir- fiilinden devril-mek)',
      partOfSpeech: 'Fiil / Siyaset',
      meaning: 'Yıkılmak, düşmek; siyasette bir iktidarın veya diktatörlük rejiminin halk hareketi ya da darbeyle sona ermesi.',
      example: '"Bir diktatörün devrilmesi, tek başına kapsayıcı demokrasinin kurulacağı anlamına gelmez."',
    ),
    'olanak': const DictionaryEntry(
      word: 'Olanak',
      origin: 'Türkçe (ol- fiilinden olanak)',
      partOfSpeech: 'İsim',
      meaning: 'Bir şeyin gerçekleşmesini mümkün kılan elverişli koşul, fırsat ve güç; imkân.',
      example: '"Eğitim ve hukuk güvencesi, yurttaşlara kendi yeteneklerini gerçekleştirme olanağı sunar."',
    ),
    'mülkiyet': const DictionaryEntry(
      word: 'Mülkiyet',
      origin: 'Arapça (mülkiyyet)',
      partOfSpeech: 'Hukuk / İktisat',
      meaning: 'Bir taşınır veya taşınmaz mal ya da fikrî eser üzerinde sahibine kullanma, yararlanma ve tasarruf yetkisi veren hukuki hak.',
      example: '"Özel mülkiyet haklarının güvence altında olması, uzun vadeli yatırım ve yeniliğin ön koşuludur."',
    ),
    'refah': const DictionaryEntry(
      word: 'Refah',
      origin: 'Arapça (refāh)',
      partOfSpeech: 'İktisat / İsim',
      meaning: 'Bolluk, rahatlık ve genişlik içinde yaşama durumu; bir toplumun maddi ve sosyal yaşam standardının yüksekliği.',
      example: '"Sürdürülebilir refah, teknolojik yenilik ve kurumsal adaletle birlikte yükselir."',
    ),
    'iktidar': const DictionaryEntry(
      word: 'İktidar',
      origin: 'Arapça (ḳudret kökünden iḳtidār)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Bir işi yapabilme gücü ve kudreti; siyasette devleti yönetme ve bağlayıcı kararlar alma yetkisini elinde bulunduran güç.',
      example: '"Siyasal iktidarın sınırlandırılması, anayasal devletin en temel ilkesidir."',
    ),
    'demokrasi': const DictionaryEntry(
      word: 'Demokrasi',
      origin: 'Yunanca (dēmos - halk + krátos - iktidar)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Egemenliğin halka ait olduğu, yöneticilerin özgür ve adil seçimlerle belirlendiği, temel hakların korunduğu yönetim biçimi.',
      example: '"Gerçek demokrasi, yalnızca sandıktan değil, kuvvetler ayrılığı ve hukukun üstünlüğünden güç alır."',
    ),
    'diktatörlük': const DictionaryEntry(
      word: 'Diktatörlük',
      origin: 'Latince (dictator) + Türkçe (-lük)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Siyasal iktidarın anayasal sınırlamalar olmaksızın tek bir kişinin veya dar bir grubun elinde toplandığı otoriter rejim.',
      example: '"Diktatörlük rejimleri, muhalefeti ve bağımsız kurumları baskı altına alarak varlığını sürdürür."',
    ),
    'oligarşi': const DictionaryEntry(
      word: 'Oligarşi',
      origin: 'Yunanca (olígos - az + arkhḗ - yönetim)',
      partOfSpeech: 'Siyaset Bilimi / İsim',
      meaning: 'Siyasal ve ekonomik iktidarın ayrıcalıklı küçük bir zümrenin elinde toplandığı yönetim biçimi.',
      example: '"Demir oligarşi yasası, devrimlerden sonra bile yeni seçkinlerin eski sömürü düzenini yeniden üretebileceğini açıklar."',
    ),
    'bürokrasi': const DictionaryEntry(
      word: 'Bürokrasi',
      origin: 'Fransızca (bureaucratie)',
      partOfSpeech: 'Kamu Yönetimi / İsim',
      meaning: 'Devlet işlerinin hiyerarşik işbölümü, yazılı kurallar ve uzman memurlar eliyle yürütüldüğü idari örgütlenme sistemi.',
      example: '"Weber’e göre rasyonel bürokrasi, modern devletin öngörülebilirlik ve süreklilik kazanmasını sağlamıştır."',
    ),
    'metodoloji': const DictionaryEntry(
      word: 'Metodoloji',
      origin: 'Yunanca (méthodos - yöntem + lógos - bilim)',
      partOfSpeech: 'Bilim / İsim',
      meaning: 'Yöntembilim; bir bilim dalında bilgi üretmek ve doğrulamak için izlenen kurallar, ilkeler ve araştırma yolları bütünü.',
      example: '"İbn Haldûn’un Mukaddime’si, tarih yazımında eleştirel metodolojinin temellerini atmıştır."',
    ),
  };

  /// Türkçe karakter duyarlı küçük harfe çevirme (`İ -> i`, `I -> ı`, `Â -> â`, `Î -> î`, `Û -> û`).
  static String _toTurkishLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Â', 'â')
        .replaceAll('Î', 'î')
        .replaceAll('Û', 'û')
        .toLowerCase();
  }

  /// Şapkalı harfleri (â, î, û) ve kesme işaretlerini düzleştirerek ikincil eşleşme anahtarı üretir.
  static String _stripCircumflex(String input) {
    return input
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll("'", '')
        .replaceAll('’', '');
  }

  /// Ünlü düşmesi görülen klasik Türkçe/Arapça kelimelerin çekimli gövdelerini aslına çevirir.
  static const Map<String, String> _vowelDropStems = {
    'hükm': 'hüküm',
    'akl': 'akıl',
    'fikr': 'fikir',
    'zikr': 'zikir',
    'şükr': 'şükür',
    'sabr': 'sabır',
    'emr': 'emir',
    'ömr': 'ömür',
    'zulm': 'zulüm',
    'ilm': 'ilim',
    'kısm': 'kısım',
    'vakt': 'vakit',
    'nakt': 'nakit',
    'nakd': 'nakit',
    'asr': 'asır',
    'devr': 'devir',
    'nehr': 'nehir',
    'şehr': 'şehir',
    'keşf': 'keşif',
    'feth': 'fetih',
    'kavm': 'kavim',
    'ism': 'isim',
    'cism': 'cisim',
    'resm': 'resim',
    'halk': 'halk',
    'nefs': 'nefis',
    'nesl': 'nesil',
    'asl': 'asıl',
    'fasl': 'fasıl',
    'usl': 'usul',
  };

  /// Türkçe çekim ve yapım eklerini (isim, fiil, sıfat-fiil, zarf-fiil, nispet) soyarak ve
  /// ünsüz yumuşaması/sertleşmesini (`b<->p`, `c<->ç`, `d<->t`, `ğ/g<->k`) çift yönlü
  /// tersine çevirerek olası kelime köklerini döndürür.
  List<String> _extractTurkishStems(String cleanWord) {
    final stems = <String>{};
    if (cleanWord.isEmpty || cleanWord.length > 48) return const [];

    // Uzun ekten kısa eke doğru sıralanmış kapsamlı Türkçe çekim ve yapım ekleri
    const suffixes = <String>[
      'ulmuştur', 'ülmüştür', 'ılmıştır', 'ilmiştir', 'maktadır', 'mektedir',
      'malıdır', 'melidir', 'acaktır', 'ecektir', 'dığından', 'diğinden',
      'duğundan', 'düğünden', 'larından', 'lerinden', 'larında', 'lerinde',
      'larının', 'lerinin', 'leriyle', 'larıyla', 'larımız', 'lerimiz',
      'larınız', 'leriniz', 'casına', 'cesine', 'sından', 'sinden',
      'sının', 'sinin', 'sunun', 'sünün', 'sında', 'sinde', 'sıyla', 'siyle',
      'mızın', 'mizin', 'muzun', 'müzün', 'ılması', 'ilmesi', 'ulması', 'ülmesi',
      'leştiğini', 'laştığını', 'leştiği', 'laştığı', 'yeceğini', 'yacağını',
      'eceğini', 'acağını', 'yeceğiz', 'yacağız', 'eceğiz', 'acağız',
      'larsak', 'lersek', 'arsak', 'ersek', 'rsak', 'rsek', 'yacak', 'yecek',
      'larına', 'lerine', 'larını', 'lerini', 'lardan', 'lerden',
      'dığını', 'diğini', 'duğunu', 'düğünü', 'tığını', 'tiğini',
      'tuğunu', 'tüğünü', 'eceği', 'acağı', 'yordu', 'yoruz', 'yorlar',
      'ları', 'leri', 'ndan', 'nden', 'mız', 'miz', 'muz', 'müz',
      'nız', 'niz', 'nuz', 'nüz', 'dan', 'den', 'tan', 'ten',
      'nda', 'nde', 'nın', 'nin', 'nun', 'nün', 'ına', 'ine',
      'una', 'üne', 'ını', 'ini', 'unu', 'ünü', 'yla', 'yle',
      'sına', 'sine', 'sını', 'sini', 'sunu', 'sünü',
      'dır', 'dir', 'dur', 'dür', 'tır', 'tir', 'tur', 'tür',
      'mış', 'miş', 'muş', 'müş', 'mak', 'mek', 'acak', 'ecek',
      'ıyor', 'iyor', 'uyor', 'üyor', 'yor', 'sak', 'sek', 'ken',
      'dık', 'dik', 'duk', 'dük', 'tık', 'tik', 'tuk', 'tük',
      'dığı', 'diği', 'duğu', 'düğü', 'tığı', 'tiği', 'tuğu', 'tüğü',
      'ması', 'mesi', 'arak', 'erek', 'iyye', 'iyet', 'iyyet',
      'lık', 'lik', 'luk', 'lük', 'sız', 'siz', 'suz', 'süz',
      'leş', 'laş', 'lar', 'ler', 'ın', 'in', 'un', 'ün', 'ya', 'ye',
      'na', 'ne', 'yı', 'yi', 'yu', 'yü', 'da', 'de',
      'ta', 'te', 'la', 'le', 'ca', 'ce', 'ça', 'çe',
      'sı', 'si', 'su', 'sü', 'an', 'en', 'ıp', 'ip', 'up', 'üp',
      'ım', 'im', 'um', 'üm', 'lı', 'li', 'lu', 'lü',
      'cı', 'ci', 'cu', 'cü', 'çı', 'çi', 'çu', 'çü',
      'at', 'ât', 'vi', 'vî',
      'a', 'e', 'ı', 'i', 'u', 'ü', 'î',
    ];

    void addWithConsonantAlternations(String candidate) {
      if (candidate.length < 2) return;
      stems.add(candidate);
      final plain = _stripCircumflex(candidate);
      stems.add(plain);
      stems.add('${candidate}mak');
      stems.add('${candidate}mek');
      stems.add('${plain}mak');
      stems.add('${plain}mek');
      if (plain == 'di') {
        stems.add('demek');
      } else if (plain == 'yi') {
        stems.add('yemek');
      }

      if (_vowelDropStems.containsKey(plain)) {
        stems.add(_vowelDropStems[plain]!);
      }

      if (candidate.length < 3) return;

      // Ünsüz yumuşaması ve sertleşmesi çift yönlü dönüşüm (b<->p, c<->ç, d<->t, ğ/g<->k)
      final prefix = candidate.substring(0, candidate.length - 1);
      final lastChar = candidate[candidate.length - 1];
      final alternations = switch (lastChar) {
        'b' => ['${prefix}p'],
        'p' => ['${prefix}b'],
        'c' => ['$prefixç'],
        'ç' => ['${prefix}c'],
        'd' => ['${prefix}t'],
        't' => ['${prefix}d'],
        'ğ' => ['${prefix}k', '${prefix}g'],
        'g' => ['${prefix}k'],
        'k' => ['$prefixğ', '${prefix}g'],
        _ => const <String>[],
      };
      for (final alt in alternations) {
        stems.add(alt);
        final altPlain = _stripCircumflex(alt);
        stems.add(altPlain);
        if (_vowelDropStems.containsKey(altPlain)) {
          stems.add(_vowelDropStems[altPlain]!);
        }
      }
    }

    addWithConsonantAlternations(cleanWord);

    // 3 Aşamalı morfolojik ek soyma (ör. "müesseselerimizdendir" -> "müessese")
    var currentFrontier = <String>{cleanWord, _stripCircumflex(cleanWord)};
    for (var pass = 0; pass < 3; pass++) {
      final nextFrontier = <String>{};
      for (final word in currentFrontier) {
        for (final suffix in suffixes) {
          if (word.endsWith(suffix) && word.length - suffix.length >= 2) {
            final stripped = word.substring(0, word.length - suffix.length);
            addWithConsonantAlternations(stripped);
            nextFrontier.add(stripped);
          }
        }
      }
      if (nextFrontier.isEmpty) break;
      currentFrontier = nextFrontier;
    }

    return stems.toList();
  }

  /// Seçilen metindeki kelimeleri temiz birer token listesi olarak ayıklar.
  static List<String> extractWordsFromSelection(String rawSelection) {
    final matches = RegExp(
      r"[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ']+",
      unicode: true,
    ).allMatches(rawSelection);
    final result = <String>[];
    for (final m in matches) {
      final token = m.group(0)?.replaceAll(RegExp(r"^'+|'+$"), '').trim() ?? '';
      if (token.length >= 2) {
        result.add(token);
      }
    }
    return result;
  }

  /// Tek bir temizlenmiş kelime için sözlükte tam veya gövde eşleşmesi arar.
  DictionaryEntry? _findSingleWordMatch(String rawToken) {
    if (rawToken.length > 64) return null;
    final cleanWithApos = _toTurkishLower(rawToken).trim();
    final clean = cleanWithApos
        .replaceAll(RegExp(r'[^a-zçğıöşüâîû]', unicode: true), '')
        .trim();

    if (clean.isEmpty) return null;

    // 1. Doğrudan eşleşme
    if (_localDictionary.containsKey(clean)) {
      return _localDictionary[clean]!;
    }
    final plainClean = _stripCircumflex(clean);
    if (_localDictionary.containsKey(plainClean)) {
      return _localDictionary[plainClean]!;
    }

    // Kesme işaretli kelimelerde kesmeden önceki kök (ör. "Kur'an'ın" -> "kuran", "şer'î" -> "şeri")
    if (cleanWithApos.contains("'") || cleanWithApos.contains('’')) {
      final beforeApos = cleanWithApos
          .split(RegExp(r"['’]"))
          .first
          .replaceAll(RegExp(r'[^a-zçğıöşüâîû]', unicode: true), '');
      if (beforeApos.length >= 3 && _localDictionary.containsKey(beforeApos)) {
        return _localDictionary[beforeApos]!;
      }
    }

    // 2. Türkçe morfolojik kök bulucu ile eşleşme
    final candidateStems = _extractTurkishStems(clean).toSet();
    for (final stem in candidateStems) {
      if (stem.length >= 2 && _localDictionary.containsKey(stem)) {
        return _localDictionary[stem]!;
      }
    }

    // 3. Şapkalı harften arındırılmış anahtar kontrolü
    for (final entry in _localDictionary.entries) {
      final normalizedKey = _stripCircumflex(entry.key);
      if (candidateStems.contains(normalizedKey)) {
        return entry.value;
      }
    }

    // 4. Uzun kök önek eşleşmesi (yalnızca anahtar uzunluğu >= 5 ve fark <= 4 ise)
    if (plainClean.length >= 5) {
      DictionaryEntry? bestPrefixMatch;
      var longestKeyLen = 0;
      for (final entry in _localDictionary.entries) {
        final keyPlain = _stripCircumflex(entry.key);
        if (keyPlain.length >= 5 &&
            plainClean.startsWith(keyPlain) &&
            plainClean.length - keyPlain.length <= 5) {
          if (keyPlain.length > longestKeyLen) {
            longestKeyLen = keyPlain.length;
            bestPrefixMatch = entry.value;
          }
        }
      }
      if (bestPrefixMatch != null) {
        return bestPrefixMatch;
      }
    }

    return null;
  }

  /// Sözlükte doğrudan madde başı olmayan kelimeler için dinamik morfolojik
  /// kök, ek, vezin ve yakın kavram analizi üretir (asla sabit şablon döndürmez).
  DictionaryEntry _buildDynamicMorphologicalEntry(
    String displayWord,
    List<String> tokens,
  ) {
    final targetToken = tokens.isNotEmpty ? tokens.first : displayWord.trim();
    final lower = _toTurkishLower(targetToken)
        .replaceAll(RegExp(r'[^a-zçğıöşüâîû]', unicode: true), '');
    final stems = _extractTurkishStems(lower);

    // En anlamlı kökü seç (3-6 harf arası en kısa geçerli gövde)
    var rootCandidate = lower;
    for (final s in stems) {
      if (s.length >= 3 && s.length < rootCandidate.length) {
        rootCandidate = s;
      }
    }

    // Soyulan eki ve dilbilgisel görevini tespit et
    final suffixPart = lower.startsWith(_stripCircumflex(rootCandidate)) &&
            lower.length > rootCandidate.length
        ? lower.substring(rootCandidate.length)
        : '';

    final detectedFunctions = <String>[];
    if (suffixPart.isNotEmpty) {
      if (RegExp(r'(lar|ler)').hasMatch(suffixPart)) {
        detectedFunctions.add('Çoğul (-lar/-ler)');
      }
      if (RegExp(r'(mıştır|miştir|muştur|müştür|mış|miş|muş|müş)').hasMatch(suffixPart)) {
        detectedFunctions.add('Geçmiş Zaman / Sıfat-Fiil (-mış/-miş)');
      }
      if (RegExp(r'(maktadır|mektedir|mak|mek|ması|mesi)').hasMatch(suffixPart)) {
        detectedFunctions.add('İsim-Fiil / Süreklilik (-mak/-mek)');
      }
      if (RegExp(r'(dığı|diği|duğu|düğü|tığı|tiği|an|en)').hasMatch(suffixPart)) {
        detectedFunctions.add('Sıfat-Fiil (Ortaç)');
      }
      if (RegExp(r'(dan|den|tan|ten)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Ayrılma Hali (-dan/-den)');
      } else if (RegExp(r'(da|de|ta|te)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Bulunma Hali (-da/-de)');
      } else if (RegExp(r'(nın|nin|nun|nün|ın|in|un|ün)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Tamlayan / İlgi Hali (-ın/-in)');
      } else if (RegExp(r'(ya|ye|na|ne|a|e)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Yönelme Hali (-a/-e)');
      } else if (RegExp(r'(yı|yi|yu|yü|ı|i|u|ü)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Belirtme / İyelik Eki');
      } else if (RegExp(r'(dır|dir|dur|dür|tır|tir|tur|tür)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Bildirme / Kesinlik Eki (-dır/-dir)');
      } else if (RegExp(r'(lık|lik|luk|lük)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Soyut İsim Yapım Eki (-lık/-lik)');
      } else if (RegExp(r'(lı|li|lu|lü|sız|siz|suz|süz)$').hasMatch(suffixPart)) {
        detectedFunctions.add('Niteleme Sıfatı Yapım Eki');
      }
    }

    // Köken ve vezin tahmini
    String origin = 'Türkçe';
    String partOfSpeech = 'İsim / Çekimli Sözcük';
    String structuralNote = '';

    if (lower.contains('â') ||
        lower.contains('î') ||
        lower.contains('û') ||
        lower.startsWith('mü') ||
        lower.startsWith('mu') ||
        lower.startsWith('te') ||
        lower.startsWith('ta') ||
        lower.startsWith('ist') ||
        lower.endsWith('iyet') ||
        lower.endsWith('iyye') ||
        lower.endsWith('ât')) {
      origin = 'Arapça / Klasik Osmanlı Türkçesi';
      if (lower.startsWith('mü') || lower.startsWith('mu')) {
        partOfSpeech = 'İsm-i Fâil / İsm-i Mef\'ûl';
        structuralNote =
            'Arapça "mü-/mu-" önekiyle türetilmiş, bir eylemi icra eden veya o niteliği taşıyan kavram kalıbıdır. ';
      } else if (lower.endsWith('iyet') || lower.endsWith('iyye')) {
        partOfSpeech = 'Soyut Kavram (Masdar-ı Sınâî)';
        structuralNote =
            '"-iyet / -iyye" nispet ve soyutluk ekiyle türetilmiş felsefi/hukuki terimdir. ';
      } else if (lower.startsWith('ist')) {
        partOfSpeech = 'İstif\'âl Babı (Masdar)';
        structuralNote =
            'Arapça "istif\'âl" kalıbında talep, arzu veya bir niteliği aramayı ifade eden terimdir. ';
      }
    } else if (detectedFunctions.any((f) => f.contains('Fiil'))) {
      partOfSpeech = 'Fiil / Fiilimsi Gövdesi';
    }

    // Kökdaş veya yazılışı en yakın lügat maddelerini bul
    final rootPlain = _stripCircumflex(rootCandidate);
    final relatedEntries = <DictionaryEntry>[];
    for (final entry in _localDictionary.entries) {
      final keyPlain = _stripCircumflex(entry.key);
      if (rootPlain.length >= 3 &&
          (keyPlain.contains(rootPlain) || rootPlain.contains(keyPlain))) {
        if (!relatedEntries.any((e) => e.word == entry.value.word)) {
          relatedEntries.add(entry.value);
        }
      }
    }

    final rootDisplay = rootCandidate.isEmpty
        ? targetToken
        : '${rootCandidate[0].toUpperCase()}${rootCandidate.substring(1)}';
    final suffixSummary = suffixPart.isNotEmpty
        ? ' • Ek: "-$suffixPart"${detectedFunctions.isNotEmpty ? " (${detectedFunctions.join(', ')})" : ""}'
        : ' • Yalın Gövde';

    final relatedNote = relatedEntries.isNotEmpty
        ? '\n\nYakın Lügat Maddesi (${relatedEntries.first.word}): ${relatedEntries.first.meaning}'
        : '';

    return DictionaryEntry(
      word: targetToken,
      origin: '$origin (Kök: $rootDisplay$suffixSummary)',
      partOfSpeech: partOfSpeech,
      meaning:
          '${structuralNote}Seçilen "$targetToken" sözcüğü "$rootDisplay" kök/gövdesinden${suffixPart.isNotEmpty ? ' "-$suffixPart" ekiyle' : ''} türemiştir.${detectedFunctions.isNotEmpty ? ' Cümle içinde ${detectedFunctions.join(" ve ").toLowerCase()} görevinde kullanılmıştır.' : ''}$relatedNote',
      example: relatedEntries.isNotEmpty
          ? relatedEntries.first.example
          : '"$targetToken" ibaresinin kök gövdesi "$rootDisplay" olarak çözümlenmiştir.',
    );
  }

  /// Osmanlıca terkip araması (tireli, boşluklu veya bitişik izafet yazımlarını eşleştirir).
  DictionaryEntry? _findTerkipMatch(String rawInput) {
    final lower = _toTurkishLower(rawInput)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (lower.isEmpty || (!lower.contains('-') && !lower.contains(' '))) {
      return null;
    }

    if (_localDictionary.containsKey(lower)) {
      return _localDictionary[lower];
    }

    final plainInput = _stripCircumflex(lower);
    final compactInput = plainInput.replaceAll(RegExp(r'[^a-zçğıöşü]'), '');

    for (final entry in _localDictionary.entries) {
      if (!entry.key.contains('-') && !entry.key.contains(' ')) continue;
      final keyLower = _toTurkishLower(entry.key);
      final keyPlain = _stripCircumflex(keyLower);
      final keySpace = keyPlain.replaceAll('-', ' ');
      final keyCompact = keyPlain.replaceAll(RegExp(r'[^a-zçğıöşü]'), '');

      if (lower == keyLower ||
          plainInput == keyPlain ||
          plainInput == keySpace ||
          (compactInput.length >= 6 && compactInput == keyCompact)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Çevreleyen cümle içinde seçilen kelimenin bir Osmanlıca terkip parçası olup olmadığını denetler.
  DictionaryEntry? _findContextualTerkipMatch(
    String targetWord,
    String surroundingText,
  ) {
    final targetPlain = _stripCircumflex(_toTurkishLower(targetWord))
        .replaceAll(RegExp(r'[^a-zçğıöşü]'), '');
    if (targetPlain.length < 2) return null;

    final contextPlain = _stripCircumflex(_toTurkishLower(surroundingText))
        .replaceAll(RegExp(r'[-–—]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    for (final entry in _localDictionary.entries) {
      if (!entry.key.contains('-')) continue;
      final keyPlain = _stripCircumflex(_toTurkishLower(entry.key));
      final parts = keyPlain
          .split(RegExp(r'[-\s]+'))
          .where((p) => p.length >= 2)
          .toList();
      if (!parts.any((p) => p == targetPlain || targetPlain.startsWith(p))) {
        continue;
      }
      final spaceForm = keyPlain.replaceAll('-', ' ');
      final joinedIzafetForm = keyPlain.replaceAllMapped(
        RegExp(r'([a-zçğıöşü]+)-([ıiüu])\s+([a-zçğıöşü]+)'),
        (m) => '${m.group(1)}${m.group(2)} ${m.group(3)}',
      );
      if (contextPlain.contains(spaceForm) ||
          contextPlain.contains(joinedIzafetForm)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Looks up a word or multi-word selection in the offline dictionary using morphological stemming
  DictionaryEntry lookup(String rawWord, {String? surroundingText}) {
    final trimmed = rawWord.trim();
    if (trimmed.isEmpty) {
      return _localDictionary['tahrir']!;
    }
    final safeSurrounding = surroundingText != null && surroundingText.length > 600
        ? surroundingText.substring(0, 600)
        : surroundingText;

    // 0. Önce doğrudan veya çevreleyen metin bağlamında Osmanlıca terkip eşleşmesi dene
    final terkipMatch = _findTerkipMatch(trimmed);
    if (terkipMatch != null) {
      return terkipMatch;
    }
    if (safeSurrounding != null && safeSurrounding.trim().isNotEmpty) {
      final contextualTerkip = _findContextualTerkipMatch(
        trimmed,
        safeSurrounding,
      );
      if (contextualTerkip != null) {
        return contextualTerkip;
      }
    }

    // 1. Sonra tek parça (veya tamlama) olarak dene
    if (!trimmed.contains(' ') && trimmed.length <= 48) {
      final directMatch = _findSingleWordMatch(trimmed);
      if (directMatch != null) {
        return directMatch;
      }
    }

    // 2. Çok kelimeli seçim yapılmışsa kelimelere ayır ve anlamlı kelimeleri çözümle
    final tokens = extractWordsFromSelection(trimmed).take(12).toList();
    if (tokens.isEmpty) {
      return _localDictionary['tahrir']!;
    }

    const stopWords = <String>{
      've', 'ile', 'de', 'da', 'ki', 'bu', 'şu', 'bir', 'için', 'gibi',
      'kadar', 'olan', 'olarak', 'ise', 'ama', 'fakat', 'ancak', 'hem',
      'ya', 'veya', 'yahut', 'her', 'hiç', 'çok', 'daha', 'en', 'ne',
    };

    final matchedEntries = <DictionaryEntry>[];
    for (final token in tokens) {
      final tokenLower = _toTurkishLower(token);
      if (tokens.length > 1 && stopWords.contains(tokenLower)) continue;
      final match = _findSingleWordMatch(token);
      if (match != null && !matchedEntries.any((e) => e.word == match.word)) {
        matchedEntries.add(match);
      }
    }

    if (matchedEntries.length == 1) {
      return matchedEntries.first;
    }

    if (matchedEntries.length > 1) {
      final first = matchedEntries.first;
      final combinedMeaning = matchedEntries
          .take(3)
          .map((e) => '• ${e.word} (${e.origin}): ${e.meaning}')
          .join('\n\n');
      return DictionaryEntry(
        word: matchedEntries.take(3).map((e) => e.word).join(' · '),
        origin: '${matchedEntries.length} Kavram Çözümlendi',
        partOfSpeech: first.partOfSpeech,
        meaning: combinedMeaning,
        example: first.example,
      );
    }

    // 3. Madde başı bulunamadıysa sabit mesaj yerine dinamik morfolojik kök/ek analizi üret
    final primaryTokens = tokens
        .where((t) => !stopWords.contains(_toTurkishLower(t)))
        .toList();
    return _buildDynamicMorphologicalEntry(
      trimmed,
      primaryTokens.isNotEmpty ? primaryTokens : tokens,
    );
  }

  /// Başlık, anlam veya kökende arama yapıp sonuçları döndürür.
  /// Boş sorguda öne çıkan 20 klasik kelimeyi döndürür.
  List<DictionaryEntry> search(String query) {
    final seenWords = <String>{};
    final uniqueEntries = <DictionaryEntry>[];
    for (final entry in _localDictionary.values) {
      if (seenWords.add(entry.word)) {
        uniqueEntries.add(entry);
      }
    }

    final cleanQuery = _toTurkishLower(query).trim();
    if (cleanQuery.isEmpty) {
      return uniqueEntries.take(24).toList();
    }

    final plainQuery = _stripCircumflex(cleanQuery);
    final stems = _extractTurkishStems(cleanQuery);

    final exactOrPrefixMatches = <DictionaryEntry>[];
    final contentMatches = <DictionaryEntry>[];

    for (final entry in uniqueEntries) {
      final wordLower = _toTurkishLower(entry.word);
      final wordPlain = _stripCircumflex(wordLower);
      final originLower = _toTurkishLower(entry.origin);
      final meaningLower = _toTurkishLower(entry.meaning);

      if (wordLower.startsWith(cleanQuery) ||
          wordPlain.startsWith(plainQuery) ||
          stems.any((s) => s.length >= 2 && (wordLower == s || wordPlain == s))) {
        exactOrPrefixMatches.add(entry);
      } else if (wordLower.contains(cleanQuery) ||
          wordPlain.contains(plainQuery) ||
          originLower.contains(cleanQuery) ||
          meaningLower.contains(cleanQuery)) {
        contentMatches.add(entry);
      }
    }

    return [...exactOrPrefixMatches, ...contentMatches];
  }

  /// Aynı kökenden veya ilişkili edebi/felsefi alandan kelimeler önerir.
  List<DictionaryEntry> getRelatedEntries(String currentWord, {int limit = 5}) {
    final currentEntry = lookup(currentWord);
    final currentOriginPrimary = currentEntry.origin.split(' ').first;

    final seenWords = <String>{currentEntry.word};
    final sameCategoryAndOrigin = <DictionaryEntry>[];
    final sameOriginOrCategory = <DictionaryEntry>[];
    final fallback = <DictionaryEntry>[];

    for (final entry in _localDictionary.values) {
      if (!seenWords.add(entry.word)) continue;

      final samePos = entry.partOfSpeech == currentEntry.partOfSpeech;
      final sameOrigin = entry.origin.startsWith(currentOriginPrimary);

      if (samePos && sameOrigin) {
        sameCategoryAndOrigin.add(entry);
      } else if (samePos || sameOrigin) {
        sameOriginOrCategory.add(entry);
      } else {
        fallback.add(entry);
      }
    }

    return [
      ...sameCategoryAndOrigin,
      ...sameOriginOrCategory,
      ...fallback,
    ].take(limit).toList();
  }
}

