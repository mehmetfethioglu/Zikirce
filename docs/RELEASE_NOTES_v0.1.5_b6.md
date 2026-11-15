# Zamera v0.1.5 (Build 6) — Çift Dilli Mağaza Sürüm Notları (Google Play & App Store Connect)

## 1. Google Play Console (`<500` Karakter)

### Türkçe (`tr-TR`)
```text
Zamera v0.1.5:
• Şeffaf Sticker Kesimi: Siyah arka plan hatası ve ön kamera dokunuş sapması giderildi; ML Kit & U²-Net hibrit motoruyla seçilen nesne %100 şeffaf veya beyaz konturlu PNG olarak kesilir.
• Pro Media & Sticker Stüdyosu: Tam ekran galeri, film şeridi, 6 filtreli arşiv, Sticker Rafı, TrueColor/Portre A/B perde karşılaştırması, 64-bin RGB histogram, RAW paylaşımı ve SMPTE video oynatıcı eklendi.
```

### English (`en-US`)
```text
Zamera v0.1.5:
• True Transparent Sticker Cutout: Fixed black background & front-camera mirror tap offset; hybrid ML Kit & U²-Net engine isolates tapped subjects as 100% transparent or white-outlined PNGs.
• Pro Media & Sticker Studio: Full-screen gallery, filmstrip, 6-filter archive, Sticker Shelf, TrueColor/Portrait A/B split curtain, 64-bin RGB histogram, RAW share, and SMPTE video player with frame grab.
```

---

## 2. Apple App Store Connect & TestFlight (`v0.1.5` — Build `6`)

### Türkçe (`tr`)
- **Kusursuz %100 Şeffaf Sticker Kesimi:** Şeffaf arka planın siyah (`#000000`) PNG olarak dışa aktarılmasına yol açan bitmap/pano alfa kaybı ve ön kamera dokunuş sapması giderildi; Android'de ML Kit Subject Segmentation + U²-Net bağlı-nesne motoru, iOS'ta ise unpremultiplied RGBA/alpha daraltmalı kırpma, kenar RGB dekontaminasyonu ve `UTType.png` panoya şeffaf kopyalama desteği sunuldu.
- **Beyaz Konturlu Sticker Modu:** Sticker Stüdyosu'nda dama tahtası şeffaflık zemini üzerinde `Saf Şeffaf` veya yumuşak gölgeli `Beyaz Konturlu Sticker` önizleme, tek dokunuşta kopyalama ve paylaşım seçenekleri eklendi.
- **Tam Ekran Pro Media & Sticker Stüdyosu (`#07090D`):** Yakınlaştırmalı medya görüntüleyici, alt film şeridi, 6 filtreli 3 sütunlu arşiv ızgarası (`Tümü`, `Fotoğraf`, `Video`, `Portre`, `RAW`, `Sticker'larım`) ve tek dokunuşla kopyalanabilen kalıcı Sticker Rafı eklendi.
- **Profesyonel Analiz & Sinema Video Oynatıcı:** `TrueColor 1:1 ↔ Stok OEM` / `Portre ↔ Orijinal` split A/B perde karşılaştırması, CIE `L*a*b* (D50)` / `ΔE00` kolorimetre büyüteci, 64-bin RGB/Luma histogramı, ayrı JPEG/RAW (`.DNG`) paylaşımı ile SMPTE (`HH:MM:SS:FF`) zaman kodlu, `0.5x/1x/2x` hızlı, kare yakalamalı ve kareden sticker kesmeli sinema video oynatıcı eklendi.

### English (`en-US`)
- **True 100% Transparent Sticker Cutout:** Fixed alpha-loss causing solid `#000000` PNG exports and clipboard opacity, plus front-camera mirror tap inversion; upgraded Android with hybrid ML Kit Subject Segmentation + U²-Net connected-subject isolation and iOS with tight-cropped edge-decontaminated RGBA output and `UTType.png` transparent clipboard copy.
- **White-Outlined Sticker Mode:** Added `StickerStudioSheet` over a transparency checkerboard with `Saf Şeffaf` (pure transparent) and soft-shadowed `Beyaz Konturlu Sticker` modes, 1-tap copy, and native share.
- **Full-Screen Pro Media & Sticker Studio (`#07090D`):** Added zoomable viewer, synced bottom filmstrip, 6-filter 3-column archive grid (`Tümü`, `Fotoğraf`, `Video`, `Portre`, `RAW`, `Sticker'larım`), and persistent Sticker Shelf.
- **Pro Analysis & Cinema Video Player:** Added `TrueColor 1:1 vs OEM` and `Portrait vs Original` split A/B curtain, CIE `L*a*b* (D50)` / `ΔE00` colorimeter loupe, 64-bin RGB/Luma histogram, separate JPEG / RAW (`.DNG`) sharing, and SMPTE (`HH:MM:SS:FF`) video player (`0.5x/1x/2x` speed, Pro Video telemetry, frame grab, and cut-sticker-from-frame).
