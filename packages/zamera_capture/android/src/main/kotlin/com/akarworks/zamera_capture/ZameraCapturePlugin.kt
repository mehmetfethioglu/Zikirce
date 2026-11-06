package com.akarworks.zamera_capture

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ColorSpace
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.hardware.camera2.*
import android.hardware.camera2.params.ColorSpaceTransform
import android.hardware.camera2.params.DynamicRangeProfiles
import android.hardware.camera2.params.MeteringRectangle
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.RggbChannelVector
import android.hardware.camera2.params.SessionConfiguration
import android.media.ExifInterface
import android.media.Image
import android.media.ImageReader
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.MediaStore
import android.util.Rational
import android.view.Surface
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

/**
 * ZameraCapturePlugin (Android Camera2 Hardware Probe + Live Preview Texture + Physical Camera ID Routing
 * + Real JNI Rust `zamera_core` 12.6MP Full-Res RAW -> TrueColor sRGB/Display P3 ISP + DNG CCT Interpolation
 * + Pro Mode DNG Kelvin/Tint WB + EV Compensation + Tap-to-Focus + 3-Frame AE Bracketing + MediaStore DCIM/Zamera Export)
 */
class ZameraCapturePlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private lateinit var textureRegistry: TextureRegistry
    private var activity: Activity? = null
    private val pendingPermissionQueue = mutableListOf<Pair<Result, () -> Unit>>()
    private var isRequestingPermission = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private val rustIspExecutor = Executors.newSingleThreadExecutor()
    // Single shared session executor (Fixes B10 leak)
    private val cameraSessionExecutor = Executors.newSingleThreadExecutor()

    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var previewSurface: Surface? = null
    private var rawImageReader: ImageReader? = null
    private var jpegImageReader: ImageReader? = null
    private var activeCameraId: String = "0"
    private var activePhysicalCameraId: String? = null
    private var activeSensorOrientation: Int = 90
    @Volatile
    private var lastTotalCaptureResult: TotalCaptureResult? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.akarworks.zamera/capture_probe")
        channel.setMethodCallHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == 9001) {
            isRequestingPermission = false
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            val copy = ArrayList(pendingPermissionQueue)
            pendingPermissionQueue.clear()
            for ((res, act) in copy) {
                if (granted) {
                    act.invoke()
                } else {
                    res.error("PERMISSION_DENIED", "Camera permission denied by user", null)
                }
            }
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "probeDeviceCapabilities" -> {
                ensureCameraPermissionAndRun(result) {
                    try {
                        result.success(probeCamera2Capabilities())
                    } catch (e: Exception) {
                        result.error("PROBE_FAILED", e.message, e.stackTraceToString())
                    }
                }
            }
            "startPreviewSession" -> {
                val cameraId = call.argument<String>("cameraId") ?: "2"
                val width = call.argument<Int>("width") ?: 1920
                val height = call.argument<Int>("height") ?: 1440
                ensureCameraPermissionAndRun(result) {
                    startPreviewSession(cameraId, width, height, result)
                }
            }
            "updateManualControls" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                updateManualControls(args, result)
            }
            "setFocusAndMeteringPoint" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                setFocusAndMeteringPoint(args, result)
            }
            "getLiveTelemetry" -> {
                result.success(extractLiveTelemetry())
            }
            "capturePhoto" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                captureRawAndJpegPhoto(args, result)
            }
            "captureBracketedPhotos" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                captureBracketedPhotos(args, result)
            }
            "stopPreviewSession" -> {
                stopPreviewSession()
                result.success(true)
            }
            "getRustCoreVersion" -> {
                result.success(ZameraRustBridge.safeCoreVersion())
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureCameraPermissionAndRun(result: Result, action: () -> Unit) {
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            action()
            return
        }
        val act = activity
        if (act != null) {
            pendingPermissionQueue.add(Pair(result, action))
            if (!isRequestingPermission) {
                isRequestingPermission = true
                ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.CAMERA), 9001)
            }
        } else {
            result.error("PERMISSION_DENIED", "Camera permission not granted", null)
        }
    }

    private fun ensureBackgroundThread() {
        if (backgroundThread == null) {
            backgroundThread = HandlerThread("ZameraCamera2Thread").also {
                it.start()
                backgroundHandler = Handler(it.looper)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startPreviewSession(requestedId: String, reqWidth: Int, reqHeight: Int, result: Result) {
        try {
            stopPreviewSession()
            ensureBackgroundThread()

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val logicalIds = manager.cameraIdList.toList()

            val openLogicalId: String
            val targetPhysicalId: String?
            if (logicalIds.contains(requestedId)) {
                openLogicalId = requestedId
                targetPhysicalId = null
            } else {
                openLogicalId = logicalIds.firstOrNull() ?: "0"
                targetPhysicalId = requestedId
            }
            activeCameraId = openLogicalId
            activePhysicalCameraId = targetPhysicalId

            val charsId = targetPhysicalId ?: openLogicalId
            val chars = manager.getCameraCharacteristics(charsId)
            activeSensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            val minFocusDist = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
            val expRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)

            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val previewSize = map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                ?.filter { it.width <= reqWidth && it.height <= reqHeight && it.width * 3 == it.height * 4 }
                ?.maxByOrNull { it.width * it.height }
                ?: map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                    ?.firstOrNull { it.width <= reqWidth && it.height <= reqHeight }
                ?: android.util.Size(1440, 1080)

            val entry = textureRegistry.createSurfaceTexture()
            surfaceEntry = entry
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height)
            val surf = Surface(surfaceTexture)
            previewSurface = surf

            val jpegSize = map?.getOutputSizes(ImageFormat.JPEG)?.maxByOrNull { it.width * it.height }
                ?: previewSize
            jpegImageReader = ImageReader.newInstance(jpegSize.width, jpegSize.height, ImageFormat.JPEG, 3)

            val rawSizes = map?.getOutputSizes(ImageFormat.RAW_SENSOR)
            if (!rawSizes.isNullOrEmpty()) {
                val rawSize = rawSizes.maxByOrNull { it.width * it.height }!!
                rawImageReader = ImageReader.newInstance(rawSize.width, rawSize.height, ImageFormat.RAW_SENSOR, 3)
            }

            manager.openCamera(openLogicalId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                        builder.addTarget(surf)
                        builder.set(
                            CaptureRequest.CONTROL_AF_MODE,
                            CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                        )
                        // Lock zoom ratio to 1.0x to prevent OEM automatic macro/crop switching (Faz 2A)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
                        }
                        previewRequestBuilder = builder

                        val surfaces = mutableListOf<Surface>(surf)
                        jpegImageReader?.surface?.let { surfaces.add(it) }
                        rawImageReader?.surface?.let { surfaces.add(it) }

                        val stateCallback = object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                captureSession = session
                                try {
                                    session.setRepeatingRequest(
                                        builder.build(),
                                        object : CameraCaptureSession.CaptureCallback() {
                                            override fun onCaptureCompleted(
                                                session: CameraCaptureSession,
                                                request: CaptureRequest,
                                                res: TotalCaptureResult
                                            ) {
                                                lastTotalCaptureResult = res
                                            }
                                        },
                                        backgroundHandler
                                    )
                                    mainHandler.post {
                                        result.success(
                                            mapOf(
                                                "textureId" to entry.id(),
                                                "previewWidth" to previewSize.width,
                                                "previewHeight" to previewSize.height,
                                                "sensorOrientation" to activeSensorOrientation,
                                                "activeCameraId" to (targetPhysicalId ?: openLogicalId),
                                                "supportsRawSensor" to (rawImageReader != null),
                                                "minimumFocusDistanceDiopters" to minFocusDist.toDouble(),
                                                "isoMin" to (isoRange?.lower ?: 50),
                                                "isoMax" to (isoRange?.upper ?: 3200),
                                                "exposureNsMin" to (expRange?.lower ?: 50_000L),
                                                "exposureNsMax" to (expRange?.upper ?: 1_000_000_000L)
                                            )
                                        )
                                    }
                                } catch (e: Exception) {
                                    mainHandler.post {
                                        result.error("SESSION_START_ERR", e.message, null)
                                    }
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                mainHandler.post {
                                    result.error("CONFIGURE_FAILED", "CameraCaptureSession configure failed", null)
                                }
                            }
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && targetPhysicalId != null) {
                            val outConfigs = surfaces.map { s ->
                                OutputConfiguration(s).apply {
                                    setPhysicalCameraId(targetPhysicalId)
                                }
                            }
                            val sessionConfig = SessionConfiguration(
                                SessionConfiguration.SESSION_REGULAR,
                                outConfigs,
                                cameraSessionExecutor,
                                stateCallback
                            )
                            camera.createCaptureSession(sessionConfig)
                        } else {
                            camera.createCaptureSession(surfaces, stateCallback, backgroundHandler)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("OPEN_BUILD_ERR", e.message, null)
                        }
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    mainHandler.post {
                        result.error("CAMERA_OPEN_ERROR", "CameraDevice error code $error", null)
                    }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            result.error("START_PREVIEW_ERR", e.message, null)
        }
    }

    private fun extractLiveTelemetry(): Map<String, Any?> {
        val logicalRes = lastTotalCaptureResult ?: return emptyMap()
        val physRes: CaptureResult = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            activePhysicalCameraId != null
        ) {
            logicalRes.physicalCameraResults[activePhysicalCameraId] ?: logicalRes
        } else {
            logicalRes
        }

        val iso = physRes.get(CaptureResult.SENSOR_SENSITIVITY)
        val expNs = physRes.get(CaptureResult.SENSOR_EXPOSURE_TIME)
        val focusDiopters = physRes.get(CaptureResult.LENS_FOCUS_DISTANCE)
        val wbGains = physRes.get(CaptureResult.COLOR_CORRECTION_GAINS)
        val neutralPt = physRes.get(CaptureResult.SENSOR_NEUTRAL_COLOR_POINT)
        val aeState = physRes.get(CaptureResult.CONTROL_AE_STATE)
        val afState = physRes.get(CaptureResult.CONTROL_AF_STATE)
        val aperture = physRes.get(CaptureResult.LENS_APERTURE)
        val focalLength = physRes.get(CaptureResult.LENS_FOCAL_LENGTH)

        // Estimate live CCT in Kelvin from SENSOR_NEUTRAL_COLOR_POINT or COLOR_CORRECTION_GAINS
        val liveCctKelvin: Double = try {
            val rOverB = when {
                neutralPt != null && neutralPt.size >= 3 && neutralPt[0].toDouble() > 1e-4 -> {
                    val rGain = neutralPt[1].toDouble() / neutralPt[0].toDouble()
                    val bGain = neutralPt[1].toDouble() / neutralPt[2].toDouble().coerceAtLeast(1e-4)
                    rGain / bGain.coerceAtLeast(1e-4)
                }
                wbGains != null && wbGains.blue > 1e-4f -> {
                    (wbGains.red / wbGains.blue).toDouble()
                }
                else -> 1.35
            }
            // Calibrated mapping for Xiaomi Sony LYT-900 / OV50H DNG matrices (2000K..10000K)
            (2856.0 + (rOverB - 0.72) * 3350.0).coerceIn(2000.0, 10000.0)
        } catch (_: Exception) {
            5500.0
        }

        return mapOf(
            "cameraId" to (activePhysicalCameraId ?: activeCameraId),
            "iso" to iso,
            "exposureTimeNs" to expNs,
            "focusDistanceDiopters" to focusDiopters?.toDouble(),
            "aperture" to aperture?.toDouble(),
            "focalLengthMm" to focalLength?.toDouble(),
            "solvedCctKelvin" to liveCctKelvin,
            "wbGains" to if (wbGains != null) listOf(
                wbGains.red.toDouble(),
                wbGains.greenEven.toDouble(),
                wbGains.greenOdd.toDouble(),
                wbGains.blue.toDouble()
            ) else null,
            "asShotNeutral" to neutralPt?.map { it.toDouble() },
            "aeState" to aeState,
            "afState" to afState
        )
    }

    private fun setFocusAndMeteringPoint(args: Map<String, Any?>, result: Result) {
        val builder = previewRequestBuilder
        val session = captureSession
        if (builder == null || session == null) {
            result.success(false)
            return
        }
        try {
            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val charsId = activePhysicalCameraId ?: activeCameraId
            val chars = manager.getCameraCharacteristics(charsId)
            val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (sensorRect == null) {
                result.success(false)
                return
            }

            val normX = ((args["x"] as? Number)?.toFloat() ?: 0.5f).coerceIn(0.05f, 0.95f)
            val normY = ((args["y"] as? Number)?.toFloat() ?: 0.5f).coerceIn(0.05f, 0.95f)

            // Rotate normalized portrait UI coordinates (normX, normY) into physical sensor array orientation
            val (sensorNormX, sensorNormY) = when ((activeSensorOrientation % 360 + 360) % 360) {
                90 -> Pair(normY, 1.0f - normX)
                270 -> Pair(1.0f - normY, 1.0f - normX)
                180 -> Pair(1.0f - normX, 1.0f - normY)
                else -> Pair(normX, normY)
            }

            val cx = (sensorRect.left + sensorNormX * sensorRect.width()).toInt()
            val cy = (sensorRect.top + sensorNormY * sensorRect.height()).toInt()
            val halfW = (sensorRect.width() * 0.075f).toInt().coerceAtLeast(32)
            val halfH = (sensorRect.height() * 0.075f).toInt().coerceAtLeast(32)

            val region = MeteringRectangle(
                Rect(
                    (cx - halfW).coerceAtLeast(sensorRect.left),
                    (cy - halfH).coerceAtLeast(sensorRect.top),
                    (cx + halfW).coerceAtMost(sensorRect.right),
                    (cy + halfH).coerceAtMost(sensorRect.bottom)
                ),
                MeteringRectangle.METERING_WEIGHT_MAX - 1
            )

            val maxAf = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0
            val maxAe = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            if (maxAf > 0 && minFocus > 0.0f) {
                builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(region))
                if (builder.get(CaptureRequest.CONTROL_AF_MODE) != CaptureRequest.CONTROL_AF_MODE_OFF) {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                }
            }
            if (maxAe > 0) {
                builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(region))
            }

            val captureCallback = object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    res: TotalCaptureResult
                ) {
                    lastTotalCaptureResult = res
                }
            }

            session.setRepeatingRequest(builder.build(), captureCallback, backgroundHandler)

            // Trigger active AF sweep if variable focus is enabled and not locked in manual focus
            if (maxAf > 0 && minFocus > 0.0f && builder.get(CaptureRequest.CONTROL_AF_MODE) != CaptureRequest.CONTROL_AF_MODE_OFF) {
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
                session.capture(builder.build(), captureCallback, backgroundHandler)
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("TAP_FOCUS_ERR", e.message, null)
        }
    }

    private fun updateManualControls(args: Map<String, Any?>, result: Result) {
        val builder = previewRequestBuilder
        val session = captureSession
        if (builder == null || session == null) {
            result.success(false)
            return
        }
        try {
            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val charsId = activePhysicalCameraId ?: activeCameraId
            val chars = manager.getCameraCharacteristics(charsId)
            val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
            val expRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
            }

            val manualExposure = args["manualExposure"] as? Boolean ?: false
            if (manualExposure) {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                val reqIso = (args["iso"] as? Number)?.toInt() ?: 100
                val clampedIso = if (isoRange != null) reqIso.coerceIn(isoRange.lower, isoRange.upper) else reqIso
                val reqShutterNs = (args["exposureTimeNs"] as? Number)?.toLong() ?: 8_000_000L
                val clampedShutter = if (expRange != null) reqShutterNs.coerceIn(expRange.lower, expRange.upper) else reqShutterNs
                builder.set(CaptureRequest.SENSOR_SENSITIVITY, clampedIso)
                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, clampedShutter)
            } else {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                val evComp = (args["evCompensation"] as? Number)?.toDouble() ?: 0.0
                val compRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                val compStep = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
                if (compRange != null && compStep != null && compStep.toDouble() > 0.0) {
                    val steps = (evComp / compStep.toDouble()).roundToInt()
                        .coerceIn(compRange.lower, compRange.upper)
                    builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, steps)
                }
            }

            val manualFocus = args["manualFocus"] as? Boolean ?: false
            if (manualFocus && minFocus > 0.0f) {
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                val normFocus = (args["focusDistance"] as? Number)?.toFloat() ?: 0.5f
                val focusDiopters = (normFocus.coerceIn(0.0f, 1.0f)) * minFocus
                builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, focusDiopters)
            } else {
                builder.set(
                    CaptureRequest.CONTROL_AF_MODE,
                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                )
            }

            val artworkLinearMode = args["artworkLinearMode"] as? Boolean ?: false
            val manualWb = args["manualWb"] as? Boolean ?: false
            val kelvin = (args["kelvin"] as? Number)?.toFloat()
            val tint = (args["tint"] as? Number)?.toFloat() ?: 0.0f
            val rggb = args["rggbGains"] as? List<*>

            if (!artworkLinearMode && manualWb) {
                val cm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1))
                    ?: floatArrayOf(0.8125f, -0.2734f, -0.1094f, -0.4375f, 1.3281f, 0.0859f, -0.0312f, 0.2578f, 0.4297f)
                val cm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM2))
                    ?: floatArrayOf(1.2188f, -0.4688f, -0.4531f, -0.9766f, 2.1797f, -0.2891f, -0.1875f, 0.3750f, 0.6094f)
                val fm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1))
                    ?: floatArrayOf(0.5469f, 0.2734f, 0.1406f, 0.1875f, 0.8672f, -0.0547f, -0.0547f, -0.3672f, 1.2500f)
                val fm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX2))
                    ?: floatArrayOf(0.6016f, -0.0391f, 0.3984f, 0.2734f, 0.4688f, 0.2500f, 0.0547f, -0.6562f, 1.4219f)

                val dngWb = if (kelvin != null) {
                    ZameraRustBridge.computeDngKelvinWb(kelvin, tint, cm1, cm2, fm1, fm2)
                } else {
                    null
                }

                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)
                if (dngWb != null) {
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_MODE,
                        CaptureRequest.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX
                    )
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_TRANSFORM,
                        floatArrayToColorSpaceTransform(dngWb.second)
                    )
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_GAINS,
                        RggbChannelVector(dngWb.first[0], dngWb.first[1], dngWb.first[2], dngWb.first[3])
                    )
                } else if (rggb != null && rggb.size == 4) {
                    val colorTransform = chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1)
                        ?: chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1)
                    if (colorTransform != null) {
                        builder.set(
                            CaptureRequest.COLOR_CORRECTION_MODE,
                            CaptureRequest.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX
                        )
                        builder.set(CaptureRequest.COLOR_CORRECTION_TRANSFORM, colorTransform)
                    }
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_GAINS,
                        RggbChannelVector(
                            (rggb[0] as Number).toFloat().coerceIn(0.5f, 4.0f),
                            (rggb[1] as Number).toFloat().coerceIn(0.5f, 4.0f),
                            (rggb[2] as Number).toFloat().coerceIn(0.5f, 4.0f),
                            (rggb[3] as Number).toFloat().coerceIn(0.5f, 4.0f)
                        )
                    )
                }
            } else {
                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
                builder.set(CaptureRequest.COLOR_CORRECTION_MODE, CaptureRequest.COLOR_CORRECTION_MODE_FAST)
            }

            session.setRepeatingRequest(
                builder.build(),
                object : CameraCaptureSession.CaptureCallback() {
                    override fun onCaptureCompleted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        res: TotalCaptureResult
                    ) {
                        lastTotalCaptureResult = res
                    }
                },
                backgroundHandler
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("MANUAL_CTRL_ERR", e.message, null)
        }
    }

    private fun captureBracketedPhotos(args: Map<String, Any?>, result: Result) {
        val evSteps = (args["evOffsets"] as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() }
            ?: listOf(-1.5, 0.0, 1.5)
        val baseTelemetry = extractLiveTelemetry()
        val baseIso = (baseTelemetry["iso"] as? Number)?.toInt() ?: 100
        val baseExpNs = (baseTelemetry["exposureTimeNs"] as? Number)?.toLong() ?: 10_000_000L

        val resultsList = mutableListOf<Map<String, Any?>>()

        fun captureNext(idx: Int) {
            if (idx >= evSteps.size) {
                // Restore preview AE after bracketing
                previewRequestBuilder?.let { prev ->
                    captureSession?.setRepeatingRequest(prev.build(), null, backgroundHandler)
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "bracketCount" to resultsList.size,
                            "captures" to resultsList
                        )
                    )
                }
                return
            }

            val ev = evSteps[idx]
            val factor = Math.pow(2.0, ev)
            val targetExpNs = (baseExpNs * factor).toLong().coerceIn(50_000L, 500_000_000L)
            val singleArgs = HashMap<String, Any?>(args).apply {
                put("isArtworkMode", false)
                put("overrideIso", baseIso)
                put("overrideExposureTimeNs", targetExpNs)
                put("bracketTag", if (ev >= 0) "EV+${ev}" else "EV${ev}")
            }

            captureRawAndJpegPhoto(singleArgs, object : Result {
                override fun success(res: Any?) {
                    @Suppress("UNCHECKED_CAST")
                    val map = res as? Map<String, Any?>
                    if (map != null) resultsList.add(map)
                    captureNext(idx + 1)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    captureNext(idx + 1)
                }

                override fun notImplemented() {
                    captureNext(idx + 1)
                }
            })
        }

        captureNext(0)
    }

    private fun captureRawAndJpegPhoto(args: Map<String, Any?>, result: Result) {
        val camera = cameraDevice
        val session = captureSession
        val jpegReader = jpegImageReader
        if (camera == null || session == null || jpegReader == null) {
            result.error("NO_ACTIVE_SESSION", "Preview session is not active", null)
            return
        }

        try {
            val timestamp = System.currentTimeMillis()
            val bracketTag = (args["bracketTag"] as? String)?.replace(".", "_")
            val baseName = if (bracketTag != null) "ZAMERA_${timestamp}_${bracketTag}" else "ZAMERA_${timestamp}"
            val outDir = File(appContext.filesDir, "captures").apply { mkdirs() }
            val oemJpegFile = File(outDir, "${baseName}_OEM.jpg")
            val trueColorJpegFile = File(outDir, "${baseName}_TRUECOLOR.jpg")
            val dngFile = File(outDir, "${baseName}.dng")

            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(jpegReader.surface)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                captureBuilder.set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
            }
            captureBuilder.set(CaptureRequest.JPEG_ORIENTATION, activeSensorOrientation)

            val captureRaw = (args["captureRaw"] as? Boolean ?: true) && rawImageReader != null
            val isArtworkMode = args["isArtworkMode"] as? Boolean ?: true
            val useDisplayP3 = args["useDisplayP3"] as? Boolean ?: false
            val fullResolution = args["fullResolution"] as? Boolean ?: true
            val normalizeExposure = args["normalizeExposure"] as? Boolean ?: true
            val applyPerspectiveWarp = args["applyPerspectiveWarp"] as? Boolean ?: false
            val perspectiveCornersNorm = (args["perspectiveCornersNorm"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val customWbGains = (args["wbGains"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val customCamToXyz = (args["camToXyzD50"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val flatFieldGrid = (args["flatFieldGrid8x6"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }

            if (captureRaw) {
                rawImageReader?.surface?.let { captureBuilder.addTarget(it) }
            }

            previewRequestBuilder?.let { prev ->
                val overrideIso = (args["overrideIso"] as? Number)?.toInt()
                val overrideExpNs = (args["overrideExposureTimeNs"] as? Number)?.toLong()
                if (overrideIso != null && overrideExpNs != null) {
                    captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    captureBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, overrideIso)
                    captureBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, overrideExpNs)
                } else {
                    val aeMode = prev.get(CaptureRequest.CONTROL_AE_MODE) ?: CaptureRequest.CONTROL_AE_MODE_ON
                    captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, aeMode)
                    if (aeMode == CaptureRequest.CONTROL_AE_MODE_OFF) {
                        captureBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, prev.get(CaptureRequest.SENSOR_SENSITIVITY))
                        captureBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, prev.get(CaptureRequest.SENSOR_EXPOSURE_TIME))
                    } else {
                        captureBuilder.set(
                            CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                            prev.get(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION)
                        )
                    }
                }
                val afMode = prev.get(CaptureRequest.CONTROL_AF_MODE) ?: CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, afMode)
                if (afMode == CaptureRequest.CONTROL_AF_MODE_OFF) {
                    captureBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, prev.get(CaptureRequest.LENS_FOCUS_DISTANCE))
                }
                prev.get(CaptureRequest.CONTROL_AF_REGIONS)?.let {
                    captureBuilder.set(CaptureRequest.CONTROL_AF_REGIONS, it)
                }
                prev.get(CaptureRequest.CONTROL_AE_REGIONS)?.let {
                    captureBuilder.set(CaptureRequest.CONTROL_AE_REGIONS, it)
                }
                val awbMode = prev.get(CaptureRequest.CONTROL_AWB_MODE) ?: CaptureRequest.CONTROL_AWB_MODE_AUTO
                captureBuilder.set(CaptureRequest.CONTROL_AWB_MODE, awbMode)
                if (awbMode == CaptureRequest.CONTROL_AWB_MODE_OFF) {
                    captureBuilder.set(CaptureRequest.COLOR_CORRECTION_MODE, prev.get(CaptureRequest.COLOR_CORRECTION_MODE))
                    captureBuilder.set(CaptureRequest.COLOR_CORRECTION_TRANSFORM, prev.get(CaptureRequest.COLOR_CORRECTION_TRANSFORM))
                    captureBuilder.set(CaptureRequest.COLOR_CORRECTION_GAINS, prev.get(CaptureRequest.COLOR_CORRECTION_GAINS))
                }
            }

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val charsId = activePhysicalCameraId ?: activeCameraId
            val physChars = manager.getCameraCharacteristics(charsId)

            val lock = Any()
            var capturedJpegBytes: ByteArray? = null
            var capturedRawImage: Image? = null
            var capturedTotalResult: TotalCaptureResult? = null
            val finalized = AtomicBoolean(false)

            fun tryFinalizeCapture() {
                val res = synchronized(lock) {
                    val hasJpeg = capturedJpegBytes != null
                    val hasRaw = !captureRaw || capturedRawImage != null
                    val hasMeta = capturedTotalResult != null
                    if (hasJpeg && hasRaw && hasMeta && finalized.compareAndSet(false, true)) {
                        Triple(capturedJpegBytes!!, capturedRawImage, capturedTotalResult!!)
                    } else {
                        null
                    }
                } ?: return

                rustIspExecutor.execute {
                    val (jpegBytes, rawImg, logicalResult) = res
                    try {
                        val activePhysResult: CaptureResult = if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                            activePhysicalCameraId != null
                        ) {
                            logicalResult.physicalCameraResults[activePhysicalCameraId] ?: logicalResult
                        } else {
                            logicalResult
                        }

                        FileOutputStream(oemJpegFile).use { it.write(jpegBytes) }

                        var mediaStoreDngUri: String? = null
                        var mediaStoreJpegUri: String? = null
                        var statsMap: Map<String, Any?> = emptyMap()

                        if (rawImg != null) {
                            try {
                                // 1. Write archival 14-bit DNG with proper EXIF Orientation (Fixes B5!)
                                DngCreator(physChars, activePhysResult).use { dngCreator ->
                                    dngCreator.setOrientation(exifOrientationFromDegrees(activeSensorOrientation))
                                    FileOutputStream(dngFile).use { fos ->
                                        dngCreator.writeImage(fos, rawImg)
                                    }
                                }
                                mediaStoreDngUri = saveFileToMediaStoreDcim(
                                    sourceFile = dngFile,
                                    displayName = "${baseName}.dng",
                                    mimeType = "image/x-adobe-dng"
                                )

                                // 2. Extract dynamic sensor metadata for Rust `zamera_core`
                                val dynBlack = activePhysResult.get(CaptureResult.SENSOR_DYNAMIC_BLACK_LEVEL)
                                val staticBlackPattern = physChars.get(CameraCharacteristics.SENSOR_BLACK_LEVEL_PATTERN)
                                val blackLevel = when {
                                    dynBlack != null && dynBlack.size >= 4 -> floatArrayOf(
                                        dynBlack[0], dynBlack[1], dynBlack[2], dynBlack[3]
                                    )
                                    staticBlackPattern != null -> floatArrayOf(
                                        staticBlackPattern.getOffsetForIndex(0, 0).toFloat(),
                                        staticBlackPattern.getOffsetForIndex(1, 0).toFloat(),
                                        staticBlackPattern.getOffsetForIndex(0, 1).toFloat(),
                                        staticBlackPattern.getOffsetForIndex(1, 1).toFloat()
                                    )
                                    else -> floatArrayOf(1025f, 1025f, 1025f, 1025f)
                                }

                                val dynWhite = activePhysResult.get(CaptureResult.SENSOR_DYNAMIC_WHITE_LEVEL)
                                val staticWhite = physChars.get(CameraCharacteristics.SENSOR_INFO_WHITE_LEVEL)
                                val whiteLevel = (dynWhite ?: staticWhite ?: 16383).toFloat()

                                val cfaPattern = physChars.get(
                                    CameraCharacteristics.SENSOR_INFO_COLOR_FILTER_ARRANGEMENT
                                ) ?: CameraCharacteristics.SENSOR_INFO_COLOR_FILTER_ARRANGEMENT_RGGB

                                val lensShadingApplied = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    physChars.get(CameraCharacteristics.SENSOR_INFO_LENS_SHADING_APPLIED) == true
                                } else {
                                    false
                                }

                                val neutralPoint = activePhysResult.get(CaptureResult.SENSOR_NEUTRAL_COLOR_POINT)
                                val asShotNeutral = if (neutralPoint != null && neutralPoint.size >= 3) {
                                    floatArrayOf(
                                        neutralPoint[0].toFloat().coerceAtLeast(1e-4f),
                                        neutralPoint[1].toFloat().coerceAtLeast(1e-4f),
                                        neutralPoint[2].toFloat().coerceAtLeast(1e-4f)
                                    )
                                } else {
                                    floatArrayOf(0.465f, 1.0f, 0.645f)
                                }

                                val asShotWbGains = floatArrayOf(
                                    asShotNeutral[1] / asShotNeutral[0],
                                    1.0f,
                                    asShotNeutral[1] / asShotNeutral[2]
                                )

                                val wbGains = if (customWbGains != null && customWbGains.size >= 3) {
                                    floatArrayOf(customWbGains[0], customWbGains[1], customWbGains[2])
                                } else {
                                    asShotWbGains
                                }

                                // Extract DNG ColorMatrix1/2 and ForwardMatrix1/2 for DNG 1.7 CCT interpolation (Fixes B2!)
                                val cm1 = extractMatrix3x3(physChars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1))
                                    ?: floatArrayOf(
                                        0.8125f, -0.2734f, -0.1094f,
                                        -0.4375f, 1.3281f, 0.0859f,
                                        -0.0312f, 0.2578f, 0.4297f
                                    )
                                val cm2 = extractMatrix3x3(physChars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM2))
                                    ?: floatArrayOf(
                                        1.2188f, -0.4688f, -0.4531f,
                                        -0.9766f, 2.1797f, -0.2891f,
                                        -0.1875f, 0.3750f, 0.6094f
                                    )
                                val fm1 = extractMatrix3x3(physChars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1))
                                    ?: floatArrayOf(
                                        0.5469f, 0.2734f, 0.1406f,
                                        0.1875f, 0.8672f, -0.0547f,
                                        -0.0547f, -0.3672f, 1.2500f
                                    )
                                val fm2 = extractMatrix3x3(physChars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX2))
                                    ?: floatArrayOf(
                                        0.6016f, -0.0391f, 0.3984f,
                                        0.2734f, 0.4688f, 0.2500f,
                                        0.0547f, -0.6562f, 1.4219f
                                    )

                                val hasCustomMatrix = customCamToXyz != null && customCamToXyz.size == 9
                                val primaryFm1OrCustom = if (hasCustomMatrix) customCamToXyz!!.toFloatArray() else fm1

                                val plane = rawImg.planes[0]
                                val rawBuffer = plane.buffer
                                rawBuffer.rewind()

                                // Fixes B1, B2, B3, B7:
                                // - In Sanat Mode (`isArtworkMode == true`), develop full-res (4096x3072 -> rotated 3072x4096 12.6 MP)
                                //   with DNG CCT interpolation (`FM1`/`FM2`) and White-Point Exposure Normalization!
                                // - In Pro Mode (`isArtworkMode == false`), skip redundant Bitmap encoding (`writeTrueColorBitmap = false`)
                                //   and only compute fast 14-bit RAW telemetry (32-bin histogram, zebra, focus peaking, CCT)!
                                val devResult = ZameraRustBridge.developRawToTrueColorFile(
                                    rawDirectBuffer = rawBuffer,
                                    width = rawImg.width,
                                    height = rawImg.height,
                                    rowStride = plane.rowStride,
                                    cfaPattern = cfaPattern,
                                    blackLevel = blackLevel,
                                    whiteLevel = whiteLevel,
                                    wbGains = wbGains,
                                    fm1OrCustomMatrix = primaryFm1OrCustom,
                                    asShotNeutralForCct = if (hasCustomMatrix) null else asShotNeutral,
                                    cm1 = cm1,
                                    cm2 = cm2,
                                    fm2 = fm2,
                                    flatField8x6 = if (flatFieldGrid != null && flatFieldGrid.size == 48) flatFieldGrid.toFloatArray() else null,
                                    useDisplayP3 = useDisplayP3,
                                    normalizeExposure = normalizeExposure,
                                    fullResolution = isArtworkMode && fullResolution,
                                    writeTrueColorBitmap = isArtworkMode,
                                    sensorOrientationDegrees = activeSensorOrientation,
                                    applyPerspectiveWarp = isArtworkMode && applyPerspectiveWarp,
                                    perspectiveCornersNorm = if (perspectiveCornersNorm != null && perspectiveCornersNorm.size == 8) perspectiveCornersNorm.toFloatArray() else null,
                                    outFile = trueColorJpegFile
                                )

                                val primaryJpegToExport = if (isArtworkMode && trueColorJpegFile.exists()) {
                                    trueColorJpegFile
                                } else {
                                    oemJpegFile
                                }
                                val suffix = if (isArtworkMode && trueColorJpegFile.exists()) "TRUECOLOR" else "PRO"
                                mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                    sourceFile = primaryJpegToExport,
                                    displayName = "${baseName}_${suffix}.jpg",
                                    mimeType = "image/jpeg"
                                )

                                statsMap = mapOf(
                                    "blackLevel" to blackLevel.toList(),
                                    "whiteLevel" to whiteLevel.toDouble(),
                                    "cfaPattern" to cfaPattern,
                                    "lensShadingApplied" to lensShadingApplied,
                                    "wbGainsUsed" to wbGains.toList(),
                                    "centerLinearCamRgb" to devResult.centerLinearCamRgb,
                                    "meanRgb" to devResult.meanRgb,
                                    "highlightClippedRatio" to devResult.highlightClippedRatio,
                                    "gamutClippedRatio" to devResult.gamutClippedRatio,
                                    "exposureNormGain" to devResult.exposureNormGain,
                                    "solvedCctKelvin" to devResult.solvedCctKelvin,
                                    "zebraRatio" to devResult.zebraRatio,
                                    "focusPeakingScore" to devResult.focusPeakingScore,
                                    "rawHistogram32" to devResult.rawHistogram32,
                                    "measuredFlatField8x6" to devResult.measuredFlatField8x6,
                                    "outputWidth" to devResult.outWidth,
                                    "outputHeight" to devResult.outHeight,
                                    "rustIspActive" to (isArtworkMode && devResult.rustIspSucceeded)
                                )
                            } finally {
                                rawImg.close()
                            }
                        } else {
                            mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                sourceFile = oemJpegFile,
                                displayName = "${baseName}.jpg",
                                mimeType = "image/jpeg"
                            )
                        }

                        val finalJpegPath = if (isArtworkMode && trueColorJpegFile.exists()) {
                            trueColorJpegFile.absolutePath
                        } else {
                            oemJpegFile.absolutePath
                        }

                        val response = HashMap<String, Any?>().apply {
                            put("jpegPath", finalJpegPath)
                            put("oemJpegPath", oemJpegFile.absolutePath)
                            put("dngPath", if (dngFile.exists()) dngFile.absolutePath else null)
                            put("mediaStoreJpegUri", mediaStoreJpegUri)
                            put("mediaStoreDngUri", mediaStoreDngUri)
                            put("cameraId", activePhysicalCameraId ?: activeCameraId)
                            put("iso", activePhysResult.get(CaptureResult.SENSOR_SENSITIVITY))
                            put("exposureTimeNs", activePhysResult.get(CaptureResult.SENSOR_EXPOSURE_TIME))
                            putAll(statsMap)
                        }

                        mainHandler.post {
                            result.success(response)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("ISP_PIPELINE_ERR", e.message, e.stackTraceToString())
                        }
                    }
                }
            }

            jpegReader.setOnImageAvailableListener({ reader ->
                val img = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                try {
                    val buf = img.planes[0].buffer
                    val bytes = ByteArray(buf.remaining())
                    buf.get(bytes)
                    synchronized(lock) {
                        capturedJpegBytes = bytes
                    }
                } finally {
                    img.close()
                }
                tryFinalizeCapture()
            }, backgroundHandler)

            if (captureRaw) {
                rawImageReader?.setOnImageAvailableListener({ reader ->
                    val rawImg = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                    synchronized(lock) {
                        if (capturedRawImage == null) {
                            capturedRawImage = rawImg
                        } else {
                            rawImg.close()
                        }
                    }
                    tryFinalizeCapture()
                }, backgroundHandler)
            }

            session.capture(
                captureBuilder.build(),
                object : CameraCaptureSession.CaptureCallback() {
                    override fun onCaptureCompleted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        res: TotalCaptureResult
                    ) {
                        lastTotalCaptureResult = res
                        synchronized(lock) {
                            capturedTotalResult = res
                        }
                        tryFinalizeCapture()
                    }
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            result.error("CAPTURE_ERR", e.message, null)
        }
    }

    private fun exifOrientationFromDegrees(degrees: Int): Int {
        return when ((degrees % 360 + 360) % 360) {
            90 -> ExifInterface.ORIENTATION_ROTATE_90
            180 -> ExifInterface.ORIENTATION_ROTATE_180
            270 -> ExifInterface.ORIENTATION_ROTATE_270
            else -> ExifInterface.ORIENTATION_NORMAL
        }
    }

    private fun extractMatrix3x3(transform: ColorSpaceTransform?): FloatArray? {
        if (transform == null) return null
        val out = FloatArray(9)
        var idx = 0
        for (row in 0 until 3) {
            for (col in 0 until 3) {
                val rat = transform.getElement(col, row)
                out[idx++] = if (rat.denominator != 0) rat.numerator.toFloat() / rat.denominator.toFloat() else 0f
            }
        }
        return out
    }

    private fun floatArrayToColorSpaceTransform(m: FloatArray): ColorSpaceTransform {
        val elements = Array(9) { i ->
            val num = (m[i] * 10000.0f).roundToInt()
            Rational(num, 10000)
        }
        return ColorSpaceTransform(elements)
    }

    private fun saveFileToMediaStoreDcim(
        sourceFile: File,
        displayName: String,
        mimeType: String
    ): String? {
        if (!sourceFile.exists()) return null
        return try {
            val resolver = appContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Zamera")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return null
            resolver.openOutputStream(uri)?.use { outStream ->
                sourceFile.inputStream().use { inStream ->
                    inStream.copyTo(outStream)
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val doneValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, doneValues, null, null)
            }
            uri.toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun stopPreviewSession() {
        try {
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
            rawImageReader?.close()
            rawImageReader = null
            jpegImageReader?.close()
            jpegImageReader = null
            previewSurface?.release()
            previewSurface = null
            surfaceEntry?.release()
            surfaceEntry = null
        } catch (_: Exception) {
        }
    }

    private fun probeCamera2Capabilities(): Map<String, Any?> {
        val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val logicalIds = manager.cameraIdList.toList()
        val allDiscoveredIds = linkedSetOf<String>().apply { addAll(logicalIds) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            for (id in logicalIds) {
                try {
                    val chars = manager.getCameraCharacteristics(id)
                    allDiscoveredIds.addAll(chars.physicalCameraIds)
                } catch (_: Exception) {
                }
            }
        }

        val cameras = mutableListOf<Map<String, Any?>>()
        for (id in allDiscoveredIds) {
            try {
                val chars = manager.getCameraCharacteristics(id)
                cameras.add(extractCameraCharacteristics(id, logicalIds.contains(id), chars))
            } catch (e: Exception) {
                cameras.add(
                    mapOf(
                        "cameraId" to id,
                        "isDirectlyOpenableInCameraIdList" to logicalIds.contains(id),
                        "error" to (e.message ?: "Restricted by OEM HAL")
                    )
                )
            }
        }

        val report = mapOf(
            "platform" to "android",
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "rustCoreVersion" to ZameraRustBridge.safeCoreVersion(),
            "cameraIdList" to allDiscoveredIds.toList(),
            "cameras" to cameras
        )
        try {
            val jsonStr = org.json.JSONObject(report).toString(2)
            File(appContext.filesDir, "probe_report.json").writeText(jsonStr)
        } catch (_: Exception) {
        }
        return report
    }

    private fun extractCameraCharacteristics(
        cameraId: String,
        inCameraIdList: Boolean,
        chars: CameraCharacteristics
    ): Map<String, Any?> {
        val hwLevelInt = chars.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)
        val hwLevel = when (hwLevelInt) {
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY"
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED"
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL"
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3"
            CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "EXTERNAL"
            else -> "UNKNOWN($hwLevelInt)"
        }

        val facingInt = chars.get(CameraCharacteristics.LENS_FACING)
        val facing = when (facingInt) {
            CameraCharacteristics.LENS_FACING_BACK -> "BACK"
            CameraCharacteristics.LENS_FACING_FRONT -> "FRONT"
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "EXTERNAL"
            else -> "UNKNOWN"
        }

        val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES) ?: intArrayOf()
        val capNames = mutableListOf<String>()
        fun checkCap(flag: Int, name: String) {
            if (caps.contains(flag)) capNames.add(name)
        }
        checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE, "BACKWARD_COMPATIBLE")
        checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR, "MANUAL_SENSOR")
        checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING, "MANUAL_POST_PROCESSING")
        checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_RAW, "RAW")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA, "LOGICAL_MULTI_CAMERA")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkCap(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_ULTRA_HIGH_RESOLUTION_SENSOR,
                "ULTRA_HIGH_RESOLUTION_SENSOR"
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkCap(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DYNAMIC_RANGE_TEN_BIT, "DYNAMIC_RANGE_TEN_BIT")
        }

        val physicalIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            chars.physicalCameraIds.toList()
        } else {
            emptyList()
        }

        val configMap = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val rawSensorSizes = configMap?.getOutputSizes(ImageFormat.RAW_SENSOR)
            ?.map { "${it.width}x${it.height}" } ?: emptyList()
        val raw10Sizes = configMap?.getOutputSizes(ImageFormat.RAW10)
            ?.map { "${it.width}x${it.height}" } ?: emptyList()

        val maxResRawSensorSizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val maxMap = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP_MAXIMUM_RESOLUTION)
            maxMap?.getOutputSizes(ImageFormat.RAW_SENSOR)?.map { "${it.width}x${it.height}" } ?: emptyList()
        } else {
            emptyList()
        }

        val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.toList() ?: emptyList()
        val apertures = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.toList() ?: emptyList()
        val minFocusDist = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
        val focusCalibration = chars.get(CameraCharacteristics.LENS_INFO_FOCUS_DISTANCE_CALIBRATION) ?: 0
        val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        val exposureNsRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        val whiteLevel = chars.get(CameraCharacteristics.SENSOR_INFO_WHITE_LEVEL)
        val sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
        val lensShadingApplied = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            chars.get(CameraCharacteristics.SENSOR_INFO_LENS_SHADING_APPLIED) == true
        } else {
            false
        }

        val tenBitProfiles = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val drProfiles = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES)
            val supported = drProfiles?.supportedProfiles ?: emptySet()
            if (supported.contains(DynamicRangeProfiles.HLG10)) tenBitProfiles.add("HLG10")
            if (supported.contains(DynamicRangeProfiles.HDR10)) tenBitProfiles.add("HDR10")
            if (supported.contains(DynamicRangeProfiles.HDR10_PLUS)) tenBitProfiles.add("HDR10_PLUS")
            if (supported.contains(DynamicRangeProfiles.DOLBY_VISION_10B_HDR_OEM)) tenBitProfiles.add("DOLBY_VISION_10B")
        }

        val oisModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)?.toList() ?: emptyList()
        val videoStabModes = chars.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)?.toList() ?: emptyList()

        return mapOf(
            "cameraId" to cameraId,
            "isDirectlyOpenableInCameraIdList" to inCameraIdList,
            "facing" to facing,
            "hardwareLevel" to hwLevel,
            "sensorOrientation" to sensorOrientation,
            "lensShadingApplied" to lensShadingApplied,
            "focusDistanceCalibration" to focusCalibration,
            "capabilities" to capNames,
            "supportsRawSensor" to rawSensorSizes.isNotEmpty(),
            "rawSensorSizes" to rawSensorSizes,
            "raw10Sizes" to raw10Sizes,
            "maxResolutionRawSensorSizes" to maxResRawSensorSizes,
            "physicalCameraIds" to physicalIds,
            "focalLengthsMm" to focalLengths,
            "apertures" to apertures,
            "minimumFocusDistanceDiopters" to minFocusDist,
            "isoRange" to if (isoRange != null) listOf(isoRange.lower, isoRange.upper) else null,
            "exposureTimeRangeNs" to if (exposureNsRange != null) listOf(exposureNsRange.lower, exposureNsRange.upper) else null,
            "sensorWhiteLevel" to whiteLevel,
            "tenBitDynamicRangeProfiles" to tenBitProfiles,
            "supportsOis" to oisModes.contains(CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_ON),
            "supportsVideoStabilization" to videoStabModes.isNotEmpty()
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopPreviewSession()
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
        channel.setMethodCallHandler(null)
    }
}

data class RustRawDevelopOutput(
    val rustIspSucceeded: Boolean,
    val outWidth: Int,
    val outHeight: Int,
    val meanRgb: List<Double>,
    val centerLinearCamRgb: List<Double>,
    val highlightClippedRatio: Double,
    val gamutClippedRatio: Double,
    val exposureNormGain: Double,
    val solvedCctKelvin: Double,
    val zebraRatio: Double,
    val focusPeakingScore: Double,
    val rawHistogram32: List<Double>,
    val measuredFlatField8x6: List<Double>
)

object ZameraRustBridge {
    private var loaded = false

    init {
        try {
            System.loadLibrary("zamera_core")
            loaded = true
        } catch (_: Throwable) {
            loaded = false
        }
    }

    @JvmStatic
    private external fun nativeCoreVersion(): String

    @JvmStatic
    private external fun nativeDevelopBayer16Direct(
        rawBuffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        cfaPattern: Int,
        paramsBuffer: ByteBuffer,
        useDisplayP3: Int,
        normalizeExposure: Int,
        outRgbaBuffer: ByteBuffer,
        outStatsBuffer: ByteBuffer
    ): Int

    @JvmStatic
    private external fun nativeComputeKelvinWbDirect(
        inBuffer: ByteBuffer,
        outBuffer: ByteBuffer
    ): Int

    fun safeCoreVersion(): String {
        if (!loaded) {
            return "UNLOADED: libzamera_core.so yüklenemedi"
        }
        return try {
            nativeCoreVersion()
        } catch (t: Throwable) {
            "JNI_SYMBOL_ERR: ${t.message}"
        }
    }

    fun computeDngKelvinWb(
        kelvin: Float,
        tint: Float,
        cm1: FloatArray,
        cm2: FloatArray,
        fm1: FloatArray,
        fm2: FloatArray
    ): Pair<FloatArray, FloatArray>? {
        if (!loaded) return null
        val inBuf = ByteBuffer.allocateDirect(38 * 4).order(ByteOrder.nativeOrder())
        val inf = inBuf.asFloatBuffer()
        inf.put(kelvin)
        inf.put(tint)
        for (i in 0 until 9) inf.put(cm1[i])
        for (i in 0 until 9) inf.put(cm2[i])
        for (i in 0 until 9) inf.put(fm1[i])
        for (i in 0 until 9) inf.put(fm2[i])

        val outBuf = ByteBuffer.allocateDirect(13 * 4).order(ByteOrder.nativeOrder())
        val rc = nativeComputeKelvinWbDirect(inBuf, outBuf)
        if (rc != 0) return null
        val outf = outBuf.asFloatBuffer()
        val gains = FloatArray(4) { i -> outf.get(i) }
        val mat = FloatArray(9) { i -> outf.get(4 + i) }
        return Pair(gains, mat)
    }

    fun developRawToTrueColorFile(
        rawDirectBuffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        cfaPattern: Int,
        blackLevel: FloatArray,
        whiteLevel: Float,
        wbGains: FloatArray,
        fm1OrCustomMatrix: FloatArray,
        asShotNeutralForCct: FloatArray?,
        cm1: FloatArray,
        cm2: FloatArray,
        fm2: FloatArray,
        flatField8x6: FloatArray?,
        useDisplayP3: Boolean,
        normalizeExposure: Boolean,
        fullResolution: Boolean,
        writeTrueColorBitmap: Boolean,
        sensorOrientationDegrees: Int,
        applyPerspectiveWarp: Boolean = false,
        perspectiveCornersNorm: FloatArray? = null,
        outFile: File
    ): RustRawDevelopOutput {
        if (!loaded) {
            return RustRawDevelopOutput(
                rustIspSucceeded = false,
                outWidth = 0,
                outHeight = 0,
                meanRgb = listOf(0.0, 0.0, 0.0),
                centerLinearCamRgb = listOf(0.18, 0.18, 0.18),
                highlightClippedRatio = 0.0,
                gamutClippedRatio = 0.0,
                exposureNormGain = 1.0,
                solvedCctKelvin = 5500.0,
                zebraRatio = 0.0,
                focusPeakingScore = 0.0,
                rawHistogram32 = List(32) { 0.0 },
                measuredFlatField8x6 = List(48) { 1.0 }
            )
        }

        val outW = if (fullResolution && writeTrueColorBitmap) width else width / 2
        val outH = if (fullResolution && writeTrueColorBitmap) height else height / 2

        val paramFloats = if (flatField8x6 != null) 95 else 47
        val paramsBuffer = ByteBuffer.allocateDirect(paramFloats * 4).order(ByteOrder.nativeOrder())
        val pf = paramsBuffer.asFloatBuffer()
        pf.put(blackLevel[0])
        pf.put(blackLevel[1])
        pf.put(blackLevel[2])
        pf.put(blackLevel[3])
        pf.put(whiteLevel)
        pf.put(wbGains[0])
        pf.put(wbGains[1])
        pf.put(wbGains[2])
        for (i in 0 until 9) pf.put(fm1OrCustomMatrix[i])
        if (asShotNeutralForCct != null && asShotNeutralForCct.size >= 3) {
            pf.put(asShotNeutralForCct[0])
            pf.put(asShotNeutralForCct[1])
            pf.put(asShotNeutralForCct[2])
        } else {
            pf.put(0.0f)
            pf.put(0.0f)
            pf.put(0.0f)
        }
        for (i in 0 until 9) pf.put(cm1[i])
        for (i in 0 until 9) pf.put(cm2[i])
        for (i in 0 until 9) pf.put(fm2[i])
        if (flatField8x6 != null) {
            for (i in 0 until 48) pf.put(flatField8x6[i])
        }

        val outRgbaBuffer = ByteBuffer.allocateDirect(outW * outH * 4)
        val outStatsBuffer = ByteBuffer.allocateDirect(92 * 4).order(ByteOrder.nativeOrder())

        val rc = nativeDevelopBayer16Direct(
            rawDirectBuffer,
            width,
            height,
            rowStride,
            cfaPattern,
            paramsBuffer,
            if (useDisplayP3) 1 else 0,
            if (normalizeExposure) 1 else 0,
            outRgbaBuffer,
            outStatsBuffer
        )

        if (rc != 0) {
            return RustRawDevelopOutput(
                rustIspSucceeded = false,
                outWidth = 0,
                outHeight = 0,
                meanRgb = listOf(0.0, 0.0, 0.0),
                centerLinearCamRgb = listOf(0.18, 0.18, 0.18),
                highlightClippedRatio = 0.0,
                gamutClippedRatio = 0.0,
                exposureNormGain = 1.0,
                solvedCctKelvin = 5500.0,
                zebraRatio = 0.0,
                focusPeakingScore = 0.0,
                rawHistogram32 = List(32) { 0.0 },
                measuredFlatField8x6 = List(48) { 1.0 }
            )
        }

        var finalW = outW
        var finalH = outH
        if (writeTrueColorBitmap) {
            outRgbaBuffer.rewind()
            val colorSpace = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ColorSpace.get(if (useDisplayP3) ColorSpace.Named.DISPLAY_P3 else ColorSpace.Named.SRGB)
            } else {
                null
            }

            val rawBitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && colorSpace != null) {
                Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888, false, colorSpace)
            } else {
                Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
            }
            rawBitmap.copyPixelsFromBuffer(outRgbaBuffer)

            val rotatedBitmap = if (sensorOrientationDegrees != 0) {
                val matrix = Matrix().apply { postRotate(sensorOrientationDegrees.toFloat()) }
                val rotated = Bitmap.createBitmap(rawBitmap, 0, 0, outW, outH, matrix, true)
                if (rotated !== rawBitmap) rawBitmap.recycle()
                rotated
            } else {
                rawBitmap
            }

            val finalBitmap = if (applyPerspectiveWarp && perspectiveCornersNorm != null && perspectiveCornersNorm.size == 8) {
                val rw = rotatedBitmap.width.toFloat()
                val rh = rotatedBitmap.height.toFloat()
                val srcPts = floatArrayOf(
                    perspectiveCornersNorm[0] * rw, perspectiveCornersNorm[1] * rh,
                    perspectiveCornersNorm[2] * rw, perspectiveCornersNorm[3] * rh,
                    perspectiveCornersNorm[4] * rw, perspectiveCornersNorm[5] * rh,
                    perspectiveCornersNorm[6] * rw, perspectiveCornersNorm[7] * rh
                )
                val dstPts = floatArrayOf(
                    0f, 0f,
                    rw, 0f,
                    rw, rh,
                    0f, rh
                )
                val polyMatrix = Matrix()
                if (polyMatrix.setPolyToPoly(srcPts, 0, dstPts, 0, 4)) {
                    val warped = Bitmap.createBitmap(rotatedBitmap.width, rotatedBitmap.height, rotatedBitmap.config ?: Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(warped)
                    val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG or android.graphics.Paint.ANTI_ALIAS_FLAG)
                    canvas.drawBitmap(rotatedBitmap, polyMatrix, paint)
                    rotatedBitmap.recycle()
                    warped
                } else {
                    rotatedBitmap
                }
            } else {
                rotatedBitmap
            }

            finalW = finalBitmap.width
            finalH = finalBitmap.height
            FileOutputStream(outFile).use { fos ->
                finalBitmap.compress(Bitmap.CompressFormat.JPEG, 96, fos)
            }
            finalBitmap.recycle()
        }

        val sf = outStatsBuffer.asFloatBuffer()
        val meanR = sf.get(0).toDouble()
        val meanG = sf.get(1).toDouble()
        val meanB = sf.get(2).toDouble()
        val highlightClip = sf.get(3).toDouble()
        val gamutClip = sf.get(4).toDouble()
        val centerR = sf.get(5).toDouble()
        val centerG = sf.get(6).toDouble()
        val centerB = sf.get(7).toDouble()
        val expNormGain = sf.get(8).toDouble()
        val solvedCct = sf.get(9).toDouble()
        val zebraRatio = sf.get(10).toDouble()
        val peakingScore = sf.get(11).toDouble()
        val hist32 = List(32) { i -> sf.get(12 + i).toDouble() }
        val flatField48 = List(48) { i -> sf.get(44 + i).toDouble() }

        return RustRawDevelopOutput(
            rustIspSucceeded = true,
            outWidth = finalW,
            outHeight = finalH,
            meanRgb = listOf(meanR, meanG, meanB),
            centerLinearCamRgb = listOf(centerR, centerG, centerB),
            highlightClippedRatio = highlightClip,
            gamutClippedRatio = gamutClip,
            exposureNormGain = expNormGain,
            solvedCctKelvin = solvedCct,
            zebraRatio = zebraRatio,
            focusPeakingScore = peakingScore,
            rawHistogram32 = hist32,
            measuredFlatField8x6 = flatField48
        )
    }
}
