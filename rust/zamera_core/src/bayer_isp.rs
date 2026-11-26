//! 16-bit Bayer RAW demosaicing, lens-shading & flat-field correction,
//! radiometric exposure normalization, and perspective homography.

use crate::colorimetry::{
    compress_negative_gamut_constant_hue_y, compute_flat_field_gains, mat3_mul_mat3, mat3_mul_vec3,
    srgb_oetf_f32, xyz_d50_to_lab, M_BRADFORD_D50_TO_D65, M_XYZ_D65_TO_DISPLAY_P3,
    M_XYZ_D65_TO_SRGB,
};

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
    develop_bayer16_to_rgba8_with_ref(
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
        exposure_mode,
        flat_field_grid_8x6,
        rggb_shading_4x48,
        0.0,
        1.0,
        out_rgba,
    )
}

/// Full TrueColor RAW developer with radiometric `reference_mid_y` (trimmed scene-linear
/// luminance from the same-shutter OEM JPEG) and hardware `sensor_baseline_gain`
/// (`POST_RAW_SENSITIVITY_BOOST / 100.0`) so `1:1 TON` (`exposure_mode == 2`) recovers
/// physical mobile RAW headroom without hue shift or bleaching dark scenes.
#[allow(clippy::too_many_arguments)]
pub fn develop_bayer16_to_rgba8_with_ref(
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
    reference_mid_y: f32,
    sensor_baseline_gain: f32,
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
        2 if !rgb_max_samples.is_empty() && !lum_samples.is_empty() => {
            lum_samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            rgb_max_samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            let len_m1 = rgb_max_samples.len() - 1;
            let lum_len_m1 = lum_samples.len() - 1;
            let i15 = (lum_len_m1 * 150) / 1000;
            let i85 = ((lum_len_m1 * 850) / 1000).max(i15);
            let raw_mid_y = (lum_samples[i15..=i85].iter().copied().sum::<f32>()
                / ((i85 - i15 + 1) as f32))
                .max(1e-4);
            let p92_rgb_max = rgb_max_samples[(len_m1 * 920) / 1000].max(1e-4);
            let p96_rgb_max = rgb_max_samples[(len_m1 * 960) / 1000].max(1e-4);
            let p995_rgb_max = rgb_max_samples[(len_m1 * 995) / 1000].max(1e-4);

            let diffuse_anchor_max = if p995_rgb_max > p96_rgb_max * 1.35 {
                p96_rgb_max.min(p92_rgb_max * 1.45)
            } else {
                p995_rgb_max
            };
            let hw_boost = sensor_baseline_gain.clamp(1.0, 6.0);
            let target_gain = if reference_mid_y > 0.0 {
                ((reference_mid_y + 0.003) / (raw_mid_y + 0.003)).clamp(0.60, 6.0)
            } else {
                let base_1to1 = if (wb_gains[1] - 1.0).abs() > 0.02 {
                    1.0_f32
                } else {
                    1.35_f32 * hw_boost
                };
                base_1to1.clamp(0.60, 6.0)
            };
            let pigment_safe_cap =
                (if reference_mid_y > 0.0 { 0.96 } else { 0.95 }) / diffuse_anchor_max;
            target_gain.min(pigment_safe_cap).clamp(0.15, 6.0)
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

    let shoulder_knee = if exposure_mode == 2 {
        0.90_f32
    } else {
        0.84_f32
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
                    (
                        (g00 + cr_smooth).max(0.0),
                        g00,
                        (g00 + cb_smooth).max(0.0),
                        row0_out + even_x * 4,
                    ),
                    (
                        (g10 + cr_smooth).max(0.0),
                        g10,
                        (g10 + cb_smooth).max(0.0),
                        row0_out + (even_x + 1) * 4,
                    ),
                    (
                        (g01 + cr_smooth).max(0.0),
                        g01,
                        (g01 + cb_smooth).max(0.0),
                        row1_out + even_x * 4,
                    ),
                    (
                        (g11 + cr_smooth).max(0.0),
                        g11,
                        (g11 + cb_smooth).max(0.0),
                        row1_out + (even_x + 1) * 4,
                    ),
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

                    let (pos_tr, pos_tg, pos_tb) = compress_negative_gamut_constant_hue_y(
                        raw_tr,
                        raw_tg,
                        raw_tb,
                        use_display_p3,
                    );
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
            let g_lin =
                ((0.5 * (raw_gr + raw_gb) - 0.5 * (bl[1] + bl[2])) / denom_g).clamp(0.01, 1.0);
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
