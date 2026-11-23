# Zamera — Mimari Karar Kayıtları (ADR)

## ADR-1: Derleme ve Dağıtım Hattı (GitHub Actions CI/CD)
- **Durum:** Onaylandı (06.11.2026)
- **Karar:** Geliştirme ortamı Windows olduğundan Android derlemeleri yerel + GitHub Actions (`ubuntu-latest`), iOS derlemeleri ise tamamen GitHub Actions (`macos-latest`) üzerinde yürütülür. İmzalı sürümler doğrudan Google Play Console (Internal Track) ve Apple App Store Connect (TestFlight) hedeflerine yüklenir.

## ADR-2: Mağaza Lisans Politikası (Sıfır GPL / AGPL / LGPL Statik Linkleme)
- **Durum:** Onaylandı (06.11.2026)
- **Karar:** Uygulama ticari olarak App Store ve Google Play'de yayınlanacağı için yalnızca **MIT, Apache-2.0, BSD ve ISC** lisanslı bağımlılıklar kullanılır. `cargo-deny` ile her PR'da lisans taraması yapılır; GPL/AGPL veya lisanssız (`NONE`) paket tespit edilirse derleme otomatik kırılır.

## ADR-3: Ortak Renk Bilimi Çekirdeği (`zamera_core` — Rust)
- **Durum:** Onaylandı (06.11.2026)
- **Karar:** Sanat Modu'nun gerçek renk doğruluğu (ColorChecker 24-yama kalibrasyonu, CIEDE2000 $\Delta E_{00}$ hesabı, Bradford D50→D65 adaptasyonu, sRGB/Display P3 OETF ve Flat-Field aydınlatma dengelemesi) iki platformda da bit-düzeyinde aynı sonucu üretmek üzere **Rust** ile `rust/zamera_core` altında geliştirilir.
- **Sıfır-Kopya Kuralı:** Büyük RAW piksel tamponları asla Dart VM'e kopyalanmaz; Kotlin'den JNI ile, Swift'ten C ABI ile doğrudan Rust belleğine aktarılır.

## ADR-4: Uygulama Kimliği ve Platform Hedefleri
- **Durum:** Onaylandı (06.11.2026)
- **Karar:**
  - `applicationId` / `PRODUCT_BUNDLE_IDENTIFIER`: **`com.akarworks.zamera`**
  - iOS minimum sürüm: **iOS 17.0** (Apple Log, ProRAW ve fiziksel lens API'leri)
  - Android minimum sürüm: **minSdk 29 (Android 10)**, **compileSdk / targetSdk 36** ve **16 KB page-size** native hizalama uyumu.

## ADR-5: Birleşik Dört Mod (Sanat + Pro Foto + Portre + Pro Video) ve Zamera Cine Ayrıştırmasının İptali
- **Durum:** Revize Edildi (16.11.2026 — Zamera Cine yan uygulama fikri iptal edildi)
- **Karar:** Hem Android hem iOS üzerinde **Sanat Modu (Gerçek Renk)**, **Pro Fotoğraf Modu**, **Stüdyo Portre Modu** ve **Pro Sinema Video Modu** tek `com.akarworks.zamera` uygulaması içinde çalışır.
- **Oturum İzolasyonu:** `packages/zamera_video` ayrı bir *Zamera Cine* yan uygulamasına bölünmeyecektir; ancak `CameraOwnershipCoordinator` ile fotoğraf/video kamera oturumu ayrımı korunur ve Pro Sinema (10-bit HLG10 / Apple Log / ProRes 422 HQ / özel `.cube` LUT) doğrudan **Zamera Pro** abonelik değerinin ana parçasıdır.

## ADR-6: Aha-Öncelikli Hibrit Freemium Gelir Modeli (1 Ay Ücretsiz Deneme) ve Sıfır-Telemetri Tahsilat
- **Durum:** Onaylandı (16.11.2026)
- **Karar:**
  - **Sıfır Üçüncü Parti Gelir/Analitik SDK'sı:** Gizlilik taahhüdünü (`privacy.html` & `PrivacyInfo.xcprivacy` *"Data Not Collected"*) korumak için RevenueCat/Adapty vb. dış sunucuya veri gönderen SDK'lar kullanılmaz. Tahsilat yalnızca resmi `in_app_purchase` (`StoreKit 2` + `Google Play Billing`) üzerinden cihaz içi yürütülür.
  - **Planlar:**
    - `com.akarworks.zamera.pro.monthly`: **\$3.99 / ay** (TR: **₺99,99 / ay**), denemesiz giriş ve fiyat çıpası.
    - `com.akarworks.zamera.pro.annual`: **\$19.99 / yıl** (TR: **₺449,99 / yıl**) — **Varsayılan önerilen plan, 30 gün (1 Ay) ücretsiz deneme**.
    - `com.akarworks.zamera.pro.lifetime`: Lansman **\$34.99** / Normal **\$49.99** (TR: Lansman **₺799,99** / Normal **₺1.199,99**), tek seferlik ömür boyu satın alma.
  - **Aha-Öncelikli Kota Politikası:** Donanım Probe, standart JPEG/HEIF Pro Foto, Portre, Rec.709 Video, canlı Sanat A/B perde karşılaştırması ve Sticker önizlemesi ücretsizdir. Günde **1 TrueColor RAW çekimi**, **1 RAW DNG çekim/paylaşımı** ve **3 şeffaf/konturlu PNG Sticker dışa aktarımı** ücretsiz kanca olarak sunulur; kota sonrasında ve doğrudan 24-Yama ColorChecker Kalibrasyonu, Kayıpsız PNG Arşivi, 10-bit Log/ProRes profilleri ile özel `.cube` LUT yüklemede **Zamera Pro** paywall açılır.
