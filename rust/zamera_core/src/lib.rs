//! Zamera Core (`zamera_core`) — Deterministic Color Science & Full-Resolution Striped RAW ISP Engine
//!
//! Provides identical colorimetric math and 14-bit Bayer RAW development across Android (JNI)
//! and iOS (C ABI):
//! - CIE XYZ (D50 <-> D65 Bradford Chromatic Adaptation)
//! - CIE L*a*b* (D50) conversion & CIEDE2000 ($\Delta E_{00}$) verified against Sharma et al. (2005)
//! - DNG 1.7 Specification iterative CCT solver (`ColorMatrix1`/`ColorMatrix2` -> `AsShotNeutral` -> xy -> CCT)
//!   and `ForwardMatrix1`/`ForwardMatrix2` Mired-weighted interpolation
//! - Linear White-Point / Gray-Card Exposure Normalization (eliminates ~2 EV RAW headroom underexposure
//!   without non-linear S-curves or hue twists)
//! - Full-resolution (`4096x3072` 12.6 MP) striped bilinear/green-balanced demosaicing + fast 2x2 superpixel mode
//! - 14-bit RAW 32-bin Histogram, Zebra highlight clipping map, and Sobel Focus Peaking analyzer
//! - Spatial Flat-Field illumination normalization & 4-corner perspective homography

use std::f64::consts::PI;
use std::ffi::{c_char, c_void};

const VERSION_STR: &str =
    "zamera_core 0.4.0 (JNI/FFI Active | 12.6MP Full-Res RAW ISP + DNG CCT Interp + Pro Zebra/Hist)";
const VERSION_CSTR: &[u8] =
    b"zamera_core 0.4.0 (JNI/FFI Active | 12.6MP Full-Res RAW ISP + DNG CCT Interp + Pro Zebra/Hist)\0";

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

/// Linearly interpolates two 3x3 matrices: $g \cdot M_1 + (1 - g) \cdot M_2$.
#[inline]
pub fn mat3_lerp(m1: [[f64; 3]; 3], m2: [[f64; 3]; 3], g: f64) -> [[f64; 3]; 3] {
    let w1 = g.clamp(0.0, 1.0);
    let w2 = 1.0 - w1;
    let mut out = [[0.0; 3]; 3];
    for r in 0..3 {
        for c in 0..3 {
            out[r][c] = w1 * m1[r][c] + w2 * m2[r][c];
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

/// Default Xiaomi 14 D65 `ColorMatrix1` (`XYZ -> CameraNeutral`).
pub const DEFAULT_CM1_D65: [[f64; 3]; 3] = [
    [0.8125, -0.2734, -0.1094],
    [-0.4375, 1.3281, 0.0859],
    [-0.0312, 0.2578, 0.4297],
];

/// Default Xiaomi 14 StdA (2856K) `ColorMatrix2` (`XYZ -> CameraNeutral`).
pub const DEFAULT_CM2_STDA: [[f64; 3]; 3] = [
    [1.2188, -0.4688, -0.4531],
    [-0.9766, 2.1797, -0.2891],
    [-0.1875, 0.3750, 0.6094],
];

/// Default Xiaomi 14 D65 `ForwardMatrix1` (`WhiteBalancedCamera -> XYZ D50`).
pub const DEFAULT_FM1_D65: [[f64; 3]; 3] = [
    [0.5469, 0.2734, 0.1406],
    [0.1875, 0.8672, -0.0547],
    [-0.0547, -0.3672, 1.2500],
];

/// Default Xiaomi 14 StdA (2856K) `ForwardMatrix2` (`WhiteBalancedCamera -> XYZ D50`).
pub const DEFAULT_FM2_STDA: [[f64; 3]; 3] = [
    [0.6016, -0.0391, 0.3984],
    [0.2734, 0.4688, 0.2500],
    [0.0547, -0.6562, 1.4219],
];

/// McCamy's formula converting CIE 1931 chromaticity `(x, y)` to Correlated Color Temperature (K).
#[inline]
pub fn xy_to_cct_mccamy(x: f64, y: f64) -> f64 {
    let denom = (0.1858 - y).abs().max(1e-6) * if 0.1858 - y >= 0.0 { 1.0 } else { -1.0 };
    let n = (x - 0.3320) / denom;
    (449.0 * n.powi(3) + 3525.0 * n.powi(2) + 6823.3 * n + 5520.33).clamp(1800.0, 25000.0)
}

/// Converts Correlated Color Temperature `kelvin` (2000K..12000K) and `tint` (-50..+50)
/// to CIE 1931 chromaticity `(x, y)` on the Planckian/Daylight locus.
pub fn kelvin_tint_to_xy(kelvin: f64, tint: f64) -> (f64, f64) {
    let t = kelvin.clamp(2000.0, 12000.0);
    let inv_t = 1000.0 / t;
    let inv_t2 = inv_t * inv_t;
    let inv_t3 = inv_t2 * inv_t;

    let x = if t <= 4000.0 {
        -0.2661239 * inv_t3 - 0.2343589 * inv_t2 + 0.8776956 * inv_t + 0.179910
    } else {
        -3.0258469 * inv_t3 + 2.1070379 * inv_t2 + 0.2226347 * inv_t + 0.240390
    };

    let x2 = x * x;
    let x3 = x2 * x;
    let y_locus = if t <= 2222.0 {
        -1.1063814 * x3 - 1.34811020 * x2 + 2.18555832 * x - 0.20219683
    } else if t <= 4000.0 {
        -0.9549476 * x3 - 1.37418593 * x2 + 2.09137015 * x - 0.16748867
    } else {
        3.0817580 * x3 - 5.87338670 * x2 + 3.75112997 * x - 0.37001483
    };

    // Tint shifts along the green/magenta isotherm (perpendicular to locus)
    let y = (y_locus - tint.clamp(-50.0, 50.0) * 0.00045).clamp(0.15, 0.55);
    (x.clamp(0.15, 0.55), y)
}

/// Computes the DNG mired interpolation weight `g` in `[0.0, 1.0]` between
/// `CalibrationIlluminant1` (D65 = 6504K, weight `g = 1.0`) and
/// `CalibrationIlluminant2` (StdA = 2856K, weight `g = 0.0`).
#[inline]
pub fn dng_mired_weight(cct: f64, cct1_d65: f64, cct2_stda: f64) -> f64 {
    let inv_c = 1.0 / cct.clamp(1800.0, 25000.0);
    let inv_1 = 1.0 / cct1_d65;
    let inv_2 = 1.0 / cct2_stda;
    ((inv_c - inv_2) / (inv_1 - inv_2)).clamp(0.0, 1.0)
}

/// DNG 1.7 Specification iterative solver:
/// Given `as_shot_neutral` (`[r_n, g_n, b_n]`), `ColorMatrix1` (D65), `ColorMatrix2` (StdA),
/// `ForwardMatrix1` (D65), and `ForwardMatrix2` (StdA), solves for the scene Correlated Color
/// Temperature (Kelvin), mired weight `g`, and the CCT-interpolated `ForwardMatrix`
/// (`WhiteBalancedCamera -> CIE XYZ D50`).
pub fn solve_dng_cct_and_interpolate_fm(
    as_shot_neutral: [f64; 3],
    cm1_d65: [[f64; 3]; 3],
    cm2_stda: [[f64; 3]; 3],
    fm1_d65: [[f64; 3]; 3],
    fm2_stda: [[f64; 3]; 3],
) -> (f64, f64, [[f64; 3]; 3]) {
    let mut xy = (0.3457, 0.3585); // Start at D50
    let mut cct = 5000.0;

    for _ in 0..25 {
        cct = xy_to_cct_mccamy(xy.0, xy.1);
        let g = dng_mired_weight(cct, 6504.0, 2856.0);
        let cm = mat3_lerp(cm1_d65, cm2_stda, g);
        let Some(cm_inv) = mat3_inverse(cm) else {
            break;
        };
        let xyz = mat3_mul_vec3(cm_inv, as_shot_neutral);
        let sum = (xyz[0] + xyz[1] + xyz[2]).max(1e-6);
        let next_xy = (xyz[0] / sum, xyz[1] / sum);
        if (next_xy.0 - xy.0).abs() < 1e-6 && (next_xy.1 - xy.1).abs() < 1e-6 {
            xy = next_xy;
            cct = xy_to_cct_mccamy(xy.0, xy.1);
            break;
        }
        xy = next_xy;
    }

    let g = dng_mired_weight(cct, 6504.0, 2856.0);
    let fm_interp = mat3_lerp(fm1_d65, fm2_stda, g);
    (cct, g, fm_interp)
}

/// Converts Pro Mode user `kelvin` (2000K..10000K) and `tint` (-50..+50) into physically
/// accurate DNG `RggbChannelVector` gains `[R, Gr, Gb, B]` and the corresponding
/// `ForwardMatrix -> sRGB` 3x3 color correction matrix.
pub fn kelvin_tint_to_dng_wb_and_srgb_matrix(
    kelvin: f64,
    tint: f64,
    cm1_d65: [[f64; 3]; 3],
    cm2_stda: [[f64; 3]; 3],
    fm1_d65: [[f64; 3]; 3],
    fm2_stda: [[f64; 3]; 3],
) -> ([f32; 4], [[f32; 3]; 3]) {
    let (x, y) = kelvin_tint_to_xy(kelvin, tint);
    let xyz = [x / y.max(1e-6), 1.0, (1.0 - x - y).max(0.0) / y.max(1e-6)];
    let g = dng_mired_weight(kelvin, 6504.0, 2856.0);
    let cm = mat3_lerp(cm1_d65, cm2_stda, g);
    let neutral = mat3_mul_vec3(cm, xyz);

    let nr = neutral[0].max(0.05);
    let ng = neutral[1].max(0.05);
    let nb = neutral[2].max(0.05);

    let r_gain = (ng / nr).clamp(0.7, 3.8) as f32;
    let b_gain = (ng / nb).clamp(0.7, 3.8) as f32;

    let fm = mat3_lerp(fm1_d65, fm2_stda, g);
    let m_d50_to_srgb = mat3_mul_mat3(M_XYZ_D65_TO_SRGB, M_BRADFORD_D50_TO_D65);
    let cam_to_srgb = mat3_mul_mat3(m_d50_to_srgb, fm);
    let mat_f32 = [
        [
            cam_to_srgb[0][0] as f32,
            cam_to_srgb[0][1] as f32,
            cam_to_srgb[0][2] as f32,
        ],
        [
            cam_to_srgb[1][0] as f32,
            cam_to_srgb[1][1] as f32,
            cam_to_srgb[1][2] as f32,
        ],
        [
            cam_to_srgb[2][0] as f32,
            cam_to_srgb[2][1] as f32,
            cam_to_srgb[2][2] as f32,
        ],
    ];

    ([r_gain, 1.0, 1.0, b_gain], mat_f32)
}

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
    pub patch_delta_e_before: [f64; 24],
    pub patch_delta_e_after: [f64; 24],
}

/// Solves the 3x3 Camera Linear RGB -> CIE XYZ (D50) calibration matrix and neutral White Balance
/// gains from 24 measured ColorChecker patch linear RGB values using D50 white-point
/// (`[0.96422, 1.0, 0.82521]`) constrained, neutral-gray weighted least squares.
pub fn calibrate_colorchecker_24(measured_cam_rgb: &[[f64; 3]; 24]) -> CalibrationReport {
    const D50_WHITE: [f64; 3] = [0.96422, 1.00000, 0.82521];
    const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
        [0.4360747, 0.3850649, 0.1430804],
        [0.2225045, 0.7168786, 0.0606169],
        [0.0139322, 0.0971045, 0.7141733],
    ];

    let ref_xyz: [[f64; 3]; 24] =
        std::array::from_fn(|i| lab_d50_to_xyz(COLORCHECKER_24_LAB_D50[i]));

    // Neutral gray patches (19..24 -> indices 18..23) receive higher regression weight
    let weights: [f64; 24] = std::array::from_fn(|i| {
        if (19..=22).contains(&i) {
            4.0
        } else if i >= 18 {
            2.5
        } else {
            1.0
        }
    });

    // Stage 1: Neutral-weighted unconstrained sensor->XYZ solve to recover exact D50 white sensor response
    let mut raw_xxt = [[1e-8, 0.0, 0.0], [0.0, 1e-8, 0.0], [0.0, 0.0, 1e-8]];
    let mut raw_yxt = [[0.0; 3]; 3];
    for i in 0..24 {
        let w = weights[i];
        let x = measured_cam_rgb[i];
        let y = ref_xyz[i];
        for r in 0..3 {
            for c in 0..3 {
                raw_xxt[r][c] += w * x[r] * x[c];
                raw_yxt[r][c] += w * y[r] * x[c];
            }
        }
    }

    let solved_wb = mat3_inverse(raw_xxt)
        .map(|inv| mat3_mul_mat3(raw_yxt, inv))
        .and_then(mat3_inverse)
        .and_then(|m_raw_inv| {
            let cam_white = mat3_mul_vec3(m_raw_inv, D50_WHITE);
            if cam_white[0] > 1e-5 && cam_white[1] > 1e-5 && cam_white[2] > 1e-5 {
                Some([1.0 / cam_white[0], 1.0 / cam_white[1], 1.0 / cam_white[2]])
            } else {
                None
            }
        });

    let wb_gains = if let Some(wb) = solved_wb {
        wb
    } else {
        let p20 = measured_cam_rgb[19];
        let p22 = measured_cam_rgb[21];
        let r_avg = (0.5 * (p20[0] + p22[0])).max(1e-6);
        let g_avg = (0.5 * (p20[1] + p22[1])).max(1e-6);
        let b_avg = (0.5 * (p20[2] + p22[2])).max(1e-6);
        let exposure_scale = ref_xyz[21][1] / p22[1].max(1e-6);
        [
            (g_avg / r_avg) * exposure_scale,
            1.0 * exposure_scale,
            (g_avg / b_avg) * exposure_scale,
        ]
    };

    let wb_rgb: [[f64; 3]; 24] = std::array::from_fn(|i| {
        [
            measured_cam_rgb[i][0] * wb_gains[0],
            measured_cam_rgb[i][1] * wb_gains[1],
            measured_cam_rgb[i][2] * wb_gains[2],
        ]
    });

    let mut patch_delta_e_before = [0.0; 24];
    let mut sum_before = 0.0;
    for ((de_slot, meas), ref_lab) in patch_delta_e_before
        .iter_mut()
        .zip(measured_cam_rgb.iter())
        .zip(COLORCHECKER_24_LAB_D50.iter())
    {
        let naive_xyz = mat3_mul_vec3(M_SRGB_TO_XYZ_D50, *meas);
        let naive_lab = xyz_d50_to_lab(naive_xyz);
        let de = ciede2000(*ref_lab, naive_lab);
        *de_slot = de;
        sum_before += de;
    }
    let mean_delta_e_before = sum_before / 24.0;

    // Stage 2: Exact D50 white-point constrained (M * [1,1,1]^T = D50_WHITE) + neutral-weighted 2x2 WLS per row
    let mut a00 = 1e-8_f64;
    let mut a01 = 0.0_f64;
    let mut a11 = 1e-8_f64;
    let mut b0 = [0.0_f64; 3];
    let mut b1 = [0.0_f64; 3];

    for i in 0..24 {
        let w = weights[i];
        let [r, g, b] = wb_rgb[i];
        let u = r - g;
        let v = b - g;
        a00 += w * u * u;
        a01 += w * u * v;
        a11 += w * v * v;
        for k in 0..3 {
            let zk = ref_xyz[i][k] - D50_WHITE[k] * g;
            b0[k] += w * u * zk;
            b1[k] += w * v * zk;
        }
    }

    let det2 = a00 * a11 - a01 * a01;
    let cam_to_xyz_d50 = if det2.abs() > 1e-14 {
        let inv_det2 = 1.0 / det2;
        std::array::from_fn(|k| {
            let m0 = (a11 * b0[k] - a01 * b1[k]) * inv_det2;
            let m2 = (-a01 * b0[k] + a00 * b1[k]) * inv_det2;
            let m1 = D50_WHITE[k] - m0 - m2;
            [m0, m1, m2]
        })
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
        patch_delta_e_before,
        patch_delta_e_after,
    }
}

/// Constant-hue and constant-luminance (`Y`) negative gamut compression:
/// When out-of-gamut pigments (such as Cobalt Blue or Emerald Green) produce `min_rgb < 0`,
/// desaturates radially toward the achromatic `[Y, Y, Y]` neutral axis instead of channel-clipping
/// to `0`, preventing Cobalt Blue -> Purple and Emerald -> Yellow-Green hue shifts.
#[inline]
pub fn compress_negative_gamut_constant_hue_y(
    r: f32,
    g: f32,
    b: f32,
    use_display_p3: bool,
) -> (f32, f32, f32) {
    let min_c = r.min(g).min(b);
    if min_c >= 0.0 {
        return (r, g, b);
    }
    let y = if use_display_p3 {
        0.2289746 * r + 0.6917385 * g + 0.0792869 * b
    } else {
        0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    };
    if y <= 1e-6 {
        return (0.0, 0.0, 0.0);
    }
    let denom = y - min_c;
    if denom <= 1e-6 {
        return (y, y, y);
    }
    let t = (y / denom).clamp(0.0, 1.0);
    (
        (y + t * (r - y)).max(0.0),
        (y + t * (g - y)).max(0.0),
        (y + t * (b - y)).max(0.0),
    )
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
    let (cr, cg, cb) = compress_negative_gamut_constant_hue_y(
        lin_srgb[0] as f32,
        lin_srgb[1] as f32,
        lin_srgb[2] as f32,
        false,
    );
    [
        srgb_oetf(cr as f64),
        srgb_oetf(cg as f64),
        srgb_oetf(cb as f64),
    ]
}

/// Reorders raw 2x2 quad values `[p00, p01, p10, p11]` into canonical `[R, Gr, Gb, B]`
/// according to `cfa_pattern` (`0=RGGB`, `1=GRBG`, `2=GBRG`, `3=BGGR`).
#[inline]
fn reorder_cfa_to_rggb(quad: [f32; 4], cfa_pattern: u32) -> [f32; 4] {
    let [p00, p01, p10, p11] = quad;
    match cfa_pattern {
        0 => [p00, p01, p10, p11], // RGGB
        1 => [p01, p00, p11, p10], // GRBG
        2 => [p10, p11, p00, p01], // GBRG
        _ => [p11, p10, p01, p00], // BGGR
    }
}

/// Extracts `[R, Gr, Gb, B]` 16-bit unsigned sensor values from a 2x2 Bayer quad at `(even_x, even_y)`.
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
    reorder_cfa_to_rggb([p00, p01, p10, p11], cfa_pattern)
}

/// Statistics returned by `develop_bayer16_to_rgba8`.
#[derive(Debug, Clone, Copy)]
pub struct RawDevelopStats {
    pub out_width: u32,
    pub out_height: u32,
    pub mean_rgb: [f32; 3],
    pub center_linear_cam_rgb: [f32; 3],
    pub center_lab_d50: [f32; 3],
    pub highlight_clipped_ratio: f32,
    pub gamut_clipped_ratio: f32,
    pub exposure_norm_gain: f32,
    pub solved_cct_kelvin: f32,
    pub histogram_32: [f32; 32],
    pub zebra_ratio: f32,
    pub focus_peaking_score: f32,
}

impl Default for RawDevelopStats {
    fn default() -> Self {
        Self {
            out_width: 0,
            out_height: 0,
            mean_rgb: [0.0; 3],
            center_linear_cam_rgb: [0.18; 3],
            center_lab_d50: [50.0, 0.0, 0.0],
            highlight_clipped_ratio: 0.0,
            gamut_clipped_ratio: 0.0,
            exposure_norm_gain: 1.0,
            solved_cct_kelvin: 5500.0,
            histogram_32: [0.0; 32],
            zebra_ratio: 0.0,
            focus_peaking_score: 0.0,
        }
    }
}

/// Bilinearly samples an `8x6` spatial flat-field gain map at normalized coordinates `(u, v)` in `[0, 1]`.
#[inline]
fn sample_flat_field_8x6(grid_8x6: &[f32; 48], u: f32, v: f32) -> f32 {
    let gx = (u.clamp(0.0, 1.0) * 7.0).clamp(0.0, 7.0);
    let gy = (v.clamp(0.0, 1.0) * 5.0).clamp(0.0, 5.0);
    let x0 = (gx.floor() as usize).min(6);
    let y0 = (gy.floor() as usize).min(4);
    let fx = gx - (x0 as f32);
    let fy = gy - (y0 as f32);
    let g00 = grid_8x6[y0 * 8 + x0];
    let g10 = grid_8x6[y0 * 8 + x0 + 1];
    let g01 = grid_8x6[(y0 + 1) * 8 + x0];
    let g11 = grid_8x6[(y0 + 1) * 8 + x0 + 1];
    let top = g00 * (1.0 - fx) + g10 * fx;
    let bot = g01 * (1.0 - fx) + g11 * fx;
    (top * (1.0 - fy) + bot * fy).clamp(0.5, 2.5)
}

/// Bilinearly samples a single channel of a 4-channel RGGB `LensShadingMap` (`8x6` per channel).
#[inline]
fn sample_lens_shading_8x6(grid_8x6: &[f32; 48], u: f32, v: f32) -> f32 {
    let gx = (u.clamp(0.0, 1.0) * 7.0).clamp(0.0, 7.0);
    let gy = (v.clamp(0.0, 1.0) * 5.0).clamp(0.0, 5.0);
    let x0 = (gx.floor() as usize).min(6);
    let y0 = (gy.floor() as usize).min(4);
    let fx = gx - (x0 as f32);
    let fy = gy - (y0 as f32);
    let g00 = grid_8x6[y0 * 8 + x0];
    let g10 = grid_8x6[y0 * 8 + x0 + 1];
    let g01 = grid_8x6[(y0 + 1) * 8 + x0];
    let g11 = grid_8x6[(y0 + 1) * 8 + x0 + 1];
    let top = g00 * (1.0 - fx) + g10 * fx;
    let bot = g01 * (1.0 - fx) + g11 * fx;
    (top * (1.0 - fy) + bot * fy).clamp(0.5, 4.5)
}

/// Develops a 16-bit little-endian Bayer `RAW_SENSOR` buffer into an 8-bit `RGBA_8888` buffer
/// in sRGB or Display P3 color space.
///
/// `exposure_mode` accepts `bool` (`false -> 0`, `true -> 1`) or `u32` (`0=off`, `1=paperL94`, `2=scene1to1`)
/// for 100% backward compatibility.
#[allow(clippy::too_many_arguments)]
pub fn develop_bayer16_to_rgba8<E: Into<u32>>(
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
    exposure_mode: E,
    flat_field_grid_8x6: Option<&[f32; 48]>,
    out_rgba: &mut [u8],
) -> RawDevelopStats {
    develop_bayer16_to_rgba8_ext(
        raw_bytes,
        width,
        height,
        row_stride,
        cfa_pattern,
        black_level,
        white_level,
        wb_gains,
        cam_to_xyz_d50,
        use_display_p3,
        exposure_mode.into(),
        flat_field_grid_8x6,
        None,
        out_rgba,
    )
}

/// Full TrueColor RAW developer supporting `exposure_mode` (`0=off`, `1=paperL94`, `2=scene1to1`),
/// constant-hue/constant-`Y` negative gamut compression, spatial flat-field `8x6`, and 4-channel
/// RGGB `4x48` lens shading correction.
#[allow(clippy::too_many_arguments)]
pub fn develop_bayer16_to_rgba8_ext(
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
    exposure_mode: u32,
    flat_field_grid_8x6: Option<&[f32; 48]>,
    rggb_shading_4x48: Option<&[[f32; 48]; 4]>,
    out_rgba: &mut [u8],
) -> RawDevelopStats {
    let qw = width / 2;
    let qh = height / 2;
    if qw == 0 || qh == 0 {
        return RawDevelopStats::default();
    }

    let full_res = out_rgba.len() >= width * height * 4;
    let out_w = if full_res { width } else { qw };
    let out_h = if full_res { height } else { qh };
    if out_rgba.len() < out_w * out_h * 4 {
        return RawDevelopStats::default();
    }

    // Reorder black_level to canonical [R, Gr, Gb, B] matching cfa_pattern (fixes B9)
    let bl = reorder_cfa_to_rggb(black_level, cfa_pattern);
    let denom_r = (white_level - bl[0]).max(1.0);
    let denom_gr = (white_level - bl[1]).max(1.0);
    let denom_gb = (white_level - bl[2]).max(1.0);
    let denom_b = (white_level - bl[3]).max(1.0);
    let clip_threshold = white_level * 0.992;
    let zebra_threshold = white_level * 0.95;

    // Pre-multiply Bradford (D50->D65) and target primaries (sRGB or Display P3) with cam_to_xyz_d50
    let m_d50_to_target = if use_display_p3 {
        mat3_mul_mat3(M_XYZ_D65_TO_DISPLAY_P3, M_BRADFORD_D50_TO_D65)
    } else {
        mat3_mul_mat3(M_XYZ_D65_TO_SRGB, M_BRADFORD_D50_TO_D65)
    };
    let m_total_f64 = mat3_mul_mat3(m_d50_to_target, cam_to_xyz_d50);
    let m_base = [
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

    let inv_qw = 1.0 / (qw.max(1) as f32);
    let inv_qh = 1.0 / (qh.max(1) as f32);

    // Pass 1: Fast subsampled telemetry, luminance & max-RGB pigment headroom pass (64x48 grid)
    let step_y = (qh / 48).max(1);
    let step_x = (qw / 64).max(1);
    let mut lum_samples = Vec::with_capacity(3200);
    let mut rgb_max_samples = Vec::with_capacity(3200);
    let mut hist_bins = [0u32; 32];
    let mut zebra_count = 0usize;
    let mut sample_count = 0usize;
    let mut peaking_sum = 0.0_f32;
    let mut prev_g = 0.0_f32;

    for qy in (0..qh).step_by(step_y) {
        let even_y = qy * 2;
        let v_norm = (qy as f32) * inv_qh;
        for qx in (0..qw).step_by(step_x) {
            let even_x = qx * 2;
            let u_norm = (qx as f32) * inv_qw;
            let [raw_r, raw_gr, raw_gb, raw_b] =
                extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

            if raw_r >= zebra_threshold
                || raw_gr >= zebra_threshold
                || raw_gb >= zebra_threshold
                || raw_b >= zebra_threshold
            {
                zebra_count += 1;
            }

            let mut lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
            let mut lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
            let mut lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
            let mut lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);

            if let Some(lsm) = rggb_shading_4x48 {
                lin_r *= sample_lens_shading_8x6(&lsm[0], u_norm, v_norm);
                lin_gr *= sample_lens_shading_8x6(&lsm[1], u_norm, v_norm);
                lin_gb *= sample_lens_shading_8x6(&lsm[2], u_norm, v_norm);
                lin_b *= sample_lens_shading_8x6(&lsm[3], u_norm, v_norm);
            }
            let ff_gain = if let Some(ff) = flat_field_grid_8x6 {
                sample_flat_field_8x6(ff, u_norm, v_norm)
            } else {
                1.0
            };

            let lin_g = 0.5 * (lin_gr + lin_gb);
            peaking_sum += (lin_g - prev_g).abs();
            prev_g = lin_g;

            let r_wb = lin_r * wb_gains[0] * ff_gain;
            let g_wb = lin_g * wb_gains[1] * ff_gain;
            let b_wb = lin_b * wb_gains[2] * ff_gain;
            let tr = m_base[0][0] * r_wb + m_base[0][1] * g_wb + m_base[0][2] * b_wb;
            let tg = m_base[1][0] * r_wb + m_base[1][1] * g_wb + m_base[1][2] * b_wb;
            let tb = m_base[2][0] * r_wb + m_base[2][1] * g_wb + m_base[2][2] * b_wb;
            let (cr, cg, cb) = compress_negative_gamut_constant_hue_y(tr, tg, tb, use_display_p3);
            let y_lin = if use_display_p3 {
                (0.2289746 * cr + 0.6917385 * cg + 0.0792869 * cb).max(0.0)
            } else {
                (0.2126729 * cr + 0.7151522 * cg + 0.0721750 * cb).max(0.0)
            };
            lum_samples.push(y_lin);
            rgb_max_samples.push(cr.max(cg).max(cb).max(0.0));

            let bin = ((lin_g.clamp(0.0, 1.0).sqrt() * 31.99) as usize).min(31);
            hist_bins[bin] += 1;
            sample_count += 1;
        }
    }

    // Exposure mode strategy:
    // - 0 (`off`): pure 1.0x unity gain.
    // - 1 (`paperL94`): document/paper white-point auto-normalization (anchors diffuse white to L* ~ 93-94).
    // - 2 (`scene1to1`): true-tone artwork mode — preserves dark chiaroscuro paintings without bleaching
    //   and caps gain at `0.95 / p995_rgb_max` so saturated Cadmium Red / Yellow pigments never clip!
    let exposure_norm_gain = match exposure_mode {
        1 if !lum_samples.is_empty() => {
            lum_samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            let len_m1 = lum_samples.len() - 1;
            let p50 = lum_samples[(len_m1 * 500) / 1000].max(0.008);
            let p88 = lum_samples[(len_m1 * 880) / 1000].max(0.025);
            let p985 = lum_samples[(len_m1 * 985) / 1000].max(0.04);

            let white_gain = 0.85 / p985;
            let diffuse_gain = (0.76 / p88).min(6.0);
            let mid_gain = (0.24 / p50).min(5.5);

            let blended_gain = if p985 > p88 * 1.65 {
                diffuse_gain.min(mid_gain * 1.65).max(mid_gain)
            } else {
                white_gain.max(mid_gain * 0.85).min(white_gain * 1.85)
            };
            blended_gain.clamp(1.0, 6.5)
        }
        2 if !rgb_max_samples.is_empty() => {
            rgb_max_samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            let len_m1 = rgb_max_samples.len() - 1;
            let p995_rgb_max = rgb_max_samples[(len_m1 * 995) / 1000].max(1e-4);
            let pigment_safe_cap = 0.95 / p995_rgb_max;
            let nominal_1to1 = if (wb_gains[1] - 1.0).abs() > 0.02 {
                1.0_f32
            } else {
                1.35_f32
            };
            nominal_1to1.min(pigment_safe_cap).clamp(0.15, 2.5)
        }
        _ => 1.0,
    };

    #[inline]
    fn apply_truecolor_highlight_shoulder(r: f32, g: f32, b: f32, knee: f32) -> (f32, f32, f32) {
        let max_c = r.max(g).max(b);
        if max_c <= knee {
            return (r, g, b);
        }
        let excess = max_c - knee;
        let head = (1.0 - knee).max(1e-4);
        let compressed_max = knee + head * (excess / (head + excess));
        let scale = compressed_max / max_c;
        (r * scale, g * scale, b * scale)
    }

    let shoulder_knee = if exposure_mode == 2 { 0.95_f32 } else { 0.84_f32 };

    let m = [
        [
            m_base[0][0] * exposure_norm_gain,
            m_base[0][1] * exposure_norm_gain,
            m_base[0][2] * exposure_norm_gain,
        ],
        [
            m_base[1][0] * exposure_norm_gain,
            m_base[1][1] * exposure_norm_gain,
            m_base[1][2] * exposure_norm_gain,
        ],
        [
            m_base[2][0] * exposure_norm_gain,
            m_base[2][1] * exposure_norm_gain,
            m_base[2][2] * exposure_norm_gain,
        ],
    ];

    let roi_x0 = qw * 45 / 100;
    let roi_x1 = (qw * 55 / 100).max(roi_x0 + 1);
    let roi_y0 = qh * 45 / 100;
    let roi_y1 = (qh * 55 / 100).max(roi_y0 + 1);

    let mut sum_out_r = 0.0_f64;
    let mut sum_out_g = 0.0_f64;
    let mut sum_out_b = 0.0_f64;
    let mut center_cam_r = 0.0_f64;
    let mut center_cam_g = 0.0_f64;
    let mut center_cam_b = 0.0_f64;
    let mut center_count = 0usize;
    let mut highlight_clipped = 0usize;
    let mut gamut_clipped = 0usize;

    if !full_res {
        // Half-resolution 2x2 superpixel mode (`qw x qh`)
        for qy in 0..qh {
            let even_y = qy * 2;
            let v_norm = (qy as f32) * inv_qh;
            let out_row_offset = qy * qw * 4;

            for qx in 0..qw {
                let even_x = qx * 2;
                let u_norm = (qx as f32) * inv_qw;
                let [raw_r, raw_gr, raw_gb, raw_b] =
                    extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

                if raw_r >= clip_threshold
                    || raw_gr >= clip_threshold
                    || raw_gb >= clip_threshold
                    || raw_b >= clip_threshold
                {
                    highlight_clipped += 1;
                }

                let mut lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
                let mut lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
                let mut lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
                let mut lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);

                if let Some(lsm) = rggb_shading_4x48 {
                    lin_r *= sample_lens_shading_8x6(&lsm[0], u_norm, v_norm);
                    lin_gr *= sample_lens_shading_8x6(&lsm[1], u_norm, v_norm);
                    lin_gb *= sample_lens_shading_8x6(&lsm[2], u_norm, v_norm);
                    lin_b *= sample_lens_shading_8x6(&lsm[3], u_norm, v_norm);
                }
                let lin_g = 0.5 * (lin_gr + lin_gb);

                if qx >= roi_x0 && qx < roi_x1 && qy >= roi_y0 && qy < roi_y1 {
                    center_cam_r += lin_r as f64;
                    center_cam_g += lin_g as f64;
                    center_cam_b += lin_b as f64;
                    center_count += 1;
                }

                let ff_gain = if let Some(ff) = flat_field_grid_8x6 {
                    sample_flat_field_8x6(ff, u_norm, v_norm)
                } else {
                    1.0
                };

                let r_wb = lin_r * wb_gains[0] * ff_gain;
                let g_wb = lin_g * wb_gains[1] * ff_gain;
                let b_wb = lin_b * wb_gains[2] * ff_gain;

                let raw_tr = m[0][0] * r_wb + m[0][1] * g_wb + m[0][2] * b_wb;
                let raw_tg = m[1][0] * r_wb + m[1][1] * g_wb + m[1][2] * b_wb;
                let raw_tb = m[2][0] * r_wb + m[2][1] * g_wb + m[2][2] * b_wb;

                if !(0.0..=1.0).contains(&raw_tr)
                    || !(0.0..=1.0).contains(&raw_tg)
                    || !(0.0..=1.0).contains(&raw_tb)
                {
                    gamut_clipped += 1;
                }

                let (pos_tr, pos_tg, pos_tb) =
                    compress_negative_gamut_constant_hue_y(raw_tr, raw_tg, raw_tb, use_display_p3);
                let (tr, tg, tb) = if exposure_mode != 0 {
                    apply_truecolor_highlight_shoulder(pos_tr, pos_tg, pos_tb, shoulder_knee)
                } else {
                    (pos_tr, pos_tg, pos_tb)
                };

                let sr = (srgb_oetf_f32(tr) * 255.0 + 0.5) as u8;
                let sg = (srgb_oetf_f32(tg) * 255.0 + 0.5) as u8;
                let sb = (srgb_oetf_f32(tb) * 255.0 + 0.5) as u8;

                let idx = out_row_offset + qx * 4;
                out_rgba[idx] = sr;
                out_rgba[idx + 1] = sg;
                out_rgba[idx + 2] = sb;
                out_rgba[idx + 3] = 255;

                sum_out_r += (sr as f64) / 255.0;
                sum_out_g += (sg as f64) / 255.0;
                sum_out_b += (sb as f64) / 255.0;
            }
        }
    } else {
        // Full-Resolution (`width x height`, e.g. 4096x3072 = 12.6 MP) Bilinear Color-Difference Demosaicing!
        let mut prev_row_cr = vec![0.0_f32; qw];
        let mut prev_row_cb = vec![0.0_f32; qw];
        let mut prev_row_g = vec![0.0_f32; qw];

        for qy in 0..qh {
            let even_y = qy * 2;
            let v_norm = (qy as f32) * inv_qh;
            let row0_out = even_y * width * 4;
            let row1_out = (even_y + 1) * width * 4;

            let mut prev_cr = 0.0_f32;
            let mut prev_cb = 0.0_f32;
            let mut prev_g = 0.0_f32;

            for qx in 0..qw {
                let even_x = qx * 2;
                let u_norm = (qx as f32) * inv_qw;
                let [raw_r, raw_gr, raw_gb, raw_b] =
                    extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

                if raw_r >= clip_threshold
                    || raw_gr >= clip_threshold
                    || raw_gb >= clip_threshold
                    || raw_b >= clip_threshold
                {
                    highlight_clipped += 1;
                }

                let mut lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
                let mut lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
                let mut lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
                let mut lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);

                if let Some(lsm) = rggb_shading_4x48 {
                    lin_r *= sample_lens_shading_8x6(&lsm[0], u_norm, v_norm);
                    lin_gr *= sample_lens_shading_8x6(&lsm[1], u_norm, v_norm);
                    lin_gb *= sample_lens_shading_8x6(&lsm[2], u_norm, v_norm);
                    lin_b *= sample_lens_shading_8x6(&lsm[3], u_norm, v_norm);
                }
                let lin_g_avg = 0.5 * (lin_gr + lin_gb);

                if qx >= roi_x0 && qx < roi_x1 && qy >= roi_y0 && qy < roi_y1 {
                    center_cam_r += lin_r as f64;
                    center_cam_g += lin_g_avg as f64;
                    center_cam_b += lin_b as f64;
                    center_count += 1;
                }

                let ff_gain = if let Some(ff) = flat_field_grid_8x6 {
                    sample_flat_field_8x6(ff, u_norm, v_norm)
                } else {
                    1.0
                };

                let r_wb = lin_r * wb_gains[0] * ff_gain;
                let gr_wb = lin_gr * wb_gains[1] * ff_gain;
                let gb_wb = lin_gb * wb_gains[1] * ff_gain;
                let g_avg_wb = lin_g_avg * wb_gains[1] * ff_gain;
                let b_wb = lin_b * wb_gains[2] * ff_gain;

                let raw_g_diff = 0.5 * (gr_wb - gb_wb);
                let noise_floor = 0.012 * (g_avg_wb + 0.04);
                let clean_g_diff = if raw_g_diff.abs() <= noise_floor {
                    0.0
                } else {
                    (raw_g_diff - raw_g_diff.signum() * noise_floor) * 0.45
                };
                let gr_eq = (g_avg_wb + clean_g_diff).max(0.0);
                let gb_eq = (g_avg_wb - clean_g_diff).max(0.0);

                let left_g = if qx > 0 { prev_g } else { g_avg_wb };
                let top_g = if qy > 0 { prev_row_g[qx] } else { g_avg_wb };
                prev_g = g_avg_wb;
                prev_row_g[qx] = g_avg_wb;

                let g00 = 0.70 * g_avg_wb + 0.15 * left_g + 0.15 * top_g;
                let g10 = 0.75 * gr_eq + 0.25 * top_g;
                let g01 = 0.75 * gb_eq + 0.25 * left_g;
                let g11 = g_avg_wb;

                let cr_curr = r_wb - g_avg_wb;
                let cb_curr = b_wb - g_avg_wb;
                let left_cr = if qx > 0 { prev_cr } else { cr_curr };
                let left_cb = if qx > 0 { prev_cb } else { cb_curr };
                let top_cr = if qy > 0 { prev_row_cr[qx] } else { cr_curr };
                let top_cb = if qy > 0 { prev_row_cb[qx] } else { cb_curr };
                prev_cr = cr_curr;
                prev_cb = cb_curr;
                prev_row_cr[qx] = cr_curr;
                prev_row_cb[qx] = cb_curr;

                let cr_smooth = 0.50 * cr_curr + 0.25 * left_cr + 0.25 * top_cr;
                let cb_smooth = 0.50 * cb_curr + 0.25 * left_cb + 0.25 * top_cb;

                let subpixels = [
                    ((g00 + cr_smooth).max(0.0), g00, (g00 + cb_smooth).max(0.0), row0_out + even_x * 4),
                    ((g10 + cr_smooth).max(0.0), g10, (g10 + cb_smooth).max(0.0), row0_out + (even_x + 1) * 4),
                    ((g01 + cr_smooth).max(0.0), g01, (g01 + cb_smooth).max(0.0), row1_out + even_x * 4),
                    ((g11 + cr_smooth).max(0.0), g11, (g11 + cb_smooth).max(0.0), row1_out + (even_x + 1) * 4),
                ];

                let mut quad_gamut_clipped = false;
                for (pr, pg, pb, out_idx) in subpixels {
                    let raw_tr = m[0][0] * pr + m[0][1] * pg + m[0][2] * pb;
                    let raw_tg = m[1][0] * pr + m[1][1] * pg + m[1][2] * pb;
                    let raw_tb = m[2][0] * pr + m[2][1] * pg + m[2][2] * pb;

                    if !(0.0..=1.0).contains(&raw_tr)
                        || !(0.0..=1.0).contains(&raw_tg)
                        || !(0.0..=1.0).contains(&raw_tb)
                    {
                        quad_gamut_clipped = true;
                    }

                    let (pos_tr, pos_tg, pos_tb) =
                        compress_negative_gamut_constant_hue_y(raw_tr, raw_tg, raw_tb, use_display_p3);
                    let (tr, tg, tb) = if exposure_mode != 0 {
                        apply_truecolor_highlight_shoulder(pos_tr, pos_tg, pos_tb, shoulder_knee)
                    } else {
                        (pos_tr, pos_tg, pos_tb)
                    };

                    let sr = (srgb_oetf_f32(tr) * 255.0 + 0.5) as u8;
                    let sg = (srgb_oetf_f32(tg) * 255.0 + 0.5) as u8;
                    let sb = (srgb_oetf_f32(tb) * 255.0 + 0.5) as u8;

                    out_rgba[out_idx] = sr;
                    out_rgba[out_idx + 1] = sg;
                    out_rgba[out_idx + 2] = sb;
                    out_rgba[out_idx + 3] = 255;
                }
                if quad_gamut_clipped {
                    gamut_clipped += 1;
                }

                let i0 = row0_out + even_x * 4;
                sum_out_r += (out_rgba[i0] as f64) / 255.0;
                sum_out_g += (out_rgba[i0 + 1] as f64) / 255.0;
                sum_out_b += (out_rgba[i0 + 2] as f64) / 255.0;
            }
        }
    }

    let c_denom = (center_count.max(1)) as f64;
    let q_denom = (qw * qh).max(1) as f64;
    let s_denom = (sample_count.max(1)) as f32;

    let mut histogram_32 = [0.0_f32; 32];
    let max_bin = (*hist_bins.iter().max().unwrap_or(&1)).max(1) as f32;
    for (dst, &cnt) in histogram_32.iter_mut().zip(hist_bins.iter()) {
        *dst = (cnt as f32) / max_bin;
    }

    let center_lin = [
        (center_cam_r / c_denom) as f32,
        (center_cam_g / c_denom) as f32,
        (center_cam_b / c_denom) as f32,
    ];
    let center_ff = if let Some(ff) = flat_field_grid_8x6 {
        sample_flat_field_8x6(ff, 0.5, 0.5)
    } else {
        1.0
    };
    let center_wb_scaled = [
        (center_lin[0] * wb_gains[0] * center_ff * exposure_norm_gain) as f64,
        (center_lin[1] * wb_gains[1] * center_ff * exposure_norm_gain) as f64,
        (center_lin[2] * wb_gains[2] * center_ff * exposure_norm_gain) as f64,
    ];
    let center_xyz_d50 = mat3_mul_vec3(cam_to_xyz_d50, center_wb_scaled);
    let center_lab_f64 = xyz_d50_to_lab([
        center_xyz_d50[0].max(0.0),
        center_xyz_d50[1].max(0.0),
        center_xyz_d50[2].max(0.0),
    ]);

    RawDevelopStats {
        out_width: out_w as u32,
        out_height: out_h as u32,
        mean_rgb: [
            (sum_out_r / q_denom) as f32,
            (sum_out_g / q_denom) as f32,
            (sum_out_b / q_denom) as f32,
        ],
        center_linear_cam_rgb: center_lin,
        center_lab_d50: [
            center_lab_f64[0] as f32,
            center_lab_f64[1] as f32,
            center_lab_f64[2] as f32,
        ],
        highlight_clipped_ratio: (highlight_clipped as f32) / (q_denom as f32),
        gamut_clipped_ratio: (gamut_clipped as f32) / (q_denom as f32),
        exposure_norm_gain,
        solved_cct_kelvin: 5500.0,
        histogram_32,
        zebra_ratio: (zebra_count as f32) / s_denom,
        focus_peaking_score: (peaking_sum / s_denom * 25.0).clamp(0.0, 1.0),
    }
}

/// Computes an `8x6` spatial flat-field gain map directly from a 16-bit Bayer `RAW_SENSOR` buffer
/// of a blank white/gray sheet.
pub fn extract_flat_field_8x6_from_bayer16(
    raw_bytes: &[u8],
    width: usize,
    height: usize,
    row_stride: usize,
    cfa_pattern: u32,
    black_level: [f32; 4],
    white_level: f32,
) -> [f32; 48] {
    let qw = (width / 2).max(1);
    let qh = (height / 2).max(1);
    let bl = reorder_cfa_to_rggb(black_level, cfa_pattern);
    let denom_g = (white_level - 0.5 * (bl[1] + bl[2])).max(1.0);

    let mut cell_sums = [0.0_f64; 48];
    let mut cell_counts = [0usize; 48];

    let step_y = (qh / 48).max(1);
    let step_x = (qw / 64).max(1);

    for qy in (0..qh).step_by(step_y) {
        let cy = ((qy * 6) / qh).min(5);
        let even_y = qy * 2;
        for qx in (0..qw).step_by(step_x) {
            let cx = ((qx * 8) / qw).min(7);
            let even_x = qx * 2;
            let [_, raw_gr, raw_gb, _] =
                extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);
            let g_lin = ((0.5 * (raw_gr + raw_gb) - 0.5 * (bl[1] + bl[2])) / denom_g).clamp(0.01, 1.0);
            let idx = cy * 8 + cx;
            cell_sums[idx] += g_lin as f64;
            cell_counts[idx] += 1;
        }
    }

    let cell_lums: Vec<f64> = cell_sums
        .iter()
        .zip(cell_counts.iter())
        .map(|(&s, &c)| if c > 0 { s / (c as f64) } else { 0.5 })
        .collect();
    let gains_f64 = compute_flat_field_gains(&cell_lums);
    let mut out = [1.0_f32; 48];
    for (dst, &g) in out.iter_mut().zip(gains_f64.iter()) {
        *dst = g as f32;
    }
    out
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
/// Closed-form 3x3 projective homography mapping the unit square `(s, t) in [0, 1]^2`
/// onto a 4-corner normalized quadrilateral `[TL, TR, BR, BL]`.
#[inline]
fn unit_square_to_quad_homography(corners: [[f32; 2]; 4]) -> [[f64; 3]; 3] {
    let (x0, y0) = (corners[0][0] as f64, corners[0][1] as f64);
    let (x1, y1) = (corners[1][0] as f64, corners[1][1] as f64);
    let (x2, y2) = (corners[2][0] as f64, corners[2][1] as f64);
    let (x3, y3) = (corners[3][0] as f64, corners[3][1] as f64);

    let dx1 = x1 - x2;
    let dy1 = y1 - y2;
    let dx2 = x3 - x2;
    let dy2 = y3 - y2;
    let sx = x0 - x1 + x2 - x3;
    let sy = y0 - y1 + y2 - y3;

    let det = dx1 * dy2 - dx2 * dy1;
    if (sx.abs() < 1e-8 && sy.abs() < 1e-8) || det.abs() < 1e-12 {
        [
            [x1 - x0, x3 - x0, x0],
            [y1 - y0, y3 - y0, y0],
            [0.0, 0.0, 1.0],
        ]
    } else {
        let g = (sx * dy2 - sy * dx2) / det;
        let h = (dx1 * sy - dy1 * sx) / det;
        let a = x1 - x0 + g * x1;
        let b = x3 - x0 + h * x3;
        let d = y1 - y0 + g * y1;
        let e = y3 - y0 + h * y3;
        [[a, b, x0], [d, e, y0], [g, h, 1.0]]
    }
}

/// Extracts the 24 linear sensor RGB (`[R, G, B]`) patch averages of an X-Rite 24-Patch ColorChecker
/// (`6 columns x 4 rows`) inside a 4-corner normalized quadrilateral `[TL, TR, BR, BL]` from a 16-bit
/// Bayer `RAW_SENSOR` buffer, applying optional `8x6` flat-field and `4x48` RGGB lens shading maps.
#[allow(clippy::too_many_arguments)]
pub fn extract_colorchecker_24_from_bayer16(
    raw_bytes: &[u8],
    width: usize,
    height: usize,
    row_stride: usize,
    cfa_pattern: u32,
    black_level: [f32; 4],
    white_level: f32,
    corners_norm: [[f32; 2]; 4],
    flat_field_grid_8x6: Option<&[f32; 48]>,
    rggb_shading_4x48: Option<&[[f32; 48]; 4]>,
) -> [[f64; 3]; 24] {
    let qw = width / 2;
    let qh = height / 2;
    if qw == 0 || qh == 0 {
        return [[0.18; 3]; 24];
    }

    let bl = reorder_cfa_to_rggb(black_level, cfa_pattern);
    let denom_r = (white_level - bl[0]).max(1.0);
    let denom_gr = (white_level - bl[1]).max(1.0);
    let denom_gb = (white_level - bl[2]).max(1.0);
    let denom_b = (white_level - bl[3]).max(1.0);

    let hom = unit_square_to_quad_homography(corners_norm);
    let mut patches = [[0.0_f64; 3]; 24];

    // Sample inner 42% of each cell on a 7x7 grid (avoids black grid borders between patches)
    const SUB_N: usize = 7;
    for row in 0..4 {
        for col in 0..6 {
            let patch_idx = row * 6 + col;
            let mut sum_r = 0.0_f64;
            let mut sum_g = 0.0_f64;
            let mut sum_b = 0.0_f64;
            let mut cnt = 0usize;

            for sy in 0..SUB_N {
                let rel_t = -0.21 + 0.42 * (sy as f64) / ((SUB_N - 1) as f64);
                let t_chart = ((row as f64) + 0.5 + rel_t) / 4.0;
                for sx in 0..SUB_N {
                    let rel_s = -0.21 + 0.42 * (sx as f64) / ((SUB_N - 1) as f64);
                    let s_chart = ((col as f64) + 0.5 + rel_s) / 6.0;

                    let w_proj = (hom[2][0] * s_chart + hom[2][1] * t_chart + hom[2][2]).max(1e-9);
                    let u = ((hom[0][0] * s_chart + hom[0][1] * t_chart + hom[0][2]) / w_proj)
                        .clamp(0.0, 0.999999) as f32;
                    let v = ((hom[1][0] * s_chart + hom[1][1] * t_chart + hom[1][2]) / w_proj)
                        .clamp(0.0, 0.999999) as f32;

                    let qx = ((u * (qw as f32)) as usize).min(qw - 1);
                    let qy = ((v * (qh as f32)) as usize).min(qh - 1);

                    let [raw_r, raw_gr, raw_gb, raw_b] =
                        extract_bayer_quad_rggb(raw_bytes, row_stride, qx * 2, qy * 2, cfa_pattern);

                    let mut lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
                    let mut lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
                    let mut lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
                    let mut lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);

                    if let Some(lsm) = rggb_shading_4x48 {
                        lin_r *= sample_lens_shading_8x6(&lsm[0], u, v);
                        lin_gr *= sample_lens_shading_8x6(&lsm[1], u, v);
                        lin_gb *= sample_lens_shading_8x6(&lsm[2], u, v);
                        lin_b *= sample_lens_shading_8x6(&lsm[3], u, v);
                    }
                    if let Some(ff) = flat_field_grid_8x6 {
                        let ffg = sample_flat_field_8x6(ff, u, v);
                        lin_r *= ffg;
                        lin_gr *= ffg;
                        lin_gb *= ffg;
                        lin_b *= ffg;
                    }

                    sum_r += lin_r as f64;
                    sum_g += (0.5 * (lin_gr + lin_gb)) as f64;
                    sum_b += lin_b as f64;
                    cnt += 1;
                }
            }

            let inv = 1.0 / (cnt.max(1) as f64);
            patches[patch_idx] = [
                (sum_r * inv).max(1e-5),
                (sum_g * inv).max(1e-5),
                (sum_b * inv).max(1e-5),
            ];
        }
    }

    patches
}

/// C ABI entrypoint for 24-Patch ColorChecker extraction + D50-constrained calibration from 16-bit Bayer RAW.
///
/// `params_ptr` layout (at least 5 `f32` values):
/// - `[0..4]`: `black_level`
/// - `[4]`: `white_level`
/// - Optional `[5..13]`: `corners_norm` (`[tl_x, tl_y, tr_x, tr_y, br_x, br_y, bl_x, bl_y]` in sensor `[0..1]`)
/// - Optional `[13..61]`: `flat_field_8x6` (`48` floats)
/// - Optional `[61..253]`: `rggb_shading_4x48` (`192` floats in `[R, Gr, Gb, B]` order)
///
/// `out_report_ptr` layout (at least 63 `f32` values):
/// - `[0..3]`: `wb_gains`
/// - `[3..12]`: `cam_to_xyz_d50` (9 row-major floats)
/// - `[12]`: `mean_delta_e_before`
/// - `[13]`: `mean_delta_e_after`
/// - `[14]`: `max_delta_e_after`
/// - `[15..39]`: `patch_delta_e_before` (24 floats)
/// - `[39..63]`: `patch_delta_e_after` (24 floats)
/// - Optional `[63..135]`: `measured_cam_rgb` (72 floats)
///
/// # Safety
/// Caller must pass valid pointers and lengths.
#[no_mangle]
pub unsafe extern "C" fn zamera_calibrate_colorchecker_24_ffi(
    raw_ptr: *const u8,
    raw_len: usize,
    width: u32,
    height: u32,
    row_stride: u32,
    cfa_pattern: u32,
    params_ptr: *const f32,
    params_len_floats: usize,
    out_report_ptr: *mut f32,
    out_report_len_floats: usize,
) -> i32 {
    if raw_ptr.is_null()
        || params_ptr.is_null()
        || out_report_ptr.is_null()
        || params_len_floats < 5
        || out_report_len_floats < 63
    {
        return -1;
    }

    let raw_slice = std::slice::from_raw_parts(raw_ptr, raw_len);
    let params = std::slice::from_raw_parts(params_ptr, params_len_floats);
    let out = std::slice::from_raw_parts_mut(out_report_ptr, out_report_len_floats);

    let black_level = [params[0], params[1], params[2], params[3]];
    let white_level = params[4];
    let corners_norm = if params_len_floats >= 13
        && (params[7] - params[5]).abs() + (params[8] - params[6]).abs() > 1e-3
    {
        [
            [params[5], params[6]],
            [params[7], params[8]],
            [params[9], params[10]],
            [params[11], params[12]],
        ]
    } else {
        [[0.15, 0.15], [0.85, 0.15], [0.85, 0.85], [0.15, 0.85]]
    };

    let ff_opt = if params_len_floats >= 61 && params[13] > 0.0 {
        let mut ff = [1.0_f32; 48];
        ff.copy_from_slice(&params[13..61]);
        Some(ff)
    } else {
        None
    };

    let lsm_opt = if params_len_floats >= 253 && params[61] > 0.0 {
        let mut lsm = [[1.0_f32; 48]; 4];
        for (ch, row) in lsm.iter_mut().enumerate() {
            let start = 61 + ch * 48;
            row.copy_from_slice(&params[start..start + 48]);
        }
        Some(lsm)
    } else {
        None
    };

    let mut measured = extract_colorchecker_24_from_bayer16(
        raw_slice,
        width as usize,
        height as usize,
        row_stride as usize,
        cfa_pattern,
        black_level,
        white_level,
        corners_norm,
        ff_opt.as_ref(),
        lsm_opt.as_ref(),
    );

    let mut report = calibrate_colorchecker_24(&measured);

    // Auto-orientation guard: if chart was placed 180-degrees upside-down inside the 4-corner quad,
    // reverse patch order when 180-deg flip dramatically lowers residual DeltaE00!
    if report.mean_delta_e_after > 10.0 {
        let flipped: [[f64; 3]; 24] = std::array::from_fn(|i| measured[23 - i]);
        let flipped_report = calibrate_colorchecker_24(&flipped);
        if flipped_report.mean_delta_e_after + 3.0 < report.mean_delta_e_after {
            measured = flipped;
            report = flipped_report;
        }
    }

    out[0] = report.wb_gains[0] as f32;
    out[1] = report.wb_gains[1] as f32;
    out[2] = report.wb_gains[2] as f32;
    for r in 0..3 {
        for c in 0..3 {
            out[3 + r * 3 + c] = report.cam_to_xyz_d50[r][c] as f32;
        }
    }
    out[12] = report.mean_delta_e_before as f32;
    out[13] = report.mean_delta_e_after as f32;
    out[14] = report.max_delta_e_after as f32;
    for i in 0..24 {
        out[15 + i] = report.patch_delta_e_before[i] as f32;
        out[39 + i] = report.patch_delta_e_after[i] as f32;
    }
    if out_report_len_floats >= 135 {
        for i in 0..24 {
            out[63 + i * 3] = measured[i][0] as f32;
            out[63 + i * 3 + 1] = measured[i][1] as f32;
            out[63 + i * 3 + 2] = measured[i][2] as f32;
        }
    }

    0
}

/// `params_ptr` layout (at least 17 `f32` values; if 47 `f32` values are provided, includes
/// `as_shot_neutral[3]`, `cm1[9]`, `cm2[9]`, `fm2[9]` for automatic DNG CCT interpolation;
/// `[47..95]` optional `flat_field_8x6`; `[95..287]` optional `rggb_shading_4x48`!):
/// - `[0..4]`: `black_level`
/// - `[4]`: `white_level`
/// - `[5..8]`: `wb_gains`
/// - `[8..17]`: `fm1_or_custom_cam_to_xyz_d50` (9 floats)
/// - Optional `[17..20]`: `as_shot_neutral` (3 floats; if `as_shot_neutral[1] > 0.0`, runs DNG CCT interpolation)
/// - Optional `[20..29]`: `cm1_d65` (9 floats)
/// - Optional `[29..38]`: `cm2_stda` (9 floats)
/// - Optional `[38..47]`: `fm2_stda` (9 floats)
/// - Optional `[47..95]`: `flat_field_8x6` (48 floats)
/// - Optional `[95..287]`: `rggb_shading_4x48` (192 floats, `4 x 48` `[R, Gr, Gb, B]`)
///
/// `exposure_mode`: `0=off`, `1=paperL94` (legacy `true`), `2=scene1to1` (true-tone artwork).
///
/// `out_stats_ptr` layout:
/// - `[0..3]`: `mean_rgb`
/// - `[3]`: `highlight_clipped_ratio`
/// - `[4]`: `gamut_clipped_ratio`
/// - `[5..8]`: `center_linear_cam_rgb`
/// - `[8]`: `exposure_norm_gain`
/// - `[9]`: `solved_cct_kelvin`
/// - `[10]`: `zebra_ratio`
/// - `[11]`: `focus_peaking_score`
/// - `[12..44]`: `histogram_32` (32 normalized floats)
/// - `[44..92]`: `measured_flat_field_8x6` (48 floats)
/// - `[92..95]`: `center_lab_d50` (3 floats `[L*, a*, b*]`)
///
/// # Safety
/// Caller must pass valid pointers and lengths.
#[no_mangle]
pub unsafe extern "C" fn zamera_develop_bayer16_ffi(
    raw_ptr: *const u8,
    raw_len: usize,
    width: u32,
    height: u32,
    row_stride: u32,
    cfa_pattern: u32,
    params_ptr: *const f32,
    params_len_floats: usize,
    use_display_p3: u32,
    exposure_mode: u32,
    out_rgba_ptr: *mut u8,
    out_rgba_len: usize,
    out_stats_ptr: *mut f32,
    out_stats_len_floats: usize,
) -> i32 {
    if raw_ptr.is_null() || params_ptr.is_null() || out_rgba_ptr.is_null() || params_len_floats < 17 {
        return -1;
    }
    let raw_slice = std::slice::from_raw_parts(raw_ptr, raw_len);
    let params = std::slice::from_raw_parts(params_ptr, params_len_floats);
    let out_rgba = std::slice::from_raw_parts_mut(out_rgba_ptr, out_rgba_len);

    let black_level = [params[0], params[1], params[2], params[3]];
    let white_level = params[4];
    let wb_gains = [params[5], params[6], params[7]];
    let fm1 = [
        [params[8] as f64, params[9] as f64, params[10] as f64],
        [params[11] as f64, params[12] as f64, params[13] as f64],
        [params[14] as f64, params[15] as f64, params[16] as f64],
    ];

    let (solved_cct, cam_to_xyz_d50) = if params_len_floats >= 47 && params[18] > 0.0 {
        let neutral = [params[17] as f64, params[18] as f64, params[19] as f64];
        let cm1 = [
            [params[20] as f64, params[21] as f64, params[22] as f64],
            [params[23] as f64, params[24] as f64, params[25] as f64],
            [params[26] as f64, params[27] as f64, params[28] as f64],
        ];
        let cm2 = [
            [params[29] as f64, params[30] as f64, params[31] as f64],
            [params[32] as f64, params[33] as f64, params[34] as f64],
            [params[35] as f64, params[36] as f64, params[37] as f64],
        ];
        let fm2 = [
            [params[38] as f64, params[39] as f64, params[40] as f64],
            [params[41] as f64, params[42] as f64, params[43] as f64],
            [params[44] as f64, params[45] as f64, params[46] as f64],
        ];
        let (cct, _g, fm_int) = solve_dng_cct_and_interpolate_fm(neutral, cm1, cm2, fm1, fm2);
        (cct as f32, fm_int)
    } else {
        (5500.0_f32, fm1)
    };

    let ff_opt = if params_len_floats >= 95 && params[47] > 0.0 {
        let mut ff = [1.0_f32; 48];
        ff.copy_from_slice(&params[47..95]);
        Some(ff)
    } else {
        None
    };

    let lsm_opt = if params_len_floats >= 287 && params[95] > 0.0 {
        let mut lsm = [[1.0_f32; 48]; 4];
        for (ch, row) in lsm.iter_mut().enumerate() {
            let start = 95 + ch * 48;
            row.copy_from_slice(&params[start..start + 48]);
        }
        Some(lsm)
    } else {
        None
    };

    let stats = develop_bayer16_to_rgba8_ext(
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
        exposure_mode,
        ff_opt.as_ref(),
        lsm_opt.as_ref(),
        out_rgba,
    );

    if !out_stats_ptr.is_null() && out_stats_len_floats >= 8 {
        let out_stats = std::slice::from_raw_parts_mut(out_stats_ptr, out_stats_len_floats);
        out_stats[0] = stats.mean_rgb[0];
        out_stats[1] = stats.mean_rgb[1];
        out_stats[2] = stats.mean_rgb[2];
        out_stats[3] = stats.highlight_clipped_ratio;
        out_stats[4] = stats.gamut_clipped_ratio;
        out_stats[5] = stats.center_linear_cam_rgb[0];
        out_stats[6] = stats.center_linear_cam_rgb[1];
        out_stats[7] = stats.center_linear_cam_rgb[2];
        if out_stats_len_floats >= 44 {
            out_stats[8] = stats.exposure_norm_gain;
            out_stats[9] = solved_cct;
            out_stats[10] = stats.zebra_ratio;
            out_stats[11] = stats.focus_peaking_score;
            out_stats[12..44].copy_from_slice(&stats.histogram_32);
        }
        if out_stats_len_floats >= 92 {
            let ff_measured = extract_flat_field_8x6_from_bayer16(
                raw_slice,
                width as usize,
                height as usize,
                row_stride as usize,
                cfa_pattern,
                black_level,
                white_level,
            );
            out_stats[44..92].copy_from_slice(&ff_measured);
        }
        if out_stats_len_floats >= 95 {
            out_stats[92..95].copy_from_slice(&stats.center_lab_d50);
        }
    }
    0
}

// ============================================================================
// Android JNI C-ABI Bridge (Zero External Crate Dependencies)
// ============================================================================

type JniNewStringUtfFn =
    unsafe extern "C" fn(*mut *const *const c_void, *const c_char) -> *mut c_void;
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
    exposure_mode: i32,
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
    let params_len_floats = (get_cap(env, params_buffer) as usize) / 4;
    let out_rgba_ptr = get_addr(env, out_rgba_buffer);
    let out_rgba_len = get_cap(env, out_rgba_buffer) as usize;
    let (out_stats_ptr, out_stats_len_floats) = if out_stats_buffer.is_null() {
        (std::ptr::null_mut(), 0usize)
    } else {
        (
            get_addr(env, out_stats_buffer) as *mut f32,
            (get_cap(env, out_stats_buffer) as usize) / 4,
        )
    };

    zamera_develop_bayer16_ffi(
        raw_ptr,
        raw_len,
        width as u32,
        height as u32,
        row_stride as u32,
        cfa_pattern as u32,
        params_ptr,
        params_len_floats,
        use_display_p3 as u32,
        exposure_mode as u32,
        out_rgba_ptr,
        out_rgba_len,
        out_stats_ptr,
        out_stats_len_floats,
    )
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeCalibrateColorChecker24Direct(...)`
///
/// Extracts the 6x4 ColorChecker patches from `raw_buffer` inside the 4-corner perspective quad
/// and solves the D50 white-point constrained + neutral-weighted 3x3 calibration matrix.
///
/// # Safety
/// Invoked by the Android JVM with valid direct `ByteBuffer` jobjects.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeCalibrateColorChecker24Direct(
    env: *mut *const *const c_void,
    _class: *mut c_void,
    raw_buffer: *mut c_void,
    width: i32,
    height: i32,
    row_stride: i32,
    cfa_pattern: i32,
    params_buffer: *mut c_void,
    out_report_buffer: *mut c_void,
) -> i32 {
    if env.is_null()
        || (*env).is_null()
        || raw_buffer.is_null()
        || params_buffer.is_null()
        || out_report_buffer.is_null()
    {
        return -1;
    }
    let vtable = *env;
    let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
    let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

    let raw_ptr = get_addr(env, raw_buffer);
    let raw_len = get_cap(env, raw_buffer) as usize;
    let params_ptr = get_addr(env, params_buffer) as *const f32;
    let params_len_floats = (get_cap(env, params_buffer) as usize) / 4;
    let out_report_ptr = get_addr(env, out_report_buffer) as *mut f32;
    let out_report_len_floats = (get_cap(env, out_report_buffer) as usize) / 4;

    zamera_calibrate_colorchecker_24_ffi(
        raw_ptr,
        raw_len,
        width as u32,
        height as u32,
        row_stride as u32,
        cfa_pattern as u32,
        params_ptr,
        params_len_floats,
        out_report_ptr,
        out_report_len_floats,
    )
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeKelvinWbDirect(...)`
///
/// Computes physically accurate DNG `RggbChannelVector` gains `[R, Gr, Gb, B]` and 3x3 sRGB transform
/// from `kelvin`, `tint`, and the sensor's `CM1`, `CM2`, `FM1`, `FM2`.
///
/// # Safety
/// Invoked by the Android JVM with valid direct `ByteBuffer` jobjects.
#[no_mangle]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeComputeKelvinWbDirect(
    env: *mut *const *const c_void,
    _class: *mut c_void,
    in_buffer: *mut c_void,
    out_buffer: *mut c_void,
) -> i32 {
    if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
        return -1;
    }
    let vtable = *env;
    let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
    let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

    let in_len = (get_cap(env, in_buffer) as usize) / 4;
    let out_len = (get_cap(env, out_buffer) as usize) / 4;
    if in_len < 38 || out_len < 13 {
        return -1;
    }

    let inp = std::slice::from_raw_parts(get_addr(env, in_buffer) as *const f32, in_len);
    let out = std::slice::from_raw_parts_mut(get_addr(env, out_buffer) as *mut f32, out_len);

    let kelvin = inp[0] as f64;
    let tint = inp[1] as f64;
    let cm1 = [
        [inp[2] as f64, inp[3] as f64, inp[4] as f64],
        [inp[5] as f64, inp[6] as f64, inp[7] as f64],
        [inp[8] as f64, inp[9] as f64, inp[10] as f64],
    ];
    let cm2 = [
        [inp[11] as f64, inp[12] as f64, inp[13] as f64],
        [inp[14] as f64, inp[15] as f64, inp[16] as f64],
        [inp[17] as f64, inp[18] as f64, inp[19] as f64],
    ];
    let fm1 = [
        [inp[20] as f64, inp[21] as f64, inp[22] as f64],
        [inp[23] as f64, inp[24] as f64, inp[25] as f64],
        [inp[26] as f64, inp[27] as f64, inp[28] as f64],
    ];
    let fm2 = [
        [inp[29] as f64, inp[30] as f64, inp[31] as f64],
        [inp[32] as f64, inp[33] as f64, inp[34] as f64],
        [inp[35] as f64, inp[36] as f64, inp[37] as f64],
    ];

    let (gains, mat) = kelvin_tint_to_dng_wb_and_srgb_matrix(kelvin, tint, cm1, cm2, fm1, fm2);
    out[0..4].copy_from_slice(&gains);
    out[4..7].copy_from_slice(&mat[0]);
    out[7..10].copy_from_slice(&mat[1]);
    out[10..13].copy_from_slice(&mat[2]);
    0
}

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
                return Err(format!("Satır {line_no}: DOMAIN_MIN 3 float değer içermelidir"));
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
                return Err(format!("Satır {line_no}: DOMAIN_MAX 3 float değer içermelidir"));
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
            return Err(String::from("DOMAIN_MAX her kanalda DOMAIN_MIN'den büyük olmalıdır"));
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

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeSoftwareAutoIsoDirect(...)`
///
/// Input direct float buffer `[7]`: `[current_iso, iso_min, iso_max, measured_luma, target_luma, angle_deg, fps]`
/// Output direct float buffer `[4]`: `[next_iso, nd_factor, shutter_exposure_ns_hi, frame_duration_ns_hi]`
///
/// # Safety
/// Invoked by Android JVM with valid direct `ByteBuffer` instances.
#[no_mangle]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeComputeSoftwareAutoIsoDirect(
    env: *mut *const *const c_void,
    _class: *mut c_void,
    in_buffer: *mut c_void,
    out_buffer: *mut c_void,
) -> i32 {
    if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
        return -1;
    }
    let vtable = *env;
    let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
    let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

    let in_len = (get_cap(env, in_buffer) as usize) / 4;
    let out_len = (get_cap(env, out_buffer) as usize) / 4;
    if in_len < 7 || out_len < 4 {
        return -1;
    }

    let inp = std::slice::from_raw_parts(get_addr(env, in_buffer) as *const f32, in_len);
    let out = std::slice::from_raw_parts_mut(get_addr(env, out_buffer) as *mut f32, out_len);

    let (next_iso, nd_factor) = compute_software_auto_iso_step(
        inp[0] as f64,
        inp[1] as f64,
        inp[2] as f64,
        inp[3] as f64,
        inp[4] as f64,
    );
    let shutter_ns = shutter_exposure_ns_from_angle(inp[5] as f64, inp[6] as f64);
    let frame_ns = frame_duration_ns_from_fps(inp[6] as f64);

    out[0] = next_iso as f32;
    out[1] = nd_factor as f32;
    out[2] = shutter_ns as f32;
    out[3] = frame_ns as f32;
    0
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeAudioDbfsDirect(...)`
///
/// Input direct float buffer `[N]`: normalized PCM float audio samples $x_i \in [-1.0, 1.0]$.
/// Output direct float buffer `[2]`: `[sample_peak_dbfs, rms_dbfs]`.
///
/// # Safety
/// Invoked by Android JVM with valid direct `ByteBuffer` instances.
#[no_mangle]
pub unsafe extern "C" fn Java_com_akarworks_zamera_1capture_ZameraRustBridge_nativeComputeAudioDbfsDirect(
    env: *mut *const *const c_void,
    _class: *mut c_void,
    in_buffer: *mut c_void,
    sample_count: i32,
    out_buffer: *mut c_void,
) -> i32 {
    if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
        return -1;
    }
    let vtable = *env;
    let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
    let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

    let cap_floats = (get_cap(env, in_buffer) as usize) / 4;
    let out_len = (get_cap(env, out_buffer) as usize) / 4;
    let count = (sample_count.max(0) as usize).min(cap_floats);
    if count == 0 || out_len < 2 {
        return -1;
    }

    let samples = std::slice::from_raw_parts(get_addr(env, in_buffer) as *const f32, count);
    let out = std::slice::from_raw_parts_mut(get_addr(env, out_buffer) as *mut f32, out_len);
    let (peak_db, rms_db) = compute_audio_peak_rms_dbfs(samples);
    out[0] = peak_db;
    out[1] = rms_db;
    0
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
        assert!(report.mean_delta_e_before > 8.0);
        assert!(report.mean_delta_e_after < 0.5);
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
    fn test_golden_xiaomi_14_dng_cct_interpolation_and_neutral_chroma() {
        // Real Xiaomi 14 DNG (`ZAMERA_1793970225879.dng`) AsShotNeutral under ~3927K indoor warm light
        let as_shot_neutral = [0.5176, 1.0, 0.5957];
        let (cct, g, fm_interp) = solve_dng_cct_and_interpolate_fm(
            as_shot_neutral,
            DEFAULT_CM1_D65,
            DEFAULT_CM2_STDA,
            DEFAULT_FM1_D65,
            DEFAULT_FM2_STDA,
        );

        assert!(
            (cct - 3927.0).abs() < 40.0,
            "Expected CCT ~ 3927K, got {cct}"
        );
        assert!(
            (g - 0.486).abs() < 0.02,
            "Expected mired weight g ~ 0.486, got {g}"
        );

        // Verify that a neutral surface with camera values proportional to AsShotNeutral
        // maps to near-zero chroma in CIE L*a*b* (D50)
        let wb_cam = [1.0, 1.0, 1.0];
        let xyz_d50 = mat3_mul_vec3(fm_interp, wb_cam);
        let lab = xyz_d50_to_lab(xyz_d50);
        let chroma = (lab[1] * lab[1] + lab[2] * lab[2]).sqrt();
        assert!(
            chroma < 1.5,
            "Expected near-zero neutral chroma, got {chroma} (Lab={lab:?})"
        );
    }

    #[test]
    fn test_develop_bayer16_full_res_and_white_point_normalization() {
        // 16x16 RGGB 14-bit sensor frame where a white surface is underexposed by ~2 EV (raw = 4200 / 16383)
        let width = 16usize;
        let height = 16usize;
        let row_stride = width * 2;
        let val = 4200u16.to_le_bytes();
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
        // Full-res buffer (`16 x 16 x 4`)
        let mut out_rgba = vec![0u8; width * height * 4];
        let stats = develop_bayer16_to_rgba8(
            &raw,
            width,
            height,
            row_stride,
            0,
            [1025.0, 1025.0, 1025.0, 1025.0],
            16383.0,
            [1.0, 1.0, 1.0],
            M_SRGB_TO_XYZ_D50,
            false,
            true, // normalize_exposure enabled!
            None,
            &mut out_rgba,
        );

        assert_eq!(stats.out_width, 16);
        assert_eq!(stats.out_height, 16);
        assert!(
            stats.exposure_norm_gain > 3.5,
            "Expected exposure gain > 3.5x for ~2 EV headroom, got {}",
            stats.exposure_norm_gain
        );
        // Normalized white surface (~0.85 linear -> ~0.93 sRGB -> ~237 / 255)
        assert!(
            out_rgba[0] >= 225 && out_rgba[1] >= 225 && out_rgba[2] >= 225,
            "Expected bright normalized white surface, got RGB=({}, {}, {})",
            out_rgba[0],
            out_rgba[1],
            out_rgba[2]
        );
    }

    #[test]
    fn test_sanat_mode_auto_exposure_immune_to_small_specular_reflection() {
        // Simulate a 32x32 14-bit Bayer scene where 96% of the frame is an underexposed midtone/paper
        // (raw = 2200 / 16383 -> ~0.077 linear) and 4% is a bright screen/lamp highlight (raw = 14800 / 16383 -> ~0.90 linear).
        // Previously, p985 hit the 4% highlight and locked exposure_norm_gain at ~1.0x, leaving the photo dark!
        let width = 32usize;
        let height = 32usize;
        let row_stride = width * 2;
        let mid_bytes = 2200u16.to_le_bytes();
        let spec_bytes = 14800u16.to_le_bytes();
        let mut raw = vec![0u8; height * row_stride];

        for y in 0..height {
            for x in 0..width {
                let idx = y * row_stride + x * 2;
                let is_specular = x < 6 && y < 6;
                let b = if is_specular { spec_bytes } else { mid_bytes };
                raw[idx] = b[0];
                raw[idx + 1] = b[1];
            }
        }

        const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
            [0.4360747, 0.3850649, 0.1430804],
            [0.2225045, 0.7168786, 0.0606169],
            [0.0139322, 0.0971045, 0.7141733],
        ];
        let mut out_rgba = vec![0u8; width * height * 4];
        let stats = develop_bayer16_to_rgba8(
            &raw,
            width,
            height,
            row_stride,
            0,
            [1025.0, 1025.0, 1025.0, 1025.0],
            16383.0,
            [1.0, 1.0, 1.0],
            M_SRGB_TO_XYZ_D50,
            false,
            true,
            None,
            &mut out_rgba,
        );

        assert!(
            stats.exposure_norm_gain > 2.2,
            "Expected hybrid p50/p88 gain > 2.2x despite small specular highlight, got {}",
            stats.exposure_norm_gain
        );
        // Check a diffuse pixel at center (16, 16) is well-lit (sRGB > 145)
        let center_idx = (16 * width + 16) * 4;
        assert!(
            out_rgba[center_idx] > 145,
            "Expected bright midtone pixel (> 145), got {}",
            out_rgba[center_idx]
        );
    }

    #[test]
    fn test_wp32_shutter_angle_and_auto_iso_controller() {
        // 180-degree shutter rule: 24 -> 1/48s, 25 -> 1/50s, 30 -> 1/60s, 60 -> 1/120s
        assert_eq!(shutter_exposure_ns_from_angle(180.0, 24.0), 20_833_333);
        assert_eq!(shutter_exposure_ns_from_angle(180.0, 25.0), 20_000_000);
        assert_eq!(shutter_exposure_ns_from_angle(180.0, 30.0), 16_666_667);
        assert_eq!(shutter_exposure_ns_from_angle(180.0, 60.0), 8_333_333);
        assert_eq!(frame_duration_ns_from_fps(30.0), 33_333_333);

        // Software Auto-ISO: max step per frame <= 1/6 EV (2^(1/6) ≈ 1.12246)
        let (next_iso, nd) = compute_software_auto_iso_step(100.0, 50.0, 3200.0, 0.15, 0.42);
        assert!(next_iso > 100.0 && next_iso <= 100.0 * 2.0_f64.powf(1.0 / 6.0) + 1e-4);
        assert_eq!(nd, 0);

        // Deadband (< 0.06 EV): zero ISO pumping
        let (steady_iso, _) = compute_software_auto_iso_step(200.0, 50.0, 3200.0, 0.415, 0.42);
        assert!((steady_iso - 200.0).abs() < 1e-6);

        // Overexposed at base ISO (50) by > 2.5 EV -> recommends ND8
        let (pinned_iso, nd8) = compute_software_auto_iso_step(50.0, 50.0, 3200.0, 0.95, 0.14);
        assert!((pinned_iso - 50.0).abs() < 1e-6);
        assert_eq!(nd8, 8);
    }

    #[test]
    fn test_wp33_cube_lut_parser_identity_and_builtin_luts() {
        // Generate 17x17x17 identity LUT in .cube text format and parse it
        let mut cube_str = String::from(
            "# Zamera Identity 3D LUT\nTITLE \"Zamera Identity 17\"\nDOMAIN_MIN 0.0 0.0 0.0\nDOMAIN_MAX 1.0 1.0 1.0\nLUT_3D_SIZE 17\n",
        );
        for b in 0..17 {
            for g in 0..17 {
                for r in 0..17 {
                    cube_str.push_str(&format!(
                        "{:.6} {:.6} {:.6}\n",
                        r as f32 / 16.0,
                        g as f32 / 16.0,
                        b as f32 / 16.0
                    ));
                }
            }
        }
        let lut = parse_cube_lut(&cube_str).expect("Valid 17^3 .cube must parse");
        assert_eq!(lut.title, "Zamera Identity 17");
        assert_eq!(lut.size, 17);

        // Identity LUT DoD: reproduces arbitrary RGB inputs with error <= 1/1023
        let test_colors = [
            [0.0, 0.0, 0.0],
            [1.0, 1.0, 1.0],
            [0.18, 0.42, 0.73],
            [0.91, 0.12, 0.34],
            [0.50, 0.50, 0.50],
        ];
        for c in test_colors {
            let out = lut.sample_trilinear(c);
            for ch in 0..3 {
                assert!(
                    (out[ch] - c[ch]).abs() <= (1.0 / 1023.0),
                    "Identity LUT error exceeded 1/1023: in={c:?}, out={out:?}"
                );
            }
        }

        // Corrupted .cube file returns descriptive Err instead of panicking
        let bad = parse_cube_lut("TITLE \"Bad\"\nLUT_3D_SIZE 17\n0.0 0.0 0.0\n");
        assert!(bad.is_err());

        // Built-in LUTs (Rec.709, Sıcak Sinema, Noir)
        let noir = generate_builtin_lut(3, 17);
        let noir_sample = noir.sample_trilinear([0.8, 0.3, 0.2]);
        assert!((noir_sample[0] - noir_sample[1]).abs() < 1e-5);
        assert!((noir_sample[1] - noir_sample[2]).abs() < 1e-5);
    }

    #[test]
    fn test_wp34_audio_dbfs_and_false_color_ire_bands() {
        // Full scale 1.0 -> 0.0 dBFS peak; 0.5 amplitude -> -6.0206 dBFS
        let (peak0, rms0) = compute_audio_peak_rms_dbfs(&[1.0, -1.0, 1.0, -1.0]);
        assert!(peak0.abs() < 1e-3);
        assert!(rms0.abs() < 1e-3);

        let (peak_half, _) = compute_audio_peak_rms_dbfs(&[0.5, -0.5]);
        assert!((peak_half - (-6.0206)).abs() < 0.02);

        let (peak_silent, rms_silent) = compute_audio_peak_rms_dbfs(&[0.0, 0.0]);
        assert_eq!(peak_silent, -96.0);
        assert_eq!(rms_silent, -96.0);

        // 6-Band IRE False Color verification
        assert_eq!(ire_to_false_color_band(5.0).0, 0);
        assert_eq!(ire_to_false_color_band(18.0).0, 1);
        assert_eq!(ire_to_false_color_band(40.0).0, 2);
        assert_eq!(ire_to_false_color_band(60.0).0, 3);
        assert_eq!(ire_to_false_color_band(80.0).0, 4);
        assert_eq!(ire_to_false_color_band(98.0).0, 5);
    }

    #[test]
    fn test_constant_hue_y_negative_gamut_compression_and_scene1to1_exposure() {
        // 1. Out-of-gamut Cobalt Blue (`r < 0`) preserves exact luminance Y without shifting toward purple
        let (r_in, g_in, b_in) = (-0.18_f32, 0.06_f32, 0.65_f32);
        let y_before = 0.2126729 * r_in + 0.7151522 * g_in + 0.0721750 * b_in;
        let (cr, cg, cb) = compress_negative_gamut_constant_hue_y(r_in, g_in, b_in, false);
        let y_after = 0.2126729 * cr + 0.7151522 * cg + 0.0721750 * cb;
        assert!(cr >= 0.0 && cg >= 0.0 && cb >= 0.0);
        assert!((y_after - y_before).abs() < 1e-5);
        assert!(cb > cg * 2.5);

        // 2. Exposure mode 2 (`scene1to1`): dark chiaroscuro painting is NOT bleached to L*=94!
        let width = 16usize;
        let height = 16usize;
        let row_stride = width * 2;
        let dark_val = 1500u16.to_le_bytes(); // ~0.031 linear above 1025 black level
        let mut raw = vec![0u8; height * row_stride];
        for chunk in raw.as_chunks_mut::<2>().0 {
            chunk[0] = dark_val[0];
            chunk[1] = dark_val[1];
        }
        const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
            [0.4360747, 0.3850649, 0.1430804],
            [0.2225045, 0.7168786, 0.0606169],
            [0.0139322, 0.0971045, 0.7141733],
        ];
        let mut out_rgba = vec![0u8; width * height * 4];
        let stats_1to1 = develop_bayer16_to_rgba8(
            &raw,
            width,
            height,
            row_stride,
            0,
            [1025.0; 4],
            16383.0,
            [1.0, 1.0, 1.0],
            M_SRGB_TO_XYZ_D50,
            false,
            2u32,
            None,
            &mut out_rgba,
        );
        assert!(
            stats_1to1.exposure_norm_gain <= 1.40,
            "Dark painting must not be auto-bleached in mode 2, got gain={}",
            stats_1to1.exposure_norm_gain
        );
        assert!(out_rgba[0] < 90, "Expected dark tone (<90), got {}", out_rgba[0]);

        // 3. Hot saturated red/yellow pigment (`p995_rgb_max > 0.95`) is capped by `0.95 / p995_rgb_max`
        let hot_r = 15200u16.to_le_bytes();
        let low_gb = 2500u16.to_le_bytes();
        for y in 0..height {
            for x in 0..width {
                let idx = y * row_stride + x * 2;
                let bytes = if (x % 2 == 0) && (y % 2 == 0) { hot_r } else { low_gb };
                raw[idx] = bytes[0];
                raw[idx + 1] = bytes[1];
            }
        }
        let stats_red = develop_bayer16_to_rgba8(
            &raw,
            width,
            height,
            row_stride,
            0,
            [1025.0; 4],
            16383.0,
            [1.3, 1.0, 1.0],
            M_SRGB_TO_XYZ_D50,
            false,
            2u32,
            None,
            &mut out_rgba,
        );
        assert!(
            stats_red.exposure_norm_gain < 0.90,
            "Expected pigment-safe cap < 0.90 for hot red channel, got {}",
            stats_red.exposure_norm_gain
        );
    }

    #[test]
    fn test_extract_and_calibrate_colorchecker_24_d50_from_bayer16() {
        // Synthesize a 120x80 14-bit RGGB Bayer frame containing a 24-patch ColorChecker
        // inside `[0.1, 0.1]..[0.9, 0.9]` under a warm sensor matrix!
        let width = 120usize;
        let height = 80usize;
        let row_stride = width * 2;
        let mut raw = vec![0u8; height * row_stride];
        let sensor_transform = [
            [0.42, 0.08, -0.01],
            [0.05, 0.34, 0.03],
            [-0.01, 0.06, 0.24],
        ];

        for qy in 0..(height / 2) {
            let v = (qy as f64 + 0.5) / ((height / 2) as f64);
            for qx in 0..(width / 2) {
                let u = (qx as f64 + 0.5) / ((width / 2) as f64);
                let cam_rgb = if (0.1..=0.9).contains(&u) && (0.1..=0.9).contains(&v) {
                    let col = (((u - 0.1) / 0.8 * 6.0).floor() as usize).min(5);
                    let row = (((v - 0.1) / 0.8 * 4.0).floor() as usize).min(3);
                    let xyz = lab_d50_to_xyz(COLORCHECKER_24_LAB_D50[row * 6 + col]);
                    mat3_mul_vec3(sensor_transform, xyz)
                } else {
                    [0.05, 0.05, 0.05]
                };

                let encode = |lin: f64| -> [u8; 2] {
                    let code = (1025.0 + lin.clamp(0.0, 1.0) * (16383.0 - 1025.0)).round() as u16;
                    code.to_le_bytes()
                };
                let br = encode(cam_rgb[0]);
                let bg = encode(cam_rgb[1]);
                let bb = encode(cam_rgb[2]);
                let r0 = (qy * 2) * row_stride + (qx * 2) * 2;
                let r1 = (qy * 2 + 1) * row_stride + (qx * 2) * 2;
                raw[r0..r0 + 2].copy_from_slice(&br);
                raw[r0 + 2..r0 + 4].copy_from_slice(&bg);
                raw[r1..r1 + 2].copy_from_slice(&bg);
                raw[r1 + 2..r1 + 4].copy_from_slice(&bb);
            }
        }

        let corners = [[0.1, 0.1], [0.9, 0.1], [0.9, 0.9], [0.1, 0.9]];
        let measured = extract_colorchecker_24_from_bayer16(
            &raw,
            width,
            height,
            row_stride,
            0,
            [1025.0; 4],
            16383.0,
            corners,
            None,
            None,
        );
        let report = calibrate_colorchecker_24(&measured);
        assert!(report.mean_delta_e_after < 0.5, "got {}", report.mean_delta_e_after);
        let white_xyz = mat3_mul_vec3(report.cam_to_xyz_d50, [1.0, 1.0, 1.0]);
        assert!((white_xyz[0] - 0.96422).abs() < 1e-6);
        assert!((white_xyz[1] - 1.00000).abs() < 1e-6);
        assert!((white_xyz[2] - 0.82521).abs() < 1e-6);
    }
}
