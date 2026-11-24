# Tahrir v1.8.0+14 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Genişletilmiş OCR Tashih Veritabanı: 350+ boşluklu hece bölünmesi ("bi çimini→biçimini") ve 1.500+ Türkçe/Osmanlıca kök sözlüğü.
• Osmanlıca Terkip & İzafet Onarımı: Tireleri düşen 2-3 kelimelik terkipler ("devlet-i aliyye", "âdâb-ı muaşeret") otomatik onarılır.
• Tek Dokunuş Popup Lügat: Okurken herhangi bir kelimeye dokunarak anlamını, kökenini, kök+ek yapısını ve OCR tashihini anında görün.
</tr-TR>
<en-US>
• Expanded OCR Lexicon Database: 350+ space-split syllable repairs, never-merge guards, and 1,500+ Turkish/Ottoman root stems.
• Ottoman Terkip & Izafet Restoration: Automatically restores 2- and 3-word Persian/Arabic izafet compounds dropped by OCR.
• One-Tap Popup Lexicon: Tap any word while reading to view its definition, etymology, stem+suffix analysis, and 1-tap OCR fixes.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Genişletilmiş OCR Tashih Veritabanı (`OcrLexiconDatabase`):** Taranmış Türkçe ve Osmanlıca eserlerde satır/sütun sonu tire düşmelerinden kaynaklanan 350+ boşluklu hece bölünmesi kalıbı (`yurt taşlar→yurttaşlar`, `bi çimini→biçimini`, `gere ken→gereken`), yanlış birleştirme koruma listesi (`neverMergeWordPairs`) ve 1.500+ Türkçe/Osmanlıca kök sözlüğü eklendi.
- **Osmanlıca Terkip & İzafet Onarımı:** OCR sırasında kısa çizgisi kaybolan 2 ve 3 kelimelik Farsça/Arapça izafet ve atıf terkipleri (`adab ı muaşeret→âdâb-ı muaşeret`, `devlet i aliyye→devlet-i aliyye`, `nokta i nazar→nokta-i nazar`) otomatik olarak tespit edilip onarılır.
- **Tek Dokunuşla Açılan Popup Lügat (`PopupLugatCard`):** Kitap okurken metin içindeki herhangi bir kelimeye tek dokunuşla açılan; kelimenin anlamını, dil kökenini (Arapça/Farsça/Osmanlıca), morfolojik kök+ek analizini ve ilişkili kavramlar arası gezintiyi sunan zarif açılır kart eklendi.
- **Bağlamsal Terkip Algılama & Kart İçi OCR Tashih:** Tıklanan kelimenin cümle bağlamındaki Osmanlıca terkip bütünlüğü otomatik algılanır ve kelime üzerinde OCR tashih önerisi varsa kart içinden tek dokunuşla düzeltilir.

### English (`en-US`)
- **Expanded OCR Lexicon Database (`OcrLexiconDatabase`):** Added 350+ space-split syllable repair patterns caused by dropped line-break hyphens in scanned Turkish/Ottoman books, a never-merge guard list for reduplications and separate compounds, and 1,500+ Turkish/Ottoman root stems.
- **Ottoman Terkip & Izafet Restoration:** Automatically detects and restores 2- and 3-word Persian/Arabic izafet compounds whose hyphens were lost during OCR (`devlet-i aliyye`, `âdâb-ı muaşeret`, `nokta-i nazar`).
- **One-Tap Contextual Popup Lexicon (`PopupLugatCard`):** Tap any word while reading to immediately open an inline card displaying its definition, language origin (Arabic/Persian/Ottoman), morphological stem+suffix breakdown, and clickable related concepts.
- **Contextual Terkip Detection & In-Card OCR Repair:** Automatically resolves multi-word Ottoman compounds from sentence context and lets you apply OCR proofreading corrections in a single tap directly inside the popup card.
