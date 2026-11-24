# Tahrir v1.7.0+13 — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Tam Kapsamlı JSON Yedekleme & Geri Yükleme: Kitap, alıntı ve okuma verilerinizi tek dokunuşla yedekleyin ve geri yükleyin.
• Yalın 3 Raflı Kütüphane & İlk Açılış Rehberi: Son Açılan 3 Eser, Okunanlar ve Tamamlananlar rafları + 3 adımlı rehber.
• Sadeleştirilmiş Okuyucu Barları & Canlı Derkenar: 4'er temel aksiyonlu üst/alt barlar ve anlık Derkenar senkronizasyonu.
• "Tahrir ile Aç" Dosya Köprüsü & Küçültülmüş APK Boyutu: Doğrudan PDF/EPUB açma ve paket boyutu optimizasyonu.
</tr-TR>
<en-US>
• Full JSON Backup & Restore: Export and restore all books, highlights, and reading progress in one tap.
• Streamlined 3-Shelf Library & 3-Step Onboarding: Recent Front Covers, Reading & Completed shelves + welcome guide.
• Clean Reader Toolbars & Live Marginalia Sync: Simplified 4-action top/bottom bars and instant highlight sync.
• "Open with Tahrir" File Bridge & Reduced APK Size: Open PDF/EPUB/TXT directly from OS and optimized package size.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Tam Kapsamlı JSON Yedekleme & Geri Yükleme (`BackupRestoreService`):** Tüm SQLite kütüphane, alıntı, okuma oturumu ve hızlı okuma ilerleme verilerinizi tek bir JSON dosyası olarak dışa aktarın ve cihaz değişimlerinde güvenle geri yükleyin.
- **Yalın 3 Raflı Kütüphane & 3 Adımlı İlk Açılış Rehberi:** Üst kısımdaki kalabalık teşvik kartları temizlenerek *Okumaya Devam Et* kartı + 3 Raf (*Son Açılan 3 Eser Ön Kapak*, *Okunanlar Dikey Sırt*, *Tamamlananlar Dikey Sırt*) mimarisine geçildi; ilk açılış için 3 adımlı `TahrirOnboardingDialog` eklendi.
- **Sadeleştirilmiş Okuyucu Barları & Canlı Derkenar Senkronizasyonu:** Okuyucu üst ve alt barları 4'er temel aksiyona sadeleştirilip ikincil araçlar düzenli çekmecelere toplandı; Derkenar sekmesinde canlı alıntı ve gerçek kitap/yazar eşleştirmesi sağlandı.
- **Tahrir Pro (Müderris Beratı), "Tahrir ile Aç" Dosya Köprüsü & Paket Optimizasyonu:** Aylık/Yıllık/Ömür Boyu Tahrir Pro freemium mimarisi, dosya yöneticilerinden doğrudan PDF/EPUB/TXT açma köprüsü, Android Ana Ekran Widget'ı ve kullanılmayan ONNX modellerinin kaldırılmasıyla önemli ölçüde küçültülmüş APK boyutu.

### English (`en-US`)
- **Full JSON Backup & Restore (`BackupRestoreService`):** Export and restore all SQLite books, highlights, reading sessions, and speed reading progress in a single portable JSON file.
- **Streamlined 3-Shelf Library & 3-Step Welcome Onboarding:** Replaced top clutter with *Continue Reading* + 3 Shelves (*Recent 3 Books Front Cover*, *Currently Reading Spines*, *Completed Spines*) and a 3-step onboarding walkthrough.
- **Clean Reader Toolbars & Live Marginalia Sync:** Simplified top and bottom reader toolbars to 4 core actions each with secondary tools grouped in clean drawers; enabled live highlight synchronization with accurate book/author metadata.
- **Tahrir Pro, "Open with Tahrir" Intent Bridge & Package Size Optimization:** Added Monthly/Annual/Lifetime Tahrir Pro options, native OS "Open with Tahrir" support for PDF/EPUB/TXT files, Android Home Screen Widget, and a significantly smaller APK footprint by removing unused ONNX runtime binaries.
