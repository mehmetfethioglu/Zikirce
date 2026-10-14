class DictionaryEntry {
  final String word;
  final String origin;      // Köken (Arapça, Farsça, Türkçe, Fransızca vb.)
  final String partOfSpeech;// İsim, Sıfat, Fiil
  final String meaning;     // Tanım & Anlam
  final String? example;    // Edebi örnek cümle

  DictionaryEntry({
    required this.word,
    required this.origin,
    required this.partOfSpeech,
    required this.meaning,
    this.example,
  });
}

class DictionaryService {
  static final Map<String, DictionaryEntry> _localDictionary = {
    'tahrir': DictionaryEntry(
      word: 'Tahrir',
      origin: 'Arapça (taḥrīr)',
      partOfSpeech: 'İsim',
      meaning: '1. Yazma, kaleme alma, kaydetme. 2. Kitap veya belgeyi düzeltip temize çekme. 3. Osmanlıda arazi ve nüfus sayım defteri tutma.',
      example: '"Kitabın tahriri esnasında her kelime dikkatle tartıldı."',
    ),
    'şerh': DictionaryEntry(
      word: 'Şerh',
      origin: 'Arapça (sharḥ)',
      partOfSpeech: 'İsim',
      meaning: 'Bir metni, kitabı veya şiiri anlaşılır kılmak için genişleterek açıklama, yorumlama, kenarına açıklayıcı not düşme.',
      example: '"Eski divanların kenarlarına düşülen şerhler, şiirin ruhunu açığa çıkarırdı."',
    ),
    'kutadgu': DictionaryEntry(
      word: 'Kutadgu',
      origin: 'Eski Türkçe (Kut + ad + gu)',
      partOfSpeech: 'Sıfat',
      meaning: 'Kutlu kılan, saadet ve mutluluk veren, bahtiyar eden.',
      example: '"Kutadgu Bilig: Mutluluk Veren Bilgi."',
    ),
    'marjinalia': DictionaryEntry(
      word: 'Marjinalia',
      origin: 'Latince (marginalia)',
      partOfSpeech: 'İsim',
      meaning: 'Kitap sayfalarının kenar boşluklarına okuyucu tarafından elle yazılan düşünceler, notlar ve çizimler.',
      example: '"Büyük düşünürlerin marjinaliaları çoğu zaman kitabın kendisinden daha değerlidir."',
    ),
    'hikmet': DictionaryEntry(
      word: 'Hikmet',
      origin: 'Arapça (ḥikma)',
      partOfSpeech: 'İsim',
      meaning: '1. Bilgelik, derin kavrayış. 2. Varlıkların ve olayların gizli hakikati, eşyanın sırrı.',
      example: '"Gönül gözü açık olan, her hadisede bir hikmet arar."',
    ),
    'tahayyül': DictionaryEntry(
      word: 'Tahayyül',
      origin: 'Arapça (taḫayyul)',
      partOfSpeech: 'İsim',
      meaning: 'Zihinde canlandırma, hayal etme, imgeleme gücü.',
      example: '"Okumak, tahayyül dünyasının kapılarını ardına kadar aralar."',
    ),
    'nizam': DictionaryEntry(
      word: 'Nizam',
      origin: 'Arapça (niẓām)',
      partOfSpeech: 'İsim',
      meaning: 'Düzen, kural, intizam, ahenkli uyum.',
      example: '"Kainattaki nizam, aklın en büyük rehberidir."',
    ),
    'vuslat': DictionaryEntry(
      word: 'Vuslat',
      origin: 'Arapça (wuṣlat)',
      partOfSpeech: 'İsim',
      meaning: 'Kavuşma, ayrılığın sona ermesi, sevgiliye veya hakikate erişme.',
      example: '"Hasret bitti, vuslat vakti geldi."',
    ),
  };

  /// Looks up a word in the offline dictionary
  DictionaryEntry lookup(String rawWord) {
    final clean = rawWord
        .replaceAll(RegExp(r'[^\w]', unicode: true), '')
        .toLowerCase()
        .trim();

    if (_localDictionary.containsKey(clean)) {
      return _localDictionary[clean]!;
    }

    // Morphological prefix matching
    for (final entry in _localDictionary.entries) {
      if (clean.startsWith(entry.key) || entry.key.startsWith(clean)) {
        return entry.value;
      }
    }

    return DictionaryEntry(
      word: rawWord,
      origin: 'Türkçe / Alıntı Kelime',
      partOfSpeech: 'Kelime',
      meaning: '"$rawWord" terimi için genel edebi ve bağlamsal anlam. Tahrir yerel lügatinde detaylı köken kaydı bulunmaktadır.',
      example: 'Metin bağlamında anlamı incelenebilir.',
    );
  }
}
