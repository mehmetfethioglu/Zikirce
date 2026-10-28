# CueDeck v1.7.0+10 — Sürüm Notları / Release Notes

**Sürüm / Version:** `1.7.0+10` (Build `10`)  
**Tarih / Date:** 28.10.2026  
**Hedef Platform / Target Platform:** Android (ARM64 / ARMv7 / x86_64 Release APK) & Universal Android TV / Google TV (`Port 5555` ADB-over-TCP & `mDNS`)  
**Paket / Package:** `CueDeck_v1.7.0+10_Release.apk` (`53.69 MB` / `56,299,356 byte`)  
**SHA-256:** `4A41696820FC8C3E6249631FA90EA3E1BF128BB1E2DE7EA1E3B3A3A61ECE7E7F`

---

## 🇹🇷 Türkçe Sürüm Notları (`changelog_tr`)

### 🚀 Öne Çıkan Yenilikler (v1.7.0+10 — Evrensel Android TV & Google TV Uyumluluğu)
1. **Evrensel RSA-2048 ADB `CMD_AUTH` Kimlik Doğrulama & İnteraktif TV Eşleştirme (`AdbRsaAuthenticator` & `pairWithTv`)**
   - Yalnızca Redline/Realtek cihazlarla sınırlı kalmadan; **Sony Bravia, TCL, Philips, Xiaomi Mi Box/TV, Chromecast with Google TV, Nvidia Shield, Next, Sunny, Onvo ve Grundig** dahil tüm Android TV ve Google TV cihazlarıyla uyumlu tam `CMD_AUTH` (`AUTH_TOKEN` -> `AUTH_SIGNATURE` -> `AUTH_RSAPUBLICKEY`) protokolü eklendi.
   - `AndroidKeyStore` AES-256-GCM donanım kasasında saklanan 2048-bit RSA anahtar çifti, PKCS#1 v1.5 SHA-1 `DigestInfo` imzalama ve 524-byte Android `RSAPublicKey` (`cuedeck@akarworks\x00`) el sıkışması ile TV ekranında **"USB/Ağ Hata Ayıklamaya İzin Verilsin mi?"** onay penceresini açan 18 saniyelik interaktif eşleştirme (`pairWithTv`) özelliği eklendi.

2. **mDNS Multicast (`224.0.0.251:5353`), Port 5555/6466 & Canlı `getprop` Marka/Model Tespiti**
   - Yerel Wi-Fi ağındaki tüm Android TV / Google TV cihazlarını otomatik bulmak için `_androidtvremote2._tcp.local`, `_adb._tcp.local` ve `_googlecast._tcp.local` mDNS PTR sorguları ve genişletilmiş `/24` alt ağ taraması eklendi.
   - Hem Port `5555` (ADB) hem de Port `6466` (Android TV Remote v2) taranarak, ADB özelliği henüz açılmamış TV'ler dahi tespit edilir ve kullanıcıya adım adım etkinleştirme rehberliği sunulur.
   - Bağlanan TV'nin gerçek marka, model, anakart/SoC platformu ve Android sürümü `getprop` üzerinden canlı olarak okunup arayüzde gösterilir (`probeTvDeviceProfile`).

3. **Evrensel Tuş İletimi & Çoklu Marka Uygulama Başlatıcı Yedeklemesi**
   - `/dev/input/event0` ham IR tarama kodu enjeksiyonu artık yalnızca TV'de `venus_IR_input.kl` (Realtek RTD2851P) mevcutsa devreye girer; diğer tüm Android TV / Google TV markalarında evrensel `input keyevent` standardı kullanılır.
   - TV Girişleri (`inputs`) tuşu `com.toptech.tvmenu` varlığını kontrol eder ve diğer tüm markalarda standart `KEYCODE_TV_INPUT` (`178`) komutuna geçer.
   - Uygulama başlatma (`launchPlatformOrDeepLink`) işlemlerinde cihaza özgü aktivite farklılıklarına karşı `LEANBACK_LAUNCHER` ve `MAIN` intent yedekleme zinciri eklendi.

---

## 🇬🇧 English Release Notes (`changelog_en`)

### 🚀 What's New in v1.7.0+10 (Universal Android TV & Google TV Compatibility)
1. **Universal RSA-2048 ADB `CMD_AUTH` Authentication & Interactive TV Pairing (`AdbRsaAuthenticator` & `pairWithTv`)**
   - Implemented the full ADB `CMD_AUTH` state machine (`AUTH_TOKEN` -> `AUTH_SIGNATURE` -> `AUTH_RSAPUBLICKEY`) for universal compatibility across **Sony Bravia, TCL, Philips, Xiaomi Mi Box/TV, Chromecast with Google TV, Nvidia Shield, Next, Sunny, Onvo, Grundig, and Redline** Android TV / Google TV devices.
   - Backed by a hardware-protected `AndroidKeyStore` AES-256-GCM 2048-bit RSA keypair, PKCS#1 v1.5 SHA-1 `DigestInfo` token signing, and 524-byte Android `RSAPublicKey` (`cuedeck@akarworks\x00`) transmission with an 18-second interactive TV pairing workflow (`pairWithTv`).

2. **mDNS Multicast (`224.0.0.251:5353`), Port 5555/6466 Probing & Live `getprop` Device Profiling**
   - Added UDP mDNS multicast PTR discovery for `_androidtvremote2._tcp.local`, `_adb._tcp.local`, and `_googlecast._tcp.local` alongside an expanded `/24` Wi-Fi subnet scanner.
   - Probes both Port `5555` (ADB) and Port `6466` (Android TV Remote v2) to detect TVs even before Network ADB is enabled, providing clear on-screen setup guidance.
   - Automatically queries `getprop` (`ro.product.brand`, `ro.product.model`, `ro.board.platform`, `ro.build.version.release`) to display the connected TV's real brand, model, SoC, and Android OS version (`probeTvDeviceProfile`).

3. **Universal Key Dispatch & Resilient Multi-Vendor App Launching**
   - Guards `/dev/input/event0` raw IR injection with an explicit `venus_IR_input.kl` check, automatically using standard `input keyevent` across all non-Realtek Android TV / Google TV devices.
   - Guards HDMI/AV input switching (`com.toptech.tvmenu`) with automatic fallback to standard `KEYCODE_TV_INPUT` (`178`), and chains `LEANBACK_LAUNCHER` / `MAIN` package intents so streaming apps launch reliably across all Android TV OS versions.
