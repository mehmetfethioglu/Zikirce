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
    // 1. HADİSLERDEN ZİKİRLER (MAUI EXACT)
    // =========================================================================
    ZikirSeedItem(
      name: 'İstiğfar',
      arabic: 'أَسْتَغْفِرُ اللهَ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue: 'Bir kimse istiğfârı dilinden düşürmezse, Allah Teâlâ ona her darlıktan bir çıkış, her üzüntüden bir kurtuluş yolu gösterir ve ona beklemediği yerden rızık verir. (Ebû Dâvûd, Vitir 26. Ayrıca bk. İbni Mâce, Edeb 57)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Besmele',
      arabic: 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue: 'Bismillah her hayrın başıdır. (Birinci Söz)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Subhanallah',
      arabic: 'سُبْحَانَ اللهِ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue: 'Sizden önde gidenlere yetişebileceğiniz, sizden sonra gelenleri geçebileceğiniz, sizin yaptığınızı yapanlar dışında herkesten üstün olacağınız bir şeyi haber vereyim mi? - Her farz namazın peşinden otuz üçer defa sübhânallah, Allâhüekber, elhamdülillah deyiniz. (Buhârî, Ezân 155; Daavât 18; Müslim, Mesâcid 142)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Elhamdülillah',
      arabic: 'الْحَمْدُ لِلَّهِ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue: 'Her farz namazın peşinden otuz üçer defa sübhânallah, Allâhüekber, elhamdülillah deyiniz. (Buhârî, Ezân 155; Daavât 18; Müslim, Mesâcid 142)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Allahuekber',
      arabic: 'اللهُ أَكْبَرُ',
      target: 33,
      category: 'Hadislerden Zikirler',
      virtue: 'Her farz namazın peşinden otuz üçer defa sübhânallah, Allâhüekber, elhamdülillah deyiniz. (Buhârî, Ezân 155; Daavât 18; Müslim, Mesâcid 142)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Kelime-i Tevhid',
      arabic: 'لَا إِلَهَ إِلَّا اللهُ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue: 'En faziletli zikir «Lâ ilâhe illallah», en faziletli dua da «el-Hamdülillâh»tır. (Tirmizî, Daavât 9)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Salavat-ı Şerif',
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
      target: 1000,
      category: 'Hadislerden Zikirler',
      virtue: 'Kıyâmet gününde insanların bana en yakın olanları, bana en çok salât ü selâm getirenleridir. (Tirmizî, Vitir 21)',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'İhlas-ı Şerif',
      arabic: 'قُلْ هُوَ اللهُ أَحَدٌ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue: 'Vefat eden kişi her gün 100 İhlas-ı Şerif okuyordu. Allah (cc) bu kulumu borçlu yatırmam buyurdu, demiştir.',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Salât-ı Adrikni (Çarem Tükendi)',
      arabic: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى سَيِّدِنَا مُحَمَّدٍ، قَدْ ضَاقَتْ حِيلَتِي أَدْرِكْنِي يَا رَسُولَ اللهِ',
      target: 100,
      category: 'Hadislerden Zikirler',
      virtue: 'Ey Allah’ım! Efendimiz Muhammed aleyhissalatü vesselama rahmet, selamet ve bereket bahşeyle. Ey Allah’ın Resulü! Çarem tükendi (artık), ne olur yardımıma yetiş.',
      isFavorite: true,
    ),
    ZikirSeedItem(
      name: 'Mâşâallâh Lâ Kuvvete İllâ Billâh',
      arabic: 'مَا شَاءَ اللَّهُ لَا قُوَّةَ إِلَّا بِاللَّهِ',
      target: 99,
      category: 'Hadislerden Zikirler',
      virtue: 'Allah\'ın dilediği olur; güç ve kuvvet ancak Allah\'ındır. Bir kimse sevdiği bir malın, evladın yani sevdiği şeyin kendine kalmasını istiyorsa bu zikri çeksin.',
      isFavorite: true,
    ),

    // =========================================================================
    // 2. ESMAÜL HÜSNA (99 İSİM - MAUI EXACT)
    // =========================================================================
    ZikirSeedItem(name: 'Allah', arabic: 'اللهُ', target: 66, category: 'Esmaül-Hüsna', virtue: 'Her türlü istek, tüm duaların kabul olması için'),
    ZikirSeedItem(name: 'Er-Rahmân', arabic: 'الرَّحْمَنُ', target: 298, category: 'Esmaül-Hüsna', virtue: 'Dünyada ve ahirette Allah\'ın sevgisini kazanmak için'),
    ZikirSeedItem(name: 'Er-Rahîm', arabic: 'الرَّحِيمُ', target: 258, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî rızka nail olmak için'),
    ZikirSeedItem(name: 'El-Melik', arabic: 'الْمَلِكُ', target: 90, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî güçlü olmak, emir sahibi olmak için'),
    ZikirSeedItem(name: 'El-Kuddûs', arabic: 'الْقُدُّوسُ', target: 170, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî her türlü temizlik, kalp temizliği için'),
    ZikirSeedItem(name: 'Es-Selâm', arabic: 'السَّلَامُ', target: 131, category: 'Esmaül-Hüsna', virtue: 'Korkulan her şeyden emin olmak ve esenliğe çıkmak için'),
    ZikirSeedItem(name: 'El-Mü\'min', arabic: 'الْمُؤْمِنُ', target: 137, category: 'Esmaül-Hüsna', virtue: 'Güvende olma, güvenilir insan olmak için'),
    ZikirSeedItem(name: 'El-Muheymin', arabic: 'الْمُهَيْمِنُ', target: 145, category: 'Esmaül-Hüsna', virtue: 'İnsanlardan korunmak ve akıl erdirebilmek için'),
    ZikirSeedItem(name: 'El-Aziz', arabic: 'الْعَزِيزُ', target: 94, category: 'Esmaül-Hüsna', virtue: 'Düşmanlara galip gelmek için'),
    ZikirSeedItem(name: 'El-Cebbâr', arabic: 'الْجَبَّارُ', target: 206, category: 'Esmaül-Hüsna', virtue: 'İstek ve arzuların olması, şerlerden emin olmak için'),
    ZikirSeedItem(name: 'El-Mütekebbir', arabic: 'الْمُتَكَبِّرُ', target: 662, category: 'Esmaül-Hüsna', virtue: 'İzzet, refah ve gerçek büyüklüğe erişmek için'),
    ZikirSeedItem(name: 'El-Hâlık', arabic: 'الْخَالِقُ', target: 731, category: 'Esmaül-Hüsna', virtue: 'İşlerde üzüntü ve sıkıntıdan kurtulmak için'),
    ZikirSeedItem(name: 'El-Bâri', arabic: 'الْبَارِئُ', target: 214, category: 'Esmaül-Hüsna', virtue: 'İşte başarılı olmak, sıkıntılardan kurtulmak için'),
    ZikirSeedItem(name: 'El-Musavvir', arabic: 'الْمُصَوِّرُ', target: 336, category: 'Esmaül-Hüsna', virtue: 'Maksat ve meramına ulaşmak, uzmanlaşmak için'),
    ZikirSeedItem(name: 'El-Gaffâr', arabic: 'الْغَفَّارُ', target: 1281, category: 'Esmaül-Hüsna', virtue: 'Bağışlanmak ve günahlardan korunmak için'),
    ZikirSeedItem(name: 'El-Kahhâr', arabic: 'الْقَهَّارُ', target: 306, category: 'Esmaül-Hüsna', virtue: 'Zalimlerin kahrından kurtulmak için'),
    ZikirSeedItem(name: 'El-Vehhâb', arabic: 'الْوَهَّابُ', target: 14, category: 'Esmaül-Hüsna', virtue: 'Sıkıntısız ve maddî açıdan rahat bir hayat için'),
    ZikirSeedItem(name: 'Er-Rezzâk', arabic: 'الرَّزَّاقُ', target: 308, category: 'Esmaül-Hüsna', virtue: 'Bol rızıklı bir ömür geçirmek için'),
    ZikirSeedItem(name: 'El-Fettâh', arabic: 'الْفَتَّاحُ', target: 489, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî hayır kapılarının açılması için'),
    ZikirSeedItem(name: 'El-Alim', arabic: 'الْعَلِيمُ', target: 150, category: 'Esmaül-Hüsna', virtue: 'İlim zenginliği için'),
    ZikirSeedItem(name: 'El-Kâbid', arabic: 'الْقَابِضُ', target: 903, category: 'Esmaül-Hüsna', virtue: 'Zalimin zulmünden kurtulmak için'),
    ZikirSeedItem(name: 'El-Bâsit', arabic: 'الْبَاسِطُ', target: 72, category: 'Esmaül-Hüsna', virtue: 'Rızkının genişlemesi ve bereketin artması için'),
    ZikirSeedItem(name: 'El-Hafid', arabic: 'الْخَافِضُ', target: 1481, category: 'Esmaül-Hüsna', virtue: 'Kötüden, kötülerden ve belalardan korunmak için'),
    ZikirSeedItem(name: 'Er-Rafi\'', arabic: 'الرَّافِعُ', target: 351, category: 'Esmaül-Hüsna', virtue: 'İnsanlar içinde ve işinde yükselmek için'),
    ZikirSeedItem(name: 'El-Muiz', arabic: 'الْمُعِزُّ', target: 117, category: 'Esmaül-Hüsna', virtue: 'Fakir ve zelillikten kurtulmak için'),
    ZikirSeedItem(name: 'El-Muzil', arabic: 'الْمُذِلُّ', target: 770, category: 'Esmaül-Hüsna', virtue: 'Düşmanları zelil etmek için'),
    ZikirSeedItem(name: 'Es-Semi\'', arabic: 'السَّمِيعُ', target: 180, category: 'Esmaül-Hüsna', virtue: 'Duaların kabul olması için'),
    ZikirSeedItem(name: 'El-Basir', arabic: 'الْبَصِيرُ', target: 302, category: 'Esmaül-Hüsna', virtue: 'Acziyetin kalkması, basiretli olmak için'),
    ZikirSeedItem(name: 'El-Hakem', arabic: 'الْحَكَمُ', target: 68, category: 'Esmaül-Hüsna', virtue: 'Haklı davasını kazanmak için'),
    ZikirSeedItem(name: 'El-Adl', arabic: 'الْعَدْلُ', target: 104, category: 'Esmaül-Hüsna', virtue: 'Adaletli olmak, haklı davayı kazanmak için'),
    ZikirSeedItem(name: 'El-Latîf', arabic: 'اللَّطِيفُ', target: 129, category: 'Esmaül-Hüsna', virtue: 'Dileklerin olması, kısmet ve rızkın artması için'),
    ZikirSeedItem(name: 'El-Habîr', arabic: 'الْخَبِيرُ', target: 812, category: 'Esmaül-Hüsna', virtue: 'Hafıza ve idrakin genişlemesi için'),
    ZikirSeedItem(name: 'El-Halîm', arabic: 'الْحَلِيمُ', target: 88, category: 'Esmaül-Hüsna', virtue: 'Ahlâk güzelliği ve yumuşak huylu olmak için'),
    ZikirSeedItem(name: 'El-Azîm', arabic: 'الْعَظِيمُ', target: 1020, category: 'Esmaül-Hüsna', virtue: 'Sözünün tesirli olması, sözü dinlenir olmak için'),
    ZikirSeedItem(name: 'El-Gafûr', arabic: 'الْغَفُورُ', target: 1286, category: 'Esmaül-Hüsna', virtue: 'Günahların affı ve kötü ahlâktan korunmak için'),
    ZikirSeedItem(name: 'Eş-Şekûr', arabic: 'الشَّكُورُ', target: 526, category: 'Esmaül-Hüsna', virtue: 'Nimetlerin şükrünü eda etmek, bol rızık için'),
    ZikirSeedItem(name: 'El-Aliyy', arabic: 'الْعَلِيُّ', target: 110, category: 'Esmaül-Hüsna', virtue: 'Zilletten kurtulmak, ilim derecelerin artması için'),
    ZikirSeedItem(name: 'El-Kebîr', arabic: 'الْكَبِيرُ', target: 232, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî büyüklük, hürmet sahibi olmak için'),
    ZikirSeedItem(name: 'El-Hafîz', arabic: 'الْحَفِظُ', target: 998, category: 'Esmaül-Hüsna', virtue: 'Nefsinin ve malının korunması için'),
    ZikirSeedItem(name: 'El-Mukît', arabic: 'الْمُقِيتُ', target: 550, category: 'Esmaül-Hüsna', virtue: 'Muhtaç olunan şeyi kazanmak ve rızık için'),
    ZikirSeedItem(name: 'El-Hasîb', arabic: 'الْحَسِيبُ', target: 80, category: 'Esmaül-Hüsna', virtue: 'Herkese karşı açık alınlı olmak için'),
    ZikirSeedItem(name: 'El-Celîl', arabic: 'الْجَلِيلُ', target: 73, category: 'Esmaül-Hüsna', virtue: 'Gerçek yüceliğe erişmek, zalimi zelil etmek için'),
    ZikirSeedItem(name: 'El-Kerîm', arabic: 'الْكَرِيمُ', target: 270, category: 'Esmaül-Hüsna', virtue: 'Bol rızık sahibi olmak, cömert olmak için'),
    ZikirSeedItem(name: 'Er-Rakîb', arabic: 'الرَّقِيبُ', target: 312, category: 'Esmaül-Hüsna', virtue: 'Allah\'ın koruması altında olmak, hafıza kuvveti için'),
    ZikirSeedItem(name: 'El-Mücîb', arabic: 'الْمُجِيبُ', target: 55, category: 'Esmaül-Hüsna', virtue: 'Duaların kabul olunması için'),
    ZikirSeedItem(name: 'El-Vâsi\'', arabic: 'الْوَاسِعُ', target: 137, category: 'Esmaül-Hüsna', virtue: 'Ömür uzunluğu, sıhhat ve rızık genişliği için'),
    ZikirSeedItem(name: 'El-Hakîm', arabic: 'الْحَكِيمُ', target: 78, category: 'Esmaül-Hüsna', virtue: 'İlim ve hikmet sahibi olmak için'),
    ZikirSeedItem(name: 'El-Vedûd', arabic: 'الْوَدُودُ', target: 20, category: 'Esmaül-Hüsna', virtue: 'İnsanların sevgisini kazanmak için'),
    ZikirSeedItem(name: 'El-Mecîd', arabic: 'الْمَاجِدُ', target: 57, category: 'Esmaül-Hüsna', virtue: 'İzzet ve şerefin artması için'),
    ZikirSeedItem(name: 'El-Bâis', arabic: 'الْبَاعِثُ', target: 573, category: 'Esmaül-Hüsna', virtue: 'Kuvvetli irade ve alacaklarını almak için'),
    ZikirSeedItem(name: 'Eş-Şehîd', arabic: 'الشَّهِيدُ', target: 319, category: 'Esmaül-Hüsna', virtue: 'Şehid olmak, heybetli olmak için'),
    ZikirSeedItem(name: 'El-Hakk', arabic: 'الْحَقُّ', target: 108, category: 'Esmaül-Hüsna', virtue: 'Sağlam iman ve doğru ibadet hayatı için'),
    ZikirSeedItem(name: 'El-Vekîl', arabic: 'الْوَكِيلُ', target: 66, category: 'Esmaül-Hüsna', virtue: 'Allah\'tan her türlü yardım görmek için'),
    ZikirSeedItem(name: 'El-Kavî', arabic: 'الْقَوِيُّ', target: 116, category: 'Esmaül-Hüsna', virtue: 'Vücudun güçlü olması, zor işleri halletmek için'),
    ZikirSeedItem(name: 'El-Metîn', arabic: 'الْمَتِينُ', target: 500, category: 'Esmaül-Hüsna', virtue: 'Maddî ve manevî dayanıklı, sağlam olmak için'),
    ZikirSeedItem(name: 'El-Veliyy', arabic: 'الْوَلِيُّ', target: 46, category: 'Esmaül-Hüsna', virtue: 'Her işte Allah\'ın yardımını istemek için'),
    ZikirSeedItem(name: 'El-Hamîd', arabic: 'الْحَمِيدُ', target: 62, category: 'Esmaül-Hüsna', virtue: 'Kazancın genişlemesi, Allah\'a hamd etmek için'),
    ZikirSeedItem(name: 'El-Muhsî', arabic: 'الْمُحْصِي', target: 148, category: 'Esmaül-Hüsna', virtue: 'Zekânın kuvvetli olması için'),
    ZikirSeedItem(name: 'El-Mübdi', arabic: 'الْمُبْدِئُ', target: 57, category: 'Esmaül-Hüsna', virtue: 'Her işte muvaffak olmak için'),
    ZikirSeedItem(name: 'El-Muîd', arabic: 'الْمُعِيدُ', target: 124, category: 'Esmaül-Hüsna', virtue: 'Elden kaçanı geri kazanmak için'),
    ZikirSeedItem(name: 'El-Muhyî', arabic: 'الْمُحْيِي', target: 68, category: 'Esmaül-Hüsna', virtue: 'İşlerin başarılı olması, hastalıklardan kurtulmak için'),
    ZikirSeedItem(name: 'El-Mumît', arabic: 'الْمُمِيتُ', target: 490, category: 'Esmaül-Hüsna', virtue: 'Harama bakmamak, kötülüklerden vazgeçmek için'),
    ZikirSeedItem(name: 'El-Hayy', arabic: 'الْحَيُّ', target: 18, category: 'Esmaül-Hüsna', virtue: 'Sözün tesirli olması, sözü dinlenir olmak için'),
    ZikirSeedItem(name: 'El-Kayyûm', arabic: 'الْقَيُّومُ', target: 156, category: 'Esmaül-Hüsna', virtue: 'İsteklere nail olmak, rızkın devamlı olması için'),
    ZikirSeedItem(name: 'El-Vâcid', arabic: 'الْوَاجِدُ', target: 14, category: 'Esmaül-Hüsna', virtue: 'Aradığını ve kaybettiğini bulmak için'),
    ZikirSeedItem(name: 'El-Mâcid', arabic: 'الْمَاجِدُ', target: 48, category: 'Esmaül-Hüsna', virtue: 'Kazancın bolluğu ve şerefli bir hayat için'),
    ZikirSeedItem(name: 'El-Vâhid', arabic: 'الْوَاحِدُ', target: 19, category: 'Esmaül-Hüsna', virtue: 'Kalbin uyanıklığı, isteklerin olması için'),
    ZikirSeedItem(name: 'Es-Samed', arabic: 'الصَّمَدُ', target: 134, category: 'Esmaül-Hüsna', virtue: 'Hiç kimseye muhtaç olmamak için'),
    ZikirSeedItem(name: 'El-Kâdir', arabic: 'الْقَادِرُ', target: 305, category: 'Esmaül-Hüsna', virtue: 'İstediğini yapmaya güç yetirmek için'),
    ZikirSeedItem(name: 'El-Muktedir', arabic: 'الْمُقْتَدِرُ', target: 744, category: 'Esmaül-Hüsna', virtue: 'Her işte başarılı olmak için'),
    ZikirSeedItem(name: 'El-Mukaddim', arabic: 'الْمُقَدِّمُ', target: 184, category: 'Esmaül-Hüsna', virtue: 'Daima yükselmek için'),
    ZikirSeedItem(name: 'El-Muahhir', arabic: 'الْمُؤَخِّرُ', target: 847, category: 'Esmaül-Hüsna', virtue: 'Kötü birinin veya işin uzaklaşması için'),
    ZikirSeedItem(name: 'El-Evvel', arabic: 'الْأَوَّلُ', target: 37, category: 'Esmaül-Hüsna', virtue: 'Her hayır işinde birinci olmak için'),
    ZikirSeedItem(name: 'El-Âhir', arabic: 'الْآخِرُ', target: 801, category: 'Esmaül-Hüsna', virtue: 'Ömrün uzun olması için'),
    ZikirSeedItem(name: 'Ez-Zâhir', arabic: 'الظَّاهِرُ', target: 1106, category: 'Esmaül-Hüsna', virtue: 'Her meselenin açıklığı için'),
    ZikirSeedItem(name: 'El-Bâtın', arabic: 'الْبَاطِنُ', target: 62, category: 'Esmaül-Hüsna', virtue: 'İç rahatlığının artması için'),
    ZikirSeedItem(name: 'El-Vâlî', arabic: 'الْوَالِي', target: 47, category: 'Esmaül-Hüsna', virtue: 'Sözünün tesirli olması için'),
    ZikirSeedItem(name: 'El-Müteâlî', arabic: 'الْمُتَعَالِي', target: 551, category: 'Esmaül-Hüsna', virtue: 'İstediği makama gelmek için'),
    ZikirSeedItem(name: 'El-Berr', arabic: 'الْبَرُّ', target: 202, category: 'Esmaül-Hüsna', virtue: 'Her halukarda iyilik bulmak için'),
    ZikirSeedItem(name: 'Et-Tevvâb', arabic: 'التَّوَّابُ', target: 409, category: 'Esmaül-Hüsna', virtue: 'Tövbelerin kabul olması için'),
    ZikirSeedItem(name: 'El-Müntekım', arabic: 'الْمُنْتَقِمُ', target: 630, category: 'Esmaül-Hüsna', virtue: 'Zulüm ve fenalıklardan korunmak için'),
    ZikirSeedItem(name: 'El-Afuvv', arabic: 'الْعَفُوُّ', target: 156, category: 'Esmaül-Hüsna', virtue: 'Rızık bolluğu, kalp huzuru, affedilmek için'),
    ZikirSeedItem(name: 'Er-Raûf', arabic: 'الرَّؤُوفُ', target: 287, category: 'Esmaül-Hüsna', virtue: 'Merhametin artması, zarar görmemek için'),
    ZikirSeedItem(name: 'Mâlikü\'l-Mülk', arabic: 'مَالِكُ الْمُلْكِ', target: 212, category: 'Esmaül-Hüsna', virtue: 'Mal ve kazanca zarar gelmemesi için'),
    ZikirSeedItem(name: 'Zü\'l-Celâli ve\'l-İkrâm', arabic: 'ذُو الْجَلَالِ وَالْإِكْرَامِ', target: 1100, category: 'Esmaül-Hüsna', virtue: 'İşlerin kolay olması için'),
    ZikirSeedItem(name: 'El-Muksit', arabic: 'الْمُقْسِطُ', target: 209, category: 'Esmaül-Hüsna', virtue: 'Eşlerin arasını düzeltmek, adaletli olmak için'),
    ZikirSeedItem(name: 'El-Câmi', arabic: 'الْجَامِعُ', target: 114, category: 'Esmaül-Hüsna', virtue: 'Küsleri barıştırmak, hayırların toplanması için'),
    ZikirSeedItem(name: 'El-Ganî', arabic: 'الْغَنِيُّ', target: 1060, category: 'Esmaül-Hüsna', virtue: 'Gerçek zenginlik, geniş rızık için'),
    ZikirSeedItem(name: 'El-Muğnî', arabic: 'الْمُغْنِي', target: 1100, category: 'Esmaül-Hüsna', virtue: 'Geçim genişliği, bol rızık ve zenginlik için'),
    ZikirSeedItem(name: 'El-Mâni\'', arabic: 'الْمَانِعُ', target: 161, category: 'Esmaül-Hüsna', virtue: 'Kaza ve belalardan emin olmak için'),
    ZikirSeedItem(name: 'Ed-Dârr', arabic: 'الضَّارُّ', target: 1001, category: 'Esmaül-Hüsna', virtue: 'Zararlı kişilerden emin olmak için'),
    ZikirSeedItem(name: 'En-Nâfi\'', arabic: 'النَّافِعُ', target: 201, category: 'Esmaül-Hüsna', virtue: 'Hastalıklardan korunmak, şifa bulmak için'),
    ZikirSeedItem(name: 'En-Nûr', arabic: 'النُّورُ', target: 256, category: 'Esmaül-Hüsna', virtue: 'Doğruyu ve yanlışı görüp kalp nuruna sahip olmak için'),
    ZikirSeedItem(name: 'El-Hâdî', arabic: 'الْهَادِي', target: 20, category: 'Esmaül-Hüsna', virtue: 'Doğru yolu bulmak için'),
    ZikirSeedItem(name: 'El-Bedî\'', arabic: 'الْبَدِيعُ', target: 86, category: 'Esmaül-Hüsna', virtue: 'Allah\'ın yardımına nail olmak, güzellik için'),
    ZikirSeedItem(name: 'El-Bâkî', arabic: 'الْبَاقِي', target: 113, category: 'Esmaül-Hüsna', virtue: 'Ömrün uzunluğu ve sağlıklı olmak için'),
    ZikirSeedItem(name: 'El-Vâris', arabic: 'الْوَارِثُ', target: 707, category: 'Esmaül-Hüsna', virtue: 'Uzun ömür, bol mal, şeref ve rızık için'),
    ZikirSeedItem(name: 'Er-Reşîd', arabic: 'الرَّشِيدُ', target: 514, category: 'Esmaül-Hüsna', virtue: 'Güzel ahlâk sahibi olmak için'),
    ZikirSeedItem(name: 'Es-Sabûr', arabic: 'الصَّبُورُ', target: 298, category: 'Esmaül-Hüsna', virtue: 'Başladığı işi kolay bitirmek, sabırlı olmak için'),

    // =========================================================================
    // 3. PEYGAMBER VE KUR'AN DUALARI (MAUI EXACT)
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
    ZikirSeedItem(name: 'Yûnus (a.s.) Duası', arabic: 'لَٓا اِلٰهَ اِلَّٓا اَنْتَ سُبْحَانَكَ اِنّ۪ي كُنْتُ مِنَ الظَّالِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Senden başka ilâh yoktur. Şüphesiz ben kendine yazık edenlerden oldum." (Enbiyâ, 87)'),
    ZikirSeedItem(name: 'Zekeriyyâ (a.s.) Duası 1', arabic: 'رَبِّ لَا تَذَرْن۪ي فَرْداً وَاَنْتَ خَيْرُ الْوَارِث۪ينَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni tek başıma bırakma. Sen vârislerin en hayırlısısın." (Enbiyâ, 89)'),
    ZikirSeedItem(name: 'Zekeriyyâ (a.s.) Duası 2', arabic: 'رَبِّ هَبْ ل۪ي مِنْ لَدُنْكَ ذُرِّيَّةً طَيِّبَةً اِنَّكَ سَم۪يعُ الدُّعَٓاءِ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Bana katından temiz bir soy ihsan eyle, şüphesiz Sen duâyı işitensin." (Âl-i İmrân, 38)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 1', arabic: 'حَسْبِيَ اللّٰهُ لَٓا اِلٰهَ اِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظ۪يمِ', target: 25, category: 'Dualar', virtue: '"Allah bana yeter. O\'ndan başka ilâh yoktur. Ben sadece O\'na güvenip dayanırım. O yüce Arş\'ın sahibidir." (Tevbe, 129)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 2', arabic: 'رَبِّ احْكُمْ بِالْحَقِّ وَرَبُّنَا الرَّحْمٰنُ الْمُسْتَعَانُ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Aramızda gerçekle hükmet. Rabbimiz O Rahmân\'dır ki yardımına sığınılacak olan ancak O\'dur." (Enbiyâ, 112)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 3', arabic: 'رَبِّ فَلَا تَجْعَلْن۪ي فِي الْقَوْمِ الظَّالِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Rabbim! Beni zalimler topluluğunun içinde bulundurma!" (Mü\'minûn, 93-94)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 4', arabic: 'رَبِّ اَعُوذُ بِكَ مِنْ هَمَزَاتِ الشَّيَاط۪ينِ وَاَعُوذُ بِكَ رَبِّ اَنْ يَحْضُرُونِ', target: 25, category: 'Dualar', virtue: '"Ey Rabbim! Şeytanların vesveselerinden Sana sığınırım. Onların yanımda bulunmalarından da Sana sığınırım." (Mü\'minûn, 97-98)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 5', arabic: 'رَبِّ اغْفِرْ وَارْحَمْ وَاَنْتَ خَيْرُ الرَّاحِم۪ينَ', target: 25, category: 'Dualar', virtue: '"Bağışla ve merhamet et Rabbim! Sen merhametlilerin en iyisidir." (Mü\'minûn, 118)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 6', arabic: 'رَبِّ اَدْخِلْن۪ي مُدْخَلَ صِدْقٍ وَاَخْرِجْن۪ي مُخْرَجَ صِدْقٍ وَاجْعَلْ ل۪ي مِنْ لَدُنْكَ سُلْطَاناً نَص۪يراً', target: 25, category: 'Dualar', virtue: '"Rabbim! Gireceğim yere dürüstlükle girmemi, çıkacağım yerden dürüstlükle çıkmamı sağla. Tarafından yardım edici kuvvet ver." (İsrâ, 80)'),
    ZikirSeedItem(name: 'Hz. Muhammed (s.a.v.) Duası 7', arabic: 'رَبِّ زِدْن۪ي عِلْماً', target: 25, category: 'Dualar', virtue: '"Rabbim, ilmimi artır." (Tâhâ, 114)'),
  ];

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
