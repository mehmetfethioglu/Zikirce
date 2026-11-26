//! Cinema 180-degree shutter exposure math, Software Auto-ISO,
//! 3D .cube LUT parser/sampler, audio dBFS meter, and 6-band IRE False Color.

// ============================================================================
// FAZ 3 — WP-3.2: 180° Cinema Shutter Angle, CFR & Software Auto-ISO Controller
// ============================================================================

/// Computes sensor exposure time in nanoseconds from cinema shutter angle $\theta$ (degrees)
/// and frame rate $f$ (fps):
/// $$t = \frac{\theta}{360^\circ \cdot f} \times 10^9\text{ ns}$$
#[inline]
pub fn shutter_exposure_ns_from_angle(angle_deg: f64, fps: f64) -> i64 {
    let clamped_angle = angle_deg.clamp(11.25, 360.0);
    let clamped_fps = fps.clamp(1.0, 240.0);
    ((clamped_angle / (360.0 * clamped_fps)) * 1_000_000_000.0).round() as i64
}

/// Computes exact Constant Frame Rate (CFR) frame duration in nanoseconds ($10^9 / f$).
#[inline]
pub fn frame_duration_ns_from_fps(fps: f64) -> i64 {
    let clamped_fps = fps.clamp(1.0, 240.0);
    (1_000_000_000.0 / clamped_fps).round() as i64
}

/// Software Auto-ISO PI step controller for 180° shutter-locked cinema recording (WP-3.2):
/// - Since Camera2 `AE_MODE_OFF` disables hardware Auto-ISO when locking shutter speed,
///   this controller drives ISO smoothly toward `target_luma` (default 18% gray / 0.42 IRE).
/// - Uses a $\pm 0.06\text{ EV}$ deadband and clamps per-frame ISO changes to $\le 1/6\text{ EV}$
///   ($2^{\pm 1/6}$) to eliminate exposure pumping.
/// - Returns `(next_iso, recommended_nd_factor)` where `recommended_nd_factor` is `0` (none),
///   `4` (`ND4`), `8` (`ND8`), or `16` (`ND16`) when ISO is at minimum and the scene is still
///   more than $+1.0\text{ EV}$ overexposed.
pub fn compute_software_auto_iso_step(
    current_iso: f64,
    iso_min: f64,
    iso_max: f64,
    measured_luma: f64,
    target_luma: f64,
) -> (f64, u32) {
    let min_i = iso_min.max(10.0);
    let max_i = iso_max.max(min_i);
    let cur = current_iso.clamp(min_i, max_i);
    let meas = measured_luma.clamp(1e-4, 1.0);
    let tgt = target_luma.clamp(0.05, 0.90);

    // EV error: positive when scene is darker than target (need higher ISO)
    let ev_error = (tgt / meas).log2();
    let next_iso = if ev_error.abs() < 0.06 {
        cur
    } else {
        // Damped proportional step clamped to +/- (1/6) EV per frame
        let step_ev = (ev_error * 0.55).clamp(-1.0 / 6.0, 1.0 / 6.0);
        (cur * 2.0_f64.powf(step_ev)).clamp(min_i, max_i)
    };

    // Check if ISO is pinned at minimum while scene is > +1.0 EV overexposed
    let over_ev = (meas / tgt).log2();
    let nd_factor = if next_iso <= min_i * 1.05 && over_ev > 1.0 {
        if over_ev > 3.5 {
            16 // ND16 (4 stops)
        } else if over_ev > 2.5 {
            8 // ND8 (3 stops)
        } else {
            4 // ND4 (2 stops)
        }
    } else {
        0
    };

    (next_iso, nd_factor)
}

// ============================================================================
// FAZ 3 — WP-3.3: 3D LUT (.cube Parser, Trilinear Sampler & Zamera Cinema LUTs)
// ============================================================================

/// 3D Lookup Table (`LUT_3D_SIZE` 17, 33, 65) with custom domain bounds.
#[derive(Debug, Clone)]
pub struct CubeLut3D {
    pub title: String,
    pub size: usize,
    pub domain_min: [f32; 3],
    pub domain_max: [f32; 3],
    /// Flattened $N^3$ RGB table in standard `.cube` order (R fastest, G middle, B slowest):
    /// `index = (b * size + g) * size + r`
    pub table: Vec<[f32; 3]>,
}

impl CubeLut3D {
    /// Evaluates the 3D LUT at `rgb` using hardware-equivalent 8-corner trilinear interpolation.
    pub fn sample_trilinear(&self, rgb: [f32; 3]) -> [f32; 3] {
        let n = self.size;
        if n < 2 || self.table.len() != n * n * n {
            return rgb;
        }
        let max_idx = (n - 1) as f32;
        let norm_r = ((rgb[0] - self.domain_min[0])
            / (self.domain_max[0] - self.domain_min[0]).max(1e-6))
        .clamp(0.0, 1.0)
            * max_idx;
        let norm_g = ((rgb[1] - self.domain_min[1])
            / (self.domain_max[1] - self.domain_min[1]).max(1e-6))
        .clamp(0.0, 1.0)
            * max_idx;
        let norm_b = ((rgb[2] - self.domain_min[2])
            / (self.domain_max[2] - self.domain_min[2]).max(1e-6))
        .clamp(0.0, 1.0)
            * max_idx;

        let r0 = (norm_r.floor() as usize).min(n - 1);
        let g0 = (norm_g.floor() as usize).min(n - 1);
        let b0 = (norm_b.floor() as usize).min(n - 1);
        let r1 = (r0 + 1).min(n - 1);
        let g1 = (g0 + 1).min(n - 1);
        let b1 = (b0 + 1).min(n - 1);

        let fr = norm_r - r0 as f32;
        let fg = norm_g - g0 as f32;
        let fb = norm_b - b0 as f32;

        let idx = |r: usize, g: usize, b: usize| -> usize { (b * n + g) * n + r };
        let c000 = self.table[idx(r0, g0, b0)];
        let c100 = self.table[idx(r1, g0, b0)];
        let c010 = self.table[idx(r0, g1, b0)];
        let c110 = self.table[idx(r1, g1, b0)];
        let c001 = self.table[idx(r0, g0, b1)];
        let c101 = self.table[idx(r1, g0, b1)];
        let c011 = self.table[idx(r0, g1, b1)];
        let c111 = self.table[idx(r1, g1, b1)];

        let mut out = [0.0f32; 3];
        for ch in 0..3 {
            let c00 = c000[ch] * (1.0 - fr) + c100[ch] * fr;
            let c10 = c010[ch] * (1.0 - fr) + c110[ch] * fr;
            let c01 = c001[ch] * (1.0 - fr) + c101[ch] * fr;
            let c11 = c011[ch] * (1.0 - fr) + c111[ch] * fr;
            let c0 = c00 * (1.0 - fg) + c10 * fg;
            let c1 = c01 * (1.0 - fg) + c11 * fg;
            out[ch] = (c0 * (1.0 - fb) + c1 * fb).clamp(0.0, 1.0);
        }
        out
    }
}

/// Parses an industry-standard Adobe/Iridas `.cube` 3D LUT file (`LUT_3D_SIZE` 17, 33, 65).
pub fn parse_cube_lut(content: &str) -> Result<CubeLut3D, String> {
    let mut title = String::from("Zamera Custom LUT");
    let mut size: Option<usize> = None;
    let mut domain_min = [0.0f32, 0.0, 0.0];
    let mut domain_max = [1.0f32, 1.0, 1.0];
    let mut table: Vec<[f32; 3]> = Vec::new();

    for (line_idx, raw_line) in content.lines().enumerate() {
        let line_no = line_idx + 1;
        let trimmed = raw_line.split('#').next().unwrap_or("").trim();
        if trimmed.is_empty() {
            continue;
        }
        let upper = trimmed.to_ascii_uppercase();
        if upper.starts_with("TITLE") {
            if let Some(first_quote) = trimmed.find('"') {
                if let Some(last_quote) = trimmed.rfind('"') {
                    if last_quote > first_quote {
                        title = trimmed[first_quote + 1..last_quote].to_string();
                    }
                }
            }
            continue;
        }
        if upper.starts_with("LUT_1D_SIZE") {
            return Err(format!(
                "Satır {line_no}: 1D LUT desteklenmiyor, 3D .cube (LUT_3D_SIZE 17/33/65) gereklidir"
            ));
        }
        if upper.starts_with("LUT_3D_SIZE") {
            let parts: Vec<&str> = trimmed.split_whitespace().collect();
            if parts.len() != 2 {
                return Err(format!("Satır {line_no}: Geçersiz LUT_3D_SIZE sözdizimi"));
            }
            let parsed_n = parts[1]
                .parse::<usize>()
                .map_err(|_| format!("Satır {line_no}: LUT_3D_SIZE tam sayı değil"))?;
            if !(2..=65).contains(&parsed_n) {
                return Err(format!(
                    "Satır {line_no}: Desteklenmeyen LUT_3D_SIZE={parsed_n} (17, 33 veya 65 olmalı)"
                ));
            }
            size = Some(parsed_n);
            table.reserve(parsed_n * parsed_n * parsed_n);
            continue;
        }
        if upper.starts_with("DOMAIN_MIN") {
            let parts: Vec<&str> = trimmed.split_whitespace().collect();
            if parts.len() != 4 {
                return Err(format!(
                    "Satır {line_no}: DOMAIN_MIN 3 float değer içermelidir"
                ));
            }
            for ch in 0..3 {
                domain_min[ch] = parts[1 + ch]
                    .parse::<f32>()
                    .map_err(|_| format!("Satır {line_no}: Geçersiz DOMAIN_MIN değeri"))?;
            }
            continue;
        }
        if upper.starts_with("DOMAIN_MAX") {
            let parts: Vec<&str> = trimmed.split_whitespace().collect();
            if parts.len() != 4 {
                return Err(format!(
                    "Satır {line_no}: DOMAIN_MAX 3 float değer içermelidir"
                ));
            }
            for ch in 0..3 {
                domain_max[ch] = parts[1 + ch]
                    .parse::<f32>()
                    .map_err(|_| format!("Satır {line_no}: Geçersiz DOMAIN_MAX değeri"))?;
            }
            continue;
        }

        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() == 3 {
            let r = parts[0]
                .parse::<f32>()
                .map_err(|_| format!("Satır {line_no}: Geçersiz R float değeri"))?;
            let g = parts[1]
                .parse::<f32>()
                .map_err(|_| format!("Satır {line_no}: Geçersiz G float değeri"))?;
            let b = parts[2]
                .parse::<f32>()
                .map_err(|_| format!("Satır {line_no}: Geçersiz B float değeri"))?;
            if !r.is_finite() || !g.is_finite() || !b.is_finite() {
                return Err(format!("Satır {line_no}: NaN veya sonsuz LUT değeri"));
            }
            table.push([r, g, b]);
        } else {
            return Err(format!(
                "Satır {line_no}: Tanınmayan .cube satırı: '{trimmed}'"
            ));
        }
    }

    let n = size.ok_or_else(|| String::from("LUT_3D_SIZE başlığı bulunamadı"))?;
    for ch in 0..3 {
        if domain_max[ch] <= domain_min[ch] {
            return Err(String::from(
                "DOMAIN_MAX her kanalda DOMAIN_MIN'den büyük olmalıdır",
            ));
        }
    }
    let expected = n * n * n;
    if table.len() != expected {
        return Err(format!(
            "LUT_3D_SIZE={n} için {expected} satır beklendi, fakat {} satır bulundu",
            table.len()
        ));
    }

    Ok(CubeLut3D {
        title,
        size: n,
        domain_min,
        domain_max,
        table,
    })
}

/// Generates Zamera's proprietary built-in 3D LUTs (WP-3.3 — zero third-party trademark risk):
/// - `preset_id = 0`: `IDENTITY` (1:1 pass-through)
/// - `preset_id = 1`: `REC.709 İZLEME` (BT.2408 HLG / Log to SDR monitoring tone-map)
/// - `preset_id = 2`: `SICAK SİNEMA` (Warm golden highlights + teal shadows cinema grade)
/// - `preset_id = 3`: `NOIR` (Silver-gelatin high-contrast monochrome cinema grade)
pub fn generate_builtin_lut(preset_id: u32, size: usize) -> CubeLut3D {
    let n = size.clamp(2, 65);
    let max_f = (n - 1) as f32;
    let mut table = Vec::with_capacity(n * n * n);

    let title = match preset_id {
        1 => "REC.709 IZLEME",
        2 => "SICAK SINEMA",
        3 => "NOIR",
        _ => "IDENTITY",
    };

    for b_idx in 0..n {
        let b = b_idx as f32 / max_f;
        for g_idx in 0..n {
            let g = g_idx as f32 / max_f;
            for r_idx in 0..n {
                let r = r_idx as f32 / max_f;
                let rgb = match preset_id {
                    1 => {
                        // BT.2408 HLG / Log -> Rec.709 SDR soft knee roll-off + saturation recovery
                        let map_ch = |x: f32| -> f32 {
                            let lifted = (x * 1.12).clamp(0.0, 1.25);
                            let knee = lifted / (1.0 + 0.28 * lifted * lifted);
                            let s = knee * knee * (3.0 - 2.0 * knee);
                            (0.35 * knee + 0.65 * s).clamp(0.0, 1.0)
                        };
                        [map_ch(r), map_ch(g), map_ch(b)]
                    }
                    2 => {
                        // SICAK SİNEMA: warm golden highlights, cool cyan-teal deep shadows, filmic S-curve
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b;
                        let shadow_w = (1.0 - luma).powi(2);
                        let high_w = luma.powi(2);
                        let sr = (r + 0.045 * high_w - 0.025 * shadow_w).clamp(0.0, 1.0);
                        let sg = (g + 0.018 * high_w + 0.010 * shadow_w).clamp(0.0, 1.0);
                        let sb = (b - 0.040 * high_w + 0.038 * shadow_w).clamp(0.0, 1.0);
                        let filmic = |x: f32| -> f32 {
                            let s = x * x * (3.0 - 2.0 * x);
                            (0.25 * x + 0.75 * s).clamp(0.0, 1.0)
                        };
                        [filmic(sr), filmic(sg), filmic(sb)]
                    }
                    3 => {
                        // NOIR: Panchromatic silver-gelatin monochrome with deep D-max toe
                        let y = (0.34 * r + 0.56 * g + 0.10 * b).clamp(0.0, 1.0);
                        let s = y * y * (3.0 - 2.0 * y);
                        let mono = ((0.22 * y + 0.78 * s - 0.50) * 1.18 + 0.50).clamp(0.0, 1.0);
                        [mono, mono, mono]
                    }
                    _ => [r, g, b],
                };
                table.push(rgb);
            }
        }
    }

    CubeLut3D {
        title: title.to_string(),
        size: n,
        domain_min: [0.0, 0.0, 0.0],
        domain_max: [1.0, 1.0, 1.0],
        table,
    }
}

// ============================================================================
// FAZ 3 — WP-3.4 & WP-3.0: Float-Normalized Audio dBFS & 6-Band IRE False Color
// ============================================================================

/// Computes format-independent Sample Peak dBFS and RMS dBFS from normalized float audio
/// samples $x_i \in [-1.0, 1.0]$ (WP-3.4):
/// $$\text{dBFS} = 20 \log_{10}(\max_i |x_i|)$$
pub fn compute_audio_peak_rms_dbfs(samples: &[f32]) -> (f32, f32) {
    if samples.is_empty() {
        return (-96.0, -96.0);
    }
    let mut peak = 0.0f32;
    let mut sum_sq = 0.0f64;
    for &s in samples {
        let a = if s.is_finite() { s.abs().min(1.0) } else { 0.0 };
        if a > peak {
            peak = a;
        }
        sum_sq += (a as f64) * (a as f64);
    }
    let rms = (sum_sq / (samples.len() as f64)).sqrt() as f32;
    let peak_dbfs = if peak <= 1.584_893_2e-5 {
        -96.0
    } else {
        (20.0 * peak.log10()).clamp(-96.0, 0.0)
    };
    let rms_dbfs = if rms <= 1.584_893_2e-5 {
        -96.0
    } else {
        (20.0 * rms.log10()).clamp(-96.0, 0.0)
    };
    (peak_dbfs, rms_dbfs)
}

/// Maps normalized IRE luma percentage (`0.0..=100.0`) into one of 6 cinema False Color bands (WP-3.0):
/// - Band 0 (`0..10%` IRE): Deep Shadow Clipping — Purple `[128, 0, 200]`
/// - Band 1 (`10..25%` IRE): Underexposed Toe — Blue `[0, 110, 255]`
/// - Band 2 (`25..48%` IRE): 18% Gray / Midtones — Green `[40, 210, 80]`
/// - Band 3 (`48..70%` IRE): Key Skin Tones — Pink `[255, 130, 170]`
/// - Band 4 (`70..94%` IRE): Bright Highlights — Yellow `[255, 214, 10]`
/// - Band 5 (`94..100%` IRE): Highlight Clipping — Red `[255, 50, 48]`
#[inline]
pub fn ire_to_false_color_band(ire_percent: f32) -> (u8, [u8; 3]) {
    let ire = ire_percent.clamp(0.0, 100.0);
    if ire < 10.0 {
        (0, [128, 0, 200])
    } else if ire < 25.0 {
        (1, [0, 110, 255])
    } else if ire < 48.0 {
        (2, [40, 210, 80])
    } else if ire < 70.0 {
        (3, [255, 130, 170])
    } else if ire < 94.0 {
        (4, [255, 214, 10])
    } else {
        (5, [255, 50, 48])
    }
}
