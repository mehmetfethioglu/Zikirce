#include "tahrir_ocr_native.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

#if !defined(_WIN32)
#include <dlfcn.h>
#include <mutex>
#include <string>
#endif

namespace {

constexpr double kPi = 3.14159265358979323846;

inline int ClampInt(int v, int lo, int hi) {
  return v < lo ? lo : (v > hi ? hi : v);
}

inline uint8_t ClampU8(int v) {
  return static_cast<uint8_t>(v < 0 ? 0 : (v > 255 ? 255 : v));
}

void BuildIntegralImages(
    const std::vector<uint8_t>& gray,
    int width,
    int height,
    std::vector<int64_t>& sum,
    std::vector<int64_t>& sum_sq) {
  const int stride = width + 1;
  sum.assign(static_cast<size_t>(stride) * (height + 1), 0);
  sum_sq.assign(static_cast<size_t>(stride) * (height + 1), 0);

  for (int y = 1; y <= height; ++y) {
    int64_t row_sum = 0;
    int64_t row_sq = 0;
    const uint8_t* src_row = &gray[static_cast<size_t>(y - 1) * width];
    int64_t* prev_sum = &sum[static_cast<size_t>(y - 1) * stride];
    int64_t* cur_sum = &sum[static_cast<size_t>(y) * stride];
    int64_t* prev_sq = &sum_sq[static_cast<size_t>(y - 1) * stride];
    int64_t* cur_sq = &sum_sq[static_cast<size_t>(y) * stride];

    for (int x = 1; x <= width; ++x) {
      const int64_t val = src_row[x - 1];
      row_sum += val;
      row_sq += val * val;
      cur_sum[x] = prev_sum[x] + row_sum;
      cur_sq[x] = prev_sq[x] + row_sq;
    }
  }
}

inline double RegionMean(
    const std::vector<int64_t>& sum,
    int stride,
    int x0,
    int y0,
    int x1,
    int y1) {
  const int64_t total = sum[static_cast<size_t>(y1) * stride + x1] -
                        sum[static_cast<size_t>(y0) * stride + x1] -
                        sum[static_cast<size_t>(y1) * stride + x0] +
                        sum[static_cast<size_t>(y0) * stride + x0];
  const int area = (x1 - x0) * (y1 - y0);
  return area > 0 ? static_cast<double>(total) / static_cast<double>(area) : 255.0;
}

void FlattenIllumination(
    std::vector<uint8_t>& gray,
    int width,
    int height) {
  std::vector<int64_t> sum;
  std::vector<int64_t> sum_sq;
  BuildIntegralImages(gray, width, height, sum, sum_sq);

  const int radius = ClampInt(std::min(width, height) / 14, 18, 64);
  const int stride = width + 1;
  std::vector<uint8_t> flattened(gray.size(), 255);

  for (int y = 0; y < height; ++y) {
    const int y0 = std::max(0, y - radius);
    const int y1 = std::min(height, y + radius + 1);
    for (int x = 0; x < width; ++x) {
      const int x0 = std::max(0, x - radius);
      const int x1 = std::min(width, x + radius + 1);
      const double local_bg = std::max(32.0, RegionMean(sum, stride, x0, y0, x1, y1));
      const double px = static_cast<double>(gray[static_cast<size_t>(y) * width + x]);
      const double normalized = (px * 242.0) / local_bg;
      flattened[static_cast<size_t>(y) * width + x] =
          ClampU8(static_cast<int>(normalized + 0.5));
    }
  }
  gray.swap(flattened);
}

double ProjectionEnergyForAngle(
    const std::vector<uint8_t>& gray,
    int width,
    int height,
    double angle_deg,
    int step) {
  const double rad = angle_deg * kPi / 180.0;
  const double sin_a = std::sin(rad);
  const double cos_a = std::cos(rad);
  const int cx = width / 2;
  const int cy = height / 2;

  std::vector<int> row_proj(height, 0);
  for (int y = 0; y < height; y += step) {
    for (int x = 0; x < width; x += step) {
      const uint8_t v = gray[static_cast<size_t>(y) * width + x];
      if (v >= 170) continue;
      const int dx = x - cx;
      const int dy = y - cy;
      const int ry = static_cast<int>(std::lround(-dx * sin_a + dy * cos_a)) + cy;
      if (ry >= 0 && ry < height) {
        row_proj[ry] += (200 - v);
      }
    }
  }

  double energy = 0.0;
  for (int v : row_proj) {
    const double dv = static_cast<double>(v);
    energy += dv * dv;
  }
  return energy;
}

float EstimateAndDeskew(
    std::vector<uint8_t>& gray,
    int width,
    int height) {
  if (width < 40 || height < 40) return 0.0f;

  const int sample_step = ClampInt(std::min(width, height) / 360, 1, 4);
  double best_angle = 0.0;
  double best_energy = -1.0;

  for (double angle = -5.0; angle <= 5.001; angle += 0.5) {
    const double energy = ProjectionEnergyForAngle(gray, width, height, angle, sample_step);
    if (energy > best_energy) {
      best_energy = energy;
      best_angle = angle;
    }
  }

  const double center = best_angle;
  for (double angle = center - 0.6; angle <= center + 0.601; angle += 0.15) {
    const double energy = ProjectionEnergyForAngle(gray, width, height, angle, sample_step);
    if (energy > best_energy) {
      best_energy = energy;
      best_angle = angle;
    }
  }

  if (std::fabs(best_angle) < 0.35) {
    return 0.0f;
  }

  const double rad = -best_angle * kPi / 180.0;
  const double cos_a = std::cos(rad);
  const double sin_a = std::sin(rad);
  const double cx = width * 0.5;
  const double cy = height * 0.5;

  std::vector<uint8_t> rotated(gray.size(), 255);
  for (int y = 0; y < height; ++y) {
    const double dy = y - cy;
    for (int x = 0; x < width; ++x) {
      const double dx = x - cx;
      const double sx = dx * cos_a - dy * sin_a + cx;
      const double sy = dx * sin_a + dy * cos_a + cy;
      const int x0 = static_cast<int>(std::floor(sx));
      const int y0 = static_cast<int>(std::floor(sy));
      if (x0 < 0 || y0 < 0 || x0 + 1 >= width || y0 + 1 >= height) {
        continue;
      }
      const double fx = sx - x0;
      const double fy = sy - y0;
      const size_t idx00 = static_cast<size_t>(y0) * width + x0;
      const double p00 = gray[idx00];
      const double p10 = gray[idx00 + 1];
      const double p01 = gray[idx00 + width];
      const double p11 = gray[idx00 + width + 1];
      const double top = p00 + (p10 - p00) * fx;
      const double bot = p01 + (p11 - p01) * fx;
      rotated[static_cast<size_t>(y) * width + x] =
          ClampU8(static_cast<int>(top + (bot - top) * fy + 0.5));
    }
  }
  gray.swap(rotated);
  return static_cast<float>(best_angle);
}

void ApplySauvolaBinarization(
    const std::vector<uint8_t>& gray,
    int width,
    int height,
    int window_size,
    float sauvola_k,
    std::vector<uint8_t>& out_gray,
    std::vector<uint8_t>& out_alpha) {
  std::vector<int64_t> sum;
  std::vector<int64_t> sum_sq;
  BuildIntegralImages(gray, width, height, sum, sum_sq);

  const int half = std::max(4, window_size / 2);
  const int stride = width + 1;
  out_gray.assign(gray.size(), 255);
  out_alpha.assign(gray.size(), 0);

  for (int y = 0; y < height; ++y) {
    const int y0 = std::max(0, y - half);
    const int y1 = std::min(height, y + half + 1);
    for (int x = 0; x < width; ++x) {
      const int x0 = std::max(0, x - half);
      const int x1 = std::min(width, x + half + 1);
      const double area = static_cast<double>((x1 - x0) * (y1 - y0));
      const int64_t s1 = sum[static_cast<size_t>(y1) * stride + x1] -
                         sum[static_cast<size_t>(y0) * stride + x1] -
                         sum[static_cast<size_t>(y1) * stride + x0] +
                         sum[static_cast<size_t>(y0) * stride + x0];
      const int64_t s2 = sum_sq[static_cast<size_t>(y1) * stride + x1] -
                         sum_sq[static_cast<size_t>(y0) * stride + x1] -
                         sum_sq[static_cast<size_t>(y1) * stride + x0] +
                         sum_sq[static_cast<size_t>(y0) * stride + x0];
      const double mean = static_cast<double>(s1) / area;
      const double variance = std::max(0.0, (static_cast<double>(s2) / area) - mean * mean);
      const double stddev = std::sqrt(variance);
      const double threshold = mean * (1.0 + static_cast<double>(sauvola_k) * (stddev / 128.0 - 1.0));
      const double px = static_cast<double>(gray[static_cast<size_t>(y) * width + x]);
      const double soft_band = 24.0;
      const double strength = (threshold + soft_band * 0.45 - px) / soft_band;
      if (strength > 0.0) {
        const double clamped = std::min(1.0, strength);
        const uint8_t alpha = ClampU8(static_cast<int>(clamped * 255.0 + 0.5));
        out_alpha[static_cast<size_t>(y) * width + x] = alpha;
        out_gray[static_cast<size_t>(y) * width + x] = ClampU8(255 - alpha);
      }
    }
  }

  // Suppress 1-pixel salt/speckle noise without eroding glyphs.
  std::vector<uint8_t> cleaned_alpha = out_alpha;
  for (int y = 1; y < height - 1; ++y) {
    for (int x = 1; x < width - 1; ++x) {
      const size_t idx = static_cast<size_t>(y) * width + x;
      if (out_alpha[idx] == 0) continue;
      int ink_neighbors = 0;
      for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
          if (dx == 0 && dy == 0) continue;
          if (out_alpha[static_cast<size_t>(y + dy) * width + (x + dx)] >= 64) {
            ++ink_neighbors;
          }
        }
      }
      if (ink_neighbors == 0) {
        cleaned_alpha[idx] = 0;
        out_gray[idx] = 255;
      }
    }
  }
  out_alpha.swap(cleaned_alpha);
}

struct ColSpan {
  int x0;
  int x1;
  int index;
};

void DetectColumnsAndSegment(
    const std::vector<uint8_t>& alpha,
    int width,
    int height,
    int& out_column_count,
    std::vector<TahrirInkLine>& out_lines,
    std::vector<TahrirWordBlob>& out_blobs) {
  out_lines.clear();
  out_blobs.clear();

  const int min_margin_x = std::max(2, width / 60);
  const int max_margin_x = std::min(width - 2, width - min_margin_x);
  const int min_margin_y = std::max(2, height / 80);
  const int max_margin_y = std::min(height - 2, height - min_margin_y);

  // Detect optional two-column gutter inside central 35%..65% width band.
  std::vector<int> col_ink(width, 0);
  for (int y = min_margin_y; y < max_margin_y; ++y) {
    for (int x = min_margin_x; x < max_margin_x; ++x) {
      if (alpha[static_cast<size_t>(y) * width + x] >= 80) {
        ++col_ink[x];
      }
    }
  }

  const int gutter_start = static_cast<int>(width * 0.36);
  const int gutter_end = static_cast<int>(width * 0.64);
  int best_run_start = -1;
  int best_run_len = 0;
  int cur_run_start = -1;
  const int quiet_thresh = std::max(2, height / 180);

  for (int x = gutter_start; x <= gutter_end; ++x) {
    if (col_ink[x] <= quiet_thresh) {
      if (cur_run_start < 0) cur_run_start = x;
      const int len = x - cur_run_start + 1;
      if (len > best_run_len) {
        best_run_len = len;
        best_run_start = cur_run_start;
      }
    } else {
      cur_run_start = -1;
    }
  }

  std::vector<ColSpan> columns;
  const int min_gutter_px = std::max(10, width / 32);
  if (best_run_len >= min_gutter_px && best_run_start > 0) {
    const int gutter_mid = best_run_start + best_run_len / 2;
    columns.push_back({min_margin_x, gutter_mid - 1, 0});
    columns.push_back({gutter_mid + 1, max_margin_x, 1});
    out_column_count = 2;
  } else {
    columns.push_back({min_margin_x, max_margin_x, 0});
    out_column_count = 1;
  }

  for (const ColSpan& col : columns) {
    std::vector<int> row_ink(height, 0);
    for (int y = min_margin_y; y < max_margin_y; ++y) {
      int count = 0;
      for (int x = col.x0; x <= col.x1; ++x) {
        if (alpha[static_cast<size_t>(y) * width + x] >= 80) {
          ++count;
        }
      }
      row_ink[y] = count;
    }

    int prev_line_bottom = -1;
    int col_left_edge = col.x1;
    std::vector<TahrirInkLine> col_lines;

    int y = min_margin_y;
    while (y < max_margin_y) {
      while (y < max_margin_y && row_ink[y] < 2) {
        ++y;
      }
      if (y >= max_margin_y) break;
      const int y0 = y;
      while (y < max_margin_y && (row_ink[y] >= 2 || (y + 1 < max_margin_y && row_ink[y + 1] >= 2))) {
        ++y;
      }
      const int y1 = y - 1;
      const int line_h = y1 - y0 + 1;
      if (line_h < 3 || line_h > height / 4) {
        continue;
      }

      int line_x0 = col.x1;
      int line_x1 = col.x0;
      for (int ly = y0; ly <= y1; ++ly) {
        for (int lx = col.x0; lx <= col.x1; ++lx) {
          if (alpha[static_cast<size_t>(ly) * width + lx] >= 80) {
            if (lx < line_x0) line_x0 = lx;
            if (lx > line_x1) line_x1 = lx;
          }
        }
      }
      if (line_x1 <= line_x0) continue;
      if (line_x0 < col_left_edge) col_left_edge = line_x0;

      TahrirInkLine line{};
      line.x = ClampInt(line_x0 - 1, 0, width - 1);
      line.y = ClampInt(y0 - 1, 0, height - 1);
      line.width = ClampInt(line_x1 - line.x + 2, 1, width - line.x);
      line.height = ClampInt(y1 - line.y + 2, 1, height - line.y);
      line.column_index = col.index;
      line.baseline_y = y1;
      const int vertical_gap = prev_line_bottom >= 0 ? (y0 - prev_line_bottom) : (line_h * 2);
      line.is_paragraph_start =
          (col_lines.empty() || vertical_gap > static_cast<int>(line_h * 0.72)) ? 1 : 0;
      prev_line_bottom = y1;
      col_lines.push_back(line);
    }

    for (size_t li = 0; li < col_lines.size(); ++li) {
      TahrirInkLine& line = col_lines[li];
      if (line.x - col_left_edge > static_cast<int>(line.height * 0.9)) {
        line.is_paragraph_start = 1;
      }
      const int line_index = static_cast<int>(out_lines.size());
      out_lines.push_back(line);

      std::vector<uint8_t> has_col(line.width, 0);
      for (int lx = 0; lx < line.width; ++lx) {
        const int px = line.x + lx;
        for (int ly = line.y; ly < line.y + line.height; ++ly) {
          if (alpha[static_cast<size_t>(ly) * width + px] >= 75) {
            has_col[lx] = 1;
            break;
          }
        }
      }

      const int word_gap_thresh = std::max(4, static_cast<int>(std::lround(line.height * 0.34)));
      const size_t blob_start_idx = out_blobs.size();
      int lx = 0;
      while (lx < line.width) {
        while (lx < line.width && has_col[lx] == 0) {
          ++lx;
        }
        if (lx >= line.width) break;
        const int bx0 = lx;
        int gap = 0;
        int bx1 = lx;
        while (lx < line.width) {
          if (has_col[lx] != 0) {
            bx1 = lx;
            gap = 0;
          } else {
            ++gap;
            if (gap > word_gap_thresh) {
              break;
            }
          }
          ++lx;
        }

        const int bw = bx1 - bx0 + 1;
        if (bw < 2) continue;
        TahrirWordBlob blob{};
        blob.x = line.x + bx0;
        blob.y = line.y;
        blob.width = bw;
        blob.height = line.height;
        blob.line_index = line_index;
        blob.column_index = line.column_index;
        blob.baseline_y = line.baseline_y;
        blob.is_paragraph_start = (out_blobs.size() == blob_start_idx) ? line.is_paragraph_start : 0;
        blob.is_line_end = 0;
        out_blobs.push_back(blob);
      }
      if (out_blobs.size() > blob_start_idx) {
        out_blobs.back().is_line_end = 1;
      }
    }
  }
}

}  // namespace

extern "C" {

TAHRIR_API int32_t tahrir_native_abi_version(void) {
  return 2;
}

TAHRIR_API TahrirPageRestorationResult* tahrir_restore_and_segment_page(
    const uint8_t* rgba_pixels,
    int32_t width,
    int32_t height,
    int32_t sauvola_window,
    float sauvola_k,
    int32_t enable_deskew) {
  if (rgba_pixels == nullptr || width <= 0 || height <= 0) {
    return nullptr;
  }

  const size_t pixel_count = static_cast<size_t>(width) * static_cast<size_t>(height);
  std::vector<uint8_t> gray(pixel_count, 255);
  for (size_t i = 0; i < pixel_count; ++i) {
    const size_t p = i * 4;
    const int r = rgba_pixels[p];
    const int g = rgba_pixels[p + 1];
    const int b = rgba_pixels[p + 2];
    const int a = rgba_pixels[p + 3];
    if (a < 16) {
      gray[i] = 255;
    } else {
      gray[i] = ClampU8((r * 77 + g * 150 + b * 29) >> 8);
    }
  }

  FlattenIllumination(gray, width, height);

  float detected_skew = 0.0f;
  if (enable_deskew != 0) {
    detected_skew = EstimateAndDeskew(gray, width, height);
  }

  std::vector<uint8_t> restored_gray;
  std::vector<uint8_t> ink_alpha;
  ApplySauvolaBinarization(
      gray,
      width,
      height,
      sauvola_window > 4 ? sauvola_window : 29,
      sauvola_k > 0.0f ? sauvola_k : 0.22f,
      restored_gray,
      ink_alpha);

  int column_count = 1;
  std::vector<TahrirInkLine> lines;
  std::vector<TahrirWordBlob> blobs;
  DetectColumnsAndSegment(ink_alpha, width, height, column_count, lines, blobs);

  auto* result = new TahrirPageRestorationResult();
  result->width = width;
  result->height = height;
  result->detected_skew_deg = detected_skew;
  result->column_count = column_count;

  result->restored_gray = new uint8_t[pixel_count];
  std::memcpy(result->restored_gray, restored_gray.data(), pixel_count);

  result->ink_alpha_mask = new uint8_t[pixel_count];
  std::memcpy(result->ink_alpha_mask, ink_alpha.data(), pixel_count);

  result->line_count = static_cast<int32_t>(lines.size());
  result->lines = lines.empty() ? nullptr : new TahrirInkLine[lines.size()];
  if (!lines.empty()) {
    std::memcpy(result->lines, lines.data(), lines.size() * sizeof(TahrirInkLine));
  }

  result->word_blob_count = static_cast<int32_t>(blobs.size());
  result->word_blobs = blobs.empty() ? nullptr : new TahrirWordBlob[blobs.size()];
  if (!blobs.empty()) {
    std::memcpy(result->word_blobs, blobs.data(), blobs.size() * sizeof(TahrirWordBlob));
  }

  return result;
}

TAHRIR_API void tahrir_free_page_result(TahrirPageRestorationResult* result) {
  if (result == nullptr) return;
  delete[] result->restored_gray;
  delete[] result->ink_alpha_mask;
  delete[] result->lines;
  delete[] result->word_blobs;
  delete result;
}

}  // extern "C"

#if !defined(_WIN32)
namespace {

struct TesseractCapi {
  void* lib_handle = nullptr;
  bool is_loaded = false;

  void* (*create)() = nullptr;
  int (*init2)(void*, const char*, const char*, int) = nullptr;
  void (*set_psm)(void*, int) = nullptr;
  int (*set_variable)(void*, const char*, const char*) = nullptr;
  void (*set_image)(void*, const unsigned char*, int, int, int, int) = nullptr;
  void (*set_source_resolution)(void*, int) = nullptr;
  char* (*get_utf8_text)(void*) = nullptr;
  int (*mean_text_conf)(void*) = nullptr;
  void (*delete_text)(const char*) = nullptr;
  void (*end)(void*) = nullptr;
  void (*del)(void*) = nullptr;
};

const TesseractCapi& GetTesseractCapi() {
  static TesseractCapi capi;
  static std::once_flag once;
  std::call_once(once, []() {
    // Transitive dependencies bundled inside tesseract4android.aar
    dlopen("libjpeg.so", RTLD_LAZY | RTLD_GLOBAL);
    dlopen("libpngx.so", RTLD_LAZY | RTLD_GLOBAL);
    dlopen("libleptonica.so", RTLD_LAZY | RTLD_GLOBAL);

    capi.lib_handle = dlopen("libtesseract.so", RTLD_NOW | RTLD_LOCAL);
    if (capi.lib_handle == nullptr) {
      return;
    }

    capi.create = reinterpret_cast<void* (*)()>(
        dlsym(capi.lib_handle, "TessBaseAPICreate"));
    capi.init2 = reinterpret_cast<int (*)(void*, const char*, const char*, int)>(
        dlsym(capi.lib_handle, "TessBaseAPIInit2"));
    capi.set_psm = reinterpret_cast<void (*)(void*, int)>(
        dlsym(capi.lib_handle, "TessBaseAPISetPageSegMode"));
    capi.set_variable = reinterpret_cast<int (*)(void*, const char*, const char*)>(
        dlsym(capi.lib_handle, "TessBaseAPISetVariable"));
    capi.set_image = reinterpret_cast<void (*)(
        void*, const unsigned char*, int, int, int, int)>(
        dlsym(capi.lib_handle, "TessBaseAPISetImage"));
    capi.set_source_resolution = reinterpret_cast<void (*)(void*, int)>(
        dlsym(capi.lib_handle, "TessBaseAPISetSourceResolution"));
    capi.get_utf8_text = reinterpret_cast<char* (*)(void*)>(
        dlsym(capi.lib_handle, "TessBaseAPIGetUTF8Text"));
    capi.mean_text_conf = reinterpret_cast<int (*)(void*)>(
        dlsym(capi.lib_handle, "TessBaseAPIMeanTextConf"));
    capi.delete_text = reinterpret_cast<void (*)(const char*)>(
        dlsym(capi.lib_handle, "TessDeleteText"));
    capi.end = reinterpret_cast<void (*)(void*)>(
        dlsym(capi.lib_handle, "TessBaseAPIEnd"));
    capi.del = reinterpret_cast<void (*)(void*)>(
        dlsym(capi.lib_handle, "TessBaseAPIDelete"));

    capi.is_loaded = (capi.create != nullptr &&
                      capi.init2 != nullptr &&
                      capi.set_psm != nullptr &&
                      capi.set_image != nullptr &&
                      capi.get_utf8_text != nullptr &&
                      capi.mean_text_conf != nullptr &&
                      capi.delete_text != nullptr &&
                      capi.end != nullptr &&
                      capi.del != nullptr);
  });
  return capi;
}

std::string TrimAsciiWhitespace(const char* raw) {
  if (raw == nullptr) return std::string();
  std::string s(raw);
  const char* ws = " \t\r\n";
  const size_t first = s.find_first_not_of(ws);
  if (first == std::string::npos) return std::string();
  const size_t last = s.find_last_not_of(ws);
  return s.substr(first, last - first + 1);
}

TahrirTesseractLineResult* MakeTesseractErrorResult(int32_t error_code) {
  auto* res = new TahrirTesseractLineResult();
  res->utf8_text = nullptr;
  res->confidence = 0;
  res->error_code = error_code;
  return res;
}

}  // namespace

struct TahrirTesseractHandle {
  void* api = nullptr;
};

extern "C" {

TAHRIR_API int32_t tahrir_tesseract_is_available(void) {
  return GetTesseractCapi().is_loaded ? 1 : 0;
}

TAHRIR_API TahrirTesseractHandle* tahrir_tesseract_create(
    const char* tessdata_dir,
    const char* languages) {
  if (tessdata_dir == nullptr || tessdata_dir[0] == '\0' ||
      languages == nullptr || languages[0] == '\0') {
    return nullptr;
  }
  const auto& capi = GetTesseractCapi();
  if (!capi.is_loaded) {
    return nullptr;
  }

  void* api = capi.create();
  if (api == nullptr) {
    return nullptr;
  }

  // OEM_LSTM_ONLY = 1
  if (capi.init2(api, tessdata_dir, languages, 1) != 0) {
    capi.end(api);
    capi.del(api);
    return nullptr;
  }

  // PSM_SINGLE_LINE = 7
  capi.set_psm(api, 7);
  if (capi.set_variable != nullptr) {
    capi.set_variable(api, "preserve_interword_spaces", "1");
    capi.set_variable(api, "user_defined_dpi", "300");
  }

  auto* handle = new TahrirTesseractHandle();
  handle->api = api;
  return handle;
}

TAHRIR_API TahrirTesseractLineResult* tahrir_tesseract_recognize_line(
    TahrirTesseractHandle* handle,
    const uint8_t* gray_pixels,
    int32_t width,
    int32_t height,
    int32_t pad_px) {
  if (handle == nullptr || handle->api == nullptr || gray_pixels == nullptr ||
      width <= 0 || height <= 0 || width > 8192 || height > 4096) {
    return MakeTesseractErrorResult(-1);
  }
  const auto& capi = GetTesseractCapi();
  if (!capi.is_loaded) {
    return MakeTesseractErrorResult(-2);
  }

  const int32_t pad = ClampInt(pad_px, 0, 32);
  const int32_t padded_w = width + pad * 2;
  const int32_t padded_h = height + pad * 2;
  std::vector<uint8_t> padded(
      static_cast<size_t>(padded_w) * static_cast<size_t>(padded_h), 255);
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t* src_row = &gray_pixels[static_cast<size_t>(y) * width];
    uint8_t* dst_row =
        &padded[static_cast<size_t>(y + pad) * padded_w + pad];
    std::memcpy(dst_row, src_row, static_cast<size_t>(width));
  }

  capi.set_image(handle->api, padded.data(), padded_w, padded_h, 1, padded_w);
  if (capi.set_source_resolution != nullptr) {
    capi.set_source_resolution(handle->api, 300);
  }

  char* raw_utf8 = capi.get_utf8_text(handle->api);
  const int conf = capi.mean_text_conf(handle->api);
  const std::string cleaned = TrimAsciiWhitespace(raw_utf8);
  if (raw_utf8 != nullptr) {
    capi.delete_text(raw_utf8);
  }

  auto* res = new TahrirTesseractLineResult();
  res->confidence = ClampInt(conf, 0, 100);
  res->error_code = 0;
  res->utf8_text = new char[cleaned.size() + 1];
  std::memcpy(res->utf8_text, cleaned.c_str(), cleaned.size() + 1);
  return res;
}

TAHRIR_API void tahrir_tesseract_free_line_result(
    TahrirTesseractLineResult* result) {
  if (result == nullptr) return;
  delete[] result->utf8_text;
  delete result;
}

TAHRIR_API void tahrir_tesseract_destroy(TahrirTesseractHandle* handle) {
  if (handle == nullptr) return;
  const auto& capi = GetTesseractCapi();
  if (capi.is_loaded && handle->api != nullptr) {
    capi.end(handle->api);
    capi.del(handle->api);
    handle->api = nullptr;
  }
  delete handle;
}

}  // extern "C"

#else  // _WIN32 desktop host

struct TahrirTesseractHandle {
  int unused = 0;
};

extern "C" {

TAHRIR_API int32_t tahrir_tesseract_is_available(void) {
  return 0;
}

TAHRIR_API TahrirTesseractHandle* tahrir_tesseract_create(
    const char* /*tessdata_dir*/,
    const char* /*languages*/) {
  return nullptr;
}

TAHRIR_API TahrirTesseractLineResult* tahrir_tesseract_recognize_line(
    TahrirTesseractHandle* /*handle*/,
    const uint8_t* /*gray_pixels*/,
    int32_t /*width*/,
    int32_t /*height*/,
    int32_t /*pad_px*/) {
  return nullptr;
}

TAHRIR_API void tahrir_tesseract_free_line_result(
    TahrirTesseractLineResult* result) {
  if (result == nullptr) return;
  delete[] result->utf8_text;
  delete result;
}

TAHRIR_API void tahrir_tesseract_destroy(TahrirTesseractHandle* handle) {
  delete handle;
}

}  // extern "C"

#endif
