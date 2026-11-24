# Tahrir v1.11.0+17 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Kapsamlı rı/ri → n Ligatür Kaynaşması Onarımı: "aynca→ayrıca", "aynntılan→ayrıntıları", "yatınmlan→yatırımları", "cumhunyet→cumhuriyet", "fikn→fikri" gibi tekli ve çiftli ligatürleri onarır.
• Morfolojik Çoğul+İyelik (-lan/-len/-lann) Çözümleyicisi: "insanlann→insanların", "kurumlan→kurumları" eklerini ortaçları koruyarak düzeltir.
• Bağlamsal rı/ri → n Tashihi: "bunlardan bin→biri", "gen çekildiğinde→geri", "içen girdi→içeri" bağlam hatalarını onarır.
</tr-TR>
<en-US>
• Comprehensive rı/ri → n Ligature Fusion Healing: Repairs single and dual ligature fusions ("aynca→ayrıca", "aynntılan→ayrıntıları", "yatınmlan→yatırımları", "cumhunyet→cumhuriyet", "fikn→fikri").
• Morphological Plural+Possessive Resolver: Restores "-lan/-len/-lann" suffixes ("insanlann→insanların", "kurumlan→kurumları") while protecting passive participles.
• Contextual rı/ri → n Disambiguation: Fixes real-word fusions ("bunlardan bin→biri", "gen çekildiğinde→geri", "içen girdi→içeri").
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Ünsüz Sonrası, Alıntı Kelime ve Çift Ligatür (`rı/ri → n`) Onarımı:** Taranmış Türkçe ve Osmanlıca eserlerde `rı/ri` harf çiftinin `n` olarak okunmasından kaynaklanan tekli ve çiftli kaynaşmaları (`aynca→ayrıca`, `aynntılan→ayrıntıları`, `yatınmlan→yatırımları`, `üzennde→üzerinde`, `tanh→tarih`, `birbinne→birbirine`, `cumhunyet→cumhuriyet`, `hürnyet→hürriyet`, `fikn→fikri`, `şehn→şehri`, `nehn→nehri`) %100 çevrimdışı onarır.
- **Morfolojik Çoğul+İyelik (`-lan/-len/-lann/-lenn`) Çözümleyicisi:** `insanlann→insanların`, `devletlenn→devletlerin`, `kurumlan→kurumları`, `koşullan→koşulları`, `haklan→hakları` ek kaynaşmalarını edilgen ortaçlara (`yapılan`, `verilen`, `olan`) zarar vermeden düzeltir.
- **Bağlamsal Gerçek-Kelime `rı/ri → n` Çözücüsü:** Sözlükte tek başına geçerli olan ancak `rı/ri → n` kaynaşması nedeniyle cümle anlamını bozan kelimeleri (`bunlardan bin→biri`, `gen çekildiğinde→geri`, `içen girdi→içeri`, `nüfusun yansından→yarısından`, `tanm→tarım`) sol ve sağ komşu bağlamına göre onarır.

### English (`en-US`)
- **Post-Consonant, Loanword & Dual-Ligature (`rı/ri → n`) Repair:** Automatically heals single and double `rı/ri → n` OCR ligature fusions across Turkish and Ottoman texts (`aynca→ayrıca`, `aynntılan→ayrıntıları`, `yatınmlan→yatırımları`, `üzennde→üzerinde`, `tanh→tarih`, `birbinne→birbirine`, `cumhunyet→cumhuriyet`, `fikn→fikri`, `şehn→şehri`).
- **Morphological Plural+Possessive (`-lan/-len/-lann/-lenn`) Resolver:** Restores fused plural-possessive suffixes (`insanlann→insanların`, `devletlenn→devletlerin`, `kurumlan→kurumları`, `koşullan→koşulları`, `haklan→hakları`) while preserving valid passive participles (`yapılan`, `verilen`, `olan`).
- **Contextual Real-Word `rı/ri → n` Disambiguation:** Repairs dictionary-valid words corrupted by `rı/ri → n` fusion (`bunlardan bin→biri`, `gen çekildiğinde→geri`, `içen girdi→içeri`, `nüfusun yansından→yarısından`, `tanm→tarım`) using left/right neighbor context.
