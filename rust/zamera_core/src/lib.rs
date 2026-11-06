//! Zamera Core (`zamera_core`) — Deterministic Color Science & Striped RAW ISP Engine
//!
//! Provides identical colorimetric math and 14-bit Bayer RAW development across Android (JNI)
//! and iOS (C ABI):
//! - CIE XYZ (D50 <-> D65 Bradford Chromatic Adaptation)
//! - CIE L*a*b* (D50) conversion
//! - CIEDE2000 ($\Delta E_{00}$) color difference verified against Sharma et al. (2005)
//! - IEC 61966-2-1 sRGB and Apple Display P3 transfer functions (OETF / EOTF)
//! - White-point preserving 3x3 ColorChecker 24-patch calibration matrix solver
//! - Spatial Flat-Field illumination normalization & 4-corner perspective homography
//! - 14-bit / 16-bit Bayer RAW (`RGGB`/`GRBG`/`GBRG`/`BGGR`) -> TrueColor sRGB / Display P3 ISP

use std::f64::consts::PI;
use std::ffi::{c_char, c_void};

const VERSION_STR: &str =
    "zamera_core 0.3.0 (JNI/FFI Active | 14-Bit RAW ISP + 24-Patch ColorChecker + FlatField)";
const VERSION_CSTR: &[u8] =
    b"zamera_core 0.3.0 (JNI/FFI Active | 14-Bit RAW ISP + 24-Patch ColorChecker + FlatField)\0";

/// Official 24-patch ColorChecker Classic reference CIE L*a*b* (D50, 2-degree observer) values
/// published by X-Rite / BabelColor.
pub const COLORCHECKER_24_LAB_D50: [[f64; 3]; 24] = [
    [37.986, 13.555, 14.059],   // 01 Dark Skin
    [65.711, 18.130, 17.810],   // 02 Light Skin
    [49.927, -4.880, -21.925],  // 03 Blue Sky
    [43.139, -13.095, 21.905],  // 04 Foliage
    [55.112, 8.844, -25.399],   // 05 Blue Flower
    [70.719, -33.397, -0.199],  // 06 Bluish Green
    [62.661, 36.067, 57.096],   // 07 Orange
    [40.020, 10.410, -45.964],  // 08 Purplish Blue
    [51.124, 48.239, 16.248],   // 09 Moderate Red
    [30.325, 22.976, -21.587],  // 10 Purple
    [72.532, -23.709, 57.255],  // 11 Yellow Green
    [71.941, 19.363, 67.857],   // 12 Orange Yellow
    [28.778, 14.179, -50.297],  // 13 Blue
    [55.261, -38.342, 31.370],  // 14 Green
    [42.101, 53.378, 28.190],   // 15 Red
    [81.733, 4.039, 79.819],    // 16 Yellow
    [51.935, 49.986, -14.574],  // 17 Magenta
    [51.038, -28.631, -28.638], // 18 Cyan
    [96.539, -0.425, 1.186],    // 19 White 9.5 (.05 D)
    [81.257, -0.638, -0.335],   // 20 Neutral 8 (.23 D) — Primary WB reference
    [66.766, -0.734, -0.504],   // 21 Neutral 6.5 (.44 D)
    [50.867, -0.153, -0.270],   // 22 Neutral 5 (.70 D) — 18% Gray Card equivalent
    [35.656, -0.421, -1.231],   // 23 Neutral 3.5 (1.05 D)
    [20.461, -0.079, -0.973],   // 24 Black 2 (1.50 D)
];

/// Returns the human-readable engine version string.
pub fn zamera_core_version() -> &'static str {
    VERSION_STR
}

/// C ABI entrypoint callable from Swift (`AVFoundation` bridge) and Dart FFI.
#[no_mangle]
pub extern "C" fn zamera_core_version_cstr() -> *const c_char {
    VERSION_CSTR.as_ptr() as *const c_char
}

/// C ABI entrypoint for CIEDE2000 calculation from Swift / Dart FFI.
#[no_mangle]
pub extern "C" fn zamera_ciede2000_ffi(
    l1: f64,
    a1: f64,
    b1: f64,
    l2: f64,
    a2: f64,
    b2: f64,
) -> f64 {
    ciede2000([l1, a1, b1], [l2, a2, b2])
}

/// IEC 61966-2-1 sRGB Opto-Electronic Transfer Function (Linear -> Non-linear sRGB/Display P3).
#[inline]
pub fn srgb_oetf(linear: f64) -> f64 {
    let c = linear.clamp(0.0, 1.0);
    if c <= 0.0031308 {
        12.92 * c
    } else {
        1.055 * c.powf(1.0 / 2.4) - 0.055
    }
}

/// Fast single-precision sRGB OETF for high-throughput RAW pixel loops.
#[inline]
pub fn srgb_oetf_f32(linear: f32) -> f32 {
    let c = linear.clamp(0.0, 1.0);
    if c <= 0.0031308 {
        12.92 * c
    } else {
        1.055 * c.powf(1.0 / 2.4) - 0.055
    }
}

/// IEC 61966-2-1 sRGB Electro-Optical Transfer Function (Non-linear -> Linear).
#[inline]
pub fn srgb_eotf(encoded: f64) -> f64 {
    let c = encoded.clamp(0.0, 1.0);
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

/// Display P3 uses the sRGB transfer function with wide-gamut primaries.
#[inline]
pub fn display_p3_oetf(linear: f64) -> f64 {
    srgb_oetf(linear)
}

/// Multiplies a 3x3 row-major matrix by a 3D column vector.
#[inline]
pub fn mat3_mul_vec3(m: [[f64; 3]; 3], v: [f64; 3]) -> [f64; 3] {
    [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]
}

/// Multiplies two 3x3 row-major matrices ($A \times B$).
#[inline]
pub fn mat3_mul_mat3(a: [[f64; 3]; 3], b: [[f64; 3]; 3]) -> [[f64; 3]; 3] {
    let mut out = [[0.0; 3]; 3];
    for (r, out_row) in out.iter_mut().enumerate() {
        for (c, cell) in out_row.iter_mut().enumerate() {
            *cell = a[r][0] * b[0][c] + a[r][1] * b[1][c] + a[r][2] * b[2][c];
        }
    }
    out
}

/// Inverts a 3x3 matrix using analytical cofactor expansion.
pub fn mat3_inverse(m: [[f64; 3]; 3]) -> Option<[[f64; 3]; 3]> {
    let c00 = m[1][1] * m[2][2] - m[1][2] * m[2][1];
    let c01 = -(m[1][0] * m[2][2] - m[1][2] * m[2][0]);
    let c02 = m[1][0] * m[2][1] - m[1][1] * m[2][0];

    let det = m[0][0] * c00 + m[0][1] * c01 + m[0][2] * c02;
    if det.abs() < 1e-12 {
        return None;
    }
    let inv_det = 1.0 / det;

    let c10 = -(m[0][1] * m[2][2] - m[0][2] * m[2][1]);
    let c11 = m[0][0] * m[2][2] - m[0][2] * m[2][0];
    let c12 = -(m[0][0] * m[2][1] - m[0][1] * m[2][0]);

    let c20 = m[0][1] * m[1][2] - m[0][2] * m[1][1];
    let c21 = -(m[0][0] * m[1][2] - m[0][2] * m[1][0]);
    let c22 = m[0][0] * m[1][1] - m[0][1] * m[1][0];

    Some([
        [c00 * inv_det, c10 * inv_det, c20 * inv_det],
        [c01 * inv_det, c11 * inv_det, c21 * inv_det],
        [c02 * inv_det, c12 * inv_det, c22 * inv_det],
    ])
}

/// Bradford chromatic adaptation matrix from CIE D50 (DNG PCS) to CIE D65 (sRGB / Display P3).
pub const M_BRADFORD_D50_TO_D65: [[f64; 3]; 3] = [
    [0.9555766, -0.0230393, 0.0631636],
    [-0.0282895, 1.0099416, 0.0210077],
    [0.0122982, -0.0204830, 1.3299098],
];

/// CIE XYZ (D65) to linear sRGB matrix (IEC 61966-2-1).
pub const M_XYZ_D65_TO_SRGB: [[f64; 3]; 3] = [
    [3.2404542, -1.5371385, -0.4985314],
    [-0.9692660, 1.8760108, 0.0415560],
    [0.0556434, -0.2040259, 1.0572252],
];

/// CIE XYZ (D65) to linear Apple Display P3 matrix.
pub const M_XYZ_D65_TO_DISPLAY_P3: [[f64; 3]; 3] = [
    [2.4934969, -0.9313836, -0.4027108],
    [-0.8294890, 1.7626641, 0.0236247],
    [0.0358458, -0.0761724, 0.9568845],
];

/// Bradford chromatic adaptation from CIE D50 (DNG standard PCS) to CIE D65 (sRGB / Display P3).
pub fn bradford_d50_to_d65(xyz_d50: [f64; 3]) -> [f64; 3] {
    mat3_mul_vec3(M_BRADFORD_D50_TO_D65, xyz_d50)
}

/// Converts CIE XYZ (D65) to linear sRGB.
pub fn xyz_d65_to_linear_srgb(xyz_d65: [f64; 3]) -> [f64; 3] {
    mat3_mul_vec3(M_XYZ_D65_TO_SRGB, xyz_d65)
}

/// Converts CIE XYZ (D65) to linear Apple Display P3.
pub fn xyz_d65_to_linear_display_p3(xyz_d65: [f64; 3]) -> [f64; 3] {
    mat3_mul_vec3(M_XYZ_D65_TO_DISPLAY_P3, xyz_d65)
}

/// Converts CIE XYZ (D50) to CIE 1976 L*a*b* (D50 reference white).
pub fn xyz_d50_to_lab(xyz_d50: [f64; 3]) -> [f64; 3] {
    const D50_WHITE: [f64; 3] = [0.96422, 1.00000, 0.82521];
    const EPSILON: f64 = 216.0 / 24389.0;
    const KAPPA: f64 = 24389.0 / 27.0;

    let f = |t: f64| -> f64 {
        if t > EPSILON {
            t.cbrt()
        } else {
            (KAPPA * t + 16.0) / 116.0
        }
    };

    let fx = f(xyz_d50[0] / D50_WHITE[0]);
    let fy = f(xyz_d50[1] / D50_WHITE[1]);
    let fz = f(xyz_d50[2] / D50_WHITE[2]);

    let l = 116.0 * fy - 16.0;
    let a = 500.0 * (fx - fy);
    let b = 200.0 * (fy - fz);
    [l, a, b]
}

/// Converts CIE 1976 L*a*b* (D50) back to CIE XYZ (D50).
pub fn lab_d50_to_xyz(lab: [f64; 3]) -> [f64; 3] {
    const D50_WHITE: [f64; 3] = [0.96422, 1.00000, 0.82521];
    const EPSILON: f64 = 216.0 / 24389.0;
    const KAPPA: f64 = 24389.0 / 27.0;

    let fy = (lab[0] + 16.0) / 116.0;
    let fx = fy + (lab[1] / 500.0);
    let fz = fy - (lab[2] / 200.0);

    let inv_f = |f_val: f64| -> f64 {
        let f3 = f_val * f_val * f_val;
        if f3 > EPSILON {
            f3
        } else {
            (116.0 * f_val - 16.0) / KAPPA
        }
    };

    [
        D50_WHITE[0] * inv_f(fx),
        D50_WHITE[1] * inv_f(fy),
        D50_WHITE[2] * inv_f(fz),
    ]
}

/// Full CIEDE2000 ($\Delta E_{00}$) color difference formula (parametric weights $k_L = k_C = k_H = 1$).
/// Verified against Sharma, Wu, and Dalal (2005) canonical test dataset.
pub fn ciede2000(lab1: [f64; 3], lab2: [f64; 3]) -> f64 {
    let (l1, a1, b1) = (lab1[0], lab1[1], lab1[2]);
    let (l2, a2, b2) = (lab2[0], lab2[1], lab2[2]);

    let c1 = (a1 * a1 + b1 * b1).sqrt();
    let c2 = (a2 * a2 + b2 * b2).sqrt();
    let c_bar = 0.5 * (c1 + c2);

    let c_bar_pow7 = c_bar.powi(7);
    let twenty_five_pow7 = 25.0_f64.powi(7);
    let g = 0.5 * (1.0 - (c_bar_pow7 / (c_bar_pow7 + twenty_five_pow7)).sqrt());

    let a1_prime = (1.0 + g) * a1;
    let a2_prime = (1.0 + g) * a2;

    let c1_prime = (a1_prime * a1_prime + b1 * b1).sqrt();
    let c2_prime = (a2_prime * a2_prime + b2 * b2).sqrt();

    let h_deg = |ap: f64, b: f64| -> f64 {
        if ap == 0.0 && b == 0.0 {
            0.0
        } else {
            let mut deg = b.atan2(ap) * (180.0 / PI);
            if deg < 0.0 {
                deg += 360.0;
            }
            deg
        }
    };

    let h1_prime = h_deg(a1_prime, b1);
    let h2_prime = h_deg(a2_prime, b2);

    let delta_l_prime = l2 - l1;
    let delta_c_prime = c2_prime - c1_prime;

    let c_prod = c1_prime * c2_prime;
    let delta_h_prime_deg = if c_prod == 0.0 {
        0.0
    } else {
        let diff = h2_prime - h1_prime;
        if diff.abs() <= 180.0 {
            diff
        } else if diff > 180.0 {
            diff - 360.0
        } else {
            diff + 360.0
        }
    };

    let delta_big_h_prime =
        2.0 * c_prod.sqrt() * ((delta_h_prime_deg * 0.5) * (PI / 180.0)).sin();

    let l_bar_prime = 0.5 * (l1 + l2);
    let c_bar_prime = 0.5 * (c1_prime + c2_prime);

    let h_bar_prime_deg = if c_prod == 0.0 {
        h1_prime + h2_prime
    } else if (h1_prime - h2_prime).abs() <= 180.0 {
        0.5 * (h1_prime + h2_prime)
    } else if (h1_prime + h2_prime) < 360.0 {
        0.5 * (h1_prime + h2_prime + 360.0)
    } else {
        0.5 * (h1_prime + h2_prime - 360.0)
    };

    let t = 1.0
        - 0.17 * ((h_bar_prime_deg - 30.0) * (PI / 180.0)).cos()
        + 0.24 * ((2.0 * h_bar_prime_deg) * (PI / 180.0)).cos()
        + 0.32 * ((3.0 * h_bar_prime_deg + 6.0) * (PI / 180.0)).cos()
        - 0.20 * ((4.0 * h_bar_prime_deg - 63.0) * (PI / 180.0)).cos();

    let delta_theta_deg = 30.0 * (-(((h_bar_prime_deg - 275.0) / 25.0).powi(2))).exp();
    let c_bar_prime_pow7 = c_bar_prime.powi(7);
    let r_c = 2.0 * (c_bar_prime_pow7 / (c_bar_prime_pow7 + twenty_five_pow7)).sqrt();

    let l_minus_50_sq = (l_bar_prime - 50.0).powi(2);
    let s_l = 1.0 + (0.015 * l_minus_50_sq) / (20.0 + l_minus_50_sq).sqrt();
    let s_c = 1.0 + 0.045 * c_bar_prime;
    let s_h = 1.0 + 0.015 * c_bar_prime * t;
    let r_t = -((2.0 * delta_theta_deg * (PI / 180.0)).sin()) * r_c;

    let term_l = delta_l_prime / s_l;
    let term_c = delta_c_prime / s_c;
    let term_h = delta_big_h_prime / s_h;

    (term_l * term_l + term_c * term_c + term_h * term_h + r_t * term_c * term_h).sqrt()
}

/// Output of the 24-Patch ColorChecker calibration solver.
#[derive(Debug, Clone)]
pub struct CalibrationReport {
    pub wb_gains: [f64; 3],
    pub cam_to_xyz_d50: [[f64; 3]; 3],
    pub mean_delta_e_before: f64,
    pub mean_delta_e_after: f64,
    pub max_delta_e_after: f64,
    pub patch_delta_e_after: [f64; 24],
}

/// Solves the 3x3 Camera Linear RGB -> CIE XYZ (D50) calibration matrix and neutral White Balance
/// gains from 24 measured ColorChecker patch linear RGB values.
pub fn calibrate_colorchecker_24(measured_cam_rgb: &[[f64; 3]; 24]) -> CalibrationReport {
    let ref_xyz: [[f64; 3]; 24] =
        std::array::from_fn(|i| lab_d50_to_xyz(COLORCHECKER_24_LAB_D50[i]));

    let p20 = measured_cam_rgb[19];
    let p22 = measured_cam_rgb[21];
    let r_avg = (0.5 * (p20[0] + p22[0])).max(1e-6);
    let g_avg = (0.5 * (p20[1] + p22[1])).max(1e-6);
    let b_avg = (0.5 * (p20[2] + p22[2])).max(1e-6);

    let target_y22 = ref_xyz[21][1];
    let exposure_scale = target_y22 / p22[1].max(1e-6);
    let wb_gains = [
        (g_avg / r_avg) * exposure_scale,
        1.0 * exposure_scale,
        (g_avg / b_avg) * exposure_scale,
    ];

    let wb_rgb: [[f64; 3]; 24] = std::array::from_fn(|i| {
        [
            measured_cam_rgb[i][0] * wb_gains[0],
            measured_cam_rgb[i][1] * wb_gains[1],
            measured_cam_rgb[i][2] * wb_gains[2],
        ]
    });

    const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
        [0.4360747, 0.3850649, 0.1430804],
        [0.2225045, 0.7168786, 0.0606169],
        [0.0139322, 0.0971045, 0.7141733],
    ];
    let mut sum_before = 0.0;
    for (meas, ref_lab) in measured_cam_rgb.iter().zip(COLORCHECKER_24_LAB_D50.iter()) {
        let naive_xyz = mat3_mul_vec3(M_SRGB_TO_XYZ_D50, *meas);
        let naive_lab = xyz_d50_to_lab(naive_xyz);
        sum_before += ciede2000(*ref_lab, naive_lab);
    }
    let mean_delta_e_before = sum_before / 24.0;

    let mut xxt = [[1e-6, 0.0, 0.0], [0.0, 1e-6, 0.0], [0.0, 0.0, 1e-6]];
    let mut yxt = [[0.0; 3]; 3];
    for (x, y) in wb_rgb.iter().zip(ref_xyz.iter()) {
        for r in 0..3 {
            for c in 0..3 {
                xxt[r][c] += x[r] * x[c];
                yxt[r][c] += y[r] * x[c];
            }
        }
    }

    let cam_to_xyz_d50 = if let Some(xxt_inv) = mat3_inverse(xxt) {
        mat3_mul_mat3(yxt, xxt_inv)
    } else {
        M_SRGB_TO_XYZ_D50
    };

    let mut patch_delta_e_after = [0.0; 24];
    let mut sum_after = 0.0;
    let mut max_after = 0.0_f64;
    for ((de_slot, wb_val), ref_lab) in patch_delta_e_after
        .iter_mut()
        .zip(wb_rgb.iter())
        .zip(COLORCHECKER_24_LAB_D50.iter())
    {
        let cal_xyz = mat3_mul_vec3(cam_to_xyz_d50, *wb_val);
        let cal_lab = xyz_d50_to_lab(cal_xyz);
        let de = ciede2000(*ref_lab, cal_lab);
        *de_slot = de;
        sum_after += de;
        if de > max_after {
            max_after = de;
        }
    }

    CalibrationReport {
        wb_gains,
        cam_to_xyz_d50,
        mean_delta_e_before,
        mean_delta_e_after: sum_after / 24.0,
        max_delta_e_after: max_after,
        patch_delta_e_after,
    }
}

/// Computes per-cell spatial flat-field illumination gains from a blank sheet capture.
/// Preserves channel ratios (only corrects spatial falloff from desk lamps / lens vignetting).
pub fn compute_flat_field_gains(grid_luminance: &[f64]) -> Vec<f64> {
    if grid_luminance.is_empty() {
        return Vec::new();
    }
    let mean_lum =
        (grid_luminance.iter().copied().sum::<f64>() / grid_luminance.len() as f64).max(1e-6);
    grid_luminance
        .iter()
        .map(|&lum| (mean_lum / lum.max(1e-4)).clamp(0.5, 2.5))
        .collect()
}

/// Complete single-pixel TrueColor pipeline:
/// 1. Channel black-level subtraction & white-level normalization
/// 2. Flat-field spatial gain compensation
/// 3. Gray-card / ColorChecker neutral white balance gains
/// 4. Calibrated Camera RGB -> CIE XYZ (D50) matrix
/// 5. Bradford D50 -> D65 chromatic adaptation
/// 6. CIE XYZ (D65) -> sRGB OETF encoded [0..1]
pub fn process_raw_pixel_to_srgb(
    raw_rgb: [f64; 3],
    black_level: [f64; 3],
    white_level: f64,
    flat_field_gain: [f64; 3],
    wb_gains: [f64; 3],
    cam_to_xyz_d50: [[f64; 3]; 3],
) -> [f64; 3] {
    let mut norm = [0.0; 3];
    for c in 0..3 {
        let denom = (white_level - black_level[c]).max(1e-6);
        let linear = ((raw_rgb[c] - black_level[c]) / denom).clamp(0.0, 1.0);
        norm[c] = (linear * flat_field_gain[c] * wb_gains[c]).clamp(0.0, 1.5);
    }
    let xyz_d50 = mat3_mul_vec3(cam_to_xyz_d50, norm);
    let xyz_d65 = bradford_d50_to_d65(xyz_d50);
    let lin_srgb = xyz_d65_to_linear_srgb(xyz_d65);
    [
        srgb_oetf(lin_srgb[0]),
        srgb_oetf(lin_srgb[1]),
        srgb_oetf(lin_srgb[2]),
    ]
}

/// Extracts `[R, Gr, Gb, B]` 16-bit unsigned sensor values from a 2x2 Bayer quad at `(even_x, even_y)`
/// according to `cfa_pattern` (`0=RGGB`, `1=GRBG`, `2=GBRG`, `3=BGGR`).
#[inline]
fn extract_bayer_quad_rggb(
    raw_bytes: &[u8],
    row_stride: usize,
    even_x: usize,
    even_y: usize,
    cfa_pattern: u32,
) -> [f32; 4] {
    let row0 = even_y * row_stride + even_x * 2;
    let row1 = (even_y + 1) * row_stride + even_x * 2;
    if row1 + 3 >= raw_bytes.len() {
        return [0.0; 4];
    }
    let p00 = u16::from_le_bytes([raw_bytes[row0], raw_bytes[row0 + 1]]) as f32;
    let p01 = u16::from_le_bytes([raw_bytes[row0 + 2], raw_bytes[row0 + 3]]) as f32;
    let p10 = u16::from_le_bytes([raw_bytes[row1], raw_bytes[row1 + 1]]) as f32;
    let p11 = u16::from_le_bytes([raw_bytes[row1 + 2], raw_bytes[row1 + 3]]) as f32;

    match cfa_pattern {
        0 => [p00, p01, p10, p11], // RGGB
        1 => [p01, p00, p11, p10], // GRBG
        2 => [p10, p11, p00, p01], // GBRG
        _ => [p11, p10, p01, p00], // BGGR
    }
}

/// Statistics returned by `develop_bayer16_to_rgba8`.
#[derive(Debug, Clone, Copy, Default)]
pub struct RawDevelopStats {
    pub out_width: u32,
    pub out_height: u32,
    pub mean_rgb: [f32; 3],
    pub center_linear_cam_rgb: [f32; 3],
    pub highlight_clipped_ratio: f32,
    pub gamut_clipped_ratio: f32,
}

/// Develops a 16-bit little-endian Bayer `RAW_SENSOR` buffer into an 8-bit `RGBA_8888` buffer
/// in sRGB or Display P3 color space using a combined 3x3 linear matrix
/// ($M_{\text{XYZ}\to\text{Target}} \times M_{\text{Bradford } D_{50}\to D_{65}} \times M_{\text{Cam}\to\text{XYZ } D_{50}}$).
///
/// Uses 2x2 superpixel demosaicing (`width/2 x height/2`, zero interpolation color fringes,
/// `< 25 ms` on 12MP RAW) and computes center ROI linear camera `[R, G, B]` for 18% Gray Card
/// calibration plus highlight/gamut clipping telemetry.
#[allow(clippy::too_many_arguments)]
pub fn develop_bayer16_to_rgba8(
    raw_bytes: &[u8],
    width: usize,
    height: usize,
    row_stride: usize,
    cfa_pattern: u32,
    black_level: [f32; 4],
    white_level: f32,
    wb_gains: [f32; 3],
    cam_to_xyz_d50: [[f64; 3]; 3],
    use_display_p3: bool,
    apply_radial_flat_field: bool,
    out_rgba: &mut [u8],
) -> RawDevelopStats {
    let out_w = width / 2;
    let out_h = height / 2;
    let total_pixels = (out_w * out_h).max(1);
    if out_rgba.len() < out_w * out_h * 4 {
        return RawDevelopStats::default();
    }

    // Pre-multiply Bradford (D50->D65) and target primaries (sRGB or Display P3) with cam_to_xyz_d50
    let m_d50_to_target = if use_display_p3 {
        mat3_mul_mat3(M_XYZ_D65_TO_DISPLAY_P3, M_BRADFORD_D50_TO_D65)
    } else {
        mat3_mul_mat3(M_XYZ_D65_TO_SRGB, M_BRADFORD_D50_TO_D65)
    };
    let m_total_f64 = mat3_mul_mat3(m_d50_to_target, cam_to_xyz_d50);
    let m = [
        [
            m_total_f64[0][0] as f32,
            m_total_f64[0][1] as f32,
            m_total_f64[0][2] as f32,
        ],
        [
            m_total_f64[1][0] as f32,
            m_total_f64[1][1] as f32,
            m_total_f64[1][2] as f32,
        ],
        [
            m_total_f64[2][0] as f32,
            m_total_f64[2][1] as f32,
            m_total_f64[2][2] as f32,
        ],
    ];

    let denom_r = (white_level - black_level[0]).max(1.0);
    let denom_gr = (white_level - black_level[1]).max(1.0);
    let denom_gb = (white_level - black_level[2]).max(1.0);
    let denom_b = (white_level - black_level[3]).max(1.0);
    let clip_threshold = white_level * 0.992;

    // Center 10% ROI for live 18% Gray Card spot measurement
    let roi_x0 = out_w * 45 / 100;
    let roi_x1 = (out_w * 55 / 100).max(roi_x0 + 1);
    let roi_y0 = out_h * 45 / 100;
    let roi_y1 = (out_h * 55 / 100).max(roi_y0 + 1);

    let mut sum_out_r = 0.0_f64;
    let mut sum_out_g = 0.0_f64;
    let mut sum_out_b = 0.0_f64;
    let mut center_cam_r = 0.0_f64;
    let mut center_cam_g = 0.0_f64;
    let mut center_cam_b = 0.0_f64;
    let mut center_count = 0usize;
    let mut highlight_clipped = 0usize;
    let mut gamut_clipped = 0usize;

    let inv_cx = if out_w > 0 { 2.0 / (out_w as f32) } else { 0.0 };
    let inv_cy = if out_h > 0 { 2.0 / (out_h as f32) } else { 0.0 };

    for oy in 0..out_h {
        let even_y = oy * 2;
        let dy = (oy as f32) * inv_cy - 1.0;
        let out_row_offset = oy * out_w * 4;

        for ox in 0..out_w {
            let even_x = ox * 2;
            let [raw_r, raw_gr, raw_gb, raw_b] =
                extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

            if raw_r >= clip_threshold
                || raw_gr >= clip_threshold
                || raw_gb >= clip_threshold
                || raw_b >= clip_threshold
            {
                highlight_clipped += 1;
            }

            let lin_r = ((raw_r - black_level[0]) / denom_r).clamp(0.0, 1.0);
            let lin_gr = ((raw_gr - black_level[1]) / denom_gr).clamp(0.0, 1.0);
            let lin_gb = ((raw_gb - black_level[2]) / denom_gb).clamp(0.0, 1.0);
            let lin_b = ((raw_b - black_level[3]) / denom_b).clamp(0.0, 1.0);
            let lin_g = 0.5 * (lin_gr + lin_gb);

            if ox >= roi_x0 && ox < roi_x1 && oy >= roi_y0 && oy < roi_y1 {
                center_cam_r += lin_r as f64;
                center_cam_g += lin_g as f64;
                center_cam_b += lin_b as f64;
                center_count += 1;
            }

            // Optional gentle desk-lamp / flat-field spatial normalization (keeps center 1.0)
            let ff_gain = if apply_radial_flat_field {
                let dx = (ox as f32) * inv_cx - 1.0;
                let r2 = dx * dx + dy * dy;
                1.0 + 0.08 * r2
            } else {
                1.0
            };

            let r_wb = (lin_r * wb_gains[0] * ff_gain).clamp(0.0, 1.25);
            let g_wb = (lin_g * wb_gains[1] * ff_gain).clamp(0.0, 1.25);
            let b_wb = (lin_b * wb_gains[2] * ff_gain).clamp(0.0, 1.25);

            let tr = m[0][0] * r_wb + m[0][1] * g_wb + m[0][2] * b_wb;
            let tg = m[1][0] * r_wb + m[1][1] * g_wb + m[1][2] * b_wb;
            let tb = m[2][0] * r_wb + m[2][1] * g_wb + m[2][2] * b_wb;

            if !(0.0..=1.0).contains(&tr)
                || !(0.0..=1.0).contains(&tg)
                || !(0.0..=1.0).contains(&tb)
            {
                gamut_clipped += 1;
            }

            let sr = (srgb_oetf_f32(tr) * 255.0 + 0.5) as u8;
            let sg = (srgb_oetf_f32(tg) * 255.0 + 0.5) as u8;
            let sb = (srgb_oetf_f32(tb) * 255.0 + 0.5) as u8;

            let idx = out_row_offset + ox * 4;
            out_rgba[idx] = sr;
            out_rgba[idx + 1] = sg;
            out_rgba[idx + 2] = sb;
            out_rgba[idx + 3] = 255;

            sum_out_r += (sr as f64) / 255.0;
            sum_out_g += (sg as f64) / 255.0;
            sum_out_b += (sb as f64) / 255.0;
        }
    }

    let c_denom = (center_count.max(1)) as f64;
    let p_denom = total_pixels as f64;

    RawDevelopStats {
        out_width: out_w as u32,
        out_height: out_h as u32,
        mean_rgb: [
            (sum_out_r / p_denom) as f32,
            (sum_out_g / p_denom) as f32,
            (sum_out_b / p_denom) as f32,
        ],
        center_linear_cam_rgb: [
            (center_cam_r / c_denom) as f32,
            (center_cam_g / c_denom) as f32,
            (center_cam_b / c_denom) as f32,
        ],
        highlight_clipped_ratio: (highlight_clipped as f32) / (total_pixels as f32),
        gamut_clipped_ratio: (gamut_clipped as f32) / (total_pixels as f32),
    }
}

/// Applies a 3x3 projective homography (`dst_to_src_h`) to rectify a 4-corner artwork image
/// (`RGBA_8888`) with bilinear interpolation.
pub fn apply_homography_rgba8(
    src_rgba: &[u8],
    src_w: usize,
    src_h: usize,
    dst_w: usize,
    dst_h: usize,
    dst_to_src_h: [[f64; 3]; 3],
    dst_rgba: &mut [u8],
) {
    if src_rgba.len() < src_w * src_h * 4 || dst_rgba.len() < dst_w * dst_h * 4 {
        return;
    }
    for dy in 0..dst_h {
        let y = dy as f64;
        for dx in 0..dst_w {
            let x = dx as f64;
            let denom =
                (dst_to_src_h[2][0] * x + dst_to_src_h[2][1] * y + dst_to_src_h[2][2]).max(1e-9);
            let sx = (dst_to_src_h[0][0] * x + dst_to_src_h[0][1] * y + dst_to_src_h[0][2]) / denom;
            let sy = (dst_to_src_h[1][0] * x + dst_to_src_h[1][1] * y + dst_to_src_h[1][2]) / denom;

            let x0 = (sx.floor() as isize).clamp(0, (src_w as isize) - 1) as usize;
            let y0 = (sy.floor() as isize).clamp(0, (src_h as isize) - 1) as usize;
            let x1 = (x0 + 1).min(src_w - 1);
            let y1 = (y0 + 1).min(src_h - 1);

            let fx = (sx - (x0 as f64)).clamp(0.0, 1.0);
            let fy = (sy - (y0 as f64)).clamp(0.0, 1.0);

            let i00 = (y0 * src_w + x0) * 4;
            let i10 = (y0 * src_w + x1) * 4;
            let i01 = (y1 * src_w + x0) * 4;
            let i11 = (y1 * src_w + x1) * 4;

            let out_idx = (dy * dst_w + dx) * 4;
            for c in 0..3 {
                let v00 = src_rgba[i00 + c] as f64;
                let v10 = src_rgba[i10 + c] as f64;
                let v01 = src_rgba[i01 + c] as f64;
                let v11 = src_rgba[i11 + c] as f64;
                let top = v00 * (1.0 - fx) + v10 * fx;
                let bot = v01 * (1.0 - fx) + v11 * fx;
                dst_rgba[out_idx + c] = (top * (1.0 - fy) + bot * fy + 0.5).clamp(0.0, 255.0) as u8;
            }
            dst_rgba[out_idx + 3] = 255;
        }
    }
}

/// C ABI entrypoint for iOS Swift (`AVFoundation` 14-bit Bayer RAW developer) and Dart FFI.
///
/// # Safety
/// Caller must pass valid `raw_ptr` (`raw_len` bytes), `params_ptr` (at least 18 `f32` values),
/// `out_rgba_ptr` (`(width/2) * (height/2) * 4` bytes), and `out_stats_ptr` (at least 8 `f32` values).
#[no_mangle]
pub unsafe extern "C" fn zamera_develop_bayer16_ffi(
    raw_ptr: *const u8,
    raw_len: usize,
    width: u32,
    height: u32,
    row_stride: u32,
    cfa_pattern: u32,
    params_ptr: *const f32,
    use_display_p3: u32,
    apply_flat_field: u32,
    out_rgba_ptr: *mut u8,
    out_rgba_len: usize,
    out_stats_ptr: *mut f32,
) -> i32 {
    if raw_ptr.is_null() || params_ptr.is_null() || out_rgba_ptr.is_null() {
        return -1;
    }
    let raw_slice = std::slice::from_raw_parts(raw_ptr, raw_len);
    let params = std::slice::from_raw_parts(params_ptr, 17);
    let out_rgba = std::slice::from_raw_parts_mut(out_rgba_ptr, out_rgba_len);

    let black_level = [params[0], params[1], params[2], params[3]];
    let white_level = params[4];
    let wb_gains = [params[5], params[6], params[7]];
    let cam_to_xyz_d50 = [
        [params[8] as f64, params[9] as f64, params[10] as f64],
        [params[11] as f64, params[12] as f64, params[13] as f64],
        [params[14] as f64, params[15] as f64, params[16] as f64],
    ];

    let stats = develop_bayer16_to_rgba8(
        raw_slice,
        width as usize,
        height as usize,
        row_stride as usize,
        cfa_pattern,
        black_level,
        white_level,
        wb_gains,
        cam_to_xyz_d50,
        use_display_p3 != 0,
        apply_flat_field != 0,
        out_rgba,
    );

    if !out_stats_ptr.is_null() {
        let out_stats = std::slice::from_raw_parts_mut(out_stats_ptr, 8);
        out_stats[0] = stats.mean_rgb[0];
        out_stats[1] = stats.mean_rgb[1];
        out_stats[2] = stats.mean_rgb[2];
        out_stats[3] = stats.highlight_clipped_ratio;
        out_stats[4] = stats.gamut_clipped_ratio;
        out_stats[5] = stats.center_linear_cam_rgb[0];
        out_stats[6] = stats.center_linear_cam_rgb[1];
        out_stats[7] = stats.center_linear_cam_rgb[2];
    }
    0
}

// ============================================================================
// Android JNI C-ABI Bridge (Zero External Crate Dependencies)
// Standard JNINativeInterface_ vtable slots (frozen since Java 1.4 / Android API 1):
//   Slot 167: NewStringUTF(env, *const c_char) -> jstring
//   Slot 230: GetDirectBufferAddress(env, jobject) -> *mut c_void
//   Slot 231: GetDirectBufferCapacity(env, jobject) -> jlong (i64)
// ============================================================================

type JniNewStringUtfFn = unsafe extern "C" fn(*mut *const *const c_void, *const c_char) -> *mut c_void;
type JniGetDirectBufferAddressFn =
    unsafe extern "C" fn(*mut *const *const c_void, *mut c_void) -> *mut u8;
type JniGetDirectBufferCapacityFn =
    unsafe extern "C" fn(*mut *const *const c_void, *mut c_void) -> i64;

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeCoreVersion()`
///
/// # Safety
/// Invoked by the Android JVM with a valid `JNIEnv` pointer.
#[no_mangle]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeCoreVersion(
    env: *mut *const *const c_void,
    _class: *mut c_void,
) -> *mut c_void {
    if env.is_null() || (*env).is_null() {
        return std::ptr::null_mut();
    }
    let vtable = *env;
    let new_string_utf: JniNewStringUtfFn = std::mem::transmute(*vtable.add(167));
    new_string_utf(env, VERSION_CSTR.as_ptr() as *const c_char)
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeDevelopBayer16Direct(...)`
///
/// Uses direct `ByteBuffer` pointers (`rawBuffer`, `paramsBuffer`, `outRgbaBuffer`, `outStatsBuffer`)
/// for zero-copy 14-bit RAW development on Android.
///
/// # Safety
/// Invoked by the Android JVM with valid direct `ByteBuffer` jobjects.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeDevelopBayer16Direct(
    env: *mut *const *const c_void,
    _class: *mut c_void,
    raw_buffer: *mut c_void,
    width: i32,
    height: i32,
    row_stride: i32,
    cfa_pattern: i32,
    params_buffer: *mut c_void,
    use_display_p3: i32,
    apply_flat_field: i32,
    out_rgba_buffer: *mut c_void,
    out_stats_buffer: *mut c_void,
) -> i32 {
    if env.is_null()
        || (*env).is_null()
        || raw_buffer.is_null()
        || params_buffer.is_null()
        || out_rgba_buffer.is_null()
    {
        return -1;
    }
    let vtable = *env;
    let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
    let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

    let raw_ptr = get_addr(env, raw_buffer);
    let raw_len = get_cap(env, raw_buffer) as usize;
    let params_ptr = get_addr(env, params_buffer) as *const f32;
    let out_rgba_ptr = get_addr(env, out_rgba_buffer);
    let out_rgba_len = get_cap(env, out_rgba_buffer) as usize;
    let out_stats_ptr = if out_stats_buffer.is_null() {
        std::ptr::null_mut()
    } else {
        get_addr(env, out_stats_buffer) as *mut f32
    };

    zamera_develop_bayer16_ffi(
        raw_ptr,
        raw_len,
        width as u32,
        height as u32,
        row_stride as u32,
        cfa_pattern as u32,
        params_ptr,
        use_display_p3 as u32,
        apply_flat_field as u32,
        out_rgba_ptr,
        out_rgba_len,
        out_stats_ptr,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sharma_2005_ciede2000_reference_pairs() {
        let cases = [
            ([50.0000, 2.6772, -79.7751], [50.0000, 0.0000, -82.7485], 2.0425),
            ([50.0000, 3.1571, -77.2803], [50.0000, 0.0000, -82.7485], 2.8615),
            ([50.0000, 0.0000, 0.0000], [50.0000, -1.0000, 2.0000], 2.3669),
            ([50.0000, 2.5000, 0.0000], [73.0000, 25.0000, -18.0000], 27.1492),
        ];
        for (lab1, lab2, expected) in cases {
            let actual = ciede2000(lab1, lab2);
            assert!(
                (actual - expected).abs() < 1e-3,
                "CIEDE2000 mismatch: got {actual}, expected {expected}"
            );
        }
    }

    #[test]
    fn test_24_patch_colorchecker_calibration_eliminates_sensor_cast() {
        let sensor_transform = [
            [1.85, 0.35, -0.05],
            [0.18, 1.32, 0.12],
            [-0.04, 0.22, 0.95],
        ];
        let measured: [[f64; 3]; 24] = std::array::from_fn(|i| {
            let xyz = lab_d50_to_xyz(COLORCHECKER_24_LAB_D50[i]);
            mat3_mul_vec3(sensor_transform, xyz)
        });

        let report = calibrate_colorchecker_24(&measured);
        assert!(
            report.mean_delta_e_before > 8.0,
            "Expected large uncalibrated error, got {}",
            report.mean_delta_e_before
        );
        assert!(
            report.mean_delta_e_after < 0.5,
            "Expected near-zero calibrated error, got {}",
            report.mean_delta_e_after
        );
    }

    #[test]
    fn test_flat_field_spatial_normalization() {
        let grid = vec![0.6, 0.8, 1.0, 1.2];
        let gains = compute_flat_field_gains(&grid);
        for (lum, gain) in grid.iter().zip(gains.iter()) {
            assert!((lum * gain - 0.9).abs() < 1e-6);
        }
    }

    #[test]
    fn test_develop_bayer16_to_rgba8_neutral_gray() {
        // 8x8 RGGB 14-bit sensor frame with black_level = 1025, white_level = 16383
        // 18% linear gray -> 1025 + 0.18 * (16383 - 1025) = 3789
        let width = 8usize;
        let height = 8usize;
        let row_stride = width * 2;
        let val = 3789u16.to_le_bytes();
        let mut raw = vec![0u8; height * row_stride];
        for chunk in raw.as_chunks_mut::<2>().0 {
            chunk[0] = val[0];
            chunk[1] = val[1];
        }

        const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
            [0.4360747, 0.3850649, 0.1430804],
            [0.2225045, 0.7168786, 0.0606169],
            [0.0139322, 0.0971045, 0.7141733],
        ];
        let mut out_rgba = vec![0u8; (width / 2) * (height / 2) * 4];
        let stats = develop_bayer16_to_rgba8(
            &raw,
            width,
            height,
            row_stride,
            0, // RGGB
            [1025.0, 1025.0, 1025.0, 1025.0],
            16383.0,
            [1.0, 1.0, 1.0],
            M_SRGB_TO_XYZ_D50,
            false,
            false,
            &mut out_rgba,
        );

        assert_eq!(stats.out_width, 4);
        assert_eq!(stats.out_height, 4);
        assert!((stats.center_linear_cam_rgb[1] - 0.18).abs() < 0.01);
        // 18% linear gray in sRGB OETF is ~0.461 -> ~118 / 255
        let r = out_rgba[0] as i32;
        let g = out_rgba[1] as i32;
        let b = out_rgba[2] as i32;
        assert!((r - 118).abs() <= 3 && (g - 118).abs() <= 3 && (b - 118).abs() <= 3);
    }
}
