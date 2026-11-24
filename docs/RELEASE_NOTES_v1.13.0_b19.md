# Tahrir v1.13.0+19 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Kusursuz Okuma Tashihi: Biçimbilim (-laş/-leş, ek-fiil), ünsüz benzeşmesi ("kitapda→kitapta", "gitdi→gitti") ve kesme işaretli ek ("Osmanlı'nm→Osmanlı'nın", "1923'de→1923'te") onarımları.
• Bağlamsal & Tire Onarımı: Gerçek-kelime ("olanak→olarak", "üzen→üzere", "dolay→dolayı"), kırık tire ve dipnot içi otomatik tashih.
• Tüm Kitabı Tara: Tüm sayfa ve EPUB bölümlerini tarayıp tek dokunuşla kalıcı olarak onarır.
</tr-TR>
<en-US>
• Flawless Reading Proofreader: Expanded Turkish morphology (-laş/-leş, copula forms), consonant assimilation ("kitapda→kitapta", "gitdi→gitti"), and apostrophe/number suffix fixes.
• Contextual & Hyphen Healing: Real-word context repairs, cross-block broken/soft hyphens, and automatic footnote proofreading.
• Full-Book OCR Scan: Scans every page and EPUB chapter in one tap, persisting fixes and jumping directly to remaining issues.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Türkçe Biçimbilim & Ünsüz Benzeşmesi Koruması:** Zemberek doğrulayıcısı `-laş/-leş`, `-(y)ıver`, `-(y)agel`, `-maksızın` ve ek-fiil çekimleri (`idi/imiş/ise`) ile genişletildi; fıstıkçı şahap ünsüz benzeşmesi ihlalleri (`kitapda → kitapta`, `gitdi → gitti`) ve kesme işaretli özel isim/sayı ekleri (`Osmanlı'nm → Osmanlı'nın`, `1923'de → 1923'te`) otomatik onarılır.
- **Bağlamsal Gerçek-Kelime, Dipnot ve Kırık Tire Tashihi:** OCP uyumlu bağlamsal kayıt tablosuyla gerçek-kelime sapmaları (`olanak → olarak`, `üzen → üzere`, `dolay → dolayı`, `gön → göre`, `karar → kadar`), görünmez yumuşak tireler (`\u00AD`), bloklar arası kırık tireler ve dipnot metinleri düzeltilir.
- **Tüm Kitabı Tara & Gelişmiş Gözden Geçir Arayüzü:** EPUB/MD/TXT bölümlerinde kalıcı SQLite önbelleği, tek dokunuşla kitap geneli tarama/onarım, yoksayılan kelime yönetimi ve satır sonlarını bozmayan altı çizili tashih görünümü eklendi.

### English (`en-US`)
- **Turkish Morphology & Consonant Assimilation Engine:** Extended offline Zemberek morphology with `-laş/-leş`, `-(y)ıver`, `-(y)agel`, `-maksızın`, and copula forms (`idi/imiş/ise`); automatically fixes devoicing typos (`kitapda → kitapta`, `gitdi → gitti`) and apostrophe-inflected proper nouns/numbers (`Osmanlı'nm → Osmanlı'nın`, `1923'de → 1923'te`).
- **Contextual Real-Word, Footnote & Hyphen Healing:** Uses an OCP contextual rule registry to repair real-word confusions (`olanak → olarak`, `üzen → üzere`, `dolay → dolayı`, `gön → göre`, `karar → kadar`), invisible soft hyphens (`\u00AD`), cross-block broken hyphens, and footnote contents.
- **Full-Book OCR Scan & Streamlined Proofreading UI:** Adds persistent SQLite chapter caching across EPUB/MD/TXT books, one-tap full-book scan & repair with direct issue jump chips, ignored-word management, and newline-safe underline highlights.
