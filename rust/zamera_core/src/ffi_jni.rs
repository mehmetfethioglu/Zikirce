//! Android JNI C-ABI Bridge (Zero External Crate Dependencies).
//! Every JNI entrypoint is guarded with `std::panic::catch_unwind` to prevent
//! any Rust panic from unwinding across the JVM FFI boundary.

use std::ffi::{c_char, c_void};
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::colorimetry::kelvin_tint_to_dng_wb_and_srgb_matrix;
use crate::ffi_c::{
    zamera_calibrate_colorchecker_24_ffi, zamera_develop_bayer16_ffi, VERSION_CSTR,
};
use crate::lut::{
    compute_audio_peak_rms_dbfs, compute_software_auto_iso_step, frame_duration_ns_from_fps,
    shutter_exposure_ns_from_angle,
};

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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null() || (*env).is_null() {
            return std::ptr::null_mut();
        }
        let vtable = *env;
        let new_string_utf: JniNewStringUtfFn = std::mem::transmute(*vtable.add(167));
        new_string_utf(env, VERSION_CSTR.as_ptr() as *const c_char)
    }))
    .unwrap_or(std::ptr::null_mut())
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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null()
            || (*env).is_null()
            || raw_buffer.is_null()
            || params_buffer.is_null()
            || out_rgba_buffer.is_null()
            || width <= 0
            || height <= 0
            || row_stride <= 0
        {
            return -1;
        }
        let vtable = *env;
        let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
        let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

        let raw_cap = get_cap(env, raw_buffer);
        let params_cap = get_cap(env, params_buffer);
        let rgba_cap = get_cap(env, out_rgba_buffer);
        if raw_cap <= 0 || params_cap <= 0 || rgba_cap <= 0 {
            return -1;
        }

        let raw_ptr = get_addr(env, raw_buffer);
        let raw_len = raw_cap as usize;
        let params_ptr = get_addr(env, params_buffer) as *const f32;
        let params_len_floats = (params_cap as usize) / 4;
        let out_rgba_ptr = get_addr(env, out_rgba_buffer);
        let out_rgba_len = rgba_cap as usize;
        let (out_stats_ptr, out_stats_len_floats) = if out_stats_buffer.is_null() {
            (std::ptr::null_mut(), 0usize)
        } else {
            let stats_cap = get_cap(env, out_stats_buffer);
            if stats_cap <= 0 {
                (std::ptr::null_mut(), 0usize)
            } else {
                (
                    get_addr(env, out_stats_buffer) as *mut f32,
                    (stats_cap as usize) / 4,
                )
            }
        };

        zamera_develop_bayer16_ffi(
            raw_ptr,
            raw_len,
            width as u32,
            height as u32,
            row_stride as u32,
            cfa_pattern.max(0) as u32,
            params_ptr,
            params_len_floats,
            use_display_p3 as u32,
            exposure_mode.max(0) as u32,
            out_rgba_ptr,
            out_rgba_len,
            out_stats_ptr,
            out_stats_len_floats,
        )
    }))
    .unwrap_or(-99)
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeCalibrateColorChecker24Direct(...)`
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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null()
            || (*env).is_null()
            || raw_buffer.is_null()
            || params_buffer.is_null()
            || out_report_buffer.is_null()
            || width <= 0
            || height <= 0
            || row_stride <= 0
        {
            return -1;
        }
        let vtable = *env;
        let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
        let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

        let raw_cap = get_cap(env, raw_buffer);
        let params_cap = get_cap(env, params_buffer);
        let report_cap = get_cap(env, out_report_buffer);
        if raw_cap <= 0 || params_cap <= 0 || report_cap <= 0 {
            return -1;
        }

        let raw_ptr = get_addr(env, raw_buffer);
        let raw_len = raw_cap as usize;
        let params_ptr = get_addr(env, params_buffer) as *const f32;
        let params_len_floats = (params_cap as usize) / 4;
        let out_report_ptr = get_addr(env, out_report_buffer) as *mut f32;
        let out_report_len_floats = (report_cap as usize) / 4;

        zamera_calibrate_colorchecker_24_ffi(
            raw_ptr,
            raw_len,
            width as u32,
            height as u32,
            row_stride as u32,
            cfa_pattern.max(0) as u32,
            params_ptr,
            params_len_floats,
            out_report_ptr,
            out_report_len_floats,
        )
    }))
    .unwrap_or(-99)
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeKelvinWbDirect(...)`
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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
            return -1;
        }
        let vtable = *env;
        let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
        let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

        let in_cap = get_cap(env, in_buffer);
        let out_cap = get_cap(env, out_buffer);
        if in_cap <= 0 || out_cap <= 0 {
            return -1;
        }
        let in_len = (in_cap as usize) / 4;
        let out_len = (out_cap as usize) / 4;
        if in_len < 38 || out_len < 13 {
            return -1;
        }

        let in_addr = get_addr(env, in_buffer);
        let out_addr = get_addr(env, out_buffer);
        if in_addr.is_null() || out_addr.is_null() {
            return -1;
        }

        let inp = std::slice::from_raw_parts(in_addr as *const f32, in_len);
        let out = std::slice::from_raw_parts_mut(out_addr as *mut f32, out_len);

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
    }))
    .unwrap_or(-99)
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeSoftwareAutoIsoDirect(...)`
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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
            return -1;
        }
        let vtable = *env;
        let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
        let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

        let in_cap = get_cap(env, in_buffer);
        let out_cap = get_cap(env, out_buffer);
        if in_cap <= 0 || out_cap <= 0 {
            return -1;
        }
        let in_len = (in_cap as usize) / 4;
        let out_len = (out_cap as usize) / 4;
        if in_len < 7 || out_len < 4 {
            return -1;
        }

        let in_addr = get_addr(env, in_buffer);
        let out_addr = get_addr(env, out_buffer);
        if in_addr.is_null() || out_addr.is_null() {
            return -1;
        }

        let inp = std::slice::from_raw_parts(in_addr as *const f32, in_len);
        let out = std::slice::from_raw_parts_mut(out_addr as *mut f32, out_len);

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
    }))
    .unwrap_or(-99)
}

/// JNI entrypoint: `com.akarworks.zamera_capture.ZameraRustBridge.nativeComputeAudioDbfsDirect(...)`
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
    catch_unwind(AssertUnwindSafe(|| {
        if env.is_null() || (*env).is_null() || in_buffer.is_null() || out_buffer.is_null() {
            return -1;
        }
        let vtable = *env;
        let get_addr: JniGetDirectBufferAddressFn = std::mem::transmute(*vtable.add(230));
        let get_cap: JniGetDirectBufferCapacityFn = std::mem::transmute(*vtable.add(231));

        let in_cap = get_cap(env, in_buffer);
        let out_cap = get_cap(env, out_buffer);
        if in_cap <= 0 || out_cap <= 0 {
            return -1;
        }
        let cap_floats = (in_cap as usize) / 4;
        let out_len = (out_cap as usize) / 4;
        let count = (sample_count.max(0) as usize).min(cap_floats);
        if count == 0 || out_len < 2 {
            return -1;
        }

        let in_addr = get_addr(env, in_buffer);
        let out_addr = get_addr(env, out_buffer);
        if in_addr.is_null() || out_addr.is_null() {
            return -1;
        }

        let samples = std::slice::from_raw_parts(in_addr as *const f32, count);
        let out = std::slice::from_raw_parts_mut(out_addr as *mut f32, out_len);
        let (peak_db, rms_db) = compute_audio_peak_rms_dbfs(samples);
        out[0] = peak_db;
        out[1] = rms_db;
        0
    }))
    .unwrap_or(-99)
}
