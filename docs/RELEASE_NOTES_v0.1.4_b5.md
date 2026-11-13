# Zamera v0.1.4 (Build 5) — Çift Dilli Mağaza Sürüm Notları (Google Play & App Store Connect)

## 1. Google Play Console (`<500` Karakter)

### Türkçe (`tr-TR`)
```text
Zamera v0.1.4:
• Sanat Modu Pozlama Düzeltmesi: ΔE00 renk doğruluğu ve ton açısı (hue) %100 korunarak karanlık kalan 1:1 TON RAW çekimler sahne-doğrusal radyometrik referansla gerçek parlaklığına kavuşturuldu.
• Vernik/Cam Parlama Koruması: Noktasal yansımaların pozlamayı kilitlemesi önlendi; sabit-tonlu parlak alan geçişi iyileştirildi.
• Portre & Denetçi: Sahne ışığı maskesi, şeffaf PNG pano çıkartması ve dokunarak piksel renk ölçümü geliştirildi.
```

### English (`en-US`)
```text
Zamera v0.1.4:
• Art Mode Exposure Fix: Restored true scene-linear brightness in 1:1 Tone RAW captures via radiometric midtone matching while preserving 100% of ΔE00 color accuracy, hue, and dark chiaroscuro tones.
• Specular Glint Immunity: Isolated varnish/glass reflections from locking down exposure and refined the constant-hue highlight shoulder.
• Portrait & Inspector: Improved Stage Light mask, clipboard PNG cutout workflow, and tap pixel colorimetry.
```

---

## 2. Apple App Store Connect & TestFlight (`v0.1.4` — Build `5`)

### Türkçe (`tr`)
- **Sanat Modu 1:1 Radyometrik Pozlama Düzeltmesi:** `1:1 TON` ve `KAĞIT L*94` çekimlerinde ΔE00 renk doğruluğu, CIE `(x, y)` kromatisitesi ve koyu (chiaroscuro) tonlar %100 korunarak karanlık kalan RAW pozlama, aynı deklanşör anındaki sahne-doğrusal orta-ton (`[p15..p85]`) ve `BaselineExposure` / `POST_RAW_SENSITIVITY_BOOST` radyometrik referansıyla gerçek sahne parlaklığına kavuşturuldu.
- **Vernik & Cam Parlama Koruması:** Sanat eserindeki `<%4` noktasal yansımaların pozlamayı kilitlemesi `p96` difüz pigment tavanıyla önlendi ve `L* ≈ 96` sabit-tonlu parlak alan geçişi iyileştirildi.
- **iOS Vizör Kararlılığı:** iOS kamera oturumu başlatma ve lens geçişleri sırasındaki canlı vizör görüntü akışı kararlılığı iyileştirildi.
- **Stüdyo Portre & Çekim Denetçisi:** Sahne Işığı arka plan kesme maskesi, şeffaf PNG çıkartmasını doğrudan panoya kopyalama akışı ve çekim denetçisinde dokunarak piksel CIE `L*a*b*` / `#HEX` renk ölçümü geliştirildi.

### English (`en-US`)
- **Art Mode 1:1 Radiometric Exposure Fix:** Restored true scene-linear brightness in `1:1 Tone` and `Paper L*94` RAW captures via synchronized `[p15..p85]` trimmed radiometric midtone matching and `BaselineExposure` / `POST_RAW_SENSITIVITY_BOOST` gain recovery, while preserving 100% of ΔE00 color accuracy, hue, and dark chiaroscuro tones.
- **Specular Glint Immunity:** Prevented `<4%` varnish, glass, or frame glints from locking down exposure via diffuse `p96` pigment capping and refined the `L* ≈ 96` constant-hue highlight shoulder.
- **iOS Viewfinder Stability:** Improved live camera viewfinder feed stability across iOS session startup and lens switches.
- **Portrait Studio & Capture Inspector:** Refined Stage Light backdrop cutout mask, clipboard-first transparent PNG cutout workflow, and tap-to-measure CIE `L*a*b*` / `#HEX` pixel colorimetry in Capture Inspector.
