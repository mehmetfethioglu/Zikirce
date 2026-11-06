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
import android.hardware.camera2.*
import android.hardware.camera2.params.ColorSpaceTransform
import android.hardware.camera2.params.DynamicRangeProfiles
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.RggbChannelVector
import android.hardware.camera2.params.SessionConfiguration
import android.media.Image
import android.media.ImageReader
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.MediaStore
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

/**
 * ZameraCapturePlugin (Android Camera2 Hardware Probe + Live Preview Texture + Physical Camera ID Routing
 * + Real JNI Rust `zamera_core` 14-bit RAW -> TrueColor sRGB/Display P3 ISP + MediaStore DCIM/Zamera Export)
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
    private var pendingPermissionAction: (() -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var rustIspExecutor = Executors.newSingleThreadExecutor()

    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var rawImageReader: ImageReader? = null
    private var jpegImageReader: ImageReader? = null
    private var activeCameraId: String = "0"
    private var activePhysicalCameraId: String? = null
    private var activeSensorOrientation: Int = 90
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
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pendingPermissionAction?.invoke()
            }
            pendingPermissionAction = null
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "probeDeviceCapabilities" -> {
                try {
                    result.success(probeCamera2Capabilities())
                } catch (e: Exception) {
                    result.error("PROBE_FAILED", e.message, e.stackTraceToString())
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
            "capturePhoto" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                captureRawAndJpegPhoto(args, result)
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
            pendingPermissionAction = action
            ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.CAMERA), 9001)
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

            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            // Pick a 4:3 preview size matching the 4:3 RAW sensor aspect ratio
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
            val previewSurface = Surface(surfaceTexture)

            val jpegSize = map?.getOutputSizes(ImageFormat.JPEG)?.maxByOrNull { it.width * it.height }
                ?: previewSize
            jpegImageReader = ImageReader.newInstance(jpegSize.width, jpegSize.height, ImageFormat.JPEG, 2)

            val rawSizes = map?.getOutputSizes(ImageFormat.RAW_SENSOR)
            if (!rawSizes.isNullOrEmpty()) {
                val rawSize = rawSizes.maxByOrNull { it.width * it.height }!!
                rawImageReader = ImageReader.newInstance(rawSize.width, rawSize.height, ImageFormat.RAW_SENSOR, 2)
            }

            manager.openCamera(openLogicalId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                        builder.addTarget(previewSurface)
                        builder.set(
                            CaptureRequest.CONTROL_AF_MODE,
                            CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                        )
                        previewRequestBuilder = builder

                        val surfaces = mutableListOf<Surface>(previewSurface)
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
                                                "supportsRawSensor" to (rawImageReader != null)
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
                            val outConfigs = surfaces.map { surf ->
                                OutputConfiguration(surf).apply {
                                    setPhysicalCameraId(targetPhysicalId)
                                }
                            }
                            val sessionConfig = SessionConfiguration(
                                SessionConfiguration.SESSION_REGULAR,
                                outConfigs,
                                Executors.newSingleThreadExecutor(),
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
            val rggb = args["rggbGains"] as? List<*>

            // In Sanat (Artwork) mode, keep viewfinder AWB smooth unless manual WB is explicitly enabled in Pro mode.
            // Whenever TRANSFORM_MATRIX is used, always supply a valid COLOR_CORRECTION_TRANSFORM so preview never turns black/green.
            if (!artworkLinearMode && manualWb && rggb != null && rggb.size == 4) {
                val colorTransform = chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1)
                    ?: chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1)
                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)
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
            val outDir = File(appContext.filesDir, "captures").apply { mkdirs() }
            val oemJpegFile = File(outDir, "ZAMERA_${timestamp}_OEM.jpg")
            val trueColorJpegFile = File(outDir, "ZAMERA_${timestamp}_TRUECOLOR.jpg")
            val dngFile = File(outDir, "ZAMERA_${timestamp}.dng")

            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(jpegReader.surface)

            val captureRaw = (args["captureRaw"] as? Boolean ?: true) && rawImageReader != null
            val isArtworkMode = args["isArtworkMode"] as? Boolean ?: true
            val useDisplayP3 = args["useDisplayP3"] as? Boolean ?: false
            val applyFlatField = args["applyFlatField"] as? Boolean ?: true
            val customWbGains = (args["wbGains"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val customCamToXyz = (args["camToXyzD50"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }

            if (captureRaw) {
                rawImageReader?.surface?.let { captureBuilder.addTarget(it) }
            }

            previewRequestBuilder?.let { prev ->
                captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, prev.get(CaptureRequest.CONTROL_AE_MODE))
                captureBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, prev.get(CaptureRequest.SENSOR_SENSITIVITY))
                captureBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, prev.get(CaptureRequest.SENSOR_EXPOSURE_TIME))
                captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, prev.get(CaptureRequest.CONTROL_AF_MODE))
                captureBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, prev.get(CaptureRequest.LENS_FOCUS_DISTANCE))
                captureBuilder.set(CaptureRequest.CONTROL_AWB_MODE, prev.get(CaptureRequest.CONTROL_AWB_MODE))
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
                        // Resolve physical camera CaptureResult if available on API 29+
                        val activePhysResult: CaptureResult = if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                            activePhysicalCameraId != null
                        ) {
                            logicalResult.physicalCameraResults[activePhysicalCameraId] ?: logicalResult
                        } else {
                            logicalResult
                        }

                        // Save OEM JPEG locally
                        FileOutputStream(oemJpegFile).use { it.write(jpegBytes) }

                        var mediaStoreDngUri: String? = null
                        var mediaStoreJpegUri: String? = null
                        var statsMap: Map<String, Any?> = emptyMap()

                        if (rawImg != null) {
                            try {
                                // 1. Write archival 14-bit DNG via DngCreator
                                DngCreator(physChars, activePhysResult).use { dngCreator ->
                                    FileOutputStream(dngFile).use { fos ->
                                        dngCreator.writeImage(fos, rawImg)
                                    }
                                }
                                mediaStoreDngUri = saveFileToMediaStoreDcim(
                                    sourceFile = dngFile,
                                    displayName = "ZAMERA_${timestamp}.dng",
                                    mimeType = "image/x-adobe-dng"
                                )

                                // 2. Extract dynamic sensor metadata for Rust `zamera_core` TrueColor ISP
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

                                // Neutral White Balance gains: use user Gray-Card gains if provided, else AsShotNeutral
                                val neutralPoint = activePhysResult.get(CaptureResult.SENSOR_NEUTRAL_COLOR_POINT)
                                val asShotWbGains = if (neutralPoint != null && neutralPoint.size >= 3) {
                                    val nr = neutralPoint[0].toFloat().coerceAtLeast(1e-4f)
                                    val ng = neutralPoint[1].toFloat().coerceAtLeast(1e-4f)
                                    val nb = neutralPoint[2].toFloat().coerceAtLeast(1e-4f)
                                    floatArrayOf(ng / nr, 1.0f, ng / nb)
                                } else {
                                    floatArrayOf(2.15f, 1.0f, 1.55f)
                                }

                                val wbGains = if (customWbGains != null && customWbGains.size >= 3) {
                                    floatArrayOf(customWbGains[0], customWbGains[1], customWbGains[2])
                                } else {
                                    asShotWbGains
                                }

                                // Camera RGB -> CIE XYZ (D50) 3x3 matrix: use calibrated ColorChecker matrix or DNG ForwardMatrix1
                                val dngForwardMatrix = extractMatrix3x3(
                                    physChars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1)
                                ) ?: floatArrayOf(
                                    0.5469f, 0.2734f, 0.1406f,
                                    0.1875f, 0.8672f, -0.0547f,
                                    -0.0547f, -0.3672f, 1.2500f
                                )
                                val camToXyzD50 = if (customCamToXyz != null && customCamToXyz.size == 9) {
                                    customCamToXyz.toFloatArray()
                                } else {
                                    dngForwardMatrix
                                }

                                // 3. Run Rust `zamera_core` 14-bit RAW -> TrueColor sRGB / Display P3 ISP
                                val plane = rawImg.planes[0]
                                val rawBuffer = plane.buffer
                                rawBuffer.rewind()

                                val devResult = ZameraRustBridge.developRawToTrueColorFile(
                                    rawDirectBuffer = rawBuffer,
                                    width = rawImg.width,
                                    height = rawImg.height,
                                    rowStride = plane.rowStride,
                                    cfaPattern = cfaPattern,
                                    blackLevel = blackLevel,
                                    whiteLevel = whiteLevel,
                                    wbGains = wbGains,
                                    camToXyzD50 = camToXyzD50,
                                    useDisplayP3 = useDisplayP3,
                                    applyFlatField = applyFlatField && !lensShadingApplied,
                                    sensorOrientationDegrees = activeSensorOrientation,
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
                                    displayName = "ZAMERA_${timestamp}_${suffix}.jpg",
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
                                    "rustIspActive" to devResult.rustIspSucceeded
                                )
                            } finally {
                                rawImg.close()
                            }
                        } else {
                            mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                sourceFile = oemJpegFile,
                                displayName = "ZAMERA_${timestamp}.jpg",
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
    val meanRgb: List<Double>,
    val centerLinearCamRgb: List<Double>,
    val highlightClippedRatio: Double,
    val gamutClippedRatio: Double
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
        applyFlatField: Int,
        outRgbaBuffer: ByteBuffer,
        outStatsBuffer: ByteBuffer
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

    fun developRawToTrueColorFile(
        rawDirectBuffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        cfaPattern: Int,
        blackLevel: FloatArray,
        whiteLevel: Float,
        wbGains: FloatArray,
        camToXyzD50: FloatArray,
        useDisplayP3: Boolean,
        applyFlatField: Boolean,
        sensorOrientationDegrees: Int,
        outFile: File
    ): RustRawDevelopOutput {
        if (!loaded) {
            return RustRawDevelopOutput(
                rustIspSucceeded = false,
                meanRgb = listOf(0.0, 0.0, 0.0),
                centerLinearCamRgb = listOf(0.18, 0.18, 0.18),
                highlightClippedRatio = 0.0,
                gamutClippedRatio = 0.0
            )
        }

        val outW = width / 2
        val outH = height / 2
        val paramsBuffer = ByteBuffer.allocateDirect(17 * 4).order(ByteOrder.nativeOrder())
        val pf = paramsBuffer.asFloatBuffer()
        pf.put(blackLevel[0])
        pf.put(blackLevel[1])
        pf.put(blackLevel[2])
        pf.put(blackLevel[3])
        pf.put(whiteLevel)
        pf.put(wbGains[0])
        pf.put(wbGains[1])
        pf.put(wbGains[2])
        for (i in 0 until 9) {
            pf.put(camToXyzD50[i])
        }

        val outRgbaBuffer = ByteBuffer.allocateDirect(outW * outH * 4)
        val outStatsBuffer = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder())

        val rc = nativeDevelopBayer16Direct(
            rawDirectBuffer,
            width,
            height,
            rowStride,
            cfaPattern,
            paramsBuffer,
            if (useDisplayP3) 1 else 0,
            if (applyFlatField) 1 else 0,
            outRgbaBuffer,
            outStatsBuffer
        )

        if (rc != 0) {
            return RustRawDevelopOutput(
                rustIspSucceeded = false,
                meanRgb = listOf(0.0, 0.0, 0.0),
                centerLinearCamRgb = listOf(0.18, 0.18, 0.18),
                highlightClippedRatio = 0.0,
                gamutClippedRatio = 0.0
            )
        }

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

        val finalBitmap = if (sensorOrientationDegrees != 0) {
            val matrix = Matrix().apply { postRotate(sensorOrientationDegrees.toFloat()) }
            val rotated = Bitmap.createBitmap(rawBitmap, 0, 0, outW, outH, matrix, true)
            if (rotated !== rawBitmap) rawBitmap.recycle()
            rotated
        } else {
            rawBitmap
        }

        FileOutputStream(outFile).use { fos ->
            finalBitmap.compress(Bitmap.CompressFormat.JPEG, 96, fos)
        }
        finalBitmap.recycle()

        val sf = outStatsBuffer.asFloatBuffer()
        val meanR = sf.get(0).toDouble()
        val meanG = sf.get(1).toDouble()
        val meanB = sf.get(2).toDouble()
        val highlightClip = sf.get(3).toDouble()
        val gamutClip = sf.get(4).toDouble()
        val centerR = sf.get(5).toDouble()
        val centerG = sf.get(6).toDouble()
        val centerB = sf.get(7).toDouble()

        return RustRawDevelopOutput(
            rustIspSucceeded = true,
            meanRgb = listOf(meanR, meanG, meanB),
            centerLinearCamRgb = listOf(centerR, centerG, centerB),
            highlightClippedRatio = highlightClip,
            gamutClippedRatio = gamutClip
        )
    }
}
