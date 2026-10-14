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
  };

  /// Türkçe karakter duyarlı küçük harfe çevirme (`İ -> i`, `I -> ı`).
  static String _toTurkishLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
  }

  /// Şapkalı harfleri (â, î, û) düzleştirerek ikincil eşleşme anahtarı üretir.
  static String _stripCircumflex(String input) {
    return input
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  /// Türkçe çekim eklerini (çoğul, iyelik, hal, bildirme) soyarak ve
  /// ünsüz yumuşamasını (`b->p`, `c->ç`, `d->t`, `ğ->k`) tersine çevirerek
  /// olası kelime köklerini döndürür.
  List<String> _extractTurkishStems(String cleanWord) {
    final stems = <String>{};
    if (cleanWord.isEmpty) return const [];

    stems.add(cleanWord);
    stems.add(_stripCircumflex(cleanWord));

    // Uzun ekten kısa eke doğru sıralanmış Türkçe çekim ve yapım ekleri
    const suffixes = <String>[
      'larından', 'lerinden', 'larında', 'lerinde', 'larının', 'lerinin',
      'larına', 'lerine', 'larını', 'lerini', 'lardan', 'lerden',
      'larımız', 'lerimiz', 'larınız', 'leriniz', 'casına', 'cesine',
      'ları', 'leri', 'ndan', 'nden', 'mız', 'miz', 'muz', 'müz',
      'nız', 'niz', 'nuz', 'nüz', 'dan', 'den', 'tan', 'ten',
      'nda', 'nde', 'nın', 'nin', 'nun', 'nün', 'ına', 'ine',
      'una', 'üne', 'ını', 'ini', 'unu', 'ünü', 'yla', 'yle',
      'dır', 'dir', 'dur', 'dür', 'tır', 'tir', 'tur', 'tür',
      'lık', 'lik', 'luk', 'lük', 'sız', 'siz', 'suz', 'süz',
      'lar', 'ler', 'ın', 'in', 'un', 'ün', 'ya', 'ye',
      'na', 'ne', 'yı', 'yi', 'yu', 'yü', 'da', 'de',
      'ta', 'te', 'la', 'le', 'ca', 'ce', 'ça', 'çe',
      'ım', 'im', 'um', 'üm', 'lı', 'li', 'lu', 'lü',
      'cı', 'ci', 'cu', 'cü', 'çı', 'çi', 'çu', 'çü',
      'a', 'e', 'ı', 'i', 'u', 'ü',
    ];

    void addWithDevoicing(String candidate) {
      if (candidate.length < 3) return;
      stems.add(candidate);
      stems.add(_stripCircumflex(candidate));

      // Ünsüz yumuşaması tersine çevirme (b->p, c->ç, d->t, ğ->k, g->k)
      final prefix = candidate.substring(0, candidate.length - 1);
      final lastChar = candidate[candidate.length - 1];
      final devoiced = switch (lastChar) {
        'b' => '${prefix}p',
        'c' => '$prefixç',
        'd' => '${prefix}t',
        'ğ' => '${prefix}k',
        'g' => '${prefix}k',
        _ => null,
      };
      if (devoiced != null) {
        stems.add(devoiced);
        stems.add(_stripCircumflex(devoiced));
      }
    }

    // 1. Aşama ek soyma
    var currentFrontier = <String>{cleanWord};
    for (var pass = 0; pass < 2; pass++) {
      final nextFrontier = <String>{};
      for (final word in currentFrontier) {
        for (final suffix in suffixes) {
          if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
            final stripped = word.substring(0, word.length - suffix.length);
            addWithDevoicing(stripped);
            nextFrontier.add(stripped);
          }
        }
      }
      if (nextFrontier.isEmpty) break;
      currentFrontier = nextFrontier;
    }

    return stems.toList();
  }

  /// Looks up a word in the offline dictionary using morphological stemming
  DictionaryEntry lookup(String rawWord) {
    final clean = _toTurkishLower(rawWord)
        .replaceAll(RegExp(r'[^\wçğıöşüâîû]', unicode: true), '')
        .trim();

    if (clean.isEmpty) {
      return _localDictionary['tahrir']!;
    }

    // 1. Doğrudan eşleşme
    if (_localDictionary.containsKey(clean)) {
      return _localDictionary[clean]!;
    }

    // 2. Türkçe morfolojik kök bulucu ile eşleşme
    final candidateStems = _extractTurkishStems(clean);
    for (final stem in candidateStems) {
      if (stem.length >= 3 && _localDictionary.containsKey(stem)) {
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

    // 4. Anlamlı kök önek eşleşmesi (yalnızca kök uzunluğu >= 3 ve anlamlıysa)
    if (clean.length >= 4) {
      DictionaryEntry? bestPrefixMatch;
      var longestKeyLen = 0;
      for (final entry in _localDictionary.entries) {
        final key = entry.key;
        if (key.length >= 3 &&
            (clean.startsWith(key) ||
                _stripCircumflex(clean).startsWith(_stripCircumflex(key)))) {
          if (key.length > longestKeyLen) {
            longestKeyLen = key.length;
            bestPrefixMatch = entry.value;
          }
        }
      }
      if (bestPrefixMatch != null) {
        return bestPrefixMatch;
      }
    }

    return DictionaryEntry(
      word: rawWord.trim().isEmpty ? 'Kelime' : rawWord.trim(),
      origin: 'Türkçe / Edebi Kavram',
      partOfSpeech: 'İsim / Kavram',
      meaning:
          '"$rawWord" ibaresi metin bağlamında özel bir anlam taşımaktadır. Lügat arama çubuğundan kök kelimeyi veya yakın edebi terimleri sorgulayabilirsiniz.',
      example: '"Her kelime, içinde doğduğu cümlenin ikliminde nefes alır."',
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
      return uniqueEntries.take(20).toList();
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
          stems.any((s) => s.length >= 3 && (wordLower == s || wordPlain == s))) {
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
