# Tahrir v1.10.0+16 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Katman 2c Bağlamsal Gerçek-Kelime OCR Çözücüsü: Sözlükte var olsa bile cümlede anlamsızlaşan kelimeleri ("120 dini→120 bini", "ortalama getir→gelir") komşu bağlamıyla onarır.
• Klasik Terim & Fiil Bağlam Tashihi: "iştikak→iştirak", "mütenasip okur→olur", "Fark Devleti→Fars Devleti" gibi bağlamsal OCR sapmalarını düzeltir.
• Morfolojik İsim/Fiil Doğrulayıcısı: "bölümdüğü→bölündüğü" gibi sahte morfolojik türetmeleri yakalayıp onarır.
</tr-TR>
<en-US>
• Tier 2c Contextual Real-Word OCR Disambiguator: Repairs valid dictionary words that break sentence meaning ("120 dini→120 bini", "ortalama getir→gelir") using neighbor context.
• Classical Term & Verb Disambiguation: Heals contextual OCR slips like "iştikak→iştirak", "mütenasip okur→olur", and "Fark Devleti→Fars Devleti".
• Morphological POS Validator: Blocks pseudo-valid noun+participle forms ("bölümdüğü→bölündüğü").
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Katman 2c Bağlamsal Gerçek-Kelime OCR Karışıklık Çözücüsü (`repairContextualRealWordInContext`):** Tek başına sözlükte yer alan ancak OCR harf karışıklığı (`b↔d`, `l↔t`, `l↔k`, `r↔k`, `p↔ş`) nedeniyle cümlenin anlamını bozan kelimeleri (`120 dini geçmemiştir→120 bini geçmemiştir`, `yalnızca diridir→yalnızca biridir`, `ortalama getir→ortalama gelir`, `yıllık yaklaşım 30 bin→yaklaşık 30 bin`) sol ve sağ komşu bağlamına göre %100 çevrimdışı onarır.
- **Klasik Terim, Yardımcı Fiil ve Coğrafya Bağlam Tashihi:** `savaşa iştikak→iştirak`, `mütenasip okur→olur`, `60 bin oluş→olup`, `ikiye ayrılık→ayrılır`, `Fark Devleti→Fars Devleti`, `Santa Aruz→Santa Cruz` ve `büyük yoğunluğu→çoğunluğu` gibi bağlamsal OCR hatalarını otomatik düzeltir.
- **Morfolojik İsim/Fiil (POS) Doğrulayıcısı:** Sıfat-fiil eklerinin (`-dığı/-diği`) yalnızca fiil gövdelerine gelmesini denetleyerek `bölümdüğü→bölündüğü` gibi isim kökü + fiil eki kaynaşmalarını yakalayıp doğru fiil gövdesine yönlendirir.

### English (`en-US`)
- **Tier 2c Contextual Real-Word OCR Disambiguator (`repairContextualRealWordInContext`):** Repairs valid dictionary words that become semantically nonsensical due to OCR character confusions (`120 dini→120 bini`, `yalnızca diridir→biridir`, `ortalama getir→gelir`, `yaklaşım 30 bin→yaklaşık 30 bin`) using left and right neighbor context.
- **Classical Term, Auxiliary Verb & Geographic Disambiguation:** Automatically heals contextual OCR slips such as `savaşa iştikak→iştirak`, `mütenasip okur→olur`, `60 bin oluş→olup`, `ikiye ayrılık→ayrılır`, `Fark Devleti→Fars Devleti`, and `Santa Aruz→Santa Cruz`.
- **Morphological Noun/Verb (POS) Validator:** Enforces verb-only participle suffix rules (`-dığı/-diği`) against nominal stems so pseudo-valid OCR corruptions like `bölümdüğü` are accurately repaired to `bölündüğü`.
