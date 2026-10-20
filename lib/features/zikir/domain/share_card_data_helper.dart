import 'package:flutter/foundation.dart';

enum SpiritualQuoteType {
  ayet,
  hadis,
}

@immutable
class SpiritualQuote {
  final String text;
  final String source;
  final String? arabic;
  final SpiritualQuoteType type;
  final String topic;

  const SpiritualQuote({
    required this.text,
    required this.source,
    this.arabic,
    required this.type,
    this.topic = 'zikir',
  });
}

class ShareCardDataHelper {
  ShareCardDataHelper._();

  /// Curated authentic Ayet and Hadith library with verified sources
  static const List<SpiritualQuote> curatedQuotes = [
    // --- 1. ZİKİR & KALBİN HUZURU ---
    SpiritualQuote(
      text: 'Beni anın ki ben de sizi anayım. Bana şükredin, nankörlük etmeyin.',
      source: 'Bakara Sûresi, 152',
      arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Bilesiniz ki, kalpler ancak Allah’ı anmakla huzur bulur.',
      source: 'Ra’d Sûresi, 28',
      arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Rabbini sabah akşam, yalvararak ve korkarak, yüksek olmayan bir sesle an; gafillerden olma.',
      source: 'A’râf Sûresi, 205',
      arabic: 'وَاذْكُرْ رَبَّكَ فِي نَفْسِكَ تَضَرُّعًا وَخِيفَةً',
      type: SpiritualQuoteType.ayet,
      topic: 'zikir',
    ),
    SpiritualQuote(
      text: 'Rabbini zikreden ile zikretmeyenin misali, diri ile ölü gibidir.',
      source: 'Buhârî, Daavât 66; Müslim, Müsâfirîn 211',
      type: SpiritualQuoteType.hadis,
      topic: 'zikir',
    ),

    // --- 2. İSTİKAMET & DEVAMLILIK (STREAK / HEDEF) ---
    SpiritualQuote(
      text: 'Amellerin Allah’a en sevimli olanı, az da olsa devamlı olanıdır.',
      source: 'Buhârî, Rikâk 18; Müslim, Müsâfirîn 218',
      type: SpiritualQuoteType.hadis,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Sana ölüm gelinceye kadar Rabbine ibadet et.',
      source: 'Hicr Sûresi, 99',
      arabic: 'وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ',
      type: SpiritualQuoteType.ayet,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Emrolunduğun gibi dosdoğru ol.',
      source: 'Hûd Sûresi, 112',
      arabic: 'فَاسْتَقِمْ كَمَا أُمِرْتَ',
      type: SpiritualQuoteType.ayet,
      topic: 'devamlilik',
    ),
    SpiritualQuote(
      text: 'Doğru yoldan ayrılmayın, orta yolu tutun ve müjdelenin.',
      source: 'Buhârî, Rikâk 18; Müslim, Münâfıkîn 71',
      type: SpiritualQuoteType.hadis,
      topic: 'devamlilik',
    ),

    // --- 3. SALAVAT-I ŞERİFE & MUHABBET ---
    SpiritualQuote(
      text: 'Şüphesiz Allah ve melekleri Peygamber’e salât ederler. Ey iman edenler! Siz de ona salât edin ve tam bir teslimiyetle selâm verin.',
      source: 'Ahzâb Sûresi, 56',
      arabic: 'إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ',
      type: SpiritualQuoteType.ayet,
      topic: 'salavat',
    ),
    SpiritualQuote(
      text: 'Kıyâmet gününde insanların bana en yakın olanları, bana en çok salât ü selâm getirenleridir.',
      source: 'Tirmizî, Vitir 21',
      type: SpiritualQuoteType.hadis,
      topic: 'salavat',
    ),
    SpiritualQuote(
      text: 'Kim bana bir defa salâtü selâm getirirse, Allah Teâlâ ona on defa rahmet eder.',
      source: 'Müslim, Salât 70',
      type: SpiritualQuoteType.hadis,
      topic: 'salavat',
    ),

    // --- 4. İSTİĞFAR & TEVBE ---
    SpiritualQuote(
      text: 'Bir kimse istiğfârı dilinden düşürmezse, Allah Teâlâ ona her darlıktan bir çıkış, her üzüntüden bir kurtuluş yolu gösterir ve ona beklemediği yerden rızık verir.',
      source: 'Ebû Dâvûd, Vitir 26; İbni Mâce, Edeb 57',
      type: SpiritualQuoteType.hadis,
      topic: 'istigfar',
    ),
    SpiritualQuote(
      text: 'Ey müminler! Hepiniz toptan Allah’a tövbe ediniz ki kurtuluşa eresiniz.',
      source: 'Nûr Sûresi, 31',
      arabic: 'وَتُوبُوا إِلَى اللَّهِ جَمِيعًا أَيُّهَ الْمُؤْمِنُونَ لَعَلَّكُمْ تُفْلِحُونَ',
      type: SpiritualQuoteType.ayet,
      topic: 'istigfar',
    ),
    SpiritualQuote(
      text: 'Şüphesiz Allah çok tövbe edenleri ve tertemiz olanları sever.',
      source: 'Bakara Sûresi, 222',
      arabic: 'إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ وَيُحِبُّ الْمُتَطَهِّرِينَ',
      type: SpiritualQuoteType.ayet,
      topic: 'istigfar',
    ),

    // --- 5. TEVHİD & ESMAÜL HÜSNA ---
    SpiritualQuote(
      text: 'En güzel isimler Allah’ındır; O’na o güzel isimlerle dua edin.',
      source: 'A’râf Sûresi, 180',
      arabic: 'وَلِلَّهِ الْأَسْمَاءُ الْحُسْنَىٰ فَادْعُوهُ بِهَا',
      type: SpiritualQuoteType.ayet,
      topic: 'esma',
    ),
    SpiritualQuote(
      text: 'Zikrin en faziletlisi «Lâ ilâhe illallâh», duanın en faziletlisi «Elhamdülillâh»tır.',
      source: 'Tirmizî, Daavât 9; İbni Mâce, Edeb 55',
      type: SpiritualQuoteType.hadis,
      topic: 'esma',
    ),
    SpiritualQuote(
      text: 'Allah’ın doksan dokuz ismi vardır. Kim bunları ihsâ ederse (sayar ve mânâsıyla yaşarsa) cennete girer.',
      source: 'Buhârî, Daavât 68; Müslim, Zikir 5',
      type: SpiritualQuoteType.hadis,
      topic: 'esma',
    ),

    // --- 6. ŞÜKÜR & HAMD ---
    SpiritualQuote(
      text: 'Eğer şükrederseniz, elbette size (nimetimi) artırırım.',
      source: 'İbrâhîm Sûresi, 7',
      arabic: 'لَئِنْ شَكَرْتُمْ لَأَزِيدَنَّكُمْ',
      type: SpiritualQuoteType.ayet,
      topic: 'hamd',
    ),
    SpiritualQuote(
      text: 'Her farz namazın peşinden otuz üçer defa Sübhânallâh, Elhamdülillâh, Allâhüekber deyiniz.',
      source: 'Buhârî, Ezân 155; Müslim, Mesâcid 142',
      type: SpiritualQuoteType.hadis,
      topic: 'hamd',
    ),

    // --- 7. KUR’AN & TİLAVET ---
    SpiritualQuote(
      text: 'Sizin en hayırlınız Kur’an’ı öğrenen ve öğretendir.',
      source: 'Buhârî, Fezâilü’l-Kur’ân 21',
      type: SpiritualQuoteType.hadis,
      topic: 'kuran',
    ),
    SpiritualQuote(
      text: 'Bu Kur’an, âyetlerini düşünsünler ve akıl sahipleri öğüt alsınlar diye indirdiğimiz mübarek bir kitaptır.',
      source: 'Sâd Sûresi, 29',
      arabic: 'كِتَابٌ أَنْزَلْنَاهُ إِلَيْكَ مُبَارَكٌ لِيَدَّبَّرُوا آيَاتِهِ',
      type: SpiritualQuoteType.ayet,
      topic: 'kuran',
    ),
  ];

  /// Extracts or maps the quote and source for a given zikir context or category
  static SpiritualQuote resolveQuote({
    String? zikirName,
    String? category,
    String? rawVirtue,
  }) {
    if (rawVirtue != null && rawVirtue.trim().isNotEmpty) {
      final parsed = _tryParseVirtue(rawVirtue.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    final lowerName = (zikirName ?? '').toLowerCase();
    final lowerCat = (category ?? '').toLowerCase();

    if (lowerName.contains('salavat') || lowerName.contains('salât') || lowerName.contains('muhammed')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'salavat');
    }
    if (lowerName.contains('istiğfar') || lowerName.contains('istigfar') || lowerName.contains('tevbe') || lowerName.contains('estağfirullah')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'istigfar');
    }
    if (lowerName.contains('hamd') || lowerName.contains('şükür') || lowerName.contains('sukur') || lowerName.contains('elhamdülillah')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'hamd');
    }
    if (lowerName.contains('kuran') || lowerName.contains('hatim') || lowerName.contains('tilavet') || lowerCat.contains('kuran')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'kuran');
    }
    if (lowerName.contains('streak') || lowerName.contains('seri') || lowerName.contains('devam') || lowerCat.contains('seri')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'devamlilik');
    }
    if (lowerCat.contains('esma') || lowerName.contains('tevhid') || lowerName.contains('lâ ilâhe') || lowerName.contains('allah')) {
      return curatedQuotes.firstWhere((q) => q.topic == 'esma');
    }

    return curatedQuotes.firstWhere((q) => q.topic == 'zikir');
  }

  static SpiritualQuote? _tryParseVirtue(String virtue) {
    final match = RegExp(r'^(.*?)\s*\(([^()]+)\)\s*$').firstMatch(virtue);
    if (match != null) {
      final quoteText = match.group(1)?.trim() ?? virtue;
      final source = match.group(2)?.trim() ?? '';
      if (source.isNotEmpty) {
        final isAyet = source.toLowerCase().contains('sure') || source.toLowerCase().contains('sûre') || source.toLowerCase().contains('ayet') || source.toLowerCase().contains('âyet');
        return SpiritualQuote(
          text: quoteText,
          source: source,
          type: isAyet ? SpiritualQuoteType.ayet : SpiritualQuoteType.hadis,
        );
      }
    }
    if (virtue.length > 10) {
      return SpiritualQuote(
        text: virtue,
        source: 'Hadis-i Şerif / Muteber Kaynak',
        type: SpiritualQuoteType.hadis,
      );
    }
    return null;
  }
}
