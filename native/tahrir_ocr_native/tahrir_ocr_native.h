#ifndef TAHRIR_OCR_NATIVE_H
#define TAHRIR_OCR_NATIVE_H

#include <stdint.h>

#ifdef _WIN32
#define TAHRIR_API __declspec(dllexport)
#else
#define TAHRIR_API __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TahrirInkLine {
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
  int32_t column_index;
  int32_t baseline_y;
  uint8_t is_paragraph_start;
  uint8_t _pad[3];
} TahrirInkLine;

typedef struct TahrirWordBlob {
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
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
  uint8_t* restored_gray;
  uint8_t* ink_alpha_mask;
  TahrirInkLine* lines;
  int32_t line_count;
  TahrirWordBlob* word_blobs;
  int32_t word_blob_count;
  int32_t column_count;
} TahrirPageRestorationResult;

TAHRIR_API int32_t tahrir_native_abi_version(void);

TAHRIR_API TahrirPageRestorationResult* tahrir_restore_and_segment_page(
    const uint8_t* rgba_pixels,
    int32_t width,
    int32_t height,
    int32_t sauvola_window,
    float sauvola_k,
    int32_t enable_deskew);

TAHRIR_API void tahrir_free_page_result(TahrirPageRestorationResult* result);

typedef struct TahrirTesseractHandle TahrirTesseractHandle;

typedef struct TahrirTesseractLineResult {
  char* utf8_text;
  int32_t confidence;
  int32_t error_code;
} TahrirTesseractLineResult;

TAHRIR_API int32_t tahrir_tesseract_is_available(void);

TAHRIR_API TahrirTesseractHandle* tahrir_tesseract_create(
    const char* tessdata_dir,
    const char* languages);

TAHRIR_API TahrirTesseractLineResult* tahrir_tesseract_recognize_line(
    TahrirTesseractHandle* handle,
    const uint8_t* gray_pixels,
    int32_t width,
    int32_t height,
    int32_t pad_px);

TAHRIR_API void tahrir_tesseract_free_line_result(
    TahrirTesseractLineResult* result);

TAHRIR_API void tahrir_tesseract_destroy(TahrirTesseractHandle* handle);

#ifdef __cplusplus
}
#endif

#endif  // TAHRIR_OCR_NATIVE_H
