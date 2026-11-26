//! Colorimetric math: CIE XYZ (D50/D65), Bradford adaptation, CIE L*a*b*, CIEDE2000,
//! ColorChecker 24 least-squares solver, DNG CCT interpolation, and gamut compression.

use std::f64::consts::PI;

const VERSION_STR: &str =
    "zamera_core 0.4.0 (JNI/FFI Active | 12.6MP Full-Res RAW ISP + DNG CCT Interp + Pro Zebra/Hist)";

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

    let delta_big_h_prime = 2.0 * c_prod.sqrt() * ((delta_h_prime_deg * 0.5) * (PI / 180.0)).sin();

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

    let t = 1.0 - 0.17 * ((h_bar_prime_deg - 30.0) * (PI / 180.0)).cos()
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
