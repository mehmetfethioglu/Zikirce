# Tahrir v1.15.0+21 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Çift Modlu Eski PDF & Hibrit OCR: Sararmış/eğik taramalar için C++ Sauvola restorasyonu, temalı Baskı Akışı ve uzun-basma Büyüteç.
• Cihaz İçi Tesseract 5 + Apple Vision: Şüpheli/Arapça satırlarda çevrimdışı LSTM doğrulaması (~19 MB ilk açılışta arka planda).
• Tahrir Pro & Esnek Erişim: Kurulumda 24 saat Pro, kapatılabilir karşılama, temel PDF/Seri ve 3 ödüllü reklamla 24 saat Pro.
</tr-TR>
<en-US>
• Dual-Mode Old PDF & Hybrid OCR: C++ Sauvola restoration, theme-tinted Optical Reflow view, and long-press 300 DPI original peek.
• On-Device Tesseract 5 + Apple Vision: Offline LSTM single-line verification for low-confidence and Arabic lines (~19 MB background fetch).
• Tahrir Pro & Flexible Access: 24h free trial on install, dismissible prompt, free PDF/Streak basics, and 3 rewarded ads for 24h Pro.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (tr)
- **Çift Modlu Eski PDF Restorasyonu (`Akış / Baskı / PDF`):** Sararmış, gölgeli veya eğik taramalarda C++ Sauvola binarizasyonu ve ±5° eğrilik düzeltme ile temaya uyumlu şeffaf **Baskı Akışı** ve kelimeye uzun basınca 300 DPI orijinal taramayı gösteren **Büyüteç (Peek)** eklendi.
- **Cihaz İçi Hibrit OCR Motoru:** iOS'ta **Apple Vision** (`.accurate`, `tr-TR`, `ar-SA`, `en-US`) ve Android'de C++ FFI **Tesseract 5 LSTM** doğrulamasıyla düşük güvenli ve Arapça/dipnot satırları daha yüksek doğrulukla çözümlenir.
- **Tahrir Pro & Banner'sız Esnek Erişim:** Banner reklam olmadan kurulumda ilk 24 saat ücretsiz Pro denemesi, kapatılabilir karşılama ekranı, temel modda ücretsiz Orijinal PDF okuma + Günlük Seri ve 3 ödüllü reklamla 24 saat Pro geçişi sunuldu.

### English (en-US)
- **Dual-Mode Old PDF Restoration (`Flow / Print / PDF`):** Added C++ Sauvola binarization and ±5° deskewing for aged scans, theme-tinted **Optical Reflow** view, and long-press **300 DPI Original Peek** magnifier.
- **On-Device Hybrid OCR Engine:** Added native iOS **Apple Vision** (`.accurate`, `tr-TR`, `ar-SA`, `en-US`) and Android C++ FFI **Tesseract 5 LSTM** single-line verification for low-confidence and Arabic lines.
- **Tahrir Pro & Banner-Free Access:** Enjoy an automatic 24-hour Pro trial on install, a dismissible welcome prompt, free Original PDF reading & Daily Streak in Basic mode, plus 3 rewarded ads for a 24h Pro Pass or flexible plans.
