# Zamera — Gerçek Renk (Sanat Modu) & Profesyonel Kamera (Pro Foto / Video)

Zamera, hem **Android** (Xiaomi 17 Pro Max vb.) hem **iOS** (iPhone 17 Pro Max vb.) üzerinde **Sanat Modu (Gerçek Renk $\Delta E_{00}$ Kalibrasyonu)** ve **Pro Kamera Modu (Fiziksel Lens Kilidi, Bayer RAW / ProRAW, Manuel Pozlama)** sunan çapraz platform profesyonel kamera uygulamasıdır.

## Monorepo Yapısı

- [`app/`](app/) — Flutter UI (`com.akarworks.zamera`): Faz 0 Probe ekranı, Sanat Modu ($\Delta E_{00}$) ve Pro Foto/Video kontrol arayüzü.
- [`packages/zamera_capture/`](packages/zamera_capture/) — Native kamera eklentisi:
  - Android: [`ZameraCapturePlugin.kt`](packages/zamera_capture/android/src/main/kotlin/com/akarworks/zamera_capture/ZameraCapturePlugin.kt) (`Camera2` donanım seviyesi, fiziksel lens ID'leri, `RAW_SENSOR`, 50MP `ULTRA_HIGH_RESOLUTION_SENSOR`, 10-bit `HLG10` probe ve JNI Rust köprüsü).
  - iOS: [`ZameraCapturePlugin.swift`](packages/zamera_capture/ios/Classes/ZameraCapturePlugin.swift) (`AVFoundation` ayrık fiziksel lensler 13mm/24mm/100mm, Bayer RAW vs ProRAW, Apple Log, Open Gate 4:3 probe).
- [`packages/zamera_video/`](packages/zamera_video/) — İzole Pro Video modülü (`--dart-define=ZAMERA_VIDEO=false` ile Faz 3'e kadar yalıtılmış; gerekirse *Zamera Cine* yan uygulamasına taşınabilir).
- [`rust/zamera_core/`](rust/zamera_core/) — Ortak Rust renk bilimi motoru (Sharma 2005 doğrulanmış CIEDE2000 $\Delta E_{00}$, Bradford D50→D65, CIE XYZ→sRGB/Display P3 OETF ve `cargo-deny` sıfır-GPL lisans politikası).
- [`.github/workflows/`](.github/workflows/) — Bulut derleme ve mağaza dağıtım iş akışları (`ci.yml`, `android-release.yml`, `ios-release.yml`).
- [`docs/`](docs/) — [Araştırma ve Mimari Raporu](docs/ARASTIRMA_RAPORU.md), [Mimari Kararlar (ADR)](docs/kararlar.md) ve [Cihaz Yetenek Dökümleri](docs/cihaz_yetenekleri/README.md).
