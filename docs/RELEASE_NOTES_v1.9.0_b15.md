# Tahrir v1.9.0+15 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• 3 Katmanlı Yerel AI OCR Tashih Motoru: ML Kit mikro-boşluk geometrisi, Türkçe morfolojik SymSpell + N-Gram bağlam modeli ve Beam Search çözücüsü.
• Çoklu Bozulma Onarımı: Hem hece bölünmesi hem harf kayması içeren kelimeleri ("basarısız ilkle→başarısızlıkla") < 5 ms içinde onarır.
• Yön Duyarlı Sayfa Hizalaması: İleri geçerken sayfa başına, geri dönerken kaldığınız sayfa sonuna otomatik hizalanır.
</tr-TR>
<en-US>
• 3-Tier On-Device AI OCR Engine: ML Kit micro-gap geometry fusion, Turkish morphological SymSpell + N-Gram context model & Beam Search decoder.
• Compound Corruption Healing: Repairs simultaneous syllable splits and character transpositions 100% offline in < 5 ms.
• Direction-Aware Page Edge Alignment: Aligns to page top when moving forward and page bottom when returning backward.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Katman 1 — ML Kit Piksel Geometrisi & Güven Füzyonu (`analyzeMlKitLineGeometryAndConfidence`):** Satır içi yatay piksel boşluğu `avgCharWidth * 0.48` eşiğinden küçük olan bölünmüş heceleri ve düşük güven skorlu (`< 0.78`) OCR sembollerini tespit ederek piksel düzeyinde birleştirir.
- **Katman 2 — Türkçe Morfolojik SymSpell & Bağlamsal N-Gram Dil Modeli (`OcrLocalAiLanguageModel`):** `O(1)` simetrik silme indeksiyle aday üretir; sol ve sağ komşu kelimelerle Bigram/Trigram kolokasyon ve Türkçe morfosentaktik dizilim uyumu puanlaması yapar.
- **Katman 3 — Karakter Seviyesi Beam Search Çözücüsü:** Hem hece bölünmesine hem de eşzamanlı harf bozulmasına/yer değiştirmesine uğrayan kelimeleri (`basarısız ilkle→başarısızlıkla`, `gercek lestiğini→gerçekleştiğini`, `götü recegini→götüreceğini`) harici model indirmeden ve sayfa başına `< 5 ms` gecikmeyle %100 çevrimdışı onarır.
- **Yön Duyarlı Sayfa Başı / Sayfa Sonu Hizalaması (`_scrollToPageEdge`):** Sonraki sayfaya geçildiğinde sayfanın en üstüne (`0.0`), önceki sayfaya dönüldüğünde ise kaldığınız son satırları kesintisiz okumak için sayfanın en alt/son kısmına (`maxScrollExtent`) otomatik hizalanır.

### English (`en-US`)
- **Tier 1 — ML Kit Pixel Geometry & Confidence Fusion (`analyzeMlKitLineGeometryAndConfidence`):** Detects intra-line micro-gaps (`avgCharWidth * 0.48`) and low-confidence (`< 0.78`) OCR symbols to fuse split syllables at the bounding-box level.
- **Tier 2 — Turkish Morphological SymSpell & Contextual N-Gram Language Model (`OcrLocalAiLanguageModel`):** Generates candidates in `O(1)` via symmetric delete indexing and scores them against left/right neighbors using Bigram/Trigram collocations and Turkish morphosyntactic rules.
- **Tier 3 — Character-Level Beam Search Decoder:** Heals words suffering from simultaneous syllable splitting, diacritic loss, and character transposition (`basarısız ilkle→başarısızlıkla`, `gercek lestiğini→gerçekleştiğini`) 100% offline in `< 5 ms` per page with zero external model downloads.
- **Direction-Aware Page Edge Alignment (`_scrollToPageEdge`):** Automatically aligns to the top of the page when advancing forward and to the bottom edge when returning to the previous page for seamless reading continuity.
