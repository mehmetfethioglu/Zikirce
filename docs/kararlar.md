# OrganicScore — Mimari Karar & Anti-Pattern Defteri (kararlar.md)

- **2026-10-30 | ADR-012 — 3D Karakter & Hayali RPG Unsurlarının İptali, Gerçek Helal & Temiz Beslenme Rehberine Geçiş:**
  - **Karar:** Kalite beklentisini karşılamayan 3D karakter sahnesi (`webview_flutter` / `<model-viewer>`), sahte adım artırma butonları (`+500`/`+1000 adım`), hayali kristal/enerji sayaçları ve RPG canavar düelloları kaldırıldı.
  - **Uygulama:** `assets/data/e_numbers.json` 35 gerçek E-kodu ve Helal/kaynak hükümleriyle (`E120 Karmin`, `E441 Jelatin`, `E471 Mono/Digliseridler`, `E542`, `E904`, `E920` vb.) genişletildi (SQLite v11). `OrganicScoreCalculator.evaluateHalalAndCleanStatus` ile deterministik Helal ve Temiz Etiket analizi eklendi; 4 ana ekran tamamen gerçek SQLite ve OCR verileriyle çalışacak şekilde yeniden inşa edildi.
