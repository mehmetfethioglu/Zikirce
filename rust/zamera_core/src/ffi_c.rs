//! C ABI (`extern "C"`) FFI boundary for iOS (`AVFoundation`) and Dart FFI.
//! Every entrypoint is wrapped in `std::panic::catch_unwind` and validates
//! dimensions, row stride, and buffer bounds before forming slices.

use std::ffi::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::bayer_isp::{
    develop_bayer16_to_rgba8_with_ref, extract_colorchecker_24_from_bayer16,
    extract_flat_field_8x6_from_bayer16,
};
use crate::colorimetry::{calibrate_colorchecker_24, ciede2000, solve_dng_cct_and_interpolate_fm};

pub(crate) const VERSION_CSTR: &[u8] =
    b"zamera_core 0.4.0 (JNI/FFI Active | 12.6MP Full-Res RAW ISP + DNG CCT Interp + Pro Zebra/Hist)\0";

pub(crate) fn validate_bayer_dimensions(
    width: u32,
    height: u32,
    row_stride: u32,
    raw_len: usize,
) -> Option<(usize, usize, usize)> {
    let w = width as usize;
    let h = height as usize;
    let stride = row_stride as usize;
    if w < 2 || h < 2 {
        return None;
    }
    let min_row_bytes = w.checked_mul(2)?;
    if stride < min_row_bytes {
        return None;
    }
    let required_bytes = (h - 1).checked_mul(stride)?.checked_add(min_row_bytes)?;
    if raw_len < required_bytes {
        return None;
    }
    Some((w, h, stride))
}

/// C ABI entrypoint callable from Swift (`AVFoundation` bridge) and Dart FFI.
#[no_mangle]
pub extern "C" fn zamera_core_version_cstr() -> *const c_char {
    catch_unwind(|| VERSION_CSTR.as_ptr() as *const c_char).unwrap_or(std::ptr::null())
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
    catch_unwind(|| ciede2000([l1, a1, b1], [l2, a2, b2])).unwrap_or(-1.0)
}

/// C ABI entrypoint for 24-patch ColorChecker calibration directly from 16-bit Bayer RAW.
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
    catch_unwind(AssertUnwindSafe(|| {
        if raw_ptr.is_null()
            || params_ptr.is_null()
            || out_report_ptr.is_null()
            || params_len_floats < 5
            || out_report_len_floats < 63
        {
            return -1;
        }
        let Some((w, h, stride)) = validate_bayer_dimensions(width, height, row_stride, raw_len)
        else {
            return -2;
        };

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
            w,
            h,
            stride,
            cfa_pattern,
            black_level,
            white_level,
            corners_norm,
            ff_opt.as_ref(),
            lsm_opt.as_ref(),
        );

        let mut report = calibrate_colorchecker_24(&measured);

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
    }))
    .unwrap_or(-99)
}

/// C ABI entrypoint for full-resolution / superpixel 16-bit Bayer RAW development to RGBA8888.
///
/// # Safety
/// Caller must pass valid pointers and lengths.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
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
    catch_unwind(AssertUnwindSafe(|| {
        if raw_ptr.is_null()
            || params_ptr.is_null()
            || out_rgba_ptr.is_null()
            || params_len_floats < 17
        {
            return -1;
        }
        let Some((w, h, stride)) = validate_bayer_dimensions(width, height, row_stride, raw_len)
        else {
            return -2;
        };
        let min_rgba = match (w / 2).checked_mul(h / 2).and_then(|px| px.checked_mul(4)) {
            Some(v) if v > 0 => v,
            _ => return -2,
        };
        if out_rgba_len < min_rgba {
            return -3;
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

        let reference_mid_y = if params_len_floats >= 288 {
            params[287].max(0.0)
        } else {
            0.0
        };
        let sensor_baseline_gain = if params_len_floats >= 289 && params[288] > 0.0 {
            params[288]
        } else {
            1.0
        };

        let stats = develop_bayer16_to_rgba8_with_ref(
            raw_slice,
            w,
            h,
            stride,
            cfa_pattern,
            black_level,
            white_level,
            wb_gains,
            cam_to_xyz_d50,
            use_display_p3 != 0,
            exposure_mode,
            ff_opt.as_ref(),
            lsm_opt.as_ref(),
            reference_mid_y,
            sensor_baseline_gain,
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
                    w,
                    h,
                    stride,
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
    }))
    .unwrap_or(-99)
}
