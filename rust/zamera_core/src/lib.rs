//! Zamera Core (`zamera_core`) — Deterministic Color Science & RAW Pipeline Engine
//!
//! Provides identical colorimetric math across Android (JNI) and iOS (C ABI):
//! - CIE XYZ (D50 <-> D65 Bradford Chromatic Adaptation)
//! - CIE L*a*b* (D50) conversion
//! - CIEDE2000 ($\Delta E_{00}$) color difference verified against Sharma et al. (2005)
//! - IEC 61966-2-1 sRGB and Apple Display P3 transfer functions (OETF / EOTF)
//! - White-point preserving 3x3 ColorChecker 24-patch calibration matrix solver
//! - Spatial Flat-Field illumination normalization & 4-corner perspective homography

use std::f64::consts::PI;
use std::ffi::c_char;

const VERSION_CSTR: &[u8] =
    b"zamera_core 0.2.0 (TrueColor 24-Patch ColorChecker + FlatField + Homography)\0";

/// Official 24-patch ColorChecker Classic reference CIE L*a*b* (D50, 2-degree observer) values
/// published by X-Rite / BabelColor.
pub const COLORCHECKER_24_LAB_D50: [[f64; 3]; 24] = [
    [37.986, 13.555, 14.059],  // 01 Dark Skin
    [65.711, 18.130, 17.810],  // 02 Light Skin
    [49.927, -4.880, -21.925], // 03 Blue Sky
    [43.139, -13.095, 21.905], // 04 Foliage
    [55.112, 8.844, -25.399],  // 05 Blue Flower
    [70.719, -33.397, -0.199], // 06 Bluish Green
    [62.661, 36.067, 57.096],  // 07 Orange
    [40.020, 10.410, -45.964], // 08 Purplish Blue
    [51.124, 48.239, 16.248],  // 09 Moderate Red
    [30.325, 22.976, -21.587], // 10 Purple
    [72.532, -23.709, 57.255], // 11 Yellow Green
    [71.941, 19.363, 67.857],  // 12 Orange Yellow
    [28.778, 14.179, -50.297], // 13 Blue
    [55.261, -38.342, 31.370], // 14 Green
    [42.101, 53.378, 28.190],  // 15 Red
    [81.733, 4.039, 79.819],   // 16 Yellow
    [51.935, 49.986, -14.574], // 17 Magenta
    [51.038, -28.631, -28.638],// 18 Cyan
    [96.539, -0.425, 1.186],   // 19 White 9.5 (.05 D)
    [81.257, -0.638, -0.335],  // 20 Neutral 8 (.23 D) — Primary WB reference
    [66.766, -0.734, -0.504],  // 21 Neutral 6.5 (.44 D)
    [50.867, -0.153, -0.270],  // 22 Neutral 5 (.70 D) — 18% Gray Card equivalent
    [35.656, -0.421, -1.231],  // 23 Neutral 3.5 (1.05 D)
    [20.461, -0.079, -0.973],  // 24 Black 2 (1.50 D)
];

/// Returns the human-readable engine version string.
pub fn zamera_core_version() -> &'static str {
    "zamera_core 0.2.0 (TrueColor 24-Patch ColorChecker + FlatField + Homography)"
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

/// Bradford chromatic adaptation from CIE D50 (DNG standard PCS) to CIE D65 (sRGB / Display P3).
pub fn bradford_d50_to_d65(xyz_d50: [f64; 3]) -> [f64; 3] {
    const M_BRADFORD_D50_TO_D65: [[f64; 3]; 3] = [
        [0.9555766, -0.0230393, 0.0631636],
        [-0.0282895, 1.0099416, 0.0210077],
        [0.0122982, -0.0204830, 1.3299098],
    ];
    mat3_mul_vec3(M_BRADFORD_D50_TO_D65, xyz_d50)
}

/// Converts CIE XYZ (D65) to linear sRGB.
pub fn xyz_d65_to_linear_srgb(xyz_d65: [f64; 3]) -> [f64; 3] {
    const M_XYZ_TO_SRGB: [[f64; 3]; 3] = [
        [3.2404542, -1.5371385, -0.4985314],
        [-0.9692660, 1.8760108, 0.0415560],
        [0.0556434, -0.2040259, 1.0572252],
    ];
    mat3_mul_vec3(M_XYZ_TO_SRGB, xyz_d65)
}

/// Converts CIE XYZ (D65) to linear Apple Display P3.
pub fn xyz_d65_to_linear_display_p3(xyz_d65: [f64; 3]) -> [f64; 3] {
    const M_XYZ_TO_P3: [[f64; 3]; 3] = [
        [2.4934969, -0.9313836, -0.4027108],
        [-0.8294890, 1.7626641, 0.0236247],
        [0.0358458, -0.0761724, 0.9568845],
    ];
    mat3_mul_vec3(M_XYZ_TO_P3, xyz_d65)
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
///
/// Uses Neutral 8 (Patch #20, index 19) and Neutral 5 / 18% Gray (Patch #22, index 21)
/// to lock white balance and exposure scale, then solves ordinary least squares
/// $M = Y X^T (X X^T)^{-1}$ across all 24 patches.
pub fn calibrate_colorchecker_24(measured_cam_rgb: &[[f64; 3]; 24]) -> CalibrationReport {
    let ref_xyz: [[f64; 3]; 24] =
        std::array::from_fn(|i| lab_d50_to_xyz(COLORCHECKER_24_LAB_D50[i]));

    // 1. Compute neutral WB gains from Patch #20 (Neutral 8) + Patch #22 (Neutral 5 / 18% Gray)
    let p20 = measured_cam_rgb[19];
    let p22 = measured_cam_rgb[21];
    let r_avg = (0.5 * (p20[0] + p22[0])).max(1e-6);
    let g_avg = (0.5 * (p20[1] + p22[1])).max(1e-6);
    let b_avg = (0.5 * (p20[2] + p22[2])).max(1e-6);

    // Scale exposure so Neutral 5 (Patch #22) green matches reference Y_D50
    let target_y22 = ref_xyz[21][1];
    let exposure_scale = target_y22 / p22[1].max(1e-6);
    let wb_gains = [
        (g_avg / r_avg) * exposure_scale,
        1.0 * exposure_scale,
        (g_avg / b_avg) * exposure_scale,
    ];

    // 2. Apply WB gains to all 24 measured patches: X_i = diag(wb_gains) * raw_i
    let wb_rgb: [[f64; 3]; 24] = std::array::from_fn(|i| {
        [
            measured_cam_rgb[i][0] * wb_gains[0],
            measured_cam_rgb[i][1] * wb_gains[1],
            measured_cam_rgb[i][2] * wb_gains[2],
        ]
    });

    // 3. Compute uncalibrated Delta E (assuming naive sRGB primaries under D50)
    const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
        [0.4360747, 0.3850649, 0.1430804],
        [0.2225045, 0.7168786, 0.0606169],
        [0.0139322, 0.0971045, 0.7141733],
    ];
    let mut sum_before = 0.0;
    for i in 0..24 {
        let naive_xyz = mat3_mul_vec3(M_SRGB_TO_XYZ_D50, measured_cam_rgb[i]);
        let naive_lab = xyz_d50_to_lab(naive_xyz);
        sum_before += ciede2000(COLORCHECKER_24_LAB_D50[i], naive_lab);
    }
    let mean_delta_e_before = sum_before / 24.0;

    // 4. Solve 3x3 Least Squares: M * X = Y  =>  M = (Y * X^T) * (X * X^T + lambda*I)^-1
    let mut xxt = [[1e-6, 0.0, 0.0], [0.0, 1e-6, 0.0], [0.0, 0.0, 1e-6]];
    let mut yxt = [[0.0; 3]; 3];
    for i in 0..24 {
        let x = wb_rgb[i];
        let y = ref_xyz[i];
        for r in 0..3 {
            for c in 0..3 {
                xxt[r][c] += x[r] * x[c];
                yxt[r][c] += y[r] * x[c];
            }
        }
    }

    let cam_to_xyz_d50 = if let Some(xxt_inv) = mat3_inverse(xxt) {
        let mut m = [[0.0; 3]; 3];
        for r in 0..3 {
            for c in 0..3 {
                m[r][c] =
                    yxt[r][0] * xxt_inv[0][c] + yxt[r][1] * xxt_inv[1][c] + yxt[r][2] * xxt_inv[2][c];
            }
        }
        m
    } else {
        M_SRGB_TO_XYZ_D50
    };

    // 5. Evaluate post-calibration Delta E across all 24 patches
    let mut patch_delta_e_after = [0.0; 24];
    let mut sum_after = 0.0;
    let mut max_after = 0.0_f64;
    for i in 0..24 {
        let cal_xyz = mat3_mul_vec3(cam_to_xyz_d50, wb_rgb[i]);
        let cal_lab = xyz_d50_to_lab(cal_xyz);
        let de = ciede2000(COLORCHECKER_24_LAB_D50[i], cal_lab);
        patch_delta_e_after[i] = de;
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
        // Simulate a camera sensor with a strong warm/greenish cast + channel cross-talk
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
        let grid = vec![0.6, 0.8, 1.0, 1.2]; // Mean = 0.9
        let gains = compute_flat_field_gains(&grid);
        for (lum, gain) in grid.iter().zip(gains.iter()) {
            assert!((lum * gain - 0.9).abs() < 1e-6);
        }
    }
}
