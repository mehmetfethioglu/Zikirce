import 'package:drift/drift.dart';
import 'app_database.dart';

class ZikirSeedItem {
  final String name;
  final String arabic;
  final int target;
  final String category;
  final String virtue;
  final bool isFavorite;

  const ZikirSeedItem({
    required this.name,
    required this.arabic,
    required this.target,
    required this.category,
    required this.virtue,
    this.isFavorite = false,
  });
}

class ZikirSeedData {
  static const List<ZikirSeedItem> defaultZikirs = [
    // =========================================================================
    // 1. HADİSLERDEN ZİKİRLER (SAHİH HADİS METİNLERİYLE)
    // =========================================================================
    ZikirSeedItem(
      name: 'İstiğfar',
      arabic: 'أَسْتَغْفِرُ اللهَ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Vallâhi ben günde yetmiş defadan (bir rivayette yüz defadan) fazla Allah’tan beni bağışlamasını diler, O’na tövbe ve istiğfâr ederim." — "Kim istiğfâra devam ederse, Allah Teâlâ ona her darlıktan bir çıkış, her üzüntüden bir kurtuluş yolu gösterir ve onu ummadığı yerden rızıklandırır." (Buhârî, Daavât 3; Müslim, Zikir 41; Ebû Dâvûd, Vitir 26)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Besmele',
      arabic: 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Bir kimse evine girerken ve yemek yerken Allah’ın adını anarsa (Besmele çekerse), şeytan (avanesine): ‘Size burada ne gecelemek ne de akşam yemeği var!’ der." — "Allah’ın adı anılarak (Besmele ile) başlanmayan her önemli iş bereket ve hayırdan yoksundur." (Müslim, Eşribe 103; Ebû Dâvûd, Edeb 18; İbn Mâce, Nikâh 19)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Subhanallah',
      arabic: 'سُبْحَانَ اللهِ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Sizden önde gidenlere yetişebileceğiniz, sizden sonra gelenleri geçebileceğiniz, sizin yaptığınızı yapanlar dışında herkesten üstün olacağınız bir şeyi haber vereyim mi? Her farz namazın peşinden otuz üçer defa Sübhânallâh, Elhamdülillâh ve Allâhüekber deyiniz." (Buhârî, Ezân 155, Daavât 18; Müslim, Mesâcid 142)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Elhamdülillah',
      arabic: 'الْحَمْدُ لِلَّهِ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Temizlik imanın yarısıdır. «Elhamdülillâh» mîzanı (sevap terazisini) doldurur. «Sübhânallâh ve Elhamdülillâh» ise göklerle yer arasını doldurur." — "Her farz namazın peşinden otuz üçer defa Sübhânallâh, Elhamdülillâh ve Allâhüekber deyiniz." (Müslim, Tahâret 1; Buhârî, Ezân 155)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Allahuekber',
      arabic: 'اللهُ أَكْبَرُ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Kim her farz namazın ardından otuz üç defa Sübhânallâh, otuz üç defa Elhamdülillâh, otuz üç defa Allâhüekber der ve yüzüncüyü «Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü’l-mülkü ve lehü’l-hamdü ve hüve alâ külli şey’in kadîr» diyerek tamamlarsa, günahları deniz köpüğü kadar çok olsa bile bağışlanır." (Müslim, Mesâcid 146; Buhârî, Ezân 155)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Kelime-i Tevhid',
      arabic: 'لَا إِلَهَ إِلَّا اللهُ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Zikrin en faziletlisi «Lâ ilâhe illallâh», duanın en faziletlisi «Elhamdülillâh»tır." — "Kim Allah’ın rızasını dileyerek (ihlasla) «Lâ ilâhe illallâh» derse, Allah ona cehennem ateşini haram kılar." (Tirmizî, Daavât 9; Buhârî, Salât 46; Müslim, Mesâcid 263)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Salavat-ı Şerif',
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Kim bana bir defa salât ü selâm getirirse, Allah Teâlâ bu sebeple ona on rahmet ihsan eder, on hatasını siler ve derecesini on kat yükseltir." — "Kıyâmet gününde insanların bana en yakın olanları, bana en çok salât ü selâm getirenleridir." (Müslim, Salât 70; Nesâî, Sehv 55; Tirmizî, Vitir 21)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'İhlas-ı Şerif',
      arabic: 'قُلْ هُوَ اللهُ أَحَدٌ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Nefsim kudret elinde olan Allah’a yemin ederim ki, «Kul hüvallâhü ehad» (İhlâs sûresi) Kur’ân’ın üçte birine denktir." — Bir sahâbînin bu sûreyi Rahmân’ın sıfatı olduğu için çok sevdiğini söylemesi üzerine Resûlullah (s.a.v.): "Onu sevmen seni cennete koydu" buyurmuştur. (Buhârî, Fezâilü’l-Kur’ân 13, Tevhîd 1; Müslim, Müsâfirîn 259)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Salât-ı Adrikni (Çarem Tükendi)',
      arabic: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى سَيِّدِنَا مُحَمَّدٍ، قَدْ ضَاقَتْ حِيلَتِي أَدْرِكْنِي يَا رَسُولَ اللهِ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue:
          'Anlamı: "Allah’ım! Efendimiz Muhammed’e (s.a.v.) rahmet, selâmet ve bereket ihsan eyle; çarem daraldı, imdadıma yetiş yâ Resûlallah!" — Übey b. Ka‘b (r.a.): "Yâ Resûlallah! Dualarımın tamamını sana salât ü selâma ayırsam nasıl olur?" diye sorduğunda Peygamberimiz (s.a.v.) şöyle buyurmuştur: "Öyleyse bütün gam ve sıkıntıların giderilir, günahların bağışlanır." (Tirmizî, Kıyâmet 23; Müslim, Salât 70)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Mâşâallâh Lâ Kuvvete İllâ Billâh',
      arabic: 'مَا شَاءَ اللَّهُ لَا قُوَّةَ إِلَّا بِاللَّهِ',
      target: 99,
      category: 'Hadislerden Zikirler',
      virtue:
          'Anlamı: "Allah’ın dilediği olur; güç ve kuvvet ancak Allah’ındır." (Kehf, 39) — Ebû Mûsâ el-Eş‘arî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Sana cennet hazinelerinden bir hazineyi bildireyim mi? O, «Lâ havle ve lâ kuvvete illâ billâh» sözüdür." Ayrıca hoşuna giden bir nimet gören kimsenin nazar değmemesi için bereket duası etmesi sünnettir. (Buhârî, Daavât 50; Müslim, Zikir 44; İbn Mâce, Tıbb 32)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Lâ havle ve lâ kuvvete illâ billâh',
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue:
          '"Ey Abdullah b. Kays! Sana cennet hazinelerinden bir hazineyi haber vereyim mi? «Lâ havle ve lâ kuvvete illâ billâh» (Günahtan kaçacak güç ve ibadet edecek kuvvet ancak Allah’ın yardımıyladır) de!" (Buhârî, Daavât 50; Müslim, Zikir 44)',
      isFavorite: false,
    ),
    ZikirSeedItem(
      name: 'Hasbünallahu ve ni\'mel vekil',
      arabic: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue:
          'İbn Abbâs (r.a.) şöyle demiştir: "«Hasbünallâhü ve ni‘me’l-vekîl» (Allah bize yeter, O ne güzel vekildir) sözünü İbrâhim (a.s.) ateşe atıldığında söyledi; Muhammed (s.a.v.) de insanlar kendisine: ‘İnsanlar size karşı toplandı, onlardan korkun!’ dediklerinde söyledi; bu onların imanını artırdı." (Buhârî, Tefsîr 3/13; Âl-i İmrân, 173)',
      isFavorite: false,
    ),

    // =========================================================================
    // 2. ESMAÜL HÜSNA (99 İSİM - İSMİN MÂNÂSI & SAHİH HADİS-İ ŞERİFLER)
    // =========================================================================
    ZikirSeedItem(
      name: 'Allah',
      arabic: 'اللهُ',
      target: 66,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün kemâl sıfatları kendisinde toplayan, varlığı zorunlu ve gerçek ma‘bûd olan Zat ismi (İsm-i Celâl). — Resûlullah (s.a.v.), bir sahâbînin: "Allah’ım! Senin Allah olduğun ve Senden başka ilâh bulunmadığı şehadetiyle Senden istiyorum" duasını işitince şöyle buyurmuştur: "Nefsim kudret elinde olan Allah’a yemin ederim ki, kendisiyle dua edildiğinde icabet ettiği ve istendiğinde verdiği İsm-i A‘zam’ı ile Allah’tan istedi!" (Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 64; İbn Mâce, Duâ 9)',
    ),
    ZikirSeedItem(
      name: 'Er-Rahmân',
      arabic: 'الرَّحْمَنُ',
      target: 298,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dünyada mümin-kâfir ayırt etmeksizin bütün mahlûkata şefkat ve merhamet eden, sayısız nimetler bahşeden. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah mahlûkatı yarattığında, Arş’ın üstünde kendi katında bulunan Kitab’a: ‘Şüphesiz rahmetim gazabımı geçmiştir’ diye yazdı." Yine kudsî hadiste: "Ben Rahmân’ım; rahimi (akrabalık bağını) yarattım ve ona ismimden bir isim verdim. Kim onu gözetirse Ben de ona rahmetimle muamele ederim." buyrulmuştur. (Buhârî, Tevhîd 15; Müslim, Tevbe 14; Ebû Dâvûd, Zekât 45)',
    ),
    ZikirSeedItem(
      name: 'Er-Rahîm',
      arabic: 'الرَّحِيمُ',
      target: 258,
      category: 'Esmaül-Hüsna',
      virtue:
          'Yarattığı nimetleri güzel kullananlara daha büyük ve ebedî nimetler veren, ahirette mümin kullarına hususî rahmetiyle muamele eden. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah rahmeti yüz parçaya ayırdı; doksan dokuz parçasını kendi katında tuttu, yeryüzüne ise bir parça indirdi. Mahlûkat bu bir parça rahmet sebebiyle birbirine şefkat gösterir; doksan dokuz rahmeti ise kıyamet günü kullarına merhamet etmek için ayırmıştır." (Buhârî, Edeb 19; Müslim, Tevbe 17)',
    ),
    ZikirSeedItem(
      name: 'El-Melik',
      arabic: 'الْمَلِكُ',
      target: 90,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün kâinatın mutlak sahibi ve hükümdarı, mülkünde dilediği gibi tasarruf eden. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Kıyamet gününde Allah yeryüzünü kabza-i kudretine alır, gökleri sağ eliyle dürer ve: ‘Ben Melik’im (gerçek hükümdarım)! Yeryüzünün hükümdarları nerede?’ buyurur." (Buhârî, Tefsîr 39/2, Rikâk 44; Müslim, Münâfikîn 23)',
    ),
    ZikirSeedItem(
      name: 'El-Kuddûs',
      arabic: 'الْقُدُّوسُ',
      target: 170,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her türlü eksiklik, kusur, gaflet ve acizlikten münezzeh, tertemiz ve mukaddes olan; kalpleri mânevî kirlerden arındıran. — Hz. Âişe (r.a.) validemizden rivayetle Resûlullah (s.a.v.) rükû ve secdelerinde: "Sübbûhun Kuddûsün Rabbü’l-melâiketi ve’r-rûh (Her türlü noksandan münezzeh ve mukaddestir; meleklerin ve Cebrâil’in Rabbidir)" diye tesbih ederdi. (Müslim, Salât 223; Ebû Dâvûd, Salât 148)',
    ),
    ZikirSeedItem(
      name: 'Es-Selâm',
      arabic: 'السَّلَامُ',
      target: 131,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her türlü âfet ve kusurdan salim olan, kullarını korkulardan emin kılıp selâmet ve esenliğe çıkaran. — Sevbân’dan (r.a.) rivayetle Resûlullah (s.a.v.) namazdan selâm verip çıktığında üç defa istiğfâr eder ve şöyle buyururdu: "Allâhümme ente’s-Selâm ve minke’s-selâm, tebârekte yâ Ze’l-celâli ve’l-ikrâm (Allah’ım! Sen Selâm’sın, selâmet ve esenlik de Sendendir; ey celâl ve ikram sahibi, Sen ne yücesin!)." (Müslim, Mesâcid 135; Tirmizî, Salât 108)',
    ),
    ZikirSeedItem(
      name: 'El-Mü\'min',
      arabic: 'الْمُؤْمِنُ',
      target: 137,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kalplerde iman nurunu yakan, kendisine sığınan kullarına emniyet ve güven veren, vaadinde sadık olan. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah’tan dünyada ve ahirette af ve âfiyet (emniyet) isteyin." — "Şüphesiz Allah’ın doksan dokuz ismi vardır: O; Melik, Kuddûs, Selâm, Mü’min, Müheymin’dir... Kim bunları ihsâ ederse (mânâsıyla kavrayıp yaşarsa) cennete girer." (Tirmizî, Daavât 82, 105; Buhârî, Daavât 68)',
    ),
    ZikirSeedItem(
      name: 'El-Muheymin',
      arabic: 'الْمُهَيْمِنُ',
      target: 145,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün varlıkları ilmi, rahmeti ve kudretiyle gözetip koruyan, her şeye şahit olan ve hükmü altına alan. — Resûlullah (s.a.v.) dualarında şöyle niyaz ederdi: "Allah’ım! Gayb ilminle ve mahlûkat üzerindeki kudretinle Senden dilerim..." — "Şüphesiz Allah’ın doksan dokuz ismi vardır; kim bunları ihsâ ederse cennete girer: O; Mü’min, Müheymin, Azîz’dir." (Nesâî, Sehv 62; Tirmizî, Daavât 82; Buhârî, Daavât 68)',
    ),
    ZikirSeedItem(
      name: 'El-Aziz',
      arabic: 'الْعَزِيزُ',
      target: 94,
      category: 'Esmaül-Hüsna',
      virtue:
          'Mutlak izzet ve kudret sahibi, yenilmesi imkânsız olan, her şeye galip gelen ve mümin kullarını aziz kılan. — Osman b. Ebü’l-Âs’tan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Bedeninde ağrı hisseden kimse elini ağrıyan yere koysun, üç defa ‘Bismillâh’ desin ve yedi defa: ‘Eûzü bi-izzetillâhi ve kudretihî min şerri mâ ecidü ve ühâziru (Hissettiğim ve çekindiğim ağrının şerrinden Allah’ın izzetine ve kudretine sığınırım)’ desin." (Müslim, Selâm 67; Tirmizî, Tıbb 29)',
    ),
    ZikirSeedItem(
      name: 'El-Cebbâr',
      arabic: 'الْجَبَّارُ',
      target: 206,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kırılan gönülleri onaran, mahzunların ve zayıfların eksiklerini sarıp tamamlayan, iradesini her durumda yürüten. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) namazda iki secde arasında şöyle dua ederdi: "Allâhümmağfirlî verhamnî vecburnî vehdinî verzuknî (Allah’ım! Beni bağışla, bana merhamet et, kırıklarımı ve eksiklerimi onar, bana hidayet ve rızık ver)." (Ebû Dâvûd, Salât 145; Tirmizî, Salât 97)',
    ),
    ZikirSeedItem(
      name: 'El-Mütekebbir',
      arabic: 'الْمُتَكَبِّرُ',
      target: 662,
      category: 'Esmaül-Hüsna',
      virtue:
          'Büyüklük ve ululukta eşi olmayan, azamet ve kibriyâ yalnızca kendisine mahsus olan. — Ebû Hüreyre ve Ebû Saîd el-Hudrî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Aziz ve Celîl olan Allah şöyle buyurur: Kibriyâ (büyüklük) Benim ridâm, azamet ise Benim izârımdır. Kim bunlardan biri hususunda Benimle yarışmaya kalkışırsa, onu cehenneme atarım." (Müslim, Birr 136; Ebû Dâvûd, Libâs 26)',
    ),
    ZikirSeedItem(
      name: 'El-Hâlık',
      arabic: 'الْخَالِقُ',
      target: 731,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her şeyi yoktan var eden, her varlığı hikmetli bir ölçü ve takdirle yaratan. — İmrân b. Husayn’dan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah vardı ve O’ndan başka hiçbir şey yoktu; Arş’ı su üzerindeydi, Levh-i Mahfûz’da her şeyi yazdı ve gökleri ile yeri yarattı." Yine: "Yaratan Allah’a isyan hususunda hiçbir yaratılmışa itaat edilmez." buyrulmuştur. (Buhârî, Bed’ü’l-halk 1; Müslim, İmâre 39; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Bâri',
      arabic: 'الْبَارِئُ',
      target: 214,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlıkları birbirine uygun, ahenkli, kusursuz ve örneksiz olarak yoktan icat eden. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah’ın doksan dokuz —yüzden bir eksik— ismi vardır. O; Hâlık, Bâri, Musavvir’dir. Kim bu isimleri ihsâ ederse (öğrenir, mânâsını tefekkür edip gereğiyle amel ederse) cennete girer." (Buhârî, Daavât 68; Müslim, Zikir 5; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Musavvir',
      arabic: 'الْمُصَوِّرُ',
      target: 336,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her varlığa kendisine has en güzel şekli, sureti ve eşsiz simayı veren. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah sizin suretlerinize ve mallarınıza bakmaz; lâkin kalplerinize ve amellerinize bakar." Yaratılışın kemâli ve işlerde maharet için zikredilir. (Müslim, Birr 34; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Gaffâr',
      arabic: 'الْغَفَّارُ',
      target: 1281,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarının günahlarını ve ayıplarını örten, tövbe edenleri tekrar tekrar ve çokça bağışlayan. — Hz. Âişe (r.a.) validemizden rivayetle Resûlullah (s.a.v.) gece uykudan uyandığında şöyle dua ederdi: "Lâ ilâhe illallâhü’l-Vâhidü’l-Kahhâr, Rabbü’s-semâvâti ve’l-ardı ve mâ beynehüme’l-Azîzü’l-Gaffâr (Tek ve Kahhâr olan, göklerin, yerin ve ikisi arasındakilerin Rabbi, Azîz ve çok bağışlayan Gaffâr olan Allah’tan başka ilâh yoktur)." (Nesâî, es-Sünenü’l-kübrâ 10638; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Kahhâr',
      arabic: 'الْقَهَّارُ',
      target: 306,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her şeye mutlak galip gelen, bütün varlıkların kudreti karşısında boyun eğdiği yegâne hükümran. — Resûlullah (s.a.v.) geceleyin yatağında döndüğünde: "Lâ ilâhe illallâhü’l-Vâhidü’l-Kahhâr (Tek ve mutlak galip olan Allah’tan başka ilâh yoktur)..." diye zikrederdi. Nefsin şerrinden ve zalimlerin zulmünden Allah’a sığınmak için okunur. (Nesâî, es-Sünenü’l-kübrâ 10638; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Vehhâb',
      arabic: 'الْوَهَّابُ',
      target: 14,
      category: 'Esmaül-Hüsna',
      virtue:
          'Karşılıksız olarak bol bol hibe eden, nimet ve ihsanı ardı arkası kesilmeksizin bağışlayan. — Hz. Âişe’den (r.a.) rivayetle Resûlullah (s.a.v.) gece uyandığında: "Rabbimiz! Bize hidayet verdikten sonra kalplerimizi eğriltme ve bize katından bir rahmet bağışla; şüphesiz Sen çok bağışta bulunan Vehhâb’sın (Âl-i İmrân, 8)" diye dua ederdi. (Buhârî, Tefsîr 3/1; Müslim, Mesâcid 137; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Er-Rezzâk',
      arabic: 'الرَّزَّاقُ',
      target: 308,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün canlıların maddî ve manevî rızkını yaratan, takdir eden ve her varlığa rızkını ulaştıran. — Enes b. Mâlik’ten (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz fiyatlar elinde olan, darlık veren (Kâbıd), bolluk veren (Bâsıt) ve rızıklandıran (er-Rezzâk) ancak Allah’tır." (Ebû Dâvûd, Büyû‘ 49; Tirmizî, Büyû‘ 73; İbn Mâce, Ticârât 27)',
    ),
    ZikirSeedItem(
      name: 'El-Fettâh',
      arabic: 'الْفَتَّاحُ',
      target: 489,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her türlü müşkülü ve kapalılığı çözen, kullarına maddî ve manevî rahmet ve hayır kapılarını açan, adaletle hükmeden. — Ebû Humeyd ve Ebû Üseyd’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Biriniz mescide girdiğinde Peygamber’e selâm versin ve: ‘Allâhümmeftah lî ebvâbe rahmetik (Allah’ım! Bana rahmetinin kapılarını aç)’ desin." (Müslim, Müsâfirîn 68; Ebû Dâvûd, Salât 18)',
    ),
    ZikirSeedItem(
      name: 'El-Alim',
      arabic: 'الْعَلِيمُ',
      target: 150,
      category: 'Esmaül-Hüsna',
      virtue:
          'Gizli ve açık, geçmiş ve gelecek, küçük ve büyük her şeyi ezeli ilmiyle en ince ayrıntısına kadar hakkıyla bilen. — Câbir b. Abdullah’tan (r.a.) rivayetle Resûlullah (s.a.v.) istihâre duasında şöyle öğretmiştir: "Allâhümme innî estehîruke bi-ilmike... inneke ta‘lemü ve lâ a‘lemü ve ente Allâmü’l-guyûb (Allah’ım! İlmine güvenerek Senden hakkımda hayırlısını isterim; şüphesiz Sen bilirsin, ben bilmem; Sen gaybları en iyi bilensin)." (Buhârî, Teheccüd 25; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Kâbid',
      arabic: 'الْقَابِضُ',
      target: 903,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hikmeti gereği dilediğine rızkı daraltan, kalpleri ve bütün varlıkları kudret elinde tutan, eceli gelenlerin ruhunu kabzeden. — Enes b. Mâlik’ten (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah; fiyat koyan, daraltan (el-Kâbıd), genişleten (el-Bâsıt) ve rızıklandıran (er-Râzık) O’dur." (Ebû Dâvûd, Büyû‘ 49; Tirmizî, Büyû‘ 73, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Bâsit',
      arabic: 'الْبَاسِطُ',
      target: 72,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dilediğine rızkı genişletip bereketlendiren, daralan gönüllere inşirah ve ferahlık veren, tövbeleri kabul için rahmet elini açan. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah, gündüz günah işleyenin tövbesini kabul etmek için geceleyin rahmet elini açar (yebsutu yedehû); gece günah işleyenin tövbesini kabul etmek için de gündüz rahmet elini açar." (Müslim, Tevbe 31; Tirmizî, Büyû‘ 73)',
    ),
    ZikirSeedItem(
      name: 'El-Hafid',
      arabic: 'الْخَافِضُ',
      target: 1481,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hakka karşı kibirlenenleri, zalimleri ve azgınları alçaltan, hak ettikleri aşağı derecelere indiren. — Ebû Mûsâ el-Eş‘arî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah uyumaz ve uyumak O’nun şânına yaraşmaz; O, mîzanı (ölçüyü ve rızkı) indirir (yahfidu) ve yükseltir (yerfeu)." (Müslim, Îmân 293; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Er-Rafi\'',
      arabic: 'الرَّافِعُ',
      target: 351,
      category: 'Esmaül-Hüsna',
      virtue:
          'İman, ilim ve tevazu sahiplerinin dünya ve ahirette derecelerini, şeref ve makamlarını yükselten. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Sadaka malı eksiltmez; Allah affeden bir kulunun ancak izzetini artırır ve kim Allah için tevazu gösterirse, Allah onu mutlaka yükseltir (refe‘ahullâh)." (Müslim, Birr 69; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Muiz',
      arabic: 'الْمُعِزُّ',
      target: 117,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dilediği kuluna izzet, şeref, vakâr ve galibiyet bahşeden, itaatkâr kullarını aziz kılan. — Hz. Ömer’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah bu Kitap (Kur’ân) ile nice toplulukları yükseltir (aziz kılar) ve onunla diğerlerini alçaltır." — "O; Hâfıd, Râfi‘, Mu‘iz, Müzill’dir." (Müslim, Müsâfirîn 269; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Muzil',
      arabic: 'الْمُذِلُّ',
      target: 770,
      category: 'Esmaül-Hüsna',
      virtue:
          'Emirlerine baş kaldıran, kibir ve zulüm yoluna sapanları zillete düşüren ve zelil kılan. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Benim emrime muhalefet edenlere zillet ve küçüklük verildi." — "Şüphesiz Allah’ın doksan dokuz ismi vardır: O; Mu‘iz ve Müzill’dir. Kim bunları ihsâ ederse cennete girer." (Buhârî, Cihâd 88; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Es-Semi\'',
      arabic: 'السَّمِيعُ',
      target: 180,
      category: 'Esmaül-Hüsna',
      virtue:
          'Gizli ve açık her sesi, her fısıltıyı ve gönülden yükselen her duayı eksiksiz işiten. — Ebû Mûsâ el-Eş‘arî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Ey insanlar! Kendinize acıyın (sesinizi aşırı yükseltmeyin). Çünkü siz sağır ve uzakta olan birine dua etmiyorsunuz; şüphesiz siz her şeyi işiten (Semî‘) ve size çok yakın olan Allah’a dua ediyorsunuz." (Buhârî, Cihâd 131, Daavât 50; Müslim, Zikir 44)',
    ),
    ZikirSeedItem(
      name: 'El-Basir',
      arabic: 'الْبَصِيرُ',
      target: 302,
      category: 'Esmaül-Hüsna',
      virtue:
          'Karanlıkta ve aydınlıkta, gizli ve açık her şeyi eksiksiz gören, kullarının bütün hallerine muttali olan. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz siz her şeyi işiten (Semî‘) ve her şeyi gören (Basîr) Allah’a dua ediyorsunuz." Cibrîl hadisinde de: "Sen O’nu görmesen de O seni mutlaka görmektedir." buyrulmuştur. (Buhârî, Cihâd 131, Îmân 37; Müslim, Zikir 44)',
    ),
    ZikirSeedItem(
      name: 'El-Hakem',
      arabic: 'الْحَكَمُ',
      target: 68,
      category: 'Esmaül-Hüsna',
      virtue:
          'Mutlak hüküm sahibi olan, hak ile bâtılı birbirinden ayıran ve verdiği hüküm asla bozulmayan. — Ebû Şüreyh Hânî b. Yezîd’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Hakem olan Allah’tır ve hüküm ancak O’na aittir." (Ebû Dâvûd, Edeb 62; Nesâî, Kudât 7; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Adl',
      arabic: 'الْعَدْلُ',
      target: 104,
      category: 'Esmaül-Hüsna',
      virtue:
          'Mutlak adalet sahibi olan, hiçbir kuluna zerre kadar zulmetmeyen, her şeyi hikmetle yerli yerine koyan. — Ebû Zer el-Gıfârî’den (r.a.) rivayet edilen kudsî hadiste Allah Teâlâ şöyle buyurur: "Ey kullarım! Ben zulmü kendime haram kıldım ve onu sizin aranızda da haram kıldım; öyleyse birbirinize zulmetmeyin!" (Müslim, Birr 55; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Latîf',
      arabic: 'اللَّطِيفُ',
      target: 129,
      category: 'Esmaül-Hüsna',
      virtue:
          'En ince ve gizli sırları bilen, kullarına sezdirmeden pek ince ve nazik yollarla lütufta ve ihsanda bulunan. — Hz. Âişe (r.a.) validemizden rivayetle Cebrâil (a.s.) Peygamberimize (s.a.v.) şöyle seslenmiştir: "Şüphesiz Latîf ve Habîr olan Allah sana haber veriyor..." (Müslim, Cenâiz 103; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Habîr',
      arabic: 'الْخَبِيرُ',
      target: 812,
      category: 'Esmaül-Hüsna',
      virtue:
          'Eşyanın ve hadiselerin iç yüzünden, kalplerde gizlenen niyetlerden ve en derin sırlardan tam anlamıyla haberdar olan. — Hz. Âişe (r.a.) validemizden rivayetle Resûlullah (s.a.v.): "Bunu bana her şeyi bilen Alîm ve her şeyin iç yüzünden haberdar olan Habîr (Allah) bildirdi." buyurmuştur. (Buhârî, Tefsîr 66/3; Müslim, Cenâiz 103; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Halîm',
      arabic: 'الْحَلِيمُ',
      target: 88,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kudreti sonsuz olduğu halde günahkârları cezalandırmakta acele etmeyen, tövbe etmeleri için mühlet veren, yumuşak muamele eden. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) sıkıntı ve üzüntü anında şöyle dua ederdi: "Lâ ilâhe illallâhü’l-Azîmü’l-Halîm, lâ ilâhe illallâhü Rabbü’l-Arşi’l-azîm (Azîm ve Halîm olan Allah’tan başka ilâh yoktur; yüce Arş’ın Rabbi olan Allah’tan başka ilâh yoktur)." (Buhârî, Daavât 27; Müslim, Zikir 83)',
    ),
    ZikirSeedItem(
      name: 'El-Azîm',
      arabic: 'الْعَظِيمُ',
      target: 1020,
      category: 'Esmaül-Hüsna',
      virtue:
          'Zatında, sıfatlarında ve fiillerinde sonsuz büyüklük, ululuk ve azamet sahibi olan. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "İki kelime vardır ki dile hafif, mîzanda (sevap terazisinde) ağır, Rahmân’a sevgilidir: «Sübhânallâhi ve bihamdihî, Sübhânallâhi’l-Azîm»." (Buhârî, Daavât 65, Tevhîd 58; Müslim, Zikir 31)',
    ),
    ZikirSeedItem(
      name: 'El-Gafûr',
      arabic: 'الْغَفُورُ',
      target: 1286,
      category: 'Esmaül-Hüsna',
      virtue:
          'Mağfireti pek geniş olan, samimiyetle tövbe eden kullarının günahlarını ne kadar çok olursa olsun bağışlayan. — Hz. Ebû Bekir (r.a.) namazda okumak üzere bir dua istediğinde Resûlullah (s.a.v.) şöyle öğretti: "Allâhümme innî zalemtü nefsî zulmen kesîran ve lâ yağfiru’z-zünûbe illâ ente, fağfirlî mağfireten min indike verhamnî, inneke ente’l-Gafûru’r-Rahîm (Allah’ım! Nefsime çok zulmettim, günahları ancak Sen bağışlarsın; beni katından bir mağfiretle bağışla ve bana merhamet et; şüphesiz Sen Gafûr ve Rahîm’sin)." (Buhârî, Ezân 149; Müslim, Zikir 48)',
    ),
    ZikirSeedItem(
      name: 'Eş-Şekûr',
      arabic: 'الشَّكُورُ',
      target: 526,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarının rızası için yaptığı az ameli dahi kabul edip karşılığında kat kat sevap ve ebedî nimetler ihsan eden. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Bir adam yolda yürürken susuzluktan toprağı yalayan bir köpeğe kuyudan su çıkarıp içirdi; Allah da onun bu güzel davranışını takdir edip (şekerallâhü lehû) günahlarını bağışladı." (Buhârî, Müsâkât 9; Müslim, Selâm 153; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Aliyy',
      arabic: 'الْعَلِيُّ',
      target: 110,
      category: 'Esmaül-Hüsna',
      virtue:
          'İzzet, şeref, kudret ve hükümranlık bakımından en yüce olan, hiçbir şeyin kendisinden üstün olmadığı. — Übey b. Ka‘b’dan (r.a.) rivayetle Resûlullah (s.a.v.), sonunda «ve hüve’l-Aliyyü’l-Azîm» geçen Âyete’l-Kürsî’nin Allah’ın Kitabı’ndaki en yüce âyet olduğunu bildirmiş ve: "Ey Ebü’l-Münzir! İlim sana mübarek olsun." buyurmuştur. (Müslim, Müsâfirîn 258; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Kebîr',
      arabic: 'الْكَبِيرُ',
      target: 232,
      category: 'Esmaül-Hüsna',
      virtue:
          'Büyüklükte eşi ve benzeri olmayan, kâinattaki her şeyden büyük ve yüce olan. — İbn Ömer (r.a.) anlatıyor: Biz Resûlullah (s.a.v.) ile namaz kılarken cemaatten bir adam: "Allâhü ekberu kebîrâ, ve’l-hamdü lillâhi kesîrâ, ve sübhânallâhi bükraten ve asîlâ" dedi. Resûlullah (s.a.v.): "Bu sözler hoşuma gitti; onlar için göğün kapıları açıldı!" buyurdu. (Müslim, Mesâcid 150; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Hafîz',
      arabic: 'الْحَفِظُ',
      target: 998,
      category: 'Esmaül-Hüsna',
      virtue:
          'Gökleri, yeri ve bütün mevcudatı zevalden koruyan, kullarının amellerini zerre miktarı zayi etmeden muhafaza eden. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Delikanlı! Sana bazı kelimeler öğreteyim: Allah’ın hakkını (emir ve sınırlarını) koru ki, Allah da seni korusun (ihfazillâhe yahfazke)." (Tirmizî, Kıyâmet 59, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Mukît',
      arabic: 'الْمُقِيتُ',
      target: 550,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her yaratılmışın bedenî ve ruhî gıdasını, azığını takdir edip ulaştıran, her şeyi görüp gözeten ve her şeye gücü yeten. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah’ın doksan dokuz ismi vardır: O; Hafîz, Mukît, Hasîb’dir... Kim bunları ihsâ ederse cennete girer." (Tirmizî, Daavât 82; Buhârî, Daavât 68)',
    ),
    ZikirSeedItem(
      name: 'El-Hasîb',
      arabic: 'الْحَسِيبُ',
      target: 80,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarının bütün amellerini inceden inceye hesaba çeken ve kendisine tevekkül eden kullarına her hususta kâfi gelen (yeten). — Şeddâd b. Evs’ten (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Akıllı kimse, nefsini hesaba çeken ve ölümden sonrası için çalışan kimsedir." — "Allah bize yeter (Hasbünallâh), O ne güzel vekildir." (Tirmizî, Kıyâmet 25, Daavât 82; Buhârî, Tefsîr 3/13)',
    ),
    ZikirSeedItem(
      name: 'El-Celîl',
      arabic: 'الْجَلِيلُ',
      target: 73,
      category: 'Esmaül-Hüsna',
      virtue:
          'Celâl, azamet, heybet ve ululuk sahibi olan, zatı ve sıfatları sonsuz kemâlde bulunan. — Enes b. Mâlik’ten (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "«Yâ Ze’l-celâli ve’l-ikrâm» (Ey celâl ve ikram sahibi!) sözüne devam ediniz." (Tirmizî, Daavât 91, 82; Nesâî, es-Sünenü’l-kübrâ 7671)',
    ),
    ZikirSeedItem(
      name: 'El-Kerîm',
      arabic: 'الْكَرِيمُ',
      target: 270,
      category: 'Esmaül-Hüsna',
      virtue:
          'Cömertliği, lütfu ve ihsanı sınırsız olan, istemeden veren, kendisinden istenildiğinde boş çevirmeyen ve bağışlamayı seven. — Selmân-ı Fârisî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Rabbiniz Hayî (hayâ sahibi) ve Kerîm’dir (sonsuz cömerttir); kulu ellerini O’na kaldırdığında onları boş çevirmekten hayâ eder." (Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 104)',
    ),
    ZikirSeedItem(
      name: 'Er-Rakîb',
      arabic: 'الرَّقِيبُ',
      target: 312,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün varlıkları her an gözetleyen, kalplerden geçenlerin ve yapılan işlerin hiçbirinin kendisinden gizli kalmadığı. — Cibrîl hadisinde Resûlullah (s.a.v.) ihsan makamını şöyle tarif etmiştir: "Allah’a, O’nu görüyormuşsun gibi ibadet etmendir; çünkü sen O’nu görmesen de O seni mutlaka görmektedir (gözetlemektedir)." (Buhârî, Îmân 37; Müslim, Îmân 1; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Mücîb',
      arabic: 'الْمُجِيبُ',
      target: 55,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kendisine yönelip yalvaran kullarının dualarına ve yakarışlarına icabet eden, ihtiyaçlarını gideren. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Rabbimiz Tebâreke ve Teâlâ her gece, gecenin son üçte biri kaldığında dünya semasına rahmetiyle tecellî eder ve: ‘Bana dua eden yok mu, duasına icabet edeyim! Benden isteyen yok mu, ona vereyim! Benden bağışlanma dileyen yok mu, onu bağışlayayım!’ buyurur." (Buhârî, Teheccüd 14; Müslim, Müsâfirîn 168)',
    ),
    ZikirSeedItem(
      name: 'El-Vâsi\'',
      arabic: 'الْوَاسِعُ',
      target: 137,
      category: 'Esmaül-Hüsna',
      virtue:
          'İlmi, rahmeti, kudreti, affı ve nimet hazinesi her şeyi kuşatacak kadar geniş olan, tükenmeyen. — Ebû Mûsâ el-Eş‘arî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle dua ederdi: "Allah’ım! Günahımı bağışla, yurdumu (gönlümü ve hanemi) genişlet ve bana verdiğin rızkı bereketlendir." (Tirmizî, Daavât 79, 82; Müslim, Zikir 63)',
    ),
    ZikirSeedItem(
      name: 'El-Hakîm',
      arabic: 'الْحَكِيمُ',
      target: 78,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün emirleri, hükümleri ve yaratışı tam bir hikmet, gaye ve maslahat üzere olan, abes işten münezzeh bulunan. — İbn Mes‘ûd’dan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah kime hikmet (ilim ve doğru anlayış) vermişse ve o da bununla hükmedip öğretiyorsa, o kimseye gıpta edilir." (Buhârî, İlim 15; Müslim, Müsâfirîn 268; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Vedûd',
      arabic: 'الْوَدُودُ',
      target: 20,
      category: 'Esmaül-Hüsna',
      virtue:
          'Salih kullarını çok seven, onları rahmet ve rızasına erdiren ve müminler tarafından her şeyden çok sevilen. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah bir kulu sevdiği zaman Cebrâil’e: ‘Allah filanı seviyor, onu sen de sev!’ diye seslenir. Cebrâil de onu sever ve gök ehline: ‘Allah filanı seviyor, siz de onu sevin!’ diye nida eder; böylece yeryüzündekilerin kalbine de onun sevgisi ve hüsnükabulü konulur." (Buhârî, Bed’ü’l-halk 6, Edeb 41; Müslim, Birr 157)',
    ),
    ZikirSeedItem(
      name: 'El-Mecîd',
      arabic: 'الْمَاجِدُ',
      target: 57,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kadr ü şânı çok yüce, keremi, ihsanı ve övgüsü sonsuz olan. — Ka‘b b. Ucre’den (r.a.) rivayetle Resûlullah (s.a.v.) namazların sonunda okunan Salli-Bârik dualarını şöyle öğretmiştir: "Allâhümme salli alâ Muhammedin ve alâ âli Muhammed... inneke Hamîdün Mecîd (Şüphesiz Sen çok övülen Hamîd ve şânı yüce Mecîd’sin)." (Buhârî, Daavât 32; Müslim, Salât 66)',
    ),
    ZikirSeedItem(
      name: 'El-Bâis',
      arabic: 'الْبَاعِثُ',
      target: 573,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarına hidayet için peygamberler gönderen, gönüllerde hayır şevki uyandıran ve kıyamet günü ölüleri kabirlerinden diriltip kaldıran. — Huzeyfe b. Yemân’dan (r.a.) rivayetle Resûlullah (s.a.v.) uykudan uyandığında şöyle dua ederdi: "Elhamdülillâhillezî ahyânâ ba‘de mâ emâtenâ ve ileyhi’n-nüşûr (Bizi öldürdükten —uyuttuktan— sonra dirilten Allah’a hamdolsun; dönüş ve yeniden diriliş ancak O’nadır)." (Buhârî, Daavât 7; Müslim, Zikir 59; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Eş-Şehîd',
      arabic: 'الشَّهِيدُ',
      target: 319,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her zaman ve her yerde hazır ve nazır olan, gizli ve açık yapılan her şeye bizzat şahit olan. — Enes b. Mâlik’ten (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Kim sabaha çıktığında veya akşama girdiğinde: ‘Allah’ım! Seni, Arş’ını taşıyanları ve meleklerini şahit tutarım ki Sen Allah’sın, Senden başka ilâh yoktur’ derse, Allah onu cehennemden azat eder." (Ebû Dâvûd, Edeb 101; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Hakk',
      arabic: 'الْحَقُّ',
      target: 108,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlığı ve ilâhlığı mutlak gerçek olan, hiç değişmeyen, sözü, vaadi ve hükmü hak olan. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) gece namazına kalktığında şöyle dua ederdi: "Allâhümme leke’l-hamdü... ente’l-Hakk, ve va‘düke’l-hakk, ve likâüke hakk, ve kavluke hakk (Allah’ım! Hamd Sana mahsustur; Sen Hakk’sın, vaadin haktır, Sana kavuşmak haktır, sözün haktır)." (Buhârî, Teheccüd 1, Tevhîd 8; Müslim, Müsâfirîn 199)',
    ),
    ZikirSeedItem(
      name: 'El-Vekîl',
      arabic: 'الْوَكِيلُ',
      target: 66,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kendisine tevekkül edip işlerini bırakan kullarının işlerini en güzel şekilde yoluna koyan, güvenilip dayanılan yegâne dost. — Hz. Ömer’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Eğer siz Allah’a hakkıyla tevekkül etseydiniz, O, sabahleyin kursakları boş çıkıp akşamleyin tok dönen kuşları rızıklandırdığı gibi sizi de mutlaka rızıklandırırdı." (Tirmizî, Zühd 33; İbn Mâce, Zühd 14; Buhârî, Tefsîr 3/13)',
    ),
    ZikirSeedItem(
      name: 'El-Kavî',
      arabic: 'الْقَوِيُّ',
      target: 116,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kudreti eksilmeyen, kendisine hiçbir acizlik, gevşeklik ve yorgunluk erişmeyen tam kuvvet sahibi. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Kuvvetli mümin, Allah katında zayıf müminden daha hayırlı ve daha sevimlidir; bununla birlikte her ikisinde de hayır vardır. Sana fayda veren şeye gayret et, Allah’tan yardım iste ve acizlik gösterme!" (Müslim, Kader 34; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Metîn',
      arabic: 'الْمَتِينُ',
      target: 500,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kudret ve kuvveti sarsılmaz derecede pek sağlam olan, hiçbir engelin aciz bırakamadığı. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah göklerde bir emre hükmettiği zaman melekler O’nun sarsılmaz sözüne boyun eğerek kanatlarını çırparlar." — "O; Vekîl, Kavî, Metîn’dir; kim bu isimleri ihsâ ederse cennete girer." (Buhârî, Tefsîr 34/1; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Veliyy',
      arabic: 'الْوَلِيُّ',
      target: 46,
      category: 'Esmaül-Hüsna',
      virtue:
          'Müminlerin dostu, yardımcısı ve hâmîsi olan, onları karanlıklardan aydınlığa çıkaran. — Ebû Hüreyre’den (r.a.) rivayet edilen kudsî hadiste Allah Teâlâ şöyle buyurur: "Kim Benim bir velî (dost) kuluma düşmanlık ederse Ben ona harp ilân ederim. Kulum Bana, kendisine farz kıldığım şeylerden daha sevimli bir şeyle yaklaşamaz; kulum nafile ibadetlerle de Bana yaklaşmaya devam eder, sonunda Ben onu severim." (Buhârî, Rikâk 38; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Hamîd',
      arabic: 'الْحَمِيدُ',
      target: 62,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her hâlükârda bütün övgülere, şükür ve senâlara bizzat lâyık olan, bütün varlıkların diliyle övülen. — Resûlullah (s.a.v.) gece namazına kalktığında ve Salli-Bârik dualarında: "Allâhümme leke’l-hamdü... inneke Hamîdün Mecîd (Allah’ım! Hamd yalnız Sana mahsustur; şüphesiz Sen her övgüye lâyık Hamîd ve şânı yüce Mecîd’sin)" diye dua ederdi. (Buhârî, Teheccüd 1, Daavât 32; Müslim, Salât 66)',
    ),
    ZikirSeedItem(
      name: 'El-Muhsî',
      arabic: 'الْمُحْصِي',
      target: 148,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün varlıkların sayısını, nefeslerini, amellerini ve zerrelerini tek tek bilen ve ilmiyle kuşatan. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah’ın doksan dokuz —yüzden bir eksik— ismi vardır. Kim bunları ihsâ ederse (sayıp korur ve gereğiyle amel ederse) cennete girer: O; Hamîd, Muhsî, Mübdi, Muîd’dir." (Buhârî, Daavât 68; Müslim, Zikir 5; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Mübdi',
      arabic: 'الْمُبْدِئُ',
      target: 57,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün mahlûkatı maddesiz ve örneksiz olarak ilk defa yoktan var eden, yaratmayı başlatan. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Sizler kıyamet gününde ilk yaratıldığınız gibi huzura toplanacaksınız: ‘İlk yaratmayı nasıl başlattıysak (yübdiü), onu yine öylece iade edeceğiz.’" (Buhârî, Rikâk 45; Müslim, Cennet 58; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Muîd',
      arabic: 'الْمُعِيدُ',
      target: 124,
      category: 'Esmaül-Hüsna',
      virtue:
          'Yaratılmışları ölümden sonra ahirette yeniden dirilterek eski haline döndüren, elden kaçan hayırları lütfuyla iade eden. — Resûlullah (s.a.v.) şöyle buyurmuştur: "İnsanoğlunun acبü’z-zeneb (kuyruk sokumu nüvesi) dışında her şeyi çürür; kıyamet günü yaratılış yeniden ondan terkip edilip iade edilir." — "O; Mübdi ve Muîd’dir." (Buhârî, Tefsîr 39/3; Müslim, Fiten 141; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Muhyî',
      arabic: 'الْمُحْيِي',
      target: 68,
      category: 'Esmaül-Hüsna',
      virtue:
          'Can bağışlayan, hayat veren, ölü toprağı yağmurla ve gafil kalpleri iman ve zikir nuruyla dirilten. — Huzeyfe b. Yemân’dan (r.a.) rivayetle Resûlullah (s.a.v.) uykudan uyandığında: "Elhamdülillâhillezî ahyânâ ba‘de mâ emâtenâ (Bizi öldürdükten —uyuttuktan— sonra dirilten Allah’a hamdolsun)" der; ayrıca: "Rabbini zikreden ile zikretmeyenin misali, diri ile ölü gibidir." buyururdu. (Buhârî, Daavât 7, 66; Müslim, Zikir 59)',
    ),
    ZikirSeedItem(
      name: 'El-Mumît',
      arabic: 'الْمُمِيتُ',
      target: 490,
      category: 'Esmaül-Hüsna',
      virtue:
          'Canlıların eceli geldiğinde ölümünü yaratan, fânî hayatı sona erdiren ve nefsin kötü arzularını söndüren. — Huzeyfe’den (r.a.) rivayetle Resûlullah (s.a.v.) yatağına girdiğinde: "Bismikellâhümme emûtü ve ahyâ (Allah’ım! Senin adınla ölür —uyur— ve Senin adınla dirilirim)" diye dua ederdi. (Buhârî, Daavât 7; Müslim, Zikir 59; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Hayy',
      arabic: 'الْحَيُّ',
      target: 18,
      category: 'Esmaül-Hüsna',
      virtue:
          'Ezelî ve ebedî hayat sahibi olan, ölümsüz, uyuklama ve uykudan münezzeh, daima diri olan. — Enes b. Mâlik’ten (r.a.) rivayetle Resûlullah (s.a.v.), kendisini üzen veya önemli bir iş başına geldiğinde şöyle dua ederdi: "Yâ Hayyu yâ Kayyûm, bi-rahmetike estegîsü (Ey daima diri olan Hayy ve her şeyi ayakta tutan Kayyûm! Rahmetinle yardımını diliyorum)." (Tirmizî, Daavât 91; İbn Mâce, Duâ 9)',
    ),
    ZikirSeedItem(
      name: 'El-Kayyûm',
      arabic: 'الْقَيُّومُ',
      target: 156,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kendi zatıyla kâim olan, gökleri, yeri ve bütün varlıkları her an ayakta tutup tedbir ve idare eden. — Esmâ bint Yezîd’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Allah’ın İsm-i A‘zam’ı şu iki âyettedir: «Ve ilâhüküm ilâhün vâhid...» ve Âl-i İmrân sûresinin başındaki «Elif-Lâm-Mîm. Allâhü lâ ilâhe illâ hüve’l-Hayyü’l-Kayyûm»." (Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 65; İbn Mâce, Duâ 9)',
    ),
    ZikirSeedItem(
      name: 'El-Vâcid',
      arabic: 'الْوَاجِدُ',
      target: 14,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hiçbir şeye muhtaç olmayan, dilediğini dilediği anda bulan, hazineleri tükenmeyen mutlak zenginlik sahibi. — Ebû Zer’den (r.a.) rivayet edilen kudsî hadiste Allah Teâlâ şöyle buyurur: "Ey kullarım! Sizin evveliniz ve âhiriniz, insanınız ve cinniniz bir araya gelip Benden isteseler ve Ben de her birine istediğini versem, bu Benim katımdaki mülkten ancak iğnenin denize daldırıldığında eksilttiği kadar eksiltir." (Müslim, Birr 55; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Mâcid',
      arabic: 'الْمَاجِدُ',
      target: 48,
      category: 'Esmaül-Hüsna',
      virtue:
          'Şânı ve kadri pek yüce, kerem, izzet ve cömertliği bol olan. — Ebû Hüreyre’den (r.a.) rivayet edilen Fâtiha kudsî hadisinde Allah Teâlâ, kul «Mâliki yevmi’d-dîn» dediğinde: "Kulum Beni ululadı, şânımın yüceliğini (mecd) ikrar etti (meccedenî abdî)!" buyurur. (Müslim, Salât 38; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Vâhid',
      arabic: 'الْوَاحِدُ',
      target: 19,
      category: 'Esmaül-Hüsna',
      virtue:
          'Zatında, sıfatlarında, isimlerinde ve fiillerinde tek olan, eşi, benzeri ve ortağı bulunmayan. — Büreyde’den (r.a.) rivayetle Resûlullah (s.a.v.), bir sahâbînin: "Allah’ım! Senin Tek (Vâhid/Ehad) ve Samed olduğun şehadetiyle Senden istiyorum" duasını işitince: "Andolsun ki o, Allah’tan İsm-i A‘zam’ı ile istedi!" buyurmuştur. (Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 64; İbn Mâce, Duâ 9)',
    ),
    ZikirSeedItem(
      name: 'Es-Samed',
      arabic: 'الصَّمَدُ',
      target: 134,
      category: 'Esmaül-Hüsna',
      virtue:
          'Her şeyin her ihtiyacında kendisine muhtaç olduğu, kendisi ise hiçbir şeye muhtaç olmayan yegâne sığınak. — Resûlullah (s.a.v.), «Allâhümme innî es’elüke bi-ennî eşhedü enneke entellâhü lâ ilâhe illâ ente’l-Ehadü’s-Samed...» diye dua eden sahâbî hakkında: "Nefsim kudret elinde olan Allah’a yemin ederim ki, kendisiyle istendiğinde verdiği ve dua edildiğinde icabet ettiği İsm-i A‘zam’ı ile Allah’tan istedi!" buyurmuştur. (Ebû Dâvûd, Vitir 23; Tirmizî, Daavât 64)',
    ),
    ZikirSeedItem(
      name: 'El-Kâdir',
      arabic: 'الْقَادِرُ',
      target: 305,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dilediği her şeyi tam bir ölçü ve hikmetle yapmaya eksiksiz gücü yeten. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Kim günde yüz defa: ‘Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü’l-mülkü ve lehü’l-hamdü ve hüve alâ külli şey’in kadîr (O her şeye Kâdir’dir)’ derse, on köle azat etmiş kadar sevap alır, yüz hasene yazılır, yüz hatası silinir ve akşama kadar şeytandan korunur." (Buhârî, Daavât 54; Müslim, Zikir 28)',
    ),
    ZikirSeedItem(
      name: 'El-Muktedir',
      arabic: 'الْمُقْتَدِرُ',
      target: 744,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kuvvet ve kudret sahipleri üzerinde mutlak tasarruf sahibi olan, hiçbir şeyin kendisine zor gelmediği. — Câbir’den (r.a.) rivayetle Resûlullah (s.a.v.) istihâre duasında: "Ve estakdiruke bi-kudretike... fe-inneke takdiru ve lâ akdiru (Allah’ım! Kudretinle Senden güç ve muvaffakiyet isterim; çünkü Sen her şeye güç yetirirsin, ben ise güç yetiremem)" diye dua etmeyi öğretmiştir. (Buhârî, Teheccüd 25; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Mukaddim',
      arabic: 'الْمُقَدِّمُ',
      target: 184,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dilediğini öne geçiren, hikmeti gereği salih kullarını hayırda ve derecede ileri mertebelere yükselten. — Hz. Ali ve İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) namazın sonunda şöyle dua ederdi: "Allâhümmağfirlî mâ kaddemtü ve mâ ahhartü... ente’l-Mukaddimü ve ente’l-Muahhiru, lâ ilâhe illâ ente (Allah’ım! Önce ve sonra yaptığım günahlarımı bağışla. Öne geçiren —Mukaddim— de Sensin, geriye bırakan —Muahhir— da Sensin; Senden başka ilâh yoktur)." (Müslim, Müsâfirîn 201; Buhârî, Teheccüd 1)',
    ),
    ZikirSeedItem(
      name: 'El-Muahhir',
      arabic: 'الْمُؤَخِّرُ',
      target: 847,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hikmeti gereği dilediğini geriye bırakan, kötülük ve şerleri kullarından uzaklaştırıp erteleyen. — Resûlullah (s.a.v.) dualarında şöyle niyaz ederdi: "Ente’l-Mukaddimü ve ente’l-Muahhiru, lâ ilâhe illâ ente (Öne geçiren de Sensin, geriye bırakan —Muahhir— da Sensin; Senden başka ilâh yoktur)." (Müslim, Müsâfirîn 201; Buhârî, Teheccüd 1)',
    ),
    ZikirSeedItem(
      name: 'El-Evvel',
      arabic: 'الْأَوَّلُ',
      target: 37,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlığının başlangıcı olmayan, her şeyden önce var olan ezelî Rabbimiz. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) bizzat bu dört ismi tefsir ederek şöyle dua ederdi: "Allâhümme ente’l-Evvelü fe-leyse kableke şey’ün... ikdı anne’d-deyne ve ağninâ mine’l-fakr (Allah’ım! Sen Evvel’sin, Senden önce hiçbir şey yoktur... Borcumuzu ödemeyi nasip eyle ve bizi fakirlikten kurtarıp zenginleştir)." (Müslim, Zikir 61; Ebû Dâvûd, Edeb 98; Tirmizî, Daavât 19)',
    ),
    ZikirSeedItem(
      name: 'El-Âhir',
      arabic: 'الْآخِرُ',
      target: 801,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlığının sonu olmayan, her şey fânî olduktan sonra da ebediyen bâkî kalan. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle dua ederdi: "Allâhümme... ve ente’l-Âhiru fe-leyse ba‘deke şey’ün, ikdı anne’d-deyne ve ağninâ mine’l-fakr (Allah’ım! Sen Âhir’sin, Senden sonra hiçbir şey yoktur; borcumuzu ödemeyi nasip eyle ve bizi fakirlikten kurtar)." (Müslim, Zikir 61; Ebû Dâvûd, Edeb 98)',
    ),
    ZikirSeedItem(
      name: 'Ez-Zâhir',
      arabic: 'الظَّاهِرُ',
      target: 1106,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlığı ve kudreti kâinattaki sayısız delillerle apaçık ortada olan, her şeye üstün ve galip gelen. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle dua ederdi: "Allâhümme... ve ente’z-Zâhiru fe-leyse fevkake şey’ün, ikdı anne’d-deyne ve ağninâ mine’l-fakr (Allah’ım! Sen Zâhir’sin, Senin üstünde hiçbir şey yoktur; borcumuzu ödemeyi nasip eyle ve bizi fakirlikten kurtar)." (Müslim, Zikir 61; Ebû Dâvûd, Edeb 98)',
    ),
    ZikirSeedItem(
      name: 'El-Bâtın',
      arabic: 'الْبَاطِنُ',
      target: 62,
      category: 'Esmaül-Hüsna',
      virtue:
          'Zatının mahiyeti akıl ve duyularla idrak edilemeyen, fakat ilmi ve rahmetiyle her şeyin iç yüzüne ve sırlarına vakıf olan. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle dua ederdi: "Allâhümme... ve ente’l-Bâtınü fe-leyse dûneke şey’ün, ikdı anne’d-deyne ve ağninâ mine’l-fakr (Allah’ım! Sen Bâtın’sın, Senden öte ve Senden gizli hiçbir şey yoktur; borcumuzu ödemeyi nasip eyle ve bizi fakirlikten kurtar)." (Müslim, Zikir 61; Ebû Dâvûd, Edeb 98)',
    ),
    ZikirSeedItem(
      name: 'El-Vâlî',
      arabic: 'الْوَالِي',
      target: 47,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün kâinatı ve her an meydana gelen hadiseleri tek başına sevk, tedbir ve idare eden mutlak yönetici. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah’ın doksan dokuz ismi vardır: O; Evvel, Âhir, Zâhir, Bâtın, Vâlî, Müteâlî’dir... Kim bunları ihsâ ederse cennete girer." (Tirmizî, Daavât 82; Buhârî, Daavât 68)',
    ),
    ZikirSeedItem(
      name: 'El-Müteâlî',
      arabic: 'الْمُتَعَالِي',
      target: 551,
      category: 'Esmaül-Hüsna',
      virtue:
          'İzzet, şeref ve hükümranlık bakımından en yüce olan, yaratılmışların sıfatlarından ve her türlü noksanlıktan münezzeh bulunan. — Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah’ın doksan dokuz —yüzden bir eksik— ismi vardır: O; Vâlî, Müteâlî, Berr, Tevvâb’dır. Kim bunları ihsâ ederse cennete girer." (Tirmizî, Daavât 82; Buhârî, Daavât 68)',
    ),
    ZikirSeedItem(
      name: 'El-Berr',
      arabic: 'الْبَرُّ',
      target: 202,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarına karşı çok şefkatli, iyilik, lütuf ve ihsanı bol olan, vaadini sadakatle yerine getiren. — Hz. Âişe (r.a.) validemizden rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz Allah Refîk’tir; her işte yumuşaklığı ve iyiliği (birr) sever." — "O, çok iyilik eden Berr ve çok merhametli Rahîm’dir." (Buhârî, Edeb 35; Müslim, Birr 77; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Et-Tevvâb',
      arabic: 'التَّوَّابُ',
      target: 409,
      category: 'Esmaül-Hüsna',
      virtue:
          'Tövbe kapısını daima açık tutan, kullarını tövbeye yönelten ve yapılan tövbeleri tekrar tekrar kabul buyuran. — İbn Ömer (r.a.) anlatıyor: Biz tek bir mecliste Resûlullah’ın (s.a.v.) yüz defa şöyle istiğfâr ettiğini sayardık: "Rabbiğfirlî ve tüb aleyye, inneke ente’t-Tevvâbü’r-Rahîm (Rabbim! Beni bağışla ve tövbemi kabul buyur; şüphesiz Sen tövbeleri çokça kabul eden Tevvâb ve çok merhametli Rahîm’sin)." (Ebû Dâvûd, Vitir 26; Tirmizî, Daavât 38)',
    ),
    ZikirSeedItem(
      name: 'El-Müntekım',
      arabic: 'الْمُنْتَقِمُ',
      target: 630,
      category: 'Esmaül-Hüsna',
      virtue:
          'Zalimlere mühlet verse de ihmal etmeyen, mazlumun hakkını zalimden tam bir adaletle alan. — İbn Abbâs ve Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Mazlumun bedduasından sakının; çünkü onunla Allah arasında hiçbir perde yoktur. Allah Teâlâ: ‘İzzetim ve celâlim hakkı için, bir süre sonra da olsa sana mutlaka yardım edeceğim (hakkını alacağım)!’ buyurur." (Buhârî, Mezâlim 9; Tirmizî, Birr 7, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Afuvv',
      arabic: 'الْعَفُوُّ',
      target: 156,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarının günahlarını kökünden silip yok eden, azarlamadan ve cezalandırmadan affetmeyi çok seven. — Hz. Âişe (r.a.) validemiz: "Yâ Resûlallah! Kadir gecesine tevafuk edersem nasıl dua edeyim?" diye sorduğunda Peygamberimiz (s.a.v.) şöyle buyurmuştur: "«Allâhümme inneke Afuvvün tuhibbü’l-afve fa‘fü annî» (Allah’ım! Şüphesiz Sen çok affedici Afuvv’sün, affetmeyi seversin; beni de affet) de!" (Tirmizî, Daavât 84; İbn Mâce, Duâ 5)',
    ),
    ZikirSeedItem(
      name: 'Er-Raûf',
      arabic: 'الرَّؤُوفُ',
      target: 287,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarına karşı son derece şefkatli ve merhametli olan, onlara güçlerinin yetmeyeceği yükü yüklemeyip kolaylık dileyen. — Hz. Ömer’den (r.a.) rivayetle Resûlullah (s.a.v.), yavrusunu bağrına basan bir anneyi göstererek şöyle buyurmuştur: "Şu kadının çocuğunu ateşe atacağını düşünür müsünüz? İşte Allah’ın kullarına olan şefkati, bu kadının yavrusuna olan şefkatinden çok daha fazladır." (Buhârî, Edeb 18; Müslim, Tevbe 22; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Mâlikü\'l-Mülk',
      arabic: 'مَالِكُ الْمُلْكِ',
      target: 212,
      category: 'Esmaül-Hüsna',
      virtue:
          'Mülkün ezelî ve ebedî sahibi, mülkünde dilediği gibi tasarruf eden, dilediğine mülk ve izzet veren. — Abdullah b. Mes‘ûd’dan (r.a.) rivayetle Resûlullah (s.a.v.) sabah ve akşam şöyle zikrederdi: "Emsâ ve’l-mülkü lillâhi ve’l-hamdü lillâh... (Mülk yalnız Allah’ın, hamd yalnız Allah’ın olarak akşamladık/sabahladık)." (Müslim, Zikir 74; Âl-i İmrân, 26; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'Zü\'l-Celâli ve\'l-İkrâm',
      arabic: 'ذُو الْجَلَالِ وَالْإِكْرَامِ',
      target: 1100,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hem sonsuz büyüklük ve azamet (celâl), hem de sınırsız lütuf ve kerem (ikram) sahibi olan. — Enes b. Mâlik (r.a.) ve Rebîa b. Âmir’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "«Yâ Ze’l-Celâli ve’l-İkrâm» (Ey celâl ve ikram sahibi!) sözüne devam ediniz; dualarınızda bu ismi sıkça söyleyiniz." (Tirmizî, Daavât 91; Müslim, Mesâcid 135; Nesâî, es-Sünenü’l-kübrâ 7671)',
    ),
    ZikirSeedItem(
      name: 'El-Muksit',
      arabic: 'الْمُقْسِطُ',
      target: 209,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün işlerini birbirine denk ve yerli yerinde yapan, hüküm ve icraatında tam adaletle muamele eden ve adil olanları seven. — Abdullah b. Amr’dan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Şüphesiz adaletle hükmedenler (muksitûn), Allah katında Rahmân’ın sağında nurdan minberler üzerindedirler; onlar verdikleri hükümlerde, aileleri ve yönettikleri kimseler hakkında adaletli davrananlardır." (Müslim, İmâre 18; Nesâî, Âdâbü’l-kudât 1; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Câmi',
      arabic: 'الْجَامِعُ',
      target: 114,
      category: 'Esmaül-Hüsna',
      virtue:
          'İstediğini istediği zaman ve yerde toplayan, birbirine uzak gönülleri sevgiyle birleştiren ve kıyamet günü bütün mahlûkatı hesaba toplayan. — Resûlullah (s.a.v.) dualarında: "Allah’ım! Dağınık işlerimi toparla, kalbimi birleştir ve kıyamet gününde beni salih kullarınla bir araya getir." diye niyaz ederdi. (Müslim, Müsâfirîn 201; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Ganî',
      arabic: 'الْغَنِيُّ',
      target: 1060,
      category: 'Esmaül-Hüsna',
      virtue:
          'Zatında, sıfatlarında ve fiillerinde hiçbir şeye muhtaç olmayan, bütün varlıkların kendisine muhtaç olduğu mutlak zengin. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Zenginlik mal çokluğuyla değildir; gerçek zenginlik gönül zenginliğidir." — "Şüphesiz Allah Ganî’dir (hiçbir şeye muhtaç değildir), cömerttir." (Buhârî, Rikâk 15; Müslim, Zekât 120; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Muğnî',
      arabic: 'الْمُغْنِي',
      target: 1100,
      category: 'Esmaül-Hüsna',
      virtue:
          'Dilediği kulunu maddî ve manevî olarak zenginleştiren, gönlüne kanaat verip kendisinden başkasına muhtaç olmaktan kurtaran. — Hz. Ali’den (r.a.) rivayetle Resûlullah (s.a.v.) borç ve darlıktan kurtulmak için şu duayı öğretmiştir: "Allâhümmekfinî bi-halâlike an harâmike ve ağninî bi-fadlike ammen sivâk (Allah’ım! Helâlinle beni haramından koru ve lütfunla beni Senden başkasına muhtaç etme, zengin kıl)." (Tirmizî, Daavât 110; Müslim, Zikir 72)',
    ),
    ZikirSeedItem(
      name: 'El-Mâni\'',
      arabic: 'الْمَانِعُ',
      target: 161,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hikmeti gereği dilediği şeyin gerçekleşmesine engel olan, kullarını kaza, bela ve tehlikelerden koruyup meneden. — Muğîre b. Şu‘be’den (r.a.) rivayetle Resûlullah (s.a.v.) her farz namazın peşinden şöyle dua ederdi: "Allâhümme lâ mânia limâ a‘tayte ve lâ mu‘tıye limâ mena‘te ve lâ yenfeu ze’l-ceddi minke’l-cedd (Allah’ım! Senin verdiğine engel olacak yoktur, Senin engellediğini —menettiğini— de verebilecek yoktur)." (Buhârî, Ezân 155, Daavât 18; Müslim, Mesâcid 137)',
    ),
    ZikirSeedItem(
      name: 'Ed-Dârr',
      arabic: 'الضَّارُّ',
      target: 1001,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hikmeti gereği imtihan veya ceza olarak elem ve zarar verici şeyleri yaratan; O’nun izni olmadan hiçbir şeyin zarar veremediği. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Bil ki, bütün ümmet sana bir zarar vermek için toplansa, Allah’ın senin aleyhine yazdığından başka bir zarar veremezler." Ve sabah-akşam: "Bismillâhillezî lâ yedurru ma‘asmihî şey’ün fi’l-ardı ve lâ fi’s-semâi ve hüve’s-Semî‘u’l-Alîm" okunmasını tavsiye etmiştir. (Tirmizî, Kıyâmet 59, Daavât 13; Ebû Dâvûd, Edeb 101)',
    ),
    ZikirSeedItem(
      name: 'En-Nâfi\'',
      arabic: 'النَّافِعُ',
      target: 201,
      category: 'Esmaül-Hüsna',
      virtue:
          'Hayır, şifa ve fayda verici şeyleri yaratan, kullarına maddî ve manevî menfaat ulaştıran. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Bil ki, bütün ümmet sana bir fayda (nef‘) sağlamak için toplansa, Allah’ın senin için yazdığından başka bir fayda sağlayamazlar." Ayrıca Peygamberimiz (s.a.v.) her sabah: "Allah’ım! Senden faydalı ilim (ilmen nâfian), temiz rızık ve makbul amel isterim." diye dua ederdi. (Tirmizî, Kıyâmet 59; İbn Mâce, İkâmet 32)',
    ),
    ZikirSeedItem(
      name: 'En-Nûr',
      arabic: 'النُّورُ',
      target: 256,
      category: 'Esmaül-Hüsna',
      virtue:
          'Âlemleri, gökleri ve yeri aydınlatan, müminlerin kalplerine ve simalarına iman, irfan ve hidayet nuru bahşeden. — İbn Abbâs’tan (r.a.) rivayetle Resûlullah (s.a.v.) gece namazına kalktığında şöyle dua ederdi: "Allâhümme leke’l-hamdü ente nûru’s-semâvâti ve’l-ardı ve men fîhinne... Allâhümmec‘al fî kalbî nûrâ (Allah’ım! Hamd Sana mahsustur; Sen göklerin, yerin ve onlarda bulunanların Nûr’usun... Allah’ım, kalbime nur ver!)." (Buhârî, Teheccüd 1, Daavât 9; Müslim, Müsâfirîn 199)',
    ),
    ZikirSeedItem(
      name: 'El-Hâdî',
      arabic: 'الْهَادِي',
      target: 20,
      category: 'Esmaül-Hüsna',
      virtue:
          'Kullarına doğru yolu gösteren, kalpleri hakka ve hayra yönelten, hidayete ve rızasına ulaştıran. — Ebû Zer’den (r.a.) rivayet edilen kudsî hadiste Allah Teâlâ şöyle buyurur: "Ey kullarım! Benim hidayete erdirdiklerim dışında hepiniz dalâlettesiniz; öyleyse Benden hidayet isteyin ki sizi doğru yola ileteyim (festehdûnî ehdiküm)!" Ve Resûlullah (s.a.v.): "Allâhümmehdinî fîmen hedeyt (Allah’ım! Hidayet verdiklerinle beraber bana da hidayet ver)" diye dua ederdi. (Müslim, Birr 55; Ebû Dâvûd, Vitir 5; Tirmizî, Vitir 10)',
    ),
    ZikirSeedItem(
      name: 'El-Bedî\'',
      arabic: 'الْبَدِيعُ',
      target: 86,
      category: 'Esmaül-Hüsna',
      virtue:
          'Gökleri, yeri ve bütün varlıkları daha önce hiçbir örneği olmaksızın eşsiz bir güzellik ve hikmetle yaratan. — Enes b. Mâlik’ten (r.a.) rivayetle bir sahâbî namazdan sonra: "Allâhümme innî es’elüke bi-enne leke’l-hamd, lâ ilâhe illâ ente’l-Mennân, Bedî‘u’s-semâvâti ve’l-ard, yâ Ze’l-celâli ve’l-ikrâm, yâ Hayyu yâ Kayyûm" diye dua ettiğinde Resûlullah (s.a.v.): "Andolsun ki o, Allah’a, kendisiyle dua edildiğinde icabet ettiği ve istendiğinde verdiği İsm-i A‘zam’ı ile dua etti!" buyurmuştur. (Ebû Dâvûd, Vitir 23; Nesâî, Sehv 58; Tirmizî, Daavât 100)',
    ),
    ZikirSeedItem(
      name: 'El-Bâkî',
      arabic: 'الْبَاقِي',
      target: 113,
      category: 'Esmaül-Hüsna',
      virtue:
          'Varlığının sonu olmayan, zeval bulmayan, her şey fânî olduktan sonra da celâl ve ikramıyla ebediyen var olacak olan. — Ebû Hüreyre’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "Bir şairin söylediği en doğru söz, Lebîd’in: ‘Bilin ki Allah’tan başka her şey fânîdir (yalnız Allah Bâkî’dir)’ sözüdür." (Buhârî, Menâkıbü’l-ensâr 26, Rikâk 29; Müslim, Şiir 3; Tirmizî, Daavât 82)',
    ),
    ZikirSeedItem(
      name: 'El-Vâris',
      arabic: 'الْوَارِثُ',
      target: 707,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün mülk ve servetlerin fânî sahipleri göçüp gittikten sonra geriye kalan hakiki ve ebedî sahibi. — İbn Ömer’den (r.a.) rivayetle Resûlullah (s.a.v.) meclisinden kalkmadan önce ashabı için şöyle dua ederdi: "Allâhümmemti‘nâ bi-esmâinâ ve ebsârinâ ve kuvvetinâ mâ ahyeytenâ vec‘alhü’l-vârise minnâ (Allah’ım! Bizi yaşattığın müddetçe kulaklarımızdan, gözlerimizden ve kuvvetimizden bizi faydalandır ve onları bizden sonra da sağlam kıl; şüphesiz her şeyin gerçek Vâris’i Sensin)." (Tirmizî, Daavât 79, 82)',
    ),
    ZikirSeedItem(
      name: 'Er-Reşîd',
      arabic: 'الرَّشِيدُ',
      target: 514,
      category: 'Esmaül-Hüsna',
      virtue:
          'Bütün işlerini ezeli hikmetine göre en doğru nizama koyan, kullarını rüşd, hidayet ve istikamete ulaştıran. — İmrân b. Husayn’dan (r.a.) rivayetle Resûlullah (s.a.v.) kendisine şu duayı öğretmiştir: "Allâhümmelhımnî rüşdî ve eıznî min şerri nefsî (Allah’ım! Bana rüşdümü —doğru yolu ve isabetli hareketi— ilham et ve beni nefsimin şerrinden koru)." (Tirmizî, Daavât 70, 82)',
    ),
    ZikirSeedItem(
      name: 'Es-Sabûr',
      arabic: 'الصَّبُورُ',
      target: 298,
      category: 'Esmaül-Hüsna',
      virtue:
          'Günahkârları cezalandırmakta acele etmeyen, tövbe ve ıslah olmaları için mühlet tanıyan ve sabreden kullarına sabır ve metanet ihsan eden. — Ebû Mûsâ el-Eş‘arî’den (r.a.) rivayetle Resûlullah (s.a.v.) şöyle buyurmuştur: "İşittiği eziyet verici sözlere karşı Allah’tan daha sabırlı (es-Sabûr) hiçbir kimse yoktur; insanlar O’na ortak ve evlat isnat ederler de O yine onlara afiyet ve rızık vermeye devam eder." (Buhârî, Edeb 71, Tevhîd 3; Müslim, Sıfâtü’l-münâfikîn 49; Tirmizî, Daavât 82)',
    ),

    // =========================================================================
    // 3. PEYGAMBER VE KUR'AN DUALARI (KUR'ÂN-I KERÎM ÂYET MEÂLLERİ)
    // =========================================================================
    ZikirSeedItem(name: 'Âdem (a.s.) Duası', arabic: 'رَبَّـنَا ظَلَمْنَٓا اَنْفُسَنَا وَاِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِر۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbimiz! Biz kendimize zulmettik. Eğer bizi bağışlamaz ve bize acımazsan mutlaka ziyan edenlerden oluruz." (A\'râf, 23)'),
    ZikirSeedItem(name: 'Nûh (a.s.) Duası 1', arabic: 'رَبِّ اِنّ۪ي اَعُوذُ بِكَ اَنْ اَسْـَٔلَكَ مَا لَيْسَ ل۪ي بِه۪ عِلْمٌ', target: 25, category: 'Dualar', virtue: '"Rabbim! Hakkında bilgim olmayan şeyi istemekten Sana sığınırım." (Hûd, 47)'),
    ZikirSeedItem(name: 'Nûh (a.s.) Duası 2', arabic: 'رَبِّ انْصُرْن۪ي بِمَا كَذَّبُونِ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni yalanlamalarına karşı bana yardım et!" (Mü\'minûn, 26)'),
    ZikirSeedItem(name: 'Nûh (a.s.) Duası 3', arabic: 'رَبِّ اغْفِرْ ل۪ي وَلِوَالِدَيَّ وَلِمَنْ دَخَلَ بَيْتِيَ مُؤْمِناً', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni, ana-babamı, iman etmiş olarak evime girenleri bağışla." (Nûh, 28)'),
    ZikirSeedItem(name: 'Lût (a.s.) Duası 1', arabic: 'رَبِّ نَجِّن۪ي وَاَهْل۪ي مِمَّا يَعْمَلُونَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni ve ailemi bunların yaptıklarından kurtar!" (Şuarâ, 169)'),
    ZikirSeedItem(name: 'Lût (a.s.) Duası 2', arabic: 'رَبِّ انْصُرْن۪ي عَلَى الْقَوْمِ الْمُفْسِد۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Bozguncu kavme karşı bana yardım et." (Ankebût, 30)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 1', arabic: 'رَبِّ هَبْ ل۪ي حُكْماً وَاَلْحِقْن۪ي بِالصَّالِح۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Bana hikmet bahşet ve beni salih kimseler arasına kat." (Şuarâ, 83)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 2', arabic: 'وَلَا تُخْزِن۪ي يَوْمَ يُبْعَثُونَ', target: 25, category: 'Dualar', virtue: '"Dirilecekleri gün beni mahcup etme." (Şuarâ, 87)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 3', arabic: 'رَبِّ هَبْ ل۪ي مِنَ الصَّالِح۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Bana salihlerden (bir evlat) ihsan et!" (Sâffât, 100)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 4', arabic: 'رَبِّ اجْعَلْن۪ي مُق۪يمَ الصَّلٰوةِ وَمِنْ ذُرِّيَّت۪ي', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Beni ve soyumu namazı devamlı kılanlardan eyle." (İbrâhim, 40)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 5', arabic: 'رَبَّـنَا اغْفِرْ ل۪ي وَلِوَالِدَيَّ وَلِلْمُؤْمِن۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbimiz! Hesap günü beni, ana-babamı ve müminleri bağışla!" (İbrâhim, 41)'),
    ZikirSeedItem(name: 'İbrâhim (a.s.) Duası 6', arabic: 'رَبَّنَا وَاجْعَلْنَا مُسْلِمَيْنِ لَكَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbimiz! Bizi Sana boyun eğenlerden kıl." (Bakara, 128)'),
    ZikirSeedItem(name: 'Yûsuf (a.s.) Duası 1', arabic: 'رَبِّ اَلْسِّجْنُ اَحَبُّ اِلَيَّ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Zindan bana bunların davet ettikleri şeyden daha sevimlidir." (Yûsuf, 33)'),
    ZikirSeedItem(name: 'Yûsuf (a.s.) Duası 2', arabic: 'تَوَفَّن۪ي مُسْلِماً وَاَلْحِقْن۪ي بِالصَّالِح۪ينَ', target: 25, category: 'Dualar', virtue: '"Beni müslüman olarak vefât ettir ve sâlihler arasına kat!" (Yûsuf, 101)'),
    ZikirSeedItem(name: 'Eyyûb (a.s.) Duası', arabic: 'اَنّ۪ي مَسَّنِيَ الضُّرُّ وَاَنْتَ اَرْحَمُ الرَّاحِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Ben derde uğradım, Sen merhametlilerin en merhametlisisin." (Enbiyâ, 83)'),
    ZikirSeedItem(name: 'Şuayb (a.s.) Duası 1', arabic: 'رَبَّـنَا افْتَحْ بَيْنَنَا وَبَيْنَ قَوْمِنَا بِالْحَقِّ', target: 25, category: 'Dualar', virtue: '"Rabbimiz! Bizimle kavmimiz arasında adaletle hükmet!" (A\'râf, 89)'),
    ZikirSeedItem(name: 'Şuayb (a.s.) Duası 2', arabic: 'وَمَا تَوْف۪يق۪ٓي اِلَّا بِاللّٰهِ', target: 25, category: 'Dualar', virtue: '"Başarım ancak Allah\'ın yardımı iledir." (Hûd, 88)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 1', arabic: 'رَبِّ اِنّ۪ي ظَلَمْتُ نَفْس۪ي فَاغْفِرْ ل۪ي', target: 25, category: 'Dualar', virtue: '"Rabbim! Doğrusu kendime zulmettim. Beni bağışla." (Kasas, 16)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 2', arabic: 'رَبِّ نَجِّن۪ي مِنَ الْقَوْمِ الظَّالِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni zalimler gürûhundan kurtar." (Kasas, 21)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 3', arabic: 'رَبِّ اغْفِرْ ل۪ي وَلِاَخ۪ي وَاَدْخِلْنَا ف۪ي رَحْمَتِكَ وَاَنْتَ اَرْحَمُ الرَّاحِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Beni ve kardeşimi bağışla! Bizi rahmetinin içine al. Sen merhametlilerin en merhametlisisin." (A\'râf, 151)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 4', arabic: 'وَاكْتُبْ لَنَا ف۪ي هٰذِهِ الدُّنْيَا حَسَنَةً وَفِي الْاٰخِرَةِ', target: 25, category: 'Dualar', virtue: '"Bize bu dünyada da iyilik yaz, âhirette de." (A\'râf, 156)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 5', arabic: 'رَبِّ اشْرَحْ ل۪ي صَدْر۪ي وَيَسِّرْ ل۪ٓي اَمْر۪ي وَاحْلُلْ عُقْدَةً مِنْ لِسَان۪ي', target: 25, category: 'Dualar', virtue: '"Rabbim! Gönlüme ferahlık ver. İşimi bana kolaylaştır. Dilimdeki tutukluğu çöz." (Tâhâ, 25-28)'),
    ZikirSeedItem(name: 'Mûsâ (a.s.) Duası 6', arabic: 'وَاُفَوِّضُ اَمْر۪ٓي اِلَى اللّٰهِ اِنَّ اللّٰهَ بَص۪يرٌ بِالْعِبَادِ', target: 25, category: 'Dualar', virtue: '"Ben işimi Allah\'a havale ediyorum. Şüphesiz Allah kullarını görür, gözetir." (Mü\'min, 44)'),
    ZikirSeedItem(name: 'Süleyman (a.s.) Duası 1', arabic: 'رَبِّ اَوْزِعْن۪ٓي اَنْ اَشْكُرَ نِعْمَتَكَ الَّت۪ٓي اَنْعَمْتَ عَلَيَّ وَعَلٰى وَالِدَيَّ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Beni; bana ve ana-babama verdiğin nimetlere şükretmeye sevk et." (Neml, 19)'),
    ZikirSeedItem(name: 'Süleyman (a.s.) Duası 2', arabic: 'رَبِّ اغْفِرْ ل۪ي وَهَبْ ل۪ي مُلْكاً لَا يَنْبَغ۪ي لِاَحَدٍ مِنْ بَعْد۪ي', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Beni bağışla; benden sonra kimsenin ulaşamayacağı bir hükümranlık ver." (Sâd, 35)'),
    ZikirSeedItem(name: 'Yûnus (a.s.) Duası', arabic: 'لَٓا اِلٰهَ اِلَّٓا اَنْتَ سُبْحَانَكَ اِنّ۪ي كُنْتُ مِنَ الظَّالِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Senden başka ilâh yoktur. Seni her türlü noksandan tenzih ederim. Şüphesiz ben kendine yazık edenlerden oldum." (Enbiyâ, 87)'),
    ZikirSeedItem(name: 'Zekeriyyâ (a.s.) Duası 1', arabic: 'رَبِّ لَا تَذَرْن۪ي فَرْداً وَاَنْتَ خَيْرُ الْوَارِث۪ينَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni tek başıma bırakma. Sen vârislerin en hayırlısısın." (Enbiyâ, 89)'),
    ZikirSeedItem(name: 'Zekeriyyâ (a.s.) Duası 2', arabic: 'رَبِّ هَبْ ل۪ي مِنْ لَدُنْكَ ذُرِّيَّةً طَيِّبَةً اِنَّكَ سَم۪يعُ الدُّعَٓاءِ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Bana katından temiz bir soy ihsan eyle, şüphesiz Sen duâyı işitensin." (Âl-i İmrân, 38)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 1', arabic: 'حَسْبِيَ اللّٰهُ لَٓا اِلٰهَ اِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظ۪يمِ', target: 25, category: 'Dualar', virtue: '"Allah bana yeter. O\'ndan başka ilâh yoktur. Ben sadece O\'na güvenip dayanırım. O yüce Arş\'ın sahibidir." (Tevbe, 129)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 2', arabic: 'رَبِّ احْكُمْ بِالْحَقِّ وَرَبُّنَا الرَّحْمٰنُ الْمُسْتَعَانُ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Aramızda gerçekle hükmet. Rabbimiz O Rahmân\'dır ki yardımına sığınılacak olan ancak O\'dur." (Enbiyâ, 112)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 3', arabic: 'رَبِّ فَلَا تَجْعَلْن۪ي فِي الْقَوْمِ الظَّالِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni zalimler topluluğunun içinde bulundurma!" (Mü\'minûn, 93-94)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 4', arabic: 'رَبِّ اَعُوذُ بِكَ مِنْ هَمَزَاتِ الشَّيَاط۪ينِ وَاَعُوذُ بِكَ رَبِّ اَنْ يَحْضُرُونِ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Şeytanların vesveselerinden Sana sığınırım. Onların yanımda bulunmalarından da Sana sığınırım." (Mü\'minûn, 97-98)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 5', arabic: 'رَبِّ اغْفِرْ وَارْحَمْ وَاَنْتَ خَيْرُ الرَّاحِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Bağışla ve merhamet et Rabbim! Sen merhametlilerin en hayırlısısın." (Mü\'minûn, 118)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 6', arabic: 'رَبِّ اَدْخِلْن۪ي مُدْخَلَ صِدْقٍ وَاَخْرِجْن۪ي مُخْرَجَ صِدْقٍ وَاجْعَلْ ل۪ي مِنْ لَدُنْكَ سُلْطَاناً نَص۪يراً', target: 25, category: 'Dualar', virtue: '"Rabbim! Gireceğim yere dürüstlükle girmemi, çıkacağım yerden dürüstlükle çıkmamı sağla. Bana katından yardım edici bir kuvvet ver." (İsrâ, 80)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 7', arabic: 'رَبِّ زِدْن۪ي عِلْماً', target: 25, category: 'Dualar', virtue: '"Rabbim, ilmimi artır." (Tâhâ, 114)'),
  ];

  static String _normalizeKey(String input) {
    return input
        .toLowerCase()
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('\'', '')
        .replaceAll('’', '')
        .replaceAll('‘', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim();
  }

  static const Map<String, String> _aliasToCanonicalName = {
    'subhanallah': 'Subhanallah',
    'elhamdulillah': 'Elhamdülillah',
    'allahuekber': 'Allahuekber',
    'lailaheillallah': 'Kelime-i Tevhid',
    'kelimeitevhid': 'Kelime-i Tevhid',
    'estagfirullah': 'İstiğfar',
    'estagfirullahelazim': 'İstiğfar',
    'istigfar': 'İstiğfar',
    'salavatiserife': 'Salavat-ı Şerif',
    'salavatiserif': 'Salavat-ı Şerif',
    'salavat': 'Salavat-ı Şerif',
    'lahavlevelakuvveteillabillah': 'Lâ havle ve lâ kuvvete illâ billâh',
    'hasbunallahuvenimelvekil': 'Hasbünallahu ve ni\'mel vekil',
    'yafettah': 'El-Fettâh',
    'yarezzak': 'Er-Rezzâk',
  };

  /// Resolves the authentic Sahih Hadith / Ayet Meali description for any zikir by name or Arabic text.
  static String? getVirtueForZikir(String name, {String? arabic}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct case-insensitive match
    final lower = trimmed.toLowerCase();
    for (final item in defaultZikirs) {
      if (item.name.toLowerCase() == lower) {
        return item.virtue;
      }
    }

    // 2. Normalized & alias match (incl. "Ya ..." -> "El-... / Er-..." Esma variations)
    final norm = _normalizeKey(trimmed);
    final canonical = _aliasToCanonicalName[norm];
    if (canonical != null) {
      for (final item in defaultZikirs) {
        if (item.name == canonical) {
          return item.virtue;
        }
      }
    }

    final strippedYa = norm.startsWith('ya') && norm.length > 3 ? norm.substring(2) : norm;
    for (final item in defaultZikirs) {
      final itemNorm = _normalizeKey(item.name);
      if (itemNorm == norm) {
        return item.virtue;
      }
      // Match Esma stems (e.g. "Ya Latif" -> "El-Latîf", "Ya Şafi" etc.)
      if (item.category == 'Esmaül-Hüsna' && itemNorm.length > 3) {
        final itemStem = itemNorm.replaceFirst(
          RegExp(r'^(el|er|es|ez|et|ed|en|es)'),
          '',
        );
        if (itemStem.isNotEmpty && (itemStem == strippedYa || itemStem == norm)) {
          return item.virtue;
        }
      }
    }

    // 3. Fallback by Arabic text
    if (arabic != null && arabic.trim().isNotEmpty) {
      final cleanAr = arabic.trim();
      for (final item in defaultZikirs) {
        if (item.arabic.trim() == cleanAr) {
          return item.virtue;
        }
      }
    }

    return null;
  }

  static Future<void> seedDatabaseIfEmpty(AppDatabase db) async {
    final existingZikirs = await db.select(db.zikirs).get();
    if (existingZikirs.isNotEmpty) return;

    await db.transaction(() async {
      for (final item in defaultZikirs) {
        await db.into(db.zikirs).insert(
          ZikirsCompanion.insert(
            name: item.name,
            arabic: Value(item.arabic),
            target: Value(item.target),
            category: Value(item.category),
            isFavorite: Value(item.isFavorite),
          ),
        );
      }
    });
  }

  static Future<void> ensureAllDefaultZikirsExist(AppDatabase db) async {
    final existingZikirs = await db.select(db.zikirs).get();
    final existingNames = existingZikirs.map((z) => z.name).toSet();

    await db.transaction(() async {
      for (final item in defaultZikirs) {
        if (!existingNames.contains(item.name)) {
          await db.into(db.zikirs).insert(
            ZikirsCompanion.insert(
              name: item.name,
              arabic: Value(item.arabic),
              target: Value(item.target),
              category: Value(item.category),
              isFavorite: Value(item.isFavorite),
            ),
          );
        }
      }
    });
  }
}
