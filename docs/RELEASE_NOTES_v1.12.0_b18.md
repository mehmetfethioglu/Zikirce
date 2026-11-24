# Tahrir v1.12.0+18 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Zemberek-NLP Morfolojik Çözümleyici: 34.795 kök (31.344 isim/sıfat + 3.451 fiil) ve dinamik ek kurallarıyla %100 çevrimdışı Türkçe kelime doğrulama.
• Optik Karışıklık Matrisi: rn/m, cl/d, n/rı, hk/lık, yn/yı çoklu ligatür kaynaşmalarını otomatik onarır.
• Doğal Kelime Poka-Yoke Koruması: Regresyon önleyici katmanla gerçek kelimelerin bozulmasını engeller.
• Minimal Üst Panel Gözden Geçirme: Okuma alanını daraltmayan Word tarzı hızlı OCR proofreading arayüzü.
</tr-TR>
<en-US>
• Zemberek-NLP Morphological Engine: 34,795 roots (31,344 noun/adj + 3,451 verb) with dynamic affix validation, 100% offline.
• Optical Confusion Matrix & Ligatures: Automatically resolves rn/m, cl/d, n/rı, hk/lık, yn/yı OCR fusions.
• Real-Word Regression Protection (Poka-Yoke): Preserves valid dictionary words from over-correction.
• Minimal Top-Bar Proofreading Panel: Word-style streamlined OCR review without shrinking reading view.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Zemberek-NLP Tabanlı Türkçe Morfolojik Çözümleyici:** 31.344 isim/sıfat ve 3.451 fiil kökü olmak üzere toplam 34.795 kök içeren çevrimdışı Zemberek sözlüğü ve dinamik ek geçiş kurallarıyla tam Türkçe morfolojik analiz ve doğrulama.
- **Optik Karışıklık Matrisi ve Çoklu Ligatür Üreticisi (OcrCandidateGenerator):** Tarama esnasında birbirine karışan `rn/m`, `cl/d`, `n/rı`, `hk/lık`, `yn/yı` gibi ligatür ve karakter kaynaşmalarını morfolojik aday türetme ve frekans skoru ile otomatik olarak düzeltir.
- **Regresyon Önleyici Poka-Yoke Koruması (`revertValidWordRegressions`):** Tahrir ve OCR motoru işlem yaparken metindeki zaten doğru olan Türkçe kelimelerin yanlışlıkla değiştirilmesini mutlak olarak engelleyen koruma mekanizması.
- **Minimal Üst Panel OCR Gözden Geçirme (Word Tarzı Proofreading):** Okuma ve düzenleme alanını daraltmadan, metin üzerinde şüpheli kelimeleri sırayla inceleyip tek dokunuşla kabul/reddet imkanı veren üst proofreading paneli.

### English (`en-US`)
- **Zemberek-NLP Powered Turkish Morphological Resolver:** Full offline Turkish morphological analysis and root verification covering 34,795 roots (31,344 noun/adjective roots + 3,451 verb roots) with dynamic Turkish inflection rules.
- **Optical Confusion Matrix & Multi-Ligature Generator (OcrCandidateGenerator):** Automatically generates and resolves OCR optical fusions (`rn/m`, `cl/d`, `n/rı`, `hk/lık`, `yn/yı`) using morphological validation and candidate frequency scoring.
- **Real-Word Anti-Regression Poka-Yoke Guard (`revertValidWordRegressions`):** Strict verification layer that guarantees already valid natural words are never erroneously altered by candidate generation.
- **Minimal Top-Bar OCR Proofreading Panel:** Streamlined Word-style proofreading bar docked at the top that preserves full reading real estate while enabling one-tap review and replacement of OCR ambiguities.
