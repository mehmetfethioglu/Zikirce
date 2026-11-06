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

## ADR-5: İki Platformda Çift Mod (Sanat Modu + Pro Mod) ve Pro Video İzolasyonu
- **Durum:** Onaylandı (06.11.2026)
- **Karar:** Hem Android (Xiaomi 17 Pro Max vb.) hem iOS (iPhone 17 Pro Max vb.) üzerinde **Sanat Modu (Gerçek Renk)** ve **Pro Fotoğraf Modu** tam özellikli çalışır.
- **Pro Video İzolasyonu:** Pro Video özelliği sistemden çıkarılmaz; `packages/zamera_video` altında **ayrı bir paket ve ayrı bir kamera oturumu** olarak izole edilir. `--dart-define=ZAMERA_VIDEO=false` derleme bayrağıyla Faz 3'e kadar devre dışı tutulabilir ve gerekirse 1–2 hafta içinde **"Zamera Cine"** adlı kardeş uygulamaya ayrılabilir.
