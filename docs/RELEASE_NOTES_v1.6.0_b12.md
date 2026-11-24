# Tahrir v1.6.0+12 (v1.0.6+7) — Tester & Mağaza Sürüm Notları (Zikirce_ Standardı)

## 1. Google Play Console (< 500 Karakter XML)

```xml
<tr-TR>
• Tek Akışta 21 Kademeli Hızlı Okuma Serüven Yolu: Sekme karmaşası kaldırılarak adım adım ilerleyen serüven haritası ve kompakt "Serbest" pratik çekmecesi eklendi.
• Kitap Okuma Hızı Koordinasyonu: Gerçek kitap okuma WPM hızınız ile hızlı okuma hedef hızınız canlı koordine edilir.
• Dinamik Kademe Kalibrasyonu: Seri bozulduğunda veya kitap hızı düştüğünde kademe otomatik dengelenir.
• Canlı Kitap Kesiti & Değişken Metin Motoru: Kitaplarınızdan canlı pasajlar ve her açılışta taze metinler.
</tr-TR>
<en-US>
• Single-Flow 21-Stage Speed Reading Adventure Path: Unified step-by-step adventure map with a compact "Free Practice" drawer.
• Book Reading Speed Coordination: Live synchronization between your actual book reading WPM and your Speed Reading Academy target WPM.
• Dynamic Stage Calibration: Automatically recalibrates your stage and target WPM when streaks break or book speed drops.
• Live Book Excerpts & Dynamic Passage Engine: Fresh passages and live book drills on every run.
</en-US>
```

## 2. Apple App Store Connect (Bu Sürümdeki Yenilikler / What's New)

### Türkçe (`tr`)
- **Tek Akışta 21 Kademeli Hızlı Okuma Serüven Yolu:** Parçalı 3 sekme yapısı kaldırılarak tüm hızlı okuma deneyimi tek bir dikey Serüven Haritası akışında birleştirildi; üst bara istediğiniz simülatörü ve 7 teknik rehberi anında açan **Serbest** pratik çekmecesi eklendi.
- **Kitap Okuma Hızı Koordinasyonu:** Kütüphanenizdeki kitapları okurken ölçülen gerçek okuma hızınız (`lastBookReadingWpm`) ile Hızlı Okuma Akademisi'ndeki hedef hızlar (`coordinatedTargetWpm`) çift yönlü senkronize edildi.
- **Dinamik Kademe Gerilemesi & Kalibrasyon:** Günlük serinin bozulması, gerçek kitap okuma hızının %15+ düşmesi veya E-WPM sınav kavramasının %50 altında kalması halinde serüven kademesi şeffaf bir bilgi kartıyla otomatik olarak gerçekçi seviyeye çekilir.
- **Canlı Kitap Kesiti & Değişken Metin Motoru:** Okuduğunuz kitaplardan ve altını çizdiğiniz alıntılardan otomatik kavrama sorulu canlı egzersiz pasajları üretilir; 12 klasik disiplinden oluşan genişletilmiş metin havuzu her egzersizde farklı bir metin sunarak ezberlemeyi önler.

### English (`en-US`)
- **Single-Flow 21-Stage Speed Reading Adventure Path:** Replaced the fragmented 3-tab layout with a unified vertical Adventure Map and a compact **Free Practice** drawer on the top bar for instant access to all 8 simulators and 7 cognitive guides.
- **Live Book Reading Speed Coordination:** Bidirectional synchronization between your real-time book reading WPM on the Bookshelf and your Speed Reading Academy target WPM (`coordinatedTargetWpm`).
- **Dynamic Stage Recalibration:** Automatically adjusts your active adventure stage and target WPM downward with transparent feedback when daily streaks break, book reading speed drops by 15%+, or comprehension falls below 50%.
- **Live Book Excerpts & Anti-Stale Passage Engine:** Generates live drills and comprehension questions directly from your active books and highlights while rotating fresh classical passages on every run.
