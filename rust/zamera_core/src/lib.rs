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

pub mod bayer_isp;
pub mod colorimetry;
pub mod ffi_c;
pub mod ffi_jni;
pub mod lut;

pub use bayer_isp::*;
pub use colorimetry::*;
pub use ffi_c::{
    zamera_calibrate_colorchecker_24_ffi, zamera_ciede2000_ffi, zamera_core_version_cstr,
    zamera_develop_bayer16_ffi,
};
pub use ffi_jni::*;
pub use lut::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sharma_2005_ciede2000_reference_pairs() {
        let cases = [
            (
                [50.0000, 2.6772, -79.7751],
                [50.0000, 0.0000, -82.7485],
                2.0425,
            ),
            (
                [50.0000, 3.1571, -77.2803],
                [50.0000, 0.0000, -82.7485],
                2.8615,
            ),
            (
                [50.0000, 0.0000, 0.0000],
                [50.0000, -1.0000, 2.0000],
                2.3669,
            ),
            (
                [50.0000, 2.5000, 0.0000],
                [73.0000, 25.0000, -18.0000],
                27.1492,
            ),
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
        let sensor_transform = [[1.85, 0.35, -0.05], [0.18, 1.32, 0.12], [-0.04, 0.22, 0.95]];
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
        assert!(
            out_rgba[0] < 90,
            "Expected dark tone (<90), got {}",
            out_rgba[0]
        );

        // 3. Hot saturated red/yellow pigment (`p995_rgb_max > 0.95`) is capped by `0.95 / p995_rgb_max`
        let hot_r = 15200u16.to_le_bytes();
        let low_gb = 2500u16.to_le_bytes();
        for y in 0..height {
            for x in 0..width {
                let idx = y * row_stride + x * 2;
                let bytes = if (x % 2 == 0) && (y % 2 == 0) {
                    hot_r
                } else {
                    low_gb
                };
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
        let sensor_transform = [[0.42, 0.08, -0.01], [0.05, 0.34, 0.03], [-0.01, 0.06, 0.24]];

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
        assert!(
            report.mean_delta_e_after < 0.5,
            "got {}",
            report.mean_delta_e_after
        );
        let white_xyz = mat3_mul_vec3(report.cam_to_xyz_d50, [1.0, 1.0, 1.0]);
        assert!((white_xyz[0] - 0.96422).abs() < 1e-6);
        assert!((white_xyz[1] - 1.00000).abs() < 1e-6);
        assert!((white_xyz[2] - 0.82521).abs() < 1e-6);
    }

    #[test]
    fn test_scene1to1_radiometric_reference_lifts_dark_raw_preserving_hue_and_chiaroscuro() {
        const M_SRGB_TO_XYZ_D50: [[f64; 3]; 3] = [
            [0.4360747, 0.3850649, 0.1430804],
            [0.2225045, 0.7168786, 0.0606169],
            [0.0139322, 0.0971045, 0.7141733],
        ];
        let srgb_to_lin = |v: u8| -> f64 {
            let c = (v as f64) / 255.0;
            if c <= 0.04045 {
                c / 12.92
            } else {
                ((c + 0.055) / 1.055).powf(2.4)
            }
        };
        let encode_14bit = |lin: f64| -> [u8; 2] {
            let code = (1025.0 + lin.clamp(0.0, 1.0) * (16383.0 - 1025.0)).round() as u16;
            code.to_le_bytes()
        };

        // 1. ~1.8 EV underexposed chromatic 32x32 RGGB scene (linear R:G:B = 0.090:0.054:0.024)
        //    plus a 3% specular varnish highlight (raw = 15200).
        let width = 32usize;
        let height = 32usize;
        let row_stride = width * 2;
        let mut raw = vec![0u8; height * row_stride];
        let patch_r = encode_14bit(0.090);
        let patch_g = encode_14bit(0.054);
        let patch_b = encode_14bit(0.024);
        let spec_bytes = 15200u16.to_le_bytes();

        for qy in 0..(height / 2) {
            for qx in 0..(width / 2) {
                let is_specular = qx < 3 && qy < 3; // 9 / 256 ≈ 3.5%
                let (br, bg, bb) = if is_specular {
                    (spec_bytes, spec_bytes, spec_bytes)
                } else {
                    (patch_r, patch_g, patch_b)
                };
                let r0 = (qy * 2) * row_stride + (qx * 2) * 2;
                let r1 = (qy * 2 + 1) * row_stride + (qx * 2) * 2;
                raw[r0..r0 + 2].copy_from_slice(&br);
                raw[r0 + 2..r0 + 4].copy_from_slice(&bg);
                raw[r1..r1 + 2].copy_from_slice(&bg);
                raw[r1 + 2..r1 + 4].copy_from_slice(&bb);
            }
        }

        let mut out_rgba = vec![0u8; width * height * 4];
        let stats = develop_bayer16_to_rgba8_with_ref(
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
            2,
            None,
            None,
            0.21,
            1.0,
            &mut out_rgba,
        );
        assert!(
            stats.exposure_norm_gain > 2.8,
            "Expected radiometric gain > 2.8x despite 3.5% specular highlight, got {}",
            stats.exposure_norm_gain
        );

        let mid_idx = (16 * width + 16) * 4;
        assert!(
            out_rgba[mid_idx] > 115,
            "Expected well-exposed midtone pixel (> 115), got R={}",
            out_rgba[mid_idx]
        );

        // Verify CIE Lab D50 hue angle matches reference (0.090, 0.054, 0.024) within < 0.5 deg
        let out_lin = [
            srgb_to_lin(out_rgba[mid_idx]),
            srgb_to_lin(out_rgba[mid_idx + 1]),
            srgb_to_lin(out_rgba[mid_idx + 2]),
        ];
        let ref_lab = xyz_d50_to_lab(mat3_mul_vec3(M_SRGB_TO_XYZ_D50, [0.090, 0.054, 0.024]));
        let out_lab = xyz_d50_to_lab(mat3_mul_vec3(M_SRGB_TO_XYZ_D50, out_lin));
        let ref_hue = ref_lab[2].atan2(ref_lab[1]).to_degrees();
        let out_hue = out_lab[2].atan2(out_lab[1]).to_degrees();
        let hue_diff = ((out_hue - ref_hue + 540.0) % 360.0) - 180.0;
        assert!(
            hue_diff.abs() < 0.5,
            "Expected hue angle drift < 0.5 deg, got {} deg (ref={}, out={})",
            hue_diff,
            ref_hue,
            out_hue
        );

        // 2. Chiaroscuro dark painting: dark reference_mid_y=0.045 keeps dark tone (< 90)
        let dark_val = 1500u16.to_le_bytes();
        for chunk in raw.as_chunks_mut::<2>().0 {
            chunk[0] = dark_val[0];
            chunk[1] = dark_val[1];
        }
        let stats_dark = develop_bayer16_to_rgba8_with_ref(
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
            2,
            None,
            None,
            0.045,
            1.0,
            &mut out_rgba,
        );
        assert!(
            stats_dark.exposure_norm_gain <= 1.5,
            "Dark chiaroscuro scene must not over-boost, got {}",
            stats_dark.exposure_norm_gain
        );
        assert!(
            out_rgba[0] < 90,
            "Dark chiaroscuro pixel must remain < 90, got {}",
            out_rgba[0]
        );
    }

    #[test]
    fn test_ffi_bounds_and_null_guards() {
        let mut rgba = [0u8; 64];
        let mut report = [0f32; 64];
        let params = [0f32; 20];
        let raw = [0u8; 32];

        unsafe {
            assert_eq!(
                zamera_develop_bayer16_ffi(
                    std::ptr::null(),
                    32,
                    4,
                    4,
                    8,
                    0,
                    params.as_ptr(),
                    params.len(),
                    0,
                    0,
                    rgba.as_mut_ptr(),
                    rgba.len(),
                    std::ptr::null_mut(),
                    0,
                ),
                -1
            );
            assert_eq!(
                zamera_develop_bayer16_ffi(
                    raw.as_ptr(),
                    raw.len(),
                    0,
                    4,
                    8,
                    0,
                    params.as_ptr(),
                    params.len(),
                    0,
                    0,
                    rgba.as_mut_ptr(),
                    rgba.len(),
                    std::ptr::null_mut(),
                    0,
                ),
                -2
            );
            assert_eq!(
                zamera_develop_bayer16_ffi(
                    raw.as_ptr(),
                    raw.len(),
                    4,
                    4,
                    8,
                    0,
                    params.as_ptr(),
                    params.len(),
                    0,
                    0,
                    rgba.as_mut_ptr(),
                    4,
                    std::ptr::null_mut(),
                    0,
                ),
                -3
            );
            assert_eq!(
                zamera_calibrate_colorchecker_24_ffi(
                    raw.as_ptr(),
                    4,
                    4,
                    4,
                    8,
                    0,
                    params.as_ptr(),
                    params.len(),
                    report.as_mut_ptr(),
                    report.len(),
                ),
                -2
            );
        }
        assert!(!zamera_core_version_cstr().is_null());
        assert!(zamera_ciede2000_ffi(50.0, 0.0, 0.0, 50.0, 0.0, 0.0) >= 0.0);
    }
}
