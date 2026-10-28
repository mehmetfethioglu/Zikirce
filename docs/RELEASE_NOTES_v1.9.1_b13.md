# CueDeck v1.9.1 (Build 13) — Google Play Store & Apple App Store Sürüm Notları

**Sürüm / Version:** `1.9.1+13` (Build `13`)  
**Uygulama Kimliği / Bundle ID:** `com.akarworks.cuedeck`  
**Tarih / Date:** 28.10.2026  
**Hedef Platformlar:** Google Play Console (`.aab` / `.apk`) & Apple App Store Connect (`TestFlight` / `App Store Review`)

---

## 🤖 Google Play Console Sürüm Notları (500 Karakter Sınırına Tam Uyumlu)

```xml
<tr-TR>
• Soft Slate & Warm Alabaster Arayüzü: Ayarlar ve İzleme Planı ekranı gözü dinlendiren yumuşak renk paleti ve sade kart düzeniyle yenilendi.
• Çift Protokol TV Bağlantısı: Standart TV'ler için Port 6466 (6 Haneli PIN) Sıfır Kurulum ve Port 5555 ADB RSA-2048 Turbo modu.
• CueDeck Pro & 24s Pro Pass: Tek ödüllü video ile 24 saatlik Pro Pass, 10 günde %40 sadakat indirimi ve ömür boyu Pro.
• Gerçek OS Bildirimleri & AES-256-GCM Google Drive Yedekleme.
</tr-TR>
<en-US>
• Soft Slate & Warm Alabaster UI: Redesigned Settings & Watch Planner with a soothing color palette and streamlined cards.
• Dual-Protocol TV Connectivity: Zero-config Port 6466 (6-Digit PIN) for retail Android/Google TVs + Port 5555 ADB RSA-2048 Turbo mode.
• CueDeck Pro & 24h Pro Pass: Unlock 24h Pro Pass via 1 rewarded ad, earn a 40% loyalty discount in 10 days, or get Lifetime Pro.
• Native OS Alarms & AES-256-GCM Google Drive Cloud Backup.
</en-US>
```

---

## 🍎 Apple App Store Connect — "Bu Sürümdeki Yenilikler / What's New in This Version"

### Türkçe (`tr`)
```text
CueDeck v1.9.1 (Build 13) Yenilikleri:

• Yumuşak Renk Paleti (Soft Slate & Warm Alabaster) ve Sadeleştirilmiş Ayarlar Ekranı:
Tam sayfa Ayarlar ve İzleme Planı (CueDeckSettingsScreen) ekranı, gözü dinlendiren Soft Slate (#141824 sayfa zemini, #1E2433 kart yüzeyi, #E6C17A yumuşak kum sarısı ve #6EE7B7 pastel adaçayı yeşili) ile Warm Alabaster (#F3F6FA açık mod) paletine kavuştu. Uzun açıklama metinleri tek satırlık yalın özetlere indirildi, Pro yükseltme ve 24 Saatlik Pro Pass butonları tek satırda birleştirildi.

• Çift Protokol Evrensel Android TV & Google TV Bağlantısı (Port 6466 PIN & Port 5555 ADB Turbo):
Geliştirici Seçenekleri kapalı olan standart perakende televizyonlar (Sony Bravia, TCL, Philips, Xiaomi Mi Box/Stick, Chromecast, Redline vb.) için Port 6466/6467 TLS + 6 Haneli PIN "Sıfır Kurulum Modu" ve adım adım görsel kurulum rehberi eklendi. Gelişmiş kullanıcılar için Port 5555 (RSA-2048 donanım imzalı ADB Turbo Modu) ile <120ms tuş tepkisi ve doğrudan YouTube Playlist / Deep-Link ışınlama desteği sunuldu.

• CueDeck Pro (Ömür Boyu) & 24 Saatlik Ödüllü Pro Pass:
Abonelik dayatması olmadan, yalnızca 1 kısa ödüllü video izleyerek 24 saat boyunca tüm Pro özelliklerini (reklamsız deneyim, sınırsız izleme planı ve bulut senkronizasyonu) açabilirsiniz. 10 farklı günde Pro Pass kullanan sadık kullanıcılara özel %40 Sadakat İndirimi (cuedeck_pro_loyalty_40) veya Tek Seferlik Ömür Boyu Pro (cuedeck_pro_lifetime) seçeneği eklendi.

• Zamanlanmış İzleme Planlayıcı & Gerçek İşletim Sistemi Alarmları:
Günlük, hafta içi, hafta sonu veya seçili günlerde yayın saatinizi ve seans sürenizi planlayın; hem ön hatırlatma hem de tam başlama saatinde gelen bildirimle televizyonunuzda kaldığınız YouTube Playlist videosunu veya yayını tek dokunuşla başlatın.

• Donanım Şifreli Google Drive & Yerel JSON Yedekleme:
AES-256-GCM ve SHA-256 bütünlük mührüyle korunan Google Drive bulut senkronizasyonu ve yerel JSON dışa/içe aktarım altyapısı güçlendirildi.
```

### English (`en-US`)
```text
What's New in CueDeck v1.9.1 (Build 13):

• Soft Slate & Warm Alabaster UI Redesign:
Refined the full-page Settings & Watch Planner screen (CueDeckSettingsScreen) with a soothing Soft Slate (#141824 background, #1E2433 card surface, #E6C17A warm sand gold, and #6EE7B7 pastel sage green) and Warm Alabaster (#F3F6FA light mode) color palette. Streamlined card descriptions into concise single-line summaries and unified the Lifetime Pro and 24h Pro Pass actions into a single compact row.

• Dual-Protocol Universal Android TV & Google TV Connectivity (Port 6466 PIN & Port 5555 ADB Turbo):
Added Zero-Config Port 6466/6467 TLS 6-Digit PIN pairing and an interactive visual setup guide for standard retail Android TV and Google TV devices (Sony Bravia, TCL, Philips, Xiaomi Mi Box/Stick, Chromecast, Shield, Redline). Power users can switch to Port 5555 (RSA-2048 hardware-authenticated ADB Turbo Mode) for <120ms key injection and direct YouTube Playlist / Deep-Link URL beaming.

• CueDeck Pro (Lifetime) & 24-Hour Rewarded Pro Pass:
No subscriptions! Watch a single optional rewarded video ad to unlock a 24-Hour Pro Pass (ad-free experience, unlimited watch plans, and cloud sync). Unlock a 40% Loyalty Discount (cuedeck_pro_loyalty_40) after 10 distinct days of usage, or upgrade once with CueDeck Pro Lifetime (cuedeck_pro_lifetime).

• Scheduled Watch Planner & Native OS Notifications:
Schedule daily, weekday, weekend, or custom-day watch sessions with automatic episode/minute checkpoint tracking. Receive native high-priority reminders before and at showtime to launch your planned stream on your TV with a single tap.

• Hardware-Encrypted Google Drive & Local JSON Backup:
Enhanced multi-device cloud synchronization and local JSON export/import protected by AES-256-GCM encryption and canonical SHA-256 integrity seals.
```
