import '../domain/models/farz_knowledge_item.dart';

/// Diyanet İşleri Başkanlığı İlmihali (Cilt 1) esas alınarak hazırlanan 32 Farz Külliyatı.
/// Bilgiler mezhep hükümleri, Kur'an ve Sünnet delilleriyle tam uyumludur.
const List<FarzKnowledgeItem> kFarz32List = [
  // ==========================================
  // I. İMANIN ŞARTLARI (6 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 1,
    category: FarzCategory.iman,
    orderInGroup: 1,
    title: 'Allah\'a İman',
    term: 'Âmentü billâh',
    notificationSummary: 'Varlığı zorunlu, kemal sıfatlarla muttasıf, noksan sıfatlardan münezzeh ve tek yaratıcı olan Allah\'a kalben inanıp dille ikrar etmektir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 68-91',
    keyPoints: [
      'Allah\'ın varlığı ve birliği (Tevhid) inancı İslâm\'ın temelidir.',
      'Zâtî ve Sübûtî sıfatlarıyla O\'nu kemal derecesinde tanımak farzdır.',
      'Hiçbir şeyi O\'na ortak (şirk) koşmamak dinin esasıdır.',
    ],
    fullContent: 'İmanın birinci ve en temel şartı Allah\'ın varlığına, birliğine, eşi ve benzeri bulunmadığına inanmaktır. İslâm inancında Allah Teâlâ, varlığı kendinden olan (Vâcibü\'l-vücûd), kemal sıfatlarla muttasıf ve her türlü eksiklikten münezzeh olandır.\n\n'
        'Kur\'ân-ı Kerîm\'de İhlâs Sûresi\'nde: "De ki: O Allah tektir. Allah Samed\'dir (her şey O\'na muhtaç, O hiçbir şeye muhtaç değildir). Doğurmamış ve doğurulmamıştır. O\'nun hiçbir dengi yoktur." (el-İhlâs 112/1-4) buyrulmuştur.\n\n'
        'Allah\'a iman; O\'nun Zâtî sıfatları (Vücûd, Kıdem, Bekā, Vahdâniyyet, Muhâlefetün li\'l-havâdis, Kıyâm bi-nefsihî) ve Sübûtî sıfatları (Hayat, İlim, Semî, Basar, İrâde, Kudret, Kelâm, Tekvîn) ile inanmayı kapsar. Müminin kalbinde tevhid akidesinin kökleşmesi, hayatındaki bütün amellerin ihlasla yalnızca Allah rızası için yapılmasını temin eder.',
  ),
  FarzKnowledgeItem(
    id: 2,
    category: FarzCategory.iman,
    orderInGroup: 2,
    title: 'Meleklere İman',
    term: 'Ve melâiketihî',
    notificationSummary: 'Nurdan yaratılmış, günah işlemeyen, yemeyen içmeyen ve Allah\'ın emirlerine harfiyen itaat eden ruhanî varlıklara inanmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 92-98',
    keyPoints: [
      'Melekler nurdan yaratılmış, erkeklik ve dişilikleri olmayan latif varlıklardır.',
      'Dört büyük melek: Cebrâil, Mîkâil, İsrâfil ve Azrâil\'dir.',
      'Kirâmen Kâtibîn (yazıcı melekler) insanın her amelini kaydeder.',
    ],
    fullContent: 'Melekler; nurani, gözle görülmeyen, yemeyen, içmeyen, evlenmeyen, uyumayan, cinsiyeti bulunmayan ve daima Allah\'a ibadet ve itaat eden latif varlıklardır. Kur\'ân-ı Kerîm meleklerin varlığını ve onların görevlerini açıkça haber vermiştir (el-Bakara 2/285).\n\n'
        'Meleklerin başında dört büyük melek gelir: Cebrâil (vahiy getiren), Mîkâil (tabiat olaylarını sevk eden), İsrâfil (Sûr\'a üfleyen) ve Azrâil (canları kabzeden). Ayrıca insanın sağında ve solunda bulunan Kirâmen Kâtibîn melekleri her söz ve davranışı kaydederken, Münker ve Nekir kabirde ilk suali soracaktır.\n\n'
        'Meleklere iman eden bir mümin, hiçbir zaman yalnız olmadığını, her daim ilahî gözetim ve rahmet muhafazası altında bulunduğunu bilerek günahlardan haya eder ve edebini muhafaza eder.',
  ),
  FarzKnowledgeItem(
    id: 3,
    category: FarzCategory.iman,
    orderInGroup: 3,
    title: 'Kitaplara İman',
    term: 'Ve kütubihî',
    notificationSummary: 'Allah\'ın peygamberlerine vahiyle gönderdiği suhuflara ve dört büyük ilahî kitaba (Tevrat, Zebûr, İncil, Kur\'an) inanmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 99-105',
    keyPoints: [
      'Allah insanlara yol göstermek üzere ilahi kitaplar indirmiştir.',
      'Dört büyük kitap ve bazı peygamberlere verilen suhuflar haktır.',
      'Kur\'ân-ı Kerîm son ilahî kitaptır ve kıyamete kadar tahriften korunmuştur.',
    ],
    fullContent: 'Yüce Allah, kullarına dünya ve ahiret saadetinin yollarını bildirmek, adaleti ayakta tutmak ve hidayet rehberliği yapmak üzere peygamberlerine vahiy yoluyla kitaplar indirmiştir. Kitaplara iman, bu vahiylerin asıllarının Allah kelâmı olduğuna inanmayı ifade eder.\n\n'
        'Kur\'an-ı Kerîm\'de isimleri zikredilen dört büyük ilahi kitap şunlardır: Hz. Mûsâ\'ya Tevrat, Hz. Dâvûd\'a Zebûr, Hz. Îsâ\'ya İncil ve nihayet âhir zaman peygamberi Hz. Muhammed\'e (s.a.v.) Kur\'ân-ı Kerîm verilmiştir. Ayrıca Hz. Âdem, Hz. Şît, Hz. İdrîs ve Hz. İbrâhim\'e suhuflar (küçük sayfalar) vahyedilmiştir.\n\n'
        'Kur\'ân-ı Kerîm, önceki kitapların hükümlerini nesh eden, lâfzı ve mânasıyla mucize olan ve bizzat Cenâb-ı Hak tarafından: "Şüphesiz o Zikr\'i (Kur\'an\'ı) biz indirdik; onun koruyucusu da elbette biziz" (el-Hicr 15/9) âyetiyle ebediyyen koruma altına alınan son ilahî rehberdir.',
  ),
  FarzKnowledgeItem(
    id: 4,
    category: FarzCategory.iman,
    orderInGroup: 4,
    title: 'Peygamberlere İman',
    term: 'Ve rusulihî',
    notificationSummary: 'İlk peygamber Hz. Âdem\'den son peygamber Hz. Muhammed\'e (s.a.v.) kadar gönderilen bütün elçilerin hak olduğuna inanmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 106-116',
    keyPoints: [
      'Peygamberler insanların arasından seçilmiş güvenilir elçilerdir.',
      'Sıdk, emânet, tebliğ, fetânet ve ismet peygamberlerin vacip sıfatlarıdır.',
      'Hz. Muhammed (s.a.v.) Hâtemü\'l-enbiyâ ve bütün insanlığa gönderilmiştir.',
    ],
    fullContent: 'Peygamberlik (nübüvvet ve risâlet), Allah Teâlâ\'nın kulları arasından seçtiği elçiler vasıtasıyla emir ve yasaklarını insanlara tebliğ etme kurumudur. Peygamberlere iman, aralarında ayrım yapmaksızın hepsinin Allah\'ın hak elçileri olduğunu kabul etmektir.\n\n'
        'Peygamberlerin sıfatları şunlardır: Sıdk (doğruluk), Emânet (güvenilirlik), Tebliğ (ilahî mesajı eksiksiz ulaştırma), Fetânet (üstün akıl ve feraset) ve İsmet (günah işlemekten korunmuşluk). İlk insan aynı zamanda ilk peygamber Hz. Âdem, peygamberler zincirinin son halkası ise Hz. Muhammed Mustafâ\'dır (s.a.v.).\n\n'
        'Kur\'ân-ı Kerîm\'de: "Muhammed... Allah\'ın Resûlü ve peygamberlerin sonuncusudur" (el-Ahzâb 33/40) buyrularak onun risâletinin evrensel ve nihai olduğu tescil edilmiştir.',
  ),
  FarzKnowledgeItem(
    id: 5,
    category: FarzCategory.iman,
    orderInGroup: 5,
    title: 'Âhiret Gününe İman',
    term: 'Ve\'l-yevmi\'l-âhiri',
    notificationSummary: 'Dünya hayatının fani olduğuna, kıyametin kopacağına, kabirde diriliş, mîzan, hesap, cennet ve cehennemin hak olduğuna inanmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 117-131',
    keyPoints: [
      'Kabir hayatı (berzah), haşir ve hesap gerçektir.',
      'Ameller zerre miktarı da olsa hassas mîzanda tartılacaktır.',
      'İyiliklerin mükâfatı ebedi Cennet, inkâr ve zulmün cezası Cehennemdir.',
    ],
    fullContent: 'Âhirete iman; dünya hayatının bir imtihan sahası olduğunu, ölümle birlikte yok olunmayıp berzah (kabir) alemine geçileceğini, İsrâfil\'in Sûr\'a üflemesiyle kıyametin kopup bütün insanların yeniden diriltilerek (ba\'s) mahşer meydanında toplanacağını kabul etmektir.\n\n'
        'Mahşerde herkesin amel defteri açılacak, mîzan kurulacak ve en küçük hayır ile şer tartılacaktır (ez-Zilzâl 99/7-8). Âhiret inancı, insana yüksek bir ahlak, sorumluluk bilinci ve adalet duygusu kazandırır. Zira mazlumun hakkını zâlimden alacağı mutlak ilahî adalet günü orasıdır.',
  ),
  FarzKnowledgeItem(
    id: 6,
    category: FarzCategory.iman,
    orderInGroup: 6,
    title: 'Kazâ ve Kadere İman',
    term: 'Ve bi\'l-kaderi hayrihî ve şerrihî minallâhi teâlâ',
    notificationSummary: 'Kâinatta vuku bulan her şeyin Allah\'ın ezelî ilmi ve takdiriyle (kader) belirlendiğine ve zamanı gelince yaratıldığına (kazâ) inanmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 132-146',
    keyPoints: [
      'Kader, Allah\'ın olmuş ve olacak her şeyi ezelî ilmiyle bilmesi ve takdiridir.',
      'Kazâ, bu takdir edilen hadiselerin vakti geldiğinde yaratılmasıdır.',
      'İnsanın cüz\'î iradesi vardır; hür seçimlerinden dolayı sorumludur.',
    ],
    fullContent: 'Kader; Allah Teâlâ\'nın ezelden ebede kadar olmuş ve olacak bütün hadiseleri, zamanını, mekânını, nitelik ve özelliklerini ezelî ilmiyle bilip takdir etmesidir. Kazâ ise bu ezelî plana uygun olarak vakti gelince o şeylerin yaratılmasıdır.\n\n'
        'İslâm inancında kadere iman, tembellik veya cebrilik (sorumluluktan kaçma) demek değildir. Allah insana akıl ve cüz\'î irade vermiş, hayır ile şerri seçme hürriyeti tanımıştır. İnsan, kendi iradesiyle yaptığı amellerden dolayı sevap kazanır veya cezaya müstahak olur.\n\n'
        'Kadere iman eden mümin, başına gelen sıkıntılara karşı sabır ve metanet gösterir, elde ettiği başarılar karşısında da gurura kapılmayıp şükreder.',
  ),

  // ==========================================
  // II. İSLAM\'IN ŞARTLARI (5 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 7,
    category: FarzCategory.islam,
    orderInGroup: 1,
    title: 'Kelime-i Şehâdet Getirmek',
    term: 'Eşhedü enlâ ilâhe illallâh ve eşhedü enne Muhammeden abdühû ve resûlüh',
    notificationSummary: 'Allah\'tan başka ilâh olmadığına ve Hz. Muhammed\'in O\'nun kulu ve elçisi olduğuna kalben inanıp dille şahitlik etmektir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 68-74',
    keyPoints: [
      'İslâm dairesine girmenin ilk ve vazgeçilmez şartıdır.',
      'Dille ikrar ve kalple tasdik birbirini tamamlar.',
      'Şehâdet, hayat boyu Allah\'ın hâkimiyetine ve Sünnet\'e bağlılık ahdidir.',
    ],
    fullContent: 'Kelime-i Şehâdet: "Eşhedü en lâ ilâhe illallâh ve eşhedü enne Muhammeden abdühû ve resûlüh" (Şahitlik ederim ki Allah\'tan başka ilâh yoktur ve yine şahitlik ederim ki Muhammed O\'nun kulu ve elçisidir) cümlesini inanarak söylemektir.\n\n'
        'Bu mukaddes ikrar, İslâm binasının üzerine kurulduğu ilk ve en mühim sütundur. Resûlullah (s.a.v.): "İslâm beş temel üzerine bina edilmiştir: Allah\'tan başka ilâh olmadığına ve Muhammed\'in Allah\'ın kulu ve elçisi olduğuna şehâdet etmek, namazı dosdoğru kılmak, zekâtı vermek, Kâbe\'yi haccetmek ve Ramazan orucunu tutmaktır" (Buhârî, Îmân, 1) buyurmuştur.\n\n'
        'Şehâdet getiren kimse, hem Allah\'ın mutlak otoritesini kabul etmiş hem de Hz. Muhammed\'in (s.a.v.) rehberliğini hayatının yegâne ölçüsü kılmış olur.',
  ),
  FarzKnowledgeItem(
    id: 8,
    category: FarzCategory.islam,
    orderInGroup: 2,
    title: 'Namaz Kılmak',
    term: 'İkāmetü\'s-salât',
    notificationSummary: 'Akıl baliğ her mümine günde 5 vakit farz olan, kulun Rabbiyle doğrudan miraç makamında buluştuğu en faziletli ibadettir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 219-226',
    keyPoints: [
      'Dinin direği, amellerin hesabı sorulacak ilkidir.',
      'Günde beş vakit farz-ı ayındır.',
      'İnsanı her türlü hayasızlıktan ve kötülükten alıkoyar.',
    ],
    fullContent: 'Namaz (salât), İslâm\'ın Kelime-i Şehâdet\'ten sonra gelen en büyük rüknü ve dinin direğidir. Akıllı ve ergenlik çağına ermiş her müslümana sabah, öğle, ikindi, akşam ve yatsı olmak üzere günde beş vakit namaz kılmak farz-ı ayındır.\n\n'
        'Kur\'ân-ı Kerîm\'de yetmişe yakın yerde dosdoğru namaz kılınması emredilmiş ve: "Şüphesiz namaz, müminler üzerine vakitleri belirlenmiş bir farzdır" (en-Nisâ 4/103) buyrulmuştur. Yine: "Şüphesiz namaz, insanı hayasızlıktan ve kötülükten alıkoyar" (el-Ankebût 29/45) buyrularak namazın ahlakı inşa eden gücüne işaret edilmiştir.\n\n'
        'Namaz, kulun Allah huzurunda divana durduğu, tekbirle dünyayı arkaya atıp secde ile O\'na en yakın olduğu mukaddes vuslat ânıdır.',
  ),
  FarzKnowledgeItem(
    id: 9,
    category: FarzCategory.islam,
    orderInGroup: 3,
    title: 'Zekât Vermek',
    term: 'Îtâü\'z-zekât',
    notificationSummary: 'Dinen zengin sayılan müminin, nisap miktarı malından yılda bir defa Kur\'an\'da belirtilen sekiz hak sahibine vermesidir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 419-427',
    keyPoints: [
      'Nisap miktarı (80.18 gr altın veya dengi) mala sahip olan hür müslümana farzdır.',
      'Malın üzerinden bir kameri yıl (havelânü\'l-havl) geçmesi gerekir.',
      'Malı bereketlendirir, cimrilikten arındırır ve toplumsal adaleti sağlar.',
    ],
    fullContent: 'Zekât; dinen zengin olan müslümanın, temel ihtiyaçları ve borçları dışında kalan nisap miktarı (80.18 gr altın veya değerinde para/ticaret malı) malından her yıl kırkta birini (%2.5) Tevbe Sûresi 60. âyette belirtilen hak sahiplerine vermesidir.\n\n'
        'Kur\'an-ı Kerîm\'de zekât, namaz ile birlikte defalarca zikredilmiş: "Namazı kılın, zekâtı verin" (el-Bakara 2/43) buyrulmuştur. Zekât, lügatte artma, bereket ve temizlenme manalarına gelir.\n\n'
        'Zekât ibadeti, zengin ile fakir arasındaki şefkat ve muhabbet köprüsünü kurar, sermayenin belli ellerde toplanıp sömürü aracına dönüşmesini engeller ve malı haramdan arındırır.',
  ),
  FarzKnowledgeItem(
    id: 10,
    category: FarzCategory.islam,
    orderInGroup: 4,
    title: 'Oruç Tutmak',
    term: 'Savm-u Ramazan',
    notificationSummary: 'Ramazan ayında imsak vaktinden akşam ezanına kadar niyet ederek yeme, içme ve nefsi arzulardan uzak durmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 381-386',
    keyPoints: [
      'Ramazan ayı orucu her mükellef müslümana farzdır.',
      'İmsak ile iftar arasında yeme, içme ve cinsi münasebetten sakınılır.',
      'Sabır, takva ve nefis terbiyesinin en yüce mektebidir.',
    ],
    fullContent: 'Oruç (savm), fecr-i sâdıktan (imsak vaktinden) güneş batıncaya (iftar vaktine) kadar ibadet niyetiyle yeme, içme ve cinsel ilişkiden uzak durmaktır. Ramazan orucu hicretin ikinci yılında farz kılınmıştır.\n\n'
        'Cenâb-ı Hak: "Ey iman edenler! Allah\'a karşı gelmekten sakınasınız diye, sizden öncekilere farz kılındığı gibi size de oruç farz kılındı" (el-Bakara 2/183) buyurmuştur.\n\n'
        'Oruç, sadece bedeni aç bırakmak değil; dili yalandan, gözü haramdan, kalbi kötülükten korumaktır. Hadis-i kudsîde: "Oruç benim içindir, onun mükâfatını bizzat ben vereceğim" (Buhârî, Savm, 9) buyrulmuştur.',
  ),
  FarzKnowledgeItem(
    id: 11,
    category: FarzCategory.islam,
    orderInGroup: 5,
    title: 'Hacca Gitmek',
    term: 'Haccu\'l-beyt',
    notificationSummary: 'Sağlığı ve mali imkânı elveren müminin, ömründe bir defa ihrama girerek Arafat vakfesini ve Kâbe tavafını eda etmesidir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 487-500',
    keyPoints: [
      'Şartları taşıyan mümine ömründe bir defa farz-ı ayındır.',
      'İhrama girmek, Arafat vakfesi ve Ziyaret Tavafı haccın ana rükünleridir.',
      'Bütün dünya müslümanlarının kardeşlik ve tevhid kongresidir.',
    ],
    fullContent: 'Hac; belirli zamanda (Hac ayları ve Zilhicce\'nin ilk on günü), belirli şartları taşıyan kimselerin, ihrama girerek Arafat\'ta vakfe yapması ve Kâbe-i Muazzama\'yı tavaf etmesinden ibaret kapsamlı bir mali ve bedeni ibadettir.\n\n'
        'Âyet-i kerîmede: "Yoluna gücü yetenlerin o evi (Kâbe\'yi) haccetmesi, Allah\'ın insanlar üzerindeki bir hakkıdır" (Âl-i İmrân 3/97) buyrulmuştur.\n\n'
        'Hac ibadeti, makam, ırk ve zenginlik farklarını ihramın iki parça beyaz örtüsü altında yok eden, mahşer gününün provası niteliğinde muazzam bir tevhid şölenidir. Mebrur bir haccın karşılığı ancak Cennettir.',
  ),

  // ==========================================
  // III. ABDESTİN FARZLARI (4 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 12,
    category: FarzCategory.abdest,
    orderInGroup: 1,
    title: 'Yüzü Yıkamak',
    term: 'Guslü\'l-vech',
    notificationSummary: 'Abdestte saç bitiminden çene altına, bir kulak memesinden diğerine kadar bütün yüzü bir defa yıkamak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 194-196',
    keyPoints: [
      'Alındaki saç bitim yerinden çene altına kadar boyuna yıkanır.',
      'İki kulak yumuşağı arası enine tamamen yıkanmalıdır.',
      'Sakal seyrekse deri, gür ise sakalın üstü yıkanır.',
    ],
    fullContent: 'Abdestin ilk farzı yüzü bir kere tam olarak yıkamaktır. Kur\'ân-ı Kerîm\'de: "Ey iman edenler! Namaza kalkacağınız zaman yüzlerinizi... yıkayın" (el-Mâide 5/6) buyrulmuştur.\n\n'
        'Fıkıh ıstılahında yüzün sınırları şöyledir: Boyuna olarak, normal saç bitim yerinden çene altına kadar; enine olarak ise iki kulak memesi arasında kalan alandır. Yüz yıkanırken bu sınırların içinde iğne ucu kadar kuru yer kalmamalıdır.\n\n'
        'Sakal şayet seyrek olup altındaki deri görünüyorsa derinin ıslanması farzdır; eğer sakal gür olup altındaki deri görünmüyorsa sakalın dış yüzünü yıkamak kâfidir. Abdest alırken suyu yüze çarpmadan, yukarıdan aşağıya edeple akıtmak sünnettir.',
  ),
  FarzKnowledgeItem(
    id: 13,
    category: FarzCategory.abdest,
    orderInGroup: 2,
    title: 'Kolları Dirseklerle Beraber Yıkamak',
    term: 'Guslü\'l-yedeyn',
    notificationSummary: 'Parmak uçlarından başlayarak dirseklerin yukarısına kadar her iki kolu kuru yer kalmayacak şekilde yıkamak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 196-197',
    keyPoints: [
      'Dirsek kemikleri farz olan yıkama alanına kesinlikle dahildir.',
      'Parmak araları ve parmaktaki yüzüklerin altı ıslatılmalıdır.',
      'Suyu parmak ucundan dirseğe doğru akıtmak esastır.',
    ],
    fullContent: 'Mâide Sûresi 6. âyetinde geçen: "...ve dirseklere kadar ellerinizi yıkayın" emri mucibince, eller ve kollar dirseklerle beraber yıkanır. Âyetteki "ilâ" (kadar) edatı, fakihlerin cumhuruna göre gaye bildirir ve dirseklerin de yıkanmasının farz olduğunu gösterir.\n\n'
        'Abdestin başında eller yıkanmış olsa bile, sıra kollara geldiğinde parmak uçlarından dirseklere kadar kolların tamamının yeniden yıkanması şarttır. Parmakta dar yüzük varsa suyun altına ulaşması için hareket ettirilmelidir.\n\n'
        'Tırnak altındaki hamur, boya gibi suyun deriye temasına engel olan tabakalar giderilmelidir.',
  ),
  FarzKnowledgeItem(
    id: 14,
    category: FarzCategory.abdest,
    orderInGroup: 3,
    title: 'Başın Dörtte Birini Meshetmek',
    term: 'Meshü\'r-re\'s',
    notificationSummary: 'Islak el içiyle başın en az dörtte birine (alın ve tepe bölgesine) bir defa meshetmek farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 197',
    keyPoints: [
      'Hanefi mezhebine göre başın en az 1/4\'ünü meshetmek farzdır.',
      'Elin ıslaklığının taze olması veya yeni su ile ıslatılması gerekir.',
      'Başın tamamını meshetmek (kaplama mesh) sünnettir.',
    ],
    fullContent: 'Mâide Sûresi 6. âyetinde: "...başlarınızı meshedin..." buyrulmuştur. Mesih; ıslak eli bir uzvun üzerine sürmek demektir. Hanefî mezhebine göre başın en az dörtte bir miktarını el ayasıyla meshetmek farzdır; başın tamamını meshetmek ise sünnettir.\n\n'
        'Şâfiî mezhebine göre birkaç tel saç dahi meshedilse farz yerine gelirken, Mâlikî ve Hanbelî mezheplerine göre başın tamamını meshetmek farzdır.\n\n'
        'Mesih için elin temiz ve ıslak olması lazımdır. Başka bir uzuvdan kalan ıslaklıkla mesih câiz olmaz; elin yeni bir su ile ıslatılması veya henüz yıkanmış kolun ıslaklığının değil, temiz suyun kullanılması esastır.',
  ),
  FarzKnowledgeItem(
    id: 15,
    category: FarzCategory.abdest,
    orderInGroup: 4,
    title: 'Ayakları Topuklarla Beraber Yıkamak',
    term: 'Guslü\'r-ricleyn',
    notificationSummary: 'Her iki ayağı, aşık kemikleri (topuklar) dahil olmak üzere parmak aralarından başlayarak tamamen yıkamak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 197-198',
    keyPoints: [
      'Topuk kemikleri (aşık kemikleri) yıkama sınırına dahildir.',
      'Parmak araları (hilalleme) ihmal edilmemelidir.',
      'Topukların arkasındaki çatlak veya kuru yerler ıslanmalıdır.',
    ],
    fullContent: 'Abdestin dördüncü farzı, ayakların aşık kemikleriyle (iki yandaki çıkıntılı topuk kemikleri) birlikte yıkanmasıdır. Resûl-i Ekrem (s.a.v.) abdest alırken topuklarında kuru yer kalanları görünce: "Vay o topukların cehennemdeki haline!" (Buhârî, Vudû\' 27) buyurarak bu uzvun titizlikle yıkanmasını emretmiştir.\n\n'
        'Ayaklar yıkanırken parmak uçlarından başlanır, sol elin serçe parmağıyla parmak araları hilallenir ve topukların arkasındaki kıvrımların ıslandığından emin olunur.\n\n'
        'Eğer meşru şartları taşıyan mest giyilmişse, ayakları yıkamak yerine mestlerin üzerini meshetmek sünnet ile sabit olan ruhsattır.',
  ),

  // ==========================================
  // IV. GUSLÜN FARZLARI (3 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 16,
    category: FarzCategory.gusul,
    orderInGroup: 1,
    title: 'Ağza Dolu Dolu Su Vermek',
    term: 'Mazmaza',
    notificationSummary: 'Gusülde ağza bolca su alıp boğazın girişine kadar çalkalayarak bütün ağız içini temizlemek farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 206-207',
    keyPoints: [
      'Hanefi ve Hanbelilere göre gusülde ağzın içini yıkamak farzdır.',
      'Oruçlu olunmadığında boğaza kadar gargara yapmak sünnettir.',
      'Diş aralarındaki yemek artıklarının altı ıslatılmalıdır.',
    ],
    fullContent: 'Gusül (boy abdesti), hükmî kirlilik olan cünüplük, hayız ve nifas hallerinden temizlenmek için bütün bedenin yıkanmasıdır. Hanefî mezhebine göre ağız içi bedenin dışından sayıldığı için gusülde ağza su vermek farzdır.\n\n'
        'Mazmaza; ağza su alıp boğaz ve damak çeperlerine kadar iyice çalkalamaktır. Oruçlu olmayan kimsenin boğazına doğru su ile gargara yapması müstehaptır; oruçlu ise suyun kaçmamasına dikkat eder.\n\n'
        'Diş dolgusu ve kaplamalar, suyun geçmesine engel teşkil etmez; zira bunlar tedavi amacıyla yapılmış olup zaruret hükmündedir ve gusle mani değildir.',
  ),
  FarzKnowledgeItem(
    id: 17,
    category: FarzCategory.gusul,
    orderInGroup: 2,
    title: 'Burna Su Çekip Genze Ulaştırmak',
    term: 'İstinsak',
    notificationSummary: 'Gusülde burna genze kadar su çekip sümkürerek burun boşluğundaki kuru yerleri yıkamak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 206-207',
    keyPoints: [
      'Burnun yumuşak kemik kısmına ve genze kadar su ulaştırılır.',
      'Burun içindeki kuru ifrazat temizlenmelidir.',
      'Sol elle sümkürülerek temizlik tamamlanır.',
    ],
    fullContent: 'Guslün ikinci farzı istinsaktır. Hanefî fakihlerine göre burun boşluğu da bedenin dış yüzeyi hükmünde kabul edildiğinden, gusül esnasında burna su çekilip genze kadar ulaştırılması farzdır.\n\n'
        'Su sağ el ile çekilir ve sol el ile sümkürülerek burun içindeki kurumuş kir ve mukus tabakaları temizlenir. Böylece suyun burun mukozasına ve kılların diplerine temas etmesi sağlanır.\n\n'
        'Oruçlu olmayan kimse suyu biraz daha derin çekerek genzini yıkar; oruçlu olan kimse ise boğazına su kaçmaması için aşırıya kaçmaz.',
  ),
  FarzKnowledgeItem(
    id: 18,
    category: FarzCategory.gusul,
    orderInGroup: 3,
    title: 'Bütün Bedeni Kuru Yer Kalmayacak Şekilde Yıkamak',
    term: 'Tathîru cemî\'i\'l-beden',
    notificationSummary: 'Tepeden tırnağa bütün vücudu, saç dipleri ve göbek çukuru dahil tek bir kuru nokta bırakmadan yıkamak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 206-208',
    keyPoints: [
      'Göbek çukuru, küpe delikleri, tırnak altları ıslatılmalıdır.',
      'Erkeklerin saç dipleri; kadınların örgüsüz saçları tamamen yıkanır.',
      'Vücutta iğne ucu kadar kuru yer kalmamalıdır.',
    ],
    fullContent: 'Guslün üçüncü ve en kapsamlı farzı, bedenin her tarafını yıkamaktır. Mâide Sûresi 6. âyetinde: "Eğer cünüp iseniz iyice temizlenin (boy abdesti alın)" buyrulmuştur.\n\n'
        'Saç, sakal, bıyık ve kaşların diplerine suyun mutlaka ulaşması gerekir. Kadınların saçları örgülü ise örgüyü çözmeleri şart olmayıp sadece saç diplerine suyun ulaşması yeterlidir; ancak saç örgülü değilse tamamının yıkanması farzdır.\n\n'
        'Göbek deliği, kulak kıvrımları, küpe deliği ve parmak araları gibi girintili yerlere özenle su değdirilmelidir.',
  ),

  // ==========================================
  // V. TEYEMMÜMÜN FARZLARI (2 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 19,
    category: FarzCategory.teyemmum,
    orderInGroup: 1,
    title: 'Niyet Etmek',
    term: 'En-Niyyet',
    notificationSummary: 'Teyemmümde hadesten (abdestsizlik veya cünüplükten) temizlenmeye ve namaz kılmaya kalben niyet etmek farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 210-211',
    keyPoints: [
      'Su bulunamadığında veya kullanılamadığında teyemmüm meşrudur.',
      'Teyemmümde niyet, ibadeti sıradan toprak temasından ayıran farzdır.',
      'Niyet hem abdestsizlik hem de cünüplük için geçerli kılınır.',
    ],
    fullContent: 'Teyemmüm; suyun bulunmadığı veya suyu kullanmaya mani sıhhi/coğrafi bir engelin bulunduğu hallerde, temiz toprak veya toprak cinsinden bir maddeye elleri sürerek yüzü ve kolları meshetmektir.\n\n'
        'Teyemmümün birinci farzı niyettir. Abdestte niyet Hanefîlere göre sünnet iken, teyemmümde bütün mezheplere göre kesin farzdır. Zira toprak bizzat temizleyici olmayıp, ancak niyet ve ibadet kastıyla temizlik vasıtası kılınmıştır.\n\n'
        'Kişi kalben: "Niyet ettim Allah rızası için hadesi gidermeye / namaz kılmayı mubah kılacak teyemmümü almaya" diye niyet eder.',
  ),
  FarzKnowledgeItem(
    id: 20,
    category: FarzCategory.teyemmum,
    orderInGroup: 2,
    title: 'İki Darp ve Mesih',
    term: 'Ed-Darbâni ve\'l-mesh',
    notificationSummary: 'Elleri temiz toprağa vurup yüzü, ikinci vuruşta ise kolları dirseklerle beraber meshetmek farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 211-213',
    keyPoints: [
      'İlk vuruşta el ayalarıyla yüzün tamamı meshedilir.',
      'İkinci vuruşta kollar dirseklere kadar meshedilir.',
      'Toprak tozunun yüze yapışması şart değildir, hafifçe silkelenir.',
    ],
    fullContent: 'Mâide Sûresi 6. âyetinde: "Temiz bir toprağa yönelin de onunla yüzlerinizi ve ellerinizi meshedin" buyrulmuştur.\n\n'
        'Teyemmümün ikinci farzı iki darptır (iki defa elleri vurup meshetmektir): Temiz eller parmaklar açık vaziyette temiz toprağa veya taş/kiremit cinsinden bir maddeye vurulur, ileri-geri hareket ettirilir, kaldırılıp birbirine hafifçe vurularak tozu silkelenir ve bütün yüz meshedilir.\n\n'
        'İkinci defa eller aynı şekilde toprağa vurulur; sol elin içiyle sağ kol parmak ucundan dirseğe kadar, sağ elin içiyle de sol kol dirseğe kadar meshedilerek teyemmüm tamamlanır.',
  ),

  // ==========================================
  // VI. NAMAZIN ŞARTLARI (DIŞINDAKİ 6 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 21,
    category: FarzCategory.namazSart,
    orderInGroup: 1,
    title: 'Hadesten Tahâret',
    term: 'Tahâretü\'l-hades',
    notificationSummary: 'Namazdan önce abdestsiz ise abdest almak, boy abdesti gerekiyorsa gusletmek, su yoksa teyemmüm etmektir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 227-228',
    keyPoints: [
      'Hükmî kirlilikten (küçük ve büyük hades) arınmaktır.',
      'Abdest ve gusül namazın sıhhatinin vazgeçilmez şartıdır.',
      'Abdestsiz kılınan hiçbir namaz makbul değildir.',
    ],
    fullContent: 'Hades; abdestsizlik veya cünüplük sebebiyle insanda meydana geldiği varsayılan hükmî kirliliktir. Hadesten tahâret; namaza başlamadan evvel küçük hadesten kurtulmak için abdest almak, büyük hadesten kurtulmak için ise gusül yapmaktır.\n\n'
        'Resûl-i Ekrem (s.a.v.): "Allah, hades vaki olan (abdesti bozulan) hiçbirinizin abdest almadıkça namazını kabul etmez" (Buhârî, Vudû\' 2) buyurmuştur.\n\n'
        'Su bulamayan veya hastalık sebebiyle su kullanamayan kimse ise hadesten teyemmüm ederek temizlenir.',
  ),
  FarzKnowledgeItem(
    id: 22,
    category: FarzCategory.namazSart,
    orderInGroup: 2,
    title: 'Necâsetten Tahâret',
    term: 'Tahâretü\'n-necâse',
    notificationSummary: 'Namaz kılacak kimsenin bedeninde, elbisesinde ve namaz kılacağı yerde dinen pis sayılan maddelerin temizlenmesidir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 229',
    keyPoints: [
      'Beden, giysi ve secde edilecek mekân temiz olmalıdır.',
      'Necâset-i galîza (ağır pislik) af miktarından fazla olmamalıdır.',
      'Müddesir Sûresi 4. âyeti: "Elbiseni tertemiz tut" emrini verir.',
    ],
    fullContent: 'Necâsetten tahâret; namaz kılanın vücudunda, üzerinde bulunan elbisede ve secde edeceği zeminde fıkhen pis kabul edilen maddelerin (kan, idrar, şarap, dışkı vb.) bulunmamasıdır.\n\n'
        'İslâm fıkhında necasetler hafif (hafîfe) ve ağır (galîza) olmak üzere ikiye ayrılır. Ağır necaset katı ise bir dirhem (yaklaşık 3 gram), sıvı ise el ayası kadar bir alanı aşarsa namazın sıhhatine engeldir.\n\n'
        'Mümin, ilahî huzura çıkarken maddi olarak en temiz ve pak kıyafetleriyle durmalıdır.',
  ),
  FarzKnowledgeItem(
    id: 23,
    category: FarzCategory.namazSart,
    orderInGroup: 3,
    title: 'Setr-i Avret',
    term: 'Setrü\'l-avret',
    notificationSummary: 'Namazda örtülmesi dinen farz kılınan avret mahallerini şeffaf olmayan temiz bir giysiyle örtmektir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 229-231',
    keyPoints: [
      'Erkeklerde göbek ile diz kapağı arası (diz kapağı dahil) örtülür.',
      'Kadınlarda yüz, eller ve ayaklar hariç bütün beden avrettir.',
      'Giysinin altındaki ten rengini göstermeyecek kalınlıkta olması şarttır.',
    ],
    fullContent: 'Setr-i avret; başkalarının bakması haram olan ve ibadette örtülmesi emredilen uzuvların örtülmesidir. A\'râf Sûresi 31. âyetinde: "Ey Âdemoğulları! Her mescitte (namaz kılarken) ziynetinizi takının (temiz ve güzel elbiselerinizi giyin)" buyrulmuştur.\n\n'
        'Hanefî mezhebine göre erkeklerin avret yeri göbekten diz kapağının altına kadardır (diz kapağı avrettir). Hür kadınların avret yeri ise el, yüz ve Hanefîlerde tercih edilen görüşe göre ayaklar hariç bütün bedenidir.\n\n'
        'Namaz esnasında avret yerlerinden birinin dörtte biri kendi kendine açılır ve bir rükün eda edecek kadar açık kalırsa namaz bozulur.',
  ),
  FarzKnowledgeItem(
    id: 24,
    category: FarzCategory.namazSart,
    orderInGroup: 4,
    title: 'İstikbâl-i Kıble',
    term: 'İstikbâlü\'l-kıble',
    notificationSummary: 'Namazı Mekke\'deki Kâbe-i Muazzama cihetine yönelerek kılmaktır. Kıbleyi bilmeyen araştırma (taharri) yapar.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 231-233',
    keyPoints: [
      'Mekke dışındakiler Kâbe istikametine yönelir.',
      'Yön bilinmiyorsa araştırma ve tespit (taharri) farzdır.',
      'Namazda göğsün kıbleden çevrilmesi namazı iptal eder.',
    ],
    fullContent: 'İstikbâl-i kıble; namaz kılarken Müslümanların kıblesi olan Kâbe yönüne dönmektir. Bakara Sûresi 144. âyetinde: "Yüzünü Mescid-i Harâm tarafına çevir. Nerede olursanız olun yüzlerinizi o yöne çevirin" buyrulmuştur.\n\n'
        'Mekke\'de olup Kâbe\'yi görenler bizzat Kâbe\'nin kendisine, uzakta olanlar ise Kâbe cihetine yönelirler. Kıblenin nerede olduğunu bilmeyen ve soracak kimse bulamayan kimse pusula, güneş, yıldızlar gibi alametlerle araştırma (taharri) yapar ve kanaat getirdiği yöne doğru namazını kılar.\n\n'
        'Namaz esnasında göğsünü kıbleden çeviren kimsenin namazı bozulur.',
  ),
  FarzKnowledgeItem(
    id: 25,
    category: FarzCategory.namazSart,
    orderInGroup: 5,
    title: 'Vakit',
    term: 'El-Vakt',
    notificationSummary: 'Kılınacak namazın dinen belirlenen meşru vaktinin girmiş olması ve namazın bu vakit içinde eda edilmesidir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 233-238',
    keyPoints: [
      'Vakti girmeden kılınan namaz farz yerine geçmez, geçersizdir.',
      'Nisâ Sûresi 103. âyeti namazın vakitli bir farz olduğunu bildirir.',
      'Her namazı vaktin ilk dilimlerinde kılmak en faziletli ameldir.',
    ],
    fullContent: 'Namazın şartlarından biri de vakittir. Kılınacak farz veya vacip namazın vaktinin girmiş olması şarttır; vakti girmeden kılınan farz namaz geçerli olmaz. Vakti çıktıktan sonra kılınan namaz ise edâ değil, kazâ hükmündedir.\n\n'
        'Kur\'an\'da: "Şüphesiz namaz müminler üzerine vakitleri belirli bir farzdır" (en-Nisâ 4/103) buyrulmuştur. Beş vakit namazın ilk ve son sınırları Cebrail (a.s.) tarafından Hz. Peygamber\'e bizzat namaz kıldırılarak öğretilmiştir.\n\n'
        'Müstehap olan, namazı vakti girdikten sonra geciktirmeden eda etmektir.',
  ),
  FarzKnowledgeItem(
    id: 26,
    category: FarzCategory.namazSart,
    orderInGroup: 6,
    title: 'Niyet',
    term: 'En-Niyyet',
    notificationSummary: 'Hangi vaktin ve hangi namazın kılınacağını kalben bilmek, kastetmek ve ihlasla Allah rızasına yönelmektir.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 238-240',
    keyPoints: [
      'Niyetin asıl mahalli kalptir; dille söylemek müstehaptır.',
      'Farz namazlarda vaktin ve farzın tayin edilmesi (belirlenmesi) şarttır.',
      'Cemaatle namazda imama uymaya niyet etmek de farzdır.',
    ],
    fullContent: 'Namazın dışındaki şartların sonuncusu niyettir. Niyet; kalbin bir şeye azmetmesi, hangi ameli ne için yaptığının şuurunda olmasıdır. Âdet ile ibadeti birbirinden ayıran temel unsur niyettir.\n\n'
        'Resûlullah (s.a.v.): "Ameller ancak niyetlere göredir ve herkese niyet ettiği şey vardır" (Buhârî, Bed\'ü\'l-vahy, 1) buyurmuştur. Farz namazlarda kılınacak namazın (mesela "Bugünkü öğle namazının farzına") tayin edilmesi şarttır.\n\n'
        'Niyetin kalple yapılması farz, kalp ile birlikte dil ile de telaffuz edilmesi Hanefîlerde müstehap kabul edilmiştir. Niyet tekbire yakın olmalı, araya dünya kelamı veya işi girmemelidir.',
  ),

  // ==========================================
  // VII. NAMAZIN RÜKÜNLERİ (İÇİNDEKİ 6 FARZ)
  // ==========================================
  FarzKnowledgeItem(
    id: 27,
    category: FarzCategory.namazRukun,
    orderInGroup: 1,
    title: 'İftitah Tekbiri',
    term: 'Tahrîme / Tekbîretü\'l-iftitâh',
    notificationSummary: 'Namaza başlarken "Allahu Ekber" demek farzdır. Bu tekbirle namaza aykırı dünyevi fiiller haram kılınır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 240-241',
    keyPoints: [
      'Namazın ilk rüknüdür ve tahrime adını alır.',
      'Kişi kendi duyacağı kadar bir sesle tekbiri telaffuz etmelidir.',
      'Tekbir ayaktayken alınır, rükûya eğilirken alınamaz.',
    ],
    fullContent: 'İftitah; "başlamak, kapıyı açıp girmek" demektir. İftitah tekbiri ise namaza başlarken alınan ilk tekbir olup "Allahu Ekber" lafzıyla söylenir. Bu tekbire "Tahrîme" de denir; zira bu tekbirle birlikte namaz dışındaki yeme, içme, konuşma gibi fiiller kula haram kılınır.\n\n'
        'Kur\'ân-ı Kerîm\'de: "Rabbinin adını anıp namaz kılan kimse kurtulmuştur" (el-A\'lâ 87/15) ve "Rabbini tekbir ile yücelt" (el-Müddessir 74/3) buyrulmuştur.\n\n'
        'İftitah tekbiri alırken kişinin kendi kulağının işitebileceği bir sesle telaffuz etmesi şarttır. İmama uyan kimse tekbiri imamdan önce veya rükûya giderken değil, tam ayakta iken almalıdır.',
  ),
  FarzKnowledgeItem(
    id: 28,
    category: FarzCategory.namazRukun,
    orderInGroup: 2,
    title: 'Kıyam',
    term: 'El-Kıyâm',
    notificationSummary: 'Gücü yeten kimsenin farz ve vacip namazları ayakta kılması farzdır. Ayakta duramayan oturarak kılar.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 241-242',
    keyPoints: [
      'Farz ve vitir namazlarında kıyam kesin farzdır.',
      'Hastalık veya ayakta duramayacak acziyet halinde oturarak kılınabilir.',
      'Kıyamda sağ el sol elin üzerine bağlanır.',
    ],
    fullContent: 'Kıyam; namazda ayakta durmak demektir. Farz ve vacip namazlarda kıyam bir rükün olup farzdır. Bakara Sûresi 238. âyetinde: "...Allah\'ın divanına tam bir saygıyla ayakta durun" buyrulmuştur.\n\n'
        'Sağlığı elveren kimsenin farz namazı oturarak kılması caiz değildir. Ancak ayakta duramayacak kadar hasta olan, baş dönmesi veya şiddetli ağrısı bulunan kimse oturarak kılar; rükû ve secdeleri ima ile yapar. İslâm\'da "Güçlük kaldırılmıştır" kuralı caridir.\n\n'
        'Kıyam esnasında gözlerin secde mahalline bakması ve huşu içinde durulması namazın edebindendir.',
  ),
  FarzKnowledgeItem(
    id: 29,
    category: FarzCategory.namazRukun,
    orderInGroup: 3,
    title: 'Kıraat',
    term: 'El-Kırâat',
    notificationSummary: 'Namazın kıyamında Kur\'an\'dan en az kısa bir sure veya üç kısa âyet miktarı okumak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 242-246',
    keyPoints: [
      'Müzemmil Sûresi 20. âyeti: "Kur\'an\'dan kolayınıza geleni okuyun" buyurur.',
      'Fâtiha Sûresi\'ni okumak Hanefîlerde vacip, cumhura göre farzdır.',
      'Kıraat ancak kişinin kendi kulağıyla duyabileceği fısıltıyla muteber olur.',
    ],
    fullContent: 'Kıraat; namazda Kur\'ân-ı Kerîm\'den âyet okumaktır. Müzemmil Sûresi 20. âyetinde: "Artık Kur\'an\'dan kolayınıza geleni okuyun" buyrulmuştur. Farz olan asgari kıraat miktarı; bir uzun âyet veya en az üç kısa âyettir.\n\n'
        'Hanefî mezhebine göre farz namazların ilk iki rekatında kıraat farzdır; Fâtiha okumak ve ardından zamm-ı sûre ilave etmek ise vaciptir. Şâfiî ve diğer üç mezhebe göre ise her rekatta Fâtiha okumak namazın farz rüknüdür.\n\n'
        'Kıraatin geçerli olması için harflerin mahrecinden doğru çıkarılması ve en az kılan kimsenin kendisi işitebileceği derecede diliyle telaffuz edilmesi şarttır; içten geçirmek kıraat sayılmaz.',
  ),
  FarzKnowledgeItem(
    id: 30,
    category: FarzCategory.namazRukun,
    orderInGroup: 4,
    title: 'Rükû',
    term: 'Er-Rükû\'',
    notificationSummary: 'Kıraatten sonra elleri diz kapaklarına koyup sırtı düz tutarak eğilmek ve en az bir tesbih miktarı durmaktır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 246-247',
    keyPoints: [
      'Hacc Sûresi 77. âyeti: "Ey iman edenler, rükû edin ve secdeye varın" emrini verir.',
      'Sırtın düz ve başın sırt hizasında tutulması sünnettir.',
      'Rükûda en az üç defa "Sübhâne Rabbiye\'l-Azîm" denir.',
    ],
    fullContent: 'Rükû; lügatte eğilmek demektir. Fıkıhta ise kıyamdan sonra elleri dizlere dayayarak baş ve sırt düz bir çizgi oluşturacak şekilde öne doğru eğilmektir. Kur\'an\'da: "Ey iman edenler! Rükû edin, secde edin..." (el-Hac 22/77) buyrulmuştur.\n\n'
        'Asgari rükû derecesi, ellerin dizlere erişebileceği kadar eğilmektir; kâmil rükû ise baş ile kalça aynı hizada dümdüz olacak şekilde eğilmektir. Kadınlar erkekler kadar tamamen düzleşmeyip biraz daha az eğilirler.\n\n'
        'Rükûda en az üç kere "Sübhâne Rabbiye\'l-Azîm" (Pek yüce olan Rabbimi tenzih ederim) denir. Rükûdan doğrulurken "Semiallâhu limen hamideh", tam doğrulunca "Rabbenâ leke\'l-hamd" denir ve vücut sükûn buluncaya kadar ayakta dik durmak (kavme / ta\'dîl-i erkân) vaciptir.',
  ),
  FarzKnowledgeItem(
    id: 31,
    category: FarzCategory.namazRukun,
    orderInGroup: 5,
    title: 'Secde',
    term: 'Es-Sücûd',
    notificationSummary: 'Her rekatta ikişer defa alın, burun, el ayaları, dizler ve ayak parmaklarını yere koyarak secdeye varmak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 247-250',
    keyPoints: [
      'Kulun Allah\'a en yakın olduğu an secde anıdır.',
      'Her rekatta peş peşe iki secde yapılır.',
      'Secdede en az üç defa "Sübhâne Rabbiye\'l-A\'lâ" denir.',
    ],
    fullContent: 'Secde; tevazu ve teslimiyetin zirvesi olarak alın, burun, eller, dizler ve ayak parmaklarını yere koyup kapanmaktır. Her rekatta iki defa secde etmek farzdır.\n\n'
        'Resûl-i Ekrem (s.a.v.): "Ben yedi uzuv üzerine secde etmekle emrolundum: Alın (eliyle burnuna da işaret etti), iki el, iki diz ve iki ayağın parmak uçları" (Buhârî, Ezân 133) buyurmuştur. Secdede burnu alınla birlikte yere koymak vaciptir.\n\n'
        'Secdede en az üç kere "Sübhâne Rabbiye\'l-A\'lâ" (En yüce olan Rabbimi tenzih ederim) tesbihi söylenir. İki secde arasında bir kere tesbih diyecek kadar oturup sükûn bulmak (celse) ta\'dîl-i erkânın bir parçasıdır.',
  ),
  FarzKnowledgeItem(
    id: 32,
    category: FarzCategory.namazRukun,
    orderInGroup: 6,
    title: 'Ka\'de-i Ahîre (Son Oturuş)',
    term: 'El-Ka\'detü\'l-ahîre',
    notificationSummary: 'Namazın son rekatında "Ettehiyyâtü" duasını okuyacak kadar bir süre oturmak farzdır.',
    sourceCitation: 'Diyanet İşleri Başkanlığı İlmihali, Cilt 1, s. 250-252',
    keyPoints: [
      'Namazın son rüknüdür.',
      'Teşehhüd miktarı (Ettehiyyâtü okuyacak kadar) oturmak farzdır.',
      'Ettehiyyâtü\'yü okumak vacip; Salli-Barik ve Rabbena duaları sünnettir.',
    ],
    fullContent: 'Ka\'de-i ahîre; iki rekatlı namazların ikinci, üç rekatlıların üçüncü, dört rekatlıların dördüncü rekatındaki son oturuştur. Bu oturuşta teşehhüd miktarı, yani "Ettehiyyâtü" duasını okuyacak kadar bir zaman oturup beklemek namazın farz olan rükünlerindendir.\n\n'
        'Hz. Peygamber (s.a.v.) İbn Mes\'ûd\'a (r.a.) teşehhüdü öğrettikten sonra: "Bunu söylediğin veya bu miktarı yerine getirdiğin vakit namazın tamamlanmış olur" (Ebû Dâvûd, Salât, 178) buyurmuştur.\n\n'
        'Bu oturuşta Ettehiyyâtü\'yü okumak vaciptir; ardından Salli-Bârik salavatları ile Rabbenâ dualarını okumak sünnettir. Dualar bittikten sonra önce sağa sonra sola selam verilerek namaz kemale erdirilir.',
  ),
];
