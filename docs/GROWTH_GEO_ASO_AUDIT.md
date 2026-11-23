# Zamera — ASO, Teknik SEO & GEO (AI Arama Görünürlüğü) Denetim Raporu

- **Tarih:** 2026-11-23 UTC
- **Proje:** `zamera` (`v0.1.6+7`)
- **GEO Skoru (ChatGPT / Perplexity / Claude / Gemini):** **88.5/100 (Excellent (A))**
- **ASO Skoru (App Store & Google Play TR / EN Metin & Yapı):** **83.0/100 (B)** — `title_subtitle: 100/100`, `description: 100/100`, `issues: []`
- **Citability (Alıntılanabilirlik) Skoru:** **82/100 (A)** (`llms.txt` "What is Zamera?" bloğu: **143 kelime**)

## 1. Üretilen Agentic Web & GEO Varlıkları
- `llms.txt`: `app_store_privacy_support/llms.txt` & `docs/llms.txt` (Format Geçerli: `True`, Skor: `100/100`)
- `llms-full.txt`: `app_store_privacy_support/llms-full.txt` & `docs/llms-full.txt`
- `robots.txt`: `app_store_privacy_support/robots.txt` & `docs/robots.txt` (İzin Verilen AI Botları: `8/8`)
- `schema-software-app.json`: `app_store_privacy_support/schema-software-app.json` & `docs/schema-software-app.json` (`SoftwareApplication` + 4 `Offer` + `FAQPage` JSON-LD)
- `sitemap.xml` & `index.html` / `privacy.html` / `support.html` / `indir.html`: Tüm portallar `v0.1.6` ve `StoreKit 2` / `Google Play Billing` sıfır-telemetri maddeleriyle eşitlendi.

## 2. Apple App Store (`app/ios/fastlane/metadata/`)
- **Türkçe (`tr`):**
  - **Ad (`29/30` krk):** `Zamera: Pro Kamera, RAW, Renk`
  - **Alt Başlık (`28/30` krk):** `DSLR Manuel, Video & Sticker`
  - **Anahtar Kelimeler (`96/100` UTF-8 bayt, 0 tekrar):** `sanat,dng,portre,kalibrasyon,log,sinema,lut,bokeh,iso,enstantane,çıkartma,stüdyo,pozlama,pasm`
  - **Tanıtım Metni (`164/170` krk):** `Sanat Modu (ΔE00 ≤ 1.0), 14-bit RAW DSLR, 10-bit Sinema Video ve Şeffaf PNG Sticker Stüdyosu tek uygulamada. Zamera Pro'yu 1 ay ücretsiz deneyin; sıfır veri takibi!`
  - **Açıklama:** `2319/4000` krk
- **İngilizce (`en-US`):**
  - **Name (`30/30` krk):** `Zamera: Pro Camera, RAW, Color`
  - **Subtitle (`30/30` krk):** `Manual DSLR, Cinema & Stickers`
  - **Keywords (`98/100` UTF-8 bytes, 0 overlap):** `art,dng,proraw,portrait,bokeh,log,prores,lut,video,pasm,iso,shutter,cutout,png,colorchecker,studio`
  - **Promotional Text (`155/170` chars):** `True-color ΔE00 Art Mode, 14-bit RAW DSLR, 10-bit Cinema Video & Transparent PNG Sticker Studio in one zero-telemetry app. Try Zamera Pro free for 1 month!`
  - **Description:** `2466/4000` chars

## 3. Google Play Store (`app/android/fastlane/metadata/android/`)
- **Türkçe (`tr-TR`):**
  - **Başlık (`29/30` krk):** `Zamera: Pro Kamera, RAW, Renk`
  - **Kısa Açıklama (`79/80` krk):** `Gerçek renk ΔE00 Sanat Modu, 14-bit RAW DSLR, 10-bit Sinema Video & PNG Sticker`
  - **Tam Açıklama:** `2487/4000` krk
  - **Sürüm Notu (`whatsnew-tr-TR`):** `470/500` krk
  - **Görseller:** `icon.png` (`512x512` PNG), `featureGraphic.png` (`1024x500` PNG)
- **İngilizce (`en-US`):**
  - **Title (`30/30` krk):** `Zamera: Pro Camera, RAW, Color`
  - **Short Description (`78/80` krk):** `True-color ΔE00 Art Mode, 14-bit RAW DSLR, 10-bit Pro Video & Transparent PNGs`
  - **Full Description:** `2589/4000` chars
  - **Release Notes (`whatsnew-en-US`):** `478/500` chars
  - **Graphics:** `icon.png` (`512x512` PNG), `featureGraphic.png` (`1024x500` PNG)

## 4. Açık Kalan Dönüşüm Fırsatı (`Visual Assets`)
- Canlı cihaz ekran görüntüleri (`phoneScreenshots`, min. 2 adet) ve 9:16 sessiz önizleme videosu mağaza paneline eklendiğinde `visual_assets` puanı `60/100 → 100/100`, toplam ASO skoru ise **95+/100 (A)** seviyesine çıkar.
- **CRO & Paywall İlkesi:** Kullanıcı ilk değer anını (günlük ücretsiz 1 TrueColor çekimi, 1 DNG RAW veya 3 şeffaf PNG sticker) deneyimlemeden paywall açılmaz.
