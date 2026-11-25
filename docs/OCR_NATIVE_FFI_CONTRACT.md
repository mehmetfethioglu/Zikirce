# Tahrir Native OCR & Optical Reflow C++/FFI Mimari Sözleşmesi (ADR-028)

## 1. İki Fazlı Çift Modlu Akış

```
Rendered 300 DPI Page PNG (pdfx)
  │
  ▼ [Worker Isolate -> C++17 FFI / Dart Fallback]
NativeDocumentRestorer (tahrir_ocr_native)
  ├── 1. Luminance + Integral-Image Illumination Flattening
  ├── 2. Coarse-to-Fine Projection Deskew (±5.0°)
  ├── 3. O(W*H) Integral Sauvola Binarization -> restored_gray + ink_alpha_mask
  ├── 4. Gutter Analysis (1/2 Column) + InkLine & WordBlob Segmentation
  │
  ├──► Dual Cache:
  │      ├─ OpticalMaskCacheService (150 MB Disk LRU -> alpha_mask.png + WordBlobs)
  │      └─ SQLite v6 scanned_ocr_cache (Kalıcı OCR metin + word_boxes_json + ocr_confidence)
  │
  ├──► Phase 1 Recognition:
  │      ├─ iOS: Apple Vision VNRecognizeTextRequest (.accurate, tr-TR, ar-SA, en-US)
  │      └─ Android: ML Kit TextRecognizer + Zemberek (34,795 roots) + Atlanan Satır -> OpticalInkBlock
  │
  └──► Phase 2 (Android Hibrit Satır Doğrulayıcı):
         ├─ TesseractModelManager: Sabit commit SHA (`e12c65a9...`) üzerinden `tur.traineddata` (7.11 MiB) + `ara.traineddata` (12.02 MiB) SHA-256 doğrulamalı ilk-kullanım arka plan indiricisi (~19.1 MiB, AAB ~98 MB sınırını korur)
         └─ C++ FFI Tesseract 5 LSTM (`cz.adaptech.tesseract4android:4.9.0` -> `dlopen("libtesseract.so")`, `OEM_LSTM_ONLY=1`, `PSM_SINGLE_LINE=7`) + Zemberek Hakem (`OcrEnsembleArbitrator`)
  │
  ▼
ReadingModeHysteresis
  ├─ Kitap başı ortalama güven < 0.78 veya yoğun Latin dışı -> Varsayılan `Baskı Akışı` (OpticalReflowView)
  └─ Tekil sayfa güven < 0.72 -> Sayfa bazlı otomatik `Baskı Akışı`
```

## 2. C ABI Sözleşmesi (`native/tahrir_ocr_native/tahrir_ocr_native.h`)

```c
int32_t tahrir_native_abi_version(void); // returns 2

// Faz 1 — Sayfa Restorasyonu & Optik Segmentasyon
typedef struct TahrirInkLine {
  int32_t x, y, width, height;
  int32_t column_index;
  int32_t baseline_y;
  uint8_t is_paragraph_start;
  uint8_t _pad[3];
} TahrirInkLine;

typedef struct TahrirWordBlob {
  int32_t x, y, width, height;
  int32_t line_index;
  int32_t column_index;
  int32_t baseline_y;
  uint8_t is_paragraph_start;
  uint8_t is_line_end;
  uint8_t _pad[2];
} TahrirWordBlob;

typedef struct TahrirPageRestorationResult {
  int32_t width;
  int32_t height;
  float detected_skew_deg;
  uint8_t* restored_gray;   // width * height
  uint8_t* ink_alpha_mask;  // width * height (0=transparent bg, 255=ink)
  TahrirInkLine* lines;
  int32_t line_count;
  TahrirWordBlob* word_blobs;
  int32_t word_blob_count;
  int32_t column_count;
} TahrirPageRestorationResult;

TahrirPageRestorationResult* tahrir_restore_and_segment_page(
    const uint8_t* rgba_pixels,
    int32_t width,
    int32_t height,
    int32_t sauvola_window,
    float sauvola_k,
    int32_t enable_deskew);

void tahrir_free_page_result(TahrirPageRestorationResult* result);

// Faz 2 — Android Tesseract 5 LSTM Tekil Satır Doğrulayıcı (`dlopen("libtesseract.so")`)
typedef struct TahrirTesseractHandle TahrirTesseractHandle;

typedef struct TahrirTesseractLineResult {
  char* utf8_text;
  int32_t confidence;  // 0..100
  int32_t error_code;  // 0 = OK, <0 = hata
} TahrirTesseractLineResult;

int32_t tahrir_tesseract_is_available(void);
TahrirTesseractHandle* tahrir_tesseract_create(const char* tessdata_dir, const char* languages);
TahrirTesseractLineResult* tahrir_tesseract_recognize_line(
    TahrirTesseractHandle* handle,
    const uint8_t* gray_pixels,
    int32_t width,
    int32_t height,
    int32_t pad_px);
void tahrir_tesseract_free_line_result(TahrirTesseractLineResult* result);
void tahrir_tesseract_destroy(TahrirTesseractHandle* handle);
```

## 3. Sıfır Bellek Sızıntısı (Zero-Leak Ownership) Kuralları

1. **Girdi Tamponları (`rgba_pixels`, `gray_pixels`, UTF-8 yollar):** Dart tarafında `calloc` / `toNativeUtf8()` ile ayrılır ve FFI çağrısı döner dönmez `try { ... } finally { calloc.free(...); }` içinde koşulsuz serbest bırakılır.
2. **Çıktı Tamponları (`TahrirPageRestorationResult*`, `TahrirTesseractLineResult*`, `TahrirTesseractHandle*`):** C++ tarafında ayrılır; Dart piksel/metin verilerini kopyaladıktan hemen sonra `finally { tahrir_free_page_result(...) / tahrir_tesseract_free_line_result(...) / tahrir_tesseract_destroy(...); }` ile serbest bırakılır.
3. **Stateless İş Parçacığı Güvenliği:** C++ fonksiyonları hiçbir global oturum durumu tutmaz; her Worker Isolate kendi `TahrirTesseractHandle*` örneğini açıp kapatır.
4. **UI / `GestureRecognizer` / `ui.Image` Yaşam Döngüsü:** `OpticalReflowView` yüklediği her `dart:ui` `Image` nesnesini `didUpdateWidget` ve `dispose()` içinde `.dispose()` eder; `TextBlockWidget` ise her güncellemede ve `dispose()`'da tüm `TapGestureRecognizer` ve `LongPressGestureRecognizer` örneklerini serbest bırakır.
5. **SHA-256 Model Bütünlüğü (`TesseractModelManager`):** İndirme `.part` geçici dosyasına akar, tam boyut + streaming SHA-256 doğrulamasından geçmeden asla hedef `.traineddata` dosyasına taşınmaz (bozuk dosya anında silinir).

## 4. Çift Katmanlı Önbellek & Prefetch Kuralları

- **Kalıcı SQLite (`scanned_ocr_cache` v6):** `raw_text`, `structured_json`, `word_boxes_json`, `ocr_confidence`, `recommended_mode`, `has_non_latin` sütunlarını kitap içi arama için kalıcı tutar.
- **150 MB Disk LRU (`OpticalMaskCacheService`):** Yalnızca optik şeffaf alfa-maskesi PNG dosyalarını ve `word_blobs` manifestini yönetir; `150 MiB` (`157,286,400` byte) sınırı aşıldığında en eski erişilen sayfaları siler (SQLite OCR metnini asla silmez).
- **İptal Edilebilir Prefetch (`ReaderPrefetchQueue`):** Öncelik sırası `[P, P+1, P+2, P+3, P-1]`'dir. Kullanıcı hızlı sayfa atladığında monoton `_generation` sayacı artırılarak eski sayfa işleri iptal edilir ve aktif sayfaya anında öncelik verilir.
