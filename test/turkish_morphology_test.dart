import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/features/reader/engine/turkish_morphology.dart';

void main() {
  group('TurkishMorphology — Zemberek tabanlı biçimbilim doğrulayıcısı', () {
    test('geçerli Türkçe kelimeleri (çekimli/yapım ekli) tanır', () {
      const valid = [
        'kırmızı', 'yapılanın', 'kullanılanın', 'anlatılanın', 'kitapları', 'kitabı',
        'evdekiler', 'güzelliği', 'kapılmaları', 'hükümdarlarının', 'politikayı',
        'kurtarır', 'kılık', 'din', 'geliyordu', 'başlıyor', 'gelmiyor', 'gelebilecek',
        'okuyucu', 'yanılmalardan', 'sebepleri', 'metodlarının', 'tarihçilerin',
        'öğretir', 'kavimlerin', 'ahlâklarını', 'hükümdarların', 'devletlerin',
        'durumunu', 'oldukları', 'edinir', 'faydalanır', 'kaynaklara', 'bilgilere',
        'dikkatle', 'incelemelere', 'gelinceye', 'muhtaçtır', 'saatleri', 'hali',
        'kalbi', 'ağzı', 'hakkı', 'onun', 'bunları', 'birinci', 'ikişer',
        'gördüğümüz', 'söyleyeceğim', 'yazılmıştır', 'anlaşılmaktadır', 'gerekir',
        'olmasaydı', 'gelmeden', 'okurken', 'Türkiye', 'İstanbul', 'Müslümanların',
        'bölümü', 'mukaddimesi', 'kimse', 'tarihe', 'başvurarak', 'kendisine',
        'kurumsallaşması', 'küreselleşmektedir', 'olmaksızın', 'süregelen',
        'geliverdi', 'idi', 'imiş', 'isem', 'iken',
      ];
      final failures = valid.where((w) => !TurkishMorphology.isKnownWord(w)).toList();
      expect(failures, isEmpty, reason: 'Tanınmayan geçerli kelimeler: $failures');
    });

    test('OCR bozulmalı (geçersiz) kelimeleri reddeder', () {
      const invalid = [
        'kaplmalan', 'hükümdarlanın', 'politikayn', 'kurtanr', 'kıhk', 'dın',
        'bölümu', 'mukaddimesı', 'zarnan', 'clünya', 'bercber', 'oldugu', 'hakıkat',
        'müslümanlarn', 'tarafmdan', 'düşmann', 'zamannda', 'kitapda', 'gitdi',
        'evlerlar', 'kitabler', 'geg', 'deviet',
        'insanlan', 'onlan',
      ];
      final accepted = invalid.where(TurkishMorphology.isKnownWord).toList();
      expect(accepted, isEmpty, reason: 'Yanlışlıkla kabul edilenler: $accepted');
    });

    test('registerExtraWords ve unregisterExtraWord önbelleği temizleyerek çalışır', () {
      const customWord = 'zembereksizkelime';
      TurkishMorphology.unregisterExtraWord(customWord);
      expect(TurkishMorphology.isKnownWord(customWord), isFalse);

      TurkishMorphology.registerExtraWords([customWord]);
      expect(TurkishMorphology.isKnownWord(customWord), isTrue);

      TurkishMorphology.unregisterExtraWord(customWord);
      expect(TurkishMorphology.isKnownWord(customWord), isFalse);
    });
  });
}
