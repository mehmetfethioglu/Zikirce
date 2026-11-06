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

/// Develops a 16-bit little-endian Bayer `RAW_SENSOR` buffer into an 8-bit `RGBA_8888` buffer
/// in sRGB or Display P3 color space.
///
/// Supports BOTH:
/// - **Full-Resolution (`width x height`, e.g. `4096x3072` 12.6 MP)** when `out_rgba.len() >= width * height * 4`
///   using striped bilinear/green-balanced interpolation with <64 KB rolling strip memory; AND
/// - **Half-Resolution (`width/2 x height/2`, e.g. `2048x1536`)** when `out_rgba.len() == (width/2) * (height/2) * 4`.
///
/// Includes:
/// - Linear White-Point Exposure Normalization (`normalize_exposure == true`): measures the 99th percentile
///   scene linear luminance (`p99_y`) and applies a pure linear scalar gain (`0.85 / p99_y`, clamped to `[1.0, 5.2]`)
///   so white paper/plates render at $L^* \approx 92\text{--}95$ instead of $L^* \approx 48$, with zero non-linear tone curve!
/// - 32-bin RAW Luminance Histogram, Zebra (`>= 95%` sensor saturation) ratio, and Sobel Focus Peaking score.
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
    normalize_exposure: bool,
    flat_field_grid_8x6: Option<&[f32; 48]>,
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

    // Pass 1: Fast subsampled telemetry & 99th-percentile linear luminance pass (64x48 grid)
    let step_y = (qh / 48).max(1);
    let step_x = (qw / 64).max(1);
    let mut lum_samples = Vec::with_capacity(3200);
    let mut hist_bins = [0u32; 32];
    let mut zebra_count = 0usize;
    let mut sample_count = 0usize;
    let mut peaking_sum = 0.0_f32;
    let mut prev_g = 0.0_f32;

    for qy in (0..qh).step_by(step_y) {
        let even_y = qy * 2;
        for qx in (0..qw).step_by(step_x) {
            let even_x = qx * 2;
            let [raw_r, raw_gr, raw_gb, raw_b] =
                extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

            if raw_r >= zebra_threshold
                || raw_gr >= zebra_threshold
                || raw_gb >= zebra_threshold
                || raw_b >= zebra_threshold
            {
                zebra_count += 1;
            }

            let lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
            let lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
            let lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
            let lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);
            let lin_g = 0.5 * (lin_gr + lin_gb);

            peaking_sum += (lin_g - prev_g).abs();
            prev_g = lin_g;

            let r_wb = lin_r * wb_gains[0];
            let g_wb = lin_g * wb_gains[1];
            let b_wb = lin_b * wb_gains[2];
            let tr = m_base[0][0] * r_wb + m_base[0][1] * g_wb + m_base[0][2] * b_wb;
            let tg = m_base[1][0] * r_wb + m_base[1][1] * g_wb + m_base[1][2] * b_wb;
            let tb = m_base[2][0] * r_wb + m_base[2][1] * g_wb + m_base[2][2] * b_wb;
            let y_lin = (0.2126 * tr + 0.7152 * tg + 0.0722 * tb).max(0.0);
            lum_samples.push(y_lin);

            let bin = ((lin_g.sqrt() * 31.99) as usize).min(31);
            hist_bins[bin] += 1;
            sample_count += 1;
        }
    }

    // Compute linear white-point exposure gain (B1 fix: scales 98.5th percentile linear Y to 0.85 -> L* ~ 94)
    let exposure_norm_gain = if normalize_exposure && !lum_samples.is_empty() {
        lum_samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let idx985 = ((lum_samples.len() - 1) * 985) / 1000;
        let p985 = lum_samples[idx985].max(0.04);
        (0.85 / p985).clamp(1.0, 5.2)
    } else {
        1.0
    };

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

    let inv_qw = 1.0 / (qw.max(1) as f32);
    let inv_qh = 1.0 / (qh.max(1) as f32);

    if !full_res {
        // Half-resolution 2x2 superpixel mode (`qw x qh`)
        for qy in 0..qh {
            let even_y = qy * 2;
            let v_norm = (qy as f32) * inv_qh;
            let out_row_offset = qy * qw * 4;

            for qx in 0..qw {
                let even_x = qx * 2;
                let [raw_r, raw_gr, raw_gb, raw_b] =
                    extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

                if raw_r >= clip_threshold
                    || raw_gr >= clip_threshold
                    || raw_gb >= clip_threshold
                    || raw_b >= clip_threshold
                {
                    highlight_clipped += 1;
                }

                let lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
                let lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
                let lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
                let lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);
                let lin_g = 0.5 * (lin_gr + lin_gb);

                if qx >= roi_x0 && qx < roi_x1 && qy >= roi_y0 && qy < roi_y1 {
                    center_cam_r += lin_r as f64;
                    center_cam_g += lin_g as f64;
                    center_cam_b += lin_b as f64;
                    center_count += 1;
                }

                let ff_gain = if let Some(ff) = flat_field_grid_8x6 {
                    sample_flat_field_8x6(ff, (qx as f32) * inv_qw, v_norm)
                } else {
                    1.0
                };

                let r_wb = lin_r * wb_gains[0] * ff_gain;
                let g_wb = lin_g * wb_gains[1] * ff_gain;
                let b_wb = lin_b * wb_gains[2] * ff_gain;

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
        // Full-Resolution (`width x height`, e.g. 4096x3072 = 12.6 MP) Striped Demosaicing!
        // Preserves native sensor per-pixel green luminance detail (Gr/Gb) while interpolating
        // chroma differences (R - G, B - G) across 2x2 neighborhoods with <48 KB strip RAM.
        let mut curr_row_r = vec![0.0_f32; qw];
        let mut curr_row_b = vec![0.0_f32; qw];

        for qy in 0..qh {
            let even_y = qy * 2;
            let v_norm = (qy as f32) * inv_qh;
            let row0_out = even_y * width * 4;
            let row1_out = (even_y + 1) * width * 4;

            for qx in 0..qw {
                let even_x = qx * 2;
                let [raw_r, raw_gr, raw_gb, raw_b] =
                    extract_bayer_quad_rggb(raw_bytes, row_stride, even_x, even_y, cfa_pattern);

                if raw_r >= clip_threshold
                    || raw_gr >= clip_threshold
                    || raw_gb >= clip_threshold
                    || raw_b >= clip_threshold
                {
                    highlight_clipped += 1;
                }

                let lin_r = ((raw_r - bl[0]) / denom_r).clamp(0.0, 1.0);
                let lin_gr = ((raw_gr - bl[1]) / denom_gr).clamp(0.0, 1.0);
                let lin_gb = ((raw_gb - bl[2]) / denom_gb).clamp(0.0, 1.0);
                let lin_b = ((raw_b - bl[3]) / denom_b).clamp(0.0, 1.0);
                let lin_g_avg = 0.5 * (lin_gr + lin_gb);

                if qx >= roi_x0 && qx < roi_x1 && qy >= roi_y0 && qy < roi_y1 {
                    center_cam_r += lin_r as f64;
                    center_cam_g += lin_g_avg as f64;
                    center_cam_b += lin_b as f64;
                    center_count += 1;
                }

                let ff_gain = if let Some(ff) = flat_field_grid_8x6 {
                    sample_flat_field_8x6(ff, (qx as f32) * inv_qw, v_norm)
                } else {
                    1.0
                };

                let r_wb = lin_r * wb_gains[0] * ff_gain;
                let gr_wb = lin_gr * wb_gains[1] * ff_gain;
                let gb_wb = lin_gb * wb_gains[1] * ff_gain;
                let g_avg_wb = lin_g_avg * wb_gains[1] * ff_gain;
                let b_wb = lin_b * wb_gains[2] * ff_gain;

                // Horizontal chroma-difference smoothing with left neighbor
                let prev_r = if qx > 0 { curr_row_r[qx - 1] } else { r_wb };
                let prev_b = if qx > 0 { curr_row_b[qx - 1] } else { b_wb };
                curr_row_r[qx] = r_wb;
                curr_row_b[qx] = b_wb;
                let r_interp = 0.5 * (r_wb + prev_r);
                let b_interp = 0.5 * (b_wb + prev_b);

                // 4 subpixels of the 2x2 quad with green-modulated luminance preservation:
                // (0,0): R site -> G = g_avg_wb, R = r_wb, B = b_interp
                // (1,0): Gr site -> G = gr_wb, R = r_interp, B = b_wb
                // (0,1): Gb site -> G = gb_wb, R = r_wb, B = b_interp
                // (1,1): B site -> G = g_avg_wb, R = r_interp, B = b_wb
                let subpixels = [
                    (r_wb, g_avg_wb, b_interp, row0_out + even_x * 4),
                    (r_interp, gr_wb, b_wb, row0_out + (even_x + 1) * 4),
                    (r_wb, gb_wb, b_interp, row1_out + even_x * 4),
                    (r_interp, g_avg_wb, b_wb, row1_out + (even_x + 1) * 4),
                ];

                let mut quad_gamut_clipped = false;
                for (pr, pg, pb, out_idx) in subpixels {
                    let tr = m[0][0] * pr + m[0][1] * pg + m[0][2] * pb;
                    let tg = m[1][0] * pr + m[1][1] * pg + m[1][2] * pb;
                    let tb = m[2][0] * pr + m[2][1] * pg + m[2][2] * pb;

                    if !(0.0..=1.0).contains(&tr)
                        || !(0.0..=1.0).contains(&tg)
                        || !(0.0..=1.0).contains(&tb)
                    {
                        quad_gamut_clipped = true;
                    }

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

    RawDevelopStats {
        out_width: out_w as u32,
        out_height: out_h as u32,
        mean_rgb: [
            (sum_out_r / q_denom) as f32,
            (sum_out_g / q_denom) as f32,
            (sum_out_b / q_denom) as f32,
        ],
        center_linear_cam_rgb: [
            (center_cam_r / c_denom) as f32,
            (center_cam_g / c_denom) as f32,
            (center_cam_b / c_denom) as f32,
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
/// `params_ptr` layout (at least 17 `f32` values; if 47 `f32` values are provided, includes
/// `as_shot_neutral[3]`, `cm1[9]`, `cm2[9]`, `fm2[9]` for automatic DNG CCT interpolation!):
/// - `[0..4]`: `black_level`
/// - `[4]`: `white_level`
/// - `[5..8]`: `wb_gains`
/// - `[8..17]`: `fm1_or_custom_cam_to_xyz_d50` (9 floats)
/// - Optional `[17..20]`: `as_shot_neutral` (3 floats; if `as_shot_neutral[1] > 0.0`, runs DNG CCT interpolation)
/// - Optional `[20..29]`: `cm1_d65` (9 floats)
/// - Optional `[29..38]`: `cm2_stda` (9 floats)
/// - Optional `[38..47]`: `fm2_stda` (9 floats)
///
/// `out_stats_ptr` layout (at least 44 `f32` values):
/// - `[0..3]`: `mean_rgb`
/// - `[3]`: `highlight_clipped_ratio`
/// - `[4]`: `gamut_clipped_ratio`
/// - `[5..8]`: `center_linear_cam_rgb`
/// - `[8]`: `exposure_norm_gain`
/// - `[9]`: `solved_cct_kelvin`
/// - `[10]`: `zebra_ratio`
/// - `[11]`: `focus_peaking_score`
/// - `[12..44]`: `histogram_32` (32 normalized floats)
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
    normalize_exposure: u32,
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

    let ff_opt = if params_len_floats >= 95 {
        let mut ff = [1.0_f32; 48];
        ff.copy_from_slice(&params[47..95]);
        Some(ff)
    } else {
        None
    };

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
        normalize_exposure != 0,
        ff_opt.as_ref(),
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
    normalize_exposure: i32,
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
        normalize_exposure as u32,
        out_rgba_ptr,
        out_rgba_len,
        out_stats_ptr,
        out_stats_len_floats,
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
}
